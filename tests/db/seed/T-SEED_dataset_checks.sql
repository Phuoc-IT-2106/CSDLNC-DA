/* =====================================================================
   T-SEED_dataset_checks.sql - TEST_ONLY (sqlcmd mode), read-only
   Work order : WO-P3-P2-01. Validates a generated P3 dataset:
     T-SEED-01 row counts          T-SEED-02 keys, FKs, constraints, schema unchanged
     T-SEED-03 distributions       T-SEED-04 payment states and timestamps
     T-SEED-05 local-calendar month boundaries
     V-TOT     header totals = sum of lines (D-023)
     T-REC-01  monthly spending = PAID invoices by local month of PaidAt (D-013)
     T-REC-02  PointsEarned = FLOOR(TotalSpend / 100000), also by incremental replay (D-006)
   Variables: the dataset profile (db/seed/profiles.json) plus CountTolerancePct,
              DistTolerancePP, LinesMeanTolerance, Demo70k (0/1/2), SkewCheck (0/1) and the
              runtime setting MaxGrantPercent (memory-grant cap; affects memory use only).
   Share tolerances: max(DistTolerancePP, 4 standard errors of the configured share for the
   sample size), so small smoke datasets are not failed by sampling noise while large datasets
   are held to DistTolerancePP. Each check prints PASS/FAIL/INFO; the script raises an error
   if any check fails.
   ===================================================================== */
:on error exit
SET NOCOUNT ON;

IF DB_NAME() NOT LIKE N'FitLife[_]P3[_]%'
    THROW 51070, N'T-SEED checks run only in an isolated FitLife_P3_% database.', 1;

DECLARE @StartLocal date = '$(StartDateLocal)', @EndLocal date = '$(EndDateLocal)';
DECLARE @InvPerMonth int = $(InvoicesPerMonth);
DECLARE @Members int = $(MemberCount), @Branches int = $(BranchCount), @EmpPerBranch int = $(EmployeesPerBranch),
        @Plans int = $(PlanCount), @Products int = $(ProductCount);
DECLARE @SvcShare float = $(ServiceInvoiceShare), @CancelShare float = $(CancelledShare),
        @PendDays int = $(PendingWindowDays), @PendShare float = $(PendingShareInWindow),
        @HeavyInvShare float = $(HeavyInvoiceShare), @DiscShare float = $(DiscountLineShare), @PeakShare float = $(PeakShare);
DECLARE @CountTolPct float = $(CountTolerancePct), @DistTolPP float = $(DistTolerancePP),
        @LinesTol float = $(LinesMeanTolerance), @Demo70k int = $(Demo70k), @SkewCheck int = $(SkewCheck);
DECLARE @StartUtc datetime2(3) = DATEADD(HOUR, -7, CAST(@StartLocal AS datetime2(3))),
        @EndUtc   datetime2(3) = DATEADD(HOUR, -7, CAST(@EndLocal AS datetime2(3))),
        @PendFrom date = DATEADD(DAY, -$(PendingWindowDays), @EndLocal);

DECLARE @r TABLE (seq int IDENTITY(1,1), test_id varchar(10), check_id varchar(4), result varchar(4), descr nvarchar(200), detail nvarchar(2000));
DECLARE @n bigint, @m bigint, @k bigint, @p float, @q float, @e float, @tol float, @se float, @txt nvarchar(2000);
DECLARE @inv bigint = (SELECT COUNT(*) FROM dbo.INVOICE),
        @svc bigint = (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM),
        @prd bigint = (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM),
        @mms bigint = (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING);

/* local timestamps, computed once */
CREATE TABLE #iv (
    Invoice_ID int NOT NULL PRIMARY KEY, Member_ID int NOT NULL, Branch_ID int NOT NULL, Employee_ID int NOT NULL,
    IssuedAt datetime2(3) NOT NULL, PaidAt datetime2(3) NULL, PaymentStatus varchar(10) NOT NULL, PaymentMethod varchar(10) NULL,
    GrossAmount decimal(18,2) NOT NULL, DiscountAmount decimal(18,2) NOT NULL, FinalAmount decimal(18,2) NOT NULL,
    issued_local datetime2(3) NOT NULL, paid_local datetime2(3) NULL,
    INDEX ix_paid (paid_local) INCLUDE (PaymentStatus));                -- temporary table only
INSERT #iv
SELECT i.Invoice_ID, i.Member_ID, i.Branch_ID, i.Employee_ID, i.IssuedAt, i.PaidAt, i.PaymentStatus, i.PaymentMethod,
       i.GrossAmount, i.DiscountAmount, i.FinalAmount,
       DATEADD(HOUR, 7, i.IssuedAt), DATEADD(HOUR, 7, i.PaidAt)
FROM dbo.INVOICE AS i
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));

/* ================= T-SEED-01 row counts ================= */
DECLARE @mon TABLE (m date PRIMARY KEY, expected bigint, actual bigint);
WITH days AS (SELECT DATEADD(DAY, value, @StartLocal) AS d FROM GENERATE_SERIES(0, DATEDIFF(DAY, @StartLocal, @EndLocal) - 1)),
w AS (SELECT d, DATEFROMPARTS(YEAR(d), MONTH(d), 1) AS m,
             CASE DATEDIFF(DAY, '19000101', d) % 7 WHEN 0 THEN 1.05 WHEN 4 THEN 0.95 WHEN 5 THEN 1.05 WHEN 6 THEN 0.95 ELSE 1.00 END AS w FROM days),
mw AS (SELECT mm.m, SUM(CASE DATEDIFF(DAY, '19000101', dd.d) % 7 WHEN 0 THEN 1.05 WHEN 4 THEN 0.95 WHEN 5 THEN 1.05 WHEN 6 THEN 0.95 ELSE 1.00 END) AS W
       FROM (SELECT DISTINCT m FROM w) AS mm
       CROSS APPLY GENERATE_SERIES(0, DAY(EOMONTH(mm.m)) - 1) AS g
       CROSS APPLY (SELECT DATEADD(DAY, g.value, mm.m) AS d) AS dd GROUP BY mm.m),
ex AS (SELECT w.m, CAST(ROUND(SUM(CAST(@InvPerMonth AS decimal(19,6)) * w.w / mw.W), 0) AS bigint) AS expected
       FROM w JOIN mw ON mw.m = w.m GROUP BY w.m),
ac AS (SELECT DATEFROMPARTS(YEAR(issued_local), MONTH(issued_local), 1) AS m, COUNT_BIG(*) AS actual FROM #iv GROUP BY DATEFROMPARTS(YEAR(issued_local), MONTH(issued_local), 1))
INSERT @mon (m, expected, actual) SELECT COALESCE(ex.m, ac.m), ISNULL(ex.expected, 0), ISNULL(ac.actual, 0) FROM ex FULL JOIN ac ON ac.m = ex.m
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
SELECT @n = COUNT(*) FROM @mon WHERE expected <> actual;
SELECT @txt = STRING_AGG(CONCAT(CONVERT(char(7), m, 23), '=', actual, '/', expected), ' ') WITHIN GROUP (ORDER BY m) FROM @mon;
INSERT @r VALUES ('T-SEED-01', 'C01', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, N'INVOICE per local month = InvoicesPerMonth x day weights (exact)', @txt);

SET @e = @inv * (1 - @SvcShare) * 2.75;
INSERT @r VALUES ('T-SEED-01', 'C02', CASE WHEN ABS(@prd - @e) <= @e * @CountTolPct / 100 THEN 'PASS' ELSE 'FAIL' END,
    N'INVOICE_PRODUCT_ITEM within tolerance of N x (1 - service share) x 2.75', CONCAT('actual=', @prd, ' expected=', CAST(ROUND(@e, 0) AS bigint), ' tol%=', @CountTolPct));
SET @e = @inv * @SvcShare;
INSERT @r VALUES ('T-SEED-01', 'C03', CASE WHEN ABS(@svc - @e) <= @e * @CountTolPct / 100 THEN 'PASS' ELSE 'FAIL' END,
    N'INVOICE_SERVICE_ITEM within tolerance of N x service share', CONCAT('actual=', @svc, ' expected=', CAST(ROUND(@e, 0) AS bigint), ' tol%=', @CountTolPct));
INSERT @r VALUES ('T-SEED-01', 'C04',
    CASE WHEN @Demo70k = 0 THEN 'INFO'
         WHEN @Demo70k = 1 AND @inv >= 70000 AND @prd >= 70000 THEN 'PASS'
         WHEN @Demo70k = 2 AND @inv >= 70000 AND @prd >= 70000 AND @mms >= 70000 THEN 'PASS' ELSE 'FAIL' END,
    N'RQ-A06 demonstration tables >= 70,000 rows (Demo70k: 1 = INVOICE, product lines; 2 = also monthly spending)',
    CONCAT('INVOICE=', @inv, ' INVOICE_PRODUCT_ITEM=', @prd, ' INVOICE_SERVICE_ITEM=', @svc, ' MEMBER_MONTHLY_SPENDING=', @mms, ' Demo70k=', @Demo70k));
DECLARE @fxPlan bigint = (SELECT COUNT(*) FROM dbo.SERVICE_PLAN), @fxProd bigint = (SELECT COUNT(*) FROM dbo.PRODUCT);
SELECT @n = (SELECT COUNT(*) FROM dbo.MEMBER), @m = (SELECT COUNT(*) FROM dbo.BRANCH), @k = (SELECT COUNT(*) FROM dbo.EMPLOYEE);
INSERT @r VALUES ('T-SEED-01', 'C05',
    CASE WHEN @n = @Members AND @m = @Branches AND @k = @Branches * @EmpPerBranch
              AND @fxPlan = @Plans AND @fxProd = @Products THEN 'PASS' ELSE 'FAIL' END,
    N'TEST_ONLY fixture key rows = profile', CONCAT('MEMBER=', @n, ' BRANCH=', @m, ' EMPLOYEE=', @k, ' SERVICE_PLAN=', @fxPlan, ' PRODUCT=', @fxProd));

/* ================= T-SEED-02 keys, FKs, constraints, schema ================= */
SELECT @n =
      (SELECT COUNT(*) FROM dbo.INVOICE i LEFT JOIN dbo.MEMBER x ON x.Member_ID = i.Member_ID WHERE x.Member_ID IS NULL)
    + (SELECT COUNT(*) FROM dbo.INVOICE i LEFT JOIN dbo.EMPLOYEE x ON x.Employee_ID = i.Employee_ID WHERE x.Employee_ID IS NULL)
    + (SELECT COUNT(*) FROM dbo.INVOICE i LEFT JOIN dbo.BRANCH x ON x.Branch_ID = i.Branch_ID WHERE x.Branch_ID IS NULL)
    + (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM s LEFT JOIN dbo.INVOICE x ON x.Invoice_ID = s.Invoice_ID WHERE x.Invoice_ID IS NULL)
    + (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM s LEFT JOIN dbo.SERVICE_PLAN x ON x.Plan_ID = s.Plan_ID WHERE x.Plan_ID IS NULL)
    + (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM p LEFT JOIN dbo.INVOICE x ON x.Invoice_ID = p.Invoice_ID WHERE x.Invoice_ID IS NULL)
    + (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM p LEFT JOIN dbo.PRODUCT x ON x.Product_ID = p.Product_ID WHERE x.Product_ID IS NULL)
    + (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING s LEFT JOIN dbo.MEMBER x ON x.Member_ID = s.Member_ID WHERE x.Member_ID IS NULL)
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
INSERT @r VALUES ('T-SEED-02', 'C06', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, N'No orphan rows on the 8 foreign keys (explicit anti-joins)', CONCAT('orphans=', @n));

SELECT @n = (SELECT COUNT(*) FROM sys.foreign_keys WHERE is_disabled = 0 AND is_not_trusted = 0),
       @m = (SELECT COUNT(*) FROM sys.check_constraints WHERE is_disabled = 0 AND is_not_trusted = 0),
       @k = (SELECT COUNT(*) FROM sys.foreign_keys WHERE is_disabled = 1 OR is_not_trusted = 1)
          + (SELECT COUNT(*) FROM sys.check_constraints WHERE is_disabled = 1 OR is_not_trusted = 1);
INSERT @r VALUES ('T-SEED-02', 'C07', CASE WHEN @n = 8 AND @m = 13 AND @k = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'8 FK and 13 CHECK constraints enabled and trusted', CONCAT('fk_trusted=', @n, ' check_trusted=', @m, ' disabled_or_untrusted=', @k));

-- Every CHECK definition re-evaluated on every row (equivalent to DBCC CHECKCONSTRAINTS for CHECK
-- constraints; FKs are covered by C06). A row violates a CHECK only if the predicate is FALSE.
DECLARE @sql nvarchar(max) = N'', @cnt bigint, @nck int = 0;
DECLARE @ck TABLE (tbl sysname, cname sysname, def nvarchar(max));
INSERT @ck SELECT OBJECT_NAME(parent_object_id), name, definition FROM sys.check_constraints;
SET @n = 0;
DECLARE ck CURSOR LOCAL FAST_FORWARD FOR SELECT tbl, def FROM @ck;
DECLARE @tbl sysname, @def nvarchar(max);
OPEN ck; FETCH NEXT FROM ck INTO @tbl, @def;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'SELECT @c = COUNT_BIG(*) FROM dbo.' + QUOTENAME(@tbl) + N' WHERE NOT ' + @def + N';';
    EXEC sys.sp_executesql @sql, N'@c bigint OUTPUT', @c = @cnt OUTPUT;
    SET @n += @cnt; SET @nck += 1;
    FETCH NEXT FROM ck INTO @tbl, @def;
END
CLOSE ck; DEALLOCATE ck;
INSERT @r VALUES ('T-SEED-02', 'C08', CASE WHEN @n = 0 AND @nck = 13 THEN 'PASS' ELSE 'FAIL' END,
    N'All 13 CHECK definitions re-evaluated on every row: no violation', CONCAT('constraints=', @nck, ' violations=', @n));

SELECT @n = COUNT(*) FROM dbo.INVOICE i
WHERE NOT EXISTS (SELECT 1 FROM dbo.INVOICE_SERVICE_ITEM s WHERE s.Invoice_ID = i.Invoice_ID)
  AND NOT EXISTS (SELECT 1 FROM dbo.INVOICE_PRODUCT_ITEM p WHERE p.Invoice_ID = i.Invoice_ID)
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
INSERT @r VALUES ('T-SEED-02', 'C09', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, N'Every invoice has at least one line (BR12)', CONCAT('invoices_without_lines=', @n));

SELECT @n = (SELECT COUNT(*) FROM (SELECT Invoice_ID FROM dbo.INVOICE_SERVICE_ITEM GROUP BY Invoice_ID HAVING MIN([LineNo]) <> 1 OR MAX([LineNo]) <> COUNT(*)) a)
          + (SELECT COUNT(*) FROM (SELECT Invoice_ID FROM dbo.INVOICE_PRODUCT_ITEM GROUP BY Invoice_ID HAVING MIN([LineNo]) <> 1 OR MAX([LineNo]) <> COUNT(*)) b)
          + (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM s JOIN dbo.INVOICE_PRODUCT_ITEM p ON p.Invoice_ID = s.Invoice_ID AND p.[LineNo] = s.[LineNo])
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
INSERT @r VALUES ('T-SEED-02', 'C10', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, N'Line numbers 1..n per invoice; no line number used in both item tables', CONCAT('violations=', @n));

SELECT @n = COUNT(*) FROM (SELECT Member_ID, SpendingMonth FROM dbo.MEMBER_MONTHLY_SPENDING GROUP BY Member_ID, SpendingMonth HAVING COUNT(*) > 1) d
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
INSERT @r VALUES ('T-SEED-02', 'C11', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, N'No duplicate monthly aggregate key (Member_ID, SpendingMonth)', CONCAT('duplicate_keys=', @n));

SELECT @n = COUNT(*) FROM sys.columns c JOIN sys.tables t ON t.object_id = c.object_id
WHERE t.name IN (N'MEMBER', N'BRANCH', N'EMPLOYEE', N'SERVICE_PLAN', N'PRODUCT');
SELECT @m = COUNT(*) FROM sys.extended_properties ep JOIN sys.tables t ON t.object_id = ep.major_id
WHERE ep.class = 1 AND ep.minor_id = 0 AND ep.name = N'Classification' AND CONVERT(nvarchar(50), ep.value) = N'TEST_ONLY_FIXTURE';
INSERT @r VALUES ('T-SEED-02', 'C12', CASE WHEN @n = 5 AND @m = 5 THEN 'PASS' ELSE 'FAIL' END,
    N'Fixtures still key-only (5 tables x 1 column) and marked TEST_ONLY_FIXTURE', CONCAT('fixture_columns=', @n, ' marked=', @m));

SELECT @n = (SELECT COUNT(*) FROM sys.indexes i JOIN sys.tables t ON t.object_id = i.object_id WHERE i.index_id > 1)
          + (SELECT COUNT(*) FROM sys.objects WHERE is_ms_shipped = 0 AND type IN ('V', 'P', 'FN', 'IF', 'TF', 'TR'))
          + (SELECT COUNT(*) FROM sys.partition_functions) + (SELECT COUNT(*) FROM sys.tables) - 9;
INSERT @r VALUES ('T-SEED-02', 'C13', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Schema unchanged by seeding: 9 tables, no nonclustered index, view, routine, trigger or partition function (B0)', CONCAT('extra_objects=', @n));

/* ================= T-SEED-03 distributions (percentage points) ================= */
SELECT @p = 100.0 * SUM(CASE WHEN PaymentStatus = 'CANCELLED' THEN 1 ELSE 0 END) / COUNT(*) FROM #iv;
SET @se = 400 * SQRT(@CancelShare * (1 - @CancelShare) / @inv); SET @tol = IIF(@se > @DistTolPP, @se, @DistTolPP);
INSERT @r VALUES ('T-SEED-03', 'C14', CASE WHEN ABS(@p - 100 * @CancelShare) <= @tol THEN 'PASS' ELSE 'FAIL' END,
    N'CANCELLED share', CONCAT('actual%=', CAST(@p AS decimal(9,3)), ' configured%=', 100 * @CancelShare, ' tol_pp=', CAST(@tol AS decimal(9,3))));
SELECT @p = 100.0 * SUM(CASE WHEN PaymentStatus = 'PENDING' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), @n = COUNT(*)
FROM #iv WHERE CAST(issued_local AS date) >= @PendFrom AND PaymentStatus <> 'CANCELLED';
SET @se = 400 * SQRT(@PendShare * (1 - @PendShare) / NULLIF(@n, 0)); SET @tol = IIF(@se > @DistTolPP, @se, @DistTolPP);
INSERT @r VALUES ('T-SEED-03', 'C15', CASE WHEN ABS(@p - 100 * @PendShare) <= @tol THEN 'PASS' ELSE 'FAIL' END,
    N'PENDING share among non-cancelled invoices of the pending window', CONCAT('actual%=', CAST(@p AS decimal(9,3)), ' configured%=', 100 * @PendShare, ' n=', @n, ' tol_pp=', CAST(@tol AS decimal(9,3)), ' window_from=', CONVERT(char(10), @PendFrom, 23)));
SELECT @n = COUNT(*) FROM #iv WHERE PaymentStatus = 'PENDING' AND CAST(issued_local AS date) < @PendFrom;
INSERT @r VALUES ('T-SEED-03', 'C16', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, N'PENDING invoices exist only in the last days of the dataset', CONCAT('pending_outside_window=', @n));
SELECT @p = 100.0 * SUM(CASE WHEN PaymentMethod = 'CASH' THEN 1 ELSE 0 END) / COUNT(*),
       @q = 100.0 * SUM(CASE WHEN PaymentMethod = 'VNPAY' THEN 1 ELSE 0 END) / COUNT(*),
       @e = 100.0 * SUM(CASE WHEN PaymentMethod = 'CARD' THEN 1 ELSE 0 END) / COUNT(*)
FROM #iv WHERE PaymentStatus = 'PAID';
SELECT @n = COUNT(*) FROM #iv WHERE PaymentStatus = 'PAID';
SET @se = 400 * SQRT(0.40 * 0.60 / NULLIF(@n, 0)); SET @tol = IIF(@se > @DistTolPP, @se, @DistTolPP);
INSERT @r VALUES ('T-SEED-03', 'C17', CASE WHEN ABS(@p - 40) <= @tol AND ABS(@q - 35) <= @tol AND ABS(@e - 25) <= @tol THEN 'PASS' ELSE 'FAIL' END,
    N'Payment method mix of PAID invoices (CASH 40 / VNPAY 35 / CARD 25)', CONCAT('CASH%=', CAST(@p AS decimal(9,3)), ' VNPAY%=', CAST(@q AS decimal(9,3)), ' CARD%=', CAST(@e AS decimal(9,3)), ' tol_pp=', CAST(@tol AS decimal(9,3))));
SELECT @p = 100.0 * COUNT(DISTINCT Invoice_ID) / NULLIF(@inv, 0) FROM dbo.INVOICE_SERVICE_ITEM
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
SET @se = 400 * SQRT(@SvcShare * (1 - @SvcShare) / @inv); SET @tol = IIF(@se > @DistTolPP, @se, @DistTolPP);
INSERT @r VALUES ('T-SEED-03', 'C18', CASE WHEN ABS(@p - 100 * @SvcShare) <= @tol THEN 'PASS' ELSE 'FAIL' END,
    N'Service-invoice share', CONCAT('actual%=', CAST(@p AS decimal(9,3)), ' configured%=', 100 * @SvcShare, ' tol_pp=', CAST(@tol AS decimal(9,3))));
SELECT @p = 1.0 * COUNT(*) / NULLIF(COUNT(DISTINCT Invoice_ID), 0), @n = COUNT(DISTINCT Invoice_ID) FROM dbo.INVOICE_PRODUCT_ITEM
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
SET @se = 4 * SQRT(1.5875 / NULLIF(@n, 0)); SET @tol = IIF(@se > @LinesTol, @se, @LinesTol);   -- variance of the 1..5 line distribution = 1.5875
INSERT @r VALUES ('T-SEED-03', 'C19', CASE WHEN ABS(@p - 2.75) <= @tol THEN 'PASS' ELSE 'FAIL' END,
    N'Mean lines per product invoice (configured 2.75)', CONCAT('actual=', CAST(@p AS decimal(9,4)), ' tolerance=', CAST(@tol AS decimal(9,4))));
WITH bw AS (SELECT value AS b, CASE WHEN value <= @Branches / 4 THEN 1.5 WHEN value > @Branches - @Branches / 4 THEN 0.5 ELSE 1.0 END AS w FROM GENERATE_SERIES(1, @Branches)),
     bs AS (SELECT b, 100.0 * w / SUM(w) OVER () AS expected_pct FROM bw),
     ba AS (SELECT Branch_ID, 100.0 * COUNT(*) / @inv AS actual_pct FROM #iv GROUP BY Branch_ID)
SELECT @q = MAX(ABS(ISNULL(ba.actual_pct, 0) - bs.expected_pct)),
       @txt = STRING_AGG(CONCAT(bs.b, ':', CAST(ISNULL(ba.actual_pct, 0) AS decimal(6,2)), '/', CAST(bs.expected_pct AS decimal(6,2))), ' ') WITHIN GROUP (ORDER BY bs.b)
FROM bs LEFT JOIN ba ON ba.Branch_ID = bs.b
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
INSERT @r VALUES ('T-SEED-03', 'C20', CASE WHEN @q <= @DistTolPP THEN 'PASS' ELSE 'FAIL' END,
    N'Branch shares vs weights (3 large 1.5 / 6 medium 1.0 / 3 small 0.5); max deviation in pp', CONCAT('max_dev_pp=', CAST(@q AS decimal(9,3)), ' branch:actual/expected% ', @txt));
WITH mc AS (SELECT Member_ID, COUNT(*) AS c, ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC, Member_ID) AS rk FROM #iv GROUP BY Member_ID)
SELECT @p = 100.0 * SUM(CASE WHEN rk <= @Members / 5 THEN c ELSE 0 END) / @inv, @n = COUNT(*) FROM mc
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
INSERT @r VALUES ('T-SEED-03', 'C21', CASE WHEN @SkewCheck = 0 THEN 'INFO' WHEN ABS(@p - 100 * @HeavyInvShare) <= 5 THEN 'PASS' ELSE 'FAIL' END,
    N'Member skew: share of invoices from the top 20% of members (configured heavy share; tolerance 5 pp)', CONCAT('top20%_share%=', CAST(@p AS decimal(9,3)), ' configured%=', 100 * @HeavyInvShare, ' members_with_invoices=', @n, ' of ', @Members));
SELECT @p = 100.0 * SUM(CASE WHEN DiscountAmount > 0 THEN 1 ELSE 0 END) / COUNT(*)
FROM (SELECT DiscountAmount FROM dbo.INVOICE_SERVICE_ITEM UNION ALL SELECT DiscountAmount FROM dbo.INVOICE_PRODUCT_ITEM) AS l;
SET @se = 400 * SQRT(@DiscShare * (1 - @DiscShare) / NULLIF(@svc + @prd, 0)); SET @tol = IIF(@se > @DistTolPP, @se, @DistTolPP);
INSERT @r VALUES ('T-SEED-03', 'C22', CASE WHEN ABS(@p - 100 * @DiscShare) <= @tol THEN 'PASS' ELSE 'FAIL' END,
    N'Share of discounted lines', CONCAT('actual%=', CAST(@p AS decimal(9,3)), ' configured%=', 100 * @DiscShare, ' tol_pp=', CAST(@tol AS decimal(9,3))));
SELECT @n = SUM(CASE WHEN CAST(issued_local AS time) < '06:00' OR CAST(issued_local AS time) >= '22:00' THEN 1 ELSE 0 END),
       @p = 100.0 * SUM(CASE WHEN CAST(issued_local AS time) >= '17:00' AND CAST(issued_local AS time) < '20:00' THEN 1 ELSE 0 END) / COUNT(*)
FROM #iv;
SET @e = 100 * (@PeakShare + (1 - @PeakShare) * 3.0 / 16.0);
SET @se = 400 * SQRT((@e / 100) * (1 - @e / 100) / @inv); SET @tol = IIF(@se > @DistTolPP, @se, @DistTolPP);
INSERT @r VALUES ('T-SEED-03', 'C23', CASE WHEN @n = 0 AND ABS(@p - @e) <= @tol THEN 'PASS' ELSE 'FAIL' END,
    N'Issue times within opening hours 06:00-22:00 local; evening-peak (17:00-20:00) share', CONCAT('outside_hours=', @n, ' peak%=', CAST(@p AS decimal(9,3)), ' expected%=', CAST(@e AS decimal(9,3))));

/* ================= T-SEED-04 payment states and timestamps ================= */
SELECT @n = COUNT(*) FROM #iv
WHERE (PaymentStatus = 'PAID' AND (PaidAt IS NULL OR PaymentMethod IS NULL OR PaidAt < IssuedAt))
   OR (PaymentStatus <> 'PAID' AND (PaidAt IS NOT NULL OR PaymentMethod IS NOT NULL))
   OR PaymentStatus NOT IN ('PAID', 'PENDING', 'CANCELLED');
INSERT @r VALUES ('T-SEED-04', 'C24', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'PAID: PaidAt and method set, PaidAt >= IssuedAt; PENDING/CANCELLED: no PaidAt, no method (D-005)', CONCAT('violations=', @n));
SELECT @n = COUNT(*) FROM #iv
WHERE IssuedAt < @StartUtc OR IssuedAt >= @EndUtc OR (PaidAt IS NOT NULL AND (PaidAt < @StartUtc OR PaidAt >= @EndUtc));
INSERT @r VALUES ('T-SEED-04', 'C25', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'All IssuedAt and PaidAt inside the dataset range (UTC bounds of the local range)', CONCAT('outside=', @n, ' utc_range=[', CONVERT(varchar(23), @StartUtc, 121), ', ', CONVERT(varchar(23), @EndUtc, 121), ')'));
SELECT @n = COUNT(*) FROM #iv WHERE PaidAt IS NOT NULL AND DATEDIFF_BIG(MILLISECOND, IssuedAt, PaidAt) > 86400000;
SELECT @k = MAX(DATEDIFF_BIG(MILLISECOND, IssuedAt, PaidAt)) FROM #iv;
INSERT @r VALUES ('T-SEED-04', 'C26', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Issue-to-payment delay at most 24 h', CONCAT('over_24h=', @n, ' max_delay_ms=', @k));

/* ================= T-SEED-05 local-calendar month boundaries ================= */
DECLARE @bd TABLE (b date PRIMARY KEY, is_end bit);
INSERT @bd
SELECT DISTINCT DATEADD(MONTH, 1, DATEFROMPARTS(YEAR(d), MONTH(d), 1)),
       CASE WHEN DATEADD(MONTH, 1, DATEFROMPARTS(YEAR(d), MONTH(d), 1)) = @EndLocal THEN 1 ELSE 0 END
FROM (SELECT DATEADD(DAY, value, @StartLocal) AS d FROM GENERATE_SERIES(0, DATEDIFF(DAY, @StartLocal, @EndLocal) - 1)) AS x
WHERE DATEADD(MONTH, 1, DATEFROMPARTS(YEAR(d), MONTH(d), 1)) <= @EndLocal AND DATEADD(MONTH, 1, DATEFROMPARTS(YEAR(d), MONTH(d), 1)) > @StartLocal;
SELECT @n = COUNT(*) FROM @bd bd
WHERE NOT EXISTS (SELECT 1 FROM #iv WHERE PaymentStatus = 'PAID' AND paid_local = DATEADD(MILLISECOND, -1, CAST(bd.b AS datetime2(3))))
   OR (bd.is_end = 0 AND NOT EXISTS (SELECT 1 FROM #iv WHERE PaymentStatus = 'PAID' AND paid_local = CAST(bd.b AS datetime2(3))))
   OR (bd.is_end = 0 AND NOT EXISTS (SELECT 1 FROM #iv WHERE PaymentStatus = 'PAID' AND paid_local = DATEADD(MINUTE, 210, CAST(bd.b AS datetime2(3)))))
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
SELECT @m = COUNT(*), @k = SUM(CAST(is_end AS int)) FROM @bd;
INSERT @r VALUES ('T-SEED-05', 'C27', CASE WHEN @n = 0 AND @m > 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Boundary rows at 23:59:59.999, 00:00:00.000 and 03:30 local for every month boundary (only 23:59:59.999 at the range end)',
    CONCAT('boundaries=', @m, ' (end=', @k, ') missing=', @n));
SELECT @n = COUNT(*) FROM #iv i JOIN @bd bd ON bd.is_end = 0
WHERE i.PaymentStatus = 'PAID' AND i.paid_local >= CAST(bd.b AS datetime2(3)) AND i.paid_local < DATEADD(HOUR, 7, CAST(bd.b AS datetime2(3)))
  AND MONTH(i.PaidAt) <> MONTH(i.paid_local)
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
SELECT @m = COUNT(*) FROM #iv i JOIN @bd bd ON bd.is_end = 0
JOIN dbo.MEMBER_MONTHLY_SPENDING s ON s.Member_ID = i.Member_ID AND s.SpendingMonth = bd.b
WHERE i.PaymentStatus = 'PAID' AND i.paid_local >= CAST(bd.b AS datetime2(3)) AND i.paid_local < DATEADD(HOUR, 7, CAST(bd.b AS datetime2(3)))
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
DECLARE @internalB bigint = (SELECT COUNT(*) FROM @bd WHERE is_end = 0);
INSERT @r VALUES ('T-SEED-05', 'C28', CASE WHEN @internalB = 0 THEN 'INFO' WHEN @n > 0 AND @m = @n THEN 'PASS' ELSE 'FAIL' END,
    N'Payments at 00:00-06:59 local on the 1st (UTC month = previous month) exist and are counted in the local month',
    CONCAT('rows=', @n, ' counted_in_local_month=', @m));

/* ================= V-TOT header totals ================= */
SELECT @n = COUNT(*)
FROM dbo.INVOICE i
OUTER APPLY (SELECT ISNULL(SUM(UnitPrice), 0) AS g, ISNULL(SUM(DiscountAmount), 0) AS d FROM dbo.INVOICE_SERVICE_ITEM s WHERE s.Invoice_ID = i.Invoice_ID) AS sv
OUTER APPLY (SELECT ISNULL(SUM(UnitPrice * Quantity), 0) AS g, ISNULL(SUM(DiscountAmount), 0) AS d FROM dbo.INVOICE_PRODUCT_ITEM p WHERE p.Invoice_ID = i.Invoice_ID) AS pr
WHERE i.GrossAmount <> sv.g + pr.g OR i.DiscountAmount <> sv.d + pr.d OR i.FinalAmount <> i.GrossAmount - i.DiscountAmount
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
INSERT @r VALUES ('V-TOT', 'C29', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, N'Gross = sum of line gross, Discount = sum of line discounts, Final = Gross - Discount (D-023)', CONCAT('mismatching_invoices=', @n));

/* ================= T-REC-01 monthly spending ================= */
WITH src AS (
    SELECT Member_ID, DATEFROMPARTS(YEAR(paid_local), MONTH(paid_local), 1) AS SpendingMonth, SUM(FinalAmount) AS TotalSpend, MAX(PaidAt) AS LastPaid
    FROM #iv WHERE PaymentStatus = 'PAID' GROUP BY Member_ID, DATEFROMPARTS(YEAR(paid_local), MONTH(paid_local), 1))
SELECT @n = SUM(CASE WHEN s.Member_ID IS NULL OR m.Member_ID IS NULL OR s.TotalSpend <> m.TotalSpend THEN 1 ELSE 0 END),
       @m = SUM(CASE WHEN s.Member_ID IS NOT NULL AND m.Member_ID IS NOT NULL AND s.LastPaid <> m.UpdatedAt THEN 1 ELSE 0 END)
FROM src s FULL JOIN dbo.MEMBER_MONTHLY_SPENDING m ON m.Member_ID = s.Member_ID AND m.SpendingMonth = s.SpendingMonth
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
INSERT @r VALUES ('T-REC-01', 'C30', CASE WHEN ISNULL(@n, 0) = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'(member, month): TotalSpend = sum of FinalAmount of PAID invoices in the local month of PaidAt; no missing or extra rows', CONCAT('mismatches=', ISNULL(@n, 0)));
INSERT @r VALUES ('T-REC-01', 'C31', CASE WHEN ISNULL(@m, 0) = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'UpdatedAt = last PaidAt of the member-month (generator convention)', CONCAT('mismatches=', ISNULL(@m, 0)));

/* ================= T-REC-02 points (D-006) ================= */
SELECT @n = COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING WHERE PointsEarned <> CAST(FLOOR(TotalSpend / 100000) AS int);
INSERT @r VALUES ('T-REC-02', 'C32', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, N'PointsEarned = FLOOR(TotalSpend / 100000) per member-month', CONCAT('mismatches=', @n));
WITH ordered AS (
    SELECT Member_ID, DATEFROMPARTS(YEAR(paid_local), MONTH(paid_local), 1) AS SpendingMonth, FinalAmount,
           SUM(FinalAmount) OVER (PARTITION BY Member_ID, DATEFROMPARTS(YEAR(paid_local), MONTH(paid_local), 1)
                                  ORDER BY PaidAt, Invoice_ID ROWS UNBOUNDED PRECEDING) AS cum
    FROM #iv WHERE PaymentStatus = 'PAID'),
inc AS (
    SELECT Member_ID, SpendingMonth, SUM(CAST(FLOOR(cum / 100000) - FLOOR((cum - FinalAmount) / 100000) AS int)) AS replay_points
    FROM ordered GROUP BY Member_ID, SpendingMonth)
SELECT @n = COUNT(*) FROM inc JOIN dbo.MEMBER_MONTHLY_SPENDING m ON m.Member_ID = inc.Member_ID AND m.SpendingMonth = inc.SpendingMonth
WHERE inc.replay_points <> m.PointsEarned
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
INSERT @r VALUES ('T-REC-02', 'C33', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Incremental replay (each PAID invoice in PaidAt order adds new floor - previous floor) = PointsEarned', CONCAT('mismatches=', @n));
SELECT @n = SUM(PointsEarned), @m = CAST(SUM(TotalSpend - 100000 * FLOOR(TotalSpend / 100000)) AS bigint) FROM dbo.MEMBER_MONTHLY_SPENDING;
SELECT @k = SUM(CAST(FLOOR(FinalAmount / 100000) AS bigint)) FROM #iv WHERE PaymentStatus = 'PAID'
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
INSERT @r VALUES ('T-REC-02', 'C34', 'INFO', N'D-006 effect: monthly-cumulative points vs a per-invoice floor; spending residual not carried to the next month',
    CONCAT('points_monthly_rule=', @n, ' points_if_per_invoice=', @k, ' residual_vnd_not_carried=', @m));

/* ================= output ================= */
PRINT '== Results ==';
SELECT test_id, check_id, result, descr, detail FROM @r ORDER BY seq;

PRINT '== Row counts ==';
SELECT 'INVOICE' AS tbl, @inv AS row_count UNION ALL SELECT 'INVOICE_SERVICE_ITEM', @svc UNION ALL SELECT 'INVOICE_PRODUCT_ITEM', @prd
UNION ALL SELECT 'MEMBER_MONTHLY_SPENDING', @mms UNION ALL SELECT 'MEMBER (fixture keys)', (SELECT COUNT(*) FROM dbo.MEMBER)
UNION ALL SELECT 'BRANCH (fixture keys)', (SELECT COUNT(*) FROM dbo.BRANCH) UNION ALL SELECT 'EMPLOYEE (fixture keys)', (SELECT COUNT(*) FROM dbo.EMPLOYEE)
UNION ALL SELECT 'SERVICE_PLAN (fixture keys)', (SELECT COUNT(*) FROM dbo.SERVICE_PLAN) UNION ALL SELECT 'PRODUCT (fixture keys)', (SELECT COUNT(*) FROM dbo.PRODUCT);

PRINT '== Distribution report ==';
SELECT PaymentStatus, PaymentMethod, COUNT(*) AS invoices, CAST(SUM(FinalAmount) AS decimal(18,2)) AS final_amount
FROM #iv GROUP BY PaymentStatus, PaymentMethod ORDER BY PaymentStatus, PaymentMethod
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
SELECT CONVERT(char(7), SpendingMonth, 23) AS spending_month, COUNT(*) AS member_months, CAST(SUM(TotalSpend) AS decimal(18,2)) AS total_spend, SUM(PointsEarned) AS points
FROM dbo.MEMBER_MONTHLY_SPENDING GROUP BY SpendingMonth ORDER BY SpendingMonth
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
SELECT MIN(FinalAmount) AS min_final, MAX(FinalAmount) AS max_final, CAST(AVG(FinalAmount) AS decimal(18,2)) AS avg_final,
       (SELECT MIN(c) FROM (SELECT COUNT(*) c FROM #iv GROUP BY Member_ID) a) AS min_invoices_per_active_member,
       (SELECT MAX(c) FROM (SELECT COUNT(*) c FROM #iv GROUP BY Member_ID) a) AS max_invoices_per_member,
       (SELECT COUNT(DISTINCT Member_ID) FROM #iv) AS members_with_invoices
FROM #iv
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));

PRINT '== Storage (sys.dm_db_partition_stats, sys.database_files) ==';
SELECT t.name AS tbl, SUM(ps.row_count) AS row_count, SUM(ps.reserved_page_count) AS reserved_pages,
       CAST(SUM(ps.reserved_page_count) * 8.0 / 1024 AS decimal(10,2)) AS reserved_mb,
       SUM(ps.in_row_data_page_count) AS data_pages
FROM sys.dm_db_partition_stats ps JOIN sys.tables t ON t.object_id = ps.object_id
GROUP BY t.name ORDER BY t.name;
SELECT type_desc, CAST(SUM(size) * 8.0 / 1024 AS decimal(10,2)) AS allocated_mb, CAST(SUM(FILEPROPERTY(name, 'SpaceUsed')) * 8.0 / 1024 AS decimal(10,2)) AS used_mb
FROM sys.database_files GROUP BY type_desc;

SELECT @n = COUNT(*) FROM @r WHERE result = 'FAIL';
SELECT @m = COUNT(*) FROM @r WHERE result = 'PASS';
SELECT @k = COUNT(*) FROM @r WHERE result = 'INFO';
PRINT CONCAT('T-SEED SUMMARY: checks=', @n + @m + @k, ' PASS=', @m, ' FAIL=', @n, ' INFO=', @k);
IF @n = 0
    PRINT 'T-SEED_RESULT: PASS';
ELSE
BEGIN
    PRINT 'T-SEED_RESULT: FAIL';
    THROW 51071, N'T-SEED dataset checks failed; see the results above.', 1;
END
GO
