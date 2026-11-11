# WO-P3-P4-02 — Revenue Summary Experiment

| Field | Value |
|---|---|
| Status | PROPOSED |
| Phase | P4 — Revenue Reporting and Index Optimization |
| Mode | BUILD_AUTHORIZED (experiment structures) + VERIFY_ONLY |
| Approver | Project Owner (the team reviews any summary proposed for promotion, at P6) |
| Approval record | — |
| Target database | Benchmark databases per D-025 |

## 1. Objective

Decide D-015 (summary structure) and D-016 (maintenance mechanism) with measured evidence. This answers the "summary table or View/Trigger" part of S-01 Problem 3.

## 2. Preconditions

WO-P3-P4-01 PASSED (the best index configuration is known); WO-P3-P3-01 PASSED (the settlement path exists for maintenance and write-overhead tests).

## 3. Inputs

[07 §7](../07_UC06_REVENUE_PLAN.md#7-aggregation-alternatives); [03 D-015, D-016](../03_DECISION_LOG.md); the environment report (indexed-view behaviour in this edition).

## 4. Tasks

1. Build alternative A3 (branch × day summary table) with the maintenance option chosen for evaluation (inside settlement, or a trigger) and an initial load from source.
2. Build alternative A5 (indexed view) if the environment probe showed it is usable. Record whether NOEXPAND is needed.
3. Measure RPT-01…RPT-04 on B4 variants vs B0 and the best B1 (T-PERF-03…T-PERF-05).
4. Measure write overhead on settlement (T-PERF-06) and concurrency on the same branch-day row (T-CONC-03).
5. Reconciliation T-REC-03; regression T-REG-01.
6. Write `docs/phase2/person3/design/SUMMARY_DECISION.md`; update D-015 and D-016 (owner approval) and the related documents.

## 5. Out of scope

Partitioning; application work; creating the summary structure in the canonical shared database (adoption = recommendation for promotion; D-025 conditions 6–7).

## 6. Deliverables and locations

DL-11: `db/summary/`, `docs/phase2/person3/design/SUMMARY_DECISION.md`; evidence in `evidence/`.

## 7. Acceptance criteria

1. Each alternative tested has plans, IO/TIME, write overhead and reconciliation results.
2. D-015/D-016 recorded as APPROVED or REJECTED with evidence (adoption uses the thresholds of [08 §6](../08_INDEX_AND_QUERY_PLAN.md#6-adoption-and-rejection-criteria), applied to the summary).
3. If adopted: T-REC-03 and T-CONC-03 pass, and settlement tests T-F05-05…T-F05-08 still pass.

## 8. Verification

Reconciliation over the full DS-L range; hash comparison with the oracle.

## 9. Evidence

RUN_IDs, plans, the reconciliation output and the decision record.

## 10. Dependencies and risks

R-16, R-11, R-09.

## 11. Approval requirements

WO approval; the team for adoption into the shared schema; separate authorization for commits.

## 12. Exit and next step

GATE-P4. Next: WO-P3-P5-01.

## 13. Execution record

_(filled by the executing session)_
