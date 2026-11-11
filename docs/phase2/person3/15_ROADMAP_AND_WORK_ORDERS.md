# 15 — Roadmap and Work Orders (Person 3)

| Field | Value |
|---|---|
| Document status | DRAFT — WO-P3-BOOT-001; P0/P1 restructured by Owner Directive WO-P3-P0-FINAL (2026-11-07); rule 3 amended and P1-R3 updated by the Owner Directive "Final P0 Decision Resolution"; P1 scope restricted by the Owner Directive "Strict Person 3 Scope Enforcement" (both 2026-11-07); **execution order reprioritized by the Owner Directive "Reprioritize Person 3 Implementation" (2026-11-08, [D-027](03_DECISION_LOG.md#d-027--deferral-of-the-formal-integration-contract-independent-p2p5-development))** |
| Date | 2026-11-10: P4-01 Part F PASSED (Owner); P3-03 Part C VERIFIED (limited-scope amendment); P3-03 and P4-01 whole WOs IN_PROGRESS; Part P / Part X pending |
| Scheduling | **Sequenced but not dated.** The Phase 2 deadline is unknown (G-22). Dates are added once the Project Owner supplies the deadline. |
| Work-order index | [work-orders/README.md](work-orders/README.md) |

## 1. Approval rules

These rules are identical to [P3_MASTER_PROMPT.md Appendix A1](../../agent/P3_MASTER_PROMPT.md#a1-approval-gates). Modes and statuses follow master prompt §3 and §4.

1. Every work order (WO) is created with status `PROPOSED`. **It may be executed only after the Project Owner sets it to `APPROVED`**, either by an explicit instruction in the session or by an approval recorded in the WO with a date.
2. A `BUILD_AUTHORIZED` WO may start only if every decision listed in its "Preconditions" is `APPROVED` in [03_DECISION_LOG.md](03_DECISION_LOG.md).
3. Decisions marked "Team approval needed" require a recorded team approval, not only the Project Owner's. **Exception (option T2, approved by the Project Owner on 2026-11-07):** for work confined to isolated local environments under D-025 and an approved `BUILD_AUTHORIZED` WO, the Project Owner may approve such a decision provisionally (`APPROVED (provisional, T2)`). The implementation must derive from the approved Phase 1 logical schema and is not the definitive team schema. Recorded team approval is required before any integration, merge into the shared `main` branch, or change to the shared database. A provisional approval authorizes no shared-database change, push or merge.
4. Even inside an approved WO, the following need **separate explicit authorization**: commits, pushes and merges; installing or upgrading software; changes to any database other than the WO's declared target database; edits to another member's files.
5. **Phase gate:** WOs of phase N+1 start only after the WOs of phase N are `PASSED` (GATE-Pn), except where the roadmap states a parallel start.
6. The agent may set a WO to `VERIFIED` after checking the evidence against its acceptance criteria, but never sets `PASSED`, approves decisions or passes gates; those require the Project Owner.

WO status lifecycle: `PROPOSED` → `APPROVED` → `IN_PROGRESS` → `VERIFIED` → `PASSED`. Side states: `BLOCKED` (precondition or dependency missing) and `FAILED` (a mandatory acceptance criterion is not met).

## 2. Execution order and dependencies

### 2.1 Execution priority (Owner Directive 2026-11-08, D-027)

The three members develop their modules independently. Person 3 implements its own database work first and integrates formally at P6.

| Order | Phase | Work orders (identifiers unchanged) | Current state (reconciled 2026-11-10) |
|---|---|---|---|
| 1 | P1 — Physical Schema Foundation | WO-P3-P1-01 | `PASSED` 2026-11-08; **GATE-P1 closed** |
| 2 | P2 — Large Dataset and Baseline Measurement | WO-P3-P2-01 → WO-P3-P2-02 (WO-P3-P0-02 before WO-P3-P2-02) | **In progress:** WO-P3-P2-01 `PASSED` (2026-11-08; **GATE-P2-01 closed**); WO-P3-P2-02 `BLOCKED`, not ready (WO-P3-P0-02 and R-27; D-010 now approved T2; [WO-P3-P2-02 §2a](work-orders/WO-P3-P2-02_BASELINE_BENCHMARK.md#2a-benchmark-readiness-checklist-r-27)) |
| 3 | P3 — Billing, Settlement and Loyalty Implementation | WO-P3-P3-00 → WO-P3-P3-01 → WO-P3-P3-02 → WO-P3-P3-03 | **2026-11-10:** P3-00 `PASSED` (functional; creation-cost baseline transferred to P3-03), P3-01 `PASSED`, P3-02 `PASSED` (Owner); **P3-03 Part C PASSED** (Owner, 2026-11-10), Part P pending (R-27), whole WO IN_PROGRESS. Functional work does not wait for WO-P3-P2-02 / R-27 (§6); each WO needs its own approval |
| 4 | P4 — Revenue Reporting and Index Optimization | WO-P3-P4-01 → WO-P3-P4-02 | Part F PASSED (Owner, 2026-11-10) under the 2026-11-10 exception; whole P4-01 IN_PROGRESS; Part X/P4-02 not approved or started |
| 5 | P5 — Partition Feasibility and Experimental Optimization | WO-P3-P5-01 | Independent; needs its own approval |
| 6 | P6 — Formal Integration Contract and Application Integration | **WO-P3-P1-02** (deferred here) → promotion WO (to be drafted at P6) → WO-P3-P6-01 | Team integration starts here |
| 7 | P7 — Integration QA, Concurrency and Performance Verification | WO-P3-P7-01 | Final re-verification |
| 8 | P8 — Final Evidence and Report | WO-P3-P8-01 | — |

Rules of this order:

1. **Formal team integration is not a prerequisite for P2–P5.** No P2–P5 WO requires WO-P3-P1-02, another member's schema, routine, query or approval, or another member finishing a module.
2. **WO-P3-P1-02 (Integration Contract) is `PROPOSED`, execution DEFERRED TO P6.** It keeps its identifier, objective and requirements. It starts at the beginning of P6, or **immediately before the first operation that requires team integration**, whichever comes first (§2.2). It is not `PASSED`, `CANCELLED` or completed.
3. Until then, shared interfaces are covered by the **dependency register** ([12 §2b](12_INTEGRATION_PLAN.md#2b-dependency-register-interim-assumptions-until-p6)): the assumptions P3 relies on, the TEST_ONLY fixture or contract-only test double that stands in for each, and when each is verified. It is not the integration contract and blocks nothing.
4. **Incompatibilities found in P2–P5** are recorded as integration risks ([14](14_RISK_REGISTER.md), R-26) and in the dependency register. They are escalated to the Owner immediately only if they make the current implementation invalid or unsafe; otherwise they are resolved at P6.
5. **Priority P3 before P4.** The rule of 2026-11-06 that WO-P3-P4-01 may start after GATE-P2 in parallel with P3 is kept, if the Owner approves it; the write-overhead step (T-PERF-06) and WO-P3-P4-02 need WO-P3-P3-01.
6. Correctness, concurrency and reproducibility tests are run **in the WO that builds the object** (P2–P5). P7 re-verifies everything on the final configuration; it is never the first time a test runs.
7. Each WO still needs its own Owner approval before `BUILD_AUTHORIZED` execution. (WO-P3-P1-01 stayed `VERIFIED` until the Owner set it to `PASSED` on 2026-11-08.)

### 2.2 Operations that require team integration (trigger for WO-P3-P1-02)

WO-P3-P1-02 must be `PASSED` before any of these, even if P6 has not started:

1. Any change to the canonical shared team database (D-025 conditions 1, 6, 7), including the promotion of a P3 object.
2. A merge into the shared `main` branch of P3 objects or of any shared item.
3. Replacing TEST_ONLY fixtures or contract-only test doubles with another member's real tables or routines (D-026 condition 9).
4. Running tests that need other members' objects or queries: T-INT-01/02 against the real hook routines, T-INT-03, T-CONC-05, T-REG-03.
5. Application integration in the team application (WO-P3-P6-01).

Local commits and pushing a `p3/<wo-id>` branch are **not** integration; they follow approval rule 4 and D-021 Part B.

### 2.3 Dependency overview

```text
P0  WO-P3-BOOT-001, WO-P3-P0-01, WO-P3-P0-03 (all PASSED) ──▶ GATE-P0 CLOSED 2026-11-07
P1  WO-P3-P1-01 Physical schema foundation (PASSED 2026-11-08)
                                  ▼ GATE-P1 (WO-P3-P1-01 PASSED)
P2  WO-P3-P2-01 Large dataset (PASSED 2026-11-08; GATE-P2-01) ──▶ WO-P3-P2-02 Harness + baseline B0
    WO-P3-P0-02 Feature probes  (any time; must be PASSED before WO-P3-P2-02; proposed home of the R-27 closure test)
                                  ▼ GATE-P2
P3  WO-P3-P3-00 Invoice creation ──▶ WO-P3-P3-01 Settlement ──▶ WO-P3-P3-02 Loyalty/tier ──▶ WO-P3-P3-03 UC05 verification
P4  WO-P3-P4-01 Revenue + indexes ──▶ WO-P3-P4-02 Revenue summary
        (priority after P3; WO-P3-P4-01 may run in parallel after GATE-P2 if approved;
         T-PERF-06 and WO-P3-P4-02 need WO-P3-P3-01)
                                  ▼ GATE-P3, GATE-P4
P5  WO-P3-P5-01 Partition feasibility (needs WO-P3-P4-01 best-B1 results)
                                  ▼ GATE-P5
P6  WO-P3-P1-02 Integration contract (deferred; first P6 step, or earlier at a §2.2 trigger)
      ──▶ promotion WO (to be drafted from the agreed procedure)
      ──▶ WO-P3-P6-01 Integration rehearsal + application
                                  ▼ GATE-P6
P7  WO-P3-P7-01 Integration QA, concurrency, final benchmark
                                  ▼ GATE-P7
P8  WO-P3-P8-01 Final evidence and report
                                  ▼ GATE-P8 (P3 complete)
```

## 3. Phases

### P0 — Readiness Audit and Decision Freeze

| Item | Content |
|---|---|
| 1. Objective | Turn the open questions into approved decisions and a verified environment, so P1 can start without guessing. |
| 2. Preconditions | WO-P3-BOOT-001 PASSED (Project Owner gate). |
| 3. Inputs | [02](02_GAP_ANALYSIS.md), [03](03_DECISION_LOG.md), S-01, S-02, the team's six-UC list (to be obtained), team availability. |
| 4. Tasks | WO-P3-P0-01: classify and analyse the decisions, assess repository readiness, review the P1–P8 WOs (decision review); PASSED 2026-11-07. Owner Directive WO-P3-P0-FINAL (2026-11-07): final decision package, repository baseline and clone, P1 readiness. Owner/team: decide (package Section F). WO-P3-P0-03: record the decisions and propagate them. Also collect the six-UC list and owners, the deadline and the team tracking tool. _(WO-P3-P0-02 was moved out of P0 on 2026-11-07: see P2.)_ |
| 5. Deliverables | [design/P0_DECISION_REVIEW.md](design/P0_DECISION_REVIEW.md); [design/P0_FINAL_DECISION_PACKAGE.md](design/P0_FINAL_DECISION_PACKAGE.md); updated [03_DECISION_LOG.md](03_DECISION_LOG.md); updated [16_READINESS_REPORT.md](16_READINESS_REPORT.md). |
| 6. Acceptance criteria | **GATE-P0 (redefined 2026-11-07; CLOSED 2026-11-07):** WO-P3-P0-01 PASSED ✔ and WO-P3-P0-03 PASSED ✔. That implies every BLOCKING_P1 decision (D-002, D-003, D-004, D-005, D-011, D-013, D-014, D-018, D-021, D-023, D-026) is APPROVED (under timing option T1 or T2 of the [package §B0](design/P0_FINAL_DECISION_PACKAGE.md#b0-team-approval-timing-choose-one)) or REJECTED with an approved replacement; D-025 APPROVED ✔. The environment facts P1 needs are captured in WO-P3-P1-01 step 1; the feature probes (WO-P3-P0-02) gate WO-P3-P2-02 instead. |
| 7. Verification | Each decision entry has an approver, date and reference; the documentation audit passes. |
| 8. Evidence | Decision review and final package; decision references (meeting notes or chat screenshots). |
| 9. Dependencies and risks | Team availability (R-02, R-18); R-17, R-24. |
| 10. Owner approval | The Project Owner approves the WOs, decides (or obtains team decisions on) the BLOCKING_P1 set, and passes GATE-P0. |
| 11. Proceed to P1 when | All P1 readiness criteria P1-R1…P1-R8 below hold. |

<a id="p1--physical-schema-and-integration-contract"></a>

### P1 — Physical Schema Foundation

_Until 2026-11-08 this phase was "Physical Schema and Integration Contract". The contract (WO-P3-P1-02) keeps its identifier but is executed in P6 (D-027)._

| Item | Content |
|---|---|
| 1. Objective | Implement the physical schema of the **four P3-owned tables** (INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM, MEMBER_MONTHLY_SPENDING) and verify it in an isolated test database, with shared parents only as TEST_ONLY key fixtures (WO-P3-P1-01). No other member's module is built. |
| 2. Preconditions | **P1 readiness criteria** for WO-P3-P1-01 (all must hold; redefined 2026-11-07 by directive WO-P3-P0-FINAL §9; current state and reasons in [16 §2](16_READINESS_REPORT.md#2-go--no-go-for-p1-physical-schema)): <br>**P1-R1** WO-P3-BOOT-001 PASSED ✔ <br>**P1-R2** WO-P3-P0-01 PASSED ✔ (2026-11-07) <br>**P1-R3** every BLOCKING_P1 decision APPROVED with approver, date and reference: D-002, D-003, D-004, D-005, D-011, D-013, D-014, D-018, D-021, D-023, D-026 (team-approval decisions provisionally under rule 3 / T2; for D-021 only Part A); recorded by WO-P3-P0-03. State 2026-11-07: 11 of 11 approved (D-013, D-021 Part A, D-026 restricted by the strict-scope directive; eight others provisionally under T2) <br>**P1-R4** D-025 APPROVED ✔ (2026-11-06, with constraints) <br>**P1-R5** repository readiness: canonical repository identified ✔ (`Phuoc-IT-2106/CSDLNC-DA`); local working copy through an authorized clone ✔ (2026-11-07); D-021 approved (layout, branch convention, single working copy, visibility decision). The documentation cut-over and `.gitignore`/`.gitattributes` are step 0 of WO-P3-P1-01; write access is needed only for push and PR, not to start. <br>**P1-R6** shared dependencies: the approved team schema, or the TEST_ONLY key fixtures allowed by D-026 (restricted, approved 2026-11-07) in isolated databases only ✔ <br>**P1-R7** test environment authorized: WO-P3-P1-01 approved with its isolated target database named; the instance identity is captured in its step 1 with stop conditions (replaces "WO-P3-P0-02 PASSED", which now gates WO-P3-P2-02) <br>**P1-R8** P3 scope confirmed by the Owner ✔ (directive 2026-11-07 §6.1: UC05, UC06); the full six-UC catalogue moved to D-001 (BLOCKING_UC06) |
| 3. Inputs | [05](05_PHYSICAL_DESIGN_PLAN.md), [12 §2a](12_INTEGRATION_PLAN.md#2a-shared-dependency-interface-required-by-p3), S-02 §10, the shared baseline of P1-R6, the [P0 final decision package](design/P0_FINAL_DECISION_PACKAGE.md). |
| 4. Tasks | WO-P3-P1-01: repository cut-over, SQL Server preflight, production migrations V001/V002 for the four P3 tables, TEST_ONLY fixture script, physical design table, constraint, conformance, FK and separation checks, clean install. |
| 5. Deliverables | DL-01, DL-03. (DL-02, the contract, is delivered in P6.) |
| 6. Acceptance criteria | GATE-P1 = WO-P3-P1-01 PASSED: T-SCH-01, T-SCH-02 and T-REPRO-01 pass; T-INT-03 passes if a team schema exists, otherwise N/A. |
| 7. Verification | Run the tests on a freshly created test database. |
| 8. Evidence | Environment capture; test outputs. |
| 9. Dependencies and risks | R-03, R-13, R-23, R-24, R-25. |
| 10. Owner approval | Project Owner. |
| 11. Proceed to P2 when | GATE-P1 passed. |

### P2 — Large Dataset and Baseline Measurement

| Item | Content |
|---|---|
| 1. Objective | Generate reproducible, logically consistent DS-S/M/L data for the four P3 tables, and capture baseline evidence (B0) for the billing, loyalty and revenue read queries before any optimisation. |
| 2. Preconditions | GATE-P1. **WO-P3-P2-01:** D-006 and D-022 APPROVED (D-006 fixes the derived `PointsEarned`; D-022 fixes dataset tiers, tool and distributions). **WO-P3-P2-02:** WO-P3-P2-01 PASSED ✔ (2026-11-08, GATE-P2-01); WO-P3-P0-02 PASSED; D-010 APPROVED (provisional T2 allowed; it fixes the revenue oracle and predicates); benchmark readiness checklist met, including the R-27 closure test E6 ([WO-P3-P2-02 §2a](work-orders/WO-P3-P2-02_BASELINE_BENCHMARK.md#2a-benchmark-readiness-checklist-r-27), [14 R-27](14_RISK_REGISTER.md#r-27-assessment-2026-11-08)). **Conditional:** D-007 and D-008 only if the Owner includes the loyalty-state queries Q-UC05-B/C in the P2 baseline (they need the F002 fixture extension); otherwise their B0 is captured in WO-P3-P3-02. **No team prerequisite** (D-027). |
| 3. Inputs | [10](10_SEED_AND_BENCHMARK_PLAN.md), [04](04_WORKLOAD_AND_DATA_VOLUME.md), DL-03, [12 §2b](12_INTEGRATION_PLAN.md#2b-dependency-register-interim-assumptions-until-p6). |
| 4. Tasks | WO-P3-P2-01: review the Phase 1 workload and volumes; seed generator for the four P3 tables on top of TEST_ONLY key fixtures (no BRANCH_INVENTORY or other shared-module data); derived MEMBER_MONTHLY_SPENDING; integrity validation. WO-P3-P2-02: freeze the baseline queries (Q-BIL-A, Q-UC05-A, Q-UC06-A/A0/B/C/D; Q-UC05-B/C if included), build the harness, measure B0 with Actual Execution Plans, logical reads, CPU and elapsed time over repeated runs. U0 (settlement) is measured in WO-P3-P3-03. |
| 5. Deliverables | DL-04, DL-05, DL-06. |
| 6. Acceptance criteria | T-SEED-01…03, V-TOT, T-REC-01, T-REC-02 (row part), T-REPRO-02 pass; baseline RUN_IDs complete for every frozen query on DS-M and DS-L; no optimisation index exists in B0. |
| 7. Verification | Re-run the seed and compare checksums; the harness re-run reproduces the logical reads. |
| 8. Evidence | Row-count report; RUN_ID folders; baseline plans and screenshots. |
| 9. Dependencies and risks | R-05, R-06, R-07, R-08, R-26. |
| 10. Owner approval | Project Owner. |
| 11. Proceed when | GATE-P2 passed; P3 (and, if approved, WO-P3-P4-01 in parallel) may then start. |

### P3 — Billing, Settlement and Loyalty Implementation

| Item | Content |
|---|---|
| 1. Objective | Build invoice creation (billing), an atomic and idempotent settlement with incremental loyalty, and periodic tier evaluation; prove correctness, concurrency safety and the Problem 4 improvement, in isolated databases. |
| 2. Preconditions | GATE-P2 only for timing measurements (since 2026-11-09, §6). WO-P3-P3-00: D-028 APPROVED (functional portion executed 2026-11-09 under the directive's fallback). WO-P3-P3-01: WO-P3-P3-00 PASSED; D-006, D-012 (provisional T2 for isolated orchestration with contract-only hook test doubles), D-019 APPROVED. WO-P3-P3-02: D-007, D-008, D-009 APPROVED; D-024 ✔. **Removed 2026-11-08:** WO-P3-P1-02 PASSED; other members' hook routines; UC01/UC04 owner approvals (all moved to P6). |
| 3. Inputs | [06](06_UC05_BILLING_LOYALTY_PLAN.md) (§8 readiness), [11](11_TEST_AND_QA_PLAN.md), [12 §2b, §4–§6](12_INTEGRATION_PLAN.md#2b-dependency-register-interim-assumptions-until-p6), DL-03, DL-04. |
| 4. Tasks | WO-P3-P3-00 invoice creation; WO-P3-P3-01 settlement (+ U0 variant, cancellation); WO-P3-P3-02 loyalty and tiers; WO-P3-P3-03 concurrency, rollback, reconciliation, U0 vs U1 benchmark. |
| 5. Deliverables | DL-07, DL-08, DL-09. |
| 6. Acceptance criteria | All in-scope T-F05 (incl. T-F05-18…22), T-CONC-01…04 and T-CONC-06, T-REC-01/02/04 pass; T-PERF-01/02/08 evidence complete. T-INT-01/02 against the real routines and T-CONC-05 are `NOT_RUN` by design until P6 (recorded with that reason). |
| 7. Verification | Test suites run on DS-S fixtures and DS-L; concurrency harness logs. |
| 8. Evidence | Test outputs; RUN_IDs for U0/U1. |
| 9. Dependencies and risks | R-04, R-10, R-15, R-16, R-26. |
| 10. Owner approval | Project Owner. |
| 11. Proceed when | GATE-P3 passed. |

### P4 — Revenue Reporting and Index Optimization

| Item | Content |
|---|---|
| 1. Objective | Implement the core revenue reports (by branch, monthly, system-wide); evaluate candidate indexes one at a time from the actual predicates; evaluate a summary or indexed view; adopt only what the evidence supports. |
| 2. Preconditions | GATE-P2; D-010 APPROVED; D-023 ✔; D-022 thresholds ✔ (approved before P2). D-001 is needed **only** for the candidate reports RPT-05…07; the core reports RPT-01…04 do not wait for it. The write-overhead step needs WO-P3-P3-01. |
| 3. Inputs | [07](07_UC06_REVENUE_PLAN.md) (§11 priority), [08](08_INDEX_AND_QUERY_PLAN.md), DL-05, DL-06. |
| 4. Tasks | WO-P3-P4-01 report routines and the index experiments; WO-P3-P4-02 summary/indexed-view experiment. |
| 5. Deliverables | DL-10, DL-11. |
| 6. Acceptance criteria | T-F06-xx (in scope), T-REG-01 pass; T-REC-03 passes if a summary is adopted; every candidate ADOPTED/REJECTED with evidence; D-015/D-016 decided. T-REG-03 (other members' queries) is `NOT_RUN` until P6. |
| 7. Verification | B0/B1/B4 runs with identical parameters; hash comparison. |
| 8. Evidence | Plans, screenshots, CSVs, decision records. |
| 9. Dependencies and risks | R-08, R-11, R-12, R-16, R-26. |
| 10. Owner approval | Project Owner (the team reviews anything proposed for promotion, at P6). |
| 11. Proceed when | GATE-P4 passed. |

### P5 — Partition Feasibility and Experimental Optimization

| Item | Content |
|---|---|
| 1. Objective | Decide D-017 for the P3-owned tables with workload-based evidence, using a PoC on a benchmark copy; document a measured rejection if partitioning is not justified. |
| 2. Preconditions | GATE-P4 (best B1 configuration known); D-004 ✔. |
| 3. Inputs | [09](09_PARTITION_FEASIBILITY_PLAN.md), DS-L (DS-XL if approved). |
| 4. Tasks | WO-P3-P5-01. The project-level partition requirement is recorded in the dependency register (DEP-11) and coordinated at P6. |
| 5. Deliverables | DL-12. |
| 6. Acceptance criteria | Elimination evidence captured; B2/B3 measured against the best B1/B4; T-REG-02 passes; D-017 recorded. |
| 7. Verification | Actual Partition Count in plans; hash comparison. |
| 8. Evidence | Plans, CSVs, partition row distribution. |
| 9. Dependencies and risks | R-13, R-08. |
| 10. Owner approval | Project Owner; the team reviews any adoption into the shared schema at P6. |
| 11. Proceed when | GATE-P5 passed. |

### P6 — Formal Integration Contract and Application Integration

| Item | Content |
|---|---|
| 1. Objective | Reconcile P3 with the team schema, approve the integration contract, replace fixtures and test doubles with the real shared objects, promote the adopted P3 objects, verify cross-module queries and transactions, and expose P3 functions in the team application. |
| 2. Preconditions | GATE-P3, GATE-P4, GATE-P5; the team's schema and the members concerned available. WO-P3-P1-02 needs its own preconditions (team approval). WO-P3-P6-01 also needs D-020 and, for its application stage, the approved promotion. D-021 Part B before the first push. |
| 3. Inputs | [12](12_INTEGRATION_PLAN.md) (§2b register, §14 P6 sequence), DL-07, DL-08, DL-10 (DL-11, DL-12 if adopted). |
| 4. Tasks | (1) **WO-P3-P1-02**: team schema reconciliation, contract DL-02 approved, every dependency-register item resolved, promotion procedure, project-level partition coordination. (2) **Promotion WO** (drafted from the agreed procedure; separate approval): shared-schema migration review and promotion of adopted P3 objects. (3) **WO-P3-P6-01**: integration rehearsal in an isolated database built from the team schema (fixtures replaced; T-SCH-01/02, T-INT-03; T-INT-01/02 with the real routines; T-CONC-05; T-REG-03), then the application (T-INT-04). |
| 5. Deliverables | DL-02, DL-13. |
| 6. Acceptance criteria | DL-02 agreed; T-INT-01…04, T-CONC-05, T-REG-03 pass; demo script runs; no business logic duplicated outside the database routines; no shared-database change without the recorded team approval. |
| 7. Verification | Rehearsal test outputs; manual demo plus database cross-check queries. |
| 8. Evidence | Contract approval record; test outputs; screenshots; demo script. |
| 9. Dependencies and risks | R-02, R-03, R-04, R-21, R-26. |
| 10. Owner approval | Project Owner; team (contract, shared database, shared application). |
| 11. Proceed when | GATE-P6 passed. |

### P7 — Integration QA, Concurrency and Performance Verification

| Item | Content |
|---|---|
| 1. Objective | Re-verify everything on the final, integrated configuration (B5/U1) from a clean rebuild and confirm reproducibility. Every test has already run in its own phase; P7 is the final re-verification. |
| 2. Preconditions | GATE-P3…P6. |
| 3. Inputs | All DLs; [11](11_TEST_AND_QA_PLAN.md). |
| 4. Tasks | WO-P3-P7-01. |
| 5. Deliverables | DL-14. |
| 6. Acceptance criteria | Full regression green (functional, concurrency, integration, reconciliation); T-REPRO-01…03 pass; final benchmark B0 vs B5 on DS-L complete. |
| 7. Verification | Clean rebuild from scripts, reseed, run all tests and the benchmark. |
| 8. Evidence | Test outputs; final RUN_IDs. |
| 9. Dependencies and risks | R-07, R-14. |
| 10. Owner approval | Project Owner. |
| 11. Proceed when | GATE-P7 passed. |

### P8 — Final Evidence and Report

| Item | Content |
|---|---|
| 1. Objective | Produce the P3 report section and evidence index, and hand off to the team. |
| 2. Preconditions | GATE-P7. |
| 3. Inputs | All evidence; [13 §3](13_DELIVERABLES_AND_EVIDENCE.md#3-report-section-checklist-for-dl-15). |
| 4. Tasks | WO-P3-P8-01. |
| 5. Deliverables | DL-15. |
| 6. Acceptance criteria | Checklist complete; every number traceable to a RUN_ID; limitations stated; implemented vs optional separated. |
| 7. Verification | Traceability audit (each report number → RUN_ID → raw file). |
| 8. Evidence | Report section; evidence index. |
| 9. Dependencies and risks | R-14, R-19. |
| 10. Owner approval | Project Owner; team for merging into the group report. |
| 11. Completion | GATE-P8 passed, so P3 is complete. |

## 4. Work-order list

Listed in execution order. Identifiers are unchanged; only WO-P3-P3-00 is new (2026-11-08).

| WO | Title | Phase | Status | File |
|---|---|---|---|---|
| WO-P3-BOOT-001 | Planning bootstrap | Pre-P0 | PASSED | [link](work-orders/WO-P3-BOOT-001_PLANNING_BOOTSTRAP.md) |
| WO-P3-P0-01 | Decision freeze and implementation readiness | P0 | PASSED | [link](work-orders/WO-P3-P0-01_DECISION_FREEZE.md) |
| WO-P3-P0-03 | Record P0 decisions and close GATE-P0 | P0 | PASSED (2026-11-07; GATE-P0 closed) | [link](work-orders/WO-P3-P0-03_DECISION_RECORDING.md) |
| WO-P3-P1-01 | Physical schema foundation (four P3-owned tables) | P1 | PASSED (2026-11-08; GATE-P1 closed) | [link](work-orders/WO-P3-P1-01_PHYSICAL_SCHEMA.md) |
| WO-P3-P0-02 | Environment and feature baseline | Before WO-P3-P2-02 | PROPOSED | [link](work-orders/WO-P3-P0-02_ENVIRONMENT_BASELINE.md) |
| WO-P3-P2-01 | Large dataset: deterministic seed generator | P2 | PASSED (2026-11-08; GATE-P2-01 closed) | [link](work-orders/WO-P3-P2-01_SEED_GENERATOR.md) |
| WO-P3-P2-02 | Benchmark harness and baseline capture | P2 | BLOCKED (WO-P3-P0-02, R-27; D-010 now approved T2; measurement-only) | [link](work-orders/WO-P3-P2-02_BASELINE_BENCHMARK.md) |
| WO-P3-P3-00 | Invoice creation (billing) | P3 | **PASSED — functional acceptance** (2026-11-09; criterion 5 transferred to WO-P3-P3-03) | [link](work-orders/WO-P3-P3-00_INVOICE_CREATION.md) |
| WO-P3-P3-01 | Settlement routine | P3 | **PASSED** (2026-11-09; U0 REFERENCE_ONLY completed) | [link](work-orders/WO-P3-P3-01_SETTLEMENT_PROCEDURE.md) |
| WO-P3-P3-02 | Incremental loyalty and tier evaluation | P3 | **PASSED** (Owner, 2026-11-10; §14) | [link](work-orders/WO-P3-P3-02_LOYALTY_AND_TIER.md) |
| WO-P3-P3-03 | UC05 verification and U0 vs U1 benchmark | P3 | **IN_PROGRESS: Part C PASSED (Owner); Part P PENDING / BLOCKED** | [link](work-orders/WO-P3-P3-03_UC05_VERIFICATION.md) |
| WO-P3-P4-01 | UC06 report routines and index experiments | P4 | **IN_PROGRESS: Part F PASSED (Owner); Part X PROPOSED / execution BLOCKED** | [link](work-orders/WO-P3-P4-01_UC06_INDEX_EXPERIMENTS.md) |
| WO-P3-P4-02 | Revenue summary experiment | P4 | PROPOSED | [link](work-orders/WO-P3-P4-02_REVENUE_SUMMARY.md) |
| WO-P3-P5-01 | Partition feasibility and PoC | P5 | PROPOSED | [link](work-orders/WO-P3-P5-01_PARTITION_POC.md) |
| WO-P3-P1-02 | Integration contract | P6 (deferred from P1; D-027) | PROPOSED — execution DEFERRED TO P6 | [link](work-orders/WO-P3-P1-02_INTEGRATION_CONTRACT.md) |
| WO-P3-P6-01 | Integration rehearsal and application integration | P6 | PROPOSED | [link](work-orders/WO-P3-P6-01_APP_INTEGRATION.md) |
| WO-P3-P7-01 | Integration QA, regression and final verification | P7 | PROPOSED | [link](work-orders/WO-P3-P7-01_QA_AND_FINAL_BENCHMARK.md) |
| WO-P3-P8-01 | Evidence, report and handoff | P8 | PROPOSED | [link](work-orders/WO-P3-P8-01_EVIDENCE_AND_HANDOFF.md) |

The promotion WO (moving adopted P3 objects into the canonical shared database; D-025 conditions 6–7) is not yet drafted. It is written at P6 from the procedure that WO-P3-P1-02 agrees.

Each WO is sized for one bounded Claude Code session, or a small number of sessions with a handoff ([P3_MASTER_PROMPT.md §15](../../agent/P3_MASTER_PROMPT.md#15-session-handoff-contract)).

## 5. Dependency changes of 2026-11-08 (D-027)

| WO | Before | After |
|---|---|---|
| WO-P3-P1-02 | P1, parallel; gated WO-P3-P3-01 and the promotion WO | Executed at P6, or before the first §2.2 operation; still gates the promotion WO and WO-P3-P6-01 |
| WO-P3-P2-01 | D-006, D-007, D-008, D-022; seed ownership agreed in DL-02; generated all shared-table data incl. BRANCH_INVENTORY | D-006, D-022; P3 tables only on TEST_ONLY key fixtures; D-007/D-008 only for the optional F002 loyalty-state extension |
| WO-P3-P2-02 | Q-UC05-A/B/C and UC06 queries | Adds Q-BIL-A; Q-UC05-B/C conditional (else baselined in WO-P3-P3-02) |
| WO-P3-P3-00 | — (no billing WO) | New: invoice creation; D-028 |
| WO-P3-P3-01 | WO-P3-P1-02 PASSED; UC01/UC04 hook routines or stand-ins; hook owners' approval; real-routine T-INT-01/02 before GATE-P3 | WO-P3-P3-00 PASSED; contract-only hook test doubles (DEP-05); D-012 provisional (T2); real-routine tests at P6 |
| WO-P3-P3-02 | MEMBER loyalty columns assumed present | F002 TEST_ONLY extension (DEP-02, DEP-03) if not created earlier |
| WO-P3-P3-03 | T-CONC-05 with the UC04 owner; UC04 owner approval | T-CONC-05 moved to WO-P3-P6-01; adds T-CONC-06 |
| WO-P3-P4-01 | D-001 for all reports; T-REG-03; regression registry from DL-02; table owners' approval for IX-08/IX-09 | D-001 only for RPT-05…07; T-REG-03 and IX-11 (shared MEMBER) at P6; IX-08/IX-09 on P3-owned tables evaluated by P3 |
| WO-P3-P5-01 | Task 7 records the project-level partition owner in the contract | Recorded as DEP-11; coordinated in WO-P3-P1-02 at P6 |
| WO-P3-P6-01 | GATE-P3, GATE-P4; D-020; promotion | GATE-P3…P5; WO-P3-P1-02 PASSED; integration rehearsal stage (fixture replacement, T-INT-01…03, T-CONC-05, T-REG-03) before the application stage |
| WO-P3-P7-01 | Name only | Renamed phase; states that P7 re-verifies tests already run |

## 6. Dependency changes of 2026-11-09 (Owner Directive "Urgent Unblock & Core Implementation")

R-27 is a performance-measurement blocker, not a development blocker ([14 R-27 §7](14_RISK_REGISTER.md#7-disposition-2026-11-09-owner-directive-urgent-unblock--core-implementation)). GATE-P2 (WO-P3-P2-02) remains required for formal timing baselines, measured-improvement claims, performance-based index adoption and partition conclusions; it is no longer a precondition of functional P3/P4 work. No WO is approved by this change.

| WO | Before | After |
|---|---|---|
| WO-P3-P2-02 | Gate for all of P3 and P4 | BLOCKED; gates timing baselines and performance decisions only |
| WO-P3-P3-00 | GATE-P2; D-028 | **PASSED (functional)** 2026-11-09: D-028 APPROVED (T2); criterion 5 (creation-cost RUN_ID) transferred to WO-P3-P3-03 criterion 5 / task 3a, which needs R-27 closed and must run before any P4 index adoption |
| WO-P3-P3-01 | GATE-P2; WO-P3-P3-00 PASSED | **PASSED** 2026-11-09 (task 2 U0 completed after D-007 and the D-008 rule were approved) |
| WO-P3-P3-02 | WO-P3-P3-01 PASSED; D-007, D-008, D-009 | **VERIFIED** 2026-11-09 (D-008 rule only; values open; synthetic TEST_ONLY thresholds) |
| WO-P3-P3-03 | WO-P3-P3-02 PASSED; harness | Also owns the transferred invoice-creation cost baseline (task 3a, criterion 5; from WO-P3-P3-00, 2026-11-09) |
| WO-P3-P3-02 | GATE-P2 (through P3) | Functions and tests independent of R-27; task 0 timings DIAGNOSTIC_ONLY until R-27 closes; D-007, D-008, D-009 still open |
| WO-P3-P3-03 | Harness from WO-P3-P2-02 | Concurrency and rollback tests independent of R-27 (T-CONC-06 already PASS ×3); U0/U1 benchmark still blocked |
| WO-P3-P4-01 | GATE-P2; D-010 | Report routines and correctness tests may be prepared independently; index adoption blocked by WO-P3-P2-02 / R-27; D-010 before accepting the revenue semantics |

## 7. Recovered completion of the 2026-11-10 functional exception

[WO-P3-P4-01 §2a](work-orders/WO-P3-P4-01_UC06_INDEX_EXPERIMENTS.md#2a-controlled-scope-amendment-2026-11-10) authorizes Part F before GATE-P2/GATE-P3. Part F is VERIFIED: 78/78 prior run steps plus read-only recovery in §13. D-010 APPROVED T2; P3-02 PASSED by Owner. Earlier dated dependency tables are historical; these statuses supersede their stale decision/acceptance notes. No performance criterion/gate waived. Whole P4-01 IN_PROGRESS; Part X not approved and blocked. P4-02 remains successor after P4-01 completion. Next separately authorized correctness work recommended: P3-03, with performance obligations still blocked. Nothing starts automatically.

**Update 2026-11-10 (Owner Directive "Accept UC06 Functional Results & Execute Integrated Correctness Verification").** P4-01 Part F `PASSED` after a read-only re-check ([ACCEPT-P4-01F](evidence/test-results/ACCEPT-P4-01F__20261110-070518.txt), 27/27). WO-P3-P3-03 split by a limited-scope amendment ([§2a](work-orders/WO-P3-P3-03_UC05_VERIFICATION.md#2a-limited-scope-amendment-2026-11-10)); Part C executed and `VERIFIED` ([P3-03-RUN__20261110-0737](evidence/test-results/P3-03-RUN__20261110-0737.txt), 100/100). Part P (U0/U1, creation-cost baseline, T-PERF-01/02/08, blocking duration) keeps every obligation and stays blocked by R-27 and WO-P3-P2-02. GATE-P3 and GATE-P4 stay open. No next WO started.

**Update 2026-11-10 (3) (Owner Directive "Accept P3 Correctness & Unblock Performance" (Claude Code session of 2026-11-10)).** P3-03 Part C `PASSED` ([ACCEPT-P3-03C](evidence/test-results/ACCEPT-P3-03C__20261110-080412.txt), 13/13). Benchmark path proposed in [design/BENCHMARK_ENVIRONMENT_READINESS.md](design/BENCHMARK_ENVIRONMENT_READINESS.md): BM-1 = instance `MSSQLSERVER01`; next WO for approval: **WO-P3-P0-02 (amended)**, then WO-P3-P2-02, then in order P3-03 Part P, P4-01 Part X, P4-02, P5-01. Nothing started.
