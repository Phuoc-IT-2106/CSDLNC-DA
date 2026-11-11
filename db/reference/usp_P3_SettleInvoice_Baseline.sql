/* =====================================================================
   usp_P3_SettleInvoice_Baseline.sql
   Classification : REFERENCE_ONLY / BENCHMARK-ONLY variant "U0" (Person 3). NOT the production
                    loyalty path and never called by any application path or other routine
                    (WO-P3-P3-01 acceptance criterion 4; code search recorded in its execution record).
                    Kept in db/reference/, apart from db/procedures/ (production) and from fixtures.
   Work order     : WO-P3-P3-01 task 2 (completed 2026-11-09, Owner Directive "Finalize UC05 Settlement
                    and Implement Loyalty" section 6).
   Purpose        : reproduce the Problem 4 design (S-01 p3) for the later U0 vs U1 benchmark
                    (WO-P3-P3-03): at every settlement, recompute the member's tier-window spending from
                    the full INVOICE history and re-rank the tier synchronously.
   Contract       : same parameters and outputs as dbo.usp_P3_SettleInvoice, plus @Tier_ID OUTPUT
                    (the member's tier after the call).
   How            : one transaction (own, or the caller's): (1) calls the UNCHANGED approved routine
                    dbo.usp_P3_SettleInvoice (transition, hooks, monthly spending, points - all its
                    guarantees are reused, nothing is duplicated); (2) only when it returns SETTLED:
                    window = D-007 (APPROVED T2): twelve Asia/Ho_Chi_Minh calendar months ending with the
                    local month of PaidAt, half-open [FromMonth, NextMonth), converted to UTC bounds
                    (UTC+7, no DST); spend = SUM(FinalAmount) of the member's PAID invoices with PaidAt in
                    those bounds (reads INVOICE - this is the reference cost being reproduced);
                    tier = D-008 rule (APPROVED T2): highest MEMBER_TIER.SpendingThreshold <= spend
                    (inclusive), base tier at 0; thresholds read from MEMBER_TIER, never hard-coded;
                    MEMBER.Tier_ID updated only if different. Any error rolls everything back.
   Not            : the production loyalty path (that is D-009 (a): periodic usp_P3_EvaluateTiers);
                    no timing is claimed here (R-27; WO-P3-P3-03).
   Errors         : 51311 invalid tier configuration (checked before any write); all errors of
                    usp_P3_SettleInvoice pass through unchanged.
   Concurrency    : intended for single-session reference measurements; it scans INVOICE under
                    READ COMMITTED and may block on (or deadlock with) other settlers - the reason
                    Problem 4 asks to replace it.
   Run            : isolated databases only, after F002P and F002T (TEST_ONLY) or the team schema.
   ===================================================================== */
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.usp_P3_SettleInvoice', N'P') IS NULL OR OBJECT_ID(N'dbo.MEMBER_TIER', N'U') IS NULL OR COL_LENGTH(N'dbo.MEMBER', N'Tier_ID') IS NULL
    THROW 51310, N'usp_P3_SettleInvoice_Baseline requires usp_P3_SettleInvoice, MEMBER_TIER and MEMBER.Tier_ID.', 1;
GO

CREATE OR ALTER PROCEDURE dbo.usp_P3_SettleInvoice_Baseline
    @Invoice_ID     INT,
    @PaymentMethod  VARCHAR(10) = NULL,
    @Outcome        VARCHAR(20) = NULL OUTPUT,
    @PaidAt         DATETIME2(3) = NULL OUTPUT,
    @PointsEarned   INT = NULL OUTPUT,
    @CurrentPoints  INT = NULL OUTPUT,
    @Tier_ID        INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ownTran bit, @member int, @local date, @fromMonth date, @nextMonth date,
            @fromUtc datetime2(3), @toUtc datetime2(3), @spend decimal(38,2), @target int;
    SELECT @Tier_ID = NULL;

    -- D-008 rule: exactly one base tier at 0, no negative and no duplicate thresholds.
    IF (SELECT COUNT(*) FROM dbo.MEMBER_TIER WHERE SpendingThreshold = 0) <> 1
       OR EXISTS (SELECT 1 FROM dbo.MEMBER_TIER WHERE SpendingThreshold < 0)
       OR EXISTS (SELECT SpendingThreshold FROM dbo.MEMBER_TIER GROUP BY SpendingThreshold HAVING COUNT(*) > 1)
        THROW 51311, N'usp_P3_SettleInvoice_Baseline: invalid MEMBER_TIER configuration (need exactly one tier at 0, unique non-negative thresholds).', 1;

    SET @ownTran = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @ownTran = 1 BEGIN TRANSACTION;

        EXEC dbo.usp_P3_SettleInvoice @Invoice_ID = @Invoice_ID, @PaymentMethod = @PaymentMethod, @Outcome = @Outcome OUTPUT,
             @PaidAt = @PaidAt OUTPUT, @PointsEarned = @PointsEarned OUTPUT, @CurrentPoints = @CurrentPoints OUTPUT;

        SELECT @member = Member_ID FROM dbo.INVOICE WHERE Invoice_ID = @Invoice_ID;

        IF @Outcome = 'SETTLED'
        BEGIN
            SET @local = CAST(DATEADD(HOUR, 7, @PaidAt) AS date);
            SET @nextMonth = DATEADD(MONTH, 1, DATEFROMPARTS(YEAR(@local), MONTH(@local), 1));
            SET @fromMonth = DATEADD(MONTH, -12, @nextMonth);
            SET @fromUtc = DATEADD(HOUR, -7, CAST(@fromMonth AS datetime2(3)));
            SET @toUtc = DATEADD(HOUR, -7, CAST(@nextMonth AS datetime2(3)));

            SELECT @spend = ISNULL(SUM(FinalAmount), 0)
            FROM dbo.INVOICE
            WHERE Member_ID = @member AND PaymentStatus = 'PAID' AND PaidAt >= @fromUtc AND PaidAt < @toUtc;

            SELECT TOP (1) @target = Tier_ID FROM dbo.MEMBER_TIER WHERE SpendingThreshold <= @spend ORDER BY SpendingThreshold DESC;

            UPDATE dbo.MEMBER SET Tier_ID = @target WHERE Member_ID = @member AND Tier_ID <> @target;
        END;

        SELECT @Tier_ID = Tier_ID FROM dbo.MEMBER WHERE Member_ID = @member;
        IF @ownTran = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @ownTran = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
    RETURN 0;
END;
GO
EXEC sys.sp_addextendedproperty @name = N'Classification', @value = N'REFERENCE_ONLY (U0 benchmark-only baseline; not an application path)',
     @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'PROCEDURE', @level1name = N'usp_P3_SettleInvoice_Baseline';
PRINT 'usp_P3_SettleInvoice_Baseline applied (REFERENCE_ONLY U0)';
GO
