<#
  run_uc05_settlement_u0.ps1 - TEST_ONLY runner completing WO-P3-P3-01 (task 2, U0). Windows PowerShell 5.1.

     1 instance fingerprint (before)            6 T-F05-U0: T-F05-36, T-F05-37, K01 (own evidence file)
     2 full WO-P3-P3-01 regression: the UNCHANGED 7 V-UC05T whole-database integrity
       runner run_uc05_settlement.ps1 (rebuild,  8 criterion 4: repository code search for U0 callers
       P1 regression, T-F05S, T-CONC-01/02/06,   9 instance fingerprint (after) = before
       V-UC05S; its own evidence files)          10 FitLife_P3_P2 checksum = DS-L run C reference
     3 F002T TEST_ONLY tiers (SYNTHETIC Gold/Platinum thresholds below)
     4 F003H TEST_ONLY paid-history helper
     5 db/reference/usp_P3_SettleInvoice_Baseline.sql (REFERENCE_ONLY U0)
  Changes only FitLife_P3_UC05. No timing is measured (R-27). Machine names are masked.
  Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tests/db/functional/run_uc05_settlement_u0.ps1
#>
param(
    [string]$Server = 'localhost',
    [string]$EvidenceDir = 'docs/phase2/person3/evidence/test-results',
    # TEST_ONLY SYNTHETIC tier thresholds (D-008 values are NOT approved; these are not business values)
    [string]$GoldThreshold = '1000000.00',
    [string]$PlatinumThreshold = '3000000.00'
)
$ErrorActionPreference = 'Continue'
$inv = [Globalization.CultureInfo]::InvariantCulture
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
Set-Location $repo
if (-not [System.IO.Path]::IsPathRooted($EvidenceDir)) { $EvidenceDir = Join-Path $repo $EvidenceDir }
$ts = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmm', $inv)
$logPath = Join-Path $EvidenceDir "UC05U-RUN__$ts.txt"
$u0Path = Join-Path $EvidenceDir "T-F05-U0__$ts.txt"
foreach ($p in @($logPath, $u0Path)) { if (Test-Path $p) { throw "refusing to overwrite $p" } }
$refChecksum = Join-Path $EvidenceDir 'CHECKSUMS__DS-L__20261108-1155_C.txt'

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

$scripts = @('tests/db/functional/run_uc05_settlement.ps1', 'tests/db/fixtures/F002T__TEST_ONLY_member_tier.sql', 'tests/db/fixtures/F003H__TEST_ONLY_paid_history_helper.sql',
             'db/reference/usp_P3_SettleInvoice_Baseline.sql', 'db/procedures/usp_P3_SettleInvoice.sql', 'tests/db/functional/T-F05-U0_settlement_baseline.sql',
             'tests/db/functional/V-UC05T_loyalty_integrity.sql', 'tests/db/functional/run_uc05_settlement_u0.ps1')
Log "UC05U-RUN - WO-P3-P3-01 completion: full settlement regression + task 2 (U0, REFERENCE_ONLY) functional tests and code search"
Log ("Started (UTC): " + (Utc) + "; target FitLife_P3_UC05 (isolated, disposable); FitLife_P3_P1, FitLife_P3_P2 read only")
Log ("TEST_ONLY SYNTHETIC tier thresholds for this run: Silver 0 (approved base-tier rule), Gold $GoldThreshold, Platinum $PlatinumThreshold (NOT business values; D-008 values open)")
Log 'Scripts (SHA-256):'
foreach ($s in $scripts) { Log ("  {0}  {1}" -f (Get-FileHash -Algorithm SHA256 (Join-Path $repo $s)).Hash, $s) }

$fpBefore = Sql @('-v', 'TargetDb=FitLife_P3_UC05', '-i', 'tests/db/build/fingerprint_instance.sql')
Section '1. Instance fingerprint before' $fpBefore
Step '1' 'Instance fingerprint captured before' ($fpBefore.Exit -eq 0) ''

$out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'tests/db/functional/run_uc05_settlement.ps1') 2>&1
$rx = $LASTEXITCODE
Log ''; Log "== 2. WO-P3-P3-01 regression (unchanged runner run_uc05_settlement.ps1; exit $rx) =="
foreach ($l in $out) { if ("$l" -match '^(STEP |UC05S-RUN|Started)') { Log "$l" } }
Step '2' 'Full WO-P3-P3-01 settlement regression on a fresh build (unchanged runner and tests)' ($rx -eq 0) ((@($out | Where-Object { "$_" -like 'UC05S-RUN SUMMARY*' }) -join ''))
$stop = ($rx -ne 0)

if (-not $stop) {
    $r = Sql @('-d', 'FitLife_P3_UC05', '-v', "GoldThreshold=$GoldThreshold", "PlatinumThreshold=$PlatinumThreshold", '-i', 'tests/db/fixtures/F002T__TEST_ONLY_member_tier.sql'); Section '3. F002T TEST_ONLY tiers' $r
    Step '3' 'F002T TEST_ONLY MEMBER_TIER (Silver 0, synthetic Gold/Platinum) + MEMBER.Tier_ID FK, all members on the base tier' (Has $r 'F002T \(TEST_ONLY\) applied') ''
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', 'tests/db/fixtures/F003H__TEST_ONLY_paid_history_helper.sql'); Section '4. F003H TEST_ONLY paid-history helper' $r
    Step '4' 'F003H TEST_ONLY helper' (Has $r 'F003H \(TEST_ONLY\) applied') ''
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', 'db/reference/usp_P3_SettleInvoice_Baseline.sql'); Section '5. U0 reference variant' $r
    Step '5' 'usp_P3_SettleInvoice_Baseline applied (REFERENCE_ONLY)' (Has $r 'usp_P3_SettleInvoice_Baseline applied') ''
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', 'tests/db/functional/T-F05-U0_settlement_baseline.sql')
    $hdr = @("T-F05-U0 - WO-P3-P3-01 task 2 functional tests. Run UC05U-RUN__$ts.", "Executed (UTC): $(Utc); database FitLife_P3_UC05; sqlcmd exit $($r.Exit)", '')
    (($hdr + $r.Lines) | ForEach-Object { Hide $_ }) | Out-File -Encoding utf8 $u0Path
    Log ''; Log "== 6. T-F05-U0: full output in $(Split-Path -Leaf $u0Path) =="
    foreach ($l in ($r.Lines | Where-Object { $_ -match '^(T-F05-U0 SUMMARY|T-F05-U0_RESULT|[UK]\d\d\||Tier configuration)' })) { Log ($l.Substring(0, [Math]::Min(260, $l.Length))) }
    Step '6' 'T-F05-36, T-F05-37 and K01 (U0)' (Has $r 'T-F05-U0_RESULT: PASS') ((@($r.Lines | Where-Object { $_ -like 'T-F05-U0 SUMMARY*' }) -join ''))
    $r = Sql @('-d', 'FitLife_P3_UC05', '-i', 'tests/db/functional/V-UC05T_loyalty_integrity.sql'); Section '7. V-UC05T integrity' $r
    Step '7' 'V-UC05T whole-database integrity after the U0 tests' (Has $r 'V-UC05T_RESULT: PASS') ((@($r.Lines | Where-Object { $_ -like 'V-UC05T SUMMARY*' }) -join ''))

    # 8. criterion 4: repository code search (all files except docs and .git)
    $hits = @(Get-ChildItem -Path $repo -Recurse -File | Where-Object { $_.FullName -notmatch '\\(\.git|docs)\\' } |
              Select-String -Pattern 'SettleInvoice_Baseline' -SimpleMatch | ForEach-Object { ($_.Path.Substring($repo.Length + 1) -replace '\\', '/') + ':' + $_.LineNumber })
    $files = @($hits | ForEach-Object { $_.Split(':')[0] } | Sort-Object -Unique)
    $bad = @($files | Where-Object { $_ -ne 'db/reference/usp_P3_SettleInvoice_Baseline.sql' -and $_ -notlike 'tests/*' })
    Log ''; Log '== 8. Criterion 4 code search: "SettleInvoice_Baseline" in every repository file outside docs/ and .git/ =='
    foreach ($f in $files) { Log ("  {0}  ({1} line(s))" -f $f, @($hits | Where-Object { $_.Split(':')[0] -eq $f }).Count) }
    Log ("  Allowed: the definition in db/reference/ and TEST_ONLY scripts under tests/. Any hit in db/procedures, db/migrations, db/seed or an application path is a failure. Application code in the repository: none.")
    Step '8' 'U0 is not called by any application path or production routine (code search)' ($bad.Count -eq 0 -and $files -contains 'db/reference/usp_P3_SettleInvoice_Baseline.sql') ("files with hits $($files.Count); outside allowed locations $($bad.Count) $($bad -join ', ')")
}

$fpAfter = Sql @('-v', 'TargetDb=FitLife_P3_UC05', '-i', 'tests/db/build/fingerprint_instance.sql')
Section '9. Instance fingerprint after' $fpAfter
Step '9' 'Instance fingerprint after = before (no other database changed)' (($fpAfter.Exit -eq 0) -and ((($fpAfter.Lines) -join "`n") -eq (($fpBefore.Lines) -join "`n"))) ''
$refLine = (Get-Content $refChecksum | Where-Object { $_ -like 'DATASET_CHECKSUM*' } | Select-Object -First 1).Trim()
$ck = Sql @('-d', 'FitLife_P3_P2', '-v', 'MaxGrantPercent=2', '-i', 'tests/db/seed/T-REPRO-02_checksums.sql')
$ckA = (($ck.Lines | Where-Object { $_ -like 'DATASET_CHECKSUM*' } | Select-Object -First 1) + '').Trim()
Section '10. FitLife_P3_P2 dataset checksum (read-only)' $ck
Step '10' 'FitLife_P3_P2 checksum = DS-L run C reference' (($ck.Exit -eq 0) -and ($ckA -eq $refLine)) $ckA

$nf = @($results | Where-Object { $_.Result -eq 'FAIL' }).Count
Log ''; Log 'Summary:'; foreach ($x in $results) { Log ("  {0,-4} {1}  {2}" -f $x.Id, $x.Result, $x.Descr) }
Log ("UC05U-RUN SUMMARY: steps $($results.Count); FAIL $nf; finished (UTC) $(Utc)")
Log ("UC05U-RUN_RESULT: " + $(if ($nf -eq 0 -and -not $stop) { 'PASS' } else { 'FAIL' }))
$log | Out-File -Encoding utf8 $logPath
if ($nf -eq 0 -and -not $stop) { exit 0 } else { exit 1 }
