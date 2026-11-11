<#
  T-CONC-04R_reports_vs_settlement.ps1 - TEST_ONLY concurrency test for WO-P3-P3-03 Part C (report part of T-CONC-04:
  revenue reports running while settlements commit or roll back). Correctness only: times are context, NOT
  measurements (R-27). PowerShell 5.1, built-in System.Data.SqlClient; nothing installed; no setting changed.

  The reporting contract (07 section 12, D-010, D-019 (a)): every report routine is ONE SELECT under the default
  READ COMMITTED (locking) isolation; RCSI / snapshot are a team choice and stay OFF. Dirty reads are never enabled.
    R1  deterministic, per report routine (RPT-01, RPT-02 total, RPT-02 by branch, RPT-03/04 branch by period,
        RPT-04 system by period): a settlement is executed inside an open writer transaction (the routine joins it);
        the report is started and must WAIT for the writer (blocking session = writer, lock wait observed). Then
        (a) writer ROLLBACK -> the report returns exactly the value before the settlement;
        (b) writer COMMIT   -> the report returns the value before + FinalAmount, count + 1.
    R2  load: 6 committing settlement sessions (whole-VND amounts) and 2 aborting sessions (settle inside a caller
        transaction, hold it 20 ms, ROLLBACK; amounts with 0.01 VND) run while 3 report sessions loop over the
        report routines. Checks:
          C1 every committing settlement SETTLED; every aborted attempt was settled inside its transaction and
             rolled back; every report call succeeded (1205 retried at the outermost level, max 3, counted)
          C2 no dirty read: (observed - before) has no cents for every observed total and every branch row
          C3 bounds: before <= observed <= final (revenue and count) for every observation
          C4 monotonic: per report session, successive company totals never decrease
          C5 single-statement consistency: by-branch SystemRevenue = sum of its rows; by-period period totals =
             sum of their rows
          C6 final quiescent state: company total - before = sum of the committed harness amounts exactly; aborted
             invoices PENDING, no PaidAt, no hook call, no spending row, no points
          C7 the report calls overlapped the settlement activity and the aborted transactions
    R3  caller-chosen isolation (no database setting): a report transaction at SERIALIZABLE reads the company total,
        a concurrent settlement waits for it, a second report statement in the same transaction returns the same
        total (multi-statement consistency); after COMMIT the settlement completes and a new report includes it.
  Members 11-20 (no invoice, spending or points expected when the script starts). Branches 1-3.
  Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tests/db/concurrency/T-CONC-04R_reports_vs_settlement.ps1 -OutFile <path>
  Exit code 0 = PASS, 1 = FAIL.
#>
param(
    [string]$Server = 'localhost',
    [string]$Database = 'FitLife_P3_UC05',
    [int]$SettleSessions = 6,
    [int]$PerSession = 20,
    [int]$AbortSessions = 2,
    [int]$ReportSessions = 3,
    [string]$OutFile = ''
)
$ErrorActionPreference = 'Stop'
$inv = [Globalization.CultureInfo]::InvariantCulture
if ($Database -ne 'FitLife_P3_UC05') { throw 'T-CONC-04R runs only against FitLife_P3_UC05.' }
$connStr = "Server=$Server;Database=$Database;Integrated Security=SSPI;Application Name=P3-T-CONC-04R;Pooling=false"
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
function SqlErr($e) { $x = $e; while ($x -and -not ($x -is [System.Data.SqlClient.SqlException])) { $x = $x.InnerException }; if ($x) { return [pscustomobject]@{ N = $x.Number; M = $x.Message } }; return [pscustomobject]@{ N = -1; M = "$e" } }

# ---- guards ----
$g = Query @"
SELECT (SELECT CONVERT(nvarchar(200), value) FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable') AS marker,
       (SELECT is_read_committed_snapshot_on FROM sys.databases WHERE name = DB_NAME()) AS rcsi,
       (SELECT snapshot_isolation_state_desc FROM sys.databases WHERE name = DB_NAME()) AS si,
       OBJECT_ID(N'dbo.usp_P3_RptSystemRevenueByPeriod', N'P') AS rpt, OBJECT_ID(N'dbo.TEST_HookCallLog', N'U') AS hk,
       (SELECT COUNT(*) FROM dbo.INVOICE WHERE Member_ID BETWEEN 11 AND 20) + (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID BETWEEN 11 AND 20)
         + (SELECT ISNULL(SUM(CurrentPoints), 0) FROM dbo.MEMBER WHERE Member_ID BETWEEN 11 AND 20) AS used,
       MONTH(DATEADD(HOUR, 7, SYSUTCDATETIME())) AS m_now, MONTH(DATEADD(MINUTE, 10, DATEADD(HOUR, 7, SYSUTCDATETIME()))) AS m_soon,
       CONVERT(varchar(10), DATEFROMPARTS(YEAR(DATEADD(HOUR, 7, SYSUTCDATETIME())), MONTH(DATEADD(HOUR, 7, SYSUTCDATETIME())), 1), 23) AS m0,
       CONVERT(varchar(10), DATEADD(MONTH, 1, DATEFROMPARTS(YEAR(DATEADD(HOUR, 7, SYSUTCDATETIME())), MONTH(DATEADD(HOUR, 7, SYSUTCDATETIME())), 1)), 23) AS m1
"@
$r0 = $g.Rows[0]
if (-not ("$($r0.marker)" -like 'WO-P3-P3-00*')) { throw 'Refusing to run: FitLife_P3_UC05 without the disposable marker.' }
if ($r0.rpt -is [DBNull] -or $r0.hk -is [DBNull]) { throw 'Report routines or hook doubles not deployed.' }
if ([int]$r0.used -ne 0) { throw 'Members 11-20 must have no invoice, spending row or point.' }
if ([int]$r0.m_now -ne [int]$r0.m_soon) { throw 'Too close to a local month boundary; run again later.' }
$m0 = [datetime]::ParseExact("$($r0.m0)", 'yyyy-MM-dd', $inv); $m1 = [datetime]::ParseExact("$($r0.m1)", 'yyyy-MM-dd', $inv)

Log 'T-CONC-04R - revenue reports concurrent with settlement (WO-P3-P3-03 Part C).'
Log ("Started (UTC): " + (Utc ([DateTime]::UtcNow)) + "; database $Database; report period (local) [$($r0.m0), $($r0.m1)); members 11-20")
Log ("Harness SHA-256: " + (Get-FileHash -Algorithm SHA256 $PSCommandPath).Hash)
Log ("Isolation settings (read, not changed): READ_COMMITTED_SNAPSHOT=$($r0.rcsi); ALLOW_SNAPSHOT_ISOLATION=$($r0.si). Session default READ COMMITTED (locking); no NOLOCK / READ UNCOMMITTED anywhere")

# ---- report helpers ----
$kinds = @('B', 'S', 'BB', 'BP', 'SP')
$kindName = @{ 'B' = 'RPT-01 usp_P3_RptBranchRevenue (branch 1)'; 'S' = 'RPT-02 usp_P3_RptSystemRevenue'; 'BB' = 'RPT-02 usp_P3_RptSystemRevenueByBranch';
               'BP' = 'RPT-03/04 usp_P3_RptBranchRevenueByPeriod (branch 2, DAY)'; 'SP' = 'RPT-04 usp_P3_RptSystemRevenueByPeriod (DAY)' }
$rptDef = @'
param($cn, [string]$kind, [datetime]$m0, [datetime]$m1, $tx)
$cmd = $cn.CreateCommand(); $cmd.CommandType = [System.Data.CommandType]::StoredProcedure; $cmd.CommandTimeout = 60
if ($tx) { $cmd.Transaction = $tx }
switch ($kind) {
  'B'  { $cmd.CommandText = 'dbo.usp_P3_RptBranchRevenue'; $cmd.Parameters.Add('@Branch_ID', [System.Data.SqlDbType]::Int).Value = 1 }
  'S'  { $cmd.CommandText = 'dbo.usp_P3_RptSystemRevenue' }
  'BB' { $cmd.CommandText = 'dbo.usp_P3_RptSystemRevenueByBranch' }
  'BP' { $cmd.CommandText = 'dbo.usp_P3_RptBranchRevenueByPeriod'; $cmd.Parameters.Add('@Branch_ID', [System.Data.SqlDbType]::Int).Value = 2; $cmd.Parameters.Add('@Grain', [System.Data.SqlDbType]::VarChar, 7).Value = 'DAY' }
  'SP' { $cmd.CommandText = 'dbo.usp_P3_RptSystemRevenueByPeriod'; $cmd.Parameters.Add('@Grain', [System.Data.SqlDbType]::VarChar, 7).Value = 'DAY' }
}
$cmd.Parameters.Add('@FromDate', [System.Data.SqlDbType]::Date).Value = $m0
$cmd.Parameters.Add('@ToDate', [System.Data.SqlDbType]::Date).Value = $m1
,$cmd
'@
$readDef = @'
param($rd, [string]$kind)
$tot = [decimal]0; $cnt = [long]0; $ok = $true; $br = @{}; $per = @{}; $sys = $null; $sysC = $null
while ($rd.Read()) {
  switch ($kind) {
    'B'  { $tot = [decimal]$rd['Revenue']; $cnt = [long]$rd['InvoiceCount'] }
    'S'  { $tot = [decimal]$rd['Revenue']; $cnt = [long]$rd['InvoiceCount'] }
    'BB' { $tot += [decimal]$rd['Revenue']; $cnt += [long]$rd['InvoiceCount']; $br[[int]$rd['Branch_ID']] = [decimal]$rd['Revenue']; $sys = [decimal]$rd['SystemRevenue']; $sysC = [long]$rd['SystemInvoiceCount'] }
    'BP' { $tot += [decimal]$rd['Revenue']; $cnt += [long]$rd['InvoiceCount'] }
    'SP' { $tot += [decimal]$rd['Revenue']; $cnt += [long]$rd['InvoiceCount']; $k = "$($rd['PeriodStart'])"
           if (-not $per.ContainsKey($k)) { $per[$k] = @{ S = [decimal]0; P = [decimal]$rd['PeriodSystemRevenue'] } }; $per[$k].S += [decimal]$rd['Revenue']; $br[[int]$rd['Branch_ID']] = [decimal]$rd['Revenue'] + $(if ($br.ContainsKey([int]$rd['Branch_ID'])) { $br[[int]$rd['Branch_ID']] } else { 0 }) }
  }
}
$rd.Close()
if ($kind -eq 'BB' -and $null -ne $sys) { $ok = ($sys -eq $tot) -and ($sysC -eq $cnt) }
if ($kind -eq 'SP') { foreach ($v in $per.Values) { if ($v.S -ne $v.P) { $ok = $false } } }
[pscustomobject]@{ Total = $tot; Count = $cnt; Consistent = $ok; Branches = $br }
'@
$NewRpt = [scriptblock]::Create($rptDef); $ReadRpt = [scriptblock]::Create($readDef)
function Report($cn, [string]$kind, $tx = $null) { $c = & $NewRpt $cn $kind $m0 $m1 $tx; $rd = $c.ExecuteReader(); return (& $ReadRpt $rd $kind) }

function NewInvoice($cn, [int]$member, [int]$branch, [decimal]$amount, [int]$product) {
    $svc = New-Object System.Data.DataTable; [void]$svc.Columns.Add('LineNo', [int16]); [void]$svc.Columns.Add('Plan_ID', [int]); [void]$svc.Columns.Add('UnitPrice', [decimal]); [void]$svc.Columns.Add('DiscountAmount', [decimal])
    $prd = New-Object System.Data.DataTable; [void]$prd.Columns.Add('LineNo', [int16]); [void]$prd.Columns.Add('Product_ID', [int]); [void]$prd.Columns.Add('Quantity', [int]); [void]$prd.Columns.Add('UnitPrice', [decimal]); [void]$prd.Columns.Add('DiscountAmount', [decimal])
    [void]$prd.Rows.Add([int16]1, $product, 1, $amount, [decimal]0)
    $cmd = $cn.CreateCommand(); $cmd.CommandType = [System.Data.CommandType]::StoredProcedure; $cmd.CommandText = 'dbo.usp_P3_CreateInvoice'
    $cmd.Parameters.Add('@Member_ID', [System.Data.SqlDbType]::Int).Value = $member; $cmd.Parameters.Add('@Employee_ID', [System.Data.SqlDbType]::Int).Value = 1; $cmd.Parameters.Add('@Branch_ID', [System.Data.SqlDbType]::Int).Value = $branch
    $p1 = $cmd.Parameters.Add('@ServiceLines', [System.Data.SqlDbType]::Structured); $p1.TypeName = 'dbo.tt_P3_InvoiceServiceLine'; $p1.Value = $svc
    $p2 = $cmd.Parameters.Add('@ProductLines', [System.Data.SqlDbType]::Structured); $p2.TypeName = 'dbo.tt_P3_InvoiceProductLine'; $p2.Value = $prd
    $o1 = $cmd.Parameters.Add('@Invoice_ID', [System.Data.SqlDbType]::Int); $o1.Direction = [System.Data.ParameterDirection]::Output
    [void]$cmd.ExecuteNonQuery(); return [int]$o1.Value
}
function SettleCmd($cn, [int]$id, $tx = $null) {
    $cmd = $cn.CreateCommand(); $cmd.CommandType = [System.Data.CommandType]::StoredProcedure; $cmd.CommandText = 'dbo.usp_P3_SettleInvoice'; $cmd.CommandTimeout = 60
    if ($tx) { $cmd.Transaction = $tx }
    $cmd.Parameters.Add('@Invoice_ID', [System.Data.SqlDbType]::Int).Value = $id
    $cmd.Parameters.Add('@PaymentMethod', [System.Data.SqlDbType]::VarChar, 10).Value = 'CASH'
    $o = $cmd.Parameters.Add('@Outcome', [System.Data.SqlDbType]::VarChar, 20); $o.Direction = [System.Data.ParameterDirection]::Output
    return $cmd
}
function WaitBlocked($mon, [int]$spid, [int]$blocker, [int]$ms = 10000) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $ms) {
        $t = Query "SELECT wait_type, blocking_session_id, wait_resource FROM sys.dm_exec_requests WHERE session_id = $spid" $mon
        if ($t.Rows.Count -gt 0 -and [int]$t.Rows[0].blocking_session_id -eq $blocker) { return "$($t.Rows[0].wait_type) on $($t.Rows[0].wait_resource)" }
        Start-Sleep -Milliseconds 25
    }
    return $null
}

$checks = New-Object System.Collections.Generic.List[object]
function Check([string]$id, [bool]$ok, [string]$descr, [string]$detail) { $checks.Add([pscustomobject]@{ Id = $id; Result = $(if ($ok) { 'PASS' } else { 'FAIL' }); Descr = $descr; Detail = $detail }); Log ("  {0} {1}  {2} | {3}" -f $id, $(if ($ok) { 'PASS' } else { 'FAIL' }), $descr, $detail) }

$mon = Open; $setup = Open

# ================= R1: deterministic blocking, rollback and commit =================
Log ''; Log 'R1 - uncommitted settlement vs each report routine (rollback, then commit)'
$k = 0
foreach ($kind in $kinds) {
    foreach ($variant in @('ROLLBACK', 'COMMIT')) {
        $k++
        $branch = $(if ($kind -eq 'BP') { 2 } else { 1 }); $amount = [decimal](50000 * $k)
        $id = NewInvoice $setup 19 $branch $amount (1 + ($k % 10))
        $rdr = Open; $wr = Open; $rSpid = Spid $rdr; $wSpid = Spid $wr
        $before = Report $rdr $kind
        $tx = $wr.BeginTransaction()
        $sc = SettleCmd $wr $id $tx; [void]$sc.ExecuteNonQuery(); $inside = "$($sc.Parameters['@Outcome'].Value)"
        $c = & $NewRpt $rdr $kind $m0 $m1 $null
        $ar = $c.BeginExecuteReader()
        $blocked = WaitBlocked $mon $rSpid $wSpid
        $doneEarly = $ar.IsCompleted
        if ($variant -eq 'ROLLBACK') { $tx.Rollback() } else { $tx.Commit() }
        $after = & $ReadRpt ($c.EndExecuteReader($ar)) $kind
        $st = Query "SELECT PaymentStatus, CASE WHEN PaidAt IS NULL THEN 0 ELSE 1 END AS paid, (SELECT COUNT(*) FROM dbo.TEST_HookCallLog WHERE Invoice_ID = $id) AS hooks FROM dbo.INVOICE WHERE Invoice_ID = $id" $mon
        if ($variant -eq 'ROLLBACK') {
            $ok = ($inside -eq 'SETTLED') -and $blocked -and -not $doneEarly -and ($after.Total -eq $before.Total) -and ($after.Count -eq $before.Count) -and ("$($st.Rows[0].PaymentStatus)" -eq 'PENDING') -and ([int]$st.Rows[0].hooks -eq 0)
            Check ("R1-$k") $ok "$($kindName[$kind]): blocked by the uncommitted settlement; after ROLLBACK returns the value before (no dirty read)" ("settled inside writer tx: $inside; waited: $blocked; before $($before.Total)/$($before.Count); after $($after.Total)/$($after.Count); invoice $($st.Rows[0].PaymentStatus), hook rows $($st.Rows[0].hooks)")
        } else {
            $ok = ($inside -eq 'SETTLED') -and $blocked -and -not $doneEarly -and ($after.Total -eq $before.Total + $amount) -and ($after.Count -eq $before.Count + 1) -and ("$($st.Rows[0].PaymentStatus)" -eq 'PAID')
            Check ("R1-$k") $ok "$($kindName[$kind]): blocked by the uncommitted settlement; after COMMIT returns before + FinalAmount, count + 1" ("waited: $blocked; before $($before.Total)/$($before.Count); amount $amount; after $($after.Total)/$($after.Count); invoice $($st.Rows[0].PaymentStatus)")
        }
        $rdr.Close(); $wr.Close()
    }
}
# the rolled-back invoices stay PENDING; settle them now so that the member's state is simple
$r1pending = Query "SELECT Invoice_ID FROM dbo.INVOICE WHERE Member_ID = 19 AND PaymentStatus = 'PENDING'" $mon
foreach ($row in $r1pending.Rows) { $sc = SettleCmd $setup ([int]$row.Invoice_ID); [void]$sc.ExecuteNonQuery() }

# ================= R2: load =================
Log ''; Log "R2 - load: $SettleSessions committing settlement sessions x $PerSession invoices, $AbortSessions aborting sessions, $ReportSessions report sessions"
$plan = New-Object System.Collections.Generic.List[object]
foreach ($s in 1..$SettleSessions) { foreach ($j in 1..$PerSession) { $amt = [decimal](10000 + 1000 * $j + 100 * $s); $b = 1 + (($s + $j) % 3)
    $plan.Add([pscustomobject]@{ S = $s; Id = (NewInvoice $setup (10 + $s) $b $amt (1 + ($j % 10))); Amount = $amt; Branch = $b }) } }
$abortIds = @(); foreach ($a in 1..$AbortSessions) { $abortIds += (NewInvoice $setup (16 + $a) $a ([decimal](77777.01 + 11111 * $a)) 5) }
$base = @{}; foreach ($kind in $kinds) { $base[$kind] = Report $setup $kind }
Log ("Prepared $($plan.Count) PENDING invoices (whole VND) and $($abortIds.Count) abort-only invoices (x.01 VND); company total before R2: $($base['S'].Total) ($($base['S'].Count) invoices)")

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
                $err = 0; $msg = ''; $t0 = [DateTime]::UtcNow.Ticks
                try { [void]$cmd.ExecuteNonQuery() } catch { $ex = $_.Exception; while ($ex -and -not ($ex -is [System.Data.SqlClient.SqlException])) { $ex = $ex.InnerException }; if ($ex) { $err = $ex.Number; $msg = $ex.Message } else { $err = -1; $msg = $_.Exception.Message } }
                $t1 = [DateTime]::UtcNow.Ticks
                if ($err -eq 1205 -and $retries -lt 3) { $retries++; continue }
                break
            }
            $res.Add([pscustomobject]@{ Id = [int]$id; Outcome = "$($o1.Value)"; Err = $err; Msg = $msg; Retries = $retries; T0 = $t0; T1 = $t1 })
        }
    } finally { $cn.Close() }
    ,$res.ToArray()
}
$abortWorker = {
    param([int]$id, [string]$connStr, $ready, $gate, $done)
    $res = New-Object System.Collections.Generic.List[object]
    $cn = New-Object System.Data.SqlClient.SqlConnection $connStr; $cn.Open()
    try {
        [void]$ready.Signal(); [void]$gate.WaitOne()
        $n = 0
        while (($n -lt 5 -or -not $done.WaitOne(0)) -and $n -lt 400) {
            $n++
            $cmd = $cn.CreateCommand(); $cmd.CommandTimeout = 60
            $cmd.CommandText = "SET XACT_ABORT ON; BEGIN TRANSACTION; DECLARE @o varchar(20); EXEC dbo.usp_P3_SettleInvoice @Invoice_ID = $id, @PaymentMethod = 'CASH', @Outcome = @o OUTPUT; WAITFOR DELAY '00:00:00.020'; ROLLBACK TRANSACTION; SELECT @o;"
            $err = 0; $msg = ''; $out = ''; $t0 = [DateTime]::UtcNow.Ticks
            try { $out = "$($cmd.ExecuteScalar())" } catch { $ex = $_.Exception; while ($ex -and -not ($ex -is [System.Data.SqlClient.SqlException])) { $ex = $ex.InnerException }; if ($ex) { $err = $ex.Number; $msg = $ex.Message } else { $err = -1; $msg = $_.Exception.Message } }
            $res.Add([pscustomobject]@{ Id = $id; Inside = $out; Err = $err; Msg = $msg; T0 = $t0; T1 = [DateTime]::UtcNow.Ticks })
        }
    } finally { $cn.Close() }
    ,$res.ToArray()
}
$reportWorker = {
    param([int]$r, [string]$connStr, $ready, $gate, $done, [string]$rptDef, [string]$readDef, [datetime]$m0, [datetime]$m1)
    $NewRpt = [scriptblock]::Create($rptDef); $ReadRpt = [scriptblock]::Create($readDef)
    $kinds = @('S', 'BB', 'SP', 'B', 'BP')
    $res = New-Object System.Collections.Generic.List[object]
    $cn = New-Object System.Data.SqlClient.SqlConnection $connStr; $cn.Open()
    try {
        [void]$ready.Signal(); [void]$gate.WaitOne()
        $n = 0
        while (($n -lt 10 -or -not $done.WaitOne(0)) -and $n -lt 600) {
            $kind = $kinds[($n + $r) % $kinds.Count]; $n++
            $retries = 0
            while ($true) {
                $err = 0; $msg = ''; $o = $null; $t0 = [DateTime]::UtcNow.Ticks
                try { $c = & $NewRpt $cn $kind $m0 $m1 $null; $o = & $ReadRpt ($c.ExecuteReader()) $kind } catch { $ex = $_.Exception; while ($ex -and -not ($ex -is [System.Data.SqlClient.SqlException])) { $ex = $ex.InnerException }; if ($ex) { $err = $ex.Number; $msg = $ex.Message } else { $err = -1; $msg = $_.Exception.Message } }
                $t1 = [DateTime]::UtcNow.Ticks
                if ($err -eq 1205 -and $retries -lt 3) { $retries++; continue }
                break
            }
            $res.Add([pscustomobject]@{ R = $r; Seq = $n; Kind = $kind; Err = $err; Msg = $msg; Retries = $retries; T0 = $t0; T1 = $t1; Obs = $o })
        }
    } finally { $cn.Close() }
    ,$res.ToArray()
}

$nW = $SettleSessions + $AbortSessions + $ReportSessions
$ready = New-Object System.Threading.CountdownEvent($nW)
$gate = New-Object System.Threading.ManualResetEvent($false)
$done = New-Object System.Threading.ManualResetEvent($false)
$pool = [runspacefactory]::CreateRunspacePool(1, $nW); $pool.Open()
$sJobs = @(); $aJobs = @(); $rJobs = @()
foreach ($s in 1..$SettleSessions) {
    $ids = @($plan | Where-Object { $_.S -eq $s } | ForEach-Object { $_.Id })
    $ps = [powershell]::Create(); $ps.RunspacePool = $pool; [void]$ps.AddScript($settleWorker).AddArgument($s).AddArgument($ids).AddArgument($connStr).AddArgument($ready).AddArgument($gate)
    $sJobs += [pscustomobject]@{ PS = $ps; H = $ps.BeginInvoke() }
}
foreach ($id in $abortIds) {
    $ps = [powershell]::Create(); $ps.RunspacePool = $pool; [void]$ps.AddScript($abortWorker).AddArgument($id).AddArgument($connStr).AddArgument($ready).AddArgument($gate).AddArgument($done)
    $aJobs += [pscustomobject]@{ PS = $ps; H = $ps.BeginInvoke() }
}
foreach ($r in 1..$ReportSessions) {
    $ps = [powershell]::Create(); $ps.RunspacePool = $pool; [void]$ps.AddScript($reportWorker).AddArgument($r).AddArgument($connStr).AddArgument($ready).AddArgument($gate).AddArgument($done).AddArgument($rptDef).AddArgument($readDef).AddArgument($m0).AddArgument($m1)
    $rJobs += [pscustomobject]@{ PS = $ps; H = $ps.BeginInvoke() }
}
if (-not $ready.Wait(60000)) { $gate.Set(); $done.Set(); throw 'Not all sessions connected within 60 s.' }
$released = [DateTime]::UtcNow; [void]$gate.Set()
$deadline = [DateTime]::UtcNow.AddSeconds(300)   # watchdog: no unattended load beyond 5 minutes
$settled = @(); $aborted = @(); $reports = @(); $workerErrors = @()
function Collect($jobs, [string]$what) {
    $out = @()
    foreach ($j in $jobs) {
        $left = [int][Math]::Max(1000, ($deadline - [DateTime]::UtcNow).TotalMilliseconds)
        if (-not $j.H.AsyncWaitHandle.WaitOne($left)) { $j.PS.Stop(); $script:workerErrors += "watchdog: $what session stopped"; continue }
        $out += @($j.PS.EndInvoke($j.H) | ForEach-Object { $_ })
        if ($j.PS.Streams.Error.Count -gt 0) { $script:workerErrors += ($j.PS.Streams.Error | ForEach-Object { "$_" }) }
    }
    return ,$out
}
$settled = Collect $sJobs 'settlement'
[void]$done.Set()
$aborted = Collect $aJobs 'abort'
$reports = Collect $rJobs 'report'
$pool.Close()
Log ("Gate released (UTC): " + (Utc $released) + "; all sessions finished (UTC): " + (Utc ([DateTime]::UtcNow)) + " (context only, not a measurement)")
$final = @{}; foreach ($kind in $kinds) { $final[$kind] = Report $setup $kind }

$badS = @($settled | Where-Object { $_.Err -ne 0 -or $_.Outcome -ne 'SETTLED' })
$badA = @($aborted | Where-Object { $_.Err -ne 0 -or $_.Inside -ne 'SETTLED' })
$badR = @($reports | Where-Object { $_.Err -ne 0 })
$retr = (($settled | Measure-Object -Property Retries -Sum).Sum) + (($reports | Measure-Object -Property Retries -Sum).Sum)
Check 'R2-C1' (($settled.Count -eq $plan.Count) -and $badS.Count -eq 0 -and $badA.Count -eq 0 -and $badR.Count -eq 0 -and $workerErrors.Count -eq 0 -and $aborted.Count -gt 0) 'Every committing settlement SETTLED; every aborted attempt settled inside its transaction, then rolled back; every report call succeeded' ("settlements $($settled.Count)/$($plan.Count), failed $($badS.Count); aborted attempts $($aborted.Count), unexpected $($badA.Count); report calls $($reports.Count), failed $($badR.Count); deadlock retries $retr; worker errors $($workerErrors.Count) $($workerErrors -join ' | ')" + $(if ($badS.Count) { '; first: ' + $badS[0].Msg } elseif ($badA.Count) { '; first: ' + $badA[0].Msg } elseif ($badR.Count) { '; first: ' + $badR[0].Msg } else { '' }))

$okR = @($reports | Where-Object { $_.Err -eq 0 -and $null -ne $_.Obs })
$dirty = New-Object System.Collections.Generic.List[string]; $bound = New-Object System.Collections.Generic.List[string]; $incons = 0
foreach ($x in $okR) {
    $b = $base[$x.Kind]; $f = $final[$x.Kind]; $o = $x.Obs
    if ((($o.Total - $b.Total) % 1) -ne 0) { $dirty.Add("$($x.Kind) total $($o.Total)") }
    foreach ($br in $o.Branches.Keys) { $bb = $(if ($b.Branches.ContainsKey($br)) { $b.Branches[$br] } else { [decimal]0 }); if ((($o.Branches[$br] - $bb) % 1) -ne 0) { $dirty.Add("$($x.Kind) branch $br $($o.Branches[$br])") } }
    if ($o.Total -lt $b.Total -or $o.Total -gt $f.Total -or $o.Count -lt $b.Count -or $o.Count -gt $f.Count) { $bound.Add("$($x.Kind) $($o.Total)/$($o.Count) outside [$($b.Total)/$($b.Count), $($f.Total)/$($f.Count)]") }
    if (-not $o.Consistent) { $incons++ }
}
Check 'R2-C2' ($dirty.Count -eq 0 -and $okR.Count -gt 0) 'No dirty read: no observed total or branch row contains the 0.01 VND of a rolled-back settlement' ("observations $($okR.Count); with cents $($dirty.Count)" + $(if ($dirty.Count) { '; first: ' + $dirty[0] } else { '' }))
Check 'R2-C3' ($bound.Count -eq 0) 'Every observation lies between the committed state before and after the load (revenue and count)' ("violations $($bound.Count)" + $(if ($bound.Count) { '; first: ' + $bound[0] } else { '' }))
$mono = 0
foreach ($grp in ($okR | Where-Object { $_.Kind -eq 'S' } | Group-Object R)) { $prev = $null; foreach ($x in ($grp.Group | Sort-Object Seq)) { if ($null -ne $prev -and ($x.Obs.Total -lt $prev.Total -or $x.Obs.Count -lt $prev.Count)) { $mono++ }; $prev = $x.Obs } }
Check 'R2-C4' ($mono -eq 0) 'Per report session, successive company totals never decrease (PAID is terminal)' ("decreases $mono over $(@($okR | Where-Object { $_.Kind -eq 'S' }).Count) company-total observations")
Check 'R2-C5' ($incons -eq 0) 'Single-statement consistency: by-branch SystemRevenue/Count = sum of its rows; by-period totals = sum of their rows' ("inconsistent observations $incons")

$expAdd = [decimal](($plan | Measure-Object -Property Amount -Sum).Sum)
$abList = ($abortIds -join ',')
$ab = Query "SELECT (SELECT COUNT(*) FROM dbo.INVOICE WHERE Invoice_ID IN ($abList) AND (PaymentStatus <> 'PENDING' OR PaidAt IS NOT NULL)) AS bad_state,
                    (SELECT COUNT(*) FROM dbo.TEST_HookCallLog WHERE Invoice_ID IN ($abList)) AS hooks,
                    (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID IN (17, 18)) AS spend_rows,
                    (SELECT SUM(CurrentPoints) FROM dbo.MEMBER WHERE Member_ID IN (17, 18)) AS points,
                    (SELECT COUNT(*) FROM dbo.MEMBER AS m WHERE m.CurrentPoints <> ISNULL((SELECT SUM(PointsEarned) FROM dbo.MEMBER_MONTHLY_SPENDING AS s WHERE s.Member_ID = m.Member_ID), 0)) AS pts_bad" $mon
$a0 = $ab.Rows[0]
$c6 = ($final['S'].Total - $base['S'].Total -eq $expAdd) -and ($final['S'].Count - $base['S'].Count -eq $plan.Count) -and ([int]$a0.bad_state -eq 0) -and ([int]$a0.hooks -eq 0) -and ([int]$a0.spend_rows -eq 0) -and ([int]$a0.points -eq 0) -and ([int]$a0.pts_bad -eq 0)
Check 'R2-C6' $c6 'Final state: company total - before = sum of committed harness amounts; aborted invoices PENDING, no PaidAt, hook call, spending row or point; CurrentPoints = SUM(PointsEarned) for all members' ("delta $($final['S'].Total - $base['S'].Total) vs $expAdd; count delta $($final['S'].Count - $base['S'].Count) vs $($plan.Count); aborted bad state $($a0.bad_state), hooks $($a0.hooks), spending rows $($a0.spend_rows), points $($a0.points); members with points <> SUM(PointsEarned) $($a0.pts_bad)")
$sFirst = ($settled | Measure-Object -Property T0 -Minimum).Minimum; $sLast = ($settled | Measure-Object -Property T1 -Maximum).Maximum
$ov = @($okR | Where-Object { $_.T0 -lt $sLast -and $_.T1 -gt $sFirst }).Count
$aFirst = ($aborted | Measure-Object -Property T0 -Minimum).Minimum; $aLast = ($aborted | Measure-Object -Property T1 -Maximum).Maximum
$ovA = @($okR | Where-Object { $_.T0 -lt $aLast -and $_.T1 -gt $aFirst }).Count
Check 'R2-C7' ($ov -ge 3 -and $ovA -ge 3 -and $aborted.Count -ge 10) 'Report calls overlapped the committing settlements and the aborted transactions' ("report calls overlapping settlements $ov; overlapping aborted transactions $ovA; aborted attempts $($aborted.Count)")

# ================= R3: caller-chosen SERIALIZABLE report transaction =================
Log ''; Log 'R3 - two report statements in one SERIALIZABLE transaction (session setting only) while a settlement commits'
$id3 = NewInvoice $setup 20 3 ([decimal]123000) 7
$rep = Open; $wr = Open; $rSpid = Spid $rep; $wSpid = Spid $wr
$tx = $rep.BeginTransaction([System.Data.IsolationLevel]::Serializable)
$v1 = Report $rep 'S' $tx
$sc = SettleCmd $wr $id3; $ar = $sc.BeginExecuteNonQuery()
$blocked = WaitBlocked $mon $wSpid $rSpid
$v2 = Report $rep 'BB' $tx
$v3 = Report $rep 'S' $tx
$early = $ar.IsCompleted
$tx.Commit()
$err3 = 0; try { [void]$sc.EndExecuteNonQuery($ar) } catch { $err3 = (SqlErr $_.Exception).N }
$v4 = Report $setup 'S'
$ok3 = $blocked -and -not $early -and ($v2.Total -eq $v1.Total) -and ($v3.Total -eq $v1.Total) -and ($v2.Count -eq $v1.Count) -and $v2.Consistent -and ($err3 -eq 0) -and ("$($sc.Parameters['@Outcome'].Value)" -eq 'SETTLED') -and ($v4.Total -eq $v1.Total + 123000) -and ($v4.Count -eq $v1.Count + 1)
Check 'R3' $ok3 'SERIALIZABLE report transaction: the settlement waits; total, by-branch sum and repeated total agree inside the transaction; after COMMIT the settlement completes and is reported' ("settlement waited: $blocked; inside tx: total $($v1.Total), by-branch sum $($v2.Total), repeat $($v3.Total); settlement error $err3 outcome $($sc.Parameters['@Outcome'].Value); after: $($v4.Total)/$($v4.Count)")
$rep.Close(); $wr.Close()

$open = Query "SELECT COUNT(*) AS n FROM sys.dm_exec_sessions WHERE is_user_process = 1 AND open_transaction_count > 0 AND session_id <> @@SPID AND database_id = DB_ID()" $mon
Check 'Z' ([int]$open.Rows[0].n -eq 0) 'No open transaction left in the database by the harness' ("sessions with open transactions: $($open.Rows[0].n)")
$mon.Close(); $setup.Close()

$nf = @($checks | Where-Object { $_.Result -eq 'FAIL' }).Count
Log ''; Log ("T-CONC-04R SUMMARY: checks $($checks.Count); FAIL $nf"); Log ("T-CONC-04R_RESULT: " + $(if ($nf -eq 0) { 'PASS' } else { 'FAIL' }))
if ($OutFile) { $lines | Out-File -Encoding utf8 $OutFile }
if ($nf -eq 0) { exit 0 } else { exit 1 }
