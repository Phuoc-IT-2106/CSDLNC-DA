# Person 3 Technical Handover — Billing, Loyalty & Revenue (UC05/UC06)

| Field | Value |
|---|---|
| Project | FitLife Hub, CSC12002 Advanced Database Systems, team ADB.24C03.12, Phase 2 |
| Scope of this file | Person 3 only (UC05 Billing & Loyalty, UC06 Revenue Reporting) |
| State recorded | 2026-11-11, reconciled against the repository, evidence files and a read-only SQL Server check |
| Repository | `https://github.com/Phuoc-IT-2106/CSDLNC-DA`, branch **`p3/wo-p3-p1-01`** (commit `496176c`, pushed). `main` still holds only the initial README (`792a85e`) |
| Operating contract | [P3_MASTER_PROMPT.md](../../agent/P3_MASTER_PROMPT.md) v2.0 (default mode PLAN_ONLY); [P3_CONTEXT_INDEX.md](../../agent/P3_CONTEXT_INDEX.md) |
| Companion documents | [Benchmark runbook](design/BENCHMARK_RUNBOOK.md) · [Prompt playbook](PROMPT_PLAYBOOK.md) · [Remaining-work roadmap](REMAINING_WORK_ROADMAP.md) |

Person 3 is **not complete**. Functional database work (schema, dataset, invoice creation, settlement, loyalty, revenue reports, concurrency) is accepted. Every performance obligation (formal baseline, index, summary and partition experiments) and all of P6–P8 (integration, application, QA, report) remain open.

---

## Start Here (new developer or new Claude Code session)

1. Work only in the clone (`<repo>` below), branch `p3/wo-p3-p1-01`. `C:\CSDLNC- DA` on the original laptop is a read-only archive; never edit it.
2. Read, in order: this file → [16_READINESS_REPORT.md](16_READINESS_REPORT.md) §7–§8 → the last entry of [SESSION_LOG.md](SESSION_LOG.md) → the work order you are asked to run in [work-orders/](work-orders/README.md).
3. Check the **"Corrections to older records"** box below. Some status documents predate the last E6 run and the GitHub push.
4. Nothing runs without an **APPROVED** work order or an explicit Owner instruction in the session (master prompt §3, roadmap [15 §1](15_ROADMAP_AND_WORK_ORDERS.md#1-approval-rules)). Commits, pushes, merges, configuration changes and new databases each need separate authorization.
5. For a ready-made session prompt, use the [Prompt playbook](PROMPT_PLAYBOOK.md). For anything that measures time, use the [Benchmark runbook](design/BENCHMARK_RUNBOOK.md).

> **Corrections to older records (verified 2026-11-11)**
>
> 1. **Repository:** older entries say "nothing committed" or "330/339 untracked paths". This is out of date. All work was committed as `496176c` ("Add Person 3 Phase 2 SQL implementation, tests and evidence", 364 files) and pushed to `origin/p3/wo-p3-p1-01` on 2026-11-11 10:12 (+07:00), on the Owner's explicit request ([SESSION_LOG](SESSION_LOG.md), last entry). The working tree is clean. The repository is **public**; D-021 Part B (visibility, team conventions) is still PROPOSED.
> 2. **E6 on BM-1:** [ENVIRONMENT_P0.md](design/ENVIRONMENT_P0.md), [WO-P3-P0-02](work-orders/WO-P3-P0-02_ENVIRONMENT_BASELINE.md) §13.1, [14](14_RISK_REGISTER.md) §12 and [16](16_READINESS_REPORT.md) §8 say "E6 NOT_RUN on BM-1". An E6 run **was** recorded afterwards: [R-27-CLOSE__20261111-0235.txt](evidence/test-results/R-27-CLOSE__20261111-0235.txt), server `localhost\MSSQLSERVER01`, 02:35–02:47 UTC, result **`R-27-CLOSE_RESULT: FAIL (4 failing items)`**. It ran with BM-1 memory already restored to 16 MB / unlimited (A3 floor **not** active) and the Balanced plan (A4 **not** applied), and without the standalone runner (no `E6-BM1__*` runner or lock files exist). It is diagnostic evidence, **not** a baseline. R-27 stays OPEN.
> 3. **Live SQL Server state (read-only check, 2026-11-11):** both instances run 17.0.1000.7 Standard Developer with `min/max server memory` 16 / 2,147,483,647 MB. BM-1 holds only `FitLife_P3_P2` (DS-L, V001+V002+**V003**, 0 non-PK indexes, 324,000 invoices). The default instance holds `FitLife_P3_P1`, `FitLife_P3_P2` (DS-L **without** V003), `FitLife_P3_UC05`, `FitLife_P3_UC05L`, and four unrelated user databases that must never be touched.

---

## A. Project overview

**FitLife Hub** is a multi-branch fitness-centre database (SQL Server). Phase 2 covers physical design, implementation, optimisation, benchmarking and an application. The group grade is weighted conceptual 20% / logical 10% / physical 50% / application 20% (see §F for the evidence status of these weights).

**Person 3 owns UC05 and UC06:**

| Use case | Content | Main functions (Phase 1 IDs, daily frequency estimate from [04 §2](04_WORKLOAD_AND_DATA_VOLUME.md)) |
|---|---|---|
| UC05 Billing & Loyalty | Invoice creation (billing), payment settlement and cancellation, monthly spending aggregation, loyalty points, periodic tier evaluation (Silver/Gold/Platinum), loyalty lookup | F05 create invoice 900/day; F06 confirm payment 900/day; F20 spending/points 900/day; F21 lookup 1,200/day; F22 tier batch 1/day |
| UC06 Revenue Reporting | Branch revenue by day/month/quarter/year, system revenue, branch comparison; index, summary and partition experiments | F27 branch revenue 120/day; F28 system revenue 20/day |

**Ownership boundary (Owner matrix, [WO-P3-P1-01 §3.2](work-orders/WO-P3-P1-01_PHYSICAL_SCHEMA.md#32-scope-matrix-directive-strict-person-3-scope-enforcement)):**

- **P3-owned tables:** `INVOICE`, `INVOICE_SERVICE_ITEM`, `INVOICE_PRODUCT_ITEM`, `MEMBER_MONTHLY_SPENDING`.
- **Shared dependencies (other members own them):** `MEMBER` (P3 writes only `CurrentPoints`, `Tier_ID`), `MEMBER_TIER`, `BRANCH`, `EMPLOYEE`, `SERVICE_PLAN`, `PRODUCT`. In P3 databases they exist only as **TEST_ONLY key fixtures**.
- **Out of scope:** check-in, PT, payroll, assignment history, registration, inventory workflows, catalogue/branch administration, other members' UIs.

**Technology:** Microsoft SQL Server 2025 (17.0.1000.7, Standard Developer, EngineEdition 2), databases at compatibility level **160**, Windows authentication, `sqlcmd` and Windows PowerShell 5.1 (`System.Data.SqlClient`). Money `DECIMAL(18,2)`, timestamps stored in UTC (`DATETIME2(3)`), reporting on the Asia/Ho_Chi_Minh calendar (D-014). Business logic lives in stored procedures so any application stack can call it (R-21).

---

## B. Current state (from work-order records and evidence)

Status vocabulary: `PASSED` (Owner accepted), `VERIFIED` (agent checked evidence; Owner not yet), `IN_PROGRESS`, `BLOCKED`, `PROPOSED` (written, not approved), `NOT_STARTED` (no execution yet).

| Work order | Status | Verified evidence | Remaining work |
|---|---|---|---|
| WO-P3-BOOT-001, P0-01, P0-03 | PASSED (GATE-P0 closed 2026-11-07) | Decision log, P0 package | — |
| [WO-P3-P0-02](work-orders/WO-P3-P0-02_ENVIRONMENT_BASELINE.md) Environment & feature baseline (BM-1) | **BLOCKED** | Probes [ENV-P0__20261110-083101_Probes](evidence/test-results/ENV-P0__20261110-083101_Probes.txt); BM-1 DS-L build [P2-RUN__DS-L__20261110-0831_BM1](evidence/test-results/P2-RUN__DS-L__20261110-0831_BM1.txt); validation 14/14 [ENV-P0__20261111-014844_Validate](evidence/test-results/ENV-P0__20261111-014844_Validate.txt); E6 FAIL [R-27-CLOSE__20261111-0235](evidence/test-results/R-27-CLOSE__20261111-0235.txt) | Acceptance criterion 7 (E6 PASS) unmet; Owner decision on the next E6 attempt |
| [WO-P3-P1-01](work-orders/WO-P3-P1-01_PHYSICAL_SCHEMA.md) Physical schema | PASSED (2026-11-08) | T-SCH-01/02, T-REPRO-01 (`*__20261107-1154.txt`), [GATE-P1-RECHECK](evidence/test-results/GATE-P1-RECHECK__20261108-0337.txt) | — |
| [WO-P3-P1-02](work-orders/WO-P3-P1-02_INTEGRATION_CONTRACT.md) Integration contract | PROPOSED, deferred to P6 (D-027) | Dependency register [12 §2b](12_INTEGRATION_PLAN.md#2b-dependency-register-interim-assumptions-until-p6) | Whole WO (team) |
| [WO-P3-P2-01](work-orders/WO-P3-P2-01_SEED_GENERATOR.md) Dataset DS-S/M/L | PASSED (2026-11-08) | `P2-RUN__*`, `CHECKSUMS__*`, `DATASET-MANIFEST__*`; DS-L run C = `26ABB277…CA1F` | — |
| [WO-P3-P2-02](work-orders/WO-P3-P2-02_BASELINE_BENCHMARK.md) Formal baseline B0 | **BLOCKED**, not approved | None (no B0 RUN_ID; `evidence/benchmark-results/` is empty) | Whole WO; needs P0-02 PASSED (E6 PASS) and its own approval |
| [WO-P3-P3-00](work-orders/WO-P3-P3-00_INVOICE_CREATION.md) Invoice creation | PASSED (functional, 2026-11-09) | [UC05-RUN__20261109-1446](evidence/test-results/UC05-RUN__20261109-1446.txt) | Creation-cost baseline moved to P3-03 Part P |
| [WO-P3-P3-01](work-orders/WO-P3-P3-01_SETTLEMENT_PROCEDURE.md) Settlement / cancellation (+U0 reference) | PASSED (2026-11-09) | [UC05S-RUN__20261109-1447](evidence/test-results/UC05S-RUN__20261109-1447.txt), [UC05U-RUN__20261109-1610](evidence/test-results/UC05U-RUN__20261109-1610.txt) | — |
| [WO-P3-P3-02](work-orders/WO-P3-P3-02_LOYALTY_AND_TIER.md) Loyalty & tier | PASSED (2026-11-10) | [UC05LOY-RUN__20261109-1636](evidence/test-results/UC05LOY-RUN__20261109-1636.txt) (62/62) | D-008 values at P6 |
| [WO-P3-P3-03](work-orders/WO-P3-P3-03_UC05_VERIFICATION.md) UC05 verification | **IN_PROGRESS**: Part C PASSED; Part P PENDING / BLOCKED (not approved) | [P3-03-RUN__20261110-0737](evidence/test-results/P3-03-RUN__20261110-0737.txt) (100/100), [ACCEPT-P3-03C](evidence/test-results/ACCEPT-P3-03C__20261110-080412.txt) | Part P: U0 vs U1, creation cost, T-PERF-01/02/08, IX-07, blocking duration, T-REPRO-03 |
| [WO-P3-P4-01](work-orders/WO-P3-P4-01_UC06_INDEX_EXPERIMENTS.md) Revenue reports + indexes | **IN_PROGRESS**: Part F PASSED; Part X PROPOSED / BLOCKED | [UC06-RUN__20261110-0206](evidence/test-results/UC06-RUN__20261110-0206.txt) (78/78), [ACCEPT-P4-01F](evidence/test-results/ACCEPT-P4-01F__20261110-070518.txt) | Part X: IX-01…IX-10, T-PERF-03…06, T-REG-01, `INDEX_DECISIONS.md` |
| [WO-P3-P4-02](work-orders/WO-P3-P4-02_REVENUE_SUMMARY.md) Revenue summary | PROPOSED; NOT_STARTED | — | Whole WO |
| [WO-P3-P5-01](work-orders/WO-P3-P5-01_PARTITION_POC.md) Partition PoC | PROPOSED; NOT_STARTED | Feature probe 3b only (partitioning supported) | Whole WO |
| [WO-P3-P6-01](work-orders/WO-P3-P6-01_APP_INTEGRATION.md) Integration + application | PROPOSED; NOT_STARTED | — | Whole WO (needs D-020, team schema) |
| [WO-P3-P7-01](work-orders/WO-P3-P7-01_QA_AND_FINAL_BENCHMARK.md) QA & final benchmark | PROPOSED; NOT_STARTED | — | Whole WO |
| [WO-P3-P8-01](work-orders/WO-P3-P8-01_EVIDENCE_AND_HANDOFF.md) Report & handoff | PROPOSED; NOT_STARTED | — | Whole WO |

| Risk | Status | Effect |
|---|---|---|
| R-27 benchmark stability | **OPEN** | Blocks every timing claim, B0, index adoption, summary/partition conclusions. Does **not** block functional, concurrency or application work |
| R-29 cancelled tier batch keeps its application lock | **OPEN** (availability only) | Caller contract and tests required before integration (see §D) |

Phase view: P0 PASSED (P0-02 BLOCKED) · P1 PASSED · P2 partial (P2-01 PASSED, P2-02 BLOCKED) · P3 partial (00/01/02 PASSED, 03 IN_PROGRESS) · P4 partial (P4-01 IN_PROGRESS, P4-02 not started) · P5–P8 NOT_STARTED.

---

## C. Implemented SQL components (real paths)

Paths are relative to the repository root. "Deployed" lists where the object exists today (read-only check, 2026-11-11).

### C.1 Production migrations (P3_OWNED; apply in this order, forward-only)

| File | Content |
|---|---|
| [V001__p3_billing_and_spending_tables.sql](../../../db/migrations/V001__p3_billing_and_spending_tables.sql) | The four P3 tables with PKs, 8 FKs to the shared tables, `CK_INVOICE_SERVICE_ITEM_Validity` |
| [V002__p3_settlement_and_spending_constraints.sql](../../../db/migrations/V002__p3_settlement_and_spending_constraints.sql) | Payment-state, method, PaidAt, amount and spending CHECKs; DEFAULTs |
| [V003__p3_points_earned_rule.sql](../../../db/migrations/V003__p3_points_earned_rule.sql) | `CK_MEMBER_MONTHLY_SPENDING_PointsRule`: `PointsEarned = FLOOR(TotalSpend/100000)` (D-006). Part of B0 by Owner decision A7 |

There is **no** performance index in any migration. The only indexes are the clustered primary keys.

### C.2 Routines (`db/procedures/`, `CREATE OR ALTER`)

| File | Objects | Purpose |
|---|---|---|
| [usp_P3_CreateInvoice.sql](../../../db/procedures/usp_P3_CreateInvoice.sql) | `usp_P3_CreateInvoice`; table types `tt_P3_InvoiceServiceLine`, `tt_P3_InvoiceProductLine` | One-call, one-transaction invoice creation; totals derived from lines (D-023, D-028) |
| [usp_P3_SettleInvoice.sql](../../../db/procedures/usp_P3_SettleInvoice.sql) | `usp_P3_SettleInvoice`; `tvf_P3_SpendingMonth` | PENDING→PAID exactly once; incremental monthly spending and points (U1); calls hook routines |
| [usp_P3_CancelInvoice.sql](../../../db/procedures/usp_P3_CancelInvoice.sql) | `usp_P3_CancelInvoice` | PENDING→CANCELLED |
| [usp_P3_EvaluateTiers.sql](../../../db/procedures/usp_P3_EvaluateTiers.sql) | `usp_P3_EvaluateTiers(@AsOfDate)`; `tvf_P3_TierWindow`; `tvf_P3_TierForSpend` | Daily tier batch (D-007/D-008 rule/D-009): upgrades and downgrades, chunked, idempotent, serialised by a session application lock (R-29) |
| [usp_P3_GetMemberLoyalty.sql](../../../db/procedures/usp_P3_GetMemberLoyalty.sql) | `usp_P3_GetMemberLoyalty` | Loyalty lookup (F21) |
| [usp_P3_RevenueReports.sql](../../../db/procedures/usp_P3_RevenueReports.sql) | `usp_P3_RptBranchRevenue`, `usp_P3_RptSystemRevenue`, `usp_P3_RptSystemRevenueByBranch`, `usp_P3_RptBranchRevenueByPeriod`, `usp_P3_RptSystemRevenueByPeriod`; `tvf_P3_ReportPeriodUtc`, `tvf_P3_ReportPeriodStart` | RPT-01…04 under D-010 (PAID only, `FinalAmount`, `PaidAt`, local calendar, half-open UTC bounds) |

**Reference only (never production):** [db/reference/usp_P3_SettleInvoice_Baseline.sql](../../../db/reference/usp_P3_SettleInvoice_Baseline.sql) — `usp_P3_SettleInvoice_Baseline`, the U0 variant that recomputes 12 months from `INVOICE`, kept only for the U0 vs U1 comparison.

**Frozen baseline queries:** [db/queries/baseline/Q-UC05-B.sql](../../../db/queries/baseline/Q-UC05-B.sql), [Q-UC05-C.sql](../../../db/queries/baseline/Q-UC05-C.sql) (frozen 2026-11-09 with B0 plans and logical reads; no timings). Q-BIL-A, Q-UC05-A and Q-UC06-A/A0/B/C/D are **not yet frozen** (WO-P3-P2-02 task 1).

**Deployed:** routines exist in `FitLife_P3_UC05` (fixtures) and `FitLife_P3_UC05L` (DS-L copy) on the default instance. `FitLife_P3_P2` on both instances holds tables and data only (no routines).

### C.3 TEST_ONLY objects (`tests/db/fixtures/`, `tests/db/doubles/`)

| File | Content |
|---|---|
| `F001__TEST_ONLY_shared_dependency_keys.sql` | Key-only `MEMBER`, `BRANCH`, `EMPLOYEE`, `SERVICE_PLAN`, `PRODUCT` |
| `F001D__…`, `F001U__…` | Fixture key rows (dataset / UC05 tests) |
| `F002P__TEST_ONLY_member_current_points.sql`, `F002T__TEST_ONLY_member_tier.sql` | `MEMBER.CurrentPoints`, `MEMBER.Tier_ID`, `MEMBER_TIER` with **synthetic** Gold/Platinum thresholds (1,000,000 / 3,000,000) |
| `F003H__…`, `L001__…`, `R001__…` | Paid-history helper `TEST_p3_AddPaidHistory`, DS-L loyalty state, revenue-report fixtures |
| `tests/db/doubles/D001__TEST_ONLY_settlement_hook_doubles.sql` | Contract-only doubles `usp_HOOK_InventoryDecrementForInvoice`, `usp_HOOK_EntitlementActivationForInvoice` (+ `TEST_Hook*` tables) |

**Why TEST_ONLY objects must never be deployed to a shared database:** the shared tables belong to other members (D-026 restricted, R-25). The fixtures carry only keys and synthetic thresholds, the hook doubles fake other members' routines, and the D-008 values are not approved. Deploying them would create a false "canonical" schema, collide with the real team objects and make tier results meaningless. They are replaced, not promoted, in WO-P3-P6-01 stage A.

### C.4 Dataset generator

[db/seed/S001__p3_dataset_generator.sql](../../../db/seed/S001__p3_dataset_generator.sql) (v1.0, deterministic SHA-256 streams, seed 20261108) with [profiles.json](../../../db/seed/profiles.json) (DS-S, DS-M, DS-L), driven by [tests/db/seed/run_p2_dataset.ps1](../../../tests/db/seed/run_p2_dataset.ps1). DS-L: `INVOICE` 324,000; `INVOICE_SERVICE_ITEM` 65,177; `INVOICE_PRODUCT_ITEM` 712,789; `MEMBER_MONTHLY_SPENDING` 169,040. Canonical DS-L fingerprint (run C, re-confirmed on BM-1 after V003 and before/after the 0235 E6): **`26ABB2776BD71C1347D2478D880B926FF35D8B6E7BA8F583D76E56D4DD82CA1F`**. DS-M run A: `3C056B7A7F0FFB8DE0C4A24474AFAEED80DE6B728F9CE834F34C3A752B33D85C`. Details: [db/seed/README.md](../../../db/seed/README.md).

### C.5 Test runners and harnesses (`tests/db/`)

| Area | Main entry points |
|---|---|
| Build / drop (marker-guarded) | `build/rebuild_isolated_db.sql`, `rebuild_p2_db.sql`, `rebuild_uc05_db.sql`, `rebuild_uc05l_db.sql`, `drop_*_db.sql`, `preflight_p1/p2.sql`, `fingerprint_instance.sql` |
| Schema | `schema/T-SCH-01…06_*.sql`, `schema/catalog_digest.sql` |
| Seed checks | `seed/T-SEED_dataset_checks.sql`, `seed/T-REPRO-02_checksums.sql` |
| Functional runners | `functional/run_uc05_invoice_creation.ps1`, `run_uc05_settlement.ps1`, `run_uc05_settlement_u0.ps1`, `run_uc05_loyalty.ps1`, `run_uc06_revenue.ps1`, `run_p3_03_verification.ps1` (all accept `-Server`) |
| Functional/integrity SQL | `functional/T-F05*_*.sql`, `T-F06_revenue_reports.sql`, `T-WF-01_uc05_uc06_workflow.sql`, `V-UC05*_*.sql`, `V-UC06R_integrity.sql`; `reconciliation/T-REC_loyalty.sql`, `T-REC_revenue.sql` |
| Concurrency | `concurrency/T-CONC-01_02_*.ps1`, `T-CONC-04F_*.ps1`, `T-CONC-04R_*.ps1`, `T-CONC-06_*.ps1`, `T-CONC-07_*.ps1`, `T-CONC-08_*.ps1` |
| Diagnostic capture (no timing) | `loyalty/capture_q_uc05_bc_b0.ps1`, `revenue/capture_uc06_reference.ps1` |
| Environment / E6 | `build/run_p0_02_bm1.ps1` (BM-1 only), `diagnostics/r27_e6_probe.ps1` (E6 harness v2), `r27_e6_wait_and_run.ps1`, `run_e6_bm1_standalone.ps1` (BM-1 only), `r27_diag_target.ps1` |

Commands and safety rules for each are in the [Benchmark runbook](design/BENCHMARK_RUNBOOK.md).

### C.6 Not implemented yet

`db/benchmark/` (B0 harness), `db/queries/optimized/`, `db/indexes/`, `db/summary/`, `db/partition-poc/`, `app/`, `design/INDEX_DECISIONS.md`, `SUMMARY_DECISION.md`, `PARTITION_DECISION.md`, `INTEGRATION_CONTRACT.md`, `report/`. Nothing in this list may be described as implemented.

---

## D. Decisions, dependencies and risks

Source of truth: [03_DECISION_LOG.md](03_DECISION_LOG.md), [12 §2b](12_INTEGRATION_PLAN.md#2b-dependency-register-interim-assumptions-until-p6), [14_RISK_REGISTER.md](14_RISK_REGISTER.md). "T2" = approved by the Owner for isolated P3 work only; the team must confirm before any integration or shared-database change.

| ID | Status | Impact |
|---|---|---|
| D-006 Monthly points | APPROVED (2026-11-08) | `PointsEarned = FLOOR(TotalSpend/100000)` per member-month; no carry-over between months; enforced by V003 |
| D-007 Tier window | APPROVED T2 (option d) | 12 local calendar months (current + 11 previous), half-open on `SpendingMonth`; not a rolling 365-day window |
| D-008 Tier rule / values | Rule APPROVED T2; **values PROPOSED** | Silver base 0, `≥`, highest eligible threshold, read from `MEMBER_TIER`. Real Gold/Platinum thresholds do not exist; tests use synthetic values. Production tier assignment is impossible until the Owner/team sets them (DEP-20) |
| D-009 Tier timing | APPROVED T2 (option a) | Daily batch `usp_P3_EvaluateTiers`; no scheduler created (DEP-19); upgrade may lag one day |
| D-010 Revenue | APPROVED T2 (2026-11-10) | PAID only, `FinalAmount`, at `PaidAt`, local calendar, by `INVOICE.Branch_ID`, refunds out of scope |
| D-028 Invoice creation | APPROVED T2 | Caller-supplied prices (DEP-04), no request deduplication (DEP-16): a blind retry can create a second PENDING invoice |
| D-001 UC catalogue | PROPOSED | Blocks only RPT-05…07 (RQ-A16–A18) and the group UC list |
| D-015 / D-016 / D-017 | DEFERRED | Decided by evidence in P4-02 / P5-01 |
| D-019 Isolation | APPROVED T2 (a); RCSI (b) team choice | P3 databases use locking READ COMMITTED |
| D-020 Application stack | **PROPOSED** | Blocks P6 stage B (application) |
| D-021 Repository | Part A APPROVED; **Part B PROPOSED** | Visibility still public; team conventions undecided |
| D-022 Thresholds | APPROVED for dataset; index adoption thresholds of [08 §6](08_INDEX_AND_QUERY_PLAN.md#6-adoption-and-rejection-criteria) still proposed defaults | Owner must confirm before Part X adoption |

**Handover of open integration items (none may be "decided" by a developer):**

| Item | Current state | What the next person must do |
|---|---|---|
| D-008 values | No source defines them | Ask the Owner/team; load into `MEMBER_TIER` via its owner (DEP-20). Never hard-code |
| D-001, D-020, D-021 Part B | Team decisions | Raise at the team meeting; record approver and date in 03 |
| DEP-04 price validation | Callers supply prices | Integration contract item; sale-flow owners must validate against the catalogue |
| DEP-16 duplicate creation | No request key | Callers must not retry blindly; contract item. A schema change needs a new Owner decision |
| DEP-19 scheduler | No job exists | Team chooses Agent job or app job at P6; must follow the R-29 caller rules below |
| R-29 lock on cancel | Reproduced by T-CONC-07 T4 | See below |
| Inventory / entitlement hooks | Contract-only doubles (DEP-05) | Real routines from UC04/UC01 owners; T-INT-01/02, T-CONC-05 at P6 |
| Shared `MEMBER` / `MEMBER_TIER` | Fixtures only (DEP-01…03) | Reconcile with the team schema in WO-P3-P1-02 |
| Permissions | TEST_ONLY principals (T-F05-26/30) | Define EXECUTE-only roles with the team (RQ-P15, DEP-14) |

**R-29 safe session/connection strategy (do not "fix" it by disabling every timeout):** the tier batch takes `sp_getapplock … @LockOwner = 'Session'`. A client cancel/timeout ends the batch without the CATCH block, so the lock stays until the connection closes. Required caller behaviour: (1) give the batch call a command timeout well above its longest expected run (not an arbitrary short default); (2) after any timeout or cancel, close and discard that connection, and clear its pool if pooling is used — never return it to the pool; (3) treat error 51324 as retryable with back-off; (4) recovery: find the holder in `sys.dm_tran_locks` (`resource_type = 'APPLICATION'`, resource like `%P3_usp_P3_EvaluateTiers%`), confirm it is idle, ask its application to close it, only an authorized operator may `KILL` it, then re-run the batch for the same date and verify with T-REC-04. Tests required before real integration ([14 §11.1](14_RISK_REGISTER.md#111-r-29-assessment--interrupted-tier-batch-keeps-its-application-lock)): T4 against the real scheduler; pooled-connection variant; KILL-and-rerun drill; 51324 retry; T-CONC-04F/T-CONC-07 regression with real hooks. A code change (transaction-owned lock) conflicts with D-019 (a) and needs its own Owner decision.

---

## E. Quick start

Replace `<repo>` with the clone path and `<server>` with the approved instance. On the original laptop `<repo>` = `C:\Users\DELL\source\repos\CSDLNC-DA`; the benchmark instance BM-1 = `localhost\MSSQLSERVER01`; `localhost` = the default instance, which also hosts unrelated databases.

### E.1 Local development on the original laptop

```powershell
Set-Location 'C:\Users\DELL\source\repos\CSDLNC-DA'
git status -sb                      # expect: ## p3/wo-p3-p1-01...origin/p3/wo-p3-p1-01, clean
git log --oneline -1                # expect: 496176c (or later)
sqlcmd -S localhost -E -W -Q "SET NOCOUNT ON; SELECT name, state_desc FROM sys.databases WHERE name LIKE 'FitLife[_]P3[_]%'"
```

Functional regression (rebuilds only the disposable `FitLife_P3_UC05` after its marker check; needs an approved WO or Owner instruction because it writes a database):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\db\functional\run_p3_03_verification.ps1 -Server localhost
```

### E.2 Benchmarking on another machine

Follow [Benchmark runbook §2–§5](design/BENCHMARK_RUNBOOK.md). Short version: transfer the source by `git clone` of branch `p3/wo-p3-p1-01` (it now contains everything), verify the file manifest, confirm the SQL Server identity, get Owner approval for a new benchmark environment, build DS-L with `run_p2_dataset.ps1 -Server <server>`, apply V003, verify fingerprint `26ABB277…CA1F`. The BM-1 runners (`run_p0_02_bm1.ps1`, `run_e6_bm1_standalone.ps1`) are hard-bound to `localhost\MSSQLSERVER01` and will refuse another machine; a portable equivalent is **NOT_IMPLEMENTED**.

### E.3 Reopening the project in Claude Code

Open the folder `<repo>` (not `C:\CSDLNC- DA`) and paste **Prompt 1 — Session Recovery** from the [Prompt playbook](PROMPT_PLAYBOOK.md).

### E.4 Continuing without a benchmark environment

Allowed without R-27: report/test preparation, P6 integration-contract drafting (documentation), P8 report sections that use already accepted functional evidence, repository checkpoint hygiene. See [roadmap Track B](REMAINING_WORK_ROADMAP.md#3-track-b--original-development-laptop). Application code (P6 stage B) still needs D-020 and an approved WO.

### E.5 Returning benchmark evidence to the original laptop

Follow [Benchmark runbook §11](design/BENCHMARK_RUNBOOK.md#11-evidence-transfer-back-to-the-original-laptop): export only new evidence files with a SHA-256 manifest and a machine manifest, copy them into `docs/phase2/person3/evidence/…` without overwriting, verify hashes, then update the WO execution record. Never claim the original laptop reproduced the timings.

---

## F. Academic deliverables (summary; full matrix in the roadmap)

- The grade weights conceptual 20% / logical 10% / physical 50% / application 20% apply to the **group**. The repository records "physical 50%" and "application 20%" from the assignment ([01](01_REQUIREMENTS_TRACEABILITY.md) RQ-A07, RQ-A09); the 20%/10% split is taken from the Owner's directive and was **not** re-verified, because the assignment PDF is password-protected and was not opened.
- Done with evidence: physical design table (DL-01), ≥70,000-row dataset on the relevant P3 tables (DL-04), stored procedures/functions for UC05/UC06, functional/concurrency/reconciliation tests.
- Missing: Actual Execution Plan **screenshots** (`evidence/screenshots/` is empty), measured before/after comparisons, index and partition experiments, summary/indexed-view experiment, application screenshots and demo, integration evidence, final report section. A SQL test PASS is not a substitute for any of these.
- Known source/decision discrepancy, kept visible: the assignment says tier spending "in the year"; Problem 4 describes "the last 12 months"; D-007 (approved T2) uses 12 month-aligned local months. Report this as an approved interpretation, not as the assignment text.

Full requirement-to-evidence matrix: [REMAINING_WORK_ROADMAP.md §5](REMAINING_WORK_ROADMAP.md#5-academic-requirement-to-evidence-matrix).

---

## What To Do Next

**Approved and executable now:** nothing that measures time. No P2-02, P3-03 Part P, P4-01 Part X, P4-02, P5-01, P6, P7 or P8 approval exists.

**Needs an Owner decision first (choose one path for R-27):**

1. **BM-1 under controlled conditions:** decide whether the 0235 run (no memory floor, Balanced plan, no standalone runner) consumed the single authorized BM-1 campaign. If the Owner authorizes a new controlled campaign: free ≥ 2 GB RAM, firm AC, re-apply A3 with `run_p0_02_bm1.ps1 -Stage Memory`, set A4, close VS Code/Claude Code, then run `run_e6_bm1_standalone.ps1`. Note: that runner's check K1 currently reports the campaign as consumed and exits 2, so the Owner's decision must also cover how K1 is handled (no ad hoc edit).
2. **Alternate machine (BM-2):** approve the machine, a portable environment runner (to be prepared), and a pre-registered rule for C-PLAN reference plan hashes on that hardware ([runbook §8.5](design/BENCHMARK_RUNBOOK.md#85-running-e6-on-another-machine)).

**Recommended next step if no benchmark machine is available this week:** draft the P6 integration-contract package (WO-P3-P1-02 tasks 1, 2, 4a as documentation only) and ask the team for D-020, D-001, D-008 values and the team schema. That unblocks the application (20% of the grade) without waiting for R-27. It still needs the Owner to approve a documentation-only start; see [roadmap §6](REMAINING_WORK_ROADMAP.md#6-recommended-next-action).

## Approved vs requires authorization

| Already approved / accepted (may be cited as done) | Requires authorization before any execution |
|---|---|
| P0-01/03, P1-01, P2-01, P3-00 (functional), P3-01, P3-02, P3-03 Part C, P4-01 Part F | Any E6 rerun; WO-P3-P2-02; P3-03 Part P; P4-01 Part X; P4-02; P5-01 |
| Decisions D-006, D-013, D-022 (dataset), D-024, D-025, D-026, D-027; T2 decisions for isolated work | Any SQL Server configuration or Windows power change; any new/rebuilt database; DS-XL |
| Reading code, evidence and running read-only SQL inspections | WO-P3-P1-02, promotion WO, WO-P3-P6-01/P7-01/P8-01; any shared-database change |
| A1–A7 for WO-P3-P0-02 (readiness only, BM-1 only) | Commit, push, merge; changing another member's files; D-008 values; D-020 |
