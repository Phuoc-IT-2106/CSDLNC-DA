/* =====================================================================
   R001__TEST_ONLY_revenue_report_invoices.sql  (sqlcmd mode)
   Classification : TEST_ONLY_FIXTURE - NOT PRODUCTION. Never deployed outside FitLife_P3_UC05.
   Work order     : WO-P3-P4-01 Part F (T-F06 revenue report tests).
   Why            : settlement always stamps PaidAt with the server UTC time (DEP-17), so tests of local
                    month, quarter and year boundaries, of the UTC-to-Vietnam shift and of "PaidAt, not
                    IssuedAt" need invoices with chosen timestamps. This script inserts 16 invoices with
                    exact, hand-chosen values into an EMPTY INVOICE table. Every header is derived from its
                    lines (D-023: Gross = sum of line gross, Discount = sum of line discounts, Final =
                    Gross - Discount), all CHECK and FOREIGN KEY constraints stay enabled, and the label of
                    each invoice is kept in dbo.TEST_RevenueFixture.
                    It writes no monthly spending, points or tier: this database is used for the revenue
                    tests only (the UC05 regression runs in a separate rebuild).
   Local time     : Asia/Ho_Chi_Minh = UTC+7. Local January 2026 = [2025-12-31 17:00:00.000, 2026-01-31 17:00:00.000) UTC.
   Fixture (amounts in VND; "local" = UTC+7):
     label br status     PaidAt (UTC)             local paid          Final        purpose
     R01   1  PAID       2025-12-31 16:59:59.999  2025-12-31 23:59    100000.00    last ms of Dec 2025 / 2025 / Q4
     R02   1  PAID       2025-12-31 17:00:00.000  2026-01-01 00:00    250000.00    exactly @From of Jan 2026; 2 lines, discount 50000
     R03   1  PAID       2025-12-31 17:30:00.000  2026-01-01 00:30     70000.00    issued 22:00 local on 31 Dec, paid 00:30 on 1 Jan
     R04   1  PAID       2026-01-31 16:59:59.999  2026-01-31 23:59     40000.00    last ms of Jan 2026
     R05   1  PAID       2026-01-31 17:00:00.000  2026-02-01 00:00    900000.00    exactly @To of Jan 2026 -> February
     R06   2  PAID       2026-01-15 03:00:00.000  2026-01-15 10:00    374999.50    service + product (qty 2) lines; gross 500000.00, discount 125000.50
     R07   2  PENDING    -                        -                   800000.00    excluded
     R08   2  CANCELLED  -                        -                   600000.00    excluded
     R09   3  PENDING    -                        -                   123000.00    branch 3 has no PAID invoice in Jan 2026
     R10   3  PAID       2026-02-02 02:00:00.000  2026-02-02 09:00     60000.00    issued 31 Jan (local), paid 2 Feb
     R11   2  PAID       2026-03-31 16:59:59.999  2026-03-31 23:59     10000.00    last ms of Q1 2026
     R12   2  PAID       2026-03-31 17:00:00.000  2026-04-01 00:00     20000.00    first instant of Q2 2026
     R13   1  PAID       2025-06-10 05:00:00.000  2025-06-10 12:00      1000.00    2025, Q2
     R14   1  PAID       2026-01-10 16:59:59.999  2026-01-10 23:59      5000.00    day boundary (10 Jan)
     R15   1  PAID       2026-01-10 17:00:00.000  2026-01-11 00:00      6000.00    day boundary (11 Jan)
     R16   3  PAID       2026-02-10 03:00:00.000  2026-02-10 10:00         0.00    fully discounted (gross 50000, discount 50000)
   Guards         : FitLife_P3_UC05 with the WO-P3-P3-00 disposable marker; INVOICE empty; not applied twice.
   ===================================================================== */
:on error exit
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF DB_NAME() <> N'FitLife_P3_UC05'
   OR NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable' AND CONVERT(nvarchar(200), value) LIKE N'WO-P3-P3-00%')
    THROW 51410, N'R001 (TEST_ONLY) may run only in FitLife_P3_UC05 with the WO-P3-P3-00 marker.', 1;
IF OBJECT_ID(N'dbo.TEST_RevenueFixture', N'U') IS NOT NULL OR EXISTS (SELECT 1 FROM dbo.INVOICE)
    THROW 51411, N'R001 (TEST_ONLY): needs an empty INVOICE table and must not be applied twice.', 1;
IF (SELECT COUNT(*) FROM dbo.BRANCH WHERE Branch_ID IN (1, 2, 3)) <> 3 OR NOT EXISTS (SELECT 1 FROM dbo.MEMBER WHERE Member_ID = 36)
   OR NOT EXISTS (SELECT 1 FROM dbo.PRODUCT WHERE Product_ID = 4) OR NOT EXISTS (SELECT 1 FROM dbo.SERVICE_PLAN WHERE Plan_ID = 1)
    THROW 51412, N'R001 (TEST_ONLY): needs the F001U key rows.', 1;
GO

CREATE TABLE dbo.TEST_RevenueFixture
(
    Label       VARCHAR(4)  NOT NULL CONSTRAINT PK_TEST_RevenueFixture PRIMARY KEY CLUSTERED,
    Invoice_ID  INT         NOT NULL
);
EXEC sys.sp_addextendedproperty @name = N'Classification', @value = N'TEST_ONLY_FIXTURE (R001 revenue report invoices)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'TEST_RevenueFixture';
GO

DECLARE @h TABLE (Label varchar(4) PRIMARY KEY, Branch_ID int, Member_ID int, Status varchar(10), IssuedAt datetime2(3), PaidAt datetime2(3) NULL);
DECLARE @l TABLE (Label varchar(4), LineNum smallint, Kind char(1), Item_ID int, Quantity int, UnitPrice decimal(18,2), DiscountAmount decimal(18,2), PRIMARY KEY (Label, Kind, LineNum));

INSERT @h (Label, Branch_ID, Member_ID, Status, IssuedAt, PaidAt) VALUES
    ('R01', 1, 21, 'PAID',      '2025-12-31 16:54:59.999', '2025-12-31 16:59:59.999'),
    ('R02', 1, 22, 'PAID',      '2025-12-31 16:55:00.000', '2025-12-31 17:00:00.000'),
    ('R03', 1, 23, 'PAID',      '2025-12-31 15:00:00.000', '2025-12-31 17:30:00.000'),
    ('R04', 1, 24, 'PAID',      '2026-01-31 16:54:59.999', '2026-01-31 16:59:59.999'),
    ('R05', 1, 25, 'PAID',      '2026-01-31 16:55:00.000', '2026-01-31 17:00:00.000'),
    ('R06', 2, 26, 'PAID',      '2026-01-15 02:55:00.000', '2026-01-15 03:00:00.000'),
    ('R07', 2, 27, 'PENDING',   '2026-01-15 04:00:00.000', NULL),
    ('R08', 2, 28, 'CANCELLED', '2026-01-16 04:00:00.000', NULL),
    ('R09', 3, 29, 'PENDING',   '2026-01-20 04:00:00.000', NULL),
    ('R10', 3, 30, 'PAID',      '2026-01-31 10:00:00.000', '2026-02-02 02:00:00.000'),
    ('R11', 2, 31, 'PAID',      '2026-03-31 16:54:59.999', '2026-03-31 16:59:59.999'),
    ('R12', 2, 32, 'PAID',      '2026-03-31 16:55:00.000', '2026-03-31 17:00:00.000'),
    ('R13', 1, 33, 'PAID',      '2025-06-10 04:55:00.000', '2025-06-10 05:00:00.000'),
    ('R14', 1, 34, 'PAID',      '2026-01-10 16:54:59.999', '2026-01-10 16:59:59.999'),
    ('R15', 1, 35, 'PAID',      '2026-01-10 16:55:00.000', '2026-01-10 17:00:00.000'),
    ('R16', 3, 36, 'PAID',      '2026-02-10 02:55:00.000', '2026-02-10 03:00:00.000');

INSERT @l (Label, LineNum, Kind, Item_ID, Quantity, UnitPrice, DiscountAmount) VALUES
    ('R01', 1, 'P', 1, 1, 100000.00, 0),
    ('R02', 1, 'P', 1, 1, 200000.00, 50000.00), ('R02', 2, 'P', 2, 2, 50000.00, 0),
    ('R03', 1, 'P', 3, 1, 70000.00, 0),
    ('R04', 1, 'P', 1, 1, 40000.00, 0),
    ('R05', 1, 'P', 1, 1, 900000.00, 0),
    ('R06', 1, 'S', 1, 1, 400000.00, 100000.50), ('R06', 1, 'P', 4, 2, 50000.00, 25000.00),
    ('R07', 1, 'P', 1, 1, 800000.00, 0),
    ('R08', 1, 'P', 1, 1, 600000.00, 0),
    ('R09', 1, 'P', 1, 1, 123000.00, 0),
    ('R10', 1, 'P', 1, 1, 60000.00, 0),
    ('R11', 1, 'P', 1, 1, 10000.00, 0),
    ('R12', 1, 'P', 1, 1, 20000.00, 0),
    ('R13', 1, 'P', 1, 1, 1000.00, 0),
    ('R14', 1, 'P', 1, 1, 5000.00, 0),
    ('R15', 1, 'P', 1, 1, 6000.00, 0),
    ('R16', 1, 'P', 1, 1, 50000.00, 50000.00);

DECLARE @label varchar(4), @branch int, @member int, @status varchar(10), @issued datetime2(3), @paid datetime2(3), @gross decimal(18,2), @disc decimal(18,2), @id int;
BEGIN TRANSACTION;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT Label, Branch_ID, Member_ID, Status, IssuedAt, PaidAt FROM @h ORDER BY Label;
OPEN c; FETCH NEXT FROM c INTO @label, @branch, @member, @status, @issued, @paid;
WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @gross = SUM(UnitPrice * Quantity), @disc = SUM(DiscountAmount) FROM @l WHERE Label = @label;
    INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount, PaymentMethod, PaymentStatus, PaidAt)
    VALUES (@member, 1, @branch, @issued, @gross, @disc, @gross - @disc, CASE WHEN @status = 'PAID' THEN 'CASH' END, @status, @paid);
    SET @id = CONVERT(int, SCOPE_IDENTITY());
    INSERT dbo.INVOICE_SERVICE_ITEM (Invoice_ID, [LineNo], Plan_ID, UnitPrice, DiscountAmount)
    SELECT @id, LineNum, Item_ID, UnitPrice, DiscountAmount FROM @l WHERE Label = @label AND Kind = 'S';
    INSERT dbo.INVOICE_PRODUCT_ITEM (Invoice_ID, [LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount)
    SELECT @id, LineNum, Item_ID, Quantity, UnitPrice, DiscountAmount FROM @l WHERE Label = @label AND Kind = 'P';
    INSERT dbo.TEST_RevenueFixture (Label, Invoice_ID) VALUES (@label, @id);
    FETCH NEXT FROM c INTO @label, @branch, @member, @status, @issued, @paid;
END;
CLOSE c; DEALLOCATE c;
COMMIT TRANSACTION;

SELECT f.Label, i.Invoice_ID, i.Branch_ID, i.PaymentStatus, CONVERT(varchar(23), i.IssuedAt, 121) AS IssuedAtUtc, CONVERT(varchar(23), i.PaidAt, 121) AS PaidAtUtc,
       CONVERT(varchar(23), DATEADD(HOUR, 7, i.PaidAt), 121) AS PaidAtLocal, i.GrossAmount, i.DiscountAmount, i.FinalAmount
FROM dbo.TEST_RevenueFixture AS f JOIN dbo.INVOICE AS i ON i.Invoice_ID = f.Invoice_ID ORDER BY f.Label;
PRINT 'R001 (TEST_ONLY) applied: 16 revenue report invoices (13 PAID, 2 PENDING, 1 CANCELLED); table dbo.TEST_RevenueFixture';
GO
