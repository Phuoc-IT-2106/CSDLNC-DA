# WO-P3-P6-01 — Integration Rehearsal and Application Integration

| Field | Value |
|---|---|
| Status | PROPOSED |
| Phase | P6 — Formal Integration Contract and Application Integration |
| Mode | BUILD_AUTHORIZED |
| Approver | Project Owner; the team (shared application) |
| Approval record | — |
| Target database | Stage A: an isolated integration-rehearsal database built from the team schema and migrations (D-025 conditions 2–3). Stage B: the canonical shared team database (D-025 condition 1), execute and read only unless a modification is separately authorized (D-025 condition 7). |
| Revision | 2026-11-08 (Owner Directive "Reprioritize Person 3 Implementation" (2026-11-08, D-027)): stage A added (fixture and test-double replacement, T-SCH-01/02, T-INT-01…03, T-CONC-05, T-REG-03, cross-module checks), moved here from P1, P3 and P4 |

## 1. Objective

Stage A: verify P3 against the real shared schema and the other members' routines and queries. Stage B: expose the P3 functions in the team application (RQ-A03, RQ-A09): create invoice (as called by the sale flows), confirm payment, loyalty view, revenue reports, tier evaluation (admin), and tier distribution if in scope.

## 2. Preconditions

GATE-P3, GATE-P4 and GATE-P5 passed; **WO-P3-P1-02 PASSED** (contract DL-02 agreed); the team schema and the other members' hook routines available (stage A); D-020 APPROVED (stage B); the team application skeleton exists, with its conventions documented; the adopted P3 objects (tables, columns, routines, indexes) are already in the canonical shared database through a **separately approved promotion WO** (proposed in the P0 review; D-025 condition 7).

## 3. Inputs

[12 §10](../12_INTEGRATION_PLAN.md#10-application-integration-pending-d-020); DL-07, DL-08, DL-10 (and DL-11 if adopted); the integration contract.

## 4. Tasks

Stage A (isolated rehearsal):

A1. Build the rehearsal database from the team schema and migrations plus the P3 scripts; replace the TEST_ONLY fixtures and the hook test doubles (D-026 condition 9).
A2. Re-run T-SCH-01, T-SCH-02 and T-INT-03; re-run the P3 suites affected by any contract change.
A3. T-INT-01 and T-INT-02 with the real entitlement and inventory routines; T-CONC-05 with the UC04 owner; T-REG-03 with the registered queries of other members; cross-module query and transaction checks.

Stage B (after the promotion WO; application):

1. Implement P3 screens/endpoints calling the database routines (no business logic duplicated in the application).
2. Apply the role restrictions (RQ-P15) agreed with the team.
3. Make sure the connection SET options satisfy filtered-index/indexed-view requirements ([08 §7](../08_INDEX_AND_QUERY_PLAN.md#7-query-writing-rules)).
4. Handle the result codes and the deadlock-retry policy at the application boundary ([06 §4.3](../06_UC05_BILLING_LOYALTY_PLAN.md#43-exactly-once-business-effect)).
5. T-INT-04: screenshots plus database cross-check queries; write a demo script.

## 5. Out of scope

Changing database routines (needs a WO amendment); caching of payment or loyalty state.

## 6. Deliverables and locations

DL-13: `app/` (per D-020/D-021); screenshots in `evidence/screenshots/APP__*`.

## 7. Acceptance criteria

0. Stage A: T-SCH-01, T-SCH-02, T-INT-01, T-INT-02, T-INT-03, T-CONC-05 and T-REG-03 pass on the rehearsal database.
1. T-INT-04 passes for every P3 feature.
2. The demo script runs end-to-end on the integration database.
3. No credentials are stored in the repository.

## 8. Verification

Manual walkthrough recorded with screenshots; cross-check queries show the same values.

## 9. Evidence

Screenshots, the demo script and the cross-check outputs.

## 10. Dependencies and risks

R-21, R-12, R-20.

## 11. Approval requirements

WO approval; team agreement on the shared application; separate authorization for commits and for any dependency installation.

## 12. Exit and next step

GATE-P6. Next: WO-P3-P7-01.

## 13. Execution record

_(filled by the executing session)_
