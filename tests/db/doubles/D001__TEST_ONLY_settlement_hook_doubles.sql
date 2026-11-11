/* =====================================================================
   D001__TEST_ONLY_settlement_hook_doubles.sql  (sqlcmd mode)
   Classification : TEST_ONLY_DOUBLE - NOT PRODUCTION. NOT A P3 MODULE.
   Work order     : WO-P3-P3-01 task 3c (D-012 (a), APPROVED provisional T2 on 2026-11-09;
                    D-026 condition 6; DEP-05 in 12 section 2b).
   Purpose        : contract-only stand-ins for the two hooks that the P3 settlement routine
                    calls inside its transaction (12 section 5), so that settlement can be
                    tested in isolation:
                      dbo.usp_HOOK_InventoryDecrementForInvoice    (UC04 owner's routine at P6)
                      dbo.usp_HOOK_EntitlementActivationForInvoice (UC01 owner's routine at P6)
                    Contract assumed (DEP-05): one call per settled invoice, parameter
                    @Invoice_ID INT; called inside the caller's transaction (fails fast if
                    none is open, 12 section 4 rule 2); never commits or rolls back; raises an
                    error to abort the whole settlement.
   What a double does: (1) records the call in dbo.TEST_HookCallLog (hook, invoice, @@TRANCOUNT,
                    invoice status seen at call time); (2) raises a TEST_ONLY error when a row in
                    dbo.TEST_HookFault asks for it (fault injection, 52901 / 52902).
                    NO stock, inventory, entitlement, validity-date, PT or other domain logic.
                    The call-log row is written inside the settlement transaction, so it
                    disappears when the settlement rolls back.
   Replaced by    : the real routines in WO-P3-P6-01 (T-INT-01, T-INT-02, T-CONC-05).
   Guards         : only FitLife_P3_UC05 carrying the WO-P3-P3-00 disposable marker.
   Run            : sqlcmd -S localhost -E -I -b -d FitLife_P3_UC05 -i tests/db/doubles/D001__TEST_ONLY_settlement_hook_doubles.sql
   ===================================================================== */
:on error exit
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF DB_NAME() <> N'FitLife_P3_UC05'
   OR NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable'
                  AND CONVERT(nvarchar(200), value) LIKE N'WO-P3-P3-00%')
    THROW 51027, N'D001 (TEST_ONLY) may run only in FitLife_P3_UC05 carrying the WO-P3-P3-00 disposable marker.', 1;
IF OBJECT_ID(N'dbo.TEST_HookCallLog', N'U') IS NOT NULL OR OBJECT_ID(N'dbo.TEST_HookFault', N'U') IS NOT NULL
    THROW 51028, N'D001 (TEST_ONLY): the hook doubles already exist; rebuild the database first.', 1;
GO

CREATE TABLE dbo.TEST_HookCallLog
(
    Seq         INT IDENTITY(1,1) NOT NULL,
    HookName    VARCHAR(30)  NOT NULL,
    Invoice_ID  INT          NOT NULL,
    TranCount   INT          NOT NULL,
    StatusSeen  VARCHAR(10)  NULL,
    SessionId   SMALLINT     NOT NULL CONSTRAINT DF_TEST_HookCallLog_SessionId DEFAULT (@@SPID),
    CalledAt    DATETIME2(3) NOT NULL CONSTRAINT DF_TEST_HookCallLog_CalledAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_TEST_HookCallLog PRIMARY KEY CLUSTERED (Seq)
);
CREATE TABLE dbo.TEST_HookFault
(
    HookName    VARCHAR(30) NOT NULL,
    Invoice_ID  INT         NOT NULL,
    CONSTRAINT PK_TEST_HookFault PRIMARY KEY CLUSTERED (HookName, Invoice_ID)
);
GO

CREATE OR ALTER PROCEDURE dbo.usp_HOOK_InventoryDecrementForInvoice
    @Invoice_ID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT = 0
        THROW 52900, N'TEST_ONLY hook double: must be called inside the settlement transaction (12 section 4 rule 2).', 1;
    INSERT dbo.TEST_HookCallLog (HookName, Invoice_ID, TranCount, StatusSeen)
    VALUES ('INVENTORY_DECREMENT', @Invoice_ID, @@TRANCOUNT, (SELECT PaymentStatus FROM dbo.INVOICE WHERE Invoice_ID = @Invoice_ID));
    IF EXISTS (SELECT 1 FROM dbo.TEST_HookFault WHERE HookName = 'INVENTORY_DECREMENT' AND Invoice_ID = @Invoice_ID)
        THROW 52901, N'TEST_ONLY injected fault in the inventory-decrement hook (stands for e.g. insufficient stock, BR30).', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_HOOK_EntitlementActivationForInvoice
    @Invoice_ID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT = 0
        THROW 52900, N'TEST_ONLY hook double: must be called inside the settlement transaction (12 section 4 rule 2).', 1;
    INSERT dbo.TEST_HookCallLog (HookName, Invoice_ID, TranCount, StatusSeen)
    VALUES ('ENTITLEMENT_ACTIVATION', @Invoice_ID, @@TRANCOUNT, (SELECT PaymentStatus FROM dbo.INVOICE WHERE Invoice_ID = @Invoice_ID));
    IF EXISTS (SELECT 1 FROM dbo.TEST_HookFault WHERE HookName = 'ENTITLEMENT_ACTIVATION' AND Invoice_ID = @Invoice_ID)
        THROW 52902, N'TEST_ONLY injected fault in the entitlement-activation hook.', 1;
END;
GO

EXEC sys.sp_addextendedproperty @name = N'Classification', @value = N'TEST_ONLY_DOUBLE', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'TEST_HookCallLog';
EXEC sys.sp_addextendedproperty @name = N'Classification', @value = N'TEST_ONLY_DOUBLE', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'TEST_HookFault';
EXEC sys.sp_addextendedproperty @name = N'Classification', @value = N'TEST_ONLY_DOUBLE', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'PROCEDURE', @level1name = N'usp_HOOK_InventoryDecrementForInvoice';
EXEC sys.sp_addextendedproperty @name = N'Classification', @value = N'TEST_ONLY_DOUBLE', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'PROCEDURE', @level1name = N'usp_HOOK_EntitlementActivationForInvoice';
PRINT 'D001 (TEST_ONLY) applied: hook doubles usp_HOOK_InventoryDecrementForInvoice, usp_HOOK_EntitlementActivationForInvoice; tables TEST_HookCallLog, TEST_HookFault';
GO
