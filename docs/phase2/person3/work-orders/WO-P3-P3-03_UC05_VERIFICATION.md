# WO-P3-P3-03 — UC05 Verification and U0 vs U1 Benchmark

| Field | Value |
|---|---|
| Status | **Part C (correctness, consistency, concurrency, rollback): PASSED** (2026-11-10, Project Owner; conditional acceptance re-checked read-only, [§14](#14-owner-acceptance-of-part-c-2026-11-10)); VERIFIED since run `P3-03-RUN__20261110-0737`, 100/100 steps PASS (§13). **Part P (performance): PENDING — not approved, BLOCKED** by R-27 and WO-P3-P2-02. **Whole WO: IN_PROGRESS** (not VERIFIED, not PASSED); GATE-P3 open |
| Phase | P3 — Billing, Settlement and Loyalty Implementation |
| Mode | BUILD_AUTHORIZED (test harness only) + VERIFY_ONLY (tests and benchmarks) |
| Approver | Project Owner |
| Approval record | **Part C only: APPROVED 2026-11-10, BUILD_AUTHORIZED** (test harness and tests; production routines only for a demonstrated defect), by the Owner Directive "Accept UC06 Functional Results & Execute Integrated Correctness Verification" (Claude Code session of 2026-11-10) §3, with the limited-scope amendment of [§2a](#2a-limited-scope-amendment-2026-11-10). Part P: no approval. No commit, push or merge authorized |
| Target database | **Part C:** `FitLife_P3_UC05` only (disposable WO-P3-P3-00 marker; rebuilt from scripts three times per run after the S0 safety check). `FitLife_P3_P1`, `FitLife_P3_P2`, `FitLife_P3_UC05L` read only (fingerprint and DS-L checksums unchanged). **Part P:** isolated benchmark databases per D-025, to be named when Part P is approved |
| Revision | 2026-11-08 (Owner Directive "Reprioritize Person 3 Implementation" (2026-11-08, D-027)): T-CONC-05 (real inventory routine, UC04 owner) moved to WO-P3-P6-01; T-CONC-06 (concurrent invoice creation) added. 2026-11-09 (Owner Directive "Urgent Unblock & Core Implementation"): T-CONC-06 was run 3 times under WO-P3-P3-00 (PASS; harness `tests/db/concurrency/T-CONC-06_parallel_creation.ps1`, reusable for T-CONC-01…04); here it is re-run on the final UC05 routines. Concurrency and rollback tests do not depend on R-27; the U0/U1 benchmark (tasks 3–4) does, and stays blocked until R-27 is closed. **2026-11-09 (Owner Directive "Close Invoice Creation and Prioritize Settlement" §3): task 3a and acceptance criterion 5 added — the invoice-creation cost baseline transferred from WO-P3-P3-00 criterion 5 (formal scope amendment, [WO-P3-P3-00 §7a](WO-P3-P3-00_INVOICE_CREATION.md#7a-scope-amendment-of-2026-11-09-criterion-5)); it needs R-27 closed. The concurrency harness now exists for T-CONC-01/02 too (`tests/db/concurrency/T-CONC-01_02_parallel_settlement.ps1`, WO-P3-P3-01, 3 runs each PASS); here they are re-run on the final UC05 routines** |

## 1. Objective

Prove UC05 correctness under concurrency and failure. Measure the Problem 4 improvement (U0 vs U1) and the cost of the tier batch and the loyalty lookup.

## 2. Preconditions

WO-P3-P3-02 PASSED; the harness from WO-P3-P2-02 available.

## 2a. Limited-scope amendment (2026-11-10)

Authority: Owner Directive "Accept UC06 Functional Results & Execute Integrated Correctness Verification" (Claude Code session of 2026-11-10) §3: BUILD_AUTHORIZED execution **only for the separable correctness, consistency and concurrency scope**; "if the Work Order is primarily a performance Work Order, record an explicit limited-scope amendment before execution". This WO combines both, so it is split. **No task, test or acceptance criterion is removed or weakened**; each is assigned to exactly one part, and the cross-cutting criterion 4 applies to both.

| Part | Tasks (§4) | Acceptance criteria (§7) and verification (§8) | Status |
|---|---|---|---|
| **C — correctness, consistency, concurrency, rollback** | 1 (concurrency harness); 2 (T-CONC-01…T-CONC-04, T-CONC-06; T-CONC-03 only if a summary exists; T-CONC-05 `NOT_RUN`, P6); 5 (reconciliation T-REC-01/02/04 after the concurrency runs, plus T-REC-05); 6 for the Part C results (documentation, 16, SESSION_LOG) | Criterion 1, **except** the "blocking duration recorded" element of the T-CONC-04 expected result ([11 §2.5](../11_TEST_AND_QA_PLAN.md#25-concurrency-wo-p3-p3-03)), which is a timing and moves to Part P; criterion 4 for the results reported here; §8 "repeat T-CONC-01 at least 3 times" | **APPROVED 2026-11-10, BUILD_AUTHORIZED** (test harness and tests only; no production routine change unless a defect is demonstrated, directive §8) |
| **P — performance measurement** | 3 (U0/B0, U0/IX-03, U1 settlement benchmark, K = 1,000, T-PERF-02), 3a (invoice-creation cost baseline), 4 (T-PERF-01, T-PERF-08, IX-07 per 08 §5); 6 for the measured summary tables | Criteria 2, 3, 5; criterion 4 for every measured number; the T-CONC-04 blocking-duration element; §8 T-REPRO-03 | **PENDING — not approved, BLOCKED** by R-27 (OPEN) and WO-P3-P2-02 (formal B0 harness and baseline). Every obligation is unchanged |

Also verified under Part C, at the Owner's request (directive §4–§6), **without** adding acceptance criteria: the integrated workflow (T-WF-01), the report half of T-CONC-04 including a caller-chosen SERIALIZABLE multi-statement case (T-CONC-04R), tier batch vs tier batch (T-CONC-07), and the existing rollback suites re-run on the final routines (T-F05-04/-19/-25, T-F05-08/-22/-29, T-F05-34). T-CONC-04 is evidenced by T-CONC-04F (settlement vs tier batch) together with T-CONC-04R (settlement vs reports).

Conditions: target `FitLife_P3_UC05` only (disposable marker and safety check before every rebuild, directive §7); `FitLife_P3_P1`, `FitLife_P3_P2`, `FitLife_P3_UC05L` read only; no index, partition, summary, isolation or instance setting; no timing is reported as evidence; TEST_ONLY synthetic tier thresholds only. Part C may be reported `VERIFIED` on its own; **the whole WO stays `IN_PROGRESS` until Part P is approved, executed and verified**, and GATE-P3 stays open.

## 3. Inputs

[06 §4.9, §5](../06_UC05_BILLING_LOYALTY_PLAN.md#5-baseline-vs-optimised-evaluation); [10 §4](../10_SEED_AND_BENCHMARK_PLAN.md#4-benchmark-methodology); [11 §2.5](../11_TEST_AND_QA_PLAN.md#25-concurrency-wo-p3-p3-03).

## 4. Tasks

1. Build the PowerShell concurrency harness ([11 §1](../11_TEST_AND_QA_PLAN.md#1-test-approach)).
2. Run T-CONC-01…T-CONC-04 and T-CONC-06 (T-CONC-03 only if a summary exists). T-CONC-05 needs the real inventory routine and runs in WO-P3-P6-01 (`NOT_RUN` here, with that reason).
3. Benchmark settlement U0/B0, U0/IX-03, U1 (and U1 + D-009 b if implemented) on DS-M and DS-L: K = 1,000 settlements, per-call metrics (T-PERF-02). Restore the snapshot between configurations.
3a. _(Transferred from WO-P3-P3-00 task 5 on 2026-11-09.)_ Measure the invoice-creation cost (`usp_P3_CreateInvoice`, insert path) on DS-L in the B0 configuration with the protocol of [10 §4.5](../10_SEED_AND_BENCHMARK_PLAN.md#45-write-overhead-measurement), as the write baseline for later index decisions. Capture it **before any P4 index is adopted** (R-11). Needs R-27 closed; diagnostic timings are not acceptable evidence.
4. Measure Q-UC05-A vs the bounded spending-table read (T-PERF-01), and Q-UC05-B and Q-UC05-C (T-PERF-08). Evaluate IX-07 with the protocol of [08 §5](../08_INDEX_AND_QUERY_PLAN.md#5-evaluation-protocol-per-candidate).
5. Re-run reconciliation (T-REC-01/02/04) after the concurrency runs.
6. Write summary tables (from measured runs only) and update [16](../16_READINESS_REPORT.md) and [SESSION_LOG.md](../SESSION_LOG.md).

## 5. Out of scope

New routines or business rules; UC06 work; concurrency, rollback or benchmark runs outside isolated databases (D-025 condition 4).

## 6. Deliverables and locations

DL-09: harness in `tests/db/concurrency/`; outputs in `evidence/test-results/`; RUN_IDs in `evidence/benchmark-results/`.

## 7. Acceptance criteria

1. T-CONC-01…04 and T-CONC-06 (in scope) pass; reconciliation is zero-mismatch afterwards.
2. T-PERF-01, T-PERF-02, T-PERF-08 evidence complete per protocol (manifest, CSV, plans).
3. The IX-07 decision recorded against [08 §6](../08_INDEX_AND_QUERY_PLAN.md#6-adoption-and-rejection-criteria).
4. Every reported number cites a RUN_ID.
5. _(Transferred from WO-P3-P3-00 criterion 5 on 2026-11-09, original wording kept.)_ "The creation-cost baseline has a RUN_ID." (task 3a). Open; it is not met by any existing evidence.

## 8. Verification

Repeat T-CONC-01 at least 3 times (race tests are probabilistic). Re-run one benchmark configuration on another day (T-REPRO-03).

## 9. Evidence

Concurrency logs, benchmark RUN_ID folders, plans, screenshots.

## 10. Dependencies and risks

R-07, R-10, R-15.

## 11. Approval requirements

WO approval; separate authorization for commits.

## 12. Exit and next step

GATE-P3. Next: WO-P3-P4-01 (if not already running), then P5; integration at P6.

## 13. Execution record

### 13.1 Authority, scope and safety (2026-11-10)

Part C executed under BUILD_AUTHORIZED (§2a). Preconditions: WO-P3-P3-02 `PASSED` (2026-11-10); the concurrency harnesses of WO-P3-P3-00/01/02 exist; the "harness from WO-P3-P2-02" precondition concerns the benchmark harness and applies to Part P only. Before every rebuild the runner checked (step S0): SQL Server 17.0.1000.7 Standard Developer; `FitLife_P3_UC05` carries the WO-P3-P3-00 disposable marker, holds no protected dataset (157 invoices), has no other session and no open transaction; `FitLife_P3_P1`, `FitLife_P3_P2`, `FitLife_P3_UC05L` present. RCSI and snapshot isolation OFF and unchanged. No production routine, table, index, setting or other database was changed.

### 13.2 Implementation (test harness only)

| File (new) | Purpose |
|---|---|
| `tests/db/functional/run_p3_03_verification.ps1` | Runner: S0 safety; stage A (creation regression incl. rollback); stage C (UC05 regression and the isolated concurrency suites, 3 runs of T-CONC-01/02/04F); stage W (integrated workflow and cross-operation concurrency); reconciliation after each concurrency stage; fingerprint and DS-L checksums |
| `tests/db/functional/T-WF-01_uc05_uc06_workflow.sql` | Integrated workflow creation → settlement → spending → points → tier → revenue, checks W1–W11 on the final database state ([11 §2.5a](../11_TEST_AND_QA_PLAN.md#25a-integrated-workflow-wo-p3-p3-03-part-c)) |
| `tests/db/concurrency/T-CONC-04R_reports_vs_settlement.ps1` | Report half of T-CONC-04: R1 deterministic no-dirty-read per routine (rollback/commit), R2 load with rolled-back x.01 VND settlements, R3 caller-chosen SERIALIZABLE multi-statement |
| `tests/db/concurrency/T-CONC-07_tier_batch_serialisation.ps1` | Tier batch vs tier batch: T1 deterministic stale-overwrite scenario, T2 51324 timeout, T3 failure inside a chunk, T4 client timeout (characterisation) |
| `tests/db/concurrency/T-CONC-08_settle_vs_cancel_ordered.ps1` | Settlement vs cancellation of one invoice with both winners forced (the random race of T-CONC-01 is usually won by settlement) |

Existing suites re-run unchanged (hashes in the run log): T-F05, T-F05S, T-F05-U0, T-F05L, T-CONC-01/02, T-CONC-04F, T-CONC-06, V-UC06R, T-REC_loyalty, T-REC_revenue, T-SCH-01…06.

### 13.3 Acceptance evidence (Part C)

Final run: [P3-03-RUN__20261110-0737](../evidence/test-results/P3-03-RUN__20261110-0737.txt) — **100 steps, 0 FAIL**. All test files of timestamp `20261110-0737` in `evidence/test-results/`.

| Criterion | Test ID | Actual result | Evidence | Status |
|---|---|---|---|---|
| 1 | T-CONC-01 ×3 (A/B/C; §8 "at least 3 times") | 10 sessions per invoice, 20 invoices per run: 200/200 allowed results, exactly one winner, one hook pair per PAID invoice, spending/points once; race outcomes PAID 19 + CANCELLED 1 (A), 19 + 1 (B), 20 + 0 (C); 0 deadlocks | `T-CONC-01__20261110-0737_A/_B/_C` | PASS |
| 1 | T-CONC-02 ×3 | 200/200 SETTLED per run; one spending row per member-month; TotalSpend = Σ; points = Σ; no PK violation surfaced; 0 deadlocks | `T-CONC-02__20261110-0737_A/_B/_C` | PASS |
| 1 | T-CONC-03 | Not applicable: no revenue summary exists (WO-P3-P4-02 not executed); "only if a summary exists" | — | NOT_RUN (by definition; moves with WO-P3-P4-02) |
| 1 | T-CONC-04 = T-CONC-04F ×3 + T-CONC-04R | 04F: 200/200 SETTLED per run against 18 / 14 / 26 concurrent batch runs; 0 downgrades while spending grew; final tiers = oracle; no lost update; idempotent final run; 0 deadlocks. 04R: R1 10/10 (every routine waited on the writer's key lock and returned exactly the committed value after ROLLBACK / COMMIT); R2 120 committed + 10 rolled-back settlements vs 30 report calls: 0 observations with rolled-back cents, all within bounds, non-decreasing, consistent; R3 SERIALIZABLE: settlement waited, totals agreed, reported after COMMIT. **Blocking duration not recorded** (timing; Part P, R-27) | `T-CONC-04F__20261110-0737_A/_B/_C`, `T-CONC-04R__20261110-0737` | PASS (blocking-duration element: Part P, PENDING) |
| 1 | T-CONC-05 | Real inventory routine (UC04) | — | NOT_RUN (WO-P3-P6-01, by design) |
| 1 | T-CONC-06 | 200/200 created, distinct ids, each invoice = its request, V-TOT 0 | `T-CONC-06__20261110-0737_R` | PASS |
| 1 | Reconciliation after the concurrency runs (task 5) | T-REC-01/02/04 after T-F05L, each T-CONC-04F run and T-CONC-07: 0 mismatches; T-REC-05 after stage C and stage W: 10 checks, 0 FAIL each; V-UC06R (10 checks) after every test | Run log steps C32-R…C35-R, C36, W25-R, W26, `*-V` | PASS |
| 4 | Every reported number cites a run | All Part C results above cite `P3-03-RUN__20261110-0737` | This table | PASS (Part C) |
| 2, 3, 5 | T-PERF-01/02/08, IX-07, creation-cost baseline | Not executed (Part P not approved; R-27 OPEN; no formal B0) | — | NOT_RUN / PENDING |

Owner-directive verification items (§4–§6 of the directive; no new acceptance criterion):

| Item | Test | Actual result | Status |
|---|---|---|---|
| Workflow items 1–10 (header = lines; settle at most once; PaidAt; CANCELLED without effect; monthly spending; D-006; D-007/D-008/D-009; D-010 revenue; independent reference; unrelated tables) | T-WF-01 W1–W10 | 14 invoices, 24 calls: all outcomes/errors/points as designed; 12 PAID / 1 CANCELLED / 1 PENDING; points m1 = 1 (60,000 + 60,000), m8 = 1 (99,999.99 + 0.01); tiers: spend = Gold → Gold, Gold − 0.01 → Silver, ≥ Platinum → Platinum, = oracle; company revenue 6,119,999.99 = harness amounts; every routine = reference and = monthly spending; unrelated hash unchanged | PASS |
| Settlement vs settlement | T-CONC-01 ×3, T-CONC-02 ×3 | see above | PASS |
| Settlement vs cancellation | T-CONC-01 races + **T-CONC-08** (3 cancel-first, 3 settle-first, forced) | First queued operation always won; losers 51204 / 51223; CANCELLED: no PaidAt, hook, spending or points; PAID: one hook pair, spending = Σ | PASS |
| Settlement vs tier evaluation | T-CONC-04F ×3 | see above | PASS |
| Settlement vs revenue reporting | T-CONC-04R | No dirty read; single-statement consistency; caller-chosen SERIALIZABLE gives multi-statement consistency (the approved contract is single-statement, 07 §12) | PASS |
| Tier evaluation vs tier evaluation | T-CONC-07 T1–T3, Z | Newer run waits on the application lock (never overlaps), no stale overwrite; 51324 after the 60 s wait with nothing written; failure inside a chunk leaves no lock and no transaction; re-runs complete; final tiers = oracle | PASS |
| Client timeout of a tier batch | T-CONC-07 T4 | Chunk transaction rolled back (0 open transactions), but the **session-owned application lock stays held until the cancelled connection closes**; other runs get 51324 meanwhile. After closing: released, re-run correct | Characterised → finding F-1 (§13.5) |
| Rollback on failure | T-F05-04/-19/-25 (creation), T-F05-08 (spending and MEMBER steps), T-F05-22 (hooks), T-F05-29 (caller tx), T-F05-34 (tier chunk), T-WF-01 W11 (hook faults, method mismatch, caller tx with create + settle rolled back), T-CONC-04R (rolled-back settlements), T-CONC-07 T3 | No partial business state in any case | PASS |
| Regression | T-F05 43/43, T-F05S 47/0 FAIL, T-F05-U0 9/0, T-F05L 10/0, T-SCH-01…06 | All PASS; catalog digest identical before/after each stage and equal across stages | PASS |
| Preservation | Fingerprint; DS-L checksums | Fingerprint after = before; `FitLife_P3_P2` and `FitLife_P3_UC05L` = run C `26ABB277…CA1F` | PASS |

### 13.4 Runs, retained failures and harness corrections

| Run | Result | Disposition |
|---|---|---|
| Dry run 0717 (scratchpad only, not evidence) | 97 of 98 steps; T-WF-01 did not compile (`PRINT` with a subquery) | Harness corrected (two `PRINT` statements); T-WF-01 then 11/11 standalone |
| [P3-03-RUN__20261110-0724](../evidence/test-results/P3-03-RUN__20261110-0724.txt) | **FAIL**, 2 of 62 steps: T-SCH-05 K3 received a corrupted column name from `sys.dm_sql_referenced_entities` (stage C stopped before its concurrency suites); W21 consequently had no stage C digest to compare | Engine fault of the DMV (also seen in UC06-RUN 0153), not a P3 defect: K6 shows the routines unchanged; the same check passed in the dry run and in the two later runs. Retained unchanged; full re-run |
| [P3-03-RUN__20261110-0728](../evidence/test-results/P3-03-RUN__20261110-0728.txt) | **PASS**, 98/98 | Complete; its T-CONC-01 races were all won by settlement, which led to T-CONC-08 |
| [P3-03-RUN__20261110-0737](../evidence/test-results/P3-03-RUN__20261110-0737.txt) | **PASS**, 100/100 (adds T-CONC-08) | **Final Part C evidence** |

No timing in any log is a measurement (R-27).

### 13.5 Defects and findings

- **No P3 business-logic defect found.** No production routine was changed.
- **F-1 (availability; risk R-29):** a client-cancelled `usp_P3_EvaluateTiers` keeps its session-owned application lock until the connection closes (attention skips the CATCH block; the chunk transaction is rolled back by XACT_ABORT, so no data is affected). Reproduced deterministically (T-CONC-07 T4 in runs 0724, 0728, 0737). The procedure comment "released on every path" is inaccurate for client cancellation. Handling within the approved scope: caller contract (DEP-19: no client command timeout on the batch, or close/discard the connection after a timeout), recorded in 12 and 14. A code change (e.g. a transaction-owned lock) would conflict with the approved per-chunk commits (D-019 (a)) and is **not** made; it needs an Owner decision if wanted.
- **Engine note:** intermittent corrupted metadata from `sys.dm_sql_referenced_entities` (T-SCH-05 K3). Test-tool reliability issue on SQL Server 17.0.1000.7 RTM; failed evidence retained.

### 13.6 Completion boundary

**Part C `VERIFIED`** (agent; the Owner sets `PASSED`). **Part P `PENDING`** (tasks 3, 3a, 4; criteria 2, 3, 5; T-CONC-04 blocking duration; T-REPRO-03), blocked by R-27 and WO-P3-P2-02. **Whole WO-P3-P3-03 `IN_PROGRESS`**; GATE-P3 open. T-CONC-05 at P6; T-CONC-03 with WO-P3-P4-02. Branch `p3/wo-p3-p1-01`, HEAD `792a85e`; nothing committed, pushed or merged. No next WO started.

## 14. Owner acceptance of Part C (2026-11-10)

The Project Owner conditionally accepted Part C in the Owner Directive "Accept P3 Correctness & Unblock Performance" (Claude Code session of 2026-11-10) §2: set Part C `PASSED` if all mandatory criteria are satisfied; keep the whole WO `IN_PROGRESS`; do not rerun completed tests. The check is **read-only**: no test re-run, no deployment, no data or setting change.

Evidence: [ACCEPT-P3-03C__20261110-080412](../evidence/test-results/ACCEPT-P3-03C__20261110-080412.txt) — **13 checks, 13 PASS** ([harness text](../evidence/test-results/ACCEPT-P3-03C__20261110-080412__harness.py.txt)).

| Item | Result | Checks |
|---|---|---|
| Final run complete | `P3-03-RUN__20261110-0737`: 100 steps, 0 FAIL, no stage stopped; all 20 per-test files present with PASS | E1, E2 |
| Criterion 1 (Part C) | T-CONC-01 ×3 (one winner per invoice), T-CONC-02 ×3, T-CONC-04 (04F ×3 + 04R: no dirty read), T-CONC-06; reconciliation after the concurrency runs | E2, E3, E6 |
| Owner-directive items | Settle vs cancel in both winning orders (T-CONC-08); workflow W1–W11 | E4, E5 |
| Preservation | Fingerprint unchanged; `FitLife_P3_P2` and `FitLife_P3_UC05L` = DS-L run C | E7 |
| Evidence integrity | 41/41 script hashes of the run = current files; nothing under `db/` or `tests/` modified since; no production file under `db/` changed by this WO; failed run 0724 and run 0728 retained | S1–S4 |
| Records | §2a amendment, §13.3 criterion table, §13.6 boundary present; `FitLife_P3_UC05` catalog = verified final routine set | S5, D1 |

**Part C: `PASSED` (2026-11-10, Project Owner, conditional acceptance verified).** Test evidence kept unchanged.

**Whole WO-P3-P3-03: `IN_PROGRESS`.** Part P obligations, unchanged: task 3 (U0/B0, U0/IX-03, U1 settlement benchmark, K = 1,000, DS-M and DS-L, T-PERF-02), task 3a (invoice-creation cost baseline before any P4 index, criterion 5), task 4 (T-PERF-01, T-PERF-08, IX-07 per 08 §5), measured summary tables (task 6), criteria 2, 3, 5 and 4 for measured numbers, the T-CONC-04 blocking duration, T-REPRO-03. Prerequisites: WO-P3-P2-02 `PASSED` on the benchmark environment of [BENCHMARK_ENVIRONMENT_READINESS](../design/BENCHMARK_ENVIRONMENT_READINESS.md) and R-27 closed. T-CONC-05 at P6; T-CONC-03 with WO-P3-P4-02.
