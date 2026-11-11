<#
  run_uc05_invoice_creation.ps1 - TEST_ONLY runner for WO-P3-P3-00 (Windows PowerShell 5.1; nothing installed)

  Builds the isolated database FitLife_P3_UC05 from nothing and runs the full WO-P3-P3-00 test set:
     1 instance fingerprint (before)            9 T-F05 functional tests (own evidence file)
     2 FitLife_P3_P2 dataset checksum (before)  10 V-UC05 integrity
     3 rebuild FitLife_P3_UC05 (F001,V001,V002) 11 T-CONC-06 runs A, B, C (own evidence files), V-UC05 after each
     4 T-SCH-01 (P1 constraint regression)      12 T-SCH-03 again (catalog and inventory unchanged by the tests)
     5 T-SCH-02 (P1 conformance regression)     13 instance fingerprint (after) = before
     6 apply db/procedures/usp_P3_CreateInvoice  14 FitLife_P3_P2 dataset checksum (after) = before = DS-L run C
     7 T-SCH-03 (catalog vs P1, scope, AC4)
     8 F001U TEST_ONLY key rows
  Changes only FitLife_P3_UC05. FitLife_P3_P1 and FitLife_P3_P2 are read only (catalog, checksum).
  No timing in this run is a performance measurement (R-27). The machine name and the SQL Server host
  name are masked as <local-server> in every file written.

  Usage (from any directory):
    powershell -NoProfile -ExecutionPolicy Bypass -File tests/db/functional/run_uc05_invoice_creation.ps1
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
$logPath = Join-Path $EvidenceDir "UC05-RUN__$ts.txt"
$f05Path = Join-Path $EvidenceDir "T-F05-CREATE__$ts.txt"
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

# ---- 0. header ----
$scripts = @('tests/db/build/fingerprint_instance.sql', 'tests/db/seed/T-REPRO-02_checksums.sql', 'tests/db/build/rebuild_uc05_db.sql',
             'tests/db/fixtures/F001__TEST_ONLY_shared_dependency_keys.sql', 'db/migrations/V001__p3_billing_and_spending_tables.sql',
             'db/migrations/V002__p3_settlement_and_spending_constraints.sql', 'tests/db/schema/T-SCH-01_constraints.sql',
             'tests/db/schema/T-SCH-02_conformance.sql', 'db/procedures/usp_P3_CreateInvoice.sql', 'tests/db/schema/T-SCH-03_uc05_catalog_and_scope.sql',
             'tests/db/fixtures/F001U__TEST_ONLY_uc05_key_rows.sql', 'tests/db/functional/T-F05_invoice_creation.sql',
             'tests/db/functional/V-UC05_integrity.sql', 'tests/db/concurrency/T-CONC-06_parallel_creation.ps1', 'tests/db/functional/run_uc05_invoice_creation.ps1')
Log "UC05-RUN - WO-P3-P3-00 invoice creation: build, regression, functional, concurrency and integrity tests"
Log ("Started (UTC): " + (Utc) + "; target database FitLife_P3_UC05 (isolated, disposable); read-only references FitLife_P3_P1, FitLife_P3_P2")
$branch = (& git -C $repo rev-parse --abbrev-ref HEAD 2>$null); $head = (& git -C $repo rev-parse --short HEAD 2>$null)
Log "Repository: branch $branch, HEAD $head (P3 work untracked; nothing committed)"
Log 'Scripts (SHA-256):'
foreach ($s in $scripts) { Log ("  {0}  {1}" -f (Get-FileHash -Algorithm SHA256 (Join-Path $repo $s)).Hash, $s) }
$id = Sql @('-Q', "SET NOCOUNT ON; SELECT CONVERT(nvarchar(128), SERVERPROPERTY('ProductVersion')) AS version, CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) AS edition, CONVERT(int, SERVERPROPERTY('EngineEdition')) AS engine_edition, ISNULL(CONVERT(nvarchar(128), SERVERPROPERTY('InstanceName')), N'(default)') AS instance;")
Section 'Instance' $id
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

# ---- 3-8. build, regression, deploy, scope, fixtures ----
$stop = $false
$r = Sql @('-i', 'tests/db/build/rebuild_uc05_db.sql'); Section '3. Rebuild FitLife_P3_UC05' $r
Step '3' 'Fresh isolated database built (F001 TEST_ONLY key-only fixtures, V001, V002)' (($r.Exit -eq 0) -and (($r.Lines -join "`n") -match 'BUILD_RESULT: OK')) ''
if ($r.Exit -ne 0) { $stop = $true }
if (-not $stop) {
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', 'tests/db/schema/T-SCH-01_constraints.sql'); Section '4. T-SCH-01 constraint tests (P1 regression)' $r
    Step '4' 'T-SCH-01 on the fresh build' (($r.Exit -eq 0) -and (($r.Lines -join "`n") -match 'T-SCH-01_RESULT: PASS')) (($r.Lines | Where-Object { $_ -like 'T-SCH-01 SUMMARY*' }) -join '')
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', 'tests/db/schema/T-SCH-02_conformance.sql'); Section '5. T-SCH-02 conformance (P1 regression, before the routine)' $r
    Step '5' 'T-SCH-02 on the fresh build' (($r.Exit -eq 0) -and (($r.Lines -join "`n") -match 'T-SCH-02_RESULT: PASS')) (($r.Lines | Where-Object { $_ -like 'T-SCH-02 SUMMARY*' }) -join '')
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', 'db/procedures/usp_P3_CreateInvoice.sql'); Section '6. Apply db/procedures/usp_P3_CreateInvoice.sql' $r
    Step '6' 'Routine and line types applied' (($r.Exit -eq 0) -and (($r.Lines -join "`n") -match 'usp_P3_CreateInvoice applied')) ''
    if ($r.Exit -ne 0) { $stop = $true }
}
if (-not $stop) {
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', 'tests/db/schema/T-SCH-03_uc05_catalog_and_scope.sql'); Section '7. T-SCH-03 catalog vs FitLife_P3_P1, inventory, write scope' $r
    Step '7' 'T-SCH-03 after deployment' (($r.Exit -eq 0) -and (($r.Lines -join "`n") -match 'T-SCH-03_RESULT: PASS')) (($r.Lines | Where-Object { $_ -like 'T-SCH-03 SUMMARY*' }) -join '')
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', 'tests/db/fixtures/F001U__TEST_ONLY_uc05_key_rows.sql'); Section '8. F001U TEST_ONLY key rows' $r
    Step '8' 'TEST_ONLY key rows loaded' (($r.Exit -eq 0) -and (($r.Lines -join "`n") -match 'F001U \(TEST_ONLY\) applied')) ''
    if ($r.Exit -ne 0) { $stop = $true }
}

# ---- 9-12. tests ----
if (-not $stop) {
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', 'tests/db/functional/T-F05_invoice_creation.sql')
    $hdr = @("T-F05 - invoice creation functional tests (WO-P3-P3-00). Run UC05-RUN__$ts.", "Executed (UTC): $(Utc); database FitLife_P3_UC05; script tests/db/functional/T-F05_invoice_creation.sql (SHA-256 $((Get-FileHash -Algorithm SHA256 (Join-Path $repo 'tests/db/functional/T-F05_invoice_creation.sql')).Hash)); sqlcmd exit $($r.Exit)", '')
    (($hdr + $r.Lines) | ForEach-Object { Hide $_ }) | Out-File -Encoding utf8 $f05Path
    Log ''; Log "== 9. T-F05 functional tests: full output in $(Split-Path -Leaf $f05Path) =="
    foreach ($l in ($r.Lines | Where-Object { $_ -match '^(T-F05 SUMMARY|T-F05_RESULT|T-F05-\d\d\|)' })) { Log $l }
    Step '9' 'T-F05 functional tests' (($r.Exit -eq 0) -and (($r.Lines -join "`n") -match 'T-F05_RESULT: PASS')) (($r.Lines | Where-Object { $_ -like 'T-F05 SUMMARY*' }) -join '')
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', 'tests/db/functional/V-UC05_integrity.sql'); Section '10. V-UC05 integrity after T-F05' $r
    Step '10' 'V-UC05 after T-F05' (($r.Exit -eq 0) -and (($r.Lines -join "`n") -match 'V-UC05_RESULT: PASS')) ''

    $n = 11
    foreach ($label in @('A', 'B', 'C')) {
        $cPath = Join-Path $EvidenceDir "T-CONC-06__${ts}_$label.txt"
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'tests/db/concurrency/T-CONC-06_parallel_creation.ps1') -RunLabel $label -OutFile $cPath 2>&1
        $cx = $LASTEXITCODE
        if (Test-Path $cPath) { $c = Get-Content $cPath; ($c | ForEach-Object { Hide $_ }) | Out-File -Encoding utf8 $cPath }
        Log ''; Log "== $n$label. T-CONC-06 run $label (exit $cx): full output in $(Split-Path -Leaf $cPath) =="
        foreach ($l in $out) { if ("$l" -match '^(  C\d|T-CONC-06 SUMMARY|T-CONC-06_RESULT|Gate released)') { Log "$l" } }
        Step "$n$label" "T-CONC-06 run $label (10 sessions x 20 parallel creations)" ($cx -eq 0) ''
        $r = Sql @('-d', 'FitLife_P3_UC05', '-i', 'tests/db/functional/V-UC05_integrity.sql'); Section "$n$label. V-UC05 integrity after T-CONC-06 run $label" $r
        Step "$n$label-V" "V-UC05 after T-CONC-06 run $label" (($r.Exit -eq 0) -and (($r.Lines -join "`n") -match 'V-UC05_RESULT: PASS')) ''
    }
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', 'tests/db/schema/T-SCH-03_uc05_catalog_and_scope.sql'); Section '12. T-SCH-03 again after all tests' $r
    Step '12' 'T-SCH-03 after all tests (no leftover object, principal or permission; catalog still = P1)' (($r.Exit -eq 0) -and (($r.Lines -join "`n") -match 'T-SCH-03_RESULT: PASS')) ''
}

# ---- 13-14. after ----
$fpAfter = Sql @('-v', 'TargetDb=FitLife_P3_UC05', '-i', 'tests/db/build/fingerprint_instance.sql')
Section '13. Instance fingerprint after' $fpAfter
Step '13' 'Instance fingerprint after = before (no other database changed)' (($fpAfter.Exit -eq 0) -and ((($fpAfter.Lines) -join "`n") -eq (($fpBefore.Lines) -join "`n"))) ''
$ckAfter = Sql @('-d', 'FitLife_P3_P2', '-v', 'MaxGrantPercent=2', '-i', 'tests/db/seed/T-REPRO-02_checksums.sql')
Section '14. FitLife_P3_P2 dataset checksum after (read-only)' $ckAfter
$ckA = (($ckAfter.Lines | Where-Object { $_ -like 'DATASET_CHECKSUM*' } | Select-Object -First 1) + '').Trim()
Step '14' 'FitLife_P3_P2 checksum after = before = DS-L run C reference' (($ckAfter.Exit -eq 0) -and ($ckA -eq $refLine) -and ($ckA -eq $ckB)) "$ckA"

# ---- summary ----
$counts = Sql @('-d', 'FitLife_P3_UC05', '-Q', 'SET NOCOUNT ON; SELECT (SELECT COUNT(*) FROM dbo.INVOICE) AS invoices, (SELECT COUNT(*) FROM dbo.INVOICE_SERVICE_ITEM) AS service_lines, (SELECT COUNT(*) FROM dbo.INVOICE_PRODUCT_ITEM) AS product_lines, (SELECT COUNT(*) FROM dbo.MEMBER_MONTHLY_SPENDING) AS spending_rows;')
Section 'Final content of FitLife_P3_UC05 (disposable; kept for inspection)' $counts
$nf = @($results | Where-Object { $_.Result -eq 'FAIL' }).Count
Log ''
Log 'Summary:'
foreach ($x in $results) { Log ("  {0,-6} {1}  {2}" -f $x.Id, $x.Result, $x.Descr) }
Log ("UC05-RUN SUMMARY: steps $($results.Count); FAIL $nf; finished (UTC) $(Utc)")
Log ("UC05-RUN_RESULT: " + $(if ($nf -eq 0 -and -not $stop) { 'PASS' } else { 'FAIL' }))
$log | Out-File -Encoding utf8 $logPath
if ($nf -eq 0 -and -not $stop) { exit 0 } else { exit 1 }
