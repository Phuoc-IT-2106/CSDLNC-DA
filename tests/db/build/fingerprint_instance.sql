/* =====================================================================
   fingerprint_instance.sql - TEST_ONLY, READ-ONLY (sqlcmd mode)
   Work order : WO-P3-P2-01
   Prints a deterministic fingerprint of every database on the instance except
   tempdb and the P2 target, plus a content fingerprint of FitLife_P3_P1.
   Run before and after a P2 run; the two outputs must be identical
   ("no unwanted changes to other databases"). Other user databases are not
   opened: only sys.databases and sys.master_files are read.
   Owner logins and machine names are not printed.
     sqlcmd -S localhost -E -I -b -W -s "|" -v TargetDb=FitLife_P3_P2 -i tests/db/build/fingerprint_instance.sql
   ===================================================================== */
:on error exit
SET NOCOUNT ON;

PRINT '== F1. Databases other than tempdb and $(TargetDb) ==';
SELECT d.name,
       d.database_id,
       CONVERT(varchar(23), d.create_date, 121)                AS create_date,
       d.compatibility_level,
       d.state_desc,
       d.recovery_model_desc,
       CASE WHEN d.owner_sid = SUSER_SID() THEN 1 ELSE 0 END  AS owner_is_current_login,
       (SELECT COUNT(*) FROM sys.master_files AS mf WHERE mf.database_id = d.database_id) AS file_count
FROM sys.databases AS d
WHERE d.name NOT IN (N'tempdb', N'$(TargetDb)')
ORDER BY d.database_id;

PRINT '== F2. FitLife_P3_P1 content fingerprint (must stay unchanged) ==';
IF DB_ID(N'FitLife_P3_P1') IS NULL
    PRINT 'FitLife_P3_P1: does not exist';
ELSE
    EXEC (N'
    SELECT N''FitLife_P3_P1'' AS db,
           (SELECT COUNT(*) FROM FitLife_P3_P1.sys.tables)                         AS user_tables,
           (SELECT COUNT(*) FROM FitLife_P3_P1.sys.objects WHERE is_ms_shipped = 0) AS user_objects,
           (SELECT SUM(p.rows) FROM FitLife_P3_P1.sys.partitions AS p
              JOIN FitLife_P3_P1.sys.tables AS t ON t.object_id = p.object_id
             WHERE p.index_id IN (0, 1))                                              AS total_rows,
           (SELECT CONVERT(varchar(23), MAX(modify_date), 121) FROM FitLife_P3_P1.sys.objects WHERE is_ms_shipped = 0) AS last_object_change,
           (SELECT CONVERT(nvarchar(200), value) FROM FitLife_P3_P1.sys.extended_properties
             WHERE class = 0 AND name = N''P3_Disposable'')                         AS disposable_marker;');
GO
