/* Q-UC05-B - loyalty lookup (F21, 1,200/day): points, stored tier and D-007 window spend of one member.
   FROZEN baseline query text (WO-P3-P3-02 task 0, 2026-11-09; 10 section 4.1). Never edited afterwards;
   an optimised variant gets a new file. Parameters: @Member_ID INT, @FromMonth DATE, @NextMonth DATE
   (half-open window on SpendingMonth). Access path expected: PK seek on MEMBER, PK range on
   MEMBER_MONTHLY_SPENDING (<= 12 rows), PK seek on MEMBER_TIER. */
SELECT m.Member_ID, m.CurrentPoints, t.Tier_Name, ISNULL(w.WindowSpend, 0) AS WindowSpend
FROM dbo.MEMBER AS m
JOIN dbo.MEMBER_TIER AS t ON t.Tier_ID = m.Tier_ID
OUTER APPLY (SELECT SUM(s.TotalSpend) AS WindowSpend
             FROM dbo.MEMBER_MONTHLY_SPENDING AS s
             WHERE s.Member_ID = m.Member_ID AND s.SpendingMonth >= @FromMonth AND s.SpendingMonth < @NextMonth) AS w
WHERE m.Member_ID = @Member_ID;
