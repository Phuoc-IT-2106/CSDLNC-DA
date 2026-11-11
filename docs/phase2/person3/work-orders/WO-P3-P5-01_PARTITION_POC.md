# WO-P3-P5-01 — Partition Feasibility and Proof of Concept

| Field | Value |
|---|---|
| Status | PROPOSED |
| Phase | P5 — Partition Feasibility and Experimental Optimization |
| Mode | BUILD_AUTHORIZED (PoC on a benchmark copy only) + VERIFY_ONLY |
| Approver | Project Owner (the team reviews any adoption proposed for the shared schema, at P6) |
| Approval record | — |
| Target database | Isolated benchmark database per D-025; **a benchmark copy table only, never the shared INVOICE table** |
| Revision | 2026-11-08 (Owner Directive "Reprioritize Person 3 Implementation" (2026-11-08, D-027)): project-level partition coordination recorded as DEP-11 and carried out at P6; no team prerequisite |

## 1. Objective

Decide D-017 with workload-based evidence for the P3-owned tables (09 §3: INVOICE is the only candidate; the other three are rejected with their reasons): is partitioning INVOICE by the recognition timestamp justified by the scaled volumes, access patterns, expected partition elimination, index and primary-key compatibility, maintenance cost and measured behaviour? Provide the partition scripts and analysis the course requires (RQ-A04, RQ-A11), whether the outcome is adoption or rejection.

## 2. Preconditions

GATE-P4 passed (best B1/B4 configuration known); D-004 settled (key column); DS-XL generation approved if it is to be used.

## 3. Inputs

[09_PARTITION_FEASIBILITY_PLAN.md](../09_PARTITION_FEASIBILITY_PLAN.md); S-08 p12–18; the environment report.

## 4. Tasks

1. Create the benchmark copy table and load DS-L (and DS-XL if approved).
2. Partition function (RANGE RIGHT, monthly, empty partitions at both ends), scheme (one filegroup, justified) and the partitioned copy, following [09 §10](../09_PARTITION_FEASIBILITY_PLAN.md#10-proof-of-concept-design-wo-p3-p5-01).
3. B2 (partition only) and B3 (partition + aligned best index): run Q-UC06-A/B/C/D, a PK lookup and a settlement-like update (row movement) with the standard protocol.
4. Capture Actual Partition Count / partitions accessed in plans; row distribution per partition.
5. T-REG-02 hash comparison; T-PERF-07.
6. Apply the decision criteria of [09 §11](../09_PARTITION_FEASIBILITY_PLAN.md#11-decision-criteria); write `docs/phase2/person3/design/PARTITION_DECISION.md`; update D-017 (owner approval).
7. If INVOICE partitioning is rejected: document the rejection with evidence, and record in the dependency register (DEP-11) that the project-level partition requirement must be covered by another member; the coordination itself happens in WO-P3-P1-02 at P6 (master prompt §8). P3 does not implement another member's partition design.

## 5. Out of scope

Partitioning any shared table (needs a separate WO after D-017 approval; D-025 conditions 6–7); multiple filegroups unless justified.

## 6. Deliverables and locations

DL-12: `db/partition-poc/`, `docs/phase2/person3/design/PARTITION_DECISION.md`; evidence in `evidence/`.

## 7. Acceptance criteria

1. The plans show partition elimination (or its absence) explicitly for every target query.
2. B2/B3 are compared with B0 and the best B1/B4 on the same data and parameters.
3. Write cost with row movement is measured.
4. D-017 is recorded with the criteria table; the PoC script runs cleanly from an empty database.

## 8. Verification

T-REG-02; re-run of the PoC script on a fresh database.

## 9. Evidence

Plans with partition information, CSVs, the partition distribution output and the decision record.

## 10. Dependencies and risks

R-13, R-08.

## 11. Approval requirements

WO approval; DS-XL approval if used; the team for any shared-schema adoption; separate authorization for commits.

## 12. Exit and next step

GATE-P5. Next: P6, starting with WO-P3-P1-02 (integration contract).

## 13. Execution record

_(filled by the executing session)_
