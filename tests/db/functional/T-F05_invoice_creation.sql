/* =====================================================================
   T-F05_invoice_creation.sql - TEST_ONLY (sqlcmd mode)
   Work order : WO-P3-P3-00 (invoice creation). Catalogue: 11 section 2.3.
   Exercises dbo.usp_P3_CreateInvoice in the isolated database FitLife_P3_UC05
   (fresh build + F001U key rows). The routine commits its own work, so created test
   invoices stay in this disposable database; every case records the row counts of
   INVOICE and both line tables before and after, and V-TOT after the case.
     Part 0  T-F05-04 foreign-key violation inside the transaction (parent deleted after
             validation; TEST_ONLY trigger, created and dropped here) -> error 547, full rollback.
     Part A  data-driven cases (one row each): T-F05-01 positive (product, service,
             mixed, boundaries, monetary calculation); T-F05-03 invalid values;
             T-F05-04 invalid or missing references; T-F05-18 no line; T-F05-19
             one bad line among valid ones.
     Part B  T-F05-19 rollback after the header and service lines were written
             (TEST_ONLY trigger, created and dropped here).
     Part C  T-F05-25 composition inside a caller's transaction (commit, rollback,
             error -> caller cannot commit).
     Part D  T-F05-23 repeated identical request (no request key: D-028 Q5 (b) not
             approved) -> two distinct invoices; exactly-once creation is NOT claimed.
     Part E  T-F05-26 least privilege: EXECUTE-only caller (TEST_ONLY role and user
             without login, created and dropped here).
     Part F  T-F05-24 no side effects: no spending row, fixtures unchanged, entitlement
             and PT columns NULL, all invoices PENDING without PaidAt.
   A case passes only if the exact expected error number (or success with the exact
   expected stored values) is observed AND V-TOT returns zero rows.
   Run from the repository root:
     sqlcmd -S localhost -E -I -b -W -d FitLife_P3_UC05 -i tests/db/functional/T-F05_invoice_creation.sql
   ===================================================================== */
:on error exit
SET NOCOUNT ON;
SET XACT_ABORT OFF;   -- errors raised by the routine must reach the CATCH blocks below

IF DB_NAME() <> N'FitLife_P3_UC05'
   OR NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable' AND CONVERT(nvarchar(200), value) LIKE N'WO-P3-P3-00%')
    THROW 51120, N'T-F05 runs only in FitLife_P3_UC05 carrying the WO-P3-P3-00 disposable marker.', 1;
IF OBJECT_ID(N'dbo.usp_P3_CreateInvoice', N'P') IS NULL
    THROW 51121, N'T-F05: dbo.usp_P3_CreateInvoice is not deployed.', 1;
IF (SELECT COUNT(*) FROM dbo.MEMBER) <> 40 OR (SELECT COUNT(*) FROM dbo.EMPLOYEE) <> 6 OR (SELECT COUNT(*) FROM dbo.BRANCH) <> 3
   OR (SELECT COUNT(*) FROM dbo.SERVICE_PLAN) <> 5 OR (SELECT COUNT(*) FROM dbo.PRODUCT) <> 10
   OR EXISTS (SELECT 1 FROM dbo.INVOICE) OR EXISTS (SELECT 1 FROM dbo.MEMBER_MONTHLY_SPENDING)
    THROW 51122, N'T-F05 expects a fresh build with exactly the F001U key rows and no invoice.', 1;

DECLARE @results TABLE (seq int IDENTITY(1,1), case_id varchar(8), cat varchar(10), kind char(1), result varchar(4), descr nvarchar(300), detail nvarchar(2000));

/* V-TOT (as in T-SCH-01) + orphan lines, as one count. */
DECLARE @vtotq nvarchar(max) = N'
WITH s AS (SELECT Invoice_ID, SUM(UnitPrice) AS g, SUM(DiscountAmount) AS d, COUNT(*) AS n FROM dbo.INVOICE_SERVICE_ITEM GROUP BY Invoice_ID),
     p AS (SELECT Invoice_ID, SUM(UnitPrice * Quantity) AS g, SUM(DiscountAmount) AS d, COUNT(*) AS n FROM dbo.INVOICE_PRODUCT_ITEM GROUP BY Invoice_ID)
SELECT @n = (SELECT COUNT(*) FROM dbo.INVOICE AS i LEFT JOIN s ON s.Invoice_ID = i.Invoice_ID LEFT JOIN p ON p.Invoice_ID = i.Invoice_ID
             WHERE i.GrossAmount <> ISNULL(s.g, 0) + ISNULL(p.g, 0) OR i.DiscountAmount <> ISNULL(s.d, 0) + ISNULL(p.d, 0)
                OR ISNULL(s.n, 0) + ISNULL(p.n, 0) = 0)
          + (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM AS x WHERE NOT EXISTS (SELECT 1 FROM dbo.INVOICE AS i WHERE i.Invoice_ID = x.Invoice_ID))
          + (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM AS x WHERE NOT EXISTS (SELECT 1 FROM dbo.INVOICE AS i WHERE i.Invoice_ID = x.Invoice_ID));';

/* Fixture fingerprint before any test (Part F compares). */
DECLARE @fixBefore varchar(64) = CONVERT(varchar(64), HASHBYTES('SHA2_256', CONCAT(
    (SELECT STRING_AGG(CONVERT(varchar(max), Member_ID), ',') WITHIN GROUP (ORDER BY Member_ID) FROM dbo.MEMBER), '|',
    (SELECT STRING_AGG(CONVERT(varchar(max), Employee_ID), ',') WITHIN GROUP (ORDER BY Employee_ID) FROM dbo.EMPLOYEE), '|',
    (SELECT STRING_AGG(CONVERT(varchar(max), Branch_ID), ',') WITHIN GROUP (ORDER BY Branch_ID) FROM dbo.BRANCH), '|',
    (SELECT STRING_AGG(CONVERT(varchar(max), Plan_ID), ',') WITHIN GROUP (ORDER BY Plan_ID) FROM dbo.SERVICE_PLAN), '|',
    (SELECT STRING_AGG(CONVERT(varchar(max), Product_ID), ',') WITHIN GROUP (ORDER BY Product_ID) FROM dbo.PRODUCT))), 2);

/* ================= Part 0 (runs first, while product 10 is not yet referenced) =================
   B02: a parent row disappears after validation, inside the transaction (simulated concurrent delete
   by a TEST_ONLY trigger on INVOICE). The FOREIGN KEY is the final guard: error 547 reaches the
   caller unchanged and the whole transaction (header, service line, and the trigger's delete) is
   rolled back. */
DECLARE @b2s dbo.tt_P3_InvoiceServiceLine, @b2p dbo.tt_P3_InvoiceProductLine;
DECLARE @b2err int = 0, @b2msg nvarchar(2048) = NULL, @b2id int = NULL, @b2out varchar(20) = NULL, @b2tc int, @b2vt int, @b2trg int, @b2prod int,
        @b2i0 numeric(38,0), @b2i1 numeric(38,0), @b2h0 int, @b2s0 int, @b2p0 int;
INSERT @b2s VALUES (1, 1, 600000.00, 0.00);
INSERT @b2p VALUES (1, 10, 1, 20000.00, 0.00);
EXEC (N'CREATE TRIGGER dbo.trg_TEST_ONLY_DeleteParent ON dbo.INVOICE AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM dbo.PRODUCT WHERE Product_ID = 10;   -- TEST_ONLY: simulates a concurrent delete of a validated parent
END;');
SELECT @b2h0 = (SELECT COUNT(*) FROM dbo.INVOICE), @b2s0 = (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM), @b2p0 = (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM),
       @b2i0 = ISNULL((SELECT CONVERT(numeric(38,0), last_value) FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'dbo.INVOICE')), 0);
BEGIN TRY
    EXEC dbo.usp_P3_CreateInvoice @Member_ID = 20, @Employee_ID = 1, @Branch_ID = 1, @ServiceLines = @b2s, @ProductLines = @b2p,
         @Invoice_ID = @b2id OUTPUT, @Outcome = @b2out OUTPUT;
END TRY
BEGIN CATCH
    SELECT @b2err = ERROR_NUMBER(), @b2msg = ERROR_MESSAGE();
END CATCH;
SET @b2tc = @@TRANCOUNT;
IF @b2tc > 0 ROLLBACK TRANSACTION;   -- defensive; asserted to be 0
SET @b2i1 = ISNULL((SELECT CONVERT(numeric(38,0), last_value) FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'dbo.INVOICE')), 0);
EXEC (N'DROP TRIGGER dbo.trg_TEST_ONLY_DeleteParent;');
SELECT @b2trg = (SELECT COUNT(*) FROM sys.triggers), @b2prod = (SELECT COUNT(*) FROM dbo.PRODUCT WHERE Product_ID = 10);
EXEC sys.sp_executesql @vtotq, N'@n int OUTPUT', @n = @b2vt OUTPUT;
INSERT @results (case_id, cat, kind, result, descr, detail) VALUES ('B02', 'T-F05-04', 'N',
    CASE WHEN @b2err = 547 AND @b2msg LIKE N'%FK_INVOICE_PRODUCT_ITEM_PRODUCT%' AND @b2tc = 0 AND @b2id IS NULL AND @b2i1 > @b2i0 AND @b2prod = 1 AND @b2trg = 0 AND @b2vt = 0
              AND (SELECT COUNT(*) FROM dbo.INVOICE) = @b2h0 AND (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM) = @b2s0 AND (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM) = @b2p0
         THEN 'PASS' ELSE 'FAIL' END,
    N'Foreign-key violation inside the transaction (parent deleted after validation, simulated by a TEST_ONLY trigger): error 547 passed through unchanged; header, lines and the delete all rolled back',
    CONCAT(N'error ', @b2err, N': ', ISNULL(@b2msg, N'(none)'), N'; identity last_value before/after ', @b2i0, N'/', @b2i1, N' (0 = never used; advanced, so the header insert ran and was rolled back); rows written: headers ',
           (SELECT COUNT(*) FROM dbo.INVOICE) - @b2h0, N', service lines ', (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM) - @b2s0, N', product lines ',
           (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM) - @b2p0, N'; product 10 still present=', @b2prod, N'; trancount after=', @b2tc,
           N'; triggers remaining=', @b2trg, N'; V-TOT rows=', @b2vt));

/* ================= Part A: data-driven cases =================
   svc: [[LineNo, Plan_ID, UnitPrice, DiscountAmount], ...]
   prd: [[LineNo, Product_ID, Quantity, UnitPrice, DiscountAmount], ...]
   exp_err 0 = success with exp_g (gross) and exp_d (discount); otherwise the exact error
   number, raised at stage 'fill' (the line type rejects the request before the call) or
   'exec' (the routine). Oracle values are hand-calculated. */
DECLARE @cases TABLE (seq int IDENTITY(1,1), case_id varchar(8), cat varchar(10), descr nvarchar(300), m int, e int, b int, meth varchar(10),
                      svc nvarchar(max), prd nvarchar(max), exp_err int, exp_stage varchar(4), exp_g decimal(38,2), exp_d decimal(38,2));
INSERT @cases (case_id, cat, descr, m, e, b, meth, svc, prd, exp_err, exp_stage, exp_g, exp_d) VALUES
 ('P01','T-F05-01',N'Product invoice, one line (2 x 50,000), method not yet known', 1,1,1,NULL, NULL, N'[[1,1,2,"50000.00","0"]]', 0,'exec',100000.00,0.00),
 ('P02','T-F05-01',N'Product invoice, three lines with cents and line discounts (exact decimal totals)', 2,2,1,NULL, NULL,
        N'[[1,2,3,"99999.99","0"],[2,3,1,"120000","20000"],[3,4,5,"15000.50","2500.25"]]', 0,'exec',495002.47,22500.25),
 ('P03','T-F05-01',N'Service invoice, one plan line, method CASH recorded at creation', 3,3,2,'CASH', N'[[1,1,"1500000","0"]]', NULL, 0,'exec',1500000.00,0.00),
 ('P04','T-F05-01',N'Service invoice, two plan lines with a line discount, method VNPAY', 4,4,2,'VNPAY', N'[[1,2,"3000000","300000"],[2,3,"500000","0"]]', NULL, 0,'exec',3500000.00,300000.00),
 ('P05','T-F05-01',N'Mixed invoice: one service line + two product lines (service and product LineNo 1 coexist), method CARD', 5,5,3,'CARD',
        N'[[1,4,"2000000","200000"]]', N'[[1,5,2,"45000","0"],[2,6,1,"30000","5000"]]', 0,'exec',2120000.00,205000.00),
 ('P06','T-F05-01',N'Boundaries: zero-price plan line; product discount > unit price but <= line gross; discount = line gross', 6,6,3,NULL,
        N'[[1,5,"0","0"]]', N'[[1,7,3,"100000","250000"],[2,8,1,"80000","80000"]]', 0,'exec',380000.00,330000.00),
 ('P07','T-F05-01',N'Whole invoice discounted: FinalAmount = 0 (allowed, D-023 FinalAmount >= 0)', 7,1,1,NULL, NULL, N'[[1,9,1,"10000","10000"]]', 0,'exec',10000.00,10000.00),
 ('P08','T-F05-01',N'Large valid total (1,000 x 9,999,999,999.99)', 8,2,1,NULL, NULL, N'[[1,10,1000,"9999999999.99","0"]]', 0,'exec',9999999999990.00,0.00),
 ('P09','T-F05-01',N'Largest representable gross (DECIMAL(18,2) maximum) is accepted', 9,3,2,NULL, NULL, N'[[1,1,1,"9999999999999999.99","0"]]', 0,'exec',9999999999999999.99,0.00),
 ('N01','T-F05-04',N'Unknown member', 9999,1,1,NULL, NULL, N'[[1,1,1,"1000","0"]]', 51110,'exec',NULL,NULL),
 ('N02','T-F05-04',N'Unknown employee', 1,9999,1,NULL, NULL, N'[[1,1,1,"1000","0"]]', 51111,'exec',NULL,NULL),
 ('N03','T-F05-04',N'Unknown branch', 1,1,9999,NULL, NULL, N'[[1,1,1,"1000","0"]]', 51112,'exec',NULL,NULL),
 ('N04','T-F05-04',N'Unknown service plan', 1,1,1,NULL, N'[[1,99,"1000","0"]]', NULL, 51113,'exec',NULL,NULL),
 ('N05','T-F05-19',N'Unknown product on line 3 of 3 (lines 1-2 valid): nothing created', 1,1,1,NULL, NULL,
        N'[[1,1,1,"1000","0"],[2,2,1,"2000","0"],[3,99,1,"3000","0"]]', 51114,'exec',NULL,NULL),
 ('N06','T-F05-04',N'Missing member key (NULL): incomplete header', NULL,1,1,NULL, NULL, N'[[1,1,1,"1000","0"]]', 51101,'exec',NULL,NULL),
 ('N07','T-F05-04',N'Missing branch key (NULL): incomplete header', 1,1,NULL,NULL, NULL, N'[[1,1,1,"1000","0"]]', 51101,'exec',NULL,NULL),
 ('N08','T-F05-03',N'Quantity 0', 1,1,1,NULL, NULL, N'[[1,1,0,"1000","0"]]', 51105,'exec',NULL,NULL),
 ('N09','T-F05-03',N'Negative quantity', 1,1,1,NULL, NULL, N'[[1,1,-2,"1000","0"]]', 51105,'exec',NULL,NULL),
 ('N10','T-F05-03',N'Negative product unit price', 1,1,1,NULL, NULL, N'[[1,1,1,"-0.01","0"]]', 51106,'exec',NULL,NULL),
 ('N11','T-F05-03',N'Negative service unit price', 1,1,1,NULL, N'[[1,1,"-1000","0"]]', NULL, 51106,'exec',NULL,NULL),
 ('N12','T-F05-03',N'Negative product discount', 1,1,1,NULL, NULL, N'[[1,1,1,"1000","-1"]]', 51107,'exec',NULL,NULL),
 ('N13','T-F05-03',N'Negative service discount', 1,1,1,NULL, N'[[1,1,"1000","-0.01"]]', NULL, 51107,'exec',NULL,NULL),
 ('N14','T-F05-03',N'Service discount greater than the line amount (100,000.01 > 100,000)', 1,1,1,NULL, N'[[1,1,"100000","100000.01"]]', NULL, 51108,'exec',NULL,NULL),
 ('N15','T-F05-03',N'Product discount greater than UnitPrice x Quantity (200,000.01 > 2 x 100,000)', 1,1,1,NULL, NULL, N'[[1,1,2,"100000","200000.01"]]', 51108,'exec',NULL,NULL),
 ('N16','T-F05-03',N'Invalid totals: one line whose gross exceeds DECIMAL(18,2)', 1,1,1,NULL, NULL, N'[[1,1,2,"9999999999999999.99","0"]]', 51109,'exec',NULL,NULL),
 ('N17','T-F05-03',N'Invalid totals: valid lines whose sum exceeds DECIMAL(18,2)', 1,1,1,NULL, NULL,
        N'[[1,1,1,"9999999999999999.99","0"],[2,2,1,"0.01","0"]]', 51109,'exec',NULL,NULL),
 ('N18','T-F05-18',N'No line at all (BR12)', 1,1,1,NULL, NULL, NULL, 51103,'exec',NULL,NULL),
 ('N19','T-F05-03',N'LineNo 0', 1,1,1,NULL, NULL, N'[[0,1,1,"1000","0"]]', 51104,'exec',NULL,NULL),
 ('N20','T-F05-03',N'PaymentMethod outside the D-005 domain (CHEQUE)', 1,1,1,'CHEQUE', NULL, N'[[1,1,1,"1000","0"]]', 51102,'exec',NULL,NULL),
 ('N21','T-F05-03',N'PaymentMethod in lower case (cash): only the exact approved literals are stored', 1,1,1,'cash', NULL, N'[[1,1,1,"1000","0"]]', 51102,'exec',NULL,NULL),
 ('N22','T-F05-03',N'PaymentMethod with a trailing space (CASH )', 1,1,1,'CASH ', NULL, N'[[1,1,1,"1000","0"]]', 51102,'exec',NULL,NULL),
 ('N23','T-F05-03',N'Duplicate LineNo in one request: rejected by the line type before the call', 1,1,1,NULL, NULL,
        N'[[1,1,1,"1000","0"],[1,2,1,"2000","0"]]', 2627,'fill',NULL,NULL),
 ('N24','T-F05-03',N'Incomplete line (UnitPrice missing): rejected by the line type before the call', 1,1,1,NULL, NULL, N'[[1,1,1,null,"0"]]', 515,'fill',NULL,NULL),
 ('N25','T-F05-19',N'Invalid amount on line 3 of 3 (lines 1-2 valid): nothing created', 1,1,1,NULL, NULL,
        N'[[1,1,1,"1000","0"],[2,2,1,"2000","0"],[3,3,1,"-5","0"]]', 51106,'exec',NULL,NULL),
 ('N26','T-F05-19',N'Mixed request: valid service line, invalid product discount: nothing created', 1,1,1,NULL,
        N'[[1,1,"500000","0"]]', N'[[1,2,1,"1000","1000.01"]]', 51108,'exec',NULL,NULL);

DECLARE @s dbo.tt_P3_InvoiceServiceLine, @p dbo.tt_P3_InvoiceProductLine;
DECLARE @case_id varchar(8), @cat varchar(10), @descr nvarchar(300), @m int, @e int, @b int, @meth varchar(10), @svc nvarchar(max), @prd nvarchar(max),
        @exp_err int, @exp_stage varchar(4), @exp_g decimal(38,2), @exp_d decimal(38,2);
DECLARE @stage varchar(4), @err int, @emsg nvarchar(2048), @id int, @out varchar(20), @rc int, @t0 datetime2(7), @t1 datetime2(7),
        @h0 int, @si0 int, @pi0 int, @h1 int, @si1 int, @pi1 int, @vt int, @tc int, @ns int, @np int,
        @hdrOk bit, @hdr nvarchar(600), @expL nvarchar(max), @actL nvarchar(max), @nullv int, @ok bit;

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT case_id, cat, descr, m, e, b, meth, svc, prd, exp_err, exp_stage, exp_g, exp_d FROM @cases ORDER BY seq;
OPEN cur;
FETCH NEXT FROM cur INTO @case_id, @cat, @descr, @m, @e, @b, @meth, @svc, @prd, @exp_err, @exp_stage, @exp_g, @exp_d;
WHILE @@FETCH_STATUS = 0
BEGIN
    DELETE FROM @s; DELETE FROM @p;
    SELECT @h0 = (SELECT COUNT(*) FROM dbo.INVOICE), @si0 = (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM), @pi0 = (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM);
    SELECT @stage = 'fill', @err = 0, @emsg = NULL, @id = NULL, @out = NULL, @rc = NULL, @t0 = NULL, @t1 = NULL;
    BEGIN TRY
        INSERT @s ([LineNo], Plan_ID, UnitPrice, DiscountAmount)
        SELECT JSON_VALUE(j.value, '$[0]'), JSON_VALUE(j.value, '$[1]'), JSON_VALUE(j.value, '$[2]'), JSON_VALUE(j.value, '$[3]')
        FROM OPENJSON(ISNULL(@svc, N'[]')) AS j;
        INSERT @p ([LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount)
        SELECT JSON_VALUE(j.value, '$[0]'), JSON_VALUE(j.value, '$[1]'), JSON_VALUE(j.value, '$[2]'), JSON_VALUE(j.value, '$[3]'), JSON_VALUE(j.value, '$[4]')
        FROM OPENJSON(ISNULL(@prd, N'[]')) AS j;
        SET @stage = 'exec';
        SET @t0 = SYSUTCDATETIME();
        EXEC @rc = dbo.usp_P3_CreateInvoice @Member_ID = @m, @Employee_ID = @e, @Branch_ID = @b,
             @ServiceLines = @s, @ProductLines = @p, @PaymentMethod = @meth, @Invoice_ID = @id OUTPUT, @Outcome = @out OUTPUT;
        SET @t1 = SYSUTCDATETIME();
    END TRY
    BEGIN CATCH
        SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE();
    END CATCH;

    SET @tc = @@TRANCOUNT;
    SELECT @h1 = (SELECT COUNT(*) FROM dbo.INVOICE), @si1 = (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM), @pi1 = (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM);
    SELECT @ns = (SELECT COUNT(*) FROM @s), @np = (SELECT COUNT(*) FROM @p);
    EXEC sys.sp_executesql @vtotq, N'@n int OUTPUT', @n = @vt OUTPUT;

    IF @exp_err = 0
    BEGIN
        SELECT @hdrOk = 0, @hdr = N'(header not found)';
        SELECT @hdrOk = CASE WHEN Member_ID = @m AND Employee_ID = @e AND Branch_ID = @b
                               AND PaymentStatus = 'PENDING' AND PaidAt IS NULL
                               AND ISNULL(PaymentMethod COLLATE Latin1_General_BIN2, '~') = ISNULL(@meth, '~')
                               AND GrossAmount = @exp_g AND DiscountAmount = @exp_d AND FinalAmount = @exp_g - @exp_d
                               AND IssuedAt >= DATEADD(MILLISECOND, -1, @t0) AND IssuedAt <= DATEADD(MILLISECOND, 1, @t1)
                             THEN 1 ELSE 0 END,
               @hdr = CONCAT(N'id=', Invoice_ID, N' status=', PaymentStatus, N' paidAt=', ISNULL(CONVERT(varchar(23), PaidAt, 121), 'NULL'),
                             N' method=', ISNULL(PaymentMethod, 'NULL'), N' gross=', GrossAmount, N' discount=', DiscountAmount, N' final=', FinalAmount,
                             N' issuedAtUTC=', CONVERT(varchar(23), IssuedAt, 121))
        FROM dbo.INVOICE WHERE Invoice_ID = @id;
        SET @expL = CONCAT(N'S[', (SELECT STRING_AGG(CONVERT(nvarchar(max), CONCAT([LineNo], ':', Plan_ID, ':', UnitPrice, ':', DiscountAmount)), ',') WITHIN GROUP (ORDER BY [LineNo]) FROM @s),
                           N'] P[', (SELECT STRING_AGG(CONVERT(nvarchar(max), CONCAT([LineNo], ':', Product_ID, ':', Quantity, ':', UnitPrice, ':', DiscountAmount)), ',') WITHIN GROUP (ORDER BY [LineNo]) FROM @p), N']');
        SET @actL = CONCAT(N'S[', (SELECT STRING_AGG(CONVERT(nvarchar(max), CONCAT([LineNo], ':', Plan_ID, ':', UnitPrice, ':', DiscountAmount)), ',') WITHIN GROUP (ORDER BY [LineNo]) FROM dbo.INVOICE_SERVICE_ITEM WHERE Invoice_ID = @id),
                           N'] P[', (SELECT STRING_AGG(CONVERT(nvarchar(max), CONCAT([LineNo], ':', Product_ID, ':', Quantity, ':', UnitPrice, ':', DiscountAmount)), ',') WITHIN GROUP (ORDER BY [LineNo]) FROM dbo.INVOICE_PRODUCT_ITEM WHERE Invoice_ID = @id), N']');
        SET @nullv = (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM WHERE Invoice_ID = @id AND (ValidFrom IS NOT NULL OR ValidUntil IS NOT NULL OR PTSessionsRemaining IS NOT NULL));
        SET @ok = CASE WHEN @err = 0 AND @rc = 0 AND @out = 'CREATED' AND @id IS NOT NULL AND @h1 = @h0 + 1 AND @si1 = @si0 + @ns AND @pi1 = @pi0 + @np
                            AND @hdrOk = 1 AND @expL = @actL AND @nullv = 0 AND @vt = 0 AND @tc = 0 THEN 1 ELSE 0 END;
        INSERT @results (case_id, cat, kind, result, descr, detail) VALUES (@case_id, @cat, 'P', CASE WHEN @ok = 1 THEN 'PASS' ELSE 'FAIL' END, @descr,
            CONCAT(N'return=', ISNULL(CONVERT(varchar(11), @rc), 'NULL'), N' outcome=', ISNULL(@out, 'NULL'), N' ', @hdr,
                   N'; lines stored=', @actL, CASE WHEN @expL <> @actL THEN CONCAT(N' expected=', @expL) ELSE N' (= request)' END,
                   N'; +headers=', @h1 - @h0, N' +service lines=', @si1 - @si0, N' +product lines=', @pi1 - @pi0,
                   N'; entitlement/PT columns not NULL=', @nullv, N'; V-TOT rows=', @vt, N'; trancount=', @tc,
                   CASE WHEN @err <> 0 THEN CONCAT(N'; unexpected error ', @err, N': ', @emsg) ELSE N'' END));
    END
    ELSE
    BEGIN
        SET @ok = CASE WHEN @err = @exp_err AND @stage = @exp_stage AND @h1 = @h0 AND @si1 = @si0 AND @pi1 = @pi0 AND @id IS NULL AND @vt = 0 AND @tc = 0 THEN 1 ELSE 0 END;
        INSERT @results (case_id, cat, kind, result, descr, detail) VALUES (@case_id, @cat, 'N', CASE WHEN @ok = 1 THEN 'PASS' ELSE 'FAIL' END, @descr,
            CONCAT(N'error ', @err, N' at stage ', @stage, N' (expected ', @exp_err, N' at ', @exp_stage, N'): ', ISNULL(@emsg, N'(none)'),
                   N'; rows written: headers ', @h1 - @h0, N', service lines ', @si1 - @si0, N', product lines ', @pi1 - @pi0,
                   N'; invoice id returned=', ISNULL(CONVERT(varchar(11), @id), 'NULL'), N'; V-TOT rows=', @vt, N'; trancount=', @tc));
    END;

    FETCH NEXT FROM cur INTO @case_id, @cat, @descr, @m, @e, @b, @meth, @svc, @prd, @exp_err, @exp_stage, @exp_g, @exp_d;
END;
CLOSE cur; DEALLOCATE cur;

/* ================= Part B: rollback after the header and service lines were written ================= */
DECLARE @ident0 numeric(38,0), @ident1 numeric(38,0), @trg int;
EXEC (N'CREATE TRIGGER dbo.trg_TEST_ONLY_FailProductLine ON dbo.INVOICE_PRODUCT_ITEM AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    THROW 51199, N''TEST_ONLY injected failure: product lines rejected after the header and service lines were inserted'', 1;
END;');
DELETE FROM @s; DELETE FROM @p;
INSERT @s VALUES (1, 1, 700000.00, 0.00);
INSERT @p VALUES (1, 1, 2, 50000.00, 0.00), (2, 2, 1, 30000.00, 0.00);
SELECT @h0 = (SELECT COUNT(*) FROM dbo.INVOICE), @si0 = (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM), @pi0 = (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM);
SELECT @ident0 = ISNULL((SELECT CONVERT(numeric(38,0), last_value) FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'dbo.INVOICE')), 0), @err = 0, @emsg = NULL, @id = NULL, @out = NULL;
BEGIN TRY
    EXEC dbo.usp_P3_CreateInvoice @Member_ID = 10, @Employee_ID = 1, @Branch_ID = 1, @ServiceLines = @s, @ProductLines = @p,
         @Invoice_ID = @id OUTPUT, @Outcome = @out OUTPUT;
END TRY
BEGIN CATCH
    SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE();
END CATCH;
SET @tc = @@TRANCOUNT;
IF @tc > 0 ROLLBACK TRANSACTION;   -- defensive; @tc is asserted to be 0
SET @ident1 = ISNULL((SELECT CONVERT(numeric(38,0), last_value) FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'dbo.INVOICE')), 0);
EXEC (N'DROP TRIGGER dbo.trg_TEST_ONLY_FailProductLine;');
SET @trg = (SELECT COUNT(*) FROM sys.triggers);
SELECT @h1 = (SELECT COUNT(*) FROM dbo.INVOICE), @si1 = (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM), @pi1 = (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM);
EXEC sys.sp_executesql @vtotq, N'@n int OUTPUT', @n = @vt OUTPUT;
INSERT @results (case_id, cat, kind, result, descr, detail) VALUES ('B01', 'T-F05-19', 'N',
    CASE WHEN @err = 51199 AND @tc = 0 AND @h1 = @h0 AND @si1 = @si0 AND @pi1 = @pi0 AND @ident1 > @ident0 AND @id IS NULL AND @vt = 0 AND @trg = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Failure inside the transaction after the header and the service line were inserted (TEST_ONLY trigger on product lines): everything rolled back',
    CONCAT(N'error ', @err, N': ', ISNULL(@emsg, N'(none)'), N'; identity last_value before/after ', @ident0, N'/', @ident1,
           N' (advanced, so the header insert ran and was rolled back); rows written: headers ', @h1 - @h0, N', service lines ', @si1 - @si0,
           N', product lines ', @pi1 - @pi0, N'; trancount after=', @tc, N'; V-TOT rows=', @vt, N'; triggers remaining=', @trg));

/* ================= Part C: composition inside a caller's transaction (12 section 4) ================= */
DECLARE @idA int, @idB int, @tcIn int, @xs int, @exists int;
DELETE FROM @s; DELETE FROM @p;
INSERT @p VALUES (1, 3, 1, 45000.00, 0.00);

-- C01: caller commits
SELECT @h0 = (SELECT COUNT(*) FROM dbo.INVOICE), @err = 0, @emsg = NULL, @id = NULL;
BEGIN TRANSACTION;
BEGIN TRY
    EXEC dbo.usp_P3_CreateInvoice @Member_ID = 11, @Employee_ID = 2, @Branch_ID = 1, @ServiceLines = @s, @ProductLines = @p, @Invoice_ID = @id OUTPUT, @Outcome = @out OUTPUT;
END TRY
BEGIN CATCH
    SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE();
END CATCH;
SET @tcIn = @@TRANCOUNT;
IF XACT_STATE() = 1 COMMIT TRANSACTION; ELSE IF XACT_STATE() = -1 ROLLBACK TRANSACTION;
SET @exists = (SELECT COUNT(*) FROM dbo.INVOICE AS i JOIN dbo.INVOICE_PRODUCT_ITEM AS l ON l.Invoice_ID = i.Invoice_ID WHERE i.Invoice_ID = @id);
EXEC sys.sp_executesql @vtotq, N'@n int OUTPUT', @n = @vt OUTPUT;
INSERT @results (case_id, cat, kind, result, descr, detail) VALUES ('C01', 'T-F05-25', 'P',
    CASE WHEN @err = 0 AND @tcIn = 1 AND @exists = 1 AND @@TRANCOUNT = 0 AND (SELECT COUNT(*) FROM dbo.INVOICE) = @h0 + 1 AND @vt = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Called inside an open caller transaction: the routine neither commits nor rolls back; the invoice persists after the caller commits',
    CONCAT(N'error ', @err, N'; trancount after the call (inside caller tran)=', @tcIn, N'; invoice ', @id, N' present after commit with lines=', @exists, N'; V-TOT rows=', @vt));

-- C02: caller rolls back
SELECT @h0 = (SELECT COUNT(*) FROM dbo.INVOICE), @pi0 = (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM), @err = 0, @emsg = NULL, @id = NULL;
BEGIN TRANSACTION;
BEGIN TRY
    EXEC dbo.usp_P3_CreateInvoice @Member_ID = 12, @Employee_ID = 2, @Branch_ID = 1, @ServiceLines = @s, @ProductLines = @p, @Invoice_ID = @id OUTPUT, @Outcome = @out OUTPUT;
END TRY
BEGIN CATCH
    SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE();
END CATCH;
SET @tcIn = @@TRANCOUNT;
IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
SET @exists = (SELECT COUNT(*) FROM dbo.INVOICE WHERE Invoice_ID = @id) + (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM WHERE Invoice_ID = @id);
EXEC sys.sp_executesql @vtotq, N'@n int OUTPUT', @n = @vt OUTPUT;
INSERT @results (case_id, cat, kind, result, descr, detail) VALUES ('C02', 'T-F05-25', 'N',
    CASE WHEN @err = 0 AND @id IS NOT NULL AND @tcIn = 1 AND @exists = 0 AND @@TRANCOUNT = 0
              AND (SELECT COUNT(*) FROM dbo.INVOICE) = @h0 AND (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM) = @pi0 AND @vt = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Caller rolls back its transaction after a successful call: the invoice and its lines disappear',
    CONCAT(N'error ', @err, N'; id returned inside the transaction=', @id, N'; rows of that invoice after rollback=', @exists, N'; V-TOT rows=', @vt));

-- C03: routine error inside the caller's transaction after an earlier successful call in the same transaction
SELECT @h0 = (SELECT COUNT(*) FROM dbo.INVOICE), @pi0 = (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM), @err = 0, @emsg = NULL, @idA = NULL, @xs = NULL;
BEGIN TRANSACTION;
EXEC dbo.usp_P3_CreateInvoice @Member_ID = 13, @Employee_ID = 2, @Branch_ID = 1, @ServiceLines = @s, @ProductLines = @p, @Invoice_ID = @idA OUTPUT, @Outcome = @out OUTPUT;
DELETE FROM @p; INSERT @p VALUES (1, 99, 1, 45000.00, 0.00);   -- unknown product
BEGIN TRY
    EXEC dbo.usp_P3_CreateInvoice @Member_ID = 13, @Employee_ID = 2, @Branch_ID = 1, @ServiceLines = @s, @ProductLines = @p, @Invoice_ID = @idB OUTPUT, @Outcome = @out OUTPUT;
END TRY
BEGIN CATCH
    SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE(), @xs = XACT_STATE();
END CATCH;
IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
SET @exists = (SELECT COUNT(*) FROM dbo.INVOICE WHERE Invoice_ID = @idA);
EXEC sys.sp_executesql @vtotq, N'@n int OUTPUT', @n = @vt OUTPUT;
INSERT @results (case_id, cat, kind, result, descr, detail) VALUES ('C03', 'T-F05-25', 'N',
    CASE WHEN @err = 51114 AND @xs <> 1 AND @idA IS NOT NULL AND @exists = 0 AND @@TRANCOUNT = 0
              AND (SELECT COUNT(*) FROM dbo.INVOICE) = @h0 AND (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM) = @pi0 AND @vt = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Routine error inside a caller transaction: the error reaches the caller, the transaction cannot be committed, one rollback removes all its work',
    CONCAT(N'error ', @err, N': ', ISNULL(@emsg, N'(none)'), N'; XACT_STATE in caller CATCH=', ISNULL(CONVERT(varchar(3), @xs), 'NULL'),
           N' (-1 = uncommittable); earlier invoice ', @idA, N' rows after rollback=', @exists, N'; V-TOT rows=', @vt));

/* ================= Part D: repeated identical request ================= */
DECLARE @id1 int, @id2 int, @same int;
DELETE FROM @s; DELETE FROM @p;
INSERT @s VALUES (1, 2, 1200000.00, 100000.00);
INSERT @p VALUES (1, 4, 2, 35000.00, 0.00);
SELECT @h0 = (SELECT COUNT(*) FROM dbo.INVOICE), @err = 0, @emsg = NULL;
BEGIN TRY
    EXEC dbo.usp_P3_CreateInvoice @Member_ID = 14, @Employee_ID = 3, @Branch_ID = 2, @ServiceLines = @s, @ProductLines = @p, @PaymentMethod = 'CASH', @Invoice_ID = @id1 OUTPUT, @Outcome = @out OUTPUT;
    EXEC dbo.usp_P3_CreateInvoice @Member_ID = 14, @Employee_ID = 3, @Branch_ID = 2, @ServiceLines = @s, @ProductLines = @p, @PaymentMethod = 'CASH', @Invoice_ID = @id2 OUTPUT, @Outcome = @out OUTPUT;
END TRY
BEGIN CATCH
    SELECT @err = ERROR_NUMBER(), @emsg = ERROR_MESSAGE();
END CATCH;
SET @same = (SELECT COUNT(*) FROM dbo.INVOICE AS a JOIN dbo.INVOICE AS b ON b.Invoice_ID = @id2
             WHERE a.Invoice_ID = @id1 AND a.Member_ID = b.Member_ID AND a.Employee_ID = b.Employee_ID AND a.Branch_ID = b.Branch_ID
               AND a.GrossAmount = b.GrossAmount AND a.DiscountAmount = b.DiscountAmount AND a.FinalAmount = b.FinalAmount
               AND a.PaymentMethod = b.PaymentMethod AND a.PaymentStatus = 'PENDING' AND b.PaymentStatus = 'PENDING' AND a.PaidAt IS NULL AND b.PaidAt IS NULL)
          + CASE WHEN (SELECT STRING_AGG(CONVERT(nvarchar(max), CONCAT([LineNo], ':', Product_ID, ':', Quantity, ':', UnitPrice, ':', DiscountAmount)), ',') WITHIN GROUP (ORDER BY [LineNo]) FROM dbo.INVOICE_PRODUCT_ITEM WHERE Invoice_ID = @id1)
                    = (SELECT STRING_AGG(CONVERT(nvarchar(max), CONCAT([LineNo], ':', Product_ID, ':', Quantity, ':', UnitPrice, ':', DiscountAmount)), ',') WITHIN GROUP (ORDER BY [LineNo]) FROM dbo.INVOICE_PRODUCT_ITEM WHERE Invoice_ID = @id2)
                  AND (SELECT STRING_AGG(CONVERT(nvarchar(max), CONCAT([LineNo], ':', Plan_ID, ':', UnitPrice, ':', DiscountAmount)), ',') WITHIN GROUP (ORDER BY [LineNo]) FROM dbo.INVOICE_SERVICE_ITEM WHERE Invoice_ID = @id1)
                    = (SELECT STRING_AGG(CONVERT(nvarchar(max), CONCAT([LineNo], ':', Plan_ID, ':', UnitPrice, ':', DiscountAmount)), ',') WITHIN GROUP (ORDER BY [LineNo]) FROM dbo.INVOICE_SERVICE_ITEM WHERE Invoice_ID = @id2)
                 THEN 1 ELSE 0 END;
EXEC sys.sp_executesql @vtotq, N'@n int OUTPUT', @n = @vt OUTPUT;
INSERT @results (case_id, cat, kind, result, descr, detail) VALUES ('D01', 'T-F05-23', 'P',
    CASE WHEN @err = 0 AND @id1 IS NOT NULL AND @id2 IS NOT NULL AND @id1 <> @id2 AND @same = 2 AND (SELECT COUNT(*) FROM dbo.INVOICE) = @h0 + 2 AND @vt = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Same request sent twice (no request key; D-028 Q5 (b) not approved): two distinct PENDING invoices with identical business values; no uniqueness on business values rejects them. Exactly-once creation is NOT provided',
    CONCAT(N'error ', @err, N'; invoice ids ', @id1, N' and ', @id2, N'; identical header+lines checks=', @same, N'/2; V-TOT rows=', @vt));

/* ================= Part E: least privilege (TEST_ONLY principals, dropped at the end) ================= */
DECLARE @e1 int = 0, @e2 int = 0, @e3 int = 0, @e4 int = 0, @m1 nvarchar(400) = NULL, @m4 nvarchar(400) = NULL, @pid int = NULL, @pout varchar(20) = NULL, @principals int;
DECLARE @call nvarchar(max) = N'DECLARE @s dbo.tt_P3_InvoiceServiceLine, @p dbo.tt_P3_InvoiceProductLine;
INSERT @p VALUES (1, 5, 1, 25000.00, 0.00);
EXEC dbo.usp_P3_CreateInvoice @Member_ID = 15, @Employee_ID = 4, @Branch_ID = 2, @ServiceLines = @s, @ProductLines = @p, @Invoice_ID = @id OUTPUT, @Outcome = @o OUTPUT;';
SELECT @h0 = (SELECT COUNT(*) FROM dbo.INVOICE);
CREATE ROLE p3_test_billing_caller;
CREATE USER p3_test_caller WITHOUT LOGIN;
ALTER ROLE p3_test_billing_caller ADD MEMBER p3_test_caller;
GRANT EXECUTE ON OBJECT::dbo.usp_P3_CreateInvoice TO p3_test_billing_caller;
-- E1: without EXECUTE on the line types the call cannot even be prepared
EXECUTE AS USER = N'p3_test_caller';
BEGIN TRY EXEC sys.sp_executesql @call, N'@id int OUTPUT, @o varchar(20) OUTPUT', @id = @pid OUTPUT, @o = @pout OUTPUT; END TRY
BEGIN CATCH SELECT @e1 = ERROR_NUMBER(), @m1 = ERROR_MESSAGE(); END CATCH;
REVERT;
GRANT EXECUTE ON TYPE::dbo.tt_P3_InvoiceServiceLine TO p3_test_billing_caller;
GRANT EXECUTE ON TYPE::dbo.tt_P3_InvoiceProductLine TO p3_test_billing_caller;
EXECUTE AS USER = N'p3_test_caller';
-- E2: EXECUTE on the routine and its types is enough to create an invoice (ownership chain)
BEGIN TRY EXEC sys.sp_executesql @call, N'@id int OUTPUT, @o varchar(20) OUTPUT', @id = @pid OUTPUT, @o = @pout OUTPUT; END TRY
BEGIN CATCH SELECT @e2 = ERROR_NUMBER(); END CATCH;
-- E3/E4: direct writes to the invoice tables are denied
BEGIN TRY INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount, PaymentStatus)
          VALUES (15, 4, 2, SYSUTCDATETIME(), 0, 0, 0, 'PENDING'); END TRY
BEGIN CATCH SET @e3 = ERROR_NUMBER(); END CATCH;
BEGIN TRY UPDATE dbo.INVOICE_PRODUCT_ITEM SET DiscountAmount = 0 WHERE Invoice_ID = -1; END TRY
BEGIN CATCH SELECT @e4 = ERROR_NUMBER(), @m4 = ERROR_MESSAGE(); END CATCH;
REVERT;
ALTER ROLE p3_test_billing_caller DROP MEMBER p3_test_caller;
DROP USER p3_test_caller;
DROP ROLE p3_test_billing_caller;
SET @principals = (SELECT COUNT(*) FROM sys.database_principals WHERE name IN (N'p3_test_caller', N'p3_test_billing_caller'));
EXEC sys.sp_executesql @vtotq, N'@n int OUTPUT', @n = @vt OUTPUT;
INSERT @results (case_id, cat, kind, result, descr, detail) VALUES ('E01', 'T-F05-26', 'P',
    CASE WHEN @e1 = 229 AND @e2 = 0 AND @pout = 'CREATED' AND @pid IS NOT NULL AND @e3 = 229 AND @e4 = 229 AND USER_NAME() = N'dbo'
              AND @principals = 0 AND (SELECT COUNT(*) FROM dbo.INVOICE) = @h0 + 1 AND @vt = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Least privilege: a caller with EXECUTE on the routine and its two line types creates invoices; direct INSERT/UPDATE on the invoice tables is denied (TEST_ONLY role and user, dropped)',
    CONCAT(N'without type permission: error ', @e1, N' (', ISNULL(@m1, N'-'), N'); with EXECUTE grants: error ', @e2, N', outcome ', ISNULL(@pout, 'NULL'), N', invoice ', ISNULL(CONVERT(varchar(11), @pid), 'NULL'),
           N'; direct INSERT INVOICE: error ', @e3, N'; direct UPDATE INVOICE_PRODUCT_ITEM: error ', @e4, N'; context after REVERT=', USER_NAME(),
           N'; TEST_ONLY principals remaining=', @principals, N'; V-TOT rows=', @vt));

/* ================= Part F: no side effects of creation ================= */
DECLARE @fixAfter varchar(64) = CONVERT(varchar(64), HASHBYTES('SHA2_256', CONCAT(
    (SELECT STRING_AGG(CONVERT(varchar(max), Member_ID), ',') WITHIN GROUP (ORDER BY Member_ID) FROM dbo.MEMBER), '|',
    (SELECT STRING_AGG(CONVERT(varchar(max), Employee_ID), ',') WITHIN GROUP (ORDER BY Employee_ID) FROM dbo.EMPLOYEE), '|',
    (SELECT STRING_AGG(CONVERT(varchar(max), Branch_ID), ',') WITHIN GROUP (ORDER BY Branch_ID) FROM dbo.BRANCH), '|',
    (SELECT STRING_AGG(CONVERT(varchar(max), Plan_ID), ',') WITHIN GROUP (ORDER BY Plan_ID) FROM dbo.SERVICE_PLAN), '|',
    (SELECT STRING_AGG(CONVERT(varchar(max), Product_ID), ',') WITHIN GROUP (ORDER BY Product_ID) FROM dbo.PRODUCT))), 2);
DECLARE @mms int = (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING),
        @ent int = (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM WHERE ValidFrom IS NOT NULL OR ValidUntil IS NOT NULL OR PTSessionsRemaining IS NOT NULL),
        @notPending int = (SELECT COUNT(*) FROM dbo.INVOICE WHERE PaymentStatus <> 'PENDING' OR PaidAt IS NOT NULL),
        @nInv int = (SELECT COUNT(*) FROM dbo.INVOICE), @nSvcAll int = (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM), @nPrdAll int = (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM);
EXEC sys.sp_executesql @vtotq, N'@n int OUTPUT', @n = @vt OUTPUT;
INSERT @results (case_id, cat, kind, result, descr, detail) VALUES ('F01', 'T-F05-24', 'P',
    CASE WHEN @mms = 0 AND @ent = 0 AND @notPending = 0 AND @fixAfter = @fixBefore AND @vt = 0 AND @nInv > 0 THEN 'PASS' ELSE 'FAIL' END,
    N'No side effect of creation: no monthly-spending (loyalty) row, shared key fixtures unchanged, entitlement and PT columns NULL, every invoice PENDING without PaidAt',
    CONCAT(N'invoices=', @nInv, N' service lines=', @nSvcAll, N' product lines=', @nPrdAll, N'; MEMBER_MONTHLY_SPENDING rows=', @mms,
           N'; service lines with ValidFrom/ValidUntil/PTSessionsRemaining set=', @ent, N'; invoices not PENDING or with PaidAt=', @notPending,
           N'; fixture key hash before=after: ', CASE WHEN @fixAfter = @fixBefore THEN N'yes' ELSE N'NO' END, N'; V-TOT rows=', @vt));

/* ================= Report ================= */
SELECT case_id, cat, kind, result, descr, detail FROM @results ORDER BY seq;
PRINT '-- invoices created by this test (all rows of the P3 tables) --';
SELECT i.Invoice_ID, i.Member_ID, i.Employee_ID, i.Branch_ID, i.PaymentStatus, ISNULL(i.PaymentMethod, 'NULL') AS PaymentMethod,
       i.GrossAmount, i.DiscountAmount, i.FinalAmount,
       (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM AS s WHERE s.Invoice_ID = i.Invoice_ID) AS service_lines,
       (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM AS p WHERE p.Invoice_ID = i.Invoice_ID) AS product_lines
FROM dbo.INVOICE AS i ORDER BY i.Invoice_ID;

DECLARE @total int, @pass int, @fail int;
SELECT @total = COUNT(*), @pass = SUM(CASE WHEN result = 'PASS' THEN 1 ELSE 0 END), @fail = SUM(CASE WHEN result = 'FAIL' THEN 1 ELSE 0 END) FROM @results;
PRINT CONCAT('T-F05 SUMMARY: cases=', @total, ' PASS=', @pass, ' FAIL=', @fail);
SELECT cat, COUNT(*) AS cases, SUM(CASE WHEN result = 'PASS' THEN 1 ELSE 0 END) AS pass FROM @results GROUP BY cat ORDER BY cat;
IF @fail > 0 OR @total <> 43   -- B02 + 35 data-driven (9 positive, 26 negative) + B01 + C01..C03 + D01 + E01 + F01
BEGIN
    PRINT 'T-F05_RESULT: FAIL';
    THROW 51123, N'T-F05 failed (see the result table).', 1;
END
ELSE
    PRINT 'T-F05_RESULT: PASS';
GO
