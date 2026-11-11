/* =====================================================================
   T-SCH-01_constraints.sql — TEST_ONLY (sqlcmd mode)
   Work order : WO-P3-P1-01 §8.1
   Positive and negative constraint tests on the four P3-owned tables, plus the
   read-only totals validation query V-TOT (not a database object).
   Every row written here is inside ONE transaction that is rolled back at the end;
   each negative case runs under its own savepoint. A negative case passes only if
   the NAMED constraint (or the stated error) rejects it.
   Run from the repository root:
     sqlcmd -S localhost -E -I -b -W -d FitLife_P3_P1 -i tests/db/schema/T-SCH-01_constraints.sql
   ===================================================================== */
:on error exit
SET NOCOUNT ON;
SET XACT_ABORT OFF;   -- constraint violations must terminate the statement only

IF DB_NAME() NOT LIKE N'FitLife[_]P3[_]%'
   OR NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable')
    THROW 51030, N'T-SCH-01 runs only in an isolated, disposable FitLife_P3_% database.', 1;
IF EXISTS (SELECT 1 FROM dbo.INVOICE) OR EXISTS (SELECT 1 FROM dbo.INVOICE_SERVICE_ITEM) OR EXISTS (SELECT 1 FROM dbo.INVOICE_PRODUCT_ITEM)
   OR EXISTS (SELECT 1 FROM dbo.MEMBER_MONTHLY_SPENDING) OR EXISTS (SELECT 1 FROM dbo.MEMBER) OR EXISTS (SELECT 1 FROM dbo.BRANCH)
   OR EXISTS (SELECT 1 FROM dbo.EMPLOYEE) OR EXISTS (SELECT 1 FROM dbo.SERVICE_PLAN) OR EXISTS (SELECT 1 FROM dbo.PRODUCT)
    THROW 51031, N'T-SCH-01 expects empty tables (fresh build).', 1;

DECLARE @results TABLE (seq INT IDENTITY(1,1), case_id VARCHAR(12), kind CHAR(1), result VARCHAR(5), descr NVARCHAR(300), detail NVARCHAR(2000));
DECLARE @inv1 INT, @inv2 INT, @inv3 INT, @inv4 INT, @ok BIT, @n INT, @msg NVARCHAR(2000);
DECLARE @vt TABLE (Invoice_ID INT);
/* V-TOT: invoices whose header Gross or Discount differs from the sum of their lines, or that have no line. */
DECLARE @vtot NVARCHAR(MAX) = N'
WITH s AS (SELECT Invoice_ID, SUM(UnitPrice) AS g, SUM(DiscountAmount) AS d, COUNT(*) AS n FROM dbo.INVOICE_SERVICE_ITEM GROUP BY Invoice_ID),
     p AS (SELECT Invoice_ID, SUM(UnitPrice * Quantity) AS g, SUM(DiscountAmount) AS d, COUNT(*) AS n FROM dbo.INVOICE_PRODUCT_ITEM GROUP BY Invoice_ID)
SELECT i.Invoice_ID
FROM dbo.INVOICE AS i
LEFT JOIN s ON s.Invoice_ID = i.Invoice_ID
LEFT JOIN p ON p.Invoice_ID = i.Invoice_ID
WHERE i.GrossAmount    <> ISNULL(s.g, 0) + ISNULL(p.g, 0)
   OR i.DiscountAmount <> ISNULL(s.d, 0) + ISNULL(p.d, 0)
   OR ISNULL(s.n, 0) + ISNULL(p.n, 0) = 0;';

BEGIN TRANSACTION;

/* ---- fixture-data block (TEST_ONLY): the only place that writes shared-dependency rows ---- */
INSERT dbo.MEMBER (Member_ID) VALUES (1), (2);
INSERT dbo.BRANCH (Branch_ID) VALUES (1);
INSERT dbo.EMPLOYEE (Employee_ID) VALUES (1);
INSERT dbo.SERVICE_PLAN (Plan_ID) VALUES (1);
INSERT dbo.PRODUCT (Product_ID) VALUES (1);

/* ---- positive (smoke) cases ---- */
-- P01: PENDING invoice with one service line and one product line; header = lines; default status
BEGIN TRY
    INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount)
    VALUES (1, 1, 1, '2026-11-07T03:00:00.000', 600000.00, 60000.00, 540000.00);
    SET @inv1 = SCOPE_IDENTITY();
    INSERT dbo.INVOICE_SERVICE_ITEM (Invoice_ID, [LineNo], Plan_ID, UnitPrice, DiscountAmount) VALUES (@inv1, 1, 1, 500000.00, 50000.00);
    INSERT dbo.INVOICE_PRODUCT_ITEM (Invoice_ID, [LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount) VALUES (@inv1, 1, 1, 2, 50000.00, 10000.00);
    SELECT @ok = CASE WHEN PaymentStatus = 'PENDING' AND PaymentMethod IS NULL AND PaidAt IS NULL THEN 1 ELSE 0 END FROM dbo.INVOICE WHERE Invoice_ID = @inv1;
    INSERT @results (case_id, kind, result, descr, detail) VALUES ('P01', 'P', CASE WHEN @ok = 1 THEN 'PASS' ELSE 'FAIL' END,
        N'PENDING invoice + service line + product line, valid FKs; status defaults to PENDING', N'accepted; PaymentStatus=PENDING, PaymentMethod NULL, PaidAt NULL');
END TRY
BEGIN CATCH
    INSERT @results (case_id, kind, result, descr, detail) VALUES ('P01', 'P', 'FAIL', N'valid invoice graph', CONCAT(ERROR_NUMBER(), N': ', ERROR_MESSAGE()));
END CATCH;

-- P02: PENDING -> PAID with method and PaidAt >= IssuedAt (UTC values)
BEGIN TRY
    UPDATE dbo.INVOICE SET PaymentStatus = 'PAID', PaymentMethod = 'CASH', PaidAt = '2026-11-07T03:05:00.000' WHERE Invoice_ID = @inv1;
    SET @n = @@ROWCOUNT;
    INSERT @results (case_id, kind, result, descr, detail) VALUES ('P02', 'P', CASE WHEN @n = 1 THEN 'PASS' ELSE 'FAIL' END,
        N'PENDING -> PAID with CASH and PaidAt after IssuedAt', CONCAT(N'rows updated: ', @n));
END TRY
BEGIN CATCH
    INSERT @results (case_id, kind, result, descr, detail) VALUES ('P02', 'P', 'FAIL', N'settle invoice', CONCAT(ERROR_NUMBER(), N': ', ERROR_MESSAGE()));
END CATCH;

-- P03: PENDING invoice with a method recorded at creation (S2), then PENDING -> CANCELLED without PaidAt
BEGIN TRY
    INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount, PaymentMethod)
    VALUES (2, 1, 1, '2026-11-07T03:10:00.000', 120000.00, 0.00, 120000.00, 'VNPAY');
    SET @inv2 = SCOPE_IDENTITY();
    INSERT dbo.INVOICE_PRODUCT_ITEM (Invoice_ID, [LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount) VALUES (@inv2, 1, 1, 3, 40000.00, 0.00);
    UPDATE dbo.INVOICE SET PaymentStatus = 'CANCELLED' WHERE Invoice_ID = @inv2;
    SELECT @ok = CASE WHEN PaymentStatus = 'CANCELLED' AND PaidAt IS NULL AND PaymentMethod = 'VNPAY' THEN 1 ELSE 0 END FROM dbo.INVOICE WHERE Invoice_ID = @inv2;
    INSERT @results (case_id, kind, result, descr, detail) VALUES ('P03', 'P', CASE WHEN @ok = 1 THEN 'PASS' ELSE 'FAIL' END,
        N'PENDING with VNPAY recorded at creation; PENDING -> CANCELLED without PaidAt', N'accepted');
END TRY
BEGIN CATCH
    INSERT @results (case_id, kind, result, descr, detail) VALUES ('P03', 'P', 'FAIL', N'method at creation; cancel', CONCAT(ERROR_NUMBER(), N': ', ERROR_MESSAGE()));
END CATCH;

-- P04: spending row on the first day of a month
BEGIN TRY
    INSERT dbo.MEMBER_MONTHLY_SPENDING (Member_ID, SpendingMonth, TotalSpend, PointsEarned, UpdatedAt)
    VALUES (1, '2026-11-01', 540000.00, 5, '2026-11-07T03:05:00.000');
    INSERT @results (case_id, kind, result, descr, detail) VALUES ('P04', 'P', 'PASS', N'MEMBER_MONTHLY_SPENDING row with SpendingMonth = 2026-11-01', N'accepted');
END TRY
BEGIN CATCH
    INSERT @results (case_id, kind, result, descr, detail) VALUES ('P04', 'P', 'FAIL', N'first-day spending row', CONCAT(ERROR_NUMBER(), N': ', ERROR_MESSAGE()));
END CATCH;

-- P07: spending defaults (0, 0, UTC timestamp)
BEGIN TRY
    INSERT dbo.MEMBER_MONTHLY_SPENDING (Member_ID, SpendingMonth) VALUES (2, '2026-10-01');
    SELECT @ok = CASE WHEN TotalSpend = 0 AND PointsEarned = 0 AND ABS(DATEDIFF(SECOND, UpdatedAt, SYSUTCDATETIME())) < 600 THEN 1 ELSE 0 END
    FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = 2 AND SpendingMonth = '2026-10-01';
    INSERT @results (case_id, kind, result, descr, detail) VALUES ('P07', 'P', CASE WHEN @ok = 1 THEN 'PASS' ELSE 'FAIL' END,
        N'Defaults: TotalSpend 0, PointsEarned 0, UpdatedAt = SYSUTCDATETIME() (UTC, D-014)', N'defaults applied; UpdatedAt within 10 minutes of SYSUTCDATETIME()');
END TRY
BEGIN CATCH
    INSERT @results (case_id, kind, result, descr, detail) VALUES ('P07', 'P', 'FAIL', N'spending defaults', CONCAT(ERROR_NUMBER(), N': ', ERROR_MESSAGE()));
END CATCH;

-- P08: valid service validity (BR13) and PT sessions on a service line
BEGIN TRY
    UPDATE dbo.INVOICE_SERVICE_ITEM SET ValidFrom = '2026-11-07', ValidUntil = '2027-11-06', PTSessionsRemaining = 10 WHERE Invoice_ID = @inv1 AND [LineNo] = 1;
    SET @n = @@ROWCOUNT;
    INSERT @results (case_id, kind, result, descr, detail) VALUES ('P08', 'P', CASE WHEN @n = 1 THEN 'PASS' ELSE 'FAIL' END,
        N'Service line with ValidUntil >= ValidFrom and PTSessionsRemaining set', CONCAT(N'rows updated: ', @n));
END TRY
BEGIN CATCH
    INSERT @results (case_id, kind, result, descr, detail) VALUES ('P08', 'P', 'FAIL', N'valid validity', CONCAT(ERROR_NUMBER(), N': ', ERROR_MESSAGE()));
END CATCH;

-- P09: invoice inserted directly as PAID with CARD (all three methods covered: CASH, VNPAY, CARD)
BEGIN TRY
    INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount, PaymentMethod, PaymentStatus, PaidAt)
    VALUES (1, 1, 1, '2026-11-07T05:00:00.000', 250000.00, 0.00, 250000.00, 'CARD', 'PAID', '2026-11-07T05:01:00.000');
    SET @inv4 = SCOPE_IDENTITY();
    INSERT dbo.INVOICE_SERVICE_ITEM (Invoice_ID, [LineNo], Plan_ID, UnitPrice, DiscountAmount) VALUES (@inv4, 1, 1, 250000.00, 0.00);
    INSERT @results (case_id, kind, result, descr, detail) VALUES ('P09', 'P', 'PASS', N'PAID invoice with CARD and PaidAt', N'accepted');
END TRY
BEGIN CATCH
    INSERT @results (case_id, kind, result, descr, detail) VALUES ('P09', 'P', 'FAIL', N'PAID with CARD', CONCAT(ERROR_NUMBER(), N': ', ERROR_MESSAGE()));
END CATCH;

-- P05: V-TOT returns zero rows for the consistent invoices
BEGIN TRY
    DELETE FROM @vt;
    INSERT @vt EXEC sys.sp_executesql @vtot;
    SELECT @n = COUNT(*) FROM @vt;
    INSERT @results (case_id, kind, result, descr, detail) VALUES ('P05', 'P', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END,
        N'V-TOT finds no inconsistent invoice among the consistent ones', CONCAT(N'V-TOT rows: ', @n));
END TRY
BEGIN CATCH
    INSERT @results (case_id, kind, result, descr, detail) VALUES ('P05', 'P', 'FAIL', N'V-TOT', CONCAT(ERROR_NUMBER(), N': ', ERROR_MESSAGE()));
END CATCH;

-- P06: an invoice whose header Gross differs from its lines passes every CHECK (cross-table rule) and V-TOT reports it
BEGIN TRY
    INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount)
    VALUES (2, 1, 1, '2026-11-07T06:00:00.000', 999999.00, 0.00, 999999.00);
    SET @inv3 = SCOPE_IDENTITY();
    INSERT dbo.INVOICE_SERVICE_ITEM (Invoice_ID, [LineNo], Plan_ID, UnitPrice, DiscountAmount) VALUES (@inv3, 1, 1, 100000.00, 0.00);
    DELETE FROM @vt;
    INSERT @vt EXEC sys.sp_executesql @vtot;
    SET @ok = CASE WHEN (SELECT COUNT(*) FROM @vt) = 1 AND EXISTS (SELECT 1 FROM @vt WHERE Invoice_ID = @inv3) THEN 1 ELSE 0 END;
    INSERT @results (case_id, kind, result, descr, detail) VALUES ('P06', 'P', CASE WHEN @ok = 1 THEN 'PASS' ELSE 'FAIL' END,
        N'Header 999,999 vs lines 100,000: accepted by all CHECKs (X1 is cross-table); V-TOT reports exactly this invoice',
        CONCAT(N'V-TOT rows: ', (SELECT COUNT(*) FROM @vt), N'; reported the inconsistent invoice: ', CASE WHEN EXISTS (SELECT 1 FROM @vt WHERE Invoice_ID = @inv3) THEN N'yes' ELSE N'no' END));
END TRY
BEGIN CATCH
    INSERT @results (case_id, kind, result, descr, detail) VALUES ('P06', 'P', 'FAIL', N'inconsistent header', CONCAT(ERROR_NUMBER(), N': ', ERROR_MESSAGE()));
END CATCH;

/* ---- negative cases (N) and one informational case (I) ---- */
DECLARE @cases TABLE (seq INT IDENTITY(1,1), case_id VARCHAR(12), kind CHAR(1), descr NVARCHAR(300), sql_text NVARCHAR(MAX), exp1 SYSNAME NULL, exp2 SYSNAME NULL, exp_num INT NULL);
INSERT @cases (case_id, kind, descr, sql_text, exp1, exp2, exp_num) VALUES
('N01',  'N', N'Status ''DONE''',
 N'INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount, PaymentStatus) VALUES (1,1,1,''2026-11-07T04:00:00'',100,0,100,''DONE'');',
 N'CK_INVOICE_PaymentStatus', NULL, 547),
('N02',  'N', N'Method ''BITCOIN''',
 N'INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount, PaymentMethod) VALUES (1,1,1,''2026-11-07T04:00:00'',100,0,100,''BITCOIN'');',
 N'CK_INVOICE_PaymentMethod', NULL, 547),
('N03',  'N', N'PAID with PaidAt NULL',
 N'INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount, PaymentMethod, PaymentStatus) VALUES (1,1,1,''2026-11-07T04:00:00'',100,0,100,''CASH'',''PAID'');',
 N'CK_INVOICE_PaidAtStatus', NULL, 547),
('N04a', 'N', N'PENDING with PaidAt set',
 N'INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount, PaidAt) VALUES (1,1,1,''2026-11-07T04:00:00'',100,0,100,''2026-11-07T04:10:00'');',
 N'CK_INVOICE_PaidAtStatus', NULL, 547),
('N04b', 'N', N'CANCELLED invoice given a PaidAt',
 N'UPDATE dbo.INVOICE SET PaidAt = ''2026-11-07T04:10:00'' WHERE Invoice_ID = @inv2;',
 N'CK_INVOICE_PaidAtStatus', NULL, 547),
('N05',  'N', N'PaidAt earlier than IssuedAt',
 N'INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount, PaymentMethod, PaymentStatus, PaidAt) VALUES (1,1,1,''2026-11-07T04:00:00'',100,0,100,''CASH'',''PAID'',''2026-11-07T03:59:00'');',
 N'CK_INVOICE_PaidAtAfterIssued', NULL, 547),
('N06',  'N', N'PAID with method NULL',
 N'INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount, PaymentStatus, PaidAt) VALUES (1,1,1,''2026-11-07T04:00:00'',100,0,100,''PAID'',''2026-11-07T04:10:00'');',
 N'CK_INVOICE_MethodWhenPaid', NULL, 547),
('N07a', 'N', N'Negative GrossAmount (also makes FinalAmount negative)',
 N'INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount) VALUES (1,1,1,''2026-11-07T04:00:00'',-100,0,-100);',
 N'CK_INVOICE_Amounts', N'CK_INVOICE_FinalAmount', 547),
('N07b', 'N', N'Negative DiscountAmount',
 N'INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount) VALUES (1,1,1,''2026-11-07T04:00:00'',100,-10,110);',
 N'CK_INVOICE_Amounts', NULL, 547),
('N07c', 'N', N'Discount greater than Gross (also makes FinalAmount negative)',
 N'INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount) VALUES (1,1,1,''2026-11-07T04:00:00'',100,150,-50);',
 N'CK_INVOICE_Amounts', N'CK_INVOICE_FinalAmount', 547),
('N08',  'N', N'FinalAmount <> Gross - Discount',
 N'INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount) VALUES (1,1,1,''2026-11-07T04:00:00'',100,10,80);',
 N'CK_INVOICE_FinalAmount', NULL, 547),
('N09a', 'N', N'Invoice with unknown member key',
 N'INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount) VALUES (999,1,1,''2026-11-07T04:00:00'',100,0,100);',
 N'FK_INVOICE_MEMBER', NULL, 547),
('N09b', 'N', N'Invoice with unknown employee key',
 N'INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount) VALUES (1,999,1,''2026-11-07T04:00:00'',100,0,100);',
 N'FK_INVOICE_EMPLOYEE', NULL, 547),
('N09c', 'N', N'Invoice with unknown branch key',
 N'INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount) VALUES (1,1,999,''2026-11-07T04:00:00'',100,0,100);',
 N'FK_INVOICE_BRANCH', NULL, 547),
('N10a', 'N', N'Invoice with NULL PaymentStatus',
 N'INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount, PaymentStatus) VALUES (1,1,1,''2026-11-07T04:00:00'',100,0,100,NULL);',
 N'PaymentStatus', NULL, 515),
('N10b', 'N', N'Invoice with NULL Member_ID',
 N'INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount) VALUES (NULL,1,1,''2026-11-07T04:00:00'',100,0,100);',
 N'Member_ID', NULL, 515),
('N11',  'N', N'SpendingMonth 2026-11-15 (not the first day)',
 N'INSERT dbo.MEMBER_MONTHLY_SPENDING (Member_ID, SpendingMonth) VALUES (1, ''2026-11-15'');',
 N'CK_MEMBER_MONTHLY_SPENDING_FirstDay', NULL, 547),
('N12',  'N', N'Duplicate (Member_ID, SpendingMonth)',
 N'INSERT dbo.MEMBER_MONTHLY_SPENDING (Member_ID, SpendingMonth) VALUES (1, ''2026-11-01'');',
 N'PK_MEMBER_MONTHLY_SPENDING', NULL, 2627),
('N13a', 'N', N'Negative TotalSpend',
 N'INSERT dbo.MEMBER_MONTHLY_SPENDING (Member_ID, SpendingMonth, TotalSpend) VALUES (2, ''2026-11-01'', -1);',
 N'CK_MEMBER_MONTHLY_SPENDING_NonNegative', NULL, 547),
('N13b', 'N', N'Negative PointsEarned',
 N'INSERT dbo.MEMBER_MONTHLY_SPENDING (Member_ID, SpendingMonth, PointsEarned) VALUES (2, ''2026-09-01'', -1);',
 N'CK_MEMBER_MONTHLY_SPENDING_NonNegative', NULL, 547),
('N14',  'N', N'Spending row for an unknown member key',
 N'INSERT dbo.MEMBER_MONTHLY_SPENDING (Member_ID, SpendingMonth) VALUES (999, ''2026-11-01'');',
 N'FK_MEMBER_MONTHLY_SPENDING_MEMBER', NULL, 547),
('N15',  'N', N'Service line with ValidUntil < ValidFrom (BR13)',
 N'INSERT dbo.INVOICE_SERVICE_ITEM (Invoice_ID, [LineNo], Plan_ID, UnitPrice, DiscountAmount, ValidFrom, ValidUntil) VALUES (@inv1, 2, 1, 100000, 0, ''2026-12-01'', ''2026-11-30'');',
 N'CK_INVOICE_SERVICE_ITEM_Validity', NULL, 547),
('N16',  'N', N'Product line with Quantity 0',
 N'INSERT dbo.INVOICE_PRODUCT_ITEM (Invoice_ID, [LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount) VALUES (@inv1, 2, 1, 0, 100, 0);',
 N'CK_INVOICE_PRODUCT_ITEM_Quantity', NULL, 547),
('N17a', 'N', N'Service line with negative UnitPrice',
 N'INSERT dbo.INVOICE_SERVICE_ITEM (Invoice_ID, [LineNo], Plan_ID, UnitPrice, DiscountAmount) VALUES (@inv1, 3, 1, -1, 0);',
 N'CK_INVOICE_SERVICE_ITEM_Amounts', NULL, 547),
('N17b', 'N', N'Service line with negative discount',
 N'INSERT dbo.INVOICE_SERVICE_ITEM (Invoice_ID, [LineNo], Plan_ID, UnitPrice, DiscountAmount) VALUES (@inv1, 3, 1, 100, -1);',
 N'CK_INVOICE_SERVICE_ITEM_Amounts', NULL, 547),
('N17c', 'N', N'Service line discount greater than line price',
 N'INSERT dbo.INVOICE_SERVICE_ITEM (Invoice_ID, [LineNo], Plan_ID, UnitPrice, DiscountAmount) VALUES (@inv1, 3, 1, 100, 150);',
 N'CK_INVOICE_SERVICE_ITEM_Amounts', NULL, 547),
('N17d', 'N', N'Product line with negative UnitPrice',
 N'INSERT dbo.INVOICE_PRODUCT_ITEM (Invoice_ID, [LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount) VALUES (@inv1, 3, 1, 1, -1, 0);',
 N'CK_INVOICE_PRODUCT_ITEM_Amounts', NULL, 547),
('N17e', 'N', N'Product line discount greater than UnitPrice x Quantity',
 N'INSERT dbo.INVOICE_PRODUCT_ITEM (Invoice_ID, [LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount) VALUES (@inv1, 3, 1, 2, 100, 250);',
 N'CK_INVOICE_PRODUCT_ITEM_Amounts', NULL, 547),
('N17f', 'N', N'Product line with negative discount',
 N'INSERT dbo.INVOICE_PRODUCT_ITEM (Invoice_ID, [LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount) VALUES (@inv1, 3, 1, 1, 100, -1);',
 N'CK_INVOICE_PRODUCT_ITEM_Amounts', NULL, 547),
('N18a', 'N', N'Service line for an unknown invoice',
 N'INSERT dbo.INVOICE_SERVICE_ITEM (Invoice_ID, [LineNo], Plan_ID, UnitPrice, DiscountAmount) VALUES (999999, 1, 1, 100, 0);',
 N'FK_INVOICE_SERVICE_ITEM_INVOICE', NULL, 547),
('N18b', 'N', N'Service line for an unknown plan key',
 N'INSERT dbo.INVOICE_SERVICE_ITEM (Invoice_ID, [LineNo], Plan_ID, UnitPrice, DiscountAmount) VALUES (@inv1, 4, 999, 100, 0);',
 N'FK_INVOICE_SERVICE_ITEM_SERVICE_PLAN', NULL, 547),
('N18c', 'N', N'Product line for an unknown invoice',
 N'INSERT dbo.INVOICE_PRODUCT_ITEM (Invoice_ID, [LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount) VALUES (999999, 1, 1, 1, 100, 0);',
 N'FK_INVOICE_PRODUCT_ITEM_INVOICE', NULL, 547),
('N18d', 'N', N'Product line for an unknown product key',
 N'INSERT dbo.INVOICE_PRODUCT_ITEM (Invoice_ID, [LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount) VALUES (@inv1, 4, 999, 1, 100, 0);',
 N'FK_INVOICE_PRODUCT_ITEM_PRODUCT', NULL, 547),
('N19a', 'N', N'Delete a referenced member (fixture row)',
 N'DELETE dbo.MEMBER WHERE Member_ID = 1;',
 N'FK_INVOICE_MEMBER', N'FK_MEMBER_MONTHLY_SPENDING_MEMBER', 547),
('N19b', 'N', N'Delete a referenced branch (fixture row)',
 N'DELETE dbo.BRANCH WHERE Branch_ID = 1;',
 N'FK_INVOICE_BRANCH', NULL, 547),
('N19c', 'N', N'Delete a referenced employee (fixture row)',
 N'DELETE dbo.EMPLOYEE WHERE Employee_ID = 1;',
 N'FK_INVOICE_EMPLOYEE', NULL, 547),
('N19d', 'N', N'Delete a referenced plan (fixture row)',
 N'DELETE dbo.SERVICE_PLAN WHERE Plan_ID = 1;',
 N'FK_INVOICE_SERVICE_ITEM_SERVICE_PLAN', NULL, 547),
('N19e', 'N', N'Delete a referenced product (fixture row)',
 N'DELETE dbo.PRODUCT WHERE Product_ID = 1;',
 N'FK_INVOICE_PRODUCT_ITEM_PRODUCT', NULL, 547),
('N19f', 'N', N'Delete an invoice that has lines',
 N'DELETE dbo.INVOICE WHERE Invoice_ID = @inv1;',
 N'FK_INVOICE_SERVICE_ITEM_INVOICE', N'FK_INVOICE_PRODUCT_ITEM_INVOICE', 547),
('N20a', 'N', N'Duplicate service line (Invoice_ID, LineNo)',
 N'INSERT dbo.INVOICE_SERVICE_ITEM (Invoice_ID, [LineNo], Plan_ID, UnitPrice, DiscountAmount) VALUES (@inv1, 1, 1, 100, 0);',
 N'PK_INVOICE_SERVICE_ITEM', NULL, 2627),
('N20b', 'N', N'Duplicate product line (Invoice_ID, LineNo)',
 N'INSERT dbo.INVOICE_PRODUCT_ITEM (Invoice_ID, [LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount) VALUES (@inv1, 1, 1, 1, 100, 0);',
 N'PK_INVOICE_PRODUCT_ITEM', NULL, 2627),
('N21',  'N', N'Duplicate Invoice_ID (explicit key with IDENTITY_INSERT)',
 N'SET IDENTITY_INSERT dbo.INVOICE ON;
BEGIN TRY
    INSERT dbo.INVOICE (Invoice_ID, Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount) VALUES (@inv1, 1, 1, 1, ''2026-11-07T04:00:00'', 100, 0, 100);
END TRY
BEGIN CATCH
    SET IDENTITY_INSERT dbo.INVOICE OFF;
    THROW;
END CATCH;
SET IDENTITY_INSERT dbo.INVOICE OFF;',
 N'PK_INVOICE', NULL, 2627),
('N22',  'N', N'PAID -> PENDING while keeping PaidAt',
 N'UPDATE dbo.INVOICE SET PaymentStatus = ''PENDING'' WHERE Invoice_ID = @inv1;',
 N'CK_INVOICE_PaidAtStatus', NULL, 547),
('I01',  'I', N'PAID -> PENDING with PaidAt and PaymentMethod cleared (transition rule T2)',
 N'UPDATE dbo.INVOICE SET PaymentStatus = ''PENDING'', PaidAt = NULL, PaymentMethod = NULL WHERE Invoice_ID = @inv1;',
 NULL, NULL, NULL);

DECLARE @cid VARCHAR(12), @kind CHAR(1), @descr NVARCHAR(300), @sql NVARCHAR(MAX), @e1 SYSNAME, @e2 SYSNAME, @enum INT, @hit BIT;
DECLARE case_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT case_id, kind, descr, sql_text, exp1, exp2, exp_num FROM @cases ORDER BY seq;
OPEN case_cursor;
FETCH NEXT FROM case_cursor INTO @cid, @kind, @descr, @sql, @e1, @e2, @enum;
WHILE @@FETCH_STATUS = 0
BEGIN
    SAVE TRANSACTION sp_case;
    BEGIN TRY
        EXEC sys.sp_executesql @sql, N'@inv1 INT, @inv2 INT, @inv3 INT, @inv4 INT', @inv1, @inv2, @inv3, @inv4;
        IF @kind = 'N'
            INSERT @results (case_id, kind, result, descr, detail) VALUES (@cid, @kind, 'FAIL', @descr, N'no error: the invalid change was accepted');
        ELSE
            INSERT @results (case_id, kind, result, descr, detail) VALUES (@cid, @kind, 'INFO', @descr,
                N'accepted by the schema, as documented: transition rules T1-T4 need the old value and are enforced by the UC05 routines (WO-P3-P3-01), not by CHECK constraints');
        ROLLBACK TRANSACTION sp_case;
    END TRY
    BEGIN CATCH
        SELECT @msg = ERROR_MESSAGE(), @n = ERROR_NUMBER();
        IF XACT_STATE() = -1
        BEGIN
            INSERT @results (case_id, kind, result, descr, detail) VALUES (@cid, @kind, 'FAIL', @descr, CONCAT(N'transaction became uncommittable: ', @n, N': ', @msg));
            BREAK;
        END;
        IF XACT_STATE() = 1 ROLLBACK TRANSACTION sp_case;
        SET @hit = CASE WHEN @msg LIKE N'%"' + @e1 + N'"%' OR @msg LIKE N'%''' + @e1 + N'''%'
                          OR (@e2 IS NOT NULL AND (@msg LIKE N'%"' + @e2 + N'"%' OR @msg LIKE N'%''' + @e2 + N'''%')) THEN 1 ELSE 0 END;
        IF @kind = 'N'
            INSERT @results (case_id, kind, result, descr, detail) VALUES (@cid, @kind,
                CASE WHEN @hit = 1 AND (@enum IS NULL OR @n = @enum) THEN 'PASS' ELSE 'FAIL' END, @descr, CONCAT(@n, N': ', @msg));
        ELSE
            INSERT @results (case_id, kind, result, descr, detail) VALUES (@cid, @kind, 'INFO', @descr, CONCAT(N'rejected: ', @n, N': ', @msg));
    END CATCH;
    FETCH NEXT FROM case_cursor INTO @cid, @kind, @descr, @sql, @e1, @e2, @enum;
END;
CLOSE case_cursor;
DEALLOCATE case_cursor;

/* ---- clean-up: nothing written by this test survives ---- */
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
SELECT @n = (SELECT COUNT(*) FROM dbo.INVOICE) + (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM) + (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM)
          + (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING) + (SELECT COUNT(*) FROM dbo.MEMBER) + (SELECT COUNT(*) FROM dbo.BRANCH)
          + (SELECT COUNT(*) FROM dbo.EMPLOYEE) + (SELECT COUNT(*) FROM dbo.SERVICE_PLAN) + (SELECT COUNT(*) FROM dbo.PRODUCT);
INSERT @results (case_id, kind, result, descr, detail) VALUES ('POST', 'P', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'All test rows rolled back (P3 and fixture tables empty)', CONCAT(N'remaining rows: ', @n));

SELECT case_id, kind, result, descr, detail FROM @results ORDER BY seq;

DECLARE @total INT, @pass INT, @fail INT, @info INT;
SELECT @total = COUNT(*), @pass = SUM(CASE WHEN result = 'PASS' THEN 1 ELSE 0 END),
       @fail = SUM(CASE WHEN result = 'FAIL' THEN 1 ELSE 0 END), @info = SUM(CASE WHEN result = 'INFO' THEN 1 ELSE 0 END)
FROM @results;
PRINT CONCAT('T-SCH-01 SUMMARY: cases=', @total, ' PASS=', @pass, ' FAIL=', @fail, ' INFO=', @info);
IF @fail > 0 OR @total <> 54   -- 9 positive + 43 negative + 1 informational + POST
BEGIN
    PRINT 'T-SCH-01_RESULT: FAIL';
    THROW 51032, N'T-SCH-01 failed (see the result table).', 1;
END
ELSE
    PRINT 'T-SCH-01_RESULT: PASS';
GO
