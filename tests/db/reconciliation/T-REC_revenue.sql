/* =====================================================================
   T-REC_revenue.sql - TEST_ONLY (sqlcmd mode). Reads the tables; writes only temporary tables.
   Work order : WO-P3-P4-01 Part F. Test T-REC-05: every revenue report routine equals an INDEPENDENT
   reference for every branch and every local month of the data (plus one empty month before and after).
   Runs in FitLife_P3_UC05 (fixtures) or FitLife_P3_UC05L (DS-L copy) with no concurrent activity.
   Reference  : one row per PAID invoice with its local payment date computed per row with
                (PaidAt AT TIME ZONE 'UTC') AT TIME ZONE 'SE Asia Standard Time' - the Windows time-zone
                rule, not the routines' UTC-bound arithmetic. Quarter buckets use DATEADD/DATEDIFF, not the
                routines' expression. Nothing in the reference calls a routine under test.
     V1  branch total (usp_P3_RptBranchRevenue) for every branch x month = reference (0.00 / 0 when none)
     V2  system total (usp_P3_RptSystemRevenue) per month = reference = sum of the V1 branch values
     V3  system by branch (usp_P3_RptSystemRevenueByBranch) per month: rows = reference rows (no row for a
         branch without a paid sale); SystemRevenue and SystemInvoiceCount = reference; SharePct =
         ROUND(revenue * 100 / total, 2); shares of a month sum to 100 within 0.01 per branch
     V4  branch by period (usp_P3_RptBranchRevenueByPeriod), grains DAY, MONTH, QUARTER, YEAR over the whole
         range, every branch: rows = reference rows
     V5  system by period (usp_P3_RptSystemRevenueByPeriod), the four grains: rows and period totals = reference
     V6  roll-up: per branch, day rows = month rows = quarter rows = year rows = sum of the monthly totals;
         all branches = system total over the whole range = SUM(FinalAmount) of PAID invoices read directly;
         invoice count = number of PAID invoices (each exactly once)
     V7  unpaid invoices: no PENDING or CANCELLED invoice has a PaidAt; all invoices - report = non-PAID
     V8  line level: per branch x month, the sum of line amounts net of line discounts of the PAID invoices
         (lines aggregated per invoice first) = the report; headers = lines (discount counted once, no
         double counting through the line tables)
     V9  a period not aligned to months (10th of the first month to the 20th of the last month):
         branch totals and the system total = reference
     V10 (only with SpendingCheck=1) cross-check with UC05: SUM(MEMBER_MONTHLY_SPENDING.TotalSpend) per
         SpendingMonth = system revenue of that local month
     V11 INFO: PAID invoices whose UTC calendar date or month differs from the local one, and the months in
         which a UTC-calendar report would differ from the local report
   Run: sqlcmd -S localhost -E -I -b -W -d <db> -v SpendingCheck=1 -i tests/db/reconciliation/T-REC_revenue.sql
   ===================================================================== */
:on error exit
SET NOCOUNT ON;
SET ANSI_WARNINGS ON;

IF DB_NAME() NOT IN (N'FitLife_P3_UC05', N'FitLife_P3_UC05L')
    THROW 51430, N'T-REC_revenue runs only in FitLife_P3_UC05 or FitLife_P3_UC05L.', 1;
IF OBJECT_ID(N'dbo.usp_P3_RptBranchRevenue', N'P') IS NULL OR OBJECT_ID(N'dbo.usp_P3_RptSystemRevenue', N'P') IS NULL OR OBJECT_ID(N'dbo.usp_P3_RptSystemRevenueByBranch', N'P') IS NULL
   OR OBJECT_ID(N'dbo.usp_P3_RptBranchRevenueByPeriod', N'P') IS NULL OR OBJECT_ID(N'dbo.usp_P3_RptSystemRevenueByPeriod', N'P') IS NULL
    THROW 51431, N'T-REC_revenue: revenue report routines not deployed.', 1;

DECLARE @checks TABLE (seq int IDENTITY(1,1), check_id varchar(10), result varchar(4), descr nvarchar(700), detail nvarchar(2000));
DECLARE @spendingCheck int = $(SpendingCheck);
DECLARE @n int, @n2 int, @n3 int, @n4 int, @d1 decimal(38,2), @d2 decimal(38,2), @d3 decimal(38,2), @d4 decimal(38,2), @c1 bigint, @c2 bigint, @c3 bigint, @c4 bigint;
DECLARE @b int, @m date, @m2 date, @g varchar(7), @rev decimal(38,2), @cnt bigint;

/* ---------- independent reference ---------- */
CREATE TABLE #o (Invoice_ID int NOT NULL PRIMARY KEY, Branch_ID int NOT NULL, LocalDate date NOT NULL, LocalMonth date NOT NULL, FinalAmount decimal(18,2) NOT NULL);
INSERT #o (Invoice_ID, Branch_ID, LocalDate, LocalMonth, FinalAmount)
SELECT i.Invoice_ID, i.Branch_ID, l.d, DATEFROMPARTS(YEAR(l.d), MONTH(l.d), 1), i.FinalAmount
FROM dbo.INVOICE AS i
CROSS APPLY (SELECT CONVERT(date, (i.PaidAt AT TIME ZONE 'UTC') AT TIME ZONE 'SE Asia Standard Time') AS d) AS l
WHERE i.PaymentStatus = 'PAID';
IF NOT EXISTS (SELECT 1 FROM #o) THROW 51432, N'T-REC_revenue needs at least one PAID invoice.', 1;

DECLARE @minM date = (SELECT MIN(LocalMonth) FROM #o), @maxM date = (SELECT MAX(LocalMonth) FROM #o);
DECLARE @from date = DATEADD(MONTH, -1, @minM), @to date = DATEADD(MONTH, 2, @maxM);     -- one empty month before and after
CREATE TABLE #months (M date NOT NULL PRIMARY KEY);
SET @m = @from;
WHILE @m < @to BEGIN INSERT #months VALUES (@m); SET @m = DATEADD(MONTH, 1, @m); END;
CREATE TABLE #br (Branch_ID int NOT NULL PRIMARY KEY);
INSERT #br SELECT Branch_ID FROM dbo.BRANCH;

CREATE TABLE #tot (Branch_ID int, FromDate date, ToDate date, Revenue decimal(38,2), InvoiceCount bigint);
CREATE TABLE #sys (FromDate date, ToDate date, Revenue decimal(38,2), InvoiceCount bigint);
CREATE TABLE #byb (Branch_ID int, Revenue decimal(38,2), InvoiceCount bigint, SystemRevenue decimal(38,2), SystemInvoiceCount bigint, SharePct decimal(7,2));
CREATE TABLE #bp  (PeriodStart date, Revenue decimal(38,2), InvoiceCount bigint);
CREATE TABLE #sp  (PeriodStart date, Branch_ID int, Revenue decimal(38,2), InvoiceCount bigint, PeriodSystemRevenue decimal(38,2), PeriodSystemInvoiceCount bigint);
CREATE TABLE #r1 (Branch_ID int NOT NULL, M date NOT NULL, Revenue decimal(38,2) NULL, InvoiceCount bigint NULL, PRIMARY KEY (Branch_ID, M));
CREATE TABLE #r2 (M date NOT NULL PRIMARY KEY, Revenue decimal(38,2) NULL, InvoiceCount bigint NULL);
CREATE TABLE #r3 (M date NOT NULL, Branch_ID int NOT NULL, Revenue decimal(38,2), InvoiceCount bigint, SystemRevenue decimal(38,2), SystemInvoiceCount bigint, SharePct decimal(7,2));
CREATE TABLE #r4 (Branch_ID int NOT NULL, Grain varchar(7) NOT NULL, PeriodStart date, Revenue decimal(38,2), InvoiceCount bigint);
CREATE TABLE #r5 (Grain varchar(7) NOT NULL, PeriodStart date, Branch_ID int, Revenue decimal(38,2), InvoiceCount bigint, PeriodSystemRevenue decimal(38,2), PeriodSystemInvoiceCount bigint);
/* reference buckets per grain (quarter start computed differently from the routines) */
CREATE TABLE #ob (Grain varchar(7) NOT NULL, PeriodStart date NOT NULL, Branch_ID int NOT NULL, Revenue decimal(38,2) NOT NULL, InvoiceCount bigint NOT NULL, PRIMARY KEY (Grain, PeriodStart, Branch_ID));
INSERT #ob SELECT 'DAY', LocalDate, Branch_ID, SUM(FinalAmount), COUNT_BIG(*) FROM #o GROUP BY LocalDate, Branch_ID;
INSERT #ob SELECT 'MONTH', LocalMonth, Branch_ID, SUM(FinalAmount), COUNT_BIG(*) FROM #o GROUP BY LocalMonth, Branch_ID;
INSERT #ob SELECT 'QUARTER', q.s, o.Branch_ID, SUM(o.FinalAmount), COUNT_BIG(*) FROM #o AS o CROSS APPLY (SELECT CONVERT(date, DATEADD(QUARTER, DATEDIFF(QUARTER, 0, o.LocalDate), 0)) AS s) AS q GROUP BY q.s, o.Branch_ID;
INSERT #ob SELECT 'YEAR', DATEFROMPARTS(YEAR(LocalDate), 1, 1), Branch_ID, SUM(FinalAmount), COUNT_BIG(*) FROM #o GROUP BY DATEFROMPARTS(YEAR(LocalDate), 1, 1), Branch_ID;

/* ---------- V1: branch total for every branch x month ---------- */
DECLARE c1 CURSOR LOCAL FAST_FORWARD FOR SELECT b.Branch_ID, mo.M FROM #br AS b CROSS JOIN #months AS mo ORDER BY b.Branch_ID, mo.M;
OPEN c1; FETCH NEXT FROM c1 INTO @b, @m;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @m2 = DATEADD(MONTH, 1, @m);
    DELETE #tot;
    INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = @b, @FromDate = @m, @ToDate = @m2, @Revenue = @rev OUTPUT, @InvoiceCount = @cnt OUTPUT;
    INSERT #r1 SELECT @b, @m, Revenue, InvoiceCount FROM #tot WHERE Revenue = @rev AND InvoiceCount = @cnt AND Branch_ID = @b AND FromDate = @m AND ToDate = @m2;
    FETCH NEXT FROM c1 INTO @b, @m;
END;
CLOSE c1; DEALLOCATE c1;
SELECT @n = (SELECT COUNT(*) FROM #br) * (SELECT COUNT(*) FROM #months), @n2 = (SELECT COUNT(*) FROM #r1);
SELECT @n3 = COUNT(*) FROM #br AS b CROSS JOIN #months AS mo
LEFT JOIN #r1 AS r ON r.Branch_ID = b.Branch_ID AND r.M = mo.M
LEFT JOIN #ob AS o ON o.Grain = 'MONTH' AND o.Branch_ID = b.Branch_ID AND o.PeriodStart = mo.M
WHERE r.Branch_ID IS NULL OR r.Revenue IS NULL OR r.Revenue <> ISNULL(o.Revenue, 0) OR r.InvoiceCount <> ISNULL(o.InvoiceCount, 0);
SELECT @c1 = COUNT(*) FROM #r1 WHERE InvoiceCount = 0;
INSERT @checks VALUES ('V1', CASE WHEN @n3 = 0 AND @n = @n2 THEN 'PASS' ELSE 'FAIL' END,
    N'Branch revenue of every branch x local month (one row and OUTPUT values per call) = independent reference; 0.00 / 0 where the branch has no paid invoice',
    CONCAT(N'branches ', (SELECT COUNT(*) FROM #br), N' x months ', (SELECT COUNT(*) FROM #months), N' (', CONVERT(varchar(7), @from, 23), N' .. ', CONVERT(varchar(7), DATEADD(MONTH, -1, @to), 23), N') = ', @n,
           N' calls; results ', @n2, N'; mismatches ', @n3, N'; branch-months with zero invoices ', @c1));

/* ---------- V2: system total per month ---------- */
DECLARE c2 CURSOR LOCAL FAST_FORWARD FOR SELECT M FROM #months ORDER BY M;
OPEN c2; FETCH NEXT FROM c2 INTO @m;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @m2 = DATEADD(MONTH, 1, @m);
    DELETE #sys;
    INSERT #sys EXEC dbo.usp_P3_RptSystemRevenue @FromDate = @m, @ToDate = @m2, @Revenue = @rev OUTPUT, @InvoiceCount = @cnt OUTPUT;
    INSERT #r2 SELECT @m, Revenue, InvoiceCount FROM #sys WHERE Revenue = @rev AND InvoiceCount = @cnt;
    DELETE #byb;
    INSERT #byb EXEC dbo.usp_P3_RptSystemRevenueByBranch @FromDate = @m, @ToDate = @m2;
    INSERT #r3 SELECT @m, Branch_ID, Revenue, InvoiceCount, SystemRevenue, SystemInvoiceCount, SharePct FROM #byb;
    FETCH NEXT FROM c2 INTO @m;
END;
CLOSE c2; DEALLOCATE c2;
SELECT @n = COUNT(*) FROM #months AS mo
LEFT JOIN #r2 AS r ON r.M = mo.M
OUTER APPLY (SELECT ISNULL(SUM(o.Revenue), 0) AS rev, ISNULL(SUM(o.InvoiceCount), 0) AS cnt FROM #ob AS o WHERE o.Grain = 'MONTH' AND o.PeriodStart = mo.M) AS o
OUTER APPLY (SELECT SUM(x.Revenue) AS rev, SUM(x.InvoiceCount) AS cnt FROM #r1 AS x WHERE x.M = mo.M) AS s
WHERE r.M IS NULL OR r.Revenue <> o.rev OR r.InvoiceCount <> o.cnt OR r.Revenue <> s.rev OR r.InvoiceCount <> s.cnt OR s.rev IS NULL;
INSERT @checks VALUES ('V2', CASE WHEN @n = 0 AND (SELECT COUNT(*) FROM #r2) = (SELECT COUNT(*) FROM #months) THEN 'PASS' ELSE 'FAIL' END,
    N'Company-wide revenue of every local month = independent reference = sum of the branch reports of the same month (D-010 rule 9)',
    CONCAT(N'months ', (SELECT COUNT(*) FROM #months), N'; mismatching months ', @n, N'; months with zero revenue ', (SELECT COUNT(*) FROM #r2 WHERE InvoiceCount = 0)));

/* ---------- V3: system by branch per month ---------- */
SELECT @n = (SELECT COUNT(*) FROM (SELECT M, Branch_ID, Revenue, InvoiceCount FROM #r3 EXCEPT SELECT PeriodStart, Branch_ID, Revenue, InvoiceCount FROM #ob WHERE Grain = 'MONTH') AS a)
          + (SELECT COUNT(*) FROM (SELECT PeriodStart, Branch_ID, Revenue, InvoiceCount FROM #ob WHERE Grain = 'MONTH' EXCEPT SELECT M, Branch_ID, Revenue, InvoiceCount FROM #r3) AS b)
          + ABS((SELECT COUNT(*) FROM #r3) - (SELECT COUNT(*) FROM #ob WHERE Grain = 'MONTH'));
SELECT @n2 = COUNT(*) FROM #r3 AS r
CROSS APPLY (SELECT SUM(o.Revenue) AS rev, SUM(o.InvoiceCount) AS cnt FROM #ob AS o WHERE o.Grain = 'MONTH' AND o.PeriodStart = r.M) AS t
WHERE r.SystemRevenue <> t.rev OR r.SystemInvoiceCount <> t.cnt
   OR (t.rev > 0 AND (r.SharePct IS NULL OR r.SharePct <> CONVERT(decimal(7,2), ROUND(r.Revenue * 100 / t.rev, 2))))
   OR (t.rev = 0 AND r.SharePct IS NOT NULL);
SELECT @n3 = COUNT(*), @d1 = MIN(s), @d2 = MAX(s) FROM (SELECT M, SUM(SharePct) AS s, COUNT(*) AS k FROM #r3 WHERE SystemRevenue > 0 GROUP BY M) AS x WHERE ABS(x.s - 100) > 0.01 * x.k;
SELECT @d1 = MIN(s), @d2 = MAX(s) FROM (SELECT M, SUM(SharePct) AS s FROM #r3 WHERE SystemRevenue > 0 GROUP BY M) AS x;
INSERT @checks VALUES ('V3', CASE WHEN @n = 0 AND @n2 = 0 AND @n3 = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Branch comparison of every local month: rows = reference rows (no row for a branch without a paid sale); system total and count on every row = reference; SharePct = ROUND(revenue * 100 / total, 2); shares sum to 100 within 0.01 per branch',
    CONCAT(N'rows ', (SELECT COUNT(*) FROM #r3), N' (reference ', (SELECT COUNT(*) FROM #ob WHERE Grain = 'MONTH'), N'); row differences ', @n, N'; rows with a wrong total or share ', @n2,
           N'; months whose shares miss 100 by more than the rounding bound ', @n3, N'; sum of shares per month between ', ISNULL(CONVERT(varchar(20), @d1), '-'), N' and ', ISNULL(CONVERT(varchar(20), @d2), '-')));

/* ---------- V4 / V5: per period, four grains, whole range ---------- */
DECLARE c4 CURSOR LOCAL FAST_FORWARD FOR SELECT v FROM (VALUES ('DAY'), ('MONTH'), ('QUARTER'), ('YEAR')) AS x(v);
OPEN c4; FETCH NEXT FROM c4 INTO @g;
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE c4b CURSOR LOCAL FAST_FORWARD FOR SELECT Branch_ID FROM #br ORDER BY Branch_ID;
    OPEN c4b; FETCH NEXT FROM c4b INTO @b;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DELETE #bp;
        INSERT #bp EXEC dbo.usp_P3_RptBranchRevenueByPeriod @Branch_ID = @b, @FromDate = @from, @ToDate = @to, @Grain = @g;
        INSERT #r4 SELECT @b, @g, PeriodStart, Revenue, InvoiceCount FROM #bp;
        FETCH NEXT FROM c4b INTO @b;
    END;
    CLOSE c4b; DEALLOCATE c4b;
    DELETE #sp;
    INSERT #sp EXEC dbo.usp_P3_RptSystemRevenueByPeriod @FromDate = @from, @ToDate = @to, @Grain = @g;
    INSERT #r5 SELECT @g, PeriodStart, Branch_ID, Revenue, InvoiceCount, PeriodSystemRevenue, PeriodSystemInvoiceCount FROM #sp;
    FETCH NEXT FROM c4 INTO @g;
END;
CLOSE c4; DEALLOCATE c4;
SELECT @n = (SELECT COUNT(*) FROM (SELECT Grain, PeriodStart, Branch_ID, Revenue, InvoiceCount FROM #r4 EXCEPT SELECT Grain, PeriodStart, Branch_ID, Revenue, InvoiceCount FROM #ob) AS a)
          + (SELECT COUNT(*) FROM (SELECT Grain, PeriodStart, Branch_ID, Revenue, InvoiceCount FROM #ob EXCEPT SELECT Grain, PeriodStart, Branch_ID, Revenue, InvoiceCount FROM #r4) AS b)
          + ABS((SELECT COUNT(*) FROM #r4) - (SELECT COUNT(*) FROM #ob));
INSERT @checks VALUES ('V4', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Branch revenue per local day, month, quarter and year over the whole range, every branch: rows = reference rows (buckets from AT TIME ZONE local dates)',
    CONCAT(N'rows ', (SELECT COUNT(*) FROM #r4), N' (reference ', (SELECT COUNT(*) FROM #ob), N'): ',
           (SELECT STRING_AGG(CONVERT(nvarchar(200), CONCAT(Grain, N' ', k)), N', ') FROM (SELECT Grain, COUNT(*) AS k FROM #r4 GROUP BY Grain) AS x), N'; differences ', @n));
SELECT @n = (SELECT COUNT(*) FROM (SELECT Grain, PeriodStart, Branch_ID, Revenue, InvoiceCount FROM #r5 EXCEPT SELECT Grain, PeriodStart, Branch_ID, Revenue, InvoiceCount FROM #ob) AS a)
          + (SELECT COUNT(*) FROM (SELECT Grain, PeriodStart, Branch_ID, Revenue, InvoiceCount FROM #ob EXCEPT SELECT Grain, PeriodStart, Branch_ID, Revenue, InvoiceCount FROM #r5) AS b)
          + ABS((SELECT COUNT(*) FROM #r5) - (SELECT COUNT(*) FROM #ob));
SELECT @n2 = COUNT(*) FROM #r5 AS r
CROSS APPLY (SELECT SUM(o.Revenue) AS rev, SUM(o.InvoiceCount) AS cnt FROM #ob AS o WHERE o.Grain = r.Grain AND o.PeriodStart = r.PeriodStart) AS t
WHERE r.PeriodSystemRevenue <> t.rev OR r.PeriodSystemInvoiceCount <> t.cnt;
INSERT @checks VALUES ('V5', CASE WHEN @n = 0 AND @n2 = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'System revenue per local period and branch, four grains over the whole range: rows = reference rows; the company-wide total of each period = reference',
    CONCAT(N'rows ', (SELECT COUNT(*) FROM #r5), N' (reference ', (SELECT COUNT(*) FROM #ob), N'); row differences ', @n, N'; rows with a wrong period total ', @n2));

/* ---------- V6: roll-up and exactly-once ---------- */
SELECT @n = COUNT(*) FROM #br AS b
OUTER APPLY (SELECT ISNULL(SUM(Revenue), 0) AS rev, ISNULL(SUM(InvoiceCount), 0) AS cnt FROM #r1 AS r WHERE r.Branch_ID = b.Branch_ID) AS t
CROSS JOIN (VALUES ('DAY'), ('MONTH'), ('QUARTER'), ('YEAR')) AS g(v)
OUTER APPLY (SELECT ISNULL(SUM(Revenue), 0) AS rev, ISNULL(SUM(InvoiceCount), 0) AS cnt FROM #r4 AS r WHERE r.Branch_ID = b.Branch_ID AND r.Grain = g.v) AS p
WHERE p.rev <> t.rev OR p.cnt <> t.cnt;
DELETE #sys;
INSERT #sys EXEC dbo.usp_P3_RptSystemRevenue @FromDate = @from, @ToDate = @to, @Revenue = @d1 OUTPUT, @InvoiceCount = @c1 OUTPUT;
SELECT @d2 = SUM(Revenue), @c2 = SUM(InvoiceCount) FROM #r1;
SELECT @d3 = ISNULL(SUM(FinalAmount), 0), @c3 = COUNT_BIG(*) FROM dbo.INVOICE WHERE PaymentStatus = 'PAID';
SELECT @d4 = SUM(Revenue), @c4 = SUM(InvoiceCount) FROM #r5 WHERE Grain = 'DAY';
INSERT @checks VALUES ('V6', CASE WHEN @n = 0 AND @d1 = @d2 AND @c1 = @c2 AND @d1 = @d3 AND @c1 = @c3 AND @d1 = @d4 AND @c1 = @c4 THEN 'PASS' ELSE 'FAIL' END,
    N'Detail = aggregate: per branch, day = month = quarter = year rows = sum of its monthly totals; sum of all branch-months = system total of the whole range = sum of the daily system rows = SUM(FinalAmount) of PAID invoices; invoice count = number of PAID invoices (each exactly once)',
    CONCAT(N'branch x grain totals differing ', @n, N'; system (whole range) ', @d1, N' / ', @c1, N'; sum of branch-months ', @d2, N' / ', @c2, N'; daily system rows ', @d4, N' / ', @c4, N'; PAID invoices read directly ', @d3, N' / ', @c3));

/* ---------- V7: unpaid invoices ---------- */
SELECT @d2 = ISNULL(SUM(FinalAmount), 0), @c2 = COUNT_BIG(*) FROM dbo.INVOICE;
SELECT @d4 = ISNULL(SUM(FinalAmount), 0), @c4 = COUNT_BIG(*), @n = ISNULL(SUM(CASE WHEN PaidAt IS NOT NULL THEN 1 ELSE 0 END), 0) FROM dbo.INVOICE WHERE PaymentStatus <> 'PAID';
INSERT @checks VALUES ('V7', CASE WHEN @n = 0 AND @d2 - @d1 = @d4 AND @c2 - @c1 = @c4 THEN 'PASS' ELSE 'FAIL' END,
    N'PENDING and CANCELLED invoices contribute nothing: none has a PaidAt; all invoices - reported revenue = amount of the non-PAID invoices',
    CONCAT(N'all invoices ', @d2, N' / ', @c2, N'; reported ', @d1, N' / ', @c1, N'; non-PAID ', @d4, N' / ', @c4, N' (',
           (SELECT STRING_AGG(CONVERT(nvarchar(200), CONCAT(PaymentStatus, N' ', k)), N', ') FROM (SELECT PaymentStatus, COUNT(*) AS k FROM dbo.INVOICE GROUP BY PaymentStatus) AS x), N'); non-PAID with a PaidAt ', @n));

/* ---------- V8: line-level reconciliation ---------- */
CREATE TABLE #ln (Invoice_ID int NOT NULL PRIMARY KEY, Net decimal(38,2) NOT NULL);
INSERT #ln
SELECT Invoice_ID, SUM(Net) FROM (
    SELECT s.Invoice_ID, SUM(CONVERT(decimal(38,2), s.UnitPrice - s.DiscountAmount)) AS Net FROM dbo.INVOICE_SERVICE_ITEM AS s GROUP BY s.Invoice_ID
    UNION ALL
    SELECT p.Invoice_ID, SUM(CONVERT(decimal(38,2), p.UnitPrice * p.Quantity - p.DiscountAmount)) FROM dbo.INVOICE_PRODUCT_ITEM AS p GROUP BY p.Invoice_ID) AS x
GROUP BY Invoice_ID;
SELECT @n = COUNT(*) FROM #o AS o LEFT JOIN #ln AS l ON l.Invoice_ID = o.Invoice_ID WHERE l.Invoice_ID IS NULL OR l.Net <> o.FinalAmount;
SELECT @n2 = COUNT(*) FROM #r1 AS r
OUTER APPLY (SELECT ISNULL(SUM(l.Net), 0) AS net FROM #o AS o JOIN #ln AS l ON l.Invoice_ID = o.Invoice_ID WHERE o.Branch_ID = r.Branch_ID AND o.LocalMonth = r.M) AS x
WHERE r.Revenue <> x.net;
SELECT @d2 = SUM(l.Net) FROM #o AS o JOIN #ln AS l ON l.Invoice_ID = o.Invoice_ID;
INSERT @checks VALUES ('V8', CASE WHEN @n = 0 AND @n2 = 0 AND @d2 = @d1 THEN 'PASS' ELSE 'FAIL' END,
    N'Line level: for every branch x month the line amounts net of line discounts of the PAID invoices (aggregated per invoice first) = the report; every PAID header = its lines (discounts once, no double counting through the line tables)',
    CONCAT(N'PAID invoices whose header differs from its lines ', @n, N'; branch-months differing ', @n2, N'; line-level total ', @d2, N' = reported ', @d1,
           N'; lines read: service ', (SELECT COUNT_BIG(*) FROM dbo.INVOICE_SERVICE_ITEM), N', product ', (SELECT COUNT_BIG(*) FROM dbo.INVOICE_PRODUCT_ITEM)));

/* ---------- V9: period not aligned to months ---------- */
DECLARE @p1 date = DATEADD(DAY, 9, @minM), @p2 date = DATEADD(DAY, 19, @maxM);
SET @n = 0; SET @d2 = 0; SET @c2 = 0;
DECLARE c9 CURSOR LOCAL FAST_FORWARD FOR SELECT Branch_ID FROM #br ORDER BY Branch_ID;
OPEN c9; FETCH NEXT FROM c9 INTO @b;
WHILE @@FETCH_STATUS = 0
BEGIN
    DELETE #tot;
    INSERT #tot EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = @b, @FromDate = @p1, @ToDate = @p2, @Revenue = @rev OUTPUT, @InvoiceCount = @cnt OUTPUT;
    SELECT @d3 = ISNULL(SUM(FinalAmount), 0), @c3 = COUNT_BIG(*) FROM #o WHERE Branch_ID = @b AND LocalDate >= @p1 AND LocalDate < @p2;
    IF @rev IS NULL OR @rev <> @d3 OR @cnt <> @c3 SET @n += 1;
    SET @d2 += ISNULL(@rev, 0); SET @c2 += ISNULL(@cnt, 0);
    FETCH NEXT FROM c9 INTO @b;
END;
CLOSE c9; DEALLOCATE c9;
DELETE #sys;
INSERT #sys EXEC dbo.usp_P3_RptSystemRevenue @FromDate = @p1, @ToDate = @p2, @Revenue = @rev OUTPUT, @InvoiceCount = @cnt OUTPUT;
SELECT @d3 = ISNULL(SUM(FinalAmount), 0), @c3 = COUNT_BIG(*) FROM #o WHERE LocalDate >= @p1 AND LocalDate < @p2;
INSERT @checks VALUES ('V9', CASE WHEN @n = 0 AND @rev = @d3 AND @cnt = @c3 AND @d2 = @rev AND @c2 = @cnt THEN 'PASS' ELSE 'FAIL' END,
    N'Period not aligned to months (10th of the first month to the 20th of the last month, half-open): every branch total and the system total = reference; sum of branches = system',
    CONCAT(N'period [', CONVERT(varchar(10), @p1, 23), N', ', CONVERT(varchar(10), @p2, 23), N'); branches differing ', @n, N'; system ', @rev, N' / ', @cnt, N'; reference ', @d3, N' / ', @c3, N'; sum of branches ', @d2, N' / ', @c2));

/* ---------- V10: cross-check with the UC05 monthly spending aggregate ---------- */
IF @spendingCheck = 1
BEGIN
    SELECT @n = COUNT(*) FROM #r2 AS r
    FULL OUTER JOIN (SELECT SpendingMonth, SUM(CONVERT(decimal(38,2), TotalSpend)) AS total FROM dbo.MEMBER_MONTHLY_SPENDING GROUP BY SpendingMonth) AS s ON s.SpendingMonth = r.M
    WHERE r.M IS NULL OR r.Revenue <> ISNULL(s.total, 0);
    SELECT @d2 = ISNULL(SUM(CONVERT(decimal(38,2), TotalSpend)), 0), @c2 = COUNT_BIG(*) FROM dbo.MEMBER_MONTHLY_SPENDING;
    INSERT @checks VALUES ('V10', CASE WHEN @n = 0 AND @d2 = @d1 THEN 'PASS' ELSE 'FAIL' END,
        N'Cross-check with UC05: SUM(MEMBER_MONTHLY_SPENDING.TotalSpend) per SpendingMonth = company-wide revenue of the same local month (two independent paths from the same PAID invoices)',
        CONCAT(N'months differing ', @n, N'; total spending ', @d2, N' in ', @c2, N' member-month rows = reported revenue ', @d1));
END;

/* ---------- V11 (INFO): effect of the UTC-to-local shift in this data ---------- */
SELECT @c1 = ISNULL(SUM(CASE WHEN CONVERT(date, i.PaidAt) <> o.LocalDate THEN 1 ELSE 0 END), 0),
       @c2 = ISNULL(SUM(CASE WHEN DATEFROMPARTS(YEAR(i.PaidAt), MONTH(i.PaidAt), 1) <> o.LocalMonth THEN 1 ELSE 0 END), 0),
       @d2 = ISNULL(SUM(CASE WHEN DATEFROMPARTS(YEAR(i.PaidAt), MONTH(i.PaidAt), 1) <> o.LocalMonth THEN i.FinalAmount ELSE 0 END), 0)
FROM #o AS o JOIN dbo.INVOICE AS i ON i.Invoice_ID = o.Invoice_ID;
SELECT @n = COUNT(*) FROM #r2 AS r
OUTER APPLY (SELECT ISNULL(SUM(i.FinalAmount), 0) AS utc_rev FROM dbo.INVOICE AS i WHERE i.PaymentStatus = 'PAID' AND DATEFROMPARTS(YEAR(i.PaidAt), MONTH(i.PaidAt), 1) = r.M) AS u
WHERE u.utc_rev <> r.Revenue;
INSERT @checks VALUES ('V11', 'INFO', N'UTC-to-local shift in this data (context for V1-V5: the reports equal the LOCAL reference)',
    CONCAT(N'PAID invoices whose UTC calendar date differs from the local date ', @c1, N'; whose UTC month differs from the local month ', @c2, N' (amount ', @d2,
           N'); months in which a UTC-calendar report would differ from the local report ', @n, N' of ', (SELECT COUNT(*) FROM #months)));

SELECT check_id, result, descr, detail FROM @checks ORDER BY seq;
PRINT '-- company-wide revenue per local month (report routine usp_P3_RptSystemRevenue) --';
SELECT CONVERT(varchar(7), M, 23) AS local_month, Revenue AS revenue, InvoiceCount AS paid_invoices FROM #r2 ORDER BY M;
PRINT '-- revenue per branch over the whole range (sum of the monthly branch reports) --';
SELECT Branch_ID, SUM(Revenue) AS revenue, SUM(InvoiceCount) AS paid_invoices FROM #r1 GROUP BY Branch_ID ORDER BY Branch_ID;

DECLARE @fails int = (SELECT COUNT(*) FROM @checks WHERE result = 'FAIL'), @nchk int = (SELECT COUNT(*) FROM @checks WHERE result <> 'INFO');
PRINT CONCAT('T-REC-05 SUMMARY: database ', DB_NAME(), '; checks=', @nchk, ' FAIL=', @fails, ' INFO=1');
IF @fails > 0 OR @nchk <> 9 + @spendingCheck
BEGIN
    PRINT 'T-REC-05_RESULT: FAIL';
    THROW 51433, N'T-REC_revenue failed (see the check table).', 1;
END
ELSE
    PRINT 'T-REC-05_RESULT: PASS';
GO
