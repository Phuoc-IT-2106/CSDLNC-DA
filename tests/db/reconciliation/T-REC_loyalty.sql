/* =====================================================================
   T-REC_loyalty.sql - TEST_ONLY (sqlcmd mode), read-only
   Work order : WO-P3-P3-02 (acceptance criterion 3; 11 section 2.6 reconciliation). Runs in
   FitLife_P3_UC05 (fixtures) or FitLife_P3_UC05L (DS-L copy) right after usp_P3_EvaluateTiers was run
   for $(AsOfDate) with no concurrent activity.
     T-REC-01  every (member, month) row of MEMBER_MONTHLY_SPENDING = SUM(FinalAmount) of the member's
               PAID invoices of that Asia/Ho_Chi_Minh month (independent oracle: AT TIME ZONE
               'SE Asia Standard Time' on the UTC PaidAt), and no PAID invoice is missing a row
     T-REC-02  PointsEarned = FLOOR(TotalSpend / 100000) on every row; CurrentPoints = SUM(PointsEarned)
               for every member (D-006, D-024)
     T-REC-04  MEMBER.Tier_ID = the tier computed INDEPENDENTLY from INVOICE (never from the monthly
               aggregate): window spend = SUM(FinalAmount) of PAID invoices whose local month lies in the
               twelve local months ending with the month of $(AsOfDate) (D-007), tier = highest
               MEMBER_TIER threshold <= spend (D-008 rule)
   Prints a tier distribution (counts per tier) for context.
   Run: sqlcmd -S localhost -E -I -b -W -d <db> -v AsOfDate=2026-11-09 -i tests/db/reconciliation/T-REC_loyalty.sql
   ===================================================================== */
:on error exit
SET NOCOUNT ON;
SET ANSI_WARNINGS ON;

IF DB_NAME() NOT IN (N'FitLife_P3_UC05', N'FitLife_P3_UC05L')
    THROW 51280, N'T-REC_loyalty runs only in FitLife_P3_UC05 or FitLife_P3_UC05L.', 1;

DECLARE @asOf date = '$(AsOfDate)';
DECLARE @lastMonth date = DATEFROMPARTS(YEAR(@asOf), MONTH(@asOf), 1);
DECLARE @firstMonth date = DATEADD(MONTH, -11, @lastMonth);
DECLARE @checks TABLE (seq int IDENTITY(1,1), check_id varchar(10), result varchar(4), descr nvarchar(300), detail nvarchar(2000));
DECLARE @n int, @n2 int, @n3 int, @rows int;

CREATE TABLE #paid (Member_ID int NOT NULL, LocalMonth date NOT NULL, FinalAmount decimal(18,2) NOT NULL);
INSERT #paid
SELECT i.Member_ID, DATEFROMPARTS(YEAR(l.loc), MONTH(l.loc), 1), i.FinalAmount
FROM dbo.INVOICE AS i
CROSS APPLY (SELECT CONVERT(datetime2(3), (i.PaidAt AT TIME ZONE 'UTC') AT TIME ZONE 'SE Asia Standard Time') AS loc) AS l
WHERE i.PaymentStatus = 'PAID';

/* T-REC-01 */
WITH agg AS (SELECT Member_ID, LocalMonth, SUM(FinalAmount) AS total FROM #paid GROUP BY Member_ID, LocalMonth)
SELECT @n = COUNT(*), @n2 = SUM(CASE WHEN s.Member_ID IS NULL THEN 1 ELSE 0 END), @n3 = SUM(CASE WHEN a.Member_ID IS NULL THEN 1 ELSE 0 END)
FROM agg AS a FULL OUTER JOIN dbo.MEMBER_MONTHLY_SPENDING AS s ON s.Member_ID = a.Member_ID AND s.SpendingMonth = a.LocalMonth
WHERE s.Member_ID IS NULL OR a.Member_ID IS NULL OR s.TotalSpend <> a.total;
SET @rows = (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING);
INSERT @checks VALUES ('T-REC-01', CASE WHEN ISNULL(@n, 0) = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Monthly spending = PAID invoices per local month (independent AT TIME ZONE oracle)',
    CONCAT(N'mismatched member-months: ', ISNULL(@n, 0), N' (missing row ', ISNULL(@n2, 0), N', row without PAID invoices ', ISNULL(@n3, 0), N'); spending rows ', @rows,
           N'; PAID invoices ', (SELECT COUNT(*) FROM #paid)));

/* T-REC-02 */
SET @n = (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING WHERE PointsEarned <> CONVERT(int, FLOOR(TotalSpend / 100000)));
SET @n2 = (SELECT COUNT(*) FROM dbo.MEMBER AS m
           WHERE m.CurrentPoints <> ISNULL((SELECT SUM(PointsEarned) FROM dbo.MEMBER_MONTHLY_SPENDING AS s WHERE s.Member_ID = m.Member_ID), 0));
INSERT @checks VALUES ('T-REC-02', CASE WHEN @n = 0 AND @n2 = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'PointsEarned = FLOOR(TotalSpend / 100000) per row; CurrentPoints = SUM(PointsEarned) per member',
    CONCAT(N'rows violating the point rule: ', @n, N'; members with CurrentPoints <> SUM(PointsEarned): ', @n2, N'; members ', (SELECT COUNT(*) FROM dbo.MEMBER),
           N'; total points ', (SELECT SUM(CAST(CurrentPoints AS bigint)) FROM dbo.MEMBER)));

/* T-REC-04 */
CREATE TABLE #oracle (Member_ID int NOT NULL PRIMARY KEY, Spend decimal(38,2) NOT NULL, Tier_ID int NULL);
INSERT #oracle (Member_ID, Spend)
SELECT m.Member_ID, ISNULL((SELECT SUM(p.FinalAmount) FROM #paid AS p WHERE p.Member_ID = m.Member_ID AND p.LocalMonth >= @firstMonth AND p.LocalMonth <= @lastMonth), 0)
FROM dbo.MEMBER AS m;
UPDATE o SET Tier_ID = (SELECT TOP (1) t.Tier_ID FROM dbo.MEMBER_TIER AS t WHERE t.SpendingThreshold <= o.Spend ORDER BY t.SpendingThreshold DESC) FROM #oracle AS o;
SELECT @n = COUNT(*) FROM dbo.MEMBER AS m JOIN #oracle AS o ON o.Member_ID = m.Member_ID WHERE m.Tier_ID <> o.Tier_ID OR o.Tier_ID IS NULL;
INSERT @checks VALUES ('T-REC-04', CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END,
    N'Tier_ID = tier computed independently from INVOICE for the twelve local months ending with the as-of month (D-007, D-008 rule)',
    CONCAT(N'as of ', CONVERT(varchar(10), @asOf, 23), N' (window ', CONVERT(varchar(10), @firstMonth, 23), N' .. ', CONVERT(varchar(10), @lastMonth, 23), N'); members with a wrong tier: ', @n));

SELECT check_id, result, descr, detail FROM @checks ORDER BY seq;
PRINT '-- tier distribution (context) --';
SELECT t.Tier_ID, t.Tier_Name, t.SpendingThreshold, COUNT(m.Member_ID) AS members
FROM dbo.MEMBER_TIER AS t LEFT JOIN dbo.MEMBER AS m ON m.Tier_ID = t.Tier_ID
GROUP BY t.Tier_ID, t.Tier_Name, t.SpendingThreshold ORDER BY t.SpendingThreshold;
DROP TABLE #paid; DROP TABLE #oracle;

DECLARE @fails int = (SELECT COUNT(*) FROM @checks WHERE result = 'FAIL'), @nchk int = (SELECT COUNT(*) FROM @checks);
PRINT CONCAT('T-REC_loyalty SUMMARY: as-of ', CONVERT(varchar(10), @asOf, 23), '; checks=', @nchk, ' FAIL=', @fails);
IF @fails > 0 BEGIN PRINT 'T-REC_loyalty_RESULT: FAIL'; THROW 51281, N'T-REC_loyalty failed.', 1; END
ELSE PRINT 'T-REC_loyalty_RESULT: PASS';
GO
