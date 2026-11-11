/* =====================================================================
   F002P__TEST_ONLY_member_current_points.sql  (sqlcmd mode)
   Classification : TEST_ONLY_FIXTURE - NOT PRODUCTION. NOT A P3 MODULE.
   Work order     : WO-P3-P3-01 (settlement). Points-only subset of the F002 extension,
                    approved by the Project Owner on 2026-11-09 (Owner Directive "Close
                    Invoice Creation and Prioritize Settlement", session answer): MEMBER.CurrentPoints only.
   Purpose        : settlement credits loyalty points to MEMBER.CurrentPoints in the same
                    transaction as the PENDING->PAID transition (D-006 approved; D-024
                    accrual only). The key-only MEMBER fixture (F001) has no such column, so
                    this script adds the Phase 1 column, nothing else (DEP-02, 12 section 2b):
                      MEMBER.CurrentPoints INT NOT NULL, default 0 (existing rows get 0)
   Not included   : MEMBER.Tier_ID, MEMBER_TIER, tier thresholds or any tier behaviour
                    (D-007, D-008, D-009 are PROPOSED; WO-P3-P3-02). No CHECK constraint
                    (constraints on MEMBER belong to its owner, 12 section 2a); the P3 tests
                    assert the properties directly (V-UC05S U5).
   Owned by       : MEMBER belongs to another member's module. This fixture is replaced by the
                    approved team schema at P6 (D-026 condition 9; WO-P3-P6-01).
   Guards         : only FitLife_P3_UC05 carrying the WO-P3-P3-00 disposable marker; MEMBER must
                    be the F001 TEST_ONLY key-only fixture; the column must not exist yet.
   Run            : sqlcmd -S localhost -E -I -b -d FitLife_P3_UC05 -i tests/db/fixtures/F002P__TEST_ONLY_member_current_points.sql
   ===================================================================== */
:on error exit
SET XACT_ABORT ON;
SET NOCOUNT ON;

-- 2026-11-09 (WO-P3-P3-02): also allowed in the Owner-approved DS-L loyalty copy FitLife_P3_UC05L.
IF DB_NAME() NOT IN (N'FitLife_P3_UC05', N'FitLife_P3_UC05L')
    THROW 51024, N'F002P (TEST_ONLY) may run only in FitLife_P3_UC05 or FitLife_P3_UC05L.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable'
               AND ((DB_NAME() = N'FitLife_P3_UC05' AND CONVERT(nvarchar(200), value) LIKE N'WO-P3-P3-00%')
                 OR (DB_NAME() = N'FitLife_P3_UC05L' AND CONVERT(nvarchar(200), value) LIKE N'WO-P3-P2-01%WO-P3-P3-02%')))
    THROW 51025, N'F002P (TEST_ONLY) requires the disposable marker of its database.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 1 AND major_id = OBJECT_ID(N'dbo.MEMBER') AND minor_id = 0
               AND name = N'Classification' AND CONVERT(nvarchar(200), value) = N'TEST_ONLY_FIXTURE')
   OR (SELECT COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.MEMBER')) <> 1
    THROW 51026, N'F002P (TEST_ONLY): dbo.MEMBER is not the key-only F001 fixture (team schema present, or F002P already applied).', 1;

BEGIN TRY
    BEGIN TRANSACTION;
    ALTER TABLE dbo.MEMBER ADD CurrentPoints INT NOT NULL CONSTRAINT DF_MEMBER_CurrentPoints DEFAULT (0) WITH VALUES;
    EXEC sys.sp_addextendedproperty @name = N'Classification', @value = N'TEST_ONLY_FIXTURE (F002P points-only)',
         @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'MEMBER',
         @level2type = N'COLUMN', @level2name = N'CurrentPoints';
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT COUNT(*) AS members, SUM(CurrentPoints) AS total_points FROM dbo.MEMBER;
PRINT 'F002P (TEST_ONLY) applied: MEMBER.CurrentPoints INT NOT NULL DEFAULT 0 (points only; no tier)';
GO
