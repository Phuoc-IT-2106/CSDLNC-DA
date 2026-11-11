/* =====================================================================
   usp_P3_RevenueReports.sql
   Classification : P3_OWNED - production routines (Person 3). Read-only reports. Programmability only:
                    creates no table, column, constraint, index, view or summary.
   Work order     : WO-P3-P4-01 Part F (functional report correctness; scope amendment of 2026-11-10).
   Objects        : dbo.tvf_P3_ReportPeriodUtc           (inline function: local half-open period -> UTC bounds)
                    dbo.tvf_P3_ReportPeriodStart         (inline function: UTC payment time -> local bucket start)
                    dbo.usp_P3_RptBranchRevenue          RPT-01  one branch, one period, total        (F27, RQ-A14)
                    dbo.usp_P3_RptSystemRevenue          RPT-02  all branches, one period, total      (F28, RQ-A15)
                    dbo.usp_P3_RptSystemRevenueByBranch  RPT-02  all branches, one period, per branch (F28, RQ-A15)
                    dbo.usp_P3_RptBranchRevenueByPeriod  RPT-03/RPT-04  one branch, per day/month/quarter/year
                    dbo.usp_P3_RptSystemRevenueByPeriod  RPT-04  all branches, per period and branch
   Decisions      : D-010 APPROVED (provisional, T2) 2026-11-10 - recognised revenue:
                      1 only successfully paid invoices        (PaymentStatus = 'PAID', literal: D-005, DEP-08)
                      2 amount  = INVOICE.FinalAmount          (after discounts, D-023; the header, never the lines)
                      3 time    = INVOICE.PaidAt               (D-004), not IssuedAt
                      4 periods = Asia/Ho_Chi_Minh calendar    5 PaidAt stays stored in UTC (D-014)
                      6 branch  = INVOICE.Branch_ID            7 PENDING and CANCELLED excluded
                      8 refunds out of scope (D-011)           9 company-wide = sum of the branch revenue under
                                                                 the same filters and period
                    Asia/Ho_Chi_Minh = UTC+7 without daylight saving: the same fixed rule as
                    dbo.tvf_P3_SpendingMonth (settlement) and the seed generator S001.
   Periods        : @FromDate and @ToDate are LOCAL calendar dates and form the half-open period
                    [@FromDate 00:00 local, @ToDate 00:00 local). A local month is (first day, first day of the
                    next month); a year is (1 January, 1 January of the next year). The bounds are converted
                    ONCE to UTC (minus 7 hours) and every report filters with
                        PaymentStatus = 'PAID' AND PaidAt >= @FromUtc AND PaidAt < @ToUtc
                    No function is applied to PaidAt in a filter (08 section 7 rule 1). The local date of a
                    payment is computed only for the qualifying rows, to group them.
   Result rules   : - one SELECT over INVOICE per routine (one query shape per routine); the line tables are
                      never joined, so an invoice contributes once whatever its number of lines;
                    - the two total routines always return ONE row (revenue 0.00, count 0 when nothing is paid);
                    - the grouped routines return a row only for a branch / bucket with at least one PAID
                      invoice (07 section 2 default, ASSUMPTION_PENDING_APPROVAL: the caller fills zeros);
                    - a bucket is labelled by its first local day (PeriodStart); a bucket cut by the requested
                      period contains only the part inside the period;
                    - SharePct = branch revenue * 100 / system revenue, rounded to 2 decimals (NULL when the
                      system revenue is 0); the rounded shares may differ from 100.00 by 0.01 per branch.
   Errors         : 51400 prerequisites missing (deployment)   51403 unknown Branch_ID
                    51401 a required parameter is NULL         51404 @Grain not DAY | MONTH | QUARTER | YEAR
                    51402 @FromDate is not before @ToDate      (P3 range, DEP-13)
   Transactions   : none. Default READ COMMITTED; no hint, no lock escalation request, no write.
   Shared tables  : dbo.BRANCH is read by key only (Branch_ID exists), 12 section 2a.
   Not done here  : indexes, filtered indexes, columnstore, summary table or indexed view (WO-P3-P4-01 Part X,
                    WO-P3-P4-02), partitioning (WO-P3-P5-01); line-level reports RPT-05...07 (D-001);
                    the frozen benchmark queries Q-UC06-* (WO-P3-P2-02). No performance claim is attached.
   Re-runnable    : CREATE OR ALTER.
   Run            : sqlcmd -S localhost -E -I -b -d <database> -i db/procedures/usp_P3_RevenueReports.sql
   ===================================================================== */
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.INVOICE', N'U') IS NULL OR COL_LENGTH(N'dbo.INVOICE', N'PaidAt') IS NULL
    THROW 51400, N'usp_P3_RevenueReports requires migrations V001 and V002.', 1;
IF OBJECT_ID(N'dbo.BRANCH', N'U') IS NULL OR COL_LENGTH(N'dbo.BRANCH', N'Branch_ID') IS NULL
    THROW 51400, N'usp_P3_RevenueReports requires the shared table dbo.BRANCH (Branch_ID); see 12 section 2a.', 1;
GO

/* Local half-open period [@FromDate, @ToDate) -> UTC bounds (Asia/Ho_Chi_Minh = UTC+7, no DST). */
CREATE OR ALTER FUNCTION dbo.tvf_P3_ReportPeriodUtc (@FromDate DATE, @ToDate DATE)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT DATEADD(HOUR, -7, CONVERT(DATETIME2(3), @FromDate)) AS FromUtc,
           DATEADD(HOUR, -7, CONVERT(DATETIME2(3), @ToDate))   AS ToUtc;
GO

/* UTC payment time -> first local day of its day / month / quarter / year. Used in SELECT and GROUP BY only. */
CREATE OR ALTER FUNCTION dbo.tvf_P3_ReportPeriodStart (@PaidAtUtc DATETIME2(3), @Grain VARCHAR(7))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT CASE @Grain
               WHEN 'DAY'     THEN l.LocalDate
               WHEN 'MONTH'   THEN DATEFROMPARTS(YEAR(l.LocalDate), MONTH(l.LocalDate), 1)
               WHEN 'QUARTER' THEN DATEFROMPARTS(YEAR(l.LocalDate), (DATEPART(QUARTER, l.LocalDate) - 1) * 3 + 1, 1)
               WHEN 'YEAR'    THEN DATEFROMPARTS(YEAR(l.LocalDate), 1, 1)
           END AS PeriodStart
    FROM (SELECT CONVERT(DATE, DATEADD(HOUR, 7, @PaidAtUtc)) AS LocalDate) AS l;
GO

/* RPT-01: revenue of ONE branch in ONE period. Always one row. */
CREATE OR ALTER PROCEDURE dbo.usp_P3_RptBranchRevenue
    @Branch_ID     INT,
    @FromDate      DATE,
    @ToDate        DATE,
    @Revenue       DECIMAL(38,2) = NULL OUTPUT,
    @InvoiceCount  BIGINT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @FromUtc DATETIME2(3), @ToUtc DATETIME2(3), @msg NVARCHAR(400);
    SELECT @Revenue = NULL, @InvoiceCount = NULL;

    IF @Branch_ID IS NULL OR @FromDate IS NULL OR @ToDate IS NULL
        THROW 51401, N'usp_P3_RptBranchRevenue: Branch_ID, FromDate and ToDate are required.', 1;
    IF @FromDate >= @ToDate
        THROW 51402, N'usp_P3_RptBranchRevenue: FromDate must be before ToDate (half-open local period).', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.BRANCH AS b WHERE b.Branch_ID = @Branch_ID)
    BEGIN
        SET @msg = CONCAT(N'usp_P3_RptBranchRevenue: unknown Branch_ID ', @Branch_ID, N'.');
        THROW 51403, @msg, 1;
    END;
    SELECT @FromUtc = FromUtc, @ToUtc = ToUtc FROM dbo.tvf_P3_ReportPeriodUtc(@FromDate, @ToDate);

    SELECT @Revenue = ISNULL(SUM(i.FinalAmount), 0), @InvoiceCount = COUNT_BIG(*)
    FROM dbo.INVOICE AS i
    WHERE i.Branch_ID = @Branch_ID
      AND i.PaymentStatus = 'PAID' AND i.PaidAt >= @FromUtc AND i.PaidAt < @ToUtc;

    SELECT @Branch_ID AS Branch_ID, @FromDate AS FromDate, @ToDate AS ToDate, @Revenue AS Revenue, @InvoiceCount AS InvoiceCount;
    RETURN 0;
END;
GO

/* RPT-02 (total): company-wide revenue in ONE period. Always one row. */
CREATE OR ALTER PROCEDURE dbo.usp_P3_RptSystemRevenue
    @FromDate      DATE,
    @ToDate        DATE,
    @Revenue       DECIMAL(38,2) = NULL OUTPUT,
    @InvoiceCount  BIGINT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @FromUtc DATETIME2(3), @ToUtc DATETIME2(3);
    SELECT @Revenue = NULL, @InvoiceCount = NULL;

    IF @FromDate IS NULL OR @ToDate IS NULL
        THROW 51401, N'usp_P3_RptSystemRevenue: FromDate and ToDate are required.', 1;
    IF @FromDate >= @ToDate
        THROW 51402, N'usp_P3_RptSystemRevenue: FromDate must be before ToDate (half-open local period).', 1;
    SELECT @FromUtc = FromUtc, @ToUtc = ToUtc FROM dbo.tvf_P3_ReportPeriodUtc(@FromDate, @ToDate);

    SELECT @Revenue = ISNULL(SUM(i.FinalAmount), 0), @InvoiceCount = COUNT_BIG(*)
    FROM dbo.INVOICE AS i
    WHERE i.PaymentStatus = 'PAID' AND i.PaidAt >= @FromUtc AND i.PaidAt < @ToUtc;

    SELECT @FromDate AS FromDate, @ToDate AS ToDate, @Revenue AS Revenue, @InvoiceCount AS InvoiceCount;
    RETURN 0;
END;
GO

/* RPT-02 (comparison): revenue per branch in ONE period, with the system total and each branch's share. */
CREATE OR ALTER PROCEDURE dbo.usp_P3_RptSystemRevenueByBranch
    @FromDate  DATE,
    @ToDate    DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @FromUtc DATETIME2(3), @ToUtc DATETIME2(3);

    IF @FromDate IS NULL OR @ToDate IS NULL
        THROW 51401, N'usp_P3_RptSystemRevenueByBranch: FromDate and ToDate are required.', 1;
    IF @FromDate >= @ToDate
        THROW 51402, N'usp_P3_RptSystemRevenueByBranch: FromDate must be before ToDate (half-open local period).', 1;
    SELECT @FromUtc = FromUtc, @ToUtc = ToUtc FROM dbo.tvf_P3_ReportPeriodUtc(@FromDate, @ToDate);

    SELECT g.Branch_ID, g.Revenue, g.InvoiceCount,
           SUM(g.Revenue) OVER ()      AS SystemRevenue,
           SUM(g.InvoiceCount) OVER () AS SystemInvoiceCount,
           CASE WHEN SUM(g.Revenue) OVER () > 0
                THEN CONVERT(DECIMAL(7,2), ROUND(g.Revenue * 100 / SUM(g.Revenue) OVER (), 2)) END AS SharePct
    FROM (SELECT i.Branch_ID, SUM(i.FinalAmount) AS Revenue, COUNT_BIG(*) AS InvoiceCount
          FROM dbo.INVOICE AS i
          WHERE i.PaymentStatus = 'PAID' AND i.PaidAt >= @FromUtc AND i.PaidAt < @ToUtc
          GROUP BY i.Branch_ID) AS g
    ORDER BY g.Branch_ID;
    RETURN 0;
END;
GO

/* RPT-03 / RPT-04 (branch): revenue of ONE branch per local day, month, quarter or year. */
CREATE OR ALTER PROCEDURE dbo.usp_P3_RptBranchRevenueByPeriod
    @Branch_ID  INT,
    @FromDate   DATE,
    @ToDate     DATE,
    @Grain      VARCHAR(7)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @FromUtc DATETIME2(3), @ToUtc DATETIME2(3), @msg NVARCHAR(400);

    IF @Branch_ID IS NULL OR @FromDate IS NULL OR @ToDate IS NULL OR @Grain IS NULL
        THROW 51401, N'usp_P3_RptBranchRevenueByPeriod: Branch_ID, FromDate, ToDate and Grain are required.', 1;
    IF @FromDate >= @ToDate
        THROW 51402, N'usp_P3_RptBranchRevenueByPeriod: FromDate must be before ToDate (half-open local period).', 1;
    IF @Grain NOT IN ('DAY', 'MONTH', 'QUARTER', 'YEAR')
        THROW 51404, N'usp_P3_RptBranchRevenueByPeriod: Grain must be DAY, MONTH, QUARTER or YEAR.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.BRANCH AS b WHERE b.Branch_ID = @Branch_ID)
    BEGIN
        SET @msg = CONCAT(N'usp_P3_RptBranchRevenueByPeriod: unknown Branch_ID ', @Branch_ID, N'.');
        THROW 51403, @msg, 1;
    END;
    SELECT @FromUtc = FromUtc, @ToUtc = ToUtc FROM dbo.tvf_P3_ReportPeriodUtc(@FromDate, @ToDate);

    SELECT p.PeriodStart, SUM(i.FinalAmount) AS Revenue, COUNT_BIG(*) AS InvoiceCount
    FROM dbo.INVOICE AS i
    CROSS APPLY dbo.tvf_P3_ReportPeriodStart(i.PaidAt, @Grain) AS p
    WHERE i.Branch_ID = @Branch_ID
      AND i.PaymentStatus = 'PAID' AND i.PaidAt >= @FromUtc AND i.PaidAt < @ToUtc
    GROUP BY p.PeriodStart
    ORDER BY p.PeriodStart;
    RETURN 0;
END;
GO

/* RPT-04 (system): revenue per local period and branch, with the company-wide total of each period. */
CREATE OR ALTER PROCEDURE dbo.usp_P3_RptSystemRevenueByPeriod
    @FromDate  DATE,
    @ToDate    DATE,
    @Grain     VARCHAR(7)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @FromUtc DATETIME2(3), @ToUtc DATETIME2(3);

    IF @FromDate IS NULL OR @ToDate IS NULL OR @Grain IS NULL
        THROW 51401, N'usp_P3_RptSystemRevenueByPeriod: FromDate, ToDate and Grain are required.', 1;
    IF @FromDate >= @ToDate
        THROW 51402, N'usp_P3_RptSystemRevenueByPeriod: FromDate must be before ToDate (half-open local period).', 1;
    IF @Grain NOT IN ('DAY', 'MONTH', 'QUARTER', 'YEAR')
        THROW 51404, N'usp_P3_RptSystemRevenueByPeriod: Grain must be DAY, MONTH, QUARTER or YEAR.', 1;
    SELECT @FromUtc = FromUtc, @ToUtc = ToUtc FROM dbo.tvf_P3_ReportPeriodUtc(@FromDate, @ToDate);

    SELECT g.PeriodStart, g.Branch_ID, g.Revenue, g.InvoiceCount,
           SUM(g.Revenue) OVER (PARTITION BY g.PeriodStart)      AS PeriodSystemRevenue,
           SUM(g.InvoiceCount) OVER (PARTITION BY g.PeriodStart) AS PeriodSystemInvoiceCount
    FROM (SELECT p.PeriodStart, i.Branch_ID, SUM(i.FinalAmount) AS Revenue, COUNT_BIG(*) AS InvoiceCount
          FROM dbo.INVOICE AS i
          CROSS APPLY dbo.tvf_P3_ReportPeriodStart(i.PaidAt, @Grain) AS p
          WHERE i.PaymentStatus = 'PAID' AND i.PaidAt >= @FromUtc AND i.PaidAt < @ToUtc
          GROUP BY p.PeriodStart, i.Branch_ID) AS g
    ORDER BY g.PeriodStart, g.Branch_ID;
    RETURN 0;
END;
GO

PRINT 'usp_P3_RevenueReports applied: functions dbo.tvf_P3_ReportPeriodUtc, dbo.tvf_P3_ReportPeriodStart; procedures dbo.usp_P3_RptBranchRevenue, dbo.usp_P3_RptSystemRevenue, dbo.usp_P3_RptSystemRevenueByBranch, dbo.usp_P3_RptBranchRevenueByPeriod, dbo.usp_P3_RptSystemRevenueByPeriod';
GO
