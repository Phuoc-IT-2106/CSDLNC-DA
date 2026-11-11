<#
  run_p2_dataset.ps1 - TEST_ONLY runner for WO-P3-P2-01 (Windows PowerShell 5.1; no installation needed)

  Builds FitLife_P3_P2 from nothing and generates one dataset profile, then validates it:
    1 preflight (read-only)            6 T-SCH-02 conformance (schema unchanged by seeding)
    2 instance fingerprint (before)    7 T-SEED dataset checks
    3 rebuild FitLife_P3_P2            8 T-REPRO-02 per-table checksums
    4 F001D fixture key rows           9 instance fingerprint (after) = before
    5 S001 generator
  Writes a run log, a checksum file and a dataset manifest into -EvidenceDir. The machine
  name and the SQL Server host name are masked as <local-server> in every file written.

  Usage (from any directory):
    powershell -NoProfile -ExecutionPolicy Bypass -File tests/db/seed/run_p2_dataset.ps1 -Dataset DS-S -RunLabel A
    ... -Dataset DS-L -RunLabel B -CompareWith docs/phase2/person3/evidence/test-results/CHECKSUMS__DS-L__<ts>_A.txt
#>
param(
    [Parameter(Mandatory = $true)][ValidateSet('DS-S', 'DS-M', 'DS-L')][string]$Dataset,
    [string]$RunLabel = 'A',
    [string]$Server = 'localhost',
    [string]$EvidenceDir = 'docs/phase2/person3/evidence/test-results',
    [string]$CompareWith = ''
)
$ErrorActionPreference = 'Continue'
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
Set-Location $repo
$TargetDb = 'FitLife_P3_P2'
if (-not [System.IO.Path]::IsPathRooted($EvidenceDir)) { $EvidenceDir = Join-Path $repo $EvidenceDir }
New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
$ts = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmm', $inv)
$base = "${Dataset}__${ts}_${RunLabel}"
$logPath = Join-Path $EvidenceDir "P2-RUN__$base.txt"
$sumPath = Join-Path $EvidenceDir "CHECKSUMS__$base.txt"
$manPath = Join-Path $EvidenceDir "DATASET-MANIFEST__$base.md"

$profiles = Get-Content -Raw -Encoding UTF8 (Join-Path $repo 'db/seed/profiles.json') | ConvertFrom-Json
$prof = $profiles.$Dataset
function ConvertTo-SqlcmdVars($obj) {
    $list = @()
    foreach ($p in $obj.PSObject.Properties) {
        $v = $p.Value
        if ($v -is [double] -or $v -is [decimal] -or $v -is [single]) { $v = $v.ToString($inv) }
        $list += ('{0}={1}' -f $p.Name, $v)
    }
    return $list
}
$genVars = ConvertTo-SqlcmdVars $prof.generator
$rtVars = ConvertTo-SqlcmdVars $prof.runtime
$valVars = $genVars + (ConvertTo-SqlcmdVars $prof.validation) + $rtVars

# names to mask (never written to any file)
$mask = New-Object System.Collections.Generic.List[string]
if ($env:COMPUTERNAME) { $mask.Add($env:COMPUTERNAME) }
$names = & sqlcmd -S $Server -E -I -b -h -1 -W -Q "SET NOCOUNT ON; SELECT CONVERT(nvarchar(128), SERVERPROPERTY('MachineName')); SELECT CONVERT(nvarchar(128), SERVERPROPERTY('ServerName')); SELECT @@SERVERNAME;" 2>$null
foreach ($n in $names) { $t = "$n".Trim(); if ($t.Length -gt 2) { $mask.Add($t); if ($t.Contains('\')) { $mask.Add($t.Split('\')[0]) } } }
function Hide([string]$s) {
    foreach ($m in ($mask | Sort-Object Length -Descending -Unique)) { $s = [regex]::Replace($s, [regex]::Escape($m), '<local-server>', 'IgnoreCase') }
    return $s
}

$log = New-Object System.Collections.Generic.List[string]
function Log([string]$s) { $log.Add((Hide $s)) }
$results = [ordered]@{}
$timings = [ordered]@{}

function Run-Sql([string]$step, [string[]]$sqlArgs) {
    $start = (Get-Date).ToUniversalTime()
    Log ("---- {0}  (UTC {1})" -f $step, $start.ToString('yyyy-MM-dd HH:mm:ss', $inv))
    Log ("Command: sqlcmd " + ($sqlArgs -join ' '))
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $out = & sqlcmd @sqlArgs 2>&1
    $code = $LASTEXITCODE
    $sw.Stop()
    $lines = @($out | ForEach-Object { "$_" })
    foreach ($l in $lines) { Log $l }
    Log ("exit code: {0}; elapsed_ms: {1}" -f $code, $sw.ElapsedMilliseconds)
    Log ''
    $script:timings[$step] = $sw.ElapsedMilliseconds
    return [pscustomobject]@{ Code = $code; Lines = $lines; Ms = $sw.ElapsedMilliseconds }
}
$common = @('-S', $Server, '-E', '-I', '-b', '-W', '-s', '|')

Log "P2-RUN - WO-P3-P2-01 dataset run. Dataset $Dataset, run label $RunLabel, target $TargetDb. Instance: local default ($Server), Windows authentication. Machine and server names are masked as <local-server>."
Log ("Profile: " + ($genVars -join ' ') + "; runtime: " + ($rtVars -join ' '))
Log ''
$ok = $true

$r = Run-Sql '1 preflight (read-only)' ($common + @('-v', "LocalComputer=$env:COMPUTERNAME", "TargetDb=$TargetDb", '-i', 'tests/db/build/preflight_p2.sql'))
$results['preflight'] = if ($r.Code -eq 0 -and ($r.Lines -match 'PREFLIGHT_P2_RESULT: PASS')) { 'PASS' } else { 'FAIL' }
if ($results['preflight'] -ne 'PASS') { $ok = $false }

if ($ok) {
    $fp1 = Run-Sql '2 instance fingerprint before' ($common + @('-v', "TargetDb=$TargetDb", '-i', 'tests/db/build/fingerprint_instance.sql'))
    $r = Run-Sql '3 rebuild FitLife_P3_P2 (F001 TEST_ONLY, V001, V002)' ($common + @('-i', 'tests/db/build/rebuild_p2_db.sql'))
    if ($r.Code -ne 0 -or -not ($r.Lines -match 'BUILD_RESULT: OK')) { $ok = $false; $results['build'] = 'FAIL' } else { $results['build'] = 'OK' }
}
if ($ok) {
    $r = Run-Sql '4 F001D fixture key rows (TEST_ONLY)' ($common + @('-d', $TargetDb, '-v') + (ConvertTo-SqlcmdVars ($prof.generator | Select-Object MemberCount, BranchCount, EmployeesPerBranch, PlanCount, ProductCount)) + @('-i', 'tests/db/fixtures/F001D__TEST_ONLY_fixture_key_rows.sql'))
    if ($r.Code -ne 0) { $ok = $false; $results['fixture_rows'] = 'FAIL' } else { $results['fixture_rows'] = 'OK' }
}
if ($ok) {
    $gen = Run-Sql '5 S001 generator' ($common + @('-d', $TargetDb, '-v') + $genVars + $rtVars + @('-i', 'db/seed/S001__p3_dataset_generator.sql'))
    if ($gen.Code -ne 0 -or -not ($gen.Lines -match 'GENERATOR_RESULT: OK')) { $ok = $false; $results['generator'] = 'FAIL' } else { $results['generator'] = 'OK' }
}
if ($ok) {
    $r = Run-Sql '6 T-SCH-02 conformance on the seeded database' ($common + @('-d', $TargetDb, '-i', 'tests/db/schema/T-SCH-02_conformance.sql'))
    $results['T-SCH-02'] = if ($r.Code -eq 0 -and ($r.Lines -match 'T-SCH-02_RESULT: PASS')) { 'PASS' } else { 'FAIL' }
    $val = Run-Sql '7 T-SEED dataset checks' ($common + @('-d', $TargetDb, '-v') + $valVars + @('-i', 'tests/db/seed/T-SEED_dataset_checks.sql'))
    $results['T-SEED'] = if ($val.Code -eq 0 -and ($val.Lines -match 'T-SEED_RESULT: PASS')) { 'PASS' } else { 'FAIL' }
    $chk = Run-Sql '8 T-REPRO-02 checksums' ($common + @('-d', $TargetDb, '-v') + $rtVars + @('-i', 'tests/db/seed/T-REPRO-02_checksums.sql'))
    $results['checksums'] = if ($chk.Code -eq 0) { 'OK' } else { 'FAIL' }
    ($chk.Lines | ForEach-Object { Hide $_ }) | Out-File -Encoding utf8 $sumPath
    $fp2 = Run-Sql '9 instance fingerprint after' ($common + @('-v', "TargetDb=$TargetDb", '-i', 'tests/db/build/fingerprint_instance.sql'))
    $same = (($fp1.Lines -join "`n") -eq ($fp2.Lines -join "`n"))
    $results['other_databases_unchanged'] = if ($same) { 'PASS' } else { 'FAIL' }
    Log ("FINGERPRINT_COMPARE: " + $(if ($same) { 'IDENTICAL (no other database changed)' } else { 'DIFFERENT - see steps 2 and 9' }))
    if ($CompareWith) {
        $other = Get-Content -Encoding UTF8 $CompareWith
        $mine = Get-Content -Encoding UTF8 $sumPath
        $eq = (($other -join "`n") -eq ($mine -join "`n"))
        $results['T-REPRO-02 vs ' + (Split-Path $CompareWith -Leaf)] = if ($eq) { 'PASS' } else { 'FAIL' }
        Log ("T-REPRO-02 compare with {0}: {1}" -f (Split-Path $CompareWith -Leaf), $(if ($eq) { 'IDENTICAL' } else { 'DIFFERENT' }))
    }
}

$overall = if ($ok -and -not ($results.Values -contains 'FAIL')) { 'PASS' } else { 'FAIL' }
Log ("RESULTS: " + (($results.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '; '))
Log ("P2-RUN_RESULT: $overall")
$log | Out-File -Encoding utf8 $logPath

# ---------- manifest ----------
$scripts = @('db/seed/S001__p3_dataset_generator.sql', 'db/seed/profiles.json', 'tests/db/fixtures/F001D__TEST_ONLY_fixture_key_rows.sql',
             'tests/db/build/rebuild_p2_db.sql', 'tests/db/fixtures/F001__TEST_ONLY_shared_dependency_keys.sql',
             'db/migrations/V001__p3_billing_and_spending_tables.sql', 'db/migrations/V002__p3_settlement_and_spending_constraints.sql',
             'tests/db/seed/T-SEED_dataset_checks.sql', 'tests/db/seed/T-REPRO-02_checksums.sql', 'tests/db/seed/run_p2_dataset.ps1')
$m = New-Object System.Collections.Generic.List[string]
$m.Add("# Dataset manifest - $Dataset, run $RunLabel")
$m.Add('')
$m.Add('| Field | Value |'); $m.Add('|---|---|')
$m.Add("| Work order | WO-P3-P2-01 (BUILD_AUTHORIZED) |")
$m.Add("| Run (UTC) | $ts |")
$m.Add("| Purpose | $($prof.purpose) |")
$m.Add("| Target database | $TargetDb (isolated, disposable; P3_Disposable marker WO-P3-P2-01) |")
$m.Add("| Instance | local default instance, Windows authentication (identity in the run log, step 1) |")
$m.Add("| Generator | S001 v1.0 (set-based T-SQL; SHA-256 seeded streams) |")
$m.Add("| Overall result | **$overall** |")
$m.Add("| Run log | P2-RUN__$base.txt |")
$m.Add("| Checksums | CHECKSUMS__$base.txt |")
$m.Add('')
$m.Add('## Parameters'); $m.Add('')
$m.Add('| Parameter | Value |'); $m.Add('|---|---|')
foreach ($p in $prof.generator.PSObject.Properties) { $v = $p.Value; if ($v -is [double]) { $v = $v.ToString($inv) }; $m.Add("| $($p.Name) | $v |") }
foreach ($p in $prof.runtime.PSObject.Properties) { $m.Add("| (runtime) $($p.Name) | $($p.Value) |") }
foreach ($p in $prof.validation.PSObject.Properties) { $v = $p.Value; if ($v -is [double]) { $v = $v.ToString($inv) }; $m.Add("| (validation) $($p.Name) | $v |") }
$m.Add('')
$m.Add('## Results'); $m.Add('')
$m.Add('| Step | Result |'); $m.Add('|---|---|')
foreach ($k in $results.Keys) { $m.Add("| $k | $($results[$k]) |") }
$m.Add('')
$m.Add('## Timings (ms, wall clock of each sqlcmd call)'); $m.Add('')
$m.Add('| Step | ms |'); $m.Add('|---|---|')
foreach ($k in $timings.Keys) { $m.Add("| $k | $($timings[$k]) |") }
if ($gen) { foreach ($l in ($gen.Lines | Where-Object { $_ -match '^TIMING ' })) { $m.Add("| (generator) $($l.Substring(7)) |  |") } }
$m.Add('')
$m.Add('## Row counts and checksums'); $m.Add('')
$m.Add('```text'); foreach ($l in (Get-Content -Encoding UTF8 $sumPath -ErrorAction SilentlyContinue)) { $m.Add($l) }; $m.Add('```')
$m.Add('')
$m.Add('## Script versions (SHA-256)'); $m.Add('')
$m.Add('| File | SHA-256 |'); $m.Add('|---|---|')
foreach ($s in $scripts) { $h = (Get-FileHash -Algorithm SHA256 (Join-Path $repo $s)).Hash.ToLowerInvariant(); $m.Add("| ``$s`` | ``$h`` |") }
$m.Add('')
$m.Add('## Reproduce'); $m.Add('')
$m.Add('```text')
$m.Add("powershell -NoProfile -ExecutionPolicy Bypass -File tests/db/seed/run_p2_dataset.ps1 -Dataset $Dataset -RunLabel <label> -CompareWith <this run's CHECKSUMS file>")
$m.Add('```')
$m.Add('Same seed and profile give byte-identical checksum output (T-REPRO-02). Storage and distribution reports are in the run log, step 7.')
($m | ForEach-Object { Hide $_ }) | Out-File -Encoding utf8 $manPath

Write-Output ("P2-RUN_RESULT: {0}  log={1}" -f $overall, (Split-Path $logPath -Leaf))
foreach ($k in $results.Keys) { Write-Output ("  {0} = {1}" -f $k, $results[$k]) }
if ($overall -ne 'PASS') { exit 1 } else { exit 0 }
