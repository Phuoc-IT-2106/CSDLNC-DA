<#
  T-CONC-08_settle_vs_cancel_ordered.ps1 - TEST_ONLY concurrency test for WO-P3-P3-03 Part C (Owner directive of
  2026-11-10 section 5 "Settlement versus Cancellation"). Deterministic complement of the random race in T-CONC-01
  (where settlement usually wins): BOTH winners are forced. Correctness only, no timing (R-27). PowerShell 5.1.

  For each invoice a blocker session holds UPDLOCK on the invoice row; the first operation is started and observed
  waiting on that row, then the second operation is started and observed waiting; the blocker then releases. Lock
  requests are granted in arrival order, so the first operation wins.
    order CancelFirst (3 invoices, member 27): cancel -> CANCELLED; the queued settlement fails with 51204
    order SettleFirst (3 invoices, member 28): settle -> SETTLED;   the queued cancellation fails with 51223
  Checks on the final database state:
    C1 every operation was observed waiting behind the blocker (real overlap) and the designed operation won each time
    C2 the loser received exactly its defined error (51204 / 51223), nothing else
    C3 CANCELLED invoices: PaidAt NULL, no hook call, no spending row, no points for member 27
    C4 PAID invoices: one inventory + one entitlement hook call each; member 28 spending = sum of the three amounts;
       PointsEarned = FLOOR(TotalSpend / 100000); CurrentPoints = SUM(PointsEarned)
    C5 no open transaction left
  Members 27-28 (no invoice, spending or points expected when the script starts).
  Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tests/db/concurrency/T-CONC-08_settle_vs_cancel_ordered.ps1 -OutFile <path>
  Exit code 0 = PASS, 1 = FAIL.
#>
param(
    [string]$Server = 'localhost',
    [string]$Database = 'FitLife_P3_UC05',
    [int]$Repeats = 3,
    [string]$OutFile = ''
)
$ErrorActionPreference = 'Stop'
$inv = [Globalization.CultureInfo]::InvariantCulture
if ($Database -ne 'FitLife_P3_UC05') { throw 'T-CONC-08 runs only against FitLife_P3_UC05.' }
$connStr = "Server=$Server;Database=$Database;Integrated Security=SSPI;Application Name=P3-T-CONC-08;Pooling=false"
$lines = New-Object System.Collections.Generic.List[string]
function Log([string]$s) { $lines.Add($s); Write-Output $s }
function Utc([datetime]$d) { $d.ToString('yyyy-MM-dd HH:mm:ss.fff', $inv) }
function Open { $cn = New-Object System.Data.SqlClient.SqlConnection $connStr; $cn.Open(); return $cn }
function Spid($cn) { $c = $cn.CreateCommand(); $c.CommandText = 'SELECT @@SPID'; return [int]$c.ExecuteScalar() }
function Query([string]$sql, $cn) { $cmd = $cn.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 120; $da = New-Object System.Data.SqlClient.SqlDataAdapter $cmd; $dt = New-Object System.Data.DataTable; [void]$da.Fill($dt); return ,$dt }
function SqlErr($e) { $x = $e; while ($x -and -not ($x -is [System.Data.SqlClient.SqlException])) { $x = $x.InnerException }; if ($x) { return $x.Number }; return -1 }
function WaitBlocked($mon, [int]$spid, [int]$ms = 10000) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $ms) {
        $t = Query "SELECT wait_type, blocking_session_id FROM sys.dm_exec_requests WHERE session_id = $spid" $mon
        if ($t.Rows.Count -gt 0 -and [int]$t.Rows[0].blocking_session_id -gt 0) { return "$($t.Rows[0].wait_type) behind session $($t.Rows[0].blocking_session_id)" }
        Start-Sleep -Milliseconds 25
    }
    return $null
}
function OpCmd($cn, [string]$op, [int]$id) {
    $c = $cn.CreateCommand(); $c.CommandType = [System.Data.CommandType]::StoredProcedure; $c.CommandTimeout = 60
    $c.CommandText = $(if ($op -eq 'S') { 'dbo.usp_P3_SettleInvoice' } else { 'dbo.usp_P3_CancelInvoice' })
    $c.Parameters.Add('@Invoice_ID', [System.Data.SqlDbType]::Int).Value = $id
    if ($op -eq 'S') { $c.Parameters.Add('@PaymentMethod', [System.Data.SqlDbType]::VarChar, 10).Value = 'CARD' }
    $o = $c.Parameters.Add('@Outcome', [System.Data.SqlDbType]::VarChar, 20); $o.Direction = [System.Data.ParameterDirection]::Output
    return $c
}
function NewInvoice($cn, [int]$member, [decimal]$amount) {
    $svc = New-Object System.Data.DataTable; [void]$svc.Columns.Add('LineNo', [int16]); [void]$svc.Columns.Add('Plan_ID', [int]); [void]$svc.Columns.Add('UnitPrice', [decimal]); [void]$svc.Columns.Add('DiscountAmount', [decimal])
    $prd = New-Object System.Data.DataTable; [void]$prd.Columns.Add('LineNo', [int16]); [void]$prd.Columns.Add('Product_ID', [int]); [void]$prd.Columns.Add('Quantity', [int]); [void]$prd.Columns.Add('UnitPrice', [decimal]); [void]$prd.Columns.Add('DiscountAmount', [decimal])
    [void]$prd.Rows.Add([int16]1, 3, 2, $amount / 2, [decimal]0)
    $cmd = $cn.CreateCommand(); $cmd.CommandType = [System.Data.CommandType]::StoredProcedure; $cmd.CommandText = 'dbo.usp_P3_CreateInvoice'
    $cmd.Parameters.Add('@Member_ID', [System.Data.SqlDbType]::Int).Value = $member; $cmd.Parameters.Add('@Employee_ID', [System.Data.SqlDbType]::Int).Value = 2; $cmd.Parameters.Add('@Branch_ID', [System.Data.SqlDbType]::Int).Value = 3
    $p1 = $cmd.Parameters.Add('@ServiceLines', [System.Data.SqlDbType]::Structured); $p1.TypeName = 'dbo.tt_P3_InvoiceServiceLine'; $p1.Value = $svc
    $p2 = $cmd.Parameters.Add('@ProductLines', [System.Data.SqlDbType]::Structured); $p2.TypeName = 'dbo.tt_P3_InvoiceProductLine'; $p2.Value = $prd
    $o1 = $cmd.Parameters.Add('@Invoice_ID', [System.Data.SqlDbType]::Int); $o1.Direction = [System.Data.ParameterDirection]::Output
    [void]$cmd.ExecuteNonQuery(); return [int]$o1.Value
}

$mon = Open; $setup = Open
$g = Query @"
SELECT (SELECT CONVERT(nvarchar(200), value) FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable') AS marker,
       OBJECT_ID(N'dbo.TEST_HookCallLog', N'U') AS hk,
       (SELECT COUNT(*) FROM dbo.INVOICE WHERE Member_ID IN (27, 28)) + (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID IN (27, 28))
         + (SELECT ISNULL(SUM(CurrentPoints), 0) FROM dbo.MEMBER WHERE Member_ID IN (27, 28)) AS used,
       MONTH(DATEADD(HOUR, 7, SYSUTCDATETIME())) AS m_now, MONTH(DATEADD(MINUTE, 10, DATEADD(HOUR, 7, SYSUTCDATETIME()))) AS m_soon
"@ $mon
$r0 = $g.Rows[0]
if (-not ("$($r0.marker)" -like 'WO-P3-P3-00*')) { throw 'Refusing to run: FitLife_P3_UC05 without the disposable marker.' }
if ($r0.hk -is [DBNull]) { throw 'Hook doubles not deployed.' }
if ([int]$r0.used -ne 0) { throw 'Members 27-28 must have no invoice, spending row or point.' }
if ([int]$r0.m_now -ne [int]$r0.m_soon) { throw 'Too close to a local month boundary; run again later.' }

Log 'T-CONC-08 - settlement vs cancellation of the same invoice, both winners forced (WO-P3-P3-03 Part C).'
Log ("Started (UTC): " + (Utc ([DateTime]::UtcNow)) + "; database $Database; $Repeats invoices per order; members 27 (cancel first) and 28 (settle first)")
Log ("Harness SHA-256: " + (Get-FileHash -Algorithm SHA256 $PSCommandPath).Hash)

$res = New-Object System.Collections.Generic.List[object]
foreach ($order in 'CancelFirst', 'SettleFirst') {
    foreach ($k in 1..$Repeats) {
        $member = $(if ($order -eq 'CancelFirst') { 27 } else { 28 }); $amount = [decimal](60000 + 10000 * $k)
        $id = NewInvoice $setup $member $amount
        $first = $(if ($order -eq 'CancelFirst') { 'C' } else { 'S' }); $second = $(if ($first -eq 'C') { 'S' } else { 'C' })
        $blk = Open; $c1 = Open; $c2 = Open; $s1 = Spid $c1; $s2 = Spid $c2
        $tx = $blk.BeginTransaction(); $bc = $blk.CreateCommand(); $bc.Transaction = $tx
        $bc.CommandText = "DECLARE @s varchar(10); SELECT @s = PaymentStatus FROM dbo.INVOICE WITH (UPDLOCK, ROWLOCK) WHERE Invoice_ID = $id;"; [void]$bc.ExecuteNonQuery()
        $cmd1 = OpCmd $c1 $first $id; $ar1 = $cmd1.BeginExecuteNonQuery(); $w1 = WaitBlocked $mon $s1
        $cmd2 = OpCmd $c2 $second $id; $ar2 = $cmd2.BeginExecuteNonQuery(); $w2 = WaitBlocked $mon $s2
        $tx.Rollback(); $blk.Close()
        $e1 = 0; try { [void]$cmd1.EndExecuteNonQuery($ar1) } catch { $e1 = SqlErr $_.Exception }
        $e2 = 0; try { [void]$cmd2.EndExecuteNonQuery($ar2) } catch { $e2 = SqlErr $_.Exception }
        $c1.Close(); $c2.Close()
        $st = Query "SELECT PaymentStatus, CASE WHEN PaidAt IS NULL THEN 0 ELSE 1 END AS paid, (SELECT COUNT(*) FROM dbo.TEST_HookCallLog WHERE Invoice_ID = $id AND HookName = 'INVENTORY_DECREMENT') AS inv, (SELECT COUNT(*) FROM dbo.TEST_HookCallLog WHERE Invoice_ID = $id AND HookName = 'ENTITLEMENT_ACTIVATION') AS ent FROM dbo.INVOICE WHERE Invoice_ID = $id" $mon
        $x = [pscustomobject]@{ Order = $order; Id = $id; Amount = $amount; W1 = $w1; W2 = $w2; Out1 = "$($cmd1.Parameters['@Outcome'].Value)"; E1 = $e1; E2 = $e2
                                Status = "$($st.Rows[0].PaymentStatus)"; Paid = [int]$st.Rows[0].paid; Inv = [int]$st.Rows[0].inv; Ent = [int]$st.Rows[0].ent }
        $res.Add($x)
        Log ("  {0} invoice {1}: first {2} waited [{3}] -> err {4} outcome {5}; second {6} waited [{7}] -> err {8}; final {9}, PaidAt set {10}, hook calls {11}/{12}" -f $order, $id, $first, $w1, $e1, $x.Out1, $second, $w2, $e2, $x.Status, $x.Paid, $x.Inv, $x.Ent)
    }
}

$checks = New-Object System.Collections.Generic.List[object]
function Check([string]$id, [bool]$ok, [string]$descr, [string]$detail) { $checks.Add([pscustomobject]@{ Id = $id; Result = $(if ($ok) { 'PASS' } else { 'FAIL' }); Descr = $descr; Detail = $detail }) }
$cf = @($res | Where-Object { $_.Order -eq 'CancelFirst' }); $sf = @($res | Where-Object { $_.Order -eq 'SettleFirst' })
$c1bad = @($res | Where-Object { -not $_.W1 -or -not $_.W2 }).Count + @($cf | Where-Object { $_.E1 -ne 0 -or $_.Out1 -ne 'CANCELLED' -or $_.Status -ne 'CANCELLED' }).Count + @($sf | Where-Object { $_.E1 -ne 0 -or $_.Out1 -ne 'SETTLED' -or $_.Status -ne 'PAID' }).Count
Check 'C1' ($c1bad -eq 0 -and $res.Count -eq 2 * $Repeats) 'Both operations waited behind the blocker; the first queued operation won every time (CANCELLED in CancelFirst, PAID in SettleFirst)' ("invoices $($res.Count); violations $c1bad")
$c2bad = @($cf | Where-Object { $_.E2 -ne 51204 }).Count + @($sf | Where-Object { $_.E2 -ne 51223 }).Count
Check 'C2' ($c2bad -eq 0) 'The loser got exactly its defined error: queued settlement 51204 (invoice CANCELLED), queued cancellation 51223 (invoice PAID)' ("violations $c2bad; errors: " + (($res | ForEach-Object { "$($_.Order):$($_.E2)" }) -join ','))
$m27 = Query "SELECT (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = 27) AS rows_, (SELECT CurrentPoints FROM dbo.MEMBER WHERE Member_ID = 27) AS pts" $mon
$c3bad = @($cf | Where-Object { $_.Paid -ne 0 -or $_.Inv -ne 0 -or $_.Ent -ne 0 }).Count
Check 'C3' ($c3bad -eq 0 -and [int]$m27.Rows[0].rows_ -eq 0 -and [int]$m27.Rows[0].pts -eq 0) 'CANCELLED invoices: no PaidAt, no hook call, no spending row, no points (member 27)' ("invoices with effects $c3bad; member 27 spending rows $($m27.Rows[0].rows_), points $($m27.Rows[0].pts)")
$exp = [decimal](($sf | Measure-Object -Property Amount -Sum).Sum)
$m28 = Query "SELECT ISNULL(SUM(TotalSpend), 0) AS sp, ISNULL(SUM(PointsEarned), 0) AS pe, SUM(CASE WHEN PointsEarned <> CONVERT(int, FLOOR(TotalSpend / 100000)) THEN 1 ELSE 0 END) AS bad, (SELECT CurrentPoints FROM dbo.MEMBER WHERE Member_ID = 28) AS pts FROM dbo.MEMBER_MONTHLY_SPENDING WHERE Member_ID = 28" $mon
$c4bad = @($sf | Where-Object { $_.Paid -ne 1 -or $_.Inv -ne 1 -or $_.Ent -ne 1 }).Count
Check 'C4' ($c4bad -eq 0 -and [decimal]$m28.Rows[0].sp -eq $exp -and [int]$m28.Rows[0].bad -eq 0 -and [int]$m28.Rows[0].pts -eq [int]$m28.Rows[0].pe) 'PAID invoices: one call per hook; member 28 spending = sum of the amounts; PointsEarned = FLOOR; CurrentPoints = SUM(PointsEarned)' ("invoices with wrong effects $c4bad; spending $($m28.Rows[0].sp) vs $exp; points $($m28.Rows[0].pts) vs SUM(PointsEarned) $($m28.Rows[0].pe)")
$open = Query "SELECT COUNT(*) AS n FROM sys.dm_exec_sessions WHERE is_user_process = 1 AND open_transaction_count > 0 AND session_id <> @@SPID AND database_id = DB_ID()" $mon
Check 'C5' ([int]$open.Rows[0].n -eq 0) 'No open transaction left' ("sessions with open transactions $($open.Rows[0].n)")
$mon.Close(); $setup.Close()

Log ''; Log 'Checks:'
foreach ($c in $checks) { Log ("  {0} {1}  {2} | {3}" -f $c.Id, $c.Result, $c.Descr, $c.Detail) }
$nf = @($checks | Where-Object { $_.Result -eq 'FAIL' }).Count
Log ''; Log ("T-CONC-08 SUMMARY: checks $($checks.Count); FAIL $nf"); Log ("T-CONC-08_RESULT: " + $(if ($nf -eq 0) { 'PASS' } else { 'FAIL' }))
if ($OutFile) { $lines | Out-File -Encoding utf8 $OutFile }
if ($nf -eq 0) { exit 0 } else { exit 1 }
