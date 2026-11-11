<#
  capture_uc06_reference.ps1 - TEST_ONLY, WO-P3-P4-01 Part F (Windows PowerShell 5.1; System.Data.SqlClient).
  DIAGNOSTIC_ONLY reference capture of the UC06 report routines on DS-L (FitLife_P3_UC05L), allowed by the
  Owner Directive "Accept Loyalty & Implement UC06 Revenue Correctness" section 9:
    - query definitions (file SHA-256, definition SHA-256 per routine) and the parameter sets used;
    - existing index inventory and size of the P3 tables;
    - per call: result row count, SHA-256 of the ordered result, logical reads per table (raw STATISTICS IO
      text kept), the Actual Execution Plan of the statement that reads INVOICE (.sqlplan) and its operators.
  NOT recorded: CPU or elapsed time (R-27 OPEN). NOT a baseline: the formal B0 of the frozen queries Q-UC06-*
  is WO-P3-P2-02. No statistics update, no index, no setting change. Nothing here supports a performance claim.
  Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tests/db/revenue/capture_uc06_reference.ps1 -RunTs <yyyyMMdd-HHmm>
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
if ($Database -ne 'FitLife_P3_UC05L') { throw 'The UC06 reference capture runs only in FitLife_P3_UC05L.' }
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$planDir = if ($PlanDir) { $PlanDir } else { Join-Path $repo 'docs/phase2/person3/evidence/execution-plans' }
New-Item -ItemType Directory -Force -Path $planDir | Out-Null
$connStr = "Server=$Server;Database=$Database;Integrated Security=SSPI;Application Name=P3-UC06-reference;Pooling=false"
$lines = New-Object System.Collections.Generic.List[string]
function Log([string]$s) { $lines.Add($s); Write-Output $s }

$cn = New-Object System.Data.SqlClient.SqlConnection $connStr
$msgs = New-Object System.Collections.Generic.List[string]
$cn.add_InfoMessage({ param($sender, $e) foreach ($er in $e.Errors) { $msgs.Add($er.Message) } })
$cn.FireInfoMessageEventOnUserErrors = $false
$cn.Open()
function NonQuery([string]$sql) { $c = $cn.CreateCommand(); $c.CommandText = $sql; $c.CommandTimeout = 600; [void]$c.ExecuteNonQuery() }
function Rows([string]$sql) {
    $c = $cn.CreateCommand(); $c.CommandText = $sql; $c.CommandTimeout = 600; $r = $c.ExecuteReader(); $out = @()
    while ($r.Read()) { $vals = for ($i = 0; $i -lt $r.FieldCount; $i++) { if ($r.IsDBNull($i)) { 'NULL' } else { [Convert]::ToString($r.GetValue($i), $inv) } }; $out += ($vals -join '|') }
    $r.Close(); return $out
}

$g = @(Rows "SELECT (SELECT CONVERT(nvarchar(200), value) FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable'), (SELECT COUNT(*) FROM sys.indexes AS i JOIN sys.tables AS t ON t.object_id = i.object_id WHERE i.type > 0 AND i.is_primary_key = 0), ISNULL(OBJECT_ID(N'dbo.usp_P3_RptBranchRevenue'), 0), (SELECT COUNT(*) FROM dbo.INVOICE), (SELECT compatibility_level FROM sys.databases WHERE name = DB_NAME()), CONVERT(nvarchar(50), SERVERPROPERTY('ProductVersion')), CONVERT(nvarchar(60), SERVERPROPERTY('Edition'))")
$p = $g[0].Split('|')
if ($p[0] -notlike 'WO-P3-P2-01*WO-P3-P3-02*') { throw 'Refusing to run: FitLife_P3_UC05L without its marker.' }
if ($p[2] -eq '0') { throw 'The report routines are not deployed.' }

Log "UC06-REF - WO-P3-P4-01 Part F: DIAGNOSTIC_ONLY reference capture of the UC06 report routines on DS-L (FitLife_P3_UC05L). Run $RunTs."
Log ("Captured (UTC): " + (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss', $inv) + "; SQL Server $($p[5]) $($p[6]); compatibility level $($p[4]); invoices $($p[3]); non-PK indexes $($p[1])")
Log 'Status: REFERENCE material, NOT a baseline and NOT a benchmark. Timing: NOT recorded (R-27 OPEN). No UPDATE STATISTICS, no index, no setting change.'
Log 'The formal B0 baseline of the frozen queries Q-UC06-* belongs to WO-P3-P2-02; index decisions belong to WO-P3-P4-01 Part X.'
$file = Join-Path $repo 'db/procedures/usp_P3_RevenueReports.sql'
Log ("Query definitions: db/procedures/usp_P3_RevenueReports.sql SHA-256 " + (Get-FileHash -Algorithm SHA256 $file).Hash)
foreach ($l in (Rows "SELECT CONCAT(o.name, ' definition SHA-256 ', CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), OBJECT_DEFINITION(o.object_id))), 2)) FROM sys.objects AS o WHERE o.name LIKE N'usp[_]P3[_]Rpt%' OR o.name LIKE N'tvf[_]P3[_]Report%' ORDER BY o.name")) { Log "  $l" }
Log ''
Log '== Existing index inventory and size of the P3 tables (sys.indexes, sys.dm_db_partition_stats) =='
Log 'table|index|type|is_primary_key|is_unique|key_columns|included_columns|filter|rows|used_pages'
foreach ($l in (Rows @"
SELECT t.name, ISNULL(i.name, '(heap)'), i.type_desc, i.is_primary_key, i.is_unique,
       ISNULL((SELECT STRING_AGG(CONVERT(nvarchar(400), c.name), ',') WITHIN GROUP (ORDER BY ic.key_ordinal) FROM sys.index_columns AS ic JOIN sys.columns AS c ON c.object_id = ic.object_id AND c.column_id = ic.column_id WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0), '-'),
       ISNULL((SELECT STRING_AGG(CONVERT(nvarchar(400), c.name), ',') FROM sys.index_columns AS ic JOIN sys.columns AS c ON c.object_id = ic.object_id AND c.column_id = ic.column_id WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1), '-'),
       ISNULL(i.filter_definition, '-'),
       (SELECT SUM(ps.row_count) FROM sys.dm_db_partition_stats AS ps WHERE ps.object_id = i.object_id AND ps.index_id = i.index_id),
       (SELECT SUM(ps.used_page_count) FROM sys.dm_db_partition_stats AS ps WHERE ps.object_id = i.object_id AND ps.index_id = i.index_id)
FROM sys.indexes AS i JOIN sys.tables AS t ON t.object_id = i.object_id
WHERE t.name IN (N'INVOICE', N'INVOICE_SERVICE_ITEM', N'INVOICE_PRODUCT_ITEM', N'MEMBER_MONTHLY_SPENDING', N'BRANCH')
ORDER BY t.name, i.index_id
"@)) { Log $l }

$sets = @(
    @{ Id = 'RPT-01'; Label = 'P1'; Proc = 'usp_P3_RptBranchRevenue';         P = [ordered]@{ '@Branch_ID' = 1;  '@FromDate' = '2025-06-01'; '@ToDate' = '2025-07-01' } },
    @{ Id = 'RPT-01'; Label = 'P2'; Proc = 'usp_P3_RptBranchRevenue';         P = [ordered]@{ '@Branch_ID' = 12; '@FromDate' = '2025-01-01'; '@ToDate' = '2026-01-01' } },
    @{ Id = 'RPT-02T'; Label = 'P1'; Proc = 'usp_P3_RptSystemRevenue';        P = [ordered]@{ '@FromDate' = '2025-06-01'; '@ToDate' = '2025-07-01' } },
    @{ Id = 'RPT-02'; Label = 'P1'; Proc = 'usp_P3_RptSystemRevenueByBranch'; P = [ordered]@{ '@FromDate' = '2025-06-01'; '@ToDate' = '2025-07-01' } },
    @{ Id = 'RPT-02'; Label = 'P2'; Proc = 'usp_P3_RptSystemRevenueByBranch'; P = [ordered]@{ '@FromDate' = '2025-01-01'; '@ToDate' = '2026-01-01' } },
    @{ Id = 'RPT-03'; Label = 'P1'; Proc = 'usp_P3_RptBranchRevenueByPeriod'; P = [ordered]@{ '@Branch_ID' = 1;  '@FromDate' = '2025-06-01'; '@ToDate' = '2025-07-01'; '@Grain' = 'DAY' } },
    @{ Id = 'RPT-04B'; Label = 'P1'; Proc = 'usp_P3_RptBranchRevenueByPeriod'; P = [ordered]@{ '@Branch_ID' = 1; '@FromDate' = '2025-01-01'; '@ToDate' = '2026-01-01'; '@Grain' = 'MONTH' } },
    @{ Id = 'RPT-04S'; Label = 'P1'; Proc = 'usp_P3_RptSystemRevenueByPeriod'; P = [ordered]@{ '@FromDate' = '2025-01-01'; '@ToDate' = '2026-01-01'; '@Grain' = 'QUARTER' } })
$sha = [System.Security.Cryptography.SHA256]::Create()
$captured = 0
foreach ($s in $sets) {
    function MakeCmd {
        $c = $cn.CreateCommand(); $c.CommandTimeout = 600
        $c.CommandText = "EXEC dbo.$($s.Proc) " + ((@($s.P.Keys) | ForEach-Object { "$_ = $_" }) -join ', ')
        foreach ($k in $s.P.Keys) {
            $v = $s.P[$k]
            if ($k -eq '@Branch_ID') { $c.Parameters.Add($k, [System.Data.SqlDbType]::Int).Value = $v }
            elseif ($k -eq '@Grain') { $prm = $c.Parameters.Add($k, [System.Data.SqlDbType]::VarChar, 7); $prm.Value = $v }
            else { $c.Parameters.Add($k, [System.Data.SqlDbType]::Date).Value = [datetime]::Parse($v, $inv) }
        }
        return $c
    }
    $w = MakeCmd; $r = $w.ExecuteReader(); do { while ($r.Read()) { } } while ($r.NextResult()); $r.Close()        # first execution, discarded
    NonQuery 'SET STATISTICS IO ON; SET STATISTICS XML ON;'
    $msgs.Clear()
    $c = MakeCmd; $r = $c.ExecuteReader()
    $sb = New-Object System.Text.StringBuilder; $rows = 0; $plans = @()
    do {
        $isPlan = ($r.FieldCount -eq 1 -and $r.GetName(0) -like '*Showplan*')
        while ($r.Read()) {
            if ($isPlan) { $plans += "$($r.GetValue(0))" }
            else { $rows++; $vals = for ($i = 0; $i -lt $r.FieldCount; $i++) { if ($r.IsDBNull($i)) { 'NULL' } else { [Convert]::ToString($r.GetValue($i), $inv) } }; [void]$sb.Append(($vals -join '|')).Append("`n") }
        }
    } while ($r.NextResult())
    $r.Close()
    NonQuery 'SET STATISTICS XML OFF; SET STATISTICS IO OFF;'
    $sorted = (($sb.ToString().TrimEnd("`n")).Split("`n") | Sort-Object) -join "`n"
    $hash = -join ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($sorted)) | ForEach-Object { $_.ToString('X2') })
    $plan = @($plans | Where-Object { $_ -match 'Table="\[INVOICE\]"' }) | Select-Object -First 1
    $planName = "UC06-REF__$($s.Id)__DS-L__$($s.Label)__$RunTs.sqlplan"
    if ($plan) { [System.IO.File]::WriteAllText((Join-Path $planDir $planName), $plan, (New-Object System.Text.UTF8Encoding($false))); $captured++ }
    $ops = @(); if ($plan) { $ops = @([regex]::Matches($plan, 'PhysicalOp="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }) }
    $reads = @($msgs | Where-Object { $_ -like 'Table *' })
    $invReads = 0; foreach ($m in $reads) { if ($m -match "^Table 'INVOICE'.*?logical reads (\d+)") { $invReads += [int]$Matches[1] } }
    Log ''
    Log "== $($s.Id) $($s.Label): dbo.$($s.Proc)"
    Log ("   parameters: " + ((@($s.P.Keys) | ForEach-Object { "$_=$($s.P[$_])" }) -join ', '))
    Log ("   result rows $rows; ordered-result SHA-256 $hash")
    Log ("   logical reads on INVOICE $invReads; STATISTICS IO (raw, all statements of the routine):")
    foreach ($m in $reads) { Log "     $m" }
    Log ("   actual plan of the INVOICE statement: " + $(if ($plan) { "execution-plans/$planName" } else { 'NOT CAPTURED' }) + "; physical operators: " + ($ops -join ' > '))
}
$cn.Close()
Log ''
Log "UC06-REF_RESULT: CAPTURED ($captured of $($sets.Count) plans; logical reads, row counts, index inventory; no timing; DIAGNOSTIC_ONLY)"
if ($OutFile) { $lines | Out-File -Encoding utf8 $OutFile }
if ($captured -eq $sets.Count) { exit 0 } else { exit 1 }
