/* =====================================================================
   T-F05L_loyalty_tiers.sql - TEST_ONLY (sqlcmd mode)
   Work order : WO-P3-P3-02 (loyalty lookup F21, periodic tier evaluation F22). Functional only (no timing).
     T-F05-12  Silver/Gold/Platinum selection at exact boundaries (threshold - 0.01, =, + 0.01; spend 0);
               upgrade after accumulated spending, visible only after the next batch (D-009 (a) latency)
     T-F05-13  window expiry: spending of the oldest window month counts through the last day of the
               current month and leaves on the 1st of the next month - downgrade WITHOUT any payment;
               December/January boundary (no 1 January reset)
     T-F05-14  re-running the batch for the same date changes nothing
     T-F05-15  loyalty lookup = oracle (points, stored and evaluated tier, window spend, gap to next tier)
     T-F05-32  many small invoices in one month: 25 x 4,000 VND -> 0 points until the 25th, then 1
     T-F05-33  payments at 16:59:59.999 / 17:00:00.000 UTC on 31 Dec fall into December / January
     T-F05-34  failure inside a batch chunk: that chunk and later chunks unchanged, earlier chunks kept,
               error passed through; a re-run completes and equals the independent oracle
     T-F05-35  invalid tier configuration (second base tier; duplicate threshold) -> error, nothing written
   Members 11-20 (they have no PAID invoice when this script starts). Past months come from the TEST_ONLY
   helper TEST_p3_AddPaidHistory (settlement always uses the server time, DEP-17). Thresholds are read from
   MEMBER_TIER (TEST_ONLY synthetic values); nothing is hard-coded.
   Run: sqlcmd -S localhost -E -I -b -W -d FitLife_P3_UC05 -i tests/db/functional/T-F05L_loyalty_tiers.sql
   ===================================================================== */
:on error exit
SET NOCOUNT ON;
SET XACT_ABORT OFF;

IF DB_NAME() <> N'FitLife_P3_UC05'
   OR NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable' AND CONVERT(nvarchar(200), value) LIKE N'WO-P3-P3-00%')
    THROW 51290, N'T-F05L runs only in FitLife_P3_UC05 with the disposable marker.', 1;
IF OBJECT_ID(N'dbo.usp_P3_EvaluateTiers', N'P') IS NULL OR OBJECT_ID(N'dbo.usp_P3_GetMemberLoyalty', N'P') IS NULL OR OBJECT_ID(N'dbo.TEST_p3_AddPaidHistory', N'P') IS NULL
    THROW 51291, N'T-F05L: loyalty routines or F003H not deployed.', 1;
IF EXISTS (SELECT 1 FROM dbo.INVOICE WHERE Member_ID BETWEEN 11 AND 20 AND PaymentStatus = 'PAID') OR EXISTS (SELECT 1 FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID BETWEEN 11 AND 20)
   OR EXISTS (SELECT 1 FROM dbo.MEMBER WHERE Member_ID BETWEEN 11 AND 20 AND CurrentPoints <> 0)
    THROW 51292, N'T-F05L expects members 11-20 without PAID invoices, spending or points.', 1;
IF MONTH(DATEADD(MINUTE, 5, DATEADD(HOUR, 7, SYSUTCDATETIME()))) <> MONTH(DATEADD(HOUR, 7, SYSUTCDATETIME()))
    THROW 51293, N'T-F05L: too close to a local month boundary; run again in a few minutes.', 1;

DECLARE @results TABLE (seq int IDENTITY(1,1), case_id varchar(8), test_id varchar(10), result varchar(4), descr nvarchar(300), detail nvarchar(2000));
DECLARE @tierq nvarchar(max) = N'SELECT @h = CONVERT(varchar(64), HASHBYTES(''SHA2_256'', (SELECT STRING_AGG(CONVERT(varchar(max), CONCAT(Member_ID, '':'', Tier_ID, '':'', CurrentPoints)), '','') WITHIN GROUP (ORDER BY Member_ID) FROM dbo.MEMBER)), 2);';
DECLARE @silver int = (SELECT Tier_ID FROM dbo.MEMBER_TIER WHERE SpendingThreshold = 0);
DECLARE @gold int = (SELECT Tier_ID FROM dbo.MEMBER_TIER WHERE Tier_Name = N'Gold'), @plat int = (SELECT Tier_ID FROM dbo.MEMBER_TIER WHERE Tier_Name = N'Platinum');
DECLARE @goldT decimal(18,2) = (SELECT SpendingThreshold FROM dbo.MEMBER_TIER WHERE Tier_ID = @gold), @platT decimal(18,2) = (SELECT SpendingThreshold FROM dbo.MEMBER_TIER WHERE Tier_ID = @plat);
DECLARE @today date = CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS date);
DECLARE @m0 date = DATEFROMPARTS(YEAR(@today), MONTH(@today), 1);
DECLARE @e int, @u int, @d int, @n int, @err int, @emsg nvarchar(2048), @ok bit, @hB varchar(64), @hA varchar(64), @hid int, @amt decimal(18,2), @at datetime2(3), @asof date;
DECLARE @prd dbo.tt_P3_InvoiceProductLine, @svc dbo.tt_P3_InvoiceServiceLine, @inv int, @co varchar(20), @outc varchar(20), @pe int, @cp int, @i int, @peList varchar(200);
PRINT CONCAT('Today (local) ', CONVERT(varchar(10), @today, 23), '; tiers (Gold/Platinum TEST_ONLY synthetic): Silver 0, Gold ', @goldT, ', Platinum ', @platT);

/* expected tier for an amount, from MEMBER_TIER (test oracle of the D-008 rule) */
DECLARE @exp TABLE (Member_ID int PRIMARY KEY, Amount decimal(18,2) NULL, ExpTier int NULL);

/* ---------- L01 T-F05-12: selection at exact boundaries ---------- */
SET @at = DATEADD(HOUR, 3, DATEADD(DAY, 14, CAST(DATEADD(MONTH, -1, @m0) AS datetime2(3))));   -- 15th of the previous local month, 10:00 local
INSERT @exp (Member_ID, Amount) VALUES (12, NULL), (13, @goldT - 0.01), (14, @goldT), (15, @goldT + 0.01), (16, @platT - 0.01), (17, @platT), (18, @platT + 1000);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT Member_ID, Amount FROM @exp WHERE Amount IS NOT NULL;
OPEN c; FETCH NEXT FROM c INTO @i, @amt;
WHILE @@FETCH_STATUS = 0 BEGIN EXEC dbo.TEST_p3_AddPaidHistory @Member_ID = @i, @PaidAtUtc = @at, @Amount = @amt, @Invoice_ID = @hid OUTPUT; FETCH NEXT FROM c INTO @i, @amt; END;
CLOSE c; DEALLOCATE c;
UPDATE x SET ExpTier = (SELECT TOP (1) t.Tier_ID FROM dbo.MEMBER_TIER AS t WHERE t.SpendingThreshold <= ISNULL(x.Amount, 0) ORDER BY t.SpendingThreshold DESC) FROM @exp AS x;
SELECT @err = 0, @emsg = N'';
BEGIN TRY EXEC dbo.usp_P3_EvaluateTiers @AsOfDate = @today, @Evaluated = @e OUTPUT, @Upgrades = @u OUTPUT, @Downgrades = @d OUTPUT, @Unchanged = @n OUTPUT; END TRY
BEGIN CATCH SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE(); END CATCH;
SET @n = (SELECT COUNT(*) FROM @exp AS x JOIN dbo.MEMBER AS m ON m.Member_ID = x.Member_ID WHERE m.Tier_ID <> x.ExpTier);
INSERT @results VALUES ('L01', 'T-F05-12', CASE WHEN @err = 0 AND @n = 0 AND (SELECT ExpTier FROM @exp WHERE Member_ID = 12) = @silver AND (SELECT ExpTier FROM @exp WHERE Member_ID = 13) = @silver
                                              AND (SELECT ExpTier FROM @exp WHERE Member_ID = 14) = @gold AND (SELECT ExpTier FROM @exp WHERE Member_ID = 16) = @gold
                                              AND (SELECT ExpTier FROM @exp WHERE Member_ID = 17) = @plat THEN 'PASS' ELSE 'FAIL' END,
    N'Tier selection: spend 0 -> Silver; Gold - 0.01 -> Silver; = Gold -> Gold; Gold + 0.01 -> Gold; Platinum - 0.01 -> Gold; = Platinum -> Platinum; above -> Platinum (inclusive, highest eligible)',
    CONCAT(N'error ', @err, N' ', LEFT(@emsg, 120), N'; batch evaluated ', @e, N', upgrades ', @u, N', downgrades ', @d, N'; members 12-18 with a wrong tier: ', @n,
           N'; tiers 12..18 = ', (SELECT STRING_AGG(CONVERT(varchar(4), Tier_ID), ',') WITHIN GROUP (ORDER BY Member_ID) FROM dbo.MEMBER WHERE Member_ID BETWEEN 12 AND 18)));

/* ---------- L02 T-F05-14: re-run for the same date changes nothing ---------- */
EXEC sys.sp_executesql @tierq, N'@h varchar(64) OUTPUT', @h = @hB OUTPUT;
EXEC dbo.usp_P3_EvaluateTiers @AsOfDate = @today, @Evaluated = @e OUTPUT, @Upgrades = @u OUTPUT, @Downgrades = @d OUTPUT, @Unchanged = @n OUTPUT;
EXEC sys.sp_executesql @tierq, N'@h varchar(64) OUTPUT', @h = @hA OUTPUT;
INSERT @results VALUES ('L02', 'T-F05-14', CASE WHEN @u = 0 AND @d = 0 AND @n = @e AND @hB = @hA THEN 'PASS' ELSE 'FAIL' END,
    N'Second run for the same evaluation date: 0 upgrades, 0 downgrades, every member unchanged, no row written',
    CONCAT(N'evaluated ', @e, N'; upgrades ', @u, N'; downgrades ', @d, N'; unchanged ', @n, N'; tier/points state changed ', CASE WHEN @hB <> @hA THEN N'yes' ELSE N'no' END));

/* ---------- L03 T-F05-12: upgrade after accumulated spending, visible after the next batch ---------- */
DELETE @prd; INSERT @prd VALUES (1, 1, 1, 0.01, 0);
EXEC dbo.usp_P3_CreateInvoice @Member_ID = 13, @Employee_ID = 1, @Branch_ID = 1, @ServiceLines = @svc, @ProductLines = @prd, @Invoice_ID = @inv OUTPUT, @Outcome = @co OUTPUT;
EXEC dbo.usp_P3_SettleInvoice @Invoice_ID = @inv, @PaymentMethod = 'CASH', @Outcome = @outc OUTPUT;
DECLARE @tierAfterSettle int = (SELECT Tier_ID FROM dbo.MEMBER WHERE Member_ID = 13);
EXEC dbo.usp_P3_EvaluateTiers @AsOfDate = @today, @Evaluated = @e OUTPUT, @Upgrades = @u OUTPUT, @Downgrades = @d OUTPUT, @Unchanged = @n OUTPUT;
INSERT @results VALUES ('L03', 'T-F05-12', CASE WHEN @outc = 'SETTLED' AND @tierAfterSettle = @silver AND (SELECT Tier_ID FROM dbo.MEMBER WHERE Member_ID = 13) = @gold AND @u = 1 AND @d = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Member at Gold - 0.01 pays 0.01 (this month): still Silver right after settlement (accepted D-009 (a) latency); the next batch upgrades exactly this member to Gold',
    CONCAT(N'settlement ', ISNULL(@outc, '-'), N'; tier after settlement ', @tierAfterSettle, N'; tier after batch ', (SELECT Tier_ID FROM dbo.MEMBER WHERE Member_ID = 13), N'; batch upgrades ', @u, N', downgrades ', @d));

/* ---------- L04 T-F05-13: window expiry, downgrade without payment ---------- */
SET @at = DATEADD(HOUR, 3, DATEADD(DAY, 4, CAST(DATEADD(MONTH, -11, @m0) AS datetime2(3))));   -- 5th of the oldest window month, 10:00 local
EXEC dbo.TEST_p3_AddPaidHistory @Member_ID = 19, @PaidAtUtc = @at, @Amount = @platT, @Invoice_ID = @hid OUTPUT;
DECLARE @t1 int, @t2 int, @t3 int, @d3 int, @t4 int;
EXEC dbo.usp_P3_EvaluateTiers @AsOfDate = @today, @Evaluated = @e OUTPUT, @Upgrades = @u OUTPUT, @Downgrades = @d OUTPUT, @Unchanged = @n OUTPUT;
SET @t1 = (SELECT Tier_ID FROM dbo.MEMBER WHERE Member_ID = 19);
SET @asof = EOMONTH(@today);
EXEC dbo.usp_P3_EvaluateTiers @AsOfDate = @asof, @Evaluated = @e OUTPUT, @Upgrades = @u OUTPUT, @Downgrades = @d OUTPUT, @Unchanged = @n OUTPUT;
SET @t2 = (SELECT Tier_ID FROM dbo.MEMBER WHERE Member_ID = 19);
SET @asof = DATEADD(DAY, 1, EOMONTH(@today));
EXEC dbo.usp_P3_EvaluateTiers @AsOfDate = @asof, @Evaluated = @e OUTPUT, @Upgrades = @u OUTPUT, @Downgrades = @d3 OUTPUT, @Unchanged = @n OUTPUT;
SET @t3 = (SELECT Tier_ID FROM dbo.MEMBER WHERE Member_ID = 19);
EXEC dbo.usp_P3_EvaluateTiers @AsOfDate = @today, @Evaluated = @e OUTPUT, @Upgrades = @u OUTPUT, @Downgrades = @d OUTPUT, @Unchanged = @n OUTPUT;
SET @t4 = (SELECT Tier_ID FROM dbo.MEMBER WHERE Member_ID = 19);
INSERT @results VALUES ('L04', 'T-F05-13', CASE WHEN @t1 = @plat AND @t2 = @plat AND @t3 = @silver AND @d3 >= 1 AND @t4 = @plat
                                                   AND NOT EXISTS (SELECT 1 FROM dbo.INVOICE WHERE Member_ID = 19 AND PaidAt > @at) THEN 'PASS' ELSE 'FAIL' END,
    N'Platinum-level spend in the oldest window month: Platinum today and on the last day of this month; on the 1st of next month it leaves the window -> Silver with NO payment; re-evaluating today restores Platinum',
    CONCAT(N'payment month ', CONVERT(varchar(10), DATEADD(MONTH, -11, @m0), 23), N'; tier today ', @t1, N'; on ', CONVERT(varchar(10), EOMONTH(@today), 23), N' ', @t2,
           N'; on ', CONVERT(varchar(10), DATEADD(DAY, 1, EOMONTH(@today)), 23), N' ', @t3, N' (batch downgrades ', @d3, N'); today again ', @t4));

/* ---------- L05 T-F05-33 + T-F05-13: December/January ---------- */
SET @at = '2025-12-31T16:59:59.999';   -- 31 Dec 2025 23:59:59.999 local
EXEC dbo.TEST_p3_AddPaidHistory @Member_ID = 20, @PaidAtUtc = @at, @Amount = @goldT, @Invoice_ID = @hid OUTPUT;
SET @at = '2025-12-31T17:00:00.000';   -- 1 Jan 2026 00:00:00.000 local
EXEC dbo.TEST_p3_AddPaidHistory @Member_ID = 20, @PaidAtUtc = @at, @Amount = @goldT, @Invoice_ID = @hid OUTPUT;
SET @ok = CASE WHEN (SELECT TotalSpend FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = 20 AND SpendingMonth = '2025-12-01') = @goldT
                AND (SELECT TotalSpend FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = 20 AND SpendingMonth = '2026-01-01') = @goldT
                AND (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = 20) = 2 THEN 1 ELSE 0 END;
INSERT @results VALUES ('L05a', 'T-F05-33', CASE WHEN @ok = 1 THEN 'PASS' ELSE 'FAIL' END,
    N'Payment at 2025-12-31 16:59:59.999 UTC -> December 2025 row; at 17:00:00.000 UTC (= 1 Jan 00:00 local) -> January 2026 row (same month function as settlement)',
    CONCAT(N'rows of member 20: ', (SELECT STRING_AGG(CONCAT(CONVERT(varchar(10), SpendingMonth, 23), '=', TotalSpend), '; ') FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = 20)));
DECLARE @x1 int, @x2 int, @x3 int, @exp1 int, @exp2 int;
SET @amt = 2 * @goldT;
SET @exp1 = (SELECT TOP (1) Tier_ID FROM dbo.MEMBER_TIER WHERE SpendingThreshold <= @amt ORDER BY SpendingThreshold DESC);
SET @exp2 = (SELECT TOP (1) Tier_ID FROM dbo.MEMBER_TIER WHERE SpendingThreshold <= @goldT ORDER BY SpendingThreshold DESC);
SET @asof = '2026-11-30'; EXEC dbo.usp_P3_EvaluateTiers @AsOfDate = @asof; SET @x1 = (SELECT Tier_ID FROM dbo.MEMBER WHERE Member_ID = 20);
SET @asof = '2026-12-01'; EXEC dbo.usp_P3_EvaluateTiers @AsOfDate = @asof; SET @x2 = (SELECT Tier_ID FROM dbo.MEMBER WHERE Member_ID = 20);
SET @asof = '2027-01-01'; EXEC dbo.usp_P3_EvaluateTiers @AsOfDate = @asof; SET @x3 = (SELECT Tier_ID FROM dbo.MEMBER WHERE Member_ID = 20);
INSERT @results VALUES ('L05b', 'T-F05-13', CASE WHEN @x1 = @exp1 AND @x2 = @exp2 AND @x3 = @silver THEN 'PASS' ELSE 'FAIL' END,
    N'December/January: as of 2026-11-30 (Dec 2025..Nov 2026) both payments count; 2026-12-01 (Jan..Dec 2026) only January; 2027-01-01 (Feb 2026..Jan 2027) none -> Silver; no 1 January reset of the window itself',
    CONCAT(N'tiers: ', @x1, N' (expected ', @exp1, N'), ', @x2, N' (expected ', @exp2, N'), ', @x3, N' (expected ', @silver, N')'));
-- note: the batch just ran as of 2027-01-01; L09 relies on that state.

/* ---------- L09 T-F05-34: failure inside a batch chunk ---------- */
SET @asof = '2026-11-30'; EXEC dbo.usp_P3_EvaluateTiers @AsOfDate = @asof;   -- members 19 and 20 back to their November tiers
DECLARE @b19 int = (SELECT Tier_ID FROM dbo.MEMBER WHERE Member_ID = 19), @b20 int = (SELECT Tier_ID FROM dbo.MEMBER WHERE Member_ID = 20);
DECLARE @after21 varchar(64), @before21 varchar(64);
SET @before21 = CONVERT(varchar(64), HASHBYTES('SHA2_256', (SELECT STRING_AGG(CONVERT(varchar(max), CONCAT(Member_ID, ':', Tier_ID)), ',') WITHIN GROUP (ORDER BY Member_ID) FROM dbo.MEMBER WHERE Member_ID > 20)), 2);
EXEC (N'CREATE TRIGGER dbo.TEST_trg_FailTierChunk ON dbo.MEMBER AFTER UPDATE AS BEGIN SET NOCOUNT ON; IF UPDATE(Tier_ID) AND EXISTS (SELECT 1 FROM inserted WHERE Member_ID = 20) THROW 52930, N''TEST_ONLY injected failure in the batch chunk of member 20.'', 1; END');
SELECT @err = 0, @emsg = N''; SET @asof = '2027-01-01';
BEGIN TRY EXEC dbo.usp_P3_EvaluateTiers @AsOfDate = @asof, @ChunkSize = 1; END TRY
BEGIN CATCH SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE(); IF XACT_STATE() <> 0 ROLLBACK; END CATCH;
DROP TRIGGER dbo.TEST_trg_FailTierChunk;
SET @after21 = CONVERT(varchar(64), HASHBYTES('SHA2_256', (SELECT STRING_AGG(CONVERT(varchar(max), CONCAT(Member_ID, ':', Tier_ID)), ',') WITHIN GROUP (ORDER BY Member_ID) FROM dbo.MEMBER WHERE Member_ID > 20)), 2);
DECLARE @f19 int = (SELECT Tier_ID FROM dbo.MEMBER WHERE Member_ID = 19), @f20 int = (SELECT Tier_ID FROM dbo.MEMBER WHERE Member_ID = 20);
SET @ok = CASE WHEN @err = 52930 AND @@TRANCOUNT = 0 AND @b19 <> @silver AND @f19 = @silver AND @f20 = @b20 AND @after21 = @before21 THEN 1 ELSE 0 END;
-- re-run completes; compare every member with an independent oracle from INVOICE for 2027-01-01
EXEC dbo.usp_P3_EvaluateTiers @AsOfDate = @asof, @ChunkSize = 1;
WITH paid AS (SELECT i.Member_ID, i.FinalAmount, DATEFROMPARTS(YEAR(l.loc), MONTH(l.loc), 1) AS lm
              FROM dbo.INVOICE AS i CROSS APPLY (SELECT CONVERT(datetime2(3), (i.PaidAt AT TIME ZONE 'UTC') AT TIME ZONE 'SE Asia Standard Time') AS loc) AS l
              WHERE i.PaymentStatus = 'PAID'),
     sp AS (SELECT m.Member_ID, ISNULL((SELECT SUM(p.FinalAmount) FROM paid AS p WHERE p.Member_ID = m.Member_ID AND p.lm BETWEEN '2026-02-01' AND '2027-01-01'), 0) AS s FROM dbo.MEMBER AS m)
SELECT @n = COUNT(*) FROM sp JOIN dbo.MEMBER AS m ON m.Member_ID = sp.Member_ID
WHERE m.Tier_ID <> (SELECT TOP (1) t.Tier_ID FROM dbo.MEMBER_TIER AS t WHERE t.SpendingThreshold <= sp.s ORDER BY t.SpendingThreshold DESC);
INSERT @results VALUES ('L09', 'T-F05-34', CASE WHEN @ok = 1 AND @n = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Failure injected in the chunk of member 20 (chunk size 1): earlier chunk (member 19) committed correctly, member 20 and all later members unchanged, error passed through, no open transaction; the re-run completes and every member equals the independent oracle',
    CONCAT(N'error ', @err, N' (', LEFT(@emsg, 90), N'); member 19 ', @b19, N'->', @f19, N'; member 20 ', @b20, N'->', @f20, N' (unchanged); members > 20 unchanged: ',
           CASE WHEN @after21 = @before21 THEN N'yes' ELSE N'NO' END, N'; after re-run, members with a wrong tier: ', @n));

/* ---------- L08 T-F05-35: invalid tier configuration ---------- */
EXEC dbo.usp_P3_EvaluateTiers @AsOfDate = @today;   -- back to today
EXEC sys.sp_executesql @tierq, N'@h varchar(64) OUTPUT', @h = @hB OUTPUT;
DECLARE @c1 int = 0, @c2 int = 0, @c3 int = 0;
INSERT dbo.MEMBER_TIER VALUES (99, N'TEST_ONLY_second_base', 0);
BEGIN TRY EXEC dbo.usp_P3_EvaluateTiers @AsOfDate = @today; END TRY BEGIN CATCH SET @c1 = ERROR_NUMBER(); END CATCH;
BEGIN TRY EXEC dbo.usp_P3_GetMemberLoyalty @Member_ID = 14; END TRY BEGIN CATCH SET @c3 = ERROR_NUMBER(); END CATCH;
DELETE dbo.MEMBER_TIER WHERE Tier_ID = 99;
INSERT dbo.MEMBER_TIER VALUES (99, N'TEST_ONLY_duplicate', @goldT);
BEGIN TRY EXEC dbo.usp_P3_EvaluateTiers @AsOfDate = @today; END TRY BEGIN CATCH SET @c2 = ERROR_NUMBER(); END CATCH;
DELETE dbo.MEMBER_TIER WHERE Tier_ID = 99;
EXEC sys.sp_executesql @tierq, N'@h varchar(64) OUTPUT', @h = @hA OUTPUT;
INSERT @results VALUES ('L08', 'T-F05-35', CASE WHEN @c1 = 51322 AND @c2 = 51323 AND @c3 = 51322 AND @hB = @hA THEN 'PASS' ELSE 'FAIL' END,
    N'Invalid MEMBER_TIER configuration (a second tier at 0; a duplicate threshold): batch and lookup refuse, no tier written',
    CONCAT(N'errors: batch ', @c1, N' / ', @c2, N'; lookup ', @c3, N'; state changed ', CASE WHEN @hB <> @hA THEN N'yes' ELSE N'no' END));

/* ---------- L06 T-F05-15: lookup ---------- */
CREATE TABLE #lk (Member_ID int, CurrentPoints int, Tier_ID int, Tier_Name nvarchar(50), FromMonth date, NextMonth date, WindowSpend decimal(38,2),
                  EvaluatedTier_ID int, EvaluatedTier_Name nvarchar(50), NextTier_Name nvarchar(50), NextTierThreshold decimal(18,2), AmountToNextTier decimal(38,2));
INSERT #lk EXEC dbo.usp_P3_GetMemberLoyalty @Member_ID = 14;
INSERT #lk EXEC dbo.usp_P3_GetMemberLoyalty @Member_ID = 12;
INSERT #lk EXEC dbo.usp_P3_GetMemberLoyalty @Member_ID = 18;
SELECT @c1 = 0, @c2 = 0;
BEGIN TRY EXEC dbo.usp_P3_GetMemberLoyalty @Member_ID = 999; END TRY BEGIN CATCH SET @c1 = ERROR_NUMBER(); END CATCH;
BEGIN TRY EXEC dbo.usp_P3_GetMemberLoyalty @Member_ID = NULL; END TRY BEGIN CATCH SET @c2 = ERROR_NUMBER(); END CATCH;
SET @ok = CASE WHEN EXISTS (SELECT 1 FROM #lk WHERE Member_ID = 14 AND Tier_ID = @gold AND EvaluatedTier_ID = @gold AND WindowSpend = @goldT AND NextTierThreshold = @platT AND AmountToNextTier = @platT - @goldT
                                AND FromMonth = DATEADD(MONTH, -11, @m0) AND NextMonth = DATEADD(MONTH, 1, @m0)
                                AND CurrentPoints = (SELECT SUM(PointsEarned) FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = 14))
                AND EXISTS (SELECT 1 FROM #lk WHERE Member_ID = 12 AND Tier_ID = @silver AND WindowSpend = 0 AND AmountToNextTier = @goldT AND CurrentPoints = 0)
                AND EXISTS (SELECT 1 FROM #lk WHERE Member_ID = 18 AND Tier_ID = @plat AND NextTier_Name IS NULL AND AmountToNextTier IS NULL)
                AND @c1 = 51331 AND @c2 = 51330 THEN 1 ELSE 0 END;
INSERT @results VALUES ('L06', 'T-F05-15', CASE WHEN @ok = 1 THEN 'PASS' ELSE 'FAIL' END,
    N'Loyalty lookup: points, stored and evaluated tier, window bounds and spend, next tier and gap equal the oracle (Gold member, Silver member with 0, top-tier member without next tier); unknown / NULL member rejected',
    CONCAT(N'rows: ', (SELECT STRING_AGG(CONCAT(Member_ID, ':', Tier_Name, '/', WindowSpend, '/next ', ISNULL(NextTier_Name, '-'), ' gap ', ISNULL(CONVERT(varchar(30), AmountToNextTier), '-')), '; ') FROM #lk),
           N'; errors ', @c1, N' / ', @c2));
DROP TABLE #lk;

/* ---------- L07 T-F05-32: many small invoices in one month ---------- */
SET @i = 1; SET @peList = '';
WHILE @i <= 25
BEGIN
    DELETE @prd; INSERT @prd VALUES (1, 1, 1, 4000, 0);
    EXEC dbo.usp_P3_CreateInvoice @Member_ID = 11, @Employee_ID = 1, @Branch_ID = 1, @ServiceLines = @svc, @ProductLines = @prd, @Invoice_ID = @inv OUTPUT, @Outcome = @co OUTPUT;
    EXEC dbo.usp_P3_SettleInvoice @Invoice_ID = @inv, @PaymentMethod = 'CASH', @Outcome = @outc OUTPUT, @PointsEarned = @pe OUTPUT, @CurrentPoints = @cp OUTPUT;
    SET @peList = CONCAT(@peList, @pe);
    SET @i += 1;
END;
INSERT @results VALUES ('L07', 'T-F05-32', CASE WHEN @peList = '0000000000000000000000001' AND @cp = 1
                                                   AND (SELECT TotalSpend FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = 11) = 100000
                                                   AND (SELECT PointsEarned FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = 11) = 1 THEN 'PASS' ELSE 'FAIL' END,
    N'25 settled invoices of 4,000 VND in one month: points per call 0 x24 then 1 at the cumulative 100,000; one month row; CurrentPoints 1',
    CONCAT(N'points per call ', @peList, N'; balance ', @cp, N'; month row ', (SELECT CONCAT(TotalSpend, '/', PointsEarned) FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = 11)));

/* ---------- final: evaluate today (state used by T-REC-04 in the runner) ---------- */
EXEC dbo.usp_P3_EvaluateTiers @AsOfDate = @today;

SELECT case_id, test_id, result, descr, detail FROM @results ORDER BY seq;
DECLARE @fails int = (SELECT COUNT(*) FROM @results WHERE result <> 'PASS'), @cases int = (SELECT COUNT(*) FROM @results);
PRINT CONCAT('T-F05L SUMMARY: cases=', @cases, ' FAIL=', @fails);
IF @fails > 0 BEGIN PRINT 'T-F05L_RESULT: FAIL'; THROW 51294, N'T-F05L failed (see the case table).', 1; END
ELSE PRINT 'T-F05L_RESULT: PASS';
GO
