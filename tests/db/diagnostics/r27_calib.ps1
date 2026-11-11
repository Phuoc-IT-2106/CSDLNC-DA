# R-27 timing-instrument calibration (diagnostic, SELECT-only; Owner Directive "R-27 Targeted Remediation and Recheck" s3).
# Purpose: measure the real resolution of each timing source before choosing the E6 method. Not an E6 run, not a baseline.
# Runs the unchanged R-27 probe statements on FitLife_P3_P2 and, after each execution, reads that statement's row in
# sys.dm_exec_query_stats (identified by query_hash from the 13:21 actual plans). Changes no setting, schema, data or cache.
param(
    [string]$Repo = 'C:\Users\DELL\source\repos\CSDLNC-DA',
    [string]$Scratch = 'C:\Users\DELL\AppData\Local\Temp\claude\d90cc3f645cab87d\84a34247-a83b-4f83-bdc1-a0d703ac4983\scratchpad',
    [int]$Per = 12,
    [string]$EvOverride = ''
)
$ErrorActionPreference = 'Stop'
$inv = [Globalization.CultureInfo]::InvariantCulture
$Db = 'FitLife_P3_P2'
$Ev = Join-Path $Repo 'docs\phase2\person3\evidence\test-results'
if ($EvOverride) { $Ev = $EvOverride; New-Item -ItemType Directory -Force $Ev | Out-Null }
$ts = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmm', $inv)
$base = "R-27-CALIB__$ts"
$sum = Join-Path $Ev "$base.txt"
if (Test-Path $sum) { throw "refusing to overwrite $sum" }
$hostName = $env:COMPUTERNAME
function Mask([string]$s) { $s -replace [regex]::Escape($hostName), '<local-server>' }

# Probe statements: byte-identical to R-27-PROBE__20261108-1321 (P1-P4).
$Q = [ordered]@{
 'P1' = "/* R27-PROBE-P1 (Q-BIL-A shape) */ SELECT i.Invoice_ID, i.IssuedAt, i.PaidAt, i.PaymentStatus, i.FinalAmount, l.[LineNo], l.kind, l.item_id, l.amount FROM dbo.INVOICE i LEFT JOIN (SELECT Invoice_ID, [LineNo], 'S' AS kind, Plan_ID AS item_id, UnitPrice - DiscountAmount AS amount FROM dbo.INVOICE_SERVICE_ITEM UNION ALL SELECT Invoice_ID, [LineNo], 'P', Product_ID, UnitPrice * Quantity - DiscountAmount FROM dbo.INVOICE_PRODUCT_ITEM) l ON l.Invoice_ID = i.Invoice_ID WHERE i.Invoice_ID = 162001;"
 'P2' = "/* R27-PROBE-P2 (Q-UC06-A shape) */ SELECT SUM(FinalAmount) AS revenue, COUNT_BIG(*) AS invoices FROM dbo.INVOICE WHERE Branch_ID = 1 AND PaymentStatus = 'PAID' AND PaidAt >= '2025-05-31T17:00:00' AND PaidAt < '2025-06-30T17:00:00';"
 'P3' = "/* R27-PROBE-P3 (Q-UC06-B shape) */ SELECT Branch_ID, SUM(FinalAmount) AS revenue, COUNT_BIG(*) AS invoices FROM dbo.INVOICE WHERE PaymentStatus = 'PAID' AND PaidAt >= '2024-12-31T17:00:00' AND PaidAt < '2025-12-31T17:00:00' GROUP BY Branch_ID ORDER BY Branch_ID;"
 'P4' = "/* R27-PROBE-P4 (Q-UC06-F shape) */ SELECT p.Product_ID, SUM(p.Quantity) AS qty, SUM(p.UnitPrice * p.Quantity - p.DiscountAmount) AS revenue FROM dbo.INVOICE_PRODUCT_ITEM p JOIN dbo.INVOICE i ON i.Invoice_ID = p.Invoice_ID WHERE i.Branch_ID = 1 AND i.PaymentStatus = 'PAID' AND i.PaidAt >= '2025-03-31T17:00:00' AND i.PaidAt < '2025-06-30T17:00:00' GROUP BY p.Product_ID ORDER BY revenue DESC;"
}
$H = [ordered]@{ 'P1' = '0x68A12298847406D8'; 'P2' = '0x50153CD9BBFED3FF'; 'P3' = '0xCF46082B461EDD5A'; 'P4' = '0x629E3BE8ECE05C0B' }

$sql = New-Object System.Collections.Generic.List[string]
$sql.Add(':on error exit'); $sql.Add('SET NOCOUNT ON;')
$sql.Add("IF DB_NAME() <> N'$Db' OR NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = 'P3_Disposable') THROW 51090, N'wrong database', 1;"); $sql.Add('GO')
# SYSDATETIME() step size (server clock resolution), 20 samples
$sql.Add("PRINT '##TICK';")
$sql.Add("DECLARE @t TABLE (n int, ns bigint); DECLARE @i int = 0, @a datetime2(7), @b datetime2(7); WHILE @i < 20 BEGIN SET @a = SYSDATETIME(); SET @b = @a; WHILE @b = @a SET @b = SYSDATETIME(); INSERT @t VALUES (@i, DATEDIFF_BIG(nanosecond, @a, @b)); SET @i += 1; END; SELECT n, ns FROM @t ORDER BY n;"); $sql.Add('GO')
$dmvCols = "execution_count, last_worker_time, last_elapsed_time, last_logical_reads, last_physical_reads, plan_generation_num, CHECKSUM(plan_handle) AS plan_ck, CONVERT(varchar(23), creation_time, 121) AS created"
$sql.Add('SET STATISTICS IO, TIME ON;'); $sql.Add('GO')
foreach ($k in $Q.Keys) {
    for ($r = 0; $r -le $Per; $r++) {
        $sql.Add("PRINT '##BEGIN $k $r';"); $sql.Add('GO'); $sql.Add($Q[$k]); $sql.Add('GO')
        $sql.Add("PRINT '##DMV';"); $sql.Add("SELECT $dmvCols FROM sys.dm_exec_query_stats WHERE query_hash = $($H[$k]);"); $sql.Add('GO')
        $sql.Add("PRINT '##END';"); $sql.Add('GO')
    }
}
# GO-count semantics check: one GO 10 of P2, then the DMV row (execution_count must rise by exactly 10)
$sql.Add("PRINT '##GOK-BEFORE';"); $sql.Add("SELECT $dmvCols FROM sys.dm_exec_query_stats WHERE query_hash = $($H['P2']);"); $sql.Add('GO')
$sql.Add($Q['P2']); $sql.Add('GO 10')
$sql.Add("PRINT '##GOK-AFTER';"); $sql.Add("SELECT $dmvCols FROM sys.dm_exec_query_stats WHERE query_hash = $($H['P2']);"); $sql.Add('GO')
$sql.Add('SET STATISTICS IO, TIME OFF;'); $sql.Add('GO')
$f = Join-Path $Scratch 'r27_calib.sql'; $sql | Out-File -Encoding ascii $f

$t0 = (Get-Date).ToUniversalTime()
$out = (& sqlcmd -S localhost -E -I -b -W -s '|' -d $Db -i $f 2>&1) | ForEach-Object { [string]$_ }
$rc = $LASTEXITCODE
$t1 = (Get-Date).ToUniversalTime()
($out | ForEach-Object { Mask $_ }) | Out-File -Encoding utf8 (Join-Path $Ev "${base}__raw.txt")

# ---- parse ----
$rows = @(); $cur = $null; $buf = $null; $mode = ''
foreach ($line in $out) {
    if ($line -match '^##BEGIN (\S+) (\d+)') { $cur = @{ Q = $Matches[1]; R = [int]$Matches[2]; Stats = (New-Object System.Collections.Generic.List[string]); Dmv = $null }; $mode = 'S'; continue }
    if ($line -eq '##DMV') { $mode = 'D'; continue }
    if ($line -eq '##END') {
        if ($cur) {
            $cpu = $null; $el = $null; $b = $cur.Stats
            for ($i = $b.Count - 1; $i -ge 0; $i--) { if ($b[$i] -match 'SQL Server Execution Times') { for ($j = $i; $j -lt [Math]::Min($i + 3, $b.Count); $j++) { if ($b[$j] -match 'CPU time = (\d+) ms,\s*elapsed time = (\d+) ms') { $cpu = [int]$Matches[1]; $el = [int]$Matches[2]; break } }; break } }
            $lr = 0; $pr = 0; foreach ($l in $b) { foreach ($m in [regex]::Matches($l, ', logical reads (\d+), physical reads (\d+)')) { $lr += [long]$m.Groups[1].Value; $pr += [long]$m.Groups[2].Value } }
            $d = if ($cur.Dmv) { $cur.Dmv -split '\|' } else { @() }
            $rows += [pscustomobject]@{ Q = $cur.Q; R = $cur.R; StCpu = $cpu; StEl = $el; Lr = $lr; Pr = $pr; Exec = $(if ($d.Count) { [long]$d[0] } else { $null }); WkUs = $(if ($d.Count) { [long]$d[1] } else { $null }); ElUs = $(if ($d.Count) { [long]$d[2] } else { $null }); DLr = $(if ($d.Count) { [long]$d[3] } else { $null }); Gen = $(if ($d.Count) { $d[5] } else { $null }); Ck = $(if ($d.Count) { $d[6] } else { $null }); Rowsn = $(if ($cur.DmvN) { $cur.DmvN } else { 0 }) }
        }
        $cur = $null; $mode = ''; continue
    }
    if ($cur -and $mode -eq 'S') { $cur.Stats.Add($line) }
    if ($cur -and $mode -eq 'D' -and $line -match '^\d+\|') { if (-not $cur.Dmv) { $cur.Dmv = $line }; $cur.DmvN = 1 + [int]$cur.DmvN }
}
$tick = @(); $inTick = $false
foreach ($line in $out) { if ($line -eq '##TICK') { $inTick = $true; continue }; if ($inTick -and $line -match '^(\d+)\|(\d+)$') { $tick += [long]$Matches[2] }; if ($inTick -and $line -match '^##BEGIN') { break } }
$gk = @{}; $sect = ''
foreach ($line in $out) { if ($line -eq '##GOK-BEFORE') { $sect = 'B'; continue }; if ($line -eq '##GOK-AFTER') { $sect = 'A'; continue }; if ($sect -and $line -match '^\d+\|') { $gk[$sect] = $line; $sect = '' } }
$gkStatsBlocks = 0; $inG = $false
foreach ($line in $out) { if ($line -eq '##GOK-BEFORE') { $inG = $true; continue }; if ($line -eq '##GOK-AFTER') { break }; if ($inG -and $line -match 'CPU time = (\d+) ms,\s*elapsed time = (\d+) ms') { $gkStatsBlocks++ } }

$L = New-Object System.Collections.Generic.List[string]
function Add([string]$s) { $L.Add((Mask $s)) }
Add "R-27-CALIB - timing-instrument calibration for the R-27 recheck. DIAGNOSTIC only: not an E6 run, not a baseline, not a performance result."
Add "Directive: Owner Directive 'R-27 Targeted Remediation and Recheck' (2026-11-08) s3, VERIFY_ONLY. Window (UTC): $($t0.ToString('yyyy-MM-dd HH:mm:ss', $inv)) to $($t1.ToString('yyyy-MM-dd HH:mm:ss', $inv)). sqlcmd exit code: $rc."
Add "Database FitLife_P3_P2 (marker checked). SELECT-only; no cache clear; no setting changed. Environment NOT controlled during this calibration (resolution is the only purpose)."
Add "Statements: byte-identical to R-27-PROBE__20261108-1321 P1-P4. DMV rows selected by query_hash taken from the 13:21 actual plans: $(( $H.Keys | ForEach-Object { "$_=$($H[$_])" }) -join ', ')."
Add ""
Add "== C1. SYSDATETIME() step size (ns), 20 samples (first may be partial) =="
Add ("  " + ($tick -join ' '))
Add ""
Add "== C2. Per execution: STATISTICS TIME (ms) vs sys.dm_exec_query_stats last_* (us) of the same execution =="
Add "query|run|stat_cpu_ms|stat_el_ms|dmv_worker_us|dmv_elapsed_us|stat_lr|stat_phys|dmv_last_lr|dmv_exec_count|dmv_rows_for_hash|plan_gen|plan_ck"
foreach ($r in $rows) { Add ("{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}|{8}|{9}|{10}|{11}|{12}" -f $r.Q, $r.R, $r.StCpu, $r.StEl, $r.WkUs, $r.ElUs, $r.Lr, $r.Pr, $r.DLr, $r.Exec, $r.Rowsn, $r.Gen, $r.Ck) }
Add ""
Add "== C3. Derived checks (runs >= 1) =="
foreach ($k in $Q.Keys) {
    $x = @($rows | Where-Object { $_.Q -eq $k -and $_.R -ge 1 -and $_.WkUs -ne $null })
    if (-not $x.Count) { Add "  ${k}: no DMV rows"; continue }
    $wk = $x | ForEach-Object { $_.WkUs }; $wkMod = @($x | Where-Object { $_.WkUs -gt 0 } | ForEach-Object { [Math]::Abs((($_.WkUs + 7812) % 15625) - 7812) })
    $stTrunc = @($x | Where-Object { $_.StEl -eq [Math]::Floor($_.ElUs / 1000.0) }).Count
    $stRound = @($x | Where-Object { $_.StEl -eq [Math]::Round($_.ElUs / 1000.0, [MidpointRounding]::AwayFromZero) }).Count
    $stCpuEq = @($x | Where-Object { $_.StCpu -eq [Math]::Floor($_.WkUs / 1000.0) -or $_.StCpu -eq [Math]::Round($_.WkUs / 1000.0) }).Count
    $execStep = @(); for ($i = 1; $i -lt $x.Count; $i++) { $execStep += ($x[$i].Exec - $x[$i - 1].Exec) }
    Add ("  {0}: dmv_worker_us distinct={1} [{2}]; distance of worker_us to nearest 15,625 us multiple: max {3} us; stat_el = floor(dmv_el/1000) in {4}/{5}, = round in {6}/{5}; stat_cpu ~ dmv_worker/1000 in {7}/{5}; exec_count step per execution: {8}; DMV rows per hash: {9}" -f $k, (@($wk | Select-Object -Unique)).Count, (($wk | Sort-Object | Select-Object -Unique) -join ','), $(if ($wkMod.Count) { ($wkMod | Measure-Object -Maximum).Maximum } else { 'n/a' }), $stTrunc, $x.Count, $stRound, $stCpuEq, (($execStep | Select-Object -Unique) -join ','), (($x | ForEach-Object { $_.Rowsn } | Select-Object -Unique) -join ','))
}
Add ""
Add "== C4. GO-count semantics (P2, one 'GO 10') =="
Add "  before: $($gk['B'])"
Add "  after:  $($gk['A'])"
$dExec = if ($gk['B'] -and $gk['A']) { [long](($gk['A'] -split '\|')[0]) - [long](($gk['B'] -split '\|')[0]) } else { $null }
Add "  execution_count delta = $dExec (expected 10); STATISTICS TIME blocks between the markers (includes the before-DMV batch and parse/compile lines): $gkStatsBlocks"
Add ""
Add "Raw sqlcmd output: ${base}__raw.txt"
$L | Out-File -Encoding utf8 $sum
"written $sum"
Get-Content $sum | Select-Object -Skip 4 | Select-Object -First 3
Get-Content $sum | Select-String -Pattern '^  P\d:|delta' | ForEach-Object { $_.Line }
