/* =====================================================================
   T-REPRO-02_checksums.sql - TEST_ONLY (sqlcmd mode), read-only
   Work order : WO-P3-P2-01. Prints one row count and one SHA-256 per table, and one
   dataset checksum, computed over every row in key order with a canonical text form
   (decimals with their fixed scale, timestamps in ODBC canonical form, NULL as "~").
   Rows are hashed one by one, then in chunks of 10,000 keys, then per table, so the
   result depends on every value and on nothing volatile. Two generations with the same
   seed and profile must print identical output. Variable MaxGrantPercent: memory-grant cap
   (affects memory use only).
   ===================================================================== */
:on error exit
SET NOCOUNT ON;

IF DB_NAME() NOT LIKE N'FitLife[_]P3[_]%'
    THROW 51080, N'T-REPRO-02 runs only in an isolated FitLife_P3_% database.', 1;

DECLARE @t TABLE (seq int, tbl sysname, row_count bigint, sha256 varchar(64));

WITH r AS (
    SELECT Invoice_ID / 10000 AS chunk, Invoice_ID AS k1, 0 AS k2,
           CONVERT(varchar(64), HASHBYTES('SHA2_256', CONCAT_WS('|', Invoice_ID, Member_ID, Employee_ID, Branch_ID,
                CONVERT(varchar(23), IssuedAt, 121), GrossAmount, DiscountAmount, FinalAmount,
                ISNULL(PaymentMethod, '~'), PaymentStatus, ISNULL(CONVERT(varchar(23), PaidAt, 121), '~'))), 2) AS h
    FROM dbo.INVOICE),
c AS (SELECT chunk, CONVERT(varchar(64), HASHBYTES('SHA2_256', STRING_AGG(CAST(h AS varchar(max)), '') WITHIN GROUP (ORDER BY k1, k2)), 2) AS ch FROM r GROUP BY chunk)
INSERT @t SELECT 1, N'INVOICE', (SELECT COUNT_BIG(*) FROM dbo.INVOICE),
       CONVERT(varchar(64), HASHBYTES('SHA2_256', STRING_AGG(CAST(ch AS varchar(max)), '') WITHIN GROUP (ORDER BY chunk)), 2) FROM c
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));

WITH r AS (
    SELECT Invoice_ID / 10000 AS chunk, Invoice_ID AS k1, [LineNo] AS k2,
           CONVERT(varchar(64), HASHBYTES('SHA2_256', CONCAT_WS('|', Invoice_ID, [LineNo], Plan_ID, UnitPrice, DiscountAmount,
                ISNULL(CONVERT(char(10), ValidFrom, 23), '~'), ISNULL(CONVERT(char(10), ValidUntil, 23), '~'),
                ISNULL(CONVERT(varchar(12), PTSessionsRemaining), '~'))), 2) AS h
    FROM dbo.INVOICE_SERVICE_ITEM),
c AS (SELECT chunk, CONVERT(varchar(64), HASHBYTES('SHA2_256', STRING_AGG(CAST(h AS varchar(max)), '') WITHIN GROUP (ORDER BY k1, k2)), 2) AS ch FROM r GROUP BY chunk)
INSERT @t SELECT 2, N'INVOICE_SERVICE_ITEM', (SELECT COUNT_BIG(*) FROM dbo.INVOICE_SERVICE_ITEM),
       CONVERT(varchar(64), HASHBYTES('SHA2_256', STRING_AGG(CAST(ch AS varchar(max)), '') WITHIN GROUP (ORDER BY chunk)), 2) FROM c
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));

WITH r AS (
    SELECT Invoice_ID / 10000 AS chunk, Invoice_ID AS k1, [LineNo] AS k2,
           CONVERT(varchar(64), HASHBYTES('SHA2_256', CONCAT_WS('|', Invoice_ID, [LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount)), 2) AS h
    FROM dbo.INVOICE_PRODUCT_ITEM),
c AS (SELECT chunk, CONVERT(varchar(64), HASHBYTES('SHA2_256', STRING_AGG(CAST(h AS varchar(max)), '') WITHIN GROUP (ORDER BY k1, k2)), 2) AS ch FROM r GROUP BY chunk)
INSERT @t SELECT 3, N'INVOICE_PRODUCT_ITEM', (SELECT COUNT_BIG(*) FROM dbo.INVOICE_PRODUCT_ITEM),
       CONVERT(varchar(64), HASHBYTES('SHA2_256', STRING_AGG(CAST(ch AS varchar(max)), '') WITHIN GROUP (ORDER BY chunk)), 2) FROM c
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));

WITH r AS (
    SELECT Member_ID / 1000 AS chunk, Member_ID AS k1, DATEDIFF(MONTH, '20000101', SpendingMonth) AS k2,
           CONVERT(varchar(64), HASHBYTES('SHA2_256', CONCAT_WS('|', Member_ID, CONVERT(char(10), SpendingMonth, 23),
                TotalSpend, PointsEarned, CONVERT(varchar(23), UpdatedAt, 121))), 2) AS h
    FROM dbo.MEMBER_MONTHLY_SPENDING),
c AS (SELECT chunk, CONVERT(varchar(64), HASHBYTES('SHA2_256', STRING_AGG(CAST(h AS varchar(max)), '') WITHIN GROUP (ORDER BY k1, k2)), 2) AS ch FROM r GROUP BY chunk)
INSERT @t SELECT 4, N'MEMBER_MONTHLY_SPENDING', (SELECT COUNT_BIG(*) FROM dbo.MEMBER_MONTHLY_SPENDING),
       CONVERT(varchar(64), HASHBYTES('SHA2_256', STRING_AGG(CAST(ch AS varchar(max)), '') WITHIN GROUP (ORDER BY chunk)), 2) FROM c
OPTION (MAX_GRANT_PERCENT = $(MaxGrantPercent));

INSERT @t SELECT 5, N'MEMBER (TEST_ONLY keys)', COUNT_BIG(*), CONVERT(varchar(64), HASHBYTES('SHA2_256', STRING_AGG(CAST(CONVERT(varchar(12), Member_ID) AS varchar(max)), ',') WITHIN GROUP (ORDER BY Member_ID)), 2) FROM dbo.MEMBER;
INSERT @t SELECT 6, N'BRANCH (TEST_ONLY keys)', COUNT_BIG(*), CONVERT(varchar(64), HASHBYTES('SHA2_256', STRING_AGG(CAST(CONVERT(varchar(12), Branch_ID) AS varchar(max)), ',') WITHIN GROUP (ORDER BY Branch_ID)), 2) FROM dbo.BRANCH;
INSERT @t SELECT 7, N'EMPLOYEE (TEST_ONLY keys)', COUNT_BIG(*), CONVERT(varchar(64), HASHBYTES('SHA2_256', STRING_AGG(CAST(CONVERT(varchar(12), Employee_ID) AS varchar(max)), ',') WITHIN GROUP (ORDER BY Employee_ID)), 2) FROM dbo.EMPLOYEE;
INSERT @t SELECT 8, N'SERVICE_PLAN (TEST_ONLY keys)', COUNT_BIG(*), CONVERT(varchar(64), HASHBYTES('SHA2_256', STRING_AGG(CAST(CONVERT(varchar(12), Plan_ID) AS varchar(max)), ',') WITHIN GROUP (ORDER BY Plan_ID)), 2) FROM dbo.SERVICE_PLAN;
INSERT @t SELECT 9, N'PRODUCT (TEST_ONLY keys)', COUNT_BIG(*), CONVERT(varchar(64), HASHBYTES('SHA2_256', STRING_AGG(CAST(CONVERT(varchar(12), Product_ID) AS varchar(max)), ',') WITHIN GROUP (ORDER BY Product_ID)), 2) FROM dbo.PRODUCT;

SELECT tbl, row_count, ISNULL(sha256, 'EMPTY') AS sha256 FROM @t ORDER BY seq;
SELECT 'DATASET_CHECKSUM' AS item,
       CONVERT(varchar(64), HASHBYTES('SHA2_256', STRING_AGG(CAST(CONCAT(tbl, ':', row_count, ':', ISNULL(sha256, 'EMPTY')) AS varchar(max)), '|') WITHIN GROUP (ORDER BY seq)), 2) AS sha256
FROM @t;
GO
