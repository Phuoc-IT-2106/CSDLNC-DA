<#
  capture_q_uc05_bc_b0.ps1 - TEST_ONLY task 0 of WO-P3-P3-02 (Windows PowerShell 5.1; System.Data.SqlClient).
  Captures the B0 evidence of the frozen loyalty queries db/queries/baseline/Q-UC05-B.sql and Q-UC05-C.sql on DS-L
  (FitLife_P3_UC05L) BEFORE any loyalty index exists and before the loyalty routines are deployed:
    - query file SHA-256 and fixed parameter sets;
    - UPDATE STATISTICS ... WITH FULLSCAN on the four P3 tables (10 section 4.3 step 2; statistics only);
    - one discarded warm-up execution, then one execution with SET STATISTICS IO ON and SET STATISTICS XML ON:
      the Actual Execution Plan (.sqlplan), logical reads per table (raw STATISTICS IO text kept), row count and
      a SHA-256 of the ordered result.
  NO timing is recorded: CPU and elapsed values on this machine are DIAGNOSTIC_ONLY until R-27 is closed
  (WO-P3-P3-02 revision of 2026-11-09). Plans, logical reads and row counts are valid analysis inputs.
  Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tests/db/loyalty/capture_q_uc05_bc_b0.ps1 -RunTs <yyyyMMdd-HHmm>
#>
param(
    [string]$Server = 'localhost',
    [string]$Database = 'FitLife_P3_UC05L',
    [string]$RunTs = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmm'),
    [string]$OutFile = '',
    [string]$PlanDir = ''
)
$ErrorActionPreference = 'Stop'
$inv = [Globalization.CultureInfo]::InvariantCulture
if ($Database -ne 'FitLife_P3_UC05L') { throw 'Task 0 capture runs only in FitLife_P3_UC05L.' }
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$planDir = if ($PlanDir) { $PlanDir } else { Join-Path $repo 'docs/phase2/person3/evidence/execution-plans' }
New-Item -ItemType Directory -Force -Path $planDir | Out-Null
$connStr = "Server=$Server;Database=$Database;Integrated Security=SSPI;Application Name=P3-T0-capture;Pooling=false"
$lines = New-Object System.Collections.Generic.List[string]
function Log([string]$s) { $lines.Add($s); Write-Output $s }

$cn = New-Object System.Data.SqlClient.SqlConnection $connStr
$msgs = New-Object System.Collections.Generic.List[string]
$cn.add_InfoMessage({ param($sender, $e) foreach ($er in $e.Errors) { $msgs.Add($er.Message) } })
$cn.FireInfoMessageEventOnUserErrors = $false
$cn.Open()
function NonQuery([string]$sql) { $c = $cn.CreateCommand(); $c.CommandText = $sql; $c.CommandTimeout = 600; [void]$c.ExecuteNonQuery() }

$g = $cn.CreateCommand(); $g.CommandText = "SELECT (SELECT CONVERT(nvarchar(200), value) FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable'), (SELECT COUNT(*) FROM sys.indexes AS i JOIN sys.tables AS t ON t.object_id = i.object_id WHERE i.type > 0 AND i.is_primary_key = 0), OBJECT_ID(N'dbo.usp_P3_EvaluateTiers'), (SELECT COUNT(*) FROM dbo.INVOICE), DATABASEPROPERTYEX(DB_NAME(), 'IsAutoCreateStatistics'), (SELECT compatibility_level FROM sys.databases WHERE name = DB_NAME())"
$rd = $g.ExecuteReader(); [void]$rd.Read()
$marker = "$($rd.GetValue(0))"; $nonPk = [int]$rd.GetValue(1); $evalExists = -not ($rd.IsDBNull(2)); $invoices = [int]$rd.GetValue(3); $compat = $rd.GetValue(5); $rd.Close()
if ($marker -notlike 'WO-P3-P2-01*WO-P3-P3-02*') { throw 'Refusing to run: FitLife_P3_UC05L without its marker.' }
if ($nonPk -ne 0) { throw 'B0 requires no non-PK index.' }
if ($evalExists) { throw 'B0 must be captured before the loyalty routines are deployed.' }

Log "T0-QUC05BC - WO-P3-P3-02 task 0: B0 capture of Q-UC05-B and Q-UC05-C on DS-L (FitLife_P3_UC05L). Run $RunTs."
Log ("Captured (UTC): " + (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss', $inv) + "; compatibility level $compat; invoices $invoices; non-PK indexes $nonPk (configuration B0); loyalty routines not yet deployed")
Log 'Timing: NOT recorded (R-27 OPEN; DIAGNOSTIC_ONLY on this machine). Valid evidence here: plans, logical reads, row counts, result hashes.'
NonQuery 'UPDATE STATISTICS dbo.INVOICE WITH FULLSCAN; UPDATE STATISTICS dbo.INVOICE_SERVICE_ITEM WITH FULLSCAN; UPDATE STATISTICS dbo.INVOICE_PRODUCT_ITEM WITH FULLSCAN; UPDATE STATISTICS dbo.MEMBER_MONTHLY_SPENDING WITH FULLSCAN;'
Log 'Statistics: UPDATE STATISTICS WITH FULLSCAN on INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM, MEMBER_MONTHLY_SPENDING (10 section 4.3 step 2).'

$sets = @(
    @{ Q = 'Q-UC05-B'; Label = 'P1'; P = @{ '@Member_ID' = 1; '@FromMonth' = '2025-01-01'; '@NextMonth' = '2026-01-01' } },
    @{ Q = 'Q-UC05-B'; Label = 'P2'; P = @{ '@Member_ID' = 30000; '@FromMonth' = '2025-01-01'; '@NextMonth' = '2026-01-01' } },
    @{ Q = 'Q-UC05-C'; Label = 'P1'; P = @{ '@FromMonth' = '2025-01-01'; '@NextMonth' = '2026-01-01' } },
    @{ Q = 'Q-UC05-C'; Label = 'P2'; P = @{ '@FromMonth' = '2025-02-01'; '@NextMonth' = '2026-02-01' } })
$sha = [System.Security.Cryptography.SHA256]::Create()
foreach ($s in $sets) {
    $file = Join-Path $repo "db/queries/baseline/$($s.Q).sql"
    $text = [System.IO.File]::ReadAllText($file)
    function MakeCmd { $c = $cn.CreateCommand(); $c.CommandText = $text; $c.CommandTimeout = 600
        foreach ($k in $s.P.Keys) { $v = $s.P[$k]; if ($k -eq '@Member_ID') { $c.Parameters.Add($k, [System.Data.SqlDbType]::Int).Value = $v } else { $c.Parameters.Add($k, [System.Data.SqlDbType]::Date).Value = [datetime]::Parse($v, $inv) } }
        return $c }
    $w = MakeCmd; $r = $w.ExecuteReader(); while ($r.Read()) { }; $r.Close()        # warm-up, discarded
    NonQuery 'SET STATISTICS IO ON; SET STATISTICS XML ON;'
    $msgs.Clear()
    $c = MakeCmd; $r = $c.ExecuteReader()
    $sb = New-Object System.Text.StringBuilder; $rows = 0
    while ($r.Read()) { $rows++; $vals = for ($i = 0; $i -lt $r.FieldCount; $i++) { if ($r.IsDBNull($i)) { 'NULL' } else { [Convert]::ToString($r.GetValue($i), $inv) } }; [void]$sb.Append(($vals -join '|')).Append("`n") }
    $plan = $null
    while ($r.NextResult()) { while ($r.Read()) { $v = "$($r.GetValue(0))"; if ($v -like '<ShowPlanXML*') { $plan = $v } } }
    $r.Close()
    NonQuery 'SET STATISTICS XML OFF; SET STATISTICS IO OFF;'
    $sorted = (($sb.ToString().TrimEnd("`n")).Split("`n") | Sort-Object) -join "`n"
    $hash = -join ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($sorted)) | ForEach-Object { $_.ToString('X2') })
    $planName = "$($s.Q)__B0__DS-L__$($s.Label)__$RunTs.sqlplan"
    if ($plan) { [System.IO.File]::WriteAllText((Join-Path $planDir $planName), $plan, (New-Object System.Text.UTF8Encoding($false))) }
    $ops = @(); if ($plan) { $ops = @([regex]::Matches($plan, 'PhysicalOp="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }) }
    $reads = @($msgs | Where-Object { $_ -like 'Table *' })
    $total = 0; foreach ($m in $reads) { if ($m -match 'logical reads (\d+)') { $total += [int]$Matches[1] } }
    Log ''
    Log ("== $($s.Q) $($s.Label): file SHA-256 " + (Get-FileHash -Algorithm SHA256 $file).Hash)
    Log ("   parameters: " + (($s.P.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ', '))
    Log ("   rows $rows; ordered-result SHA-256 $hash")
    Log ("   logical reads total $total; STATISTICS IO (raw):")
    foreach ($m in $reads) { Log "     $m" }
    Log ("   actual plan: execution-plans/$planName; physical operators: " + ($ops -join ' > '))
}
$cn.Close()
Log ''
Log 'T0-QUC05BC_RESULT: CAPTURED (B0 plans, logical reads, row counts; no timing)'
if ($OutFile) { $lines | Out-File -Encoding utf8 $OutFile }
exit 0
