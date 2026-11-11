/* =====================================================================
   V002__p3_settlement_and_spending_constraints.sql
   Classification : P3_OWNED — production migration (Person 3)
   Work order     : WO-P3-P1-01 — Physical Schema Foundation
   Purpose        : approved amendments on the four P3 tables (after V001):
                    - INVOICE.PaidAt (D-004; deviation DV-01)
                    - payment-state row invariants S1–S5 (D-003, D-004, D-005, D-011)
                    - monetary integrity on header and lines (D-023)
                    - SpendingMonth first-day-of-month invariant (D-013)
                    - defaults (D-005, D-014: timestamps in UTC)
   Not enforceable here (by design, see WO-P3-P1-01 §3.4):
                    - transitions T1–T5 (need the old value)  -> UC05 routines (WO-P3-P3-01)
                    - header totals = sum of lines (X1, X2) and BR12 (X3) are
                      cross-table invariants -> billing/settlement logic; verified by query V-TOT
   Notes          : forward-only; apply once. All-or-nothing (one transaction).
                    No UNIQUE constraint is required on P3-owned tables; MEMBER and
                    MEMBER_TIER constraints belong to their owners (12 §2a).
   ===================================================================== */
SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.INVOICE', N'U') IS NULL OR OBJECT_ID(N'dbo.MEMBER_MONTHLY_SPENDING', N'U') IS NULL
        THROW 51006, N'V002 requires V001 (P3 tables) to be applied first.', 1;

    /* DV-01: successful-settlement time, UTC (D-004, D-014). */
    ALTER TABLE dbo.INVOICE ADD PaidAt DATETIME2(3) NULL;

    /* INVOICE — payment state (S1–S5). Constraints that reference the new column run as
       separate statements so that the column is bound at execution time. */
    ALTER TABLE dbo.INVOICE ADD CONSTRAINT DF_INVOICE_PaymentStatus DEFAULT ('PENDING') FOR PaymentStatus;
    ALTER TABLE dbo.INVOICE WITH CHECK ADD CONSTRAINT CK_INVOICE_PaymentStatus
        CHECK (PaymentStatus IN ('PENDING', 'PAID', 'CANCELLED'));                       -- S1; D-005, D-011
    ALTER TABLE dbo.INVOICE WITH CHECK ADD CONSTRAINT CK_INVOICE_PaymentMethod
        CHECK (PaymentMethod IN ('CASH', 'VNPAY', 'CARD'));                               -- S2; NULL allowed before settlement
    ALTER TABLE dbo.INVOICE WITH CHECK ADD CONSTRAINT CK_INVOICE_MethodWhenPaid
        CHECK (PaymentStatus <> 'PAID' OR PaymentMethod IS NOT NULL);                     -- S3
    EXEC (N'ALTER TABLE dbo.INVOICE WITH CHECK ADD CONSTRAINT CK_INVOICE_PaidAtStatus
        CHECK ((PaymentStatus = ''PAID'' AND PaidAt IS NOT NULL) OR (PaymentStatus <> ''PAID'' AND PaidAt IS NULL));');   -- S4; D-004
    EXEC (N'ALTER TABLE dbo.INVOICE WITH CHECK ADD CONSTRAINT CK_INVOICE_PaidAtAfterIssued
        CHECK (PaidAt >= IssuedAt);');                                                    -- S5; passes when PaidAt is NULL

    /* INVOICE — monetary integrity (D-023). */
    ALTER TABLE dbo.INVOICE WITH CHECK ADD CONSTRAINT CK_INVOICE_Amounts
        CHECK (GrossAmount >= 0 AND DiscountAmount >= 0 AND DiscountAmount <= GrossAmount);
    ALTER TABLE dbo.INVOICE WITH CHECK ADD CONSTRAINT CK_INVOICE_FinalAmount
        CHECK (FinalAmount = GrossAmount - DiscountAmount AND FinalAmount >= 0);

    /* Lines — monetary integrity (D-023). */
    ALTER TABLE dbo.INVOICE_SERVICE_ITEM WITH CHECK ADD CONSTRAINT CK_INVOICE_SERVICE_ITEM_Amounts
        CHECK (UnitPrice >= 0 AND DiscountAmount >= 0 AND DiscountAmount <= UnitPrice);
    ALTER TABLE dbo.INVOICE_PRODUCT_ITEM WITH CHECK ADD CONSTRAINT CK_INVOICE_PRODUCT_ITEM_Quantity
        CHECK (Quantity > 0);
    ALTER TABLE dbo.INVOICE_PRODUCT_ITEM WITH CHECK ADD CONSTRAINT CK_INVOICE_PRODUCT_ITEM_Amounts
        CHECK (UnitPrice >= 0 AND DiscountAmount >= 0 AND DiscountAmount <= UnitPrice * Quantity);

    /* MEMBER_MONTHLY_SPENDING — D-013 and non-negativity; defaults (UTC). */
    ALTER TABLE dbo.MEMBER_MONTHLY_SPENDING WITH CHECK ADD CONSTRAINT CK_MEMBER_MONTHLY_SPENDING_FirstDay
        CHECK (DAY(SpendingMonth) = 1);
    ALTER TABLE dbo.MEMBER_MONTHLY_SPENDING WITH CHECK ADD CONSTRAINT CK_MEMBER_MONTHLY_SPENDING_NonNegative
        CHECK (TotalSpend >= 0 AND PointsEarned >= 0);
    ALTER TABLE dbo.MEMBER_MONTHLY_SPENDING ADD CONSTRAINT DF_MEMBER_MONTHLY_SPENDING_TotalSpend   DEFAULT (0) FOR TotalSpend;
    ALTER TABLE dbo.MEMBER_MONTHLY_SPENDING ADD CONSTRAINT DF_MEMBER_MONTHLY_SPENDING_PointsEarned DEFAULT (0) FOR PointsEarned;
    ALTER TABLE dbo.MEMBER_MONTHLY_SPENDING ADD CONSTRAINT DF_MEMBER_MONTHLY_SPENDING_UpdatedAt    DEFAULT (SYSUTCDATETIME()) FOR UpdatedAt;

    COMMIT TRANSACTION;
    PRINT 'V002 applied: INVOICE.PaidAt, 12 CHECK constraints, 4 DEFAULT constraints';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
