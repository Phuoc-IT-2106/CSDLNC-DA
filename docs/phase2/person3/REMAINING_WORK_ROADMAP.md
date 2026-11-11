# Person 3 — Remaining Work Roadmap (to final submission)

| Field | Value |
|---|---|
| State | 2026-11-11, reconciled with work-order records, evidence and a read-only SQL Server check |
| Authoritative plan | [15_ROADMAP_AND_WORK_ORDERS.md](15_ROADMAP_AND_WORK_ORDERS.md) (execution order, approval rules, gates). This file maps what is **left**; it creates no new work order and approves nothing |
| Related | [README_HANDOFF.md](README_HANDOFF.md) · [design/BENCHMARK_RUNBOOK.md](design/BENCHMARK_RUNBOOK.md) · [PROMPT_PLAYBOOK.md](PROMPT_PLAYBOOK.md) |
| Deadline | Unknown (G-22). Dates are added only when the Owner supplies the deadline |

## 1. Rules for every item below

1. An item starts only when its work order is `APPROVED` (or the Owner gives an explicit in-session instruction with scope). Starting an "independent portion" of a WO whose gate is not met needs a **limited-scope amendment** recorded in that WO, as was done for P3-03 Part C and P4-01 Part F. No new WO identifiers are invented here; the promotion WO is the only planned WO without a file (drafted at P6 per [15 §4](15_ROADMAP_AND_WORK_ORDERS.md#4-work-order-list)).
2. Passing an independent portion never makes the whole WO or phase `PASSED`. P6, P7 and P8 are complete only when their full acceptance criteria are met.
3. Every timing needs E6 PASS on the instance that produces it, then B0 on that instance (R-27).
4. "Mandatory" = needed by the assignment or by an accepted WO criterion. "Optional" = engineering recommendation that may be skipped with a recorded reason.

---

## 2. Track A — Performance machine

Runs on one approved, E6-passed instance. All items are blocked today by R-27.

| # | Work order | Deliverable | Prerequisites | Owner authorization needed | Input | Expected output | Tests / evidence | Acceptance | Independent? | Integration deps |
|---|---|---|---|---|---|---|---|---|---|---|
| A1 | [WO-P3-P0-02](work-orders/WO-P3-P0-02_ENVIRONMENT_BASELINE.md) (BLOCKED) | E6 PASS on the chosen instance; `ENVIRONMENT_P0.md` updated | Free RAM ≥ 2 GB, firm AC; BM-1: A3 floor + A4 power re-applied; or a new machine | **Decision on the next attempt**: does `R-27-CLOSE__20261111-0235` consume the single BM-1 campaign (runner check K1 says yes)? Or approve BM-2 + portable runner + C-PLAN reference rule | Verified DS-L (`26ABB277…CA1F`), harness v2 | `R-27-CLOSE__<ts>` PASS | E6 files ([runbook §8](design/BENCHMARK_RUNBOOK.md#8-e6--environment-stability-gate)) | WO criterion 7, then Owner `PASSED` | Yes (no team input) | None |
| A2 | [WO-P3-P2-02](work-orders/WO-P3-P2-02_BASELINE_BENCHMARK.md) (BLOCKED) | Frozen queries Q-BIL-A, Q-UC05-A, Q-UC06-A/A0/B/C/D; parameter sets; B0 harness (`db/benchmark/`); B0 on DS-M and DS-L | A1 PASSED on the same instance | WO approval naming instance/databases; FULLSCAN statistics; DS-M rebuild | Specs [07 §5](07_UC06_REVENUE_PLAN.md#5-baseline-query-candidates-specifications-to-be-frozen-in-wo-p3-p2-02), [10 §4](10_SEED_AND_BENCHMARK_PLAN.md#4-benchmark-methodology) | `evidence/benchmark-results/<RUN_ID>/`, plans, screenshots | Result hash = oracle; T-REPRO-03 partial | WO §7 criteria 1–4 | Yes. Query files and harness may be **built** before E6 (no timing) once approved | None |
| A3 | [WO-P3-P3-03](work-orders/WO-P3-P3-03_UC05_VERIFICATION.md) Part P (PENDING) | U0 vs U1 (U0/B0, U0/IX-03, U1), K = 1,000, creation-cost baseline, T-PERF-01/02/08, IX-07 decision, T-CONC-04 blocking duration, T-REPRO-03 | A2 accepted; settlement benchmark runner and DS-L database with routines + F002 fixtures (**NOT_IMPLEMENTED**) | Part P approval | B0, routines, `usp_P3_SettleInvoice_Baseline` | RUN_IDs, summary tables | T-PERF-01/02/08, T-REPRO-03 | WO criteria 2, 3, 5 (+4) → whole WO and GATE-P3 | Yes | None for timing; T-CONC-05 stays at P6 |
| A4 | [WO-P3-P4-01](work-orders/WO-P3-P4-01_UC06_INDEX_EXPERIMENTS.md) Part X (PROPOSED) | IX-01…IX-10 one at a time; Q-UC06-A0 vs A; `INDEX_DECISIONS.md`; `db/indexes/`, `db/queries/optimized/` | A2 accepted; creation-cost baseline (A3 task 3a) before any adoption | Part X approval; Owner confirms [08 §6](08_INDEX_AND_QUERY_PLAN.md#6-adoption-and-rejection-criteria) thresholds; D-001 only for IX-08/09 | B0, frozen queries | ADOPTED/REJECTED per candidate with RUN_IDs | T-PERF-03…06, T-REG-01 (T-REG-03 NOT_RUN until P6) | WO criteria 1–4 → GATE-P4 (with A5) | Yes | IX-11 and T-REG-03 at P6 |
| A5 | [WO-P3-P4-02](work-orders/WO-P3-P4-02_REVENUE_SUMMARY.md) (PROPOSED) | A3 summary table and/or A5 indexed view experiment; `SUMMARY_DECISION.md`; D-015/D-016 | A4 PASSED | WO approval | Best B1, settlement path | B4 RUN_IDs | T-PERF-03…06, T-CONC-03, T-REC-03, T-REG-01 | WO criteria 1–3 | Yes | Adoption into shared schema at P6 |
| A6 | [WO-P3-P5-01](work-orders/WO-P3-P5-01_PARTITION_POC.md) (PROPOSED) | INVOICE partition PoC on a copy (B2/B3), elimination evidence, `PARTITION_DECISION.md`, D-017 (adopt **or** measured rejection) | GATE-P4 | WO approval; DS-XL only if separately approved | Best B1/B4 | `db/partition-poc/`, plans with partition counts | T-REG-02, T-PERF-07 | WO criteria 1–4 | Yes | DEP-11 (project-level partition owner) at P6 |

Order inside Track A is strict: A1 → A2 → A3 → A4 → A5 → A6 (A3 task 3a must precede any A4 adoption).

---

## 3. Track B — Original development laptop

Runs without a benchmark environment. Items marked "amendment" need the Owner to record a limited-scope amendment of the named WO, because its gate (GATE-P5/P6/P7) is not met.

| # | Work order | Deliverable (independent portion) | Prerequisites | Authorization | Expected output | Evidence | Can it complete the WO? | Integration deps |
|---|---|---|---|---|---|---|---|---|
| B1 | Repository (D-021) | Checkpoint of the handover files and later work on `p3/wo-p3-p1-01` | — | Commit/push authorization; D-021 Part B for visibility | Commit, clean `git status` | Commit id | n/a | Team decides visibility/conventions |
| B2 | [WO-P3-P1-02](work-orders/WO-P3-P1-02_INTEGRATION_CONTRACT.md) (amendment) | Draft `design/INTEGRATION_CONTRACT.md` (13 items of [12 §3](12_INTEGRATION_PLAN.md)): types, status literals, settlement orchestration, lock order, error ranges, SET options, D-028 caller rules (DEP-04, DEP-16), scheduler and R-29 caller contract (DEP-19), D-008 values request (DEP-20), regression-query request (T-REG-03), partition owner (DEP-11) | None for drafting | Amendment allowing early drafting (WO trigger is P6 or a [15 §2.2](15_ROADMAP_AND_WORK_ORDERS.md#22-operations-that-require-team-integration-trigger-for-wo-p3-p1-02) operation) | Draft v0.x | Draft file, change log | **No** — needs team agreement (criterion 2) | All team members |
| B3 | Team coordination (no WO) | Questions to the team: D-001 catalogue, D-020 stack, D-008 values, D-021 Part B, team schema and hook routines, app skeleton, report template, deadline | — | Owner sends them | Recorded answers in [03](03_DECISION_LOG.md) | Approver + date per decision | n/a | — |
| B4 | [WO-P3-P6-01](work-orders/WO-P3-P6-01_APP_INTEGRATION.md) stage B (amendment) | P3 application surface on isolated databases: invoice list/detail, confirm payment, loyalty view, revenue reports, admin tier batch — calling the existing procedures only | **D-020 approved**; app skeleton/conventions | Amendment + D-020 | `app/` code, screenshots `evidence/screenshots/APP__*` | T-INT-04 on isolated DB (not the integration DB) | **No** — WO needs stage A (team schema, real hooks), promotion WO and the integration DB | Team stack, roles (RQ-P15) |
| B5 | [WO-P3-P7-01](work-orders/WO-P3-P7-01_QA_AND_FINAL_BENCHMARK.md) prep (amendment) | R-29 pre-integration test design (pooled-connection variant, KILL-and-rerun drill, 51324 retry); regression-suite inventory; clean-rebuild script plan | None for design | Amendment for any test **execution** | Test specs/scripts | Test plan entries in [11](11_TEST_AND_QA_PLAN.md) | **No** — needs GATE-P6 and final benchmark | Real scheduler, real hooks |
| B6 | [WO-P3-P8-01](work-orders/WO-P3-P8-01_EVIDENCE_AND_HANDOFF.md) (amendment) | Report sections that rely only on accepted evidence: scope and frequencies, physical design table, UC05 design (incremental loyalty, Problem 4 design without timing claims), correctness/concurrency results, limitations | — | Amendment (WO gate is GATE-P7) | `docs/phase2/person3/report/` drafts | Every number → RUN_ID | **No** — performance, application and integration sections stay open | Team report template |

What cannot be completed on Track B alone: any timing or before/after claim (Track A), stage A integration (team schema and hook routines), promotion to the shared database (team approval), the final integrated QA, the group report merge.

---

## 4. Parallel execution and dependencies

```text
Track A (benchmark instance)            Track B (laptop, parallel)
A1 E6 PASS ─▶ A2 B0 ─▶ A3 Part P         B1 checkpoint (any time, authorized)
                   └─▶ A4 Part X ─▶ A5    B3 team questions (now)
                              └──────▶ A6 B2 contract draft (amendment)
                                          B4 app on isolated DB (after D-020 + amendment)
                                          B5 QA design, B6 report drafts (amendments)
                 ▼ GATE-P3, P4, P5                 ▼ team schema, real hooks, D-020, D-001
                 P6: WO-P3-P1-02 agreed ─▶ promotion WO ─▶ WO-P3-P6-01 stage A ─▶ stage B
                                          ▼ GATE-P6
                                          P7 WO-P3-P7-01 (needs Track A results + integration)
                                          ▼ GATE-P7
                                          P8 WO-P3-P8-01 final report
```

Can run in parallel: all of Track B with all of Track A. Inside Track A: nothing in parallel before A2; after A2, A3 and the A4 setup may overlap only if they use the same instance one configuration at a time. Cannot finish without other members: B2, B4, P6 stage A, promotion, P7, group report. Cannot finish without benchmark results: A2–A6, P7, the performance sections of P8.

---

## 5. Academic requirement-to-evidence matrix

Grade weights (group assessment, not Person 3 percentages): conceptual 20%, logical 10%, physical 50%, application 20%. The repository records physical 50% and application 20% ([01](01_REQUIREMENTS_TRACEABILITY.md) RQ-A07, RQ-A09); 20%/10% come from the Owner's directive and were not re-verified (the assignment PDF is password-protected and was not opened).

| Academic requirement | Person 3 responsibility | Current evidence | Missing artifact | WO | Mandatory? |
|---|---|---|---|---|---|
| Conceptual design (20%) | UC05/UC06 descriptions for the group (RQ-A08) | [06](06_UC05_BILLING_LOYALTY_PLAN.md), [07](07_UC06_REVENUE_PLAN.md) plans; Phase 1 report (outside repo) | Final UC text aligned with D-001 | P8-01; D-001 (team) | Yes (group) |
| Logical design (10%) | P3 additions to the logical schema (PaidAt, MEMBER_MONTHLY_SPENDING, status domains) | Decisions D-003…D-005, D-013, D-014; [PHYSICAL_DESIGN_TABLE](design/PHYSICAL_DESIGN_TABLE.md) | Report section | P8-01 | Yes (group) |
| Physical design table | Four P3 tables | DL-01, T-SCH-01/02 PASS | Index/summary rows (after P4) | P1-01 ✔; P4-01 X | Yes |
| Large valid dataset (≥70,000 rows on selected relevant tables) | P3 tables | DS-L: INVOICE 324,000; INVOICE_PRODUCT_ITEM 712,789; MEMBER_MONTHLY_SPENDING 169,040; FK-valid, reproducible | None for these three. Note: INVOICE_SERVICE_ITEM has 65,177 rows (below 70,000) and is not one of the RQ-A06 demonstration tables; do not present it as one. Shared tables are key fixtures (MEMBER 30,000) | P2-01 ✔ | Yes |
| Related use cases (5–8) with frequencies | Group-level; P3 supplies UC05/UC06 only | [04 §2](04_WORKLOAD_AND_DATA_VOLUME.md) frequencies (Phase 1 estimates) | Group catalogue (D-001); do not add UCs to Person 3 to reach the count | Team | Yes (group) |
| High/low-frequency query analysis | F05/F06/F20/F21 high; F22/F27/F28 low | [04](04_WORKLOAD_AND_DATA_VOLUME.md), [08 §3](08_INDEX_AND_QUERY_PLAN.md) | Measured confirmation (B0) and report text | P2-02, P8-01 | Yes |
| Stored procedures / functions | UC05/UC06 routines | 10 production procedures, 5 functions and 2 table types in `db/procedures/` (+1 reference U0 procedure in `db/reference/`); tests PASS | — | P3-00…02 ✔, P4-01 F ✔ | Yes |
| Triggers | Only if D-016 selects a trigger-maintained summary | None (no trigger exists) | Decision in P4-02; otherwise state why no trigger is used | P4-02 | Conditional |
| Index experiments | IX-01…IX-10 | None (DIAGNOSTIC_ONLY plans/reads from Part F) | All candidate runs, `INDEX_DECISIONS.md` | P4-01 X | Yes |
| Partition analysis | INVOICE PoC or measured rejection | Feasibility plan [09](09_PARTITION_FEASIBILITY_PLAN.md); probe 3b (supported) | PoC, elimination evidence, decision | P5-01 | Yes |
| Summary table or View/Trigger (Problem 3) | Revenue summary experiment | None | A3/A5 experiment and decision | P4-02 | Yes (assignment Problem 3 asks to propose it) |
| Problem 4 (loyalty redesign) | Incremental spending/points, periodic tiers | Functional PASS (P3-01, P3-02, P3-03 C) | U0 vs U1 measurements | P3-03 P | Yes |
| Actual Execution Plans | All frozen queries, B0 and each configuration | 20 `.sqlplan` files (B0 Q-UC05-B/C; UC06 reference, DIAGNOSTIC_ONLY) | B0 and experiment plans | P2-02 → P5-01 | Yes |
| Before/after measurements | Every adopted/rejected change | None valid (R-27) | Measured RUN_IDs | P2-02 → P5-01, P7-01 | Yes |
| Screenshots + technical explanation | Plans and IO/TIME screenshots | `evidence/screenshots/` empty | All screenshots | P2-02 → P5-01, P6-01 | Yes |
| Scripts to create DB, run queries, indexes, partitions | P3 scripts | Migrations, procedures, seed, test runners | Index, summary, partition scripts | P4-01 X, P4-02, P5-01 | Yes |
| Application source code | P3 screens/endpoints | None | `app/` | P6-01 (D-020) | Yes (20%) |
| Working UI connected to SQL Server | Same | None | Demo + screenshots + cross-check queries | P6-01 | Yes |
| Integration evidence | T-INT-01…04, T-CONC-05, T-REG-03 | Contract doubles only | Stage A results | P6-01 | Yes |
| Regression tests | All suites on final configuration | Part C 100/100, Part F 78/78 (isolated) | Final regression on integrated build | P7-01 | Yes |
| Final academic report | P3 section + evidence index | Planning docs, evidence index structure | `report/` section, traceability audit | P8-01 | Yes |
| Team tracking tool, contributions (RQ-A19–A21) | P3 entries | Work orders in repo | Tool link, contribution table | Team / P8-01 | Yes (group) |
| Optional extensions (columnstore IX-10, DS-XL, cold-cache runs, CDC, In-Memory) | — | — | Only if approved; report as optional | — | No |

Recorded discrepancies (kept, not rewritten): the assignment says tier spending "in the year" while Problem 4 describes "the last 12 months"; D-007 (approved T2) uses twelve month-aligned local months — report it as an approved interpretation. Revenue is recognised in full at `PaidAt` (D-010), so service-plan revenue is not spread over the plan period. D-008 threshold values are not defined by any source.

---

## 6. Recommended next action

**If a benchmark instance can be prepared this week:** the Owner decides the R-27 path (A1) — either a controlled BM-1 campaign with A3 + A4 re-applied and ≥ 2 GB free RAM (including how the consumed-campaign check K1 is handled), or an approved BM-2. Then run [Prompt 3](PROMPT_PLAYBOOK.md#prompt-3--e6-execution).

**If not (most likely today): start Track B item B2 + B3** — draft the integration contract as documentation and send the team the decision questions (D-020, D-001, D-008 values, D-021 Part B, team schema, app skeleton). This is the shortest path to the application (20% of the grade) and to P6, and it does not depend on R-27. It needs the Owner to record a documentation-only amendment of WO-P3-P1-02. Nothing starts automatically.

## 7. Deliverable tracking

| Work order | Deliverable | Dependency | Can start now? | Acceptance evidence |
|---|---|---|---|---|
| WO-P3-P0-02 | E6 PASS, environment report | Owner R-27 decision; RAM/AC | No (decision) | `R-27-CLOSE__*` PASS |
| WO-P3-P2-02 | DL-05, DL-06 (B0) | P0-02 PASSED | Build-only parts after approval; no timing | B0 RUN_IDs, plans, screenshots |
| WO-P3-P3-03 Part P | DL-09 benchmark part | B0 accepted | No | T-PERF-01/02/08 RUN_IDs, IX-07 decision |
| WO-P3-P4-01 Part X | DL-10 indexes + decisions | B0, creation-cost baseline | No | `INDEX_DECISIONS.md` with RUN_IDs |
| WO-P3-P4-02 | DL-11 | P4-01 PASSED | No | `SUMMARY_DECISION.md`, T-REC-03 |
| WO-P3-P5-01 | DL-12 | GATE-P4 | No | `PARTITION_DECISION.md`, partition counts |
| WO-P3-P1-02 | DL-02 contract | Team; amendment for early drafting | Drafting only, after amendment | Agreement record |
| Promotion WO (to be drafted at P6) | Adopted P3 objects in the shared DB | WO-P3-P1-02 PASSED | No | Promotion record |
| WO-P3-P6-01 | DL-13 application + integration | D-020, team schema, promotion | Isolated-DB portion after D-020 + amendment | T-INT-01…04, screenshots, demo |
| WO-P3-P7-01 | DL-14 final regression/benchmark | GATE-P6, Track A | No | Final RUN_IDs, T-REPRO-01…03 |
| WO-P3-P8-01 | DL-15 report section | GATE-P7 (drafts by amendment) | Drafts after amendment | Traceability audit: zero untraceable numbers |
