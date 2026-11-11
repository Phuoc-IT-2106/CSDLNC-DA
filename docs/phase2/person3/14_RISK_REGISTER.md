# 14 — Risk Register (Person 3)

| Field | Value |
|---|---|
| Document status | DRAFT — WO-P3-BOOT-001; updated 2026-11-07 (Owner Directive WO-P3-P0-FINAL); R-03, R-04 mitigations and R-26 by the Owner Directive "Reprioritize Person 3 Implementation" (2026-11-08, D-027); R-27 added by WO-P3-P2-01 (2026-11-08); R-27 assessed by the Owner Directive "Accept P2-01 and Resolve R-27" (2026-11-08; [§R-27 assessment](#r-27-assessment-2026-11-08)); R-27 causes corrected and E6 re-run by the Owner Directive "R-27 Targeted Remediation and Recheck" (2026-11-08; §5, §6); R-27 reclassified as a performance-measurement blocker by the Owner Directive "Urgent Unblock & Core Implementation" (2026-11-09; §7) ; R-28 added and R-10, R-16, R-27 reviewed by the Owner Directive "Close Invoice Creation and Prioritize Settlement" (2026-11-09; [§8](#8-update-2026-11-09-owner-directive-close-invoice-creation-and-prioritize-settlement)) |
| Date | 2026-11-09 |
| Scale | Likelihood (L) and Impact (I): High / Medium / Low. All risks are OPEN. |
| Review | Re-assess at every phase gate ([15](15_ROADMAP_AND_WORK_ORDERS.md)) and record changes here. |

| ID | Risk | Cause | L | I | Mitigation | Trigger / indicator | Owner |
|---|---|---|---|---|---|---|---|
| R-01 | Business rules stay unresolved (status, PaidAt, points, tier window, thresholds, revenue, refunds) | Sources silent or conflicting (G-02…G-11) | High | High | WO-P3-P0-01 decision brief; P1/P3/P4 entry gated on the listed decisions; rules isolated in configuration/parameters where possible | Decision still PROPOSED at a WO's start | P3 / Project Owner |
| R-02 | Scope conflict between the 7-UC and 6-UC catalogues causes duplicated or orphaned work (F06, F29, F30, RQ-A16–18) | S-10 missing | High | High | D-001 with an explicit owner per function; scope-pending rows kept in [01](01_REQUIREMENTS_TRACEABILITY.md) | Two members building the same function, or none | Team |
| R-03 | Shared schema drift: the team's real MEMBER, BRANCH, EMPLOYEE, SERVICE_PLAN or PRODUCT keys differ from the Phase 1 names and types that P3's FKs and fixtures use | No contract yet; P1 uses TEST_ONLY key fixtures (D-026, restricted) | Medium | High | Shared-dependency interface ([12 §2a](12_INTEGRATION_PLAN.md#2a-shared-dependency-interface-required-by-p3)) and dependency register (12 §2b, DEP-01); type standard (D-014); replace fixtures and run T-INT-03 in WO-P3-P6-01 stage A, after the contract (P6, D-027) | Deploy errors; FK type mismatch | P3 + Team |
| R-04 | Settlement ownership conflict leads to partial effects or cross-module deadlocks | Effects owned by three members (D-012) | Medium | High | One orchestrator; transaction composition rules; global lock order; contract-only hook test doubles in P3 (T-F05-21/22, DEP-05); real-routine T-INT-01/02 and T-CONC-05 at P6; T-CONC-04 | Inconsistent stock/entitlement/points after failures | Team |
| R-05 | Workload assumptions wrong (Phase 1 numbers are estimates) | No production data | Medium | Medium | Parameterised seed; show sensitivity on DS-M vs DS-L; label numbers as estimates | Results depend strongly on a parameter | P3 |
| R-06 | Unrealistic data skew (uniform data) gives misleading plans | Naive generator | Medium | Medium | Skewed distributions ([10 §3.4](10_SEED_AND_BENCHMARK_PLAN.md#34-distributions-and-parameters-defaults-are-assumption_pending_approval)); T-SEED-03; median and heavy parameter sets | Estimated vs actual rows far apart | P3 |
| R-07 | Benchmark variability (laptop load, power plan, different machines) | Shared personal hardware | High | Medium | Single machine per series; manifest; warm-up; N repetitions; medians and IQR; logical reads as the primary metric; reruns | High IQR; inconsistent reruns | P3 |
| R-08 | Dataset fits in memory, so elapsed gains are small and the ">1 minute" symptom is not reproduced; temptation to overclaim | Phase 1 volume is small | High | Medium | Report logical reads/CPU; honesty rules ([10 §5](10_SEED_AND_BENCHMARK_PLAN.md#5-honesty-rules)); optional DS-XL with approval | Millisecond-level differences only | P3 |
| R-09 | Edition limits ("Standard Developer") remove features (e.g. online index operations, automatic indexed-view matching) | Edition differences | Medium | Medium | Verify features in WO-P3-P0-02; use NOEXPAND or alternatives; document | Feature error or plan not matching | P3 |
| R-10 | Transaction races: double settlement, lost updates on spending/summary, deadlocks with the tier batch | Concurrency | Medium | High | Conditional transition; safe upsert; atomic increments; lock order; chunked batch; T-CONC-01…05 | Reconciliation mismatch; error 1205 frequency | P3 |
| R-11 | Over-indexing / write amplification on INVOICE (shared, 1,800 writes/day) | Too many candidates adopted | Medium | Medium | One-at-a-time evaluation; write-overhead thresholds; workload-weighted check ([08 §6](08_INDEX_AND_QUERY_PLAN.md#6-adoption-and-rejection-criteria)) | Settlement p95 increase | P3 |
| R-12 | Filtered index not used (parameterised status) or DML fails (wrong SET options, e.g. sqlcmd without `-I`) | Filtered-index requirements | Medium | Medium | Literal predicates; documented client SET options; test with the actual application driver | "INSERT failed because of incorrect SET options" error; scan instead of seek | P3 |
| R-13 | Schema migration risk: adding PaidAt or changing keys (partitioning) after others wrote code | Late decisions | Medium | High | Decide D-004/D-017 early; PoC only on a copy; migration ordering ([12 §7](12_INTEGRATION_PLAN.md#7-schema-change-and-migration-ordering)) | Rework requests from other members | P3 + Team |
| R-14 | Insufficient proof of performance (missing plans, mixed changes, unrecorded environment) | Rushed evidence | Medium | High | Evidence conventions; B0–B5 isolation; checklist in [13 §3](13_DELIVERABLES_AND_EVIDENCE.md#3-report-section-checklist-for-dl-15) | Report number without a RUN_ID | P3 |
| R-15 | Tier batch escalates locks and blocks settlements | Large set-based update on MEMBER | Medium | Medium | Chunked updates below the escalation threshold; update only changed rows; off-peak schedule; T-CONC-04 | Blocking seen during the batch | P3 |
| R-16 | Derived data drifts from source (spending, points, summary) | Missed write path, bug, manual edits | Medium | High | All writes through routines; reconciliation tests T-REC-01…04 in regression | Non-zero reconciliation rows | P3 |
| R-17 | No version control, so work is lost or members overwrite each other | Folder not a Git repo (S-12) | Low (cut-over done 2026-11-07: clone authoritative on branch `p3/wo-p3-p1-01`; archive read-only) | High | D-021: single working copy in the clone from WO-P3-P1-01 step 0; old folder kept as a read-only archive; `p3/<wo-id>` branches; PR review | Edits made in the archive after the cut-over; conflicting copies | P3 + Team |
| R-18 | Unknown deadline makes P6/P8 late | G-22 | Medium | High | Get the deadline in WO-P3-P0-01; prioritise P1–P4 evidence; keep WOs small | Days remaining < work remaining | Project Owner |
| R-19 | AI-generated content (S-09, this documentation) is treated as a requirement or a result | Source confusion | Medium | High | Classification labels; precedence; honesty rules; review at each gate | Report cites S-09 as a requirement | P3 |
| R-20 | Secrets leak into the repository (PDF password, DB credentials) | Convenience | Low | High | Never record secrets; Windows authentication or local untracked config; review before any commit | Secret found by a pre-commit check | P3 |
| R-21 | Application stack decided late, so P6 is blocked | D-020 open | Medium | Medium | Keep P3 logic in database routines so any stack can call it | No stack decision by the end of P4 | Team |
| R-22 | Time-zone or boundary errors put revenue/spending in the wrong month | Inconsistent timestamps; UTC storage with local-calendar reporting (D-014, 2026-11-07); other members storing local time | Medium | Medium | Store UTC everywhere; convert local period bounds to UTC parameters; month = local month of PaidAt (D-013); boundary tests T-F05-10, T-F06-04; boundary rows in the seed; UTC rule in the integration contract | Boundary test failure; revenue for 00:00–06:59 local on the 1st in the wrong month | P3 |
| R-23 | An isolated P3 test/benchmark database drifts from the shared schema and becomes an incompatible P3 implementation (D-025 condition 3), TEST_ONLY fixtures grow beyond keys, or an experimental structure leaks into the shared database (condition 6) | Long-lived isolated databases; manual changes | Medium | High | Rebuild isolated databases from the approved shared schema and migrations for every series; schema-conformance check (T-SCH-02, T-INT-03) before tests; promotion to the shared database only through a separately approved WO | Schema differences found by T-INT-03; any P3 object in the shared DB without a promotion record | P3 |
| R-24 | Public repository exposes course-derived content (assignment quotes), team-internal planning and later evidence, or a secret committed by mistake | The canonical repository `Phuoc-IT-2106/CSDLNC-DA` is public (inspected 2026-11-07) | Medium | Medium | Decide visibility before the first push (package §E.4; private with collaborators recommended during the course); secret scan and file allowlist before every commit; no credentials anywhere (R-20) | A push planned while the visibility decision is open; the scan finds a secret | Project Owner + Team |
| R-25 | Scope creep: P3 builds parts of other members' modules (shared tables, check-in, PT, inventory, administration), or TEST_ONLY fixtures are treated as the canonical schema of another module | Missing shared schema; convenience | Medium | High | Owner scope matrix ([WO-P3-P1-01 §3.2](work-orders/WO-P3-P1-01_PHYSICAL_SCHEMA.md#32-scope-matrix-directive-strict-person-3-scope-enforcement)); D-026 restricted conditions; key-only fixtures with a TEST_ONLY marker in a separate test folder; separation check (WO-P3-P1-01 §8.3); allowed and forbidden table lists in every build WO | A migration under `db/` creates a non-P3 table; a fixture gains non-key columns or logic | P3 |
| R-26 | Late integration: the formal contract is deferred to P6 (D-027), so an assumption of the dependency register (12 §2b) proves wrong late, forcing rework of P3 migrations, routines or index decisions, or compressing P6 against an unknown deadline (R-18) | Independent development of the three modules; integration contract deferred | Medium | High | Minimal dependency register reviewed at every gate; Phase 1 names, keys and types only; P3 logic in database routines; contract-only test doubles; incompatibilities recorded as integration risks and escalated immediately if they invalidate or endanger the current implementation; integration rehearsal (WO-P3-P6-01 stage A) before promotion; the 12 §2a interface may be shared informally with the team at any time without blocking P3 | A team schema or routine contradicts a DEP row; rework estimate at P6 exceeds the remaining time | P3 + Project Owner |
| R-27 | **OPEN — performance-measurement blocker only (reclassified 2026-11-09, [§7](#7-disposition-2026-11-09-owner-directive-urgent-unblock--core-implementation)).** It blocks measured-improvement claims, the formal WO-P3-P2-02 timing baselines, performance-based index selection and final partition conclusions. It does **not** block invoice creation, settlement, spending, loyalty, revenue-query correctness, transaction and concurrency tests, or application functions that do not depend on benchmark results. Timings from the failed probes are DIAGNOSTIC_ONLY. The optional final E6 attempt of 2026-11-09 was not performed (preconditions unmet); further investigation is deferred to a separately approved remediation or an alternate environment. **History: E6 failed twice on 2026-11-08 (13:21 and 15:54 UTC; partially mitigated).** The benchmark machine is not yet a stable measurement environment. **Correctness is not affected.** Corrected statement (§6): (1) under procedure A, power, background load, isolation and cache warmth are controlled and the series medians now agree within 2–10% for three of four probes. (2) SQL Server still releases its plan cache and buffer pool on the OS low-memory signal, which recurs about once a minute even with more than 2 GB free. One such signal in the middle of a series invalidated 8 samples and caused an 8.1 s RESOURCE_SEMAPHORE wait. (3) Single executions vary up to about 2× within a clean series (IQR/median 21–40%), consistent with CPU performance-state changes under the Balanced plan | Confirmed: unstable AC connection (Kernel-Power 105 events); background CPU load (installer and update downloads); STATISTICS TIME CPU quantization (measurement; fixed in harness v2); SQL Server cache release on `RESOURCE_MEMPHYSICAL_LOW` without a memory floor (`min server memory` 16 MB). Suspected: CPU frequency variability (`% Processor Performance` 50–144% on AC). Corrected: the cumulative forced-grant and RESOURCE_SEMAPHORE counters since 2026-10-27 do not show that memory pressure caused the 13:21 failure. Not causes: the dataset, disk I/O in warm samples, plan instability. Details: [§6](#6-root-cause-update-and-e6-recheck-2026-11-08-r-27-targeted-remediation-and-recheck), [method review](design/R27_MEASUREMENT_METHOD_REVIEW.md) | High | High | Generation and validation cap memory grants (`MaxGrantPercent`), which changes memory use only, never results (proved by identical checksums under different conditions). **Before any benchmark:** controlled measurement procedure, option A of the assessment: AC power, no sleep during a series, heavy applications closed, environment gate per series, adaptive features controlled. Checklist: [WO-P3-P2-02 §2a](work-orders/WO-P3-P2-02_BASELINE_BENCHMARK.md#2a-benchmark-readiness-checklist-r-27). Options B (memory floor) and C (stop `MSSQLSERVER01`) apply only if A fails, and need the Owner's authorization. **Closure:** test E6 passes (see the assessment). **2026-11-08: A applied, E6 still FAIL → next: B (memory floor) plus D (Windows power mode "Best performance" on AC for the measurement session), both Owner-authorized, then E6 again with the same thresholds ([§6.4](#6-root-cause-update-and-e6-recheck-2026-11-08-r-27-targeted-remediation-and-recheck))** | Available memory < 2,048 MB; `process_physical_memory_low` = 1; semaphore target < 256 MB; any RESOURCE_SEMAPHORE wait or forced grant during a series; any Kernel-Power 42/105/107/506/507 event within 10 min before or during a series; battery status 1; a cached probe plan replaced during a series | Project Owner + P3 |
| R-28 | Approved integration limitations of invoice creation are not honoured by callers at P6: (a) prices reach P3 unvalidated against the catalogue, so a wrong price becomes a wrong invoice, wrong spending and wrong points; (b) a blind retry of creation creates a duplicate PENDING invoice (no request deduplication); (c) a duplicate is settled by mistake | D-028 Q4 (a) and Q5 (a) approved 2026-11-09: caller-supplied prices, no request key, exactly-once creation not claimed | Medium | Medium | Documented as integration requirements DEP-04 and DEP-16 (12 §2b) and in the contract at P6; least-privilege callers (T-F05-26, T-F05-30); P3 still validates monetary consistency and derives totals; duplicates are visible PENDING invoices that can be cancelled (no effect before settlement); settlement is idempotent per Invoice_ID | A caller without catalogue validation; repeated identical PENDING invoices in integration tests | P3 + Team (sale-flow owners) |
| R-29 | A tier batch cancelled by its CLIENT (command timeout / attention) keeps the session-owned application lock `P3_usp_P3_EvaluateTiers` until that connection closes; every other run waits 60 s and fails with 51324 meanwhile | `sp_getapplock @LockOwner = 'Session'` (approved serialisation, WO-P3-P3-02); an attention ends the batch without running the CATCH block, so `sp_releaseapplock` is not reached (the chunk transaction itself is rolled back: XACT_ABORT ON, 0 open transactions observed) | Medium | Low (availability only: no data is written by the waiting or failing runs; tiers remain correct, D-009 accepts lag until the next run) | Scheduler contract (DEP-19): no client command timeout on the batch call, or close/discard the connection after a timeout or cancel (do not return it to a pool); 51324 handled as retryable with back-off. Found and characterised by T-CONC-07 T4 (WO-P3-P3-03, 2026-11-10). A code change (e.g. transaction-owned lock) would conflict with the approved per-chunk commits (D-019 (a)) and needs an Owner decision | Repeated 51324 after a cancelled run; an APPLICATION lock held by an idle session in `sys.dm_tran_locks` | P3 + Team (scheduler owner, P6) |

## R-27 assessment (2026-11-08)

Owner Directive "Accept P2-01 and Resolve R-27" §2 (VERIFY_ONLY then PLAN_ONLY): no software installed, no setting changed, no benchmark run. Evidence: [R-27-DIAG__20261108-1221.txt](evidence/test-results/R-27-DIAG__20261108-1221.txt) (read-only diagnostic, two samples, script text in the appendix); the six WO-P3-P2-01 run logs; [WO-P3-P2-01 §13.1, §13.4, §13.8](work-orders/WO-P3-P2-01_SEED_GENERATOR.md#13-execution-record).

### 1. Observations

| # | Observation | Source |
|---|---|---|
| O1 | 7.9 GB RAM; about 0.8–1.0 GB free; commit 17.7 GB of a 22.9 GB limit; page file 4.3 GB in use (peak 4.9 GB) | R-27-DIAG §D2 |
| O2 | Private memory by process group: VS Code 2.35 GB, Chrome 1.85 GB, Claude 1.74 GB, ChatGPT 1.65 GB, both SQL Server instances 1.12 GB, Zalo 0.89 GB, Defender 0.46 GB | R-27-DIAG §D2 |
| O3 | SQL Server (MSSQLSERVER): `min server memory` 16 MB, `max server memory` unlimited, no locked pages; working set about 150–220 MB; 5.15 million page faults since 2026-10-27; `process_physical_memory_low` = 1 at 12:22 UTC | R-27-DIAG §D3 |
| O4 | Query-memory semaphore (default pool): target **651 MB** of 823 MB, memory state "high", in a sample between about 12:10 and 12:21 UTC. Target **8 MB** of 283 MB at 12:21:59 and again at 12:22:35 UTC. Nothing about SQL Server changed between the samples. The executing session saw 7.68–7.8 MB for most of the day and about 790 MB at 11:59 UTC | R-27-DIAG §D3, §D6; WO-P3-P2-01 §13.1 |
| O5 | Since the instance start: 97 forced grants (a query ran with less memory than it asked for), 37 RESOURCE_SEMAPHORE waits totalling 28,791 s, the longest 25,791 s. The longest wait matches run B's validation step (26,036 s, 04:39–11:53 UTC), which spans the sleep (inference from the timing) | R-27-DIAG §D3; P2-RUN__DS-L__20261108-0408_B |
| O6 | Error log "significant part of SQL Server process memory has been paged out": 24 messages on 2026-11-08, about 1 per day before | R-27-DIAG §D3 |
| O7 | On battery (BatteryStatus 1; 50% → 46% during the assessment); Balanced plan. Sleep and display-off after 240 s on battery and 600 s on AC. S0 Modern Standby (connected standby) | R-27-DIAG §D1 |
| O8 | Power events on 2026-11-08: connected standby 03:46–04:07 UTC (run A validation), 04:08–04:39 UTC (run B generator), sleep 04:39–11:49 UTC (run B validation), connected standby again 12:11–12:14 UTC. Run C (11:55–12:00 UTC) had none | R-27-DIAG §D1 |
| O9 | The same DS-L generation took 52 s (A), 1,143 s (B) and 168 s (C); validation took 1,302 s, 26,036 s and 96 s. The DS-M generation (no power event) took 368 s, against 52 s for four times the data in DS-L A | Run logs, step 5 and step 7 |
| O10 | Despite O4–O9, the DS-L checksums of A, B and C are identical, and every validation run passed | CHECKSUMS files; GATE-P2-01-RECHECK |
| O11 | CPU: i5-1135G7, 4 cores / 8 threads; load 22–46% from other processes when sampled. NVMe SSD; C: 12.6 GB free of 238 GB | R-27-DIAG §D2 |
| O12 | `FitLife_P3_P2`: compatibility 160; Query Store READ_WRITE (AUTO); DOP feedback, CE feedback, row- and batch-mode memory-grant feedback (with persistence and percentile), parameter-sensitive plan optimization and optional-parameter optimization all ON | R-27-DIAG §D4 |
| O13 | Second instance `MSSQLSERVER01`: running, 0 user databases, about 63 MB working set | R-27-DIAG §D5 |

### 2. Assessment

| Question | Answer |
|---|---|
| What makes the machine unsuitable now | The environment is not stationary. The memory SQL Server can grant changes by about 80× within minutes (O4), driven by other applications (O1, O2). Runs are paused or throttled by connected standby and sleep (O7, O8). The resulting timings vary by up to 270× for identical work (O9) |
| Correctness, measurement or both | **Measurement only.** Data, results and checksums are identical across conditions (O10); memory caps change memory use, not results. For benchmarks: elapsed and CPU time are directly affected. Logical reads are stable for a fixed plan, but forced grants can cause spills (extra worktable and tempdb I/O), and adaptive features (O12) can change plans or grants between runs. So even logical reads need E3 and E5 of the checklist |
| Cause by category | **Competing workloads: primary** (O1, O2). **Power management: primary for interruptions** (O7, O8). **SQL Server configuration: amplifier**: no memory floor, so SQL Server yields first (O3). **Methodology: contributing**: no environment gate or per-series wait check; cumulative instance statistics cannot be attributed to one run; adaptive features not controlled (O12). **Hardware: contributing only**: 7.9 GB is enough for a 68 MB dataset once other load is removed, and the 4-core mobile CPU is shared with interactive work (O11). **Dataset: not a cause**. **Second instance: minor** (O13, about 63 MB) |
| Are reliable measurements possible under control | **Likely yes; not yet demonstrated.** With memory freed, the pool reached 650–790 MB (O4), far above what queries over a 68 MB dataset need. Run C, on an awake machine, completed generation and validation in 4.4 min (O9). Stability has not been measured; that is test E6 |

### 3. Remediation options (ranked)

| Rank | Option | Valid, reproducible evidence | Complexity | Time and resource cost | Fit with the current local environment | Authorization needed |
|---|---|---|---|---|---|---|
| **1 (recommended)** | **A. Controlled measurement procedure** on the current machine: AC power; no sleep during a series (harness-held "system required" request, or "sleep: never" on AC for the session); close heavy applications, including other agent sessions, with the driving agent idle during timed series; an environment gate before and after each series (E1–E3); adaptive features controlled (E5); a series is discarded whole and rerun if the gate fails | Good, provided E6 passes. All configurations still run on the same machine (R-07) | Low: procedure plus a few gate queries in the harness | Minutes per session | Full: no change to SQL Server or Windows | None for the procedure itself. "Sleep: never" is a system setting (Owner). E5 needs WO-P3-P2-02's approval |
| 2 | **A + B. Memory floor** for MSSQLSERVER (for example `min server memory` 1,024 MB and `max server memory` 3,072 MB) | Better: SQL Server stops releasing memory below the floor. Windows can still page it out without locked pages | Low; reversible with `sp_configure` | Minutes | Instance-wide setting; other local databases on the instance are idle | Owner (server configuration) |
| 3 | **A + C. Stop `MSSQLSERVER01`** during measurement sessions | Small gain (about 60–430 MB) | Trivial; reversible | Minutes | No user databases on it | Owner (service change) |
| 4 | **D. Locked pages in memory or High performance plan** | Better again against paging; power plan affects CPU frequency | Medium: Windows policy or user right, restart of SQL Server | Hours | Changes system policy | Owner (system settings) |
| 5 | **E. Another machine** with ≥ 16 GB RAM, on AC, dedicated during runs | Best isolation | Medium: install SQL Server 2025, regenerate DS-M and DS-L and prove the same checksums | Hours to a day | Every configuration must then be measured there; no mixing with this laptop (R-07) | Owner (new environment; D-025 target) |

**Smallest correct remediation: option A.** Use B or C only if E6 fails under A, and D or E only if B and C also fail. Option A needs no software and no setting change: the sleep request is held by the harness process and ends with it.

### 4. Closure test for R-27 (E6)

Run under an approved WO: WO-P3-P0-02, which is VERIFY_ONLY and environment-focused, or the first step of WO-P3-P2-02. Record it in `evidence/test-results/R-27-CLOSE__<ts>.txt` together with an R-27-DIAG snapshot before and after.

1. **Gate (E1–E3) at the start and end of each series:**
   - AC power; no Kernel-Power 42/506 or Power-Troubleshooter 1 event in the window.
   - Available memory ≥ 2,048 MB; `process_physical_memory_low` = 0; semaphore target ≥ 256 MB.
   - RESOURCE_SEMAPHORE session waits = 0; `forced_grant_count` unchanged; no spill or grant warning in the actual plans.
2. **Stability:**
   - Probe: three fixed read-only probe queries on DS-L (a primary-key lookup on INVOICE, a full-scan monthly aggregate of INVOICE, an INVOICE ⋈ INVOICE_PRODUCT_ITEM aggregate). These are not the frozen baseline queries.
   - Two series, ≥ 10 minutes apart, each a warm-up plus N = 15 runs.
   - Pass when: logical reads are identical in every run; median CPU and median elapsed differ by ≤ 10% between the series; IQR/median ≤ 20% per query.
3. **Pass:** R-27 is set to CLOSED with a reference to the file. **Fail:** apply the next option of §3 and repeat.

The thresholds are proposed and are confirmed in the approving WO.

### 5. E6 runs (test results only; recorded under VERIFY_ONLY)

| Run (UTC) | Authority | Result | Evidence |
|---|---|---|---|
| 2026-11-08 13:21–13:32 | Owner Directive "R-27 Remediation & Person 3 Progress Review" §4 (diagnostic, SELECT-only probe). Conditions: AC requested; five heavy applications stopped at the Owner's request | **FAIL** — R-27 stays **OPEN**. G-E3 PASS: 0 RESOURCE_SEMAPHORE waits, 0 forced grants, no spill or grant warnings; query-memory pool 1.1–1.7 GB. C-LR PASS for all 4 probe queries. G-E1 FAIL: AC lost during S1; five Kernel-Power 105 events between 13:20 and 13:24. G-E2 FAIL: 1,754–1,784 MB available in S1. Timing FAIL for P2–P4: S1 2–3× slower than S2 (P3 elapsed median 344 vs 133 ms). Within-series IQR/median up to 65% | [R-27-PROBE__20261108-1321.txt](evidence/test-results/R-27-PROBE__20261108-1321.txt) (+ `__raw_S1/S2.txt`, `__P1…P4.sqlplan`, `__supplement.txt`); [before](evidence/test-results/R-27-DIAG__20261108-1321_before.txt) / [after](evidence/test-results/R-27-DIAG__20261108-1321_after.txt) snapshots |

| 2026-11-08 15:44 | Owner Directive "R-27 Targeted Remediation and Recheck" §6 (VERIFY_ONLY), harness v2 | **NOT RUN, aborted by the precheck before any series** (by design): connected standby 15:40:52–15:43:40 UTC; 1,128 MB available | [R-27-CLOSE__20261108-1544__precheck.txt](evidence/test-results/R-27-CLOSE__20261108-1544__precheck.txt) |
| 2026-11-08 15:54–16:06 | Same directive, harness v2 ([review](design/R27_MEASUREMENT_METHOD_REVIEW.md); timing from validated DMV deltas; P1 in batches of 200). Conditions: charger secured; Chrome, Edge and the Visual Studio Installer download ended by the agent at the Owner's request (15:47 UTC); a keep-awake helper held the system awake from 15:46 and started the run after 10.7 min without any power event and with ≥ 2,100 MB free; peer agent sessions idle | **FAIL** — R-27 stays **OPEN**. PASS: precheck (5/5), dataset checksum before and after (identical to run C), G-E1 (0 power events), G-E2, G-ISO, G-WARM, C-LR (4/4), C-PLAN (4/4: plan hash = reference, DOP and grant stable). FAIL: G-E3 (one RESOURCE_SEMAPHORE wait of 8,098 ms in S1); C-ID (8 of 120 samples invalid: all four probe plans and the cached data released at about 15:55:53 UTC in the middle of S1, one low-memory notification in S1); C-IQR for all four probes (21.3–40.2%); C-CPU/C-EL for P3 (13.5%). Median differences S1 vs S2: P1 1.9%, P2 9.5%, P3 13.5%, P4 6.2% (CPU) / 5.7% (elapsed) | [R-27-CLOSE__20261108-1554.txt](evidence/test-results/R-27-CLOSE__20261108-1554.txt) (+ `__raw_S1/S2.txt`, `__P1…P4.sqlplan`, `__checksum_before/after.txt`, `__precheck.txt`); [before](evidence/test-results/R-27-DIAG__20261108-1554_before.txt) / [after](evidence/test-results/R-27-DIAG__20261108-1554_after.txt); calibration [R-27-CALIB__20261108-1458.txt](evidence/test-results/R-27-CALIB__20261108-1458.txt); harness diff [R-27-HARNESS-DIFF__20261108-1532.txt](evidence/test-results/R-27-HARNESS-DIFF__20261108-1532.txt) |

### 6. Root-cause update and E6 recheck (2026-11-08, "R-27 Targeted Remediation and Recheck")

This section replaces the pending interpretation of the 13:21 session handoff (items 7(a)–(c)). The full analysis is in [design/R27_MEASUREMENT_METHOD_REVIEW.md §2](design/R27_MEASUREMENT_METHOD_REVIEW.md#2-root-cause-re-analysis-confirmed-versus-suspected).

#### 6.1 Confirmed causes

| Cause | Evidence | Status after the 15:54 run |
|---|---|---|
| Unstable AC connection (power-source changes, connected standby) | Kernel-Power 105 at 13:20–13:24 (S1 began in the same second as one), 14:41, 14:49; standby 14:05–14:41, 15:40–15:43 | **Controlled** under procedure A with a firmly connected charger and a keep-awake helper: 0 events from 15:44:25 to 16:06 |
| Background CPU load (VS Installer downloads, Windows servicing, browsers) | 40% / 26% load at the 13:21 S1 gates | **Controlled**: 1–12% at the 15:54 gates |
| STATISTICS TIME CPU quantization (about 15.6 ms) | 13:21 supplement S2; calibration C2 | **Fixed** in harness v2 (DMV µs deltas, validated) |
| SQL Server releases its plan cache, buffer pool and query memory on the OS low-memory signal (no memory floor) | Notifications about once a minute from 13:37 to 16:06, even with 2.2–2.8 GB available. All probe plans released at 14:53 and between 14:55 and 14:58. In the 15:54 run, everything released mid-S1, with an 8.1 s grant wait | **Not controlled.** Cause of the C-ID and G-E3 failures. The gate "≥ 2,048 MB available" does not prevent it |

#### 6.2 Suspected cause

Within-series dispersion of 21–40% (IQR/median) even in the clean S2 of the 15:54 run: no notification, no physical read, a stable plan, 1–4% background CPU.
- Single executions vary about 2× (P2 21.5–44.1 ms).
- P1 batch means, each over 200 executions, still vary 72–191 µs. So the variation persists longer than a batch, which points to a machine state rather than measurement noise.
- `% Processor Performance` at the gates ranged 49.6–124.7% within a minute.

Consistent with CPU performance-state (frequency) changes under the Balanced plan; **not proven** because frequency is sampled only at the gates.

#### 6.3 Corrections to earlier statements

- "Memory pressure is the primary cause" (assessment §2) and "memory pressure confirmed, mitigated under procedure A" (13:21 handoff 7(a)) are both replaced. Grant pressure did not cause the 13:21 failure: 0 waits, 0 forced grants. The forced-grant and RESOURCE_SEMAPHORE totals are cumulative since 2026-10-27 and include a 7 h sleep. Memory is confirmed instead as a **cache-release mechanism**, which did cause invalid samples and one grant wait at 15:54.
- The 13:21 G-E2 failure (1,754–1,784 MB) was a threshold failure, not evidence of pressure on measured runs.

#### 6.4 Smallest next corrective actions (Owner authorization; nothing changed in this session)

1. **Option B, memory floor** on `MSSQLSERVER`: for example `min server memory` 1,024 MB and `max server memory` 3,072 MB. Instance-wide and reversible with `sp_configure`. It targets the confirmed cache-release cause.
2. **Option D (partial), Windows power mode "Best performance" on AC for the measurement session** (power slider; reversible). It targets the suspected frequency cause.
3. Keep procedure A as executed at 15:54: charger secured, browsers and installers closed, keep-awake helper, 10 clean minutes. Then repeat E6 with harness v2 and the same thresholds.

If B + D still fail C-IQR, option E (another machine) or an Owner decision on the statistical design (made before the next run, not after) is the remaining path.

### 7. Disposition 2026-11-09 (Owner Directive "Urgent Unblock & Core Implementation")

#### 7.1 Scope of the blocker (directive §3)

| R-27 blocks | R-27 does not block |
|---|---|
| Claims of measured performance improvement | Invoice creation (WO-P3-P3-00), settlement (WO-P3-P3-01) |
| Final acceptance of formal WO-P3-P2-02 timing baselines | Monthly spending and loyalty processing (WO-P3-P3-01/-02) |
| Performance-based index selection (WO-P3-P4-01 adoption decisions) | Revenue-query correctness (T-F06 tests) |
| Final partition performance conclusions (WO-P3-P5-01) | Transaction, rollback and concurrency tests |
| Write-cost baselines used for index decisions (WO-P3-P3-00 criterion 5) | Application functions that do not depend on benchmark results |

R-27 stays **OPEN**. It is not closed without a passing E6 under unchanged thresholds.

#### 7.2 Optional final E6 attempt: not performed

The directive allowed at most one more attempt, under the existing harness and thresholds, with no change to schema, data, indexes or SQL Server configuration, and only on stable AC power without substantial interfering activity. The read-only precheck ([R-27-DIAG__20261109-0800_e6-precheck.txt](evidence/test-results/R-27-DIAG__20261109-0800_e6-precheck.txt), existing script `tests/db/diagnostics/r27_diag.ps1`) found: on battery (BatteryStatus 1, 65%), power-source changes at 07:24 and 07:39 UTC, 566 MB free physical memory (gate E2: ≥ 2,048 MB), browser (27 processes, 2.8 GB private), chat client and editor running, CPU load 37%. A later read-only look (08:32 UTC) showed AC restored at 08:21:55 with a one-second sleep and resume at 08:21:59–08:22:00, but still about 0.6 GB free with the same applications open. Closing the Owner's applications is not authorized, and the confirmed cause (cache release without a memory floor, §6.1) cannot be controlled without an instance-level change, which the directive does not authorize. An attempt would have repeated the failure conditions of 15:54 on 2026-11-08, so it was **not performed**; the single permitted attempt is unused. No setting, schema, data, index or cache was changed.

#### 7.3 Classification of existing results

| Item | Classification |
|---|---|
| CPU and elapsed times of R-27-PROBE (13:21), R-27-CALIB (14:58) and R-27-CLOSE (15:54), 2026-11-08 | **DIAGNOSTIC_ONLY.** No baseline and no improvement claim may cite them |
| Probe query definitions, actual plans (`.sqlplan`), logical reads (P1 8, P2 3,281, P3 3,281, P4 7,245; identical in every valid sample), row counts, DS-L dataset checksum (`26ABB277…CA1F`), index inventory (clustered PKs only, B0), SQL Server configuration | Valid inputs for query analysis. They are not a formal baseline until WO-P3-P2-02 is approved and run |
| Timestamps and durations in the WO-P3-P3-00 functional and concurrency evidence | Context only, not measurements |

No performance-oriented index is introduced before a comparison baseline exists (directive §5).

#### 7.4 Path to closure (each needs a separate approval; not started)

1. **Alternate benchmark environment** (recommended): a machine or VM with fixed memory, on mains power, used only for the measurement session, built from the same scripts and checked with the DS-L checksum. Thresholds unchanged.
2. **Separately approved configuration change** on this instance for one measurement session: memory floor (option B, §6.4 item 1) and "Best performance" power mode (§6.4 item 2), with the Owner's applications closed. The memory values are proposals, not verified optimal settings, and they affect the other databases of the instance.
3. Any change to the method or thresholds is approved before the affected measurements and never converts earlier failures into passes.

Further R-27 investigation is deferred in the current implementation sequence.

## 8. Update 2026-11-09 (Owner Directive "Close Invoice Creation and Prioritize Settlement")

| Risk | Change |
|---|---|
| R-27 | **Unchanged: OPEN, performance-measurement blocker only.** No E6 run, no diagnostic, no change to SQL Server memory or Windows power settings in this session (directive §8). The invoice-creation cost baseline (former WO-P3-P3-00 criterion 5) now waits in WO-P3-P3-03 (task 3a, criterion 5) together with the U0/U1 benchmark; no timing was reported as evidence |
| R-10 | Mitigation now has runtime evidence in isolation (WO-P3-P3-01, run `UC05S-RUN__20261109-1447`): T-CONC-01 (10 settlers on one invoice, incl. a settle-vs-cancel race) and T-CONC-02 (concurrent first insert and updates of one member-month row), 3 runs each, final state checked: one winner per invoice, no lost spending or points, no PK violation, 0 deadlocks. Still open: T-CONC-04 (tier batch, WO-P3-P3-03) and T-CONC-05 (real inventory routine, P6) |
| R-16 | All settlement writes go through `usp_P3_SettleInvoice`; V-UC05S reconciles spending (independent month oracle), PointsEarned and CurrentPoints after every stage (0 mismatches). Direct writes are denied to an EXECUTE-only caller (T-F05-30) |
| R-28 | Added (approved limitations of D-028 Q4/Q5 at integration) |

## 9. Update 2026-11-09 (Owner Directive "Finalize UC05 Settlement and Implement Loyalty")

| Risk | Change |
|---|---|
| R-27 | **Unchanged: OPEN**, measurement only. Not investigated; no instance or Windows setting changed. Task 0 of WO-P3-P3-02 recorded plans and logical reads only (no timing). Timings of Q-UC05-B/C, the tier batch, U0 vs U1 and invoice creation remain in WO-P3-P3-03 |
| R-10 | Further runtime evidence: T-CONC-04F A/B/C (settlement concurrent with the tier batch): no lost spending or points, no incorrect tier change, 0 deadlocks. A race between two overlapping batch runs (older snapshot overwriting a newer result) was found in development and removed by run serialisation (application lock) |
| R-15 | Mitigated as designed: chunks of ≤ 4,500 members in short transactions; on DS-L (30,000 members) no blocking or error observed in the functional runs (not a measurement) |
| R-16 | Reconciliation now also covers tiers: T-REC-04 compares Tier_ID with an oracle computed from INVOICE (fixtures ×4, DS-L ×2: 0 mismatches); V003 enforces the per-row point rule |
| R-28 | Extended: the D-008 **threshold values** are not approved; production tier assignment needs them (DEP-20). Synthetic values exist only in TEST_ONLY fixtures and runner parameters |

## 10. Update 2026-11-10 (Owner Directive "Accept UC06 Functional Results & Execute Integrated Correctness Verification")

| Risk | Change |
|---|---|
| R-27 | **Unchanged: OPEN**, measurement only. Not investigated; no instance or Windows setting changed. WO-P3-P3-03 Part P (U0/U1, creation-cost baseline, T-PERF-01/02/08) and the T-CONC-04 blocking-duration element stay blocked |
| R-10 | Runtime evidence completed for the P3 scope (WO-P3-P3-03 Part C): T-CONC-01 and T-CONC-02 A/B/C again on the final routines, T-CONC-04F A/B/C, T-CONC-04R (reports vs settlement) and T-CONC-07 (batch vs batch); 0 deadlocks, final state reconciled. T-CONC-03 not applicable (no summary), T-CONC-05 at P6 |
| R-15 | No blocking incident in any run; the batch and the reports serialise only where designed (row/key locks, application lock). Blocking durations are not measured (R-27) |
| R-16 | Integrated workflow T-WF-01 and T-REC-01/02/04/05 after every concurrency stage: 0 mismatches |
| R-29 | **Added**: client-cancelled tier batch keeps the session-owned application lock until its connection closes (T-CONC-07 T4; data unaffected) |
| Engine note | `sys.dm_sql_referenced_entities` returned a corrupted column name once more (T-SCH-05 K3 in run `P3-03-RUN__20261110-0724`; earlier: UC06-RUN 0153). Same check PASS in the dry run and in the following run; P3 routines unchanged (K6). Treated as an instance-level fault of SQL Server 17.0.1000.7 RTM affecting that DMV, not a P3 defect; failed evidence retained |

## 11. Update 2026-11-10 (Owner Directive "Accept P3 Correctness & Unblock Performance" (Claude Code session of 2026-11-10))

| Risk | Change |
|---|---|
| R-27 | **Unchanged: OPEN.** Read-only inventory: no separate machine available; a second, empty instance `MSSQLSERVER01` (same build/edition) exists on the laptop. Recommended benchmark environment BM-1 = that instance plus the remediation and authorizations of [design/BENCHMARK_ENVIRONMENT_READINESS.md](design/BENCHMARK_ENVIRONMENT_READINESS.md); closure still requires E6 PASS with unchanged thresholds. Nothing changed |
| R-29 | Assessed in detail below; status OPEN, severity unchanged (availability only) |

### 11.1 R-29 assessment — interrupted tier batch keeps its application lock

Evidence: T-CONC-07 T4 in runs `P3-03-RUN__20261110-0724`, `-0728`, `-0737` (identical observation) and T3 (server-side error path).

| Aspect | Finding |
|---|---|
| Cancellation behaviour | A client command timeout or cancel sends an attention: the batch stops at once and the procedure's CATCH block does **not** run. With `XACT_ABORT ON` the open chunk transaction is rolled back (T4: 0 open transactions); chunks committed earlier stay committed and are correct for that `@AsOfDate` (as for any failed run, T-F05-34). A **server-side** error (e.g. 1222, T3) does run the CATCH block: lock released, transaction rolled back |
| Lock ownership and lifetime | `sp_getapplock @LockOwner = 'Session'`: owned by the session, independent of transactions; released only by `sp_releaseapplock` or when the session ends (connection closed or killed) |
| Effect | While the cancelled session stays open, every other run waits 60 s and fails with 51324, writing nothing; no wrong tier, spending or points (T2, T4) |
| Expected connection cleanup | Closing the connection (no pooling) ends the session and releases the lock (T4: holders empty, probe acquires). **Not yet tested:** pooled connections — a pooled connection is not closed on the server when the client returns it, so the lock is expected to persist until the pool reuses or drops the physical connection; release by the pool's reset on reuse is **unverified** |
| Caller responsibilities (DEP-19) | No client command timeout on the batch call (or a timeout well above the longest expected run); after any timeout or cancel, discard the connection (close it, and clear its pool if pooling is used) rather than return it; treat 51324 as retryable with back-off; the next daily run catches up (D-009 lag accepted) |
| Recovery procedure | 1. Find the holder: `SELECT request_session_id, request_status FROM sys.dm_tran_locks WHERE resource_type = 'APPLICATION' AND resource_description LIKE '%P3_usp_P3_EvaluateTiers%';` 2. Check it is idle (`sys.dm_exec_sessions`: status sleeping, `open_transaction_count = 0`, no request in `sys.dm_exec_requests`). 3. Ask the owning application to close it; only an authorized operator may end it with `KILL <session_id>`. 4. Re-run `usp_P3_EvaluateTiers` for the intended date (idempotent). 5. Verify with T-REC-04 (tiers = oracle) |
| Tests required before integration (P6, WO-P3-P6-01) | (1) T4 against the real scheduler (Agent job stop/timeout or the application job); (2) pooled-connection variant: timeout, return to pool, then reuse and pool clear — observe lock release; (3) recovery drill with `KILL` and re-run, tiers = oracle; (4) caller retry of 51324 with back-off; (5) T-CONC-04F/T-CONC-07 T1–T3 regression with the real hooks |
| Code change | None. A transaction-owned lock conflicts with the approved per-chunk commits (D-019 (a)); a change needs a separately authorized WO and an Owner decision. The procedure comment "released on every path" is inaccurate for client cancellation; correcting it changes the module definition and is left to that WO |

## 12. BM-1 recovery and R-27 disposition - 2026-11-11

- **R-27 remains OPEN**, measurement-only. WO-P3-P0-02 **BLOCKED**: approved preparation completed, E6 **NOT_RUN** because the physical-memory precondition failed (observed 722-1144 MB; required >= 2,048 MB). R-27 **OPEN**. No benchmark failure or performance claim. Memory settings restored to their recorded original configuration; temporary power mode was not applied. P2-02 remains not authorized.
- Standing-condition evidence: [ENV-P0__20261111-015319_ControlledSession.txt](evidence/test-results/ENV-P0__20261111-015319_ControlledSession.txt); memory 722-1144 MB, final 1057 MB. No timed series, so no inference of per-series E3, timing variability or plan stability. No extra diagnostic campaign started.
- **R-09 characterized:** filtered indexes/partitioning/indexed-view creation work; no automatic view matching observed, NOEXPAND works; ONLINE refused Msg 1712. Without sqlcmd -I DML refused Msg 1934. These are verified capability results, not unexecuted tests. Existing R-09 remains open for feature planning/integration.
- Approved A3 had been applied on named instance only; cleanup restored actual original configured min 0 / max 2147483647 (in-use minimum 16). Default instance protected. Power overlay never changed.
- Full matrix, canonical fingerprints, safety and next approval boundary: [ENVIRONMENT_P0](design/ENVIRONMENT_P0.md). No threshold weakened; next new machine/configuration/statistical design needs Owner approval before an experiment.
