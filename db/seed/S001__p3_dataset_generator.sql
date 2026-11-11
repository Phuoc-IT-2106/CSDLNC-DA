/* =====================================================================
   S001__p3_dataset_generator.sql  (sqlcmd mode)
   Classification : P3 dataset generator (DL-04). Writes ONLY the four P3-owned tables:
                    INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM, MEMBER_MONTHLY_SPENDING.
                    Reads the TEST_ONLY fixture keys (MEMBER, BRANCH, EMPLOYEE, SERVICE_PLAN,
                    PRODUCT) and never writes them. Creates no table, index, view, routine or
                    trigger in the database (temporary #tables only).
   Work order     : WO-P3-P2-01. Decisions: D-022 (dataset), D-006 (points), D-013 (month),
                    D-014 (UTC), D-005 (states), D-023 (totals).
   Version        : S001 v1.0
   Determinism    : no NEWID(), RAND() or clock values in the data. Every pseudo-random value
                    is a 4-byte slice of SHA-256(Seed : stream : key) scaled to [0, 1); keys are
                    the local date and the invoice number within that day, so the same Seed and
                    parameters always give the same rows. Invoice_ID is assigned by the order
                    (IssuedAt, key) and inserted explicitly.
   Time           : business times are generated on the Asia/Ho_Chi_Minh calendar (fixed UTC+07:00,
                    no daylight saving) and stored in UTC (D-014).
   Variables      : Seed, StartDateLocal, EndDateLocal (exclusive), InvoicesPerMonth, MemberCount,
                    BranchCount, EmployeesPerBranch, PlanCount, ProductCount, ServiceInvoiceShare,
                    CancelledShare, PendingWindowDays, PendingShareInWindow, HeavyMemberShare,
                    HeavyInvoiceShare, HomeBranchShare, DiscountLineShare, PeakShare
                    (values per dataset profile: db/seed/profiles.json); MaxGrantPercent (runtime
                    setting: caps the memory grant of each large statement so that the script also
                    runs on a memory-starved instance; it changes memory use and spills, never results).
   Preconditions  : run in a FitLife_P3_% database (never FitLife_P3_P1) carrying the WO-P3-P2-01
                    disposable marker, after F001 (key-only fixtures) and F001D (fixture key rows);
                    the four P3 tables must be empty.
   ===================================================================== */
:on error exit
SET XACT_ABORT ON;
SET NOCOUNT ON;

DECLARE @GeneratorVersion varchar(20) = 'S001 v1.0';
DECLARE @Seed int = $(Seed);
DECLARE @StartLocal date = '$(StartDateLocal)', @EndLocal date = '$(EndDateLocal)';
DECLARE @InvPerMonth int = $(InvoicesPerMonth);
DECLARE @Members int = $(MemberCount), @Branches int = $(BranchCount), @EmpPerBranch int = $(EmployeesPerBranch),
        @Plans int = $(PlanCount), @Products int = $(ProductCount);
DECLARE @SvcShare float = $(ServiceInvoiceShare), @CancelShare float = $(CancelledShare),
        @PendDays int = $(PendingWindowDays), @PendShare float = $(PendingShareInWindow),
        @HeavyMemShare float = $(HeavyMemberShare), @HeavyInvShare float = $(HeavyInvoiceShare),
        @HomeShare float = $(HomeBranchShare), @DiscShare float = $(DiscountLineShare), @PeakShare float = $(PeakShare);
DECLARE @OffsetH int = 7;                                   -- Asia/Ho_Chi_Minh = UTC+07:00
DECLARE @S nvarchar(20) = CONVERT(nvarchar(20), @Seed);
DECLARE @EndLocalDt datetime2(3) = CAST(@EndLocal AS datetime2(3));
DECLARE @PendFrom date = DATEADD(DAY, -@PendDays, @EndLocal);
DECLARE @t0 datetime2(7) = SYSUTCDATETIME(), @t datetime2(7) = SYSUTCDATETIME();

/* ---------- 0. guards ---------- */
IF DB_NAME() NOT LIKE N'FitLife[_]P3[_]%' OR DB_NAME() = N'FitLife_P3_P1'
    THROW 51060, N'S001 runs only in an isolated FitLife_P3_% database other than FitLife_P3_P1.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable'
               AND CONVERT(nvarchar(200), value) LIKE N'WO-P3-P2-01%')
    THROW 51061, N'S001 requires the WO-P3-P2-01 disposable marker.', 1;
IF EXISTS (SELECT 1 FROM dbo.INVOICE) OR EXISTS (SELECT 1 FROM dbo.INVOICE_SERVICE_ITEM)
   OR EXISTS (SELECT 1 FROM dbo.INVOICE_PRODUCT_ITEM) OR EXISTS (SELECT 1 FROM dbo.MEMBER_MONTHLY_SPENDING)
    THROW 51062, N'S001: the P3 tables must be empty (rebuild the database first).', 1;
IF (SELECT COUNT(*) FROM dbo.MEMBER) <> @Members OR (SELECT COUNT(*) FROM dbo.BRANCH) <> @Branches
   OR (SELECT COUNT(*) FROM dbo.EMPLOYEE) <> @Branches * @EmpPerBranch
   OR (SELECT COUNT(*) FROM dbo.SERVICE_PLAN) <> @Plans OR (SELECT COUNT(*) FROM dbo.PRODUCT) <> @Products
    THROW 51063, N'S001: fixture key rows do not match the profile (run F001D with the same profile).', 1;
IF @EndLocal <= @StartLocal OR @InvPerMonth < 1
    THROW 51064, N'S001: invalid date range or volume.', 1;

PRINT 'GENERATOR: ' + @GeneratorVersion + '; seed ' + @S + '; local range [' + CONVERT(char(10), @StartLocal, 23) + ', ' + CONVERT(char(10), @EndLocal, 23) + ')';

/* ---------- 1. calendar and daily volumes ----------
   Day-of-week weights (Mon 1.05, Tue-Thu 1.00, Fri 0.95, Sat 1.05, Sun 0.95). Each calendar
   month receives InvoicesPerMonth x (weight of the generated days / weight of the whole month);
   cumulative rounding makes a complete month exactly InvoicesPerMonth (Phase 1: 900/day x 30). */
CREATE TABLE #day (d date NOT NULL PRIMARY KEY, m date NOT NULL, w decimal(9,4) NOT NULL, cnt int NULL);
INSERT #day (d, m, w)
SELECT x.d, DATEFROMPARTS(YEAR(x.d), MONTH(x.d), 1),
       CASE DATEDIFF(DAY, '19000101', x.d) % 7 WHEN 0 THEN 1.05 WHEN 4 THEN 0.95 WHEN 5 THEN 1.05 WHEN 6 THEN 0.95 ELSE 1.00 END
FROM GENERATE_SERIES(0, DATEDIFF(DAY, @StartLocal, @EndLocal) - 1) AS g
CROSS APPLY (SELECT DATEADD(DAY, g.value, @StartLocal) AS d) AS x
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));

CREATE TABLE #month (m date NOT NULL PRIMARY KEY, W decimal(12,4) NOT NULL);
INSERT #month (m, W)
SELECT mm.m, SUM(CASE DATEDIFF(DAY, '19000101', dd.d) % 7 WHEN 0 THEN 1.05 WHEN 4 THEN 0.95 WHEN 5 THEN 1.05 WHEN 6 THEN 0.95 ELSE 1.00 END)
FROM (SELECT DISTINCT m FROM #day) AS mm
CROSS APPLY GENERATE_SERIES(0, DAY(EOMONTH(mm.m)) - 1) AS g
CROSS APPLY (SELECT DATEADD(DAY, g.value, mm.m) AS d) AS dd
GROUP BY mm.m
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));

WITH e AS (
    SELECT d.d, d.m, CAST(CAST(@InvPerMonth AS decimal(19,6)) * d.w / mo.W AS decimal(19,6)) AS ex
    FROM #day AS d JOIN #month AS mo ON mo.m = d.m),
c AS (
    SELECT d, ex, SUM(ex) OVER (PARTITION BY m ORDER BY d ROWS UNBOUNDED PRECEDING) AS cum FROM e)
UPDATE dd SET cnt = CAST(ROUND(c.cum, 0) - ROUND(c.cum - c.ex, 0) AS int)
FROM #day AS dd JOIN c ON c.d = dd.d
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));

/* ---------- 2. branch weights, members, price lists (seed-side helpers, #temp only) ---------- */
CREATE TABLE #branch (branch_id int NOT NULL PRIMARY KEY, w decimal(9,4) NOT NULL, lo decimal(24,12) NOT NULL, hi decimal(24,12) NOT NULL);
WITH b AS (
    SELECT value AS branch_id,
           CAST(CASE WHEN value <= @Branches / 4 THEN 1.5 WHEN value > @Branches - @Branches / 4 THEN 0.5 ELSE 1.0 END AS decimal(9,4)) AS w
    FROM GENERATE_SERIES(1, @Branches))
INSERT #branch (branch_id, w, lo, hi)
SELECT branch_id, w,
       (SUM(w) OVER (ORDER BY branch_id ROWS UNBOUNDED PRECEDING) - w) / SUM(w) OVER (),
        SUM(w) OVER (ORDER BY branch_id ROWS UNBOUNDED PRECEDING)      / SUM(w) OVER ()
FROM b
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
UPDATE #branch SET hi = 1 WHERE branch_id = @Branches;

CREATE TABLE #mu (member_id int NOT NULL PRIMARY KEY, u1 float NOT NULL, u2 float NOT NULL);
INSERT #mu (member_id, u1, u2)
SELECT m.value, CAST(CAST(SUBSTRING(hh.h, 1, 4) AS bigint) AS float) / 4294967296.0, CAST(CAST(SUBSTRING(hh.h, 5, 4) AS bigint) AS float) / 4294967296.0
FROM GENERATE_SERIES(1, @Members) AS m
CROSS APPLY (SELECT HASHBYTES('SHA2_256', CONCAT(@S, N':member:', m.value)) AS h) AS hh
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));

CREATE TABLE #mem (member_id int NOT NULL PRIMARY KEY, is_heavy bit NOT NULL, home_branch int NOT NULL, grp_rank int NOT NULL,
                   INDEX ux_mem_grp UNIQUE (is_heavy, grp_rank) INCLUDE (home_branch));
INSERT #mem (member_id, is_heavy, home_branch, grp_rank)
SELECT x.member_id, x.is_heavy, x.home_branch, ROW_NUMBER() OVER (PARTITION BY x.is_heavy ORDER BY x.member_id)
FROM (SELECT mu.member_id, CAST(CASE WHEN mu.u1 < @HeavyMemShare THEN 1 ELSE 0 END AS bit) AS is_heavy,
             (SELECT b.branch_id FROM #branch AS b WHERE mu.u2 >= b.lo AND mu.u2 < b.hi) AS home_branch
      FROM #mu AS mu) AS x
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
DECLARE @HeavyN int = (SELECT COUNT(*) FROM #mem WHERE is_heavy = 1),
        @LightN int = (SELECT COUNT(*) FROM #mem WHERE is_heavy = 0);
IF @HeavyN = 0 OR @LightN = 0
    THROW 51065, N'S001: member groups must both be non-empty.', 1;

CREATE TABLE #price (kind char(1) NOT NULL, item_id int NOT NULL, price decimal(18,2) NOT NULL, PRIMARY KEY (kind, item_id));
INSERT #price (kind, item_id, price)        -- service plans: TEST_ONLY price list (DEP-04)
SELECT 'S', g.value,
       CHOOSE(1 + CAST(FLOOR(a.u1 * 8) AS int), 300000, 500000, 800000, 1200000, 1800000, 2500000, 3500000, 6000000)
FROM GENERATE_SERIES(1, @Plans) AS g
CROSS APPLY (SELECT CAST(CAST(SUBSTRING(HASHBYTES('SHA2_256', CONCAT(@S, N':plan-price:', g.value)), 1, 4) AS bigint) AS float) / 4294967296.0 AS u1) AS a;
INSERT #price (kind, item_id, price)        -- products: 20,000-1,500,000 VND, skewed to cheap items (DEP-04)
SELECT 'P', g.value, 1000 * (20 + CAST(ROUND(POWER(CAST(a.u1 AS float), 2) * 1480, 0) AS int))
FROM GENERATE_SERIES(1, @Products) AS g
CROSS APPLY (SELECT CAST(CAST(SUBSTRING(HASHBYTES('SHA2_256', CONCAT(@S, N':product-price:', g.value)), 1, 4) AS bigint) AS float) / 4294967296.0 AS u1) AS a;

PRINT 'TIMING step=calendar_members_prices ms=' + CONVERT(varchar(20), DATEDIFF(MILLISECOND, @t, SYSUTCDATETIME())); SET @t = SYSUTCDATETIME();

/* ---------- 3. invoice headers (in #inv) ---------- */
CREATE TABLE #inv (
    gen_key      varchar(16)  NOT NULL PRIMARY KEY,   -- yyyymmdd:nnnnn (local day, number in day)
    d            date         NOT NULL,
    issued_local datetime2(3) NOT NULL,
    member_id    int          NOT NULL,
    branch_id    int          NOT NULL,
    employee_id  int          NOT NULL,
    inv_type     char(1)      NOT NULL,               -- S = service invoice (1 plan line), P = product invoice
    line_count   int          NOT NULL,
    status       varchar(10)  NOT NULL,
    method       varchar(10)  NULL,
    paid_local   datetime2(3) NULL,
    invoice_id   int          NOT NULL,              -- order of (issued_local, gen_key)
    INDEX ux_inv_id UNIQUE (invoice_id));

-- 3a. one row per invoice with its pseudo-random uniforms (two SHA-256 streams per invoice)
CREATE TABLE #u (
    gen_key varchar(16) NOT NULL PRIMARY KEY, d date NOT NULL,
    u1 float NOT NULL, u2 float NOT NULL, u3 float NOT NULL, u4 float NOT NULL, u5 float NOT NULL, u6 float NOT NULL, u7 float NOT NULL, u8 float NOT NULL,
    v1 float NOT NULL, v2 float NOT NULL, v3 float NOT NULL, v4 float NOT NULL, v5 float NOT NULL, v6 float NOT NULL,
    mem_heavy bit NULL, mem_rank int NULL, other_branch int NULL);
INSERT #u (gen_key, d, u1, u2, u3, u4, u5, u6, u7, u8, v1, v2, v3, v4, v5, v6)
SELECT k.gen_key, dd.d,
       CAST(CAST(SUBSTRING(hh.h1, 1, 4) AS bigint) AS float) / 4294967296.0,
       CAST(CAST(SUBSTRING(hh.h1, 5, 4) AS bigint) AS float) / 4294967296.0,
       CAST(CAST(SUBSTRING(hh.h1, 9, 4) AS bigint) AS float) / 4294967296.0,
       CAST(CAST(SUBSTRING(hh.h1, 13, 4) AS bigint) AS float) / 4294967296.0,
       CAST(CAST(SUBSTRING(hh.h1, 17, 4) AS bigint) AS float) / 4294967296.0,
       CAST(CAST(SUBSTRING(hh.h1, 21, 4) AS bigint) AS float) / 4294967296.0,
       CAST(CAST(SUBSTRING(hh.h1, 25, 4) AS bigint) AS float) / 4294967296.0,
       CAST(CAST(SUBSTRING(hh.h1, 29, 4) AS bigint) AS float) / 4294967296.0,
       CAST(CAST(SUBSTRING(hh.h2, 1, 4) AS bigint) AS float) / 4294967296.0,
       CAST(CAST(SUBSTRING(hh.h2, 5, 4) AS bigint) AS float) / 4294967296.0,
       CAST(CAST(SUBSTRING(hh.h2, 9, 4) AS bigint) AS float) / 4294967296.0,
       CAST(CAST(SUBSTRING(hh.h2, 13, 4) AS bigint) AS float) / 4294967296.0,
       CAST(CAST(SUBSTRING(hh.h2, 17, 4) AS bigint) AS float) / 4294967296.0,
       CAST(CAST(SUBSTRING(hh.h2, 21, 4) AS bigint) AS float) / 4294967296.0
FROM #day AS dd
CROSS APPLY GENERATE_SERIES(1, dd.cnt) AS g
CROSS APPLY (SELECT CONCAT(CONVERT(char(8), dd.d, 112), ':', RIGHT(CONCAT('00000', g.value), 5)) AS gen_key) AS k
CROSS APPLY (SELECT HASHBYTES('SHA2_256', CONCAT(@S, N':inv1:', k.gen_key)) AS h1,
                    HASHBYTES('SHA2_256', CONCAT(@S, N':inv2:', k.gen_key)) AS h2) AS hh
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));

-- 3b. member group and rank (HeavyInvoiceShare of invoices from the heavy group), weighted branch for non-home purchases
UPDATE #u
SET mem_heavy = CASE WHEN u3 < @HeavyInvShare THEN 1 ELSE 0 END,
    mem_rank  = 1 + CAST(FLOOR(u4 * CASE WHEN u3 < @HeavyInvShare THEN @HeavyN ELSE @LightN END) AS int),
    other_branch = (SELECT b.branch_id FROM #branch AS b WHERE u6 >= b.lo AND u6 < b.hi)
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));

-- 3c. headers
INSERT #inv (gen_key, d, issued_local, member_id, branch_id, employee_id, inv_type, line_count, status, method, paid_local, invoice_id)
SELECT x.*, ROW_NUMBER() OVER (ORDER BY x.issued_local, x.gen_key)
FROM (
SELECT u.gen_key, u.d, ti.issued_local, mem.member_id, br.branch_id,
       (br.branch_id - 1) * @EmpPerBranch + 1 + CAST(FLOOR(u.u7 * @EmpPerBranch) AS int) AS employee_id,
       ty.inv_type,
       CASE WHEN ty.inv_type = 'S' THEN 1
            WHEN u.v6 < 0.20 THEN 1 WHEN u.v6 < 0.45 THEN 2 WHEN u.v6 < 0.70 THEN 3 WHEN u.v6 < 0.90 THEN 4 ELSE 5 END AS line_count,
       st.status,
       CASE WHEN st.status = 'PAID' THEN CASE WHEN u.v3 < 0.40 THEN 'CASH' WHEN u.v3 < 0.75 THEN 'VNPAY' ELSE 'CARD' END END AS method,
       CASE WHEN st.status = 'PAID' THEN pd.paid0 END AS paid_local
FROM #u AS u
JOIN #mem AS mem ON mem.is_heavy = u.mem_heavy AND mem.grp_rank = u.mem_rank
-- time of day (local): PeakShare in 17:00-20:00, the rest uniform over opening hours 06:00-22:00
CROSS APPLY (SELECT DATEADD(MILLISECOND,
                    CAST(CASE WHEN u.u1 < @PeakShare THEN 39600000 + FLOOR(u.u2 * 10800000) ELSE FLOOR(u.u2 * 57600000) END AS int),
                    DATEADD(HOUR, 6, CAST(u.d AS datetime2(3)))) AS issued_local) AS ti
-- branch: the member's home branch with HomeBranchShare, otherwise a weighted branch
CROSS APPLY (SELECT CASE WHEN u.u5 < @HomeShare THEN mem.home_branch ELSE u.other_branch END AS branch_id) AS br
CROSS APPLY (SELECT CASE WHEN u.u8 < @SvcShare THEN 'S' ELSE 'P' END AS inv_type) AS ty
-- payment delay: 90% 1-15 min, 8% 15-120 min, 2% 4-12 h (crosses midnight)
CROSS APPLY (SELECT DATEADD(MILLISECOND,
                    CAST(CASE WHEN u.v4 < 0.90 THEN 60000 + FLOOR(u.v5 * 840000)
                              WHEN u.v4 < 0.98 THEN 900000 + FLOOR(u.v5 * 6300000)
                              ELSE 14400000 + FLOOR(u.v5 * 28800000) END AS int),
                    ti.issued_local) AS paid0) AS pd
-- status: CancelledShare cancelled; PendingShareInWindow of the last PendingWindowDays days still pending;
-- an invoice whose payment would fall after the dataset end is also still pending
CROSS APPLY (SELECT CASE WHEN u.v1 < @CancelShare THEN 'CANCELLED'
                         WHEN u.d >= @PendFrom AND u.v2 < @PendShare THEN 'PENDING'
                         WHEN pd.paid0 >= @EndLocalDt THEN 'PENDING'
                         ELSE 'PAID' END AS status) AS st
) AS x
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
IF (SELECT COUNT(*) FROM #inv) <> (SELECT COUNT(*) FROM #u)
    THROW 51066, N'S001: member assignment lost invoices.', 1;

/* Deliberate local-calendar boundary rows: for every month boundary B inside the range, the last
   three PAID invoices issued on the day before B are paid at B - 1 ms (23:59:59.999 local, old month),
   exactly B (00:00:00.000 local, new month) and B + 03:30 (local 1st, while UTC is still the previous
   day). At the range end only the B - 1 ms row is set. */
CREATE TABLE #boundary (b date NOT NULL PRIMARY KEY, is_end bit NOT NULL);
INSERT #boundary (b, is_end)
SELECT DISTINCT DATEADD(MONTH, 1, m), CASE WHEN DATEADD(MONTH, 1, m) = @EndLocal THEN 1 ELSE 0 END
FROM #day
WHERE DATEADD(MONTH, 1, m) <= @EndLocal AND DATEADD(MONTH, 1, m) > @StartLocal
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));

WITH c AS (
    SELECT i.paid_local, bd.b, bd.is_end,
           ROW_NUMBER() OVER (PARTITION BY bd.b ORDER BY i.issued_local DESC, i.gen_key DESC) AS rn
    FROM #inv AS i JOIN #boundary AS bd ON i.d = DATEADD(DAY, -1, bd.b)
    WHERE i.status = 'PAID')
UPDATE c
SET paid_local = CASE rn WHEN 1 THEN DATEADD(MILLISECOND, -1, CAST(b AS datetime2(3)))
                         WHEN 2 THEN CAST(b AS datetime2(3))
                         ELSE DATEADD(MINUTE, 210, CAST(b AS datetime2(3))) END
WHERE rn = 1 OR (rn IN (2, 3) AND is_end = 0)
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));


PRINT 'TIMING step=invoice_headers ms=' + CONVERT(varchar(20), DATEDIFF(MILLISECOND, @t, SYSUTCDATETIME())); SET @t = SYSUTCDATETIME();

/* ---------- 4. invoice lines (in #line) ---------- */
CREATE TABLE #lu (
    invoice_id int NOT NULL, line_no smallint NOT NULL, kind char(1) NOT NULL, item_id int NOT NULL, qty int NOT NULL,
    u3 float NOT NULL, u4 float NOT NULL, PRIMARY KEY (invoice_id, line_no));
INSERT #lu (invoice_id, line_no, kind, item_id, qty, u3, u4)
SELECT i.invoice_id, CAST(g.value AS smallint), i.inv_type,
       -- popularity skew: item = 1 + floor(count x u^1.6)
       1 + CAST(FLOOR(CASE WHEN i.inv_type = 'S' THEN @Plans ELSE @Products END * POWER(a.u1, 1.6)) AS int),
       CASE WHEN i.inv_type = 'S' THEN 1
            WHEN a.u2 < 0.70 THEN 1 WHEN a.u2 < 0.90 THEN 2 WHEN a.u2 < 0.97 THEN 3 WHEN a.u2 < 0.99 THEN 4 ELSE 5 END,
       a.u3, a.u4
FROM #inv AS i
CROSS APPLY GENERATE_SERIES(1, i.line_count) AS g
CROSS APPLY (SELECT HASHBYTES('SHA2_256', CONCAT(@S, N':line:', i.gen_key, N':', g.value)) AS h) AS lh
CROSS APPLY (SELECT CAST(CAST(SUBSTRING(lh.h, 1, 4) AS bigint) AS float) / 4294967296.0 AS u1,
                    CAST(CAST(SUBSTRING(lh.h, 5, 4) AS bigint) AS float) / 4294967296.0 AS u2,
                    CAST(CAST(SUBSTRING(lh.h, 9, 4) AS bigint) AS float) / 4294967296.0 AS u3,
                    CAST(CAST(SUBSTRING(lh.h, 13, 4) AS bigint) AS float) / 4294967296.0 AS u4) AS a
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));

CREATE TABLE #line (
    invoice_id int NOT NULL, line_no smallint NOT NULL, kind char(1) NOT NULL, item_id int NOT NULL,
    qty int NOT NULL, unit_price decimal(18,2) NOT NULL, discount decimal(18,2) NOT NULL,
    PRIMARY KEY (invoice_id, line_no));
-- DiscountLineShare of lines discounted by 5, 10, 15 or 20 % (rounded to whole VND)
INSERT #line (invoice_id, line_no, kind, item_id, qty, unit_price, discount)
SELECT l.invoice_id, l.line_no, l.kind, l.item_id, l.qty, p.price,
       CASE WHEN l.u3 < @DiscShare THEN ROUND(p.price * l.qty * (5 * (1 + CAST(FLOOR(l.u4 * 4) AS int))) / 100, 0) ELSE 0 END
FROM #lu AS l JOIN #price AS p ON p.kind = l.kind AND p.item_id = l.item_id
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
IF (SELECT COUNT(*) FROM #line) <> (SELECT COUNT(*) FROM #lu)
    THROW 51067, N'S001: price lookup lost lines.', 1;

PRINT 'TIMING step=invoice_lines ms=' + CONVERT(varchar(20), DATEDIFF(MILLISECOND, @t, SYSUTCDATETIME())); SET @t = SYSUTCDATETIME();

/* ---------- 5. load the P3 tables (header totals from the lines, D-023; UTC storage, D-014) ---------- */
SET IDENTITY_INSERT dbo.INVOICE ON;
INSERT dbo.INVOICE WITH (TABLOCK)
       (Invoice_ID, Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount, PaymentMethod, PaymentStatus, PaidAt)
SELECT i.invoice_id, i.member_id, i.employee_id, i.branch_id, DATEADD(HOUR, -@OffsetH, i.issued_local),
       t.gross, t.disc, t.gross - t.disc,
       CASE WHEN i.status = 'PAID' THEN i.method END, i.status,
       CASE WHEN i.status = 'PAID' THEN DATEADD(HOUR, -@OffsetH, i.paid_local) END
FROM #inv AS i
JOIN (SELECT invoice_id, SUM(unit_price * qty) AS gross, SUM(discount) AS disc FROM #line GROUP BY invoice_id) AS t
  ON t.invoice_id = i.invoice_id
ORDER BY i.invoice_id
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
SET IDENTITY_INSERT dbo.INVOICE OFF;

INSERT dbo.INVOICE_SERVICE_ITEM WITH (TABLOCK) (Invoice_ID, [LineNo], Plan_ID, UnitPrice, DiscountAmount)
SELECT invoice_id, line_no, item_id, unit_price, discount FROM #line WHERE kind = 'S' ORDER BY invoice_id, line_no
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));
-- ValidFrom, ValidUntil, PTSessionsRemaining stay NULL: written by other members (DEP-06)

INSERT dbo.INVOICE_PRODUCT_ITEM WITH (TABLOCK) (Invoice_ID, [LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount)
SELECT invoice_id, line_no, item_id, qty, unit_price, discount FROM #line WHERE kind = 'P' ORDER BY invoice_id, line_no
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));

PRINT 'TIMING step=load_invoice_tables ms=' + CONVERT(varchar(20), DATEDIFF(MILLISECOND, @t, SYSUTCDATETIME())); SET @t = SYSUTCDATETIME();

/* ---------- 6. derived monthly spending (D-006, D-013) ----------
   Only PAID invoices count; SpendingMonth = first day of the Asia/Ho_Chi_Minh month of PaidAt;
   PointsEarned = FLOOR(TotalSpend / 100000) per member and month (residual spending below
   100,000 VND does not carry over to the next month); UpdatedAt = the last PaidAt of the group
   (a data value, so the dataset stays reproducible). */
INSERT dbo.MEMBER_MONTHLY_SPENDING WITH (TABLOCK) (Member_ID, SpendingMonth, TotalSpend, PointsEarned, UpdatedAt)
SELECT x.Member_ID, x.SpendingMonth, SUM(x.FinalAmount), CAST(FLOOR(SUM(x.FinalAmount) / 100000) AS int), MAX(x.PaidAt)
FROM (SELECT iv.Member_ID, iv.FinalAmount, iv.PaidAt, DATEFROMPARTS(YEAR(l.loc), MONTH(l.loc), 1) AS SpendingMonth
      FROM dbo.INVOICE AS iv
      CROSS APPLY (SELECT DATEADD(HOUR, @OffsetH, iv.PaidAt) AS loc) AS l
      WHERE iv.PaymentStatus = 'PAID') AS x
GROUP BY x.Member_ID, x.SpendingMonth
ORDER BY x.Member_ID, x.SpendingMonth
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));

PRINT 'TIMING step=monthly_spending ms=' + CONVERT(varchar(20), DATEDIFF(MILLISECOND, @t, SYSUTCDATETIME())); SET @t = SYSUTCDATETIME();

/* Statistics are not updated here: WO-P3-P2-02 updates them WITH FULLSCAN per configuration
   (10 section 4.3 step 2). No index is created. */
PRINT 'TIMING step=total_generator ms=' + CONVERT(varchar(20), DATEDIFF(MILLISECOND, @t0, SYSUTCDATETIME()));

SELECT (SELECT COUNT(*) FROM dbo.INVOICE) AS invoice_rows,
       (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM) AS service_item_rows,
       (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM) AS product_item_rows,
       (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING) AS monthly_spending_rows;
PRINT 'GENERATOR_RESULT: OK';
GO
