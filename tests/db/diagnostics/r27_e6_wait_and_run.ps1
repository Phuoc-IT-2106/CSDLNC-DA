# Operator helper for the R-27 E6 recheck (not part of the measurement). Holds a process-scoped keep-awake request
# (SetThreadExecutionState; no power setting changed; released when this process ends), waits until no power event has
# occurred for CleanMinutes and available memory >= MinFreeMb, then runs the reviewed harness once. Kills nothing,
# changes nothing. The harness re-checks every precondition itself.
param([int]$CleanMinutes = 10, [int]$MinFreeMb = 2100, [int]$MaxWaitMinutes = 40,
      [string]$Server = 'localhost',
      [string]$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path,
      [string]$Harness = (Join-Path $PSScriptRoot 'r27_e6_probe.ps1'),
      [string]$Scratch = (Join-Path $env:TEMP 'p3_r27'))
$ErrorActionPreference = 'Stop'
Add-Type -Namespace P3W -Name Power -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);'
function Utc { (Get-Date).ToUniversalTime().ToString('HH:mm:ss') }
[void][P3W.Power]::SetThreadExecutionState([uint32]2147483651)   # ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED
try {
    $deadline = (Get-Date).AddMinutes($MaxWaitMinutes)
    while ($true) {
        $ev = $null
        try { $ev = Get-WinEvent -FilterHashtable @{LogName='System'; StartTime=(Get-Date).AddMinutes(-90); ProviderName='Microsoft-Windows-Kernel-Power','Microsoft-Windows-Power-Troubleshooter'} -ErrorAction Stop | Where-Object { $_.Id -in 1,42,105,107,506,507 } | Sort-Object TimeCreated -Descending | Select-Object -First 1 } catch { }
        $last = if ($ev) { $ev.TimeCreated } else { (Get-Date).AddMinutes(-90) }
        $clean = ((Get-Date) - $last).TotalMinutes
        $free = [int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024)
        "{0} UTC wait: last power event {1} UTC ({2:0.0} min clean); free {3} MB" -f (Utc), $last.ToUniversalTime().ToString('HH:mm:ss'), $clean, $free
        if ($clean -ge ($CleanMinutes + 0.5) -and $free -ge $MinFreeMb) { break }
        if ((Get-Date) -gt $deadline) { "$(Utc) UTC wait timed out after $MaxWaitMinutes min; harness not started"; exit 3 }
        Start-Sleep -Seconds 30
    }
    "$(Utc) UTC conditions met; starting harness"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $Harness -Server $Server -Repo $Repo -Scratch $Scratch
    "$(Utc) UTC harness exit=$LASTEXITCODE"
} finally {
    [void][P3W.Power]::SetThreadExecutionState([uint32]2147483648)
}
