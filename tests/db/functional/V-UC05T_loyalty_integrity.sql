/* =====================================================================
   V-UC05T_loyalty_integrity.sql - TEST_ONLY (sqlcmd mode), read-only
   Work order : WO-P3-P3-01 task 2 and WO-P3-P3-02. Successor of V-UC05T (which stays the evidence of
   run UC05S-RUN__20261109-1447) for databases that also carry F002T (tiers), F003H (paid history),
   U0 and the loyalty routines. Same checks U1-U7 and U10; U6 excludes exactly the TEST_ONLY history
   invoices listed in TEST_HistoryInvoice (they never pass through the hooks); U8 and U9 cover the tier
   fixture and use an allowed-object list instead of exact counts.
   Tier correctness against an independent oracle is T-REC-04 (tests/db/reconciliation/T-REC_loyalty.sql).
   Whole-database checks:
     U1  V-TOT: every header = sum of its lines; every invoice has a line (BR12); no orphan line
     U2  payment-state rows: PAID <=> PaidAt set; PAID => method set and PaidAt >= IssuedAt;
         status and method literals exact (D-004, D-005)
     U3  spending reconciliation with an INDEPENDENT month oracle (AT TIME ZONE
         'SE Asia Standard Time'): for every (member, month) the MEMBER_MONTHLY_SPENDING row
         equals the PAID invoices of that local month (TotalSpend = sum FinalAmount,
         UpdatedAt = latest PaidAt), and no row exists without PAID invoices (D-006, D-013)
     U4  PointsEarned = FLOOR(TotalSpend / 100000) on every row; amounts >= 0 (D-006)
     U5  every member: CurrentPoints = sum of PointsEarned (D-024 accrual invariant)
     U6  hook calls: every PAID invoice has exactly one inventory and one entitlement call,
         inventory first, both inside a transaction and while the invoice was PENDING;
         no hook call for a non-PAID invoice; no fault request left (D-012 (a); T-F05-21)
     U7  CANCELLED and PENDING invoices have no PaidAt and no spending effect (covered by
         U2/U3) and no entitlement or PT value on any service line (DEP-06)
     U8  TEST_ONLY fixtures: exact F001U key rows; MEMBER = key + CurrentPoints (F002P);
         the other four fixtures key-only
     U9  no leftover trigger, principal or permission; object inventory as deployed
         (5 procedures, 1 function, 2 table types, 11 tables, no non-PK index)
     U10 every CHECK and FOREIGN KEY constraint enabled and trusted
   Run: sqlcmd -S localhost -E -I -b -W -d FitLife_P3_UC05 -i tests/db/functional/V-UC05T_loyalty_integrity.sql
   ===================================================================== */
:on error exit
SET NOCOUNT ON;

IF DB_NAME() <> N'FitLife_P3_UC05'
    THROW 51242, N'V-UC05T runs only in FitLife_P3_UC05.', 1;

DECLARE @checks TABLE (seq int IDENTITY(1,1), check_id varchar(4), result varchar(4), descr nvarchar(300), detail nvarchar(2000));
DECLARE @n int, @n2 int, @n3 int, @n4 int;
IF OBJECT_ID(N'dbo.MEMBER_TIER', N'U') IS NULL OR OBJECT_ID(N'dbo.TEST_HistoryInvoice', N'U') IS NULL
    THROW 51244, N'V-UC05T needs F002T and F003H.', 1;

/* U1 */
WITH s AS (SELECT Invoice_ID, SUM(UnitPrice) AS g, SUM(DiscountAmount) AS d, COUNT(*) AS n FROM dbo.INVOICE_SERVICE_ITEM GROUP BY Invoice_ID),
     p AS (SELECT Invoice_ID, SUM(UnitPrice * Quantity) AS g, SUM(DiscountAmount) AS d, COUNT(*) AS n FROM dbo.INVOICE_PRODUCT_ITEM GROUP BY Invoice_ID)
SELECT @n = COUNT(*) FROM dbo.INVOICE AS i LEFT JOIN s ON s.Invoice_ID = i.Invoice_ID LEFT JOIN p ON p.Invoice_ID = i.Invoice_ID
WHERE i.GrossAmount <> ISNULL(s.g, 0) + ISNULL(p.g, 0) OR i.DiscountAmount <> ISNULL(s.d, 0) + ISNULL(p.d, 0)
   OR i.FinalAmount <> i.GrossAmount - i.DiscountAmount OR ISNULL(s.n, 0) + ISNULL(p.n, 0) = 0;
SELECT @n2 = (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM AS x WHERE NOT EXISTS (SELECT 1 FROM dbo.INVOICE AS i WHERE i.Invoice_ID = x.Invoice_ID))
           + (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM AS x WHERE NOT EXISTS (SELECT 1 FROM dbo.INVOICE AS i WHERE i.Invoice_ID = x.Invoice_ID));
INSERT @checks VALUES ('U1', CASE WHEN @n = 0 AND @n2 = 0 THEN 'PASS' ELSE 'FAIL' END, N'V-TOT: header = sum of lines, Final = Gross - Discount, at least one line (D-023 X1, BR12); no orphan line', CONCAT(N'V-TOT rows: ', @n, N'; orphan lines: ', @n2));

/* U2 */
SELECT @n = COUNT(*) FROM dbo.INVOICE
WHERE PaymentStatus COLLATE Latin1_General_BIN2 NOT IN ('PENDING', 'PAID', 'CANCELLED')
   OR (PaymentStatus = 'PAID' AND (PaidAt IS NULL OR PaymentMethod IS NULL OR PaidAt < IssuedAt))
   OR (PaymentStatus <> 'PAID' AND PaidAt IS NOT NULL)
   OR (PaymentMethod IS NOT NULL AND (PaymentMethod COLLATE Latin1_General_BIN2 NOT IN ('CASH', 'VNPAY', 'CARD') OR DATALENGTH(PaymentMethod) <> LEN(PaymentMethod)))
   OR PaidAt > DATEADD(SECOND, 5, SYSUTCDATETIME()) OR IssuedAt > DATEADD(SECOND, 5, SYSUTCDATETIME());
INSERT @checks VALUES ('U2', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, N'Payment state: PAID <=> PaidAt set; PAID => method set, PaidAt >= IssuedAt; exact literals; no future UTC time (D-004, D-005)', CONCAT(N'violations: ', @n));

/* U3 (independent oracle for the local month) */
WITH paid AS (
    SELECT i.Member_ID,
           DATEFROMPARTS(YEAR(l.loc), MONTH(l.loc), 1) AS SpendingMonth,
           i.FinalAmount, i.PaidAt
    FROM dbo.INVOICE AS i
    CROSS APPLY (SELECT CONVERT(datetime2(3), (i.PaidAt AT TIME ZONE 'UTC') AT TIME ZONE 'SE Asia Standard Time') AS loc) AS l
    WHERE i.PaymentStatus = 'PAID'),
agg AS (SELECT Member_ID, SpendingMonth, SUM(FinalAmount) AS total, MAX(PaidAt) AS last_paid, COUNT(*) AS n FROM paid GROUP BY Member_ID, SpendingMonth)
SELECT @n = COUNT(*), @n2 = SUM(CASE WHEN m.Member_ID IS NULL THEN 1 ELSE 0 END), @n3 = SUM(CASE WHEN a.Member_ID IS NULL THEN 1 ELSE 0 END)
FROM agg AS a FULL OUTER JOIN dbo.MEMBER_MONTHLY_SPENDING AS m ON m.Member_ID = a.Member_ID AND m.SpendingMonth = a.SpendingMonth
WHERE m.Member_ID IS NULL OR a.Member_ID IS NULL OR m.TotalSpend <> a.total OR m.UpdatedAt <> a.last_paid;
SELECT @n4 = COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING;
INSERT @checks VALUES ('U3', CASE WHEN ISNULL(@n, 0) = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Spending reconciliation (independent month oracle): each MEMBER_MONTHLY_SPENDING row = PAID invoices of that Asia/Ho_Chi_Minh month (TotalSpend, UpdatedAt = latest PaidAt); no row without PAID invoices; no PAID invoice without its row',
    CONCAT(N'mismatched member-months: ', ISNULL(@n, 0), N' (missing row: ', ISNULL(@n2, 0), N'; row without PAID invoices: ', ISNULL(@n3, 0), N'); spending rows: ', @n4));

/* U4 */
SELECT @n = COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING WHERE PointsEarned <> CONVERT(int, FLOOR(TotalSpend / 100000)) OR TotalSpend < 0 OR PointsEarned < 0 OR DAY(SpendingMonth) <> 1;
INSERT @checks VALUES ('U4', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, N'PointsEarned = FLOOR(TotalSpend / 100000) on every row; non-negative; first day of month (D-006, D-013)', CONCAT(N'violations: ', @n));

/* U5 */
SELECT @n = COUNT(*), @n2 = SUM(ISNULL(x.pe, 0)), @n3 = SUM(mb.CurrentPoints)
FROM dbo.MEMBER AS mb
OUTER APPLY (SELECT SUM(PointsEarned) AS pe FROM dbo.MEMBER_MONTHLY_SPENDING AS s WHERE s.Member_ID = mb.Member_ID) AS x;
SELECT @n4 = COUNT(*) FROM dbo.MEMBER AS mb
WHERE mb.CurrentPoints <> ISNULL((SELECT SUM(PointsEarned) FROM dbo.MEMBER_MONTHLY_SPENDING AS s WHERE s.Member_ID = mb.Member_ID), 0) OR mb.CurrentPoints < 0;
INSERT @checks VALUES ('U5', CASE WHEN @n4 = 0 THEN 'PASS' ELSE 'FAIL' END, N'Every member: CurrentPoints = sum of PointsEarned over all months (D-024; no lost or duplicated points)',
    CONCAT(N'members: ', @n, N'; mismatching members: ', @n4, N'; sum CurrentPoints ', @n3, N' = sum PointsEarned ', @n2));

/* U6 */
WITH h AS (
    SELECT i.Invoice_ID, i.PaymentStatus,
           SUM(CASE WHEN l.HookName = 'INVENTORY_DECREMENT' THEN 1 ELSE 0 END) AS inv_calls,
           SUM(CASE WHEN l.HookName = 'ENTITLEMENT_ACTIVATION' THEN 1 ELSE 0 END) AS ent_calls,
           MIN(CASE WHEN l.HookName = 'INVENTORY_DECREMENT' THEN l.Seq END) AS inv_seq,
           MIN(CASE WHEN l.HookName = 'ENTITLEMENT_ACTIVATION' THEN l.Seq END) AS ent_seq,
           SUM(CASE WHEN l.Seq IS NOT NULL AND (l.StatusSeen IS NULL OR l.StatusSeen <> 'PENDING' OR l.TranCount < 1) THEN 1 ELSE 0 END) AS bad_ctx
           , MAX(CASE WHEN hi.Invoice_ID IS NULL THEN 0 ELSE 1 END) AS hist
    FROM dbo.INVOICE AS i LEFT JOIN dbo.TEST_HookCallLog AS l ON l.Invoice_ID = i.Invoice_ID
    LEFT JOIN dbo.TEST_HistoryInvoice AS hi ON hi.Invoice_ID = i.Invoice_ID
    GROUP BY i.Invoice_ID, i.PaymentStatus)
SELECT @n = SUM(CASE WHEN hist = 0 AND PaymentStatus = 'PAID' AND (inv_calls <> 1 OR ent_calls <> 1 OR inv_seq > ent_seq) THEN 1 ELSE 0 END)
          + SUM(CASE WHEN hist = 1 AND (PaymentStatus <> 'PAID' OR inv_calls + ent_calls > 0) THEN 1 ELSE 0 END),
       @n2 = SUM(CASE WHEN PaymentStatus <> 'PAID' AND inv_calls + ent_calls > 0 THEN 1 ELSE 0 END),
       @n3 = SUM(bad_ctx)
FROM h;
SELECT @n4 = (SELECT COUNT(*) FROM dbo.TEST_HookFault)
           + (SELECT COUNT(*) FROM dbo.TEST_HookCallLog AS l WHERE NOT EXISTS (SELECT 1 FROM dbo.INVOICE AS i WHERE i.Invoice_ID = l.Invoice_ID));
INSERT @checks VALUES ('U6', CASE WHEN ISNULL(@n, 0) = 0 AND ISNULL(@n2, 0) = 0 AND ISNULL(@n3, 0) = 0 AND @n4 = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Hooks (test doubles): exactly one inventory then one entitlement call per settled PAID invoice, inside the transaction while PENDING; none for other invoices and none for TEST_ONLY history invoices; no fault request left',
    CONCAT(N'PAID invoices with wrong calls: ', ISNULL(@n, 0), N'; non-PAID invoices with calls: ', ISNULL(@n2, 0), N'; calls outside the expected context: ', ISNULL(@n3, 0),
           N'; leftover faults or unknown invoices: ', @n4, N'; calls logged: ', (SELECT COUNT(*) FROM dbo.TEST_HookCallLog)));

/* U7 */
SET @n = (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM WHERE ValidFrom IS NOT NULL OR ValidUntil IS NOT NULL OR PTSessionsRemaining IS NOT NULL);
INSERT @checks VALUES ('U7', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, N'No entitlement or PT value written by P3 or the doubles (DEP-06)', CONCAT(N'service lines with a value: ', @n));

/* U8 */
SELECT @n = CASE WHEN (SELECT COUNT(*) FROM dbo.MEMBER) = 40 AND (SELECT MIN(Member_ID) FROM dbo.MEMBER) = 1 AND (SELECT MAX(Member_ID) FROM dbo.MEMBER) = 40
                  AND (SELECT COUNT(*) FROM dbo.EMPLOYEE) = 6 AND (SELECT MIN(Employee_ID) FROM dbo.EMPLOYEE) = 1 AND (SELECT MAX(Employee_ID) FROM dbo.EMPLOYEE) = 6
                  AND (SELECT COUNT(*) FROM dbo.BRANCH) = 3 AND (SELECT MIN(Branch_ID) FROM dbo.BRANCH) = 1 AND (SELECT MAX(Branch_ID) FROM dbo.BRANCH) = 3
                  AND (SELECT COUNT(*) FROM dbo.SERVICE_PLAN) = 5 AND (SELECT MIN(Plan_ID) FROM dbo.SERVICE_PLAN) = 1 AND (SELECT MAX(Plan_ID) FROM dbo.SERVICE_PLAN) = 5
                  AND (SELECT COUNT(*) FROM dbo.PRODUCT) = 10 AND (SELECT MIN(Product_ID) FROM dbo.PRODUCT) = 1 AND (SELECT MAX(Product_ID) FROM dbo.PRODUCT) = 10
             THEN 0 ELSE 1 END,
       @n2 = (SELECT COUNT(*) FROM sys.columns WHERE object_id IN (OBJECT_ID(N'dbo.EMPLOYEE'), OBJECT_ID(N'dbo.BRANCH'), OBJECT_ID(N'dbo.SERVICE_PLAN'), OBJECT_ID(N'dbo.PRODUCT'))),
       @n3 = CASE WHEN (SELECT STRING_AGG(CONVERT(nvarchar(400), CONCAT(c.name, ':', TYPE_NAME(c.user_type_id), ':', c.is_nullable)), ',') WITHIN GROUP (ORDER BY c.column_id)
                        FROM sys.columns AS c WHERE c.object_id = OBJECT_ID(N'dbo.MEMBER')) = N'Member_ID:int:0,CurrentPoints:int:0,Tier_ID:int:0' THEN 0 ELSE 1 END;
SET @n4 = CASE WHEN (SELECT COUNT(*) FROM dbo.MEMBER_TIER) = 3
                AND (SELECT COUNT(*) FROM dbo.MEMBER_TIER WHERE SpendingThreshold = 0 AND Tier_Name = N'Silver') = 1
                AND (SELECT SpendingThreshold FROM dbo.MEMBER_TIER WHERE Tier_Name = N'Gold') > 0
                AND (SELECT SpendingThreshold FROM dbo.MEMBER_TIER WHERE Tier_Name = N'Platinum') > (SELECT SpendingThreshold FROM dbo.MEMBER_TIER WHERE Tier_Name = N'Gold')
           THEN 0 ELSE 1 END;
INSERT @checks VALUES ('U8', CASE WHEN @n = 0 AND @n2 = 4 AND @n3 = 0 AND @n4 = 0 THEN 'PASS' ELSE 'FAIL' END, N'TEST_ONLY fixtures: exact F001U key rows; MEMBER = Member_ID + CurrentPoints (F002P) + Tier_ID (F002T); MEMBER_TIER = Silver 0 + Gold + Platinum (synthetic, increasing); other fixtures key-only',
    CONCAT(N'key rows as loaded: ', CASE WHEN @n = 0 THEN N'yes' ELSE N'NO' END, N'; key-only fixture columns: ', @n2, N'/4; MEMBER columns as expected: ', CASE WHEN @n3 = 0 THEN N'yes' ELSE N'NO' END,
           N'; tier fixture as expected: ', CASE WHEN @n4 = 0 THEN N'yes' ELSE N'NO' END));

/* U9 */
DECLARE @unexpected nvarchar(2000) = (
    SELECT STRING_AGG(CONVERT(nvarchar(2000), CONCAT(o.type COLLATE DATABASE_DEFAULT, ':', o.name)), ', ')
    FROM sys.objects AS o
    WHERE o.is_ms_shipped = 0 AND o.parent_object_id = 0 AND o.type NOT IN ('TT')
      AND NOT ((o.type = 'U' AND o.name IN (N'INVOICE', N'INVOICE_SERVICE_ITEM', N'INVOICE_PRODUCT_ITEM', N'MEMBER_MONTHLY_SPENDING', N'MEMBER', N'BRANCH', N'EMPLOYEE',
                                            N'SERVICE_PLAN', N'PRODUCT', N'MEMBER_TIER', N'TEST_HookCallLog', N'TEST_HookFault', N'TEST_HistoryInvoice'))
            OR (o.type = 'P' AND o.name IN (N'usp_P3_CreateInvoice', N'usp_P3_SettleInvoice', N'usp_P3_CancelInvoice', N'usp_P3_SettleInvoice_Baseline',
                                            N'usp_P3_EvaluateTiers', N'usp_P3_GetMemberLoyalty', N'usp_HOOK_InventoryDecrementForInvoice',
                                            N'usp_HOOK_EntitlementActivationForInvoice', N'TEST_p3_AddPaidHistory'))
            OR (o.type = 'IF' AND o.name IN (N'tvf_P3_SpendingMonth', N'tvf_P3_TierWindow', N'tvf_P3_TierForSpend'))));
DECLARE @missing int = CASE WHEN OBJECT_ID(N'dbo.usp_P3_CreateInvoice', N'P') IS NULL OR OBJECT_ID(N'dbo.usp_P3_SettleInvoice', N'P') IS NULL
                              OR OBJECT_ID(N'dbo.usp_P3_CancelInvoice', N'P') IS NULL OR OBJECT_ID(N'dbo.tvf_P3_SpendingMonth', N'IF') IS NULL
                              OR OBJECT_ID(N'dbo.usp_P3_SettleInvoice_Baseline', N'P') IS NULL THEN 1 ELSE 0 END;
SELECT @n = (SELECT COUNT(*) FROM sys.triggers),
       @n2 = (SELECT COUNT(*) FROM sys.database_principals WHERE principal_id > 4 AND is_fixed_role = 0 AND name NOT IN (N'public'))
           + (SELECT COUNT(*) FROM sys.database_permissions WHERE class IN (1, 6) AND grantee_principal_id > 4),
       @n3 = (SELECT COUNT(*) FROM sys.indexes AS i JOIN sys.tables AS t ON t.object_id = i.object_id WHERE t.is_ms_shipped = 0 AND i.type > 0 AND i.is_primary_key = 0)
           + ABS((SELECT COUNT(*) FROM sys.table_types WHERE is_user_defined = 1) - 2);
INSERT @checks VALUES ('U9', CASE WHEN @n = 0 AND @n2 = 0 AND @n3 = 0 AND @unexpected IS NULL AND @missing = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'No leftover TEST_ONLY trigger, principal or permission; only allowed objects (P3 routines, U0 reference, loyalty routines, fixtures, TEST_ONLY doubles/helper); no non-PK index',
    CONCAT(N'triggers: ', @n, N'; extra principals/permissions: ', @n2, N'; non-PK indexes / type deviations: ', @n3, N'; unexpected objects: ', ISNULL(@unexpected, N'none'),
           N'; core objects missing: ', @missing));

/* U10 */
SET @n = (SELECT COUNT(*) FROM sys.check_constraints WHERE is_disabled = 1 OR is_not_trusted = 1) + (SELECT COUNT(*) FROM sys.foreign_keys WHERE is_disabled = 1 OR is_not_trusted = 1);
INSERT @checks VALUES ('U10', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, N'All CHECK and FOREIGN KEY constraints enabled and trusted', CONCAT(N'disabled or untrusted: ', @n));

SELECT check_id, result, descr, detail FROM @checks ORDER BY seq;
SELECT (SELECT COUNT(*) FROM dbo.INVOICE) AS invoices,
       (SELECT COUNT(*) FROM dbo.INVOICE WHERE PaymentStatus = 'PENDING') AS pending,
       (SELECT COUNT(*) FROM dbo.INVOICE WHERE PaymentStatus = 'PAID') AS paid,
       (SELECT COUNT(*) FROM dbo.INVOICE WHERE PaymentStatus = 'CANCELLED') AS cancelled,
       (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING) AS spending_rows,
       (SELECT ISNULL(SUM(CurrentPoints), 0) FROM dbo.MEMBER) AS total_points,
       (SELECT COUNT(*) FROM dbo.TEST_HookCallLog) AS hook_calls;

DECLARE @fails int = (SELECT COUNT(*) FROM @checks WHERE result = 'FAIL'), @nchecks int = (SELECT COUNT(*) FROM @checks);
PRINT CONCAT('V-UC05T SUMMARY: checks=', @nchecks, ' FAIL=', @fails);
IF @fails > 0
BEGIN
    PRINT 'V-UC05T_RESULT: FAIL';
    THROW 51243, N'V-UC05T failed (see the check table).', 1;
END
ELSE
    PRINT 'V-UC05T_RESULT: PASS';
GO
