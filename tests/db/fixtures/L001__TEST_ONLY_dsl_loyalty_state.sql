/* =====================================================================
   L001__TEST_ONLY_dsl_loyalty_state.sql  (sqlcmd mode)
   Classification : TEST_ONLY_LOADER - NOT PRODUCTION. Only in the DS-L copy FitLife_P3_UC05L.
   Work order     : WO-P3-P3-02 (DS-L reconciliation, criterion 3).
   Why            : the accepted generator S001 writes the four P3 tables only (F002 was deferred in P2),
                    so after F002P/F002T every member has CurrentPoints 0 and the base tier. This loader
                    sets the loyalty balance that the approved rules imply for the generated data:
                      MEMBER.CurrentPoints = SUM(MEMBER_MONTHLY_SPENDING.PointsEarned)   (D-006, D-024)
                    It does not touch Tier_ID (the tier is assigned only by usp_P3_EvaluateTiers under
                    test) and never writes a P3 table.
   Guards         : database FitLife_P3_UC05L with its marker; F002P and F002T applied; balances all 0.
   ===================================================================== */
:on error exit
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF DB_NAME() <> N'FitLife_P3_UC05L'
   OR NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable' AND CONVERT(nvarchar(200), value) LIKE N'WO-P3-P2-01%WO-P3-P3-02%')
    THROW 51034, N'L001 (TEST_ONLY) runs only in FitLife_P3_UC05L with its marker.', 1;
IF COL_LENGTH(N'dbo.MEMBER', N'CurrentPoints') IS NULL OR COL_LENGTH(N'dbo.MEMBER', N'Tier_ID') IS NULL OR EXISTS (SELECT 1 FROM dbo.MEMBER WHERE CurrentPoints <> 0)
    THROW 51035, N'L001 (TEST_ONLY): needs F002P and F002T and all balances at 0.', 1;

BEGIN TRANSACTION;
UPDATE m SET CurrentPoints = s.pe
FROM dbo.MEMBER AS m
JOIN (SELECT Member_ID, SUM(PointsEarned) AS pe FROM dbo.MEMBER_MONTHLY_SPENDING GROUP BY Member_ID) AS s ON s.Member_ID = m.Member_ID;
COMMIT TRANSACTION;

SELECT COUNT(*) AS members, SUM(CASE WHEN CurrentPoints > 0 THEN 1 ELSE 0 END) AS members_with_points, SUM(CAST(CurrentPoints AS bigint)) AS total_points FROM dbo.MEMBER;
PRINT 'L001 (TEST_ONLY) applied: CurrentPoints = SUM(PointsEarned) per member';
GO
