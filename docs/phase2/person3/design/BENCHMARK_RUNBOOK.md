# Benchmark Runbook — Person 3 (E6, B0 and later performance work)

| Field | Value |
|---|---|
| Purpose | Operational guide to prepare a measurement environment, run the R-27 closure test E6, capture the formal baseline B0 and continue the UC05/UC06 performance work orders |
| State | 2026-11-11. Commands below were checked against the scripts in the repository (parameters, fixed targets, outputs, exit codes). Nothing in this runbook was executed to write it |
| Entry point | [README_HANDOFF.md](../README_HANDOFF.md) |
| Governing records | [WO-P3-P0-02](../work-orders/WO-P3-P0-02_ENVIRONMENT_BASELINE.md), [WO-P3-P2-02](../work-orders/WO-P3-P2-02_BASELINE_BENCHMARK.md) §2a (E1–E6, D1–D2, M1–M4, B1), [10 §4](../10_SEED_AND_BENCHMARK_PLAN.md#4-benchmark-methodology), [ENVIRONMENT_P0.md](ENVIRONMENT_P0.md), [BENCHMARK_ENVIRONMENT_READINESS.md](BENCHMARK_ENVIRONMENT_READINESS.md), [14 R-27](../14_RISK_REGISTER.md) |

**Authorization rule.** Every step that creates, rebuilds or drops a database, changes a SQL Server or Windows setting, updates statistics or runs a timed series needs an APPROVED work order or an explicit Owner instruction naming the instance and database. Read-only inspection (marked **RO**) is always allowed. Steps marked **AUTH** need authorization. This runbook authorizes nothing.

**Three different things — do not mix them:**

| Activity | What it proves | Work order | Status |
|---|---|---|---|
| **E6** (R-27 closure test) | The machine gives stable, repeatable timings for four fixed probe queries | WO-P3-P0-02 criterion 7 | Not passed. Last run FAIL (2026-11-11 02:35 UTC, BM-1) |
| **B0** (formal baseline) | Baseline plans, logical reads, CPU and elapsed time of every frozen P3 query, before any optimisation | WO-P3-P2-02 | BLOCKED; runner **NOT_IMPLEMENTED** |
| **Experiments** (U0/U1, IX-xx, summary, partition) | Measured effect of one change against B0 | P3-03 Part P, P4-01 Part X, P4-02, P5-01 | Not approved |

---

## 1. Placeholders used in all commands

Run commands in **Windows PowerShell 5.1** from the repository root. Set these once per window:

```powershell
$Repo   = 'C:\Users\DELL\source\repos\CSDLNC-DA'   # replace with the clone path on this computer
$Server = 'localhost\MSSQLSERVER01'                 # REQUIRED: the approved benchmark instance on this computer
$Ev     = Join-Path $Repo 'docs\phase2\person3\evidence\test-results'
Set-Location $Repo
```

- Always pass `-Server $Server` explicitly. Most scripts default to `'localhost'` (the default instance). On the original laptop that is `MSSQLSERVER`, which hosts four unrelated user databases and must never be used for benchmarking.
- The database name `FitLife_P3_P2` is fixed inside the scripts (not a parameter).
- Two scripts are hard-bound to BM-1 on the original laptop and **refuse any other target**: `tests\db\build\run_p0_02_bm1.ps1` (instance `localhost\MSSQLSERVER01`) and `tests\db\diagnostics\run_e6_bm1_standalone.ps1` (instance, engine 17.0.1000.7, A3 memory values and pinned file hashes). A portable equivalent for another machine is **NOT_IMPLEMENTED — requires preparation and authorization**.

---

## 2. Prerequisites and the environment record

### 2.1 Requirements

| Item | Requirement | Why |
|---|---|---|
| OS / shell | Windows, Windows PowerShell 5.1, `sqlcmd` on PATH | All runners use `sqlcmd -E` and `System.Data.SqlClient` |
| SQL Server | Version supporting compatibility level 160 and `GENERATE_SERIES` (SQL Server 2022 or later); **Developer edition** | Build scripts refuse non-Developer editions (`rebuild_p2_db.sql`, error 51013) |
| Connection | Windows authentication (`-E`); sysadmin on the benchmark instance (DMVs, `xp_readerrorlog`, CREATE DATABASE) | No SQL logins or passwords are used or stored |
| Instance | A dedicated or idle instance with no other workload during series | G-ISO gate |
| Disk | DS-L reserves about 72 MB data / 8 MB log on BM-1; keep several GB free for rebuilds and tempdb | Rebuild between configurations |
| RAM | Available physical memory ≥ 2,048 MB during every series (E2) | R-27 root cause |
| Power | AC power, no sleep, no power events 10 min before and during series (E1) | R-27 root cause |

### 2.2 Record the environment (RO)

Machine and instance manifest, read-only, machine name masked:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\db\diagnostics\r27_diag_target.ps1 -Server $Server -OutFile (Join-Path $Ev ("ENV-MANIFEST__{0}.txt" -f (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmm')))
```

It records power plan and events, CPU, RAM, page file, disks and free space, top processes by memory, SQL services, instance memory/semaphore/configuration/waits, and the `FitLife_P3_P2` database-scoped settings. Its section D5 always queries `localhost\MSSQLSERVER01`; on another computer that section only prints a connection error. Review the file before keeping it (it lists process names).

Instance identity (RO):

```powershell
sqlcmd -S $Server -E -W -s '|' -Q "SET NOCOUNT ON; SELECT @@SERVICENAME AS service, CONVERT(varchar(20), SERVERPROPERTY('ProductVersion')) AS version, CONVERT(varchar(80), SERVERPROPERTY('Edition')) AS edition, CONVERT(int, SERVERPROPERTY('EngineEdition')) AS engine_edition; SELECT name, CONVERT(bigint, value_in_use) AS value_in_use FROM sys.configurations WHERE name IN ('min server memory (MB)','max server memory (MB)','max degree of parallelism','cost threshold for parallelism','optimize for ad hoc workloads') ORDER BY name; SELECT name, state_desc, compatibility_level FROM sys.databases WHERE database_id > 4 ORDER BY name;"
```

Database settings, statistics and index inventory (RO; after the dataset exists):

```powershell
sqlcmd -S $Server -E -W -s '|' -d FitLife_P3_P2 -Q "SET NOCOUNT ON; SELECT compatibility_level, recovery_model_desc, is_read_committed_snapshot_on, snapshot_isolation_state_desc, is_auto_create_stats_on, is_auto_update_stats_on, is_auto_update_stats_async_on FROM sys.databases WHERE name = DB_NAME(); SELECT actual_state_desc, query_capture_mode_desc FROM sys.database_query_store_options; SELECT name, CONVERT(nvarchar(30), value) AS value FROM sys.database_scoped_configurations ORDER BY name; SELECT t.name AS table_name, i.name AS index_name, i.type_desc, i.is_primary_key FROM sys.indexes i JOIN sys.tables t ON t.object_id = i.object_id WHERE i.type > 0 ORDER BY t.name, i.index_id; SELECT OBJECT_NAME(s.object_id) AS table_name, s.name AS stats_name, sp.last_updated, sp.rows, sp.rows_sampled FROM sys.stats s CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp WHERE OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1 ORDER BY 1, 2;"
```

Record also: migration versions applied (V001, V002, V003 — check with §7 step 9), dataset fingerprint (§7 step 10), the Git commit and the operator.

### 2.3 Reference values (BM-1, original laptop)

| Item | BM-1 value |
|---|---|
| Instance | `localhost\MSSQLSERVER01`, SQL Server 2025 RTM 17.0.1000.7, Standard Developer (EngineEdition 2) |
| Host | Intel i5-1135G7, 4 cores / 8 logical, 7,915 MB RAM, Windows 10 Pro 19044, SSD 238 GB |
| Configuration | MAXDOP 8, cost threshold 5, ad hoc 0; memory **currently 16 MB / unlimited** (A3 floor 1,024 / cap 2,048 MB was applied 2026-11-10 and rolled back 2026-11-11 02:05 UTC) |
| Database B0 | `FitLife_P3_P2`: V001+V002+V003, compatibility 160, SIMPLE, RCSI OFF, auto stats ON (sync), Query Store READ_WRITE, adaptive database-scoped settings left at defaults (decision A7/E5) |
| Fingerprint | DS-L `26ABB2776BD71C1347D2478D880B926FF35D8B6E7BA8F583D76E56D4DD82CA1F`; catalog digest after V003 `A3291B5E862A39E1613DB29A9BB830F4504947EA8448678FB83D3F1C2EDF8A71` |

---

## 3. Equivalent content vs comparable measurements

| Goal | How it is proven | Can it hold across computers? |
|---|---|---|
| **Equivalent database content** | Same scripts (Git blob IDs), same migrations, same profile and seed → `T-REPRO-02` DATASET_CHECKSUM `26ABB277…CA1F` and identical per-table hashes; same catalog digest; zero non-PK indexes | **Yes.** The generator is deterministic. Physical `.mdf` checksums are **not** expected to match and are never compared |
| **Comparable measurement environment** | Same instance, same hardware, same configuration, same session conditions, E6 PASS on that instance | **No.** Timings from different hardware are not comparable. Logical reads and plan shapes usually are, but must be re-captured, not assumed |

Rule: **every before/after timing pair in one comparison comes from the same instance on the same computer, after E6 PASS on that instance**, with B0 re-captured there. A baseline from one computer is never compared with an optimised run from another unless the Owner approves a written cross-machine methodology first.

---

## 4. Environment safety checklist (before any AUTH step)

1. **Instance:** the identity query (§2.2) shows the expected `@@SERVICENAME`, version and edition. Stop if it shows the default instance of the original laptop (`MSSQLSERVER`).
2. **Database:** the target is `FitLife_P3_P2` (or another `FitLife_P3_%` name the WO approves). Never `FitLife_P3_P1`, never a non-`FitLife_P3_%` database.
3. **Disposable:** if the database exists, its marker starts with `WO-P3-P2-01` (RO):
   ```powershell
   sqlcmd -S $Server -E -W -d FitLife_P3_P2 -Q "SET NOCOUNT ON; SELECT CONVERT(nvarchar(200), value) FROM sys.extended_properties WHERE class = 0 AND name = 'P3_Disposable';"
   ```
   `rebuild_p2_db.sql` drops an existing `FitLife_P3_P2` **only** when this marker is present, and stops otherwise.
4. **Protected databases:** list all user databases (§2.2). None outside `FitLife_P3_%` may be touched. `tests\db\build\fingerprint_instance.sql` is run before and after each build by `run_p2_dataset.ps1` and must report IDENTICAL.
5. **Sessions:** no other sessions on the target database and no other user requests on the instance (RO):
   ```powershell
   sqlcmd -S $Server -E -W -s '|' -Q "SET NOCOUNT ON; SELECT s.session_id, DB_NAME(s.database_id) AS db, s.program_name, s.status FROM sys.dm_exec_sessions s WHERE s.is_user_process = 1 AND s.session_id <> @@SPID;"
   ```
6. **Disk:** check free space (`r27_diag_target.ps1` prints volumes).
7. **Configuration:** before any authorized configuration change, record the current `value` and `value_in_use` of the setting. On BM-1, use `run_p0_02_bm1.ps1 -Stage Memory` (records previous values) and `-Stage MemoryRollback -PrevMin <v> -PrevMax <v>` to restore. No service stop, no cache clear, no power change without explicit authorization.

---

## 5. Moving the source to another computer

### 5.1 What is on GitHub

All Person 3 source, tests and evidence up to 2026-11-11 are in commit `496176c` on `origin/p3/wo-p3-p1-01` (`main` does not contain them). Files created after that commit — **including this runbook and the other three handover files** — exist only on the original laptop until the Owner authorizes a commit and push.

### 5.2 Recommended transfer (Git checkpoint)

On the original laptop (RO):

```powershell
Set-Location $Repo
git status --porcelain=v1 -uall     # must be empty, or list the files that still need an authorized commit
git rev-parse HEAD                   # record the full commit id
git ls-files -s | Out-File -Encoding utf8 (Join-Path $env:TEMP 'p3_source_blobs.txt')
```

If `git status` lists files, either the Owner authorizes a commit and push (preferred), or use §5.3. On the benchmark computer:

```powershell
git clone --branch p3/wo-p3-p1-01 https://github.com/Phuoc-IT-2106/CSDLNC-DA.git C:\work\CSDLNC-DA
Set-Location C:\work\CSDLNC-DA
git rev-parse HEAD                   # must equal the recorded commit id
git ls-files -s | Out-File -Encoding utf8 (Join-Path $env:TEMP 'p3_source_blobs_target.txt')
```

Compare the two `ls-files -s` outputs (`Compare-Object (Get-Content a) (Get-Content b)` → no differences). They list the Git blob ID of every tracked file, which proves identical content independent of line endings.

**Line-ending caveat (verified 2026-11-11):** on the original laptop most tracked files are CRLF in the working tree, but `.gitattributes` sets `* text=auto eol=lf`, so a fresh clone writes LF files. Content is the same, but `Get-FileHash` values differ. Example: `r27_e6_probe.ps1` is `AB8D0114…2762B2` on the laptop (the hash pinned in the E6 evidence and in `run_e6_bm1_standalone.ps1`) and `B8CA54B6…1B2C9` as committed (LF). Consequences: use blob IDs, not file hashes, to prove source identity across computers; a harness run from a clone records a different self-hash in its output, which the evidence manifest must explain; pinned-hash checks in the BM-1 runner would fail on a clone.

### 5.3 Fallback: portable archive (only when a commit is not authorized)

```powershell
Set-Location $Repo
$list = git ls-files -co --exclude-standard
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmm')
$list | ForEach-Object { '{0}  {1}' -f (Get-FileHash -Algorithm SHA256 -LiteralPath $_).Hash, $_ } | Out-File -Encoding utf8 "$env:TEMP\P3-SOURCE-MANIFEST__$stamp.txt"
Compress-Archive -LiteralPath $list -DestinationPath "$env:TEMP\P3-SOURCE__$stamp.zip"
```

`Compress-Archive -LiteralPath` with a file list flattens folders in some PowerShell 5.1 cases; check the archive before relying on it, or copy the whole folder (excluding `.git` if not needed) with `robocopy $Repo <dest> /E /XD .git`. On the target, recompute the manifest with the same command and compare it with `Compare-Object`; byte-identical copies give identical hashes (no line-ending conversion happens with a file copy). `*.zip` is ignored by `.gitignore`; never commit the archive.

### 5.4 Never transfer or publish

Passwords (including the assignment PDF password), connection strings with credentials, `.mdf/.ldf/.bak` files, the original source PDFs (outside the repository), machine or SQL host names (the scripts mask them as `<local-server>`), private user data, private chat content. Windows authentication means no credential needs to move. The only local path used in these documents is the clone path already published in [P3_CONTEXT_INDEX.md](../../../agent/P3_CONTEXT_INDEX.md); do not add other personal paths.

### 5.5 Local paths to replace on another computer

| Where | Original value | Action |
|---|---|---|
| `$Repo` in every command | `C:\Users\DELL\source\repos\CSDLNC-DA` | Use the new clone path |
| `-Server` | `localhost\MSSQLSERVER01` | Use the approved instance name |
| `tests\db\diagnostics\r27_calib.ps1` defaults `-Repo`, `-Scratch` | Hard-coded laptop paths | Historical calibration script; do not use for new evidence |
| `run_p0_02_bm1.ps1`, `run_e6_bm1_standalone.ps1` | Fixed BM-1 targets | Not usable elsewhere (§1) |
| `r27_e6_probe.ps1` `-Scratch` default | `%TEMP%\p3_r27` | Portable; keep |

---

## 6. Database setup on a benchmark instance (AUTH)

Each step needs authorization naming the instance and the database. On BM-1 the dataset already exists and is verified; **do not rebuild it** without a separate authorization (§10.6 restores B0 only when an experiment changed it).

1. **Connect and verify identity** — §2.2 identity query; checklist §4 items 1–6.
2. **Create the isolated database and load DS-L** — one command builds `FitLife_P3_P2` from nothing (preflight, instance fingerprint, rebuild with F001 TEST_ONLY fixtures + V001 + V002, F001D key rows, S001 generator, T-SCH-02, T-SEED checks, T-REPRO-02 checksums, fingerprint again, comparison with run C):
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tests\db\seed\run_p2_dataset.ps1 -Dataset DS-L -RunLabel BM2 -Server $Server -CompareWith docs\phase2\person3\evidence\test-results\CHECKSUMS__DS-L__20261108-1155_C.txt
   ```
   Use a `-RunLabel` that names the machine (e.g. `BM2`) so evidence names never collide. Success: console `P2-RUN_RESULT: PASS`, exit code 0, and `T-REPRO-02 vs CHECKSUMS__DS-L__20261108-1155_C.txt = PASS`. Outputs: `P2-RUN__DS-L__<utc>_<label>.txt`, `CHECKSUMS__DS-L__<utc>_<label>.txt`, `DATASET-MANIFEST__DS-L__<utc>_<label>.md`. The run log's first line says "Instance: local default (<server>)" whatever the target; the value in parentheses is the real target (known cosmetic label, [ENVIRONMENT_P0 §4](ENVIRONMENT_P0.md#4-dataset-and-schema-verification)). DS-L took about 5 minutes on the laptop.
3. **Apply only the required TEST_ONLY dependencies** — step 2 already applies F001 and F001D (key-only fixtures). The loyalty fixtures (F002P/F002T/L001) and hook doubles are **not** part of `FitLife_P3_P2` B0; add them only if an approved WO needs routines that use them (e.g. U0/U1 settlement in Part P), and record that in the manifest.
4. **Apply V003** (B0 includes it, decision A7):
   ```powershell
   sqlcmd -S $Server -E -I -b -d FitLife_P3_P2 -i db\migrations\V003__p3_points_earned_rule.sql
   ```
   Expected output contains `V003 applied`; error 51008 means it was already applied. On BM-1 the equivalent is `run_p0_02_bm1.ps1 -Stage Validate`, which applies V003 if missing and validates 14 checks.
5. **DS-M** (B0 requires DS-M and DS-L): `FitLife_P3_P2` holds one dataset at a time. Rebuild with `-Dataset DS-M -CompareWith docs\phase2\person3\evidence\test-results\CHECKSUMS__DS-M__20261108-0338_A.txt` (expected DATASET_CHECKSUM `3C056B7A7F0FFB8DE0C4A24474AFAEED80DE6B728F9CE834F34C3A752B33D85C`), apply V003, measure, then rebuild DS-L. Record every rebuild.
6. **Never** run any build against the default instance of the original laptop, and never rebuild the approved BM-1 database just to "refresh" it.

## 7. Integrity and B0-inventory verification (RO)

7. **Constraints** — expected with V003: 9 PK, 8 FK, 14 CHECK, 4 DEFAULT; all enabled and trusted:
   ```powershell
   sqlcmd -S $Server -E -W -s '|' -d FitLife_P3_P2 -Q "SET NOCOUNT ON; SELECT (SELECT COUNT(*) FROM sys.key_constraints WHERE type = 'PK') AS pk, (SELECT COUNT(*) FROM sys.foreign_keys) AS fk, (SELECT COUNT(*) FROM sys.foreign_keys WHERE is_disabled = 1 OR is_not_trusted = 1) AS fk_untrusted, (SELECT COUNT(*) FROM sys.check_constraints) AS ck, (SELECT COUNT(*) FROM sys.check_constraints WHERE is_disabled = 1 OR is_not_trusted = 1) AS ck_untrusted, (SELECT COUNT(*) FROM sys.default_constraints) AS df;"
   ```
8. **Row counts** — DS-L: INVOICE 324,000; INVOICE_SERVICE_ITEM 65,177; INVOICE_PRODUCT_ITEM 712,789; MEMBER_MONTHLY_SPENDING 169,040; fixtures MEMBER 30,000, BRANCH 12, EMPLOYEE 120, SERVICE_PLAN 30, PRODUCT 200:
   ```powershell
   sqlcmd -S $Server -E -W -s '|' -d FitLife_P3_P2 -Q "SET NOCOUNT ON; SELECT t.name, SUM(p.row_count) AS rows FROM sys.dm_db_partition_stats p JOIN sys.tables t ON t.object_id = p.object_id WHERE p.index_id IN (0, 1) GROUP BY t.name ORDER BY t.name;"
   ```
9. **Monetary consistency and schema** — already checked by `run_p2_dataset.ps1` (T-SEED V-TOT: header = sum of lines; payment-state and spending checks; T-SCH-02 conformance). Re-run conformance alone if needed:
   ```powershell
   sqlcmd -S $Server -E -I -b -W -d FitLife_P3_P2 -i tests\db\schema\T-SCH-02_conformance.sql
   ```
   Expected last line `T-SCH-02_RESULT: PASS`. V003 present: `SELECT name, is_not_trusted FROM sys.check_constraints WHERE name = 'CK_MEMBER_MONTHLY_SPENDING_PointsRule'`.
10. **Canonical fingerprint**:
    ```powershell
    sqlcmd -S $Server -E -I -b -W -s '|' -d FitLife_P3_P2 -v MaxGrantPercent=2 -i tests\db\seed\T-REPRO-02_checksums.sql
    ```
    The `DATASET_CHECKSUM|…` line must equal `26ABB2776BD71C1347D2478D880B926FF35D8B6E7BA8F583D76E56D4DD82CA1F` (DS-L) and every per-table line must equal [CHECKSUMS__DS-L__20261108-1155_C.txt](../evidence/test-results/CHECKSUMS__DS-L__20261108-1155_C.txt).
11. **Baseline index inventory** — only clustered primary keys (9 rows from the index query in §2.2, all `is_primary_key = 1`). Catalog digest (expected after V003 on identical scripts: `A3291B5E…8A71`; a different value must be explained before measuring):
    ```powershell
    sqlcmd -S $Server -E -I -b -W -d FitLife_P3_P2 -i tests\db\schema\catalog_digest.sql
    ```
12. **No experimental structures** — zero non-PK indexes, views, triggers, partition functions/schemes, columnstore or compressed partitions:
    ```powershell
    sqlcmd -S $Server -E -W -s '|' -d FitLife_P3_P2 -Q "SET NOCOUNT ON; SELECT (SELECT COUNT(*) FROM sys.indexes i JOIN sys.tables t ON t.object_id = i.object_id WHERE i.type > 0 AND i.is_primary_key = 0) AS non_pk_indexes, (SELECT COUNT(*) FROM sys.views) AS views, (SELECT COUNT(*) FROM sys.triggers) AS triggers, (SELECT COUNT(*) FROM sys.partition_functions) AS partition_functions, (SELECT COUNT(*) FROM sys.partitions WHERE data_compression > 0) AS compressed_partitions;"
    ```
    All must be 0. **Schema-integrity constraints** (PK, FK, CHECK, DEFAULT from V001–V003) and **baseline PK indexes** belong to B0. **Experimental optimisation indexes** (IX-01…IX-10), summaries and partitions must not exist in B0.

---

## 8. E6 — environment stability gate

E6 is **not** the baseline. It checks whether this instance, under controlled conditions, gives repeatable timings. A PASS closes R-27 for that instance; it produces no B0 number.

### 8.1 Harness and command (verified)

Harness: [tests/db/diagnostics/r27_e6_probe.ps1](../../../../tests/db/diagnostics/r27_e6_probe.ps1) (v2, A6 revision). Parameters: `-Server` (default `localhost` — always pass it), `-Repo`, `-Scratch`, `-DiagScript`, `-Runs 15`, `-GapMinutes 10`, `-K1 200`, `-SettleSeconds 60`, `-PreWindowMinutes 10`, `-EvOverride`, `-SkipChecksum`, `-NoAbort`. The defaults are the **pre-registered method**; a formal E6 must not change them and must not use `-SkipChecksum` or `-NoAbort`. `-EvOverride` sends output elsewhere and is for dry runs only (never evidence).

The pattern `& ".\tests\db\diagnostics\r27_e6_probe.ps1" -Server "localhost\MSSQLSERVER01"` is syntactically valid. Prefer a separate process so the exit code is reliable:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\db\diagnostics\r27_e6_probe.ps1 -Server $Server
"exit code: $LASTEXITCODE"
```

Optional bounded wait wrapper (waits for a clean power window and free RAM, holds keep-awake, then starts the harness once):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\db\diagnostics\r27_e6_wait_and_run.ps1 -Server $Server -CleanMinutes 10 -MinFreeMb 2100 -MaxWaitMinutes 40
```

It exits 3 without starting the harness if the wait times out. On BM-1 only, the standalone runner adds the fixed A3/A4/A5 and campaign-lock checks: `powershell -NoProfile -ExecutionPolicy Bypass -File tests\db\diagnostics\run_e6_bm1_standalone.ps1` (`-PreflightOnly` checks without running). Its exit codes: 0 PASS, 1 FAIL, 2 BLOCKED by a fixed precondition, 3 BLOCKED by wait timeout or harness precheck, 4 ERROR. **Its check K1 now fails**, because `R-27-CLOSE__20261111-0235` already exists for `localhost\MSSQLSERVER01`; an Owner decision is needed before any further BM-1 campaign (§8.6).

The harness works on `FitLife_P3_P2` only, compares the dataset with run C before and after, is SELECT-only, clears no cache, changes no setting, and holds a process keep-awake request that it releases at the end. One run takes about 13–15 minutes (two series 10 minutes apart).

### 8.2 Preflight (operator, then harness)

Operator before starting: AC connected firmly; VS Code, Claude Code, browsers, chat clients and installers closed; no other benchmark or sqlcmd; Windows updates paused if allowed; 10 minutes without power events; on BM-1 the authorized A3 memory floor and A4 "Best performance" mode applied (they are **not** applied today).

Harness precheck (recorded in `R-27-CLOSE__<ts>__precheck.txt`; any FAIL → exit 2, no series, campaign not consumed):

| Check | Condition |
|---|---|
| PRE-1 | AC power online now |
| PRE-2 | No Kernel-Power 42/105/107/506/507 or Power-Troubleshooter 1 event in the last 10 minutes |
| PRE-3 | Database `FitLife_P3_P2`, marker present, compatibility 160, read-write |
| PRE-4 | No other session on the database, no other user request on the instance, no other sqlcmd process |
| PRE-5 | E2: available memory ≥ 2,048 MB, `process_physical_memory_low = 0`, query-memory semaphore target ≥ 256 MB |

### 8.3 Pre-registered criteria (from the harness; unchanged since 2026-11-08)

| ID | Criterion |
|---|---|
| C-LR | Logical reads per execution identical in every measured sample of both series |
| C-CPU / C-EL | Median CPU / elapsed per execution, S1 vs S2: abs(m1 − m2) / min(m1, m2) ≤ 10% |
| C-IQR | Per series and query: IQR / median ≤ 20% (CPU and elapsed) |
| C-PLAN | `query_plan_hash` equal to the hard-coded reference (P1 `0x196530FD2A44915E`, P2 `0x0E9B652E8283125A`, P3 `0x4CFD70279968D628`, P4 `0x77884F58C7F1DEB5`) and DOP identical in every sample |
| C-ID (query/plan identity) | One cached row per `query_hash`; plan handle, creation time and generation unchanged; execution count rose by exactly K; for K = 1 STATISTICS TIME/IO agree with the DMV |
| G-WARM | Every sample warm: physical and read-ahead reads = 0 |
| G-E1 | AC at every gate; no listed power event from 10 min before S1 to the end of S2 |
| G-E2 | At every gate: available ≥ 2,048 MB, low-memory flag 0, semaphore target ≥ 256 MB |
| G-E3 (resource waits) | Per series: RESOURCE_SEMAPHORE waits 0, forced grants unchanged, no spills, no grant/spill warnings in plans |
| G-ISO | No other session on the database and no other user request at every gate |
| Dataset | T-REPRO-02 checksum = run C before and after |

Method: timing from `sys.dm_exec_query_stats` deltas (decision M3); STATISTICS IO/TIME kept as raw record; one discarded warm-up per series; 15 interleaved samples per query per series; P1 uses batches of K = 200 executions; median and quartiles by linear interpolation.

### 8.4 Result vocabulary and completion

| Result | Meaning |
|---|---|
| **PASS** | Every criterion and every gate passed (`R-27-CLOSE_RESULT: PASS`). R-27 may be proposed for closure for **that instance**; Owner acceptance of WO-P3-P0-02 is still required |
| **FAIL** | Series ran and at least one criterion or gate failed (`R-27-CLOSE_RESULT: FAIL (n failing items)`). R-27 stays OPEN |
| **NOT_RUN** | Precheck failed (harness exit 2) or the wait timed out (wrapper exit 3); no timed series |
| **INVALID SAMPLE** | A sample marked `valid=False` (identity or warm-cache check failed). It is excluded from the statistics and makes C-ID FAIL; it is never deleted or replaced |

How to recognise completion and read the result:

1. The console prints `written <path>\R-27-CLOSE__<yyyyMMdd-HHmm>.txt` followed by the gate, C-ID, dataset and per-query lines.
2. **Do not use the exit code to decide PASS/FAIL.** The harness exits 2 only on a failed precheck; after a completed campaign it exits 0 for both PASS and FAIL (1 only on an unexpected error). The decision is the last line of the summary file:
   ```powershell
   $f = Get-ChildItem $Ev -Filter 'R-27-CLOSE__*.txt' | Where-Object { $_.Name -match '^R-27-CLOSE__\d{8}-\d{4}\.txt$' } | Sort-Object LastWriteTime | Select-Object -Last 1
   $f.Name
   Select-String -LiteralPath $f.FullName -Pattern '^R-27-CLOSE_RESULT|^G-|^C-ID|^DATASET CHECK|^  P\d  ' | ForEach-Object { $_.Line }
   ```
3. Preserve every file with the same timestamp: `R-27-CLOSE__<ts>.txt`, `__precheck.txt`, `__raw_S1.txt`, `__raw_S2.txt`, `__P1…P4.sqlplan`, `__checksum_before.txt`, `__checksum_after.txt`, and `R-27-DIAG__<ts>_before.txt` / `_after.txt`. Add their SHA-256 values to the WO execution record. Never edit or delete them.

### 8.5 Running E6 on another machine

Before the first run on a new computer (each item needs Owner approval, recorded before the run):

1. The machine is named as the benchmark environment (e.g. BM-2) with its manifest (§2.2).
2. The dataset is built and verified there (§6–§7).
3. **C-PLAN references:** the reference plan hashes were captured on the original laptop (8 logical CPUs; P4 runs at DOP 8). Different hardware can produce a different, equally valid plan hash or DOP, which would fail C-PLAN for reasons unrelated to stability. The Owner must decide **before** the run whether the references are kept, or replaced by a pre-registered reference capture on the new machine. Do not edit the harness ad hoc; a changed harness is a new reviewed revision with a diff in the evidence (as done for A6).
4. Note the line-ending caveat (§5.2): the harness self-hash recorded on a clone differs from `AB8D0114…`; record the Git blob ID as the identity proof.

### 8.6 Failure handling (bounded)

| Situation | Action | Stop? |
|---|---|---|
| Precheck FAIL (PRE-1…PRE-5) | Fix the condition (AC, close apps, wait); one bounded retry within the same session using the wait wrapper | If still failing after `-MaxWaitMinutes`: stop, record NOT_RUN, report |
| RAM or power unstable during series (G-E1/G-E2 FAIL) | Record FAIL. Do not rerun under the same conditions | Stop. Owner chooses: authorized memory floor + power mode, or another machine |
| Missing or invalid samples (C-ID FAIL) | Record FAIL; quote the invalid-sample lines | Stop |
| Plan change (C-PLAN FAIL, plan replaced mid-series) | Record FAIL; keep the `.sqlplan` files | Stop; Owner decision |
| Dataset mismatch (checksum ≠ run C) | Invalid campaign; do not interpret timings | Stop; rebuild only with authorization |
| Statistical instability (C-IQR / C-CPU / C-EL FAIL) | Record FAIL | Stop; Owner decides on environment or a pre-registered change of statistical design **before** the next run |
| Unsupported feature / permission error | Record ERROR with the message | Stop |

Never: rerun E6 repeatedly hoping for a PASS; change thresholds, `-Runs` or sample rules after seeing results; delete invalid samples; declare R-27 closed because a precheck passed.

### 8.7 Latest E6 result (BM-1, 2026-11-11 02:35–02:47 UTC)

[R-27-CLOSE__20261111-0235.txt](../evidence/test-results/R-27-CLOSE__20261111-0235.txt): **FAIL (4 failing items)**. Conditions: memory 16 MB / unlimited (no A3 floor), Balanced plan (no A4), launched without the standalone runner.

| Item | Result |
|---|---|
| Precheck PRE-1…PRE-5 | PASS (2,303 MB available) |
| Dataset | IDENTICAL before and after (`26ABB277…CA1F`) |
| G-E1 | FAIL — two Kernel-Power 105 (power source change) events at 02:37:02–03 UTC, 7 s before S1 |
| G-E2 | FAIL — semaphore target 133 MB at S1 end (< 256 MB) |
| G-E3, G-ISO, G-WARM | PASS |
| C-ID | FAIL — 115 of 120 valid samples (all four plans replaced at S1 run 11; one P2 timing mismatch) |
| P2, P3 | PASS (median difference 2.4% / 1.4%; IQR/median ≤ 6.2%) |
| P1 | FAIL (C-LR: one sample averaged 8.64 reads, linked to the plan replacement); timing criteria passed |
| P4 | FAIL (elapsed IQR/median 39.9% in S1 > 20%) |

Status consequence: R-27 OPEN; WO-P3-P0-02 criterion 7 unmet; this is DIAGNOSTIC evidence only.

---

## 9. Formal baseline B0 (WO-P3-P2-02)

### 9.1 Preconditions (all required)

1. WO-P3-P0-02 `PASSED` — which needs E6 PASS on the **same** instance that will host B0.
2. WO-P3-P2-02 `APPROVED`, naming the instance and databases, and confirming the open method choices it lists (E5 adaptive features = current configuration and M3 = DMV deltas were recorded in A7; index-adoption thresholds are a P4 matter).
3. Dataset and schema verified (§7): fingerprint = run C (DS-L) / run A (DS-M); V001+V002+V003; PK indexes only.
4. E1–E3 hold at the start of the session.

### 9.2 What exists and what does not

| B0 step | Exists in the repository | Status |
|---|---|---|
| Environment validation | §2.2, §4, §7 commands; `r27_diag_target.ps1` | Available |
| Dataset and schema integrity | `run_p2_dataset.ps1`, `T-REPRO-02_checksums.sql`, `T-SCH-02_conformance.sql`, `catalog_digest.sql` | Available |
| Frozen query files | `db/queries/baseline/Q-UC05-B.sql`, `Q-UC05-C.sql` only | **NOT_IMPLEMENTED** for Q-BIL-A, Q-UC05-A, Q-UC06-A, A0, B, C, D (task 1). Specifications: [07 §5](../07_UC06_REVENUE_PLAN.md#5-baseline-query-candidates-specifications-to-be-frozen-in-wo-p3-p2-02), [06 §5](../06_UC05_BILLING_LOYALTY_PLAN.md#5-baseline-vs-optimised-evaluation), [10 §4.1](../10_SEED_AND_BENCHMARK_PLAN.md#41-query-set) |
| Fixed parameter sets | Definitions in [10 §4.2](../10_SEED_AND_BENCHMARK_PLAN.md#42-fixed-parameter-sets) | **NOT_IMPLEMENTED** (values not yet chosen from data; task 2) |
| Statistics `UPDATE STATISTICS … WITH FULLSCAN` on the four P3 tables (D2) | Pattern used in `tests/db/loyalty/capture_q_uc05_bc_b0.ps1` | Part of the future B0 harness; AUTH (changes statistics) |
| Actual Execution Plan capture | Patterns in `capture_q_uc05_bc_b0.ps1` and `capture_uc06_reference.ps1` (both locked to `FitLife_P3_UC05L`, DIAGNOSTIC_ONLY) | **NOT_IMPLEMENTED** for B0 on `FitLife_P3_P2` |
| Logical reads, CPU, elapsed (warm-up + N = 15 interleaved, DMV deltas) | Method implemented inside `r27_e6_probe.ps1` for its four probe queries only | **NOT_IMPLEMENTED** as a B0 runner (`db/benchmark/` does not exist; task 3) |
| Result export (`manifest.md`, `results.csv`, `summary.md`, `raw/`) | Format in [10 §4.8](../10_SEED_AND_BENCHMARK_PLAN.md#48-result-files-and-run-manifest) | **NOT_IMPLEMENTED** |
| Oracle/result-hash comparison | Report oracles exist in `tests/db/reconciliation/T-REC_revenue.sql`; result-hash pattern in the capture scripts | **NOT_IMPLEMENTED** for B0 queries |

**Do not run anything called "B0" until tasks 1–3 of WO-P3-P2-02 are implemented under its approval.** The harness and frozen query files may be built before E6 passes (WO §2a go rule), but they must not be timed.

### 9.3 B0 procedure (to be executed by the approved WO, in this order)

1. Validate environment: §2.2 manifest, §4 checklist, E1–E3 gate values captured at start.
2. Verify dataset and schema: §7 steps 7–12; record fingerprint and catalog digest in the manifest.
3. Select workload: freeze the query files (SHA-256 recorded, never edited afterwards) and the parameter sets.
4. `UPDATE STATISTICS … WITH FULLSCAN` on `INVOICE`, `INVOICE_SERVICE_ITEM`, `INVOICE_PRODUCT_ITEM`, `MEMBER_MONTHLY_SPENDING`; record the plan-cache policy.
5. Warm-up: one discarded execution per query × parameter set.
6. Timed runs: N = 15 interleaved (N ≥ 20 if p95 is reported), no plan capture during timing; CPU/elapsed from validated DMV deltas, STATISTICS IO/TIME kept raw; sub-millisecond queries use a fixed repeated-execution unit (like K = 200).
7. Plan capture: one separate execution per query × parameter set with the Actual Execution Plan → `evidence/execution-plans/<QUERY_ID>__B0__<DATASET>.sqlplan` plus screenshot `evidence/screenshots/<QUERY_ID>__B0__<DATASET>__plan.png`.
8. Export: `evidence/benchmark-results/<RUN_ID>/` with `manifest.md`, `results.csv`, `summary.md`, `raw/`. `RUN_ID = YYYYMMDD-HHMM_<DATASET>_<CONFIG>`, e.g. `20261120-1430_DSL_B0`; add a machine tag in the manifest (and in the folder name if two machines are involved, e.g. `_BM2`).
9. Reproducibility: re-run one configuration later (another day for T-REPRO-03) and compare logical reads (must be identical) and medians.
10. Acceptance: criteria of WO-P3-P2-02 §7, then Owner acceptance.

### 9.4 What makes a B0 valid

- Measured after E6 PASS on the same instance, with E1–E3 holding for every series (a series is kept or discarded whole for a recorded cause; no single sample is deleted).
- Dataset fingerprint = reference; schema = V001+V002+V003; only PK indexes; no summary, view, partition or experimental index.
- Frozen query files with SHA-256; results equal the oracle hash.
- Every number has a RUN_ID and raw evidence; every screenshot has a `.sqlplan`.
- Captured **before** any performance index, summary or partition is created on that instance.

### 9.5 Mandatory evidence per B0 query

Query ID · SQL file and SHA-256 · dataset tier and fingerprint · server/database configuration (manifest) · Actual Execution Plan (`.sqlplan` + screenshot) · logical reads per table · CPU time · elapsed time · repetition count · median · IQR · valid sample count · raw evidence path · RUN_ID.

### 9.6 Independent reproduction

A reviewer clones the recorded commit, verifies blob IDs (§5.2), builds the dataset (§6), checks the fingerprint (§7), runs the B0 runner with the recorded parameter sets on an E6-passed instance, and compares: logical reads and plan shapes must match; timings are compared only on the same instance and conditions (§3).

---

## 10. Remaining performance work orders

All are **PROPOSED / not approved**. Each starts only after B0 is accepted on the same instance and its own approval. Use one configuration change at a time, rebuild or restore B0 between configurations, and compare with identical parameters.

### 10.1 WO-P3-P3-03 Part P (UC05)

| Item | Content |
|---|---|
| Configurations | U0/B0 (`usp_P3_SettleInvoice_Baseline`, recomputes 12 months from INVOICE), U0/IX-03, U1 (`usp_P3_SettleInvoice`, incremental) — on DS-M and DS-L |
| Workload | K = 1,000 settlements per configuration, per-call metrics (T-PERF-02); restore the snapshot between configurations |
| Creation cost | `usp_P3_CreateInvoice` insert path on DS-L in B0 (task 3a, criterion 5), **before any P4 index is adopted** |
| Reads | T-PERF-01 (Q-UC05-A vs bounded spending read), T-PERF-08 (Q-UC05-B, Q-UC05-C); IX-07 via [08 §5](../08_INDEX_AND_QUERY_PLAN.md#5-evaluation-protocol-per-candidate) |
| Concurrency timing | Blocking duration of T-CONC-04 (moved from Part C) |
| Reproducibility | T-REPRO-03: one configuration repeated on another day |
| Needed but missing | A settlement benchmark runner and a DS-L database containing the routines and the F002 loyalty fixtures: **NOT_IMPLEMENTED** |

### 10.2 WO-P3-P4-01 Part X (UC06 indexes)

1. Baseline: B0 of Q-UC06-A/A0/B/C/D from §9 (same instance).
2. Candidates, one at a time ([08 §4](../08_INDEX_AND_QUERY_PLAN.md#4-candidate-index-register)): IX-01, IX-02, IX-03 (UC06 use), IX-04, IX-05, IX-06 (only if the app needs it), IX-08/IX-09 (only if D-001 assigns RPT-05/06), IX-10 optional. IX-11 is on shared `MEMBER` → proposed at P6, not created.
3. Per candidate: create on the benchmark copy → FULLSCAN statistics → warm-up + N = 15 → plan capture → logical reads/CPU/elapsed → result hash vs B0 → write overhead on settlement (T-PERF-06) → T-REG-01 → drop and restore B0.
4. Q-UC06-A0 vs Q-UC06-A with IX-01 (sargability, T-PERF-05).
5. Adoption only if **all** [08 §6](../08_INDEX_AND_QUERY_PLAN.md#6-adoption-and-rejection-criteria) criteria hold (plan uses it; ≥ 50% fewer logical reads and a time gain larger than noise; identical results; write overhead ≤ +10% median / +20% p95; no regression > 10%; not a left-prefix duplicate; workload-weighted reads decrease). The thresholds are still "proposed defaults": the Owner confirms them in the Part X approval.
6. Output: `db/indexes/`, `db/queries/optimized/`, `docs/phase2/person3/design/INDEX_DECISIONS.md` (ADOPTED/REJECTED with RUN_IDs). A measured rejection is a valid result.

### 10.3 WO-P3-P4-02 (revenue summary)

Only what the WO lists: A3 branch × day summary table (maintained in settlement or by a trigger, chosen for evaluation) and A5 indexed view if usable. The feature probe showed indexed views can be created but **no automatic matching was observed; NOEXPAND works** (record whether NOEXPAND is needed). Measure RPT-01…04 on B4 variants vs B0 and the best B1, write overhead (T-PERF-06), same-row concurrency (T-CONC-03), reconciliation (T-REC-03), regression (T-REG-01). Decide D-015/D-016 in `design/SUMMARY_DECISION.md`. Preconditions: P4-01 PASSED. No summary design is approved today.

### 10.4 WO-P3-P5-01 (partition)

1. Candidate: `INVOICE` only ([09 §3](../09_PARTITION_FEASIBILITY_PLAN.md)); the other three tables are rejected with reasons. Benchmark **copy** table, never the shared INVOICE.
2. Key and design: recognition timestamp (`PaidAt`, D-004), RANGE RIGHT monthly, empty partitions at both ends, one filegroup unless justified ([09 §10](../09_PARTITION_FEASIBILITY_PLAN.md)). Partitioning is supported on this edition (probe 3b).
3. Configurations: B2 (partition only) and B3 (partition + aligned best index) vs B0 and the best B1/B4, same data and parameters; Q-UC06-A/B/C/D, a PK lookup and a settlement-like update (row movement cost).
4. Evidence: Actual Partition Count / partitions accessed in plans; row distribution per partition; T-REG-02; T-PERF-07; PoC script runs cleanly on an empty database.
5. Decision: apply [09 §11](../09_PARTITION_FEASIBILITY_PLAN.md) criteria; `design/PARTITION_DECISION.md`; D-017. Partitioning may be **rejected** if the benefit is insufficient — at 324,000 rows that is a realistic outcome. Partitioning does not automatically speed up every query (no elimination → no gain, plus maintenance cost). If rejected, record DEP-11 for the team.

### 10.5 Comparability rule

All timings in one comparison come from one instance, one computer, one dataset fingerprint, one session protocol, after E6 PASS there. Logical reads and plans are the primary cross-configuration metric; CPU/elapsed support them only when the difference exceeds the measured noise.

### 10.6 Restoring B0 between experiments

1. Drop the experimental object(s) created by the experiment script, **or** rebuild the dataset (§6 step 2) when the experiment changed data or structure (partition copies, summary loads, settlement benchmarks).
2. Re-run §7 steps 10–12: fingerprint = reference, catalog digest = B0 value, zero non-PK indexes.
3. Update statistics as the protocol requires and record it.
4. Only then start the next configuration.

---

## 11. Evidence transfer back to the original laptop

1. **What to copy** (new files only): raw benchmark folders `evidence/benchmark-results/<RUN_ID>/`; `.sqlplan` files; screenshots; new `R-27-CLOSE__*`/`R-27-DIAG__*`/`ENV-*`/`P2-RUN__*`/`CHECKSUMS__*`/`DATASET-MANIFEST__*` files; frozen query files; index, summary and partition scripts; decision drafts (`INDEX_DECISIONS.md` etc.); test logs; the machine manifest (§2.2).
2. **Where it belongs:** same relative paths under `docs/phase2/person3/evidence/` (`test-results/`, `execution-plans/`, `screenshots/`, `benchmark-results/`), scripts under `db/…` and `tests/db/…`, decisions under `docs/phase2/person3/design/`.
3. **Avoid collisions:** every name already carries a UTC timestamp; add the machine tag (e.g. `_BM2`) to RunLabel / RUN_ID. Before copying, list target names that already exist and stop if any would be overwritten:
   ```powershell
   $src = 'D:\transfer\evidence'   # the exported folder (same layout as docs\phase2\person3\evidence)
   Get-ChildItem $src -Recurse -File | ForEach-Object { $rel = $_.FullName.Substring($src.Length).TrimStart('\'); $dst = Join-Path $Repo "docs\phase2\person3\evidence\$rel"; if (Test-Path -LiteralPath $dst) { "COLLISION $rel" } }
   ```
4. **Validate:** on the benchmark computer write `TRANSFER-MANIFEST__<utc>.txt` (SHA-256 + relative path of every exported file, the Git commit, the instance identity, the operator); after copying, recompute the hashes on the laptop and compare with `Compare-Object`. Any difference → do not use the file.
5. **Update references:** add the RUN_IDs and file hashes to the WO execution record (§13 of the WO), the evidence README, [16](../16_READINESS_REPORT.md), [SESSION_LOG.md](../SESSION_LOG.md); every number cites a RUN_ID and the machine.
6. **Continue locally:** documentation and application work continue on the laptop. State explicitly in every report table **which machine produced each measurement**. The laptop does not reproduce those timings, and must never be presented as having done so.

---

## 12. Quick reference

| Script | Target | Writes | Success signal |
|---|---|---|---|
| `tests\db\seed\run_p2_dataset.ps1 -Dataset DS-L -RunLabel <l> -Server <s> [-CompareWith <file>]` | Rebuilds `FitLife_P3_P2` (marker-guarded) | DB + evidence | `P2-RUN_RESULT: PASS`, exit 0 |
| `sqlcmd … -i db\migrations\V003__p3_points_earned_rule.sql` | `FitLife_P3_P2` | 1 CHECK | `V003 applied` |
| `sqlcmd … -v MaxGrantPercent=2 -i tests\db\seed\T-REPRO-02_checksums.sql` | RO | — | `DATASET_CHECKSUM\|26ABB277…CA1F` |
| `tests\db\diagnostics\r27_diag_target.ps1 -Server <s> -OutFile <f>` | RO | evidence file | file written |
| `tests\db\diagnostics\r27_e6_probe.ps1 -Server <s>` | RO (SELECT only) | evidence | `R-27-CLOSE_RESULT: PASS` (exit code is not the verdict) |
| `tests\db\diagnostics\r27_e6_wait_and_run.ps1 -Server <s>` | wrapper | — | exit 3 = wait timed out |
| `tests\db\build\run_p0_02_bm1.ps1 -Stage <Preflight, Memory, MemoryRollback, Probes or Validate>` | BM-1 only | per stage | `ENV-P0__<utc>_<Stage>.txt` |
| `tests\db\diagnostics\run_e6_bm1_standalone.ps1 [-PreflightOnly]` | BM-1 only | evidence | exit 0 PASS / 1 FAIL / 2–3 BLOCKED / 4 ERROR |
