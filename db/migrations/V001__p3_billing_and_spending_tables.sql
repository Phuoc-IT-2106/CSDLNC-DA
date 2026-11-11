/* =====================================================================
   V001__p3_billing_and_spending_tables.sql
   Classification : P3_OWNED — production migration (Person 3)
   Work order     : WO-P3-P1-01 — Physical Schema Foundation
   Purpose        : Phase 1 structure (S-02 §10) of the four Person 3 tables:
                    INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM,
                    MEMBER_MONTHLY_SPENDING — columns, primary keys, the
                    8 foreign keys, and BR13.
   Decisions      : D-002 (SQL Server), D-014 (INT ids, DECIMAL(18,2) money,
                    DATETIME2(3) timestamps stored in UTC), D-018 (clustered
                    PK on Invoice_ID), D-026 restricted (P3-owned tables only).
   Requires       : the shared parent tables below, with these keys
                    (integration interface, docs/phase2/person3/12 §2a).
                    They are NOT created here and never altered here:
                      dbo.MEMBER(Member_ID INT PK)
                      dbo.BRANCH(Branch_ID INT PK)
                      dbo.EMPLOYEE(Employee_ID INT PK)
                      dbo.SERVICE_PLAN(Plan_ID INT PK)
                      dbo.PRODUCT(Product_ID INT PK)
   Notes          : forward-only; apply once. All-or-nothing (one transaction).
                    LineNo is a T-SQL reserved word and is always written [LineNo].
                    Error numbers 51001–51005 use the proposed P3 range (12 §3 item 7).
   ===================================================================== */
SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    /* Prerequisites: shared parents must exist (team schema, or TEST_ONLY fixtures in an isolated database). */
    IF OBJECT_ID(N'dbo.MEMBER', N'U')       IS NULL THROW 51001, N'V001 requires shared table dbo.MEMBER (Member_ID INT PK); see 12 §2a.', 1;
    IF OBJECT_ID(N'dbo.BRANCH', N'U')       IS NULL THROW 51002, N'V001 requires shared table dbo.BRANCH (Branch_ID INT PK); see 12 §2a.', 1;
    IF OBJECT_ID(N'dbo.EMPLOYEE', N'U')     IS NULL THROW 51003, N'V001 requires shared table dbo.EMPLOYEE (Employee_ID INT PK); see 12 §2a.', 1;
    IF OBJECT_ID(N'dbo.SERVICE_PLAN', N'U') IS NULL THROW 51004, N'V001 requires shared table dbo.SERVICE_PLAN (Plan_ID INT PK); see 12 §2a.', 1;
    IF OBJECT_ID(N'dbo.PRODUCT', N'U')      IS NULL THROW 51005, N'V001 requires shared table dbo.PRODUCT (Product_ID INT PK); see 12 §2a.', 1;

    /* INVOICE (BR07, BR08). PaidAt and the payment/monetary CHECKs are added by V002. */
    CREATE TABLE dbo.INVOICE
    (
        Invoice_ID      INT IDENTITY(1,1) NOT NULL,
        Member_ID       INT               NOT NULL,
        Employee_ID     INT               NOT NULL,
        Branch_ID       INT               NOT NULL,
        IssuedAt        DATETIME2(3)      NOT NULL,   -- UTC (D-014)
        GrossAmount     DECIMAL(18,2)     NOT NULL,
        DiscountAmount  DECIMAL(18,2)     NOT NULL,
        FinalAmount     DECIMAL(18,2)     NOT NULL,   -- stored, not computed (D-023)
        PaymentMethod   VARCHAR(10)       NULL,       -- nullable before settlement (D-005)
        PaymentStatus   VARCHAR(10)       NOT NULL,
        CONSTRAINT PK_INVOICE PRIMARY KEY CLUSTERED (Invoice_ID),
        CONSTRAINT FK_INVOICE_MEMBER   FOREIGN KEY (Member_ID)   REFERENCES dbo.MEMBER (Member_ID)     ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_INVOICE_EMPLOYEE FOREIGN KEY (Employee_ID) REFERENCES dbo.EMPLOYEE (Employee_ID) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_INVOICE_BRANCH   FOREIGN KEY (Branch_ID)   REFERENCES dbo.BRANCH (Branch_ID)     ON DELETE NO ACTION ON UPDATE NO ACTION
    );

    /* INVOICE_SERVICE_ITEM (BR09, BR10, BR13). */
    CREATE TABLE dbo.INVOICE_SERVICE_ITEM
    (
        Invoice_ID          INT           NOT NULL,
        [LineNo]            SMALLINT      NOT NULL,
        Plan_ID             INT           NOT NULL,
        UnitPrice           DECIMAL(18,2) NOT NULL,
        DiscountAmount      DECIMAL(18,2) NOT NULL,
        ValidFrom           DATE          NULL,       -- set when the entitlement is activated (writer per contract)
        ValidUntil          DATE          NULL,
        PTSessionsRemaining INT           NULL,       -- written by the PT owner per contract
        CONSTRAINT PK_INVOICE_SERVICE_ITEM PRIMARY KEY CLUSTERED (Invoice_ID, [LineNo]),
        CONSTRAINT FK_INVOICE_SERVICE_ITEM_INVOICE      FOREIGN KEY (Invoice_ID) REFERENCES dbo.INVOICE (Invoice_ID)   ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_INVOICE_SERVICE_ITEM_SERVICE_PLAN FOREIGN KEY (Plan_ID)    REFERENCES dbo.SERVICE_PLAN (Plan_ID) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT CK_INVOICE_SERVICE_ITEM_Validity CHECK (ValidUntil >= ValidFrom)   -- BR13; passes when either is NULL
    );

    /* INVOICE_PRODUCT_ITEM (BR09, BR11). */
    CREATE TABLE dbo.INVOICE_PRODUCT_ITEM
    (
        Invoice_ID      INT           NOT NULL,
        [LineNo]        SMALLINT      NOT NULL,
        Product_ID      INT           NOT NULL,
        Quantity        INT           NOT NULL,
        UnitPrice       DECIMAL(18,2) NOT NULL,
        DiscountAmount  DECIMAL(18,2) NOT NULL,
        CONSTRAINT PK_INVOICE_PRODUCT_ITEM PRIMARY KEY CLUSTERED (Invoice_ID, [LineNo]),
        CONSTRAINT FK_INVOICE_PRODUCT_ITEM_INVOICE FOREIGN KEY (Invoice_ID) REFERENCES dbo.INVOICE (Invoice_ID) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_INVOICE_PRODUCT_ITEM_PRODUCT FOREIGN KEY (Product_ID) REFERENCES dbo.PRODUCT (Product_ID) ON DELETE NO ACTION ON UPDATE NO ACTION
    );

    /* MEMBER_MONTHLY_SPENDING (BR05, BR06). SpendingMonth rule (D-013) and defaults are added by V002. */
    CREATE TABLE dbo.MEMBER_MONTHLY_SPENDING
    (
        Member_ID      INT           NOT NULL,
        SpendingMonth  DATE          NOT NULL,   -- first day of the Asia/Ho_Chi_Minh month of PaidAt (D-013)
        TotalSpend     DECIMAL(18,2) NOT NULL,
        PointsEarned   INT           NOT NULL,
        UpdatedAt      DATETIME2(3)  NOT NULL,   -- UTC (D-014)
        CONSTRAINT PK_MEMBER_MONTHLY_SPENDING PRIMARY KEY CLUSTERED (Member_ID, SpendingMonth),
        CONSTRAINT FK_MEMBER_MONTHLY_SPENDING_MEMBER FOREIGN KEY (Member_ID) REFERENCES dbo.MEMBER (Member_ID) ON DELETE NO ACTION ON UPDATE NO ACTION
    );

    COMMIT TRANSACTION;
    PRINT 'V001 applied: INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM, MEMBER_MONTHLY_SPENDING';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
