<#
  run_e6_bm1_standalone.ps1 - standalone operator runner for WO-P3-P0-02 task 11 (amended 2026-11-10): the single E6
  (R-27 closure) campaign on BM-1, started by the Owner from a plain Windows PowerShell 5.1 window while VS Code and
  Claude Code are closed. Not part of the measurement method.

  What it does
    1. Fixed preconditions (checked twice: at start and again right before launch):
       tooling and pinned SHA-256 of the reviewed harness files (A6); exact instance identity (service MSSQLSERVER01 on
       this computer, engine 17.0.1000.7, EngineEdition 2); BM-1 configuration in use = A3 (min 1,024 / max 2,048 MB)
       and E4 values (MAXDOP 8, cost threshold 5, ad hoc 0); FitLife_P3_P2 ONLINE, read-write, compatibility 160, marker
       WO-P3-P2-01, V003 trusted, B0 inventory unchanged; FitLife_P3_Probe absent; the single BM-1 campaign unused;
       A4 power mode "Best performance"; A5 VS Code / Claude Code closed; no other sqlcmd, request or session on the DB.
    2. Bounded wait (E1/E2): AC online, no power event for CleanMinutes, available RAM (Windows and SQL Server view)
       >= WaitTargetMb (>= 2,048), process_physical_memory_low = 0, query-memory semaphore target >= 256 MB.
    3. Only if everything passes: writes a campaign lock and runs the UNCHANGED harness r27_e6_probe.ps1 once with its
       default thresholds and sampling (-Server localhost\MSSQLSERVER01). The harness re-checks its own preconditions
       and writes all raw evidence (R-27-CLOSE__<ts>*, R-27-DIAG__<ts>*).
    4. Records RUN_ID, harness exit code, evidence file hashes, the configuration after the run and E6_BM1_RESULT.

  What it never does: change any SQL Server or Windows setting (including memory and power mode), start or stop a
  service, close an application, clear a cache, create/alter/drop any database or object, rerun DS-L, feature probes or
  migrations, or touch the default instance MSSQLSERVER. Every SQL statement here is a SELECT.

  Exit codes: 0 E6 PASS (or preflight-only PASS) | 1 E6 FAIL | 2 BLOCKED by a fixed precondition (nothing run)
              3 BLOCKED by the wait timeout or by the harness precheck (no timed series) | 4 ERROR
#>
[CmdletBinding()]
param(
    [ValidateRange(2048, 8192)][int]$MinAvailableMb = 2048,
    [ValidateRange(2048, 8192)][int]$WaitTargetMb = 2100,
    [ValidateRange(10, 60)][int]$CleanMinutes = 10,
    [ValidateRange(0, 60)][int]$MaxWaitMinutes = 20,
    [switch]$PreflightOnly,
    [string]$LogDir = ''
)
$ErrorActionPreference = 'Stop'
$inv = [Globalization.CultureInfo]::InvariantCulture

# ---------------- fixed targets (deliberately not parameters) ----------------
$Server = 'localhost\MSSQLSERVER01'; $Service = 'MSSQLSERVER01'; $WinService = 'MSSQL$MSSQLSERVER01'
$Db = 'FitLife_P3_P2'; $ProbeDb = 'FitLife_P3_Probe'; $EngineVersion = '17.0.1000.7'
$ReqCfg = [ordered]@{ 'min server memory (MB)' = 1024; 'max server memory (MB)' = 2048; 'max degree of parallelism' = 8; 'cost threshold for parallelism' = 5; 'optimize for ad hoc workloads' = 0 }
$BestPerformance = [Guid]'ded574b5-45a0-4f42-8737-46345c09c238'   # Windows 10 power-mode overlay "Best performance"
$OverlayNames = @{ 'ded574b5-45a0-4f42-8737-46345c09c238' = 'Best performance'; '00000000-0000-0000-0000-000000000000' = 'Better performance (default)'; '961cc777-2547-4f9d-8174-7d86181b8a7a' = 'Better battery'; '3af9b8d9-7c97-431d-ad78-34a8bfea439f' = 'Battery saver' }
$BlockedProcs = @('Code', 'Code - Insiders', 'claude')
$Pinned = [ordered]@{   # A6-reviewed versions (R-27-HARNESS-DIFF__20261111-015043_BM1) and the DS-L run C reference
    'tests\db\diagnostics\r27_e6_probe.ps1'                                            = 'AB8D01145415E47F4450B1F3F4B911F1DD9F758A4FB9586A6542A619FA2762B2'
    'tests\db\diagnostics\r27_diag_target.ps1'                                         = 'BC7F4EC0031869AC0570804397324785208F77BE6D2A0286F30C29473B289BA2'
    'tests\db\seed\T-REPRO-02_checksums.sql'                                           = 'D731F90C57F82553B4D1A292F1EC2F73EBDA2B6EF722728C0A5526032ACBAABE'
    'docs\phase2\person3\evidence\test-results\CHECKSUMS__DS-L__20261108-1155_C.txt'   = '32F837044A81BE34975EA2BC83B4CA2AFB2404E9FEB66840B81A9C13DF07E124'
}
$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$Ev = Join-Path $Repo 'docs\phase2\person3\evidence\test-results'
$Harness = Join-Path $Repo 'tests\db\diagnostics\r27_e6_probe.ps1'
$PsExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$RunId = 'E6-BM1__' + (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss', $inv)
if ($LogDir -and -not $PreflightOnly) { throw '-LogDir is allowed only with -PreflightOnly; a real campaign always logs into the evidence folder.' }
if (-not $LogDir) { $LogDir = $Ev }
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Log = Join-Path $LogDir "${RunId}__runner.txt"
$HarnessLog = Join-Path $Ev "${RunId}__harness_console.txt"
$Lock = Join-Path $Ev "${RunId}__CAMPAIGN_LOCK.txt"
$Scratch = Join-Path $env:TEMP "p3_r27\$RunId"
if (Test-Path -LiteralPath $Log) { throw "refusing to overwrite $Log" }

$hostName = $env:COMPUTERNAME
function Mask([string]$s) {
    if ($hostName) { $s = [regex]::Replace($s, [regex]::Escape($hostName), '<local-server>', 'IgnoreCase') }
    [regex]::Replace($s, [regex]::Escape($Repo), '<repo>', 'IgnoreCase')
}
function Utc { (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss', $inv) }
function Log([string]$s) { $m = Mask $s; Add-Content -LiteralPath $Log -Value $m -Encoding UTF8; Write-Host $m }
$script:failIds = New-Object System.Collections.Generic.List[string]
function Check([string]$id, [bool]$ok, [string]$text, [string]$detail = '') {
    if (-not $ok) { $script:failIds.Add($id) }
    Log ('{0} {1}  {2}{3}' -f $id, $(if ($ok) { 'PASS' } else { 'FAIL' }), $text, $(if ($detail) { " | $detail" } else { '' }))
}
function Sql([string]$d, [string]$text) {
    $ErrorActionPreference = 'Continue'   # sqlcmd stderr must not become a terminating error
    $o = & sqlcmd -S $Server -E -I -b -W -s '|' -h -1 -l 15 -d $d -Q ('SET NOCOUNT ON; ' + $text) 2>&1
    [pscustomobject]@{ Exit = $LASTEXITCODE; Lines = @($o | ForEach-Object { [string]$_ }) }
}
function Tag($r, [string]$tag) { $l = @($r.Lines | Where-Object { $_ -like "$tag|*" }) | Select-Object -First 1; if ($l) { return ,($l -split '\|') } else { return ,@() } }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -Namespace P3E6 -Name Native -MemberDefinition @'
[DllImport("powrprof.dll")] public static extern uint PowerGetEffectiveOverlayScheme(out Guid overlay);
[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);
'@
function Overlay { $g = [Guid]::Empty; $rc = [P3E6.Native]::PowerGetEffectiveOverlayScheme([ref]$g); $n = $OverlayNames[$g.ToString()]; [pscustomobject]@{ Rc = $rc; Guid = $g; Name = $(if ($n) { $n } else { 'unknown' }) } }
function PowerEvents([datetime]$from, [datetime]$to) {   # same event list as the harness (G-E1)
    try {
        $e = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; StartTime = $from; EndTime = $to; ProviderName = 'Microsoft-Windows-Kernel-Power', 'Microsoft-Windows-Power-Troubleshooter' } -ErrorAction Stop |
            Where-Object { ($_.ProviderName -match 'Kernel-Power' -and $_.Id -in 42, 105, 107, 506, 507) -or ($_.ProviderName -match 'Troubleshooter' -and $_.Id -eq 1) })
        [pscustomobject]@{ Ok = $true; Events = $e; Err = '' }
    } catch {
        if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') { [pscustomobject]@{ Ok = $true; Events = @(); Err = '' } }
        else { [pscustomobject]@{ Ok = $false; Events = @(); Err = $_.Exception.Message } }
    }
}

# ---------------- fixed preconditions ----------------
function FixedChecks([string]$phase) {
    $script:failIds.Clear()
    Log ''; Log "== $phase - fixed preconditions ($(Utc) UTC) =="
    Check 'H1' (($PSVersionTable.PSVersion.Major -eq 5) -and ($PSVersionTable.PSEdition -eq 'Desktop')) 'Windows PowerShell 5.1 (Desktop edition), as used by every earlier harness run' $PSVersionTable.PSVersion.ToString()
    $sc = Get-Command sqlcmd -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    Check 'H2' ([bool]$sc) 'sqlcmd available on PATH' $(if ($sc) { $sc.Source } else { 'missing' })
    $n = 0
    foreach ($k in $Pinned.Keys) {
        $n++; $p = Join-Path $Repo $k
        $h = if (Test-Path -LiteralPath $p) { (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash } else { 'missing' }
        Check "H3.$n" ($h -eq $Pinned[$k]) "Reviewed file unchanged: $k" $h
    }
    if (-not $sc) { Log 'STOP: sqlcmd missing; no SQL check possible.'; return }

    $svc = Get-Service -Name $WinService -ErrorAction SilentlyContinue
    Check 'I1' ([bool]$svc -and $svc.Status -eq 'Running') "Windows service $WinService running (this runner never starts or stops services)" $(if ($svc) { [string]$svc.Status } else { 'not found' })
    $id = Sql 'master' "SELECT 'ID', @@SERVICENAME, ISNULL(CONVERT(varchar(60), SERVERPROPERTY('InstanceName')), '(default)'), CONVERT(varchar(30), SERVERPROPERTY('ProductVersion')), CONVERT(varchar(5), SERVERPROPERTY('EngineEdition')), CASE WHEN UPPER(CONVERT(nvarchar(128), SERVERPROPERTY('MachineName'))) = UPPER(N'$hostName') THEN 'local' ELSE 'NOT-LOCAL' END, CONVERT(varchar(5), HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE'));"
    $v = Tag $id 'ID'
    $idOk = ($id.Exit -eq 0) -and ($v.Count -ge 7) -and ($v[1] -eq $Service) -and ($v[2] -eq $Service) -and ($v[5] -eq 'local')
    Check 'I2' $idOk "Connection $Server reaches instance $Service on this computer (not the default instance MSSQLSERVER)" $(if ($v.Count) { $v -join '|' } else { ($id.Lines -join ' ') })
    if (-not $idOk) { Log 'STOP: wrong or unreachable instance; no further SQL check.'; return }
    Check 'I3' (($v[3] -eq $EngineVersion) -and ($v[4] -eq '2')) "Engine $EngineVersion, EngineEdition 2 (as recorded in ENVIRONMENT_P0)" "$($v[3]) / $($v[4])"
    Check 'I4' ($v[6] -eq '1') 'Login has VIEW SERVER STATE (needed by the harness DMV reads)' $v[6]

    $cfg = Sql 'master' "SELECT 'CFG', name, CONVERT(varchar(20), value), CONVERT(varchar(20), value_in_use) FROM sys.configurations WHERE name IN ('min server memory (MB)','max server memory (MB)','max degree of parallelism','cost threshold for parallelism','optimize for ad hoc workloads') ORDER BY name;"
    $n = 0
    foreach ($k in $ReqCfg.Keys) {
        $n++; $c = Tag $cfg "CFG|$k"
        $ok = ($c.Count -ge 4) -and ($c[2] -eq [string]$ReqCfg[$k]) -and ($c[3] -eq [string]$ReqCfg[$k])
        $hint = if (-not $ok -and $k -like '*server memory*') { ' -> A3 not in effect. Apply it (Owner step, approved A3): tests\db\build\run_p0_02_bm1.ps1 -Stage Memory' } else { '' }
        Check "C$n" $ok "BM-1 '$k' configured and in use = $($ReqCfg[$k]) ($(if ($k -like '*server memory*') { 'A3' } else { 'E4' }); read only, never changed here)" ("configured {0}, in use {1}{2}" -f $(if ($c.Count -ge 4) { $c[2] } else { '?' }), $(if ($c.Count -ge 4) { $c[3] } else { '?' }), $hint)
    }

    $dbr = Sql 'master' "SELECT 'DB', name, state_desc, CONVERT(varchar(5), compatibility_level), CONVERT(varchar(1), is_read_only), user_access_desc FROM sys.databases WHERE name = N'$Db'; SELECT 'PROBE', COUNT(*) FROM sys.databases WHERE name = N'$ProbeDb'; SELECT 'REQ', COUNT(*) FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id WHERE s.is_user_process = 1 AND r.session_id <> @@SPID; SELECT 'DBSESS', COUNT(*) FROM sys.dm_exec_sessions WHERE is_user_process = 1 AND session_id <> @@SPID AND database_id = DB_ID(N'$Db');"
    $d = Tag $dbr 'DB'
    $dbOk = ($d.Count -ge 6) -and ($d[2] -eq 'ONLINE') -and ($d[3] -eq '160') -and ($d[4] -eq '0') -and ($d[5] -eq 'MULTI_USER')
    Check 'D1' $dbOk "$Db exists on BM-1: ONLINE, compatibility 160, read-write, MULTI_USER" ($d -join '|')
    Check 'D2' ((Tag $dbr 'PROBE')[1] -eq '0') "$ProbeDb absent (feature probes finished and dropped 2026-11-10; not rerun)" ''
    if ($dbOk) {
        $b0 = Sql $Db "SELECT 'MARK', CONVERT(nvarchar(200), value) FROM sys.extended_properties WHERE class = 0 AND name = N'P3_Disposable'; SELECT 'V003', name, is_disabled, is_not_trusted FROM sys.check_constraints WHERE name = N'CK_MEMBER_MONTHLY_SPENDING_PointsRule'; SELECT 'OBJ', (SELECT COUNT(*) FROM sys.tables), (SELECT COUNT(*) FROM sys.indexes i JOIN sys.tables t ON t.object_id = i.object_id WHERE i.type > 0 AND i.is_primary_key = 0), (SELECT COUNT(*) FROM sys.indexes i JOIN sys.tables t ON t.object_id = i.object_id WHERE i.type NOT IN (0, 1)), (SELECT COUNT(*) FROM sys.views), (SELECT COUNT(*) FROM sys.triggers), (SELECT COUNT(*) FROM sys.partition_functions) + (SELECT COUNT(*) FROM sys.partition_schemes), (SELECT COUNT(*) FROM sys.objects WHERE is_ms_shipped = 0 AND type IN ('P', 'FN', 'IF', 'TF')), (SELECT COUNT(*) FROM sys.partitions p JOIN sys.tables t ON t.object_id = p.object_id WHERE p.data_compression <> 0);"
        $mk = Tag $b0 'MARK'; $v3 = Tag $b0 'V003'; $o = Tag $b0 'OBJ'
        Check 'D3' (($mk.Count -ge 2) -and ($mk[1] -like 'WO-P3-P2-01*')) 'Disposable marker P3_Disposable = WO-P3-P2-01... (the validated DS-L build of 2026-11-10, not rebuilt)' $(if ($mk.Count -ge 2) { $mk[1] } else { 'missing' })
        Check 'D4' (($v3.Count -ge 4) -and ($v3[2] -eq '0') -and ($v3[3] -eq '0')) 'V003 constraint present, enabled and trusted (not re-applied here)' ($v3 -join '|')
        Check 'D5' (($o.Count -ge 9) -and ($o[1] -eq '9') -and (@($o[2..8] | Where-Object { $_ -ne '0' }).Count -eq 0)) 'B0 inventory unchanged (same query as Validate V6): 9 tables, PK indexes only, no view/trigger/partition/routine/compression' ($o -join '|')
    }
    Check 'D6' ((Tag $dbr 'REQ')[1] -eq '0') 'No other user request running on BM-1' ''
    Check 'D7' ((Tag $dbr 'DBSESS')[1] -eq '0') "No other user session connected to $Db (close SSMS / Azure Data Studio windows on it)" ''

    $consumed = @()
    $consumed += @(Get-ChildItem -LiteralPath $Ev -File | Where-Object { $_.Name -match '^R-27-CLOSE__\d{8}-\d{4}\.txt$' } | Where-Object { Select-String -LiteralPath $_.FullName -SimpleMatch -Quiet -Pattern "Server $Server." } | ForEach-Object { $_.Name })
    $consumed += @(Get-ChildItem -LiteralPath $Ev -File -Filter 'E6-BM1__*__CAMPAIGN_LOCK.txt' | Where-Object { -not (Select-String -LiteralPath $_.FullName -SimpleMatch -Quiet -Pattern 'RELEASED') } | ForEach-Object { $_.Name })
    Check 'K1' ($consumed.Count -eq 0) 'The single authorized BM-1 E6 campaign is still unused (no BM-1 R-27-CLOSE result, no unreleased campaign lock); a FAIL is not repeated under the same conditions' $(if ($consumed.Count) { 'found: ' + ($consumed -join ', ') } else { 'none found' })

    $ov = Overlay
    Check 'A4' (($ov.Rc -eq 0) -and ($ov.Guid -eq $BestPerformance)) 'A4 power mode "Best performance" in effect (set by the Owner with the battery-icon slider; never changed here)' "effective overlay $($ov.Guid) = $($ov.Name)"
    $bad = @(Get-Process -Name $BlockedProcs -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ProcessName -Unique)
    Check 'A5' ($bad.Count -eq 0) 'A5 VS Code and Claude Code closed (this runner closes nothing)' $(if ($bad.Count) { 'still running: ' + ($bad -join ', ') } else { 'none running' })
    $sq = @(Get-Process -Name sqlcmd -ErrorAction SilentlyContinue).Count
    Check 'A6' ($sq -eq 0) 'No other sqlcmd process (the harness precheck PRE-4 requires 0)' "sqlcmd processes $sq"
    $vol = Get-Item -LiteralPath $Ev; $drv = Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='{0}:'" -f $vol.PSDrive.Name)
    Check 'A7' (($drv.FreeSpace / 1MB) -ge 1024) 'At least 1 GB free on the evidence volume' ('{0:N0} MB free' -f ($drv.FreeSpace / 1MB))
    Log 'INFO heaviest process groups (working set MB):'
    Get-Process | Group-Object ProcessName | ForEach-Object { [pscustomobject]@{ N = $_.Name; C = $_.Count; MB = [int](($_.Group | Measure-Object WorkingSet64 -Sum).Sum / 1MB) } } | Sort-Object MB -Descending | Select-Object -First 10 | ForEach-Object { Log "  $($_.N) x$($_.C): $($_.MB)" }
}

# ---------------- E1/E2 standing conditions ----------------
function Standing {
    $now = Get-Date
    $ac = ([System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus.ToString() -eq 'Online')
    $pe = PowerEvents $now.AddMinutes(-90) $now
    $last = if ($pe.Events.Count) { ($pe.Events | Sort-Object TimeCreated | Select-Object -Last 1).TimeCreated } else { $null }
    $clean = if ($last) { ($now - $last).TotalMinutes } else { 90.0 }
    $winMb = [int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024)
    $m = Tag (Sql 'master' "SELECT 'MEM', m.available_physical_memory_kb/1024, p.process_physical_memory_low, (SELECT target_memory_kb/1024 FROM sys.dm_exec_query_resource_semaphores WHERE pool_id = 2 AND resource_semaphore_id = 0) FROM sys.dm_os_sys_memory m CROSS JOIN sys.dm_os_process_memory p;") 'MEM'
    $sqlMb = if ($m.Count -ge 4) { [int]$m[1] } else { -1 }; $low = if ($m.Count -ge 4) { [int]$m[2] } else { -1 }; $sem = if ($m.Count -ge 4) { [int]$m[3] } else { -1 }
    $ready = $ac -and $pe.Ok -and ($clean -ge ($CleanMinutes + 0.5)) -and ($winMb -ge $WaitTargetMb) -and ($sqlMb -ge $WaitTargetMb) -and ($low -eq 0) -and ($sem -ge 256)
    Log ('{0} UTC E1 ac={1} power_event_read_ok={2} minutes_since_last_power_event={3:0.0} (need >= {4}) | E2 windows_available_mb={5} sql_available_mb={6} (need >= {7}; harness gate >= {8}) physical_memory_low={9} semaphore_target_mb={10} (need >= 256) | ready={11}' -f (Utc), $ac, $pe.Ok, $clean, $CleanMinutes, $winMb, $sqlMb, $WaitTargetMb, $MinAvailableMb, $low, $sem, $ready)
    if (-not $pe.Ok) { Log "     power event log not readable: $($pe.Err)" }
    $ready
}

function Finish([string]$result, [int]$code, [string]$why) {
    Log ''; Log '== RESULT =='
    Log "RUN_ID: $RunId"
    Log "Reason: $why"
    Log "Runner log: $Log"
    Log "E6_BM1_RESULT: $result"
    $script:exitCode = $code
}

# ================================ main ================================
$script:exitCode = 4
function Main {   # a function, so that 'return' still reaches the final 'exit $script:exitCode'
$keepAwake = $false
try {
    Log "E6-BM1 standalone runner - WO-P3-P0-02 task 11 / acceptance criterion 7 (R-27 closure test). RUN_ID $RunId."
    Log "Started (UTC) $(Utc). Mode: $(if ($PreflightOnly) { 'PREFLIGHT ONLY (harness never started)' } else { 'CAMPAIGN (harness started once if every precondition passes)' })."
    Log "Runner SHA-256: $((Get-FileHash -Algorithm SHA256 -LiteralPath $PSCommandPath).Hash). Target $Server only; default instance not contacted."
    Log "Parameters: MinAvailableMb=$MinAvailableMb WaitTargetMb=$WaitTargetMb CleanMinutes=$CleanMinutes MaxWaitMinutes=$MaxWaitMinutes. Harness thresholds/sampling: harness defaults, unchanged (2 series >= 10 min apart, warm-up + 15 runs)."
    if ($WaitTargetMb -lt $MinAvailableMb) { throw 'WaitTargetMb must be >= MinAvailableMb' }

    FixedChecks 'Initial'
    if ($script:failIds.Count) { Finish 'BLOCKED' 2 ("fixed precondition(s) failed: " + ($script:failIds -join ', ') + '. E6 NOT_RUN; no campaign consumed.'); return }

    [void][P3E6.Native]::SetThreadExecutionState([uint32]2147483651); $keepAwake = $true   # process-scoped keep-awake; no setting changed
    Log ''; Log "== Bounded wait for E1/E2 (up to $MaxWaitMinutes min, every 30 s) =="
    $deadline = (Get-Date).AddMinutes($MaxWaitMinutes)
    $ready = $false
    while ($true) {
        $ready = Standing
        if ($ready -or (Get-Date) -ge $deadline) { break }
        Start-Sleep -Seconds 30
    }
    if (-not $ready) { Finish 'BLOCKED' 3 "E1/E2 standing conditions not met within $MaxWaitMinutes min. E6 NOT_RUN; no campaign consumed."; return }

    FixedChecks 'Final (immediately before launch)'
    if ($script:failIds.Count) { Finish 'BLOCKED' 2 ("fixed precondition(s) failed at the final check: " + ($script:failIds -join ', ') + '. E6 NOT_RUN; no campaign consumed.'); return }
    if ($PreflightOnly) { Finish 'PREFLIGHT_PASS' 0 'every precondition passed; harness NOT started because -PreflightOnly was given.'; return }

    # ---------------- the single campaign ----------------
    @("RUN_ID $RunId", "STARTED $(Utc) UTC: E6 campaign on $Server launched by run_e6_bm1_standalone.ps1.") | Out-File -LiteralPath $Lock -Encoding utf8
    New-Item -ItemType Directory -Force -Path $Scratch | Out-Null
    Log ''; Log "== Harness (unchanged r27_e6_probe.ps1; console copy in $HarnessLog) =="
    Log "Command: powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Harness -Server $Server -Repo $Repo -Scratch $Scratch"
    Log "Launched $(Utc) UTC. Expected duration about 25-40 min (two series, 10 min gap, checksums). Do not use the computer."
    $hStart = Get-Date
    $ErrorActionPreference = 'Continue'
    $hOut = @(& $PsExe -NoProfile -ExecutionPolicy Bypass -File $Harness -Server $Server -Repo $Repo -Scratch $Scratch 2>&1 | ForEach-Object {
            $l = Mask ([string]$_); Add-Content -LiteralPath $HarnessLog -Value $l -Encoding UTF8; Write-Host "  | $l"; $l })
    $hRc = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    Log "Harness ended $(Utc) UTC, exit code $hRc, $([int]((Get-Date) - $hStart).TotalMinutes) min."

    # evidence inventory with hashes
    $written = @($hOut | Where-Object { $_ -match '^written ' } | ForEach-Object { ($_ -replace '^written ', '').Trim() }) | Select-Object -Last 1
    $sumPath = if ($written) { $written -replace [regex]::Escape('<repo>'), $Repo } else { $null }
    $files = @(Get-ChildItem -LiteralPath $Ev -File | Where-Object { $_.LastWriteTime -ge $hStart.AddSeconds(-5) -and $_.Name -match '^(R-27-CLOSE__|R-27-DIAG__|E6-BM1__)' -and $_.FullName -ne $Log })
    Log 'Evidence written during the run (SHA-256):'
    foreach ($f in ($files | Sort-Object Name)) { Log ('  {0}  {1}' -f (Get-FileHash -Algorithm SHA256 -LiteralPath $f.FullName).Hash, $f.Name) }

    # configuration after the run (must be unchanged; read only)
    $post = Sql 'master' "SELECT 'CFG', name, CONVERT(varchar(20), value), CONVERT(varchar(20), value_in_use) FROM sys.configurations WHERE name IN ('min server memory (MB)','max server memory (MB)','max degree of parallelism','cost threshold for parallelism','optimize for ad hoc workloads') ORDER BY name;"
    Log 'BM-1 configuration after the run (configured|in use):'; foreach ($l in $post.Lines) { if ($l -like 'CFG|*') { Log "  $l" } }
    $ov = Overlay; Log "Power overlay after the run: $($ov.Guid) = $($ov.Name). AC: $([System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus)."

    if ($hRc -eq 2 -and ($hOut -match 'PRECHECK FAILED')) {
        Add-Content -LiteralPath $Lock -Encoding UTF8 -Value "RELEASED $(Utc) UTC: harness precheck failed before any timed series (exit 2); campaign not consumed."
        Finish 'BLOCKED' 3 'harness precheck (PRE-1..PRE-5) failed; no timed series ran; campaign NOT consumed. See R-27-CLOSE__*__precheck.txt.'
        return
    }
    $line = if ($sumPath -and (Test-Path -LiteralPath $sumPath)) { @(Get-Content -LiteralPath $sumPath -Encoding UTF8 | Where-Object { $_ -match '^R-27-CLOSE_RESULT:' }) | Select-Object -Last 1 } else { $null }
    Add-Content -LiteralPath $Lock -Encoding UTF8 -Value "CONSUMED $(Utc) UTC: timed series started; harness exit $hRc; $(if ($line) { $line } else { 'no result line' })."
    Log "Harness summary: $(if ($sumPath) { Mask $sumPath } else { 'not found' })"
    if ($line -match '^R-27-CLOSE_RESULT: PASS') { Finish 'PASS' 0 "$line (exit $hRc)" }
    elseif ($line -match '^R-27-CLOSE_RESULT: FAIL') { Finish 'FAIL' 1 "$line (exit $hRc). R-27 stays OPEN; do not rerun under the same conditions." }
    else { Finish 'ERROR' 4 "harness ended (exit $hRc) without a result line; campaign treated as consumed. Inspect $HarnessLog." }
} catch {
    $ErrorActionPreference = 'Continue'
    Log "EXCEPTION: $($_.Exception.Message) at line $($_.InvocationInfo.ScriptLineNumber)"
    if (Test-Path -LiteralPath $Lock) { Add-Content -LiteralPath $Lock -Encoding UTF8 -Value "ERROR $(Utc) UTC: runner exception after launch; campaign treated as consumed." }
    Finish 'ERROR' 4 'runner exception; see log above.'
} finally {
    if ($keepAwake) { [void][P3E6.Native]::SetThreadExecutionState([uint32]2147483648) }
}
}
Main
exit $script:exitCode
