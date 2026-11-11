# WO-P3-P2-02 — Benchmark Harness and Baseline Capture

| Field | Value |
|---|---|
| Status | **BLOCKED** (not approved; preconditions missing, see Readiness) |
| Phase | P2 — Large Dataset and Baseline Measurement |
| Mode | BUILD_AUTHORIZED (harness, frozen queries) + VERIFY_ONLY (measurement) |
| Approver | Project Owner |
| Approval record | — |
| Target database | Isolated benchmark database(s) per D-025, loaded with DS-M and DS-L by WO-P3-P2-01 in the B0 configuration, named in the approval |
| Revision | 2026-11-08 (Owner Directive "Reprioritize Person 3 Implementation" (2026-11-08, D-027)): Q-BIL-A (billing read path) added; Q-UC05-B/C conditional on the F002 extension; no team prerequisite. 2026-11-08 (Owner Directive "Accept P2-01 and Resolve R-27"): benchmark readiness checklist §2a added (R-27); status unchanged. 2026-11-08 (Owner Directive "R-27 Targeted Remediation and Recheck"): status recorded as BLOCKED; §2a "Now" column updated after the E6 recheck; method recommendations for M3 (no threshold changed). 2026-11-09 (Owner Directive "Urgent Unblock & Core Implementation"): R-27 reclassified as a performance-measurement blocker ([14 R-27 §7](../14_RISK_REGISTER.md#7-disposition-2026-11-09-owner-directive-urgent-unblock--core-implementation)); this WO stays BLOCKED and is still required for formal timing baselines; it no longer gates functional P3/P4 work; the optional final E6 attempt was not performed (preconditions unmet); no threshold changed |
| Readiness | **NOT READY / BLOCKED (2026-11-11 recovery)**: P2-01 PASSED; D-010 APPROVED T2; A7 E5/M3/V003 choices recorded in P0-02 approval; BM-1 feature probes and B0/DS-L verified. P0-02 BLOCKED (E2), E6 NOT_RUN on BM-1, R-27 OPEN; P0-02 Owner gate and this WO authorization absent. Historical E6 FAILs on default instance remain diagnostic only |

## 1. Objective

Freeze the baseline query texts, build a reproducible harness, and capture B0 evidence for every P3 read query before any optimisation exists.

## 2. Preconditions

WO-P3-P2-01 PASSED (✔ 2026-11-08); WO-P3-P0-02 PASSED (environment and feature baseline; moved here on 2026-11-07); D-010 APPROVED (provisional T2 allowed; the revenue definition fixes the oracle and the query predicates). D-007 recommended (it fixes the Q-UC05-A window parameters; otherwise option (d) is used and labelled as an assumption). No integration contract or other member's input is required (D-027). **Benchmark readiness checklist §2a met, including the R-27 closure test** (added 2026-11-08).

## 2a. Benchmark readiness checklist (R-27)

Added by the readiness assessment of 2026-11-08 (Owner Directive "Accept P2-01 and Resolve R-27"; evidence [R-27-DIAG__20261108-1221.txt](../evidence/test-results/R-27-DIAG__20261108-1221.txt); analysis in [14 R-27](../14_RISK_REGISTER.md)). It adds an environment gate and noise controls to the existing protocol of [10 §4](../10_SEED_AND_BENCHMARK_PLAN.md#4-benchmark-methodology) and does not replace it. Thresholds are **proposed** and are confirmed or changed by the Owner in this WO's approval. "Now" = state on 2026-11-08.

| # | Item | Required condition | Evidence that shows it | Now |
|---|---|---|---|---|
| E1 | Power | On AC power; Balanced or higher plan recorded. The system must not sleep or enter connected standby during a series. Preferred means: the harness holds a process-scoped "system required" request (Windows `SetThreadExecutionState`), which ends with the harness and changes no setting. Alternative: the Owner temporarily sets "sleep: never" on AC | Battery status and plan in the manifest; System-log power events (Kernel-Power 42/107/506/507, Power-Troubleshooter 1) for the series window: none | NOT MET (on battery; sleep after 4 min on battery and 10 min on AC; Modern Standby; 7 h sleep in run B). **Recheck 15:54 UTC: MET for that session** (AC, keep-awake helper and harness request, 0 events incl. Kernel-Power 105 from 10 min before S1 to the end). Not yet a standing condition: power-source changes recur when the charger is not firmly connected. Recommended addition (stricter): Kernel-Power 105 in the event list and a 10-min clean window before S1 |
| E2 | Memory available to SQL Server | Before and after each series: available physical memory ≥ 2,048 MB; `process_physical_memory_low = 0`; query-memory semaphore (default pool) target ≥ 256 MB. Heavy applications are closed: browsers, chat clients, extra editor windows and other agent sessions. The agent session waits idle while a series runs | `sys.dm_os_sys_memory`, `sys.dm_os_process_memory`, `sys.dm_exec_query_resource_semaphores` in the manifest (start and end of each series) | NOT MET (about 0.8 GB free; commit 17.7 GB on 7.9 GB RAM; semaphore target 8 MB at 12:22 UTC). **Recheck 15:54: gate MET at all gates (2,202–2,274 MB; semaphore 1.5–1.6 GB), but insufficient:** SQL Server still released its caches and query memory on a low-memory signal mid-S1. A memory floor (option B) is needed |
| E3 | No memory-grant or CPU interference inside a series | Per-series delta: RESOURCE_SEMAPHORE waits = 0 (`sys.dm_exec_session_wait_stats` of the harness session); `forced_grant_count` unchanged; no spill or grant warning in the actual plans; CPU load from other processes recorded. A series that fails is discarded and rerun (10 §4.3 step 8) | Manifest and `raw/` | NOT MET (97 forced grants and 37 RESOURCE_SEMAPHORE waits since the instance start). **Recheck 15:54: FAIL** (one RESOURCE_SEMAPHORE wait of 8.1 s in S1 after the cache release; forced grants unchanged; no spill) |
| E4 | SQL Server configuration documented | Manifest records: version, edition, instance, max/min server memory, MAXDOP, cost threshold, compatibility level, RCSI, Query Store state and the database-scoped settings `DOP_FEEDBACK`, `CE_FEEDBACK`, `*_MEMORY_GRANT_FEEDBACK*`, `PARAMETER_SENSITIVE_PLAN_OPTIMIZATION`, `OPTIONAL_PARAMETER_OPTIMIZATION`, `BATCH_MODE_ON_ROWSTORE` (10 §2) | Manifest | PARTIAL (values read on 2026-11-08 in R-27-DIAG §D3–D4 and again in R-27-DIAG__20261108-1554_before/after; no WO-P3-P2-02 manifest yet) |
| E5 | Repeatable query execution (adaptive features controlled) | DOP feedback, CE feedback, persistent memory-grant feedback and Query Store are all ON in `FitLife_P3_P2`, and each can change a plan or grant between repeated executions. Proposed: in the isolated benchmark database only, turn the feedback features off, or clear Query Store and the plan cache before each configuration. Record the choice; it must be identical for B0 and every later configuration. Either way, this needs this WO's approval | Manifest; identical plan shape and logical reads across the N runs | NOT MET (decision needed at approval). Unchanged on 2026-11-08: all features still ON, nothing switched. E6 ran with this documented configuration and found no adaptive change (plan hash, DOP and grant identical in all valid samples). Input for the decision: with `MEMORY_GRANT_FEEDBACK_PERSISTENCE` ON, feedback survives the frequent recompiles, so "plan-cache clear" alone does not reset it |
| E6 | Stability shown (R-27 closure test) | Two series of one fixed probe query set, ≥ 10 minutes apart, each warm-up + N = 15 (10 §4.3): logical reads identical in every run; median CPU and median elapsed of the two series within 10% of each other; IQR/median ≤ 20% per query; E1–E3 hold for both series | `evidence/test-results/R-27-CLOSE__<ts>.txt` | **FAIL** (run 2026-11-08 13:21 UTC as a diagnostic probe: [R-27-PROBE__20261108-1321.txt](../evidence/test-results/R-27-PROBE__20261108-1321.txt); see [14 R-27 §5](../14_RISK_REGISTER.md#r-27-assessment-2026-11-08)). **FAIL again** at 15:54 UTC with the corrected harness v2 and identical thresholds ([R-27-CLOSE__20261108-1554.txt](../evidence/test-results/R-27-CLOSE__20261108-1554.txt)). Reads and plans identical. Medians within 2–10% except P3 (13.5%). IQR/median 21–40% for all probes. 8 samples invalidated by a mid-series cache release; one 8.1 s grant wait ([14 §6](../14_RISK_REGISTER.md#6-root-cause-update-and-e6-recheck-2026-11-08-r-27-targeted-remediation-and-recheck)) |
| D1 | Representative, validated dataset | DS-M and DS-L from S001 v1.0, seed 20261108; checksum equal to `CHECKSUMS__DS-L__20261108-1155_C.txt` (DS-L) and `CHECKSUMS__DS-M__20261108-0338_A.txt` (DS-M) before measuring | T-REPRO-02 output in the manifest | MET (WO-P3-P2-01 `PASSED`; database holds DS-L) |
| D2 | Statistics | `UPDATE STATISTICS … WITH FULLSCAN` on the four P3 tables after each rebuild and each configuration change (10 §4.3 step 2); the generator does not update statistics (WO-P3-P2-01 §13.7 item 4) | Manifest | NOT MET (harness step) |
| M1 | Cache and warm-up | Warm cache is primary (DS-L reserves 68 MB and fits in memory once E2 holds); one discarded warm-up per query × parameter set; plan-cache policy recorded (10 §4.3 steps 3–4). Cold cache only on a dedicated instance with authorization (10 §4.3 step 7) | Manifest | Defined (10 §4.3); not run |
| M2 | Actual Execution Plans | One separate plan-capture execution per query × parameter set × configuration, saved as `.sqlplan` plus screenshot (10 §4.3 step 6, §4.9); grant and spill warnings checked (E3) | `evidence/execution-plans/`, `screenshots/` | Defined; not run |
| M3 | Logical reads, CPU time, elapsed time | `SET STATISTICS IO, TIME ON` raw output kept verbatim; client elapsed by the harness timer; logical reads are the primary cross-configuration metric because they do not depend on machine noise for a fixed plan | `raw/`, `results.csv` (10 §4.8) | Defined; not run. **Recommendation (2026-11-08, needs this WO's approval):** STATISTICS TIME CPU is quantized to about 15.6 ms on this machine (R-27-CALIB). Take CPU and elapsed from validated `sys.dm_exec_query_stats` deltas, as in harness v2 ([method review](../design/R27_MEASUREMENT_METHOD_REVIEW.md)), and keep STATISTICS IO/TIME as the raw record. Q-BIL-A (sub-ms) needs a fixed repeated-execution unit |
| M4 | Repeated measurements, outliers and noise | N = 15 interleaved runs (N ≥ 20 for p95). Report median, IQR, min and max (10 §4.4). No single run is deleted as an "outlier": a series is either kept whole or discarded whole for a recorded environmental cause (E1–E3), then rerun | `summary.md` | Defined; not run |
| B1 | Baseline preservation | Baseline query files frozen with their SHA-256 (task 1). B0 RUN_IDs are never overwritten. Each later configuration starts from a rebuild of the same dataset, verified by checksum (D1). The rebuild has been shown deterministic: DS-L about 5 min on an awake machine, run C | `db/queries/baseline/` checksums; RUN_ID folders | Defined; not run |

**Go rule:** WO-P3-P2-02 may start measuring only when its preconditions (§2) are `PASSED`/`APPROVED`, E1–E3 hold at the start of the session, and E6 has passed once, which closes R-27. The harness itself (task 3) and the frozen queries (task 1) may be built before E6, because they do not depend on timings.

## 3. Inputs

[10 §4](../10_SEED_AND_BENCHMARK_PLAN.md#4-benchmark-methodology); [07 §5](../07_UC06_REVENUE_PLAN.md#5-baseline-query-candidates-specifications-to-be-frozen-in-wo-p3-p2-02); [04 §6](../04_WORKLOAD_AND_DATA_VOLUME.md#6-query-workload-catalogue).

## 4. Tasks

1. Write the baseline query files and the oracle queries. Record their checksums. **These files are never edited afterwards.**
   - Billing: Q-BIL-A (invoice detail by `Invoice_ID`, read step of F06).
   - Loyalty: Q-UC05-A (window spend from INVOICE, the Problem 4 path); Q-UC05-B/C only if F002 exists (otherwise their B0 is captured in WO-P3-P3-02 before any loyalty index).
   - Revenue: Q-UC06-A, A0, B, C, D (core); E, F only if D-001 assigns RPT-05/06 to P3; G only with F002 and if in scope.
2. Choose and record the fixed parameter sets ([10 §4.2](../10_SEED_AND_BENCHMARK_PLAN.md#42-fixed-parameter-sets)).
3. Build the harness: manifest writer, timed loop (warm-up + N runs), STATISTICS IO/TIME capture, result-hash computation, CSV writer.
4. Capture B0 on DS-M and DS-L following [10 §4.3](../10_SEED_AND_BENCHMARK_PLAN.md#43-measurement-protocol): warm-up, N = 15 timed runs per query × parameter set (logical reads, CPU, elapsed), then separate Actual Execution Plans with screenshots. Document the methodology and the plan-cache policy in each manifest.
5. The U0 settlement baseline is captured in WO-P3-P3-03, because it needs the routine from WO-P3-P3-01.
6. Write `summary.md` per RUN_ID; update [16](../16_READINESS_REPORT.md) and [SESSION_LOG.md](../SESSION_LOG.md).

## 5. Out of scope

Creating any index, summary or partition (no optimisation index may exist before the baseline is captured); changing the baseline queries after capture; other members' queries (T-REG-03, P6); running benchmarks against the canonical shared database (D-025 condition 4).

## 6. Deliverables and locations

DL-05 (`db/queries/baseline/`, `db/benchmark/`); DL-06 (`evidence/benchmark-results/<RUN_ID>/`, `evidence/execution-plans/`, `evidence/screenshots/`).

## 7. Acceptance criteria

1. Every in-scope P3 read query has a B0 RUN_ID on DS-M and DS-L with the manifest, CSV, raw output, plan and screenshot.
2. Each query's result hash equals its oracle hash.
3. A harness re-run reproduces identical logical reads (T-REPRO-03, partial).
4. No reported number lacks a RUN_ID.

## 8. Verification

Re-run one configuration and compare; spot-check one plan screenshot against its `.sqlplan`.

## 9. Evidence

As in §6.

## 10. Dependencies and risks

R-07, R-08, R-14.

## 11. Approval requirements

WO approval; authorization for any cold-cache commands (only on a dedicated instance).

## 12. Exit and next step

GATE-P2. Next: WO-P3-P3-00 (billing; P3 has priority) and, if the Owner approves the parallel start, WO-P3-P4-01.

## 13. Execution record

_(filled by the executing session)_

## 2b. Readiness update and execution plan (2026-11-10)

Owner Directive "Accept P3 Correctness & Unblock Performance" (Claude Code session of 2026-11-10) §3–§5 (planning and read-only inspection only; status unchanged: **BLOCKED**, not approved). Full analysis: [design/BENCHMARK_ENVIRONMENT_READINESS.md](../design/BENCHMARK_ENVIRONMENT_READINESS.md).

- Preconditions now met: WO-P3-P2-01 `PASSED`; **D-010 APPROVED (T2) 2026-11-10** (the "D-010 `PROPOSED`" notes above are superseded); D-007 APPROVED (T2).
- Still missing: WO-P3-P0-02 `PASSED` (five feature probes need object creation); a benchmark environment meeting E1–E3; **E6 PASS** (R-27 closure); decisions E5, M3 and V003-in-B0 at approval.
- Environment: no separate machine is available; recommended **BM-1 = instance `localhost\MSSQLSERVER01`** (same build 17.0.1000.7 and edition, no user database) with a memory floor/cap on that instance only, "Best performance" power mode for sessions and the operator procedure; authorizations A1–A7 in the readiness document §3.
- Execution sequence (readiness document §5.2): environment verification → feature probes → DS-L build on BM-1 with checksum = run C → E6 → plan capture → logical reads → CPU/elapsed → reproducibility. Formal measurement starts only after steps 1–4 pass and this WO is approved.

## 2c. Recovery update - 2026-11-11

A1-A7 are recorded approved in P0-02 (2026-11-10); they authorize readiness only. E5=current settings; M3=validated DMV deltas with raw STATISTICS IO/TIME; V003 included in B0. Feature probes and DS-L integrity now verified; [ENVIRONMENT_P0](../design/ENVIRONMENT_P0.md). E2 still unmet, so no E6 on BM-1 and no formal baseline. Other historical section 2a/2b "Now" cells describe their dated assessments. This WO remains BLOCKED and unapproved.
