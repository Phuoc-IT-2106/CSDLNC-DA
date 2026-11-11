<#
  run_uc05_loyalty.ps1 - TEST_ONLY runner for WO-P3-P3-02 (Windows PowerShell 5.1; nothing installed).

  Stage 1 - FitLife_P3_UC05 (fixtures):
     1 fingerprint before   2 FitLife_P3_P2 checksum before   3 rebuild   4-5 T-SCH-01/02 (P1 regression)
     6-13 creation routine, T-SCH-03, F001U, F002P, D001 doubles, settle, cancel, T-SCH-04 (P3-00/01 deployment)
     14 F002T (TEST_ONLY SYNTHETIC thresholds)   15 F003H helper   16 U0 (REFERENCE_ONLY)
     17 V003   18 usp_P3_EvaluateTiers + tier functions   19 usp_P3_GetMemberLoyalty   20 T-SCH-05
     21 T-F05S (settlement regression) + V-UC05T   22 T-F05-U0 (P3-01 task 2 regression) + V-UC05T
     23 T-CONC-06 R, 24 T-CONC-01 A, 25 T-CONC-02 A (regression) + V-UC05T after each
     26 T-F05L loyalty tests + V-UC05T + T-REC (today)   27 T-CONC-04F A/B/C + V-UC05T + T-REC after each
     28 T-SCH-05 again
  Stage 2 - FitLife_P3_UC05L (DS-L copy, approved 2026-11-09):
     29 rebuild   30 F001D + 31 S001 with the DS-L profile (unchanged generator)   32 dataset checksum = run C
     33 F002P   34 F002T   35 L001 loader   36 task 0: B0 capture of Q-UC05-B/C (plans, logical reads; no timing)
     37 V003 (validated WITH CHECK on DS-L)   38 loyalty routines
     39-41 batch as of 2025-12-31, T-REC, re-run = 0 changes
     42-44 batch as of 2026-01-15 (January 2025 leaves the window; no new payment), T-REC, re-run = 0 changes
     45 dataset checksum again = run C (P3 tables untouched by the loyalty work)
  46 fingerprint after = before (FitLife_P3_UC05 and FitLife_P3_UC05L excluded)   47 FitLife_P3_P2 checksum after
  Changes only FitLife_P3_UC05 and FitLife_P3_UC05L. No timing is a measurement (R-27). Names are masked.
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
$logPath = Join-Path $EvidenceDir "UC05LOY-RUN__$ts.txt"
foreach ($p in @($logPath)) { if (Test-Path $p) { throw "refusing to overwrite $p" } }
$refChecksum = Join-Path $repo 'docs/phase2/person3/evidence/test-results/CHECKSUMS__DS-L__20261108-1155_C.txt'
$refLine = (Get-Content $refChecksum | Where-Object { $_ -like 'DATASET_CHECKSUM*' } | Select-Object -First 1).Trim()

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
function Fp { $r = Sql @('-v', 'TargetDb=FitLife_P3_UC05', '-i', 'tests/db/build/fingerprint_instance.sql'); return [pscustomobject]@{ Exit = $r.Exit; Lines = @($r.Lines | Where-Object { $_ -notlike 'FitLife_P3_UC05L|*' }) } }
function DeployUC05([string]$id, [string]$file, [string]$descr, [string]$pattern, [string[]]$extra = @()) {
    # Section/Step write to the console; $null = keeps that text out of the return value (the boolean only).
    $r = Sql (@('-d', 'FitLife_P3_UC05') + $extra + @('-i', $file)); $null = Section "$id. $descr" $r
    $ok = Has $r $pattern; $null = Step $id $descr $ok ''; return $ok
}
function V([string]$id, [string]$after) {
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', 'tests/db/functional/V-UC05T_loyalty_integrity.sql'); Section "$id. V-UC05T after $after" $r
    Step "$id-V" "V-UC05T after $after" (Has $r 'V-UC05T_RESULT: PASS') (Summ $r 'V-UC05T SUMMARY')
}
function Rec([string]$id, [string]$db, [string]$asOf, [string]$after) {
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
function TestFile([string]$id, [string]$file, [string]$evName, [string]$descr, [string]$prefix, [string]$linePattern) {
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', $file)
    $hdr = @("$descr. Run UC05LOY-RUN__$ts.", "Executed (UTC): $(Utc); database FitLife_P3_UC05; script $file (SHA-256 $((Get-FileHash -Algorithm SHA256 (Join-Path $repo $file)).Hash)); sqlcmd exit $($r.Exit)", '')
    (($hdr + $r.Lines) | ForEach-Object { Hide $_ }) | Out-File -Encoding utf8 (Join-Path $EvidenceDir $evName)
    Log ''; Log "== $id. ${descr}: full output in $evName =="
    foreach ($l in ($r.Lines | Where-Object { $_ -match $linePattern })) { Log ($l.Substring(0, [Math]::Min(260, $l.Length))) }
    Step $id $descr (Has $r "${prefix}_RESULT: PASS") (Summ $r "$prefix SUMMARY")
}
function Eval([string]$id, [string]$db, [string]$asOf, [string]$descr) {
    $q = "SET NOCOUNT ON; DECLARE @e int, @u int, @d int, @n int; EXEC dbo.usp_P3_EvaluateTiers @AsOfDate = '$asOf', @Evaluated = @e OUTPUT, @Upgrades = @u OUTPUT, @Downgrades = @d OUTPUT, @Unchanged = @n OUTPUT; PRINT CONCAT('EVAL|', '$asOf', '|', @e, '|', @u, '|', @d, '|', @n);"
    $r = Sql @('-d', $db, '-Q', $q); $null = Section "$id. usp_P3_EvaluateTiers in $db as of $asOf" $r
    $line = @($r.Lines | Where-Object { $_ -like 'EVAL|*' }) | Select-Object -First 1
    $p = "$line".Split('|')
    $o = [pscustomobject]@{ Ok = ($r.Exit -eq 0 -and $p.Count -eq 6); Ev = $(if ($p.Count -eq 6) { [int]$p[2] } else { -1 }); Up = $(if ($p.Count -eq 6) { [int]$p[3] } else { -1 }); Down = $(if ($p.Count -eq 6) { [int]$p[4] } else { -1 }) }
    return $o
}

$scripts = @('tests/db/build/rebuild_uc05_db.sql', 'tests/db/build/rebuild_uc05l_db.sql', 'db/migrations/V001__p3_billing_and_spending_tables.sql', 'db/migrations/V002__p3_settlement_and_spending_constraints.sql',
             'db/migrations/V003__p3_points_earned_rule.sql', 'db/procedures/usp_P3_CreateInvoice.sql', 'db/procedures/usp_P3_SettleInvoice.sql', 'db/procedures/usp_P3_CancelInvoice.sql',
             'db/procedures/usp_P3_EvaluateTiers.sql', 'db/procedures/usp_P3_GetMemberLoyalty.sql', 'db/reference/usp_P3_SettleInvoice_Baseline.sql',
             'db/queries/baseline/Q-UC05-B.sql', 'db/queries/baseline/Q-UC05-C.sql', 'db/seed/S001__p3_dataset_generator.sql',
             'tests/db/fixtures/F001U__TEST_ONLY_uc05_key_rows.sql', 'tests/db/fixtures/F001D__TEST_ONLY_fixture_key_rows.sql', 'tests/db/fixtures/F002P__TEST_ONLY_member_current_points.sql',
             'tests/db/fixtures/F002T__TEST_ONLY_member_tier.sql', 'tests/db/fixtures/F003H__TEST_ONLY_paid_history_helper.sql', 'tests/db/fixtures/L001__TEST_ONLY_dsl_loyalty_state.sql',
             'tests/db/doubles/D001__TEST_ONLY_settlement_hook_doubles.sql', 'tests/db/schema/T-SCH-04_settlement_catalog_and_scope.sql', 'tests/db/schema/T-SCH-05_loyalty_catalog_and_scope.sql',
             'tests/db/functional/T-F05S_settlement.sql', 'tests/db/functional/T-F05-U0_settlement_baseline.sql', 'tests/db/functional/T-F05L_loyalty_tiers.sql',
             'tests/db/functional/V-UC05T_loyalty_integrity.sql', 'tests/db/reconciliation/T-REC_loyalty.sql', 'tests/db/concurrency/T-CONC-04F_settlement_vs_tier_batch.ps1',
             'tests/db/concurrency/T-CONC-01_02_parallel_settlement.ps1', 'tests/db/concurrency/T-CONC-06_parallel_creation.ps1', 'tests/db/loyalty/capture_q_uc05_bc_b0.ps1',
             'tests/db/functional/run_uc05_loyalty.ps1')
Log "UC05LOY-RUN - WO-P3-P3-02 incremental loyalty and tier evaluation: build, regression, functional, concurrency, reconciliation (fixtures and DS-L)"
Log ("Started (UTC): " + (Utc) + "; databases changed: FitLife_P3_UC05, FitLife_P3_UC05L (isolated, disposable); FitLife_P3_P1 and FitLife_P3_P2 read only")
Log ("TEST_ONLY SYNTHETIC tier thresholds: Silver 0 (approved base rule), Gold $GoldThreshold, Platinum $PlatinumThreshold - NOT business values (D-008 values open)")
Log 'Scripts (SHA-256):'
foreach ($s in $scripts) { Log ("  {0}  {1}" -f (Get-FileHash -Algorithm SHA256 (Join-Path $repo $s)).Hash, $s) }

$fpBefore = Fp; Section '1. Instance fingerprint before (FitLife_P3_UC05 and FitLife_P3_UC05L excluded)' $fpBefore
Step '1' 'Instance fingerprint captured before' ($fpBefore.Exit -eq 0) ''
$ck = Sql @('-d', 'FitLife_P3_P2', '-v', 'MaxGrantPercent=2', '-i', 'tests/db/seed/T-REPRO-02_checksums.sql')
$ckB = ((@($ck.Lines | Where-Object { $_ -like 'DATASET_CHECKSUM*' }) | Select-Object -First 1) + '').Trim()
Step '2' 'FitLife_P3_P2 checksum before = DS-L run C reference' (($ck.Exit -eq 0) -and ($ckB -eq $refLine)) $ckB

# ================= Stage 1 =================
$r = Sql @('-i', 'tests/db/build/rebuild_uc05_db.sql'); Section '3. Rebuild FitLife_P3_UC05' $r
$stop = -not (Has $r 'BUILD_RESULT: OK'); Step '3' 'Fresh FitLife_P3_UC05 (F001, V001, V002)' (-not $stop) ''
if (-not $stop) {
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', 'tests/db/schema/T-SCH-01_constraints.sql'); Step '4' 'T-SCH-01 (P1 regression)' (Has $r 'T-SCH-01_RESULT: PASS') (Summ $r 'T-SCH-01 SUMMARY')
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', 'tests/db/schema/T-SCH-02_conformance.sql'); Step '5' 'T-SCH-02 (P1 regression)' (Has $r 'T-SCH-02_RESULT: PASS') (Summ $r 'T-SCH-02 SUMMARY')
    $d = @(
        @('6', 'db/procedures/usp_P3_CreateInvoice.sql', 'Creation routine (unchanged)', 'usp_P3_CreateInvoice applied', @()),
        @('7', 'tests/db/schema/T-SCH-03_uc05_catalog_and_scope.sql', 'T-SCH-03 creation scope', 'T-SCH-03_RESULT: PASS', @()),
        @('8', 'tests/db/fixtures/F001U__TEST_ONLY_uc05_key_rows.sql', 'F001U TEST_ONLY key rows', 'F001U \(TEST_ONLY\) applied', @()),
        @('9', 'tests/db/fixtures/F002P__TEST_ONLY_member_current_points.sql', 'F002P TEST_ONLY CurrentPoints', 'F002P \(TEST_ONLY\) applied', @()),
        @('10', 'tests/db/doubles/D001__TEST_ONLY_settlement_hook_doubles.sql', 'D001 TEST_ONLY hook doubles', 'D001 \(TEST_ONLY\) applied', @()),
        @('11', 'db/procedures/usp_P3_SettleInvoice.sql', 'Settlement routine (unchanged)', 'usp_P3_SettleInvoice applied', @()),
        @('12', 'db/procedures/usp_P3_CancelInvoice.sql', 'Cancellation routine (unchanged)', 'usp_P3_CancelInvoice applied', @()),
        @('13', 'tests/db/schema/T-SCH-04_settlement_catalog_and_scope.sql', 'T-SCH-04 settlement scope (before loyalty objects)', 'T-SCH-04_RESULT: PASS', @()),
        @('14', 'tests/db/fixtures/F002T__TEST_ONLY_member_tier.sql', 'F002T TEST_ONLY tiers (synthetic thresholds)', 'F002T \(TEST_ONLY\) applied', @('-v', "GoldThreshold=$GoldThreshold", "PlatinumThreshold=$PlatinumThreshold")),
        @('15', 'tests/db/fixtures/F003H__TEST_ONLY_paid_history_helper.sql', 'F003H TEST_ONLY paid-history helper', 'F003H \(TEST_ONLY\) applied', @()),
        @('16', 'db/reference/usp_P3_SettleInvoice_Baseline.sql', 'U0 REFERENCE_ONLY', 'usp_P3_SettleInvoice_Baseline applied', @()),
        @('17', 'db/migrations/V003__p3_points_earned_rule.sql', 'V003 point-rule CHECK', 'V003 applied', @()),
        @('18', 'db/procedures/usp_P3_EvaluateTiers.sql', 'usp_P3_EvaluateTiers + tier functions', 'usp_P3_EvaluateTiers applied', @()),
        @('19', 'db/procedures/usp_P3_GetMemberLoyalty.sql', 'usp_P3_GetMemberLoyalty', 'usp_P3_GetMemberLoyalty applied', @()),
        @('20', 'tests/db/schema/T-SCH-05_loyalty_catalog_and_scope.sql', 'T-SCH-05 catalog, inventory, loyalty write scope, no hard-coded thresholds, approved routines unchanged', 'T-SCH-05_RESULT: PASS', @()))
    foreach ($x in $d) { if (-not (DeployUC05 $x[0] $x[1] $x[2] $x[3] $x[4])) { $stop = $true; break } }
}
if (-not $stop) {
    TestFile '21' 'tests/db/functional/T-F05S_settlement.sql' "T-F05S-SETTLE__$ts.txt" 'T-F05S settlement regression (47 cases)' 'T-F05S' '^(T-F05S SUMMARY|T-F05S_RESULT)'
    V '21' 'T-F05S'
    TestFile '22' 'tests/db/functional/T-F05-U0_settlement_baseline.sql' "T-F05-U0__$ts.txt" 'T-F05-U0 regression (T-F05-36, T-F05-37, K01)' 'T-F05-U0' '^(T-F05-U0 SUMMARY|T-F05-U0_RESULT)'
    V '22' 'T-F05-U0'
    Conc '23' 'tests/db/concurrency/T-CONC-06_parallel_creation.ps1' @('-RunLabel', 'R') "T-CONC-06__${ts}_R.txt" 'T-CONC-06 run R (creation regression)' '^(T-CONC-06 SUMMARY|T-CONC-06_RESULT)'
    V '23' 'T-CONC-06 R'
    Conc '24' 'tests/db/concurrency/T-CONC-01_02_parallel_settlement.ps1' @('-Mode', 'SameInvoice', '-RunLabel', 'A') "T-CONC-01__${ts}_A.txt" 'T-CONC-01 run A (settlement regression)' '^(T-CONC-01 SUMMARY|T-CONC-01_RESULT)'
    V '24' 'T-CONC-01 A'
    Conc '25' 'tests/db/concurrency/T-CONC-01_02_parallel_settlement.ps1' @('-Mode', 'SameMember', '-RunLabel', 'A') "T-CONC-02__${ts}_A.txt" 'T-CONC-02 run A (concurrent payments, same member)' '^(T-CONC-02 SUMMARY|T-CONC-02_RESULT)'
    V '25' 'T-CONC-02 A'
    TestFile '26' 'tests/db/functional/T-F05L_loyalty_tiers.sql' "T-F05L__$ts.txt" 'T-F05L loyalty tests (T-F05-12...-15, -32...-35)' 'T-F05L' '^(L\d|T-F05L SUMMARY|T-F05L_RESULT)'
    V '26' 'T-F05L'
    $today = (Get-Date).ToUniversalTime().AddHours(7).ToString('yyyy-MM-dd', $inv)
    Rec '26' 'FitLife_P3_UC05' $today 'after T-F05L, whose last step evaluates today'
    foreach ($label in @('A', 'B', 'C')) {
        Conc "27$label" 'tests/db/concurrency/T-CONC-04F_settlement_vs_tier_batch.ps1' @('-RunLabel', $label) "T-CONC-04F__${ts}_$label.txt" "T-CONC-04F run $label (settlement concurrent with the tier batch)" '^(  C\d|T-CONC-04F SUMMARY|T-CONC-04F_RESULT|Final)'
        V "27$label" "T-CONC-04F $label"
        Rec "27$label" 'FitLife_P3_UC05' $today "after T-CONC-04F $label (ends with a quiescent run)"
    }
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', 'tests/db/schema/T-SCH-05_loyalty_catalog_and_scope.sql'); Section '28. T-SCH-05 again' $r
    Step '28' 'T-SCH-05 after all tests (no leftover object, principal or permission; approved routines unchanged)' (Has $r 'T-SCH-05_RESULT: PASS') (Summ $r 'T-SCH-05 SUMMARY')
}

# ================= Stage 2 (DS-L) =================
$stop2 = $false
$r = Sql @('-i', 'tests/db/build/rebuild_uc05l_db.sql'); Section '29. Rebuild FitLife_P3_UC05L' $r
if (-not (Has $r 'BUILD_RESULT: OK')) { $stop2 = $true }; Step '29' 'Fresh FitLife_P3_UC05L (F001, V001, V002)' (-not $stop2) ''
if (-not $stop2) {
    $profiles = Get-Content -Raw -Encoding UTF8 (Join-Path $repo 'db/seed/profiles.json') | ConvertFrom-Json
    $prof = $profiles.'DS-L'
    function ToVars($obj) { $l = @(); foreach ($p in $obj.PSObject.Properties) { $v = $p.Value; if ($v -is [double] -or $v -is [decimal]) { $v = $v.ToString($inv) }; $l += ('{0}={1}' -f $p.Name, $v) }; return $l }
    $gen = ToVars $prof.generator; $rt = ToVars $prof.runtime
    $r = Sql (@('-d', 'FitLife_P3_UC05L', '-v') + (ToVars ($prof.generator | Select-Object MemberCount, BranchCount, EmployeesPerBranch, PlanCount, ProductCount)) + @('-i', 'tests/db/fixtures/F001D__TEST_ONLY_fixture_key_rows.sql'))
    Step '30' 'F001D key rows (DS-L profile)' ($r.Exit -eq 0) ''
    Log ("== 31. S001 generator, DS-L profile: " + ($gen -join ' ') + " (UTC start $(Utc)) ==")
    $r = Sql (@('-d', 'FitLife_P3_UC05L', '-v') + $gen + $rt + @('-i', 'db/seed/S001__p3_dataset_generator.sql'))
    foreach ($l in ($r.Lines | Select-Object -Last 8)) { Log $l }
    Step '31' 'S001 DS-L generation (unchanged generator)' (Has $r 'GENERATOR_RESULT: OK') ''
    $c1 = Sql @('-d', 'FitLife_P3_UC05L', '-v', 'MaxGrantPercent=2', '-i', 'tests/db/seed/T-REPRO-02_checksums.sql')
    $c1l = ((@($c1.Lines | Where-Object { $_ -like 'DATASET_CHECKSUM*' }) | Select-Object -First 1) + '').Trim()
    Step '32' 'FitLife_P3_UC05L dataset checksum = DS-L run C reference (same data as the accepted dataset)' (($c1.Exit -eq 0) -and ($c1l -eq $refLine)) $c1l
    if ($c1l -ne $refLine) { $stop2 = $true }
}
if (-not $stop2) {
    $r = Sql @('-d', 'FitLife_P3_UC05L', '-i', 'tests/db/fixtures/F002P__TEST_ONLY_member_current_points.sql'); Step '33' 'F002P on DS-L copy' (Has $r 'F002P \(TEST_ONLY\) applied') ''
    $r = Sql @('-d', 'FitLife_P3_UC05L', '-v', "GoldThreshold=$GoldThreshold", "PlatinumThreshold=$PlatinumThreshold", '-i', 'tests/db/fixtures/F002T__TEST_ONLY_member_tier.sql'); Step '34' 'F002T on DS-L copy (synthetic thresholds)' (Has $r 'F002T \(TEST_ONLY\) applied') ''
    $r = Sql @('-d', 'FitLife_P3_UC05L', '-i', 'tests/db/fixtures/L001__TEST_ONLY_dsl_loyalty_state.sql'); Section '35. L001 TEST_ONLY loader' $r; Step '35' 'L001 CurrentPoints = SUM(PointsEarned)' (Has $r 'L001 \(TEST_ONLY\) applied') ''
    $t0Path = Join-Path $EvidenceDir "T0-QUC05BC__$ts.txt"
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'tests/db/loyalty/capture_q_uc05_bc_b0.ps1') -RunTs $ts -OutFile $t0Path -PlanDir (Join-Path (Split-Path $EvidenceDir) 'execution-plans') 2>&1
    $cx = $LASTEXITCODE
    if (Test-Path $t0Path) { $c = Get-Content $t0Path; ($c | ForEach-Object { Hide $_ }) | Out-File -Encoding utf8 $t0Path }
    Log ''; Log "== 36. Task 0 B0 capture (exit $cx): full output in $(Split-Path -Leaf $t0Path) =="
    foreach ($l in $out) { if ("$l" -match '^(==|   rows|   logical reads|T0-)') { Log "$l" } }
    Step '36' 'Task 0: Q-UC05-B/C frozen and captured on DS-L before any loyalty routine or index (plans, logical reads; no timing)' ($cx -eq 0) ''
    $r = Sql @('-d', 'FitLife_P3_UC05L', '-i', 'db/migrations/V003__p3_points_earned_rule.sql'); Step '37' 'V003 validated WITH CHECK on all DS-L monthly rows' (Has $r 'V003 applied') ''
    $r1 = Sql @('-d', 'FitLife_P3_UC05L', '-i', 'db/procedures/usp_P3_EvaluateTiers.sql'); $r2 = Sql @('-d', 'FitLife_P3_UC05L', '-i', 'db/procedures/usp_P3_GetMemberLoyalty.sql')
    Step '38' 'Loyalty routines deployed on the DS-L copy' ((Has $r1 'usp_P3_EvaluateTiers applied') -and (Has $r2 'usp_P3_GetMemberLoyalty applied')) ''
    $e1 = Eval '39' 'FitLife_P3_UC05L' '2025-12-31' 'all twelve 2025 months'
    Step '39' 'Batch on DS-L as of 2025-12-31 (window Jan..Dec 2025)' $e1.Ok "evaluated $($e1.Ev); upgrades $($e1.Up); downgrades $($e1.Down)"
    Rec '40' 'FitLife_P3_UC05L' '2025-12-31' 'after the batch'
    $e2 = Eval '41' 'FitLife_P3_UC05L' '2025-12-31' 're-run'
    Step '41' 'Re-run for 2025-12-31 changes nothing (T-F05-14 on DS-L)' ($e2.Ok -and $e2.Up -eq 0 -and $e2.Down -eq 0) "upgrades $($e2.Up); downgrades $($e2.Down)"
    $e3 = Eval '42' 'FitLife_P3_UC05L' '2026-01-15' 'January 2025 leaves the window'
    Step '42' 'Batch as of 2026-01-15 (Feb 2025..Jan 2026; no new payment): only downgrades, no upgrade' ($e3.Ok -and $e3.Up -eq 0 -and $e3.Down -ge 1) "evaluated $($e3.Ev); upgrades $($e3.Up); downgrades $($e3.Down)"
    Rec '43' 'FitLife_P3_UC05L' '2026-01-15' 'after the no-payment downgrade run'
    $e4 = Eval '44' 'FitLife_P3_UC05L' '2026-01-15' 're-run'
    Step '44' 'Re-run for 2026-01-15 changes nothing' ($e4.Ok -and $e4.Up -eq 0 -and $e4.Down -eq 0) "upgrades $($e4.Up); downgrades $($e4.Down)"
    $c2 = Sql @('-d', 'FitLife_P3_UC05L', '-v', 'MaxGrantPercent=2', '-i', 'tests/db/seed/T-REPRO-02_checksums.sql')
    $c2l = ((@($c2.Lines | Where-Object { $_ -like 'DATASET_CHECKSUM*' }) | Select-Object -First 1) + '').Trim()
    Step '45' 'FitLife_P3_UC05L dataset checksum unchanged by the loyalty work (= run C)' (($c2.Exit -eq 0) -and ($c2l -eq $refLine)) $c2l
}

$fpAfter = Fp; Section '46. Instance fingerprint after' $fpAfter
Step '46' 'Instance fingerprint after = before (no other database changed)' (($fpAfter.Exit -eq 0) -and ((($fpAfter.Lines) -join "`n") -eq (($fpBefore.Lines) -join "`n"))) ''
$ck = Sql @('-d', 'FitLife_P3_P2', '-v', 'MaxGrantPercent=2', '-i', 'tests/db/seed/T-REPRO-02_checksums.sql')
$ckA = ((@($ck.Lines | Where-Object { $_ -like 'DATASET_CHECKSUM*' }) | Select-Object -First 1) + '').Trim()
Step '47' 'FitLife_P3_P2 checksum after = before = run C' (($ck.Exit -eq 0) -and ($ckA -eq $refLine) -and ($ckA -eq $ckB)) $ckA

$nf = @($results | Where-Object { $_.Result -eq 'FAIL' }).Count
Log ''; Log 'Summary:'; foreach ($x in $results) { Log ("  {0,-6} {1}  {2}" -f $x.Id, $x.Result, $x.Descr) }
Log ("UC05LOY-RUN SUMMARY: steps $($results.Count); FAIL $nf; finished (UTC) $(Utc)")
Log ("UC05LOY-RUN_RESULT: " + $(if ($nf -eq 0 -and -not $stop -and -not $stop2) { 'PASS' } else { 'FAIL' }))
$log | Out-File -Encoding utf8 $logPath
if ($nf -eq 0 -and -not $stop -and -not $stop2) { exit 0 } else { exit 1 }
