/* =====================================================================
   rebuild_uc05l_db.sql - TEST_ONLY harness (sqlcmd mode), not production
   Work order : WO-P3-P3-02 (acceptance criterion 3 and task 0 on DS-L). Target approved by the Project
                Owner on 2026-11-09 (answer to the decision question of the session "Finalize UC05
                Settlement and Implement Loyalty": new disposable database FitLife_P3_UC05L).
   Builds the disposable DS-L loyalty copy FitLife_P3_UC05L with the SAME sequence as the accepted P2
   pipeline (rebuild_p2_db.sql stays unchanged, it is P2 evidence; FitLife_P3_P2 is never touched):
     1. guard: the name is exactly FitLife_P3_UC05L; Developer edition;
     2. if the database exists, drop it ONLY if its P3_Disposable marker was written by this script
        (starts with "WO-P3-P2-01" and contains "WO-P3-P3-02"); otherwise stop;
     3. create it (SIMPLE recovery, compatibility level 160) and mark it disposable. The marker starts
        with "WO-P3-P2-01" because the unchanged generator S001 and fixture F001D require that prefix;
     4. apply F001 (TEST_ONLY key-only fixtures), V001, V002 (P3_OWNED).
   The runner then loads F001D + S001 with the DS-L profile and checks the dataset checksum against the
   accepted run C reference before any loyalty object is added.
   Run from the repository root:
     sqlcmd -S localhost -E -I -b -i tests/db/build/rebuild_uc05l_db.sql
   ===================================================================== */
:on error exit
:setvar DbName FitLife_P3_UC05L
SET NOCOUNT ON;

IF N'$(DbName)' <> N'FitLife_P3_UC05L'
    THROW 51014, N'Refusing to run: this script builds only FitLife_P3_UC05L.', 1;
IF CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) NOT LIKE N'%Developer%'
    THROW 51013, N'Refusing to run: not a Developer-edition (local development) instance.', 1;
GO

DECLARE @marker nvarchar(200) = NULL;
IF DB_ID(N'$(DbName)') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql
        N'SELECT @m = CONVERT(nvarchar(200), value) FROM [$(DbName)].sys.extended_properties WHERE class = 0 AND name = N''P3_Disposable'';',
        N'@m nvarchar(200) OUTPUT', @m = @marker OUTPUT;
    IF @marker IS NULL OR @marker NOT LIKE N'WO-P3-P2-01%WO-P3-P3-02%'
        THROW 51015, N'Refusing to drop: $(DbName) exists without the WO-P3-P3-02 DS-L copy marker (unknown data). Inspect it manually.', 1;
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
EXEC sys.sp_addextendedproperty @name = N'P3_Disposable', @value = N'WO-P3-P2-01 dataset pipeline - WO-P3-P3-02 DS-L loyalty copy (FitLife_P3_UC05L); safe to drop and rebuild from scripts';
PRINT 'Created $(DbName) (compatibility level 160, SIMPLE recovery, P3_Disposable marker)';
GO

:r tests/db/fixtures/F001__TEST_ONLY_shared_dependency_keys.sql
:r db/migrations/V001__p3_billing_and_spending_tables.sql
:r db/migrations/V002__p3_settlement_and_spending_constraints.sql

PRINT 'BUILD_RESULT: OK ($(DbName))';
GO
