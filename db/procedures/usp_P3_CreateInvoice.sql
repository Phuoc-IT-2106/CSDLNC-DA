/* =====================================================================
   usp_P3_CreateInvoice.sql
   Classification : P3_OWNED - production routine (Person 3). Programmability only:
                    creates no table, column, constraint or index.
   Work order     : WO-P3-P3-00 - Invoice Creation (Billing, F05)
   Objects        : dbo.tt_P3_InvoiceServiceLine  (table type: service lines of one request)
                    dbo.tt_P3_InvoiceProductLine  (table type: product lines of one request)
                    dbo.usp_P3_CreateInvoice      (procedure)
   Purpose        : create ONE invoice - header and all lines - in ONE transaction, in
                    status PENDING, with header totals derived from the lines.
   Decisions      : D-003 (A) invoice-state model; D-005 (PENDING at creation; PaymentMethod
                    optional before settlement, domain CASH/VNPAY/CARD); D-011 (no refunds);
                    D-014 (IssuedAt = SYSUTCDATETIME(), DECIMAL(18,2) money); D-023 (Gross =
                    sum of line gross, Discount = sum of line discounts, Final = Gross - Discount;
                    invariant X1 re-checked inside this transaction); BR12 (at least one line).
                    D-028 APPROVED (provisional, T2) on 2026-11-09: Q1(a), Q2(a), Q3(a), Q4(a)
                    (the caller - an authorized, trusted component - supplies UnitPrice and
                    DiscountAmount; prices are NOT validated against a catalogue here; upstream
                    price validation is an integration requirement, DEP-04), Q5(a) (no request
                    key; exactly-once creation is not claimed), Q6 (no side effects at creation).
                    See WO-P3-P3-00 section 13 and 03 D-028. (Header comment only; the
                    procedure definition is unchanged since WO-P3-P3-00.)
   Interface      : @Member_ID, @Employee_ID, @Branch_ID   required (keys of shared tables)
                    @ServiceLines, @ProductLines             at least one row in total
                    @PaymentMethod                           optional (NULL until settlement)
                    @Invoice_ID OUTPUT                       new invoice key
                    @Outcome OUTPUT                          'CREATED'
                    Return value 0 on success. On failure an error is raised and NOTHING is
                    written (no header, no line).
   Line numbers   : supplied by the caller, >= 1, unique within each line list (the type's
                    PRIMARY KEY), stored unchanged. Service and product lines are numbered
                    independently, as the two item tables have separate primary keys.
   Errors         : 51101-51115 (P3 range, 12 section 2b DEP-13). Constraint and engine errors
                    (547, 2627, 8115, ...) are re-raised unchanged.
                      51101 header key missing          51109 totals exceed DECIMAL(18,2)
                      51102 invalid PaymentMethod       51110 unknown Member_ID
                      51103 no line (BR12)              51111 unknown Employee_ID
                      51104 LineNo < 1                  51112 unknown Branch_ID
                      51105 Quantity <= 0               51113 unknown Plan_ID
                      51106 UnitPrice < 0               51114 unknown Product_ID
                      51107 DiscountAmount < 0          51115 header/line totals mismatch
                      51108 discount > line gross             after insert (defensive, X1)
   Transactions   : SET XACT_ABORT ON. If no transaction is open, the routine owns one and
                    commits or rolls it back. If the caller already has a transaction open,
                    the routine joins it, never commits or rolls it back, and re-raises any
                    error so that the caller rolls back once (12 section 4).
   Idempotency    : none at creation (D-028 Q5 (b) not approved): a repeated identical request
                    creates a second, distinct PENDING invoice. Exactly-once creation is NOT
                    claimed. A request-key column would need migration V003 (Owner approval).
   Not done here  : settlement, cancellation, payment time, loyalty points, monthly spending,
                    tier, revenue; stock check or inventory; entitlement activation (ValidFrom,
                    ValidUntil) or PT sessions (PTSessionsRemaining), all left NULL (DEP-06);
                    catalogue prices (DEP-04). Shared tables are read by key only (12 section 2a).
   Re-runnable    : the types are created when missing (an existing type must match the
                    expected definition); the procedure uses CREATE OR ALTER.
   Run            : sqlcmd -S localhost -E -I -b -d <database> -i db/procedures/usp_P3_CreateInvoice.sql
   ===================================================================== */
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.INVOICE', N'U') IS NULL OR OBJECT_ID(N'dbo.INVOICE_SERVICE_ITEM', N'U') IS NULL
   OR OBJECT_ID(N'dbo.INVOICE_PRODUCT_ITEM', N'U') IS NULL OR COL_LENGTH(N'dbo.INVOICE', N'PaidAt') IS NULL
    THROW 51100, N'usp_P3_CreateInvoice requires migrations V001 and V002.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF TYPE_ID(N'dbo.tt_P3_InvoiceServiceLine') IS NULL
        EXEC (N'CREATE TYPE dbo.tt_P3_InvoiceServiceLine AS TABLE
        (
            [LineNo]        SMALLINT      NOT NULL PRIMARY KEY,
            Plan_ID         INT           NOT NULL,
            UnitPrice       DECIMAL(18,2) NOT NULL,
            DiscountAmount  DECIMAL(18,2) NOT NULL
        );');

    IF TYPE_ID(N'dbo.tt_P3_InvoiceProductLine') IS NULL
        EXEC (N'CREATE TYPE dbo.tt_P3_InvoiceProductLine AS TABLE
        (
            [LineNo]        SMALLINT      NOT NULL PRIMARY KEY,
            Product_ID      INT           NOT NULL,
            Quantity        INT           NOT NULL,
            UnitPrice       DECIMAL(18,2) NOT NULL,
            DiscountAmount  DECIMAL(18,2) NOT NULL
        );');

    /* An existing type must have exactly the expected columns (name, order, type, nullability). */
    DECLARE @svcDef nvarchar(400), @prdDef nvarchar(400);
    SELECT @svcDef = STRING_AGG(CONVERT(nvarchar(400), CONCAT(c.column_id, ':', c.name, ':', ty.name, ':', c.precision, ':', c.scale, ':', c.is_nullable)), '|')
                     WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.table_types AS tt JOIN sys.columns AS c ON c.object_id = tt.type_table_object_id
    JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
    WHERE tt.name = N'tt_P3_InvoiceServiceLine' AND tt.schema_id = SCHEMA_ID(N'dbo');
    SELECT @prdDef = STRING_AGG(CONVERT(nvarchar(400), CONCAT(c.column_id, ':', c.name, ':', ty.name, ':', c.precision, ':', c.scale, ':', c.is_nullable)), '|')
                     WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.table_types AS tt JOIN sys.columns AS c ON c.object_id = tt.type_table_object_id
    JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
    WHERE tt.name = N'tt_P3_InvoiceProductLine' AND tt.schema_id = SCHEMA_ID(N'dbo');
    IF @svcDef <> N'1:LineNo:smallint:5:0:0|2:Plan_ID:int:10:0:0|3:UnitPrice:decimal:18:2:0|4:DiscountAmount:decimal:18:2:0'
        THROW 51100, N'dbo.tt_P3_InvoiceServiceLine exists with an unexpected definition.', 1;
    IF @prdDef <> N'1:LineNo:smallint:5:0:0|2:Product_ID:int:10:0:0|3:Quantity:int:10:0:0|4:UnitPrice:decimal:18:2:0|5:DiscountAmount:decimal:18:2:0'
        THROW 51100, N'dbo.tt_P3_InvoiceProductLine exists with an unexpected definition.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

CREATE OR ALTER PROCEDURE dbo.usp_P3_CreateInvoice
    @Member_ID      INT,
    @Employee_ID    INT,
    @Branch_ID      INT,
    @ServiceLines   dbo.tt_P3_InvoiceServiceLine READONLY,
    @ProductLines   dbo.tt_P3_InvoiceProductLine READONLY,
    @PaymentMethod  VARCHAR(10) = NULL,
    @Invoice_ID     INT = NULL OUTPUT,
    @Outcome        VARCHAR(20) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @msg nvarchar(2048), @bad nvarchar(200);
    DECLARE @lineCount int, @gross decimal(38,2), @discount decimal(38,2);
    DECLARE @newId int, @ownTran bit;
    DECLARE @ids TABLE (Invoice_ID int NOT NULL);

    SELECT @Invoice_ID = NULL, @Outcome = NULL;

    /* ---------- 1. Validate the request (reads only; nothing is written yet) ---------- */
    IF @Member_ID IS NULL OR @Employee_ID IS NULL OR @Branch_ID IS NULL
        THROW 51101, N'usp_P3_CreateInvoice: Member_ID, Employee_ID and Branch_ID are required.', 1;

    -- D-005 domain, compared exactly (binary, no trailing space), so that only the approved literals are stored.
    IF @PaymentMethod IS NOT NULL
       AND (@PaymentMethod COLLATE Latin1_General_BIN2 NOT IN ('CASH', 'VNPAY', 'CARD') OR DATALENGTH(@PaymentMethod) <> LEN(@PaymentMethod))
    BEGIN
        SET @msg = CONCAT(N'usp_P3_CreateInvoice: PaymentMethod ''', @PaymentMethod, N''' is not one of CASH, VNPAY, CARD (or NULL).');
        THROW 51102, @msg, 1;
    END;

    SET @lineCount = (SELECT COUNT(*) FROM @ServiceLines) + (SELECT COUNT(*) FROM @ProductLines);
    IF @lineCount = 0
        THROW 51103, N'usp_P3_CreateInvoice: an invoice needs at least one service or product line (BR12).', 1;

    SET @bad = (SELECT TOP (1) CONCAT(N'service line ', [LineNo]) FROM @ServiceLines WHERE [LineNo] < 1 ORDER BY [LineNo]);
    IF @bad IS NULL SET @bad = (SELECT TOP (1) CONCAT(N'product line ', [LineNo]) FROM @ProductLines WHERE [LineNo] < 1 ORDER BY [LineNo]);
    IF @bad IS NOT NULL BEGIN SET @msg = CONCAT(N'usp_P3_CreateInvoice: ', @bad, N': LineNo must be >= 1.'); THROW 51104, @msg, 1; END;

    SET @bad = (SELECT TOP (1) CONCAT(N'product line ', [LineNo]) FROM @ProductLines WHERE Quantity <= 0 ORDER BY [LineNo]);
    IF @bad IS NOT NULL BEGIN SET @msg = CONCAT(N'usp_P3_CreateInvoice: ', @bad, N': Quantity must be > 0.'); THROW 51105, @msg, 1; END;

    SET @bad = (SELECT TOP (1) CONCAT(N'service line ', [LineNo]) FROM @ServiceLines WHERE UnitPrice < 0 ORDER BY [LineNo]);
    IF @bad IS NULL SET @bad = (SELECT TOP (1) CONCAT(N'product line ', [LineNo]) FROM @ProductLines WHERE UnitPrice < 0 ORDER BY [LineNo]);
    IF @bad IS NOT NULL BEGIN SET @msg = CONCAT(N'usp_P3_CreateInvoice: ', @bad, N': UnitPrice must be >= 0.'); THROW 51106, @msg, 1; END;

    SET @bad = (SELECT TOP (1) CONCAT(N'service line ', [LineNo]) FROM @ServiceLines WHERE DiscountAmount < 0 ORDER BY [LineNo]);
    IF @bad IS NULL SET @bad = (SELECT TOP (1) CONCAT(N'product line ', [LineNo]) FROM @ProductLines WHERE DiscountAmount < 0 ORDER BY [LineNo]);
    IF @bad IS NOT NULL BEGIN SET @msg = CONCAT(N'usp_P3_CreateInvoice: ', @bad, N': DiscountAmount must be >= 0.'); THROW 51107, @msg, 1; END;

    -- D-023: a line discount never exceeds the line gross (service: UnitPrice; product: UnitPrice x Quantity).
    SET @bad = (SELECT TOP (1) CONCAT(N'service line ', [LineNo]) FROM @ServiceLines WHERE DiscountAmount > UnitPrice ORDER BY [LineNo]);
    IF @bad IS NULL SET @bad = (SELECT TOP (1) CONCAT(N'product line ', [LineNo]) FROM @ProductLines WHERE DiscountAmount > UnitPrice * Quantity ORDER BY [LineNo]);
    IF @bad IS NOT NULL BEGIN SET @msg = CONCAT(N'usp_P3_CreateInvoice: ', @bad, N': DiscountAmount exceeds the line gross amount.'); THROW 51108, @msg, 1; END;

    -- D-023 totals, computed at full precision; they must fit the DECIMAL(18,2) header columns.
    SET @gross    = ISNULL((SELECT SUM(CONVERT(decimal(38,2), UnitPrice)) FROM @ServiceLines), 0)
                  + ISNULL((SELECT SUM(CONVERT(decimal(38,2), UnitPrice) * Quantity) FROM @ProductLines), 0);
    SET @discount = ISNULL((SELECT SUM(CONVERT(decimal(38,2), DiscountAmount)) FROM @ServiceLines), 0)
                  + ISNULL((SELECT SUM(CONVERT(decimal(38,2), DiscountAmount)) FROM @ProductLines), 0);
    IF @gross > 9999999999999999.99
    BEGIN
        SET @msg = CONCAT(N'usp_P3_CreateInvoice: invoice gross amount ', @gross, N' exceeds DECIMAL(18,2).');
        THROW 51109, @msg, 1;
    END;

    -- References (shared tables, key columns only). The foreign keys remain the final guard.
    IF NOT EXISTS (SELECT 1 FROM dbo.MEMBER WHERE Member_ID = @Member_ID)
    BEGIN SET @msg = CONCAT(N'usp_P3_CreateInvoice: unknown Member_ID ', @Member_ID, N'.'); THROW 51110, @msg, 1; END;
    IF NOT EXISTS (SELECT 1 FROM dbo.EMPLOYEE WHERE Employee_ID = @Employee_ID)
    BEGIN SET @msg = CONCAT(N'usp_P3_CreateInvoice: unknown Employee_ID ', @Employee_ID, N'.'); THROW 51111, @msg, 1; END;
    IF NOT EXISTS (SELECT 1 FROM dbo.BRANCH WHERE Branch_ID = @Branch_ID)
    BEGIN SET @msg = CONCAT(N'usp_P3_CreateInvoice: unknown Branch_ID ', @Branch_ID, N'.'); THROW 51112, @msg, 1; END;

    SET @bad = (SELECT TOP (1) CONCAT(N'service line ', s.[LineNo], N' (Plan_ID ', s.Plan_ID, N')') FROM @ServiceLines AS s
                WHERE NOT EXISTS (SELECT 1 FROM dbo.SERVICE_PLAN AS sp WHERE sp.Plan_ID = s.Plan_ID) ORDER BY s.[LineNo]);
    IF @bad IS NOT NULL BEGIN SET @msg = CONCAT(N'usp_P3_CreateInvoice: ', @bad, N': unknown Plan_ID.'); THROW 51113, @msg, 1; END;

    SET @bad = (SELECT TOP (1) CONCAT(N'product line ', p.[LineNo], N' (Product_ID ', p.Product_ID, N')') FROM @ProductLines AS p
                WHERE NOT EXISTS (SELECT 1 FROM dbo.PRODUCT AS pr WHERE pr.Product_ID = p.Product_ID) ORDER BY p.[LineNo]);
    IF @bad IS NOT NULL BEGIN SET @msg = CONCAT(N'usp_P3_CreateInvoice: ', @bad, N': unknown Product_ID.'); THROW 51114, @msg, 1; END;

    /* ---------- 2. Write header and lines atomically ---------- */
    SET @ownTran = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @ownTran = 1 BEGIN TRANSACTION;

        INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount, PaymentMethod, PaymentStatus, PaidAt)
        OUTPUT INSERTED.Invoice_ID INTO @ids (Invoice_ID)
        VALUES (@Member_ID, @Employee_ID, @Branch_ID, SYSUTCDATETIME(), @gross, @discount, @gross - @discount, @PaymentMethod, 'PENDING', NULL);

        SET @newId = (SELECT Invoice_ID FROM @ids);

        INSERT dbo.INVOICE_SERVICE_ITEM (Invoice_ID, [LineNo], Plan_ID, UnitPrice, DiscountAmount, ValidFrom, ValidUntil, PTSessionsRemaining)
        SELECT @newId, s.[LineNo], s.Plan_ID, s.UnitPrice, s.DiscountAmount, NULL, NULL, NULL
        FROM @ServiceLines AS s;

        INSERT dbo.INVOICE_PRODUCT_ITEM (Invoice_ID, [LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount)
        SELECT @newId, p.[LineNo], p.Product_ID, p.Quantity, p.UnitPrice, p.DiscountAmount
        FROM @ProductLines AS p;

        -- D-023 X1 and BR12 against the stored rows, before commit (defensive: catches any
        -- interference with the rows written above).
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.INVOICE AS i
            CROSS APPLY (SELECT ISNULL(SUM(si.UnitPrice), 0) AS g, ISNULL(SUM(si.DiscountAmount), 0) AS d, COUNT(*) AS n
                         FROM dbo.INVOICE_SERVICE_ITEM AS si WHERE si.Invoice_ID = i.Invoice_ID) AS s
            CROSS APPLY (SELECT ISNULL(SUM(pi.UnitPrice * pi.Quantity), 0) AS g, ISNULL(SUM(pi.DiscountAmount), 0) AS d, COUNT(*) AS n
                         FROM dbo.INVOICE_PRODUCT_ITEM AS pi WHERE pi.Invoice_ID = i.Invoice_ID) AS p
            WHERE i.Invoice_ID = @newId
              AND i.GrossAmount = s.g + p.g
              AND i.DiscountAmount = s.d + p.d
              AND s.n + p.n = @lineCount)
            THROW 51115, N'usp_P3_CreateInvoice: header totals do not equal the stored lines (D-023 X1); creation rolled back.', 1;

        IF @ownTran = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @ownTran = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @Invoice_ID = @newId, @Outcome = 'CREATED';
    RETURN 0;
END;
GO

PRINT 'usp_P3_CreateInvoice applied: types dbo.tt_P3_InvoiceServiceLine, dbo.tt_P3_InvoiceProductLine; procedure dbo.usp_P3_CreateInvoice';
GO
