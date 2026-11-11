<#
  T-CONC-04F_settlement_vs_tier_batch.ps1 - TEST_ONLY concurrency test for WO-P3-P3-02 (functional variant of
  T-CONC-04: settlement concurrent with the tier batch; correctness only, NO timing - R-27). PowerShell 5.1.

  Before: one quiescent usp_P3_EvaluateTiers run (today). Then S settlement sessions settle K PENDING invoices each
  (members 21-36, amounts around Gold/8 so members cross thresholds during the run) while B batch sessions call
  usp_P3_EvaluateTiers (today, small chunks) in a loop until all settlements are done. After: a quiescent final
  run and a second final run. Checks on the FINAL DATABASE STATE:
    C1 every settlement SETTLED and every batch run succeeded (deadlock victims 1205 retried at the outermost
       level, max 3, counted)
    C2 no incorrect Tier_ID change: spending only grows during the test, so no batch run (concurrent or final)
       may report a downgrade
    C3 after the final run every member's Tier_ID equals the tier computed independently from INVOICE (D-007,
       D-008 rule)
    C4 no lost update: for members 21-36 the current-month spending grew by exactly the harness amounts,
       CurrentPoints = SUM(PointsEarned), and the increase of CurrentPoints = SUM of the points returned by the
       settlements
    C5 batch runs really overlapped settlement activity (at least 2 runs started before the last settlement ended)
    C6 the second final run changes nothing (idempotent)
  Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tests/db/concurrency/T-CONC-04F_settlement_vs_tier_batch.ps1 -RunLabel A -OutFile <path>
#>
param(
    [ValidateSet('A', 'B', 'C')][string]$RunLabel = 'A',
    [int]$SettleSessions = 8,
    [int]$PerSession = 25,
    [int]$BatchSessions = 2,
    [int]$ChunkSize = 5,
    [string]$Server = 'localhost',
    [string]$Database = 'FitLife_P3_UC05',
    [string]$OutFile = ''
)
$ErrorActionPreference = 'Stop'
$inv = [Globalization.CultureInfo]::InvariantCulture
if ($Database -ne 'FitLife_P3_UC05') { throw 'T-CONC-04F runs only against FitLife_P3_UC05.' }
$connStr = "Server=$Server;Database=$Database;Integrated Security=SSPI;Application Name=P3-T-CONC-04F;Pooling=false"
$lines = New-Object System.Collections.Generic.List[string]
function Log([string]$s) { $lines.Add($s); Write-Output $s }
function Utc([datetime]$d) { $d.ToString('yyyy-MM-dd HH:mm:ss.fff', $inv) }
function Query([string]$sql) {
    $cn = New-Object System.Data.SqlClient.SqlConnection $connStr; $cn.Open()
    try { $cmd = $cn.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 300; $da = New-Object System.Data.SqlClient.SqlDataAdapter $cmd; $dt = New-Object System.Data.DataTable; [void]$da.Fill($dt); return ,$dt }
    finally { $cn.Close() }
}
function Eval([System.Data.SqlClient.SqlConnection]$cn, [int]$chunk) {
    $retries = 0
    while ($true) {
        $cmd = $cn.CreateCommand(); $cmd.CommandType = [System.Data.CommandType]::StoredProcedure; $cmd.CommandText = 'dbo.usp_P3_EvaluateTiers'; $cmd.CommandTimeout = 120
        $cmd.Parameters.Add('@ChunkSize', [System.Data.SqlDbType]::Int).Value = $chunk
        $o = @{}; foreach ($n in 'Evaluated', 'Upgrades', 'Downgrades', 'Unchanged') { $p = $cmd.Parameters.Add("@$n", [System.Data.SqlDbType]::Int); $p.Direction = [System.Data.ParameterDirection]::Output; $o[$n] = $p }
        $err = 0; $msg = ''; $t0 = [DateTime]::UtcNow.Ticks
        try { [void]$cmd.ExecuteNonQuery() } catch { $ex = $_.Exception; while ($ex -and -not ($ex -is [System.Data.SqlClient.SqlException])) { $ex = $ex.InnerException }; if ($ex) { $err = $ex.Number; $msg = $ex.Message } else { $err = -1; $msg = $_.Exception.Message } }
        $t1 = [DateTime]::UtcNow.Ticks
        if ($err -eq 1205 -and $retries -lt 3) { $retries++; continue }
        return [pscustomobject]@{ Err = $err; Msg = $msg; Retries = $retries; T0 = $t0; T1 = $t1
            Up = $(if ($err -eq 0) { [int]$o['Upgrades'].Value } else { $null }); Down = $(if ($err -eq 0) { [int]$o['Downgrades'].Value } else { $null }); Ev = $(if ($err -eq 0) { [int]$o['Evaluated'].Value } else { $null }) }
    }
}

# ---- guards ----
$g = Query @"
SELECT (SELECT CONVERT(nvarchar(200), value) FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable') AS marker,
       OBJECT_ID(N'dbo.usp_P3_EvaluateTiers', N'P') AS eval_id, (SELECT SpendingThreshold FROM dbo.MEMBER_TIER WHERE Tier_Name = N'Gold') AS gold,
       MONTH(DATEADD(HOUR, 7, SYSUTCDATETIME())) AS m_now, MONTH(DATEADD(MINUTE, 10, DATEADD(HOUR, 7, SYSUTCDATETIME()))) AS m_soon,
       CONVERT(varchar(10), CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS date), 23) AS today
"@
if (-not ("$($g.Rows[0].marker)" -like 'WO-P3-P3-00*')) { throw 'Refusing to run: FitLife_P3_UC05 without the disposable marker.' }
if ($g.Rows[0].eval_id -is [DBNull]) { throw 'usp_P3_EvaluateTiers is not deployed.' }
if ([int]$g.Rows[0].m_now -ne [int]$g.Rows[0].m_soon) { throw 'Too close to a local month boundary; run again later.' }
$gold = [decimal]$g.Rows[0].gold; $today = "$($g.Rows[0].today)"
$members = 21..36; $memberList = ($members -join ',')

Log "T-CONC-04F - settlement concurrent with the tier batch (WO-P3-P3-02). Run $RunLabel."
Log ("Started (UTC): " + (Utc ([DateTime]::UtcNow)) + "; database $Database; $SettleSessions settlement sessions x $PerSession invoices; $BatchSessions batch sessions (chunk $ChunkSize); members $memberList; evaluation date (local) $today")
Log ("Harness SHA-256: " + (Get-FileHash -Algorithm SHA256 $PSCommandPath).Hash)
Log ("Gold threshold read from MEMBER_TIER (TEST_ONLY synthetic): $gold")

$cn0 = New-Object System.Data.SqlClient.SqlConnection $connStr; $cn0.Open()
$pre = Eval $cn0 4000
Log ("Pre-run quiescent evaluation: error $($pre.Err); upgrades $($pre.Up); downgrades $($pre.Down)")
$before = Query @"
SELECT m.Member_ID, m.CurrentPoints, ISNULL(s.TotalSpend, 0) AS month_spend
FROM dbo.MEMBER AS m LEFT JOIN dbo.MEMBER_MONTHLY_SPENDING AS s ON s.Member_ID = m.Member_ID
     AND s.SpendingMonth = (SELECT SpendingMonth FROM dbo.tvf_P3_SpendingMonth(SYSUTCDATETIME()))
WHERE m.Member_ID IN ($memberList)
"@
$bPts = @{}; $bSpend = @{}; foreach ($r in $before.Rows) { $bPts[[int]$r.Member_ID] = [int]$r.CurrentPoints; $bSpend[[int]$r.Member_ID] = [decimal]$r.month_spend }

# ---- prepare invoices ----
$plan = New-Object System.Collections.Generic.List[object]
foreach ($s in 1..$SettleSessions) {
    foreach ($k in 1..$PerSession) {
        $m = $members[($s * 7 + $k) % $members.Count]; $amt = [decimal]::Round($gold / 8 + 1111 * $s + 7 * $k, 2)
        $svc = New-Object System.Data.DataTable; [void]$svc.Columns.Add('LineNo', [int16]); [void]$svc.Columns.Add('Plan_ID', [int]); [void]$svc.Columns.Add('UnitPrice', [decimal]); [void]$svc.Columns.Add('DiscountAmount', [decimal])
        $prd = New-Object System.Data.DataTable; [void]$prd.Columns.Add('LineNo', [int16]); [void]$prd.Columns.Add('Product_ID', [int]); [void]$prd.Columns.Add('Quantity', [int]); [void]$prd.Columns.Add('UnitPrice', [decimal]); [void]$prd.Columns.Add('DiscountAmount', [decimal])
        [void]$prd.Rows.Add([int16]1, 1 + ($k % 10), 1, $amt, [decimal]0)
        $cmd = $cn0.CreateCommand(); $cmd.CommandType = [System.Data.CommandType]::StoredProcedure; $cmd.CommandText = 'dbo.usp_P3_CreateInvoice'
        $cmd.Parameters.Add('@Member_ID', [System.Data.SqlDbType]::Int).Value = $m; $cmd.Parameters.Add('@Employee_ID', [System.Data.SqlDbType]::Int).Value = 1; $cmd.Parameters.Add('@Branch_ID', [System.Data.SqlDbType]::Int).Value = 1
        $p1 = $cmd.Parameters.Add('@ServiceLines', [System.Data.SqlDbType]::Structured); $p1.TypeName = 'dbo.tt_P3_InvoiceServiceLine'; $p1.Value = $svc
        $p2 = $cmd.Parameters.Add('@ProductLines', [System.Data.SqlDbType]::Structured); $p2.TypeName = 'dbo.tt_P3_InvoiceProductLine'; $p2.Value = $prd
        $o1 = $cmd.Parameters.Add('@Invoice_ID', [System.Data.SqlDbType]::Int); $o1.Direction = [System.Data.ParameterDirection]::Output
        [void]$cmd.ExecuteNonQuery()
        $plan.Add([pscustomobject]@{ S = $s; K = $k; Id = [int]$o1.Value; Member = $m; Amount = $amt })
    }
}
Log ("Prepared $($plan.Count) PENDING invoices")

# ---- workers ----
$settleWorker = {
    param([int]$s, $ids, [string]$connStr, $ready, $gate)
    $res = New-Object System.Collections.Generic.List[object]
    $cn = New-Object System.Data.SqlClient.SqlConnection $connStr; $cn.Open()
    try {
        [void]$ready.Signal(); [void]$gate.WaitOne()
        foreach ($id in $ids) {
            $retries = 0
            while ($true) {
                $cmd = $cn.CreateCommand(); $cmd.CommandType = [System.Data.CommandType]::StoredProcedure; $cmd.CommandText = 'dbo.usp_P3_SettleInvoice'; $cmd.CommandTimeout = 60
                $cmd.Parameters.Add('@Invoice_ID', [System.Data.SqlDbType]::Int).Value = [int]$id
                $cmd.Parameters.Add('@PaymentMethod', [System.Data.SqlDbType]::VarChar, 10).Value = 'CASH'
                $o1 = $cmd.Parameters.Add('@Outcome', [System.Data.SqlDbType]::VarChar, 20); $o1.Direction = [System.Data.ParameterDirection]::Output
                $o2 = $cmd.Parameters.Add('@PointsEarned', [System.Data.SqlDbType]::Int); $o2.Direction = [System.Data.ParameterDirection]::Output
                $err = 0; $msg = ''; $t0 = [DateTime]::UtcNow.Ticks
                try { [void]$cmd.ExecuteNonQuery() } catch { $ex = $_.Exception; while ($ex -and -not ($ex -is [System.Data.SqlClient.SqlException])) { $ex = $ex.InnerException }; if ($ex) { $err = $ex.Number; $msg = $ex.Message } else { $err = -1; $msg = $_.Exception.Message } }
                $t1 = [DateTime]::UtcNow.Ticks
                if ($err -eq 1205 -and $retries -lt 3) { $retries++; continue }
                break
            }
            $res.Add([pscustomobject]@{ S = $s; Id = [int]$id; Outcome = "$($o1.Value)"; Err = $err; Msg = $msg; Retries = $retries; T0 = $t0; T1 = $t1
                                        Points = $(if ($o2.Value -is [DBNull] -or $null -eq $o2.Value) { 0 } else { [int]$o2.Value }) })
        }
    } finally { $cn.Close() }
    ,$res.ToArray()
}
$batchWorker = {
    param([int]$b, [string]$connStr, [int]$chunk, $ready, $gate, $done)
    $res = New-Object System.Collections.Generic.List[object]
    $cn = New-Object System.Data.SqlClient.SqlConnection $connStr; $cn.Open()
    try {
        [void]$ready.Signal(); [void]$gate.WaitOne()
        $runs = 0
        while ($runs -lt 3 -or -not $done.WaitOne(0)) {
            if ($runs -ge 200) { break }
            $retries = 0
            while ($true) {
                $cmd = $cn.CreateCommand(); $cmd.CommandType = [System.Data.CommandType]::StoredProcedure; $cmd.CommandText = 'dbo.usp_P3_EvaluateTiers'; $cmd.CommandTimeout = 120
                $cmd.Parameters.Add('@ChunkSize', [System.Data.SqlDbType]::Int).Value = $chunk
                $pu = $cmd.Parameters.Add('@Upgrades', [System.Data.SqlDbType]::Int); $pu.Direction = [System.Data.ParameterDirection]::Output
                $pd = $cmd.Parameters.Add('@Downgrades', [System.Data.SqlDbType]::Int); $pd.Direction = [System.Data.ParameterDirection]::Output
                $err = 0; $msg = ''; $t0 = [DateTime]::UtcNow.Ticks
                try { [void]$cmd.ExecuteNonQuery() } catch { $ex = $_.Exception; while ($ex -and -not ($ex -is [System.Data.SqlClient.SqlException])) { $ex = $ex.InnerException }; if ($ex) { $err = $ex.Number; $msg = $ex.Message } else { $err = -1; $msg = $_.Exception.Message } }
                $t1 = [DateTime]::UtcNow.Ticks
                if ($err -eq 1205 -and $retries -lt 3) { $retries++; continue }
                break
            }
            $res.Add([pscustomobject]@{ B = $b; Err = $err; Msg = $msg; Retries = $retries; T0 = $t0; T1 = $t1
                                        Up = $(if ($err -eq 0) { [int]$pu.Value } else { $null }); Down = $(if ($err -eq 0) { [int]$pd.Value } else { $null }) })
            $runs++
        }
    } finally { $cn.Close() }
    ,$res.ToArray()
}

# ---- run ----
$ready = New-Object System.Threading.CountdownEvent($SettleSessions + $BatchSessions)
$gate = New-Object System.Threading.ManualResetEvent($false)
$done = New-Object System.Threading.ManualResetEvent($false)
$pool = [runspacefactory]::CreateRunspacePool(1, $SettleSessions + $BatchSessions); $pool.Open()
$sJobs = @(); $bJobs = @()
foreach ($s in 1..$SettleSessions) {
    $ids = @($plan | Where-Object { $_.S -eq $s } | ForEach-Object { $_.Id })
    $ps = [powershell]::Create(); $ps.RunspacePool = $pool
    [void]$ps.AddScript($settleWorker).AddArgument($s).AddArgument($ids).AddArgument($connStr).AddArgument($ready).AddArgument($gate)
    $sJobs += [pscustomobject]@{ PS = $ps; H = $ps.BeginInvoke() }
}
foreach ($b in 1..$BatchSessions) {
    $ps = [powershell]::Create(); $ps.RunspacePool = $pool
    [void]$ps.AddScript($batchWorker).AddArgument($b).AddArgument($connStr).AddArgument($ChunkSize).AddArgument($ready).AddArgument($gate).AddArgument($done)
    $bJobs += [pscustomobject]@{ PS = $ps; H = $ps.BeginInvoke() }
}
if (-not $ready.Wait(60000)) { $gate.Set(); $done.Set(); throw 'Not all sessions connected within 60 s.' }
$released = [DateTime]::UtcNow; [void]$gate.Set()
$deadline = [DateTime]::UtcNow.AddSeconds(300)
$settled = @(); $batches = @(); $workerErrors = @()
foreach ($j in $sJobs) {
    $left = [int][Math]::Max(1000, ($deadline - [DateTime]::UtcNow).TotalMilliseconds)
    if (-not $j.H.AsyncWaitHandle.WaitOne($left)) { $j.PS.Stop(); $workerErrors += 'watchdog: settlement session stopped'; continue }
    $settled += @($j.PS.EndInvoke($j.H) | ForEach-Object { $_ })
    if ($j.PS.Streams.Error.Count -gt 0) { $workerErrors += ($j.PS.Streams.Error | ForEach-Object { "$_" }) }
}
[void]$done.Set()
foreach ($j in $bJobs) {
    $left = [int][Math]::Max(1000, ($deadline - [DateTime]::UtcNow).TotalMilliseconds)
    if (-not $j.H.AsyncWaitHandle.WaitOne($left)) { $j.PS.Stop(); $workerErrors += 'watchdog: batch session stopped'; continue }
    $batches += @($j.PS.EndInvoke($j.H) | ForEach-Object { $_ })
    if ($j.PS.Streams.Error.Count -gt 0) { $workerErrors += ($j.PS.Streams.Error | ForEach-Object { "$_" }) }
}
$pool.Close()
Log ("Gate released (UTC): " + (Utc $released) + "; all sessions finished (UTC): " + (Utc ([DateTime]::UtcNow)) + " (context only, not a measurement)")

$final1 = Eval $cn0 4000
$final2 = Eval $cn0 4000
$cn0.Close()
Log ("Final quiescent run 1: error $($final1.Err); upgrades $($final1.Up); downgrades $($final1.Down). Run 2: error $($final2.Err); upgrades $($final2.Up); downgrades $($final2.Down)")

$checks = New-Object System.Collections.Generic.List[object]
function Check([string]$id, [bool]$ok, [string]$descr, [string]$detail) { $checks.Add([pscustomobject]@{ Id = $id; Result = $(if ($ok) { 'PASS' } else { 'FAIL' }); Descr = $descr; Detail = $detail }) }

$badS = @($settled | Where-Object { $_.Err -ne 0 -or $_.Outcome -ne 'SETTLED' })
$badB = @($batches | Where-Object { $_.Err -ne 0 })
$retr = (($settled | Measure-Object -Property Retries -Sum).Sum) + (($batches | Measure-Object -Property Retries -Sum).Sum)
Check 'C1' (($settled.Count -eq $plan.Count) -and $badS.Count -eq 0 -and $badB.Count -eq 0 -and $workerErrors.Count -eq 0 -and $final1.Err -eq 0 -and $final2.Err -eq 0) 'Every settlement SETTLED; every batch run succeeded' ("settlements $($settled.Count) of $($plan.Count), failed $($badS.Count); batch runs $($batches.Count), failed $($badB.Count); deadlock retries $retr; worker errors $($workerErrors.Count) $($workerErrors -join ' | ')" + $(if ($badS.Count) { '; first: ' + $badS[0].Msg } elseif ($badB.Count) { '; first: ' + $badB[0].Msg } else { '' }))

$downs = (($batches | Where-Object { $_.Err -eq 0 } | Measure-Object -Property Down -Sum).Sum) + [int]$final1.Down + [int]$final2.Down
$ups = (($batches | Where-Object { $_.Err -eq 0 } | Measure-Object -Property Up -Sum).Sum)
Check 'C2' ($downs -eq 0) 'No incorrect Tier_ID change: no batch run reported a downgrade while spending only grew' ("concurrent runs: upgrades $ups, downgrades $(($batches | Where-Object { $_.Err -eq 0 } | Measure-Object -Property Down -Sum).Sum); final runs downgrades $($final1.Down) + $($final2.Down)")

$or = Query @"
WITH paid AS (SELECT i.Member_ID, i.FinalAmount, DATEFROMPARTS(YEAR(l.loc), MONTH(l.loc), 1) AS lm
              FROM dbo.INVOICE AS i CROSS APPLY (SELECT CONVERT(datetime2(3), (i.PaidAt AT TIME ZONE 'UTC') AT TIME ZONE 'SE Asia Standard Time') AS loc) AS l
              WHERE i.PaymentStatus = 'PAID'),
     w AS (SELECT DATEFROMPARTS(YEAR('$today'), MONTH('$today'), 1) AS last_m),
     sp AS (SELECT m.Member_ID, m.Tier_ID, ISNULL((SELECT SUM(p.FinalAmount) FROM paid AS p CROSS JOIN w WHERE p.Member_ID = m.Member_ID AND p.lm BETWEEN DATEADD(MONTH, -11, w.last_m) AND w.last_m), 0) AS s FROM dbo.MEMBER AS m)
SELECT COUNT(*) AS wrong FROM sp WHERE sp.Tier_ID <> (SELECT TOP (1) t.Tier_ID FROM dbo.MEMBER_TIER AS t WHERE t.SpendingThreshold <= sp.s ORDER BY t.SpendingThreshold DESC)
"@
Check 'C3' ([int]$or.Rows[0].wrong -eq 0) 'After the final run every member''s Tier_ID equals the tier computed independently from INVOICE' ("members with a wrong tier: $($or.Rows[0].wrong)")

$after = Query @"
SELECT m.Member_ID, m.CurrentPoints, ISNULL(s.TotalSpend, 0) AS month_spend,
       (SELECT ISNULL(SUM(PointsEarned), 0) FROM dbo.MEMBER_MONTHLY_SPENDING AS x WHERE x.Member_ID = m.Member_ID) AS pe
FROM dbo.MEMBER AS m LEFT JOIN dbo.MEMBER_MONTHLY_SPENDING AS s ON s.Member_ID = m.Member_ID
     AND s.SpendingMonth = (SELECT SpendingMonth FROM dbo.tvf_P3_SpendingMonth(SYSUTCDATETIME()))
WHERE m.Member_ID IN ($memberList)
"@
$c4bad = New-Object System.Collections.Generic.List[string]
foreach ($r in $after.Rows) {
    $m = [int]$r.Member_ID
    $expAdd = [decimal](($plan | Where-Object { $_.Member -eq $m } | Measure-Object -Property Amount -Sum).Sum)
    $ids = @($plan | Where-Object { $_.Member -eq $m } | ForEach-Object { $_.Id })
    $ret = [int](($settled | Where-Object { $ids -contains $_.Id } | Measure-Object -Property Points -Sum).Sum)
    $ok = ([decimal]$r.month_spend - $bSpend[$m] -eq $expAdd) -and ([int]$r.CurrentPoints -eq [int]$r.pe) -and ([int]$r.CurrentPoints - $bPts[$m] -eq $ret)
    if (-not $ok) { $c4bad.Add("member ${m}: spend +$([decimal]$r.month_spend - $bSpend[$m]) vs $expAdd; points $($bPts[$m])->$($r.CurrentPoints) vs returned $ret; SUM(PointsEarned) $($r.pe)") }
}
Check 'C4' ($c4bad.Count -eq 0) 'No lost update: month spending grew by exactly the harness amounts; CurrentPoints = SUM(PointsEarned); point increase = SUM of returned increments' ("members checked $($after.Rows.Count); mismatches $($c4bad.Count)" + $(if ($c4bad.Count) { '; first: ' + $c4bad[0] } else { '' }))

$sFirst = ($settled | Measure-Object -Property T0 -Minimum).Minimum; $sLast = ($settled | Measure-Object -Property T1 -Maximum).Maximum
$overlapRuns = @($batches | Where-Object { $_.T0 -lt $sLast -and $_.T1 -gt $sFirst }).Count
Check 'C5' ($overlapRuns -ge 2) 'Batch runs overlapped settlement activity' ("batch runs overlapping the settlement period: $overlapRuns of $($batches.Count)")
Check 'C6' ($final2.Err -eq 0 -and [int]$final2.Up -eq 0 -and [int]$final2.Down -eq 0) 'Second final run changes nothing (idempotent)' ("upgrades $($final2.Up); downgrades $($final2.Down)")

Log ''; Log 'Checks:'
foreach ($c in $checks) { Log ("  {0} {1}  {2} | {3}" -f $c.Id, $c.Result, $c.Descr, $c.Detail) }
$nf = @($checks | Where-Object { $_.Result -eq 'FAIL' }).Count
Log ''; Log ("T-CONC-04F SUMMARY: run $RunLabel; checks $($checks.Count); FAIL $nf"); Log ("T-CONC-04F_RESULT: " + $(if ($nf -eq 0) { 'PASS' } else { 'FAIL' }))
if ($OutFile) { $lines | Out-File -Encoding utf8 $OutFile }
if ($nf -eq 0) { exit 0 } else { exit 1 }
