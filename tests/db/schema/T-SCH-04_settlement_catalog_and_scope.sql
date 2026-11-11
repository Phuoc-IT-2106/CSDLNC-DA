/* =====================================================================
   T-SCH-04_settlement_catalog_and_scope.sql - TEST_ONLY (sqlcmd mode), read-only
   Work order : WO-P3-P3-01. Run in FitLife_P3_UC05 after the settlement objects are deployed
   (F002P, D001 doubles, usp_P3_SettleInvoice, usp_P3_CancelInvoice).
     K1  Table catalog vs the accepted P1 database FitLife_P3_P1: identical, except exactly the
         F002P items on MEMBER (CurrentPoints column, its default, its TEST_ONLY marker) and the
         two TEST_ONLY double tables. The four P3 tables are unchanged (no migration, no index).
     K2  Object inventory: procedures {create, settle, cancel, 2 hook doubles}, function
         {tvf_P3_SpendingMonth}, 2 table types, 11 tables; no trigger, view, sequence, non-PK
         index, partition function or scheme; doubles and their tables marked TEST_ONLY_DOUBLE.
     K3  Settlement write scope (sys.dm_sql_referenced_entities): modifies only INVOICE,
         MEMBER_MONTHLY_SPENDING and MEMBER.CurrentPoints; reads the two line tables; calls only
         the two hooks and the month function; no tier, TEST_ object, cross-database reference.
     K4  Cancellation write scope: references and modifies INVOICE only.
     K5  No dynamic SQL: settle contains exactly the two static hook EXEC statements and no other
         EXEC, sp_executesql or OPEN*; cancel and the function contain none; definition hashes.
     K6  No database principal or explicit permission beyond the defaults.
     K7  INFO: no benchmark-only U0 variant exists (WO-P3-P3-01 task 2 blocked by D-007/D-008).
   Run: sqlcmd -S localhost -E -I -b -W -d FitLife_P3_UC05 -i tests/db/schema/T-SCH-04_settlement_catalog_and_scope.sql
   ===================================================================== */
:on error exit
SET NOCOUNT ON;

IF DB_NAME() <> N'FitLife_P3_UC05'
    THROW 51250, N'T-SCH-04 runs only in FitLife_P3_UC05.', 1;
IF DB_ID(N'FitLife_P3_P1') IS NULL
    THROW 51251, N'T-SCH-04 needs the accepted P1 database FitLife_P3_P1 as the catalog reference (read-only).', 1;

DECLARE @checks TABLE (seq int IDENTITY(1,1), check_id varchar(4), result varchar(4), descr nvarchar(300), detail nvarchar(4000));
DECLARE @d nvarchar(4000), @n1 int, @n2 int;

/* ---------- K1 catalog vs FitLife_P3_P1 ---------- */
CREATE TABLE #cat (db varchar(4) NOT NULL, item nvarchar(1000) COLLATE DATABASE_DEFAULT NOT NULL);
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

DECLARE @expectedExtra TABLE (item nvarchar(1000) NOT NULL);
INSERT @expectedExtra VALUES
    (N'COL|MEMBER|2|CurrentPoints|int|4|10|0|0|0|-'),
    (N'OBJ|D |DF_MEMBER_CurrentPoints|MEMBER'),
    (N'DEF|DF_MEMBER_CurrentPoints|((0))'),
    (N'EP|MEMBER|2|Classification|TEST_ONLY_FIXTURE (F002P points-only)');
DECLARE @onlyP1 nvarchar(4000), @onlyUc05Unexpected nvarchar(4000), @missingExtra nvarchar(4000), @testItems int;
SELECT @onlyP1 = STRING_AGG(CONVERT(nvarchar(4000), b.item), N'; ')
FROM (SELECT item FROM #cat WHERE db = 'P1') AS b WHERE NOT EXISTS (SELECT 1 FROM #cat AS a WHERE a.db = 'UC05' AND a.item = b.item);
SELECT @onlyUc05Unexpected = STRING_AGG(CONVERT(nvarchar(4000), a.item), N'; ')
FROM (SELECT item FROM #cat WHERE db = 'UC05') AS a
WHERE NOT EXISTS (SELECT 1 FROM #cat AS b WHERE b.db = 'P1' AND b.item = a.item)
  AND NOT EXISTS (SELECT 1 FROM @expectedExtra AS e WHERE e.item = a.item)
  AND a.item NOT LIKE N'%TEST[_]Hook%';
SELECT @missingExtra = STRING_AGG(CONVERT(nvarchar(4000), e.item), N'; ')
FROM @expectedExtra AS e WHERE NOT EXISTS (SELECT 1 FROM #cat AS a WHERE a.db = 'UC05' AND a.item = e.item);
SELECT @testItems = COUNT(*) FROM #cat WHERE db = 'UC05' AND item LIKE N'%TEST[_]Hook%';
SELECT @n1 = SUM(CASE WHEN db = 'P1' THEN 1 ELSE 0 END), @n2 = SUM(CASE WHEN db = 'UC05' THEN 1 ELSE 0 END) FROM #cat;
INSERT @checks VALUES ('K1', CASE WHEN @onlyP1 IS NULL AND @onlyUc05Unexpected IS NULL AND @missingExtra IS NULL AND @n1 > 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Table catalog = accepted P1 catalog (FitLife_P3_P1) plus exactly the F002P items on MEMBER and the TEST_ONLY double tables; the four P3 tables unchanged',
    CONCAT(N'items P1 ', @n1, N', UC05 ', @n2, N' (TEST_ONLY double items ', @testItems, N', F002P items 4); only in P1: ', ISNULL(@onlyP1, N'none'),
           N'; unexpected only in UC05: ', ISNULL(@onlyUc05Unexpected, N'none'), N'; missing F002P items: ', ISNULL(@missingExtra, N'none')));

/* ---------- K2 inventory ---------- */
DECLARE @procs nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), name), ',') WITHIN GROUP (ORDER BY name) FROM sys.procedures WHERE is_ms_shipped = 0);
DECLARE @funcs nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), CONCAT(type COLLATE DATABASE_DEFAULT, ':', name)), ',') WITHIN GROUP (ORDER BY name) FROM sys.objects WHERE is_ms_shipped = 0 AND type IN ('FN', 'IF', 'TF', 'FS', 'FT', 'AF'));
DECLARE @tts nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), name), ',') WITHIN GROUP (ORDER BY name) FROM sys.table_types WHERE is_user_defined = 1);
DECLARE @tbls nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), name), ',') WITHIN GROUP (ORDER BY name) FROM sys.tables WHERE is_ms_shipped = 0);
DECLARE @other int = (SELECT COUNT(*) FROM sys.objects WHERE is_ms_shipped = 0 AND type NOT IN ('U', 'PK', 'F', 'C', 'D', 'P', 'TT', 'IF'))
                   + (SELECT COUNT(*) FROM sys.triggers)
                   + (SELECT COUNT(*) FROM sys.indexes AS i JOIN sys.tables AS t ON t.object_id = i.object_id WHERE t.is_ms_shipped = 0 AND i.type > 0 AND i.is_primary_key = 0)
                   + (SELECT COUNT(*) FROM sys.partition_functions) + (SELECT COUNT(*) FROM sys.partition_schemes)
                   + (SELECT COUNT(*) FROM sys.types WHERE is_user_defined = 1 AND is_table_type = 0);
DECLARE @marked int = (SELECT COUNT(*) FROM sys.extended_properties AS ep
                       WHERE ep.class = 1 AND ep.minor_id = 0 AND ep.name = N'Classification' AND CONVERT(nvarchar(200), ep.value) = N'TEST_ONLY_DOUBLE'
                         AND ep.major_id IN (OBJECT_ID(N'dbo.TEST_HookCallLog'), OBJECT_ID(N'dbo.TEST_HookFault'),
                                             OBJECT_ID(N'dbo.usp_HOOK_InventoryDecrementForInvoice'), OBJECT_ID(N'dbo.usp_HOOK_EntitlementActivationForInvoice')));
INSERT @checks VALUES ('K2', CASE WHEN @procs = N'usp_HOOK_EntitlementActivationForInvoice,usp_HOOK_InventoryDecrementForInvoice,usp_P3_CancelInvoice,usp_P3_CreateInvoice,usp_P3_SettleInvoice'
                                  AND @funcs = N'IF:tvf_P3_SpendingMonth'
                                  AND @tts = N'tt_P3_InvoiceProductLine,tt_P3_InvoiceServiceLine'
                                  AND @tbls = N'BRANCH,EMPLOYEE,INVOICE,INVOICE_PRODUCT_ITEM,INVOICE_SERVICE_ITEM,MEMBER,MEMBER_MONTHLY_SPENDING,PRODUCT,SERVICE_PLAN,TEST_HookCallLog,TEST_HookFault'
                                  AND @other = 0 AND @marked = 4 THEN 'PASS' ELSE 'FAIL' END,
    N'Inventory: 3 P3 procedures + 2 TEST_ONLY hook doubles, 1 function, 2 table types, 9 tables + 2 TEST_ONLY tables; no trigger, view, sequence, non-PK index or partition object; doubles marked TEST_ONLY_DOUBLE',
    CONCAT(N'procedures: ', @procs, N' || functions: ', ISNULL(@funcs, N'-'), N' || table types: ', @tts, N' || tables: ', @tbls, N' || other objects: ', @other, N' || TEST_ONLY_DOUBLE markers: ', @marked, N'/4'));

/* ---------- K3 settlement write scope ---------- */
DECLARE @dep TABLE (ent sysname, minor sysname NULL, db sysname NULL, srv sysname NULL, sel bit, upd bit);
INSERT @dep SELECT referenced_entity_name, referenced_minor_name, referenced_database_name, referenced_server_name, is_selected, is_updated
FROM sys.dm_sql_referenced_entities(N'dbo.usp_P3_SettleInvoice', N'OBJECT');
DECLARE @refs nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), ent), ',') WITHIN GROUP (ORDER BY ent) FROM @dep WHERE minor IS NULL);
DECLARE @mods nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), ent), ',') WITHIN GROUP (ORDER BY ent) FROM (SELECT DISTINCT ent FROM @dep WHERE upd = 1) AS x);
DECLARE @memberCols nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), CONCAT(minor, CASE WHEN upd = 1 THEN ':w' ELSE ':r' END)), ',') WITHIN GROUP (ORDER BY minor)
                                      FROM @dep WHERE ent = N'MEMBER' AND minor IS NOT NULL);
DECLARE @lineWrites int = (SELECT COUNT(*) FROM @dep WHERE ent IN (N'INVOICE_SERVICE_ITEM', N'INVOICE_PRODUCT_ITEM') AND upd = 1);
DECLARE @remote int = (SELECT COUNT(*) FROM @dep WHERE db IS NOT NULL OR srv IS NOT NULL);
DECLARE @defS nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_P3_SettleInvoice'));
DECLARE @tierOrTest int = CASE WHEN @defS LIKE N'%Tier%' OR @defS LIKE N'%TEST[_]%' THEN 1 ELSE 0 END;
INSERT @checks VALUES ('K3', CASE WHEN @refs = N'INVOICE,INVOICE_PRODUCT_ITEM,INVOICE_SERVICE_ITEM,MEMBER,MEMBER_MONTHLY_SPENDING,tvf_P3_SpendingMonth,usp_HOOK_EntitlementActivationForInvoice,usp_HOOK_InventoryDecrementForInvoice'
                                  AND @mods = N'INVOICE,MEMBER,MEMBER_MONTHLY_SPENDING'
                                  AND @memberCols = N'CurrentPoints:w,Member_ID:r'
                                  AND @lineWrites = 0 AND @remote = 0 AND @tierOrTest = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Settlement write scope: modifies only INVOICE, MEMBER_MONTHLY_SPENDING and MEMBER.CurrentPoints; reads the line tables; calls only the 2 hooks and the month function; no tier or TEST_ object; no cross-database reference',
    CONCAT(N'referenced: ', ISNULL(@refs, N'-'), N' || modified: ', ISNULL(@mods, N'-'), N' || MEMBER columns: ', ISNULL(@memberCols, N'-'),
           N' || line-table writes: ', @lineWrites, N' || remote: ', @remote, N' || Tier/TEST_ tokens: ', @tierOrTest));

/* ---------- K4 cancellation write scope ---------- */
DECLARE @depC TABLE (ent sysname, minor sysname NULL, upd bit);
INSERT @depC SELECT referenced_entity_name, referenced_minor_name, is_updated FROM sys.dm_sql_referenced_entities(N'dbo.usp_P3_CancelInvoice', N'OBJECT');
DECLARE @refsC nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), ent), ',') FROM @depC WHERE minor IS NULL);
DECLARE @colsC nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), CONCAT(minor, CASE WHEN upd = 1 THEN ':w' ELSE ':r' END)), ',') WITHIN GROUP (ORDER BY minor) FROM @depC WHERE minor IS NOT NULL);
INSERT @checks VALUES ('K4', CASE WHEN @refsC = N'INVOICE' AND @colsC = N'Invoice_ID:r,PaymentStatus:w' THEN 'PASS' ELSE 'FAIL' END,
    N'Cancellation write scope: references INVOICE only and writes only PaymentStatus (no PaidAt, spending, points or hook)',
    CONCAT(N'referenced: ', ISNULL(@refsC, N'-'), N' || columns: ', ISNULL(@colsC, N'-')));

/* ---------- K5 no dynamic SQL ---------- */
DECLARE @defC nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_P3_CancelInvoice'));
DECLARE @defF nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.tvf_P3_SpendingMonth'));
DECLARE @execS int = (LEN(@defS) - LEN(REPLACE(@defS, N'EXEC', N''))) / 4;
DECLARE @rest nvarchar(max) = REPLACE(REPLACE(@defS, N'EXEC dbo.usp_HOOK_InventoryDecrementForInvoice @Invoice_ID = @Invoice_ID;', N''),
                                      N'EXEC dbo.usp_HOOK_EntitlementActivationForInvoice @Invoice_ID = @Invoice_ID;', N'');
DECLARE @bad int = CASE WHEN @rest LIKE N'%EXEC%' OR @rest LIKE N'%sp[_]executesql%' OR @rest LIKE N'%OPENQUERY%' OR @rest LIKE N'%OPENROWSET%' OR @rest LIKE N'%OPENDATASOURCE%' THEN 1 ELSE 0 END
                 + CASE WHEN @defC LIKE N'%EXEC%' OR @defC LIKE N'%sp[_]executesql%' OR @defC LIKE N'%OPEN%' OR @defC LIKE N'%Tier%' OR @defC LIKE N'%TEST[_]%' THEN 1 ELSE 0 END
                 + CASE WHEN @defF LIKE N'%EXEC%' OR @defF LIKE N'%OPEN%' THEN 1 ELSE 0 END;
INSERT @checks VALUES ('K5', CASE WHEN @execS = 2 AND @bad = 0 AND OBJECTPROPERTY(OBJECT_ID(N'dbo.usp_P3_SettleInvoice'), 'IsEncrypted') = 0
                                  AND OBJECTPROPERTY(OBJECT_ID(N'dbo.usp_P3_CancelInvoice'), 'IsEncrypted') = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'No dynamic SQL: settlement has exactly the 2 static hook calls and nothing else executed dynamically; cancellation and the function have none; not encrypted (K3/K4 complete)',
    CONCAT(N'EXEC tokens in settle: ', @execS, N'; other dynamic tokens: ', @bad,
           N' || SHA-256 settle ', CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @defS)), 2),
           N'; cancel ', CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @defC)), 2),
           N'; function ', CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @defF)), 2),
           N'; create ', CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_P3_CreateInvoice')))), 2)));

/* ---------- K6 principals and permissions ---------- */
DECLARE @prin nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), name), ',') FROM sys.database_principals WHERE principal_id > 4 AND is_fixed_role = 0 AND name NOT IN (N'public'));
DECLARE @perm int = (SELECT COUNT(*) FROM sys.database_permissions WHERE class IN (1, 6) AND grantee_principal_id > 4);
INSERT @checks VALUES ('K6', CASE WHEN @prin IS NULL AND @perm = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'No extra database user or role and no explicit object or type permission (least-privilege principals are TEST_ONLY and dropped by T-F05S)',
    CONCAT(N'extra principals: ', ISNULL(@prin, N'none'), N'; explicit permissions: ', @perm));

/* ---------- K7 U0 variant (information) ---------- */
DECLARE @u0 int = (SELECT COUNT(*) FROM sys.objects WHERE is_ms_shipped = 0 AND name LIKE N'%Baseline%');
INSERT @checks VALUES ('K7', 'INFO', N'Benchmark-only U0 variant (usp_P3_SettleInvoice_Baseline, task 2) not implemented: needs tier rules D-007/D-008 (PROPOSED); acceptance criterion 4 NOT_RUN',
    CONCAT(N'objects named like %Baseline%: ', @u0));

/* ---------- report ---------- */
SELECT check_id, result, descr, detail FROM @checks ORDER BY seq;
PRINT '-- settlement dependencies (sys.dm_sql_referenced_entities) --';
SELECT ent, ISNULL(minor, '-') AS minor, sel AS is_selected, upd AS is_updated FROM @dep ORDER BY ent, minor;
DROP TABLE #cat;

DECLARE @fails int = (SELECT COUNT(*) FROM @checks WHERE result = 'FAIL'), @nchecks int = (SELECT COUNT(*) FROM @checks WHERE result <> 'INFO');
PRINT CONCAT('T-SCH-04 SUMMARY: checks=', @nchecks, ' FAIL=', @fails, ' INFO=1');
IF @fails > 0 OR @nchecks <> 6
BEGIN
    PRINT 'T-SCH-04_RESULT: FAIL';
    THROW 51252, N'T-SCH-04 failed (see the check table).', 1;
END
ELSE
    PRINT 'T-SCH-04_RESULT: PASS';
GO
