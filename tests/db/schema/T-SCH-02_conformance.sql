/* =====================================================================
   T-SCH-02_conformance.sql — TEST_ONLY (sqlcmd mode), read-only
   Work order : WO-P3-P1-01 §8.2
   Compares the catalog of the isolated database with the approved specification
   (WO-P3-P1-01 §3.3, §3.3a, §3.4, §3.6): columns and types, constraint set, PK keys,
   the 8 foreign keys, table classification (4 P3_OWNED, 5 TEST_ONLY fixtures),
   object inventory, enabled/trusted state, compatibility level.
   Output contains no volatile values, so two builds can be compared (T-REPRO-01).
   Run from the repository root:
     sqlcmd -S localhost -E -I -b -W -d FitLife_P3_P1 -i tests/db/schema/T-SCH-02_conformance.sql
   ===================================================================== */
:on error exit
SET NOCOUNT ON;

IF DB_NAME() NOT LIKE N'FitLife[_]P3[_]%'
    THROW 51040, N'T-SCH-02 runs only in an isolated FitLife_P3_% database.', 1;

DECLARE @checks TABLE (seq INT IDENTITY(1,1), check_id VARCHAR(8), result VARCHAR(4), descr NVARCHAR(200), detail NVARCHAR(4000));

/* ---------- expected specification ---------- */
DECLARE @tables TABLE (tbl SYSNAME PRIMARY KEY, cls VARCHAR(20));
INSERT @tables VALUES
 (N'INVOICE','P3_OWNED'), (N'INVOICE_SERVICE_ITEM','P3_OWNED'), (N'INVOICE_PRODUCT_ITEM','P3_OWNED'), (N'MEMBER_MONTHLY_SPENDING','P3_OWNED'),
 (N'MEMBER','TEST_ONLY_FIXTURE'), (N'BRANCH','TEST_ONLY_FIXTURE'), (N'EMPLOYEE','TEST_ONLY_FIXTURE'), (N'SERVICE_PLAN','TEST_ONLY_FIXTURE'), (N'PRODUCT','TEST_ONLY_FIXTURE');

DECLARE @cols TABLE (tbl SYSNAME, col SYSNAME, colid INT, typ VARCHAR(30), nullable BIT, ident BIT);
INSERT @cols VALUES
 (N'INVOICE',N'Invoice_ID',1,'int',0,1), (N'INVOICE',N'Member_ID',2,'int',0,0), (N'INVOICE',N'Employee_ID',3,'int',0,0), (N'INVOICE',N'Branch_ID',4,'int',0,0),
 (N'INVOICE',N'IssuedAt',5,'datetime2(3)',0,0), (N'INVOICE',N'GrossAmount',6,'decimal(18,2)',0,0), (N'INVOICE',N'DiscountAmount',7,'decimal(18,2)',0,0),
 (N'INVOICE',N'FinalAmount',8,'decimal(18,2)',0,0), (N'INVOICE',N'PaymentMethod',9,'varchar(10)',1,0), (N'INVOICE',N'PaymentStatus',10,'varchar(10)',0,0),
 (N'INVOICE',N'PaidAt',11,'datetime2(3)',1,0),
 (N'INVOICE_SERVICE_ITEM',N'Invoice_ID',1,'int',0,0), (N'INVOICE_SERVICE_ITEM',N'LineNo',2,'smallint',0,0), (N'INVOICE_SERVICE_ITEM',N'Plan_ID',3,'int',0,0),
 (N'INVOICE_SERVICE_ITEM',N'UnitPrice',4,'decimal(18,2)',0,0), (N'INVOICE_SERVICE_ITEM',N'DiscountAmount',5,'decimal(18,2)',0,0),
 (N'INVOICE_SERVICE_ITEM',N'ValidFrom',6,'date',1,0), (N'INVOICE_SERVICE_ITEM',N'ValidUntil',7,'date',1,0), (N'INVOICE_SERVICE_ITEM',N'PTSessionsRemaining',8,'int',1,0),
 (N'INVOICE_PRODUCT_ITEM',N'Invoice_ID',1,'int',0,0), (N'INVOICE_PRODUCT_ITEM',N'LineNo',2,'smallint',0,0), (N'INVOICE_PRODUCT_ITEM',N'Product_ID',3,'int',0,0),
 (N'INVOICE_PRODUCT_ITEM',N'Quantity',4,'int',0,0), (N'INVOICE_PRODUCT_ITEM',N'UnitPrice',5,'decimal(18,2)',0,0), (N'INVOICE_PRODUCT_ITEM',N'DiscountAmount',6,'decimal(18,2)',0,0),
 (N'MEMBER_MONTHLY_SPENDING',N'Member_ID',1,'int',0,0), (N'MEMBER_MONTHLY_SPENDING',N'SpendingMonth',2,'date',0,0), (N'MEMBER_MONTHLY_SPENDING',N'TotalSpend',3,'decimal(18,2)',0,0),
 (N'MEMBER_MONTHLY_SPENDING',N'PointsEarned',4,'int',0,0), (N'MEMBER_MONTHLY_SPENDING',N'UpdatedAt',5,'datetime2(3)',0,0),
 (N'MEMBER',N'Member_ID',1,'int',0,0), (N'BRANCH',N'Branch_ID',1,'int',0,0), (N'EMPLOYEE',N'Employee_ID',1,'int',0,0),
 (N'SERVICE_PLAN',N'Plan_ID',1,'int',0,0), (N'PRODUCT',N'Product_ID',1,'int',0,0);

DECLARE @cons TABLE (typ VARCHAR(2), name SYSNAME, tbl SYSNAME, info NVARCHAR(200));
INSERT @cons VALUES
 ('PK',N'PK_INVOICE',N'INVOICE',N'Invoice_ID'), ('PK',N'PK_INVOICE_SERVICE_ITEM',N'INVOICE_SERVICE_ITEM',N'Invoice_ID,LineNo'),
 ('PK',N'PK_INVOICE_PRODUCT_ITEM',N'INVOICE_PRODUCT_ITEM',N'Invoice_ID,LineNo'), ('PK',N'PK_MEMBER_MONTHLY_SPENDING',N'MEMBER_MONTHLY_SPENDING',N'Member_ID,SpendingMonth'),
 ('PK',N'PK_MEMBER',N'MEMBER',N'Member_ID'), ('PK',N'PK_BRANCH',N'BRANCH',N'Branch_ID'), ('PK',N'PK_EMPLOYEE',N'EMPLOYEE',N'Employee_ID'),
 ('PK',N'PK_SERVICE_PLAN',N'SERVICE_PLAN',N'Plan_ID'), ('PK',N'PK_PRODUCT',N'PRODUCT',N'Product_ID'),
 ('F',N'FK_INVOICE_MEMBER',N'INVOICE',N'Member_ID->MEMBER.Member_ID'), ('F',N'FK_INVOICE_EMPLOYEE',N'INVOICE',N'Employee_ID->EMPLOYEE.Employee_ID'),
 ('F',N'FK_INVOICE_BRANCH',N'INVOICE',N'Branch_ID->BRANCH.Branch_ID'),
 ('F',N'FK_INVOICE_SERVICE_ITEM_INVOICE',N'INVOICE_SERVICE_ITEM',N'Invoice_ID->INVOICE.Invoice_ID'),
 ('F',N'FK_INVOICE_SERVICE_ITEM_SERVICE_PLAN',N'INVOICE_SERVICE_ITEM',N'Plan_ID->SERVICE_PLAN.Plan_ID'),
 ('F',N'FK_INVOICE_PRODUCT_ITEM_INVOICE',N'INVOICE_PRODUCT_ITEM',N'Invoice_ID->INVOICE.Invoice_ID'),
 ('F',N'FK_INVOICE_PRODUCT_ITEM_PRODUCT',N'INVOICE_PRODUCT_ITEM',N'Product_ID->PRODUCT.Product_ID'),
 ('F',N'FK_MEMBER_MONTHLY_SPENDING_MEMBER',N'MEMBER_MONTHLY_SPENDING',N'Member_ID->MEMBER.Member_ID'),
 ('C',N'CK_INVOICE_SERVICE_ITEM_Validity',N'INVOICE_SERVICE_ITEM',NULL),
 ('C',N'CK_INVOICE_PaymentStatus',N'INVOICE',NULL), ('C',N'CK_INVOICE_PaymentMethod',N'INVOICE',NULL), ('C',N'CK_INVOICE_MethodWhenPaid',N'INVOICE',NULL),
 ('C',N'CK_INVOICE_PaidAtStatus',N'INVOICE',NULL), ('C',N'CK_INVOICE_PaidAtAfterIssued',N'INVOICE',NULL), ('C',N'CK_INVOICE_Amounts',N'INVOICE',NULL),
 ('C',N'CK_INVOICE_FinalAmount',N'INVOICE',NULL), ('C',N'CK_INVOICE_SERVICE_ITEM_Amounts',N'INVOICE_SERVICE_ITEM',NULL),
 ('C',N'CK_INVOICE_PRODUCT_ITEM_Quantity',N'INVOICE_PRODUCT_ITEM',NULL), ('C',N'CK_INVOICE_PRODUCT_ITEM_Amounts',N'INVOICE_PRODUCT_ITEM',NULL),
 ('C',N'CK_MEMBER_MONTHLY_SPENDING_FirstDay',N'MEMBER_MONTHLY_SPENDING',NULL), ('C',N'CK_MEMBER_MONTHLY_SPENDING_NonNegative',N'MEMBER_MONTHLY_SPENDING',NULL),
 ('D',N'DF_INVOICE_PaymentStatus',N'INVOICE',N'PaymentStatus'), ('D',N'DF_MEMBER_MONTHLY_SPENDING_TotalSpend',N'MEMBER_MONTHLY_SPENDING',N'TotalSpend'),
 ('D',N'DF_MEMBER_MONTHLY_SPENDING_PointsEarned',N'MEMBER_MONTHLY_SPENDING',N'PointsEarned'), ('D',N'DF_MEMBER_MONTHLY_SPENDING_UpdatedAt',N'MEMBER_MONTHLY_SPENDING',N'UpdatedAt');

/* ---------- actual catalog ---------- */
DECLARE @acols TABLE (tbl SYSNAME, col SYSNAME, colid INT, typ VARCHAR(30), nullable BIT, ident BIT);
INSERT @acols
SELECT t.name, c.name, c.column_id,
       CASE ty.name WHEN 'decimal'  THEN CONCAT('decimal(', c.precision, ',', c.scale, ')')
                    WHEN 'varchar'  THEN CONCAT('varchar(', c.max_length, ')')
                    WHEN 'nvarchar' THEN CONCAT('nvarchar(', c.max_length / 2, ')')
                    WHEN 'datetime2' THEN CONCAT('datetime2(', c.scale, ')')
                    ELSE ty.name END,
       c.is_nullable, c.is_identity
FROM sys.tables AS t
JOIN sys.columns AS c ON c.object_id = t.object_id
JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
WHERE t.is_ms_shipped = 0;

DECLARE @acons TABLE (typ VARCHAR(2), name SYSNAME, tbl SYSNAME, info NVARCHAR(200));
INSERT @acons
SELECT 'PK', kc.name, t.name,
       (SELECT STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.key_ordinal)
          FROM sys.index_columns AS ic JOIN sys.columns AS c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
         WHERE ic.object_id = kc.parent_object_id AND ic.index_id = kc.unique_index_id)
FROM sys.key_constraints AS kc JOIN sys.tables AS t ON t.object_id = kc.parent_object_id WHERE kc.type = 'PK'
UNION ALL
SELECT 'UQ', kc.name, t.name, NULL FROM sys.key_constraints AS kc JOIN sys.tables AS t ON t.object_id = kc.parent_object_id WHERE kc.type = 'UQ'
UNION ALL
SELECT 'F', fk.name, OBJECT_NAME(fk.parent_object_id),
       CONCAT(COL_NAME(fkc.parent_object_id, fkc.parent_column_id), '->', OBJECT_NAME(fk.referenced_object_id), '.', COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id))
FROM sys.foreign_keys AS fk JOIN sys.foreign_key_columns AS fkc ON fkc.constraint_object_id = fk.object_id
UNION ALL
SELECT 'C', cc.name, OBJECT_NAME(cc.parent_object_id), NULL FROM sys.check_constraints AS cc
UNION ALL
SELECT 'D', dc.name, OBJECT_NAME(dc.parent_object_id), COL_NAME(dc.parent_object_id, dc.parent_column_id) FROM sys.default_constraints AS dc;

/* ---------- C1 columns ---------- */
DECLARE @d NVARCHAR(4000);
SELECT @d = STRING_AGG(CONVERT(NVARCHAR(4000), CONCAT(COALESCE(e.tbl, a.tbl), '.', COALESCE(e.col, a.col), ' expected=', ISNULL(CONCAT(e.colid,'/',e.typ,'/null=',e.nullable,'/id=',e.ident), 'none'),
              ' actual=', ISNULL(CONCAT(a.colid,'/',a.typ,'/null=',a.nullable,'/id=',a.ident), 'none'))), '; ')
FROM @cols AS e FULL OUTER JOIN @acols AS a ON a.tbl = e.tbl AND a.col = e.col
WHERE e.tbl IS NULL OR a.tbl IS NULL OR e.colid <> a.colid OR e.typ <> a.typ OR e.nullable <> a.nullable OR e.ident <> a.ident;
DECLARE @n1 INT = (SELECT COUNT(*) FROM @acols), @n2 INT = (SELECT COUNT(*) FROM @cons), @n3 INT = (SELECT COUNT(*) FROM @acons);
INSERT @checks VALUES ('C1', CASE WHEN @d IS NULL THEN 'PASS' ELSE 'FAIL' END, N'Columns of all 9 tables: name, order, type, nullability, identity (35 columns)',
    ISNULL(@d, CONCAT(N'35 expected = ', @n1, N' actual; no differences')));

/* ---------- C2 constraint set and PK keys ---------- */
SET @d = NULL;
SELECT @d = STRING_AGG(CONVERT(NVARCHAR(4000), CONCAT(COALESCE(e.typ, a.typ), ' ', COALESCE(e.name, a.name), ' expected=', ISNULL(CONCAT(e.tbl, ':', e.info), 'none'), ' actual=', ISNULL(CONCAT(a.tbl, ':', a.info), 'none'))), '; ')
FROM @cons AS e FULL OUTER JOIN @acons AS a ON a.typ = e.typ AND a.name = e.name
WHERE e.name IS NULL OR a.name IS NULL OR e.tbl <> a.tbl OR ISNULL(e.info, N'') <> ISNULL(CASE WHEN a.typ = 'C' THEN NULL ELSE a.info END, N'');
INSERT @checks VALUES ('C2', CASE WHEN @d IS NULL THEN 'PASS' ELSE 'FAIL' END,
    N'Constraint set: 9 PK (key columns), 8 FK, 13 CHECK, 4 DEFAULT, 0 UNIQUE; nothing extra or missing',
    ISNULL(@d, CONCAT(N'expected ', @n2, N' = actual ', @n3)));

/* ---------- C3 foreign keys ---------- */
SET @d = NULL;
SELECT @d = STRING_AGG(CONVERT(NVARCHAR(4000), CONCAT(fk.name, ' delete=', fk.delete_referential_action_desc COLLATE DATABASE_DEFAULT, ' update=', fk.update_referential_action_desc COLLATE DATABASE_DEFAULT,
              ' disabled=', fk.is_disabled, ' not_trusted=', fk.is_not_trusted)), '; ')
FROM sys.foreign_keys AS fk
WHERE fk.delete_referential_action <> 0 OR fk.update_referential_action <> 0 OR fk.is_disabled = 1 OR fk.is_not_trusted = 1;
DECLARE @fkcount INT = (SELECT COUNT(*) FROM sys.foreign_keys);
DECLARE @fkonfix INT = (SELECT COUNT(*) FROM sys.foreign_keys AS fk JOIN @tables AS t ON t.tbl = OBJECT_NAME(fk.parent_object_id) WHERE t.cls <> 'P3_OWNED');
INSERT @checks VALUES ('C3', CASE WHEN @d IS NULL AND @fkcount = 8 AND @fkonfix = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Foreign keys: exactly 8, all owned by P3 tables, NO ACTION on delete and update, enabled and trusted',
    ISNULL(@d, CONCAT(N'count=', @fkcount, N'; on fixtures=', @fkonfix, N'; all NO_ACTION, enabled, trusted')));

/* ---------- C4 classification ---------- */
DECLARE @cls TABLE (tbl SYSNAME, marker NVARCHAR(100), ncols INT, ncons INT);
INSERT @cls
SELECT t.name,
       (SELECT CONVERT(NVARCHAR(100), ep.value) FROM sys.extended_properties AS ep WHERE ep.class = 1 AND ep.major_id = t.object_id AND ep.minor_id = 0 AND ep.name = N'Classification'),
       (SELECT COUNT(*) FROM sys.columns AS c WHERE c.object_id = t.object_id),
       (SELECT COUNT(*) FROM sys.objects AS o WHERE o.parent_object_id = t.object_id AND o.type IN ('PK','UQ','F','C','D'))
FROM sys.tables AS t WHERE t.is_ms_shipped = 0;
SET @d = NULL;
SELECT @d = STRING_AGG(CONVERT(NVARCHAR(4000), CONCAT(COALESCE(e.tbl, a.tbl), ' expected=', ISNULL(e.cls, 'none'), ' marker=', ISNULL(a.marker, '(none)'), ' cols=', a.ncols, ' constraints=', a.ncons)), '; ')
FROM @tables AS e FULL OUTER JOIN @cls AS a ON a.tbl = e.tbl
WHERE e.tbl IS NULL OR a.tbl IS NULL
   OR (e.cls = 'TEST_ONLY_FIXTURE' AND (ISNULL(a.marker, N'') <> N'TEST_ONLY_FIXTURE' OR a.ncols <> 1 OR a.ncons <> 1))
   OR (e.cls = 'P3_OWNED' AND a.marker IS NOT NULL);
DECLARE @clslist NVARCHAR(4000) = (SELECT STRING_AGG(CONVERT(NVARCHAR(4000), CONCAT(tbl, '=', ISNULL(marker, 'P3_OWNED (no fixture marker)'))), ', ') WITHIN GROUP (ORDER BY tbl) FROM @cls);
INSERT @checks VALUES ('C4', CASE WHEN @d IS NULL THEN 'PASS' ELSE 'FAIL' END,
    N'Classification: exactly 9 user tables; 5 fixtures marked TEST_ONLY_FIXTURE with 1 key column and only their PK; 4 P3 tables unmarked',
    ISNULL(@d, @clslist));

/* ---------- C5 object inventory ---------- */
SET @d = NULL;
SELECT @d = STRING_AGG(CONVERT(NVARCHAR(4000), CONCAT(o.type_desc COLLATE DATABASE_DEFAULT, ' ', o.name)), '; ')
FROM sys.objects AS o WHERE o.is_ms_shipped = 0 AND o.type NOT IN ('U', 'PK', 'F', 'C', 'D');
DECLARE @nonpk INT = (SELECT COUNT(*) FROM sys.indexes AS i JOIN sys.tables AS t ON t.object_id = i.object_id WHERE t.is_ms_shipped = 0 AND i.type > 0 AND i.is_primary_key = 0);
DECLARE @pk INT = (SELECT COUNT(*) FROM sys.indexes AS i JOIN sys.tables AS t ON t.object_id = i.object_id WHERE t.is_ms_shipped = 0 AND i.is_primary_key = 1 AND i.type = 1);
DECLARE @parts INT = (SELECT COUNT(*) FROM sys.partition_functions) + (SELECT COUNT(*) FROM sys.partition_schemes);
INSERT @checks VALUES ('C5', CASE WHEN @d IS NULL AND @nonpk = 0 AND @pk = 9 AND @parts = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Inventory: no views, procedures, functions, triggers, sequences or synonyms; only the 9 clustered PK indexes; no partition function or scheme',
    CONCAT(N'other objects: ', ISNULL(@d, N'none'), N'; clustered PK indexes: ', @pk, N'; non-PK indexes: ', @nonpk, N'; partition functions+schemes: ', @parts));

/* ---------- C6 CHECK state, compatibility level, marker ---------- */
SET @d = NULL;
SELECT @d = STRING_AGG(CONVERT(NVARCHAR(4000), CONCAT(name, ' disabled=', is_disabled, ' not_trusted=', is_not_trusted)), '; ')
FROM sys.check_constraints WHERE is_disabled = 1 OR is_not_trusted = 1;
DECLARE @compat INT = (SELECT compatibility_level FROM sys.databases WHERE name = DB_NAME());
DECLARE @marker NVARCHAR(200) = (SELECT CONVERT(NVARCHAR(200), value) FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable');
INSERT @checks VALUES ('C6', CASE WHEN @d IS NULL AND @compat = 160 AND @marker IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
    N'All 13 CHECK constraints enabled and trusted; compatibility level 160; P3_Disposable marker present',
    CONCAT(N'untrusted/disabled: ', ISNULL(@d, N'none'), N'; compatibility_level=', @compat, N'; marker=', ISNULL(@marker, N'(missing)')));

/* ---------- report ---------- */
SELECT check_id, result, descr, detail FROM @checks ORDER BY seq;

PRINT '-- catalog listing: constraints (type, name, table, keys/columns/definition) --';
SELECT a.typ, a.name, a.tbl, CASE WHEN a.typ = 'C' THEN (SELECT definition FROM sys.check_constraints WHERE name = a.name)
                                  WHEN a.typ = 'D' THEN CONCAT(a.info, ' = ', (SELECT definition FROM sys.default_constraints WHERE name = a.name))
                                  ELSE a.info END AS detail
FROM @acons AS a ORDER BY a.tbl, a.typ, a.name;

DECLARE @fails INT = (SELECT COUNT(*) FROM @checks WHERE result = 'FAIL');
DECLARE @nchecks INT = (SELECT COUNT(*) FROM @checks);
PRINT CONCAT('T-SCH-02 SUMMARY: checks=', @nchecks, ' FAIL=', @fails);
IF @fails > 0
BEGIN
    PRINT 'T-SCH-02_RESULT: FAIL';
    THROW 51041, N'T-SCH-02 failed (see the check table).', 1;
END
ELSE
    PRINT 'T-SCH-02_RESULT: PASS';
GO
