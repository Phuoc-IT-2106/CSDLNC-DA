/* =====================================================================
   T-F05S_settlement.sql - TEST_ONLY (sqlcmd mode)
   Work order : WO-P3-P3-01 (settlement and cancellation). Catalogue: 11 section 2.3.
   Exercises dbo.usp_P3_SettleInvoice and dbo.usp_P3_CancelInvoice in FitLife_P3_UC05 (fresh
   build + F001U key rows + F002P + D001 hook doubles; invoices created through
   dbo.usp_P3_CreateInvoice). Every case records a hash of the whole mutable state (INVOICE
   payment columns, MEMBER_MONTHLY_SPENDING, MEMBER.CurrentPoints, hook call log, line counts)
   before and after the call, so "no effect" means no change in ANY of these tables.
     Part A  data-driven settle/cancel cases: T-F05-05 positive; T-F05-06 repeat (idempotent);
             T-F05-07 invalid / unknown / CANCELLED invoice; T-F05-09 point boundaries (D-006);
             T-F05-11 first vs later payment in a month; T-F05-16 cancellation; T-F05-27 payment
             method rules.
     Part B  TEST_ONLY invoices inserted directly (they cannot be produced by the creation
             routine) and removed afterwards: T-F05-02 no line (BR12); T-F05-28 header totals
             differ from the lines (D-023); T-F05-31 settlement time before IssuedAt.
     Part C  rollback: T-F05-08 late failure at the MEMBER step and at the spending step
             (TEST_ONLY triggers, created and dropped here); T-F05-22 hook failures (fault
             injection through the doubles); then the same invoice settles normally.
     Part D  T-F05-29 composition inside a caller's transaction (commit, rollback, error).
     Part E  T-F05-10 spending month: function at the UTC/local month boundaries, against an
             independent AT TIME ZONE oracle, and end to end for every PAID invoice.
     Part F  T-F05-30 least privilege (TEST_ONLY role/user created and dropped here): EXECUTE
             on the routines suffices; direct changes to status, points, spending or hooks are
             denied, so PAID cannot be reverted outside the routines.
     Part G  T-F05-21 hook calls: one inventory then one entitlement call per settled invoice,
             none for repeated, rejected or cancelled requests.
   A case passes only if the exact expected error number (or outcome and values) is observed,
   the state changed exactly as expected, V-TOT is zero and no transaction is left open.
   Run: sqlcmd -S localhost -E -I -b -W -d FitLife_P3_UC05 -i tests/db/functional/T-F05S_settlement.sql
   ===================================================================== */
:on error exit
SET NOCOUNT ON;
SET XACT_ABORT OFF;   -- errors raised by the routines must reach the CATCH blocks below

IF DB_NAME() <> N'FitLife_P3_UC05'
   OR NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable' AND CONVERT(nvarchar(200), value) LIKE N'WO-P3-P3-00%')
    THROW 51260, N'T-F05S runs only in FitLife_P3_UC05 carrying the disposable marker.', 1;
IF OBJECT_ID(N'dbo.usp_P3_SettleInvoice', N'P') IS NULL OR OBJECT_ID(N'dbo.usp_P3_CancelInvoice', N'P') IS NULL OR OBJECT_ID(N'dbo.usp_P3_CreateInvoice', N'P') IS NULL
   OR OBJECT_ID(N'dbo.TEST_HookCallLog', N'U') IS NULL OR COL_LENGTH(N'dbo.MEMBER', N'CurrentPoints') IS NULL
    THROW 51261, N'T-F05S: routines, F002P or the D001 hook doubles are not deployed.', 1;
IF (SELECT COUNT(*) FROM dbo.MEMBER) <> 40 OR EXISTS (SELECT 1 FROM dbo.INVOICE) OR EXISTS (SELECT 1 FROM dbo.MEMBER_MONTHLY_SPENDING)
   OR EXISTS (SELECT 1 FROM dbo.TEST_HookCallLog) OR EXISTS (SELECT 1 FROM dbo.MEMBER WHERE CurrentPoints <> 0)
    THROW 51262, N'T-F05S expects a fresh build: F001U key rows, no invoice, no spending, no points, empty hook log.', 1;
-- The expected month of every settlement is the current local month; refuse to start within 2 minutes of a local month change.
IF MONTH(DATEADD(MINUTE, 2, DATEADD(HOUR, 7, SYSUTCDATETIME()))) <> MONTH(DATEADD(HOUR, 7, SYSUTCDATETIME()))
    THROW 51263, N'T-F05S: too close to a local month boundary; run again in a few minutes.', 1;

DECLARE @results TABLE (seq int IDENTITY(1,1), case_id varchar(8), test_id varchar(10), result varchar(4), descr nvarchar(300), detail nvarchar(2000));

DECLARE @stateq nvarchar(max) = N'
SELECT @h = CONVERT(varchar(64), HASHBYTES(''SHA2_256'', CONCAT(
  (SELECT STRING_AGG(CONVERT(varchar(max), CONCAT(Invoice_ID, '':'', Member_ID, '':'', PaymentStatus, '':'', ISNULL(PaymentMethod, ''-''), '':'',
          ISNULL(CONVERT(varchar(30), PaidAt, 126), ''-''), '':'', GrossAmount, '':'', DiscountAmount, '':'', FinalAmount)), '','') WITHIN GROUP (ORDER BY Invoice_ID) FROM dbo.INVOICE), ''|'',
  (SELECT STRING_AGG(CONVERT(varchar(max), CONCAT(Member_ID, '':'', SpendingMonth, '':'', TotalSpend, '':'', PointsEarned, '':'', CONVERT(varchar(30), UpdatedAt, 126))), '','')
          WITHIN GROUP (ORDER BY Member_ID, SpendingMonth) FROM dbo.MEMBER_MONTHLY_SPENDING), ''|'',
  (SELECT STRING_AGG(CONVERT(varchar(max), CONCAT(Member_ID, '':'', CurrentPoints)), '','') WITHIN GROUP (ORDER BY Member_ID) FROM dbo.MEMBER), ''|'',
  (SELECT STRING_AGG(CONVERT(varchar(max), CONCAT(Seq, '':'', HookName, '':'', Invoice_ID)), '','') WITHIN GROUP (ORDER BY Seq) FROM dbo.TEST_HookCallLog), ''|'',
  (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM), ''|'', (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM))), 2);';
DECLARE @vtotq nvarchar(max) = N'
WITH s AS (SELECT Invoice_ID, SUM(UnitPrice) AS g, SUM(DiscountAmount) AS d, COUNT(*) AS n FROM dbo.INVOICE_SERVICE_ITEM GROUP BY Invoice_ID),
     p AS (SELECT Invoice_ID, SUM(UnitPrice * Quantity) AS g, SUM(DiscountAmount) AS d, COUNT(*) AS n FROM dbo.INVOICE_PRODUCT_ITEM GROUP BY Invoice_ID)
SELECT @n = COUNT(*) FROM dbo.INVOICE AS i LEFT JOIN s ON s.Invoice_ID = i.Invoice_ID LEFT JOIN p ON p.Invoice_ID = i.Invoice_ID
WHERE i.GrossAmount <> ISNULL(s.g, 0) + ISNULL(p.g, 0) OR i.DiscountAmount <> ISNULL(s.d, 0) + ISNULL(p.d, 0) OR ISNULL(s.n, 0) + ISNULL(p.n, 0) = 0;';

DECLARE @hB varchar(64), @hA varchar(64), @vt int, @id int, @member int, @final decimal(18,2);
DECLARE @err int, @emsg nvarchar(2048), @outc varchar(20), @pa datetime2(3), @pe int, @cp int, @t0 datetime2(7), @t1 datetime2(7), @xs int, @tc int;
DECLARE @spB decimal(38,2), @spA decimal(38,2), @ptB int, @ptA int, @hk int, @stStatus varchar(10), @stMethod varchar(10), @stPaid datetime2(3);
DECLARE @ok bit, @detail nvarchar(2000), @n1 int, @n2 int;

/* ---------- Setup: invoices created through the creation routine ---------- */
CREATE TABLE #def (ref varchar(8) PRIMARY KEY, member int, kind char(1), item int, qty int, price decimal(18,2), disc decimal(18,2), method varchar(10) NULL);
INSERT #def VALUES
 ('A1', 1, 'P', 1, 1, 150000, 0, NULL),    -- member 1: 150,000            -> 1 point
 ('A2', 1, 'S', 1, 1,  80000, 0, NULL),    --           +80,000 = 230,000  -> 2 (+1)
 ('A3', 1, 'P', 2, 2,  30000, 10000, 'VNPAY'), --       +50,000 = 280,000  -> 2 (+0)
 ('B0', 2, 'P', 3, 1,      0, 0, NULL),    -- D-006 boundaries: 0 -> 0
 ('B1', 3, 'P', 3, 1,  99999, 0, NULL),    -- 99,999 -> 0
 ('B2', 4, 'P', 3, 1, 100000, 0, NULL),    -- 100,000 -> 1
 ('B3', 5, 'P', 3, 1, 199999, 0, NULL),    -- 199,999 -> 1
 ('B4', 6, 'P', 3, 1, 200000, 0, NULL),    -- 200,000 -> 2
 ('B5', 7, 'P', 4, 1,  60000, 0, NULL),    -- two x 60,000 in one month -> 0 then 1
 ('B6', 7, 'S', 2, 1,  60000, 0, NULL),
 ('C1', 8, 'P', 5, 1, 100000, 0, 'VNPAY'), -- method recorded at creation
 ('C2', 8, 'P', 5, 1,  50000, 0, NULL),    -- no method recorded
 ('D1', 9, 'P', 6, 1, 120000, 0, 'CARD'),  -- cancelled
 ('F1',10, 'P', 7, 3, 100000, 0, NULL),    -- 300,000: rollback cases, then settles -> 3
 ('F2',10, 'S', 3, 1, 100000, 0, 'CASH'),  -- caller transaction, commit -> 400,000 -> 4
 ('F3',10, 'P', 8, 1, 250000, 0, NULL),    -- caller transaction, rollback; then settles -> 650,000 -> 6
 ('L1', 1, 'P', 9, 1,  10000, 0, NULL);    -- least privilege -> member 1: 290,000 -> 2 (+0)
CREATE TABLE #inv (ref varchar(8) PRIMARY KEY, Invoice_ID int NOT NULL);

DECLARE @svc dbo.tt_P3_InvoiceServiceLine, @prd dbo.tt_P3_InvoiceProductLine;
DECLARE @ref varchar(8), @kind char(1), @item int, @qty int, @price decimal(18,2), @disc decimal(18,2), @method varchar(10), @newId int, @co varchar(20);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT ref, member, kind, item, qty, price, disc, method FROM #def ORDER BY ref;
OPEN c;
FETCH NEXT FROM c INTO @ref, @member, @kind, @item, @qty, @price, @disc, @method;
WHILE @@FETCH_STATUS = 0
BEGIN
    DELETE @svc; DELETE @prd;
    IF @kind = 'S' INSERT @svc ([LineNo], Plan_ID, UnitPrice, DiscountAmount) VALUES (1, @item, @price, @disc);
    ELSE INSERT @prd ([LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount) VALUES (1, @item, @qty, @price, @disc);
    EXEC dbo.usp_P3_CreateInvoice @Member_ID = @member, @Employee_ID = 1, @Branch_ID = 1, @ServiceLines = @svc, @ProductLines = @prd,
         @PaymentMethod = @method, @Invoice_ID = @newId OUTPUT, @Outcome = @co OUTPUT;
    INSERT #inv VALUES (@ref, @newId);
    FETCH NEXT FROM c INTO @ref, @member, @kind, @item, @qty, @price, @disc, @method;
END;
CLOSE c; DEALLOCATE c;
SET @n1 = (SELECT COUNT(*) FROM #inv); PRINT CONCAT('Setup: ', @n1, ' PENDING test invoices created through dbo.usp_P3_CreateInvoice');

/* ---------- Part A: data-driven cases ---------- */
CREATE TABLE #case (seq int IDENTITY(1,1), case_id varchar(8), test_id varchar(10), op char(1), ref varchar(8), method varchar(10) NULL,
                    exp_err int, exp_outcome varchar(20) NULL, exp_points int NULL, exp_balance int NULL,
                    exp_status varchar(10) NULL, exp_method varchar(10) NULL, exp_change bit, descr nvarchar(300));
INSERT #case (case_id, test_id, op, ref, method, exp_err, exp_outcome, exp_points, exp_balance, exp_status, exp_method, exp_change, descr) VALUES
 ('A01', 'T-F05-05', 'S', 'A1', 'CASH',  0, 'SETTLED', 1, 1, 'PAID', 'CASH', 1, N'Settle a PENDING invoice (150,000, CASH): PAID, PaidAt UTC, first spending row of the member-month inserted, 1 point'),
 ('A02', 'T-F05-11', 'S', 'A2', 'CARD',  0, 'SETTLED', 1, 2, 'PAID', 'CARD', 1, N'Second payment of the member in the month (80,000): same row updated, cumulative 230,000 -> 2 points (+1)'),
 ('A03', 'T-F05-05', 'S', 'A3', NULL,    0, 'SETTLED', 0, 2, 'PAID', 'VNPAY', 1, N'Method recorded at creation (VNPAY) used when none is supplied; 280,000 -> still 2 points (+0)'),
 ('A04', 'T-F05-06', 'S', 'A1', 'CASH',  0, 'ALREADY_SETTLED', 0, 2, 'PAID', 'CASH', 0, N'Repeat settlement of a PAID invoice: ALREADY_SETTLED, no change in any table'),
 ('A05', 'T-F05-06', 'S', 'A1', 'VNPAY', 0, 'ALREADY_SETTLED', 0, 2, 'PAID', 'CASH', 0, N'Repeat with a different method: ALREADY_SETTLED, stored method and PaidAt unchanged'),
 ('A06', 'T-F05-06', 'S', 'A1', NULL,    0, 'ALREADY_SETTLED', 0, 2, 'PAID', 'CASH', 0, N'Third repeat without method: no change'),
 ('A07', 'T-F05-09', 'S', 'B0', 'CASH',  0, 'SETTLED', 0, 0, 'PAID', 'CASH', 1, N'D-006 boundary: FinalAmount 0 -> 0 points'),
 ('A08', 'T-F05-09', 'S', 'B1', 'CASH',  0, 'SETTLED', 0, 0, 'PAID', 'CASH', 1, N'D-006 boundary: 99,999 -> 0 points'),
 ('A09', 'T-F05-09', 'S', 'B2', 'CASH',  0, 'SETTLED', 1, 1, 'PAID', 'CASH', 1, N'D-006 boundary: 100,000 -> 1 point'),
 ('A10', 'T-F05-09', 'S', 'B3', 'CASH',  0, 'SETTLED', 1, 1, 'PAID', 'CASH', 1, N'D-006 boundary: 199,999 -> 1 point'),
 ('A11', 'T-F05-09', 'S', 'B4', 'CASH',  0, 'SETTLED', 2, 2, 'PAID', 'CASH', 1, N'D-006 boundary: 200,000 -> 2 points'),
 ('A12', 'T-F05-09', 'S', 'B5', 'CARD',  0, 'SETTLED', 0, 0, 'PAID', 'CARD', 1, N'D-006 (b): first 60,000 of the month -> 0 points'),
 ('A13', 'T-F05-09', 'S', 'B6', 'CARD',  0, 'SETTLED', 1, 1, 'PAID', 'CARD', 1, N'D-006 (b): second 60,000 in the same month -> cumulative 120,000 -> +1 point'),
 ('A14', 'T-F05-27', 'S', 'C1', 'CASH',  51208, NULL, NULL, NULL, 'PENDING', 'VNPAY', 0, N'Supplied method differs from the method recorded at creation: rejected, nothing written'),
 ('A15', 'T-F05-27', 'S', 'C2', NULL,    51207, NULL, NULL, NULL, 'PENDING', NULL, 0, N'No method supplied and none recorded: rejected (PaymentMethod NOT NULL when PAID, D-005)'),
 ('A16', 'T-F05-27', 'S', 'C2', 'CHEQUE', 51202, NULL, NULL, NULL, 'PENDING', NULL, 0, N'Method outside the approved domain (CHEQUE): rejected'),
 ('A17', 'T-F05-27', 'S', 'C2', 'cash',  51202, NULL, NULL, NULL, 'PENDING', NULL, 0, N'Method in lower case: rejected (exact literal required)'),
 ('A18', 'T-F05-27', 'S', 'C2', 'CASH ', 51202, NULL, NULL, NULL, 'PENDING', NULL, 0, N'Method with a trailing space: rejected'),
 ('A19', 'T-F05-27', 'S', 'C2', '',      51202, NULL, NULL, NULL, 'PENDING', NULL, 0, N'Empty method: rejected'),
 ('A20', 'T-F05-05', 'S', 'C1', 'VNPAY', 0, 'SETTLED', 1, 1, 'PAID', 'VNPAY', 1, N'After the rejected attempts, settlement with the recorded method succeeds (100,000 -> 1 point)'),
 ('A21', 'T-F05-05', 'S', 'C2', 'CARD',  0, 'SETTLED', 0, 1, 'PAID', 'CARD', 1, N'Method supplied at settlement (CARD); member 8 month 150,000 -> still 1 point (+0)'),
 ('A22', 'T-F05-07', 'S', 'NONE', 'CASH', 51203, NULL, NULL, NULL, NULL, NULL, 0, N'Unknown Invoice_ID: rejected, nothing written'),
 ('A23', 'T-F05-07', 'S', 'NULLID', 'CASH', 51201, NULL, NULL, NULL, NULL, NULL, 0, N'NULL Invoice_ID: rejected'),
 ('A24', 'T-F05-16', 'C', 'D1', NULL,    0, 'CANCELLED', NULL, NULL, 'CANCELLED', 'CARD', 1, N'Cancel a PENDING invoice: CANCELLED, PaidAt NULL, no spending, points or hook call'),
 ('A25', 'T-F05-07', 'S', 'D1', 'CARD',  51204, NULL, NULL, NULL, 'CANCELLED', 'CARD', 0, N'CANCELLED invoice cannot be settled: rejected, nothing written'),
 ('A26', 'T-F05-16', 'C', 'D1', NULL,    0, 'ALREADY_CANCELLED', NULL, NULL, 'CANCELLED', 'CARD', 0, N'Repeat cancellation: ALREADY_CANCELLED, no change'),
 ('A27', 'T-F05-16', 'C', 'A1', NULL,    51223, NULL, NULL, NULL, 'PAID', 'CASH', 0, N'PAID invoice cannot be cancelled (no refund, D-011): PAID is never reverted'),
 ('A28', 'T-F05-07', 'C', 'NONE', NULL,  51222, NULL, NULL, NULL, NULL, NULL, 0, N'Cancel an unknown Invoice_ID: rejected'),
 ('A29', 'T-F05-07', 'C', 'NULLID', NULL, 51221, NULL, NULL, NULL, NULL, NULL, 0, N'Cancel with NULL Invoice_ID: rejected');

DECLARE @cid varchar(8), @tid varchar(10), @op char(1), @expErr int, @expOut varchar(20), @expPts int, @expBal int, @expSt varchar(10), @expMeth varchar(10), @expChg bit, @descr nvarchar(300);
DECLARE k CURSOR LOCAL FAST_FORWARD FOR
    SELECT case_id, test_id, op, ref, method, exp_err, exp_outcome, exp_points, exp_balance, exp_status, exp_method, exp_change, descr FROM #case ORDER BY seq;
OPEN k;
FETCH NEXT FROM k INTO @cid, @tid, @op, @ref, @method, @expErr, @expOut, @expPts, @expBal, @expSt, @expMeth, @expChg, @descr;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @id = CASE @ref WHEN 'NONE' THEN 999999 WHEN 'NULLID' THEN NULL ELSE (SELECT Invoice_ID FROM #inv WHERE ref = @ref) END;
    SELECT @member = Member_ID, @final = FinalAmount FROM dbo.INVOICE WHERE Invoice_ID = @id;
    IF @@ROWCOUNT = 0 SELECT @member = NULL, @final = NULL;
    SELECT @spB = ISNULL((SELECT SUM(TotalSpend) FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = @member), 0),
           @ptB = (SELECT CurrentPoints FROM dbo.MEMBER WHERE Member_ID = @member);
    EXEC sys.sp_executesql @stateq, N'@h varchar(64) OUTPUT', @h = @hB OUTPUT;
    SELECT @err = 0, @emsg = N'', @outc = NULL, @pa = NULL, @pe = NULL, @cp = NULL, @t0 = SYSUTCDATETIME();
    BEGIN TRY
        IF @op = 'S'
            EXEC dbo.usp_P3_SettleInvoice @Invoice_ID = @id, @PaymentMethod = @method, @Outcome = @outc OUTPUT, @PaidAt = @pa OUTPUT,
                 @PointsEarned = @pe OUTPUT, @CurrentPoints = @cp OUTPUT;
        ELSE
            EXEC dbo.usp_P3_CancelInvoice @Invoice_ID = @id, @Outcome = @outc OUTPUT;
    END TRY
    BEGIN CATCH
        SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE();
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END CATCH;
    SELECT @t1 = SYSUTCDATETIME(), @tc = @@TRANCOUNT;
    EXEC sys.sp_executesql @stateq, N'@h varchar(64) OUTPUT', @h = @hA OUTPUT;
    EXEC sys.sp_executesql @vtotq, N'@n int OUTPUT', @n = @vt OUTPUT;
    SELECT @spA = ISNULL((SELECT SUM(TotalSpend) FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = @member), 0),
           @ptA = (SELECT CurrentPoints FROM dbo.MEMBER WHERE Member_ID = @member),
           @hk = (SELECT COUNT(*) FROM dbo.TEST_HookCallLog WHERE Invoice_ID = @id);
    SELECT @stStatus = NULL, @stMethod = NULL, @stPaid = NULL;
    SELECT @stStatus = PaymentStatus, @stMethod = PaymentMethod, @stPaid = PaidAt FROM dbo.INVOICE WHERE Invoice_ID = @id;

    SET @ok = CASE WHEN @err = @expErr AND @vt = 0 AND @tc = 0
                    AND (@expErr <> 0 OR ISNULL(@outc, '') = ISNULL(@expOut, ''))
                    AND (@expPts IS NULL OR @pe = @expPts)
                    AND (@expBal IS NULL OR @cp = @expBal)
                    AND ((@expChg = 1 AND @hB <> @hA) OR (@expChg = 0 AND @hB = @hA))
                    AND (@id IS NULL OR @member IS NULL OR (ISNULL(@stStatus, '') = ISNULL(@expSt, '') AND ISNULL(@stMethod, '') = ISNULL(@expMeth, '')))
                    AND (ISNULL(@outc, '') <> 'SETTLED' OR (@stPaid = @pa AND @pa >= DATEADD(MILLISECOND, -2, @t0) AND @pa <= DATEADD(MILLISECOND, 2, @t1)
                                                        AND @spA - @spB = @final AND @ptA - @ptB = @pe AND @ptA = @cp AND @hk = 2))
                    AND (ISNULL(@outc, '') <> 'ALREADY_SETTLED' OR (@pa = @stPaid AND @cp = @ptA AND @spA = @spB AND @hk = 2))
                    AND (ISNULL(@outc, '') <> 'CANCELLED' OR (@stPaid IS NULL AND @spA = @spB AND @ptA = @ptB AND @hk = 0))
               THEN 1 ELSE 0 END;
    SET @detail = CONCAT(N'invoice ', ISNULL(CONVERT(varchar(12), @id), 'NULL'), N'; error ', @err, CASE WHEN @err <> 0 THEN CONCAT(N' (', LEFT(@emsg, 160), N')') ELSE N'' END,
                         N'; outcome ', ISNULL(@outc, '-'), N'; points earned ', ISNULL(CONVERT(varchar(12), @pe), '-'), N'; balance ', ISNULL(CONVERT(varchar(12), @cp), '-'),
                         N'; stored ', ISNULL(@stStatus, '-'), N'/', ISNULL(@stMethod, '-'), N'/PaidAt ', ISNULL(CONVERT(varchar(30), @stPaid, 126), '-'),
                         N'; member spend ', @spB, N'->', @spA, N'; hook calls ', @hk, N'; state changed ', CASE WHEN @hB <> @hA THEN N'yes' ELSE N'no' END,
                         N'; V-TOT ', @vt, N'; open tran ', @tc);
    INSERT @results (case_id, test_id, result, descr, detail) VALUES (@cid, @tid, CASE WHEN @ok = 1 THEN 'PASS' ELSE 'FAIL' END, @descr, @detail);
    FETCH NEXT FROM k INTO @cid, @tid, @op, @ref, @method, @expErr, @expOut, @expPts, @expBal, @expSt, @expMeth, @expChg, @descr;
END;
CLOSE k; DEALLOCATE k;

/* ---------- Part B: TEST_ONLY invoices inserted directly (ineligible states) ---------- */
CREATE TABLE #bad (case_id varchar(8), test_id varchar(10), kind varchar(10), exp_err int, descr nvarchar(300));
INSERT #bad VALUES
 ('B01', 'T-F05-02', 'NOLINE',   51205, N'PENDING invoice without any line (BR12): settlement rejected, nothing written'),
 ('B02', 'T-F05-28', 'GROSS',    51206, N'Header GrossAmount (100,000) differs from its line (90,000): settlement rejected, nothing written'),
 ('B03', 'T-F05-28', 'DISCOUNT', 51206, N'Header DiscountAmount (0) differs from the line discount (5,000): settlement rejected'),
 ('B04', 'T-F05-31', 'FUTURE',   51212, N'IssuedAt one day in the future (settlement time would precede it, D-004): rejected');
DECLARE @bkind varchar(10);
DECLARE b CURSOR LOCAL FAST_FORWARD FOR SELECT case_id, test_id, kind, exp_err, descr FROM #bad ORDER BY case_id;
OPEN b;
FETCH NEXT FROM b INTO @cid, @tid, @bkind, @expErr, @descr;
WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount, PaymentMethod, PaymentStatus, PaidAt)
    VALUES (11, 1, 1, CASE WHEN @bkind = 'FUTURE' THEN DATEADD(DAY, 1, SYSUTCDATETIME()) ELSE SYSUTCDATETIME() END,
            100000, 0, 100000, 'CASH', 'PENDING', NULL);
    SET @id = SCOPE_IDENTITY();
    IF @bkind = 'GROSS'    INSERT dbo.INVOICE_PRODUCT_ITEM (Invoice_ID, [LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount) VALUES (@id, 1, 1, 1, 90000, 0);
    IF @bkind = 'DISCOUNT' INSERT dbo.INVOICE_PRODUCT_ITEM (Invoice_ID, [LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount) VALUES (@id, 1, 1, 1, 100000, 5000);
    IF @bkind = 'FUTURE'   INSERT dbo.INVOICE_PRODUCT_ITEM (Invoice_ID, [LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount) VALUES (@id, 1, 1, 1, 100000, 0);
    EXEC sys.sp_executesql @stateq, N'@h varchar(64) OUTPUT', @h = @hB OUTPUT;
    SELECT @err = 0, @emsg = N'', @outc = NULL;
    BEGIN TRY
        EXEC dbo.usp_P3_SettleInvoice @Invoice_ID = @id, @PaymentMethod = 'CASH', @Outcome = @outc OUTPUT;
    END TRY
    BEGIN CATCH
        SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE();
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END CATCH;
    SET @tc = @@TRANCOUNT;
    EXEC sys.sp_executesql @stateq, N'@h varchar(64) OUTPUT', @h = @hA OUTPUT;
    SELECT @stStatus = PaymentStatus, @stPaid = PaidAt FROM dbo.INVOICE WHERE Invoice_ID = @id;
    -- remove the TEST_ONLY invoice (it violates D-023/BR12 or D-004 by construction)
    DELETE dbo.INVOICE_PRODUCT_ITEM WHERE Invoice_ID = @id;
    DELETE dbo.INVOICE WHERE Invoice_ID = @id;
    EXEC sys.sp_executesql @vtotq, N'@n int OUTPUT', @n = @vt OUTPUT;
    SET @ok = CASE WHEN @err = @expErr AND @hB = @hA AND @stStatus = 'PENDING' AND @stPaid IS NULL AND @tc = 0 AND @vt = 0
                    AND NOT EXISTS (SELECT 1 FROM dbo.TEST_HookCallLog WHERE Invoice_ID = @id) THEN 1 ELSE 0 END;
    INSERT @results (case_id, test_id, result, descr, detail) VALUES (@cid, @tid, CASE WHEN @ok = 1 THEN 'PASS' ELSE 'FAIL' END, @descr,
        CONCAT(N'TEST_ONLY invoice ', @id, N'; error ', @err, N' (', LEFT(@emsg, 200), N'); stored ', @stStatus, N'; state changed ', CASE WHEN @hB <> @hA THEN N'yes' ELSE N'no' END,
               N'; removed afterwards; V-TOT ', @vt, N'; open tran ', @tc));
    FETCH NEXT FROM b INTO @cid, @tid, @bkind, @expErr, @descr;
END;
CLOSE b; DEALLOCATE b;

/* ---------- Part C: rollback of late failures (T-F05-08) and hook failures (T-F05-22) ---------- */
CREATE TABLE #rb (case_id varchar(8), test_id varchar(10), kind varchar(12), exp_err int, descr nvarchar(300));
INSERT #rb VALUES
 ('C01', 'T-F05-08', 'TRG_MEMBER', 52910, N'Injected failure at the last step (MEMBER points update; TEST_ONLY trigger): whole settlement rolled back, error passed through'),
 ('C02', 'T-F05-08', 'TRG_SPEND',  52911, N'Injected failure at the spending step (TEST_ONLY trigger on MEMBER_MONTHLY_SPENDING): whole settlement rolled back'),
 ('C03', 'T-F05-22', 'HOOK_INV',   52901, N'Inventory hook double raises an error (e.g. insufficient stock): whole settlement rolled back, error passed through unchanged'),
 ('C04', 'T-F05-22', 'HOOK_ENT',   52902, N'Entitlement hook double raises an error after the inventory hook ran: both hook effects and everything else rolled back');
SET @id = (SELECT Invoice_ID FROM #inv WHERE ref = 'F1');
DECLARE r CURSOR LOCAL FAST_FORWARD FOR SELECT case_id, test_id, kind, exp_err, descr FROM #rb ORDER BY case_id;
OPEN r;
FETCH NEXT FROM r INTO @cid, @tid, @bkind, @expErr, @descr;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF @bkind = 'TRG_MEMBER' EXEC (N'CREATE TRIGGER dbo.TEST_trg_FailMemberUpdate ON dbo.MEMBER AFTER UPDATE AS BEGIN SET NOCOUNT ON; THROW 52910, N''TEST_ONLY injected failure at the MEMBER step (06 section 4.8 i).'', 1; END');
    IF @bkind = 'TRG_SPEND'  EXEC (N'CREATE TRIGGER dbo.TEST_trg_FailSpending ON dbo.MEMBER_MONTHLY_SPENDING AFTER INSERT, UPDATE AS BEGIN SET NOCOUNT ON; THROW 52911, N''TEST_ONLY injected failure at the spending step.'', 1; END');
    IF @bkind = 'HOOK_INV'   INSERT dbo.TEST_HookFault (HookName, Invoice_ID) VALUES ('INVENTORY_DECREMENT', @id);
    IF @bkind = 'HOOK_ENT'   INSERT dbo.TEST_HookFault (HookName, Invoice_ID) VALUES ('ENTITLEMENT_ACTIVATION', @id);
    EXEC sys.sp_executesql @stateq, N'@h varchar(64) OUTPUT', @h = @hB OUTPUT;
    SELECT @err = 0, @emsg = N'', @outc = NULL;
    BEGIN TRY
        EXEC dbo.usp_P3_SettleInvoice @Invoice_ID = @id, @PaymentMethod = 'CASH', @Outcome = @outc OUTPUT;
    END TRY
    BEGIN CATCH
        SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE();
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END CATCH;
    SET @tc = @@TRANCOUNT;
    EXEC sys.sp_executesql @stateq, N'@h varchar(64) OUTPUT', @h = @hA OUTPUT;
    IF OBJECT_ID(N'dbo.TEST_trg_FailMemberUpdate', N'TR') IS NOT NULL DROP TRIGGER dbo.TEST_trg_FailMemberUpdate;
    IF OBJECT_ID(N'dbo.TEST_trg_FailSpending', N'TR') IS NOT NULL DROP TRIGGER dbo.TEST_trg_FailSpending;
    DELETE dbo.TEST_HookFault;
    SELECT @stStatus = PaymentStatus, @stMethod = PaymentMethod, @stPaid = PaidAt FROM dbo.INVOICE WHERE Invoice_ID = @id;
    SET @ok = CASE WHEN @err = @expErr AND @hB = @hA AND @stStatus = 'PENDING' AND @stPaid IS NULL AND @stMethod IS NULL AND @tc = 0
                    AND NOT EXISTS (SELECT 1 FROM dbo.TEST_HookCallLog WHERE Invoice_ID = @id)
                    AND NOT EXISTS (SELECT 1 FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = 10)
                    AND (SELECT CurrentPoints FROM dbo.MEMBER WHERE Member_ID = 10) = 0 THEN 1 ELSE 0 END;
    INSERT @results (case_id, test_id, result, descr, detail) VALUES (@cid, @tid, CASE WHEN @ok = 1 THEN 'PASS' ELSE 'FAIL' END, @descr,
        CONCAT(N'invoice F1 ', @id, N'; error ', @err, N' (', LEFT(@emsg, 160), N'); stored ', @stStatus, N'/', ISNULL(@stMethod, '-'), N'/PaidAt ', ISNULL(CONVERT(varchar(30), @stPaid, 126), '-'),
               N'; state changed ', CASE WHEN @hB <> @hA THEN N'yes' ELSE N'no' END, N'; member 10 spending rows ', (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = 10),
               N'; hook calls kept ', (SELECT COUNT(*) FROM dbo.TEST_HookCallLog WHERE Invoice_ID = @id), N'; open tran ', @tc,
               N'; TEST_ONLY trigger/fault removed: ', CASE WHEN NOT EXISTS (SELECT 1 FROM sys.triggers) AND NOT EXISTS (SELECT 1 FROM dbo.TEST_HookFault) THEN N'yes' ELSE N'NO' END));
    FETCH NEXT FROM r INTO @cid, @tid, @bkind, @expErr, @descr;
END;
CLOSE r; DEALLOCATE r;

-- C05: the same invoice settles normally afterwards (no residue from the failed attempts)
SELECT @err = 0, @emsg = N'', @outc = NULL, @pe = NULL, @cp = NULL;
BEGIN TRY
    EXEC dbo.usp_P3_SettleInvoice @Invoice_ID = @id, @PaymentMethod = 'CASH', @Outcome = @outc OUTPUT, @PointsEarned = @pe OUTPUT, @CurrentPoints = @cp OUTPUT;
END TRY
BEGIN CATCH
    SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
END CATCH;
SET @ok = CASE WHEN @err = 0 AND @outc = 'SETTLED' AND @pe = 3 AND @cp = 3
                AND (SELECT COUNT(*) FROM dbo.TEST_HookCallLog WHERE Invoice_ID = @id) = 2
                AND (SELECT TotalSpend FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = 10) = 300000 THEN 1 ELSE 0 END;
INSERT @results (case_id, test_id, result, descr, detail) VALUES ('C05', 'T-F05-08', CASE WHEN @ok = 1 THEN 'PASS' ELSE 'FAIL' END,
    N'After the four failed attempts the same invoice settles once: 300,000 -> 3 points, one call per hook',
    CONCAT(N'error ', @err, N' ', LEFT(@emsg, 160), N'; outcome ', ISNULL(@outc, '-'), N'; points ', ISNULL(CONVERT(varchar(12), @pe), '-'), N'; balance ', ISNULL(CONVERT(varchar(12), @cp), '-')));

/* ---------- Part D: composition inside a caller's transaction (T-F05-29) ---------- */
-- D01 commit
SET @id = (SELECT Invoice_ID FROM #inv WHERE ref = 'F2');
SELECT @err = 0, @emsg = N'', @outc = NULL, @pe = NULL, @cp = NULL;
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.usp_P3_SettleInvoice @Invoice_ID = @id, @PaymentMethod = NULL, @Outcome = @outc OUTPUT, @PointsEarned = @pe OUTPUT, @CurrentPoints = @cp OUTPUT;
    SET @tc = @@TRANCOUNT;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
END CATCH;
SELECT @stStatus = PaymentStatus, @stMethod = PaymentMethod FROM dbo.INVOICE WHERE Invoice_ID = @id;
SET @ok = CASE WHEN @err = 0 AND @outc = 'SETTLED' AND @tc = 1 AND @@TRANCOUNT = 0 AND @stStatus = 'PAID' AND @stMethod = 'CASH' AND @pe = 1 AND @cp = 4
                AND (SELECT CurrentPoints FROM dbo.MEMBER WHERE Member_ID = 10) = 4 THEN 1 ELSE 0 END;
INSERT @results (case_id, test_id, result, descr, detail) VALUES ('D01', 'T-F05-29', CASE WHEN @ok = 1 THEN 'PASS' ELSE 'FAIL' END,
    N'Inside a caller transaction + COMMIT: the routine joins (does not commit itself); the commit keeps PAID, spending and points (400,000 -> 4)',
    CONCAT(N'error ', @err, N'; outcome ', ISNULL(@outc, '-'), N'; @@TRANCOUNT after the call ', @tc, N'; stored ', @stStatus, N'/', @stMethod, N'; points ', @pe, N'; balance ', @cp));

-- D02 rollback
SET @id = (SELECT Invoice_ID FROM #inv WHERE ref = 'F3');
EXEC sys.sp_executesql @stateq, N'@h varchar(64) OUTPUT', @h = @hB OUTPUT;
SELECT @err = 0, @emsg = N'', @outc = NULL;
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.usp_P3_SettleInvoice @Invoice_ID = @id, @PaymentMethod = 'CARD', @Outcome = @outc OUTPUT;
    SET @tc = @@TRANCOUNT;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
END CATCH;
EXEC sys.sp_executesql @stateq, N'@h varchar(64) OUTPUT', @h = @hA OUTPUT;
SET @ok = CASE WHEN @err = 0 AND @outc = 'SETTLED' AND @tc = 1 AND @@TRANCOUNT = 0 AND @hB = @hA
                AND (SELECT PaymentStatus FROM dbo.INVOICE WHERE Invoice_ID = @id) = 'PENDING' THEN 1 ELSE 0 END;
INSERT @results (case_id, test_id, result, descr, detail) VALUES ('D02', 'T-F05-29', CASE WHEN @ok = 1 THEN 'PASS' ELSE 'FAIL' END,
    N'Inside a caller transaction + ROLLBACK: status, PaidAt, spending, points and hook calls all removed',
    CONCAT(N'error ', @err, N'; outcome inside ', ISNULL(@outc, '-'), N'; state after rollback = before: ', CASE WHEN @hB = @hA THEN N'yes' ELSE N'NO' END));

-- D03 error inside the caller transaction after a successful settlement
EXEC sys.sp_executesql @stateq, N'@h varchar(64) OUTPUT', @h = @hB OUTPUT;
SELECT @err = 0, @emsg = N'', @outc = NULL, @xs = NULL;
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.usp_P3_SettleInvoice @Invoice_ID = @id, @PaymentMethod = 'CARD', @Outcome = @outc OUTPUT;
    DECLARE @d1 int = (SELECT Invoice_ID FROM #inv WHERE ref = 'D1');
    EXEC dbo.usp_P3_SettleInvoice @Invoice_ID = @d1, @PaymentMethod = 'CARD';   -- CANCELLED -> 51204
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE(), @xs = XACT_STATE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
END CATCH;
EXEC sys.sp_executesql @stateq, N'@h varchar(64) OUTPUT', @h = @hA OUTPUT;
SET @ok = CASE WHEN @err = 51204 AND @xs = -1 AND @outc = 'SETTLED' AND @@TRANCOUNT = 0 AND @hB = @hA
                AND (SELECT PaymentStatus FROM dbo.INVOICE WHERE Invoice_ID = @id) = 'PENDING' THEN 1 ELSE 0 END;
INSERT @results (case_id, test_id, result, descr, detail) VALUES ('D03', 'T-F05-29', CASE WHEN @ok = 1 THEN 'PASS' ELSE 'FAIL' END,
    N'Error in a later call of the same caller transaction: the transaction is uncommittable (XACT_STATE -1); one rollback removes the earlier settlement too',
    CONCAT(N'first call ', ISNULL(@outc, '-'), N'; error ', @err, N' (', LEFT(@emsg, 120), N'); XACT_STATE in CATCH ', ISNULL(CONVERT(varchar(4), @xs), '-'),
           N'; state after rollback = before: ', CASE WHEN @hB = @hA THEN N'yes' ELSE N'NO' END));

-- D04 the same invoice settles on its own afterwards
SELECT @err = 0, @emsg = N'', @outc = NULL, @pe = NULL, @cp = NULL;
BEGIN TRY
    EXEC dbo.usp_P3_SettleInvoice @Invoice_ID = @id, @PaymentMethod = 'CARD', @Outcome = @outc OUTPUT, @PointsEarned = @pe OUTPUT, @CurrentPoints = @cp OUTPUT;
END TRY
BEGIN CATCH
    SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
END CATCH;
SET @ok = CASE WHEN @err = 0 AND @outc = 'SETTLED' AND @pe = 2 AND @cp = 6
                AND (SELECT TotalSpend FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = 10) = 650000 THEN 1 ELSE 0 END;
INSERT @results (case_id, test_id, result, descr, detail) VALUES ('D04', 'T-F05-29', CASE WHEN @ok = 1 THEN 'PASS' ELSE 'FAIL' END,
    N'After the rolled-back attempts the invoice settles once on its own: 650,000 -> 6 points (+2)',
    CONCAT(N'error ', @err, N'; outcome ', ISNULL(@outc, '-'), N'; points ', ISNULL(CONVERT(varchar(12), @pe), '-'), N'; balance ', ISNULL(CONVERT(varchar(12), @cp), '-')));

/* ---------- Part E: spending month (T-F05-10) ---------- */
DECLARE @e1 date = (SELECT SpendingMonth FROM dbo.tvf_P3_SpendingMonth('2026-01-31T16:59:59.999'));
DECLARE @e2 date = (SELECT SpendingMonth FROM dbo.tvf_P3_SpendingMonth('2026-01-31T17:00:00.000'));
DECLARE @e3 date = (SELECT SpendingMonth FROM dbo.tvf_P3_SpendingMonth('2026-12-31T17:00:00.000'));
DECLARE @e4 date = (SELECT SpendingMonth FROM dbo.tvf_P3_SpendingMonth('2028-02-28T17:30:00.000'));
INSERT @results (case_id, test_id, result, descr, detail) VALUES ('E01', 'T-F05-10',
    CASE WHEN @e1 = '2026-01-01' AND @e2 = '2026-02-01' AND @e3 = '2027-01-01' AND @e4 = '2028-02-01' THEN 'PASS' ELSE 'FAIL' END,
    N'Month boundary with UTC storage: 2026-01-31 16:59:59.999 UTC -> January; 17:00:00.000 UTC (= Feb 1 00:00 local) -> February; year end; leap day',
    CONCAT(N'results: ', @e1, N', ', @e2, N', ', @e3, N', ', @e4));

-- every minute boundary around each month end of 2026-2028, plus every hour of 2026, against the AT TIME ZONE oracle
WITH pts AS (
    SELECT DATEADD(MILLISECOND, o.ms, DATEADD(HOUR, 17, CAST(EOMONTH(DATEFROMPARTS(y.value, m.value, 1)) AS datetime2(3)))) AS t
    FROM GENERATE_SERIES(2026, 2028) AS y CROSS JOIN GENERATE_SERIES(1, 12) AS m
    CROSS JOIN (VALUES (-3600000), (-60000), (-1), (0), (1), (60000), (3600000)) AS o(ms)
    UNION ALL
    SELECT DATEADD(HOUR, h.value, CAST('2026-01-01T00:00:00' AS datetime2(3))) FROM GENERATE_SERIES(0, 8759) AS h)
SELECT @n1 = COUNT(*), @n2 = SUM(CASE WHEN f.SpendingMonth <> DATEFROMPARTS(YEAR(o.loc), MONTH(o.loc), 1) THEN 1 ELSE 0 END)
FROM pts CROSS APPLY dbo.tvf_P3_SpendingMonth(pts.t) AS f
CROSS APPLY (SELECT CONVERT(datetime2(3), (pts.t AT TIME ZONE 'UTC') AT TIME ZONE 'SE Asia Standard Time') AS loc) AS o;
INSERT @results (case_id, test_id, result, descr, detail) VALUES ('E02', 'T-F05-10', CASE WHEN @n1 > 9000 AND @n2 = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Month function = independent oracle (AT TIME ZONE ''SE Asia Standard Time'') at every month end 2026-2028 (+/-1 ms, 1 min, 1 h) and every hour of 2026',
    CONCAT(N'points compared: ', @n1, N'; mismatches: ', @n2));

SELECT @n1 = COUNT(*), @n2 = SUM(CASE WHEN s.Member_ID IS NULL THEN 1 ELSE 0 END)
FROM dbo.INVOICE AS i CROSS APPLY dbo.tvf_P3_SpendingMonth(i.PaidAt) AS f
LEFT JOIN dbo.MEMBER_MONTHLY_SPENDING AS s ON s.Member_ID = i.Member_ID AND s.SpendingMonth = f.SpendingMonth
WHERE i.PaymentStatus = 'PAID';
INSERT @results (case_id, test_id, result, descr, detail) VALUES ('E03', 'T-F05-10', CASE WHEN @n1 > 0 AND @n2 = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'End to end: every PAID invoice is counted in the spending row of its member and local month of PaidAt (full reconciliation: V-UC05S U3)',
    CONCAT(N'PAID invoices: ', @n1, N'; without their spending row: ', @n2));

/* ---------- Part F: least privilege (T-F05-30) ---------- */
SET @id = (SELECT Invoice_ID FROM #inv WHERE ref = 'L1');
DECLARE @a1 int = (SELECT Invoice_ID FROM #inv WHERE ref = 'A1');
DECLARE @eSettle int = -1, @eUpdInv int = -1, @eUpdMem int = -1, @eInsSp int = -1, @eHook int = -1, @eCancel int = -1;
EXEC (N'CREATE ROLE TEST_p3_settlement_caller;');
EXEC (N'GRANT EXECUTE ON OBJECT::dbo.usp_P3_SettleInvoice TO TEST_p3_settlement_caller; GRANT EXECUTE ON OBJECT::dbo.usp_P3_CancelInvoice TO TEST_p3_settlement_caller;');
EXEC (N'CREATE USER TEST_p3_settle_user WITHOUT LOGIN; ALTER ROLE TEST_p3_settlement_caller ADD MEMBER TEST_p3_settle_user;');
EXECUTE AS USER = N'TEST_p3_settle_user';
BEGIN TRY EXEC dbo.usp_P3_SettleInvoice @Invoice_ID = @id, @PaymentMethod = 'CASH', @Outcome = @outc OUTPUT; SET @eSettle = 0; END TRY
BEGIN CATCH SET @eSettle = ERROR_NUMBER(); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY EXEC dbo.usp_P3_CancelInvoice @Invoice_ID = @a1; SET @eCancel = 0; END TRY
BEGIN CATCH SET @eCancel = ERROR_NUMBER(); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY UPDATE dbo.INVOICE SET PaymentStatus = 'PENDING', PaidAt = NULL WHERE Invoice_ID = @a1; SET @eUpdInv = 0; END TRY
BEGIN CATCH SET @eUpdInv = ERROR_NUMBER(); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY UPDATE dbo.MEMBER SET CurrentPoints = CurrentPoints + 100 WHERE Member_ID = 1; SET @eUpdMem = 0; END TRY
BEGIN CATCH SET @eUpdMem = ERROR_NUMBER(); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY INSERT dbo.MEMBER_MONTHLY_SPENDING (Member_ID, SpendingMonth, TotalSpend, PointsEarned, UpdatedAt) VALUES (40, '2026-01-01', 1, 0, SYSUTCDATETIME()); SET @eInsSp = 0; END TRY
BEGIN CATCH SET @eInsSp = ERROR_NUMBER(); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY EXEC dbo.usp_HOOK_InventoryDecrementForInvoice @Invoice_ID = @a1; SET @eHook = 0; END TRY
BEGIN CATCH SET @eHook = ERROR_NUMBER(); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
REVERT;
EXEC (N'ALTER ROLE TEST_p3_settlement_caller DROP MEMBER TEST_p3_settle_user; DROP USER TEST_p3_settle_user; DROP ROLE TEST_p3_settlement_caller;');
SET @ok = CASE WHEN @eSettle = 0 AND @eCancel = 51223 AND @eUpdInv = 229 AND @eUpdMem = 229 AND @eInsSp = 229 AND @eHook = 229
                AND (SELECT PaymentStatus FROM dbo.INVOICE WHERE Invoice_ID = @id) = 'PAID'
                AND (SELECT PaymentStatus FROM dbo.INVOICE WHERE Invoice_ID = @a1) = 'PAID'
                AND (SELECT CurrentPoints FROM dbo.MEMBER WHERE Member_ID = 1) = 2
                AND NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name LIKE N'TEST[_]p3%') THEN 1 ELSE 0 END;
INSERT @results (case_id, test_id, result, descr, detail) VALUES ('F01', 'T-F05-30', CASE WHEN @ok = 1 THEN 'PASS' ELSE 'FAIL' END,
    N'Least privilege (TEST_ONLY role): EXECUTE on the routines suffices to settle; cancelling a PAID invoice is refused; direct reversal of PAID, direct points or spending changes and direct hook calls are denied (229)',
    CONCAT(N'settle ', @eSettle, N'; cancel PAID ', @eCancel, N'; UPDATE INVOICE PAID->PENDING ', @eUpdInv, N'; UPDATE MEMBER points ', @eUpdMem,
           N'; INSERT spending ', @eInsSp, N'; EXEC hook ', @eHook, N'; principals dropped: ', CASE WHEN NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name LIKE N'TEST[_]p3%') THEN N'yes' ELSE N'NO' END));

/* ---------- Part G: hook calls (T-F05-21) ---------- */
WITH h AS (
    SELECT i.Invoice_ID, i.PaymentStatus,
           SUM(CASE WHEN l.HookName = 'INVENTORY_DECREMENT' THEN 1 ELSE 0 END) AS inv_calls,
           SUM(CASE WHEN l.HookName = 'ENTITLEMENT_ACTIVATION' THEN 1 ELSE 0 END) AS ent_calls,
           MIN(CASE WHEN l.HookName = 'INVENTORY_DECREMENT' THEN l.Seq END) AS inv_seq,
           MIN(CASE WHEN l.HookName = 'ENTITLEMENT_ACTIVATION' THEN l.Seq END) AS ent_seq,
           SUM(CASE WHEN l.Seq IS NOT NULL AND (l.StatusSeen <> 'PENDING' OR l.TranCount < 1) THEN 1 ELSE 0 END) AS bad
    FROM dbo.INVOICE AS i LEFT JOIN dbo.TEST_HookCallLog AS l ON l.Invoice_ID = i.Invoice_ID
    GROUP BY i.Invoice_ID, i.PaymentStatus)
SELECT @n1 = SUM(CASE WHEN PaymentStatus = 'PAID' THEN 1 ELSE 0 END),
       @n2 = SUM(CASE WHEN (PaymentStatus = 'PAID' AND (inv_calls <> 1 OR ent_calls <> 1 OR inv_seq > ent_seq)) OR (PaymentStatus <> 'PAID' AND inv_calls + ent_calls > 0) OR bad > 0 THEN 1 ELSE 0 END)
FROM h;
INSERT @results (case_id, test_id, result, descr, detail) VALUES ('G01', 'T-F05-21', CASE WHEN @n1 > 0 AND @n2 = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Each settled invoice: exactly one inventory then one entitlement hook call, inside the transaction while PENDING; none for repeated, rejected, rolled-back or cancelled requests',
    CONCAT(N'PAID invoices: ', @n1, N'; invoices with wrong calls: ', @n2, N'; calls logged: ', (SELECT COUNT(*) FROM dbo.TEST_HookCallLog)));

/* ---------- report ---------- */
SELECT case_id, test_id, result, descr, detail FROM @results ORDER BY seq;
SELECT test_id, COUNT(*) AS cases, SUM(CASE WHEN result = 'PASS' THEN 1 ELSE 0 END) AS passed FROM @results GROUP BY test_id ORDER BY test_id;
SELECT (SELECT COUNT(*) FROM dbo.INVOICE) AS invoices, (SELECT COUNT(*) FROM dbo.INVOICE WHERE PaymentStatus = 'PAID') AS paid,
       (SELECT COUNT(*) FROM dbo.INVOICE WHERE PaymentStatus = 'CANCELLED') AS cancelled, (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING) AS spending_rows,
       (SELECT SUM(CurrentPoints) FROM dbo.MEMBER) AS total_points, (SELECT COUNT(*) FROM dbo.TEST_HookCallLog) AS hook_calls;

DECLARE @fails int = (SELECT COUNT(*) FROM @results WHERE result <> 'PASS'), @ncases int = (SELECT COUNT(*) FROM @results);
PRINT CONCAT('T-F05S SUMMARY: cases=', @ncases, ' FAIL=', @fails);
IF @fails > 0
BEGIN
    PRINT 'T-F05S_RESULT: FAIL';
    THROW 51264, N'T-F05S failed (see the case table).', 1;
END
ELSE
    PRINT 'T-F05S_RESULT: PASS';
GO
