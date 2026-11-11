/* =====================================================================
   F001D__TEST_ONLY_fixture_key_rows.sql  (sqlcmd mode)
   Classification : TEST_ONLY_FIXTURE DATA - NOT PRODUCTION. NOT A P3 MODULE.
   Work order     : WO-P3-P2-01 (D-026 restricted; D-022)
   Purpose        : inserts KEY ROWS ONLY into the five F001 key-only fixtures, so
                    that the P3 dataset generator (db/seed/S001) can reference valid
                    parents. No names, prices, stock, assignments, statuses or any
                    other attribute of another member's domain is created.
   Owned by       : the real tables belong to other members; replaced by the approved
                    team schema and team seed pipeline at P6 (D-026 condition 9).
   Variables      : MemberCount, BranchCount, EmployeesPerBranch, PlanCount, ProductCount
   Guards         : FitLife_P3_% database other than FitLife_P3_P1, carrying the
                    WO-P3-P2-01 disposable marker; fixtures and P3 tables empty.
   ===================================================================== */
:on error exit
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF DB_NAME() NOT LIKE N'FitLife[_]P3[_]%' OR DB_NAME() = N'FitLife_P3_P1'
    THROW 51020, N'F001D (TEST_ONLY) may run only in an isolated FitLife_P3_% database other than FitLife_P3_P1.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable'
               AND CONVERT(nvarchar(200), value) LIKE N'WO-P3-P2-01%')
    THROW 51021, N'F001D (TEST_ONLY) requires the WO-P3-P2-01 disposable marker.', 1;
IF EXISTS (SELECT 1 FROM dbo.MEMBER) OR EXISTS (SELECT 1 FROM dbo.BRANCH) OR EXISTS (SELECT 1 FROM dbo.EMPLOYEE)
   OR EXISTS (SELECT 1 FROM dbo.SERVICE_PLAN) OR EXISTS (SELECT 1 FROM dbo.PRODUCT) OR EXISTS (SELECT 1 FROM dbo.INVOICE)
    THROW 51023, N'F001D (TEST_ONLY): fixtures or P3 tables are not empty; rebuild the database first.', 1;
IF $(MemberCount) < 1 OR $(BranchCount) < 1 OR $(EmployeesPerBranch) < 1 OR $(PlanCount) < 1 OR $(ProductCount) < 1
    THROW 51024, N'F001D (TEST_ONLY): every key count must be at least 1.', 1;

BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.BRANCH       (Branch_ID)   SELECT value FROM GENERATE_SERIES(1, $(BranchCount));
    INSERT dbo.EMPLOYEE     (Employee_ID) SELECT value FROM GENERATE_SERIES(1, $(BranchCount) * $(EmployeesPerBranch));
    INSERT dbo.MEMBER       (Member_ID)   SELECT value FROM GENERATE_SERIES(1, $(MemberCount));
    INSERT dbo.SERVICE_PLAN (Plan_ID)     SELECT value FROM GENERATE_SERIES(1, $(PlanCount));
    INSERT dbo.PRODUCT      (Product_ID)  SELECT value FROM GENERATE_SERIES(1, $(ProductCount));
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT (SELECT COUNT(*) FROM dbo.BRANCH) AS branch_keys, (SELECT COUNT(*) FROM dbo.EMPLOYEE) AS employee_keys,
       (SELECT COUNT(*) FROM dbo.MEMBER) AS member_keys, (SELECT COUNT(*) FROM dbo.SERVICE_PLAN) AS plan_keys,
       (SELECT COUNT(*) FROM dbo.PRODUCT) AS product_keys;
PRINT 'F001D (TEST_ONLY) applied: key rows only';
GO
