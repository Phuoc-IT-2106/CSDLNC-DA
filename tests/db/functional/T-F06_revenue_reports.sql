/* =====================================================================
   T-F06_revenue_reports.sql - TEST_ONLY (sqlcmd mode)
   Work order : WO-P3-P4-01 Part F (UC06 revenue reports, D-010). Functional only (no timing).
   Runs in a fresh FitLife_P3_UC05 that holds exactly the 16 invoices of the TEST_ONLY fixture R001
   (tests/db/fixtures/R001__TEST_ONLY_revenue_report_invoices.sql). Every expected value below is a
   literal calculated by hand from the fixture table in the R001 header, not by the routines under test.
     T-F06-01  branch revenue for a period and per day / month / quarter / year            (F01, F08a-F08d)
     T-F06-02  system revenue, per-branch comparison and shares, per period and branch     (F07, F09)
     T-F06-03  PENDING and CANCELLED invoices contribute nothing                          (F03)
     T-F06-04  half-open local periods converted to UTC bounds: row at @From included, row at @To
               excluded, payment at 00:30 local on the 1st belongs to the new month       (F04)
     T-F06-05  empty period, branch without paid sales, fully discounted invoice          (F02, F10)
     T-F06-09  PaidAt, not IssuedAt, decides the period                                   (F05)
     T-F06-10  discounts counted exactly once; a multi-line invoice contributes once      (F06)
     T-F06-11  real path: create -> settle -> report; repeated settlement, cancellation and
               a pending invoice change nothing                                           (F13)
     T-F06-12  invalid parameters are rejected (51401-51404)                              (F12)
     T-F06-13  detail = aggregate: day, month, quarter and year series, branch totals and the system
               total agree with each other and with an independent invoice-level reference (F11)
   Run: sqlcmd -S localhost -E -I -b -W -d FitLife_P3_UC05 -i tests/db/functional/T-F06_revenue_reports.sql
   ===================================================================== */
:on error exit
SET NOCOUNT ON;
SET XACT_ABORT OFF;

IF DB_NAME() <> N'FitLife_P3_UC05'
   OR NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable' AND CONVERT(nvarchar(200), value) LIKE N'WO-P3-P3-00%')
    THROW 51420, N'T-F06 runs only in FitLife_P3_UC05 with the disposable marker.', 1;
IF OBJECT_ID(N'dbo.usp_P3_RptBranchRevenue', N'P') IS NULL OR OBJECT_ID(N'dbo.usp_P3_RptSystemRevenue', N'P') IS NULL OR OBJECT_ID(N'dbo.usp_P3_RptSystemRevenueByBranch', N'P') IS NULL
   OR OBJECT_ID(N'dbo.usp_P3_RptBranchRevenueByPeriod', N'P') IS NULL OR OBJECT_ID(N'dbo.usp_P3_RptSystemRevenueByPeriod', N'P') IS NULL
   OR OBJECT_ID(N'dbo.usp_P3_CreateInvoice', N'P') IS NULL OR OBJECT_ID(N'dbo.usp_P3_SettleInvoice', N'P') IS NULL OR OBJECT_ID(N'dbo.usp_P3_CancelInvoice', N'P') IS NULL
    THROW 51421, N'T-F06: revenue report routines or the UC05 routines are not deployed.', 1;
IF OBJECT_ID(N'dbo.TEST_RevenueFixture', N'U') IS NULL OR (SELECT COUNT(*) FROM dbo.INVOICE) <> 16 OR (SELECT COUNT(*) FROM dbo.TEST_RevenueFixture) <> 16
    THROW 51422, N'T-F06 expects exactly the 16 invoices of fixture R001 (fresh database).', 1;
IF CONVERT(date, DATEADD(MINUTE, 5, DATEADD(HOUR, 7, SYSUTCDATETIME()))) <> CONVERT(date, DATEADD(HOUR, 7, SYSUTCDATETIME()))
    THROW 51423, N'T-F06: too close to local midnight; run again in a few minutes.', 1;
IF CONVERT(date, DATEADD(HOUR, 7, SYSUTCDATETIME())) < '2026-05-01'
    THROW 51424, N'T-F06: the fixture periods must lie before the current local month.', 1;

DECLARE @results TABLE (seq int IDENTITY(1,1), case_id varchar(8), test_id varchar(10), result varchar(4), descr nvarchar(700), detail nvarchar(2000));
DECLARE @rev decimal(38,2), @cnt bigint, @rev2 decimal(38,2), @cnt2 bigint, @rev3 decimal(38,2), @cnt3 bigint, @n int, @n2 int, @ok bit, @err int, @errs varchar(400);
DECLARE @d1 decimal(38,2), @d2 decimal(38,2), @d3 decimal(38,2), @d4 decimal(38,2), @d5 decimal(38,2), @c1 bigint, @c2 bigint, @c3 bigint, @c4 bigint, @c5 bigint;
DECLARE @fu datetime2(3), @tu datetime2(3), @txt nvarchar(1800);

CREATE TABLE #tot (Branch_ID int, FromDate date, ToDate date, Revenue decimal(38,2), InvoiceCount bigint);
CREATE TABLE #sys (FromDate date, ToDate date, Revenue decimal(38,2), InvoiceCount bigint);
CREATE TABLE #byb (Branch_ID int, Revenue decimal(38,2), InvoiceCount bigint, SystemRevenue decimal(38,2), SystemInvoiceCount bigint, SharePct decimal(7,2));
CREATE TABLE #bp  (PeriodStart date, Revenue decimal(38,2), InvoiceCount bigint);
CREATE TABLE #sp  (PeriodStart date, Branch_ID int, Revenue decimal(38,2), InvoiceCount bigint, PeriodSystemRevenue decimal(38,2), PeriodSystemInvoiceCount bigint);
DECLARE @ebp TABLE (PeriodStart date, Revenue decimal(38,2), InvoiceCount bigint);
DECLARE @esp TABLE (PeriodStart date, Branch_ID int, Revenue decimal(38,2), InvoiceCount bigint, PeriodSystemRevenue decimal(38,2), PeriodSystemInvoiceCount bigint);
DECLARE @ebb TABLE (Branch_ID int, Revenue decimal(38,2), InvoiceCount bigint, SystemRevenue decimal(38,2), SystemInvoiceCount bigint, SharePct decimal(7,2));

/* ---------- F01 T-F06-01: branch revenue of a local month ---------- */
DELETE #tot;
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 1, @FromDate = '2026-01-01', @ToDate = '2026-02-01', @Revenue = @rev OUTPUT, @InvoiceCount = @cnt OUTPUT;
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 2, @FromDate = '2026-01-01', @ToDate = '2026-02-01', @Revenue = @rev2 OUTPUT, @InvoiceCount = @cnt2 OUTPUT;
SET @n = (SELECT COUNT(*) FROM #tot WHERE (Branch_ID = 1 AND Revenue = 371000.00 AND InvoiceCount = 5 AND FromDate = '2026-01-01' AND ToDate = '2026-02-01')
                                       OR (Branch_ID = 2 AND Revenue = 374999.50 AND InvoiceCount = 1 AND FromDate = '2026-01-01' AND ToDate = '2026-02-01'));
INSERT @results VALUES ('F01', 'T-F06-01', CASE WHEN @n = 2 AND (SELECT COUNT(*) FROM #tot) = 2 AND @rev = 371000.00 AND @cnt = 5 AND @rev2 = 374999.50 AND @cnt2 = 1 THEN 'PASS' ELSE 'FAIL' END,
    N'Branch revenue, local January 2026: branch 1 = 250000 + 70000 + 40000 + 5000 + 6000 = 371000.00 (5 invoices); branch 2 = 374999.50 (1 invoice); result row = OUTPUT values',
    CONCAT(N'branch 1: ', @rev, N' / ', @cnt, N'; branch 2: ', @rev2, N' / ', @cnt2, N'; matching result rows ', @n, N' of 2'));

/* ---------- F02 T-F06-05: branch without a PAID invoice in the period ---------- */
DELETE #tot;
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 3, @FromDate = '2026-01-01', @ToDate = '2026-02-01', @Revenue = @rev OUTPUT, @InvoiceCount = @cnt OUTPUT;
INSERT @results VALUES ('F02', 'T-F06-05', CASE WHEN (SELECT COUNT(*) FROM #tot) = 1 AND (SELECT COUNT(*) FROM #tot WHERE Branch_ID = 3 AND Revenue = 0 AND InvoiceCount = 0) = 1 AND @rev = 0 AND @cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Branch 3 in January 2026 has only a PENDING invoice (123000): the report returns ONE row with revenue 0.00 and 0 invoices (not NULL, not an empty result)',
    CONCAT(N'rows ', (SELECT COUNT(*) FROM #tot), N'; revenue ', ISNULL(CONVERT(varchar(40), @rev), 'NULL'), N'; invoices ', ISNULL(CONVERT(varchar(20), @cnt), 'NULL')));

/* ---------- F03 T-F06-03: PENDING and CANCELLED excluded ---------- */
DELETE #sys;
INSERT #sys EXEC dbo.usp_P3_RptSystemRevenue @FromDate = '2025-01-01', @ToDate = '2027-01-01', @Revenue = @rev OUTPUT, @InvoiceCount = @cnt OUTPUT;
SELECT @d1 = SUM(FinalAmount), @c1 = COUNT_BIG(*) FROM dbo.INVOICE;
SELECT @d2 = SUM(FinalAmount), @c2 = COUNT_BIG(*) FROM dbo.INVOICE WHERE PaymentStatus IN ('PENDING', 'CANCELLED');
DELETE #tot;
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 2, @FromDate = '2026-01-01', @ToDate = '2026-02-01', @Revenue = @rev2 OUTPUT, @InvoiceCount = @cnt2 OUTPUT;
INSERT @results VALUES ('F03', 'T-F06-03', CASE WHEN @rev = 1836999.50 AND @cnt = 13 AND @d1 = 3359999.50 AND @c1 = 16 AND @d2 = 1523000.00 AND @c2 = 3 AND @d1 - @rev = @d2 AND @rev2 = 374999.50 AND @cnt2 = 1 THEN 'PASS' ELSE 'FAIL' END,
    N'All 13 PAID invoices = 1836999.50; the PENDING (800000 + 123000) and CANCELLED (600000) invoices = 1523000.00 are excluded (all 16 invoices = 3359999.50); branch 2 January = 374999.50, not 1774999.50',
    CONCAT(N'report ', @rev, N' / ', @cnt, N'; all invoices ', @d1, N' / ', @c1, N'; non-PAID ', @d2, N' / ', @c2, N'; branch 2 January ', @rev2, N' / ', @cnt2));

/* ---------- F04 T-F06-04: half-open boundaries, local month vs UTC ---------- */
SELECT @fu = FromUtc, @tu = ToUtc FROM dbo.tvf_P3_ReportPeriodUtc('2026-01-01', '2026-02-01');
DELETE #tot;
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 1, @FromDate = '2025-12-01', @ToDate = '2026-01-01', @Revenue = @d1 OUTPUT, @InvoiceCount = @c1 OUTPUT;   -- December 2025: R01 only
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 1, @FromDate = '2026-01-01', @ToDate = '2026-02-01', @Revenue = @d2 OUTPUT, @InvoiceCount = @c2 OUTPUT;   -- January 2026
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 1, @FromDate = '2026-02-01', @ToDate = '2026-03-01', @Revenue = @d3 OUTPUT, @InvoiceCount = @c3 OUTPUT;   -- February 2026: R05 only
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 1, @FromDate = '2026-01-01', @ToDate = '2026-01-02', @Revenue = @d4 OUTPUT, @InvoiceCount = @c4 OUTPUT;   -- 1 January: R02 + R03
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 1, @FromDate = '2026-01-31', @ToDate = '2026-02-01', @Revenue = @d5 OUTPUT, @InvoiceCount = @c5 OUTPUT;   -- 31 January: R04 only
INSERT @results VALUES ('F04', 'T-F06-04', CASE WHEN @fu = '2025-12-31 17:00:00.000' AND @tu = '2026-01-31 17:00:00.000'
                                              AND @d1 = 100000.00 AND @c1 = 1 AND @d2 = 371000.00 AND @c2 = 5 AND @d3 = 900000.00 AND @c3 = 1
                                              AND @d4 = 320000.00 AND @c4 = 2 AND @d5 = 40000.00 AND @c5 = 1 THEN 'PASS' ELSE 'FAIL' END,
    N'Local January 2026 = [2025-12-31 17:00:00.000, 2026-01-31 17:00:00.000) UTC. Paid 16:59:59.999 UTC on 31 Dec -> December; exactly 17:00:00.000 -> January (@From included); 00:30 local on 1 Jan -> January; 16:59:59.999 UTC on 31 Jan -> January; exactly 17:00:00.000 on 31 Jan -> February (@To excluded)',
    CONCAT(N'UTC bounds ', CONVERT(varchar(23), @fu, 121), N' .. ', CONVERT(varchar(23), @tu, 121), N'; branch 1: Dec 2025 ', @d1, N'/', @c1, N'; Jan 2026 ', @d2, N'/', @c2, N'; Feb 2026 ', @d3, N'/', @c3,
           N'; 1 Jan ', @d4, N'/', @c4, N'; 31 Jan ', @d5, N'/', @c5));

/* ---------- F05 T-F06-09: PaidAt, not IssuedAt ---------- */
DELETE #tot;
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 3, @FromDate = '2026-01-01', @ToDate = '2026-02-01', @Revenue = @d1 OUTPUT, @InvoiceCount = @c1 OUTPUT;
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 3, @FromDate = '2026-02-01', @ToDate = '2026-03-01', @Revenue = @d2 OUTPUT, @InvoiceCount = @c2 OUTPUT;
DELETE #sys;
INSERT #sys EXEC dbo.usp_P3_RptSystemRevenue @FromDate = '2026-01-01', @ToDate = '2026-02-01', @Revenue = @rev OUTPUT, @InvoiceCount = @cnt OUTPUT;
-- what a report dated by IssuedAt would have shown for January 2026 (must differ: the fixture separates the two rules)
SELECT @d3 = ISNULL(SUM(FinalAmount), 0), @c3 = COUNT_BIG(*) FROM dbo.INVOICE
WHERE PaymentStatus = 'PAID' AND CONVERT(date, DATEADD(HOUR, 7, IssuedAt)) >= '2026-01-01' AND CONVERT(date, DATEADD(HOUR, 7, IssuedAt)) < '2026-02-01';
INSERT @results VALUES ('F05', 'T-F06-09', CASE WHEN @d1 = 0 AND @c1 = 0 AND @d2 = 60000.00 AND @c2 = 2 AND @rev = 745999.50 AND @cnt = 6 AND @d3 = 1385999.50 AND @c3 = 6 AND @d3 <> @rev THEN 'PASS' ELSE 'FAIL' END,
    N'Invoice R10 issued on 31 January and paid on 2 February counts in February (branch 3: January 0, February 60000.00 with 2 invoices incl. the fully discounted R16); R02 and R03 issued on 31 December and paid on 1 January count in January. System January = 745999.50; dating by IssuedAt would give 1385999.50',
    CONCAT(N'branch 3: Jan ', @d1, N'/', @c1, N', Feb ', @d2, N'/', @c2, N'; system Jan (PaidAt, report) ', @rev, N'/', @cnt, N'; by IssuedAt (reference only) ', @d3, N'/', @c3));

/* ---------- F06 T-F06-10: discount exactly once; a multi-line invoice counted once ---------- */
DELETE #tot;
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 2, @FromDate = '2026-01-15', @ToDate = '2026-01-16', @Revenue = @rev OUTPUT, @InvoiceCount = @cnt OUTPUT;
SELECT @d1 = i.GrossAmount, @d2 = i.DiscountAmount, @d3 = i.FinalAmount,
       @c1 = (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM AS s WHERE s.Invoice_ID = i.Invoice_ID) + (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM AS p WHERE p.Invoice_ID = i.Invoice_ID)
FROM dbo.INVOICE AS i JOIN dbo.TEST_RevenueFixture AS f ON f.Invoice_ID = i.Invoice_ID WHERE f.Label = 'R06';
-- independent line-level reference for all PAID invoices: lines aggregated per invoice first
WITH s AS (SELECT Invoice_ID, SUM(UnitPrice - DiscountAmount) AS net FROM dbo.INVOICE_SERVICE_ITEM GROUP BY Invoice_ID),
     p AS (SELECT Invoice_ID, SUM(UnitPrice * Quantity - DiscountAmount) AS net FROM dbo.INVOICE_PRODUCT_ITEM GROUP BY Invoice_ID)
SELECT @d4 = SUM(ISNULL(s.net, 0) + ISNULL(p.net, 0)) FROM dbo.INVOICE AS i LEFT JOIN s ON s.Invoice_ID = i.Invoice_ID LEFT JOIN p ON p.Invoice_ID = i.Invoice_ID WHERE i.PaymentStatus = 'PAID';
-- what a report joining the header to its product lines would have shown (must differ: R02 has two product lines)
SELECT @d5 = SUM(i.FinalAmount) FROM dbo.INVOICE AS i JOIN dbo.INVOICE_PRODUCT_ITEM AS p ON p.Invoice_ID = i.Invoice_ID WHERE i.PaymentStatus = 'PAID';
DELETE #sys;
INSERT #sys EXEC dbo.usp_P3_RptSystemRevenue @FromDate = '2025-01-01', @ToDate = '2027-01-01', @Revenue = @rev2 OUTPUT, @InvoiceCount = @cnt2 OUTPUT;
DELETE #sp;
INSERT #sp EXEC dbo.usp_P3_RptSystemRevenueByPeriod @FromDate = '2025-01-01', @ToDate = '2027-01-01', @Grain = 'DAY';
SELECT @c2 = SUM(InvoiceCount) FROM #sp;
INSERT @results VALUES ('F06', 'T-F06-10', CASE WHEN @rev = 374999.50 AND @cnt = 1 AND @d1 = 500000.00 AND @d2 = 125000.50 AND @d3 = 374999.50 AND @c1 = 2
                                              AND @d4 = 1836999.50 AND @rev2 = @d4 AND @d5 = 2086999.50 AND @d5 <> @rev2 AND @cnt2 = 13 AND @c2 = 13 THEN 'PASS' ELSE 'FAIL' END,
    N'R06 (service 400000 - 100000.50; product 2 x 50000 - 25000): gross 500000.00, discount 125000.50 -> revenue 374999.50 once (not 500000.00, not 249999.00, not doubled by its 2 lines). All PAID: report = line-level reference = 1836999.50; a header-to-lines join would give 2086999.50; each of the 13 PAID invoices is counted once',
    CONCAT(N'branch 2 on 15 Jan ', @rev, N'/', @cnt, N'; R06 header ', @d1, N' - ', @d2, N' = ', @d3, N', lines ', @c1, N'; all PAID: report ', @rev2, N'/', @cnt2, N', line-level reference ', @d4,
           N', header-join (reference only) ', @d5, N'; sum of daily invoice counts ', @c2));

/* ---------- F07 T-F06-02: system revenue by branch, shares, system total ---------- */
DELETE #byb;
INSERT #byb EXEC dbo.usp_P3_RptSystemRevenueByBranch @FromDate = '2026-01-01', @ToDate = '2026-02-01';
INSERT @ebb VALUES (1, 371000.00, 5, 745999.50, 6, 49.73), (2, 374999.50, 1, 745999.50, 6, 50.27);
SET @n = (SELECT COUNT(*) FROM (SELECT * FROM #byb EXCEPT SELECT * FROM @ebb) AS a) + (SELECT COUNT(*) FROM (SELECT * FROM @ebb EXCEPT SELECT * FROM #byb) AS b) + ABS((SELECT COUNT(*) FROM #byb) - 2);
DELETE #sys;
INSERT #sys EXEC dbo.usp_P3_RptSystemRevenue @FromDate = '2026-01-01', @ToDate = '2026-02-01', @Revenue = @rev OUTPUT, @InvoiceCount = @cnt OUTPUT;
DELETE #tot;
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 1, @FromDate = '2026-01-01', @ToDate = '2026-02-01';
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 2, @FromDate = '2026-01-01', @ToDate = '2026-02-01';
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 3, @FromDate = '2026-01-01', @ToDate = '2026-02-01';
SELECT @d1 = SUM(Revenue), @c1 = SUM(InvoiceCount) FROM #tot;
SELECT @d2 = SUM(SharePct) FROM #byb;
SET @txt = (SELECT STRING_AGG(CONVERT(nvarchar(400), CONCAT(Branch_ID, N': ', Revenue, N'/', InvoiceCount, N' share ', SharePct, N'% of ', SystemRevenue, N'/', SystemInvoiceCount)), N'; ') WITHIN GROUP (ORDER BY Branch_ID) FROM #byb);
INSERT @results VALUES ('F07', 'T-F06-02', CASE WHEN @n = 0 AND @rev = 745999.50 AND @cnt = 6 AND @d1 = @rev AND @c1 = @cnt AND @d2 = 100.00 THEN 'PASS' ELSE 'FAIL' END,
    N'System January 2026: branch 1 371000.00 (49.73%), branch 2 374999.50 (50.27%), no row for branch 3 (no paid sale); system total 745999.50 / 6 = sum of the three branch reports; shares sum to 100.00',
    CONCAT(N'rows: ', ISNULL(@txt, N'none'), N'; differences from the expected rows ', @n, N'; system total routine ', @rev, N'/', @cnt, N'; sum of branch routines ', @d1, N'/', @c1, N'; sum of shares ', @d2));

/* ---------- F08a T-F06-01: branch revenue per local day ---------- */
DELETE #bp; DELETE @ebp;
INSERT #bp EXEC dbo.usp_P3_RptBranchRevenueByPeriod @Branch_ID = 1, @FromDate = '2026-01-01', @ToDate = '2026-02-01', @Grain = 'DAY';
INSERT @ebp VALUES ('2026-01-01', 320000.00, 2), ('2026-01-10', 5000.00, 1), ('2026-01-11', 6000.00, 1), ('2026-01-31', 40000.00, 1);
SET @n = (SELECT COUNT(*) FROM (SELECT * FROM #bp EXCEPT SELECT * FROM @ebp) AS a) + (SELECT COUNT(*) FROM (SELECT * FROM @ebp EXCEPT SELECT * FROM #bp) AS b) + ABS((SELECT COUNT(*) FROM #bp) - 4);
SET @txt = (SELECT STRING_AGG(CONVERT(nvarchar(400), CONCAT(CONVERT(varchar(10), PeriodStart, 23), N'=', Revenue, N'/', InvoiceCount)), N'; ') WITHIN GROUP (ORDER BY PeriodStart) FROM #bp);
INSERT @results VALUES ('F08a', 'T-F06-01', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Branch 1 per local day in January 2026: 1 Jan 320000.00 (2), 10 Jan 5000.00 (paid 16:59:59.999 UTC), 11 Jan 6000.00 (paid 17:00:00.000 UTC on the 10th), 31 Jan 40000.00; days without a paid invoice have no row',
    CONCAT(N'rows: ', ISNULL(@txt, N'none'), N'; differences ', @n));

/* ---------- F08b T-F06-01: branch revenue per local month ---------- */
DELETE #bp; DELETE @ebp;
INSERT #bp EXEC dbo.usp_P3_RptBranchRevenueByPeriod @Branch_ID = 1, @FromDate = '2025-01-01', @ToDate = '2026-05-01', @Grain = 'MONTH';
INSERT @ebp VALUES ('2025-06-01', 1000.00, 1), ('2025-12-01', 100000.00, 1), ('2026-01-01', 371000.00, 5), ('2026-02-01', 900000.00, 1);
SET @n = (SELECT COUNT(*) FROM (SELECT * FROM #bp EXCEPT SELECT * FROM @ebp) AS a) + (SELECT COUNT(*) FROM (SELECT * FROM @ebp EXCEPT SELECT * FROM #bp) AS b) + ABS((SELECT COUNT(*) FROM #bp) - 4);
SET @txt = (SELECT STRING_AGG(CONVERT(nvarchar(400), CONCAT(CONVERT(varchar(10), PeriodStart, 23), N'=', Revenue, N'/', InvoiceCount)), N'; ') WITHIN GROUP (ORDER BY PeriodStart) FROM #bp);
INSERT @results VALUES ('F08b', 'T-F06-01', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Branch 1 per local month, January 2025 to April 2026: June 2025 1000.00; December 2025 100000.00; January 2026 371000.00 (5); February 2026 900000.00 (year boundary between R01 and R02)',
    CONCAT(N'rows: ', ISNULL(@txt, N'none'), N'; differences ', @n));

/* ---------- F08c T-F06-01: quarters ---------- */
DELETE #bp; DELETE @ebp;
INSERT #bp EXEC dbo.usp_P3_RptBranchRevenueByPeriod @Branch_ID = 1, @FromDate = '2025-01-01', @ToDate = '2026-05-01', @Grain = 'QUARTER';
INSERT @ebp VALUES ('2025-04-01', 1000.00, 1), ('2025-10-01', 100000.00, 1), ('2026-01-01', 1271000.00, 6);
SET @n = (SELECT COUNT(*) FROM (SELECT * FROM #bp EXCEPT SELECT * FROM @ebp) AS a) + (SELECT COUNT(*) FROM (SELECT * FROM @ebp EXCEPT SELECT * FROM #bp) AS b) + ABS((SELECT COUNT(*) FROM #bp) - 3);
SET @txt = (SELECT STRING_AGG(CONVERT(nvarchar(400), CONCAT(N'B1 ', CONVERT(varchar(10), PeriodStart, 23), N'=', Revenue, N'/', InvoiceCount)), N'; ') WITHIN GROUP (ORDER BY PeriodStart) FROM #bp);
DELETE #bp; DELETE @ebp;
INSERT #bp EXEC dbo.usp_P3_RptBranchRevenueByPeriod @Branch_ID = 2, @FromDate = '2025-01-01', @ToDate = '2026-05-01', @Grain = 'QUARTER';
INSERT @ebp VALUES ('2026-01-01', 384999.50, 2), ('2026-04-01', 20000.00, 1);
SET @n2 = (SELECT COUNT(*) FROM (SELECT * FROM #bp EXCEPT SELECT * FROM @ebp) AS a) + (SELECT COUNT(*) FROM (SELECT * FROM @ebp EXCEPT SELECT * FROM #bp) AS b) + ABS((SELECT COUNT(*) FROM #bp) - 2);
SET @txt = CONCAT(@txt, N'; ', (SELECT STRING_AGG(CONVERT(nvarchar(400), CONCAT(N'B2 ', CONVERT(varchar(10), PeriodStart, 23), N'=', Revenue, N'/', InvoiceCount)), N'; ') WITHIN GROUP (ORDER BY PeriodStart) FROM #bp));
INSERT @results VALUES ('F08c', 'T-F06-01', CASE WHEN @n = 0 AND @n2 = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Per local quarter. Branch 1: Q2 2025 1000.00, Q4 2025 100000.00, Q1 2026 1271000.00 (6). Branch 2: Q1 2026 384999.50 (R06 + R11 paid 16:59:59.999 UTC on 31 March), Q2 2026 20000.00 (R12 paid 17:00:00.000 UTC on 31 March = 1 April local)',
    CONCAT(N'rows: ', ISNULL(@txt, N'none'), N'; differences ', @n, N' + ', @n2));

/* ---------- F08d T-F06-01: years ---------- */
DELETE #bp; DELETE @ebp;
INSERT #bp EXEC dbo.usp_P3_RptBranchRevenueByPeriod @Branch_ID = 1, @FromDate = '2025-01-01', @ToDate = '2026-05-01', @Grain = 'YEAR';
INSERT @ebp VALUES ('2025-01-01', 101000.00, 2), ('2026-01-01', 1271000.00, 6);
SET @n = (SELECT COUNT(*) FROM (SELECT * FROM #bp EXCEPT SELECT * FROM @ebp) AS a) + (SELECT COUNT(*) FROM (SELECT * FROM @ebp EXCEPT SELECT * FROM #bp) AS b) + ABS((SELECT COUNT(*) FROM #bp) - 2);
SET @txt = (SELECT STRING_AGG(CONVERT(nvarchar(400), CONCAT(CONVERT(varchar(10), PeriodStart, 23), N'=', Revenue, N'/', InvoiceCount)), N'; ') WITHIN GROUP (ORDER BY PeriodStart) FROM #bp);
INSERT @results VALUES ('F08d', 'T-F06-01', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Branch 1 per local year: 2025 = 1000 + 100000 = 101000.00 (R01 paid 23:59:59.999 local on 31 December 2025); 2026 = 1271000.00 (R02 paid 00:00:00.000 local on 1 January 2026)',
    CONCAT(N'rows: ', ISNULL(@txt, N'none'), N'; differences ', @n));

/* ---------- F09 T-F06-02: system revenue per period and branch ---------- */
DELETE #sp; DELETE @esp;
INSERT #sp EXEC dbo.usp_P3_RptSystemRevenueByPeriod @FromDate = '2025-01-01', @ToDate = '2026-05-01', @Grain = 'MONTH';
INSERT @esp VALUES ('2025-06-01', 1, 1000.00, 1, 1000.00, 1), ('2025-12-01', 1, 100000.00, 1, 100000.00, 1),
                   ('2026-01-01', 1, 371000.00, 5, 745999.50, 6), ('2026-01-01', 2, 374999.50, 1, 745999.50, 6),
                   ('2026-02-01', 1, 900000.00, 1, 960000.00, 3), ('2026-02-01', 3, 60000.00, 2, 960000.00, 3),
                   ('2026-03-01', 2, 10000.00, 1, 10000.00, 1), ('2026-04-01', 2, 20000.00, 1, 20000.00, 1);
SET @n = (SELECT COUNT(*) FROM (SELECT * FROM #sp EXCEPT SELECT * FROM @esp) AS a) + (SELECT COUNT(*) FROM (SELECT * FROM @esp EXCEPT SELECT * FROM #sp) AS b) + ABS((SELECT COUNT(*) FROM #sp) - 8);
SET @txt = (SELECT STRING_AGG(CONVERT(nvarchar(400), CONCAT(CONVERT(varchar(7), PeriodStart, 23), N' b', Branch_ID, N'=', Revenue, N'/', InvoiceCount, N' of ', PeriodSystemRevenue)), N'; ') WITHIN GROUP (ORDER BY PeriodStart, Branch_ID) FROM #sp);
DELETE #sp; DELETE @esp;
INSERT #sp EXEC dbo.usp_P3_RptSystemRevenueByPeriod @FromDate = '2025-01-01', @ToDate = '2026-05-01', @Grain = 'YEAR';
INSERT @esp VALUES ('2025-01-01', 1, 101000.00, 2, 101000.00, 2), ('2026-01-01', 1, 1271000.00, 6, 1735999.50, 11),
                   ('2026-01-01', 2, 404999.50, 3, 1735999.50, 11), ('2026-01-01', 3, 60000.00, 2, 1735999.50, 11);
SET @n2 = (SELECT COUNT(*) FROM (SELECT * FROM #sp EXCEPT SELECT * FROM @esp) AS a) + (SELECT COUNT(*) FROM (SELECT * FROM @esp EXCEPT SELECT * FROM #sp) AS b) + ABS((SELECT COUNT(*) FROM #sp) - 4);
INSERT @results VALUES ('F09', 'T-F06-02', CASE WHEN @n = 0 AND @n2 = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'System revenue per local month and branch (8 rows, period totals 1000.00, 100000.00, 745999.50, 960000.00, 10000.00, 20000.00) and per local year (2025: 101000.00; 2026: branches 1271000.00 + 404999.50 + 60000.00 = 1735999.50)',
    CONCAT(N'month rows: ', ISNULL(@txt, N'none'), N'; differences month ', @n, N', year ', @n2));

/* ---------- F10 T-F06-05: empty reporting periods ---------- */
DELETE #tot; DELETE #sys; DELETE #byb; DELETE #bp; DELETE #sp;
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 1, @FromDate = '2025-07-01', @ToDate = '2025-08-01', @Revenue = @rev OUTPUT, @InvoiceCount = @cnt OUTPUT;
INSERT #sys EXEC dbo.usp_P3_RptSystemRevenue @FromDate = '2025-07-01', @ToDate = '2025-08-01', @Revenue = @rev2 OUTPUT, @InvoiceCount = @cnt2 OUTPUT;
INSERT #sys EXEC dbo.usp_P3_RptSystemRevenue @FromDate = '2030-01-01', @ToDate = '2031-01-01', @Revenue = @rev3 OUTPUT, @InvoiceCount = @cnt3 OUTPUT;
INSERT #byb EXEC dbo.usp_P3_RptSystemRevenueByBranch @FromDate = '2025-07-01', @ToDate = '2025-08-01';
INSERT #bp EXEC dbo.usp_P3_RptBranchRevenueByPeriod @Branch_ID = 1, @FromDate = '2025-07-01', @ToDate = '2025-08-01', @Grain = 'DAY';
INSERT #sp EXEC dbo.usp_P3_RptSystemRevenueByPeriod @FromDate = '2025-07-01', @ToDate = '2025-08-01', @Grain = 'MONTH';
INSERT @results VALUES ('F10', 'T-F06-05', CASE WHEN @rev = 0 AND @cnt = 0 AND @rev2 = 0 AND @cnt2 = 0 AND @rev3 = 0 AND @cnt3 = 0 AND (SELECT COUNT(*) FROM #tot) = 1 AND (SELECT COUNT(*) FROM #sys WHERE Revenue = 0 AND InvoiceCount = 0) = 2
                                              AND (SELECT COUNT(*) FROM #byb) = 0 AND (SELECT COUNT(*) FROM #bp) = 0 AND (SELECT COUNT(*) FROM #sp) = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Empty periods (July 2025; year 2030): the branch total and the system total return one row with 0.00 and 0 invoices; the grouped reports return no row (07 section 2 default)',
    CONCAT(N'branch total ', @rev, N'/', @cnt, N'; system total July 2025 ', @rev2, N'/', @cnt2, N', 2030 ', @rev3, N'/', @cnt3, N'; rows: by branch ', (SELECT COUNT(*) FROM #byb), N', branch by day ', (SELECT COUNT(*) FROM #bp), N', system by month ', (SELECT COUNT(*) FROM #sp)));

/* ---------- F11 T-F06-13: detail = aggregate; independent invoice-level reference ---------- */
CREATE TABLE #o (Invoice_ID int NOT NULL PRIMARY KEY, Branch_ID int NOT NULL, LocalDate date NOT NULL, FinalAmount decimal(18,2) NOT NULL);
INSERT #o SELECT i.Invoice_ID, i.Branch_ID, CONVERT(date, (i.PaidAt AT TIME ZONE 'UTC') AT TIME ZONE 'SE Asia Standard Time'), i.FinalAmount FROM dbo.INVOICE AS i WHERE i.PaymentStatus = 'PAID';
CREATE TABLE #roll (Branch_ID int, Grain varchar(7), Revenue decimal(38,2), InvoiceCount bigint);
CREATE TABLE #mon (Branch_ID int, PeriodStart date, Revenue decimal(38,2), InvoiceCount bigint);
DECLARE @b int = 1, @g varchar(7);
WHILE @b <= 3
BEGIN
    DELETE #tot;
    INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = @b, @FromDate = '2025-01-01', @ToDate = '2026-05-01';
    INSERT #roll SELECT @b, 'TOTAL', Revenue, InvoiceCount FROM #tot;
    DECLARE gc CURSOR LOCAL FAST_FORWARD FOR SELECT v FROM (VALUES ('DAY'), ('MONTH'), ('QUARTER'), ('YEAR')) AS x(v);
    OPEN gc; FETCH NEXT FROM gc INTO @g;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DELETE #bp;
        INSERT #bp EXEC dbo.usp_P3_RptBranchRevenueByPeriod @Branch_ID = @b, @FromDate = '2025-01-01', @ToDate = '2026-05-01', @Grain = @g;
        INSERT #roll SELECT @b, @g, ISNULL(SUM(Revenue), 0), ISNULL(SUM(InvoiceCount), 0) FROM #bp;
        IF @g = 'MONTH' INSERT #mon SELECT @b, PeriodStart, Revenue, InvoiceCount FROM #bp;
        FETCH NEXT FROM gc INTO @g;
    END;
    CLOSE gc; DEALLOCATE gc;
    SET @b += 1;
END;
-- every grain of a branch gives the same total and count as the branch total
SET @n = (SELECT COUNT(*) FROM #roll AS r JOIN #roll AS t ON t.Branch_ID = r.Branch_ID AND t.Grain = 'TOTAL' WHERE r.Revenue <> t.Revenue OR r.InvoiceCount <> t.InvoiceCount);
-- branch totals equal the independent reference; their sum equals the system total
SET @n2 = (SELECT COUNT(*) FROM #roll AS t FULL OUTER JOIN (SELECT Branch_ID, SUM(FinalAmount) AS total, COUNT_BIG(*) AS n FROM #o GROUP BY Branch_ID) AS o ON o.Branch_ID = t.Branch_ID
           WHERE t.Grain = 'TOTAL' AND (o.Branch_ID IS NULL OR t.Revenue <> o.total OR t.InvoiceCount <> o.n));
DELETE #sys;
INSERT #sys EXEC dbo.usp_P3_RptSystemRevenue @FromDate = '2025-01-01', @ToDate = '2026-05-01', @Revenue = @rev OUTPUT, @InvoiceCount = @cnt OUTPUT;
SELECT @d1 = SUM(Revenue), @c1 = SUM(InvoiceCount) FROM #roll WHERE Grain = 'TOTAL';
DELETE #sp;
INSERT #sp EXEC dbo.usp_P3_RptSystemRevenueByPeriod @FromDate = '2025-01-01', @ToDate = '2026-05-01', @Grain = 'MONTH';
SELECT @d2 = SUM(Revenue), @c2 = SUM(InvoiceCount) FROM #sp;
-- monthly rows per branch = reference grouped by the AT TIME ZONE local month (set equality), and = the system-by-period rows
DECLARE @nm int = (SELECT COUNT(*) FROM (SELECT Branch_ID, PeriodStart, Revenue, InvoiceCount FROM #mon
                                         EXCEPT SELECT Branch_ID, DATEFROMPARTS(YEAR(LocalDate), MONTH(LocalDate), 1), SUM(FinalAmount), COUNT_BIG(*) FROM #o GROUP BY Branch_ID, DATEFROMPARTS(YEAR(LocalDate), MONTH(LocalDate), 1)) AS a)
              + (SELECT COUNT(*) FROM (SELECT Branch_ID, DATEFROMPARTS(YEAR(LocalDate), MONTH(LocalDate), 1) AS m, SUM(FinalAmount) AS r, COUNT_BIG(*) AS n FROM #o GROUP BY Branch_ID, DATEFROMPARTS(YEAR(LocalDate), MONTH(LocalDate), 1)
                                         EXCEPT SELECT Branch_ID, PeriodStart, Revenue, InvoiceCount FROM #mon) AS b)
              + (SELECT COUNT(*) FROM (SELECT Branch_ID, PeriodStart, Revenue, InvoiceCount FROM #mon EXCEPT SELECT Branch_ID, PeriodStart, Revenue, InvoiceCount FROM #sp) AS c)
              + (SELECT COUNT(*) FROM (SELECT Branch_ID, PeriodStart, Revenue, InvoiceCount FROM #sp EXCEPT SELECT Branch_ID, PeriodStart, Revenue, InvoiceCount FROM #mon) AS d);
SELECT @d3 = SUM(FinalAmount), @c3 = COUNT_BIG(*) FROM #o;
INSERT @results VALUES ('F11', 'T-F06-13', CASE WHEN @n = 0 AND @n2 = 0 AND @nm = 0 AND @rev = 1836999.50 AND @cnt = 13 AND @d1 = @rev AND @c1 = @cnt AND @d2 = @rev AND @c2 = @cnt AND @d3 = @rev AND @c3 = @cnt
                                              AND (SELECT COUNT(*) FROM #roll) = 15 THEN 'PASS' ELSE 'FAIL' END,
    N'January 2025 to April 2026, every branch: sum of day rows = sum of month rows = sum of quarter rows = sum of year rows = branch total; sum of branch totals = system total = sum of the per-period-and-branch rows = independent invoice-level reference (AT TIME ZONE); monthly rows equal the reference row by row',
    CONCAT(N'grain totals differing from the branch total ', @n, N'; branch totals differing from the reference ', @n2, N'; monthly row differences ', @nm, N'; system ', @rev, N'/', @cnt, N'; sum of branches ', @d1, N'/', @c1,
           N'; sum of period rows ', @d2, N'/', @c2, N'; reference ', @d3, N'/', @c3,
           N'; per branch: ', (SELECT STRING_AGG(CONVERT(nvarchar(200), CONCAT(Branch_ID, N'=', Revenue, N'/', InvoiceCount)), N', ') WITHIN GROUP (ORDER BY Branch_ID) FROM #roll WHERE Grain = 'TOTAL')));

/* ---------- F12 T-F06-12: invalid parameters ---------- */
SET @errs = '';
SET @err = 0; BEGIN TRY EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = NULL, @FromDate = '2026-01-01', @ToDate = '2026-02-01'; END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH; SET @errs = CONCAT(@errs, @err, ',');
SET @err = 0; BEGIN TRY EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 1, @FromDate = NULL, @ToDate = '2026-02-01'; END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH; SET @errs = CONCAT(@errs, @err, ',');
SET @err = 0; BEGIN TRY EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 1, @FromDate = '2026-02-01', @ToDate = '2026-02-01'; END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH; SET @errs = CONCAT(@errs, @err, ',');
SET @err = 0; BEGIN TRY EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 1, @FromDate = '2026-03-01', @ToDate = '2026-02-01'; END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH; SET @errs = CONCAT(@errs, @err, ',');
SET @err = 0; BEGIN TRY EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 999, @FromDate = '2026-01-01', @ToDate = '2026-02-01'; END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH; SET @errs = CONCAT(@errs, @err, ',');
SET @err = 0; BEGIN TRY EXEC dbo.usp_P3_RptSystemRevenue @FromDate = '2026-01-01', @ToDate = NULL; END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH; SET @errs = CONCAT(@errs, @err, ',');
SET @err = 0; BEGIN TRY EXEC dbo.usp_P3_RptSystemRevenue @FromDate = '2026-02-01', @ToDate = '2026-01-01'; END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH; SET @errs = CONCAT(@errs, @err, ',');
SET @err = 0; BEGIN TRY EXEC dbo.usp_P3_RptSystemRevenueByBranch @FromDate = NULL, @ToDate = '2026-02-01'; END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH; SET @errs = CONCAT(@errs, @err, ',');
SET @err = 0; BEGIN TRY EXEC dbo.usp_P3_RptSystemRevenueByBranch @FromDate = '2026-02-01', @ToDate = '2026-02-01'; END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH; SET @errs = CONCAT(@errs, @err, ',');
SET @err = 0; BEGIN TRY EXEC dbo.usp_P3_RptBranchRevenueByPeriod @Branch_ID = 1, @FromDate = '2026-01-01', @ToDate = '2026-02-01', @Grain = NULL; END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH; SET @errs = CONCAT(@errs, @err, ',');
SET @err = 0; BEGIN TRY EXEC dbo.usp_P3_RptBranchRevenueByPeriod @Branch_ID = 1, @FromDate = '2026-02-01', @ToDate = '2026-01-01', @Grain = 'DAY'; END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH; SET @errs = CONCAT(@errs, @err, ',');
SET @err = 0; BEGIN TRY EXEC dbo.usp_P3_RptBranchRevenueByPeriod @Branch_ID = 1, @FromDate = '2026-01-01', @ToDate = '2026-02-01', @Grain = 'WEEK'; END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH; SET @errs = CONCAT(@errs, @err, ',');
SET @err = 0; BEGIN TRY EXEC dbo.usp_P3_RptBranchRevenueByPeriod @Branch_ID = 999, @FromDate = '2026-01-01', @ToDate = '2026-02-01', @Grain = 'DAY'; END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH; SET @errs = CONCAT(@errs, @err, ',');
SET @err = 0; BEGIN TRY EXEC dbo.usp_P3_RptSystemRevenueByPeriod @FromDate = '2026-01-01', @ToDate = '2026-02-01', @Grain = NULL; END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH; SET @errs = CONCAT(@errs, @err, ',');
SET @err = 0; BEGIN TRY EXEC dbo.usp_P3_RptSystemRevenueByPeriod @FromDate = '2026-02-01', @ToDate = '2026-02-01', @Grain = 'MONTH'; END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH; SET @errs = CONCAT(@errs, @err, ',');
SET @err = 0; BEGIN TRY EXEC dbo.usp_P3_RptSystemRevenueByPeriod @FromDate = '2026-01-01', @ToDate = '2026-02-01', @Grain = 'HOUR'; END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH; SET @errs = CONCAT(@errs, @err, ',');
INSERT @results VALUES ('F12', 'T-F06-12', CASE WHEN @errs = '51401,51401,51402,51402,51403,51401,51402,51401,51402,51401,51402,51404,51403,51401,51402,51404,' AND @@TRANCOUNT = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Invalid parameters are rejected: NULL parameter 51401; FromDate equal to or after ToDate 51402; unknown branch 51403; grain other than DAY/MONTH/QUARTER/YEAR 51404 (16 calls on the 5 routines)',
    CONCAT(N'errors raised: ', @errs, N' open transactions ', @@TRANCOUNT));

/* ---------- F13 T-F06-11: real path through the UC05 routines (server time; current local month) ---------- */
DECLARE @today date = CONVERT(date, DATEADD(HOUR, 7, SYSUTCDATETIME()));
DECLARE @m0 date = DATEFROMPARTS(YEAR(@today), MONTH(@today), 1);
DECLARE @m1 date = DATEADD(MONTH, 1, @m0), @tomorrow date = DATEADD(DAY, 1, @today);
DECLARE @svc dbo.tt_P3_InvoiceServiceLine, @prd dbo.tt_P3_InvoiceProductLine, @invA int, @invB int, @invC int, @co varchar(20), @o1 varchar(20), @o2 varchar(20), @oc varchar(20), @paidAt datetime2(3);
DECLARE @r0 decimal(38,2), @k0 bigint, @rP decimal(38,2), @kP bigint, @rS decimal(38,2), @kS bigint, @rS2 decimal(38,2), @kS2 bigint, @rE decimal(38,2), @kE bigint, @rSys decimal(38,2), @kSys bigint;
DELETE #tot;
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 3, @FromDate = @m0, @ToDate = @m1, @Revenue = @r0 OUTPUT, @InvoiceCount = @k0 OUTPUT;
INSERT @svc VALUES (1, 2, 300000.00, 30000.00);
INSERT @prd VALUES (1, 5, 2, 45000.25, 0.50);
EXEC dbo.usp_P3_CreateInvoice @Member_ID = 37, @Employee_ID = 1, @Branch_ID = 3, @ServiceLines = @svc, @ProductLines = @prd, @Invoice_ID = @invA OUTPUT, @Outcome = @co OUTPUT;
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 3, @FromDate = @m0, @ToDate = @m1, @Revenue = @rP OUTPUT, @InvoiceCount = @kP OUTPUT;     -- still PENDING
EXEC dbo.usp_P3_SettleInvoice @Invoice_ID = @invA, @PaymentMethod = 'CARD', @Outcome = @o1 OUTPUT, @PaidAt = @paidAt OUTPUT;
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 3, @FromDate = @m0, @ToDate = @m1, @Revenue = @rS OUTPUT, @InvoiceCount = @kS OUTPUT;     -- PAID
EXEC dbo.usp_P3_SettleInvoice @Invoice_ID = @invA, @PaymentMethod = 'CARD', @Outcome = @o2 OUTPUT;
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 3, @FromDate = @m0, @ToDate = @m1, @Revenue = @rS2 OUTPUT, @InvoiceCount = @kS2 OUTPUT;   -- repeated confirmation
DELETE @svc; DELETE @prd; INSERT @prd VALUES (1, 6, 1, 500000.00, 0);
EXEC dbo.usp_P3_CreateInvoice @Member_ID = 38, @Employee_ID = 1, @Branch_ID = 3, @ServiceLines = @svc, @ProductLines = @prd, @Invoice_ID = @invB OUTPUT, @Outcome = @co OUTPUT;
EXEC dbo.usp_P3_CancelInvoice @Invoice_ID = @invB, @Outcome = @oc OUTPUT;
DELETE @prd; INSERT @prd VALUES (1, 7, 1, 70000.00, 0);
EXEC dbo.usp_P3_CreateInvoice @Member_ID = 39, @Employee_ID = 1, @Branch_ID = 3, @ServiceLines = @svc, @ProductLines = @prd, @Invoice_ID = @invC OUTPUT, @Outcome = @co OUTPUT;
INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = 3, @FromDate = @m0, @ToDate = @m1, @Revenue = @rE OUTPUT, @InvoiceCount = @kE OUTPUT;     -- after a cancelled and a pending invoice
DELETE #sys;
INSERT #sys EXEC dbo.usp_P3_RptSystemRevenue @FromDate = @m0, @ToDate = @m1, @Revenue = @rSys OUTPUT, @InvoiceCount = @kSys OUTPUT;
DELETE #bp;
INSERT #bp EXEC dbo.usp_P3_RptBranchRevenueByPeriod @Branch_ID = 3, @FromDate = @today, @ToDate = @tomorrow, @Grain = 'DAY';
DECLARE @finalA decimal(18,2) = (SELECT FinalAmount FROM dbo.INVOICE WHERE Invoice_ID = @invA), @discA decimal(18,2) = (SELECT DiscountAmount FROM dbo.INVOICE WHERE Invoice_ID = @invA);
DECLARE @stB varchar(10) = (SELECT PaymentStatus FROM dbo.INVOICE WHERE Invoice_ID = @invB), @stC varchar(10) = (SELECT PaymentStatus FROM dbo.INVOICE WHERE Invoice_ID = @invC);
INSERT @results VALUES ('F13', 'T-F06-11', CASE WHEN @r0 = 0 AND @k0 = 0 AND @rP = 0 AND @kP = 0 AND @o1 = 'SETTLED' AND @finalA = 360000.00 AND @discA = 30000.50 AND @rS = 360000.00 AND @kS = 1
                                              AND @o2 = 'ALREADY_SETTLED' AND @rS2 = 360000.00 AND @kS2 = 1 AND @oc = 'CANCELLED' AND @stB = 'CANCELLED' AND @stC = 'PENDING' AND @rE = 360000.00 AND @kE = 1
                                              AND @rSys = 360000.00 AND @kSys = 1 AND (SELECT COUNT(*) FROM #bp) = 1 AND (SELECT COUNT(*) FROM #bp WHERE PeriodStart = @today AND Revenue = 360000.00 AND InvoiceCount = 1) = 1
                                              AND CONVERT(date, DATEADD(HOUR, 7, @paidAt)) = @today THEN 'PASS' ELSE 'FAIL' END,
    N'Invoice created by usp_P3_CreateInvoice (service 300000 - 30000; product 2 x 45000.25 - 0.50 = final 360000.00): 0 while PENDING; +360000.00 and +1 invoice after usp_P3_SettleInvoice; unchanged after a repeated settlement (ALREADY_SETTLED), a cancelled invoice (500000) and a pending invoice (70000); today''s day row and the system month total show the same 360000.00',
    CONCAT(N'local today ', CONVERT(varchar(10), @today, 23), N'; branch 3 this month: before ', @r0, N'/', @k0, N'; pending ', @rP, N'/', @kP, N'; settled (', @o1, N') ', @rS, N'/', @kS, N'; settled again (', @o2, N') ', @rS2, N'/', @kS2,
           N'; after cancel (', @oc, N') and pending ', @rE, N'/', @kE, N'; system month ', @rSys, N'/', @kSys, N'; header discount ', @discA, N', final ', @finalA,
           N'; day rows ', (SELECT COUNT(*) FROM #bp)));

SELECT case_id, test_id, result, descr, detail FROM @results ORDER BY seq;
DECLARE @fails int = (SELECT COUNT(*) FROM @results WHERE result <> 'PASS'), @cases int = (SELECT COUNT(*) FROM @results);
PRINT CONCAT('T-F06 SUMMARY: cases=', @cases, ' FAIL=', @fails);
IF @fails > 0 OR @cases <> 16
BEGIN
    PRINT 'T-F06_RESULT: FAIL';
    THROW 51425, N'T-F06 failed (see the result table).', 1;
END
ELSE
    PRINT 'T-F06_RESULT: PASS';
