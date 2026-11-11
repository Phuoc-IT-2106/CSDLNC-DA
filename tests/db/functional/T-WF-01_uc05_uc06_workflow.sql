/* =====================================================================
   T-WF-01_uc05_uc06_workflow.sql - TEST_ONLY (sqlcmd mode)
   Work order : WO-P3-P3-03 Part C (correctness scope; amendment of 2026-11-10). Integrated Person 3
                workflow, checked on the FINAL DATABASE STATE (not on return codes alone):
                  invoice creation -> settlement / cancellation -> monthly spending -> loyalty points
                  -> tier evaluation -> revenue reports
   Uses only the approved, unchanged routines; changes no routine, table or setting; creates no object.
   Members 1-10 (must have no invoice, spending row or point when the script starts). Branches 1-3.
   Tier thresholds are read from MEMBER_TIER (TEST_ONLY synthetic values of F002T; D-008 values are not
   approved); every amount below is derived from them, nothing is hard-coded as a business threshold.
     W1  every header = sum of its lines (D-023); every invoice has a line (BR12)
     W2  settlement at most once per invoice: one SETTLED response per PAID invoice, repeats ALREADY_SETTLED
         with 0 points and the stored PaidAt; one inventory + one entitlement hook call per PAID invoice, none
         for failed, cancelled, pending or rolled-back attempts
     W3  PAID => PaidAt set, >= IssuedAt, inside the run window, method set; PENDING/CANCELLED => PaidAt NULL
     W4  CANCELLED and PENDING invoices contribute nothing to spending, points or revenue
     W5  monthly spending = SUM(FinalAmount) of PAID invoices per member and local month (independent oracle
         AT TIME ZONE 'SE Asia Standard Time'), exactly once; no row without a PAID invoice
     W6  points (D-006): PointsEarned = FLOOR(TotalSpend / 100000) of the MONTHLY total; CurrentPoints =
         SUM(PointsEarned) = SUM of the increments returned = literal expectation per member
     W7  tier (D-007 window, D-008 rule, D-009 batch): Tier_ID = literal expectation (threshold inclusive,
         threshold - 0.01 stays below) = independent oracle from INVOICE; second batch run changes nothing
     W8  revenue = PAID only, FinalAmount, PaidAt, Branch_ID: per branch and company = the harness's own
         amounts (literal), not the PENDING or CANCELLED amounts
     W9  every report routine = independent reference (AT TIME ZONE; DATEDIFF quarter buckets); RPT-02 =
         sum of RPT-01; month revenue = SUM(MEMBER_MONTHLY_SPENDING.TotalSpend) of the month
     W10 unrelated state unchanged: shared fixture tables, other members' rows, other invoices, lines and
         spending rows; MEMBER rows of members 1-10 differ only in CurrentPoints / Tier_ID
     W11 failure injection: a hook fault (inventory, then entitlement), a method mismatch and a caller
         transaction rolled back after create + settle leave no partial state
   Run: sqlcmd -S localhost -E -I -b -W -d FitLife_P3_UC05 -i tests/db/functional/T-WF-01_uc05_uc06_workflow.sql
   ===================================================================== */
:on error exit
SET NOCOUNT ON;
SET XACT_ABORT OFF;
IF DB_NAME() <> N'FitLife_P3_UC05'
   OR NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable' AND CONVERT(nvarchar(200), value) LIKE N'WO-P3-P3-00%')
    THROW 51600, N'T-WF-01 runs only in FitLife_P3_UC05 carrying the disposable marker.', 1;
IF OBJECT_ID(N'dbo.usp_P3_CreateInvoice', N'P') IS NULL OR OBJECT_ID(N'dbo.usp_P3_SettleInvoice', N'P') IS NULL OR OBJECT_ID(N'dbo.usp_P3_CancelInvoice', N'P') IS NULL
   OR OBJECT_ID(N'dbo.usp_P3_EvaluateTiers', N'P') IS NULL OR OBJECT_ID(N'dbo.usp_P3_RptSystemRevenueByPeriod', N'P') IS NULL OR OBJECT_ID(N'dbo.TEST_HookFault', N'U') IS NULL
    THROW 51601, N'T-WF-01: UC05/UC06 routines, tiers or hook doubles not deployed.', 1;
IF EXISTS (SELECT 1 FROM dbo.INVOICE WHERE Member_ID BETWEEN 1 AND 10) OR EXISTS (SELECT 1 FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID BETWEEN 1 AND 10)
   OR EXISTS (SELECT 1 FROM dbo.MEMBER WHERE Member_ID BETWEEN 1 AND 10 AND (CurrentPoints <> 0 OR Tier_ID <> (SELECT Tier_ID FROM dbo.MEMBER_TIER WHERE SpendingThreshold = 0)))
    THROW 51602, N'T-WF-01 expects members 1-10 without invoices, spending or points, on the base tier.', 1;
IF MONTH(DATEADD(MINUTE, 10, DATEADD(HOUR, 7, SYSUTCDATETIME()))) <> MONTH(DATEADD(HOUR, 7, SYSUTCDATETIME()))
    THROW 51603, N'T-WF-01: too close to a local month boundary; run again later.', 1;
IF EXISTS (SELECT 1 FROM dbo.TEST_HookFault)
    THROW 51604, N'T-WF-01: TEST_HookFault must be empty.', 1;

DECLARE @silver int = (SELECT Tier_ID FROM dbo.MEMBER_TIER WHERE SpendingThreshold = 0);
DECLARE @gold int = (SELECT Tier_ID FROM dbo.MEMBER_TIER WHERE Tier_Name = N'Gold'), @plat int = (SELECT Tier_ID FROM dbo.MEMBER_TIER WHERE Tier_Name = N'Platinum');
DECLARE @G decimal(18,2) = (SELECT SpendingThreshold FROM dbo.MEMBER_TIER WHERE Tier_ID = @gold), @P decimal(18,2) = (SELECT SpendingThreshold FROM dbo.MEMBER_TIER WHERE Tier_ID = @plat);
IF @G IS NULL OR @P IS NULL OR @G < 400000 OR @P < @G + 400000
    THROW 51605, N'T-WF-01 needs TEST_ONLY tiers Gold >= 400,000 and Platinum >= Gold + 400,000.', 1;
DECLARE @runStart datetime2(3) = SYSUTCDATETIME();
DECLARE @today date = CAST(DATEADD(HOUR, 7, @runStart) AS date);
DECLARE @m0 date = DATEFROMPARTS(YEAR(@today), MONTH(@today), 1), @m1 date = DATEADD(MONTH, 1, DATEFROMPARTS(YEAR(@today), MONTH(@today), 1));
DECLARE @y0 date = DATEFROMPARTS(YEAR(@today), 1, 1), @y1 date = DATEFROMPARTS(YEAR(@today) + 1, 1, 1);
PRINT CONCAT('T-WF-01 start (UTC) ', CONVERT(varchar(23), @runStart, 121), '; local date ', CONVERT(varchar(10), @today, 23),
             '; TEST_ONLY synthetic thresholds: Silver 0, Gold ', @G, ', Platinum ', @P);

CREATE TABLE #r (seq int IDENTITY(1,1), id varchar(6), result varchar(4), descr nvarchar(400), detail nvarchar(2000));

/* ---------- W10 before: hash of everything the workflow must not touch ---------- */
DECLARE @unrel nvarchar(max) = N'
SELECT @h = CONVERT(varchar(64), HASHBYTES(''SHA2_256'', CONCAT(
  (SELECT * FROM dbo.BRANCH ORDER BY Branch_ID FOR JSON PATH), ''|'',
  (SELECT * FROM dbo.EMPLOYEE ORDER BY Employee_ID FOR JSON PATH), ''|'',
  (SELECT * FROM dbo.SERVICE_PLAN ORDER BY Plan_ID FOR JSON PATH), ''|'',
  (SELECT * FROM dbo.PRODUCT ORDER BY Product_ID FOR JSON PATH), ''|'',
  (SELECT * FROM dbo.MEMBER_TIER ORDER BY Tier_ID FOR JSON PATH), ''|'',
  (SELECT * FROM dbo.MEMBER WHERE Member_ID NOT BETWEEN 1 AND 10 ORDER BY Member_ID FOR JSON PATH), ''|'',
  (SELECT Member_ID FROM dbo.MEMBER WHERE Member_ID BETWEEN 1 AND 10 ORDER BY Member_ID FOR JSON PATH), ''|'',
  (SELECT * FROM dbo.INVOICE WHERE Member_ID NOT BETWEEN 1 AND 10 ORDER BY Invoice_ID FOR JSON PATH), ''|'',
  (SELECT s.* FROM dbo.INVOICE_SERVICE_ITEM AS s JOIN dbo.INVOICE AS i ON i.Invoice_ID = s.Invoice_ID WHERE i.Member_ID NOT BETWEEN 1 AND 10 ORDER BY s.Invoice_ID, s.[LineNo] FOR JSON PATH), ''|'',
  (SELECT p.* FROM dbo.INVOICE_PRODUCT_ITEM AS p JOIN dbo.INVOICE AS i ON i.Invoice_ID = p.Invoice_ID WHERE i.Member_ID NOT BETWEEN 1 AND 10 ORDER BY p.Invoice_ID, p.[LineNo] FOR JSON PATH), ''|'',
  (SELECT * FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID NOT BETWEEN 1 AND 10 ORDER BY Member_ID, SpendingMonth FOR JSON PATH))), 2);';
DECLARE @hB varchar(64), @hA varchar(64);
EXEC sys.sp_executesql @unrel, N'@h varchar(64) OUTPUT', @h = @hB OUTPUT;
DECLARE @maxIdBefore int = ISNULL((SELECT MAX(Invoice_ID) FROM dbo.INVOICE), 0);

/* ---------- 1. Invoice creation (header + lines in one call) ---------- */
CREATE TABLE #def (ref varchar(4) PRIMARY KEY, member int, branch int, method varchar(10) NULL,
                   s_plan int NULL, s_price decimal(18,2) NULL, s_disc decimal(18,2) NULL,
                   p_prod int NULL, p_qty int NULL, p_price decimal(18,2) NULL, p_disc decimal(18,2) NULL,
                   exp_status varchar(10) NOT NULL, exp_final decimal(18,2) NULL);
INSERT #def (ref, member, branch, method, s_plan, s_price, s_disc, p_prod, p_qty, p_price, p_disc, exp_status) VALUES
 ('W01', 1, 1, NULL,    1, 60000, 0,               NULL, NULL, NULL, NULL,       'PAID'),      -- m1: 60,000
 ('W02', 1, 2, 'VNPAY', NULL, NULL, NULL,          1, 2, 30000, 0,               'PAID'),      -- m1: +60,000 = 120,000 -> 1 point (per-invoice floor would give 0)
 ('W03', 2, 1, NULL,    2, @G - 280000, 20000,     2, 3, 100000, 0,              'PAID'),      -- m2: mixed lines, final = Gold exactly -> Gold (inclusive)
 ('W04', 3, 2, NULL,    NULL, NULL, NULL,          3, 1, @G + 99.99, 100.00,     'PAID'),      -- m3: Gold - 0.01 -> Silver
 ('W05', 4, 2, NULL,    3, @P, 0,                  NULL, NULL, NULL, NULL,       'PAID'),      -- m4: Platinum
 ('W06', 4, 3, NULL,    NULL, NULL, NULL,          4, 5, 20000, 0,               'PAID'),      -- m4: +100,000
 ('W07', 5, 3, 'CARD',  NULL, NULL, NULL,          5, 1, @P + 1, 0,              'CANCELLED'), -- m5: large invoice cancelled -> contributes nothing
 ('W08', 5, 1, NULL,    4, 50000, 0,               NULL, NULL, NULL, NULL,       'PAID'),      -- m5: 50,000 -> 0 points
 ('W09', 6, 1, NULL,    NULL, NULL, NULL,          6, 2, @G, 0,                  'PENDING'),   -- m6: 2 x Gold left PENDING -> contributes nothing
 ('W10', 6, 3, NULL,    5, 100000, 0,              NULL, NULL, NULL, NULL,       'PAID'),      -- m6: 100,000 -> 1 point
 ('W11', 7, 2, NULL,    NULL, NULL, NULL,          7, 1, 260000, 10000,          'PAID'),      -- m7: 250,000, settled three times -> 2 points
 ('W12', 8, 3, NULL,    NULL, NULL, NULL,          8, 1, 99999.99, 0,            'PAID'),      -- m8: hook faults first; 99,999.99 -> 0 points
 ('W13', 8, 3, NULL,    1, 0.01, 0,                NULL, NULL, NULL, NULL,       'PAID'),      -- m8: +0.01 = 100,000.00 -> 1 point (monthly cumulative boundary)
 ('W14', 9, 1, 'CASH',  NULL, NULL, NULL,          9, 4, 100000, 0,              'PAID');      -- m9: method mismatch first; 400,000 -> 4 points
UPDATE #def SET exp_final = ISNULL(s_price - s_disc, 0) + ISNULL(p_qty * p_price - p_disc, 0);   -- the harness's own arithmetic (D-023)
CREATE TABLE #inv (ref varchar(4) PRIMARY KEY, Invoice_ID int NOT NULL);

DECLARE @svc dbo.tt_P3_InvoiceServiceLine, @prd dbo.tt_P3_InvoiceProductLine;
DECLARE @ref varchar(4), @member int, @branch int, @method varchar(10), @sPlan int, @sPrice decimal(18,2), @sDisc decimal(18,2),
        @pProd int, @pQty int, @pPrice decimal(18,2), @pDisc decimal(18,2), @newId int, @co varchar(20), @nCreateErr int = 0;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT ref, member, branch, method, s_plan, s_price, s_disc, p_prod, p_qty, p_price, p_disc FROM #def ORDER BY ref;
OPEN c;
FETCH NEXT FROM c INTO @ref, @member, @branch, @method, @sPlan, @sPrice, @sDisc, @pProd, @pQty, @pPrice, @pDisc;
WHILE @@FETCH_STATUS = 0
BEGIN
    DELETE @svc; DELETE @prd;
    IF @sPlan IS NOT NULL INSERT @svc ([LineNo], Plan_ID, UnitPrice, DiscountAmount) VALUES (1, @sPlan, @sPrice, @sDisc);
    IF @pProd IS NOT NULL INSERT @prd ([LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount) VALUES (1, @pProd, @pQty, @pPrice, @pDisc);
    BEGIN TRY
        EXEC dbo.usp_P3_CreateInvoice @Member_ID = @member, @Employee_ID = 1, @Branch_ID = @branch, @ServiceLines = @svc, @ProductLines = @prd,
             @PaymentMethod = @method, @Invoice_ID = @newId OUTPUT, @Outcome = @co OUTPUT;
        INSERT #inv VALUES (@ref, @newId);
    END TRY
    BEGIN CATCH
        SET @nCreateErr += 1; PRINT CONCAT('Creation of ', @ref, ' failed: ', ERROR_NUMBER(), ' ', ERROR_MESSAGE());
    END CATCH;
    FETCH NEXT FROM c INTO @ref, @member, @branch, @method, @sPlan, @sPrice, @sDisc, @pProd, @pQty, @pPrice, @pDisc;
END;
CLOSE c; DEALLOCATE c;
DECLARE @nInv int = (SELECT COUNT(*) FROM #inv), @nDef int = (SELECT COUNT(*) FROM #def);
PRINT CONCAT('Created ', @nInv, ' of ', @nDef, ' invoices through dbo.usp_P3_CreateInvoice');

/* ---------- 2. Settlement, cancellation, repeats and injected failures, in this order ---------- */
CREATE TABLE #op (seq int PRIMARY KEY, op char(1), ref varchar(4), arg varchar(30) NULL, exp_err int, exp_outcome varchar(20) NULL, exp_points int NULL, descr nvarchar(200));
INSERT #op VALUES
 ( 1, 'S', 'W01', 'CASH',  0, 'SETTLED', 0, N'first 60,000 of member 1 -> 0 points'),
 ( 2, 'S', 'W02', NULL,    0, 'SETTLED', 1, N'recorded method VNPAY used; cumulative 120,000 -> +1'),
 ( 3, 'S', 'W03', 'CARD',  0, 'SETTLED', CONVERT(int, FLOOR(@G / 100000)), N'final = Gold threshold'),
 ( 4, 'S', 'W04', 'CASH',  0, 'SETTLED', CONVERT(int, FLOOR((@G - 0.01) / 100000)), N'final = Gold threshold - 0.01'),
 ( 5, 'S', 'W05', 'CARD',  0, 'SETTLED', CONVERT(int, FLOOR(@P / 100000)), N'final = Platinum threshold'),
 ( 6, 'S', 'W06', 'CASH',  0, 'SETTLED', CONVERT(int, FLOOR((@P + 100000) / 100000)) - CONVERT(int, FLOOR(@P / 100000)), N'second invoice of member 4, other branch'),
 ( 7, 'C', 'W07', NULL,    0, 'CANCELLED', NULL, N'cancel a PENDING invoice'),
 ( 8, 'C', 'W07', NULL,    0, 'ALREADY_CANCELLED', NULL, N'repeat cancellation'),
 ( 9, 'S', 'W07', 'CARD',  51204, NULL, NULL, N'settle a CANCELLED invoice: rejected'),
 (10, 'S', 'W08', 'VNPAY', 0, 'SETTLED', 0, N'50,000 -> 0 points'),
 (11, 'S', 'W10', 'CASH',  0, 'SETTLED', 1, N'100,000 -> 1 point; W09 stays PENDING'),
 (12, 'S', 'W11', 'CASH',  0, 'SETTLED', 2, N'250,000 -> 2 points'),
 (13, 'S', 'W11', 'CASH',  0, 'ALREADY_SETTLED', 0, N'repeat settlement: no effect'),
 (14, 'S', 'W11', 'CARD',  0, 'ALREADY_SETTLED', 0, N'repeat with another method: no effect, method unchanged'),
 (15, 'C', 'W11', NULL,    51223, NULL, NULL, N'cancel a PAID invoice: rejected (no refund, D-011)'),
 (16, 'F', 'W12', 'INVENTORY_DECREMENT', 0, NULL, NULL, N'inject fault in the inventory hook'),
 (17, 'S', 'W12', 'CASH',  52901, NULL, NULL, N'settlement aborted by the inventory hook: nothing written'),
 (18, 'F', 'W12', 'ENTITLEMENT_ACTIVATION', 0, NULL, NULL, N'move the fault to the entitlement hook (after the inventory hook ran)'),
 (19, 'S', 'W12', 'CASH',  52902, NULL, NULL, N'settlement aborted by the entitlement hook: inventory call rolled back too'),
 (20, 'F', 'W12', NULL,    0, NULL, NULL, N'remove the fault'),
 (21, 'S', 'W12', 'CASH',  0, 'SETTLED', 0, N'retry after the failures: settled once; 99,999.99 -> 0 points'),
 (22, 'S', 'W13', 'CASH',  0, 'SETTLED', 1, N'+0.01 -> month total 100,000.00 -> +1'),
 (23, 'S', 'W14', 'VNPAY', 51208, NULL, NULL, N'method differs from the recorded CASH: rejected, nothing written'),
 (24, 'S', 'W14', NULL,    0, 'SETTLED', 4, N'retry with the recorded method: 400,000 -> 4 points');
CREATE TABLE #call (seq int PRIMARY KEY, err int, outcome varchar(20) NULL, points int NULL, paid_at datetime2(3) NULL, msg nvarchar(2048) NULL);

DECLARE @seq int, @op char(1), @arg varchar(30), @id int, @err int, @emsg nvarchar(2048), @outc varchar(20), @pa datetime2(3), @pe int, @cp int;
DECLARE o CURSOR LOCAL FAST_FORWARD FOR SELECT seq, op, ref, arg FROM #op ORDER BY seq;
OPEN o;
FETCH NEXT FROM o INTO @seq, @op, @ref, @arg;
WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @id = Invoice_ID FROM #inv WHERE ref = @ref;
    SELECT @err = 0, @emsg = NULL, @outc = NULL, @pa = NULL, @pe = NULL;
    BEGIN TRY
        IF @op = 'S' EXEC dbo.usp_P3_SettleInvoice @Invoice_ID = @id, @PaymentMethod = @arg, @Outcome = @outc OUTPUT, @PaidAt = @pa OUTPUT, @PointsEarned = @pe OUTPUT, @CurrentPoints = @cp OUTPUT;
        IF @op = 'C' EXEC dbo.usp_P3_CancelInvoice @Invoice_ID = @id, @Outcome = @outc OUTPUT;
        IF @op = 'F' BEGIN DELETE dbo.TEST_HookFault WHERE Invoice_ID = @id; IF @arg IS NOT NULL INSERT dbo.TEST_HookFault (HookName, Invoice_ID) VALUES (@arg, @id); END;
    END TRY
    BEGIN CATCH
        SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE();
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END CATCH;
    INSERT #call VALUES (@seq, @err, @outc, @pe, @pa, @emsg);
    FETCH NEXT FROM o INTO @seq, @op, @ref, @arg;
END;
CLOSE o; DEALLOCATE o;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

/* W11 (c): member 10 - create AND settle inside a caller transaction that is then rolled back */
DECLARE @w15 int, @w15Outc varchar(20), @w15Err int = 0, @w15Msg nvarchar(2048);
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE @svc; DELETE @prd;
    INSERT @prd ([LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount) VALUES (1, 10, 3, 150000, 0);
    INSERT @svc ([LineNo], Plan_ID, UnitPrice, DiscountAmount) VALUES (1, 2, 90000, 5000);
    EXEC dbo.usp_P3_CreateInvoice @Member_ID = 10, @Employee_ID = 2, @Branch_ID = 2, @ServiceLines = @svc, @ProductLines = @prd,
         @PaymentMethod = 'CASH', @Invoice_ID = @w15 OUTPUT, @Outcome = @co OUTPUT;
    EXEC dbo.usp_P3_SettleInvoice @Invoice_ID = @w15, @Outcome = @w15Outc OUTPUT;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @w15Err = ERROR_NUMBER(), @w15Msg = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
END CATCH;
PRINT CONCAT('W11c: caller transaction created invoice ', @w15, ' and settled it (', @w15Outc, '), then rolled back; error ', @w15Err);

/* ---------- 3. Tier evaluation (daily batch, D-009), small chunks, then a second run ---------- */
DECLARE @ev1 int, @up1 int, @dn1 int, @un1 int, @ev2 int, @up2 int, @dn2 int, @un2 int, @tErr int = 0, @tMsg nvarchar(2048);
BEGIN TRY
    EXEC dbo.usp_P3_EvaluateTiers @AsOfDate = @today, @ChunkSize = 3, @Evaluated = @ev1 OUTPUT, @Upgrades = @up1 OUTPUT, @Downgrades = @dn1 OUTPUT, @Unchanged = @un1 OUTPUT;
    EXEC dbo.usp_P3_EvaluateTiers @AsOfDate = @today, @ChunkSize = 3, @Evaluated = @ev2 OUTPUT, @Upgrades = @up2 OUTPUT, @Downgrades = @dn2 OUTPUT, @Unchanged = @un2 OUTPUT;
END TRY
BEGIN CATCH
    SELECT @tErr = ERROR_NUMBER(), @tMsg = ERROR_MESSAGE();
END CATCH;
DECLARE @runEnd datetime2(3) = SYSUTCDATETIME();
PRINT CONCAT('Tier batch run 1: evaluated ', @ev1, ', upgrades ', @up1, ', downgrades ', @dn1, '; run 2: upgrades ', @up2, ', downgrades ', @dn2, '; error ', @tErr);

/* ---------- 4. Revenue reports, captured through the routines ---------- */
CREATE TABLE #rb (Branch_ID int, FromDate date, ToDate date, Revenue decimal(38,2), InvoiceCount bigint);
CREATE TABLE #rs (FromDate date, ToDate date, Revenue decimal(38,2), InvoiceCount bigint);
CREATE TABLE #rbb (Branch_ID int, Revenue decimal(38,2), InvoiceCount bigint, SystemRevenue decimal(38,2), SystemInvoiceCount bigint, SharePct decimal(7,2));
CREATE TABLE #rbp (Branch_ID int NULL, Grain varchar(7) NULL, PeriodStart date, Revenue decimal(38,2), InvoiceCount bigint);
CREATE TABLE #rsp (Grain varchar(7) NULL, PeriodStart date, Branch_ID int, Revenue decimal(38,2), InvoiceCount bigint, PeriodSystemRevenue decimal(38,2), PeriodSystemInvoiceCount bigint);
DECLARE @b int = 1, @grain varchar(7);
WHILE @b <= 3
BEGIN
    INSERT #rb EXEC dbo.usp_P3_RptBranchRevenue @Branch_ID = @b, @FromDate = @m0, @ToDate = @m1;
    SET @b += 1;
END;
INSERT #rs EXEC dbo.usp_P3_RptSystemRevenue @FromDate = @m0, @ToDate = @m1;
INSERT #rbb EXEC dbo.usp_P3_RptSystemRevenueByBranch @FromDate = @m0, @ToDate = @m1;
DECLARE gr CURSOR LOCAL FAST_FORWARD FOR SELECT v FROM (VALUES ('DAY'), ('MONTH'), ('QUARTER'), ('YEAR')) AS x(v);
OPEN gr; FETCH NEXT FROM gr INTO @grain;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @b = 1;
    WHILE @b <= 3
    BEGIN
        INSERT #rbp (PeriodStart, Revenue, InvoiceCount) EXEC dbo.usp_P3_RptBranchRevenueByPeriod @Branch_ID = @b, @FromDate = @y0, @ToDate = @y1, @Grain = @grain;
        UPDATE #rbp SET Branch_ID = @b, Grain = @grain WHERE Branch_ID IS NULL;
        SET @b += 1;
    END;
    INSERT #rsp (PeriodStart, Branch_ID, Revenue, InvoiceCount, PeriodSystemRevenue, PeriodSystemInvoiceCount) EXEC dbo.usp_P3_RptSystemRevenueByPeriod @FromDate = @y0, @ToDate = @y1, @Grain = @grain;
    UPDATE #rsp SET Grain = @grain WHERE Grain IS NULL;
    FETCH NEXT FROM gr INTO @grain;
END;
CLOSE gr; DEALLOCATE gr;

/* ---------- Independent references (no routine under test is called) ---------- */
SELECT i.Invoice_ID, i.Member_ID, i.Branch_ID, i.FinalAmount,
       CONVERT(date, CONVERT(datetime2(3), (i.PaidAt AT TIME ZONE 'UTC') AT TIME ZONE 'SE Asia Standard Time')) AS LocalDate
INTO #paid
FROM dbo.INVOICE AS i WHERE i.PaymentStatus = 'PAID';
SELECT d.ref, d.member, d.branch, d.exp_status, d.exp_final, x.Invoice_ID, i.PaymentStatus, i.FinalAmount, i.GrossAmount, i.DiscountAmount,
       i.PaidAt, i.IssuedAt, i.PaymentMethod, i.Branch_ID, i.Member_ID
INTO #st
FROM #def AS d JOIN #inv AS x ON x.ref = d.ref JOIN dbo.INVOICE AS i ON i.Invoice_ID = x.Invoice_ID;
CREATE TABLE #expm (member int PRIMARY KEY, spend decimal(18,2), points int, tier int);
INSERT #expm VALUES
 (1, 120000, 1, @silver), (2, @G, CONVERT(int, FLOOR(@G / 100000)), @gold), (3, @G - 0.01, CONVERT(int, FLOOR((@G - 0.01) / 100000)), @silver),
 (4, @P + 100000, CONVERT(int, FLOOR((@P + 100000) / 100000)), @plat), (5, 50000, 0, @silver), (6, 100000, 1, @silver),
 (7, 250000, 2, @silver), (8, 100000, 1, @silver), (9, 400000, 4, @silver), (10, 0, 0, @silver);

DECLARE @n int, @n2 int, @n3 int, @detail nvarchar(2000);

/* W1 */
SELECT @n = COUNT(*) FROM dbo.INVOICE AS i
OUTER APPLY (SELECT SUM(UnitPrice) AS g, SUM(DiscountAmount) AS d, COUNT(*) AS c FROM dbo.INVOICE_SERVICE_ITEM WHERE Invoice_ID = i.Invoice_ID) AS s
OUTER APPLY (SELECT SUM(UnitPrice * Quantity) AS g, SUM(DiscountAmount) AS d, COUNT(*) AS c FROM dbo.INVOICE_PRODUCT_ITEM WHERE Invoice_ID = i.Invoice_ID) AS p
WHERE i.GrossAmount <> ISNULL(s.g, 0) + ISNULL(p.g, 0) OR i.DiscountAmount <> ISNULL(s.d, 0) + ISNULL(p.d, 0)
   OR i.FinalAmount <> i.GrossAmount - i.DiscountAmount OR s.c + p.c = 0;
SELECT @n2 = COUNT(*) FROM #st WHERE FinalAmount <> exp_final;
SET @n3 = (SELECT COUNT(*) FROM #inv);
INSERT #r VALUES ('W1', CASE WHEN @n = 0 AND @n2 = 0 AND @n3 = 14 AND @nCreateErr = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Every header = sum of its lines (all invoices of the database); FinalAmount = harness arithmetic for the 14 workflow invoices',
    CONCAT('header/line mismatches ', @n, '; FinalAmount <> harness ', @n2, '; created ', @n3, '/14; creation errors ', @nCreateErr));

/* W2 */
SELECT @n = COUNT(*) FROM #op AS o JOIN #call AS c ON c.seq = o.seq
WHERE c.err <> o.exp_err OR ISNULL(c.outcome, '-') <> ISNULL(o.exp_outcome, '-') OR (o.exp_points IS NOT NULL AND ISNULL(c.points, -1) <> o.exp_points);
SELECT @detail = STRING_AGG(CONVERT(nvarchar(max), CONCAT('op ', o.seq, ' ', o.ref, ': err ', c.err, ' outcome ', c.outcome, ' points ', c.points, ' (expected ', o.exp_err, ' ', o.exp_outcome, ' ', o.exp_points, ')')), '; ')
FROM #op AS o JOIN #call AS c ON c.seq = o.seq
WHERE c.err <> o.exp_err OR ISNULL(c.outcome, '-') <> ISNULL(o.exp_outcome, '-') OR (o.exp_points IS NOT NULL AND ISNULL(c.points, -1) <> o.exp_points);
SELECT @n2 = COUNT(*) FROM #st AS s
WHERE (SELECT COUNT(*) FROM #op AS o JOIN #call AS c ON c.seq = o.seq WHERE o.ref = s.ref AND o.op = 'S' AND c.outcome = 'SETTLED') <> CASE WHEN s.exp_status = 'PAID' THEN 1 ELSE 0 END
   OR EXISTS (SELECT 1 FROM #op AS o JOIN #call AS c ON c.seq = o.seq WHERE o.ref = s.ref AND c.outcome IN ('SETTLED', 'ALREADY_SETTLED') AND c.paid_at <> s.PaidAt)
   OR (SELECT COUNT(*) FROM dbo.TEST_HookCallLog AS h WHERE h.Invoice_ID = s.Invoice_ID AND h.HookName = 'INVENTORY_DECREMENT') <> CASE WHEN s.exp_status = 'PAID' THEN 1 ELSE 0 END
   OR (SELECT COUNT(*) FROM dbo.TEST_HookCallLog AS h WHERE h.Invoice_ID = s.Invoice_ID AND h.HookName = 'ENTITLEMENT_ACTIVATION') <> CASE WHEN s.exp_status = 'PAID' THEN 1 ELSE 0 END;
INSERT #r VALUES ('W2', CASE WHEN @n = 0 AND @n2 = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Settlement at most once: every call returned the expected outcome/error/points; one SETTLED per PAID invoice; repeats return the stored PaidAt; one call per hook per PAID invoice, none otherwise',
    CONCAT('unexpected call results ', @n, '; invoices violating once-only/hook rule ', @n2, ISNULL('; ' + @detail, '')));

/* W3 */
SELECT @n = COUNT(*) FROM #st WHERE PaymentStatus <> exp_status;
SELECT @n2 = COUNT(*) FROM dbo.INVOICE
WHERE (PaymentStatus = 'PAID' AND (PaidAt IS NULL OR PaidAt < IssuedAt OR PaymentMethod IS NULL))
   OR (PaymentStatus <> 'PAID' AND PaidAt IS NOT NULL);
SELECT @n3 = COUNT(*) FROM #st WHERE PaymentStatus = 'PAID' AND (PaidAt < @runStart OR PaidAt > @runEnd);
INSERT #r VALUES ('W3', CASE WHEN @n = 0 AND @n2 = 0 AND @n3 = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Final states as designed (12 PAID, 1 CANCELLED, 1 PENDING); PAID => PaidAt (UTC, inside the run, >= IssuedAt) and method; non-PAID => PaidAt NULL',
    CONCAT('state <> design ', @n, '; payment-state violations (whole db) ', @n2, '; PaidAt outside run window ', @n3,
           '; W14 method ', (SELECT PaymentMethod FROM #st WHERE ref = 'W14'), '; W11 method ', (SELECT PaymentMethod FROM #st WHERE ref = 'W11')));

/* W4 */
DECLARE @excl decimal(38,2) = (SELECT SUM(exp_final) FROM #def WHERE exp_status <> 'PAID');
SELECT @n = COUNT(*) FROM #st AS s WHERE s.exp_status <> 'PAID'
   AND (EXISTS (SELECT 1 FROM dbo.TEST_HookCallLog AS h WHERE h.Invoice_ID = s.Invoice_ID) OR s.PaidAt IS NOT NULL);
SELECT @n2 = COUNT(*) FROM #expm AS e JOIN dbo.MEMBER AS m ON m.Member_ID = e.member
WHERE ISNULL((SELECT SUM(TotalSpend) FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = e.member), 0) <> e.spend;
SET @n3 = (SELECT COUNT(*) FROM #rs WHERE Revenue = (SELECT SUM(exp_final) FROM #def) OR Revenue = (SELECT SUM(exp_final) FROM #def WHERE exp_status = 'PAID') + @excl);
INSERT #r VALUES ('W4', CASE WHEN @n = 0 AND @n2 = 0 AND @n3 = 0 AND @excl > 0 THEN 'PASS' ELSE 'FAIL' END,
    N'CANCELLED (W07) and PENDING (W09) invoices: no PaidAt, no hook call, no spending, no points, not in revenue',
    CONCAT('excluded amount ', @excl, '; non-PAID with effects ', @n, '; members whose spending differs from PAID-only expectation ', @n2, '; revenue including excluded amounts ', @n3));

/* W5 */
WITH o AS (SELECT Member_ID, DATEFROMPARTS(YEAR(LocalDate), MONTH(LocalDate), 1) AS m, SUM(FinalAmount) AS s FROM #paid GROUP BY Member_ID, DATEFROMPARTS(YEAR(LocalDate), MONTH(LocalDate), 1))
SELECT @n = COUNT(*) FROM o FULL JOIN dbo.MEMBER_MONTHLY_SPENDING AS t ON t.Member_ID = o.Member_ID AND t.SpendingMonth = o.m
WHERE o.Member_ID IS NULL OR t.Member_ID IS NULL OR o.s <> t.TotalSpend;
SELECT @n2 = COUNT(*) FROM #expm AS e
WHERE ISNULL((SELECT TotalSpend FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = e.member AND SpendingMonth = @m0), 0) <> e.spend
   OR (e.spend = 0 AND EXISTS (SELECT 1 FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = e.member));
INSERT #r VALUES ('W5', CASE WHEN @n = 0 AND @n2 = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Monthly spending = SUM(FinalAmount) of PAID invoices per member and local month (independent AT TIME ZONE oracle, whole db) = literal expectation for members 1-10',
    CONCAT('oracle mismatches (rows missing, extra or different) ', @n, '; literal mismatches ', @n2));

/* W6 */
SELECT @n = COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING WHERE PointsEarned <> CONVERT(int, FLOOR(TotalSpend / 100000));
SELECT @n2 = COUNT(*) FROM dbo.MEMBER AS m WHERE m.CurrentPoints <> ISNULL((SELECT SUM(PointsEarned) FROM dbo.MEMBER_MONTHLY_SPENDING AS s WHERE s.Member_ID = m.Member_ID), 0);
SELECT @n3 = COUNT(*) FROM #expm AS e JOIN dbo.MEMBER AS m ON m.Member_ID = e.member
WHERE m.CurrentPoints <> e.points
   OR m.CurrentPoints <> ISNULL((SELECT SUM(c.points) FROM #op AS o JOIN #call AS c ON c.seq = o.seq JOIN #def AS d ON d.ref = o.ref WHERE d.member = e.member AND c.outcome = 'SETTLED'), 0);
SELECT @detail = STRING_AGG(CONVERT(nvarchar(max), CONCAT('m', e.member, '=', m.CurrentPoints)), ', ') WITHIN GROUP (ORDER BY e.member) FROM #expm AS e JOIN dbo.MEMBER AS m ON m.Member_ID = e.member;
INSERT #r VALUES ('W6', CASE WHEN @n = 0 AND @n2 = 0 AND @n3 = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'D-006: PointsEarned = FLOOR(monthly TotalSpend / 100000) (member 1: 60,000 + 60,000 -> 1; member 8: 99,999.99 + 0.01 -> 1); CurrentPoints = SUM(PointsEarned) = SUM of returned increments = literal',
    CONCAT('rows with wrong PointsEarned ', @n, '; members with CurrentPoints <> SUM(PointsEarned) ', @n2, '; literal/returned mismatches ', @n3, '; points ', @detail));

/* W7 */
WITH o AS (SELECT m.Member_ID, ISNULL((SELECT SUM(p.FinalAmount) FROM #paid AS p WHERE p.Member_ID = m.Member_ID
                AND DATEFROMPARTS(YEAR(p.LocalDate), MONTH(p.LocalDate), 1) >= DATEADD(MONTH, -11, @m0) AND DATEFROMPARTS(YEAR(p.LocalDate), MONTH(p.LocalDate), 1) <= @m0), 0) AS s
           FROM dbo.MEMBER AS m)
SELECT @n = COUNT(*) FROM o JOIN dbo.MEMBER AS m ON m.Member_ID = o.Member_ID
WHERE m.Tier_ID <> (SELECT TOP (1) t.Tier_ID FROM dbo.MEMBER_TIER AS t WHERE t.SpendingThreshold <= o.s ORDER BY t.SpendingThreshold DESC);
SELECT @n2 = COUNT(*) FROM #expm AS e JOIN dbo.MEMBER AS m ON m.Member_ID = e.member WHERE m.Tier_ID <> e.tier;
SELECT @detail = STRING_AGG(CONVERT(nvarchar(max), CONCAT('m', e.member, '=', t.Tier_Name)), ', ') WITHIN GROUP (ORDER BY e.member)
FROM #expm AS e JOIN dbo.MEMBER AS m ON m.Member_ID = e.member JOIN dbo.MEMBER_TIER AS t ON t.Tier_ID = m.Tier_ID;
INSERT #r VALUES ('W7', CASE WHEN @n = 0 AND @n2 = 0 AND @tErr = 0 AND @up2 = 0 AND @dn2 = 0 AND @dn1 = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'D-007/D-008/D-009: after the batch, Tier_ID = literal (spend = Gold -> Gold; Gold - 0.01 -> Silver; >= Platinum -> Platinum) = independent oracle from INVOICE (every member); second run changes nothing',
    CONCAT('oracle mismatches ', @n, '; literal mismatches ', @n2, '; run 1 upgrades ', @up1, ' downgrades ', @dn1, '; run 2 upgrades ', @up2, ' downgrades ', @dn2, '; error ', @tErr, ' ', @tMsg, '; tiers ', @detail));

/* W8 */
WITH e AS (SELECT b.v AS Branch_ID, ISNULL(SUM(d.exp_final), 0) AS rev, COUNT(d.ref) AS cnt
           FROM (VALUES (1), (2), (3)) AS b(v) LEFT JOIN #def AS d ON d.branch = b.v AND d.exp_status = 'PAID' GROUP BY b.v)
SELECT @n = COUNT(*) FROM e LEFT JOIN #rb AS r ON r.Branch_ID = e.Branch_ID WHERE r.Branch_ID IS NULL OR r.Revenue <> e.rev OR r.InvoiceCount <> e.cnt;
SELECT @n2 = COUNT(*) FROM #rs WHERE Revenue <> (SELECT SUM(exp_final) FROM #def WHERE exp_status = 'PAID') OR InvoiceCount <> (SELECT COUNT(*) FROM #def WHERE exp_status = 'PAID');
SELECT @detail = STRING_AGG(CONVERT(nvarchar(max), CONCAT('branch ', Branch_ID, ' ', Revenue, ' (', InvoiceCount, ')')), '; ') WITHIN GROUP (ORDER BY Branch_ID) FROM #rb;
INSERT #r VALUES ('W8', CASE WHEN @n = 0 AND @n2 = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'D-010 revenue of the local month: per branch (RPT-01) and company (RPT-02) = the harness''s own FinalAmounts of PAID invoices by Branch_ID (literal)',
    CONCAT('branch mismatches ', @n, '; company mismatch ', @n2, '; company ', (SELECT Revenue FROM #rs), '; ', @detail));

/* W9 */
CREATE TABLE #ref (Grain varchar(7), Branch_ID int, PeriodStart date, Revenue decimal(38,2), InvoiceCount bigint);
INSERT #ref
SELECT g.Grain, p.Branch_ID,
       CASE g.Grain WHEN 'DAY' THEN p.LocalDate WHEN 'MONTH' THEN DATEADD(MONTH, DATEDIFF(MONTH, 0, p.LocalDate), 0)
                    WHEN 'QUARTER' THEN DATEADD(QUARTER, DATEDIFF(QUARTER, 0, p.LocalDate), 0) ELSE DATEADD(YEAR, DATEDIFF(YEAR, 0, p.LocalDate), 0) END,
       SUM(p.FinalAmount), COUNT_BIG(*)
FROM #paid AS p CROSS JOIN (VALUES ('DAY'), ('MONTH'), ('QUARTER'), ('YEAR')) AS g(Grain)
WHERE p.LocalDate >= @y0 AND p.LocalDate < @y1
GROUP BY g.Grain, p.Branch_ID,
       CASE g.Grain WHEN 'DAY' THEN p.LocalDate WHEN 'MONTH' THEN DATEADD(MONTH, DATEDIFF(MONTH, 0, p.LocalDate), 0)
                    WHEN 'QUARTER' THEN DATEADD(QUARTER, DATEDIFF(QUARTER, 0, p.LocalDate), 0) ELSE DATEADD(YEAR, DATEDIFF(YEAR, 0, p.LocalDate), 0) END;
DECLARE @v1 int, @v2 int, @v3 int, @v4 int, @v5 int, @v6 int;
SELECT @v1 = COUNT(*) FROM (SELECT Grain, Branch_ID, PeriodStart, Revenue, InvoiceCount FROM #rbp EXCEPT SELECT Grain, Branch_ID, PeriodStart, Revenue, InvoiceCount FROM #ref
                             UNION ALL SELECT Grain, Branch_ID, PeriodStart, Revenue, InvoiceCount FROM #ref EXCEPT SELECT Grain, Branch_ID, PeriodStart, Revenue, InvoiceCount FROM #rbp) AS x;
SELECT @v2 = COUNT(*) FROM (SELECT Grain, Branch_ID, PeriodStart, Revenue, InvoiceCount FROM #rsp EXCEPT SELECT Grain, Branch_ID, PeriodStart, Revenue, InvoiceCount FROM #ref
                             UNION ALL SELECT Grain, Branch_ID, PeriodStart, Revenue, InvoiceCount FROM #ref EXCEPT SELECT Grain, Branch_ID, PeriodStart, Revenue, InvoiceCount FROM #rsp) AS x;
SELECT @v3 = COUNT(*) FROM #rsp AS r WHERE r.PeriodSystemRevenue <> (SELECT SUM(Revenue) FROM #ref AS f WHERE f.Grain = r.Grain AND f.PeriodStart = r.PeriodStart)
                                       OR r.PeriodSystemInvoiceCount <> (SELECT SUM(InvoiceCount) FROM #ref AS f WHERE f.Grain = r.Grain AND f.PeriodStart = r.PeriodStart);
WITH mref AS (SELECT Branch_ID, SUM(FinalAmount) AS rev, COUNT_BIG(*) AS cnt FROM #paid WHERE LocalDate >= @m0 AND LocalDate < @m1 GROUP BY Branch_ID)
SELECT @v4 = COUNT(*) FROM (SELECT Branch_ID, Revenue, InvoiceCount FROM #rbb EXCEPT SELECT Branch_ID, rev, cnt FROM mref
                             UNION ALL SELECT Branch_ID, rev, cnt FROM mref EXCEPT SELECT Branch_ID, Revenue, InvoiceCount FROM #rbb) AS x;
SELECT @v5 = COUNT(*) FROM #rbb WHERE SystemRevenue <> (SELECT Revenue FROM #rs) OR SystemInvoiceCount <> (SELECT InvoiceCount FROM #rs)
                                    OR SharePct <> CONVERT(decimal(7,2), ROUND(Revenue * 100 / (SELECT Revenue FROM #rs), 2));
SET @v6 = CASE WHEN (SELECT Revenue FROM #rs) = (SELECT SUM(Revenue) FROM #rb)
                AND (SELECT Revenue FROM #rs) = (SELECT ISNULL(SUM(FinalAmount), 0) FROM #paid WHERE LocalDate >= @m0 AND LocalDate < @m1)
                AND (SELECT Revenue FROM #rs) = (SELECT ISNULL(SUM(TotalSpend), 0) FROM dbo.MEMBER_MONTHLY_SPENDING WHERE SpendingMonth = @m0) THEN 0 ELSE 1 END;
INSERT #r VALUES ('W9', CASE WHEN @v1 + @v2 + @v3 + @v4 + @v5 + @v6 = 0 AND (SELECT COUNT(*) FROM #rbp) > 0 THEN 'PASS' ELSE 'FAIL' END,
    N'All five report routines = independent reference (AT TIME ZONE; DATEDIFF buckets; four grains; three branches); RPT-02 = SUM(RPT-01) = SUM(PAID) = SUM(monthly spending of the month)',
    CONCAT('branch-by-period diffs ', @v1, '; system-by-period diffs ', @v2, '; period totals ', @v3, '; by-branch rows ', @v4, '; system/share ', @v5, '; roll-up/spending ', @v6,
           '; rows compared ', (SELECT COUNT(*) FROM #rbp) + (SELECT COUNT(*) FROM #rsp)));

/* W10 */
EXEC sys.sp_executesql @unrel, N'@h varchar(64) OUTPUT', @h = @hA OUTPUT;
INSERT #r VALUES ('W10', CASE WHEN @hA = @hB THEN 'PASS' ELSE 'FAIL' END,
    N'Unrelated state unchanged: shared fixture tables (BRANCH, EMPLOYEE, SERVICE_PLAN, PRODUCT, MEMBER_TIER), other members, other invoices, lines and spending rows',
    CONCAT('before ', @hB, '; after ', @hA));

/* W11 */
SELECT @n = COUNT(*) FROM dbo.INVOICE WHERE Member_ID = 10 OR Invoice_ID = @w15;
SELECT @n2 = COUNT(*) FROM dbo.TEST_HookCallLog WHERE Invoice_ID = @w15 OR Invoice_ID = (SELECT Invoice_ID FROM #inv WHERE ref = 'W12') AND Seq < (SELECT MIN(Seq) FROM dbo.TEST_HookCallLog WHERE Invoice_ID = (SELECT Invoice_ID FROM #inv WHERE ref = 'W12') AND HookName = 'ENTITLEMENT_ACTIVATION');
SELECT @n3 = COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM WHERE Invoice_ID = @w15;
SET @n3 += (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM WHERE Invoice_ID = @w15) + (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = 10)
         + (SELECT CurrentPoints FROM dbo.MEMBER WHERE Member_ID = 10) + (SELECT COUNT(*) FROM dbo.TEST_HookFault);
INSERT #r VALUES ('W11', CASE WHEN @w15 IS NOT NULL AND @w15Outc = 'SETTLED' AND @w15Err = 0 AND @n = 0 AND @n2 = 1 AND @n3 = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Injected failures leave no partial state: hook faults (W12, ops 17/19) and the method mismatch (W14, op 23) wrote nothing (see W2-W6); caller transaction with create + settle rolled back -> no invoice, line, spending, points or hook call',
    CONCAT('rolled-back invoice id ', @w15, ' (settled inside: ', @w15Outc, '); invoices of member 10 or that id ', @n,
           '; W12 inventory-hook rows before its successful call ', @n2, ' (1 = only the successful call; failed attempts left none); leftover lines/spending/points/faults ', @n3));

/* ---------- Report ---------- */
DECLARE @id6 varchar(6), @res varchar(4), @descr nvarchar(400);
DECLARE p CURSOR LOCAL FAST_FORWARD FOR SELECT id, result, descr, detail FROM #r ORDER BY seq;
OPEN p; FETCH NEXT FROM p INTO @id6, @res, @descr, @detail;
WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT CONCAT(@id6, ' ', @res, '  ', @descr, ' | ', @detail);
    FETCH NEXT FROM p INTO @id6, @res, @descr, @detail;
END;
CLOSE p; DEALLOCATE p;
DECLARE @nf int = (SELECT COUNT(*) FROM #r WHERE result <> 'PASS');
DECLARE @nChk int = (SELECT COUNT(*) FROM #r), @nCall int = (SELECT COUNT(*) FROM #call);
SET @nInv = (SELECT COUNT(*) FROM #inv);
PRINT CONCAT('T-WF-01 SUMMARY: checks=', @nChk, ' FAIL=', @nf, '; invoices created ', @nInv, '; calls ', @nCall);
IF @nf = 0 PRINT 'T-WF-01_RESULT: PASS'; ELSE PRINT 'T-WF-01_RESULT: FAIL';
GO
