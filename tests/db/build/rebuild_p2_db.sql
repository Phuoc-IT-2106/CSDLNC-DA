/* =====================================================================
   rebuild_p2_db.sql - TEST_ONLY harness (sqlcmd mode), not production
   Work order : WO-P3-P2-01
   Builds the isolated, disposable P2 dataset database FitLife_P3_P2 from nothing,
   with the same migration sequence as P1 (rebuild_isolated_db.sql is left unchanged
   because it is part of the P1 evidence):
     1. guard the name (FitLife_P3_%, never FitLife_P3_P1);
     2. if the database exists, drop it ONLY if its P3_Disposable marker was written
        by this script (starts with "WO-P3-P2-01"); otherwise stop;
     3. create it (SIMPLE recovery, compatibility level 160) and mark it disposable;
     4. apply F001 (TEST_ONLY key-only fixtures), V001, V002 (P3_OWNED).
   Run from the repository root:
     sqlcmd -S localhost -E -I -b -i tests/db/build/rebuild_p2_db.sql
   ===================================================================== */
:on error exit
:setvar DbName FitLife_P3_P2
SET NOCOUNT ON;

IF N'$(DbName)' NOT LIKE N'FitLife[_]P3[_]%' OR N'$(DbName)' = N'FitLife_P3_P1'
    THROW 51010, N'Refusing to run: target must match FitLife_P3_% and must not be FitLife_P3_P1.', 1;
IF CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) NOT LIKE N'%Developer%'
    THROW 51013, N'Refusing to run: not a Developer-edition (local development) instance.', 1;
GO

DECLARE @marker nvarchar(200) = NULL;
IF DB_ID(N'$(DbName)') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql
        N'SELECT @m = CONVERT(nvarchar(200), value) FROM [$(DbName)].sys.extended_properties WHERE class = 0 AND name = N''P3_Disposable'';',
        N'@m nvarchar(200) OUTPUT', @m = @marker OUTPUT;
    IF @marker IS NULL OR @marker NOT LIKE N'WO-P3-P2-01%'
        THROW 51011, N'Refusing to drop: $(DbName) exists without the WO-P3-P2-01 disposable marker (unknown data). Inspect it manually.', 1;
    ALTER DATABASE [$(DbName)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$(DbName)];
    PRINT 'Dropped previous disposable database $(DbName)';
END
GO

CREATE DATABASE [$(DbName)];
GO
ALTER DATABASE [$(DbName)] SET RECOVERY SIMPLE;
ALTER DATABASE [$(DbName)] SET COMPATIBILITY_LEVEL = 160;
GO
USE [$(DbName)];
GO
EXEC sys.sp_addextendedproperty @name = N'P3_Disposable', @value = N'WO-P3-P2-01 isolated dataset database; safe to drop and rebuild from scripts';
PRINT 'Created $(DbName) (compatibility level 160, SIMPLE recovery, P3_Disposable marker)';
GO

:r tests/db/fixtures/F001__TEST_ONLY_shared_dependency_keys.sql
:r db/migrations/V001__p3_billing_and_spending_tables.sql
:r db/migrations/V002__p3_settlement_and_spending_constraints.sql

PRINT 'BUILD_RESULT: OK ($(DbName))';
GO
