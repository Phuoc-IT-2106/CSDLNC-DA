/* =====================================================================
   F001U__TEST_ONLY_uc05_key_rows.sql  (sqlcmd mode)
   Classification : TEST_ONLY_FIXTURE DATA - NOT PRODUCTION. NOT A P3 MODULE.
   Work order     : WO-P3-P3-00 (D-026 restricted)
   Purpose        : inserts KEY ROWS ONLY into the five F001 key-only fixtures of the
                    isolated UC05 database, so that invoice-creation tests can reference
                    valid parents. No names, prices, stock, assignments, statuses or any
                    other attribute of another member's domain is created.
                      BRANCH 1-3, EMPLOYEE 1-6, MEMBER 1-40, SERVICE_PLAN 1-5, PRODUCT 1-10
   Owned by       : the real tables belong to other members; replaced by the approved team
                    schema at P6 (D-026 condition 9).
   Guards         : only FitLife_P3_UC05 carrying the WO-P3-P3-00 disposable marker;
                    fixtures and P3 tables empty.
   ===================================================================== */
:on error exit
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF DB_NAME() <> N'FitLife_P3_UC05'
    THROW 51020, N'F001U (TEST_ONLY) may run only in FitLife_P3_UC05.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable'
               AND CONVERT(nvarchar(200), value) LIKE N'WO-P3-P3-00%')
    THROW 51021, N'F001U (TEST_ONLY) requires the WO-P3-P3-00 disposable marker.', 1;
IF EXISTS (SELECT 1 FROM dbo.MEMBER) OR EXISTS (SELECT 1 FROM dbo.BRANCH) OR EXISTS (SELECT 1 FROM dbo.EMPLOYEE)
   OR EXISTS (SELECT 1 FROM dbo.SERVICE_PLAN) OR EXISTS (SELECT 1 FROM dbo.PRODUCT) OR EXISTS (SELECT 1 FROM dbo.INVOICE)
    THROW 51023, N'F001U (TEST_ONLY): fixtures or P3 tables are not empty; rebuild the database first.', 1;

BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.BRANCH       (Branch_ID)   SELECT value FROM GENERATE_SERIES(1, 3);
    INSERT dbo.EMPLOYEE     (Employee_ID) SELECT value FROM GENERATE_SERIES(1, 6);
    INSERT dbo.MEMBER       (Member_ID)   SELECT value FROM GENERATE_SERIES(1, 40);
    INSERT dbo.SERVICE_PLAN (Plan_ID)     SELECT value FROM GENERATE_SERIES(1, 5);
    INSERT dbo.PRODUCT      (Product_ID)  SELECT value FROM GENERATE_SERIES(1, 10);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT (SELECT COUNT(*) FROM dbo.BRANCH) AS branch_keys, (SELECT COUNT(*) FROM dbo.EMPLOYEE) AS employee_keys,
       (SELECT COUNT(*) FROM dbo.MEMBER) AS member_keys, (SELECT COUNT(*) FROM dbo.SERVICE_PLAN) AS plan_keys,
       (SELECT COUNT(*) FROM dbo.PRODUCT) AS product_keys;
PRINT 'F001U (TEST_ONLY) applied: key rows only';
GO
