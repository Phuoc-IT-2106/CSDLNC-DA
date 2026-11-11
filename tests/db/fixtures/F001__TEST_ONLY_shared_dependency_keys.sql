/* =====================================================================
   F001__TEST_ONLY_shared_dependency_keys.sql
   Classification : TEST_ONLY_FIXTURE — NOT PRODUCTION. NOT A P3 MODULE.
   Work order     : WO-P3-P1-01 (D-026, restricted scope, approved 2026-11-07)
   Purpose        : minimum key-only stand-ins for five SHARED_DEPENDENCY tables,
                    so that the 8 foreign keys of the P3 tables can be created and
                    tested in an isolated database while no approved team schema exists.
   Owned by       : the real tables belong to other team members (12 §2 / §2a).
                    These fixtures are never deployed to a shared database, never cited
                    as their implementation, and are replaced by the approved team
                    schema before final integration (then T-SCH-01, T-SCH-02, T-INT-03
                    are re-run) — D-026 conditions 3–9.
   Content        : Phase 1 table names, Phase 1 primary-key column, D-014 type (INT).
                    No other columns, no IDENTITY, no defaults, CHECKs, indexes,
                    triggers, routines or business logic.
   Guards         : runs only in a database named FitLife_P3_% that carries the
                    P3_Disposable marker, and only if none of the five tables exists.
   ===================================================================== */
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF DB_NAME() NOT LIKE N'FitLife[_]P3[_]%'
    THROW 51020, N'F001 (TEST_ONLY) may run only in an isolated FitLife_P3_% database.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable')
    THROW 51021, N'F001 (TEST_ONLY) requires the P3_Disposable database marker.', 1;
IF OBJECT_ID(N'dbo.MEMBER', N'U') IS NOT NULL OR OBJECT_ID(N'dbo.BRANCH', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.EMPLOYEE', N'U') IS NOT NULL OR OBJECT_ID(N'dbo.SERVICE_PLAN', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.PRODUCT', N'U') IS NOT NULL
    THROW 51022, N'F001 (TEST_ONLY): a shared table already exists (team schema?). Use it instead of fixtures.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    CREATE TABLE dbo.MEMBER       (Member_ID   INT NOT NULL, CONSTRAINT PK_MEMBER       PRIMARY KEY CLUSTERED (Member_ID));
    CREATE TABLE dbo.BRANCH       (Branch_ID   INT NOT NULL, CONSTRAINT PK_BRANCH       PRIMARY KEY CLUSTERED (Branch_ID));
    CREATE TABLE dbo.EMPLOYEE     (Employee_ID INT NOT NULL, CONSTRAINT PK_EMPLOYEE     PRIMARY KEY CLUSTERED (Employee_ID));
    CREATE TABLE dbo.SERVICE_PLAN (Plan_ID     INT NOT NULL, CONSTRAINT PK_SERVICE_PLAN PRIMARY KEY CLUSTERED (Plan_ID));
    CREATE TABLE dbo.PRODUCT      (Product_ID  INT NOT NULL, CONSTRAINT PK_PRODUCT      PRIMARY KEY CLUSTERED (Product_ID));

    EXEC sys.sp_addextendedproperty @name = N'Classification', @value = N'TEST_ONLY_FIXTURE', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'MEMBER';
    EXEC sys.sp_addextendedproperty @name = N'Classification', @value = N'TEST_ONLY_FIXTURE', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BRANCH';
    EXEC sys.sp_addextendedproperty @name = N'Classification', @value = N'TEST_ONLY_FIXTURE', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'EMPLOYEE';
    EXEC sys.sp_addextendedproperty @name = N'Classification', @value = N'TEST_ONLY_FIXTURE', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SERVICE_PLAN';
    EXEC sys.sp_addextendedproperty @name = N'Classification', @value = N'TEST_ONLY_FIXTURE', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'PRODUCT';

    COMMIT TRANSACTION;
    PRINT 'F001 (TEST_ONLY) applied: key-only fixtures MEMBER, BRANCH, EMPLOYEE, SERVICE_PLAN, PRODUCT';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
