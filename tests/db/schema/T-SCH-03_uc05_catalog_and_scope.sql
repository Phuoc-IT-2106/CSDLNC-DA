/* =====================================================================
   T-SCH-03_uc05_catalog_and_scope.sql - TEST_ONLY (sqlcmd mode), read-only
   Work order : WO-P3-P3-00 (acceptance criterion 4; P1 schema regression after the routine)
   Run in FitLife_P3_UC05 after db/procedures/usp_P3_CreateInvoice.sql is applied.
     K1  Table catalog identical to the accepted P1 database FitLife_P3_P1 (read-only
         cross-database catalog query): columns, constraints with definitions and trust,
         foreign keys with actions, indexes, triggers, table classification markers.
     K2  Object inventory: besides the P1 tables and their constraints, exactly one
         procedure (usp_P3_CreateInvoice) and two table types; no view, function,
         trigger, sequence, synonym, non-PK index, partition function or scheme.
     K3  Table types have exactly the specified columns.
     K4  Write scope of the routine (sys.dm_sql_referenced_entities): it modifies only
         INVOICE, INVOICE_SERVICE_ITEM and INVOICE_PRODUCT_ITEM; it does not reference
         MEMBER_MONTHLY_SPENDING or any table outside the P3 interface; it reads shared
         tables by key column only; no cross-database or remote reference.
     K5  No dynamic SQL or nested procedure call in the routine body (so K4 is complete).
     K6  No database principal or explicit permission created beyond the defaults.
   Run from the repository root:
     sqlcmd -S localhost -E -I -b -W -d FitLife_P3_UC05 -i tests/db/schema/T-SCH-03_uc05_catalog_and_scope.sql
   ===================================================================== */
:on error exit
SET NOCOUNT ON;

IF DB_NAME() <> N'FitLife_P3_UC05'
    THROW 51130, N'T-SCH-03 runs only in FitLife_P3_UC05.', 1;
IF DB_ID(N'FitLife_P3_P1') IS NULL
    THROW 51131, N'T-SCH-03 needs the accepted P1 database FitLife_P3_P1 as the catalog reference (read-only).', 1;

DECLARE @checks TABLE (seq int IDENTITY(1,1), check_id varchar(4), result varchar(4), descr nvarchar(300), detail nvarchar(4000));
DECLARE @d nvarchar(4000), @n1 int, @n2 int;

/* ---------- K1 catalog of the tables vs FitLife_P3_P1 ---------- */
CREATE TABLE #cat (db varchar(4) NOT NULL, item nvarchar(1000) NOT NULL);
DECLARE @q nvarchar(max) = N'
INSERT #cat (db, item)
SELECT @db, x FROM (
  SELECT CONCAT(N''COL|'', t.name, N''|'', c.column_id, N''|'', c.name, N''|'', ty.name, N''|'', c.max_length, N''|'', c.precision, N''|'', c.scale,
                N''|'', c.is_nullable, N''|'', c.is_identity, N''|'', ISNULL(c.collation_name, N''-'')) AS x
  FROM sys.tables AS t JOIN sys.columns AS c ON c.object_id = t.object_id JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
  WHERE t.is_ms_shipped = 0
  UNION ALL
  SELECT CONCAT(N''OBJ|'', o.type, N''|'', o.name, N''|'', t.name)
  FROM sys.objects AS o JOIN sys.tables AS t ON t.object_id = o.parent_object_id WHERE o.is_ms_shipped = 0
  UNION ALL
  SELECT CONCAT(N''CHK|'', cc.name, N''|'', cc.definition, N''|'', cc.is_disabled, N''|'', cc.is_not_trusted) FROM sys.check_constraints AS cc
  UNION ALL
  SELECT CONCAT(N''DEF|'', dc.name, N''|'', dc.definition) FROM sys.default_constraints AS dc
  UNION ALL
  SELECT CONCAT(N''FK|'', fk.name, N''|'', COL_NAME(fkc.parent_object_id, fkc.parent_column_id), N''->'', OBJECT_NAME(fk.referenced_object_id), N''.'',
                COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id), N''|'', fk.delete_referential_action, N''|'', fk.update_referential_action,
                N''|'', fk.is_disabled, N''|'', fk.is_not_trusted)
  FROM sys.foreign_keys AS fk JOIN sys.foreign_key_columns AS fkc ON fkc.constraint_object_id = fk.object_id
  UNION ALL
  SELECT CONCAT(N''IDX|'', t.name, N''|'', i.name, N''|'', i.type, N''|'', i.is_unique, N''|'', i.is_primary_key, N''|'', ISNULL(i.filter_definition, N''-''), N''|'',
                (SELECT STRING_AGG(CONVERT(nvarchar(400), CONCAT(c.name, N'':'', ic.key_ordinal, N'':'', ic.is_descending_key, N'':'', ic.is_included_column)), N'','')
                        WITHIN GROUP (ORDER BY ic.key_ordinal, c.name)
                 FROM sys.index_columns AS ic JOIN sys.columns AS c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                 WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id))
  FROM sys.indexes AS i JOIN sys.tables AS t ON t.object_id = i.object_id WHERE t.is_ms_shipped = 0
  UNION ALL
  SELECT CONCAT(N''EP|'', t.name, N''|'', ep.minor_id, N''|'', ep.name, N''|'', CONVERT(nvarchar(400), ep.value))
  FROM sys.extended_properties AS ep JOIN sys.tables AS t ON t.object_id = ep.major_id WHERE ep.class = 1
) AS q;';
EXEC FitLife_P3_P1.sys.sp_executesql @q, N'@db varchar(4)', @db = 'P1';
EXEC sys.sp_executesql @q, N'@db varchar(4)', @db = 'UC05';
SELECT @n1 = SUM(CASE WHEN db = 'P1' THEN 1 ELSE 0 END), @n2 = SUM(CASE WHEN db = 'UC05' THEN 1 ELSE 0 END) FROM #cat;
SELECT @d = STRING_AGG(CONVERT(nvarchar(4000), CONCAT(COALESCE(a.item, b.item), CASE WHEN a.item IS NULL THEN N' [only in FitLife_P3_P1]' ELSE N' [only in FitLife_P3_UC05]' END)), N'; ')
FROM (SELECT item FROM #cat WHERE db = 'UC05') AS a FULL OUTER JOIN (SELECT item FROM #cat WHERE db = 'P1') AS b ON b.item = a.item
WHERE a.item IS NULL OR b.item IS NULL;
INSERT @checks VALUES ('K1', CASE WHEN @d IS NULL AND @n1 = @n2 AND @n1 > 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Table catalog (9 tables: columns, constraints and definitions, FKs, indexes, triggers, markers) identical to the accepted P1 database FitLife_P3_P1',
    ISNULL(@d, CONCAT(N'catalog items: FitLife_P3_P1 ', @n1, N' = FitLife_P3_UC05 ', @n2, N'; no difference')));

/* ---------- K2 object inventory ---------- */
SET @d = NULL;
SELECT @d = STRING_AGG(CONVERT(nvarchar(4000), CONCAT(o.type_desc COLLATE DATABASE_DEFAULT, N' ', o.name)), N'; ')
FROM sys.objects AS o
WHERE o.is_ms_shipped = 0 AND o.type NOT IN ('U', 'PK', 'F', 'C', 'D')
  AND NOT (o.type = 'P' AND o.name = N'usp_P3_CreateInvoice')
  AND NOT (o.type = 'TT' AND o.object_id IN (SELECT type_table_object_id FROM sys.table_types WHERE name IN (N'tt_P3_InvoiceServiceLine', N'tt_P3_InvoiceProductLine')));
DECLARE @procs int = (SELECT COUNT(*) FROM sys.procedures WHERE is_ms_shipped = 0),
        @tts int = (SELECT COUNT(*) FROM sys.table_types WHERE is_user_defined = 1),
        @ttOk int = (SELECT COUNT(*) FROM sys.table_types WHERE name IN (N'tt_P3_InvoiceServiceLine', N'tt_P3_InvoiceProductLine') AND schema_id = SCHEMA_ID(N'dbo')),
        @udt int = (SELECT COUNT(*) FROM sys.types WHERE is_user_defined = 1 AND is_table_type = 0),
        @trg int = (SELECT COUNT(*) FROM sys.triggers),
        @nonpk int = (SELECT COUNT(*) FROM sys.indexes AS i JOIN sys.tables AS t ON t.object_id = i.object_id WHERE t.is_ms_shipped = 0 AND i.type > 0 AND i.is_primary_key = 0),
        @parts int = (SELECT COUNT(*) FROM sys.partition_functions) + (SELECT COUNT(*) FROM sys.partition_schemes),
        @tables int = (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0);
INSERT @checks VALUES ('K2', CASE WHEN @d IS NULL AND @procs = 1 AND @tts = 2 AND @ttOk = 2 AND @udt = 0 AND @trg = 0 AND @nonpk = 0 AND @parts = 0 AND @tables = 9 THEN 'PASS' ELSE 'FAIL' END,
    N'Inventory: 9 tables; plus exactly 1 procedure (usp_P3_CreateInvoice) and 2 table types; no view, function, trigger, sequence, synonym, other type, non-PK index, partition function or scheme',
    CONCAT(N'unexpected objects: ', ISNULL(@d, N'none'), N'; procedures=', @procs, N'; table types=', @tts, N' (expected names ', @ttOk, N'/2); other user types=', @udt,
           N'; triggers=', @trg, N'; non-PK indexes on tables=', @nonpk, N'; partition functions+schemes=', @parts, N'; user tables=', @tables));

/* ---------- K3 table type definitions ---------- */
DECLARE @svcDef nvarchar(400), @prdDef nvarchar(400);
SELECT @svcDef = STRING_AGG(CONVERT(nvarchar(400), CONCAT(c.column_id, ':', c.name, ':', ty.name, ':', c.precision, ':', c.scale, ':', c.is_nullable)), '|') WITHIN GROUP (ORDER BY c.column_id)
FROM sys.table_types AS tt JOIN sys.columns AS c ON c.object_id = tt.type_table_object_id JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
WHERE tt.name = N'tt_P3_InvoiceServiceLine';
SELECT @prdDef = STRING_AGG(CONVERT(nvarchar(400), CONCAT(c.column_id, ':', c.name, ':', ty.name, ':', c.precision, ':', c.scale, ':', c.is_nullable)), '|') WITHIN GROUP (ORDER BY c.column_id)
FROM sys.table_types AS tt JOIN sys.columns AS c ON c.object_id = tt.type_table_object_id JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
WHERE tt.name = N'tt_P3_InvoiceProductLine';
DECLARE @ttPk int = (SELECT COUNT(*) FROM sys.key_constraints AS kc JOIN sys.table_types AS tt ON tt.type_table_object_id = kc.parent_object_id WHERE kc.type = 'PK');
INSERT @checks VALUES ('K3', CASE WHEN @svcDef = N'1:LineNo:smallint:5:0:0|2:Plan_ID:int:10:0:0|3:UnitPrice:decimal:18:2:0|4:DiscountAmount:decimal:18:2:0'
                                  AND @prdDef = N'1:LineNo:smallint:5:0:0|2:Product_ID:int:10:0:0|3:Quantity:int:10:0:0|4:UnitPrice:decimal:18:2:0|5:DiscountAmount:decimal:18:2:0'
                                  AND @ttPk = 2 THEN 'PASS' ELSE 'FAIL' END,
    N'Line types: columns as specified (all NOT NULL, money DECIMAL(18,2)), primary key on LineNo in each',
    CONCAT(N'service: ', ISNULL(@svcDef, N'(missing)'), N' || product: ', ISNULL(@prdDef, N'(missing)'), N' || type primary keys: ', @ttPk));

/* ---------- K4 write scope (dependency analysis) ---------- */
DECLARE @dep TABLE (cls nvarchar(60), db sysname NULL, srv sysname NULL, ent sysname, minor sysname NULL, sel bit, upd bit);
INSERT @dep
SELECT referenced_class_desc, referenced_database_name, referenced_server_name, referenced_entity_name, referenced_minor_name, is_selected, is_updated
FROM sys.dm_sql_referenced_entities(N'dbo.usp_P3_CreateInvoice', N'OBJECT');
DECLARE @refs nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), ent), ',') WITHIN GROUP (ORDER BY ent) FROM @dep WHERE minor IS NULL);
DECLARE @mods nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), ent), ',') WITHIN GROUP (ORDER BY ent) FROM (SELECT DISTINCT ent FROM @dep WHERE upd = 1) AS x);
DECLARE @sharedCols nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), CONCAT(ent, '.', minor)), ',') WITHIN GROUP (ORDER BY ent, minor)
                                      FROM @dep WHERE ent IN (N'MEMBER', N'EMPLOYEE', N'BRANCH', N'SERVICE_PLAN', N'PRODUCT') AND minor IS NOT NULL);
DECLARE @remote int = (SELECT COUNT(*) FROM @dep WHERE db IS NOT NULL OR srv IS NOT NULL);
DECLARE @entCols nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), minor), ',') WITHIN GROUP (ORDER BY minor)
                                   FROM @dep WHERE ent = N'INVOICE_SERVICE_ITEM' AND minor IN (N'ValidFrom', N'ValidUntil', N'PTSessionsRemaining') AND upd = 1);
INSERT @checks VALUES ('K4', CASE WHEN @refs = N'BRANCH,EMPLOYEE,INVOICE,INVOICE_PRODUCT_ITEM,INVOICE_SERVICE_ITEM,MEMBER,PRODUCT,SERVICE_PLAN,tt_P3_InvoiceProductLine,tt_P3_InvoiceServiceLine'
                                  AND @mods = N'INVOICE,INVOICE_PRODUCT_ITEM,INVOICE_SERVICE_ITEM'
                                  AND @sharedCols = N'BRANCH.Branch_ID,EMPLOYEE.Employee_ID,MEMBER.Member_ID,PRODUCT.Product_ID,SERVICE_PLAN.Plan_ID'
                                  AND @remote = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Write scope: modifies only the three invoice tables; no reference to MEMBER_MONTHLY_SPENDING, inventory, tier or any other table; shared tables read by key only; no cross-database reference',
    CONCAT(N'referenced: ', ISNULL(@refs, N'-'), N' || modified: ', ISNULL(@mods, N'-'), N' || shared columns read: ', ISNULL(@sharedCols, N'-'),
           N' || cross-database/remote references: ', @remote,
           N' || entitlement/PT columns in the insert column list: ', ISNULL(@entCols, N'-'), N' (inserted as literal NULL only; values checked by T-F05-24 and V-UC05 I7)'));

/* ---------- K5 no dynamic SQL or nested call ---------- */
DECLARE @def nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_P3_CreateInvoice'));
DECLARE @dyn int = CASE WHEN @def LIKE N'%EXEC%' OR @def LIKE N'%sp[_]executesql%' OR @def LIKE N'%OPENQUERY%' OR @def LIKE N'%OPENROWSET%' OR @def LIKE N'%OPENDATASOURCE%' THEN 1 ELSE 0 END;
INSERT @checks VALUES ('K5', CASE WHEN @def IS NOT NULL AND @dyn = 0 AND OBJECTPROPERTY(OBJECT_ID(N'dbo.usp_P3_CreateInvoice'), 'IsEncrypted') = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Routine body has no EXEC, sp_executesql, OPENQUERY, OPENROWSET or OPENDATASOURCE and is not encrypted, so the dependency analysis (K4) covers every statement',
    CONCAT(N'definition length=', LEN(@def), N'; dynamic/nested call tokens found=', @dyn, N'; SHA-256 of definition=', CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @def)), 2)));

/* ---------- K6 principals and permissions ---------- */
DECLARE @prin nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), name), ',') FROM sys.database_principals
                                WHERE principal_id > 4 AND is_fixed_role = 0 AND name NOT IN (N'public'));
DECLARE @perm int = (SELECT COUNT(*) FROM sys.database_permissions WHERE class IN (1, 6) AND grantee_principal_id > 4);
INSERT @checks VALUES ('K6', CASE WHEN @prin IS NULL AND @perm = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'No extra database user or role and no explicit object or type permission (the least-privilege role is TEST_ONLY, created and dropped by T-F05-26)',
    CONCAT(N'extra principals: ', ISNULL(@prin, N'none'), N'; explicit object/type permissions: ', @perm));

/* ---------- report ---------- */
SELECT check_id, result, descr, detail FROM @checks ORDER BY seq;
PRINT '-- routine dependencies (sys.dm_sql_referenced_entities) --';
SELECT cls, ent, ISNULL(minor, '-') AS minor, sel AS is_selected, upd AS is_updated FROM @dep ORDER BY ent, minor;
DROP TABLE #cat;

DECLARE @fails int = (SELECT COUNT(*) FROM @checks WHERE result = 'FAIL'), @nchecks int = (SELECT COUNT(*) FROM @checks);
PRINT CONCAT('T-SCH-03 SUMMARY: checks=', @nchecks, ' FAIL=', @fails);
IF @fails > 0 OR @nchecks <> 6
BEGIN
    PRINT 'T-SCH-03_RESULT: FAIL';
    THROW 51132, N'T-SCH-03 failed (see the check table).', 1;
END
ELSE
    PRINT 'T-SCH-03_RESULT: PASS';
GO
