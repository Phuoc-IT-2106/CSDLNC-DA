/* =====================================================================
   V-UC05_integrity.sql - TEST_ONLY (sqlcmd mode), read-only
   Work order : WO-P3-P3-00. Run after every test stage in FitLife_P3_UC05
   (after T-F05 and after each T-CONC-06 run). Checks the whole database:
     I1  V-TOT: every header equals the sum of its lines; every invoice has a line (BR12)
     I2  no orphan line (line without header)
     I3  initial payment state: every invoice PENDING, PaidAt NULL (no settlement exists here)
     I4  PaymentMethod NULL or one of the exact literals CASH, VNPAY, CARD
     I5  FinalAmount = Gross - Discount, all amounts >= 0, IssuedAt not in the future (UTC)
     I6  no loyalty or spending effect: MEMBER_MONTHLY_SPENDING empty
     I7  no entitlement or PT effect: ValidFrom, ValidUntil, PTSessionsRemaining all NULL
     I8  TEST_ONLY fixtures unchanged (exact F001U key rows) and still key-only
     I9  no leftover test object (trigger), principal or explicit permission; inventory as deployed
     I10 every CHECK and FOREIGN KEY constraint enabled and trusted
   Run: sqlcmd -S localhost -E -I -b -W -d FitLife_P3_UC05 -i tests/db/functional/V-UC05_integrity.sql
   ===================================================================== */
:on error exit
SET NOCOUNT ON;

IF DB_NAME() <> N'FitLife_P3_UC05'
    THROW 51140, N'V-UC05 runs only in FitLife_P3_UC05.', 1;

DECLARE @checks TABLE (seq int IDENTITY(1,1), check_id varchar(4), result varchar(4), descr nvarchar(300), detail nvarchar(2000));
DECLARE @n int, @n2 int, @n3 int;

WITH s AS (SELECT Invoice_ID, SUM(UnitPrice) AS g, SUM(DiscountAmount) AS d, COUNT(*) AS n FROM dbo.INVOICE_SERVICE_ITEM GROUP BY Invoice_ID),
     p AS (SELECT Invoice_ID, SUM(UnitPrice * Quantity) AS g, SUM(DiscountAmount) AS d, COUNT(*) AS n FROM dbo.INVOICE_PRODUCT_ITEM GROUP BY Invoice_ID)
SELECT @n = COUNT(*) FROM dbo.INVOICE AS i LEFT JOIN s ON s.Invoice_ID = i.Invoice_ID LEFT JOIN p ON p.Invoice_ID = i.Invoice_ID
WHERE i.GrossAmount <> ISNULL(s.g, 0) + ISNULL(p.g, 0) OR i.DiscountAmount <> ISNULL(s.d, 0) + ISNULL(p.d, 0) OR ISNULL(s.n, 0) + ISNULL(p.n, 0) = 0;
INSERT @checks VALUES ('I1', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, N'V-TOT: header Gross/Discount = sum of lines; no invoice without a line (D-023 X1, BR12)', CONCAT(N'V-TOT rows: ', @n));

SELECT @n = (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM AS x WHERE NOT EXISTS (SELECT 1 FROM dbo.INVOICE AS i WHERE i.Invoice_ID = x.Invoice_ID)),
       @n2 = (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM AS x WHERE NOT EXISTS (SELECT 1 FROM dbo.INVOICE AS i WHERE i.Invoice_ID = x.Invoice_ID));
INSERT @checks VALUES ('I2', CASE WHEN @n + @n2 = 0 THEN 'PASS' ELSE 'FAIL' END, N'No orphan invoice line', CONCAT(N'orphan service lines: ', @n, N'; orphan product lines: ', @n2));

SET @n = (SELECT COUNT(*) FROM dbo.INVOICE WHERE PaymentStatus <> 'PENDING' OR PaidAt IS NOT NULL);
INSERT @checks VALUES ('I3', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, N'Initial payment state: every invoice PENDING with PaidAt NULL (D-005; no settlement routine in this database)', CONCAT(N'invoices not PENDING or with PaidAt: ', @n));

SET @n = (SELECT COUNT(*) FROM dbo.INVOICE WHERE PaymentMethod IS NOT NULL
          AND (PaymentMethod COLLATE Latin1_General_BIN2 NOT IN ('CASH', 'VNPAY', 'CARD') OR DATALENGTH(PaymentMethod) <> LEN(PaymentMethod)));
INSERT @checks VALUES ('I4', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, N'PaymentMethod NULL or exactly CASH, VNPAY, CARD', CONCAT(N'other values: ', @n));

SET @n = (SELECT COUNT(*) FROM dbo.INVOICE WHERE FinalAmount <> GrossAmount - DiscountAmount OR GrossAmount < 0 OR DiscountAmount < 0 OR FinalAmount < 0
          OR DiscountAmount > GrossAmount OR IssuedAt > DATEADD(SECOND, 5, SYSUTCDATETIME()));
INSERT @checks VALUES ('I5', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, N'Header amounts consistent (Final = Gross - Discount >= 0, Discount <= Gross); IssuedAt (UTC) not in the future', CONCAT(N'violations: ', @n));

SET @n = (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING);
INSERT @checks VALUES ('I6', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, N'No loyalty or spending effect: MEMBER_MONTHLY_SPENDING has no row', CONCAT(N'rows: ', @n));

SET @n = (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM WHERE ValidFrom IS NOT NULL OR ValidUntil IS NOT NULL OR PTSessionsRemaining IS NOT NULL);
INSERT @checks VALUES ('I7', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, N'No entitlement activation or PT effect: ValidFrom, ValidUntil, PTSessionsRemaining NULL on every service line (DEP-06)', CONCAT(N'service lines with a value: ', @n));

SELECT @n = CASE WHEN (SELECT COUNT(*) FROM dbo.MEMBER) = 40 AND (SELECT MIN(Member_ID) FROM dbo.MEMBER) = 1 AND (SELECT MAX(Member_ID) FROM dbo.MEMBER) = 40
                  AND (SELECT COUNT(*) FROM dbo.EMPLOYEE) = 6 AND (SELECT MIN(Employee_ID) FROM dbo.EMPLOYEE) = 1 AND (SELECT MAX(Employee_ID) FROM dbo.EMPLOYEE) = 6
                  AND (SELECT COUNT(*) FROM dbo.BRANCH) = 3 AND (SELECT MIN(Branch_ID) FROM dbo.BRANCH) = 1 AND (SELECT MAX(Branch_ID) FROM dbo.BRANCH) = 3
                  AND (SELECT COUNT(*) FROM dbo.SERVICE_PLAN) = 5 AND (SELECT MIN(Plan_ID) FROM dbo.SERVICE_PLAN) = 1 AND (SELECT MAX(Plan_ID) FROM dbo.SERVICE_PLAN) = 5
                  AND (SELECT COUNT(*) FROM dbo.PRODUCT) = 10 AND (SELECT MIN(Product_ID) FROM dbo.PRODUCT) = 1 AND (SELECT MAX(Product_ID) FROM dbo.PRODUCT) = 10
             THEN 0 ELSE 1 END,
       @n2 = (SELECT COUNT(*) FROM sys.columns WHERE object_id IN (OBJECT_ID(N'dbo.MEMBER'), OBJECT_ID(N'dbo.EMPLOYEE'), OBJECT_ID(N'dbo.BRANCH'), OBJECT_ID(N'dbo.SERVICE_PLAN'), OBJECT_ID(N'dbo.PRODUCT')));
INSERT @checks VALUES ('I8', CASE WHEN @n = 0 AND @n2 = 5 THEN 'PASS' ELSE 'FAIL' END, N'TEST_ONLY fixtures unchanged (exact F001U key rows) and key-only (one column each)',
    CONCAT(N'key rows as loaded: ', CASE WHEN @n = 0 THEN N'yes' ELSE N'NO' END, N'; fixture columns: ', @n2));

SELECT @n = (SELECT COUNT(*) FROM sys.triggers),
       @n2 = (SELECT COUNT(*) FROM sys.database_principals WHERE principal_id > 4 AND is_fixed_role = 0 AND name NOT IN (N'public'))
           + (SELECT COUNT(*) FROM sys.database_permissions WHERE class IN (1, 6) AND grantee_principal_id > 4),
       @n3 = (SELECT COUNT(*) FROM sys.objects WHERE is_ms_shipped = 0 AND type NOT IN ('U', 'PK', 'F', 'C', 'D', 'P', 'TT'))
           + ABS((SELECT COUNT(*) FROM sys.procedures WHERE is_ms_shipped = 0) - 1) + ABS((SELECT COUNT(*) FROM sys.table_types WHERE is_user_defined = 1) - 2)
           + (SELECT COUNT(*) FROM sys.indexes AS i JOIN sys.tables AS t ON t.object_id = i.object_id WHERE t.is_ms_shipped = 0 AND i.type > 0 AND i.is_primary_key = 0);
INSERT @checks VALUES ('I9', CASE WHEN @n = 0 AND @n2 = 0 AND @n3 = 0 THEN 'PASS' ELSE 'FAIL' END, N'No leftover TEST_ONLY trigger, principal or permission; object inventory as deployed (1 procedure, 2 types, no extra index)',
    CONCAT(N'triggers: ', @n, N'; extra principals/permissions: ', @n2, N'; inventory deviations: ', @n3));

SET @n = (SELECT COUNT(*) FROM sys.check_constraints WHERE is_disabled = 1 OR is_not_trusted = 1) + (SELECT COUNT(*) FROM sys.foreign_keys WHERE is_disabled = 1 OR is_not_trusted = 1);
INSERT @checks VALUES ('I10', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, N'All CHECK and FOREIGN KEY constraints enabled and trusted', CONCAT(N'disabled or untrusted: ', @n));

SELECT check_id, result, descr, detail FROM @checks ORDER BY seq;
SELECT (SELECT COUNT(*) FROM dbo.INVOICE) AS invoices, (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM) AS service_lines,
       (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM) AS product_lines, (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING) AS spending_rows;

DECLARE @fails int = (SELECT COUNT(*) FROM @checks WHERE result = 'FAIL'), @nchecks int = (SELECT COUNT(*) FROM @checks);
PRINT CONCAT('V-UC05 SUMMARY: checks=', @nchecks, ' FAIL=', @fails);
IF @fails > 0
BEGIN
    PRINT 'V-UC05_RESULT: FAIL';
    THROW 51141, N'V-UC05 failed (see the check table).', 1;
END
ELSE
    PRINT 'V-UC05_RESULT: PASS';
GO
