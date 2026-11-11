<#
  run_uc05_settlement.ps1 - TEST_ONLY runner for WO-P3-P3-01 (Windows PowerShell 5.1; nothing installed)

  Builds the isolated database FitLife_P3_UC05 from nothing and runs the WO-P3-P3-01 test set:
     1 instance fingerprint (before)                 12 apply db/procedures/usp_P3_CancelInvoice
     2 FitLife_P3_P2 dataset checksum (before)       13 T-SCH-04 (catalog vs P1, inventory, write scope)
     3 rebuild FitLife_P3_UC05 (F001, V001, V002)    14 T-F05S settlement functional tests (own evidence file)
     4 T-SCH-01 (P1 constraint regression)           15 V-UC05S settlement integrity
     5 T-SCH-02 (P1 conformance regression)          16 T-CONC-06 run R (creation regression after settlement deploy) + V-UC05S
     6 apply db/procedures/usp_P3_CreateInvoice      17 T-CONC-01 runs A, B, C (same invoice) + V-UC05S after each
     7 T-SCH-03 (creation scope, before settlement)  18 T-CONC-02 runs A, B, C (same member) + V-UC05S after each
     8 F001U TEST_ONLY key rows                      19 T-SCH-04 again (no leftover object, principal or permission)
     9 F002P TEST_ONLY MEMBER.CurrentPoints           20 instance fingerprint (after) = before
    10 D001 TEST_ONLY hook doubles                   21 FitLife_P3_P2 dataset checksum (after) = before = DS-L run C
    11 apply db/procedures/usp_P3_SettleInvoice
  Changes only FitLife_P3_UC05. FitLife_P3_P1 and FitLife_P3_P2 are read only (catalog, checksum).
  No timing in this run is a performance measurement (R-27). Machine and SQL Server host names are masked.

  Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tests/db/functional/run_uc05_settlement.ps1
  Exit code 0 = every step PASS.
#>
param(
    [string]$Server = 'localhost',
    [string]$EvidenceDir = 'docs/phase2/person3/evidence/test-results'
)
$ErrorActionPreference = 'Continue'
$inv = [Globalization.CultureInfo]::InvariantCulture
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
Set-Location $repo
if (-not [System.IO.Path]::IsPathRooted($EvidenceDir)) { $EvidenceDir = Join-Path $repo $EvidenceDir }
New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
$ts = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmm', $inv)
$logPath = Join-Path $EvidenceDir "UC05S-RUN__$ts.txt"
$f05Path = Join-Path $EvidenceDir "T-F05S-SETTLE__$ts.txt"
foreach ($p in @($logPath, $f05Path)) { if (Test-Path $p) { throw "refusing to overwrite $p" } }
$refChecksum = Join-Path $EvidenceDir 'CHECKSUMS__DS-L__20261108-1155_C.txt'

$mask = New-Object System.Collections.Generic.List[string]
if ($env:COMPUTERNAME) { $mask.Add($env:COMPUTERNAME) }
$names = & sqlcmd -S $Server -E -I -b -h -1 -W -Q "SET NOCOUNT ON; SELECT CONVERT(nvarchar(128), SERVERPROPERTY('MachineName')); SELECT CONVERT(nvarchar(128), SERVERPROPERTY('ServerName')); SELECT @@SERVERNAME;" 2>$null
foreach ($n in $names) { $t = "$n".Trim(); if ($t.Length -gt 2) { $mask.Add($t); if ($t.Contains('\')) { $mask.Add($t.Split('\')[0]) } } }
function Hide([string]$s) {
    foreach ($m in ($mask | Sort-Object Length -Descending -Unique)) { $s = [regex]::Replace($s, [regex]::Escape($m), '<local-server>', 'IgnoreCase') }
    return $s
}
$log = New-Object System.Collections.Generic.List[string]
function Log([string]$s) { $h = Hide $s; $log.Add($h); Write-Output $h }
function Utc { (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss', $inv) }
$results = New-Object System.Collections.Generic.List[object]
function Step([string]$id, [string]$descr, [bool]$ok, [string]$note) {
    $results.Add([pscustomobject]@{ Id = $id; Result = $(if ($ok) { 'PASS' } else { 'FAIL' }); Descr = $descr; Note = $note })
    Log ("STEP {0} {1}: {2}{3}" -f $id, $(if ($ok) { 'PASS' } else { 'FAIL' }), $descr, $(if ($note) { " - $note" } else { '' }))
}
function Sql([string[]]$sqlArgs) {
    $out = & sqlcmd -S $Server -E -I -b -W -s '|' @sqlArgs 2>&1
    return [pscustomobject]@{ Exit = $LASTEXITCODE; Lines = @($out | ForEach-Object { "$_" }) }
}
function Section([string]$title, $res) { Log ''; Log "== $title (sqlcmd exit $($res.Exit)) =="; foreach ($l in $res.Lines) { Log $l } }
function Has($res, [string]$pattern) { return (($res.Exit -eq 0) -and (($res.Lines -join "`n") -match $pattern)) }
function Summary($res, [string]$prefix) { return (($res.Lines | Where-Object { $_ -like "$prefix*" }) -join '') }
function Integrity([string]$id, [string]$after) {
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', 'tests/db/functional/V-UC05S_settlement_integrity.sql'); Section "$id. V-UC05S integrity after $after" $r
    Step "$id-V" "V-UC05S after $after" (Has $r 'V-UC05S_RESULT: PASS') (Summary $r 'V-UC05S SUMMARY')
}
function Conc([string]$id, [string]$script, [string[]]$scriptArgs, [string]$evName, [string]$descr, [string]$pattern) {
    $cPath = Join-Path $EvidenceDir $evName
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo $script) @scriptArgs -OutFile $cPath 2>&1
    $cx = $LASTEXITCODE
    if (Test-Path $cPath) { $c = Get-Content $cPath; ($c | ForEach-Object { Hide $_ }) | Out-File -Encoding utf8 $cPath }
    Log ''; Log "== $id. $descr (exit $cx): full output in $evName =="
    foreach ($l in $out) { if ("$l" -match $pattern) { Log "$l" } }
    Step $id $descr ($cx -eq 0) ''
}

# ---- 0. header ----
$scripts = @('tests/db/build/fingerprint_instance.sql', 'tests/db/seed/T-REPRO-02_checksums.sql', 'tests/db/build/rebuild_uc05_db.sql',
             'tests/db/fixtures/F001__TEST_ONLY_shared_dependency_keys.sql', 'db/migrations/V001__p3_billing_and_spending_tables.sql',
             'db/migrations/V002__p3_settlement_and_spending_constraints.sql', 'tests/db/schema/T-SCH-01_constraints.sql',
             'tests/db/schema/T-SCH-02_conformance.sql', 'db/procedures/usp_P3_CreateInvoice.sql', 'tests/db/schema/T-SCH-03_uc05_catalog_and_scope.sql',
             'tests/db/fixtures/F001U__TEST_ONLY_uc05_key_rows.sql', 'tests/db/fixtures/F002P__TEST_ONLY_member_current_points.sql',
             'tests/db/doubles/D001__TEST_ONLY_settlement_hook_doubles.sql', 'db/procedures/usp_P3_SettleInvoice.sql', 'db/procedures/usp_P3_CancelInvoice.sql',
             'tests/db/schema/T-SCH-04_settlement_catalog_and_scope.sql', 'tests/db/functional/T-F05S_settlement.sql',
             'tests/db/functional/V-UC05S_settlement_integrity.sql', 'tests/db/concurrency/T-CONC-06_parallel_creation.ps1',
             'tests/db/concurrency/T-CONC-01_02_parallel_settlement.ps1', 'tests/db/functional/run_uc05_settlement.ps1')
Log "UC05S-RUN - WO-P3-P3-01 settlement: build, regression, functional, concurrency and integrity tests"
Log ("Started (UTC): " + (Utc) + "; target database FitLife_P3_UC05 (isolated, disposable); read-only references FitLife_P3_P1, FitLife_P3_P2")
$branch = (& git -C $repo rev-parse --abbrev-ref HEAD 2>$null); $head = (& git -C $repo rev-parse --short HEAD 2>$null)
Log "Repository: branch $branch, HEAD $head (P3 work untracked; nothing committed)"
Log 'Scripts (SHA-256):'
foreach ($s in $scripts) { Log ("  {0}  {1}" -f (Get-FileHash -Algorithm SHA256 (Join-Path $repo $s)).Hash, $s) }
$id = Sql @('-Q', "SET NOCOUNT ON; SELECT CONVERT(nvarchar(128), SERVERPROPERTY('ProductVersion')) AS version, CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) AS edition, CONVERT(int, SERVERPROPERTY('EngineEdition')) AS engine_edition, ISNULL(CONVERT(nvarchar(128), SERVERPROPERTY('InstanceName')), N'(default)') AS instance, CONVERT(varchar(40), SYSUTCDATETIME(), 121) AS utc_now, CONVERT(varchar(40), SYSDATETIMEOFFSET(), 121) AS local_now_with_offset;")
Section 'Instance and clock (PaidAt is stored in UTC; the server clock offset is shown for reference)' $id
$bat = Get-CimInstance Win32_Battery
Log ("Power (context only): BatteryStatus {0} (1 = on battery, 2 = on AC), charge {1}%. Correctness tests do not depend on it." -f $bat.BatteryStatus, $bat.EstimatedChargeRemaining)

# ---- 1-2. before ----
$fpBefore = Sql @('-v', 'TargetDb=FitLife_P3_UC05', '-i', 'tests/db/build/fingerprint_instance.sql')
Section '1. Instance fingerprint before (all databases except tempdb and FitLife_P3_UC05)' $fpBefore
Step '1' 'Instance fingerprint captured before' ($fpBefore.Exit -eq 0) ''
$refLine = (Get-Content $refChecksum | Where-Object { $_ -like 'DATASET_CHECKSUM*' } | Select-Object -First 1).Trim()
$ckBefore = Sql @('-d', 'FitLife_P3_P2', '-v', 'MaxGrantPercent=2', '-i', 'tests/db/seed/T-REPRO-02_checksums.sql')
Section '2. FitLife_P3_P2 dataset checksum before (read-only)' $ckBefore
$ckB = (($ckBefore.Lines | Where-Object { $_ -like 'DATASET_CHECKSUM*' } | Select-Object -First 1) + '').Trim()
Step '2' 'FitLife_P3_P2 checksum before = DS-L run C reference' (($ckBefore.Exit -eq 0) -and ($ckB -eq $refLine)) "$ckB"

# ---- 3-13. build, regression, deploy, scope ----
$stop = $false
$r = Sql @('-i', 'tests/db/build/rebuild_uc05_db.sql'); Section '3. Rebuild FitLife_P3_UC05' $r
Step '3' 'Fresh isolated database built (F001 TEST_ONLY key-only fixtures, V001, V002)' (Has $r 'BUILD_RESULT: OK') ''
if ($r.Exit -ne 0) { $stop = $true }
$deploy = @(
    @('4', 'tests/db/schema/T-SCH-01_constraints.sql', 'T-SCH-01 constraint tests (P1 regression)', 'T-SCH-01_RESULT: PASS', 'T-SCH-01 SUMMARY'),
    @('5', 'tests/db/schema/T-SCH-02_conformance.sql', 'T-SCH-02 conformance (P1 regression)', 'T-SCH-02_RESULT: PASS', 'T-SCH-02 SUMMARY'),
    @('6', 'db/procedures/usp_P3_CreateInvoice.sql', 'Apply the invoice-creation routine (unchanged, WO-P3-P3-00)', 'usp_P3_CreateInvoice applied', ''),
    @('7', 'tests/db/schema/T-SCH-03_uc05_catalog_and_scope.sql', 'T-SCH-03 creation scope and catalog (before settlement objects)', 'T-SCH-03_RESULT: PASS', 'T-SCH-03 SUMMARY'),
    @('8', 'tests/db/fixtures/F001U__TEST_ONLY_uc05_key_rows.sql', 'F001U TEST_ONLY key rows', 'F001U \(TEST_ONLY\) applied', ''),
    @('9', 'tests/db/fixtures/F002P__TEST_ONLY_member_current_points.sql', 'F002P TEST_ONLY MEMBER.CurrentPoints (points only, no tier)', 'F002P \(TEST_ONLY\) applied', ''),
    @('10', 'tests/db/doubles/D001__TEST_ONLY_settlement_hook_doubles.sql', 'D001 TEST_ONLY contract-only hook doubles', 'D001 \(TEST_ONLY\) applied', ''),
    @('11', 'db/procedures/usp_P3_SettleInvoice.sql', 'Apply the settlement routine and month function', 'usp_P3_SettleInvoice applied', ''),
    @('12', 'db/procedures/usp_P3_CancelInvoice.sql', 'Apply the cancellation routine', 'usp_P3_CancelInvoice applied', ''),
    @('13', 'tests/db/schema/T-SCH-04_settlement_catalog_and_scope.sql', 'T-SCH-04 catalog vs P1, inventory, settlement and cancellation write scope', 'T-SCH-04_RESULT: PASS', 'T-SCH-04 SUMMARY'))
foreach ($d in $deploy) {
    if ($stop) { break }
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', $d[1]); Section "$($d[0]). $($d[2])" $r
    $ok = Has $r $d[3]
    Step $d[0] $d[2] $ok $(if ($d[4]) { Summary $r $d[4] } else { '' })
    if (-not $ok -and [int]$d[0] -ge 6) { $stop = $true }
}

# ---- 14-19. tests ----
if (-not $stop) {
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', 'tests/db/functional/T-F05S_settlement.sql')
    $hdr = @("T-F05S - settlement and cancellation functional tests (WO-P3-P3-01). Run UC05S-RUN__$ts.", "Executed (UTC): $(Utc); database FitLife_P3_UC05; script tests/db/functional/T-F05S_settlement.sql (SHA-256 $((Get-FileHash -Algorithm SHA256 (Join-Path $repo 'tests/db/functional/T-F05S_settlement.sql')).Hash)); sqlcmd exit $($r.Exit)", '')
    (($hdr + $r.Lines) | ForEach-Object { Hide $_ }) | Out-File -Encoding utf8 $f05Path
    Log ''; Log "== 14. T-F05S functional tests: full output in $(Split-Path -Leaf $f05Path) =="
    foreach ($l in ($r.Lines | Where-Object { $_ -match '^(T-F05S SUMMARY|T-F05S_RESULT|[A-G]\d\d\|T-F05-)' })) { Log ($l.Substring(0, [Math]::Min(220, $l.Length))) }
    Step '14' 'T-F05S settlement functional tests' (Has $r 'T-F05S_RESULT: PASS') (Summary $r 'T-F05S SUMMARY')
    Integrity '15' 'T-F05S'

    Conc '16' 'tests/db/concurrency/T-CONC-06_parallel_creation.ps1' @('-RunLabel', 'R') "T-CONC-06__${ts}_R.txt" 'T-CONC-06 run R (creation regression with settlement objects deployed; 10 x 20 parallel creations)' '^(  C\d|T-CONC-06 SUMMARY|T-CONC-06_RESULT)'
    Integrity '16' 'T-CONC-06 run R'
    foreach ($label in @('A', 'B', 'C')) {
        Conc "17$label" 'tests/db/concurrency/T-CONC-01_02_parallel_settlement.ps1' @('-Mode', 'SameInvoice', '-RunLabel', $label) "T-CONC-01__${ts}_$label.txt" "T-CONC-01 run $label (10 sessions settle the same invoice, 20 invoices, settle-vs-cancel race on every 5th)" '^(  C\d|T-CONC-01 SUMMARY|T-CONC-01_RESULT)'
        Integrity "17$label" "T-CONC-01 run $label"
    }
    foreach ($label in @('A', 'B', 'C')) {
        Conc "18$label" 'tests/db/concurrency/T-CONC-01_02_parallel_settlement.ps1' @('-Mode', 'SameMember', '-RunLabel', $label) "T-CONC-02__${ts}_$label.txt" "T-CONC-02 run $label (10 sessions x 20 rounds, different invoices of the same two fresh members)" '^(  C\d|T-CONC-02 SUMMARY|T-CONC-02_RESULT)'
        Integrity "18$label" "T-CONC-02 run $label"
    }
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', 'tests/db/schema/T-SCH-04_settlement_catalog_and_scope.sql'); Section '19. T-SCH-04 again after all tests' $r
    Step '19' 'T-SCH-04 after all tests (no leftover object, principal or permission; catalog unchanged)' (Has $r 'T-SCH-04_RESULT: PASS') (Summary $r 'T-SCH-04 SUMMARY')
}

# ---- 20-21. after ----
$fpAfter = Sql @('-v', 'TargetDb=FitLife_P3_UC05', '-i', 'tests/db/build/fingerprint_instance.sql')
Section '20. Instance fingerprint after' $fpAfter
Step '20' 'Instance fingerprint after = before (no other database changed)' (($fpAfter.Exit -eq 0) -and ((($fpAfter.Lines) -join "`n") -eq (($fpBefore.Lines) -join "`n"))) ''
$ckAfter = Sql @('-d', 'FitLife_P3_P2', '-v', 'MaxGrantPercent=2', '-i', 'tests/db/seed/T-REPRO-02_checksums.sql')
Section '21. FitLife_P3_P2 dataset checksum after (read-only)' $ckAfter
$ckA = (($ckAfter.Lines | Where-Object { $_ -like 'DATASET_CHECKSUM*' } | Select-Object -First 1) + '').Trim()
Step '21' 'FitLife_P3_P2 checksum after = before = DS-L run C reference' (($ckAfter.Exit -eq 0) -and ($ckA -eq $refLine) -and ($ckA -eq $ckB)) "$ckA"

# ---- summary ----
$counts = Sql @('-d', 'FitLife_P3_UC05', '-Q', "SET NOCOUNT ON; SELECT (SELECT COUNT(*) FROM dbo.INVOICE) AS invoices, (SELECT COUNT(*) FROM dbo.INVOICE WHERE PaymentStatus = 'PENDING') AS pending, (SELECT COUNT(*) FROM dbo.INVOICE WHERE PaymentStatus = 'PAID') AS paid, (SELECT COUNT(*) FROM dbo.INVOICE WHERE PaymentStatus = 'CANCELLED') AS cancelled, (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING) AS spending_rows, (SELECT SUM(CurrentPoints) FROM dbo.MEMBER) AS total_points, (SELECT COUNT(*) FROM dbo.TEST_HookCallLog) AS hook_calls;")
Section 'Final content of FitLife_P3_UC05 (disposable; kept for inspection)' $counts
$nf = @($results | Where-Object { $_.Result -eq 'FAIL' }).Count
Log ''
Log 'Summary:'
foreach ($x in $results) { Log ("  {0,-6} {1}  {2}" -f $x.Id, $x.Result, $x.Descr) }
Log ("UC05S-RUN SUMMARY: steps $($results.Count); FAIL $nf; finished (UTC) $(Utc)")
Log ("UC05S-RUN_RESULT: " + $(if ($nf -eq 0 -and -not $stop) { 'PASS' } else { 'FAIL' }))
$log | Out-File -Encoding utf8 $logPath
if ($nf -eq 0 -and -not $stop) { exit 0 } else { exit 1 }
