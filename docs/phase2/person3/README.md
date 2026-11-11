# Person 3 — Billing, Loyalty & Revenue (FitLife Hub, Phase 2)

| Field | Value |
|---|---|
| Course / project | CSC12002 Advanced Database Systems, project 2627.ADB.02 (FitLife Hub), team ADB.24C03.12 |
| P3 scope | UC05 invoice settlement, spending aggregation, loyalty points, tier management; UC06 revenue reporting (branch, system, by period). Scope boundaries pending D-001. |
| Status | **UC05 core P3-00/01/02 PASSED; UC06 P4-01 Part F PASSED (Owner); P3-03 Part C (integrated correctness/concurrency) PASSED (Owner).** Whole P3-03 and P4-01 IN_PROGRESS; benchmarks/Part X blocked by R-27/P2-02. See [readiness](16_READINESS_REPORT.md) |
| Last update | 2026-11-10 — recovery and completion of authorized UC06 functional reporting |
| Repository | Canonical: `Phuoc-IT-2106/CSDLNC-DA` (GitHub). **Since the cut-over of 2026-11-07 these documents live only in the clone `C:\Users\DELL\source\repos\CSDLNC-DA` (branch `p3/wo-p3-p1-01`)**; `C:\CSDLNC- DA` is a read-only archive. |

## Start here

- **Agent or new session:** read [../../agent/P3_CONTEXT_INDEX.md](../../agent/P3_CONTEXT_INDEX.md), then follow [../../agent/P3_MASTER_PROMPT.md](../../agent/P3_MASTER_PROMPT.md).
- **Project Owner:** read [16_READINESS_REPORT.md](16_READINESS_REPORT.md), then the approval matrix in [design/P0_FINAL_DECISION_PACKAGE.md](design/P0_FINAL_DECISION_PACKAGE.md#f-approval-matrix).

## Document map

| File | Purpose |
|---|---|
| [00_SOURCE_AND_SCOPE.md](00_SOURCE_AND_SCOPE.md) | Source inventory (S-xx), labels, precedence, 7-vs-6 UC reconciliation, P3 scope |
| [01_REQUIREMENTS_TRACEABILITY.md](01_REQUIREMENTS_TRACEABILITY.md) | Requirements (RQ-xx) → solution → artifact → test → evidence → owner → status |
| [02_GAP_ANALYSIS.md](02_GAP_ANALYSIS.md) | Missing information (G-xx) and what it blocks |
| [03_DECISION_LOG.md](03_DECISION_LOG.md) | Decisions (D-xxx) with alternatives, recommendation and status |
| [04_WORKLOAD_AND_DATA_VOLUME.md](04_WORKLOAD_AND_DATA_VOLUME.md) | Phase 1 workload, projected volumes, per-table profiles, query catalogue (Q-xx) |
| [05_PHYSICAL_DESIGN_PLAN.md](05_PHYSICAL_DESIGN_PLAN.md) | Physical design method, proposed types, constraints, procedures, proposed code layout |
| [06_UC05_BILLING_LOYALTY_PLAN.md](06_UC05_BILLING_LOYALTY_PLAN.md) | Settlement, exactly-once effect, spending, points, tier evaluation, concurrency |
| [07_UC06_REVENUE_PLAN.md](07_UC06_REVENUE_PLAN.md) | Revenue semantics, reports, baseline queries, alternatives, B0–B5 matrix |
| [08_INDEX_AND_QUERY_PLAN.md](08_INDEX_AND_QUERY_PLAN.md) | Candidate index register (IX-xx), evaluation protocol, adoption criteria |
| [09_PARTITION_FEASIBILITY_PLAN.md](09_PARTITION_FEASIBILITY_PLAN.md) | Partition candidates, key/alignment issues, PoC design, decision criteria |
| [10_SEED_AND_BENCHMARK_PLAN.md](10_SEED_AND_BENCHMARK_PLAN.md) | Deterministic seed, dataset tiers (DS-xx), benchmark protocol, evidence format |
| [11_TEST_AND_QA_PLAN.md](11_TEST_AND_QA_PLAN.md) | Test catalogue (T-xx), entry/exit criteria |
| [12_INTEGRATION_PLAN.md](12_INTEGRATION_PLAN.md) | Ownership matrix, shared-dependency interface, dependency register (DEP-xx), contract contents, transaction composition, lock order, P6 sequence |
| [13_DELIVERABLES_AND_EVIDENCE.md](13_DELIVERABLES_AND_EVIDENCE.md) | Deliverables (DL-xx), acceptance criteria, report checklist |
| [14_RISK_REGISTER.md](14_RISK_REGISTER.md) | Risks (R-xx) |
| [15_ROADMAP_AND_WORK_ORDERS.md](15_ROADMAP_AND_WORK_ORDERS.md) | Execution order, phases P0–P8, gates, approval rules, work-order list |
| [16_READINESS_REPORT.md](16_READINESS_REPORT.md) | Current readiness, blockers, next work order |
| [design/P0_FINAL_DECISION_PACKAGE.md](design/P0_FINAL_DECISION_PACKAGE.md) | **Current** P0 decision package: blocker classes, approval bundles, approval matrix, repository readiness |
| [design/P0_DECISION_REVIEW.md](design/P0_DECISION_REVIEW.md) | Historical P0 decision review (2026-11-06; superseded for classification) |
| [SESSION_LOG.md](SESSION_LOG.md) | Chronological session handoff log |
| [work-orders/](work-orders/README.md) | One file per work order (WO-P3-…) |
| [evidence/](evidence/README.md) | Evidence folders (empty until build phases) |

## ID conventions

| Prefix | Meaning | Defined in |
|---|---|---|
| S-xx | Source | 00 |
| RQ-Axx / RQ-Pxx / RQ-Txx | Requirement (assignment / Phase 1 / team integration) | 01 |
| G-xx | Gap | 02 |
| D-xxx | Decision | 03 |
| F-xx | Phase 1 function (F01–F34) | S-02 §5.2 |
| Q-BIL-x / Q-UC05-x / Q-UC06-x | Benchmark query | 04 §6, 07 §5, 10 §4.1 |
| IX-xx | Candidate index | 08 §4 |
| B0–B5 / U0–U1 | Benchmark configuration (UC06 / UC05) | 07 §10, 06 §5 |
| DS-S/M/L/XL | Dataset tier | 10 §3.3 |
| T-xxx-nn | Test | 11 |
| DL-xx | Deliverable | 13 |
| R-xx | Risk | 14 |
| DEP-xx | Shared-interface assumption (interim, until P6) | 12 §2b |
| WO-P3-… | Work order | 15, work-orders/ |

## Classification labels

`REQUIRED_BY_ASSIGNMENT`, `DERIVED_FROM_PHASE1`, `TEAM_DECISION`, `TECHNICAL_RECOMMENDATION`, `ASSUMPTION_PENDING_APPROVAL`. Definitions: [00 §1](00_SOURCE_AND_SCOPE.md#1-classification-labels).

## Golden rules

1. Implementation requires an **APPROVED** work order. Planning documents are not authorization.
2. Recommendations are not requirements until approved.
3. No performance claim without a measured RUN_ID.
4. Never store secrets (including the assignment PDF password) in this repository.
5. Never modify another member's work.
