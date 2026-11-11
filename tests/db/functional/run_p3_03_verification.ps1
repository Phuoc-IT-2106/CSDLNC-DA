<#
  run_p3_03_verification.ps1 - TEST_ONLY runner for WO-P3-P3-03 Part C (correctness, consistency, concurrency and
  rollback scope of the 2026-11-10 limited-scope amendment). Windows PowerShell 5.1; nothing installed.
  NO performance measurement: no timing in this log is a measurement (R-27 OPEN); Part P (tasks 3, 3a, 4) is not run.

  S0 safety before any destructive step: instance identity; FitLife_P3_UC05 carries the WO-P3-P3-00 disposable
     marker, holds no protected dataset (< 10,000 invoices, not the DS-L copy) and has no other session connected;
     protected databases present and untouched (FitLife_P3_P1, FitLife_P3_P2, FitLife_P3_UC05L)
  1  instance fingerprint before (FitLife_P3_UC05 excluded)
  Stage A - FitLife_P3_UC05 rebuilt: invoice-creation regression incl. rollback cases (T-F05-04 Part 0, T-F05-19,
     T-F05-25) on the final routine set (report routines deployed)
  Stage C - FitLife_P3_UC05 rebuilt: UC05 regression and the isolated concurrency suites on the final routines
     T-F05S (incl. rollback T-F05-08 at the spending and MEMBER steps, T-F05-22 hook faults, T-F05-29 caller tx),
     T-F05-U0, T-CONC-06 R, T-CONC-01 A/B/C (same invoice; settle-vs-cancel race), T-CONC-02 A/B/C (same member),
     T-F05L (incl. T-F05-34 chunk failure), T-CONC-04F A/B/C (settlement vs tier batch), integrity after each,
     T-REC-01/02/04 and T-REC-05 (task 5: reconciliation after the concurrency runs), scope and catalog unchanged
  Stage W - FitLife_P3_UC05 rebuilt: integrated workflow and cross-operation concurrency
     T-WF-01 (creation -> settlement -> spending -> points -> tier -> revenue, final-state checks W1-W11),
     T-CONC-04R (reports vs settlement: no dirty read, rollback/commit, load, SERIALIZABLE multi-statement),
     T-CONC-07 (tier batch vs tier batch: application lock, timeout, error and client-timeout paths),
     T-CONC-08 (settlement vs cancellation of one invoice, both winners forced),
     integrity, T-REC-01/02/04, T-REC-05, scope and catalog unchanged
  Z  fingerprint after = before; FitLife_P3_P2 and FitLife_P3_UC05L dataset checksums = DS-L run C (read only)
  Changes only FitLife_P3_UC05 (rebuilt three times). TEST_ONLY SYNTHETIC tier thresholds (D-008 values open).
#>
param(
    [string]$Server = 'localhost',
    [string]$EvidenceDir = 'docs/phase2/person3/evidence/test-results',
    [string]$GoldThreshold = '1000000.00',        # TEST_ONLY SYNTHETIC (D-008 values not approved)
    [string]$PlatinumThreshold = '3000000.00'     # TEST_ONLY SYNTHETIC
)
$ErrorActionPreference = 'Continue'
$inv = [Globalization.CultureInfo]::InvariantCulture
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
Set-Location $repo
if (-not [System.IO.Path]::IsPathRooted($EvidenceDir)) { $EvidenceDir = Join-Path $repo $EvidenceDir }
$ts = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmm', $inv)
$logPath = Join-Path $EvidenceDir "P3-03-RUN__$ts.txt"
if (Test-Path $logPath) { throw "refusing to overwrite $logPath" }
$refChecksum = Join-Path $repo 'docs/phase2/person3/evidence/test-results/CHECKSUMS__DS-L__20261108-1155_C.txt'
$refLine = (Get-Content $refChecksum | Where-Object { $_ -like 'DATASET_CHECKSUM*' } | Select-Object -First 1).Trim()
$UC05 = 'FitLife_P3_UC05'

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
function Fp { return (Sql @('-v', "TargetDb=$UC05", '-i', 'tests/db/build/fingerprint_instance.sql')) }
function Deploy([string]$id, [string]$db, [string]$file, [string]$descr, [string]$pattern, [string[]]$extra = @()) {
    $r = Sql (@('-d', $db) + $extra + @('-i', $file)); $null = Section "$id. $descr" $r
    $ok = Has $r $pattern; $null = Step $id $descr $ok ''; return $ok
}
function Digest([string]$db) { $r = Sql @('-d', $db, '-i', 'tests/db/schema/catalog_digest.sql'); return (Line1 $r 'CATALOG_DIGEST|') }
function Sch06([string]$id, [string]$when) {
    $r = Sql @('-d', $UC05, '-i', 'tests/db/schema/T-SCH-06_revenue_catalog_and_scope.sql'); Section "$id. T-SCH-06 ($when)" $r
    Step $id "T-SCH-06 ($when): exact object set, no leftover object/principal/permission, approved routines unchanged" (Has $r 'T-SCH-06_RESULT: PASS') (Summ $r 'T-SCH-06 SUMMARY')
}
function V([string]$id, [string]$after) {
    $r = Sql @('-d', $UC05, '-i', 'tests/db/functional/V-UC06R_integrity.sql'); Section "$id. V-UC06R after $after" $r
    Step "$id-V" "V-UC06R integrity after $after" (Has $r 'V-UC06R_RESULT: PASS') (Summ $r 'V-UC06R SUMMARY')
}
function RecLoy([string]$id, [string]$asOf, [string]$after) {
    $r = Sql @('-d', $UC05, '-v', "AsOfDate=$asOf", '-i', 'tests/db/reconciliation/T-REC_loyalty.sql'); Section "$id. T-REC-01/02/04 as of $asOf ($after)" $r
    Step "$id-R" "T-REC-01/02/04 as of $asOf ($after)" (Has $r 'T-REC_loyalty_RESULT: PASS') (Summ $r 'T-REC_loyalty SUMMARY')
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
function TestFile([string]$id, [string]$file, [string]$evName, [string]$descr, [string]$prefix, [string]$linePattern, [string[]]$extra = @()) {
    $r = Sql (@('-d', $UC05) + $extra + @('-i', $file))
    $hdr = @("$descr. Run P3-03-RUN__$ts.", "Executed (UTC): $(Utc); database $UC05; script $file (SHA-256 $((Get-FileHash -Algorithm SHA256 (Join-Path $repo $file)).Hash)); sqlcmd exit $($r.Exit)", '')
    (($hdr + $r.Lines) | ForEach-Object { Hide $_ }) | Out-File -Encoding utf8 (Join-Path $EvidenceDir $evName)
    Log ''; Log "== $id. ${descr}: full output in $evName =="
    foreach ($l in ($r.Lines | Where-Object { $_ -match $linePattern })) { Log ($l.Substring(0, [Math]::Min(480, $l.Length))) }
    Step $id $descr (Has $r "${prefix}_RESULT: PASS") (Summ $r "$prefix SUMMARY")
}
function Checksum([string]$db) { $c = Sql @('-d', $db, '-v', 'MaxGrantPercent=10', '-i', 'tests/db/seed/T-REPRO-02_checksums.sql'); return (Line1 $c 'DATASET_CHECKSUM') }
function Rebuild([string]$id) { $r = Sql @('-i', 'tests/db/build/rebuild_uc05_db.sql'); Section "$id. Rebuild $UC05" $r; $ok = Has $r 'BUILD_RESULT: OK'; Step $id "Fresh $UC05 (F001, V001, V002)" $ok ''; return $ok }
function FullDeploy([string]$p) {
    $d = @(
        @("${p}04", 'db/procedures/usp_P3_CreateInvoice.sql', 'Creation routine (unchanged)', 'usp_P3_CreateInvoice applied', @()),
        @("${p}05", 'tests/db/schema/T-SCH-03_uc05_catalog_and_scope.sql', 'T-SCH-03 creation scope', 'T-SCH-03_RESULT: PASS', @()),
        @("${p}06", 'tests/db/fixtures/F001U__TEST_ONLY_uc05_key_rows.sql', 'F001U TEST_ONLY key rows', 'F001U \(TEST_ONLY\) applied', @()),
        @("${p}07", 'tests/db/fixtures/F002P__TEST_ONLY_member_current_points.sql', 'F002P TEST_ONLY CurrentPoints', 'F002P \(TEST_ONLY\) applied', @()),
        @("${p}08", 'tests/db/doubles/D001__TEST_ONLY_settlement_hook_doubles.sql', 'D001 TEST_ONLY hook doubles', 'D001 \(TEST_ONLY\) applied', @()),
        @("${p}09", 'db/procedures/usp_P3_SettleInvoice.sql', 'Settlement routine (unchanged)', 'usp_P3_SettleInvoice applied', @()),
        @("${p}10", 'db/procedures/usp_P3_CancelInvoice.sql', 'Cancellation routine (unchanged)', 'usp_P3_CancelInvoice applied', @()),
        @("${p}11", 'tests/db/schema/T-SCH-04_settlement_catalog_and_scope.sql', 'T-SCH-04 settlement scope', 'T-SCH-04_RESULT: PASS', @()),
        @("${p}12", 'tests/db/fixtures/F002T__TEST_ONLY_member_tier.sql', 'F002T TEST_ONLY tiers (synthetic thresholds)', 'F002T \(TEST_ONLY\) applied', @('-v', "GoldThreshold=$GoldThreshold", "PlatinumThreshold=$PlatinumThreshold")),
        @("${p}13", 'tests/db/fixtures/F003H__TEST_ONLY_paid_history_helper.sql', 'F003H TEST_ONLY paid-history helper', 'F003H \(TEST_ONLY\) applied', @()),
        @("${p}14", 'db/reference/usp_P3_SettleInvoice_Baseline.sql', 'U0 REFERENCE_ONLY', 'usp_P3_SettleInvoice_Baseline applied', @()),
        @("${p}15", 'db/migrations/V003__p3_points_earned_rule.sql', 'V003 point-rule CHECK', 'V003 applied', @()),
        @("${p}16", 'db/procedures/usp_P3_EvaluateTiers.sql', 'usp_P3_EvaluateTiers + tier functions (unchanged)', 'usp_P3_EvaluateTiers applied', @()),
        @("${p}17", 'db/procedures/usp_P3_GetMemberLoyalty.sql', 'usp_P3_GetMemberLoyalty (unchanged)', 'usp_P3_GetMemberLoyalty applied', @()),
        @("${p}18", 'tests/db/schema/T-SCH-05_loyalty_catalog_and_scope.sql', 'T-SCH-05 accepted UC05 catalog (before the report routines)', 'T-SCH-05_RESULT: PASS', @()))
    foreach ($x in $d) { if (-not (Deploy $x[0] $UC05 $x[1] $x[2] $x[3] $x[4])) { return $false } }
    return (Deploy "${p}20" $UC05 'db/procedures/usp_P3_RevenueReports.sql' 'UC06 report routines (unchanged)' 'usp_P3_RevenueReports applied')
}

$scripts = @('tests/db/functional/run_p3_03_verification.ps1', 'tests/db/functional/T-WF-01_uc05_uc06_workflow.sql',
             'tests/db/concurrency/T-CONC-04R_reports_vs_settlement.ps1', 'tests/db/concurrency/T-CONC-07_tier_batch_serialisation.ps1', 'tests/db/concurrency/T-CONC-08_settle_vs_cancel_ordered.ps1',
             'tests/db/concurrency/T-CONC-01_02_parallel_settlement.ps1', 'tests/db/concurrency/T-CONC-04F_settlement_vs_tier_batch.ps1', 'tests/db/concurrency/T-CONC-06_parallel_creation.ps1',
             'db/migrations/V001__p3_billing_and_spending_tables.sql', 'db/migrations/V002__p3_settlement_and_spending_constraints.sql', 'db/migrations/V003__p3_points_earned_rule.sql',
             'db/procedures/usp_P3_CreateInvoice.sql', 'db/procedures/usp_P3_SettleInvoice.sql', 'db/procedures/usp_P3_CancelInvoice.sql', 'db/procedures/usp_P3_EvaluateTiers.sql',
             'db/procedures/usp_P3_GetMemberLoyalty.sql', 'db/procedures/usp_P3_RevenueReports.sql', 'db/reference/usp_P3_SettleInvoice_Baseline.sql',
             'tests/db/build/rebuild_uc05_db.sql', 'tests/db/fixtures/F001__TEST_ONLY_shared_dependency_keys.sql', 'tests/db/fixtures/F001U__TEST_ONLY_uc05_key_rows.sql',
             'tests/db/fixtures/F002P__TEST_ONLY_member_current_points.sql', 'tests/db/fixtures/F002T__TEST_ONLY_member_tier.sql', 'tests/db/fixtures/F003H__TEST_ONLY_paid_history_helper.sql',
             'tests/db/doubles/D001__TEST_ONLY_settlement_hook_doubles.sql', 'tests/db/schema/T-SCH-01_constraints.sql', 'tests/db/schema/T-SCH-02_conformance.sql',
             'tests/db/schema/T-SCH-03_uc05_catalog_and_scope.sql', 'tests/db/schema/T-SCH-04_settlement_catalog_and_scope.sql', 'tests/db/schema/T-SCH-05_loyalty_catalog_and_scope.sql',
             'tests/db/schema/T-SCH-06_revenue_catalog_and_scope.sql', 'tests/db/schema/catalog_digest.sql',
             'tests/db/functional/T-F05_invoice_creation.sql', 'tests/db/functional/T-F05S_settlement.sql', 'tests/db/functional/T-F05-U0_settlement_baseline.sql', 'tests/db/functional/T-F05L_loyalty_tiers.sql',
             'tests/db/functional/V-UC06R_integrity.sql', 'tests/db/reconciliation/T-REC_loyalty.sql', 'tests/db/reconciliation/T-REC_revenue.sql',
             'tests/db/seed/T-REPRO-02_checksums.sql', 'tests/db/build/fingerprint_instance.sql')
Log "P3-03-RUN - WO-P3-P3-03 Part C: UC05/UC06 integrated correctness, consistency, concurrency and rollback verification"
Log ("Started (UTC): " + (Utc) + "; database changed: $UC05 only (rebuilt three times; isolated, disposable). FitLife_P3_P1, FitLife_P3_P2, FitLife_P3_UC05L read only")
Log "No timing in this log is a measurement (R-27 OPEN); Part P (U0/U1 benchmark, creation-cost baseline, T-PERF-*) not run. No index, partition, view, summary or setting change. TEST_ONLY SYNTHETIC tier thresholds: Gold $GoldThreshold, Platinum $PlatinumThreshold (D-008 values open)"
Log 'Scripts (SHA-256):'
foreach ($s in $scripts) { Log ("  {0}  {1}" -f (Get-FileHash -Algorithm SHA256 (Join-Path $repo $s)).Hash, $s) }

# ================= S0 safety =================
$q = @"
SET NOCOUNT ON;
SELECT 'ENGINE', CONVERT(varchar(40), SERVERPROPERTY('ProductVersion')), CONVERT(varchar(100), SERVERPROPERTY('Edition'));
SELECT 'DB', name, state_desc, is_read_committed_snapshot_on, snapshot_isolation_state_desc FROM sys.databases WHERE name LIKE 'FitLife[_]P3[_]%' ORDER BY name;
SELECT 'MARKER', CONVERT(nvarchar(200), value) FROM [$UC05].sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable';
SELECT 'INVOICES', COUNT_BIG(*) FROM [$UC05].dbo.INVOICE;
SELECT 'SESSIONS', COUNT(*) FROM sys.dm_exec_sessions WHERE is_user_process = 1 AND session_id <> @@SPID AND database_id = DB_ID(N'$UC05');
SELECT 'OPEN_TX', COUNT(*) FROM sys.dm_tran_database_transactions WHERE database_id = DB_ID(N'$UC05') AND database_transaction_begin_time IS NOT NULL;
"@
$r = Sql @('-d', 'master', '-h', '-1', '-Q', $q); Section 'S0. Safety before any destructive step' $r
$txt = ($r.Lines -join "`n")
$m = [regex]::Match($txt, '(?m)^INVOICES\|(\d+)'); $nInv = $(if ($m.Success) { [long]$m.Groups[1].Value } else { -1 })
$s0 = ($r.Exit -eq 0) -and ($txt -match '(?m)^ENGINE\|17\.0\.1000\.7\|Standard Developer') -and ($txt -match '(?m)^MARKER\|WO-P3-P3-00') -and ($nInv -ge 0 -and $nInv -lt 10000) `
      -and ($txt -match '(?m)^SESSIONS\|0\s*$') -and ($txt -match '(?m)^OPEN_TX\|0\s*$') -and ($txt -match '(?m)^DB\|FitLife_P3_P1\|ONLINE') -and ($txt -match '(?m)^DB\|FitLife_P3_P2\|ONLINE') -and ($txt -match '(?m)^DB\|FitLife_P3_UC05L\|ONLINE')
Step 'S0' "Target $UC05 is the disposable WO-P3-P3-00 database (marker), holds no protected dataset ($nInv invoices), has no other session or open transaction; protected databases present" $s0 ''
if (-not $s0) { Log 'STOP: safety preconditions not met; nothing destructive was executed.'; $log | Out-File -Encoding utf8 $logPath; exit 1 }

$fpBefore = Fp; Section '1. Instance fingerprint before (FitLife_P3_UC05 excluded)' $fpBefore
Step '1' 'Instance fingerprint captured before' ($fpBefore.Exit -eq 0) ''

# ================= Stage A =================
Log ''; Log '######## Stage A: invoice-creation regression (incl. rollback cases) on the final routine set ########'
$stopA = -not (Rebuild 'A1')
if (-not $stopA) {
    $r = Sql @('-d', $UC05, '-i', 'tests/db/schema/T-SCH-01_constraints.sql'); Step 'A2' 'T-SCH-01 (P1 regression)' (Has $r 'T-SCH-01_RESULT: PASS') (Summ $r 'T-SCH-01 SUMMARY')
    $r = Sql @('-d', $UC05, '-i', 'tests/db/schema/T-SCH-02_conformance.sql'); Step 'A3' 'T-SCH-02 (P1 regression)' (Has $r 'T-SCH-02_RESULT: PASS') (Summ $r 'T-SCH-02 SUMMARY')
    foreach ($x in @(@('A4', 'db/procedures/usp_P3_CreateInvoice.sql', 'Creation routine (unchanged)', 'usp_P3_CreateInvoice applied'),
                     @('A5', 'tests/db/schema/T-SCH-03_uc05_catalog_and_scope.sql', 'T-SCH-03 creation scope', 'T-SCH-03_RESULT: PASS'),
                     @('A6', 'tests/db/fixtures/F001U__TEST_ONLY_uc05_key_rows.sql', 'F001U TEST_ONLY key rows', 'F001U \(TEST_ONLY\) applied'),
                     @('A7', 'db/procedures/usp_P3_RevenueReports.sql', 'UC06 report routines (unchanged)', 'usp_P3_RevenueReports applied'))) {
        if (-not (Deploy $x[0] $UC05 $x[1] $x[2] $x[3])) { $stopA = $true; break }
    }
}
if (-not $stopA) {
    TestFile 'A8' 'tests/db/functional/T-F05_invoice_creation.sql' "T-F05-CREATE__$ts.txt" 'T-F05 invoice creation incl. rollback after header+lines (T-F05-19), FK violation inside the tx (T-F05-04), caller tx (T-F05-25)' 'T-F05' '^(T-F05 SUMMARY|T-F05_RESULT)'
}

# ================= Stage C =================
Log ''; Log '######## Stage C: UC05 regression and isolated concurrency suites on the final routines ########'
$stopC = -not (Rebuild 'C1')
if (-not $stopC) {
    $r = Sql @('-d', $UC05, '-i', 'tests/db/schema/T-SCH-01_constraints.sql'); Step 'C2' 'T-SCH-01 (P1 regression)' (Has $r 'T-SCH-01_RESULT: PASS') (Summ $r 'T-SCH-01 SUMMARY')
    $r = Sql @('-d', $UC05, '-i', 'tests/db/schema/T-SCH-02_conformance.sql'); Step 'C3' 'T-SCH-02 (P1 regression)' (Has $r 'T-SCH-02_RESULT: PASS') (Summ $r 'T-SCH-02 SUMMARY')
    $stopC = -not (FullDeploy 'C')
}
if (-not $stopC) {
    $dgC = Digest $UC05; Step 'C21' 'Catalog digest of the final routine set (before the tests)' ($dgC -like 'CATALOG_DIGEST|*') $dgC
    Sch06 'C22' 'before the UC05 tests'
    TestFile 'C23' 'tests/db/functional/T-F05S_settlement.sql' "T-F05S-SETTLE__$ts.txt" 'T-F05S settlement/cancellation incl. rollback at the spending and MEMBER steps (T-F05-08), hook faults (T-F05-22), caller tx (T-F05-29)' 'T-F05S' '^(T-F05S SUMMARY|T-F05S_RESULT)'
    V 'C23' 'T-F05S'
    TestFile 'C24' 'tests/db/functional/T-F05-U0_settlement_baseline.sql' "T-F05-U0__$ts.txt" 'T-F05-U0 regression (U0 REFERENCE_ONLY)' 'T-F05-U0' '^(T-F05-U0 SUMMARY|T-F05-U0_RESULT)'
    V 'C24' 'T-F05-U0'
    Conc 'C25' 'tests/db/concurrency/T-CONC-06_parallel_creation.ps1' @('-RunLabel', 'R') "T-CONC-06__${ts}_R.txt" 'T-CONC-06 run R (10 sessions create invoices in parallel)' '^(T-CONC-06 SUMMARY|T-CONC-06_RESULT)'
    V 'C25' 'T-CONC-06 R'
    $i = 26
    foreach ($lbl in 'A', 'B', 'C') {
        Conc "C$i" 'tests/db/concurrency/T-CONC-01_02_parallel_settlement.ps1' @('-Mode', 'SameInvoice', '-RunLabel', $lbl) "T-CONC-01__${ts}_$lbl.txt" "T-CONC-01 run $lbl (10 sessions settle the same invoice; settle-vs-cancel race on every 5th)" '^(  C\d|T-CONC-01 SUMMARY|T-CONC-01_RESULT)'
        V "C$i" "T-CONC-01 $lbl"; $i++
    }
    foreach ($lbl in 'A', 'B', 'C') {
        Conc "C$i" 'tests/db/concurrency/T-CONC-01_02_parallel_settlement.ps1' @('-Mode', 'SameMember', '-RunLabel', $lbl) "T-CONC-02__${ts}_$lbl.txt" "T-CONC-02 run $lbl (10 sessions, different invoices of the same fresh members)" '^(  C\d|T-CONC-02 SUMMARY|T-CONC-02_RESULT)'
        V "C$i" "T-CONC-02 $lbl"; $i++
    }
    TestFile "C$i" 'tests/db/functional/T-F05L_loyalty_tiers.sql' "T-F05L__$ts.txt" 'T-F05L loyalty and tiers incl. failure inside a batch chunk (T-F05-34)' 'T-F05L' '^(L\d|T-F05L SUMMARY|T-F05L_RESULT)'
    V "C$i" 'T-F05L'
    $today = (Get-Date).ToUniversalTime().AddHours(7).ToString('yyyy-MM-dd', $inv)
    RecLoy "C$i" $today 'after T-F05L'; $i++
    foreach ($lbl in 'A', 'B', 'C') {
        Conc "C$i" 'tests/db/concurrency/T-CONC-04F_settlement_vs_tier_batch.ps1' @('-RunLabel', $lbl) "T-CONC-04F__${ts}_$lbl.txt" "T-CONC-04F run $lbl (8 settlement sessions vs 2 tier-batch sessions)" '^(  C\d|T-CONC-04F SUMMARY|T-CONC-04F_RESULT|Final)'
        V "C$i" "T-CONC-04F $lbl"
        RecLoy "C$i" $today "after T-CONC-04F $lbl (ends with a quiescent run)"; $i++
    }
    TestFile "C$i" 'tests/db/reconciliation/T-REC_revenue.sql' "T-REC-05__${ts}_regression.txt" 'T-REC-05 after the concurrency runs: every report routine vs independent reference; revenue = monthly spending' 'T-REC-05' '^(V\d|T-REC-05 SUMMARY|T-REC-05_RESULT)' @('-v', 'SpendingCheck=1'); $i++
    Sch06 "C$i" 'after all stage C tests'; $i++
    $dgC2 = Digest $UC05; Step "C$i" 'Catalog digest after stage C = before (no table, constraint or index changed)' (($dgC2 -eq $dgC) -and ($dgC -like 'CATALOG_DIGEST|*')) $dgC2
}

# ================= Stage W =================
Log ''; Log '######## Stage W: integrated workflow and cross-operation concurrency ########'
$stopW = -not (Rebuild 'W1')
if (-not $stopW) {
    $r = Sql @('-d', $UC05, '-i', 'tests/db/schema/T-SCH-01_constraints.sql'); Step 'W2' 'T-SCH-01 (P1 regression)' (Has $r 'T-SCH-01_RESULT: PASS') (Summ $r 'T-SCH-01 SUMMARY')
    $r = Sql @('-d', $UC05, '-i', 'tests/db/schema/T-SCH-02_conformance.sql'); Step 'W3' 'T-SCH-02 (P1 regression)' (Has $r 'T-SCH-02_RESULT: PASS') (Summ $r 'T-SCH-02 SUMMARY')
    $stopW = -not (FullDeploy 'W')
}
if (-not $stopW) {
    $dgW = Digest $UC05; Step 'W21' 'Catalog digest of the final routine set (before the tests)' (($dgW -like 'CATALOG_DIGEST|*') -and ($dgW -eq $dgC)) "$dgW (= stage C: $($dgW -eq $dgC))"
    Sch06 'W22' 'before the workflow tests'
    TestFile 'W23' 'tests/db/functional/T-WF-01_uc05_uc06_workflow.sql' "T-WF-01__$ts.txt" 'T-WF-01 integrated workflow: creation -> settlement -> spending -> points -> tier -> revenue (final-state checks W1-W11)' 'T-WF-01' '^(W\d+ |T-WF-01 SUMMARY|T-WF-01_RESULT|Created|Tier batch)'
    V 'W23' 'T-WF-01'
    Conc 'W24' 'tests/db/concurrency/T-CONC-04R_reports_vs_settlement.ps1' @() "T-CONC-04R__$ts.txt" 'T-CONC-04R reports vs settlement (no dirty read; rollback/commit; load; SERIALIZABLE multi-statement)' '^(  R\d|  Z|Isolation|T-CONC-04R SUMMARY|T-CONC-04R_RESULT)'
    V 'W24' 'T-CONC-04R'
    Conc 'W25' 'tests/db/concurrency/T-CONC-07_tier_batch_serialisation.ps1' @() "T-CONC-07__$ts.txt" 'T-CONC-07 tier batch vs tier batch (application lock, 51324 timeout, error and client-timeout paths)' '^(  T\d|  Z|T4 OBSERVATION|T-CONC-07 SUMMARY|T-CONC-07_RESULT)'
    V 'W25' 'T-CONC-07'
    Conc 'W25a' 'tests/db/concurrency/T-CONC-08_settle_vs_cancel_ordered.ps1' @() "T-CONC-08__$ts.txt" 'T-CONC-08 settlement vs cancellation of one invoice, both winners forced (3 + 3)' '^(  C\d|  CancelFirst|  SettleFirst|T-CONC-08 SUMMARY|T-CONC-08_RESULT)'
    V 'W25a' 'T-CONC-08'
    $today = (Get-Date).ToUniversalTime().AddHours(7).ToString('yyyy-MM-dd', $inv)
    RecLoy 'W25' $today 'after T-CONC-07 (ends with a quiescent run)'
    TestFile 'W26' 'tests/db/reconciliation/T-REC_revenue.sql' "T-REC-05__${ts}_workflow.txt" 'T-REC-05 after the workflow and cross-operation tests; revenue = monthly spending' 'T-REC-05' '^(V\d|T-REC-05 SUMMARY|T-REC-05_RESULT)' @('-v', 'SpendingCheck=1')
    Sch06 'W27' 'after all stage W tests'
    $dgW2 = Digest $UC05; Step 'W28' 'Catalog digest after stage W = before (no object left behind)' (($dgW2 -eq $dgW) -and ($dgW -like 'CATALOG_DIGEST|*')) $dgW2
}

# ================= Z =================
$fpAfter = Fp; Section 'Z1. Instance fingerprint after' $fpAfter
Step 'Z1' 'Instance fingerprint after = before (FitLife_P3_P1 content, FitLife_P3_P2, FitLife_P3_UC05L and every other database unchanged)' (($fpAfter.Exit -eq 0) -and ((($fpAfter.Lines) -join "`n") -eq (($fpBefore.Lines) -join "`n"))) ''
foreach ($db in 'FitLife_P3_P2', 'FitLife_P3_UC05L') { $ck = Checksum $db; Step "Z-$db" "$db dataset checksum = DS-L run C reference (read only)" ($ck -eq $refLine) $ck }

$nf = @($results | Where-Object { $_.Result -eq 'FAIL' }).Count
$stopped = ($stopA -or $stopC -or $stopW)
Log ''; Log 'Summary:'; foreach ($x in $results) { Log ("  {0,-22} {1}  {2}" -f $x.Id, $x.Result, $x.Descr) }
Log ("P3-03-RUN SUMMARY: steps $($results.Count); FAIL $nf; stage stopped early: $stopped; finished (UTC) $(Utc)")
Log ("P3-03-RUN_RESULT: " + $(if ($nf -eq 0 -and -not $stopped) { 'PASS' } else { 'FAIL' }))
$log | Out-File -Encoding utf8 $logPath
if ($nf -eq 0 -and -not $stopped) { exit 0 } else { exit 1 }
