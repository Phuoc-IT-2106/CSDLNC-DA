<#
  T-CONC-07_tier_batch_serialisation.ps1 - TEST_ONLY concurrency test for WO-P3-P3-03 Part C (Owner directive of
  2026-11-10 section 5 "Tier Evaluation versus Tier Evaluation"; complements T-CONC-04F). Correctness only: times are
  context, NOT measurements (R-27). PowerShell 5.1, built-in System.Data.SqlClient; nothing installed; no setting changed.

  usp_P3_EvaluateTiers serialises runs with sp_getapplock (resource P3_usp_P3_EvaluateTiers, Exclusive, session
  owner, 60 s wait; error 51324 when the wait expires). Without it, an OLDER run (spending snapshot taken before a
  payment) could finish after a NEWER run and overwrite the newer, correct tier with a stale one.
    T1  deterministic stale-overwrite scenario. Run A (chunk 1) takes its spending snapshot and is then held at the
        chunk of member 21 by a blocker's row lock; meanwhile member 22 pays the Gold threshold and run B starts.
        Checks: B waits on the APPLICATION lock while A is held (never runs concurrently with A); after release A
        succeeds without a downgrade, B then reads fresh data and upgrades member 22; final Tier_ID of member 22 =
        Gold; every member's tier = independent oracle from INVOICE.
    T2  application-lock timeout: a session holds the lock; a run fails with 51324 after its 60 s wait and writes
        NOTHING (tier hash unchanged although member 23 is due for an upgrade); after release a run upgrades 23.
    T3  failure inside a run (lock timeout 1222 at the chunk of member 25, held by a blocker): the error is passed to
        the caller, the run's session keeps NO application lock and NO open transaction, and an immediate re-run on
        another session completes (member 25 upgraded).
    T4  client timeout (attention) during a run held at member 26 - CHARACTERISATION: records whether the cancelled
        session still holds the application lock / a transaction, and checks that closing that session releases
        everything and that a re-run then completes with the correct tiers.
    Z   final quiescent run + second run (no change); tiers = oracle; CurrentPoints = SUM(PointsEarned); no open
        transaction; no application lock left.
  Members 21-26 (no invoice, spending or points expected when the script starts). Thresholds read from MEMBER_TIER
  (TEST_ONLY synthetic values; D-008 values not approved).
  Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tests/db/concurrency/T-CONC-07_tier_batch_serialisation.ps1 -OutFile <path>
  Exit code 0 = PASS, 1 = FAIL.
#>
param(
    [string]$Server = 'localhost',
    [string]$Database = 'FitLife_P3_UC05',
    [string]$OutFile = ''
)
$ErrorActionPreference = 'Stop'
$inv = [Globalization.CultureInfo]::InvariantCulture
if ($Database -ne 'FitLife_P3_UC05') { throw 'T-CONC-07 runs only against FitLife_P3_UC05.' }
$connStr = "Server=$Server;Database=$Database;Integrated Security=SSPI;Application Name=P3-T-CONC-07;Pooling=false"
$lines = New-Object System.Collections.Generic.List[string]
function Log([string]$s) { $lines.Add($s); Write-Output $s }
function Utc([datetime]$d) { $d.ToString('yyyy-MM-dd HH:mm:ss.fff', $inv) }
function Open { $cn = New-Object System.Data.SqlClient.SqlConnection $connStr; $cn.Open(); return $cn }
function Spid($cn) { $c = $cn.CreateCommand(); $c.CommandText = 'SELECT @@SPID'; return [int]$c.ExecuteScalar() }
function Query([string]$sql, $cn = $null) {
    $own = $null -eq $cn; if ($own) { $cn = Open }
    try { $cmd = $cn.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 120; $da = New-Object System.Data.SqlClient.SqlDataAdapter $cmd; $dt = New-Object System.Data.DataTable; [void]$da.Fill($dt); return ,$dt }
    finally { if ($own) { $cn.Close() } }
}
function NonQ([string]$sql, $cn, $tx = $null) { $c = $cn.CreateCommand(); $c.CommandText = $sql; $c.CommandTimeout = 120; if ($tx) { $c.Transaction = $tx }; return $c.ExecuteNonQuery() }
function SqlErr($e) { $x = $e; while ($x -and -not ($x -is [System.Data.SqlClient.SqlException])) { $x = $x.InnerException }; if ($x) { return [pscustomobject]@{ N = $x.Number; M = $x.Message } }; return [pscustomobject]@{ N = -1; M = "$e" } }

$g = Query @"
SELECT (SELECT CONVERT(nvarchar(200), value) FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable') AS marker,
       (SELECT SpendingThreshold FROM dbo.MEMBER_TIER WHERE Tier_Name = N'Gold') AS gold, (SELECT Tier_ID FROM dbo.MEMBER_TIER WHERE Tier_Name = N'Gold') AS gold_id,
       (SELECT Tier_ID FROM dbo.MEMBER_TIER WHERE SpendingThreshold = 0) AS base_id,
       (SELECT COUNT(*) FROM dbo.INVOICE WHERE Member_ID BETWEEN 21 AND 26) + (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID BETWEEN 21 AND 26)
         + (SELECT ISNULL(SUM(CurrentPoints), 0) FROM dbo.MEMBER WHERE Member_ID BETWEEN 21 AND 26) AS used,
       MONTH(DATEADD(HOUR, 7, SYSUTCDATETIME())) AS m_now, MONTH(DATEADD(MINUTE, 10, DATEADD(HOUR, 7, SYSUTCDATETIME()))) AS m_soon,
       CONVERT(varchar(10), CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS date), 23) AS today
"@
$r0 = $g.Rows[0]
if (-not ("$($r0.marker)" -like 'WO-P3-P3-00*')) { throw 'Refusing to run: FitLife_P3_UC05 without the disposable marker.' }
if ($r0.gold -is [DBNull]) { throw 'TEST_ONLY tiers (F002T) not deployed.' }
if ([int]$r0.used -ne 0) { throw 'Members 21-26 must have no invoice, spending row or point.' }
if ([int]$r0.m_now -ne [int]$r0.m_soon) { throw 'Too close to a local month boundary; run again later.' }
$gold = [decimal]$r0.gold; $goldId = [int]$r0.gold_id; $baseId = [int]$r0.base_id; $today = "$($r0.today)"

Log 'T-CONC-07 - tier batch vs tier batch: application-lock serialisation, timeout and error paths (WO-P3-P3-03 Part C).'
Log ("Started (UTC): " + (Utc ([DateTime]::UtcNow)) + "; database $Database; evaluation date (local) $today; members 21-26; Gold threshold (TEST_ONLY synthetic) $gold")
Log ("Harness SHA-256: " + (Get-FileHash -Algorithm SHA256 $PSCommandPath).Hash)

function NewInvoice($cn, [int]$member, [decimal]$amount) {
    $svc = New-Object System.Data.DataTable; [void]$svc.Columns.Add('LineNo', [int16]); [void]$svc.Columns.Add('Plan_ID', [int]); [void]$svc.Columns.Add('UnitPrice', [decimal]); [void]$svc.Columns.Add('DiscountAmount', [decimal])
    $prd = New-Object System.Data.DataTable; [void]$prd.Columns.Add('LineNo', [int16]); [void]$prd.Columns.Add('Product_ID', [int]); [void]$prd.Columns.Add('Quantity', [int]); [void]$prd.Columns.Add('UnitPrice', [decimal]); [void]$prd.Columns.Add('DiscountAmount', [decimal])
    [void]$svc.Rows.Add([int16]1, 1, $amount, [decimal]0)
    $cmd = $cn.CreateCommand(); $cmd.CommandType = [System.Data.CommandType]::StoredProcedure; $cmd.CommandText = 'dbo.usp_P3_CreateInvoice'
    $cmd.Parameters.Add('@Member_ID', [System.Data.SqlDbType]::Int).Value = $member; $cmd.Parameters.Add('@Employee_ID', [System.Data.SqlDbType]::Int).Value = 1; $cmd.Parameters.Add('@Branch_ID', [System.Data.SqlDbType]::Int).Value = 1
    $p1 = $cmd.Parameters.Add('@ServiceLines', [System.Data.SqlDbType]::Structured); $p1.TypeName = 'dbo.tt_P3_InvoiceServiceLine'; $p1.Value = $svc
    $p2 = $cmd.Parameters.Add('@ProductLines', [System.Data.SqlDbType]::Structured); $p2.TypeName = 'dbo.tt_P3_InvoiceProductLine'; $p2.Value = $prd
    $o1 = $cmd.Parameters.Add('@Invoice_ID', [System.Data.SqlDbType]::Int); $o1.Direction = [System.Data.ParameterDirection]::Output
    [void]$cmd.ExecuteNonQuery(); return [int]$o1.Value
}
function Settle($cn, [int]$id) { [void](NonQ "DECLARE @o varchar(20); EXEC dbo.usp_P3_SettleInvoice @Invoice_ID = $id, @PaymentMethod = 'CASH', @Outcome = @o OUTPUT;" $cn) }
function EvalCmd($cn, [int]$chunk, [int]$timeout = 120, [string]$prefix = '') {
    $cmd = $cn.CreateCommand(); $cmd.CommandTimeout = $timeout
    $cmd.CommandText = "$prefix DECLARE @u int, @d int, @e int; EXEC dbo.usp_P3_EvaluateTiers @ChunkSize = $chunk, @Evaluated = @e OUTPUT, @Upgrades = @u OUTPUT, @Downgrades = @d OUTPUT; SET @pu = @u; SET @pd = @d;"
    $pu = $cmd.Parameters.Add('@pu', [System.Data.SqlDbType]::Int); $pu.Direction = [System.Data.ParameterDirection]::Output
    $pd = $cmd.Parameters.Add('@pd', [System.Data.SqlDbType]::Int); $pd.Direction = [System.Data.ParameterDirection]::Output
    return $cmd
}
function EvalNow($cn, [int]$chunk = 4000, [int]$timeout = 120, [string]$prefix = '') {
    $c = EvalCmd $cn $chunk $timeout $prefix; $err = 0; $msg = ''
    try { [void]$c.ExecuteNonQuery() } catch { $e = SqlErr $_.Exception; $err = $e.N; $msg = $e.M }
    return [pscustomobject]@{ Err = $err; Msg = $msg; Up = $(if ($err -eq 0) { [int]$c.Parameters['@pu'].Value } else { $null }); Down = $(if ($err -eq 0) { [int]$c.Parameters['@pd'].Value } else { $null }) }
}
function WaitRow($mon, [int]$spid, [int]$blocker, [int]$ms = 15000) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $ms) {
        $t = Query "SELECT wait_type, blocking_session_id, wait_resource FROM sys.dm_exec_requests WHERE session_id = $spid" $mon
        if ($t.Rows.Count -gt 0 -and [int]$t.Rows[0].blocking_session_id -eq $blocker) { return "$($t.Rows[0].wait_type) on $($t.Rows[0].wait_resource)" }
        Start-Sleep -Milliseconds 25
    }
    return $null
}
function WaitAppLock($mon, [int]$spid, [int]$ms = 15000) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $ms) {
        $t = Query "SELECT request_mode, request_status, resource_description FROM sys.dm_tran_locks WHERE request_session_id = $spid AND resource_type = 'APPLICATION' AND request_status = 'WAIT'" $mon
        if ($t.Rows.Count -gt 0) { return "$($t.Rows[0].request_mode) $($t.Rows[0].request_status) $($t.Rows[0].resource_description)" }
        Start-Sleep -Milliseconds 25
    }
    return $null
}
function AppLockHolders($mon) { $t = Query "SELECT request_session_id, request_status FROM sys.dm_tran_locks WHERE resource_type = 'APPLICATION' AND resource_description LIKE '%P3_usp_P3_EvaluateTiers%'" $mon; return @($t.Rows | ForEach-Object { "$($_.request_session_id):$($_.request_status)" }) }
function OpenTran($mon, [int]$spid) { $t = Query "SELECT open_transaction_count FROM sys.dm_exec_sessions WHERE session_id = $spid" $mon; if ($t.Rows.Count -eq 0) { return -1 }; return [int]$t.Rows[0].open_transaction_count }
function Tier($mon, [int]$m) { return [int](Query "SELECT Tier_ID FROM dbo.MEMBER WHERE Member_ID = $m" $mon).Rows[0].Tier_ID }
function TierHash($mon) { return "$((Query "SELECT CONVERT(varchar(64), HASHBYTES('SHA2_256', (SELECT STRING_AGG(CONVERT(varchar(max), CONCAT(Member_ID, ':', Tier_ID)), ',') WITHIN GROUP (ORDER BY Member_ID) FROM dbo.MEMBER)), 2) AS h" $mon).Rows[0].h)" }
function OracleWrong($mon) {
    $t = Query @"
WITH paid AS (SELECT i.Member_ID, i.FinalAmount, DATEFROMPARTS(YEAR(l.loc), MONTH(l.loc), 1) AS lm
              FROM dbo.INVOICE AS i CROSS APPLY (SELECT CONVERT(datetime2(3), (i.PaidAt AT TIME ZONE 'UTC') AT TIME ZONE 'SE Asia Standard Time') AS loc) AS l
              WHERE i.PaymentStatus = 'PAID'),
     w AS (SELECT DATEFROMPARTS(YEAR('$today'), MONTH('$today'), 1) AS last_m),
     sp AS (SELECT m.Member_ID, m.Tier_ID, ISNULL((SELECT SUM(p.FinalAmount) FROM paid AS p CROSS JOIN w WHERE p.Member_ID = m.Member_ID AND p.lm BETWEEN DATEADD(MONTH, -11, w.last_m) AND w.last_m), 0) AS s FROM dbo.MEMBER AS m)
SELECT COUNT(*) AS wrong FROM sp WHERE sp.Tier_ID <> (SELECT TOP (1) t.Tier_ID FROM dbo.MEMBER_TIER AS t WHERE t.SpendingThreshold <= sp.s ORDER BY t.SpendingThreshold DESC)
"@ $mon
    return [int]$t.Rows[0].wrong
}
$checks = New-Object System.Collections.Generic.List[object]
function Check([string]$id, [bool]$ok, [string]$descr, [string]$detail) { $checks.Add([pscustomobject]@{ Id = $id; Result = $(if ($ok) { 'PASS' } else { 'FAIL' }); Descr = $descr; Detail = $detail }); Log ("  {0} {1}  {2} | {3}" -f $id, $(if ($ok) { 'PASS' } else { 'FAIL' }), $descr, $detail) }

$mon = Open; $setup = Open
$q0 = EvalNow $setup
Log ("Pre-test quiescent run: error $($q0.Err); upgrades $($q0.Up); downgrades $($q0.Down); application-lock holders: $((AppLockHolders $mon) -join ',')")

# ================= T1 =================
Log ''; Log 'T1 - stale-overwrite scenario (run A holds an old snapshot, payment commits, run B starts)'
$id22 = NewInvoice $setup 22 $gold
$blk = Open; $cA = Open; $cB = Open; $bSpid = Spid $blk; $aSpid = Spid $cA; $bbSpid = Spid $cB
$btx = $blk.BeginTransaction(); [void](NonQ 'DECLARE @x int; SELECT @x = Member_ID FROM dbo.MEMBER WITH (UPDLOCK, ROWLOCK) WHERE Member_ID = 21;' $blk $btx)
$cmdA = EvalCmd $cA 1; $arA = $cmdA.BeginExecuteNonQuery()
$heldA = WaitRow $mon $aSpid $bSpid
Settle $setup $id22
$paid22 = "$((Query "SELECT PaymentStatus FROM dbo.INVOICE WHERE Invoice_ID = $id22" $mon).Rows[0].PaymentStatus)"
$cmdB = EvalCmd $cB 1; $arB = $cmdB.BeginExecuteNonQuery()
$waitB = WaitAppLock $mon $bbSpid
$bDoneEarly = $arB.IsCompleted; $aDoneEarly = $arA.IsCompleted
$btx.Rollback()
$errA = 0; $msgA = ''; try { [void]$cmdA.EndExecuteNonQuery($arA) } catch { $e = SqlErr $_.Exception; $errA = $e.N; $msgA = $e.M }; $tAEnd = [DateTime]::UtcNow
$errB = 0; $msgB = ''; try { [void]$cmdB.EndExecuteNonQuery($arB) } catch { $e = SqlErr $_.Exception; $errB = $e.N; $msgB = $e.M }
$upA = $(if ($errA -eq 0) { [int]$cmdA.Parameters['@pu'].Value }); $dnA = $(if ($errA -eq 0) { [int]$cmdA.Parameters['@pd'].Value })
$upB = $(if ($errB -eq 0) { [int]$cmdB.Parameters['@pu'].Value }); $dnB = $(if ($errB -eq 0) { [int]$cmdB.Parameters['@pd'].Value })
$t22 = Tier $mon 22; $w1 = OracleWrong $mon
$blk.Close(); $cA.Close(); $cB.Close()
$ok1 = $heldA -and ($paid22 -eq 'PAID') -and $waitB -and -not $bDoneEarly -and -not $aDoneEarly -and ($errA -eq 0) -and ($errB -eq 0) -and ($dnA -eq 0) -and ($dnB -eq 0) -and ($upB -ge 1) -and ($t22 -eq $goldId) -and ($w1 -eq 0)
Check 'T1' $ok1 'Run B never overlaps run A: it waits on the application lock, then reads fresh data; no stale overwrite; member 22 Gold; all tiers = oracle' ("A held after its snapshot: $heldA; member 22 invoice $paid22 while A held; B waiting: $waitB; A error $errA $msgA, upgrades $upA, downgrades $dnA; B error $errB $msgB, upgrades $upB, downgrades $dnB; member 22 tier $t22 (Gold = $goldId); oracle mismatches $w1")

# ================= T2 =================
Log ''; Log 'T2 - application lock held by another session: 60 s wait, error 51324, nothing written'
$id23 = NewInvoice $setup 23 $gold; Settle $setup $id23
$hold = Open; $holdSpid = Spid $hold
$hc = $hold.CreateCommand(); $hc.CommandText = "DECLARE @r int; EXEC @r = sys.sp_getapplock @Resource = N'P3_usp_P3_EvaluateTiers', @LockMode = N'Exclusive', @LockOwner = N'Session', @LockTimeout = 0; SELECT @r;"
$got = [int]$hc.ExecuteScalar()
$hB = TierHash $mon
$cC = Open; $sw = [Diagnostics.Stopwatch]::StartNew(); $rc = EvalNow $cC 4000 120; $sw.Stop(); $cC.Close()
$hA = TierHash $mon; $t23a = Tier $mon 23
$hc = $hold.CreateCommand(); $hc.CommandText = "DECLARE @r int; EXEC @r = sys.sp_releaseapplock @Resource = N'P3_usp_P3_EvaluateTiers', @LockOwner = N'Session'; SELECT @r;"; $rel = [int]$hc.ExecuteScalar(); $hold.Close()
$rd = EvalNow $setup; $t23b = Tier $mon 23
$ok2 = ($got -eq 0) -and ($rc.Err -eq 51324) -and ($hA -eq $hB) -and ($t23a -eq $baseId) -and ($rel -eq 0) -and ($rd.Err -eq 0) -and ($rd.Up -ge 1) -and ($t23b -eq $goldId)
Check 'T2' $ok2 'While another session holds the lock, a run fails with 51324 and writes nothing; after release a run upgrades member 23' ("sp_getapplock by holder: $got; run error $($rc.Err) after about $([Math]::Round($sw.Elapsed.TotalSeconds)) s (context only); tier hash unchanged: $($hA -eq $hB); member 23 tier during hold $t23a (base $baseId); release $rel; next run error $($rd.Err) upgrades $($rd.Up); member 23 tier $t23b")

# ================= T3 =================
Log ''; Log 'T3 - error inside a run (1222 at the chunk of member 25): lock released, no open transaction, re-run completes'
$id25 = NewInvoice $setup 25 $gold; Settle $setup $id25
$blk = Open; $cE = Open; $eSpid = Spid $cE; $bSpid = Spid $blk
$btx = $blk.BeginTransaction(); [void](NonQ 'DECLARE @x int; SELECT @x = Member_ID FROM dbo.MEMBER WITH (UPDLOCK, ROWLOCK) WHERE Member_ID = 25;' $blk $btx)
$re = EvalNow $cE 1 120 'SET LOCK_TIMEOUT 2000;'
$holdersE = AppLockHolders $mon; $openE = OpenTran $mon $eSpid
$t25a = Tier $mon 25
$btx.Rollback(); $blk.Close()
$cF = Open; $rf = EvalNow $cF 4000 120; $cF.Close(); $cE.Close()
$t25b = Tier $mon 25
$ok3 = ($re.Err -eq 1222) -and ($holdersE.Count -eq 0) -and ($openE -eq 0) -and ($t25a -eq $baseId) -and ($rf.Err -eq 0) -and ($rf.Up -ge 1) -and ($t25b -eq $goldId)
Check 'T3' $ok3 'A run failing inside a chunk passes the error on, keeps no application lock and no open transaction; the failed chunk wrote nothing; an immediate re-run completes' ("run error $($re.Err) ($($re.Msg)); application-lock holders after the error: [$($holdersE -join ',')]; open transactions of that session: $openE; member 25 tier after failure $t25a; re-run error $($rf.Err) upgrades $($rf.Up); member 25 tier $t25b")

# ================= T4 =================
Log ''; Log 'T4 - client timeout (attention) during a run: characterisation of the session-owned lock'
$id26 = NewInvoice $setup 26 $gold; Settle $setup $id26
$blk = Open; $cG = Open; $gSpid = Spid $cG; $bSpid = Spid $blk
$btx = $blk.BeginTransaction(); [void](NonQ 'DECLARE @x int; SELECT @x = Member_ID FROM dbo.MEMBER WITH (UPDLOCK, ROWLOCK) WHERE Member_ID = 26;' $blk $btx)
$rg = EvalNow $cG 1 3
Start-Sleep -Milliseconds 300
$holdersG = AppLockHolders $mon; $openG = OpenTran $mon $gSpid
$probe = Open; $pc = $probe.CreateCommand(); $pc.CommandText = "DECLARE @r int; EXEC @r = sys.sp_getapplock @Resource = N'P3_usp_P3_EvaluateTiers', @LockMode = N'Exclusive', @LockOwner = N'Session', @LockTimeout = 0; IF @r >= 0 EXEC sys.sp_releaseapplock @Resource = N'P3_usp_P3_EvaluateTiers', @LockOwner = N'Session'; SELECT @r;"
$probeWhileOpen = [int]$pc.ExecuteScalar()
$btx.Rollback(); $blk.Close()
$cG.Close(); Start-Sleep -Milliseconds 300
$holdersAfterClose = AppLockHolders $mon
$probeAfterClose = [int]$pc.ExecuteScalar(); $probe.Close()
$rh = EvalNow $setup; $t26 = Tier $mon 26
$heldAfterTimeout = ($holdersG.Count -gt 0)
$ok4 = ($rg.Err -eq -2 -or $rg.Err -eq 0 -or $rg.Err -eq -1) -and ($holdersAfterClose.Count -eq 0) -and ($probeAfterClose -ge 0) -and ($rh.Err -eq 0) -and ($t26 -eq $goldId)
Check 'T4' $ok4 'After a client timeout, closing the cancelled session releases everything and a re-run completes with the correct tier (characterisation recorded in the detail)' ("client error $($rg.Err) ($($rg.Msg)); while the cancelled session stays open: application-lock holders [$($holdersG -join ',')], its open transactions $openG, probe sp_getapplock(timeout 0) = $probeWhileOpen (negative = lock still held); after closing it: holders [$($holdersAfterClose -join ',')], probe $probeAfterClose; re-run error $($rh.Err); member 26 tier $t26")
Log ("T4 OBSERVATION: session-owned application lock " + $(if ($heldAfterTimeout) { "STAYS HELD by a client-cancelled session until that session closes (open transactions: $openG); other runs get 51324 meanwhile" } else { 'was released after the client timeout' }))

# ================= Z =================
Log ''; Log 'Z - final state'
$z1 = EvalNow $setup; $z2 = EvalNow $setup
$wZ = OracleWrong $mon
$pts = Query "SELECT COUNT(*) AS n FROM dbo.MEMBER AS m WHERE m.CurrentPoints <> ISNULL((SELECT SUM(PointsEarned) FROM dbo.MEMBER_MONTHLY_SPENDING AS s WHERE s.Member_ID = m.Member_ID), 0)" $mon
$open = Query "SELECT COUNT(*) AS n FROM sys.dm_exec_sessions WHERE is_user_process = 1 AND open_transaction_count > 0 AND session_id <> @@SPID AND database_id = DB_ID()" $mon
$holdZ = AppLockHolders $mon
Check 'Z' (($z1.Err -eq 0) -and ($z1.Down -eq 0) -and ($z2.Err -eq 0) -and ($z2.Up -eq 0) -and ($z2.Down -eq 0) -and ($wZ -eq 0) -and ([int]$pts.Rows[0].n -eq 0) -and ([int]$open.Rows[0].n -eq 0) -and ($holdZ.Count -eq 0)) 'Final run consistent and idempotent; tiers = oracle; CurrentPoints = SUM(PointsEarned); no open transaction or application lock left' ("final run upgrades $($z1.Up) downgrades $($z1.Down); second run upgrades $($z2.Up) downgrades $($z2.Down); oracle mismatches $wZ; points mismatches $($pts.Rows[0].n); open transactions $($open.Rows[0].n); lock holders [$($holdZ -join ',')]")
$mon.Close(); $setup.Close()

$nf = @($checks | Where-Object { $_.Result -eq 'FAIL' }).Count
Log ''; Log ("T-CONC-07 SUMMARY: checks $($checks.Count); FAIL $nf"); Log ("T-CONC-07_RESULT: " + $(if ($nf -eq 0) { 'PASS' } else { 'FAIL' }))
if ($OutFile) { $lines | Out-File -Encoding utf8 $OutFile }
if ($nf -eq 0) { exit 0 } else { exit 1 }
