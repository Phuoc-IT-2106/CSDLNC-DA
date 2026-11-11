/* =====================================================================
   T-SCH-06_revenue_catalog_and_scope.sql - TEST_ONLY (sqlcmd mode), read-only
   Work order : WO-P3-P4-01 Part F (criterion F3: the report routines are read-only, add no index, table,
   view or summary, and leave the approved UC05 routines unchanged).
   Run in FitLife_P3_UC05 or FitLife_P3_UC05L after db/procedures/usp_P3_RevenueReports.sql is deployed.
     S1  The seven revenue objects exist (5 procedures, 2 inline functions) and nothing else was added:
         every user object is on the list of known P3 / TEST_ONLY / REFERENCE_ONLY objects; no view,
         trigger, sequence, synonym, non-PK index, columnstore, partition function or scheme.
     S2  Dependencies of the five report procedures (sys.sql_expression_dependencies): only INVOICE, BRANCH
         (the two branch reports) and the two report functions; no line table, MEMBER,
         MEMBER_MONTHLY_SPENDING, cross-database or remote reference; the functions read no table. Columns
         (routine text): no INVOICE column other than Branch_ID, FinalAmount, PaidAt, PaymentStatus is named.
     S3  Text of the routines: exactly one filter per procedure and it is the canonical sargable one
         (PaymentStatus = 'PAID' AND PaidAt >= @FromUtc AND PaidAt < @ToUtc); PaidAt appears elsewhere only
         as the argument of the bucket function; no AT TIME ZONE, IssuedAt, GrossAmount, hint or dynamic SQL.
     S4  Approved routines unchanged (definition SHA-256 = WO-P3-P3-00/01/02 evidence): create, settle,
         cancel, month function, and - where deployed - tier evaluation and loyalty lookup.
     S5  No database principal or explicit permission beyond the defaults.
   The table catalog itself (columns, constraints, indexes) is compared before / after by the runner with
   tests/db/schema/catalog_digest.sql.
   Note (2026-11-10): the first version of S2 used sys.dm_sql_referenced_entities. In run
   UC06-RUN__20261110-0153 that function failed twice on this instance (SQL Server 2025 RTM 17.0.1000.7):
   one session was terminated with an access violation logged by the engine (step C30) and one call
   returned a corrupted column name (step D4), while the same check passed in steps A9, B11, C21 and in 22
   later repetitions. S2 therefore uses only the static catalog view and the routine text; "nothing is
   updated" is covered by S3 (no INSERT, UPDATE, DELETE, MERGE or INTO in any routine).
   Run: sqlcmd -S localhost -E -I -b -W -d <db> -i tests/db/schema/T-SCH-06_revenue_catalog_and_scope.sql
   ===================================================================== */
:on error exit
SET NOCOUNT ON;

IF DB_NAME() NOT IN (N'FitLife_P3_UC05', N'FitLife_P3_UC05L') THROW 51450, N'T-SCH-06 runs only in FitLife_P3_UC05 or FitLife_P3_UC05L.', 1;

DECLARE @checks TABLE (seq int IDENTITY(1,1), check_id varchar(4), result varchar(4), descr nvarchar(700), detail nvarchar(4000));
DECLARE @rpt TABLE (name sysname PRIMARY KEY, type char(2), filters int);
INSERT @rpt VALUES (N'usp_P3_RptBranchRevenue', 'P', 1), (N'usp_P3_RptSystemRevenue', 'P', 1), (N'usp_P3_RptSystemRevenueByBranch', 'P', 1),
                   (N'usp_P3_RptBranchRevenueByPeriod', 'P', 1), (N'usp_P3_RptSystemRevenueByPeriod', 'P', 1),
                   (N'tvf_P3_ReportPeriodUtc', 'IF', 0), (N'tvf_P3_ReportPeriodStart', 'IF', 0);

/* ---------- S1 ---------- */
DECLARE @known TABLE (name sysname PRIMARY KEY);
INSERT @known VALUES (N'INVOICE'), (N'INVOICE_SERVICE_ITEM'), (N'INVOICE_PRODUCT_ITEM'), (N'MEMBER_MONTHLY_SPENDING'), (N'MEMBER'), (N'BRANCH'), (N'EMPLOYEE'), (N'SERVICE_PLAN'), (N'PRODUCT'),
    (N'MEMBER_TIER'), (N'TEST_HookCallLog'), (N'TEST_HookFault'), (N'TEST_HistoryInvoice'), (N'TEST_RevenueFixture'),
    (N'usp_P3_CreateInvoice'), (N'usp_P3_SettleInvoice'), (N'usp_P3_CancelInvoice'), (N'usp_P3_SettleInvoice_Baseline'), (N'usp_P3_EvaluateTiers'), (N'usp_P3_GetMemberLoyalty'),
    (N'usp_HOOK_InventoryDecrementForInvoice'), (N'usp_HOOK_EntitlementActivationForInvoice'), (N'TEST_p3_AddPaidHistory'),
    (N'tvf_P3_SpendingMonth'), (N'tvf_P3_TierWindow'), (N'tvf_P3_TierForSpend');
DECLARE @missing nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), r.name), ',') FROM @rpt AS r
                                   WHERE NOT EXISTS (SELECT 1 FROM sys.objects AS o WHERE o.name = r.name AND o.type COLLATE DATABASE_DEFAULT = r.type AND o.schema_id = SCHEMA_ID(N'dbo')));
DECLARE @unexpected nvarchar(2000) = (
    SELECT STRING_AGG(CONVERT(nvarchar(2000), CONCAT(o.type COLLATE DATABASE_DEFAULT, ':', o.name)), ', ') FROM sys.objects AS o
    WHERE o.is_ms_shipped = 0 AND o.parent_object_id = 0 AND o.type <> 'TT'
      AND NOT EXISTS (SELECT 1 FROM @known AS k WHERE k.name = o.name) AND NOT EXISTS (SELECT 1 FROM @rpt AS r WHERE r.name = o.name));
DECLARE @other int = (SELECT COUNT(*) FROM sys.objects WHERE is_ms_shipped = 0 AND type NOT IN ('U', 'PK', 'F', 'C', 'D', 'P', 'TT', 'IF')) + (SELECT COUNT(*) FROM sys.triggers)
                   + (SELECT COUNT(*) FROM sys.indexes AS i JOIN sys.tables AS t ON t.object_id = i.object_id WHERE t.is_ms_shipped = 0 AND i.type > 0 AND i.is_primary_key = 0)
                   + (SELECT COUNT(*) FROM sys.partition_functions) + (SELECT COUNT(*) FROM sys.partition_schemes);
DECLARE @rptLike nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), CONCAT(o.type COLLATE DATABASE_DEFAULT, ':', o.name)), ',') WITHIN GROUP (ORDER BY o.name) FROM sys.objects AS o
                                   WHERE o.is_ms_shipped = 0 AND o.parent_object_id = 0 AND (o.name LIKE N'usp[_]P3[_]Rpt%' OR o.name LIKE N'tvf[_]P3[_]Report%'));
INSERT @checks VALUES ('S1', CASE WHEN @missing IS NULL AND @unexpected IS NULL AND @other = 0
                                  AND @rptLike = N'IF:tvf_P3_ReportPeriodStart,IF:tvf_P3_ReportPeriodUtc,P :usp_P3_RptBranchRevenue,P :usp_P3_RptBranchRevenueByPeriod,P :usp_P3_RptSystemRevenue,P :usp_P3_RptSystemRevenueByBranch,P :usp_P3_RptSystemRevenueByPeriod'
                             THEN 'PASS' ELSE 'FAIL' END,
    N'Exactly the 7 revenue objects were added (5 report procedures, 2 inline functions); every other object is a known P3 / TEST_ONLY / REFERENCE_ONLY object; no view, trigger, sequence, synonym, non-PK index, columnstore or partition object; no summary table',
    CONCAT(N'revenue objects: ', ISNULL(@rptLike, N'none'), N' || missing: ', ISNULL(@missing, N'none'), N' || unexpected objects: ', ISNULL(@unexpected, N'none'), N' || views/triggers/non-PK indexes/partition objects/other types: ', @other,
           N' || tables: ', (SELECT STRING_AGG(CONVERT(nvarchar(1000), name), ',') WITHIN GROUP (ORDER BY name) FROM sys.tables WHERE is_ms_shipped = 0)));

/* ---------- S2 (static: catalog view + routine text; see the header note on sys.dm_sql_referenced_entities) ---------- */
DECLARE @dep TABLE (obj sysname, ent sysname, db sysname NULL, srv sysname NULL);
INSERT @dep (obj, ent, db, srv)
SELECT DISTINCT OBJECT_NAME(d.referencing_id), d.referenced_entity_name, d.referenced_database_name, d.referenced_server_name
FROM sys.sql_expression_dependencies AS d JOIN @rpt AS r ON r.name = OBJECT_NAME(d.referencing_id);
DECLARE @expDep TABLE (obj sysname PRIMARY KEY, ents nvarchar(400));
INSERT @expDep VALUES (N'usp_P3_RptBranchRevenue', N'BRANCH,INVOICE,tvf_P3_ReportPeriodUtc'), (N'usp_P3_RptSystemRevenue', N'INVOICE,tvf_P3_ReportPeriodUtc'),
                      (N'usp_P3_RptSystemRevenueByBranch', N'INVOICE,tvf_P3_ReportPeriodUtc'), (N'usp_P3_RptBranchRevenueByPeriod', N'BRANCH,INVOICE,tvf_P3_ReportPeriodStart,tvf_P3_ReportPeriodUtc'),
                      (N'usp_P3_RptSystemRevenueByPeriod', N'INVOICE,tvf_P3_ReportPeriodStart,tvf_P3_ReportPeriodUtc');
DECLARE @badEnt nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), CONCAT(e.obj, N' -> ', ISNULL(x.ents, N'(none)'))), N'; ') FROM @expDep AS e
                                  OUTER APPLY (SELECT STRING_AGG(CONVERT(nvarchar(400), d.ent), N',') WITHIN GROUP (ORDER BY d.ent) AS ents FROM @dep AS d WHERE d.obj = e.obj) AS x
                                  WHERE ISNULL(x.ents, N'') <> e.ents);
DECLARE @fnDeps int = (SELECT COUNT(*) FROM @dep WHERE obj LIKE N'tvf%'), @remote int = (SELECT COUNT(*) FROM @dep WHERE db IS NOT NULL OR srv IS NOT NULL);
-- columns, from the routine text: no INVOICE column other than the four revenue columns is named anywhere in the 7 definitions
DECLARE @txt TABLE (name sysname PRIMARY KEY, type char(2), def nvarchar(max));
INSERT @txt SELECT r.name, r.type, OBJECT_DEFINITION(OBJECT_ID(N'dbo.' + r.name)) FROM @rpt AS r;
DECLARE @badCol nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), CONCAT(t.name, N':', c.name)), N', ')
                                  FROM sys.columns AS c CROSS JOIN @txt AS t
                                  WHERE c.object_id = OBJECT_ID(N'dbo.INVOICE') AND c.name NOT IN (N'Branch_ID', N'FinalAmount', N'PaidAt', N'PaymentStatus') AND t.def LIKE N'%' + c.name + N'%');
DECLARE @missCol nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), t.name), N',') FROM @txt AS t
                                   WHERE t.type = 'P' AND (t.def NOT LIKE N'%SUM(i.FinalAmount)%' OR t.def NOT LIKE N'%i.PaidAt%' OR t.def NOT LIKE N'%i.PaymentStatus%'));
DECLARE @otherCols nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), name), N',') WITHIN GROUP (ORDER BY column_id) FROM sys.columns
                                     WHERE object_id = OBJECT_ID(N'dbo.INVOICE') AND name NOT IN (N'Branch_ID', N'FinalAmount', N'PaidAt', N'PaymentStatus'));
INSERT @checks VALUES ('S2', CASE WHEN @badEnt IS NULL AND (SELECT COUNT(DISTINCT obj) FROM @dep) = 5 AND @fnDeps = 0 AND @remote = 0 AND @badCol IS NULL AND @missCol IS NULL
                                  AND (SELECT COUNT(*) FROM @txt WHERE def IS NOT NULL) = 7 THEN 'PASS' ELSE 'FAIL' END,
    N'Report procedures depend only on INVOICE, BRANCH (key check, branch reports only) and the two report functions (sys.sql_expression_dependencies); the functions read no table; no line table, MEMBER or spending table; no cross-database or remote reference; of the INVOICE columns only Branch_ID, FinalAmount, PaidAt and PaymentStatus are named in the routine text',
    CONCAT(N'dependencies: ', (SELECT STRING_AGG(CONVERT(nvarchar(2000), CONCAT(e.obj, N' -> ', x.ents)), N'; ') WITHIN GROUP (ORDER BY e.obj) FROM @expDep AS e
                               OUTER APPLY (SELECT STRING_AGG(CONVERT(nvarchar(400), d.ent), N',') WITHIN GROUP (ORDER BY d.ent) AS ents FROM @dep AS d WHERE d.obj = e.obj) AS x),
           N' || deviating: ', ISNULL(@badEnt, N'none'), N' || dependencies of the functions: ', @fnDeps, N' || cross-database or remote: ', @remote,
           N' || other INVOICE columns (', @otherCols, N') named in a routine: ', ISNULL(@badCol, N'none'), N' || procedures without the revenue columns: ', ISNULL(@missCol, N'none')));

/* ---------- S3 ---------- */
DECLARE @defs TABLE (name sysname PRIMARY KEY, type char(2), def nvarchar(max), filters int NULL, rest nvarchar(max) NULL);
INSERT @defs (name, type, def) SELECT r.name, r.type, OBJECT_DEFINITION(OBJECT_ID(N'dbo.' + r.name)) FROM @rpt AS r;
DECLARE @canon nvarchar(200) = N'i.PaymentStatus = ''PAID'' AND i.PaidAt >= @FromUtc AND i.PaidAt < @ToUtc';
UPDATE @defs SET filters = (LEN(def) - LEN(REPLACE(def, @canon, N''))) / LEN(@canon),
                 rest = REPLACE(REPLACE(REPLACE(def, @canon, N''), N'dbo.tvf_P3_ReportPeriodStart(i.PaidAt, @Grain)', N''), N'@PaidAtUtc', N'');
DECLARE @badFilter nvarchar(400) = (SELECT STRING_AGG(CONVERT(nvarchar(400), CONCAT(d.name, N'=', d.filters)), ',') FROM @defs AS d JOIN @rpt AS r ON r.name = d.name WHERE d.filters <> r.filters OR d.filters IS NULL);
DECLARE @paidElsewhere nvarchar(400) = (SELECT STRING_AGG(CONVERT(nvarchar(400), name), ',') FROM @defs WHERE rest LIKE N'%PaidAt%');
DECLARE @whereCount nvarchar(400) = (SELECT STRING_AGG(CONVERT(nvarchar(400), name), ',') FROM @defs WHERE type = 'P' AND (LEN(def) - LEN(REPLACE(def, N'FROM dbo.INVOICE', N''))) / LEN(N'FROM dbo.INVOICE') <> 1);
DECLARE @forbidden nvarchar(400) = (SELECT STRING_AGG(CONVERT(nvarchar(400), name), ',') FROM @defs
                                    WHERE def LIKE N'%AT TIME ZONE%' OR def LIKE N'%IssuedAt%' OR def LIKE N'%GrossAmount%' OR def LIKE N'%EXEC%' OR def LIKE N'%sp[_]executesql%' OR def LIKE N'%OPENROWSET%'
                                       OR def LIKE N'%OPENQUERY%' OR def LIKE N'%NOLOCK%' OR def LIKE N'%WITH (%' OR def LIKE N'%OPTION (%' OR def LIKE N'%INSERT %' OR def LIKE N'%UPDATE %' OR def LIKE N'%DELETE %' OR def LIKE N'%MERGE %'
                                       OR def LIKE N'%INTO #%' OR def LIKE N'% INTO %' OR def LIKE N'%ITEM%');
INSERT @checks VALUES ('S3', CASE WHEN (SELECT COUNT(*) FROM @defs WHERE def IS NOT NULL) = 7 AND @badFilter IS NULL AND @paidElsewhere IS NULL AND @whereCount IS NULL AND @forbidden IS NULL THEN 'PASS' ELSE 'FAIL' END,
    N'Each report procedure has ONE statement over INVOICE with the canonical half-open UTC filter (PaymentStatus = ''PAID'' literal, PaidAt >= @FromUtc AND PaidAt < @ToUtc); PaidAt is otherwise used only as the argument of the bucket function (SELECT / GROUP BY); no AT TIME ZONE, IssuedAt, GrossAmount, line table, table hint, query hint, DML or dynamic SQL',
    CONCAT(N'definitions ', (SELECT COUNT(*) FROM @defs WHERE def IS NOT NULL), N'; filters per object: ', (SELECT STRING_AGG(CONVERT(nvarchar(600), CONCAT(name, N'=', filters)), N', ') WITHIN GROUP (ORDER BY name) FROM @defs),
           N'; wrong filter count: ', ISNULL(@badFilter, N'none'), N'; PaidAt used elsewhere: ', ISNULL(@paidElsewhere, N'none'), N'; not exactly one INVOICE statement: ', ISNULL(@whereCount, N'none'), N'; forbidden token: ', ISNULL(@forbidden, N'none')));

/* ---------- S4 ---------- */
DECLARE @h TABLE (name sysname, expected varchar(64), actual varchar(64) NULL, deployed bit NULL);
INSERT @h (name, expected) VALUES
    (N'usp_P3_CreateInvoice',    '3513176C846634380A87A740B3F58A2F29E70930B90B9A94CB0893F97A123013'),
    (N'usp_P3_SettleInvoice',    '96C877A800B0EBE004F6B6F44780B7A5C11530F36F8BEA9A9E2C96C07FD47E44'),
    (N'usp_P3_CancelInvoice',    '9C2EE95CDE5A6E579FE4E746EBB298BBCF0D7C2E62E6D4F802EAC026598B39D4'),
    (N'tvf_P3_SpendingMonth',    '7E8A717BE994377D766A553B2D182D29C03CBDBF442226195F2E936C6E5EB780'),
    (N'usp_P3_EvaluateTiers',    'B99EE9625431B9D6297877EC4C8717EC37E2B833CD9A7494CFB855A5A15AF606'),
    (N'usp_P3_GetMemberLoyalty', '7C13AEA21908E3B0ECB5DE067555E9B56E8B52E3001B959A66B4F8D11F145A42');
UPDATE h SET deployed = CASE WHEN OBJECT_ID(N'dbo.' + h.name) IS NULL THEN 0 ELSE 1 END,
             actual = CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), OBJECT_DEFINITION(OBJECT_ID(N'dbo.' + h.name)))), 2) FROM @h AS h;
DECLARE @changed nvarchar(400) = (SELECT STRING_AGG(CONVERT(nvarchar(400), name), ',') FROM @h WHERE deployed = 1 AND ISNULL(actual, '') <> expected);
DECLARE @notDeployed nvarchar(400) = (SELECT STRING_AGG(CONVERT(nvarchar(400), name), ',') FROM @h WHERE deployed = 0);
INSERT @checks VALUES ('S4', CASE WHEN @changed IS NULL AND (SELECT COUNT(*) FROM @h WHERE deployed = 1) >= 1 THEN 'PASS' ELSE 'FAIL' END,
    N'Approved routines unchanged where deployed (definition SHA-256 = WO-P3-P3-00/01/02 evidence): create, settle, cancel, month function, tier evaluation, loyalty lookup',
    CONCAT(N'compared: ', (SELECT COUNT(*) FROM @h WHERE deployed = 1), N'; changed: ', ISNULL(@changed, N'none'), N'; not deployed in this database: ', ISNULL(@notDeployed, N'none'),
           N' || new (SHA-256 of definition): ', (SELECT STRING_AGG(CONVERT(nvarchar(2000), CONCAT(name, N' ', CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), def)), 2))), N'; ') WITHIN GROUP (ORDER BY name) FROM @defs)));

/* ---------- S5 ---------- */
DECLARE @prin nvarchar(1000) = (SELECT STRING_AGG(CONVERT(nvarchar(1000), name), ',') FROM sys.database_principals WHERE principal_id > 4 AND is_fixed_role = 0 AND name NOT IN (N'public'));
DECLARE @perm int = (SELECT COUNT(*) FROM sys.database_permissions WHERE class IN (1, 6) AND grantee_principal_id > 4);
INSERT @checks VALUES ('S5', CASE WHEN @prin IS NULL AND @perm = 0 THEN 'PASS' ELSE 'FAIL' END, N'No extra database user or role and no explicit permission',
    CONCAT(N'extra principals: ', ISNULL(@prin, N'none'), N'; explicit permissions: ', @perm));

SELECT check_id, result, descr, detail FROM @checks ORDER BY seq;
DECLARE @fails int = (SELECT COUNT(*) FROM @checks WHERE result = 'FAIL'), @nchk int = (SELECT COUNT(*) FROM @checks);
PRINT CONCAT('T-SCH-06 SUMMARY: database ', DB_NAME(), '; checks=', @nchk, ' FAIL=', @fails);
IF @fails > 0 OR @nchk <> 5 BEGIN PRINT 'T-SCH-06_RESULT: FAIL'; THROW 51451, N'T-SCH-06 failed (see the check table).', 1; END
ELSE PRINT 'T-SCH-06_RESULT: PASS';
GO
