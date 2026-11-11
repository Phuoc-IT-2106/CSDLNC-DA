# A6 routing adapter: derived from byte-preserved r27_diag.ps1; selected-instance D3/D4 reads use -Server. D5 remains a read-only BM-1 inventory.
# R-27 environment diagnostic - read-only. Changes no setting, service, database or file except the output file.
param([Parameter(Mandatory)][string]$OutFile, [string]$Server = 'localhost')
$ErrorActionPreference = 'Continue'
$inv = [Globalization.CultureInfo]::InvariantCulture
$host_ = $env:COMPUTERNAME
$lines = New-Object System.Collections.Generic.List[string]
function Add([string]$s) { $lines.Add(($s -replace [regex]::Escape($host_), '<local-server>')) }
function Sql([string]$server, [string]$q) {
    (& sqlcmd -S $server -E -I -W -s '|' -l 5 -Q ("SET NOCOUNT ON; " + $q) 2>&1) | ForEach-Object { Add ([string]$_) }
}
Add "R-27-DIAG - read-only environment diagnostic for R-27 (Owner Directive 'Accept P2-01 and Resolve R-27', VERIFY_ONLY)."
Add ("Captured (UTC): " + (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss', $inv) + ". Machine and server names masked as <local-server>. No setting was changed.")
Add ""
Add "== D1. Power =="
$bat = Get-CimInstance Win32_Battery
Add ("BatteryStatus (1 = discharging / on battery, 2 = on AC): {0}; charge %: {1}" -f $bat.BatteryStatus, $bat.EstimatedChargeRemaining)
(powercfg /getactivescheme) | ForEach-Object { Add $_ }
Add "Sleep after (STANDBYIDLE) and display off (VIDEOIDLE), seconds as hex:"
(powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE | Select-String 'Current (AC|DC)') | ForEach-Object { Add ("  STANDBYIDLE " + $_.Line.Trim()) }
(powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE | Select-String 'Current (AC|DC)') | ForEach-Object { Add ("  VIDEOIDLE " + $_.Line.Trim()) }
Add ("Sleep states available: " + ((powercfg /a | Select-Object -First 4 | Select-Object -Skip 1) -join '; ').Trim())
Add "Power events (System log, Kernel-Power 42/107/506/507, Power-Troubleshooter 1, Kernel-Power 105) in the last 24 h, UTC:"
try {
    Get-WinEvent -FilterHashtable @{LogName='System'; StartTime=(Get-Date).AddHours(-24); ProviderName='Microsoft-Windows-Kernel-Power','Microsoft-Windows-Power-Troubleshooter'} -ErrorAction Stop |
      Where-Object { $_.Id -in 1,42,105,107,506,507 } | Sort-Object TimeCreated |
      ForEach-Object { Add ("  {0}  id={1}  {2}" -f $_.TimeCreated.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss', $inv), $_.Id, (($_.Message -split "`n")[0]).Trim()) }
} catch { Add "  none" }
Add ""
Add "== D2. Hardware and OS memory =="
$cpu = Get-CimInstance Win32_Processor
Add ("CPU: {0}; cores {1}; logical {2}; load % now {3}" -f $cpu.Name.Trim(), $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors, $cpu.LoadPercentage)
$os = Get-CimInstance Win32_OperatingSystem
Add ("OS: {0} build {1}" -f $os.Caption, $os.BuildNumber)
Add ("RAM MB total {0}; free {1}; commit limit {2}; commit in use {3}" -f [int]($os.TotalVisibleMemorySize/1024), [int]($os.FreePhysicalMemory/1024), [int]($os.TotalVirtualMemorySize/1024), [int](($os.TotalVirtualMemorySize-$os.FreeVirtualMemory)/1024))
Get-CimInstance Win32_PageFileUsage | ForEach-Object { Add ("Page file: allocated MB {0}; current use MB {1}; peak MB {2}" -f $_.AllocatedBaseSize, $_.CurrentUsage, $_.PeakUsage) }
Get-PhysicalDisk | ForEach-Object { Add ("Disk: {0} {1} {2} GB" -f $_.MediaType, $_.BusType, [int]($_.Size/1GB)) }
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object { Add ("Volume {0}: size GB {1}; free GB {2}" -f $_.DeviceID, [int]($_.Size/1GB), [math]::Round($_.FreeSpace/1GB,1)) }
Add "Top 12 process groups by private memory (MB):"
Get-Process | Group-Object ProcessName | ForEach-Object { [pscustomobject]@{N=$_.Name; C=$_.Count; P=[int](($_.Group | Measure-Object PrivateMemorySize64 -Sum).Sum/1MB); W=[int](($_.Group | Measure-Object WorkingSet64 -Sum).Sum/1MB)} } |
  Sort-Object P -Descending | Select-Object -First 12 | ForEach-Object { Add ("  {0,-16} x{1,-3} private {2,6}  working set {3,6}" -f $_.N, $_.C, $_.P, $_.W) }
Add "SQL Server services:"
Get-Service | Where-Object { $_.Name -match '^MSSQL|^SQLAgent' } | ForEach-Object { Add ("  {0}: {1} ({2})" -f $_.Name, $_.Status, $_.StartType) }
Add ""
Add "== D3. SQL Server $Server (selected benchmark instance) =="
Sql $Server "SELECT total_physical_memory_kb/1024 total_mb, available_physical_memory_kb/1024 avail_mb, system_memory_state_desc FROM sys.dm_os_sys_memory;
SELECT physical_memory_in_use_kb/1024 in_use_mb, locked_page_allocations_kb/1024 locked_mb, memory_utilization_percentage util_pct, process_physical_memory_low, page_fault_count FROM sys.dm_os_process_memory;
SELECT committed_kb/1024 committed_mb, committed_target_kb/1024 target_mb, sql_memory_model_desc, cpu_count, sqlserver_start_time FROM sys.dm_os_sys_info;
SELECT pool_id, resource_semaphore_id, target_memory_kb/1024 target_mb, max_target_memory_kb/1024 max_target_mb, available_memory_kb/1024 avail_mb, waiter_count, timeout_error_count, forced_grant_count FROM sys.dm_exec_query_resource_semaphores ORDER BY pool_id, resource_semaphore_id;
SELECT name, value_in_use FROM sys.configurations WHERE name IN ('max server memory (MB)','min server memory (MB)','max degree of parallelism','cost threshold for parallelism','min memory per query (KB)') ORDER BY name;
SELECT wait_type, waiting_tasks_count, wait_time_ms/1000 wait_s, max_wait_time_ms/1000 max_wait_s FROM sys.dm_os_wait_stats WHERE wait_type IN ('RESOURCE_SEMAPHORE','PAGEIOLATCH_SH','SOS_SCHEDULER_YIELD','CXPACKET','MEMORY_ALLOCATION_EXT') ORDER BY wait_time_ms DESC;
CREATE TABLE #e (LogDate datetime, ProcessInfo nvarchar(50), Text nvarchar(max)); INSERT #e EXEC xp_readerrorlog 0, 1, N'paged out';
SELECT CONVERT(char(10), LogDate, 23) log_day, COUNT(*) paged_out_messages FROM #e WHERE LogDate >= DATEADD(day, -10, GETDATE()) GROUP BY CONVERT(char(10), LogDate, 23) ORDER BY 1 DESC; DROP TABLE #e;"
Add ""
Add "== D4. Database-scoped settings of FitLife_P3_P2 that affect repeated executions =="
Sql $Server "USE FitLife_P3_P2; SELECT name, CONVERT(nvarchar(20), value) value FROM sys.database_scoped_configurations WHERE name IN ('MAXDOP','DOP_FEEDBACK','CE_FEEDBACK','ROW_MODE_MEMORY_GRANT_FEEDBACK','BATCH_MODE_MEMORY_GRANT_FEEDBACK','MEMORY_GRANT_FEEDBACK_PERSISTENCE','MEMORY_GRANT_FEEDBACK_PERCENTILE_GRANT','PARAMETER_SENSITIVE_PLAN_OPTIMIZATION','OPTIONAL_PARAMETER_OPTIMIZATION','BATCH_MODE_ON_ROWSTORE') ORDER BY name;
SELECT actual_state_desc query_store, query_capture_mode_desc FROM sys.database_query_store_options;
SELECT compatibility_level, recovery_model_desc, is_read_committed_snapshot_on rcsi, is_auto_update_stats_on auto_update_stats FROM sys.databases WHERE name = DB_NAME();
SELECT SUM(reserved_page_count)*8/1024 reserved_mb_all_tables FROM sys.dm_db_partition_stats;"
Add ""
Add "== D5. Second instance MSSQLSERVER01 =="
Sql 'localhost\MSSQLSERVER01' "SELECT physical_memory_in_use_kb/1024 in_use_mb FROM sys.dm_os_process_memory; SELECT COUNT(*) user_databases FROM sys.databases WHERE database_id > 4; SELECT name, value_in_use FROM sys.configurations WHERE name IN ('max server memory (MB)','min server memory (MB)') ORDER BY name;"
$lines | Out-File -Encoding utf8 $OutFile
"written: $OutFile ($($lines.Count) lines)"
