# R-27 Measurement Method Review and E6 Harness Correction

| Field | Value |
|---|---|
| Directive | Owner Directive "R-27 Targeted Remediation and Recheck" (2026-11-08), §2–§5 |
| Mode | PLAN_ONLY review (§3); harness-only correction classified as **narrow BUILD_AUTHORIZED** (authorized by the directive: no schema, seed data, benchmark query, index or server-configuration change); calibration and dry runs SELECT-only (VERIFY_ONLY) |
| Status | Review completed **before** the E6 recheck. Results of the recheck are recorded only in [14 R-27 §5–§6](../14_RISK_REGISTER.md#6-root-cause-update-and-e6-recheck-2026-11-08-r-27-targeted-remediation-and-recheck) and the evidence files (15:54 UTC run: FAIL) |
| Scope | The R-27 diagnostic harness only. Not the WO-P3-P2-02 harness (its task 3), not the baseline |

## 1. Starting point

The E6 probe of 13:21 UTC ([R-27-PROBE__20261108-1321.txt](../evidence/test-results/R-27-PROBE__20261108-1321.txt)) failed. Logical reads were deterministic (P1 8, P2 3,281, P3 3,281, P4 7,245) and no grant waits occurred. Timing failed for P2–P4: S1 ran 1.6–2.7× slower than S2, and within-series IQR/median reached 65%. G-E1 failed because AC was lost in S1; G-E2 failed because 1,754–1,784 MB were available in S1. The previous session proposed (handoff 7(a)–(e)) to treat memory pressure as "confirmed, mitigated" and to switch the timing source to `last_worker_time`/`last_elapsed_time`.

## 2. Root-cause re-analysis: confirmed versus suspected

New read-only evidence, 2026-11-08 14:50–15:30 UTC: System event log; `RING_BUFFER_RESOURCE_MONITOR`; plan cache and buffer pool state; instrument calibration [R-27-CALIB__20261108-1458.txt](../evidence/test-results/R-27-CALIB__20261108-1458.txt).

| Factor | Evidence | Classification | Effect on the 13:21 E6 result |
|---|---|---|---|
| Unstable AC connection | S1 end gate AC = False. Kernel-Power 105 (power-source change) at 13:20:44, 13:20:45, 13:21:11, **13:21:43 (the second S1 started)** and 13:24:26. More 105 events at 12:34, 12:42–12:43, 13:14, 14:41 and 14:49 (three). Connected standby 12:11–12:14, 12:52–13:00, 13:42–13:54, 14:05–14:41, and a resume at 15:24 | **Confirmed** environmental cause: S1 did not run in the same power state as S2 | Probable main contributor to the S1/S2 difference. It cannot be separated from CPU load (next row): both changed together |
| CPU contention from other processes | S1 gates 40% / 26% load against 2% / 1% in S2. Visual Studio Installer `BackgroundDownload.exe` used about 13% at 13:20. At 14:50: Windows servicing (TiWorker, TrustedInstaller, MoUsoCoreWorker), a VS Code updater (`CodeSetup-stable…tmp`, running since 01:20 UTC) and Chrome | **Confirmed present** | Probable contributor. For the serial P3, CPU time rose 2.7× with identical reads and plan. That means slower or shared cores, not more work |
| CPU frequency variability (Balanced plan) | `% Processor Performance` on AC: 125% (14:56), 144% (15:28), 59% (15:30) | Variability **confirmed**; effect on timings **suspected** | Not measured at 13:21. The corrected gates record it |
| STATISTICS TIME CPU quantization | 13:21 values cluster at multiples of about 15.6 ms (supplement S2). Calibration: for the same executions, the DMV worker time is fine-grained (P1 101–228 µs, P2 22.7–38.9 ms) while STATISTICS TIME CPU shows 0/15/16/31/47 | **Confirmed measurement defect** | The CPU criteria of P2 (about 25–30 ms) and P4 (parallel: one quantization per thread) could not be met at 10%/20% even in a stable environment. **Does not explain the elapsed failures**: STATISTICS TIME elapsed has 1 ms resolution (calibration: it equals the DMV elapsed truncated) |
| Memory: query-grant pressure | 13:21: 0 RESOURCE_SEMAPHORE waits, 0 forced grants, semaphore target 1.1–1.7 GB. Semaphore target 8 MB at 12:22 and **9 MB at 15:28** (dry-run precheck), with `process_physical_memory_low` = 1 | Condition **confirmed** (recurs); **not a cause of the 13:21 failure** | None at 13:21. It remains a live risk for grant-requiring queries (P3 1.5 MB, P4 36 MB), controlled by G-E2/G-E3 |
| Memory: cache eviction | `RESOURCE_MEMPHYSICAL_LOW` (system indicator) every 1–3 min from 13:37 to 14:53, with 950–2,800 MB available. Both 13:21 warm-ups did physical/read-ahead reads and recompiled, so the data and plans had been evicted between S1 and S2. At 14:53 only 44 pages (< 1 MB) of the database were cached and no probe plan; all four plans were recompiled again between 14:55 and 14:58. `AUTO_CLOSE` is OFF, so the database is not closing | **Confirmed mechanism** (SQL Server trims caches on the OS low-memory signal; no memory floor) | **None on measured runs**: runs 1–15 of both series had 0 physical reads and no compile. A notification inside a series would make samples cold, so the corrected harness gates on it (G-WARM, C-ID) |
| Memory: the earlier "primary cause" statement | The 97–98 forced grants and 28,791 s of RESOURCE_SEMAPHORE waits are cumulative since the instance start (2026-10-27). The longest wait spans a 7 h sleep | **Correction**: these counters cannot be attributed to the measurements. Memory pressure is a confirmed condition and a cache-eviction mechanism, not the demonstrated cause of the timing instability | — |
| G-E2 failure at 13:21 S1 | 1,754–1,784 MB available; SQL Server "Available physical memory is high"; `phys_low` = 0 | Threshold failure only | Not evidence of pressure on the measured runs |
| Disk I/O, dataset or state drift | 0 physical reads in measured runs; identical logical reads; checksums identical (GATE-P2-01 re-check) | **Excluded** for measured runs | — |
| Thermal throttling | No tool available without installation | **Not verified** | Unknown |
| Within-series dispersion under good conditions (S2) | Elapsed IQR/median 26–40% for P2–P4 (1 ms resolution, so real) | Real variance; cause **suspected**: frequency transitions between short executions, and P4 at DOP 8 on all 8 logical CPUs of a 4-core laptop | Contributed to the C-IQR failures |

**Conclusion.** The confirmed causes of the 13:21 failure are environmental (power-source instability, with background CPU load in the same series) plus one measurement defect (CPU-time quantization). Memory pressure did not cause that failure. It is confirmed as an eviction mechanism and a recurring grant risk, and is handled by gates, not by changing the measurement.

## 3. Evaluation of measurement sources

| Source | What it measures | Resolution on this instance (calibrated) | Pitfalls | Use in E6 v2 |
|---|---|---|---|---|
| `SET STATISTICS TIME` | Per-statement server CPU and elapsed, integer ms | CPU in steps of about 15.6 ms; elapsed 1 ms, truncated (= DMV elapsed truncated; P4 within 1 ms) | CPU unusable below about 150 ms per execution. For a parallel plan, the quantization adds up per thread. Sub-ms statements read 0 | Kept ON, raw output verbatim (M3); cross-check only |
| `sys.dm_exec_query_stats` | Per cached plan: execution count, worker and elapsed time (µs), reads, spills, DOP, grant | Values are sub-ms granular (P1 101–228 µs); documentation states millisecond accuracy | Plan lifetime: eviction and recompile reset the row, and eviction here happens within minutes. Auto-parameterized text drops the comment tag (P2), so identity must use `query_hash`. Rows aggregate all sessions | **Timing source**, as validated deltas per sample (§4) |
| Actual Execution Plan (`QueryTimeStats`, per-operator runtime) | ms per statement and operator | ms | Collection overhead distorts timing (10 §4.3 step 5) | Plan identity, grant and spill check after the series only |
| High-resolution client timer (`Stopwatch`, 100 ns) | Client round trip + server + result transfer | 0.1 µs | Needs an in-process connection (SqlClient); dominated by round-trip overhead for sub-ms statements; a larger harness change | Not adopted (not the smallest change; the server-side source is adequate) |
| Repeated-execution batch | Total of K executions, divided by K | Amortizes the resolution limit by K | Changes the sample unit; must be fixed in advance and used identically for later configurations | **P1 only** (one execution is about 0.1–0.25 ms, below the documented DMV accuracy); K = 200 |
| `SYSDATETIME()` deltas | Server wall clock | About 1 ms steps (calibration C1) | Batch context changes statement identity | Not used |

## 4. Selected method and justification

1. **Timing source:** `sys.dm_exec_query_stats` deltas of `total_worker_time` and `total_elapsed_time` for the probe statement, read in a separate batch right after each sample in the same session, divided by K. This removes the confirmed CPU quantization. It is the smallest change: same `sqlcmd` harness, same statements, one extra read per sample.
2. **Validation (directive §3)** for every sample, part of the verdict (C-ID):
   - **Statement identity:** exactly one cached row for the `query_hash`; `query_plan_hash` equal to the 13:21 reference.
   - **Execution count:** it rose by exactly K, so no other session ran the statement and no eviction or recompile happened in between.
   - **Plan stability:** plan handle, creation time and generation are unchanged.
   - **Cross-check against STATISTICS:** for K = 1, the STATISTICS TIME elapsed of the same execution lies within [floor, floor + 1] of the DMV value in ms, and the STATISTICS IO logical reads equal the DMV reads.
3. **Sample unit:** P2–P4 stay one execution per sample (as in v1 and in 10 §4.3), because 20–200 ms is far above the 1 ms resolution. P1 becomes a batch of K = 200 identical single-statement executions (`GO 200`), because one execution (about 0.1–0.25 ms) is below the documented accuracy. Its output goes to NUL to keep the raw file small. Its raw record is the DMV reading before and after each batch.
4. **Thresholds unchanged:** median difference ≤ 10%, IQR/median ≤ 20%, logical reads identical. The v1 "resolution rule" (C-RES, absolute tolerance for medians < 5 ms) is **removed**, so P1 now faces the original relative thresholds.
5. **Not chosen:** reading `last_*` values alone, because they fail silently under concurrent executions. A client timer would need a larger change. Averaging P2–P4 in batches would change the benchmark's sample unit and could hide the instability E6 is meant to detect.

## 5. Harness changes (v1 → v2)

Full diff: [R-27-HARNESS-DIFF__20261108-1532.txt](../evidence/test-results/R-27-HARNESS-DIFF__20261108-1532.txt). v1 SHA-256 `9D45B929…3716` (13:21 run); v2 `tests/db/diagnostics/r27_e6_probe.ps1` SHA-256 `74D40E03…5080`.

| # | Change | Reason |
|---|---|---|
| H1 | Timing from validated DMV deltas (µs) instead of STATISTICS TIME | Confirmed CPU quantization (§2) |
| H2 | P1 sample = `GO 200` batch, output to NUL; K recorded | Sub-ms statement (§4.3) |
| H3 | C-ID per-sample identity, execution-count, plan and cross-check validation | Directive §3 DMV conditions |
| H4 | G-WARM: DMV physical-read delta = 0 (and STATISTICS physical/read-ahead = 0) in every measured sample | Confirmed cache eviction within minutes |
| H5 | C-PLAN: plan hash equal to the reference; DOP identical; grants reported | Directive §6 "stable execution plan" |
| H6 | G-E1 event list completed to the §2a list (Kernel-Power 42/107/506/507, Troubleshooter 1) **plus 105**, from 10 min before S1 to the end | v1 checked only 42/506/1; directive §4 "no recent power-source transitions" |
| H7 | Preconditions PRE-1…PRE-5 (AC, no recent power event, database identity and marker, no conflicting session or `sqlcmd`, memory gate). The run aborts before any series if one fails, and the precheck is recorded | Directive §4 items 1–7; avoids burning a series |
| H8 | Gates also record `% Processor Performance`, low-memory notifications since start, cached pages, other requests on the instance | Separating frequency, contention and memory causes |
| H9 | T-REPRO-02 dataset checksum before and after, compared byte for byte with `CHECKSUMS__DS-L__20261108-1155_C.txt` | Directive §4.5 and §6 |
| H10 | Plan-cache view by `query_hash` (v1 missed auto-parameterized P2); STATISTICS cross-check columns in the raw sample table; output named `R-27-CLOSE__<ts>` (14 §4) | Correct identity; traceability |
| H11 | Number formatting with the invariant culture | Locale-independent evidence |

**Unchanged:** the four probe statements (byte-identical), the database, warm-up + 15 interleaved runs, two series ≥ 10 min apart, the keep-awake request, plan capture after the series, the before/after diagnostic snapshots (`r27_diag.ps1`, byte-identical), and no cache clear and no setting change.

## 6. Review before execution

| Check | Result |
|---|---|
| Changes limited to the harness; no schema, data, index, query or configuration change | Yes: the series SQL contains only the four SELECTs, `PRINT`, DMV reads and SET STATISTICS |
| Thresholds equal to WO-P3-P2-02 §2a E6 / 14 R-27 §4 | Yes; C-RES removed; only stricter gates added (G-WARM, C-ID, C-PLAN, E1 events) |
| Criteria written before the run | Yes: in the script (`$Criteria`), printed in the result file |
| Self-review defects found and fixed before any dry run | (1) `ms_ticks` read returned one column and could not be parsed; (2) two calls passed method-call arguments without parentheses; (3) one unused leftover line |
| Dry runs (scratchpad, not evidence; 2 and 3 runs, no gap, uncontrolled environment) | Run 1 found a real defect: PowerShell variable names are case-insensitive, so `$K` (repetitions) overwrote `$k` (query), giving 2 invalid samples. `$qph` would likewise have overwritten `$QPH` (reference hashes). Both renamed; a scan found no other cross-scope collisions. Run 2: C-ID 24/24 valid; `:out NUL` works (P1 Δexecution_count = 200 exactly); G-WARM and G-E3 computed |
| Safety | SELECT-only. Side effects recorded rather than avoided: Query Store capture, plan-cache entries, possible automatic statistics creation. The checksum script uses a table variable (tempdb) only |

## 7. Implications for WO-P3-P2-02 (recommendations; Owner approval needed)

1. M3: use the validated DMV deltas as the CPU/elapsed source and keep STATISTICS IO/TIME as the raw record. STATISTICS TIME CPU alone cannot support 10%/20% criteria for queries under about 150 ms.
2. Q-BIL-A (P1 shape) needs the repeated-execution unit; its K must be frozen with the query.
3. Add G-WARM and the completed E1 event list (incl. 105) to §2a. The per-series warm-up is mandatory because the cache does not survive minutes on this machine.
4. E5: with `MEMORY_GRANT_FEEDBACK_PERSISTENCE` ON, feedback survives the frequent recompiles. "Plan-cache clear per configuration" therefore does not reset it; only "feedback off" or "Query Store clear" does. Input for the Owner's E5 decision; nothing changed.
