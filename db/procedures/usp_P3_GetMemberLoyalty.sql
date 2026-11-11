/* =====================================================================
   usp_P3_GetMemberLoyalty.sql
   Classification : P3_OWNED - production routine (Person 3). Read-only.
   Work order     : WO-P3-P3-02 task 1 (F21 loyalty lookup, Q-UC05-B access path).
   Decisions      : D-006, D-024 (CurrentPoints, accrual only); D-007 (d) window; D-008 rule (tiers and
                    thresholds read from MEMBER_TIER); D-009 (a) (the stored tier is the tier of the last
                    batch run - it may lag; the evaluated tier is what the next run for @AsOfDate assigns).
   Interface      : @Member_ID INT required; @AsOfDate DATE (local; NULL = today in Asia/Ho_Chi_Minh).
                    One row: Member_ID, CurrentPoints, Tier_ID, Tier_Name (stored), FromMonth, NextMonth,
                    WindowSpend, EvaluatedTier_ID, EvaluatedTier_Name, NextTier_Name, NextTierThreshold,
                    AmountToNextTier (NULL at the top tier).
   Access         : PK lookup on MEMBER, PK range on MEMBER_MONTHLY_SPENDING (<= 12 rows), MEMBER_TIER.
                    No INVOICE access. No write, no transaction.
   Errors         : 51330 Member_ID missing; 51331 unknown member; 51322/51323 invalid tier configuration.
   ===================================================================== */
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.tvf_P3_TierWindow', N'IF') IS NULL OR OBJECT_ID(N'dbo.tvf_P3_TierForSpend', N'IF') IS NULL
    THROW 51329, N'usp_P3_GetMemberLoyalty requires db/procedures/usp_P3_EvaluateTiers.sql (tier functions).', 1;
GO

CREATE OR ALTER PROCEDURE dbo.usp_P3_GetMemberLoyalty
    @Member_ID  INT,
    @AsOfDate   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @from date, @next date, @spend decimal(38,2), @msg nvarchar(400);

    IF @Member_ID IS NULL
        THROW 51330, N'usp_P3_GetMemberLoyalty: Member_ID is required.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.MEMBER WHERE Member_ID = @Member_ID)
    BEGIN
        SET @msg = CONCAT(N'usp_P3_GetMemberLoyalty: unknown Member_ID ', @Member_ID, N'.');
        THROW 51331, @msg, 1;
    END;
    IF (SELECT COUNT(*) FROM dbo.MEMBER_TIER WHERE SpendingThreshold = 0) <> 1
        THROW 51322, N'usp_P3_GetMemberLoyalty: MEMBER_TIER must contain exactly one base tier with SpendingThreshold 0 (D-008 rule).', 1;
    IF EXISTS (SELECT 1 FROM dbo.MEMBER_TIER WHERE SpendingThreshold < 0)
       OR EXISTS (SELECT SpendingThreshold FROM dbo.MEMBER_TIER GROUP BY SpendingThreshold HAVING COUNT(*) > 1)
        THROW 51323, N'usp_P3_GetMemberLoyalty: MEMBER_TIER thresholds must be non-negative and unique (D-008 rule).', 1;

    IF @AsOfDate IS NULL SET @AsOfDate = CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS date);
    SELECT @from = FromMonth, @next = NextMonth FROM dbo.tvf_P3_TierWindow(@AsOfDate);
    SELECT @spend = ISNULL(SUM(TotalSpend), 0)
    FROM dbo.MEMBER_MONTHLY_SPENDING
    WHERE Member_ID = @Member_ID AND SpendingMonth >= @from AND SpendingMonth < @next;

    SELECT m.Member_ID, m.CurrentPoints, m.Tier_ID, cur.Tier_Name,
           @from AS FromMonth, @next AS NextMonth, @spend AS WindowSpend,
           ev.Tier_ID AS EvaluatedTier_ID, ev.Tier_Name AS EvaluatedTier_Name,
           nx.Tier_Name AS NextTier_Name, nx.SpendingThreshold AS NextTierThreshold,
           CASE WHEN nx.SpendingThreshold IS NULL THEN NULL ELSE nx.SpendingThreshold - @spend END AS AmountToNextTier
    FROM dbo.MEMBER AS m
    JOIN dbo.MEMBER_TIER AS cur ON cur.Tier_ID = m.Tier_ID
    CROSS APPLY dbo.tvf_P3_TierForSpend(@spend) AS ev
    OUTER APPLY (SELECT TOP (1) t.Tier_Name, t.SpendingThreshold FROM dbo.MEMBER_TIER AS t
                 WHERE t.SpendingThreshold > @spend ORDER BY t.SpendingThreshold) AS nx
    WHERE m.Member_ID = @Member_ID;
    RETURN 0;
END;
GO

PRINT 'usp_P3_GetMemberLoyalty applied: procedure dbo.usp_P3_GetMemberLoyalty';
GO
