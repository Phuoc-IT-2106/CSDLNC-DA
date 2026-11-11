/* =====================================================================
   usp_P3_SettleInvoice.sql
   Classification : P3_OWNED - production routine (Person 3). Programmability only:
                    creates no table, column, constraint or index.
   Work order     : WO-P3-P3-01 - Settlement Routine (F06 + F20 effects)
   Objects        : dbo.tvf_P3_SpendingMonth  (inline function: UTC payment time -> spending month)
                    dbo.usp_P3_SettleInvoice   (procedure)
   Purpose        : settle ONE invoice: PENDING -> PAID with PaidAt (UTC) and PaymentMethod, the
                    two integration hooks, the member's monthly spending and loyalty points - all
                    in ONE transaction, exactly once per invoice.
   Decisions      : D-003 (A) invoice-state model: the PENDING->PAID transition is the idempotency
                    token; D-004 PaidAt (UTC, >= IssuedAt); D-005 domains and transitions (PAID and
                    CANCELLED are terminal); D-006 points = FLOOR(TotalSpend(member, month) / 100000),
                    credited incrementally in the same statement as the TotalSpend increase;
                    D-012 (a) one transaction owned by this routine, hooks called inside it
                    (APPROVED provisional T2, 2026-11-09); D-013 SpendingMonth = first day of the
                    Asia/Ho_Chi_Minh month of PaidAt; D-014 UTC timestamps, Asia/Ho_Chi_Minh = UTC+7
                    without daylight saving (same rule as the seed generator S001); D-019 (a) default
                    READ COMMITTED (locking), UPDLOCK on the invoice row, conditional transition,
                    UPDLOCK+HOLDLOCK upsert of the spending row, atomic increments (APPROVED
                    provisional T2, 2026-11-09); D-023 header = sum of lines checked before
                    settlement; D-024 accrual only (no redemption, no expiry).
   Interface      : @Invoice_ID        required
                    @PaymentMethod     optional: CASH | VNPAY | CARD. If NULL, the method recorded at
                                       creation is used. If both are given they must be equal (the
                                       recorded method is never overwritten silently).
                    @Outcome OUTPUT    'SETTLED' or 'ALREADY_SETTLED'
                    @PaidAt OUTPUT     settlement time (UTC); for ALREADY_SETTLED the stored value
                    @PointsEarned OUTPUT  points credited by THIS call (0 for ALREADY_SETTLED)
                    @CurrentPoints OUTPUT the member's balance after the call
                    Return value 0 on success. On any failure an error is raised and NOTHING is
                    written (status, PaidAt, method, spending, points and hook effects unchanged).
   Steps          : 1 validate parameters (no write); 2 lock the invoice row (UPDLOCK) - concurrent
                    settlers of the same invoice queue here; 3 PAID -> ALREADY_SETTLED, no effect;
                    other non-PENDING -> error; 4 eligibility: method resolved, at least one line
                    (BR12), header = sum of stored lines (D-023 X1), PaidAt >= IssuedAt;
                    5 hooks in the lock order of 12 section 6 (inventory, then entitlement);
                    6 conditional transition PENDING -> PAID (exactly one row); 7 spending upsert
                    for (member, local month of PaidAt); 8 points increment on MEMBER; commit.
   Lock order     : INVOICE row -> inventory (hook) -> service items (hook) -> MEMBER_MONTHLY_SPENDING
                    row -> MEMBER row (12 section 6).
   Errors         : 51201-51212 (P3 range, DEP-13). Hook and engine errors pass through unchanged.
                      51201 Invoice_ID missing           51207 no payment method (none given, none recorded)
                      51202 invalid PaymentMethod        51208 method differs from the recorded one
                      51203 invoice not found            51209 transition did not change exactly one row
                      51204 invoice not payable          51210 points would decrease (defensive)
                            (status CANCELLED)           51211 member row not updated (defensive)
                      51205 invoice has no line (BR12)   51212 settlement time before IssuedAt
                      51206 header totals differ from the lines (D-023 X1)
   Transactions   : SET XACT_ABORT ON. Without an open transaction the routine owns one and commits
                    or rolls it back. Inside a caller's transaction it joins it, never commits or
                    rolls it back, and re-raises any error, leaving the caller's transaction
                    uncommittable (12 section 4).
   Hooks          : dbo.usp_HOOK_InventoryDecrementForInvoice and dbo.usp_HOOK_EntitlementActivationForInvoice
                    (@Invoice_ID INT) belong to other members (UC04, UC01). In isolated databases they
                    are TEST_ONLY contract-only doubles (tests/db/doubles/D001...); the real routines
                    are wired and tested at P6 (DEP-05, WO-P3-P6-01).
   Not done here  : tier evaluation or upgrade (D-007/D-008/D-009 PROPOSED; WO-P3-P3-02); revenue
                    summary (D-015/D-016 DEFERRED); refunds (D-011); the benchmark-only baseline
                    variant U0 (task 2, blocked by D-007/D-008); stock or entitlement logic (hooks).
   Re-runnable    : CREATE OR ALTER.
   Run            : sqlcmd -S localhost -E -I -b -d <database> -i db/procedures/usp_P3_SettleInvoice.sql
   ===================================================================== */
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.INVOICE', N'U') IS NULL OR OBJECT_ID(N'dbo.MEMBER_MONTHLY_SPENDING', N'U') IS NULL
   OR COL_LENGTH(N'dbo.INVOICE', N'PaidAt') IS NULL
    THROW 51200, N'usp_P3_SettleInvoice requires migrations V001 and V002.', 1;
IF COL_LENGTH(N'dbo.MEMBER', N'CurrentPoints') IS NULL
    THROW 51200, N'usp_P3_SettleInvoice requires MEMBER.CurrentPoints (shared dependency DEP-02; TEST_ONLY F002P in isolated databases).', 1;
GO

/* Spending month of a UTC payment time: first day of the Asia/Ho_Chi_Minh (UTC+7, no DST) month. */
CREATE OR ALTER FUNCTION dbo.tvf_P3_SpendingMonth (@PaidAtUtc DATETIME2(3))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT DATEFROMPARTS(YEAR(l.LocalTime), MONTH(l.LocalTime), 1) AS SpendingMonth
    FROM (SELECT DATEADD(HOUR, 7, @PaidAtUtc) AS LocalTime) AS l;
GO

CREATE OR ALTER PROCEDURE dbo.usp_P3_SettleInvoice
    @Invoice_ID     INT,
    @PaymentMethod  VARCHAR(10) = NULL,
    @Outcome        VARCHAR(20) = NULL OUTPUT,
    @PaidAt         DATETIME2(3) = NULL OUTPUT,
    @PointsEarned   INT = NULL OUTPUT,
    @CurrentPoints  INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @msg nvarchar(2048), @ownTran bit;
    DECLARE @status varchar(10), @storedMethod varchar(10), @method varchar(10), @member int,
            @issuedAt datetime2(3), @storedPaidAt datetime2(3), @now datetime2(3), @month date,
            @gross decimal(18,2), @discount decimal(18,2), @final decimal(18,2);
    DECLARE @lines int, @lineGross decimal(38,2), @lineDiscount decimal(38,2);
    DECLARE @oldPoints int, @newPoints int, @delta int, @balance int;
    DECLARE @spend TABLE (OldPoints int NULL, NewPoints int NOT NULL);
    DECLARE @mem TABLE (CurrentPoints int NOT NULL);

    SELECT @Outcome = NULL, @PaidAt = NULL, @PointsEarned = NULL, @CurrentPoints = NULL;

    /* ---------- 1. Validate parameters (no write) ---------- */
    IF @Invoice_ID IS NULL
        THROW 51201, N'usp_P3_SettleInvoice: Invoice_ID is required.', 1;
    -- D-005 domain, compared exactly (binary, no trailing space).
    IF @PaymentMethod IS NOT NULL
       AND (@PaymentMethod COLLATE Latin1_General_BIN2 NOT IN ('CASH', 'VNPAY', 'CARD') OR DATALENGTH(@PaymentMethod) <> LEN(@PaymentMethod))
    BEGIN
        SET @msg = CONCAT(N'usp_P3_SettleInvoice: PaymentMethod ''', @PaymentMethod, N''' is not one of CASH, VNPAY, CARD.');
        THROW 51202, @msg, 1;
    END;

    SET @ownTran = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @ownTran = 1 BEGIN TRANSACTION;

        /* ---------- 2. Lock the invoice row; concurrent settlers of this invoice wait here ---------- */
        SELECT @status = PaymentStatus, @storedMethod = PaymentMethod, @member = Member_ID, @issuedAt = IssuedAt,
               @storedPaidAt = PaidAt, @gross = GrossAmount, @discount = DiscountAmount, @final = FinalAmount
        FROM dbo.INVOICE WITH (UPDLOCK, ROWLOCK)
        WHERE Invoice_ID = @Invoice_ID;
        IF @@ROWCOUNT = 0
        BEGIN
            SET @msg = CONCAT(N'usp_P3_SettleInvoice: invoice ', @Invoice_ID, N' does not exist.');
            THROW 51203, @msg, 1;
        END;

        /* ---------- 3. Idempotent repeat: already PAID -> no effect at all ---------- */
        IF @status = 'PAID'
        BEGIN
            SELECT @balance = CurrentPoints FROM dbo.MEMBER WHERE Member_ID = @member;
            IF @ownTran = 1 COMMIT TRANSACTION;
            SELECT @Outcome = 'ALREADY_SETTLED', @PaidAt = @storedPaidAt, @PointsEarned = 0, @CurrentPoints = @balance;
            RETURN 0;
        END;
        IF @status <> 'PENDING'
        BEGIN
            SET @msg = CONCAT(N'usp_P3_SettleInvoice: invoice ', @Invoice_ID, N' is ', @status, N' and cannot be settled (only PENDING invoices are payable; D-005, D-011).');
            THROW 51204, @msg, 1;
        END;

        /* ---------- 4. Eligibility of the PENDING invoice ---------- */
        SET @method = COALESCE(@PaymentMethod, @storedMethod);
        IF @method IS NULL
        BEGIN
            SET @msg = CONCAT(N'usp_P3_SettleInvoice: invoice ', @Invoice_ID, N' has no recorded payment method and none was supplied.');
            THROW 51207, @msg, 1;
        END;
        IF @PaymentMethod IS NOT NULL AND @storedMethod IS NOT NULL AND @PaymentMethod COLLATE Latin1_General_BIN2 <> @storedMethod
        BEGIN
            SET @msg = CONCAT(N'usp_P3_SettleInvoice: invoice ', @Invoice_ID, N' was created with payment method ', @storedMethod,
                              N'; the supplied method ', @PaymentMethod, N' differs. The recorded method is not overwritten.');
            THROW 51208, @msg, 1;
        END;

        SELECT @lines = COUNT(*), @lineGross = ISNULL(SUM(g), 0), @lineDiscount = ISNULL(SUM(d), 0)
        FROM (SELECT CONVERT(decimal(38,2), UnitPrice) AS g, CONVERT(decimal(38,2), DiscountAmount) AS d
              FROM dbo.INVOICE_SERVICE_ITEM WHERE Invoice_ID = @Invoice_ID
              UNION ALL
              SELECT CONVERT(decimal(38,2), UnitPrice) * Quantity, CONVERT(decimal(38,2), DiscountAmount)
              FROM dbo.INVOICE_PRODUCT_ITEM WHERE Invoice_ID = @Invoice_ID) AS x;
        IF @lines = 0
        BEGIN
            SET @msg = CONCAT(N'usp_P3_SettleInvoice: invoice ', @Invoice_ID, N' has no line (BR12).');
            THROW 51205, @msg, 1;
        END;
        IF @gross <> @lineGross OR @discount <> @lineDiscount OR @final <> @gross - @discount
        BEGIN
            SET @msg = CONCAT(N'usp_P3_SettleInvoice: invoice ', @Invoice_ID, N' header totals (gross ', @gross, N', discount ', @discount,
                              N', final ', @final, N') differ from its lines (gross ', @lineGross, N', discount ', @lineDiscount, N') (D-023 X1).');
            THROW 51206, @msg, 1;
        END;

        SET @now = SYSUTCDATETIME();
        IF @now < @issuedAt
        BEGIN
            SET @msg = CONCAT(N'usp_P3_SettleInvoice: settlement time ', CONVERT(varchar(30), @now, 126), N' is before IssuedAt ',
                              CONVERT(varchar(30), @issuedAt, 126), N' (D-004).');
            THROW 51212, @msg, 1;
        END;

        /* ---------- 5. Integration hooks, in the global lock order (D-012 (a); 12 sections 5-6) ---------- */
        EXEC dbo.usp_HOOK_InventoryDecrementForInvoice @Invoice_ID = @Invoice_ID;
        EXEC dbo.usp_HOOK_EntitlementActivationForInvoice @Invoice_ID = @Invoice_ID;

        /* ---------- 6. Conditional transition PENDING -> PAID ---------- */
        UPDATE dbo.INVOICE
        SET PaymentStatus = 'PAID', PaidAt = @now, PaymentMethod = @method
        WHERE Invoice_ID = @Invoice_ID AND PaymentStatus = 'PENDING';
        IF @@ROWCOUNT <> 1
            THROW 51209, N'usp_P3_SettleInvoice: the PENDING -> PAID transition did not change exactly one row.', 1;

        /* ---------- 7. Monthly spending and points (D-006, D-013): one statement per path ---------- */
        SELECT @month = SpendingMonth FROM dbo.tvf_P3_SpendingMonth(@now);

        UPDATE dbo.MEMBER_MONTHLY_SPENDING WITH (UPDLOCK, HOLDLOCK)
        SET TotalSpend   = TotalSpend + @final,
            PointsEarned = CONVERT(int, FLOOR((TotalSpend + @final) / 100000)),
            UpdatedAt    = CASE WHEN UpdatedAt > @now THEN UpdatedAt ELSE @now END   -- latest PaidAt of the row (as in seed S001), even if commits interleave
        OUTPUT deleted.PointsEarned, inserted.PointsEarned INTO @spend (OldPoints, NewPoints)
        WHERE Member_ID = @member AND SpendingMonth = @month;

        IF @@ROWCOUNT = 0   -- first payment of the member in this month; the range lock above keeps it race-free
            INSERT dbo.MEMBER_MONTHLY_SPENDING (Member_ID, SpendingMonth, TotalSpend, PointsEarned, UpdatedAt)
            OUTPUT 0, inserted.PointsEarned INTO @spend (OldPoints, NewPoints)
            VALUES (@member, @month, @final, CONVERT(int, FLOOR(@final / 100000)), @now);

        SELECT @oldPoints = OldPoints, @newPoints = NewPoints FROM @spend;
        SET @delta = @newPoints - @oldPoints;
        IF @delta IS NULL OR @delta < 0
            THROW 51210, N'usp_P3_SettleInvoice: monthly points would decrease (defensive check).', 1;

        /* ---------- 8. Loyalty balance: atomic increment (D-006, D-024) ---------- */
        UPDATE dbo.MEMBER
        SET CurrentPoints = CurrentPoints + @delta
        OUTPUT inserted.CurrentPoints INTO @mem (CurrentPoints)
        WHERE Member_ID = @member;
        IF @@ROWCOUNT <> 1
            THROW 51211, N'usp_P3_SettleInvoice: the member row was not updated (defensive check).', 1;

        IF @ownTran = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @ownTran = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @Outcome = 'SETTLED', @PaidAt = @now, @PointsEarned = @delta, @CurrentPoints = (SELECT CurrentPoints FROM @mem);
    RETURN 0;
END;
GO

PRINT 'usp_P3_SettleInvoice applied: function dbo.tvf_P3_SpendingMonth; procedure dbo.usp_P3_SettleInvoice';
GO
