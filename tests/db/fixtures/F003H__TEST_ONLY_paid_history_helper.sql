/* =====================================================================
   F003H__TEST_ONLY_paid_history_helper.sql  (sqlcmd mode)
   Classification : TEST_ONLY_HELPER - NOT PRODUCTION. Never deployed outside isolated databases.
   Work order     : WO-P3-P3-01 task 2 (T-F05-36) and WO-P3-P3-02 (T-F05-12, -13, -33, -34).
   Why            : settlement always stamps PaidAt with the server UTC time (DEP-17), so tests of the
                    twelve-month tier window, of month and year boundaries and of downgrades need
                    PAID invoices in past months. This helper inserts such history directly and
                    consistently in ONE transaction:
                      INVOICE (PAID, method CASH, IssuedAt = PaidAt - 5 min) + one product line;
                      MEMBER_MONTHLY_SPENDING row of the local month of PaidAt (dbo.tvf_P3_SpendingMonth,
                      the same function settlement uses): TotalSpend += amount, PointsEarned =
                      FLOOR(TotalSpend / 100000) (D-006), UpdatedAt = latest PaidAt;
                      MEMBER.CurrentPoints += points delta (D-024);
                      the invoice id in dbo.TEST_HistoryInvoice (history invoices never passed through the
                      settlement hooks, so the hook-call integrity check excludes exactly these ids).
                    It writes no tier (Tier_ID is changed only by the routines under test).
   Objects        : dbo.TEST_HistoryInvoice (table), dbo.TEST_p3_AddPaidHistory (procedure)
   Guards         : FitLife_P3_UC05 with the WO-P3-P3-00 marker; settlement objects and F002P present.
   ===================================================================== */
:on error exit
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF DB_NAME() <> N'FitLife_P3_UC05'
   OR NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable' AND CONVERT(nvarchar(200), value) LIKE N'WO-P3-P3-00%')
    THROW 51032, N'F003H (TEST_ONLY) may run only in FitLife_P3_UC05 with the WO-P3-P3-00 marker.', 1;
IF OBJECT_ID(N'dbo.tvf_P3_SpendingMonth', N'IF') IS NULL OR COL_LENGTH(N'dbo.MEMBER', N'CurrentPoints') IS NULL OR OBJECT_ID(N'dbo.TEST_HistoryInvoice', N'U') IS NOT NULL
    THROW 51033, N'F003H (TEST_ONLY): needs the settlement objects and F002P, and must not be applied twice.', 1;
GO

CREATE TABLE dbo.TEST_HistoryInvoice (Invoice_ID INT NOT NULL, CONSTRAINT PK_TEST_HistoryInvoice PRIMARY KEY CLUSTERED (Invoice_ID));
EXEC sys.sp_addextendedproperty @name = N'Classification', @value = N'TEST_ONLY_HELPER', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'TEST_HistoryInvoice';
GO

CREATE OR ALTER PROCEDURE dbo.TEST_p3_AddPaidHistory
    @Member_ID   INT,
    @PaidAtUtc   DATETIME2(3),
    @Amount      DECIMAL(18,2),
    @Invoice_ID  INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @month date, @delta int;
    DECLARE @ids TABLE (Invoice_ID int);
    DECLARE @spend TABLE (OldPoints int, NewPoints int);
    IF @Member_ID IS NULL OR @PaidAtUtc IS NULL OR @Amount IS NULL OR @Amount < 0 OR @PaidAtUtc > SYSUTCDATETIME()
        THROW 52940, N'TEST_p3_AddPaidHistory: member, past UTC payment time and a non-negative amount are required.', 1;
    SELECT @month = SpendingMonth FROM dbo.tvf_P3_SpendingMonth(@PaidAtUtc);

    BEGIN TRANSACTION;
    INSERT dbo.INVOICE (Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount, PaymentMethod, PaymentStatus, PaidAt)
    OUTPUT INSERTED.Invoice_ID INTO @ids
    VALUES (@Member_ID, 1, 1, DATEADD(MINUTE, -5, @PaidAtUtc), @Amount, 0, @Amount, 'CASH', 'PAID', @PaidAtUtc);
    SET @Invoice_ID = (SELECT Invoice_ID FROM @ids);
    INSERT dbo.INVOICE_PRODUCT_ITEM (Invoice_ID, [LineNo], Product_ID, Quantity, UnitPrice, DiscountAmount) VALUES (@Invoice_ID, 1, 1, 1, @Amount, 0);

    UPDATE dbo.MEMBER_MONTHLY_SPENDING WITH (UPDLOCK, HOLDLOCK)
    SET TotalSpend = TotalSpend + @Amount, PointsEarned = CONVERT(int, FLOOR((TotalSpend + @Amount) / 100000)),
        UpdatedAt = CASE WHEN UpdatedAt > @PaidAtUtc THEN UpdatedAt ELSE @PaidAtUtc END
    OUTPUT deleted.PointsEarned, inserted.PointsEarned INTO @spend
    WHERE Member_ID = @Member_ID AND SpendingMonth = @month;
    IF @@ROWCOUNT = 0
        INSERT dbo.MEMBER_MONTHLY_SPENDING (Member_ID, SpendingMonth, TotalSpend, PointsEarned, UpdatedAt)
        OUTPUT 0, inserted.PointsEarned INTO @spend
        VALUES (@Member_ID, @month, @Amount, CONVERT(int, FLOOR(@Amount / 100000)), @PaidAtUtc);
    SELECT @delta = NewPoints - OldPoints FROM @spend;
    UPDATE dbo.MEMBER SET CurrentPoints = CurrentPoints + @delta WHERE Member_ID = @Member_ID;
    INSERT dbo.TEST_HistoryInvoice (Invoice_ID) VALUES (@Invoice_ID);
    COMMIT TRANSACTION;
END;
GO
EXEC sys.sp_addextendedproperty @name = N'Classification', @value = N'TEST_ONLY_HELPER', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'PROCEDURE', @level1name = N'TEST_p3_AddPaidHistory';
PRINT 'F003H (TEST_ONLY) applied: dbo.TEST_p3_AddPaidHistory, dbo.TEST_HistoryInvoice';
GO
