/* =====================================================================
   drop_p2_db.sql - TEST_ONLY harness (sqlcmd mode); rollback for WO-P3-P2-01
   Drops FitLife_P3_P2 ONLY if it carries the disposable marker written by
   rebuild_p2_db.sql (starts with "WO-P3-P2-01"). Never touches FitLife_P3_P1.
   Run: sqlcmd -S localhost -E -I -b -i tests/db/build/drop_p2_db.sql
   ===================================================================== */
:on error exit
:setvar DbName FitLife_P3_P2
SET NOCOUNT ON;

IF N'$(DbName)' NOT LIKE N'FitLife[_]P3[_]%' OR N'$(DbName)' = N'FitLife_P3_P1'
    THROW 51010, N'Refusing to run: target must match FitLife_P3_% and must not be FitLife_P3_P1.', 1;
GO
DECLARE @marker nvarchar(200) = NULL;
IF DB_ID(N'$(DbName)') IS NULL
    PRINT 'Nothing to drop: $(DbName) does not exist.';
ELSE
BEGIN
    EXEC sys.sp_executesql
        N'SELECT @m = CONVERT(nvarchar(200), value) FROM [$(DbName)].sys.extended_properties WHERE class = 0 AND name = N''P3_Disposable'';',
        N'@m nvarchar(200) OUTPUT', @m = @marker OUTPUT;
    IF @marker IS NULL OR @marker NOT LIKE N'WO-P3-P2-01%'
        THROW 51011, N'Refusing to drop: $(DbName) has no WO-P3-P2-01 disposable marker (unknown data).', 1;
    ALTER DATABASE [$(DbName)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$(DbName)];
    PRINT 'Dropped disposable database $(DbName).';
END
GO
