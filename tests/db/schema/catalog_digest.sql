/* =====================================================================
   catalog_digest.sql - TEST_ONLY (sqlcmd mode), read-only
   Work order : WO-P3-P4-01 Part F (criterion F3).
   Prints ONE line: a SHA-256 over the complete table catalog of the current database - every column
   (name, type, length, precision, scale, nullability, identity, collation), every constraint with its
   definition and trust state, every foreign key, every index (keys, included columns, filter, type) and
   every trigger. Routines, functions, statistics and data are not part of the digest.
   The runner calls it before the report routines are deployed and after all tests: the two lines must be
   identical ("the report work changed no table, constraint or index").
   Run: sqlcmd -S localhost -E -I -b -W -d <db> -i tests/db/schema/catalog_digest.sql
   ===================================================================== */
:on error exit
SET NOCOUNT ON;

IF DB_NAME() NOT LIKE N'FitLife[_]P3[_]%' THROW 51460, N'catalog_digest runs only in a FitLife_P3_% database.', 1;

DECLARE @items TABLE (item nvarchar(1000) COLLATE Latin1_General_BIN2 NOT NULL);
INSERT @items (item)
SELECT x FROM (
    SELECT CONCAT(N'COL|', t.name, N'|', c.column_id, N'|', c.name, N'|', ty.name, N'|', c.max_length, N'|', c.precision, N'|', c.scale, N'|', c.is_nullable, N'|', c.is_identity, N'|', ISNULL(c.collation_name, N'-')) AS x
    FROM sys.tables AS t JOIN sys.columns AS c ON c.object_id = t.object_id JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id WHERE t.is_ms_shipped = 0
    UNION ALL SELECT CONCAT(N'OBJ|', o.type, N'|', o.name, N'|', t.name) FROM sys.objects AS o JOIN sys.tables AS t ON t.object_id = o.parent_object_id WHERE o.is_ms_shipped = 0
    UNION ALL SELECT CONCAT(N'CHK|', cc.name, N'|', cc.definition, N'|', cc.is_disabled, N'|', cc.is_not_trusted) FROM sys.check_constraints AS cc
    UNION ALL SELECT CONCAT(N'DEF|', dc.name, N'|', dc.definition) FROM sys.default_constraints AS dc
    UNION ALL SELECT CONCAT(N'FK|', fk.name, N'|', COL_NAME(fkc.parent_object_id, fkc.parent_column_id), N'->', OBJECT_NAME(fk.referenced_object_id), N'.', COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id),
                            N'|', fk.delete_referential_action, N'|', fk.update_referential_action, N'|', fk.is_disabled, N'|', fk.is_not_trusted)
              FROM sys.foreign_keys AS fk JOIN sys.foreign_key_columns AS fkc ON fkc.constraint_object_id = fk.object_id
    UNION ALL SELECT CONCAT(N'IDX|', t.name, N'|', ISNULL(i.name, N'(heap)'), N'|', i.type, N'|', i.is_unique, N'|', i.is_primary_key, N'|', ISNULL(i.filter_definition, N'-'), N'|',
                            (SELECT STRING_AGG(CONVERT(nvarchar(400), CONCAT(c.name, N':', ic.key_ordinal, N':', ic.is_descending_key, N':', ic.is_included_column)), N',') WITHIN GROUP (ORDER BY ic.key_ordinal, c.name)
                             FROM sys.index_columns AS ic JOIN sys.columns AS c ON c.object_id = ic.object_id AND c.column_id = ic.column_id WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id))
              FROM sys.indexes AS i JOIN sys.tables AS t ON t.object_id = i.object_id WHERE t.is_ms_shipped = 0
    UNION ALL SELECT CONCAT(N'TRG|', tr.name, N'|', OBJECT_NAME(tr.parent_id), N'|', tr.is_disabled) FROM sys.triggers AS tr
) AS q;

DECLARE @s nvarchar(max) = (SELECT STRING_AGG(CONVERT(nvarchar(max), item), N'~') WITHIN GROUP (ORDER BY item) FROM @items);
DECLARE @nItems int = (SELECT COUNT(*) FROM @items),
        @nTables int = (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0),
        @nIdx int = (SELECT COUNT(*) FROM sys.indexes AS i JOIN sys.tables AS t ON t.object_id = i.object_id WHERE t.is_ms_shipped = 0 AND i.type > 0 AND i.is_primary_key = 0),
        @nViews int = (SELECT COUNT(*) FROM sys.views WHERE is_ms_shipped = 0),
        @nTrg int = (SELECT COUNT(*) FROM sys.triggers),
        @nPart int = (SELECT COUNT(*) FROM sys.partition_functions) + (SELECT COUNT(*) FROM sys.partition_schemes);
PRINT CONCAT('CATALOG_DIGEST|', CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @s)), 2), '|items=', @nItems, '|tables=', @nTables,
             '|non_pk_indexes=', @nIdx, '|views=', @nViews, '|triggers=', @nTrg, '|partition_objects=', @nPart);
GO
