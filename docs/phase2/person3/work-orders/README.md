# Person 3 — Work Orders

Every work order (WO) is a bounded task for one Claude Code session, or a few sessions with a handoff. **A WO may be executed only when its status is `APPROVED`** ([15 §1](../15_ROADMAP_AND_WORK_ORDERS.md#1-approval-rules)).

**Execution order since 2026-11-08 (Owner Directive "Reprioritize Person 3 Implementation" (2026-11-08, D-027); [15 §2](../15_ROADMAP_AND_WORK_ORDERS.md#2-execution-order-and-dependencies)):** P1 → P2 → P3 → P4 → P5 → P6 → P7 → P8. Identifiers are unchanged; WO-P3-P1-02 keeps its number but is executed at P6, and WO-P3-P3-00 (invoice creation) is new. Rows below are in execution order.

Renumbering on 2026-11-07 (Owner Directive WO-P3-P0-FINAL): WO-P3-P1-01 is now the physical schema foundation and WO-P3-P1-02 the integration contract (the reverse of the 2026-11-06 numbering). Historical records (session log, P0 decision review, WO-P3-P0-01 execution record) keep the old numbers.

| WO | Title | Phase | Mode | Status | Key preconditions |
|---|---|---|---|---|---|
| [WO-P3-BOOT-001](WO-P3-BOOT-001_PLANNING_BOOTSTRAP.md) | Planning bootstrap | Pre-P0 | PLAN_ONLY | PASSED | — |
| [WO-P3-P0-01](WO-P3-P0-01_DECISION_FREEZE.md) | Decision freeze and implementation readiness | P0 | PLAN_ONLY | PASSED | Passed 2026-11-07 (directive WO-P3-P0-FINAL §4) |
| [WO-P3-P0-03](WO-P3-P0-03_DECISION_RECORDING.md) | Record P0 decisions and close GATE-P0 | P0 | PLAN_ONLY | PASSED (2026-11-07; GATE-P0 closed) | WO-P3-P0-01 PASSED ✔; owner/team answers in Section F of the [P0 final decision package](../design/P0_FINAL_DECISION_PACKAGE.md) |
| [WO-P3-P1-01](WO-P3-P1-01_PHYSICAL_SCHEMA.md) | Physical schema foundation (four P3-owned tables; TEST_ONLY key fixtures) | P1 | BUILD_AUTHORIZED | PASSED (2026-11-08; GATE-P1 closed) | GATE-P0 ✔; P1-R1…P1-R8: D-002, D-003, D-004, D-005, D-011, D-013, D-014, D-018, D-021, D-023, D-026 (all approved 2026-11-07); D-025 ✔ |
| [WO-P3-P0-02](WO-P3-P0-02_ENVIRONMENT_BASELINE.md) | Environment and feature baseline / BM-1 readiness | Before WO-P3-P2-02 | BUILD_AUTHORIZED + VERIFY_ONLY (A1-A7 approved 2026-11-10) | **BLOCKED** (2026-11-11: E2 unmet, E6 NOT_RUN) | Probes/DS-L/B0 verified; 14/14 Validate; A6 complete; E6 gate still mandatory |
| [WO-P3-P2-01](WO-P3-P2-01_SEED_GENERATOR.md) | Large dataset: deterministic seed generator (P3 tables on TEST_ONLY key fixtures) | P2 | BUILD_AUTHORIZED | PASSED (2026-11-08; GATE-P2-01 closed) | GATE-P1 ✔; D-006 ✔, D-022 ✔ (F002 deferred) |
| [WO-P3-P2-02](WO-P3-P2-02_BASELINE_BENCHMARK.md) | Benchmark harness and baseline capture | P2 | BUILD_AUTHORIZED + VERIFY_ONLY | BLOCKED / not approved | P2-01 and D-010 approved; A7 choices recorded; BM-1 probes/DS-L/B0 verified; P0-02 acceptance and passing E6 still missing, R-27 OPEN |
| [WO-P3-P3-00](WO-P3-P3-00_INVOICE_CREATION.md) | Invoice creation (billing) | P3 | BUILD_AUTHORIZED | **PASSED — functional acceptance** (2026-11-09; Owner conditional acceptance after verification; criterion 5 transferred to WO-P3-P3-03) | D-028 ✔ (T2) |
| [WO-P3-P3-01](WO-P3-P3-01_SETTLEMENT_PROCEDURE.md) | Settlement routine | P3 | BUILD_AUTHORIZED | **PASSED** (2026-11-09; U0 REFERENCE_ONLY done, T-F05-36/37 PASS, code search recorded; U0/U1 timing stays in WO-P3-P3-03) | WO-P3-P3-00 ✔; D-006 ✔, D-012 ✔ (T2), D-019 ✔ (T2); F002 points-only ✔; hook test doubles ✔. Not R-27 |
| [WO-P3-P3-02](WO-P3-P3-02_LOYALTY_AND_TIER.md) | Incremental loyalty and tier evaluation | P3 | BUILD_AUTHORIZED | **PASSED** (Owner, 2026-11-10; §14; historical 62/62 run valid) | WO-P3-P3-01; D-006, D-007, D-008, D-009, D-024; F002 |
| [WO-P3-P3-03](WO-P3-P3-03_UC05_VERIFICATION.md) | UC05 verification and U0 vs U1 benchmark | P3 | BUILD_AUTHORIZED (harness) + VERIFY_ONLY | **Whole WO IN_PROGRESS; Part C PASSED** (Owner, 2026-11-10; run `P3-03-RUN__20261110-0737`, 100/100); Part P PENDING / BLOCKED (R-27, P2-02) | WO-P3-P3-02 ✔; limited-scope amendment §2a |
| [WO-P3-P4-01](WO-P3-P4-01_UC06_INDEX_EXPERIMENTS.md) | UC06 report routines and index experiments | P4 | BUILD_AUTHORIZED + VERIFY_ONLY | **Whole WO IN_PROGRESS; Part F PASSED** (Owner, 2026-11-10); Part X PROPOSED / execution BLOCKED | Part F: D-010 approved T2 and gate exception §2a. Part X: own approval, P2-02/R-27 and creation-cost baseline |
| [WO-P3-P4-02](WO-P3-P4-02_REVENUE_SUMMARY.md) | Revenue summary experiment | P4 | BUILD_AUTHORIZED + VERIFY_ONLY | PROPOSED | WO-P3-P4-01; WO-P3-P3-01 |
| [WO-P3-P5-01](WO-P3-P5-01_PARTITION_POC.md) | Partition feasibility and PoC | P5 | BUILD_AUTHORIZED + VERIFY_ONLY | PROPOSED | GATE-P4 |
| [WO-P3-P1-02](WO-P3-P1-02_INTEGRATION_CONTRACT.md) | Integration contract | **P6** (deferred from P1, D-027) | PLAN_ONLY | PROPOSED — execution DEFERRED TO P6 | GATE-P5 or a 15 §2.2 trigger; D-002, D-005, D-012, D-014, D-021, D-026; D-001 owners named; team approval |
| [WO-P3-P6-01](WO-P3-P6-01_APP_INTEGRATION.md) | Integration rehearsal and application integration | P6 | BUILD_AUTHORIZED | PROPOSED | GATE-P3…P5; WO-P3-P1-02; D-020; approved promotion (stage B) |
| [WO-P3-P7-01](WO-P3-P7-01_QA_AND_FINAL_BENCHMARK.md) | Integration QA, regression and final verification | P7 | VERIFY_ONLY | PROPOSED | GATE-P3…P6 |
| [WO-P3-P8-01](WO-P3-P8-01_EVIDENCE_AND_HANDOFF.md) | Evidence, report and handoff | P8 | PLAN_ONLY (documentation) | PROPOSED | GATE-P7 |

## Template sections (every WO)

Header (status, phase, mode, approver, approval record, target database) · 1 Objective · 2 Preconditions · 3 Inputs · 4 Tasks · 5 Out of scope · 6 Deliverables and locations · 7 Acceptance criteria · 8 Verification · 9 Evidence · 10 Dependencies and risks · 11 Approval requirements · 12 Exit and next step · 13 Execution record.

## Status changes

Statuses follow master prompt §4. Only the Project Owner sets `APPROVED` and `PASSED` (PASSED = every mandatory acceptance criterion met **and** the approval gate passed). The executing session may set `IN_PROGRESS`, `BLOCKED`, `FAILED` and `VERIFIED` (VERIFIED = evidence checked against the acceptance criteria), and fills §13. Test results use `PASS`, `FAIL` or `NOT_RUN` (with reason and impact).
