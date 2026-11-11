<#
  run_p0_02_bm1.ps1 - TEST_ONLY runner for WO-P3-P0-02 (amended 2026-11-10): benchmark environment BM-1 and SQL Server
  feature readiness. Windows PowerShell 5.1; nothing installed.

  HARD-BOUND to the benchmark instance localhost\MSSQLSERVER01 (BM-1). There is no -Server parameter on purpose: every
  stage first proves that the connection reaches the service MSSQLSERVER01 on the local computer and stops otherwise.
  The default instance (localhost = MSSQLSERVER) is only READ (memory in use, reference DS-L size and settings).

  -Stage Preflight   read-only: instance identity, user databases, name conflicts, configuration, host resources
  -Stage Memory      A3: safety preflight, then min server memory 1024 MB / max server memory 2048 MB on BM-1 only
                     (previous values recorded; nothing applied if a safety rule fails)
  -Stage MemoryRollback  restores the previous values given by -PrevMin / -PrevMax (cleanup boundary or safety)
  -Stage Probes      feature probes of WO-P3-P0-02 task 3 (+ task 4) in the disposable database FitLife_P3_Probe,
                     which is created, marked, used and dropped here
  -Stage Validate    after tests/db/seed/run_p2_dataset.ps1 -Server localhost\MSSQLSERVER01: applies V003 if missing
                     and validates FitLife_P3_P2 on BM-1 as the B0 benchmark dataset (schema, constraints, counts,
                     index inventory, canonical checksum = DS-L run C, E5 configuration record)
  Evidence: docs/phase2/person3/evidence/test-results/ENV-P0__<utc>_<stage>.txt. Machine names are masked.
  No timing in any output is a measurement.
#>
param(
    [Parameter(Mandatory = $true)][ValidateSet('Preflight', 'Memory', 'MemoryRollback', 'Probes', 'Validate')][string]$Stage,
    [int]$MinMb = 1024,
    [int]$MaxMb = 2048,
    [long]$PrevMin = -1,
    [long]$PrevMax = -1,
    [string]$EvidenceDir = 'docs/phase2/person3/evidence/test-results'
)
$ErrorActionPreference = 'Continue'
$inv = [Globalization.CultureInfo]::InvariantCulture
$BM1 = 'localhost\MSSQLSERVER01'; $BM1Service = 'MSSQLSERVER01'
$DefaultInst = 'localhost'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
Set-Location $repo
if (-not [System.IO.Path]::IsPathRooted($EvidenceDir)) { $EvidenceDir = Join-Path $repo $EvidenceDir }
$ts = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss', $inv)
$logPath = Join-Path $EvidenceDir "ENV-P0__${ts}_$Stage.txt"
$log = New-Object System.Collections.Generic.List[string]
function Hide([string]$s) { if ($env:COMPUTERNAME) { $s = [regex]::Replace($s, [regex]::Escape($env:COMPUTERNAME), '<local-server>', 'IgnoreCase') }; return $s }
function Log([string]$s) { $h = Hide $s; $log.Add($h); Write-Host $h }   # Write-Host: keeps function return values clean
function Utc { (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss', $inv) }
$res = New-Object System.Collections.Generic.List[object]
function Check([string]$id, [bool]$ok, [string]$descr, [string]$detail = '') { $res.Add([pscustomobject]@{ Id = $id; Ok = $ok }); Log ("{0} {1}  {2}{3}" -f $id, $(if ($ok) { 'PASS' } else { 'FAIL' }), $descr, $(if ($detail) { " | $detail" } else { '' })) }
function Sql([string]$server, [string[]]$a) { $o = & sqlcmd -S $server -E -b -W -s '|' -l 15 @a 2>&1; [pscustomobject]@{ Exit = $LASTEXITCODE; Lines = @($o | ForEach-Object { "$_" }) } }
function Q([string]$server, [string]$db, [string]$text, [switch]$NoQI) { $a = @('-d', $db, '-h', '-1', '-Q', ("SET NOCOUNT ON; " + $text)); if (-not $NoQI) { $a = @('-I') + $a }; Sql $server $a }
function Val($r, [string]$tag) { $l = @($r.Lines | Where-Object { $_ -like "$tag|*" }) | Select-Object -First 1; if ($l) { return ($l -split '\|') } else { return @() } }
function Finish { $nf = @($res | Where-Object { -not $_.Ok }).Count; Log ''; Log ("ENV-P0 $Stage SUMMARY: checks $($res.Count); FAIL $nf; finished (UTC) $(Utc)"); Log ("ENV-P0_${Stage}_RESULT: " + $(if ($nf -eq 0) { 'PASS' } else { 'FAIL' })); $log | Out-File -Encoding utf8 $logPath; Write-Output "LOG=$logPath"; if ($nf -eq 0) { exit 0 } else { exit 1 } }

Log "ENV-P0 - WO-P3-P0-02 (amended 2026-11-10), stage $Stage. Benchmark instance BM-1 = $BM1. Started (UTC) $(Utc)."
Log ("Runner SHA-256: " + (Get-FileHash -Algorithm SHA256 $PSCommandPath).Hash)

# ---------------- identity guard (every stage) ----------------
$idSql = "SELECT 'ID', @@SERVICENAME, ISNULL(CONVERT(varchar(60), SERVERPROPERTY('InstanceName')), '(default)'), CONVERT(varchar(30), SERVERPROPERTY('ProductVersion')), CONVERT(varchar(60), SERVERPROPERTY('Edition')), CONVERT(varchar(5), SERVERPROPERTY('EngineEdition')), CASE WHEN UPPER(CONVERT(nvarchar(128), SERVERPROPERTY('MachineName'))) = UPPER(N'$($env:COMPUTERNAME)') THEN 'local' ELSE 'NOT-LOCAL' END, CONVERT(varchar(5), IS_SRVROLEMEMBER('sysadmin'));"
$id = Q $BM1 'master' $idSql; $idv = Val $id 'ID'
Log ("Identity: " + ($idv -join '|'))
$idOk = ($id.Exit -eq 0) -and ($idv.Count -ge 8) -and ($idv[1] -eq $BM1Service) -and ($idv[2] -eq $BM1Service) -and ($idv[6] -eq 'local')
Check 'G0' $idOk "Connection reaches service $BM1Service on the local computer (not the default instance)" ''
if (-not $idOk) { Log 'STOP: wrong or unreachable instance; nothing executed.'; Finish }
Check 'G1' (($idv[3] -eq '17.0.1000.7') -and ($idv[4] -like 'Standard Developer*') -and ($idv[5] -eq '2') -and ($idv[7] -eq '1')) 'Engine 17.0.1000.7, Standard Developer Edition, EngineEdition 2; current login is sysadmin' ''

function HostFacts {
    $cs = Get-CimInstance Win32_ComputerSystem; $os = Get-CimInstance Win32_OperatingSystem; $cpu = Get-CimInstance Win32_Processor; $b = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    $o = [pscustomobject]@{ TotalMb = [int]($os.TotalVisibleMemorySize / 1024); FreeMb = [int]($os.FreePhysicalMemory / 1024); CommitLimitMb = [int]($os.TotalVirtualMemorySize / 1024); CommitUsedMb = [int](($os.TotalVirtualMemorySize - $os.FreeVirtualMemory) / 1024); Ac = $(if ($b) { $b.BatteryStatus -eq 2 } else { $true }) }
    Log ("Host: CPU $($cpu.Name.Trim()), cores $($cpu.NumberOfCores), logical $($cpu.NumberOfLogicalProcessors); RAM $($o.TotalMb) MB, free $($o.FreeMb) MB; commit $($o.CommitUsedMb) of $($o.CommitLimitMb) MB; OS $($os.Caption) build $($os.BuildNumber); battery status $(if ($b) { $b.BatteryStatus } else { 'none' }) (2 = AC), charge $(if ($b) { $b.EstimatedChargeRemaining } else { '-' })%")
    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object { Log ("Volume {0}: free {1:N1} GB of {2:N0} GB" -f $_.DeviceID, ($_.FreeSpace / 1GB), ($_.Size / 1GB)) }
    Log ("Power scheme: " + ((powercfg /getactivescheme) -replace '^.*GUID: ', ''))
    Log 'Heaviest process groups (working set MB):'
    Get-Process | Group-Object ProcessName | ForEach-Object { [pscustomobject]@{ N = $_.Name; C = $_.Count; MB = [int](($_.Group | Measure-Object WorkingSet64 -Sum).Sum / 1MB) } } | Sort-Object MB -Descending | Select-Object -First 8 | ForEach-Object { Log "  $($_.N) x$($_.C): $($_.MB)" }
    return $o
}
$cfgSql = "SELECT 'CFG', name, CONVERT(varchar(20), value), CONVERT(varchar(20), value_in_use) FROM sys.configurations WHERE name IN ('max server memory (MB)','min server memory (MB)','max degree of parallelism','cost threshold for parallelism','show advanced options','optimize for ad hoc workloads') ORDER BY name; SELECT 'MEM', total_physical_memory_kb/1024, available_physical_memory_kb/1024, system_memory_state_desc FROM sys.dm_os_sys_memory; SELECT 'PROC', physical_memory_in_use_kb/1024, process_physical_memory_low, locked_page_allocations_kb FROM sys.dm_os_process_memory; SELECT 'SYSINFO', committed_kb/1024, committed_target_kb/1024, sql_memory_model_desc FROM sys.dm_os_sys_info; SELECT 'SEM', target_memory_kb/1024, max_target_memory_kb/1024, forced_grant_count FROM sys.dm_exec_query_resource_semaphores WHERE resource_semaphore_id = 0 AND pool_id = 2;"
function InstState([string]$server, [string]$label) { $r = Q $server 'master' $cfgSql; Log "-- $label configuration and memory (name|value|value_in_use; MEM total|available|state; PROC in_use_mb|physical_low|locked_kb; SYSINFO committed|target|model; SEM target|max|forced) --"; foreach ($l in $r.Lines) { if ($l.Trim()) { Log "  $l" } }; return $r }
function CfgVal($r, [string]$name) { $l = @($r.Lines | Where-Object { $_ -like "CFG|$name|*" }) | Select-Object -First 1; if ($l) { return [long](($l -split '\|')[3]) } else { return $null } }

# =====================================================================
if ($Stage -eq 'Preflight') {
    $h = HostFacts
    $s = InstState $BM1 'BM-1'
    $d = Q $BM1 'master' "SELECT 'USERDB', name, state_desc, CONVERT(varchar(19), create_date, 120) FROM sys.databases WHERE database_id > 4; SELECT 'USERDB_COUNT', COUNT(*) FROM sys.databases WHERE database_id > 4; SELECT 'CONFLICT', name FROM sys.databases WHERE name IN (N'FitLife_P3_Probe', N'FitLife_P3_P2'); SELECT 'SESSIONS', COUNT(*) FROM sys.dm_exec_sessions WHERE is_user_process = 1 AND session_id <> @@SPID; SELECT 'REQUESTS', COUNT(*) FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id WHERE s.is_user_process = 1 AND r.session_id <> @@SPID; SELECT 'PATH', CONVERT(varchar(200), SERVERPROPERTY('InstanceDefaultDataPath'));"
    foreach ($l in $d.Lines) { if ($l.Trim()) { Log "  $l" } }
    $conf = @($d.Lines | Where-Object { $_ -like 'CONFLICT|*' })
    Check 'P1' ($conf.Count -eq 0) 'Target names FitLife_P3_Probe and FitLife_P3_P2 do not exist on BM-1 (no unknown database would be overwritten)' ("existing: " + ($conf -join ', '))
    $udb = Val $d 'USERDB_COUNT'
    Log ("User databases on BM-1: $($udb[1])")
    $o = InstState $DefaultInst 'Default instance MSSQLSERVER (read only)'
    $vol = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    Check 'P2' (($vol.FreeSpace / 1GB) -ge 3) 'At least 3 GB free on the data volume for the DS-L build (data about 0.1 GB plus log and tempdb growth)' ("free {0:N1} GB" -f ($vol.FreeSpace / 1GB))
    Check 'P3' ((Val $d 'REQUESTS')[1] -eq '0') 'No other user request running on BM-1' ''
    Log 'Creation and cleanup procedures confirmed: FitLife_P3_Probe is created, marked (P3_Disposable = WO-P3-P0-02...) and dropped by stage Probes of this runner; FitLife_P3_P2 is built by tests/db/build/rebuild_p2_db.sql (marker WO-P3-P2-01...) through tests/db/seed/run_p2_dataset.ps1 -Server and can be dropped only by tests/db/build/drop_p2_db.sql (marker guard) run with -S localhost\MSSQLSERVER01.'
    Finish
}

# =====================================================================
if ($Stage -eq 'Memory') {
    $h = HostFacts
    $before = InstState $BM1 'BM-1 BEFORE'
    $other = InstState $DefaultInst 'Default instance MSSQLSERVER (read only; NOT changed)'
    $prevMin = CfgVal $before 'min server memory (MB)'; $prevMax = CfgVal $before 'max server memory (MB)'; $prevAdv = CfgVal $before 'show advanced options'
    $prevMinCfg = [long]((@($before.Lines | Where-Object { $_ -like 'CFG|min server memory (MB)|*' })[0] -split '\|')[2])
    Log "Previous values on BM-1 (for rollback): min server memory configured $prevMinCfg (in use $prevMin) MB; max server memory $prevMax MB; show advanced options $prevAdv"
    $ref = Q $DefaultInst 'FitLife_P3_P2' "SELECT 'DSL', SUM(reserved_page_count) * 8 / 1024 FROM sys.dm_db_partition_stats;"
    $dslMb = [int](Val $ref 'DSL')[1]
    $otherUse = [int](Val $other 'PROC')[1]; $bmUse = [int](Val $before 'PROC')[1]
    Log "Workload size: DS-L reserves $dslMb MB (read from the default instance copy). Memory in use now: BM-1 $bmUse MB, default instance $otherUse MB."
    # safety rules, fixed before applying
    $need = 4 * $dslMb + 256 + 256      # data fully cached several times over + minimum query-memory target + engine overhead
    Check 'M1' ($MaxMb -ge $need) "Proposed max server memory is sufficient for the workload: >= 4 x DS-L size + 256 MB query memory + 256 MB overhead" "$MaxMb MB vs required $need MB"
    Check 'M2' ($MinMb -le [int]($h.TotalMb * 0.25) -and $MaxMb -le [int]($h.TotalMb * 0.35)) 'Floor <= 25% and cap <= 35% of physical RAM, leaving the rest to the OS, applications and the default instance' "floor $MinMb, cap $MaxMb, RAM $($h.TotalMb) MB"
    Check 'M3' (($h.CommitLimitMb - $h.CommitUsedMb) -ge ($MinMb + 512)) 'Commit headroom of the host >= floor + 512 MB, so the floor cannot exhaust the commit limit' "headroom $($h.CommitLimitMb - $h.CommitUsedMb) MB"
    Check 'M4' ($prevMax -ge $MaxMb -and $prevMin -le $MinMb) 'The change only narrows the range: today BM-1 has no cap, so its worst-case memory use decreases; the floor can retain at most (floor - current use) more than today' "worst-case additional retention $([Math]::Max(0, $MinMb - $bmUse)) MB"
    if (@($res | Where-Object { -not $_.Ok }).Count -gt 0) { Log 'STOP: a safety rule failed; the configuration was NOT applied.'; Finish }
    $apply = "IF @@SERVICENAME <> N'$BM1Service' THROW 51900, N'wrong instance', 1; EXEC sys.sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sys.sp_configure 'min server memory (MB)', $MinMb; EXEC sys.sp_configure 'max server memory (MB)', $MaxMb; RECONFIGURE; EXEC sys.sp_configure 'show advanced options', $prevAdv; RECONFIGURE; SELECT 'APPLIED', @@SERVICENAME;"
    Log "Applying on $BM1 only: $apply"
    $a = Q $BM1 'master' $apply; foreach ($l in $a.Lines) { if ($l.Trim()) { Log "  $l" } }
    $after = InstState $BM1 'BM-1 AFTER'
    $other2 = InstState $DefaultInst 'Default instance MSSQLSERVER AFTER (must be unchanged)'
    Check 'M5' (($a.Exit -eq 0) -and ((CfgVal $after 'min server memory (MB)') -eq $MinMb) -and ((CfgVal $after 'max server memory (MB)') -eq $MaxMb)) "BM-1 value_in_use: min server memory $MinMb MB, max server memory $MaxMb MB" ''
    Check 'M6' (((CfgVal $other2 'min server memory (MB)') -eq (CfgVal $other 'min server memory (MB)')) -and ((CfgVal $other2 'max server memory (MB)') -eq (CfgVal $other 'max server memory (MB)'))) 'Default instance MSSQLSERVER memory settings unchanged' "min $(CfgVal $other2 'min server memory (MB)'), max $(CfgVal $other2 'max server memory (MB)')"
    Log "ROLLBACK (not executed): powershell -File tests/db/build/run_p0_02_bm1.ps1 -Stage MemoryRollback -PrevMin $prevMinCfg -PrevMax $prevMax"
    Finish
}

if ($Stage -eq 'MemoryRollback') {
    if ($PrevMin -lt 0 -or $PrevMax -lt 0) { Log 'STOP: -PrevMin and -PrevMax are required.'; Check 'R0' $false 'Rollback parameters supplied' ''; Finish }
    $before = InstState $BM1 'BM-1 BEFORE rollback'
    $adv = CfgVal $before 'show advanced options'
    $a = Q $BM1 'master' "IF @@SERVICENAME <> N'$BM1Service' THROW 51900, N'wrong instance', 1; EXEC sys.sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sys.sp_configure 'min server memory (MB)', $PrevMin; EXEC sys.sp_configure 'max server memory (MB)', $PrevMax; RECONFIGURE; EXEC sys.sp_configure 'show advanced options', $adv; RECONFIGURE;"
    foreach ($l in $a.Lines) { if ($l.Trim()) { Log "  $l" } }
    $after = InstState $BM1 'BM-1 AFTER rollback'
    Check 'R1' (($a.Exit -eq 0) -and ((CfgVal $after 'max server memory (MB)') -eq $PrevMax)) "BM-1 memory settings restored (configured min $PrevMin, max $PrevMax)" ''
    Finish
}

# =====================================================================
if ($Stage -eq 'Probes') {
    $P = 'FitLife_P3_Probe'
    $dbBefore = Q $BM1 'master' "SELECT 'DB', name FROM sys.databases ORDER BY database_id;"
    Log ("Databases on BM-1 before: " + ((@($dbBefore.Lines | Where-Object { $_ -like 'DB|*' }) | ForEach-Object { ($_ -split '\|')[1] }) -join ', '))
    $ex = Q $BM1 'master' "SELECT 'EX', CASE WHEN DB_ID(N'$P') IS NULL THEN 'absent' ELSE 'EXISTS' END;"
    if ((Val $ex 'EX')[1] -ne 'absent') { Check 'F0' $false "$P must not exist before the probes (unknown database is never dropped)" ''; Finish }
    $c = Q $BM1 'master' "IF @@SERVICENAME <> N'$BM1Service' THROW 51900, N'wrong instance', 1; CREATE DATABASE [$P]; ALTER DATABASE [$P] SET RECOVERY SIMPLE; ALTER DATABASE [$P] SET COMPATIBILITY_LEVEL = 160; EXEC [$P].sys.sp_addextendedproperty @name = N'P3_Disposable', @value = N'WO-P3-P0-02 feature probe database; safe to drop'; SELECT 'CREATED', compatibility_level FROM sys.databases WHERE name = N'$P';"
    Check 'F0' (($c.Exit -eq 0) -and ((Val $c 'CREATED')[1] -eq '160')) "Probe database $P created on BM-1 (SIMPLE, compatibility 160 like the P3 databases, P3_Disposable marker)" (($c.Lines | Where-Object { $_ -match 'Msg ' }) -join ' ')
    $probe = New-Object System.Collections.Generic.List[object]
    function Probe([string]$pid_, [string]$name, [string]$sql, [string]$okPattern, [switch]$NoQI, [switch]$Info) {
        $r = if ($NoQI) { Q $BM1 $P $sql -NoQI } else { Q $BM1 $P $sql }
        $txt = (($r.Lines | Where-Object { $_.Trim() }) -join ' / ')
        $ok = ($r.Exit -eq 0) -and ($txt -match $okPattern)
        $err = (@($r.Lines | Where-Object { $_ -match '^Msg \d+' }) | Select-Object -First 1)
        $errText = if ($err) { $i = [Array]::IndexOf($r.Lines, $err); "$err $($r.Lines[[Math]::Min($i + 1, $r.Lines.Count - 1)])" } else { '' }
        $verdict = if ($ok) { 'SUPPORTED' } elseif ($errText) { 'UNSUPPORTED/REFUSED' } else { 'FAILED' }
        $probe.Add([pscustomobject]@{ Id = $pid_; Name = $name; Verdict = $verdict; Info = [bool]$Info })
        Log ''; Log "[$pid_] $name"; Log "  SQL: $sql"; Log "  sqlcmd exit $($r.Exit); output: $($txt.Substring(0, [Math]::Min(700, $txt.Length)))"
        Log "  RESULT $pid_ : $verdict$(if ($errText) { ' - ' + $errText })"
        return $r
    }
    function PlanUses([string]$sql, [string]$obj) {
        $po = (& sqlcmd -S $BM1 -E -I -b -y 0 -d $P -Q ("SET NOCOUNT ON; SET STATISTICS XML ON; " + $sql + " SET STATISTICS XML OFF;") 2>&1) -join "`n"
        $m = [regex]::Match($po, '<ShowPlanXML[\s\S]*?</ShowPlanXML>')
        if (-not $m.Success) { return 'plan not captured' }
        $idx = ([regex]::Matches($m.Value, 'Index="\[([^\]]+)\]"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique) -join ', '
        $mode = ([regex]::Matches($m.Value, 'ActualExecutionMode="([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique) -join ', '
        return "indexes read: [$idx]; uses ${obj}: $($m.Value -match [regex]::Escape($obj)); execution mode: $mode"
    }
    $null = Probe '3e' 'GENERATE_SERIES (compatibility 160)' "SELECT 'N', COUNT(*) FROM GENERATE_SERIES(1, 10000);" 'N\|10000'
    $null = Probe 'setup' 'Probe table with 10,000 rows' "CREATE TABLE dbo.probe_t (id int NOT NULL CONSTRAINT pk_probe_t PRIMARY KEY, grp int NOT NULL, st char(4) NOT NULL, amt decimal(18,2) NOT NULL); INSERT dbo.probe_t SELECT value, value % 10, CASE WHEN value % 2 = 0 THEN 'PAID' ELSE 'PEND' END, value FROM GENERATE_SERIES(1, 10000); SELECT 'ROWS', COUNT(*) FROM dbo.probe_t;" 'ROWS\|10000' -Info
    $null = Probe '3a' 'Filtered index' "CREATE INDEX ix_probe_filtered ON dbo.probe_t (grp) INCLUDE (amt) WHERE st = 'PAID'; SELECT 'FI', has_filter, CONVERT(varchar(100), filter_definition) FROM sys.indexes WHERE name = 'ix_probe_filtered';" 'FI\|1\|'
    Log ("  3a plan check (INFO): " + (PlanUses "SELECT grp, SUM(amt) AS s FROM dbo.probe_t WHERE st = 'PAID' AND grp = 3 GROUP BY grp;" 'ix_probe_filtered'))
    $null = Probe '3b' 'Partition function and scheme on a 3-row table' "CREATE PARTITION FUNCTION pf_probe (int) AS RANGE RIGHT FOR VALUES (2, 3); CREATE PARTITION SCHEME ps_probe AS PARTITION pf_probe ALL TO ([PRIMARY]); CREATE TABLE dbo.probe_part (id int NOT NULL CONSTRAINT pk_probe_part PRIMARY KEY) ON ps_probe (id); INSERT dbo.probe_part VALUES (1), (2), (3); SELECT 'PART', COUNT(*), SUM(CASE WHEN rows = 1 THEN 1 ELSE 0 END) FROM sys.partitions WHERE object_id = OBJECT_ID('dbo.probe_part') AND index_id = 1; SELECT 'PFN', `$PARTITION.pf_probe(id), id FROM dbo.probe_part ORDER BY id;" 'PART\|3\|3'
    $null = Probe '3c-1' 'Indexed view: create (SCHEMABINDING, unique clustered index)' "EXEC (N'CREATE VIEW dbo.v_probe WITH SCHEMABINDING AS SELECT grp, SUM(amt) AS s, COUNT_BIG(*) AS c FROM dbo.probe_t WHERE st = ''PAID'' GROUP BY grp;'); CREATE UNIQUE CLUSTERED INDEX ix_v_probe ON dbo.v_probe (grp); SELECT 'IV', COUNT(*) FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.v_probe') AND index_id = 1;" 'IV\|1'
    $m1 = PlanUses "SELECT grp, SUM(amt) AS s FROM dbo.probe_t WHERE st = 'PAID' GROUP BY grp;" 'ix_v_probe'
    $m2 = PlanUses "SELECT grp, s FROM dbo.v_probe WITH (NOEXPAND);" 'ix_v_probe'
    $m3 = PlanUses "SELECT grp, s FROM dbo.v_probe;" 'ix_v_probe'
    Log ''; Log '[3c-2] Indexed view: optimizer matching'
    Log "  base-table query, no hint : $m1"; Log "  view WITH (NOEXPAND)      : $m2"; Log "  view without hint         : $m3"
    $auto = ($m1 -match 'uses ix_v_probe: True'); $noexp = ($m2 -match 'uses ix_v_probe: True')
    $probe.Add([pscustomobject]@{ Id = '3c-2'; Name = 'Indexed view matched automatically (no NOEXPAND)'; Verdict = $(if ($auto) { 'SUPPORTED' } else { 'UNSUPPORTED/REFUSED' }); Info = $false })
    $probe.Add([pscustomobject]@{ Id = '3c-3'; Name = 'Indexed view usable WITH (NOEXPAND)'; Verdict = $(if ($noexp) { 'SUPPORTED' } else { 'FAILED' }); Info = $false })
    Log "  RESULT 3c-2 : $(if ($auto) { 'SUPPORTED (automatic matching)' } else { 'UNSUPPORTED on this engine edition: the view index is not used unless NOEXPAND is written' })"
    Log "  RESULT 3c-3 : $(if ($noexp) { 'SUPPORTED' } else { 'FAILED' })"
    $null = Probe '3d' 'CREATE INDEX ... WITH (ONLINE = ON)' "CREATE INDEX ix_probe_online ON dbo.probe_t (amt) WITH (ONLINE = ON); SELECT 'ONL', COUNT(*) FROM sys.indexes WHERE name = 'ix_probe_online';" 'ONL\|1'
    $null = Probe '3f-1' 'DML on a table with a filtered index and an indexed view, sqlcmd WITH -I (QUOTED_IDENTIFIER ON)' "UPDATE dbo.probe_t SET amt = amt + 1 WHERE id = 2; SELECT 'DML', @@ROWCOUNT;" 'DML\|1'
    $r = Probe '3f-2' 'Same DML, sqlcmd WITHOUT -I (QUOTED_IDENTIFIER OFF): expected to be refused with message 1934' "UPDATE dbo.probe_t SET amt = amt + 1 WHERE id = 2; SELECT 'DML', @@ROWCOUNT;" 'DML\|1' -NoQI -Info
    Log ("  3f-2 interpretation: " + $(if (($r.Lines -join ' ') -match 'Msg 1934') { 'refused with Msg 1934 as documented -> every P3 script and client must keep QUOTED_IDENTIFIER ON (sqlcmd -I; SqlClient default ON)' } else { 'not refused (see output)' }))
    $null = Probe '3g' 'Nonclustered columnstore index (roadmap candidate IX-10, optional; INFO, not a WO criterion)' "CREATE NONCLUSTERED COLUMNSTORE INDEX ix_probe_ncci ON dbo.probe_t (grp, st, amt); SELECT 'CS', COUNT(*) FROM sys.indexes WHERE name = 'ix_probe_ncci' AND type = 6;" 'CS\|1' -Info
    Log ("  3g plan check (INFO): " + (PlanUses "SELECT grp, SUM(amt) AS s, COUNT_BIG(*) AS c FROM dbo.probe_t GROUP BY grp;" 'ix_probe_ncci'))
    # task 4: PowerShell System.Data.SqlClient with Windows authentication
    Log ''; Log '[task 4] PowerShell 5.1 System.Data.SqlClient, Windows authentication, no stored credential'
    $t4 = ''; try { $cn = New-Object System.Data.SqlClient.SqlConnection "Server=$BM1;Database=$P;Integrated Security=SSPI;Application Name=P3-ENV-P0;Pooling=false"; $cn.Open(); $cm = $cn.CreateCommand(); $cm.CommandText = "SELECT CONCAT(@@SERVICENAME, '|', DB_NAME(), '|', CONVERT(varchar(5), SESSIONPROPERTY('QUOTED_IDENTIFIER')), '|', (SELECT COUNT(*) FROM dbo.probe_t))"; $t4 = "$($cm.ExecuteScalar())"; $cn.Close() } catch { $t4 = "ERROR $($_.Exception.Message)" }
    Log "  result: service|database|QUOTED_IDENTIFIER|rows = $t4"
    $probe.Add([pscustomobject]@{ Id = 'task4'; Name = 'System.Data.SqlClient connectivity'; Verdict = $(if ($t4 -eq "$BM1Service|$P|1|10000") { 'SUPPORTED' } else { 'FAILED' }); Info = $false })
    # cleanup: drop only the marked probe database
    $d = Q $BM1 'master' "IF @@SERVICENAME <> N'$BM1Service' THROW 51900, N'wrong instance', 1; DECLARE @m nvarchar(200); EXEC sys.sp_executesql N'SELECT @m = CONVERT(nvarchar(200), value) FROM [$P].sys.extended_properties WHERE class = 0 AND name = N''P3_Disposable'';', N'@m nvarchar(200) OUTPUT', @m = @m OUTPUT; IF @m IS NULL OR @m NOT LIKE N'WO-P3-P0-02%' THROW 51901, N'probe marker missing; not dropped', 1; ALTER DATABASE [$P] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$P]; SELECT 'DROPPED', CASE WHEN DB_ID(N'$P') IS NULL THEN 'yes' ELSE 'no' END;"
    $dbAfter = Q $BM1 'master' "SELECT 'DB', name FROM sys.databases ORDER BY database_id;"
    Log ''; Log ("Databases on BM-1 after: " + ((@($dbAfter.Lines | Where-Object { $_ -like 'DB|*' }) | ForEach-Object { ($_ -split '\|')[1] }) -join ', '))
    Log ''; Log 'Feature summary (id | capability | result):'
    foreach ($x in $probe) { Log ("  {0,-6} | {1} | {2}{3}" -f $x.Id, $x.Name, $x.Verdict, $(if ($x.Info) { ' (INFO)' } else { '' })) }
    Check 'F1' (@($probe | Where-Object { $_.Verdict -eq 'FAILED' -and -not $_.Info }).Count -eq 0) 'Every probe produced a recorded result (SUPPORTED or UNSUPPORTED with its message); none failed to execute' ''
    Check 'F2' (((Val $d 'DROPPED')[1] -eq 'yes') -and ((($dbAfter.Lines | Where-Object { $_ -like 'DB|*' }) -join ',') -eq (($dbBefore.Lines | Where-Object { $_ -like 'DB|*' }) -join ','))) "Probe database dropped; database list after = before" ''
    Finish
}

# =====================================================================
if ($Stage -eq 'Validate') {
    $T = 'FitLife_P3_P2'
    $refChecksum = Join-Path $repo 'docs/phase2/person3/evidence/test-results/CHECKSUMS__DS-L__20261108-1155_C.txt'
    $refLines = (Get-Content -Encoding UTF8 $refChecksum) -join "`n"
    $m = Q $BM1 'master' "SELECT 'T', CASE WHEN DB_ID(N'$T') IS NULL THEN 'absent' ELSE 'EXISTS' END; IF DB_ID(N'$T') IS NOT NULL EXEC (N'SELECT ''MARKER'', CONVERT(nvarchar(200), value) FROM [$T].sys.extended_properties WHERE class = 0 AND name = N''P3_Disposable'';');"
    $mk = "$((Val $m 'MARKER')[1])"
    Check 'V0' ($mk -like 'WO-P3-P2-01*') "$T on BM-1 exists and carries the WO-P3-P2-01 disposable marker" $mk
    if ($mk -notlike 'WO-P3-P2-01*') { Finish }
    $v3 = Q $BM1 $T "SELECT 'V3', COUNT(*) FROM sys.check_constraints WHERE name = N'CK_MEMBER_MONTHLY_SPENDING_PointsRule';"
    if ((Val $v3 'V3')[1] -eq '0') {
        $a = Sql $BM1 @('-I', '-d', $T, '-i', 'db/migrations/V003__p3_points_earned_rule.sql'); foreach ($l in $a.Lines) { if ($l.Trim()) { Log "  $l" } }
        Check 'V1' (($a.Exit -eq 0) -and (($a.Lines -join ' ') -match 'V003 applied')) 'V003 (approved integrity migration, D-006 (b)) applied WITH CHECK: all 169,040 rows validated by the engine' ("SHA-256 " + (Get-FileHash -Algorithm SHA256 (Join-Path $repo 'db/migrations/V003__p3_points_earned_rule.sql')).Hash)
    } else { Check 'V1' $true 'V003 already applied' '' }
    $q = @"
SELECT 'DBP', compatibility_level, recovery_model_desc, is_read_committed_snapshot_on, snapshot_isolation_state_desc, is_auto_create_stats_on, is_auto_update_stats_on, is_auto_update_stats_async_on, is_read_only FROM sys.databases WHERE name = DB_NAME();
SELECT 'ROWS', (SELECT COUNT_BIG(*) FROM dbo.INVOICE), (SELECT COUNT_BIG(*) FROM dbo.INVOICE_SERVICE_ITEM), (SELECT COUNT_BIG(*) FROM dbo.INVOICE_PRODUCT_ITEM), (SELECT COUNT_BIG(*) FROM dbo.MEMBER_MONTHLY_SPENDING), (SELECT COUNT(*) FROM dbo.MEMBER), (SELECT COUNT(*) FROM dbo.BRANCH), (SELECT COUNT(*) FROM dbo.EMPLOYEE), (SELECT COUNT(*) FROM dbo.SERVICE_PLAN), (SELECT COUNT(*) FROM dbo.PRODUCT);
SELECT 'CONS', (SELECT COUNT(*) FROM sys.key_constraints WHERE type = 'PK'), (SELECT COUNT(*) FROM sys.foreign_keys), (SELECT COUNT(*) FROM sys.check_constraints), (SELECT COUNT(*) FROM sys.default_constraints), (SELECT COUNT(*) FROM sys.foreign_keys WHERE is_disabled = 1 OR is_not_trusted = 1) + (SELECT COUNT(*) FROM sys.check_constraints WHERE is_disabled = 1 OR is_not_trusted = 1);
SELECT 'V003', name, is_disabled, is_not_trusted, CONVERT(varchar(100), definition) FROM sys.check_constraints WHERE name = N'CK_MEMBER_MONTHLY_SPENDING_PointsRule';
SELECT 'OBJ', (SELECT COUNT(*) FROM sys.tables), (SELECT COUNT(*) FROM sys.indexes i JOIN sys.tables t ON t.object_id = i.object_id WHERE i.type > 0 AND i.is_primary_key = 0), (SELECT COUNT(*) FROM sys.indexes i JOIN sys.tables t ON t.object_id = i.object_id WHERE i.type NOT IN (0, 1)), (SELECT COUNT(*) FROM sys.views), (SELECT COUNT(*) FROM sys.triggers), (SELECT COUNT(*) FROM sys.partition_functions) + (SELECT COUNT(*) FROM sys.partition_schemes), (SELECT COUNT(*) FROM sys.objects WHERE is_ms_shipped = 0 AND type IN ('P', 'FN', 'IF', 'TF')), (SELECT COUNT(*) FROM sys.partitions p JOIN sys.tables t ON t.object_id = p.object_id WHERE p.data_compression <> 0);
SELECT 'IDX', t.name, i.name, i.type_desc, i.is_primary_key FROM sys.indexes i JOIN sys.tables t ON t.object_id = i.object_id WHERE i.type > 0 ORDER BY t.name, i.index_id;
SELECT 'VTOT', COUNT(*) FROM dbo.INVOICE i OUTER APPLY (SELECT SUM(UnitPrice) g, SUM(DiscountAmount) d, COUNT(*) c FROM dbo.INVOICE_SERVICE_ITEM WHERE Invoice_ID = i.Invoice_ID) s OUTER APPLY (SELECT SUM(UnitPrice * Quantity) g, SUM(DiscountAmount) d, COUNT(*) c FROM dbo.INVOICE_PRODUCT_ITEM WHERE Invoice_ID = i.Invoice_ID) p WHERE i.GrossAmount <> ISNULL(s.g, 0) + ISNULL(p.g, 0) OR i.DiscountAmount <> ISNULL(s.d, 0) + ISNULL(p.d, 0) OR i.FinalAmount <> i.GrossAmount - i.DiscountAmount OR s.c + p.c = 0;
WITH o AS (SELECT Member_ID, DATEFROMPARTS(YEAR(DATEADD(HOUR, 7, PaidAt)), MONTH(DATEADD(HOUR, 7, PaidAt)), 1) AS m, SUM(FinalAmount) AS s FROM dbo.INVOICE WHERE PaymentStatus = 'PAID' GROUP BY Member_ID, DATEFROMPARTS(YEAR(DATEADD(HOUR, 7, PaidAt)), MONTH(DATEADD(HOUR, 7, PaidAt)), 1))
SELECT 'SPEND', COUNT(*) FROM o FULL JOIN dbo.MEMBER_MONTHLY_SPENDING t ON t.Member_ID = o.Member_ID AND t.SpendingMonth = o.m WHERE o.Member_ID IS NULL OR t.Member_ID IS NULL OR o.s <> t.TotalSpend OR t.PointsEarned <> CONVERT(int, FLOOR(t.TotalSpend / 100000));
SELECT 'PAY', COUNT(*) FROM dbo.INVOICE WHERE (PaymentStatus = 'PAID' AND (PaidAt IS NULL OR PaidAt < IssuedAt OR PaymentMethod IS NULL)) OR (PaymentStatus <> 'PAID' AND PaidAt IS NOT NULL);
SELECT 'SIZE', SUM(reserved_page_count) * 8 / 1024 FROM sys.dm_db_partition_stats;
SELECT 'STATS', COUNT(*), SUM(CASE WHEN auto_created = 1 THEN 1 ELSE 0 END) FROM sys.stats st JOIN sys.tables t ON t.object_id = st.object_id;
"@
    $r = Q $BM1 $T $q; foreach ($l in $r.Lines) { if ($l.Trim()) { Log "  $l" } }
    $dbp = Val $r 'DBP'; $rows = Val $r 'ROWS'; $cons = Val $r 'CONS'; $obj = Val $r 'OBJ'; $v003 = Val $r 'V003'
    Check 'V2' (($dbp[1] -eq '160') -and ($dbp[2] -eq 'SIMPLE') -and ($dbp[3] -eq '0') -and ($dbp[4] -eq 'OFF') -and ($dbp[8] -eq '0')) 'Compatibility level 160; SIMPLE recovery; RCSI and snapshot isolation OFF (D-019 (a)); read-write' ($dbp -join '|')
    Check 'V3' ((($rows[1..9]) -join ',') -eq '324000,65177,712789,169040,30000,12,120,30,200') 'Exact row counts = DS-L run C (INVOICE 324,000; service items 65,177; product items 712,789; monthly spending 169,040; fixtures 30,000/12/120/30/200)' (($rows[1..9]) -join ',')
    Check 'V4' (($cons[1] -eq '9') -and ($cons[2] -eq '8') -and ($cons[3] -eq '14') -and ($cons[4] -eq '4') -and ($cons[5] -eq '0')) 'Migration content: 9 PK, 8 FK, 14 CHECK (13 of V001+V002 plus V003), 4 DEFAULT; every FK and CHECK enabled and trusted' ($cons -join '|')
    Check 'V5' (($v003.Count -ge 4) -and ($v003[2] -eq '0') -and ($v003[3] -eq '0')) 'V003 CK_MEMBER_MONTHLY_SPENDING_PointsRule enabled and trusted (an integrity constraint; it creates no index)' ($v003 -join '|')
    Check 'V6' (($obj[1] -eq '9') -and ($obj[2] -eq '0') -and ($obj[3] -eq '0') -and ($obj[4] -eq '0') -and ($obj[5] -eq '0') -and ($obj[6] -eq '0') -and ($obj[7] -eq '0') -and ($obj[8] -eq '0')) 'B0 inventory: 9 tables; indexes = clustered primary keys only (0 non-PK, 0 nonclustered/columnstore); 0 views, triggers, partition objects, routines, compressed partitions' ($obj -join '|')
    Check 'V7' (((Val $r 'VTOT')[1] -eq '0') -and ((Val $r 'PAY')[1] -eq '0')) 'Monetary consistency: every header = sum of its lines, FinalAmount = Gross - Discount, every invoice has a line; payment-state rules hold' "header/line mismatches $((Val $r 'VTOT')[1]); payment-state violations $((Val $r 'PAY')[1])"
    Check 'V8' ((Val $r 'SPEND')[1] -eq '0') 'Monthly spending = SUM(FinalAmount) of PAID invoices per member and local month, and PointsEarned = FLOOR(TotalSpend / 100000), for every row' "mismatches $((Val $r 'SPEND')[1])"
    $ck = Sql $BM1 @('-I', '-d', $T, '-v', 'MaxGrantPercent=10', '-i', 'tests/db/seed/T-REPRO-02_checksums.sql')
    Log '-- T-REPRO-02 canonical checksums on BM-1 (after V003) --'; foreach ($l in $ck.Lines) { if ($l.Trim()) { Log "  $l" } }
    $ckPath = Join-Path $EvidenceDir "ENV-P0__${ts}_Validate__checksums.txt"; ($ck.Lines | ForEach-Object { Hide $_ }) | Out-File -Encoding utf8 $ckPath
    Check 'V9' ((((Get-Content -Encoding UTF8 $ckPath) -join "`n") -eq $refLines)) 'Canonical data fingerprint: T-REPRO-02 output byte-identical to CHECKSUMS__DS-L__20261108-1155_C.txt (every table hash and the dataset checksum)' (@($ck.Lines | Where-Object { $_ -like 'DATASET_CHECKSUM*' })[0])
    $dg = Sql $BM1 @('-I', '-d', $T, '-i', 'tests/db/schema/catalog_digest.sql')
    Log ("Catalog digest of B0 on BM-1: " + (@($dg.Lines | Where-Object { $_ -like 'CATALOG_DIGEST|*' })[0]))
    # E5: database-scoped configuration, recorded and compared with the default-instance copy (read only)
    $e5 = "SELECT 'DSC', name, CONVERT(varchar(20), value) FROM sys.database_scoped_configurations WHERE name IN ('MAXDOP','DOP_FEEDBACK','CE_FEEDBACK','ROW_MODE_MEMORY_GRANT_FEEDBACK','BATCH_MODE_MEMORY_GRANT_FEEDBACK','MEMORY_GRANT_FEEDBACK_PERSISTENCE','MEMORY_GRANT_FEEDBACK_PERCENTILE_GRANT','PARAMETER_SENSITIVE_PLAN_OPTIMIZATION','OPTIONAL_PARAMETER_OPTIMIZATION','BATCH_MODE_ON_ROWSTORE','LEGACY_CARDINALITY_ESTIMATION','QUERY_OPTIMIZER_HOTFIXES') ORDER BY name; SELECT 'QS', actual_state_desc, query_capture_mode_desc FROM sys.database_query_store_options;"
    $a = Q $BM1 $T $e5; $b = Q $DefaultInst $T $e5
    Log '-- E5 database-scoped configuration of FitLife_P3_P2 on BM-1 (initial benchmark configuration; nothing changed) --'; foreach ($l in $a.Lines) { if ($l.Trim()) { Log "  $l" } }
    Check 'V10' ((($a.Lines | Where-Object { $_ -like 'DSC|*' }) -join ';') -eq (($b.Lines | Where-Object { $_ -like 'DSC|*' }) -join ';')) 'E5: database-scoped configuration on BM-1 identical to the default-instance copy used by all earlier diagnostics (engine defaults, untouched)' ("Query Store BM-1: " + ((Val $a 'QS') -join '|') + "; default instance: " + ((Val $b 'QS') -join '|'))
    $ockF = Sql $DefaultInst @('-I', '-d', $T, '-v', 'MaxGrantPercent=10', '-i', 'tests/db/seed/T-REPRO-02_checksums.sql')
    $ol = @($ockF.Lines | Where-Object { $_ -like 'DATASET_CHECKSUM*' })[0]
    Check 'V11' ($ol -eq (@((Get-Content -Encoding UTF8 $refChecksum) | Where-Object { $_ -like 'DATASET_CHECKSUM*' })[0])) 'Original FitLife_P3_P2 on the default instance MSSQLSERVER untouched (read-only checksum = run C)' "$ol"
    Finish
}
