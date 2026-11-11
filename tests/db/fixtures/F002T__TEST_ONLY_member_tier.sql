/* =====================================================================
   F002T__TEST_ONLY_member_tier.sql  (sqlcmd mode)
   Classification : TEST_ONLY_FIXTURE - NOT PRODUCTION. NOT A P3 MODULE.
   Work order     : WO-P3-P3-01 task 2 and WO-P3-P3-02. Tier part of the F002 extension,
                    approved as TEST_ONLY by the Project Owner on 2026-11-09 (Owner Directive
                    "Finalize UC05 Settlement and Implement Loyalty" section 5).
   Purpose        : minimum stand-ins for the shared loyalty structures (DEP-02, DEP-03):
                      dbo.MEMBER_TIER (Tier_ID, Tier_Name, SpendingThreshold) - Phase 1 columns (S-02 section 10)
                      dbo.MEMBER.Tier_ID INT NOT NULL + FK -> MEMBER_TIER (Phase 1 FK, BR04)
                    Every member starts on the base tier (threshold 0).
   Tier names     : Silver, Gold, Platinum (official, S-01).
   THRESHOLDS     : Silver = 0 is the approved base-tier rule (D-008 rule, 2026-11-09).
                    Gold and Platinum values are **SYNTHETIC TEST VALUES**, supplied by the caller as
                    sqlcmd variables GoldThreshold and PlatinumThreshold (no default in this file).
                    The business values are NOT approved (D-008 values open). These values must
                    never be copied into db/, reports or evidence as business thresholds.
   Not included   : UNIQUE or CHECK constraints on MEMBER_TIER (they belong to the table owner,
                    12 section 2a); the P3 routines validate the tier configuration themselves.
   Owned by       : MEMBER and MEMBER_TIER belong to other members' modules; replaced by the
                    approved team schema at P6 (D-026 condition 9).
   Guards         : FitLife_P3_UC05 (WO-P3-P3-00 marker) or FitLife_P3_UC05L (WO-P3-P2-01 ... WO-P3-P3-02
                    marker); F002P applied; MEMBER_TIER and MEMBER.Tier_ID absent; 0 < Gold < Platinum.
   Run            : sqlcmd -S localhost -E -I -b -d FitLife_P3_UC05 -v GoldThreshold=1000000.00 PlatinumThreshold=3000000.00 -i tests/db/fixtures/F002T__TEST_ONLY_member_tier.sql
   ===================================================================== */
:on error exit
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF DB_NAME() NOT IN (N'FitLife_P3_UC05', N'FitLife_P3_UC05L')
   OR NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable'
                  AND ((DB_NAME() = N'FitLife_P3_UC05' AND CONVERT(nvarchar(200), value) LIKE N'WO-P3-P3-00%')
                    OR (DB_NAME() = N'FitLife_P3_UC05L' AND CONVERT(nvarchar(200), value) LIKE N'WO-P3-P2-01%WO-P3-P3-02%')))
    THROW 51029, N'F002T (TEST_ONLY) may run only in FitLife_P3_UC05 or FitLife_P3_UC05L with their disposable markers.', 1;
IF COL_LENGTH(N'dbo.MEMBER', N'CurrentPoints') IS NULL OR COL_LENGTH(N'dbo.MEMBER', N'Tier_ID') IS NOT NULL OR OBJECT_ID(N'dbo.MEMBER_TIER', N'U') IS NOT NULL
    THROW 51030, N'F002T (TEST_ONLY): requires F002P and no existing tier structures.', 1;
DECLARE @gold decimal(18,2) = $(GoldThreshold), @plat decimal(18,2) = $(PlatinumThreshold);
IF NOT (@gold > 0 AND @plat > @gold)
    THROW 51031, N'F002T (TEST_ONLY): synthetic thresholds must satisfy 0 < Gold < Platinum.', 1;
GO

BEGIN TRY
    BEGIN TRANSACTION;
    CREATE TABLE dbo.MEMBER_TIER
    (
        Tier_ID            INT           NOT NULL,
        Tier_Name          NVARCHAR(50)  NOT NULL,
        SpendingThreshold  DECIMAL(18,2) NOT NULL,
        CONSTRAINT PK_MEMBER_TIER PRIMARY KEY CLUSTERED (Tier_ID)
    );
    EXEC (N'INSERT dbo.MEMBER_TIER (Tier_ID, Tier_Name, SpendingThreshold) VALUES
             (1, N''Silver'', 0.00), (2, N''Gold'', $(GoldThreshold)), (3, N''Platinum'', $(PlatinumThreshold));');
    ALTER TABLE dbo.MEMBER ADD Tier_ID INT NULL;
    EXEC (N'UPDATE dbo.MEMBER SET Tier_ID = 1;');
    EXEC (N'ALTER TABLE dbo.MEMBER ALTER COLUMN Tier_ID INT NOT NULL;');
    EXEC (N'ALTER TABLE dbo.MEMBER WITH CHECK ADD CONSTRAINT FK_MEMBER_MEMBER_TIER FOREIGN KEY (Tier_ID) REFERENCES dbo.MEMBER_TIER (Tier_ID) ON DELETE NO ACTION ON UPDATE NO ACTION;');
    EXEC sys.sp_addextendedproperty @name = N'Classification', @value = N'TEST_ONLY_FIXTURE (F002T; Gold/Platinum thresholds are TEST_ONLY_SYNTHETIC, not business values)',
         @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'MEMBER_TIER';
    EXEC sys.sp_addextendedproperty @name = N'Classification', @value = N'TEST_ONLY_FIXTURE (F002T)',
         @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'MEMBER',
         @level2type = N'COLUMN', @level2name = N'Tier_ID';
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT Tier_ID, Tier_Name, SpendingThreshold FROM dbo.MEMBER_TIER ORDER BY SpendingThreshold;
SELECT COUNT(*) AS members, SUM(CASE WHEN Tier_ID = 1 THEN 1 ELSE 0 END) AS on_base_tier FROM dbo.MEMBER;
PRINT 'F002T (TEST_ONLY) applied: MEMBER_TIER (Silver 0 + SYNTHETIC Gold/Platinum) and MEMBER.Tier_ID NOT NULL FK; all members on the base tier';
GO
