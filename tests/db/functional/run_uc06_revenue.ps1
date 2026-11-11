<#
  run_uc06_revenue.ps1 - TEST_ONLY runner for WO-P3-P4-01 Part F (Windows PowerShell 5.1; nothing installed).
  UC06 revenue report routines: build, functional tests, reconciliation against independent references,
  UC05 regression with the report routines deployed, DS-L scale check, DIAGNOSTIC_ONLY reference capture.

  1 fingerprint before   2 FitLife_P3_P2 checksum before
  Stage A - FitLife_P3_UC05 rebuilt: invoice-creation regression with the report routines deployed
     A1 rebuild   A2-A3 T-SCH-01/02   A4 creation routine   A5 T-SCH-03 (exact inventory, before the report
     routines)   A6 F001U   A7 catalog digest   A8 report routines   A9 T-SCH-06   A10 T-F05 (creation tests)
     A11 catalog digest again = A7
  Stage B - FitLife_P3_UC05 rebuilt: revenue fixtures
     B1 rebuild   B2-B7 creation routine, F001U, F002P, D001 doubles, settle, cancel (all unchanged)
     B8 R001 TEST_ONLY revenue fixture (16 invoices)   B9 catalog digest   B10 report routines   B11 T-SCH-06
     B12 T-F06 (16 cases, literal expectations)   B13 T-REC-05 (all routines vs independent references)
     B14 catalog digest again = B9
  Stage C - FitLife_P3_UC05 rebuilt: UC05 regression (settlement, cancellation, loyalty, tiers) with the
     report routines deployed
     C1 rebuild   C2-C3 T-SCH-01/02   C4-C18 deployment exactly as run UC05LOY-RUN (incl. T-SCH-03/04/05)
     C19 catalog digest   C20 report routines   C21 T-SCH-06
     C22 T-F05S   C23 T-F05-U0   C24 T-CONC-06 R   C25 T-CONC-01 A   C26 T-CONC-02 A   C27 T-F05L + T-REC-01/02/04
     C28 T-CONC-04F A + T-REC-01/02/04   (V-UC06R integrity after each)
     C29 T-REC-05 incl. the spending cross-check   C30 T-SCH-06 again   C31 catalog digest again = C19
  Stage D - FitLife_P3_UC05L (existing DS-L copy; NOT rebuilt, dataset NOT regenerated)
     D1 marker + dataset checksum = run C   D2 catalog digest   D3 report routines   D4 T-SCH-06
     D5 T-REC-05 on DS-L incl. the spending cross-check   D6 reference capture (plans, logical reads; no timing)
     D7 T-REC-01/02/04 as of 2026-01-15 (loyalty state unaffected)   D8 dataset checksum again = run C
     D9 catalog digest again = D2
  Z1 fingerprint after = before   Z2 FitLife_P3_P2 checksum after
  Changes only FitLife_P3_UC05 (rebuilt) and FitLife_P3_UC05L (programmability only). No timing is a
  measurement (R-27 OPEN). No index, partition, view or summary is created. Names are masked.
#>
param(
    [string]$Server = 'localhost',
    [string]$EvidenceDir = 'docs/phase2/person3/evidence/test-results',
    [string]$GoldThreshold = '1000000.00',        # TEST_ONLY SYNTHETIC (D-008 values not approved)
    [string]$PlatinumThreshold = '3000000.00',    # TEST_ONLY SYNTHETIC
    [string]$DslLoyaltyAsOf = '2026-01-15'        # evaluation date of the last tier batch on the DS-L copy (UC05LOY-RUN step 42)
)
$ErrorActionPreference = 'Continue'
$inv = [Globalization.CultureInfo]::InvariantCulture
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
Set-Location $repo
if (-not [System.IO.Path]::IsPathRooted($EvidenceDir)) { $EvidenceDir = Join-Path $repo $EvidenceDir }
$planDir = Join-Path (Split-Path $EvidenceDir) 'execution-plans'
$ts = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmm', $inv)
$logPath = Join-Path $EvidenceDir "UC06-RUN__$ts.txt"
foreach ($p in @($logPath)) { if (Test-Path $p) { throw "refusing to overwrite $p" } }
$refChecksum = Join-Path $repo 'docs/phase2/person3/evidence/test-results/CHECKSUMS__DS-L__20261108-1155_C.txt'
$refLine = (Get-Content $refChecksum | Where-Object { $_ -like 'DATASET_CHECKSUM*' } | Select-Object -First 1).Trim()
$UC05 = 'FitLife_P3_UC05'; $UC05L = 'FitLife_P3_UC05L'

$mask = New-Object System.Collections.Generic.List[string]
if ($env:COMPUTERNAME) { $mask.Add($env:COMPUTERNAME) }
$names = & sqlcmd -S $Server -E -I -b -h -1 -W -Q "SET NOCOUNT ON; SELECT CONVERT(nvarchar(128), SERVERPROPERTY('MachineName')); SELECT CONVERT(nvarchar(128), SERVERPROPERTY('ServerName')); SELECT @@SERVERNAME;" 2>$null
foreach ($n in $names) { $t = "$n".Trim(); if ($t.Length -gt 2) { $mask.Add($t); if ($t.Contains('\')) { $mask.Add($t.Split('\')[0]) } } }
function Hide([string]$s) { foreach ($m in ($mask | Sort-Object Length -Descending -Unique)) { $s = [regex]::Replace($s, [regex]::Escape($m), '<local-server>', 'IgnoreCase') }; return $s }
$log = New-Object System.Collections.Generic.List[string]
function Log([string]$s) { $h = Hide $s; $log.Add($h); Write-Output $h }
function Utc { (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss', $inv) }
$results = New-Object System.Collections.Generic.List[object]
function Step([string]$id, [string]$descr, [bool]$ok, [string]$note) {
    $results.Add([pscustomobject]@{ Id = $id; Result = $(if ($ok) { 'PASS' } else { 'FAIL' }); Descr = $descr })
    Log ("STEP {0} {1}: {2}{3}" -f $id, $(if ($ok) { 'PASS' } else { 'FAIL' }), $descr, $(if ($note) { " - $note" } else { '' }))
}
function Sql([string[]]$sqlArgs) { $out = & sqlcmd -S $Server -E -I -b -W -s '|' @sqlArgs 2>&1; return [pscustomobject]@{ Exit = $LASTEXITCODE; Lines = @($out | ForEach-Object { "$_" }) } }
function Section([string]$title, $res) { Log ''; Log "== $title (sqlcmd exit $($res.Exit)) =="; foreach ($l in $res.Lines) { Log $l } }
function Has($res, [string]$pattern) { return (($res.Exit -eq 0) -and (($res.Lines -join "`n") -match $pattern)) }
function Summ($res, [string]$prefix) { return ((@($res.Lines | Where-Object { $_ -like "$prefix*" })) -join '') }
function Line1($res, [string]$prefix) { return ((@($res.Lines | Where-Object { $_ -like "$prefix*" }) | Select-Object -First 1) + '').Trim() }
function Fp { $r = Sql @('-v', "TargetDb=$UC05", '-i', 'tests/db/build/fingerprint_instance.sql'); return [pscustomobject]@{ Exit = $r.Exit; Lines = @($r.Lines | Where-Object { $_ -notlike "$UC05L|*" }) } }
# Section/Step write to the console; $null = keeps that text out of the return value (the boolean only).
function Deploy([string]$id, [string]$db, [string]$file, [string]$descr, [string]$pattern, [string[]]$extra = @()) {
    $r = Sql (@('-d', $db) + $extra + @('-i', $file)); $null = Section "$id. $descr" $r
    $ok = Has $r $pattern; $null = Step $id $descr $ok ''; return $ok
}
function Digest([string]$db) { $r = Sql @('-d', $db, '-i', 'tests/db/schema/catalog_digest.sql'); return (Line1 $r 'CATALOG_DIGEST|') }
function Sch06([string]$id, [string]$db, [string]$when) {
    $r = Sql @('-d', $db, '-i', 'tests/db/schema/T-SCH-06_revenue_catalog_and_scope.sql'); Section "$id. T-SCH-06 in $db ($when)" $r
    Step $id "T-SCH-06 in $db ($when): report routines read-only, exact object set, canonical filter, approved routines unchanged" (Has $r 'T-SCH-06_RESULT: PASS') (Summ $r 'T-SCH-06 SUMMARY')
}
function V([string]$id, [string]$after) {
    $r = Sql @('-d', $UC05, '-i', 'tests/db/functional/V-UC06R_integrity.sql'); Section "$id. V-UC06R after $after" $r
    Step "$id-V" "V-UC06R integrity after $after" (Has $r 'V-UC06R_RESULT: PASS') (Summ $r 'V-UC06R SUMMARY')
}
function RecLoy([string]$id, [string]$db, [string]$asOf, [string]$after) {
    $r = Sql @('-d', $db, '-v', "AsOfDate=$asOf", '-i', 'tests/db/reconciliation/T-REC_loyalty.sql'); Section "$id. T-REC-01/02/04 in $db as of $asOf ($after)" $r
    Step "$id-R" "T-REC-01/02/04 in $db as of $asOf ($after)" (Has $r 'T-REC_loyalty_RESULT: PASS') (Summ $r 'T-REC_loyalty SUMMARY')
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
function TestFile([string]$id, [string]$db, [string]$file, [string]$evName, [string]$descr, [string]$prefix, [string]$linePattern, [string[]]$extra = @()) {
    $r = Sql (@('-d', $db) + $extra + @('-i', $file))
    $hdr = @("$descr. Run UC06-RUN__$ts.", "Executed (UTC): $(Utc); database $db; script $file (SHA-256 $((Get-FileHash -Algorithm SHA256 (Join-Path $repo $file)).Hash)); sqlcmd exit $($r.Exit)", '')
    (($hdr + $r.Lines) | ForEach-Object { Hide $_ }) | Out-File -Encoding utf8 (Join-Path $EvidenceDir $evName)
    Log ''; Log "== $id. ${descr}: full output in $evName =="
    foreach ($l in ($r.Lines | Where-Object { $_ -match $linePattern })) { Log ($l.Substring(0, [Math]::Min(420, $l.Length))) }
    Step $id $descr (Has $r "${prefix}_RESULT: PASS") (Summ $r "$prefix SUMMARY")
}
function Checksum([string]$db) { $c = Sql @('-d', $db, '-v', 'MaxGrantPercent=2', '-i', 'tests/db/seed/T-REPRO-02_checksums.sql'); return (Line1 $c 'DATASET_CHECKSUM') }

$scripts = @('db/procedures/usp_P3_RevenueReports.sql',
             'tests/db/fixtures/R001__TEST_ONLY_revenue_report_invoices.sql', 'tests/db/functional/T-F06_revenue_reports.sql', 'tests/db/reconciliation/T-REC_revenue.sql',
             'tests/db/schema/T-SCH-06_revenue_catalog_and_scope.sql', 'tests/db/schema/catalog_digest.sql', 'tests/db/functional/V-UC06R_integrity.sql',
             'tests/db/revenue/capture_uc06_reference.ps1', 'tests/db/functional/run_uc06_revenue.ps1',
             'tests/db/build/rebuild_uc05_db.sql', 'db/migrations/V001__p3_billing_and_spending_tables.sql', 'db/migrations/V002__p3_settlement_and_spending_constraints.sql',
             'db/migrations/V003__p3_points_earned_rule.sql', 'db/procedures/usp_P3_CreateInvoice.sql', 'db/procedures/usp_P3_SettleInvoice.sql', 'db/procedures/usp_P3_CancelInvoice.sql',
             'db/procedures/usp_P3_EvaluateTiers.sql', 'db/procedures/usp_P3_GetMemberLoyalty.sql', 'db/reference/usp_P3_SettleInvoice_Baseline.sql',
             'tests/db/fixtures/F001U__TEST_ONLY_uc05_key_rows.sql', 'tests/db/fixtures/F002P__TEST_ONLY_member_current_points.sql',
             'tests/db/fixtures/F002T__TEST_ONLY_member_tier.sql', 'tests/db/fixtures/F003H__TEST_ONLY_paid_history_helper.sql',
             'tests/db/doubles/D001__TEST_ONLY_settlement_hook_doubles.sql', 'tests/db/schema/T-SCH-01_constraints.sql', 'tests/db/schema/T-SCH-02_conformance.sql',
             'tests/db/schema/T-SCH-03_uc05_catalog_and_scope.sql', 'tests/db/schema/T-SCH-04_settlement_catalog_and_scope.sql', 'tests/db/schema/T-SCH-05_loyalty_catalog_and_scope.sql',
             'tests/db/functional/T-F05_invoice_creation.sql', 'tests/db/functional/T-F05S_settlement.sql', 'tests/db/functional/T-F05-U0_settlement_baseline.sql', 'tests/db/functional/T-F05L_loyalty_tiers.sql',
             'tests/db/reconciliation/T-REC_loyalty.sql', 'tests/db/concurrency/T-CONC-04F_settlement_vs_tier_batch.ps1',
             'tests/db/concurrency/T-CONC-01_02_parallel_settlement.ps1', 'tests/db/concurrency/T-CONC-06_parallel_creation.ps1',
             'tests/db/seed/T-REPRO-02_checksums.sql', 'tests/db/build/fingerprint_instance.sql')
Log "UC06-RUN - WO-P3-P4-01 Part F: UC06 revenue report routines (D-010): functional tests, reconciliation, UC05 regression, DS-L, reference capture"
Log ("Started (UTC): " + (Utc) + "; databases changed: $UC05 (rebuilt three times; isolated, disposable), $UC05L (report routines deployed; tables read only); FitLife_P3_P1 and FitLife_P3_P2 read only")
Log "No timing in this log is a measurement (R-27 OPEN). No index, partition, view or summary is created. TEST_ONLY SYNTHETIC tier thresholds in stage C: Gold $GoldThreshold, Platinum $PlatinumThreshold (D-008 values open)"
Log 'Scripts (SHA-256):'
foreach ($s in $scripts) { Log ("  {0}  {1}" -f (Get-FileHash -Algorithm SHA256 (Join-Path $repo $s)).Hash, $s) }

$fpBefore = Fp; Section '1. Instance fingerprint before (FitLife_P3_UC05 and FitLife_P3_UC05L excluded)' $fpBefore
Step '1' 'Instance fingerprint captured before' ($fpBefore.Exit -eq 0) ''
$ckB = Checksum 'FitLife_P3_P2'
Step '2' 'FitLife_P3_P2 checksum before = DS-L run C reference' ($ckB -eq $refLine) $ckB

# ================= Stage A: invoice-creation regression =================
Log ''; Log '######## Stage A: invoice-creation regression with the report routines deployed ########'
$stopA = $false
$r = Sql @('-i', 'tests/db/build/rebuild_uc05_db.sql'); Section 'A1. Rebuild FitLife_P3_UC05' $r
if (-not (Has $r 'BUILD_RESULT: OK')) { $stopA = $true }; Step 'A1' 'Fresh FitLife_P3_UC05 (F001, V001, V002)' (-not $stopA) ''
if (-not $stopA) {
    $r = Sql @('-d', $UC05, '-i', 'tests/db/schema/T-SCH-01_constraints.sql'); Step 'A2' 'T-SCH-01 (P1 regression)' (Has $r 'T-SCH-01_RESULT: PASS') (Summ $r 'T-SCH-01 SUMMARY')
    $r = Sql @('-d', $UC05, '-i', 'tests/db/schema/T-SCH-02_conformance.sql'); Step 'A3' 'T-SCH-02 (P1 regression)' (Has $r 'T-SCH-02_RESULT: PASS') (Summ $r 'T-SCH-02 SUMMARY')
    $d = @(
        @('A4', 'db/procedures/usp_P3_CreateInvoice.sql', 'Creation routine (unchanged)', 'usp_P3_CreateInvoice applied'),
        @('A5', 'tests/db/schema/T-SCH-03_uc05_catalog_and_scope.sql', 'T-SCH-03 creation scope (before the report routines)', 'T-SCH-03_RESULT: PASS'),
        @('A6', 'tests/db/fixtures/F001U__TEST_ONLY_uc05_key_rows.sql', 'F001U TEST_ONLY key rows', 'F001U \(TEST_ONLY\) applied'))
    foreach ($x in $d) { if (-not (Deploy $x[0] $UC05 $x[1] $x[2] $x[3])) { $stopA = $true; break } }
}
if (-not $stopA) {
    $dgA = Digest $UC05; Step 'A7' 'Catalog digest before the report routines' ($dgA -like 'CATALOG_DIGEST|*') $dgA
    if (-not (Deploy 'A8' $UC05 'db/procedures/usp_P3_RevenueReports.sql' 'UC06 report routines deployed' 'usp_P3_RevenueReports applied')) { $stopA = $true }
}
if (-not $stopA) {
    Sch06 'A9' $UC05 'creation stage'
    TestFile 'A10' $UC05 'tests/db/functional/T-F05_invoice_creation.sql' "T-F05-CREATE__$ts.txt" 'T-F05 invoice-creation tests (WO-P3-P3-00 suite) with the report routines deployed' 'T-F05' '^(T-F05 SUMMARY|T-F05_RESULT)'
    $dgA2 = Digest $UC05; Step 'A11' 'Catalog digest after the creation tests = before the report routines' (($dgA2 -eq $dgA) -and ($dgA -like 'CATALOG_DIGEST|*')) $dgA2
}

# ================= Stage B: revenue fixtures =================
Log ''; Log '######## Stage B: revenue report tests on the TEST_ONLY fixture R001 ########'
$stopB = $false
$r = Sql @('-i', 'tests/db/build/rebuild_uc05_db.sql'); Section 'B1. Rebuild FitLife_P3_UC05' $r
if (-not (Has $r 'BUILD_RESULT: OK')) { $stopB = $true }; Step 'B1' 'Fresh FitLife_P3_UC05 (F001, V001, V002)' (-not $stopB) ''
if (-not $stopB) {
    $d = @(
        @('B2', 'db/procedures/usp_P3_CreateInvoice.sql', 'Creation routine (unchanged)', 'usp_P3_CreateInvoice applied'),
        @('B3', 'tests/db/fixtures/F001U__TEST_ONLY_uc05_key_rows.sql', 'F001U TEST_ONLY key rows', 'F001U \(TEST_ONLY\) applied'),
        @('B4', 'tests/db/fixtures/F002P__TEST_ONLY_member_current_points.sql', 'F002P TEST_ONLY CurrentPoints', 'F002P \(TEST_ONLY\) applied'),
        @('B5', 'tests/db/doubles/D001__TEST_ONLY_settlement_hook_doubles.sql', 'D001 TEST_ONLY hook doubles', 'D001 \(TEST_ONLY\) applied'),
        @('B6', 'db/procedures/usp_P3_SettleInvoice.sql', 'Settlement routine (unchanged)', 'usp_P3_SettleInvoice applied'),
        @('B7', 'db/procedures/usp_P3_CancelInvoice.sql', 'Cancellation routine (unchanged)', 'usp_P3_CancelInvoice applied'),
        @('B8', 'tests/db/fixtures/R001__TEST_ONLY_revenue_report_invoices.sql', 'R001 TEST_ONLY revenue fixture (16 invoices with chosen UTC payment times)', 'R001 \(TEST_ONLY\) applied'))
    foreach ($x in $d) { if (-not (Deploy $x[0] $UC05 $x[1] $x[2] $x[3])) { $stopB = $true; break } }
}
if (-not $stopB) {
    $dgB = Digest $UC05; Step 'B9' 'Catalog digest before the report routines' ($dgB -like 'CATALOG_DIGEST|*') $dgB
    if (-not (Deploy 'B10' $UC05 'db/procedures/usp_P3_RevenueReports.sql' 'UC06 report routines deployed' 'usp_P3_RevenueReports applied')) { $stopB = $true }
}
if (-not $stopB) {
    Sch06 'B11' $UC05 'fixture stage'
    TestFile 'B12' $UC05 'tests/db/functional/T-F06_revenue_reports.sql' "T-F06__$ts.txt" 'T-F06 revenue report tests (T-F06-01...-05, -09...-13; literal expectations)' 'T-F06' '^(F\d|T-F06 SUMMARY|T-F06_RESULT)'
    TestFile 'B13' $UC05 'tests/db/reconciliation/T-REC_revenue.sql' "T-REC-05__${ts}_fixtures.txt" 'T-REC-05 on the fixtures: every routine vs independent references, every branch x month' 'T-REC-05' '^(V\d|T-REC-05 SUMMARY|T-REC-05_RESULT)' @('-v', 'SpendingCheck=0')
    $dgB2 = Digest $UC05; Step 'B14' 'Catalog digest after the revenue tests = before the report routines' (($dgB2 -eq $dgB) -and ($dgB -like 'CATALOG_DIGEST|*')) $dgB2
}

# ================= Stage C: UC05 regression =================
Log ''; Log '######## Stage C: UC05 regression (settlement, cancellation, loyalty, tiers) with the report routines deployed ########'
$stopC = $false
$r = Sql @('-i', 'tests/db/build/rebuild_uc05_db.sql'); Section 'C1. Rebuild FitLife_P3_UC05' $r
if (-not (Has $r 'BUILD_RESULT: OK')) { $stopC = $true }; Step 'C1' 'Fresh FitLife_P3_UC05 (F001, V001, V002)' (-not $stopC) ''
if (-not $stopC) {
    $r = Sql @('-d', $UC05, '-i', 'tests/db/schema/T-SCH-01_constraints.sql'); Step 'C2' 'T-SCH-01 (P1 regression)' (Has $r 'T-SCH-01_RESULT: PASS') (Summ $r 'T-SCH-01 SUMMARY')
    $r = Sql @('-d', $UC05, '-i', 'tests/db/schema/T-SCH-02_conformance.sql'); Step 'C3' 'T-SCH-02 (P1 regression)' (Has $r 'T-SCH-02_RESULT: PASS') (Summ $r 'T-SCH-02 SUMMARY')
    $d = @(
        @('C4', 'db/procedures/usp_P3_CreateInvoice.sql', 'Creation routine (unchanged)', 'usp_P3_CreateInvoice applied', @()),
        @('C5', 'tests/db/schema/T-SCH-03_uc05_catalog_and_scope.sql', 'T-SCH-03 creation scope', 'T-SCH-03_RESULT: PASS', @()),
        @('C6', 'tests/db/fixtures/F001U__TEST_ONLY_uc05_key_rows.sql', 'F001U TEST_ONLY key rows', 'F001U \(TEST_ONLY\) applied', @()),
        @('C7', 'tests/db/fixtures/F002P__TEST_ONLY_member_current_points.sql', 'F002P TEST_ONLY CurrentPoints', 'F002P \(TEST_ONLY\) applied', @()),
        @('C8', 'tests/db/doubles/D001__TEST_ONLY_settlement_hook_doubles.sql', 'D001 TEST_ONLY hook doubles', 'D001 \(TEST_ONLY\) applied', @()),
        @('C9', 'db/procedures/usp_P3_SettleInvoice.sql', 'Settlement routine (unchanged)', 'usp_P3_SettleInvoice applied', @()),
        @('C10', 'db/procedures/usp_P3_CancelInvoice.sql', 'Cancellation routine (unchanged)', 'usp_P3_CancelInvoice applied', @()),
        @('C11', 'tests/db/schema/T-SCH-04_settlement_catalog_and_scope.sql', 'T-SCH-04 settlement scope', 'T-SCH-04_RESULT: PASS', @()),
        @('C12', 'tests/db/fixtures/F002T__TEST_ONLY_member_tier.sql', 'F002T TEST_ONLY tiers (synthetic thresholds)', 'F002T \(TEST_ONLY\) applied', @('-v', "GoldThreshold=$GoldThreshold", "PlatinumThreshold=$PlatinumThreshold")),
        @('C13', 'tests/db/fixtures/F003H__TEST_ONLY_paid_history_helper.sql', 'F003H TEST_ONLY paid-history helper', 'F003H \(TEST_ONLY\) applied', @()),
        @('C14', 'db/reference/usp_P3_SettleInvoice_Baseline.sql', 'U0 REFERENCE_ONLY', 'usp_P3_SettleInvoice_Baseline applied', @()),
        @('C15', 'db/migrations/V003__p3_points_earned_rule.sql', 'V003 point-rule CHECK', 'V003 applied', @()),
        @('C16', 'db/procedures/usp_P3_EvaluateTiers.sql', 'usp_P3_EvaluateTiers + tier functions (unchanged)', 'usp_P3_EvaluateTiers applied', @()),
        @('C17', 'db/procedures/usp_P3_GetMemberLoyalty.sql', 'usp_P3_GetMemberLoyalty (unchanged)', 'usp_P3_GetMemberLoyalty applied', @()),
        @('C18', 'tests/db/schema/T-SCH-05_loyalty_catalog_and_scope.sql', 'T-SCH-05 accepted UC05 catalog, inventory and scopes (before the report routines)', 'T-SCH-05_RESULT: PASS', @()))
    foreach ($x in $d) { if (-not (Deploy $x[0] $UC05 $x[1] $x[2] $x[3] $x[4])) { $stopC = $true; break } }
}
if (-not $stopC) {
    $dgC = Digest $UC05; Step 'C19' 'Catalog digest before the report routines' ($dgC -like 'CATALOG_DIGEST|*') $dgC
    if (-not (Deploy 'C20' $UC05 'db/procedures/usp_P3_RevenueReports.sql' 'UC06 report routines deployed' 'usp_P3_RevenueReports applied')) { $stopC = $true }
}
if (-not $stopC) {
    Sch06 'C21' $UC05 'regression stage, before the UC05 tests'
    TestFile 'C22' $UC05 'tests/db/functional/T-F05S_settlement.sql' "T-F05S-SETTLE__$ts.txt" 'T-F05S settlement and cancellation regression (47 cases)' 'T-F05S' '^(T-F05S SUMMARY|T-F05S_RESULT)'
    V 'C22' 'T-F05S'
    TestFile 'C23' $UC05 'tests/db/functional/T-F05-U0_settlement_baseline.sql' "T-F05-U0__$ts.txt" 'T-F05-U0 regression (T-F05-36, T-F05-37, K01)' 'T-F05-U0' '^(T-F05-U0 SUMMARY|T-F05-U0_RESULT)'
    V 'C23' 'T-F05-U0'
    Conc 'C24' 'tests/db/concurrency/T-CONC-06_parallel_creation.ps1' @('-RunLabel', 'R') "T-CONC-06__${ts}_R.txt" 'T-CONC-06 run R (parallel creation regression)' '^(T-CONC-06 SUMMARY|T-CONC-06_RESULT)'
    V 'C24' 'T-CONC-06 R'
    Conc 'C25' 'tests/db/concurrency/T-CONC-01_02_parallel_settlement.ps1' @('-Mode', 'SameInvoice', '-RunLabel', 'A') "T-CONC-01__${ts}_A.txt" 'T-CONC-01 run A (same invoice settled in parallel)' '^(T-CONC-01 SUMMARY|T-CONC-01_RESULT)'
    V 'C25' 'T-CONC-01 A'
    Conc 'C26' 'tests/db/concurrency/T-CONC-01_02_parallel_settlement.ps1' @('-Mode', 'SameMember', '-RunLabel', 'A') "T-CONC-02__${ts}_A.txt" 'T-CONC-02 run A (concurrent payments, same member)' '^(T-CONC-02 SUMMARY|T-CONC-02_RESULT)'
    V 'C26' 'T-CONC-02 A'
    TestFile 'C27' $UC05 'tests/db/functional/T-F05L_loyalty_tiers.sql' "T-F05L__$ts.txt" 'T-F05L loyalty and tier tests (T-F05-12...-15, -32...-35)' 'T-F05L' '^(L\d|T-F05L SUMMARY|T-F05L_RESULT)'
    V 'C27' 'T-F05L'
    $today = (Get-Date).ToUniversalTime().AddHours(7).ToString('yyyy-MM-dd', $inv)
    RecLoy 'C27' $UC05 $today 'after T-F05L, whose last step evaluates today'
    Conc 'C28' 'tests/db/concurrency/T-CONC-04F_settlement_vs_tier_batch.ps1' @('-RunLabel', 'A') "T-CONC-04F__${ts}_A.txt" 'T-CONC-04F run A (settlement concurrent with the tier batch)' '^(  C\d|T-CONC-04F SUMMARY|T-CONC-04F_RESULT|Final)'
    V 'C28' 'T-CONC-04F A'
    RecLoy 'C28' $UC05 $today 'after T-CONC-04F A (ends with a quiescent run)'
    TestFile 'C29' $UC05 'tests/db/reconciliation/T-REC_revenue.sql' "T-REC-05__${ts}_regression.txt" 'T-REC-05 on the regression data: every routine vs independent references; revenue = UC05 monthly spending' 'T-REC-05' '^(V\d|T-REC-05 SUMMARY|T-REC-05_RESULT)' @('-v', 'SpendingCheck=1')
    Sch06 'C30' $UC05 'regression stage, after all tests'
    $dgC2 = Digest $UC05; Step 'C31' 'Catalog digest after the regression = before the report routines (no table, constraint or index changed)' (($dgC2 -eq $dgC) -and ($dgC -like 'CATALOG_DIGEST|*')) $dgC2
}

# ================= Stage D: DS-L =================
Log ''; Log '######## Stage D: DS-L scale (existing copy FitLife_P3_UC05L; not rebuilt, dataset not regenerated) ########'
$stopD = $false
$mk = Sql @('-d', 'master', '-h', '-1', '-Q', "SET NOCOUNT ON; IF DB_ID(N'$UC05L') IS NULL SELECT 'MARKER|missing' ELSE EXEC (N'SELECT CONCAT(''MARKER|'', CONVERT(nvarchar(200), value)) FROM [$UC05L].sys.extended_properties WHERE class = 0 AND name = N''P3_Disposable'';');")
$marker = Line1 $mk 'MARKER|'
$ckL1 = ''
if ($marker -like 'MARKER|WO-P3-P2-01*WO-P3-P3-02*') { $ckL1 = Checksum $UC05L }
if (($marker -notlike 'MARKER|WO-P3-P2-01*WO-P3-P3-02*') -or ($ckL1 -ne $refLine)) { $stopD = $true }
Step 'D1' 'FitLife_P3_UC05L is the approved disposable DS-L copy and its dataset checksum = DS-L run C reference (before)' (-not $stopD) "$marker; $ckL1"
if (-not $stopD) {
    $dgD = Digest $UC05L; Step 'D2' 'Catalog digest before the report routines' ($dgD -like 'CATALOG_DIGEST|*') $dgD
    if (-not (Deploy 'D3' $UC05L 'db/procedures/usp_P3_RevenueReports.sql' 'UC06 report routines deployed on the DS-L copy' 'usp_P3_RevenueReports applied')) { $stopD = $true }
}
if (-not $stopD) {
    Sch06 'D4' $UC05L 'DS-L copy'
    TestFile 'D5' $UC05L 'tests/db/reconciliation/T-REC_revenue.sql' "T-REC-05__${ts}_DS-L.txt" 'T-REC-05 on DS-L: every routine vs independent references for every branch x month; line level; revenue = UC05 monthly spending' 'T-REC-05' '^(V\d|T-REC-05 SUMMARY|T-REC-05_RESULT|\d{4}-\d{2}\||\d+\|\d)' @('-v', 'SpendingCheck=1')
    $refPath = Join-Path $EvidenceDir "UC06-REF__$ts.txt"
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'tests/db/revenue/capture_uc06_reference.ps1') -RunTs $ts -OutFile $refPath -PlanDir $planDir 2>&1
    $cx = $LASTEXITCODE
    if (Test-Path $refPath) { $c = Get-Content $refPath; ($c | ForEach-Object { Hide $_ }) | Out-File -Encoding utf8 $refPath }
    Log ''; Log "== D6. DIAGNOSTIC_ONLY reference capture (exit $cx): full output in $(Split-Path -Leaf $refPath) =="
    foreach ($l in $out) { if ("$l" -match '^(==|   result rows|   logical reads|   actual plan|UC06-REF_)') { Log "$l" } }
    Step 'D6' 'Reference capture on DS-L: query definitions, index inventory, row counts, logical reads, actual plans (DIAGNOSTIC_ONLY; no timing; not a baseline)' ($cx -eq 0) ''
    RecLoy 'D7' $UC05L $DslLoyaltyAsOf 'loyalty state of the DS-L copy unaffected by the report work'
    $ckL2 = Checksum $UC05L
    Step 'D8' 'FitLife_P3_UC05L dataset checksum after = before = run C' (($ckL2 -eq $refLine) -and ($ckL2 -eq $ckL1)) $ckL2
    $dgD2 = Digest $UC05L; Step 'D9' 'Catalog digest after = before the report routines (no table, constraint or index changed on DS-L)' (($dgD2 -eq $dgD) -and ($dgD -like 'CATALOG_DIGEST|*')) $dgD2
}

$fpAfter = Fp; Section 'Z1. Instance fingerprint after' $fpAfter
Step 'Z1' 'Instance fingerprint after = before (no other database changed)' (($fpAfter.Exit -eq 0) -and ((($fpAfter.Lines) -join "`n") -eq (($fpBefore.Lines) -join "`n"))) ''
$ckA = Checksum 'FitLife_P3_P2'
Step 'Z2' 'FitLife_P3_P2 checksum after = before = run C' (($ckA -eq $refLine) -and ($ckA -eq $ckB)) $ckA

$nf = @($results | Where-Object { $_.Result -eq 'FAIL' }).Count
$stopped = ($stopA -or $stopB -or $stopC -or $stopD)
Log ''; Log 'Summary:'; foreach ($x in $results) { Log ("  {0,-6} {1}  {2}" -f $x.Id, $x.Result, $x.Descr) }
Log ("UC06-RUN SUMMARY: steps $($results.Count); FAIL $nf; stage stopped early: $stopped; finished (UTC) $(Utc)")
Log ("UC06-RUN_RESULT: " + $(if ($nf -eq 0 -and -not $stopped) { 'PASS' } else { 'FAIL' }))
$log | Out-File -Encoding utf8 $logPath
if ($nf -eq 0 -and -not $stopped) { exit 0 } else { exit 1 }
