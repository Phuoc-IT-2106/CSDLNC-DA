# 05 — Physical Design Plan (Person 3)

| Field | Value |
|---|---|
| Document status | DRAFT — WO-P3-BOOT-001 |
| Date | 2026-11-06 |
| Reference DBMS | Microsoft SQL Server (D-002 approved provisionally 2026-11-07); local engine 17.0.1000.7 (SQL Server 2025 RTM, Standard Developer, registry); compatibility level 160 if the P1 preflight confirms support |
| P1 specification | The binding column, constraint and naming specification for P1 is [WO-P3-P1-01 §3](work-orders/WO-P3-P1-01_PHYSICAL_SCHEMA.md#3-inputs) (2026-11-07). This document keeps the method and the later-phase design. |
| Implementation status | **Implemented and verified (2026-11-07)** for the four P3-owned tables in the isolated database `FitLife_P3_P1` (WO-P3-P1-01 VERIFIED). As-built design and deviation register: [DL-01](design/PHYSICAL_DESIGN_TABLE.md). |
| Nature | This document defines **how** the physical design will be produced and verified. The type map and procedure list are *proposals* for WO-P3-P1-01 and WO-P3-P3-xx. No DDL has been written. |

## 1. Scope and ownership

Ownership as fixed by the Project Owner on 2026-11-07 (directive "Strict Person 3 Scope Enforcement"). P3 designs and implements **only** the P3_OWNED tables. Shared dependencies are documented as an interface ([12 §2a](12_INTEGRATION_PLAN.md#2a-shared-dependency-interface-required-by-p3)); in isolated test databases they exist only as key-only TEST_ONLY fixtures (D-026, restricted). Full scope matrix: [WO-P3-P1-01 §3.2](work-orders/WO-P3-P1-01_PHYSICAL_SCHEMA.md#32-scope-matrix-directive-strict-person-3-scope-enforcement).

| Table | Classification | P3 involvement |
|---|---|---|
| INVOICE | P3_OWNED | Full: DDL, billing, settlement (status, PaidAt), reports, indexes |
| INVOICE_SERVICE_ITEM | P3_OWNED | Full DDL; entitlement and PT owners write their columns per the contract |
| INVOICE_PRODUCT_ITEM | P3_OWNED | Full |
| MEMBER_MONTHLY_SPENDING | P3_OWNED | Full |
| Revenue summary (if D-015 adopts one) | P3_OWNED (if adopted) | Full |
| MEMBER | SHARED_DEPENDENCY | Maintains `CurrentPoints` and `Tier_ID`; reads `Member_ID` |
| MEMBER_TIER | SHARED_DEPENDENCY | Reads tier definitions; supplies threshold values (D-008) |
| BRANCH, EMPLOYEE, SERVICE_PLAN, PRODUCT | SHARED_DEPENDENCY | FK targets (identifiers); report grouping |
| The other 15 Phase 1 tables | OUT_OF_SCOPE | None (BRANCH_INVENTORY only through the settlement hook, D-012) |

## 2. Design inputs (course method)

The seminar method (S-07 p2; S-08 p4) lists the inputs of physical design as: normalised relations, volume estimates, attribute definitions, response-time expectations, data-security needs, backup/recovery needs, integrity expectations and DBMS technology. For P3 they come from:

| Input | P3 source |
|---|---|
| Normalised relations | S-02 §10 (RQ-P16) |
| Volume estimates | [04 §3](04_WORKLOAD_AND_DATA_VOLUME.md#3-projected-row-counts-straight-line-extrapolation-of-s-02-61) |
| Attribute definitions | §3 below (pending D-014) |
| Response-time expectations | None numeric (G-17); relative targets via D-022 |
| Security | RQ-P15 (least-privilege execution of P3 procedures) |
| Integrity | BR04–BR13, D-005, D-023 |
| DBMS | D-002 |

## 3. Column data types (D-014 approved provisionally 2026-11-07)

Logical names are unchanged from S-02 §10. **Additions are marked ➕ and need the listed decision.** Approved direction (D-014, 2026-11-07): INT identifiers, DECIMAL(18,2) money, DATETIME2(3) timestamps **stored in UTC**, Asia/Ho_Chi_Minh as the reporting time zone. The binding P1 specification is WO-P3-P1-01 §3.

### 3.1 INVOICE

| Column | Proposed type | Null | Default | Constraint / note |
|---|---|---|---|---|
| Invoice_ID | INT IDENTITY(1,1) | NOT NULL | — | PK, clustered (D-018) |
| Member_ID | INT | NOT NULL | — | FK → MEMBER (BR07) |
| Employee_ID | INT | NOT NULL | — | FK → EMPLOYEE (BR08) |
| Branch_ID | INT | NOT NULL | — | FK → BRANCH (BR08) |
| IssuedAt | DATETIME2(3) | NOT NULL | — (supplied by the creating module) | UTC (D-014) |
| ➕ PaidAt | DATETIME2(3) | NULL | — | D-004 (approved provisionally). UTC. NOT NULL iff PAID; PaidAt ≥ IssuedAt |
| GrossAmount | DECIMAL(18,2) | NOT NULL | — | ≥ 0 (D-023) |
| DiscountAmount | DECIMAL(18,2) | NOT NULL | 0 | ≥ 0; ≤ GrossAmount |
| FinalAmount | DECIMAL(18,2) | NOT NULL | — | = GrossAmount − DiscountAmount (D-023). Alternative to evaluate: a PERSISTED computed column, which removes the possibility of inconsistency. |
| PaymentMethod | VARCHAR(10) | NULL while not PAID | — | IN ('CASH','VNPAY','CARD') (D-005; REQUIRED_BY_ASSIGNMENT list); may be recorded at creation (S-02 §2.2 step 3); NOT NULL when PAID |
| PaymentStatus | VARCHAR(10) | NOT NULL | 'PENDING' | IN ('PENDING','PAID','CANCELLED'[, 'REFUNDED']) (D-005, D-011) |
| ➕ ClientRequestKey | UNIQUEIDENTIFIER | NULL | — | Only if D-003 option (C); unique when not null |

### 3.2 MEMBER_TIER (SHARED_DEPENDENCY: requirements on the owner, not P3 DDL)

| Column | Proposed type | Null | Constraint |
|---|---|---|---|
| Tier_ID | INT IDENTITY(1,1) (team uniformity, D-014) | NOT NULL | PK |
| Tier_Name | NVARCHAR(20) | NOT NULL | UNIQUE |
| SpendingThreshold | DECIMAL(18,2) | NOT NULL | UNIQUE, ≥ 0; base tier = 0 (D-008) |

### 3.3 MEMBER (SHARED_DEPENDENCY: P3-maintained columns; requirements on the owner, not P3 DDL)

| Column | Proposed type | Null | Default | Constraint |
|---|---|---|---|---|
| CurrentPoints | INT | NOT NULL | 0 | ≥ 0; = Σ PointsEarned (D-024 invariant) |
| Tier_ID | same type as MEMBER_TIER.Tier_ID | NOT NULL | base tier | FK → MEMBER_TIER (BR04) |

### 3.4 MEMBER_MONTHLY_SPENDING

| Column | Proposed type | Null | Default | Constraint |
|---|---|---|---|---|
| Member_ID | INT | NOT NULL | — | PK part 1; FK → MEMBER |
| SpendingMonth | DATE | NOT NULL | — | PK part 2; `DAY(SpendingMonth) = 1`; the Asia/Ho_Chi_Minh calendar month of PaidAt (D-013, approved 2026-11-07) |
| TotalSpend | DECIMAL(18,2) | NOT NULL | 0 | ≥ 0 |
| PointsEarned | INT | NOT NULL | 0 | ≥ 0 |
| UpdatedAt | DATETIME2(3) | NOT NULL | SYSUTCDATETIME() | UTC (D-014) |

### 3.5 Line tables (P3_OWNED since 2026-11-07)

`LineNo` is a T-SQL reserved keyword. The Phase 1 name is kept (RQ-P16) and is always written `[LineNo]` (WO-P3-P1-01 §3.5).

Invoice_ID uses the same type as INVOICE.Invoice_ID. Amount columns use the same DECIMAL type as INVOICE. INVOICE_PRODUCT_ITEM.Quantity > 0. Line DiscountAmount ≥ 0 and never exceeds the line gross amount (D-023). Full specification: WO-P3-P1-01 §3.3–§3.4. Column-level writers from other modules (entitlement validity, PT sessions) are integration-contract items.

## 4. Primary and foreign keys

- PKs exactly as S-02 §10 (DERIVED_FROM_PHASE1).
- All FKs declared, with no cascading deletes (financial history must not disappear silently).
- **FK-supporting indexes are not automatic in SQL Server.** Each FK index (INVOICE.Member_ID, Branch_ID, Employee_ID; MEMBER.Tier_ID) is an index *candidate* evaluated in [08](08_INDEX_AND_QUERY_PLAN.md), not created by default.
- Seeded data must leave every FK and CHECK constraint **trusted** (`is_not_trusted = 0`). Untrusted constraints prevent some optimiser simplifications (T-SEED-02).

## 5. Constraints and consistency

| Rule | Mechanism (planned) | Source / label |
|---|---|---|
| Amounts non-negative; FinalAmount = Gross − Discount; FinalAmount ≥ 0; line rules | CHECK constraints on the stored column (not a computed column) | D-023 (approved provisionally) |
| Header totals = Σ invoice lines | **Not a CHECK** (cross-table): enforced inside the invoice-finalisation transaction by the creating module; verified by a validation query ([WO-P3-P1-01 §3.4](work-orders/WO-P3-P1-01_PHYSICAL_SCHEMA.md#34-keys-foreign-keys-and-constraints)) | D-023 |
| Status and method domains; PaidAt/status coupling; PaidAt ≥ IssuedAt | CHECK constraints | D-004, D-005 |
| One spending row per member-month | PK + month normalisation CHECK | BR06, D-013 |
| Every member has a tier | NOT NULL FK on the shared MEMBER table, enforced by its owner ([12 §2a](12_INTEGRATION_PLAN.md#2a-shared-dependency-interface-required-by-p3)); P3 relies on it | BR04, D-008 |
| Confirmed invoice has ≥ 1 line (BR12) | Not expressible as a CHECK; enforced inside settlement before the status change (T-F05-02) | BR12 |
| Settlement applied once | Conditional PENDING→PAID update inside the transaction | D-003 |
| CurrentPoints = Σ PointsEarned; TotalSpend = Σ FinalAmount of PAID invoices in the month | Maintained by settlement; verified by reconciliation tests (T-REC-01, T-REC-02) | D-006, D-024 |
| Revenue summary = source aggregate (if adopted) | Maintenance per D-016; verified by T-REC-03 | D-015 |

## 6. Data access paths (planned analysis)

For each query in [04 §6](04_WORKLOAD_AND_DATA_VOLUME.md#6-query-workload-catalogue) the build work orders will record the access path in B0 (baseline), the candidate path and the observed path.

| Query | Expected B0 path (hypothesis) | Candidate path |
|---|---|---|
| Settlement lookup by Invoice_ID | Clustered index seek | — (already optimal) |
| Q-UC05-A | Clustered index scan of INVOICE | IX-03 seek + range |
| Q-UC05-B | PK seeks on MEMBER and MEMBER_MONTHLY_SPENDING | — |
| Q-UC05-C | Clustered scan of MEMBER_MONTHLY_SPENDING | IX-07 if month-first access helps |
| Q-UC06-A/C/D | Clustered index scan of INVOICE + aggregate | IX-01 seek + range; summary (D-015) |
| Q-UC06-B | Clustered index scan + hash aggregate | IX-02; summary |
| Q-UC06-E/F | Scans of line tables + join | IX-08 / IX-09 |
| Q-UC06-G | Scan of MEMBER | IX-11 |

These are hypotheses to test, not results.

## 7. Stored procedures and transaction boundaries (planned, not implemented)

Names are placeholders pending the naming convention in D-021. P3 errors use a reserved THROW range proposed for the integration contract: **51000–51999**.

| Procedure (placeholder) | Purpose | Transaction boundary | WO |
|---|---|---|---|
| `usp_P3_SettleInvoice` | Settlement (F06 + F20): status transition, PaidAt, loyalty effects, revenue-summary effect (if adopted), integration hooks (D-012) | One transaction for the whole settlement; `SET XACT_ABORT ON`; fixed lock order ([06 §4.9](06_UC05_BILLING_LOYALTY_PLAN.md#49-concurrent-settlement-handling)) | WO-P3-P3-01 |
| `usp_P3_SettleInvoice_Baseline` | Benchmark-only variant U0: recomputes window spend from INVOICE and re-ranks the tier at every payment (what Problem 4 describes) | Same as above | WO-P3-P3-01 |
| `usp_P3_EvaluateTiers` | F22 daily batch | One short transaction per chunk of members (size chosen to stay below the lock-escalation threshold) | WO-P3-P3-02 |
| `usp_P3_GetMemberLoyalty` | F21 lookup | None (single read) | WO-P3-P3-02 |
| Revenue report routines (procedures or inline table-valued functions, one per query shape) | F27, F28 and grains | None | WO-P3-P4-01 |
| `usp_P3_CancelInvoice` | PENDING→CANCELLED (if D-011) | One transaction | WO-P3-P3-01 |

Design rule: avoid one catch-all report procedure with optional parameters (`@Branch_ID IS NULL OR ...`). It produces unstable cached plans. Prefer one routine per query shape, or a documented `OPTION (RECOMPILE)`; the choice is measured in WO-P3-P4-01.

## 8. Index selection (summary)

Method, candidates IX-01…IX-11 and adopt/reject criteria are in [08_INDEX_AND_QUERY_PLAN.md](08_INDEX_AND_QUERY_PLAN.md). No index is final until its target query's Actual Execution Plan and measurements justify it, and its write overhead is measured.

## 9. Aggregation and derived data

| Derived data | Status | Why it exists | Correctness guard |
|---|---|---|---|
| MEMBER_MONTHLY_SPENDING | DERIVED_FROM_PHASE1 | Bounded tier computation (Problem 4) | T-REC-01 |
| MEMBER.CurrentPoints | DERIVED_FROM_PHASE1 | O(1) points lookup | T-REC-02 |
| MEMBER.Tier_ID | DERIVED_FROM_PHASE1 (cached result of evaluation) | O(1) tier lookup | T-REC-04 |
| Revenue summary | DEFERRED (D-015) | Repeated report aggregation | T-REC-03 |

Every derived structure must have a reconciliation query that recomputes it from source invoices and reports differences (expected: zero rows).

## 10. Partition feasibility (summary)

See [09_PARTITION_FEASIBILITY_PLAN.md](09_PARTITION_FEASIBILITY_PLAN.md). Partitioning is evaluated on a **benchmark copy** of INVOICE. The shared schema is not partitioned unless D-017 is approved with evidence.

## 11. Data generation (summary)

See [10_SEED_AND_BENCHMARK_PLAN.md](10_SEED_AND_BENCHMARK_PLAN.md). Seeding is deterministic, set-based and FK-valid. Derived tables (MEMBER_MONTHLY_SPENDING, CurrentPoints, Tier_ID, summaries) are **computed from the generated invoices**, never generated independently.

## 12. Query execution analysis

For every compared query and configuration, capture:

1. Actual Execution Plan (`.sqlplan` + screenshot). Course method: S-07 p13–19.
2. `SET STATISTICS IO ON` (logical reads per table) and `SET STATISTICS TIME ON` (CPU and elapsed).
3. Observations: scan vs seek; Key Lookup present or absent; aggregate type (stream/hash); sort operators; parallelism; estimated vs actual rows; and, for partitioning, Actual Partition Count.
4. Result hash, to prove the optimisation did not change the answer.

Protocol: [10 §4](10_SEED_AND_BENCHMARK_PLAN.md#4-benchmark-methodology).

## 13. Proposed implementation layout (not created)

Pending D-021. These directories are **documented only** because the team's repository and conventions are unknown (S-12, S-13). Creating top-level code directories now could conflict with another member's layout. They will be created by the first build work order that needs them, after D-021 is approved.

```text
<repo-root>/
├── db/
│   ├── migrations/         production migrations for P3-owned tables only (V001 tables, V002 constraints; WO-P3-P1-01)
│   ├── schema/             DDL for tables and constraints (P3 files tagged p3; superseded by migrations/ if D-021 is approved as proposed)
│   ├── procedures/         stored procedures and functions
│   ├── indexes/            one script per candidate index + adopted set
│   ├── summary/            revenue-summary / indexed-view experiments (D-015)
│   ├── partition-poc/      partition function/scheme on a benchmark copy (D-017)
│   ├── seed/               deterministic seed scripts + configuration
│   ├── queries/
│   │   ├── baseline/       frozen baseline queries (never edited after capture)
│   │   └── optimized/
│   └── benchmark/          benchmark harness (runner, manifest writer)
├── tests/
│   └── db/
│       ├── fixtures/       TEST_ONLY key-only fixtures for shared dependencies (D-026, restricted; never production)
│       ├── build/          preflight, guarded rebuild and drop scripts for isolated databases (test harness)
│       ├── schema/         T-SCH-01, T-SCH-02
│       ├── functional/
│       ├── concurrency/
│       ├── reconciliation/
│       └── regression/
├── app/                    application (stack per D-020)
└── docs/phase2/person3/
    ├── design/             physical design table, integration contract, decision records (created in P1)
    ├── report/             P3 report section (created in P8)
    └── evidence/           execution-plans/, screenshots/, benchmark-results/, test-results/ (created now, empty)
```

## 14. Physical design table format (deliverable DL-01)

The report-ready table produced in WO-P3-P1-01 has one row per column:

| Table | Column | Type | Null | Default | Key / constraint | Index participation | Source label | Rationale |
|---|---|---|---|---|---|---|---|---|

Plus one row per index (name, keys, INCLUDE, filter, target query, evidence link) and one row per derived structure (maintenance mechanism, reconciliation test).
