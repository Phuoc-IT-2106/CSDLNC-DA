/* =====================================================================
   usp_P3_EvaluateTiers.sql
   Classification : P3_OWNED - production routine (Person 3). Programmability only.
   Work order     : WO-P3-P3-02 task 2 (F22 periodic tier evaluation).
   Objects        : dbo.tvf_P3_TierWindow   (inline: local evaluation date -> [FromMonth, NextMonth))
                    dbo.tvf_P3_TierForSpend (inline: window spend -> tier by the D-008 rule)
                    dbo.usp_P3_EvaluateTiers (procedure)
   Decisions      : D-007 (d) APPROVED T2: twelve Asia/Ho_Chi_Minh calendar months = the local month of
                    @AsOfDate and the eleven preceding months, half-open on SpendingMonth; advances on the
                    1st of each local month; not a rolling 365-day period.
                    D-008 rule APPROVED T2: base tier = the tier with SpendingThreshold 0 (Silver);
                    spend >= threshold qualifies; the highest eligible threshold wins; thresholds are read
                    from MEMBER_TIER and never hard-coded (the VALUES are not approved - configuration).
                    D-009 (a) APPROVED T2: periodic batch, intended daily; no scheduler is created here;
                    a tier may lag until the next run (accepted).
                    D-019 (a): READ COMMITTED; short per-chunk transactions; atomic single-column updates.
   Interface      : @AsOfDate   DATE, local Asia/Ho_Chi_Minh date (NULL = today local = UTC + 7 h)
                    @ChunkSize  INT, members per transaction (1..4500, below lock escalation; default 4000)
                    OUTPUT @Evaluated, @Upgrades, @Downgrades, @Unchanged; also one result row
                    (AsOfDate, FromMonth, NextMonth, Evaluated, Upgrades, Downgrades, Unchanged).
   Steps          : 1 refuse an open caller transaction (the routine commits per chunk) and an invalid
                    tier configuration (exactly one tier at 0, thresholds unique and >= 0) - nothing written;
                    2 window spend per member from MEMBER_MONTHLY_SPENDING only (<= 12 rows per member;
                    no INVOICE access - no history rescan); members without rows have spend 0 -> base tier;
                    3 target tier per member (D-008 rule);
                    4 update MEMBER.Tier_ID ONLY where it differs, in Member_ID-range chunks, each its own
                    short transaction (XACT_ABORT); classify upgrades/downgrades by threshold.
   Concurrency    : step 2 is one read statement that keeps no locks afterwards; step 4 holds only MEMBER
                    row locks of one chunk. Settlement writes MEMBER_MONTHLY_SPENDING then
                    MEMBER.CurrentPoints; this routine writes only MEMBER.Tier_ID, so no column is lost and
                    no lock cycle exists. A payment committed after step 2 is reflected by the next run.
                    Runs are serialised by an application lock (sp_getapplock, session owner, 60 s wait):
                    two overlapping runs could otherwise let an older spending snapshot overwrite the
                    result of a newer run (a spurious downgrade). Error 51324 if the wait expires.
   Re-run         : idempotent for unchanged data (second run for the same date changes 0 rows).
                    A failed chunk rolls back completely and the error is re-raised; chunks already
                    committed are correct for @AsOfDate; re-running completes the rest.
   Errors         : 51320 open caller transaction; 51321 invalid @ChunkSize; 51322 not exactly one base tier
                    at 0 (or no tier); 51323 negative or duplicate thresholds.
   Re-runnable    : CREATE OR ALTER.
   ===================================================================== */
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.MEMBER_MONTHLY_SPENDING', N'U') IS NULL OR OBJECT_ID(N'dbo.MEMBER_TIER', N'U') IS NULL OR COL_LENGTH(N'dbo.MEMBER', N'Tier_ID') IS NULL
    THROW 51319, N'usp_P3_EvaluateTiers requires MEMBER_MONTHLY_SPENDING, MEMBER_TIER and MEMBER.Tier_ID (DEP-02, DEP-03).', 1;
GO

/* D-007: [FromMonth, NextMonth) for a local evaluation date. */
CREATE OR ALTER FUNCTION dbo.tvf_P3_TierWindow (@AsOfDate DATE)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT DATEADD(MONTH, -11, m.MonthStart) AS FromMonth, DATEADD(MONTH, 1, m.MonthStart) AS NextMonth
    FROM (SELECT DATEFROMPARTS(YEAR(@AsOfDate), MONTH(@AsOfDate), 1) AS MonthStart) AS m;
GO

/* D-008 rule: the tier with the highest SpendingThreshold <= spend (inclusive). Values come from MEMBER_TIER. */
CREATE OR ALTER FUNCTION dbo.tvf_P3_TierForSpend (@Spend DECIMAL(38,2))
RETURNS TABLE
AS
RETURN
    SELECT TOP (1) t.Tier_ID, t.Tier_Name, t.SpendingThreshold
    FROM dbo.MEMBER_TIER AS t
    WHERE t.SpendingThreshold <= @Spend
    ORDER BY t.SpendingThreshold DESC;
GO

CREATE OR ALTER PROCEDURE dbo.usp_P3_EvaluateTiers
    @AsOfDate    DATE = NULL,
    @ChunkSize   INT = 4000,
    @Evaluated   INT = NULL OUTPUT,
    @Upgrades    INT = NULL OUTPUT,
    @Downgrades  INT = NULL OUTPUT,
    @Unchanged   INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @from date, @next date, @lo int, @hi int, @lock int;
    DECLARE @spend TABLE (Member_ID int NOT NULL PRIMARY KEY, Spend decimal(38,2) NOT NULL);
    DECLARE @target TABLE (Member_ID int NOT NULL PRIMARY KEY, Tier_ID int NOT NULL);
    DECLARE @chg TABLE (Member_ID int NOT NULL, OldTier int NOT NULL, NewTier int NOT NULL);
    DECLARE @chunk TABLE (Member_ID int NOT NULL, OldTier int NOT NULL, NewTier int NOT NULL);

    SELECT @Evaluated = 0, @Upgrades = 0, @Downgrades = 0, @Unchanged = 0;

    /* ---------- 1. Preconditions (no write) ---------- */
    IF @@TRANCOUNT > 0
        THROW 51320, N'usp_P3_EvaluateTiers: must not run inside a caller transaction (it commits per chunk).', 1;
    IF @ChunkSize IS NULL OR @ChunkSize < 1 OR @ChunkSize > 4500
        THROW 51321, N'usp_P3_EvaluateTiers: @ChunkSize must be between 1 and 4500 (below lock escalation).', 1;
    IF (SELECT COUNT(*) FROM dbo.MEMBER_TIER WHERE SpendingThreshold = 0) <> 1
        THROW 51322, N'usp_P3_EvaluateTiers: MEMBER_TIER must contain exactly one base tier with SpendingThreshold 0 (D-008 rule).', 1;
    IF EXISTS (SELECT 1 FROM dbo.MEMBER_TIER WHERE SpendingThreshold < 0)
       OR EXISTS (SELECT SpendingThreshold FROM dbo.MEMBER_TIER GROUP BY SpendingThreshold HAVING COUNT(*) > 1)
        THROW 51323, N'usp_P3_EvaluateTiers: MEMBER_TIER thresholds must be non-negative and unique (D-008 rule).', 1;

    IF @AsOfDate IS NULL SET @AsOfDate = CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS date);   -- today in Asia/Ho_Chi_Minh
    SELECT @from = FromMonth, @next = NextMonth FROM dbo.tvf_P3_TierWindow(@AsOfDate);

    /* Runs are serialised: a second concurrent call waits (up to 60 s) and then reads fresh data, so an
       older snapshot can never overwrite the result of a newer run. Session-owned, released on every path. */
    EXEC @lock = sys.sp_getapplock @Resource = N'P3_usp_P3_EvaluateTiers', @LockMode = N'Exclusive', @LockOwner = N'Session', @LockTimeout = 60000;
    IF @lock < 0
        THROW 51324, N'usp_P3_EvaluateTiers: another tier evaluation is still running (waited 60 s).', 1;
    BEGIN TRY

    /* ---------- 2. Window spend from the monthly aggregate only (one read; no locks kept) ---------- */
    INSERT @spend (Member_ID, Spend)
    SELECT s.Member_ID, SUM(s.TotalSpend)
    FROM dbo.MEMBER_MONTHLY_SPENDING AS s
    WHERE s.SpendingMonth >= @from AND s.SpendingMonth < @next
    GROUP BY s.Member_ID;

    /* ---------- 3. Target tier for every member (spend 0 -> base tier) ---------- */
    INSERT @target (Member_ID, Tier_ID)
    SELECT m.Member_ID, t.Tier_ID
    FROM dbo.MEMBER AS m
    LEFT JOIN @spend AS sp ON sp.Member_ID = m.Member_ID
    CROSS APPLY dbo.tvf_P3_TierForSpend(ISNULL(sp.Spend, 0)) AS t;
    SET @Evaluated = @@ROWCOUNT;

    /* ---------- 4. Update only changed rows, chunk by chunk ---------- */
    SET @lo = (SELECT MIN(Member_ID) FROM @target);
    WHILE @lo IS NOT NULL
    BEGIN
        SET @hi = (SELECT MAX(Member_ID) FROM (SELECT TOP (@ChunkSize) Member_ID FROM @target WHERE Member_ID >= @lo ORDER BY Member_ID) AS c);
        DELETE @chunk;
        BEGIN TRY
            BEGIN TRANSACTION;
            UPDATE m
            SET Tier_ID = t.Tier_ID
            OUTPUT inserted.Member_ID, deleted.Tier_ID, inserted.Tier_ID INTO @chunk (Member_ID, OldTier, NewTier)
            FROM dbo.MEMBER AS m
            JOIN @target AS t ON t.Member_ID = m.Member_ID
            WHERE m.Member_ID BETWEEN @lo AND @hi AND m.Tier_ID <> t.Tier_ID;
            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
            THROW;
        END CATCH;
        INSERT @chg SELECT Member_ID, OldTier, NewTier FROM @chunk;
        SET @lo = (SELECT MIN(Member_ID) FROM @target WHERE Member_ID > @hi);
    END;

    SELECT @Upgrades = ISNULL(SUM(CASE WHEN tNew.SpendingThreshold > tOld.SpendingThreshold THEN 1 ELSE 0 END), 0),
           @Downgrades = ISNULL(SUM(CASE WHEN tNew.SpendingThreshold < tOld.SpendingThreshold THEN 1 ELSE 0 END), 0)
    FROM @chg AS c
    JOIN dbo.MEMBER_TIER AS tNew ON tNew.Tier_ID = c.NewTier
    JOIN dbo.MEMBER_TIER AS tOld ON tOld.Tier_ID = c.OldTier;
    SET @Unchanged = @Evaluated - (SELECT COUNT(*) FROM @chg);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        EXEC sys.sp_releaseapplock @Resource = N'P3_usp_P3_EvaluateTiers', @LockOwner = N'Session';
        THROW;
    END CATCH;
    EXEC sys.sp_releaseapplock @Resource = N'P3_usp_P3_EvaluateTiers', @LockOwner = N'Session';

    SELECT @AsOfDate AS AsOfDate, @from AS FromMonth, @next AS NextMonth, @Evaluated AS Evaluated,
           @Upgrades AS Upgrades, @Downgrades AS Downgrades, @Unchanged AS Unchanged;
    RETURN 0;
END;
GO

PRINT 'usp_P3_EvaluateTiers applied: functions dbo.tvf_P3_TierWindow, dbo.tvf_P3_TierForSpend; procedure dbo.usp_P3_EvaluateTiers';
GO
