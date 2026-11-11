/* =====================================================================
   preflight_p2.sql - TEST_ONLY, READ-ONLY (sqlcmd mode)
   Work order : WO-P3-P2-01 (step 1). Creates, alters and drops nothing.
   Verifies the SQL Server instance identity and inspects the P2 target database
   (existence, disposable marker, ownership) before it is created or rebuilt.
     sqlcmd -S localhost -E -I -b -W -v LocalComputer="%COMPUTERNAME%" TargetDb=FitLife_P3_P2 -i tests/db/build/preflight_p2.sql
   The machine name and owner logins are not printed.
   ===================================================================== */
:on error exit
SET NOCOUNT ON;

PRINT '== 1. Engine, edition, instance ==';
SELECT
    CONVERT(nvarchar(128), SERVERPROPERTY('ProductVersion'))      AS product_version,
    CONVERT(nvarchar(128), SERVERPROPERTY('ProductLevel'))        AS product_level,
    CONVERT(nvarchar(128), SERVERPROPERTY('Edition'))             AS edition,
    CONVERT(int,           SERVERPROPERTY('EngineEdition'))       AS engine_edition,
    CONVERT(nvarchar(128), SERVERPROPERTY('Collation'))           AS server_collation,
    ISNULL(CONVERT(nvarchar(128), SERVERPROPERTY('InstanceName')), N'(default instance)') AS instance_name;

PRINT '== 2. Local development instance and permissions ==';
SELECT
    c.net_transport,
    CASE WHEN UPPER(CONVERT(nvarchar(128), SERVERPROPERTY('MachineName'))) = UPPER(N'$(LocalComputer)') THEN 1 ELSE 0 END AS machine_is_local_computer,
    CASE WHEN CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) LIKE N'%Developer%' THEN 1 ELSE 0 END AS is_developer_edition,
    CASE WHEN CONVERT(int, SERVERPROPERTY('ProductMajorVersion')) >= 16 THEN 1 ELSE 0 END AS supports_level_160,
    IS_SRVROLEMEMBER(N'sysadmin') AS is_sysadmin,
    HAS_PERMS_BY_NAME(NULL, NULL, N'CREATE ANY DATABASE') AS can_create_database
FROM sys.dm_exec_connections AS c
WHERE c.session_id = @@SPID;

PRINT '== 3. Target database $(TargetDb) ==';
DECLARE @marker nvarchar(200) = NULL;
IF DB_ID(N'$(TargetDb)') IS NOT NULL
    EXEC sys.sp_executesql
        N'SELECT @m = CONVERT(nvarchar(200), value) FROM [$(TargetDb)].sys.extended_properties WHERE class = 0 AND name = N''P3_Disposable'';',
        N'@m nvarchar(200) OUTPUT', @m = @marker OUTPUT;
SELECT N'$(TargetDb)' AS target,
       CASE WHEN DB_ID(N'$(TargetDb)') IS NULL THEN N'does not exist' ELSE N'EXISTS' END AS target_state,
       ISNULL(@marker, N'(none)') AS disposable_marker,
       (SELECT CASE WHEN owner_sid = SUSER_SID() THEN 1 ELSE 0 END FROM sys.databases WHERE name = N'$(TargetDb)') AS owner_is_current_login;

PRINT '== 4. Verdict ==';
DECLARE @fail nvarchar(400) = N'';
IF N'$(TargetDb)' NOT LIKE N'FitLife[_]P3[_]%' SET @fail += N'target name must match FitLife_P3_%; ';
IF N'$(TargetDb)' = N'FitLife_P3_P1' SET @fail += N'FitLife_P3_P1 must not be altered; ';
IF CONVERT(int, SERVERPROPERTY('ProductMajorVersion')) < 16 SET @fail += N'compatibility level 160 not supported; ';
IF CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) NOT LIKE N'%Developer%' SET @fail += N'not a Developer edition; ';
IF UPPER(CONVERT(nvarchar(128), SERVERPROPERTY('MachineName'))) <> UPPER(N'$(LocalComputer)') SET @fail += N'instance is not on the local computer; ';
IF HAS_PERMS_BY_NAME(NULL, NULL, N'CREATE ANY DATABASE') <> 1 SET @fail += N'no CREATE DATABASE permission; ';
IF DB_ID(N'$(TargetDb)') IS NOT NULL AND (@marker IS NULL OR @marker NOT LIKE N'WO-P3-P2-01%')
    SET @fail += N'target exists without the WO-P3-P2-01 disposable marker (unknown data, never dropped); ';
IF @fail = N''
    PRINT 'PREFLIGHT_P2_RESULT: PASS';
ELSE
BEGIN
    PRINT 'PREFLIGHT_P2_RESULT: FAIL - ' + @fail;
    THROW 51000, N'Preflight failed; see the verdict above.', 1;
END
GO
