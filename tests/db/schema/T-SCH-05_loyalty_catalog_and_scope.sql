/* =====================================================================
   T-SCH-05_loyalty_catalog_and_scope.sql - TEST_ONLY (sqlcmd mode), read-only
   Work order : WO-P3-P3-02 (acceptance criterion 4, scope, no unauthorized shared-module change).
   Run in FitLife_P3_UC05 after V003 and the loyalty routines are deployed.
     K1  Table catalog vs FitLife_P3_P1: identical except exactly the F002P and F002T items on MEMBER,
         the TEST_ONLY fixture table MEMBER_TIER, the TEST_ONLY tables TEST_*, and the V003 CHECK.
     K2  Object inventory (exact sets) and markers (TEST_ONLY / REFERENCE_ONLY).
     K3  usp_P3_EvaluateTiers: reads MEMBER_MONTHLY_SPENDING, MEMBER, MEMBER_TIER and the tier functions;
         writes ONLY MEMBER.Tier_ID; no INVOICE reference (no invoice-history rescan).
     K4  usp_P3_GetMemberLoyalty: read-only; no INVOICE reference.
     K5  No hard-coded monetary threshold (no numeric literal of 6+ digits) and no dynamic SQL in the
         loyalty routines and functions; the tier function reads MEMBER_TIER.SpendingThreshold.
     K6  Approved routines unchanged: create, settle, cancel, month function (definition SHA-256).
     K7  No database principal or explicit permission beyond the defaults.
   Run: sqlcmd -S localhost -E -I -b -W -d FitLife_P3_UC05 -i tests/db/schema/T-SCH-05_loyalty_catalog_and_scope.sql
   ===================================================================== */
:on error exit
SET NOCOUNT ON;

IF DB_NAME() <> N'FitLife_P3_UC05' THROW 51255, N'T-SCH-05 runs only in FitLife_P3_UC05.', 1;
IF DB_ID(N'FitLife_P3_P1') IS NULL THROW 51256, N'T-SCH-05 needs FitLife_P3_P1 as the catalog reference (read-only).', 1;

DECLARE @checks TABLE (seq int IDENTITY(1,1), check_id varchar(4), result varchar(4), descr nvarchar(300), detail nvarchar(4000));
DECLARE @n1 int, @n2 int;

/* ---------- K1 ---------- */
CREATE TABLE #cat (db varchar(4) NOT NULL, item nvarchar(1000) COLLATE DATABASE_DEFAULT NOT NULL);
DECLARE @q nvarchar(max) = N'
INSERT #cat (db, item)
SELECT @db, x FROM (
  SELECT CONCAT(N''COL|'', t.name, N''|'', c.column_id, N''|'', c.name, N''|'', ty.name, N''|'', c.max_length, N''|'', c.precision, N''|'', c.scale,
                N''|'', c.is_nullable, N''|'', c.is_identity, N''|'', ISNULL(c.collation_name, N''-'')) AS x
  FROM sys.tables AS t JOIN sys.columns AS c ON c.object_id = t.object_id JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id WHERE t.is_ms_shipped = 0
  UNION ALL SELECT CONCAT(N''OBJ|'', o.type, N''|'', o.name, N''|'', t.name) FROM sys.objects AS o JOIN sys.tables AS t ON t.object_id = o.parent_object_id WHERE o.is_ms_shipped = 0
  UNION ALL SELECT CONCAT(N''CHK|'', cc.name, N''|'', cc.definition, N''|'', cc.is_disabled, N''|'', cc.is_not_trusted) FROM sys.check_constraints AS cc
  UNION ALL SELECT CONCAT(N''DEF|'', dc.name, N''|'', dc.definition) FROM sys.default_constraints AS dc
  UNION ALL SELECT CONCAT(N''FK|'', fk.name, N''|'', COL_NAME(fkc.parent_object_id, fkc.parent_column_id), N''->'', OBJECT_NAME(fk.referenced_object_id), N''.'',
                COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id), N''|'', fk.delete_referential_action, N''|'', fk.update_referential_action, N''|'', fk.is_disabled, N''|'', fk.is_not_trusted)
            FROM sys.foreign_keys AS fk JOIN sys.foreign_key_columns AS fkc ON fkc.constraint_object_id = fk.object_id
  UNION ALL SELECT CONCAT(N''IDX|'', t.name, N''|'', i.name, N''|'', i.type, N''|'', i.is_unique, N''|'', i.is_primary_key, N''|'', ISNULL(i.filter_definition, N''-''), N''|'',
                (SELECT STRING_AGG(CONVERT(nvarchar(400), CONCAT(c.name, N'':'', ic.key_ordinal, N'':'', ic.is_descending_key, N'':'', ic.is_included_column)), N'','') WITHIN GROUP (ORDER BY ic.key_ordinal, c.name)
                 FROM sys.index_columns AS ic JOIN sys.columns AS c ON c.object_id = ic.object_id AND c.column_id = ic.column_id WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id))
            FROM sys.indexes AS i JOIN sys.tables AS t ON t.object_id = i.object_id WHERE t.is_ms_shipped = 0
  UNION ALL SELECT CONCAT(N''EP|'', t.name, N''|'', ep.minor_id, N''|'', ep.name, N''|'', CONVERT(nvarchar(400), ep.value)) FROM sys.extended_properties AS ep JOIN sys.tables AS t ON t.object_id = ep.major_id WHERE ep.class = 1
) AS q;';
EXEC FitLife_P3_P1.sys.sp_executesql @q, N'@db varchar(4)', @db = 'P1';
EXEC sys.sp_executesql @q, N'@db varchar(4)', @db = 'UC05';
DECLARE @expected TABLE (item nvarchar(1000) COLLATE DATABASE_DEFAULT NOT NULL);
INSERT @expected VALUES
    (N'COL|MEMBER|2|CurrentPoints|int|4|10|0|0|0|-'), (N'OBJ|D |DF_MEMBER_CurrentPoints|MEMBER'), (N'DEF|DF_MEMBER_CurrentPoints|((0))'),
    (N'EP|MEMBER|2|Classification|TEST_ONLY_FIXTURE (F002P points-only)'),
    (N'COL|MEMBER|3|Tier_ID|int|4|10|0|0|0|-'), (N'OBJ|F |FK_MEMBER_MEMBER_TIER|MEMBER'), (N'FK|FK_MEMBER_MEMBER_TIER|Tier_ID->MEMBER_TIER.Tier_ID|0|0|0|0'),
    (N'EP|MEMBER|3|Classification|TEST_ONLY_FIXTURE (F002T)'),
    (N'OBJ|C |CK_MEMBER_MONTHLY_SPENDING_PointsRule|MEMBER_MONTHLY_SPENDING');
DECLARE @onlyP1 nvarchar(4000), @unexp nvarchar(4000), @missing nvarchar(4000), @v003 nvarchar(400);
SELECT @onlyP1 = STRING_AGG(CONVERT(nvarchar(4000), b.item), N'; ') FROM #cat AS b WHERE b.db = 'P1' AND NOT EXISTS (SELECT 1 FROM #cat AS a WHERE a.db = 'UC05' AND a.item = b.item);
SELECT @unexp = STRING_AGG(CONVERT(nvarchar(4000), a.item), N'; ') FROM #cat AS a
WHERE a.db = 'UC05' AND NOT EXISTS (SELECT 1 FROM #cat AS b WHERE b.db = 'P1' AND b.item = a.item) AND NOT EXISTS (SELECT 1 FROM @expected AS e WHERE e.item = a.item)
  AND a.item NOT LIKE N'%TEST[_]%' AND a.item NOT LIKE N'COL|MEMBER[_]TIER|%' AND a.item NOT LIKE N'OBJ|%|MEMBER[_]TIER' AND a.item NOT LIKE N'IDX|MEMBER[_]TIER|%'
  AND a.item NOT LIKE N'EP|MEMBER[_]TIER|%' AND a.item NOT LIKE N'CHK|CK[_]MEMBER[_]MONTHLY[_]SPENDING[_]PointsRule|%|0|0';
SELECT @missing = STRING_AGG(CONVERT(nvarchar(4000), e.item), N'; ') FROM @expected AS e WHERE NOT EXISTS (SELECT 1 FROM #cat AS a WHERE a.db = 'UC05' AND a.item = e.item);
SELECT @v003 = MIN(item) FROM #cat WHERE db = 'UC05' AND item LIKE N'CHK|CK[_]MEMBER[_]MONTHLY[_]SPENDING[_]PointsRule|%|0|0';
SELECT @n1 = SUM(CASE WHEN db = 'P1' THEN 1 ELSE 0 END), @n2 = SUM(CASE WHEN db = 'UC05' THEN 1 ELSE 0 END) FROM #cat;
INSERT @checks VALUES ('K1', CASE WHEN @onlyP1 IS NULL AND @unexp IS NULL AND @missing IS NULL AND @v003 IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
    N'Catalog = accepted P1 catalog + exactly: F002P/F002T items on MEMBER, TEST_ONLY MEMBER_TIER and TEST_* tables, V003 CHECK (trusted, enabled); the P3 tables otherwise unchanged; no index added',
    CONCAT(N'items P1 ', @n1, N', UC05 ', @n2, N'; only in P1: ', ISNULL(@onlyP1, N'none'), N'; unexpected: ', ISNULL(@unexp, N'none'), N'; missing expected: ', ISNULL(@missing, N'none'), N'; V003: ', ISNULL(@v003, N'MISSING')));

/* ---------- K2 ---------- */
DECLARE @procs nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), name), ',') WITHIN GROUP (ORDER BY name) FROM sys.procedures WHERE is_ms_shipped = 0);
DECLARE @funcs nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), CONCAT(type COLLATE DATABASE_DEFAULT, ':', name)), ',') WITHIN GROUP (ORDER BY name) FROM sys.objects WHERE is_ms_shipped = 0 AND type IN ('FN', 'IF', 'TF', 'FS', 'FT', 'AF'));
DECLARE @tbls nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), name), ',') WITHIN GROUP (ORDER BY name) FROM sys.tables WHERE is_ms_shipped = 0);
DECLARE @other int = (SELECT COUNT(*) FROM sys.objects WHERE is_ms_shipped = 0 AND type NOT IN ('U', 'PK', 'F', 'C', 'D', 'P', 'TT', 'IF')) + (SELECT COUNT(*) FROM sys.triggers)
                   + (SELECT COUNT(*) FROM sys.indexes AS i JOIN sys.tables AS t ON t.object_id = i.object_id WHERE t.is_ms_shipped = 0 AND i.type > 0 AND i.is_primary_key = 0)
                   + (SELECT COUNT(*) FROM sys.partition_functions) + (SELECT COUNT(*) FROM sys.partition_schemes);
DECLARE @unmarked nvarchar(1000) = (
    SELECT STRING_AGG(CONVERT(nvarchar(1000), o.name), ',') FROM sys.objects AS o
    WHERE o.is_ms_shipped = 0 AND o.parent_object_id = 0 AND (o.name LIKE N'TEST[_]%' OR o.name LIKE N'usp[_]HOOK[_]%' OR o.name = N'usp_P3_SettleInvoice_Baseline' OR o.name = N'MEMBER_TIER')
      AND NOT EXISTS (SELECT 1 FROM sys.extended_properties AS ep WHERE ep.class = 1 AND ep.major_id = o.object_id AND ep.minor_id = 0 AND ep.name = N'Classification'
                      AND (CONVERT(nvarchar(400), ep.value) LIKE N'TEST[_]ONLY%' OR CONVERT(nvarchar(400), ep.value) LIKE N'REFERENCE[_]ONLY%')));
INSERT @checks VALUES ('K2', CASE WHEN @procs = N'TEST_p3_AddPaidHistory,usp_HOOK_EntitlementActivationForInvoice,usp_HOOK_InventoryDecrementForInvoice,usp_P3_CancelInvoice,usp_P3_CreateInvoice,usp_P3_EvaluateTiers,usp_P3_GetMemberLoyalty,usp_P3_SettleInvoice,usp_P3_SettleInvoice_Baseline'
                                  AND @funcs = N'IF:tvf_P3_SpendingMonth,IF:tvf_P3_TierForSpend,IF:tvf_P3_TierWindow'
                                  AND @tbls = N'BRANCH,EMPLOYEE,INVOICE,INVOICE_PRODUCT_ITEM,INVOICE_SERVICE_ITEM,MEMBER,MEMBER_MONTHLY_SPENDING,MEMBER_TIER,PRODUCT,SERVICE_PLAN,TEST_HistoryInvoice,TEST_HookCallLog,TEST_HookFault'
                                  AND @other = 0 AND @unmarked IS NULL THEN 'PASS' ELSE 'FAIL' END,
    N'Inventory: P3 routines (create, settle, cancel, evaluate, lookup) + REFERENCE_ONLY U0 + TEST_ONLY doubles/helper; 3 inline functions; fixtures + TEST_ONLY tables; no trigger, view, non-PK index or partition object; every non-production object marked',
    CONCAT(N'procedures: ', @procs, N' || functions: ', @funcs, N' || tables: ', @tbls, N' || other: ', @other, N' || unmarked: ', ISNULL(@unmarked, N'none')));

/* ---------- K3 / K4 ---------- */
DECLARE @dep TABLE (obj sysname, ent sysname, minor sysname NULL, db sysname NULL, upd bit);
INSERT @dep SELECT N'eval', referenced_entity_name, referenced_minor_name, referenced_database_name, is_updated FROM sys.dm_sql_referenced_entities(N'dbo.usp_P3_EvaluateTiers', N'OBJECT')
WHERE ISNULL(referenced_schema_name, N'dbo') <> N'sys';   -- sp_getapplock / sp_releaseapplock (run serialisation)
INSERT @dep SELECT N'look', referenced_entity_name, referenced_minor_name, referenced_database_name, is_updated FROM sys.dm_sql_referenced_entities(N'dbo.usp_P3_GetMemberLoyalty', N'OBJECT');
INSERT @dep SELECT N'tier', referenced_entity_name, referenced_minor_name, referenced_database_name, is_updated FROM sys.dm_sql_referenced_entities(N'dbo.tvf_P3_TierForSpend', N'OBJECT');
DECLARE @eRefs nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), ent), ',') WITHIN GROUP (ORDER BY ent) FROM @dep WHERE obj = N'eval' AND minor IS NULL);
DECLARE @eMods nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), CONCAT(ent, '.', ISNULL(minor, '*'))), ',') WITHIN GROUP (ORDER BY ent, minor) FROM @dep WHERE obj = N'eval' AND upd = 1);
DECLARE @lRefs nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), ent), ',') WITHIN GROUP (ORDER BY ent) FROM @dep WHERE obj = N'look' AND minor IS NULL);
DECLARE @lMods int = (SELECT COUNT(*) FROM @dep WHERE obj = N'look' AND upd = 1);
DECLARE @tRefs nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), CONCAT(ent, '.', ISNULL(minor, '*'))), ',') WITHIN GROUP (ORDER BY ent, minor) FROM @dep WHERE obj = N'tier');
DECLARE @remote int = (SELECT COUNT(*) FROM @dep WHERE db IS NOT NULL);
INSERT @checks VALUES ('K3', CASE WHEN @eRefs = N'MEMBER,MEMBER_MONTHLY_SPENDING,MEMBER_TIER,tvf_P3_TierForSpend,tvf_P3_TierWindow'
                                  AND @eMods = N'MEMBER.*,MEMBER.Tier_ID' AND @remote = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'usp_P3_EvaluateTiers reads only the monthly aggregate, MEMBER and MEMBER_TIER (no INVOICE: no invoice-history rescan) and writes only MEMBER.Tier_ID',
    CONCAT(N'referenced: ', ISNULL(@eRefs, N'-'), N' || modified: ', ISNULL(@eMods, N'-'), N' || cross-database: ', @remote));
INSERT @checks VALUES ('K4', CASE WHEN @lRefs = N'MEMBER,MEMBER_MONTHLY_SPENDING,MEMBER_TIER,tvf_P3_TierForSpend,tvf_P3_TierWindow' AND @lMods = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'usp_P3_GetMemberLoyalty is read-only and does not read INVOICE',
    CONCAT(N'referenced: ', ISNULL(@lRefs, N'-'), N' || modified entities: ', @lMods));

/* ---------- K5 ---------- */
DECLARE @defs TABLE (name sysname, def nvarchar(max));
INSERT @defs SELECT name, OBJECT_DEFINITION(object_id) FROM sys.objects WHERE name IN (N'usp_P3_EvaluateTiers', N'usp_P3_GetMemberLoyalty', N'tvf_P3_TierForSpend', N'tvf_P3_TierWindow');
DECLARE @lit nvarchar(400) = (SELECT STRING_AGG(CONVERT(nvarchar(400), name), ',') FROM @defs WHERE def LIKE N'%[0-9][0-9][0-9][0-9][0-9][0-9]%');
-- the run-serialisation calls of usp_P3_EvaluateTiers are static system-procedure calls, not dynamic SQL
UPDATE @defs SET def = REPLACE(REPLACE(def, N'EXEC @lock = sys.sp_getapplock', N''), N'EXEC sys.sp_releaseapplock', N'');
DECLARE @dyn nvarchar(400) = (SELECT STRING_AGG(CONVERT(nvarchar(400), name), ',') FROM @defs WHERE def LIKE N'%EXEC%' OR def LIKE N'%sp[_]executesql%' OR def LIKE N'%OPEN%');
DECLARE @nd int = (SELECT COUNT(*) FROM @defs);
INSERT @checks VALUES ('K5', CASE WHEN @nd = 4 AND @lit IS NULL AND @dyn IS NULL AND @tRefs LIKE N'%MEMBER_TIER.SpendingThreshold%' THEN 'PASS' ELSE 'FAIL' END,
    N'No hard-coded monetary threshold (no numeric literal of 6+ digits) and no dynamic SQL in the loyalty routines and functions; the tier rule reads MEMBER_TIER.SpendingThreshold (criterion 4)',
    CONCAT(N'definitions checked: ', @nd, N'; with 6+ digit literals: ', ISNULL(@lit, N'none'), N'; with dynamic SQL tokens: ', ISNULL(@dyn, N'none'), N'; tier function reads: ', ISNULL(@tRefs, N'-')));

/* ---------- K6 ---------- */
DECLARE @h TABLE (name sysname, expected varchar(64), actual varchar(64));
INSERT @h (name, expected) VALUES
    (N'usp_P3_CreateInvoice', '3513176C846634380A87A740B3F58A2F29E70930B90B9A94CB0893F97A123013'),
    (N'usp_P3_SettleInvoice', '96C877A800B0EBE004F6B6F44780B7A5C11530F36F8BEA9A9E2C96C07FD47E44'),
    (N'usp_P3_CancelInvoice', '9C2EE95CDE5A6E579FE4E746EBB298BBCF0D7C2E62E6D4F802EAC026598B39D4'),
    (N'tvf_P3_SpendingMonth', '7E8A717BE994377D766A553B2D182D29C03CBDBF442226195F2E936C6E5EB780');
UPDATE h SET actual = CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), OBJECT_DEFINITION(OBJECT_ID(N'dbo.' + h.name)))), 2) FROM @h AS h;
DECLARE @changed nvarchar(400) = (SELECT STRING_AGG(CONVERT(nvarchar(400), name), ',') FROM @h WHERE ISNULL(actual, '') <> expected);
INSERT @checks VALUES ('K6', CASE WHEN @changed IS NULL THEN 'PASS' ELSE 'FAIL' END,
    N'Approved routines unchanged (definition SHA-256 = WO-P3-P3-00/01 evidence): create, settle, cancel, month function',
    CONCAT(N'changed: ', ISNULL(@changed, N'none'), N'; new: evaluate ', CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_P3_EvaluateTiers')))), 2),
           N', lookup ', CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_P3_GetMemberLoyalty')))), 2)));

/* ---------- K7 ---------- */
DECLARE @prin nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), name), ',') FROM sys.database_principals WHERE principal_id > 4 AND is_fixed_role = 0 AND name NOT IN (N'public'));
DECLARE @perm int = (SELECT COUNT(*) FROM sys.database_permissions WHERE class IN (1, 6) AND grantee_principal_id > 4);
INSERT @checks VALUES ('K7', CASE WHEN @prin IS NULL AND @perm = 0 THEN 'PASS' ELSE 'FAIL' END, N'No extra database user or role and no explicit permission',
    CONCAT(N'extra principals: ', ISNULL(@prin, N'none'), N'; explicit permissions: ', @perm));

SELECT check_id, result, descr, detail FROM @checks ORDER BY seq;
DROP TABLE #cat;
DECLARE @fails int = (SELECT COUNT(*) FROM @checks WHERE result = 'FAIL'), @nchk int = (SELECT COUNT(*) FROM @checks);
PRINT CONCAT('T-SCH-05 SUMMARY: checks=', @nchk, ' FAIL=', @fails);
IF @fails > 0 OR @nchk <> 7 BEGIN PRINT 'T-SCH-05_RESULT: FAIL'; THROW 51257, N'T-SCH-05 failed (see the check table).', 1; END
ELSE PRINT 'T-SCH-05_RESULT: PASS';
GO
