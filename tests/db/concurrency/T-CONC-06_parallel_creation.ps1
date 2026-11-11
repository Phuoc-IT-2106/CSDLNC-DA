<#
  T-CONC-06_parallel_creation.ps1 - TEST_ONLY concurrency test for WO-P3-P3-00 (Windows PowerShell 5.1;
  built-in System.Data.SqlClient; nothing installed).

  N sessions (default 10) open their connections, wait at a shared gate, are released together and each
  calls dbo.usp_P3_CreateInvoice K times (default 20) with table-valued parameters. Every request has a
  distinct, traceable line pattern (prices encode session and iteration; 1-3 product lines; every 4th
  request also has a service line, so mixed invoices are included). The controller then checks:
    C1 every call returned success, Outcome CREATED and an invoice id
    C2 the returned ids are distinct, and exactly N x K new invoices exist (none extra, none missing)
    C3 every new invoice has exactly the header values and lines its own request sent (no lost or
       misattached line), totals = expected, status PENDING, PaidAt NULL
    C4 V-TOT = 0 and no orphan line in the whole database
    C5 the sessions really overlapped (latest first-call start < earliest last-call end)
  Correctness only: elapsed times are recorded for context and are NOT performance measurements (R-27).

  Usage (from the repository root):
    powershell -NoProfile -ExecutionPolicy Bypass -File tests/db/concurrency/T-CONC-06_parallel_creation.ps1 -RunLabel A -OutFile <path>
  Exit code 0 = PASS, 1 = FAIL.
#>
param(
    [int]$Sessions = 10,
    [int]$PerSession = 20,
    [string]$RunLabel = 'A',
    [string]$Server = 'localhost',
    [string]$Database = 'FitLife_P3_UC05',
    [string]$OutFile = ''
)
$ErrorActionPreference = 'Stop'
$inv = [Globalization.CultureInfo]::InvariantCulture
if ($Database -ne 'FitLife_P3_UC05') { throw 'T-CONC-06 runs only against FitLife_P3_UC05.' }
$connStr = "Server=$Server;Database=$Database;Integrated Security=SSPI;Application Name=P3-T-CONC-06;Pooling=false"
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

# ---- guards: isolated database with the WO-P3-P3-00 marker, routine deployed ----
$g = Query "SELECT DB_NAME() AS db, (SELECT CONVERT(nvarchar(200), value) FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable') AS marker, OBJECT_ID(N'dbo.usp_P3_CreateInvoice', N'P') AS proc_id, (SELECT COUNT(*) FROM dbo.MEMBER) AS members"
if (-not ("$($g.Rows[0].marker)" -like 'WO-P3-P3-00*')) { throw 'Refusing to run: FitLife_P3_UC05 without the WO-P3-P3-00 disposable marker.' }
if ($g.Rows[0].proc_id -is [DBNull]) { throw 'dbo.usp_P3_CreateInvoice is not deployed.' }
if ([int]$g.Rows[0].members -lt (10 + $Sessions)) { throw 'Not enough TEST_ONLY member keys for the sessions.' }

$base = Query "SELECT ISNULL(MAX(Invoice_ID), 0) AS max_id, COUNT(*) AS n FROM dbo.INVOICE"
$baseMax = [int]$base.Rows[0].max_id
$baseCount = [int]$base.Rows[0].n

Log "T-CONC-06 - parallel invoice creation (WO-P3-P3-00). Run $RunLabel."
Log ("Started (UTC): " + (Utc ([DateTime]::UtcNow)) + "; database $Database; sessions $Sessions x $PerSession calls; routine dbo.usp_P3_CreateInvoice")
Log ("Harness SHA-256: " + (Get-FileHash -Algorithm SHA256 $PSCommandPath).Hash)
Log "Before: invoices $baseCount, max Invoice_ID $baseMax"

# ---- worker: one session ----
$worker = {
    param([int]$s, [int]$Calls, [string]$connStr, $ready, $gate)   # note: PowerShell names are case-insensitive ($k is the loop counter)
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $res = New-Object System.Collections.Generic.List[object]
    $first = $null; $last = $null
    $cn = New-Object System.Data.SqlClient.SqlConnection $connStr
    $cn.Open()
    try {
        [void]$ready.Signal()
        [void]$gate.WaitOne()
        for ($k = 1; $k -le $Calls; $k++) {
            $svc = New-Object System.Data.DataTable
            [void]$svc.Columns.Add('LineNo', [int16]); [void]$svc.Columns.Add('Plan_ID', [int]); [void]$svc.Columns.Add('UnitPrice', [decimal]); [void]$svc.Columns.Add('DiscountAmount', [decimal])
            $prd = New-Object System.Data.DataTable
            [void]$prd.Columns.Add('LineNo', [int16]); [void]$prd.Columns.Add('Product_ID', [int]); [void]$prd.Columns.Add('Quantity', [int]); [void]$prd.Columns.Add('UnitPrice', [decimal]); [void]$prd.Columns.Add('DiscountAmount', [decimal])
            $gross = [decimal]0; $disc = [decimal]0
            $expP = New-Object System.Collections.Generic.List[string]
            $expS = New-Object System.Collections.Generic.List[string]
            $nP = 1 + ($k % 3)
            for ($j = 1; $j -le $nP; $j++) {
                $price = [decimal](1000 * $s + 10 * $k + $j)            # encodes session, iteration, line
                $qty = 1 + ($j % 3)
                $d = if ((($k % 2) -eq 0) -and ($j -eq 1)) { [decimal]100 } else { [decimal]0 }
                $pid_ = 1 + (($s + $k + $j) % 10)
                [void]$prd.Rows.Add([int16]$j, $pid_, $qty, $price, $d)
                $gross += $price * $qty; $disc += $d
                $expP.Add(('{0}:{1}:{2}:{3}:{4}' -f $j, $pid_, $qty, $price.ToString('0.00', $inv), $d.ToString('0.00', $inv)))
            }
            if (($k % 4) -eq 0) {
                $sp = [decimal](500000 + 1000 * $s + $k)
                $plan = 1 + ($s % 5)
                [void]$svc.Rows.Add([int16]1, $plan, $sp, [decimal]0)
                $gross += $sp
                $expS.Add(('1:{0}:{1}:{2}' -f $plan, $sp.ToString('0.00', $inv), ([decimal]0).ToString('0.00', $inv)))
            }
            $member = 10 + $s; $emp = 1 + ($s % 6); $branch = 1 + ($s % 3)
            $cmd = $cn.CreateCommand()
            $cmd.CommandType = [System.Data.CommandType]::StoredProcedure
            $cmd.CommandText = 'dbo.usp_P3_CreateInvoice'
            $cmd.CommandTimeout = 60
            $cmd.Parameters.Add('@Member_ID', [System.Data.SqlDbType]::Int).Value = $member
            $cmd.Parameters.Add('@Employee_ID', [System.Data.SqlDbType]::Int).Value = $emp
            $cmd.Parameters.Add('@Branch_ID', [System.Data.SqlDbType]::Int).Value = $branch
            $p1 = $cmd.Parameters.Add('@ServiceLines', [System.Data.SqlDbType]::Structured); $p1.TypeName = 'dbo.tt_P3_InvoiceServiceLine'; $p1.Value = $svc
            $p2 = $cmd.Parameters.Add('@ProductLines', [System.Data.SqlDbType]::Structured); $p2.TypeName = 'dbo.tt_P3_InvoiceProductLine'; $p2.Value = $prd
            $o1 = $cmd.Parameters.Add('@Invoice_ID', [System.Data.SqlDbType]::Int); $o1.Direction = [System.Data.ParameterDirection]::Output
            $o2 = $cmd.Parameters.Add('@Outcome', [System.Data.SqlDbType]::VarChar, 20); $o2.Direction = [System.Data.ParameterDirection]::Output
            $rv = $cmd.Parameters.Add('@RETURN_VALUE', [System.Data.SqlDbType]::Int); $rv.Direction = [System.Data.ParameterDirection]::ReturnValue
            $errNo = 0; $errMsg = ''
            $t = [DateTime]::UtcNow
            if ($null -eq $first) { $first = $t }
            try { [void]$cmd.ExecuteNonQuery() }
            catch {
                $ex = $_.Exception
                while ($ex -and -not ($ex -is [System.Data.SqlClient.SqlException])) { $ex = $ex.InnerException }
                if ($ex) { $errNo = $ex.Number; $errMsg = $ex.Message } else { $errNo = -1; $errMsg = $_.Exception.Message }
            }
            $last = [DateTime]::UtcNow
            $id = if ($o1.Value -is [DBNull] -or $null -eq $o1.Value) { $null } else { [int]$o1.Value }
            $res.Add([pscustomobject]@{
                S = $s; K = $k; Id = $id; Outcome = "$($o2.Value)"; Ret = "$($rv.Value)"; Err = $errNo; Msg = $errMsg
                Member = $member; Emp = $emp; Branch = $branch
                Gross = $gross.ToString('0.00', $inv); Disc = $disc.ToString('0.00', $inv); Final = ($gross - $disc).ToString('0.00', $inv)
                ExpS = ($expS -join ','); ExpP = ($expP -join ',')
            })
        }
    } finally { $cn.Close() }
    [pscustomobject]@{ S = $s; First = $first; Last = $last; Results = $res }
}

# ---- run: all sessions connect, wait at the gate, start together ----
$ready = New-Object System.Threading.CountdownEvent($Sessions)
$gate = New-Object System.Threading.ManualResetEvent($false)
$pool = [runspacefactory]::CreateRunspacePool(1, $Sessions)
$pool.Open()
$jobs = @()
for ($s = 1; $s -le $Sessions; $s++) {
    $ps = [powershell]::Create()
    $ps.RunspacePool = $pool
    [void]$ps.AddScript($worker).AddArgument($s).AddArgument($PerSession).AddArgument($connStr).AddArgument($ready).AddArgument($gate)
    $jobs += [pscustomobject]@{ PS = $ps; H = $ps.BeginInvoke() }
}
if (-not $ready.Wait(60000)) { $gate.Set(); throw 'Not all sessions connected within 60 s.' }
$released = [DateTime]::UtcNow
[void]$gate.Set()
$outs = @()
$workerErrors = @()
$deadline = [DateTime]::UtcNow.AddSeconds(300)   # watchdog: no session may run unbounded
foreach ($j in $jobs) {
    $left = [int][Math]::Max(1000, ($deadline - [DateTime]::UtcNow).TotalMilliseconds)
    if (-not $j.H.AsyncWaitHandle.WaitOne($left)) {
        $j.PS.Stop()
        $workerErrors += 'watchdog: a session did not finish within 300 s and was stopped'
        continue
    }
    $outs += $j.PS.EndInvoke($j.H)
    if ($j.PS.Streams.Error.Count -gt 0) { $workerErrors += ($j.PS.Streams.Error | ForEach-Object { "$_" }) }
    $j.PS.Dispose()
}
$pool.Close()
$done = [DateTime]::UtcNow
Log ("Gate released (UTC): " + (Utc $released) + "; all sessions finished (UTC): " + (Utc $done) + " (context only, not a measurement)")

$all = @($outs | ForEach-Object { $_.Results } | ForEach-Object { $_ })
$expected = $Sessions * $PerSession
$checks = New-Object System.Collections.Generic.List[object]
function Check([string]$id, [bool]$ok, [string]$descr, [string]$detail) { $checks.Add([pscustomobject]@{ Id = $id; Result = $(if ($ok) { 'PASS' } else { 'FAIL' }); Descr = $descr; Detail = $detail }) }

# C1
$failed = @($all | Where-Object { $_.Err -ne 0 -or $_.Outcome -ne 'CREATED' -or $null -eq $_.Id -or $_.Ret -ne '0' })
$errSummary = ($failed | Group-Object Err | ForEach-Object { "error $($_.Name) x$($_.Count)" }) -join ', '
Check 'C1' (($all.Count -eq $expected) -and ($failed.Count -eq 0) -and ($workerErrors.Count -eq 0)) 'Every call succeeded: return 0, Outcome CREATED, an invoice id' ("calls recorded $($all.Count) of $expected; failed $($failed.Count) $errSummary; worker errors $($workerErrors.Count) $($workerErrors -join ' | ')")

# C2
$ids = @($all | Where-Object { $null -ne $_.Id } | ForEach-Object { $_.Id })
$distinct = @($ids | Sort-Object -Unique)
$after = Query "SELECT COUNT(*) AS n_new, ISNULL(MIN(Invoice_ID), 0) AS min_new, ISNULL(MAX(Invoice_ID), 0) AS max_new FROM dbo.INVOICE WHERE Invoice_ID > $baseMax"
$nNew = [int]$after.Rows[0].n_new
$notReturned = @()
if ($nNew -gt 0) {
    $newIds = Query "SELECT Invoice_ID FROM dbo.INVOICE WHERE Invoice_ID > $baseMax"
    $set = New-Object 'System.Collections.Generic.HashSet[int]'
    foreach ($i in $distinct) { [void]$set.Add([int]$i) }
    $notReturned = @($newIds.Rows | Where-Object { -not $set.Contains([int]$_.Invoice_ID) } | ForEach-Object { $_.Invoice_ID })
}
Check 'C2' (($distinct.Count -eq $ids.Count) -and ($ids.Count -eq $expected) -and ($nNew -eq $expected) -and ($notReturned.Count -eq 0)) 'Distinct invoice ids; exactly N x K new invoices; no new invoice that no session received' ("ids returned $($ids.Count), distinct $($distinct.Count); new invoices in the table $nNew (ids $($after.Rows[0].min_new)-$($after.Rows[0].max_new)); new invoices not returned to any session $($notReturned.Count)")

# C3
$act = Query @"
SELECT i.Invoice_ID, i.Member_ID, i.Employee_ID, i.Branch_ID, i.PaymentStatus, CASE WHEN i.PaidAt IS NULL THEN 0 ELSE 1 END AS paid_at_set,
       ISNULL(i.PaymentMethod, '') AS method,
       CONVERT(varchar(40), i.GrossAmount) AS gross, CONVERT(varchar(40), i.DiscountAmount) AS disc, CONVERT(varchar(40), i.FinalAmount) AS final,
       ISNULL((SELECT STRING_AGG(CONVERT(varchar(max), CONCAT([LineNo], ':', Plan_ID, ':', UnitPrice, ':', DiscountAmount)), ',') WITHIN GROUP (ORDER BY [LineNo])
               FROM dbo.INVOICE_SERVICE_ITEM AS s WHERE s.Invoice_ID = i.Invoice_ID), '') AS svc,
       ISNULL((SELECT STRING_AGG(CONVERT(varchar(max), CONCAT([LineNo], ':', Product_ID, ':', Quantity, ':', UnitPrice, ':', DiscountAmount)), ',') WITHIN GROUP (ORDER BY [LineNo])
               FROM dbo.INVOICE_PRODUCT_ITEM AS p WHERE p.Invoice_ID = i.Invoice_ID), '') AS prd,
       (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM AS s WHERE s.Invoice_ID = i.Invoice_ID AND (s.ValidFrom IS NOT NULL OR s.ValidUntil IS NOT NULL OR s.PTSessionsRemaining IS NOT NULL)) AS ent
FROM dbo.INVOICE AS i WHERE i.Invoice_ID > $baseMax
"@
$byId = @{}
foreach ($r in $act.Rows) { $byId[[int]$r.Invoice_ID] = $r }
$mismatch = New-Object System.Collections.Generic.List[string]
$mixed = 0; $linesTotal = 0
foreach ($x in ($all | Where-Object { $null -ne $_.Id })) {
    $r = $byId[[int]$x.Id]
    if ($null -eq $r) { $mismatch.Add("session $($x.S) call $($x.K): invoice $($x.Id) not found"); continue }
    $okRow = ([int]$r.Member_ID -eq $x.Member) -and ([int]$r.Employee_ID -eq $x.Emp) -and ([int]$r.Branch_ID -eq $x.Branch) -and
             ($r.PaymentStatus -eq 'PENDING') -and ([int]$r.paid_at_set -eq 0) -and ($r.method -eq '') -and
             ($r.gross -eq $x.Gross) -and ($r.disc -eq $x.Disc) -and ($r.final -eq $x.Final) -and
             ($r.svc -eq $x.ExpS) -and ($r.prd -eq $x.ExpP) -and ([int]$r.ent -eq 0)
    if (-not $okRow) { $mismatch.Add("session $($x.S) call $($x.K) invoice $($x.Id): stored [$($r.Member_ID),$($r.gross),$($r.disc),S=$($r.svc),P=$($r.prd)] expected [$($x.Member),$($x.Gross),$($x.Disc),S=$($x.ExpS),P=$($x.ExpP)]") }
    if ($x.ExpS -ne '') { $mixed++ }
    $linesTotal += ($x.ExpP.Split(',').Count) + $(if ($x.ExpS -ne '') { 1 } else { 0 })
}
Check 'C3' ($mismatch.Count -eq 0 -and $byId.Count -eq $expected) 'Each new invoice holds exactly its own request: header keys, totals, PENDING, PaidAt NULL, lines (no lost or misattached line), entitlement/PT columns NULL' ("invoices compared $($byId.Count); mismatches $($mismatch.Count); mixed invoices $mixed; lines expected and found $linesTotal" + $(if ($mismatch.Count -gt 0) { '; first: ' + $mismatch[0] } else { '' }))

# C4
$vt = Query @"
WITH s AS (SELECT Invoice_ID, SUM(UnitPrice) AS g, SUM(DiscountAmount) AS d, COUNT(*) AS n FROM dbo.INVOICE_SERVICE_ITEM GROUP BY Invoice_ID),
     p AS (SELECT Invoice_ID, SUM(UnitPrice * Quantity) AS g, SUM(DiscountAmount) AS d, COUNT(*) AS n FROM dbo.INVOICE_PRODUCT_ITEM GROUP BY Invoice_ID)
SELECT (SELECT COUNT(*) FROM dbo.INVOICE AS i LEFT JOIN s ON s.Invoice_ID = i.Invoice_ID LEFT JOIN p ON p.Invoice_ID = i.Invoice_ID
        WHERE i.GrossAmount <> ISNULL(s.g, 0) + ISNULL(p.g, 0) OR i.DiscountAmount <> ISNULL(s.d, 0) + ISNULL(p.d, 0) OR ISNULL(s.n, 0) + ISNULL(p.n, 0) = 0) AS vtot,
       (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM AS x WHERE NOT EXISTS (SELECT 1 FROM dbo.INVOICE AS i WHERE i.Invoice_ID = x.Invoice_ID))
     + (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM AS x WHERE NOT EXISTS (SELECT 1 FROM dbo.INVOICE AS i WHERE i.Invoice_ID = x.Invoice_ID)) AS orphans,
       (SELECT COUNT(*) FROM dbo.INVOICE) AS invoices
"@
Check 'C4' (([int]$vt.Rows[0].vtot -eq 0) -and ([int]$vt.Rows[0].orphans -eq 0) -and ([int]$vt.Rows[0].invoices -eq $baseCount + $expected)) 'V-TOT = 0 and no orphan line in the whole database' ("V-TOT rows $($vt.Rows[0].vtot); orphan lines $($vt.Rows[0].orphans); invoices $baseCount -> $($vt.Rows[0].invoices)")

# C5
$firsts = @($outs | ForEach-Object { $_.First }); $lasts = @($outs | ForEach-Object { $_.Last })
$maxFirst = ($firsts | Measure-Object -Maximum).Maximum; $minLast = ($lasts | Measure-Object -Minimum).Minimum
Check 'C5' ($maxFirst -lt $minLast) 'Sessions overlapped (the last session started before the first session finished)' ("latest first call (UTC) $(Utc $maxFirst); earliest last call end (UTC) $(Utc $minLast)")

Log ''
Log 'Per session (calls, failures, first id, last id):'
foreach ($o in ($outs | Sort-Object S)) {
    $r = $o.Results.ToArray()   # @() over a List[object] fails in Windows PowerShell 5.1 ("Argument types do not match")
    Log ("  session {0,2}: calls {1}, failures {2}, ids {3}..{4}" -f $o.S, $r.Count, @($r | Where-Object { $_.Err -ne 0 }).Count, ($r | Select-Object -First 1).Id, ($r | Select-Object -Last 1).Id)
}
Log ''
Log 'Checks:'
foreach ($c in $checks) { Log ("  {0} {1}  {2} | {3}" -f $c.Id, $c.Result, $c.Descr, $c.Detail) }
$nf = @($checks | Where-Object { $_.Result -eq 'FAIL' }).Count
Log ''
Log ("T-CONC-06 SUMMARY: run $RunLabel; checks $($checks.Count); FAIL $nf")
Log ("T-CONC-06_RESULT: " + $(if ($nf -eq 0) { 'PASS' } else { 'FAIL' }))
if ($OutFile) { $lines | Out-File -Encoding utf8 $OutFile }
if ($nf -eq 0) { exit 0 } else { exit 1 }
