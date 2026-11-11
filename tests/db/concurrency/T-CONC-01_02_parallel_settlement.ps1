<#
  T-CONC-01_02_parallel_settlement.ps1 - TEST_ONLY concurrency tests for WO-P3-P3-01 (Windows PowerShell 5.1;
  built-in System.Data.SqlClient; nothing installed). Correctness only: times are context, NOT measurements (R-27).

  -Mode SameInvoice  (T-CONC-01): R invoices; for every invoice ALL N sessions are released together by a barrier
                     and call usp_P3_SettleInvoice on that same invoice. On every 5th invoice session 1 calls
                     usp_P3_CancelInvoice instead (settle-vs-cancel race). Final-state checks:
      C1 every call returned an allowed result (SETTLED / ALREADY_SETTLED / CANCELLED, or 51204 for a settle that
         lost against a cancellation, or 51223 for a cancellation that lost against a settlement); nothing else
      C2 per invoice exactly one winner: PAID with exactly one SETTLED response (all other settles ALREADY_SETTLED,
         returning the stored PaidAt), or - race invoices only - CANCELLED with no SETTLED response
      C3 effects applied once: one inventory + one entitlement hook call per PAID invoice, none per CANCELLED invoice
      C4 spending and points of the run's members: TotalSpend = sum of FinalAmount of their PAID invoices
         (= the harness's own amounts), PointsEarned = FLOOR(TotalSpend/100000), CurrentPoints = sum PointsEarned
         = sum of the points returned by the SETTLED responses
      C5 the calls really overlapped (several calls in flight on the same invoice)
  -Mode SameMember   (T-CONC-02): N sessions x R rounds; in each round every session settles its OWN invoice, all
                     invoices belonging to two fresh members (no spending row yet), released together by a barrier
                     (round 1 = concurrent first insert of the member-month row). Checks:
      C1 every call SETTLED (deadlock victims 1205 are retried at the outermost level, max 3, and counted)
      C2 every invoice PAID exactly once with the PaidAt returned to its caller; one call per hook
      C3 one spending row per member-month; TotalSpend = sum FinalAmount = harness amounts; PointsEarned = FLOOR;
         UpdatedAt = latest PaidAt; no primary-key violation surfaced
      C4 CurrentPoints = sum PointsEarned = sum of the incremental points returned (no lost update)
      C5 overlap
  Members are fixed per run label (fresh members, so expected values are exact):
      SameInvoice A 21-23, B 24-26, C 27-29;  SameMember A 31-32, B 33-34, C 35-36.
  Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tests/db/concurrency/T-CONC-01_02_parallel_settlement.ps1 -Mode SameInvoice -RunLabel A -OutFile <path>
  Exit code 0 = PASS, 1 = FAIL.
#>
param(
    [ValidateSet('SameInvoice', 'SameMember')][string]$Mode = 'SameInvoice',
    [ValidateSet('A', 'B', 'C')][string]$RunLabel = 'A',
    [int]$Sessions = 10,
    [int]$Rounds = 20,
    [string]$Server = 'localhost',
    [string]$Database = 'FitLife_P3_UC05',
    [string]$OutFile = ''
)
$ErrorActionPreference = 'Stop'
$inv = [Globalization.CultureInfo]::InvariantCulture
if ($Database -ne 'FitLife_P3_UC05') { throw 'T-CONC-01/02 run only against FitLife_P3_UC05.' }
$testId = if ($Mode -eq 'SameInvoice') { 'T-CONC-01' } else { 'T-CONC-02' }
$connStr = "Server=$Server;Database=$Database;Integrated Security=SSPI;Application Name=P3-$testId;Pooling=false"
$lines = New-Object System.Collections.Generic.List[string]
function Log([string]$s) { $lines.Add($s); Write-Output $s }
function Utc([datetime]$d) { $d.ToString('yyyy-MM-dd HH:mm:ss.fff', $inv) }
function Query([string]$sql) {
    $cn = New-Object System.Data.SqlClient.SqlConnection $connStr
    $cn.Open()
    try {
        $cmd = $cn.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 120
        $da = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
        $dt = New-Object System.Data.DataTable
        [void]$da.Fill($dt)
        return ,$dt
    } finally { $cn.Close() }
}

$members = @{ 'SameInvoice' = @{ 'A' = @(21, 22, 23); 'B' = @(24, 25, 26); 'C' = @(27, 28, 29) };
              'SameMember'  = @{ 'A' = @(31, 32);     'B' = @(33, 34);     'C' = @(35, 36) } }[$Mode][$RunLabel]
$memberList = ($members -join ',')

# ---- guards ----
$g = Query @"
SELECT (SELECT CONVERT(nvarchar(200), value) FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable') AS marker,
       OBJECT_ID(N'dbo.usp_P3_SettleInvoice', N'P') AS settle_id, OBJECT_ID(N'dbo.TEST_HookCallLog', N'U') AS log_id,
       (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID IN ($memberList)) AS spend_rows,
       (SELECT ISNULL(SUM(CurrentPoints), 0) FROM dbo.MEMBER WHERE Member_ID IN ($memberList)) AS points,
       (SELECT COUNT(*) FROM dbo.INVOICE WHERE Member_ID IN ($memberList)) AS invoices,
       MONTH(DATEADD(HOUR, 7, SYSUTCDATETIME())) AS m_now, MONTH(DATEADD(MINUTE, 5, DATEADD(HOUR, 7, SYSUTCDATETIME()))) AS m_soon
"@
if (-not ("$($g.Rows[0].marker)" -like 'WO-P3-P3-00*')) { throw 'Refusing to run: FitLife_P3_UC05 without the disposable marker.' }
if ($g.Rows[0].settle_id -is [DBNull] -or $g.Rows[0].log_id -is [DBNull]) { throw 'Settlement routine or hook doubles not deployed.' }
if ([int]$g.Rows[0].spend_rows -ne 0 -or [int]$g.Rows[0].points -ne 0 -or [int]$g.Rows[0].invoices -ne 0) { throw "Members $memberList are not fresh (run label already used in this database)." }
if ([int]$g.Rows[0].m_now -ne [int]$g.Rows[0].m_soon) { throw 'Too close to a local month boundary; run again in a few minutes.' }

Log "$testId - parallel settlement ($Mode) (WO-P3-P3-01). Run $RunLabel."
Log ("Started (UTC): " + (Utc ([DateTime]::UtcNow)) + "; database $Database; sessions $Sessions; rounds $Rounds; members $memberList")
Log ("Harness SHA-256: " + (Get-FileHash -Algorithm SHA256 $PSCommandPath).Hash)

# ---- preparation: PENDING invoices created through dbo.usp_P3_CreateInvoice (sequential) ----
function New-Invoice([System.Data.SqlClient.SqlConnection]$cn, [int]$member, [int]$product, [int]$qty, [decimal]$price) {
    $svc = New-Object System.Data.DataTable
    [void]$svc.Columns.Add('LineNo', [int16]); [void]$svc.Columns.Add('Plan_ID', [int]); [void]$svc.Columns.Add('UnitPrice', [decimal]); [void]$svc.Columns.Add('DiscountAmount', [decimal])
    $prd = New-Object System.Data.DataTable
    [void]$prd.Columns.Add('LineNo', [int16]); [void]$prd.Columns.Add('Product_ID', [int]); [void]$prd.Columns.Add('Quantity', [int]); [void]$prd.Columns.Add('UnitPrice', [decimal]); [void]$prd.Columns.Add('DiscountAmount', [decimal])
    [void]$prd.Rows.Add([int16]1, $product, $qty, $price, [decimal]0)
    $cmd = $cn.CreateCommand(); $cmd.CommandType = [System.Data.CommandType]::StoredProcedure; $cmd.CommandText = 'dbo.usp_P3_CreateInvoice'
    $cmd.Parameters.Add('@Member_ID', [System.Data.SqlDbType]::Int).Value = $member
    $cmd.Parameters.Add('@Employee_ID', [System.Data.SqlDbType]::Int).Value = 1
    $cmd.Parameters.Add('@Branch_ID', [System.Data.SqlDbType]::Int).Value = 1
    $p1 = $cmd.Parameters.Add('@ServiceLines', [System.Data.SqlDbType]::Structured); $p1.TypeName = 'dbo.tt_P3_InvoiceServiceLine'; $p1.Value = $svc
    $p2 = $cmd.Parameters.Add('@ProductLines', [System.Data.SqlDbType]::Structured); $p2.TypeName = 'dbo.tt_P3_InvoiceProductLine'; $p2.Value = $prd
    $o1 = $cmd.Parameters.Add('@Invoice_ID', [System.Data.SqlDbType]::Int); $o1.Direction = [System.Data.ParameterDirection]::Output
    [void]$cmd.ExecuteNonQuery()
    return [int]$o1.Value
}
$plan = New-Object System.Collections.Generic.List[object]    # one entry per invoice: Id, Member, Final, Round, Owner (session or 0 = all), Race
$cnp = New-Object System.Data.SqlClient.SqlConnection $connStr
$cnp.Open()
try {
    if ($Mode -eq 'SameInvoice') {
        for ($r = 1; $r -le $Rounds; $r++) {
            $m = $members[($r - 1) % $members.Count]; $qty = 1 + ($r % 3); $price = [decimal](37000 + 1000 * $r)
            $id = New-Invoice $cnp $m (1 + ($r % 10)) $qty $price
            $plan.Add([pscustomobject]@{ Id = $id; Member = $m; Final = $price * $qty; Round = $r; Owner = 0; Race = (($r % 5) -eq 0) })
        }
    } else {
        for ($r = 1; $r -le $Rounds; $r++) {
            for ($s = 1; $s -le $Sessions; $s++) {
                $m = $members[($s + $r) % 2]; $price = [decimal](23456 + 1111 * $s + 97 * $r)
                $id = New-Invoice $cnp $m (1 + (($s + $r) % 10)) 1 $price
                $plan.Add([pscustomobject]@{ Id = $id; Member = $m; Final = $price; Round = $r; Owner = $s; Race = $false })
            }
        }
    }
} finally { $cnp.Close() }
Log ("Prepared $($plan.Count) PENDING invoices (ids " + ($plan | Measure-Object -Property Id -Minimum).Minimum + "-" + ($plan | Measure-Object -Property Id -Maximum).Maximum + ")")

# per-session call lists: array of rounds, each = @(invoiceId, op)
$callLists = @{}
for ($s = 1; $s -le $Sessions; $s++) {
    $list = New-Object System.Collections.Generic.List[object]
    for ($r = 1; $r -le $Rounds; $r++) {
        if ($Mode -eq 'SameInvoice') {
            $p = $plan | Where-Object { $_.Round -eq $r } | Select-Object -First 1
            $op = if ($p.Race -and $s -eq 1) { 'C' } else { 'S' }
            $list.Add(@($p.Id, $op, $r))
        } else {
            $p = $plan | Where-Object { $_.Round -eq $r -and $_.Owner -eq $s } | Select-Object -First 1
            $list.Add(@($p.Id, 'S', $r))
        }
    }
    $callLists[$s] = $list.ToArray()
}

# ---- worker ----
$worker = {
    param([int]$s, $calls, [string]$connStr, $ready, $gate, $barrier)
    $res = New-Object System.Collections.Generic.List[object]
    $cn = New-Object System.Data.SqlClient.SqlConnection $connStr
    $cn.Open()
    try {
        [void]$ready.Signal()
        [void]$gate.WaitOne()
        foreach ($c in $calls) {
            $invId = [int]$c[0]; $op = [string]$c[1]; $round = [int]$c[2]
            if (-not $barrier.SignalAndWait(60000)) { $res.Add([pscustomobject]@{ S = $s; Round = $round; Id = $invId; Op = $op; Outcome = ''; Err = -2; Msg = 'barrier timeout'; PaidAt = ''; Points = $null; Balance = $null; Retries = 0; T0 = 0; T1 = 0 }); break }
            $retries = 0
            while ($true) {
                $cmd = $cn.CreateCommand(); $cmd.CommandType = [System.Data.CommandType]::StoredProcedure; $cmd.CommandTimeout = 60
                $cmd.Parameters.Add('@Invoice_ID', [System.Data.SqlDbType]::Int).Value = $invId
                if ($op -eq 'S') {
                    $cmd.CommandText = 'dbo.usp_P3_SettleInvoice'
                    $cmd.Parameters.Add('@PaymentMethod', [System.Data.SqlDbType]::VarChar, 10).Value = 'CASH'
                    $o2 = $cmd.Parameters.Add('@PaidAt', [System.Data.SqlDbType]::DateTime2); $o2.Scale = 3; $o2.Direction = [System.Data.ParameterDirection]::Output
                    $o3 = $cmd.Parameters.Add('@PointsEarned', [System.Data.SqlDbType]::Int); $o3.Direction = [System.Data.ParameterDirection]::Output
                    $o4 = $cmd.Parameters.Add('@CurrentPoints', [System.Data.SqlDbType]::Int); $o4.Direction = [System.Data.ParameterDirection]::Output
                } else {
                    $cmd.CommandText = 'dbo.usp_P3_CancelInvoice'
                    $o2 = $null; $o3 = $null; $o4 = $null
                }
                $o1 = $cmd.Parameters.Add('@Outcome', [System.Data.SqlDbType]::VarChar, 20); $o1.Direction = [System.Data.ParameterDirection]::Output
                $errNo = 0; $errMsg = ''
                $t0 = [DateTime]::UtcNow.Ticks
                try { [void]$cmd.ExecuteNonQuery() }
                catch {
                    $ex = $_.Exception
                    while ($ex -and -not ($ex -is [System.Data.SqlClient.SqlException])) { $ex = $ex.InnerException }
                    if ($ex) { $errNo = $ex.Number; $errMsg = $ex.Message } else { $errNo = -1; $errMsg = $_.Exception.Message }
                }
                $t1 = [DateTime]::UtcNow.Ticks
                if ($errNo -eq 1205 -and $retries -lt 3) { $retries++; continue }   # deadlock victim: whole transaction rolled back, retry at the outermost level
                break
            }
            $paid = ''
            if ($o2 -and -not ($o2.Value -is [DBNull]) -and $null -ne $o2.Value) { $paid = ([datetime]$o2.Value).ToString('yyyy-MM-dd HH:mm:ss.fff', [Globalization.CultureInfo]::InvariantCulture) }
            $res.Add([pscustomobject]@{
                S = $s; Round = $round; Id = $invId; Op = $op; Outcome = "$($o1.Value)"; Err = $errNo; Msg = $errMsg; PaidAt = $paid
                Points = $(if ($o3 -and -not ($o3.Value -is [DBNull])) { [int]$o3.Value } else { $null })
                Balance = $(if ($o4 -and -not ($o4.Value -is [DBNull])) { [int]$o4.Value } else { $null })
                Retries = $retries; T0 = $t0; T1 = $t1 })
        }
    } finally { $cn.Close() }
    [pscustomobject]@{ S = $s; Results = $res }
}

# ---- run ----
$ready = New-Object System.Threading.CountdownEvent($Sessions)
$gate = New-Object System.Threading.ManualResetEvent($false)
$barrier = New-Object System.Threading.Barrier($Sessions)
$pool = [runspacefactory]::CreateRunspacePool(1, $Sessions)
$pool.Open()
$jobs = @()
for ($s = 1; $s -le $Sessions; $s++) {
    $ps = [powershell]::Create(); $ps.RunspacePool = $pool
    [void]$ps.AddScript($worker).AddArgument($s).AddArgument($callLists[$s]).AddArgument($connStr).AddArgument($ready).AddArgument($gate).AddArgument($barrier)
    $jobs += [pscustomobject]@{ PS = $ps; H = $ps.BeginInvoke() }
}
if (-not $ready.Wait(60000)) { $gate.Set(); throw 'Not all sessions connected within 60 s.' }
$released = [DateTime]::UtcNow
[void]$gate.Set()
$outs = @(); $workerErrors = @()
$deadline = [DateTime]::UtcNow.AddSeconds(300)   # watchdog
foreach ($j in $jobs) {
    $left = [int][Math]::Max(1000, ($deadline - [DateTime]::UtcNow).TotalMilliseconds)
    if (-not $j.H.AsyncWaitHandle.WaitOne($left)) { $j.PS.Stop(); $workerErrors += 'watchdog: a session did not finish within 300 s and was stopped'; continue }
    $outs += $j.PS.EndInvoke($j.H)
    if ($j.PS.Streams.Error.Count -gt 0) { $workerErrors += ($j.PS.Streams.Error | ForEach-Object { "$_" }) }
    $j.PS.Dispose()
}
$pool.Close()
Log ("Gate released (UTC): " + (Utc $released) + "; all sessions finished (UTC): " + (Utc ([DateTime]::UtcNow)) + " (context only, not a measurement)")

$all = @($outs | ForEach-Object { $_.Results.ToArray() } | ForEach-Object { $_ })
$expectedCalls = $Sessions * $Rounds
$checks = New-Object System.Collections.Generic.List[object]
function Check([string]$id, [bool]$ok, [string]$descr, [string]$detail) { $checks.Add([pscustomobject]@{ Id = $id; Result = $(if ($ok) { 'PASS' } else { 'FAIL' }); Descr = $descr; Detail = $detail }) }

# ---- final database state ----
$ids = ($plan | ForEach-Object { $_.Id }) -join ','
$db = Query @"
SELECT i.Invoice_ID, i.Member_ID, i.PaymentStatus, ISNULL(i.PaymentMethod, '') AS method, ISNULL(CONVERT(varchar(23), i.PaidAt, 121), '') AS paid_at,
       CONVERT(varchar(40), i.FinalAmount) AS final,
       (SELECT COUNT(*) FROM dbo.TEST_HookCallLog AS l WHERE l.Invoice_ID = i.Invoice_ID AND l.HookName = 'INVENTORY_DECREMENT') AS inv_calls,
       (SELECT COUNT(*) FROM dbo.TEST_HookCallLog AS l WHERE l.Invoice_ID = i.Invoice_ID AND l.HookName = 'ENTITLEMENT_ACTIVATION') AS ent_calls
FROM dbo.INVOICE AS i WHERE i.Invoice_ID IN ($ids)
"@
$byId = @{}; foreach ($r in $db.Rows) { $byId[[int]$r.Invoice_ID] = $r }
$sp = Query @"
SELECT m.Member_ID, m.CurrentPoints,
       (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING AS s WHERE s.Member_ID = m.Member_ID) AS rows_,
       (SELECT CONVERT(varchar(40), ISNULL(SUM(TotalSpend), 0)) FROM dbo.MEMBER_MONTHLY_SPENDING AS s WHERE s.Member_ID = m.Member_ID) AS total,
       (SELECT ISNULL(SUM(PointsEarned), 0) FROM dbo.MEMBER_MONTHLY_SPENDING AS s WHERE s.Member_ID = m.Member_ID) AS pe,
       (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING AS s WHERE s.Member_ID = m.Member_ID AND s.PointsEarned <> CONVERT(int, FLOOR(s.TotalSpend / 100000))) AS bad_pe,
       (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING AS s WHERE s.Member_ID = m.Member_ID
            AND s.UpdatedAt <> (SELECT MAX(i.PaidAt) FROM dbo.INVOICE AS i CROSS APPLY dbo.tvf_P3_SpendingMonth(i.PaidAt) AS f
                                WHERE i.Member_ID = s.Member_ID AND i.PaymentStatus = 'PAID' AND f.SpendingMonth = s.SpendingMonth)) AS bad_upd,
       (SELECT CONVERT(varchar(40), ISNULL(SUM(FinalAmount), 0)) FROM dbo.INVOICE AS i WHERE i.Member_ID = m.Member_ID AND i.PaymentStatus = 'PAID') AS paid_total
FROM dbo.MEMBER AS m WHERE m.Member_ID IN ($memberList)
"@

# C1
$bad = New-Object System.Collections.Generic.List[string]
foreach ($x in $all) {
    $final = $byId[[int]$x.Id]
    $st = if ($final) { $final.PaymentStatus } else { '?' }
    $okc = $false
    if ($x.Op -eq 'S') {
        $okc = (($x.Err -eq 0) -and ($x.Outcome -eq 'SETTLED' -or $x.Outcome -eq 'ALREADY_SETTLED')) -or (($x.Err -eq 51204) -and ($st -eq 'CANCELLED'))
        if ($Mode -eq 'SameMember') { $okc = ($x.Err -eq 0) -and ($x.Outcome -eq 'SETTLED') }
    } else {
        $okc = (($x.Err -eq 0) -and ($x.Outcome -eq 'CANCELLED')) -or (($x.Err -eq 51223) -and ($st -eq 'PAID'))
    }
    if (-not $okc) { $bad.Add("session $($x.S) round $($x.Round) invoice $($x.Id) op $($x.Op): err $($x.Err) outcome '$($x.Outcome)' final $st $($x.Msg)") }
}
$retriesTotal = ($all | Measure-Object -Property Retries -Sum).Sum
$pkViol = @($all | Where-Object { $_.Err -eq 2627 -or $_.Err -eq 2601 }).Count
Check 'C1' (($all.Count -eq $expectedCalls) -and ($bad.Count -eq 0) -and ($workerErrors.Count -eq 0)) 'Every call returned an allowed result (no unexpected error, no PK violation surfaced)' ("calls $($all.Count) of $expectedCalls; unexpected $($bad.Count); deadlock retries $retriesTotal; PK violations $pkViol; worker errors $($workerErrors.Count) $($workerErrors -join ' | ')" + $(if ($bad.Count -gt 0) { '; first: ' + $bad[0] } else { '' }))

# C2 (one winner / exactly once)
$c2bad = New-Object System.Collections.Generic.List[string]
$nPaid = 0; $nCancelled = 0
foreach ($p in $plan) {
    $row = $byId[[int]$p.Id]
    $calls = @($all | Where-Object { $_.Id -eq $p.Id })
    $settled = @($calls | Where-Object { $_.Op -eq 'S' -and $_.Err -eq 0 -and $_.Outcome -eq 'SETTLED' })
    $already = @($calls | Where-Object { $_.Op -eq 'S' -and $_.Err -eq 0 -and $_.Outcome -eq 'ALREADY_SETTLED' })
    $settleCalls = @($calls | Where-Object { $_.Op -eq 'S' })
    $cancelled = @($calls | Where-Object { $_.Op -eq 'C' -and $_.Err -eq 0 -and $_.Outcome -eq 'CANCELLED' })
    if ($null -eq $row) { $c2bad.Add("invoice $($p.Id) missing"); continue }
    if ($row.PaymentStatus -eq 'PAID') {
        $nPaid++
        $okp = ($settled.Count -eq 1) -and ($already.Count -eq $settleCalls.Count - 1) -and ($cancelled.Count -eq 0) -and ($row.method -eq 'CASH') -and
               ($settled[0].PaidAt -eq $row.paid_at) -and (@($already | Where-Object { $_.PaidAt -ne $row.paid_at }).Count -eq 0)
        if (-not $okp) { $c2bad.Add("invoice $($p.Id) PAID: SETTLED $($settled.Count), ALREADY_SETTLED $($already.Count) of $($settleCalls.Count) settle calls, CANCELLED $($cancelled.Count), stored PaidAt $($row.paid_at)") }
    } elseif ($row.PaymentStatus -eq 'CANCELLED' -and $p.Race) {
        $nCancelled++
        if (($settled.Count -ne 0) -or ($already.Count -ne 0) -or ($cancelled.Count -ne 1) -or ($row.paid_at -ne '')) { $c2bad.Add("invoice $($p.Id) CANCELLED: SETTLED $($settled.Count), CANCELLED $($cancelled.Count)") }
    } else { $c2bad.Add("invoice $($p.Id) final status $($row.PaymentStatus)") }
}
Check 'C2' ($c2bad.Count -eq 0) 'Exactly one winner per invoice: PAID with one SETTLED response (others ALREADY_SETTLED with the stored PaidAt), or CANCELLED (race invoices only) with no settlement' ("invoices $($plan.Count): PAID $nPaid, CANCELLED $nCancelled; violations $($c2bad.Count)" + $(if ($c2bad.Count -gt 0) { '; first: ' + $c2bad[0] } else { '' }))

# C3 hooks once
$c3bad = @($db.Rows | Where-Object { ($_.PaymentStatus -eq 'PAID' -and ([int]$_.inv_calls -ne 1 -or [int]$_.ent_calls -ne 1)) -or ($_.PaymentStatus -ne 'PAID' -and ([int]$_.inv_calls + [int]$_.ent_calls) -ne 0) }).Count
$hookTotal = ($db.Rows | ForEach-Object { [int]$_.inv_calls + [int]$_.ent_calls } | Measure-Object -Sum).Sum
Check 'C3' ($c3bad -eq 0) 'Effects applied once: one inventory and one entitlement hook call per PAID invoice; none per CANCELLED invoice' ("invoices with wrong hook calls $c3bad; hook calls $hookTotal")

# C4 spending and points
$c4bad = New-Object System.Collections.Generic.List[string]
foreach ($r in $sp.Rows) {
    $m = [int]$r.Member_ID
    $exp = [decimal]0
    foreach ($p in ($plan | Where-Object { $_.Member -eq $m })) { if ($byId[[int]$p.Id].PaymentStatus -eq 'PAID') { $exp += $p.Final } }
    $memberIds = @($plan | Where-Object { $_.Member -eq $m } | ForEach-Object { $_.Id })
    $sumRet = (@($all | Where-Object { $_.Outcome -eq 'SETTLED' -and $_.Err -eq 0 -and ($memberIds -contains $_.Id) }) | Measure-Object -Property Points -Sum).Sum
    if ($null -eq $sumRet) { $sumRet = 0 }
    $total = [decimal]::Parse("$($r.total)", $inv); $paidTotal = [decimal]::Parse("$($r.paid_total)", $inv)
    $okm = ($total -eq $exp) -and ($paidTotal -eq $exp) -and ([int]$r.bad_pe -eq 0) -and ([int]$r.bad_upd -eq 0) -and ([int]$r.CurrentPoints -eq [int]$r.pe) -and ([int]$r.pe -eq $sumRet) -and ([int]$r.rows_ -ge 1)
    if ($Mode -eq 'SameMember') { $okm = $okm -and ([int]$r.rows_ -eq 1) }
    $c4bad.Add(("member {0}: rows {1}, TotalSpend {2}, PAID total {3}, harness expected {4}, PointsEarned {5}, CurrentPoints {6}, sum of returned increments {7}, bad floor rows {8}, bad UpdatedAt rows {9} -> {10}" -f $m, $r.rows_, $total, $paidTotal, $exp, $r.pe, $r.CurrentPoints, $sumRet, $r.bad_pe, $r.bad_upd, $(if ($okm) { 'ok' } else { 'MISMATCH' })))
}
$c4fail = @($c4bad | Where-Object { $_ -like '*MISMATCH' }).Count
Check 'C4' (($c4fail -eq 0) -and ($sp.Rows.Count -eq $members.Count)) 'Spending and points exactly once: TotalSpend = sum of PAID FinalAmount = harness amounts; PointsEarned = FLOOR; UpdatedAt = latest PaidAt; CurrentPoints = sum PointsEarned = sum of returned increments' ($c4bad -join ' | ')

# C5 overlap
$overRounds = 0; $maxInFlight = 0
foreach ($rr in (1..$Rounds)) {
    $rc = @($all | Where-Object { $_.Round -eq $rr })
    if ($rc.Count -lt 2) { continue }
    $inflight = 0
    foreach ($a in $rc) { $n = @($rc | Where-Object { $_.T0 -le $a.T0 -and $_.T1 -ge $a.T0 }).Count; if ($n -gt $inflight) { $inflight = $n } }
    if ($inflight -ge 2) { $overRounds++ }
    if ($inflight -gt $maxInFlight) { $maxInFlight = $inflight }
}
Check 'C5' ($overRounds -ge [Math]::Ceiling($Rounds / 2)) 'Calls of the same round overlapped in time (several calls in flight together) in at least half of the rounds' ("rounds with >= 2 calls in flight: $overRounds of $Rounds; max calls in flight together: $maxInFlight")

Log ''
Log 'Per member (final state):'
foreach ($l in $c4bad) { Log "  $l" }
Log ''
Log 'Checks:'
foreach ($c in $checks) { Log ("  {0} {1}  {2} | {3}" -f $c.Id, $c.Result, $c.Descr, $c.Detail) }
$nf = @($checks | Where-Object { $_.Result -eq 'FAIL' }).Count
Log ''
Log ("$testId SUMMARY: run $RunLabel; mode $Mode; checks $($checks.Count); FAIL $nf")
Log ("${testId}_RESULT: " + $(if ($nf -eq 0) { 'PASS' } else { 'FAIL' }))
if ($OutFile) { $lines | Out-File -Encoding utf8 $OutFile }
if ($nf -eq 0) { exit 0 } else { exit 1 }
