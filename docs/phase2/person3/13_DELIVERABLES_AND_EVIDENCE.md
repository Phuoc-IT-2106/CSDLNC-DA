# 13 — Deliverables and Evidence (Person 3)

| Field | Value |
|---|---|
| Document status | DRAFT — WO-P3-BOOT-001 |
| Date | 2026-11-10 (P4-01 Part F PASSED; P3-03 Part C PASSED) |
| Status of deliverables | DL-01/03 delivered (P1 PASSED); DL-04 delivered (P2-01 PASSED); DL-07 billing/settlement and DL-08 core loyalty accepted in isolation. DL-09: correctness, concurrency, rollback and reconciliation part complete (P3-03 Part C PASSED (Owner), run `P3-03-RUN__20261110-0737`); U0 vs U1 benchmark pending (R-27). **DL-10 functional report portion PASSED (Owner)**, indexes/decisions pending. DL-02 integration, DL-05/06 formal baseline and DL-11…15 remain pending; see readiness report |

## 1. Deliverable register

Implemented paths are identified by status/evidence records; future locations remain planned under D-021 ([05 §13](05_PHYSICAL_DESIGN_PLAN.md#13-proposed-implementation-layout-not-created)).

| ID | Deliverable | Requirements | WO | Location (proposed) | Acceptance criterion | Evidence |
|---|---|---|---|---|---|---|
| DL-01 | P3 physical design table (columns, types, constraints, indexes, derived structures, rationale with source labels) | RQ-A01, RQ-P16 | WO-P3-P1-01 | `docs/phase2/person3/design/PHYSICAL_DESIGN_TABLE.md` | Covers every P3 table/column; every addition cites an APPROVED decision; T-SCH-02 shows zero differences from the DDL | T-SCH-02 output |
| DL-02 | Integration contract (+ shared index registry) | RQ-T01, RQ-T02, RQ-P03 | WO-P3-P1-02 (at P6, D-027) | `docs/phase2/person3/design/INTEGRATION_CONTRACT.md` | All 13 items of [12 §3](12_INTEGRATION_PLAN.md#3-integration-contract-contents-dl-02) filled; approval by the members concerned recorded | Approval record (date, members) |
| DL-03 | DDL scripts for P3 tables, P3 columns and constraints | RQ-A01, RQ-A04, RQ-A13, RQ-P06–P08 | WO-P3-P1-01 | `db/migrations/` (V001, V002; the four P3-owned tables only). Test tools (TEST_ONLY fixtures, build script) live under `tests/db/` and are not part of DL-03 | Clean install passes; constraint negative tests pass | T-REPRO-01, T-SCH-01 outputs |
| DL-04 | Deterministic seed generator + configuration + validation report | RQ-A06, RQ-T03 | WO-P3-P2-01 | `db/seed/` (S001 v1.0, profiles, README); fixture key rows and validation in `tests/db/`; reports in `evidence/test-results/` (`P2-RUN__`, `CHECKSUMS__`, `DATASET-MANIFEST__`, `SEPARATION-P2__`, `GATE-P2-01-RECHECK__`). **Delivered 2026-11-08 (WO-P3-P2-01 `PASSED`, GATE-P2-01 closed)** | DS-M and DS-L generated; ≥ 70,000 rows where required; FK-valid; reproducible | T-SEED-01…03, T-REPRO-02 outputs; row-count table |
| DL-05 | Frozen baseline queries + benchmark harness | RQ-A05 | WO-P3-P2-02 | `db/queries/baseline/`, `db/benchmark/` | Harness produces the manifest and CSV of [10 §4.8](10_SEED_AND_BENCHMARK_PLAN.md#48-result-files-and-run-manifest); baseline files unchanged after capture | File checksums recorded in the manifest |
| DL-06 | Baseline measurements (B0, U0) with plans | RQ-A05, RQ-A10, RQ-A11 | WO-P3-P2-02 | `evidence/benchmark-results/<RUN_ID>/`, `evidence/execution-plans/`, `evidence/screenshots/` | All P3 queries measured on DS-M and DS-L per protocol | RUN_ID folders |
| DL-07 | Invoice creation routine (WO-P3-P3-00) + settlement routine (+ baseline variant U0 + cancel if D-011) | RQ-A07, RQ-A10, RQ-P01, RQ-P03, RQ-P10, RQ-P14 | WO-P3-P3-00, WO-P3-P3-01 | `db/procedures/` | T-F05-01…08, T-F05-16 (if in scope), T-INT-01/02 pass | Test outputs |
| DL-08 | Loyalty lookup + tier evaluation routines (+ tier distribution if in scope) | RQ-A10, RQ-A12, RQ-A18, RQ-P05, RQ-P06 | WO-P3-P3-02 | `db/procedures/` | T-F05-09…15 and T-REC-01/02/04 pass | Test outputs |
| DL-09 | UC05 test suites and results (functional, concurrency, rollback, reconciliation) + U0 vs U1 benchmark | RQ-P01, RQ-P14, RQ-A10 | WO-P3-P3-01…03 | `tests/db/…`; `evidence/test-results/`; `evidence/benchmark-results/` | All UC05 tests pass; T-PERF-01/02/08 evidence complete | Outputs + RUN_IDs |
| DL-10 | Revenue report routines, index scripts (candidates + adopted) and index decision record | RQ-A02, RQ-A05, RQ-A11, RQ-A14–A17 | WO-P3-P4-01 | `db/queries/optimized/`, `db/indexes/`, `docs/phase2/person3/design/INDEX_DECISIONS.md` | Every candidate ADOPTED/REJECTED against [08 §6](08_INDEX_AND_QUERY_PLAN.md#6-adoption-and-rejection-criteria) with evidence links; T-F06-xx, T-REG-01/03 pass | Plans, CSVs, decision record |
| DL-11 | Revenue summary / indexed-view experiment + decision record | RQ-A11 | WO-P3-P4-02 | `db/summary/`, `docs/phase2/person3/design/SUMMARY_DECISION.md` | D-015/D-016 decided with evidence; T-REC-03 passes if adopted | Plans, CSVs, reconciliation output |
| DL-12 | Partition feasibility report + PoC scripts (or measured rejection) | RQ-A04, RQ-A11 | WO-P3-P5-01 | `db/partition-poc/`, `docs/phase2/person3/design/PARTITION_DECISION.md` | D-017 decided against [09 §11](09_PARTITION_FEASIBILITY_PLAN.md#11-decision-criteria); elimination evidence shown | Plans with partition counts, CSVs |
| DL-13 | P3 application features | RQ-A03, RQ-A09, RQ-P15 | WO-P3-P6-01 | `app/` (stack per D-020) | T-INT-04 passes; demo script runs end-to-end | Screenshots, demo script |
| DL-14 | Final regression + final benchmark + reproducibility results | RQ-A05, RQ-P04 | WO-P3-P7-01 | `evidence/` | All tests green; B5 vs B0 measured; T-REPRO-01…03 pass | RUN_IDs, test outputs |
| DL-15 | P3 report section + evidence index + handoff notes | RQ-A19, RQ-A21, RQ-A08 | WO-P3-P8-01 | `docs/phase2/person3/report/` | Report checklist (§3) complete; every number traceable to a RUN_ID | Report section, evidence index |

## 2. Evidence conventions

- Folder structure, RUN_ID format and file naming: [10 §4.8–4.9](10_SEED_AND_BENCHMARK_PLAN.md#48-result-files-and-run-manifest), and [evidence/README.md](evidence/README.md).
- Evidence is never edited after capture. A correction is a new run with a new RUN_ID and a note.
- Every screenshot has a matching raw artifact (`.sqlplan`, raw STATISTICS output or a test log).
- Secrets (passwords, connection strings with credentials) never appear in evidence. Redact them before saving.

## 3. Report section checklist (for DL-15)

The P3 section of the group report must contain:

1. Scope (UC05/UC06 per D-001) and the frequencies used (from S-02, labelled as estimates).
2. Physical design table (DL-01) with the rationale and source label of every addition.
3. Problem 4 solution: incremental aggregation design, with U0 vs U1 evidence (plans, IO/TIME, RUN_IDs).
4. Problem 3 (revenue) solution: index experiments, summary/indexed-view experiment, partition PoC and decision, with B0–B5 evidence.
5. Correctness: concurrency, rollback and reconciliation test results.
6. Write-overhead and storage cost of adopted structures.
7. Application screenshots for P3 functions.
8. Limitations: rules still assumed, excluded refunds (if D-011), dataset scale vs the problem statement, environment.
9. A clear separation between **implemented and measured** results and **optional/unimplemented** research ideas (S-09 extensions such as CDC, In-Memory OLTP, compression).
10. Individual contribution and self-evaluation entries (RQ-A19, RQ-A21).

## Recovered DL-10 functional evidence (2026-11-10)

Five procedures/two functions in `db/procedures/usp_P3_RevenueReports.sql`; T-F06/T-REC-05, UC05 regression and scope checks: [UC06 run](evidence/test-results/UC06-RUN__20261110-0206.txt). [recovery](evidence/test-results/RECOVERY-UC06__20261110-043737.txt) and [targeted retry](evidence/test-results/RECOVERY-UC06-RECHECK__20261110-045109.txt) confirm preserved source/deployment/data. **Part F PASSED (Owner, 2026-11-10) does not complete DL-10**: candidate indexes, decisions and formal performance evidence remain Part X.
