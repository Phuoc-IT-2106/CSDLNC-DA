/* Q-UC05-C - tier batch read (F22, 1/day): D-007 window spend of every member from the monthly aggregate.
   FROZEN baseline query text (WO-P3-P3-02 task 0, 2026-11-09; 10 section 4.1). Never edited afterwards;
   an optimised variant gets a new file. Parameters: @FromMonth DATE, @NextMonth DATE (half-open).
   It is the read step of usp_P3_EvaluateTiers. Index candidate IX-07 (SpendingMonth, Member_ID)
   INCLUDE (TotalSpend) is evaluated later (WO-P3-P3-03), not here. */
SELECT s.Member_ID, SUM(s.TotalSpend) AS WindowSpend
FROM dbo.MEMBER_MONTHLY_SPENDING AS s
WHERE s.SpendingMonth >= @FromMonth AND s.SpendingMonth < @NextMonth
GROUP BY s.Member_ID;
