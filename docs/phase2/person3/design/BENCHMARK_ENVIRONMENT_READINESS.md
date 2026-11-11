# Benchmark Environment Readiness (R-27 unblocking) — Person 3

| Field | Value |
|---|---|
| Status | **BLOCKED (reconciled 2026-11-11)**. A1-A7 approved 2026-11-10 in WO-P3-P0-02; preparation verified, E6 NOT_RUN due E2; earlier proposal sections retained as history |
| Authority | Owner Directive "Accept P3 Correctness & Unblock Performance" (2026-11-10) §3–§6 |
| Evidence | [ENV-INVENTORY__20261110-080635](../evidence/test-results/ENV-INVENTORY__20261110-080635.txt) (read-only); earlier R-27 evidence in [14 R-27](../14_RISK_REGISTER.md#r-27-assessment-2026-11-08) |
| Affects | WO-P3-P0-02, WO-P3-P2-02, then WO-P3-P3-03 Part P, WO-P3-P4-01 Part X, WO-P3-P4-02, WO-P3-P5-01 |

## 1. Infrastructure found (read-only inspection, 2026-11-10 08:06 UTC)

No other machine, VM or cloud subscription is visible or configured from this session: no Docker, no Azure CLI, no linked server; LAN discovery was deliberately not performed. **No separate stable benchmark machine is available to Person 3 today.** What exists on the Owner's laptop (i5-1135G7 4C/8T, 7.7 GB RAM, NVMe 256 GB, Windows 10 build 19044, Balanced plan, on AC at capture):

| Candidate | Facts | Usable as benchmark environment? |
|---|---|---|
| `MSSQLSERVER` (default instance) | SQL Server 17.0.1000.7, Standard Developer (EngineEdition 2); memory unlimited/16 MB; MAXDOP 8; cost threshold 5; **8 user databases**: the four P3 databases plus four non-P3 databases of the Owner; started 2026-10-27; `process_physical_memory_low = 1`, default-pool grant target 9 MB at capture | Possible, but every instance-level change (memory floor, cache clears) also hits the Owner's other databases, and its plan cache/Query Store/wait statistics carry history from all earlier diagnostics |
| **`MSSQLSERVER01`** (named instance) | **Same build 17.0.1000.7, same edition and defaults; 0 user databases**; running, Agent stopped; `process_physical_memory_low = 1`, grant target 5 MB at capture | **Yes — recommended (BM-1)**, with the remediation of §3. Same engine and feature set, so feature probes and dataset scripts transfer unchanged; no other database is affected by its configuration |
| WSL2 `Ubuntu` (stopped) | Would need SQL Server for Linux installed; same physical RAM | No: installation not authorized, different OS stack, same memory pressure |
| LocalDB (`SqlLocalDB` 150) | SQL Server 2019 engine | No: different engine version (not comparable to 17.0) |

Root cause of R-27 (unchanged, [14 §6](../14_RISK_REGISTER.md#6-root-cause-update-and-e6-recheck-2026-11-08-r-27-targeted-remediation-and-recheck)): the OS low-memory signal makes SQL Server release caches and query memory mid-series (confirmed), plus suspected CPU frequency changes under the Balanced plan. At capture only 0.6 GB was free (browser ≈ 1.8 GB, editor ≈ 1.1 GB, chat clients ≈ 0.5 GB). **A second instance on the same laptop does not remove this cause by itself**; it only makes the remediation safe and isolated. E6 remains the arbiter.

## 2. Requirements check for BM-1 (`MSSQLSERVER01`)

| Requirement (directive §3) | BM-1 as is | After remediation (§3) |
|---|---|---|
| Compatible engine and configuration | MET (17.0.1000.7, same edition, compatibility 160 set by the build scripts) | MET; configuration recorded in every manifest (E4) |
| Sufficient, stable memory | NOT MET (no floor; OS low-memory signal) | Floor `min server memory` = 1,024 MB, cap `max server memory` = 2,048 MB on BM-1 only; E2 gate ≥ 2,048 MB available before each series |
| Stable CPU and power | PARTIAL (on AC now; Balanced plan) | AC + "Best performance" power mode for the session; harness-held keep-awake (E1) |
| Controlled background workload | NOT MET (browser, chat clients, several editor windows) | Operator closes them for the session; agent session idle during timed series; `MSSQLSERVER` left idle |
| Reproducible dataset deployment | Scripts ready: `tests/db/seed/run_p2_dataset.ps1 -Server localhost\MSSQLSERVER01` builds `FitLife_P3_P2` there; acceptance = DS-L checksum `26ABB277…CA1F` (run C) | Same |
| Actual Execution Plans | Available (same engine) | Same |
| Reliable logical reads, CPU, elapsed | Logical reads deterministic (shown in R-27 probes); CPU/elapsed unproven | Proven only by **E6 PASS** on BM-1 with unchanged thresholds |

## 3. Recommendation and exact Owner authorizations

**Recommended environment: BM-1 = instance `MSSQLSERVER01` on the Owner's laptop, dedicated to Person 3 benchmarks.** All configurations of all performance WOs are then measured on BM-1 only (R-07); nothing measured on `MSSQLSERVER` is mixed in. If E6 fails on BM-1 after this remediation, the only remaining path is a different physical machine supplied by the Owner (option E), or an Owner decision on the statistical design taken **before** further runs.

Authorizations needed (each explicit; nothing is done without them):

| # | Authorization | Exact content | Reversal |
|---|---|---|---|
| A1 | Approve **WO-P3-P0-02** (amended, §5) as BUILD_AUTHORIZED + VERIFY_ONLY with target instance `localhost\MSSQLSERVER01` | Declares BM-1 the D-025 benchmark target for Person 3 | — |
| A2 | Create databases on BM-1 | `FitLife_P3_Probe` (feature probes, dropped at the end) and `FitLife_P3_P2` (DS-L, then DS-M for P2-02; disposable marker of WO-P3-P2-01; built only by the existing scripts) | Drop scripts with marker guard |
| A3 | Instance memory setting on BM-1 only | `sp_configure 'show advanced options', 1; sp_configure 'min server memory (MB)', 1024; sp_configure 'max server memory (MB)', 2048; RECONFIGURE;` | Back to 16 / 2147483647 |
| A4 | Windows power mode "Best performance" while plugged in, for measurement sessions only | Power slider; no plan or policy change | Slider back to Balanced |
| A5 | Operator procedure for each measurement session | Charger secured; browser, chat clients and extra editor windows closed by the Owner; 10 clean minutes before the first series; agent session idle while a series runs | — |
| A6 | Test-harness change (BUILD) | Add a `-Server` parameter to `tests/db/diagnostics/r27_e6_probe.ps1` and `r27_e6_wait_and_run.ps1`, and remove their hard-coded local paths (they currently target `localhost` only) | Files versioned |
| A7 | Decisions for WO-P3-P2-02 approval | E5 (adaptive features: proposed OFF on BM-1 databases only, identical for every configuration), M3 (CPU/elapsed from validated `sys.dm_exec_query_stats` deltas; STATISTICS IO/TIME kept raw), thresholds of §2a unchanged, cold-cache variant allowed on BM-1 (dedicated instance, 10 §4.3 step 7) | — |

Not requested: locked pages in memory, power-plan policy changes, any change to `MSSQLSERVER` or its databases, software installation, data transfer to another machine.

## 4. Experiment comparability (fixed before any formal run)

| Item | Rule |
|---|---|
| Dataset | DS-L (and DS-M) generated by S001 v1.0, seed 20261108 on BM-1; T-REPRO-02 checksum must equal run C (`CHECKSUMS__DS-L__20261108-1155_C.txt`) / DS-M run A before measuring; rebuilt and re-checked for every configuration (B1) |
| Migration version | B0 = the P1 schema as in `FitLife_P3_P2` today: V001 + V002 (no optimisation index). Whether V003 (point-rule CHECK, a production constraint since WO-P3-P3-02) is part of B0 for the read queries and of U1 for settlement is decided in the P2-02 approval and recorded in every manifest |
| Baseline queries | Frozen by P2-02 task 1 (Q-BIL-A, Q-UC05-A, Q-UC06-A/A0/B/C/D); Q-UC05-B/C already frozen in `db/queries/baseline/` with their B0 reads/plans (WO-P3-P3-02 task 0, DIAGNOSTIC_ONLY timings). SHA-256 recorded; never edited after capture |
| Compatibility, configuration | Compatibility 160; E4 configuration snapshot in every manifest |
| Indexes and statistics | Index inventory = clustered primary keys only (catalog digest `non_pk_indexes=0`); `UPDATE STATISTICS … WITH FULLSCAN` on the four P3 tables after each build/configuration (D2) |
| Warm-up and repetition | 10 §4.3: one discarded warm-up per query × parameter set; N = 15 interleaved timed runs (N ≥ 20 for p95); separate actual-plan execution |
| Variability criteria (pre-registered) | E6 thresholds unchanged: logical reads identical; medians of two series ≥ 10 min apart within 10%; IQR/median ≤ 20%; a series is kept or discarded whole for a recorded E1–E3 cause (M4) |
| Prior timings | R-27 PROBE/CALIB/CLOSE timings and all functional-run durations stay DIAGNOSTIC_ONLY; never reused as baseline |

## 5. WO-P3-P2-02 readiness and execution sequence

### 5.1 Prerequisites by category

| Category | Item | State on 2026-11-10 |
|---|---|---|
| Environment readiness | E1–E3 standing conditions; E6 closure test | NOT MET (BM-1 not configured; E6 never run on BM-1) |
| Database feature verification (WO-P3-P0-02) | Machine/instance facts (tasks 1–2) | Captured (R-27-DIAG, ENV-INVENTORY); to be written into `ENVIRONMENT_P0.md` for BM-1 |
| | `GENERATE_SERIES` (3e) | Equivalent evidence exists (P2-01 runs) |
| | PowerShell `System.Data.SqlClient` (task 4) | **Equivalent evidence exists**: every T-CONC harness connects with SqlClient and Windows authentication (e.g. `P3-03-RUN__20261110-0737`) |
| | Filtered index (3a), partition function/scheme (3b), indexed view + matching without NOEXPAND (3c), `ONLINE = ON` (3d), DML with/without `-I` (3f) | **NOT_RUN — need object creation** in `FitLife_P3_Probe` (DDL fixed in WO-P3-P0-02 §2a). No PASS without execution |
| Business decisions | D-010 recognised revenue | APPROVED (T2) 2026-11-10 |
| | D-007 tier window (Q-UC05-A parameters) | APPROVED (T2) (d) |
| | D-008 threshold values | Not needed for P2-02 queries |
| | D-001 (Q-UC06-E/F/G) | Open; those queries stay out of scope |
| Baseline execution | Tasks 1–6 of WO-P3-P2-02; E5, M3, V003-in-B0 decisions | NOT STARTED; decisions at approval (A7) |

### 5.2 Execution sequence (after A1–A7)

| Step | WO | Action | Pass rule / evidence |
|---|---|---|---|
| 1 Environment verification | P0-02 | Record machine and BM-1 facts (10 §2 fields); apply A3 and verify `value_in_use`; power mode set; operator procedure A5 | `ENV-P0__<ts>.txt`; `design/ENVIRONMENT_P0.md` |
| 2 Feature probes | P0-02 | Run the §2a DDL in `FitLife_P3_Probe` on BM-1 (3a–3d, 3f); record result or error text; drop the probe database; list databases before/after | Every probe has a recorded result; probe DB gone |
| 3 Baseline data validation | P0-02 | `run_p2_dataset.ps1 -Server localhost\MSSQLSERVER01 -Dataset DS-L -RunLabel BM -CompareWith …_C.txt`; T-SCH-02 conformance; index inventory | DS-L checksum = run C; `non_pk_indexes = 0` |
| 4 Controlled readiness probe (R-27 closure) | P0-02 | E6 with harness v2 (+ `-Server`, A6), unchanged thresholds, E1–E3 gates at every series | `R-27-CLOSE__<ts>.txt` PASS → R-27 closed; FAIL → stop, report, option E decision |
| 5 Actual Execution Plan capture | P2-02 | Freeze queries and parameter sets (tasks 1–2); one actual-plan run per query × set on DS-L (then DS-M) | `.sqlplan` + screenshot per query × set; result hash = oracle |
| 6 Logical reads | P2-02 | STATISTICS IO for warm-up + N runs | Identical reads in every run of a series |
| 7 CPU / elapsed | P2-02 | N = 15 interleaved runs per series; validated `dm_exec_query_stats` deltas (M3) + raw STATISTICS TIME; gates E1–E3 per series | Median, IQR, min, max; series discarded whole on a gate failure |
| 8 Reproducibility | P2-02 | Rebuild DS-L from scripts, checksum, re-run one configuration (T-REPRO-03 partial); second series ≥ 10 min later | Identical reads; medians within the pre-registered tolerance |

Stop rules: any checksum mismatch, any non-PK index in B0, or an E6 FAIL stops the sequence before formal measurements. The formal P2-02 benchmark does not start until steps 1–4 are `PASSED` and WO-P3-P2-02 is approved.

## 6. Remaining performance work after P2-02 (identifiers unchanged; none starts automatically)

1. WO-P3-P3-03 Part P — U0 vs U1 settlement, invoice-creation cost baseline (before any P4 index, R-11), T-PERF-01/02/08, IX-07, T-CONC-04 blocking duration.
2. WO-P3-P4-01 Part X — index candidates, T-PERF-03…06, T-REG-01, `INDEX_DECISIONS.md`.
3. WO-P3-P4-02 — revenue summary / indexed-view experiment (+ T-CONC-03 if a summary is adopted).
4. WO-P3-P5-01 — partition feasibility and experiment (needs the P0-02 probe 3b and P4-01 best-B1).

## 7. Independent mandatory work if BM-1 preparation is blocked

No performance claim is made by any of these:

- WO-P3-P8-01 (partial): report chapters for the completed functional scope (schema, dataset, UC05 billing/loyalty, UC06 reports, correctness and concurrency evidence) with links to existing evidence.
- WO-P3-P5-01 analysis part: partition key/interval options, alignment with the clustered PK and constraints, maintenance and archival reasoning from DS-L row counts and growth (04); plans and logical reads may be collected, timings not.
- P6 preparation only with the team (D-027): the dependency register DEP-19 caller rules (R-29) are already written down for the scheduler owner.

## 8. Interrupted-session recovery - 2026-11-11

WO-P3-P0-02 **BLOCKED**: approved preparation completed, E6 **NOT_RUN** because the physical-memory precondition failed (observed 722-1144 MB; required >= 2,048 MB). R-27 **OPEN**. No benchmark failure or performance claim. Memory settings restored to their recorded original configuration; temporary power mode was not applied. P2-02 remains not authorized.

This supersedes historical readiness states in sections 1-5: BM-1 is populated, feature probes completed/cleaned, A6 completed and A7 resolved as recorded by the dated WO approval. Full evidence and task matrix: [ENVIRONMENT_P0](ENVIRONMENT_P0.md). Earlier proposal and raw manifest labels are preserved, with corrections in that report. No formal benchmark was started.
