/* =====================================================================
   rebuild_isolated_db.sql — TEST_ONLY harness (sqlcmd mode), not production
   Work order : WO-P3-P1-01
   Builds the isolated, disposable test database for P1 from nothing:
     1. guard the name (must match FitLife_P3_%);
     2. if the database exists, drop it ONLY if it carries the P3_Disposable
        marker written by this script; otherwise stop (unknown data is never dropped);
     3. create it (SIMPLE recovery, compatibility level 160) and mark it disposable;
     4. apply, in order:
          tests/db/fixtures/F001__TEST_ONLY_shared_dependency_keys.sql  (TEST_ONLY; only
              while no approved team schema exists — D-026 condition 3)
          db/migrations/V001__p3_billing_and_spending_tables.sql        (P3_OWNED)
          db/migrations/V002__p3_settlement_and_spending_constraints.sql (P3_OWNED)
   Run from the repository root (paths below are relative to it):
     sqlcmd -S localhost -E -I -b -i tests/db/build/rebuild_isolated_db.sql
   Never point DbName at a team or shared database.
   ===================================================================== */
:on error exit
:setvar DbName FitLife_P3_P1
SET NOCOUNT ON;

IF N'$(DbName)' NOT LIKE N'FitLife[_]P3[_]%'
    THROW 51010, N'Refusing to run: target database name must match FitLife_P3_%.', 1;
IF CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) NOT LIKE N'%Developer%'
    THROW 51013, N'Refusing to run: not a Developer-edition (local development) instance.', 1;
GO

DECLARE @marker nvarchar(200) = NULL;
IF DB_ID(N'$(DbName)') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql
        N'SELECT @m = CONVERT(nvarchar(200), value) FROM [$(DbName)].sys.extended_properties WHERE class = 0 AND name = N''P3_Disposable'';',
        N'@m nvarchar(200) OUTPUT', @m = @marker OUTPUT;
    IF @marker IS NULL
        THROW 51011, N'Refusing to drop: $(DbName) exists but has no P3_Disposable marker (unknown data). Inspect it manually.', 1;
    ALTER DATABASE [$(DbName)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$(DbName)];
    PRINT 'Dropped previous disposable database $(DbName) (marker: ' + @marker + ')';
END
GO

CREATE DATABASE [$(DbName)];
GO
ALTER DATABASE [$(DbName)] SET RECOVERY SIMPLE;
ALTER DATABASE [$(DbName)] SET COMPATIBILITY_LEVEL = 160;
GO
USE [$(DbName)];
GO
EXEC sys.sp_addextendedproperty @name = N'P3_Disposable', @value = N'WO-P3-P1-01 isolated test database; safe to drop and rebuild from scripts';
PRINT 'Created $(DbName) (compatibility level 160, SIMPLE recovery, P3_Disposable marker)';
GO

:r tests/db/fixtures/F001__TEST_ONLY_shared_dependency_keys.sql
:r db/migrations/V001__p3_billing_and_spending_tables.sql
:r db/migrations/V002__p3_settlement_and_spending_constraints.sql

PRINT 'BUILD_RESULT: OK ($(DbName))';
GO
