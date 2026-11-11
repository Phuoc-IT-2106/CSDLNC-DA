/* =====================================================================
   drop_isolated_db.sql — TEST_ONLY harness (sqlcmd mode); rollback for WO-P3-P1-01
   Drops the isolated test database ONLY if its name matches FitLife_P3_% and it
   carries the P3_Disposable marker written by rebuild_isolated_db.sql.
   Run: sqlcmd -S localhost -E -I -b -i tests/db/build/drop_isolated_db.sql
   ===================================================================== */
:on error exit
:setvar DbName FitLife_P3_P1
SET NOCOUNT ON;

IF N'$(DbName)' NOT LIKE N'FitLife[_]P3[_]%'
    THROW 51010, N'Refusing to run: target database name must match FitLife_P3_%.', 1;
GO
DECLARE @marker nvarchar(200) = NULL;
IF DB_ID(N'$(DbName)') IS NULL
    PRINT 'Nothing to drop: $(DbName) does not exist.';
ELSE
BEGIN
    EXEC sys.sp_executesql
        N'SELECT @m = CONVERT(nvarchar(200), value) FROM [$(DbName)].sys.extended_properties WHERE class = 0 AND name = N''P3_Disposable'';',
        N'@m nvarchar(200) OUTPUT', @m = @marker OUTPUT;
    IF @marker IS NULL
        THROW 51011, N'Refusing to drop: $(DbName) has no P3_Disposable marker (unknown data).', 1;
    ALTER DATABASE [$(DbName)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$(DbName)];
    PRINT 'Dropped disposable database $(DbName).';
END
GO
