/* =====================================================================
   preflight_p1.sql — TEST_ONLY, READ-ONLY
   WO-P3-P1-01 step 1 (SQL Server preflight required by D-002).
   Creates, alters and drops nothing. Run from the repository root:
     sqlcmd -S localhost -E -I -b -W -v LocalComputer="%COMPUTERNAME%" -i tests/db/build/preflight_p1.sql
   The machine name is not printed (it may contain a personal name);
   only whether it equals the local computer name.
   ===================================================================== */
:on error exit
SET NOCOUNT ON;

PRINT '== 1. Engine, edition, instance ==';
SELECT
    CONVERT(nvarchar(128), SERVERPROPERTY('ProductVersion'))      AS product_version,
    CONVERT(int,           SERVERPROPERTY('ProductMajorVersion')) AS product_major_version,
    CONVERT(nvarchar(128), SERVERPROPERTY('ProductLevel'))        AS product_level,
    CONVERT(nvarchar(128), SERVERPROPERTY('Edition'))             AS edition,
    CONVERT(int,           SERVERPROPERTY('EngineEdition'))       AS engine_edition,
    CONVERT(nvarchar(128), SERVERPROPERTY('Collation'))           AS server_collation,
    ISNULL(CONVERT(nvarchar(128), SERVERPROPERTY('InstanceName')), N'(default instance)') AS instance_name,
    CONVERT(int,           SERVERPROPERTY('IsClustered'))         AS is_clustered,
    CONVERT(int,           SERVERPROPERTY('IsHadrEnabled'))       AS is_hadr_enabled;
SELECT @@VERSION AS at_at_version;

PRINT '== 2. Local development instance ==';
SELECT
    c.net_transport,
    CASE WHEN UPPER(CONVERT(nvarchar(128), SERVERPROPERTY('MachineName'))) = UPPER(N'$(LocalComputer)') THEN 1 ELSE 0 END AS machine_is_local_computer,
    CASE WHEN CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) LIKE N'%Developer%' THEN 1 ELSE 0 END AS is_developer_edition
FROM sys.dm_exec_connections AS c
WHERE c.session_id = @@SPID;

PRINT '== 3. Compatibility level support ==';
SELECT
    CONVERT(int, SERVERPROPERTY('ProductMajorVersion')) * 10 AS max_supported_compatibility_level,
    CASE WHEN CONVERT(int, SERVERPROPERTY('ProductMajorVersion')) >= 16 THEN 1 ELSE 0 END AS supports_level_160,
    (SELECT compatibility_level FROM sys.databases WHERE name = N'model') AS model_compatibility_level;

PRINT '== 4. Permissions of the current login ==';
SELECT
    IS_SRVROLEMEMBER(N'sysadmin') AS is_sysadmin,
    HAS_PERMS_BY_NAME(NULL, NULL, N'CREATE ANY DATABASE') AS can_create_database;

PRINT '== 5. Time (storage is UTC, D-014) ==';
SELECT
    SYSUTCDATETIME()   AS sys_utc_datetime,
    SYSDATETIMEOFFSET() AS sys_datetime_offset,
    DATEPART(TZOFFSET, SYSDATETIMEOFFSET()) AS host_offset_minutes;

PRINT '== 6. Session SET options (sqlcmd -I) ==';
SELECT
    SESSIONPROPERTY('QUOTED_IDENTIFIER') AS quoted_identifier,
    SESSIONPROPERTY('ANSI_NULLS')        AS ansi_nulls,
    SESSIONPROPERTY('ANSI_PADDING')      AS ansi_padding,
    SESSIONPROPERTY('ANSI_WARNINGS')     AS ansi_warnings,
    SESSIONPROPERTY('ARITHABORT')        AS arithabort,
    SESSIONPROPERTY('CONCAT_NULL_YIELDS_NULL') AS concat_null_yields_null,
    SESSIONPROPERTY('NUMERIC_ROUNDABORT') AS numeric_roundabort;

PRINT '== 7. Databases on the instance (names only; nothing is opened) ==';
SELECT name, database_id, compatibility_level, state_desc, recovery_model_desc
FROM sys.databases
ORDER BY database_id;

PRINT '== 8. Target database FitLife_P3_P1 ==';
DECLARE @marker nvarchar(200) = NULL;
IF DB_ID(N'FitLife_P3_P1') IS NOT NULL
    EXEC sys.sp_executesql
        N'SELECT @m = CONVERT(nvarchar(200), value) FROM [FitLife_P3_P1].sys.extended_properties WHERE class = 0 AND name = N''P3_Disposable'';',
        N'@m nvarchar(200) OUTPUT', @m = @marker OUTPUT;
SELECT N'FitLife_P3_P1' AS target,
       CASE WHEN DB_ID(N'FitLife_P3_P1') IS NULL THEN N'does not exist' ELSE N'EXISTS' END AS target_state,
       ISNULL(@marker, N'(none)') AS disposable_marker;

PRINT '== 9. Verdict ==';
DECLARE @fail nvarchar(400) = N'';
IF CONVERT(int, SERVERPROPERTY('ProductMajorVersion')) < 16 SET @fail += N'compatibility level 160 not supported; ';
IF CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) NOT LIKE N'%Developer%' SET @fail += N'not a Developer edition; ';
IF UPPER(CONVERT(nvarchar(128), SERVERPROPERTY('MachineName'))) <> UPPER(N'$(LocalComputer)') SET @fail += N'instance is not on the local computer; ';
IF HAS_PERMS_BY_NAME(NULL, NULL, N'CREATE ANY DATABASE') <> 1 SET @fail += N'no CREATE DATABASE permission; ';
IF DB_ID(N'FitLife_P3_P1') IS NOT NULL AND @marker IS NULL
    SET @fail += N'FitLife_P3_P1 exists without the P3 disposable marker; ';
IF @fail = N''
    PRINT 'PREFLIGHT_RESULT: PASS';
ELSE
BEGIN
    PRINT 'PREFLIGHT_RESULT: FAIL — ' + @fail;
    THROW 51000, N'Preflight failed; see the verdict above.', 1;
END
