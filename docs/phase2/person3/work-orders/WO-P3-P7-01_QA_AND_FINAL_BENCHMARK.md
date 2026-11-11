# WO-P3-P7-01 — QA, Regression and Final Performance Verification

| Field | Value |
|---|---|
| Status | PROPOSED |
| Phase | P7 — Integration QA, Concurrency and Performance Verification |
| Mode | VERIFY_ONLY |
| Approver | Project Owner |
| Approval record | — |
| Target database | Fresh test and benchmark databases (per D-025) rebuilt from the team schema scripts |

## 1. Objective

Re-verify the complete P3 deliverable on the final, integrated configuration (B5/U1) from a clean rebuild, and confirm reproducibility. Every test has already run in the WO that built its object (P2–P6); P7 is the final re-verification, not the first run (D-027).

## 2. Preconditions

GATE-P3, GATE-P4, GATE-P5 and GATE-P6 passed.

## 3. Inputs

All DLs; [11](../11_TEST_AND_QA_PLAN.md); [10](../10_SEED_AND_BENCHMARK_PLAN.md).

## 4. Tasks

1. Clean install in an isolated database from the approved shared schema and migrations plus the P3 scripts (T-REPRO-01; D-025 condition 2), and reseed DS-L (T-REPRO-02). Checks against the canonical shared database are read-only.
2. Run the full functional, concurrency, integration, reconciliation and regression suites.
3. Final benchmark: B0 vs B5 for UC06; U0 vs U1 for UC05; on DS-L (and DS-M) with fresh RUN_IDs.
4. T-REPRO-03: repeat one configuration on another day; compare.
5. Compile the final results table, filled only from measured RUN_IDs.
6. Update [16](../16_READINESS_REPORT.md) and [SESSION_LOG.md](../SESSION_LOG.md).

## 5. Out of scope

New features or optimisations. Defects found here are fixed only under a WO amendment approved by the Project Owner.

## 6. Deliverables and locations

DL-14 in `evidence/`.

## 7. Acceptance criteria

1. All in-scope tests pass.
2. T-REPRO-01…03 pass.
3. The final benchmark tables are complete, with RUN_IDs and plans.

## 8. Verification

Independent re-run of a sample of the tests by the Project Owner, or in a second session.

## 9. Evidence

Test outputs; final RUN_ID folders.

## 10. Dependencies and risks

R-07, R-14.

## 11. Approval requirements

WO approval; separate authorization for commits.

## 12. Exit and next step

GATE-P7. Next: WO-P3-P8-01.

## 13. Execution record

_(filled by the executing session)_
