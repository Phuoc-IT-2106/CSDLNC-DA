# WO-P3-P1-02 — Integration Contract

| Field | Value |
|---|---|
| Status | PROPOSED |
| Execution | **DEFERRED TO P6** (D-027, 2026-11-08): starts at the beginning of P6, or immediately before the first operation that requires team integration ([15 §2.2](../15_ROADMAP_AND_WORK_ORDERS.md#22-operations-that-require-team-integration-trigger-for-wo-p3-p1-02)), whichever comes first. Not `PASSED`, `CANCELLED` or completed. |
| Phase | P6 — Formal Integration Contract and Application Integration (identifier kept from P1) |
| Mode | PLAN_ONLY (documentation and team agreement) |
| Approver | Project Owner + the members concerned (UC01, UC04 and profile owners) |
| Approval record | — |
| Target database | None |

**Revision record.** Created on 2026-11-06 as WO-P3-P1-01. Renumbered to WO-P3-P1-02 on 2026-11-07 (Owner Directive WO-P3-P0-FINAL): the physical schema foundation became [WO-P3-P1-01](WO-P3-P1-01_PHYSICAL_SCHEMA.md) and no longer waits for this contract. The schema-related contract items (types, names, status literals, column ownership) are fixed by decisions D-002, D-005, D-014, D-021 and D-026 and by the P1 DDL; this WO records them and agrees the rest. It runs in parallel with WO-P3-P1-01 and must be PASSED before WO-P3-P3-01 (settlement) and before the promotion step. **Revised 2026-11-08 (Owner Directive "Reprioritize Person 3 Implementation" (2026-11-08, D-027)):** the identifier and the requirements are kept; execution is deferred to P6. It is no longer a prerequisite of any P2–P5 work order (WO-P3-P3-01 now uses contract-only test doubles and a provisional D-012). It remains a prerequisite of the promotion WO and of WO-P3-P6-01, and of every operation listed in 15 §2.2. Until it runs, the shared-interface assumptions are kept in the dependency register ([12 §2b](../12_INTEGRATION_PLAN.md#2b-dependency-register-interim-assumptions-until-p6)).

## 1. Objective

Produce and get agreement on the integration contract (DL-02) that fixes ownership, shared types, settlement orchestration, transaction rules, lock order, error ranges, SET options, migration order, seed ownership and the shared index registry.

## 2. Preconditions

GATE-P5 passed (start of P6), or a 15 §2.2 operation is imminent; GATE-P0 passed ✔; D-002, D-005, D-012, D-014, D-021, D-026 APPROVED; D-001 APPROVED or at least the settlement orchestrator and the F29/F30 owners named; D-025 APPROVED ✔ (2026-11-06; its conditions become part of the contract). Recorded team approval is required for the shared items (approval rule 3).

## 3. Inputs

[12_INTEGRATION_PLAN.md](../12_INTEGRATION_PLAN.md) (§2a interface, §2b dependency register, §14 P6 sequence); approved decisions; the V001/V002 migrations and DL-01 from WO-P3-P1-01; the P2–P5 deliverables and evidence (routines, adopted indexes, partition decision); other members' schemas (to be requested).

## 4. Tasks

1. Draft `docs/phase2/person3/design/INTEGRATION_CONTRACT.md` covering all 13 items of [12 §3](../12_INTEGRATION_PLAN.md#3-integration-contract-contents-dl-02).
2. Collect other members' high-frequency queries on shared tables for the regression registry (T-REG-03).
3. Review with the members concerned; record the agreed version and date.
4. Update [12](../12_INTEGRATION_PLAN.md), [06](../06_UC05_BILLING_LOYALTY_PLAN.md) and [08 §9](../08_INDEX_AND_QUERY_PLAN.md#9-coordination-with-other-members) to point to the agreed contract.
4a. **Formal schema reconciliation:** compare the team schema with the P3 assumptions; confirm or change every row of the dependency register (12 §2b); record each difference as a contract change with the affected P3 tests to re-run. Agree the billing-interface callers (D-028) and the project-level partition owner (DEP-11, master prompt §8).
5. Record the D-025 conditions in the contract, and agree the **promotion procedure**: how an object adopted in P3 experiments reaches the canonical shared database (team-approved migration, reviewer, separate authorization). Nothing propagates automatically (D-025 conditions 6–7).

## 5. Out of scope

Writing DDL or routines; editing other members' files.

## 6. Deliverables and locations

DL-02: `docs/phase2/person3/design/INTEGRATION_CONTRACT.md` (version 1.0 when agreed).

## 7. Acceptance criteria

1. All 13 contract items filled; no "TBD" for items that block UC05 (P3 phase) or integration.
2. Agreement recorded (members, date, reference).
3. Settlement orchestration owner named.
4. Regression query registry contains at least the other members' queries on INVOICE, INVOICE_SERVICE_ITEM and MEMBER (or an explicit statement that none exist yet).

## 8. Verification

Documentation audit (links, IDs). Consistency check: contract types equal the D-014 decision; lock order equals [06 §4.9](../06_UC05_BILLING_LOYALTY_PLAN.md#49-concurrent-settlement-handling).

## 9. Evidence

Agreement reference; contract change log.

## 10. Dependencies and risks

R-02, R-03, R-04.

## 11. Approval requirements

Project Owner and the members concerned.

## 12. Exit and next step

Next: the promotion WO (drafted from the agreed procedure) and WO-P3-P6-01 (integration rehearsal, then application). _(Until 2026-11-08: "WO-P3-P3-01 (after GATE-P2) uses the agreed orchestration interface"; superseded by D-027.)_

## 13. Execution record

_(filled by the executing session)_
