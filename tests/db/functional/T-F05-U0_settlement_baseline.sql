/* =====================================================================
   T-F05-U0_settlement_baseline.sql - TEST_ONLY (sqlcmd mode)
   Work order : WO-P3-P3-01 task 2 (U0, REFERENCE_ONLY). Functional tests only - no timing (R-27).
     T-F05-36  U0 keeps the settlement contract and adds exactly the synchronous re-rank:
               boundaries (threshold - 0.01 / = threshold), window from INVOICE (a month outside the
               D-007 window is ignored, a month inside counts; a stale higher tier is lowered), repeat
               (ALREADY_SETTLED, no change at all), rejected requests (nothing written), and the U1
               routine alone leaves the tier untouched (D-009 (a) latency).
     T-F05-37  U0 rollback: a failure injected at its tier update (TEST_ONLY trigger) removes the
               whole settlement; inside a caller transaction a rollback removes everything and an
               error leaves the transaction uncommittable.
     K-U0      criterion 4, database part: no module references U0; U0 marked REFERENCE_ONLY;
               the approved settlement routine is unchanged (definition hash).
   Members 37-40 (unused by T-F05S and the concurrency harnesses). Thresholds are read from
   MEMBER_TIER (TEST_ONLY synthetic values); nothing is hard-coded.
   Run: sqlcmd -S localhost -E -I -b -W -d FitLife_P3_UC05 -i tests/db/functional/T-F05-U0_settlement_baseline.sql
   ===================================================================== */
:on error exit
SET NOCOUNT ON;
SET XACT_ABORT OFF;

IF DB_NAME() <> N'FitLife_P3_UC05'
   OR NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable' AND CONVERT(nvarchar(200), value) LIKE N'WO-P3-P3-00%')
    THROW 51270, N'T-F05-U0 runs only in FitLife_P3_UC05 with the disposable marker.', 1;
IF OBJECT_ID(N'dbo.usp_P3_SettleInvoice_Baseline', N'P') IS NULL OR OBJECT_ID(N'dbo.TEST_p3_AddPaidHistory', N'P') IS NULL OR OBJECT_ID(N'dbo.MEMBER_TIER', N'U') IS NULL
    THROW 51271, N'T-F05-U0: U0, F002T or F003H not deployed.', 1;
IF EXISTS (SELECT 1 FROM dbo.INVOICE WHERE Member_ID BETWEEN 37 AND 40) OR EXISTS (SELECT 1 FROM dbo.MEMBER WHERE Member_ID BETWEEN 37 AND 40 AND (CurrentPoints <> 0 OR Tier_ID <> 1))
    THROW 51272, N'T-F05-U0 expects members 37-40 without invoices, points or tier.', 1;
IF MONTH(DATEADD(MINUTE, 2, DATEADD(HOUR, 7, SYSUTCDATETIME()))) <> MONTH(DATEADD(HOUR, 7, SYSUTCDATETIME()))
    THROW 51273, N'T-F05-U0: too close to a local month boundary; run again in a few minutes.', 1;

DECLARE @results TABLE (seq int IDENTITY(1,1), case_id varchar(8), test_id varchar(10), result varchar(4), descr nvarchar(300), detail nvarchar(2000));
DECLARE @stateq nvarchar(max) = N'
SELECT @h = CONVERT(varchar(64), HASHBYTES(''SHA2_256'', CONCAT(
  (SELECT STRING_AGG(CONVERT(varchar(max), CONCAT(Invoice_ID, '':'', PaymentStatus, '':'', ISNULL(PaymentMethod, ''-''), '':'', ISNULL(CONVERT(varchar(30), PaidAt, 126), ''-''))), '','') WITHIN GROUP (ORDER BY Invoice_ID) FROM dbo.INVOICE), ''|'',
  (SELECT STRING_AGG(CONVERT(varchar(max), CONCAT(Member_ID, '':'', SpendingMonth, '':'', TotalSpend, '':'', PointsEarned)), '','') WITHIN GROUP (ORDER BY Member_ID, SpendingMonth) FROM dbo.MEMBER_MONTHLY_SPENDING), ''|'',
  (SELECT STRING_AGG(CONVERT(varchar(max), CONCAT(Member_ID, '':'', CurrentPoints, '':'', Tier_ID)), '','') WITHIN GROUP (ORDER BY Member_ID) FROM dbo.MEMBER), ''|'',
  (SELECT COUNT(*) FROM dbo.TEST_HookCallLog), ''|'', (SELECT COUNT(*) FROM dbo.MEMBER_TIER))), 2);';

DECLARE @silver int = (SELECT Tier_ID FROM dbo.MEMBER_TIER WHERE SpendingThreshold = 0);
DECLARE @gold int = (SELECT Tier_ID FROM dbo.MEMBER_TIER WHERE Tier_Name = N'Gold'), @plat int = (SELECT Tier_ID FROM dbo.MEMBER_TIER WHERE Tier_Name = N'Platinum');
DECLARE @goldT decimal(18,2) = (SELECT SpendingThreshold FROM dbo.MEMBER_TIER WHERE Tier_ID = @gold), @platT decimal(18,2) = (SELECT SpendingThreshold FROM dbo.MEMBER_TIER WHERE Tier_ID = @plat);
DECLARE @prd dbo.tt_P3_InvoiceProductLine, @svc dbo.tt_P3_InvoiceServiceLine;
DECLARE @inv int, @inv2 int, @canc int, @co varchar(20), @err int, @emsg nvarchar(2048), @outc varchar(20), @pa datetime2(3), @pe int, @cp int, @tier int,
        @hB varchar(64), @hA varchar(64), @xs int, @ok bit, @hid int, @oracle decimal(38,2), @err2 int;
DECLARE @m0 datetime2(3) = CAST(DATEFROMPARTS(YEAR(DATEADD(HOUR, 7, SYSUTCDATETIME())), MONTH(DATEADD(HOUR, 7, SYSUTCDATETIME())), 1) AS datetime2(3));   -- current local month (local midnight)
PRINT CONCAT('Tier configuration (Gold/Platinum TEST_ONLY synthetic): Silver id ', @silver, ' = 0; Gold id ', @gold, ' = ', @goldT, '; Platinum id ', @plat, ' = ', @platT);

/* ---------- U01 (T-F05-36): spend = Gold - 0.01 -> stays Silver; full U1 contract ---------- */
DELETE @prd; INSERT @prd VALUES (1, 1, 1, @goldT - 0.01, 0);
EXEC dbo.usp_P3_CreateInvoice @Member_ID = 37, @Employee_ID = 1, @Branch_ID = 1, @ServiceLines = @svc, @ProductLines = @prd, @Invoice_ID = @inv OUTPUT, @Outcome = @co OUTPUT;
SELECT @err = 0, @emsg = N'', @outc = NULL, @tier = NULL;
BEGIN TRY EXEC dbo.usp_P3_SettleInvoice_Baseline @Invoice_ID = @inv, @PaymentMethod = 'CASH', @Outcome = @outc OUTPUT, @PaidAt = @pa OUTPUT, @PointsEarned = @pe OUTPUT, @CurrentPoints = @cp OUTPUT, @Tier_ID = @tier OUTPUT; END TRY
BEGIN CATCH SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE(); IF XACT_STATE() <> 0 ROLLBACK; END CATCH;
SET @ok = CASE WHEN @err = 0 AND @outc = 'SETTLED' AND @tier = @silver AND (SELECT Tier_ID FROM dbo.MEMBER WHERE Member_ID = 37) = @silver
                AND (SELECT PaymentStatus FROM dbo.INVOICE WHERE Invoice_ID = @inv) = 'PAID' AND (SELECT PaidAt FROM dbo.INVOICE WHERE Invoice_ID = @inv) = @pa
                AND (SELECT TotalSpend FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = 37) = @goldT - 0.01
                AND @pe = CONVERT(int, FLOOR((@goldT - 0.01) / 100000)) AND @cp = @pe
                AND (SELECT COUNT(*) FROM dbo.TEST_HookCallLog WHERE Invoice_ID = @inv) = 2 THEN 1 ELSE 0 END;
INSERT @results VALUES ('U01', 'T-F05-36', CASE WHEN @ok = 1 THEN 'PASS' ELSE 'FAIL' END, N'U0 keeps the settlement contract (PAID, PaidAt, spending, points, one call per hook); window spend Gold - 0.01 -> Silver',
    CONCAT(N'error ', @err, N' ', LEFT(@emsg, 150), N'; outcome ', ISNULL(@outc, '-'), N'; tier ', ISNULL(CONVERT(varchar(4), @tier), '-'), N'; points ', @pe, N'; balance ', @cp));

/* ---------- U02 (T-F05-36): + 0.01 -> spend = Gold exactly -> Gold (inclusive) ---------- */
DELETE @prd; INSERT @prd VALUES (1, 1, 1, 0.01, 0);
EXEC dbo.usp_P3_CreateInvoice @Member_ID = 37, @Employee_ID = 1, @Branch_ID = 1, @ServiceLines = @svc, @ProductLines = @prd, @Invoice_ID = @inv2 OUTPUT, @Outcome = @co OUTPUT;
SELECT @err = 0, @emsg = N'', @outc = NULL, @tier = NULL;
BEGIN TRY EXEC dbo.usp_P3_SettleInvoice_Baseline @Invoice_ID = @inv2, @PaymentMethod = 'CARD', @Outcome = @outc OUTPUT, @Tier_ID = @tier OUTPUT; END TRY
BEGIN CATCH SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE(); IF XACT_STATE() <> 0 ROLLBACK; END CATCH;
SET @ok = CASE WHEN @err = 0 AND @outc = 'SETTLED' AND @tier = @gold AND (SELECT Tier_ID FROM dbo.MEMBER WHERE Member_ID = 37) = @gold
                AND (SELECT TotalSpend FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = 37) = @goldT THEN 1 ELSE 0 END;
INSERT @results VALUES ('U02', 'T-F05-36', CASE WHEN @ok = 1 THEN 'PASS' ELSE 'FAIL' END, N'Window spend exactly = Gold threshold -> Gold (inclusive comparison, D-008 rule)',
    CONCAT(N'error ', @err, N' ', LEFT(@emsg, 150), N'; outcome ', ISNULL(@outc, '-'), N'; tier ', ISNULL(CONVERT(varchar(4), @tier), '-')));

/* ---------- U03 (T-F05-36): repeat -> ALREADY_SETTLED, no change in any table (tier included) ---------- */
EXEC sys.sp_executesql @stateq, N'@h varchar(64) OUTPUT', @h = @hB OUTPUT;
SELECT @err = 0, @emsg = N'', @outc = NULL, @tier = NULL;
BEGIN TRY EXEC dbo.usp_P3_SettleInvoice_Baseline @Invoice_ID = @inv2, @PaymentMethod = 'CARD', @Outcome = @outc OUTPUT, @Tier_ID = @tier OUTPUT; END TRY
BEGIN CATCH SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE(); IF XACT_STATE() <> 0 ROLLBACK; END CATCH;
EXEC sys.sp_executesql @stateq, N'@h varchar(64) OUTPUT', @h = @hA OUTPUT;
INSERT @results VALUES ('U03', 'T-F05-36', CASE WHEN @err = 0 AND @outc = 'ALREADY_SETTLED' AND @tier = @gold AND @hB = @hA AND @@TRANCOUNT = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Repeated U0 settlement: ALREADY_SETTLED, whole state (status, spending, points, tier, hook log) unchanged',
    CONCAT(N'error ', @err, N'; outcome ', ISNULL(@outc, '-'), N'; state changed ', CASE WHEN @hB <> @hA THEN N'yes' ELSE N'no' END));

/* ---------- U04 (T-F05-36): window computed from INVOICE (D-007) ---------- */
-- History (TEST_ONLY): Platinum-level spend in the local month 12 months back (outside the window),
-- Gold - 1,000 in the month 11 months back (inside); a stale Platinum tier is set directly.
DECLARE @out12 datetime2(3) = DATEADD(HOUR, 3, DATEADD(MONTH, -12, @m0));    -- 10:00 local on the 1st, 12 months back
DECLARE @in11 datetime2(3) = DATEADD(HOUR, 3, DATEADD(MONTH, -11, @m0));     -- 10:00 local on the 1st, 11 months back
EXEC dbo.TEST_p3_AddPaidHistory @Member_ID = 38, @PaidAtUtc = @out12, @Amount = @platT, @Invoice_ID = @hid OUTPUT;
DECLARE @amt decimal(18,2) = @goldT - 1000;
EXEC dbo.TEST_p3_AddPaidHistory @Member_ID = 38, @PaidAtUtc = @in11, @Amount = @amt, @Invoice_ID = @hid OUTPUT;
UPDATE dbo.MEMBER SET Tier_ID = @plat WHERE Member_ID = 38;   -- TEST_ONLY stale tier
DELETE @prd; INSERT @prd VALUES (1, 1, 1, 1000, 0);
EXEC dbo.usp_P3_CreateInvoice @Member_ID = 38, @Employee_ID = 1, @Branch_ID = 1, @ServiceLines = @svc, @ProductLines = @prd, @Invoice_ID = @inv OUTPUT, @Outcome = @co OUTPUT;
SELECT @err = 0, @emsg = N'', @outc = NULL, @tier = NULL;
BEGIN TRY EXEC dbo.usp_P3_SettleInvoice_Baseline @Invoice_ID = @inv, @PaymentMethod = 'VNPAY', @Outcome = @outc OUTPUT, @Tier_ID = @tier OUTPUT; END TRY
BEGIN CATCH SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE(); IF XACT_STATE() <> 0 ROLLBACK; END CATCH;
-- independent oracle: local month by AT TIME ZONE, window = current local month and the 11 before
SELECT @oracle = ISNULL(SUM(i.FinalAmount), 0)
FROM dbo.INVOICE AS i
CROSS APPLY (SELECT CONVERT(datetime2(3), (i.PaidAt AT TIME ZONE 'UTC') AT TIME ZONE 'SE Asia Standard Time') AS loc) AS l
WHERE i.Member_ID = 38 AND i.PaymentStatus = 'PAID'
  AND DATEFROMPARTS(YEAR(l.loc), MONTH(l.loc), 1) >= DATEADD(MONTH, -11, CAST(@m0 AS date)) AND DATEFROMPARTS(YEAR(l.loc), MONTH(l.loc), 1) <= CAST(@m0 AS date);
SET @ok = CASE WHEN @err = 0 AND @outc = 'SETTLED' AND @oracle = @goldT AND @tier = @gold AND (SELECT Tier_ID FROM dbo.MEMBER WHERE Member_ID = 38) = @gold THEN 1 ELSE 0 END;
INSERT @results VALUES ('U04', 'T-F05-36', CASE WHEN @ok = 1 THEN 'PASS' ELSE 'FAIL' END,
    N'Window recomputed from INVOICE (D-007): month 12 back (Platinum-level) ignored, month 11 back counted; spend = Gold -> stale Platinum lowered to Gold',
    CONCAT(N'error ', @err, N' ', LEFT(@emsg, 150), N'; outcome ', ISNULL(@outc, '-'), N'; oracle window spend ', @oracle, N'; tier ', ISNULL(CONVERT(varchar(4), @tier), '-'),
           N'; history months ', CONVERT(varchar(10), DATEADD(MONTH, -12, CAST(@m0 AS date)), 23), N' (out) / ', CONVERT(varchar(10), DATEADD(MONTH, -11, CAST(@m0 AS date)), 23), N' (in)'));

/* ---------- U05 (T-F05-36): the production settlement alone does not re-rank (D-009 (a)) ---------- */
DELETE @prd; INSERT @prd VALUES (1, 1, 1, @platT, 0);
EXEC dbo.usp_P3_CreateInvoice @Member_ID = 39, @Employee_ID = 1, @Branch_ID = 1, @ServiceLines = @svc, @ProductLines = @prd, @Invoice_ID = @inv OUTPUT, @Outcome = @co OUTPUT;
SELECT @err = 0, @emsg = N'', @outc = NULL;
BEGIN TRY EXEC dbo.usp_P3_SettleInvoice @Invoice_ID = @inv, @PaymentMethod = 'CASH', @Outcome = @outc OUTPUT; END TRY
BEGIN CATCH SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE(); IF XACT_STATE() <> 0 ROLLBACK; END CATCH;
INSERT @results VALUES ('U05', 'T-F05-36', CASE WHEN @err = 0 AND @outc = 'SETTLED' AND (SELECT Tier_ID FROM dbo.MEMBER WHERE Member_ID = 39) = @silver THEN 'PASS' ELSE 'FAIL' END,
    N'Contrast: the production routine usp_P3_SettleInvoice (U1) settles Platinum-level spending without touching Tier_ID - re-ranking is U0-only (reference) or the periodic batch',
    CONCAT(N'error ', @err, N'; outcome ', ISNULL(@outc, '-'), N'; tier after U1 ', (SELECT Tier_ID FROM dbo.MEMBER WHERE Member_ID = 39)));

/* ---------- U06 (T-F05-36): rejected requests write nothing ---------- */
DELETE @prd; INSERT @prd VALUES (1, 1, 1, 50000, 0);
EXEC dbo.usp_P3_CreateInvoice @Member_ID = 40, @Employee_ID = 1, @Branch_ID = 1, @ServiceLines = @svc, @ProductLines = @prd, @Invoice_ID = @canc OUTPUT, @Outcome = @co OUTPUT;
EXEC dbo.usp_P3_CancelInvoice @Invoice_ID = @canc;
EXEC sys.sp_executesql @stateq, N'@h varchar(64) OUTPUT', @h = @hB OUTPUT;
SELECT @err = 0, @err2 = 0, @xs = 0;
BEGIN TRY EXEC dbo.usp_P3_SettleInvoice_Baseline @Invoice_ID = @canc, @PaymentMethod = 'CASH'; END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); IF XACT_STATE() <> 0 ROLLBACK; END CATCH;
BEGIN TRY EXEC dbo.usp_P3_SettleInvoice_Baseline @Invoice_ID = @canc, @PaymentMethod = 'cash'; END TRY
BEGIN CATCH SET @err2 = ERROR_NUMBER(); IF XACT_STATE() <> 0 ROLLBACK; END CATCH;
INSERT dbo.MEMBER_TIER (Tier_ID, Tier_Name, SpendingThreshold) VALUES (99, N'TEST_ONLY_second_base', 0);   -- invalid configuration
BEGIN TRY EXEC dbo.usp_P3_SettleInvoice_Baseline @Invoice_ID = @canc, @PaymentMethod = 'CASH'; END TRY
BEGIN CATCH SET @xs = ERROR_NUMBER(); IF XACT_STATE() <> 0 ROLLBACK; END CATCH;
DELETE dbo.MEMBER_TIER WHERE Tier_ID = 99;
EXEC sys.sp_executesql @stateq, N'@h varchar(64) OUTPUT', @h = @hA OUTPUT;
INSERT @results VALUES ('U06', 'T-F05-36', CASE WHEN @err = 51204 AND @err2 = 51202 AND @xs = 51311 AND @hB = @hA AND @@TRANCOUNT = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Rejected U0 requests (CANCELLED invoice 51204, invalid method 51202, invalid tier configuration 51311): nothing written',
    CONCAT(N'errors ', @err, N' / ', @err2, N' / ', @xs, N'; state changed ', CASE WHEN @hB <> @hA THEN N'yes' ELSE N'no' END));

/* ---------- U07 (T-F05-37): failure at the tier update rolls back the whole settlement ---------- */
DELETE @prd; INSERT @prd VALUES (1, 1, 1, @goldT, 0);
EXEC dbo.usp_P3_CreateInvoice @Member_ID = 40, @Employee_ID = 1, @Branch_ID = 1, @ServiceLines = @svc, @ProductLines = @prd, @Invoice_ID = @inv OUTPUT, @Outcome = @co OUTPUT;
EXEC (N'CREATE TRIGGER dbo.TEST_trg_FailTierUpdate ON dbo.MEMBER AFTER UPDATE AS BEGIN SET NOCOUNT ON; IF UPDATE(Tier_ID) THROW 52920, N''TEST_ONLY injected failure at the U0 tier update.'', 1; END');
EXEC sys.sp_executesql @stateq, N'@h varchar(64) OUTPUT', @h = @hB OUTPUT;
SELECT @err = 0, @emsg = N'';
BEGIN TRY EXEC dbo.usp_P3_SettleInvoice_Baseline @Invoice_ID = @inv, @PaymentMethod = 'CASH'; END TRY
BEGIN CATCH SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE(); IF XACT_STATE() <> 0 ROLLBACK; END CATCH;
EXEC sys.sp_executesql @stateq, N'@h varchar(64) OUTPUT', @h = @hA OUTPUT;
DROP TRIGGER dbo.TEST_trg_FailTierUpdate;
SET @ok = CASE WHEN @err = 52920 AND @hB = @hA AND @@TRANCOUNT = 0 AND (SELECT PaymentStatus FROM dbo.INVOICE WHERE Invoice_ID = @inv) = 'PENDING'
                AND NOT EXISTS (SELECT 1 FROM dbo.TEST_HookCallLog WHERE Invoice_ID = @inv) AND NOT EXISTS (SELECT 1 FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = 40) THEN 1 ELSE 0 END;
SELECT @err2 = 0, @outc = NULL, @tier = NULL;
BEGIN TRY EXEC dbo.usp_P3_SettleInvoice_Baseline @Invoice_ID = @inv, @PaymentMethod = 'CASH', @Outcome = @outc OUTPUT, @Tier_ID = @tier OUTPUT; END TRY
BEGIN CATCH SET @err2 = ERROR_NUMBER(); IF XACT_STATE() <> 0 ROLLBACK; END CATCH;
INSERT @results VALUES ('U07', 'T-F05-37', CASE WHEN @ok = 1 AND @err2 = 0 AND @outc = 'SETTLED' AND @tier = @gold THEN 'PASS' ELSE 'FAIL' END,
    N'Failure injected at the U0 tier update: status, PaidAt, spending, points, hook calls and tier all rolled back; afterwards the invoice settles once (Gold)',
    CONCAT(N'error ', @err, N' (', LEFT(@emsg, 100), N'); state changed ', CASE WHEN @hB <> @hA THEN N'yes' ELSE N'no' END, N'; retry ', ISNULL(@outc, '-'), N', tier ', ISNULL(CONVERT(varchar(4), @tier), '-')));

/* ---------- U08 (T-F05-37): inside a caller transaction ---------- */
DELETE @prd; INSERT @prd VALUES (1, 1, 1, @platT, 0);
EXEC dbo.usp_P3_CreateInvoice @Member_ID = 40, @Employee_ID = 1, @Branch_ID = 1, @ServiceLines = @svc, @ProductLines = @prd, @Invoice_ID = @inv OUTPUT, @Outcome = @co OUTPUT;
EXEC sys.sp_executesql @stateq, N'@h varchar(64) OUTPUT', @h = @hB OUTPUT;
SELECT @outc = NULL, @tier = NULL, @err = 0;
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.usp_P3_SettleInvoice_Baseline @Invoice_ID = @inv, @PaymentMethod = 'CASH', @Outcome = @outc OUTPUT, @Tier_ID = @tier OUTPUT;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); IF XACT_STATE() <> 0 ROLLBACK; END CATCH;
EXEC sys.sp_executesql @stateq, N'@h varchar(64) OUTPUT', @h = @hA OUTPUT;
SET @ok = CASE WHEN @err = 0 AND @outc = 'SETTLED' AND @tier = @plat AND @hB = @hA THEN 1 ELSE 0 END;
SELECT @err2 = 0, @xs = NULL;
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.usp_P3_SettleInvoice_Baseline @Invoice_ID = @inv, @PaymentMethod = 'CASH';
    EXEC dbo.usp_P3_SettleInvoice_Baseline @Invoice_ID = @canc, @PaymentMethod = 'CASH';   -- CANCELLED -> 51204
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH SELECT @err2 = ERROR_NUMBER(), @xs = XACT_STATE(); IF XACT_STATE() <> 0 ROLLBACK; END CATCH;
EXEC sys.sp_executesql @stateq, N'@h varchar(64) OUTPUT', @h = @hA OUTPUT;
INSERT @results VALUES ('U08', 'T-F05-37', CASE WHEN @ok = 1 AND @err2 = 51204 AND @xs = -1 AND @hB = @hA AND @@TRANCOUNT = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Inside a caller transaction: rollback removes the U0 settlement and its re-rank; a later error leaves XACT_STATE -1 and one rollback removes everything',
    CONCAT(N'inside: ', ISNULL(@outc, '-'), N' tier ', ISNULL(CONVERT(varchar(4), @tier), '-'), N'; second error ', @err2, N', XACT_STATE ', ISNULL(CONVERT(varchar(4), @xs), '-'),
           N'; state after rollbacks = before: ', CASE WHEN @hB = @hA THEN N'yes' ELSE N'NO' END));
-- leave invoice @inv PENDING (settled later by nobody); it has no effect.

/* ---------- K01 (criterion 4, database part) ---------- */
DECLARE @refs int = (SELECT COUNT(*) FROM sys.sql_modules WHERE definition LIKE N'%usp[_]P3[_]SettleInvoice[_]Baseline%' AND object_id <> OBJECT_ID(N'dbo.usp_P3_SettleInvoice_Baseline'));
DECLARE @refd int = (SELECT COUNT(*) FROM sys.dm_sql_referencing_entities(N'dbo.usp_P3_SettleInvoice_Baseline', N'OBJECT'));
DECLARE @mark nvarchar(200) = (SELECT CONVERT(nvarchar(200), value) FROM sys.extended_properties WHERE class = 1 AND major_id = OBJECT_ID(N'dbo.usp_P3_SettleInvoice_Baseline') AND minor_id = 0 AND name = N'Classification');
DECLARE @settleHash varchar(64) = CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_P3_SettleInvoice')))), 2);
INSERT @results VALUES ('K01', 'AC4', CASE WHEN @refs = 0 AND @refd = 0 AND @mark LIKE N'REFERENCE_ONLY%' AND @settleHash = '96C877A800B0EBE004F6B6F44780B7A5C11530F36F8BEA9A9E2C96C07FD47E44' THEN 'PASS' ELSE 'FAIL' END,
    N'No database module references U0 (definitions and dependency view); U0 marked REFERENCE_ONLY; approved settlement routine unchanged (definition hash = WO-P3-P3-01 run 1447)',
    CONCAT(N'modules mentioning U0: ', @refs, N'; referencing entities: ', @refd, N'; marker: ', ISNULL(@mark, N'-'), N'; settle SHA-256 ', @settleHash));

SELECT case_id, test_id, result, descr, detail FROM @results ORDER BY seq;
DECLARE @fails int = (SELECT COUNT(*) FROM @results WHERE result <> 'PASS'), @n int = (SELECT COUNT(*) FROM @results);
PRINT CONCAT('T-F05-U0 SUMMARY: cases=', @n, ' FAIL=', @fails);
IF @fails > 0 BEGIN PRINT 'T-F05-U0_RESULT: FAIL'; THROW 51274, N'T-F05-U0 failed (see the case table).', 1; END
ELSE PRINT 'T-F05-U0_RESULT: PASS';
GO
