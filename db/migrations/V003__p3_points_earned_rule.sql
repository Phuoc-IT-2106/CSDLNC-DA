/* =====================================================================
   V003__p3_points_earned_rule.sql
   Classification : P3_OWNED - production migration (Person 3), additive.
   Work order     : WO-P3-P3-02 (precondition text: "If D-006 option (b) is approved, this WO adds the
                    CHECK PointsEarned = FLOOR(TotalSpend / 100000) as an additive migration").
   Decision       : D-006 (b) APPROVED 2026-11-08: PointsEarned = FLOOR(TotalSpend / 100000) for every
                    (member, month) row.
   Purpose        : make the per-row point rule a database invariant of the P3-owned table
                    MEMBER_MONTHLY_SPENDING (row-level, so a CHECK can enforce it; the cross-table
                    invariant CurrentPoints = SUM(PointsEarned) stays a reconciliation check, T-REC-02).
   Effect         : one CHECK constraint, created WITH CHECK (existing rows are validated: the approved
                    seed S001 and the settlement routine already write exactly this value). No column,
                    index or data change. Shared tables are not touched.
   Notes          : forward-only; apply once (after V001, V002).
   ===================================================================== */
SET XACT_ABORT ON;
SET NOCOUNT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF OBJECT_ID(N'dbo.MEMBER_MONTHLY_SPENDING', N'U') IS NULL OR OBJECT_ID(N'dbo.CK_MEMBER_MONTHLY_SPENDING_NonNegative', N'C') IS NULL
        THROW 51007, N'V003 requires V001 and V002.', 1;
    IF OBJECT_ID(N'dbo.CK_MEMBER_MONTHLY_SPENDING_PointsRule', N'C') IS NOT NULL
        THROW 51008, N'V003 is already applied.', 1;
    ALTER TABLE dbo.MEMBER_MONTHLY_SPENDING WITH CHECK ADD CONSTRAINT CK_MEMBER_MONTHLY_SPENDING_PointsRule
        CHECK (PointsEarned = FLOOR(TotalSpend / 100000));                                   -- D-006 (b)
    COMMIT TRANSACTION;
    PRINT 'V003 applied: CK_MEMBER_MONTHLY_SPENDING_PointsRule (PointsEarned = FLOOR(TotalSpend / 100000))';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
