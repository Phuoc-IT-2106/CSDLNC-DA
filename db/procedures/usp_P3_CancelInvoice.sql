/* =====================================================================
   usp_P3_CancelInvoice.sql
   Classification : P3_OWNED - production routine (Person 3). Programmability only.
   Work order     : WO-P3-P3-01 task 3 - cancellation (D-011, APPROVED provisional T2, 2026-11-07)
   Purpose        : PENDING -> CANCELLED, nothing else. A cancelled invoice has no payment time,
                    no loyalty, spending, revenue, inventory or entitlement effect, and can never be
                    settled afterwards (usp_P3_SettleInvoice raises 51204). A PAID invoice cannot be
                    cancelled: refunds are outside the approved scope (D-011), so PAID is never
                    reverted. A correction of a PENDING invoice = cancellation + a new invoice
                    (D-028 Q3 (a)).
   Interface      : @Invoice_ID required; @Outcome OUTPUT 'CANCELLED' or 'ALREADY_CANCELLED'
                    (a repeated cancellation has no effect). Return value 0 on success.
   Concurrency    : UPDLOCK on the invoice row (D-019 (a)) + conditional update, so a cancellation
                    and a settlement of the same invoice serialise: exactly one of them wins.
   Errors         : 51221 Invoice_ID missing; 51222 invoice not found; 51223 invoice is PAID (refund
                    out of scope); 51224 transition did not change exactly one row (defensive).
   Transactions   : as usp_P3_SettleInvoice (owns a transaction, or joins the caller's; 12 section 4).
   Run            : sqlcmd -S localhost -E -I -b -d <database> -i db/procedures/usp_P3_CancelInvoice.sql
   ===================================================================== */
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.INVOICE', N'U') IS NULL OR COL_LENGTH(N'dbo.INVOICE', N'PaidAt') IS NULL
    THROW 51220, N'usp_P3_CancelInvoice requires migrations V001 and V002.', 1;
GO

CREATE OR ALTER PROCEDURE dbo.usp_P3_CancelInvoice
    @Invoice_ID  INT,
    @Outcome     VARCHAR(20) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @msg nvarchar(2048), @ownTran bit, @status varchar(10);
    SET @Outcome = NULL;

    IF @Invoice_ID IS NULL
        THROW 51221, N'usp_P3_CancelInvoice: Invoice_ID is required.', 1;

    SET @ownTran = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @ownTran = 1 BEGIN TRANSACTION;

        SELECT @status = PaymentStatus FROM dbo.INVOICE WITH (UPDLOCK, ROWLOCK) WHERE Invoice_ID = @Invoice_ID;
        IF @@ROWCOUNT = 0
        BEGIN
            SET @msg = CONCAT(N'usp_P3_CancelInvoice: invoice ', @Invoice_ID, N' does not exist.');
            THROW 51222, @msg, 1;
        END;

        IF @status = 'CANCELLED'
        BEGIN
            IF @ownTran = 1 COMMIT TRANSACTION;
            SET @Outcome = 'ALREADY_CANCELLED';
            RETURN 0;
        END;
        IF @status = 'PAID'
        BEGIN
            SET @msg = CONCAT(N'usp_P3_CancelInvoice: invoice ', @Invoice_ID, N' is PAID and cannot be cancelled (refunds are out of scope, D-011).');
            THROW 51223, @msg, 1;
        END;

        UPDATE dbo.INVOICE SET PaymentStatus = 'CANCELLED'
        WHERE Invoice_ID = @Invoice_ID AND PaymentStatus = 'PENDING';
        IF @@ROWCOUNT <> 1
            THROW 51224, N'usp_P3_CancelInvoice: the PENDING -> CANCELLED transition did not change exactly one row.', 1;

        IF @ownTran = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @ownTran = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SET @Outcome = 'CANCELLED';
    RETURN 0;
END;
GO

PRINT 'usp_P3_CancelInvoice applied: procedure dbo.usp_P3_CancelInvoice';
GO
