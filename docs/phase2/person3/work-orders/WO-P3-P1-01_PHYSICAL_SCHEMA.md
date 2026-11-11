# WO-P3-P1-01 — Physical Schema Foundation

| Field | Value |
|---|---|
| Status | PASSED |
| Readiness | Executed 2026-11-07 (`VERIFIED`); **accepted by the Owner on 2026-11-08** after a read-only re-check of the evidence (§14). GATE-P1 closed. |
| Phase | P1 — Physical Schema Foundation |
| Mode | BUILD_AUTHORIZED (after approval) |
| Approver | Project Owner. Shared-table decisions are approved provisionally under approval rule 3 / T2; team review is required before any integration or merge. |
| Approval record | **APPROVED** 2026-11-07 by the Owner Directive "Close P0 and Execute WO-P3-P1-01" (Claude Code session of 2026-11-07), §1 step 4: mode BUILD_AUTHORIZED; target `FitLife_P3_P1` on the local default instance; cut-over and local branch `p3/wo-p3-p1-01` authorized; **no commit, push, pull request or merge**. GATE-P0 closed the same day (WO-P3-P0-03 `PASSED`). Executed: `APPROVED` → `IN_PROGRESS` → `VERIFIED`. |
| Target database | One isolated, disposable database **`FitLife_P3_P1`** on the local default instance `MSSQLSERVER` (D-025), created and rebuilt only by this WO's build script. The approval may name another instance. No other database is touched. |
| Working copy | `C:\Users\DELL\source\repos\CSDLNC-DA`, branch `p3/wo-p3-p1-01` (D-021 Part A) |
| Scope rule | **Person 3 only.** Production DDL for the four P3-owned tables. Shared tables appear only as TEST_ONLY key fixtures in the isolated database (D-026, restricted). Nothing of another member's module is built. |

## 0. Revision record

| Date | Change |
|---|---|
| 2026-11-06 | Created by WO-P3-BOOT-001 as **WO-P3-P1-02** "Physical Schema and Physical Design Table" |
| 2026-11-07 | Renumbered and rewritten as "Physical Schema Foundation" (directive WO-P3-P0-FINAL) |
| 2026-11-07 | UTC storage, preflight, payment-state invariants, V-TOT, FK verification, deviation register (directive "Final P0 Decision Resolution") |
| 2026-11-07 | **Strict scope** (directive "Strict Person 3 Scope Enforcement"). Production DDL reduced to INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM and MEMBER_MONTHLY_SPENDING. The earlier 10-table "shared baseline" (V001 creating MEMBER, MEMBER_TIER, BRANCH, EMPLOYEE, SERVICE_PLAN, PRODUCT) is **withdrawn**. Shared tables are replaced by key-only TEST_ONLY fixtures in a separate test folder. Constraints on MEMBER and MEMBER_TIER are moved to the integration contract. Scope matrix, object ownership, allowed and forbidden tables added. The archive marker file is dropped (the archive must stay immutable). |

## 1. Objective and scope

Implement and verify the physical schema of the **four Person 3-owned tables** (INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM, MEMBER_MONTHLY_SPENDING), as forward-only production migrations derived from the approved Phase 1 logical schema (S-02 §10) and the approved amendments. Verify them in an isolated, disposable database. In that database, the shared parent tables come from the approved team schema when it exists; otherwise from minimal, key-only TEST_ONLY fixtures (D-026). Also write the physical design table (DL-01).

In scope: two production migrations; one TEST_ONLY fixture script; a guarded test build script; two schema test scripts; DL-01; the repository cut-over (step 0); the SQL Server preflight (step 1).

Not in scope: anything in §5, in particular any shared table's real implementation and any UC05/UC06 business code.

## 2. Preconditions

| ID | Precondition | State 2026-11-07 |
|---|---|---|
| P1-R1 | WO-P3-BOOT-001 PASSED | ✔ |
| P1-R2 | WO-P3-P0-01 PASSED | ✔ |
| P1-R3 | APPROVED in [03](../03_DECISION_LOG.md): D-002, D-003, D-004, D-005, D-011, D-013, D-014, D-018, D-021 (Part A), D-023, D-026 (restricted) | ✔ 11 of 11 (D-013, D-021 Part A, D-026 approved 2026-11-07; eight others provisionally under T2) |
| P1-R4 | D-025 APPROVED | ✔ |
| P1-R5 | Repository readiness: canonical repository identified; local clone; D-021 Part A approved | ✔ |
| P1-R6 | Shared dependencies: approved team schema, or TEST_ONLY fixtures under the restricted D-026 | ✔ (fixtures; no team schema exists) |
| P1-R7 | Test environment authorized: this WO approved with its target database named | Open (§11 statement) |
| P1-R8 | P3 scope confirmed by the Owner | ✔ (ownership matrix of 2026-11-07, §3.2) |
| GATE-P0 | WO-P3-P0-03 PASSED (approval rule 5) | Open: WO-P3-P0-03 is `VERIFIED`; the Owner sets `PASSED` |

**Stop conditions during execution** (set the WO to `BLOCKED` and report; never change the approved design silently):

- the instance cannot be reached with Windows authentication;
- the engine does not support compatibility level 160;
- the preflight finds a conflict between this specification and S-02 §10;
- an approved team schema appears in the repository that differs from the fixture keys (then rebase onto it instead of using fixtures);
- the clone is not clean, or `main` has unexpected commits touching the same paths.

## 3. Inputs

### 3.1 Approved schema baseline

- **S-02 §10** (Phase 1 report `ADB.24C03.12`, .docx md5 `c11b9c116880`): names, keys and relationships of the four P3 tables and of the shared parents they reference (RQ-P16).
- Phase 1 business rules BR06, BR07–BR13 (S-02 §4.2–§4.3).
- Approved amendments: `INVOICE.PaidAt` (D-004); payment domains and invariants (D-003, D-005, D-011); monetary rules (D-023); types and UTC storage (D-002, D-014, D-018); `SpendingMonth` (D-013); dependency handling (D-026, restricted). Every difference from §10 is in §3.7.

### 3.2 Scope matrix (directive "Strict Person 3 Scope Enforcement")

A shared table's business entity remains a SHARED_DEPENDENCY even when its physical fixture in the isolated database is TEST_ONLY.

| Table (Phase 1) | Business entity | Physical object in P1 | P3 interaction | Owner of the real table |
|---|---|---|---|---|
| INVOICE | **P3_OWNED** | Production migration V001/V002 | Full: DDL, billing, settlement, revenue | P3 |
| INVOICE_SERVICE_ITEM | **P3_OWNED** | Production migration V001/V002 | Full (DDL); other members write entitlement and PT columns per the contract | P3 |
| INVOICE_PRODUCT_ITEM | **P3_OWNED** | Production migration V001/V002 | Full (DDL) | P3 |
| MEMBER_MONTHLY_SPENDING | **P3_OWNED** | Production migration V001/V002 | Full | P3 |
| MEMBER | SHARED_DEPENDENCY | **TEST_ONLY_FIXTURE** (key only: `Member_ID`) | FK target; P3 later maintains `CurrentPoints`, `Tier_ID` (contract) | Profile owner (team) |
| BRANCH | SHARED_DEPENDENCY | **TEST_ONLY_FIXTURE** (key only: `Branch_ID`) | FK target for invoices; report grouping | Team |
| EMPLOYEE | SHARED_DEPENDENCY | **TEST_ONLY_FIXTURE** (key only: `Employee_ID`) | FK target for invoice staff | HR owner (team) |
| SERVICE_PLAN | SHARED_DEPENDENCY | **TEST_ONLY_FIXTURE** (key only: `Plan_ID`) | FK target for service lines | Catalogue owner (team) |
| PRODUCT | SHARED_DEPENDENCY | **TEST_ONLY_FIXTURE** (key only: `Product_ID`) | FK target for product lines | Catalogue owner (team) |
| MEMBER_TIER | SHARED_DEPENDENCY | **None in P1** (no P3 table references it) | Tier definitions and thresholds read by UC05 (D-008); fixture added by WO-P3-P3-02 if still needed | Team |
| CHECK_IN, ACCESS_POINT, PT_APPOINTMENT, PT_SESSION, FACILITY, BRANCH_FACILITY, BRANCH_SERVICE, BRANCH_INVENTORY, PERSONAL_TRAINER, RECEPTIONIST, BRANCH_MANAGER, SALES_STAFF, EMPLOYEE_ASSIGNMENT, SALARY_RATE_HISTORY, MONTHLY_PAYROLL | OUT_OF_SCOPE | **None** | None in P1 (BRANCH_INVENTORY is reached later only through the settlement hook, D-012) | Other members |

Totals: 4 P3_OWNED, 6 SHARED_DEPENDENCY (5 with a TEST_ONLY fixture in P1), 15 OUT_OF_SCOPE = 25 Phase 1 tables.

**Allowed tables in P1:** CREATE/ALTER only on the 4 P3-owned tables (production migrations) and on the 5 TEST_ONLY fixtures (fixture script, isolated database only).
**Forbidden tables in P1:** every other table, including MEMBER_TIER and the 15 OUT_OF_SCOPE tables; any change to a shared table outside the isolated database; any column or constraint on a fixture beyond its key.

### 3.3 Column specification — P3-owned tables (production)

Types follow D-014: identifiers `INT`, money `DECIMAL(18,2)`, transaction timestamps `DATETIME2(3)` **in UTC**; other types and `IDENTITY` are listed in §3.7. "V2" = added in V002.

| Table | Column | Type | Null | Default | Basis |
|---|---|---|---|---|---|
| INVOICE | Invoice_ID | INT IDENTITY(1,1) | NOT NULL | — | §10 PK; D-018 |
| INVOICE | Member_ID | INT | NOT NULL | — | §10 FK; BR07 |
| INVOICE | Employee_ID | INT | NOT NULL | — | §10 FK; BR08 |
| INVOICE | Branch_ID | INT | NOT NULL | — | §10 FK; BR08 |
| INVOICE | IssuedAt | DATETIME2(3) | NOT NULL | — | §10; UTC (D-014) |
| INVOICE | GrossAmount | DECIMAL(18,2) | NOT NULL | — | §10 |
| INVOICE | DiscountAmount | DECIMAL(18,2) | NOT NULL | — | §10 |
| INVOICE | FinalAmount | DECIMAL(18,2) | NOT NULL | — | §10 (stored, not computed: D-023) |
| INVOICE | PaymentMethod | VARCHAR(10) | **NULL** (before settlement) | — | §10; D-005 |
| INVOICE | PaymentStatus | VARCHAR(10) | NOT NULL | 'PENDING' (V2) | §10; D-005 |
| INVOICE | PaidAt | DATETIME2(3) | NULL | — | **V2 addition, D-004**; UTC |
| INVOICE_SERVICE_ITEM | Invoice_ID | INT | NOT NULL | — | §10 PK/FK; BR09 |
| INVOICE_SERVICE_ITEM | [LineNo] | SMALLINT | NOT NULL | — | §10 PK |
| INVOICE_SERVICE_ITEM | Plan_ID | INT | NOT NULL | — | §10 FK; BR10 |
| INVOICE_SERVICE_ITEM | UnitPrice | DECIMAL(18,2) | NOT NULL | — | §10; BR13 |
| INVOICE_SERVICE_ITEM | DiscountAmount | DECIMAL(18,2) | NOT NULL | — | §10 |
| INVOICE_SERVICE_ITEM | ValidFrom | DATE | NULL | — | §10 (set when the entitlement is activated; writer per contract) |
| INVOICE_SERVICE_ITEM | ValidUntil | DATE | NULL | — | §10 |
| INVOICE_SERVICE_ITEM | PTSessionsRemaining | INT | NULL | — | §10 (written by the PT owner per contract; no P3 rule added) |
| INVOICE_PRODUCT_ITEM | Invoice_ID | INT | NOT NULL | — | §10 PK/FK; BR09 |
| INVOICE_PRODUCT_ITEM | [LineNo] | SMALLINT | NOT NULL | — | §10 PK |
| INVOICE_PRODUCT_ITEM | Product_ID | INT | NOT NULL | — | §10 FK; BR11 |
| INVOICE_PRODUCT_ITEM | Quantity | INT | NOT NULL | — | §10 |
| INVOICE_PRODUCT_ITEM | UnitPrice | DECIMAL(18,2) | NOT NULL | — | §10 |
| INVOICE_PRODUCT_ITEM | DiscountAmount | DECIMAL(18,2) | NOT NULL | — | §10 |
| MEMBER_MONTHLY_SPENDING | Member_ID | INT | NOT NULL | — | §10 PK/FK |
| MEMBER_MONTHLY_SPENDING | SpendingMonth | DATE | NOT NULL | — | §10 PK; **D-013 approved** |
| MEMBER_MONTHLY_SPENDING | TotalSpend | DECIMAL(18,2) | NOT NULL | 0 (V2) | §10 |
| MEMBER_MONTHLY_SPENDING | PointsEarned | INT | NOT NULL | 0 (V2) | §10 |
| MEMBER_MONTHLY_SPENDING | UpdatedAt | DATETIME2(3) | NOT NULL | SYSUTCDATETIME() (V2) | §10; UTC (D-014) |

### 3.3a TEST_ONLY dependency fixtures (isolated database only)

Created by `tests/db/fixtures/F001__TEST_ONLY_shared_dependency_keys.sql`, **only** when no approved team schema is available, and only in a database named `FitLife_P3_%`.

| Fixture table | Columns (Phase 1 name, D-014 type) | Constraints | Why it exists |
|---|---|---|---|
| MEMBER | `Member_ID INT NOT NULL` | `PK_MEMBER` only | FK target of INVOICE and MEMBER_MONTHLY_SPENDING |
| BRANCH | `Branch_ID INT NOT NULL` | `PK_BRANCH` only | FK target of INVOICE |
| EMPLOYEE | `Employee_ID INT NOT NULL` | `PK_EMPLOYEE` only | FK target of INVOICE |
| SERVICE_PLAN | `Plan_ID INT NOT NULL` | `PK_SERVICE_PLAN` only | FK target of INVOICE_SERVICE_ITEM |
| PRODUCT | `Product_ID INT NOT NULL` | `PK_PRODUCT` only | FK target of INVOICE_PRODUCT_ITEM |

Fixture rules (D-026 restricted, conditions 3–9):

1. Names, key columns and key types come from Phase 1 and D-014. No new domain structure, no extra columns, no `IDENTITY` (tests insert explicit keys), no defaults, CHECKs, indexes, triggers or routines.
2. Each fixture table carries the extended property `Classification = 'TEST_ONLY_FIXTURE'`, and the script header says TEST_ONLY, not production, owned by another member, to be replaced before integration.
3. Tests insert parent rows only through a fixture-data block at the top of each test script, so replacing fixtures with the team schema later changes only that block.
4. A later WO may add a Phase 1 column to a fixture only when a P3 query needs it, with the same name and type, under the same rules (for example MEMBER.`CurrentPoints` and `Tier_ID` and a MEMBER_TIER fixture for UC05).
5. Before final integration, fixtures are replaced by the approved team schema and T-SCH-01, T-SCH-02 and T-INT-03 are re-run (condition 9).
6. Fixtures are never deployed to a shared database and are never cited as the implementation of another member's module.

### 3.4 Keys, foreign keys and constraints

These constraints exist only on the four P3-owned tables. All FKs use `ON DELETE NO ACTION` and `ON UPDATE NO ACTION`. All constraints are named, enabled and trusted. Ownership class of every object: P3_OWNED.

| Name | Table | Definition | Basis | File |
|---|---|---|---|---|
| PK_INVOICE | INVOICE | PRIMARY KEY CLUSTERED (Invoice_ID) | §10; D-018 | V001 |
| FK_INVOICE_MEMBER / FK_INVOICE_EMPLOYEE / FK_INVOICE_BRANCH | INVOICE | → MEMBER(Member_ID) / EMPLOYEE(Employee_ID) / BRANCH(Branch_ID) | §10; BR07, BR08 | V001 |
| PK_INVOICE_SERVICE_ITEM | INVOICE_SERVICE_ITEM | PRIMARY KEY CLUSTERED (Invoice_ID, [LineNo]) | §10 | V001 |
| FK_INVOICE_SERVICE_ITEM_INVOICE / _SERVICE_PLAN | INVOICE_SERVICE_ITEM | → INVOICE(Invoice_ID) / SERVICE_PLAN(Plan_ID) | §10; BR09, BR10 | V001 |
| CK_INVOICE_SERVICE_ITEM_Validity | INVOICE_SERVICE_ITEM | `ValidUntil >= ValidFrom` (passes when either is NULL) | BR13 | V001 |
| PK_INVOICE_PRODUCT_ITEM | INVOICE_PRODUCT_ITEM | PRIMARY KEY CLUSTERED (Invoice_ID, [LineNo]) | §10 | V001 |
| FK_INVOICE_PRODUCT_ITEM_INVOICE / _PRODUCT | INVOICE_PRODUCT_ITEM | → INVOICE(Invoice_ID) / PRODUCT(Product_ID) | §10; BR09, BR11 | V001 |
| PK_MEMBER_MONTHLY_SPENDING | MEMBER_MONTHLY_SPENDING | PRIMARY KEY CLUSTERED (Member_ID, SpendingMonth) | §10; BR06 | V001 |
| FK_MEMBER_MONTHLY_SPENDING_MEMBER | MEMBER_MONTHLY_SPENDING | → MEMBER(Member_ID) | §10; BR05 | V001 |
| CK_MEMBER_MONTHLY_SPENDING_FirstDay | MEMBER_MONTHLY_SPENDING | `DAY(SpendingMonth) = 1` | D-013 | V002 |
| CK_MEMBER_MONTHLY_SPENDING_NonNegative | MEMBER_MONTHLY_SPENDING | `TotalSpend >= 0 AND PointsEarned >= 0` | — | V002 |
| DF_MEMBER_MONTHLY_SPENDING_TotalSpend / _PointsEarned / _UpdatedAt | MEMBER_MONTHLY_SPENDING | 0 / 0 / SYSUTCDATETIME() | D-014 | V002 |
| DF_INVOICE_PaymentStatus | INVOICE | DEFAULT 'PENDING' | D-005 | V002 |
| CK_INVOICE_PaymentStatus | INVOICE | `PaymentStatus IN ('PENDING','PAID','CANCELLED')` | D-005, D-011 | V002 |
| CK_INVOICE_PaymentMethod | INVOICE | `PaymentMethod IN ('CASH','VNPAY','CARD')` (NULL allowed) | D-005 | V002 |
| CK_INVOICE_MethodWhenPaid | INVOICE | `PaymentStatus <> 'PAID' OR PaymentMethod IS NOT NULL` | D-005 | V002 |
| CK_INVOICE_PaidAtStatus | INVOICE | `(PaymentStatus = 'PAID' AND PaidAt IS NOT NULL) OR (PaymentStatus <> 'PAID' AND PaidAt IS NULL)` | D-004 | V002 |
| CK_INVOICE_PaidAtAfterIssued | INVOICE | `PaidAt >= IssuedAt` (passes when NULL; both UTC) | D-004 | V002 |
| CK_INVOICE_Amounts | INVOICE | `GrossAmount >= 0 AND DiscountAmount >= 0 AND DiscountAmount <= GrossAmount` | D-023 | V002 |
| CK_INVOICE_FinalAmount | INVOICE | `FinalAmount = GrossAmount - DiscountAmount AND FinalAmount >= 0` | D-023 | V002 |
| CK_INVOICE_SERVICE_ITEM_Amounts | INVOICE_SERVICE_ITEM | `UnitPrice >= 0 AND DiscountAmount >= 0 AND DiscountAmount <= UnitPrice` | D-023 | V002 |
| CK_INVOICE_PRODUCT_ITEM_Quantity | INVOICE_PRODUCT_ITEM | `Quantity > 0` | D-023 | V002 |
| CK_INVOICE_PRODUCT_ITEM_Amounts | INVOICE_PRODUCT_ITEM | `UnitPrice >= 0 AND DiscountAmount >= 0 AND DiscountAmount <= UnitPrice * Quantity` | D-023 | V002 |

**Payment-state invariants (D-003, D-004, D-005, D-011).**

| # | Invariant | Kind | Enforced by | When |
|---|---|---|---|---|
| S1 | `PaymentStatus` NOT NULL, one of PENDING, PAID, CANCELLED; default PENDING | Row | NOT NULL + CK_INVOICE_PaymentStatus + DF | P1 |
| S2 | `PaymentMethod` is **nullable before settlement** (may be recorded at creation, S-02 §2.2 step 3); one of CASH, VNPAY, CARD when present | Row | CK_INVOICE_PaymentMethod | P1 |
| S3 | PAID ⇒ `PaymentMethod` NOT NULL | Row | CK_INVOICE_MethodWhenPaid | P1 |
| S4 | PAID ⇔ `PaidAt` NOT NULL | Row | CK_INVOICE_PaidAtStatus | P1 |
| S5 | `PaidAt ≥ IssuedAt` | Row | CK_INVOICE_PaidAtAfterIssued | P1 |
| T1 | Only PENDING→PAID and PENDING→CANCELLED | Transition (needs the old value) | UC05 routines: conditional update; status changed only through them | WO-P3-P3-01 |
| T2 | PAID is terminal (no re-settlement, no refund) | Transition | Same | WO-P3-P3-01 |
| T3 | CANCELLED is terminal | Transition | Same | WO-P3-P3-01 |
| T4 | `PaidAt`, `PaymentMethod` unchanged after PAID | Transition | Same | WO-P3-P3-01 |
| T5 | Loyalty and revenue effects exactly once, in the PENDING→PAID transaction | Cross-table | Settlement transaction (D-012) | WO-P3-P3-01 |

Compatibility: check-in and entitlement processing treat only `PaymentStatus = 'PAID'` as paid. `ValidFrom`, `ValidUntil` and `PTSessionsRemaining` keep their §10 meaning; the only rule added on them is BR13.

**Cross-table invariants (D-023): what a CHECK cannot enforce.**

| # | Invariant | Mechanism | When |
|---|---|---|---|
| X1 | Header `GrossAmount` = Σ service `UnitPrice` + Σ product `UnitPrice × Quantity` | P3 invoice-finalisation logic inside the billing transaction (UC05 billing; WO to be confirmed, see [16 §3](../16_READINESS_REPORT.md#3-blockers-for-the-build-phases)), plus the defensive check at settlement | Later UC05 WO |
| X2 | Header `DiscountAmount` = Σ line `DiscountAmount` | Same | Same |
| X3 | A confirmed invoice has at least one line (BR12) | Settlement checks the line count before PENDING→PAID | WO-P3-P3-01 |

A CHECK calling a function that reads the line tables is not used: it fires only when the header row changes, not when lines change, so it would give a false guarantee. To keep totals **verifiable**, P1 defines the read-only validation query **V-TOT** (test scripts only, not a database object): invoices whose header Gross or Discount differs from their lines, and invoices without lines.

**Moved out of P1 by the strict scope** (shared tables, proposed to their owners in [12 §2a](../12_INTEGRATION_PLAN.md#2a-shared-dependency-interface-required-by-p3)): `MEMBER.CurrentPoints` NOT NULL DEFAULT 0 and `>= 0`; `MEMBER.Tier_ID` NOT NULL FK → MEMBER_TIER (BR04); MEMBER_TIER UNIQUE `Tier_Name`, UNIQUE `SpendingThreshold`, `SpendingThreshold >= 0`. Also not part of P1: `PointsEarned = FLOOR(TotalSpend / 100000)` (only if D-006 (b) is approved; WO-P3-P3-02).

**Indexes:** only those created by PRIMARY KEY constraints (P3 tables and fixtures). No nonclustered, unique-performance or partitioned index.

### 3.5 Data types and naming conventions

| Item | Convention |
|---|---|
| Schema | `dbo` |
| Table and column names | Exactly as S-02 §10 (RQ-P16); fixtures use the same names so the production FKs resolve unchanged |
| Reserved word | `LineNo` is a T-SQL reserved keyword: always write `[LineNo]` |
| Constraint names | `PK_<TABLE>`, `FK_<CHILD>_<PARENT>`, `CK_<TABLE>_<Rule>`, `DF_<TABLE>_<Column>`; all named explicitly |
| Timestamps | `DATETIME2(3)` in UTC; defaults `SYSUTCDATETIME()` (D-014) |
| Production migrations (P3_OWNED) | `db/migrations/V001__p3_billing_and_spending_tables.sql` (Phase 1 structure: columns, PKs, FKs, BR13), `db/migrations/V002__p3_settlement_and_spending_constraints.sql` (approved amendments: `PaidAt`, CHECKs, DEFAULTs). Header comment: purpose, WO, decisions, "requires the shared parent keys listed in 12 §2a". |
| TEST_ONLY fixtures | `tests/db/fixtures/F001__TEST_ONLY_shared_dependency_keys.sql` |
| Test build | `tests/db/build/rebuild_isolated_db.sql` (sqlcmd mode; test harness, not production) |
| Tests | `tests/db/schema/T-SCH-01_constraints.sql`, `tests/db/schema/T-SCH-02_conformance.sql` |
| Session settings | `sqlcmd -E -I -b` |

### 3.6 Dependencies and shared interfaces

The production migrations require the shared parents below. They are referenced through the documented interface in [12 §2a](../12_INTEGRATION_PLAN.md#2a-shared-dependency-interface-required-by-p3) and, later, the integration contract (WO-P3-P1-02). A missing shared schema never justifies building another member's module.

| P3 FK (8) | Requires on the shared side | Owner |
|---|---|---|
| FK_INVOICE_MEMBER, FK_MEMBER_MONTHLY_SPENDING_MEMBER | MEMBER(`Member_ID INT` PK) | Profile owner |
| FK_INVOICE_BRANCH | BRANCH(`Branch_ID INT` PK) | Team |
| FK_INVOICE_EMPLOYEE | EMPLOYEE(`Employee_ID INT` PK) | HR owner |
| FK_INVOICE_SERVICE_ITEM_SERVICE_PLAN | SERVICE_PLAN(`Plan_ID INT` PK) | Catalogue owner |
| FK_INVOICE_PRODUCT_ITEM_PRODUCT | PRODUCT(`Product_ID INT` PK) | Catalogue owner |
| FK_INVOICE_SERVICE_ITEM_INVOICE, FK_INVOICE_PRODUCT_ITEM_INVOICE | INVOICE (P3) | P3 |

Other interfaces: `INVOICE.PaymentStatus` literals (check-in reads them); column-level writers on INVOICE_SERVICE_ITEM (entitlement activation: `ValidFrom`, `ValidUntil`; PT owner: `PTSessionsRemaining`); UTC storage for every member's timestamps. All are integration-contract items (team review).

### 3.7 Deviation register (differences from S-02 §10)

| # | Item | Phase 1 (§10) | This WO | Authority |
|---|---|---|---|---|
| DV-01 | `INVOICE.PaidAt` | Absent | Added, `DATETIME2(3) NULL`, UTC | D-004 (provisional, T2) |
| DV-02 | Identifier, money and timestamp types (P3 tables) | Not specified | INT, DECIMAL(18,2), DATETIME2(3) UTC | D-014 (provisional, T2) |
| DV-03 | Other column types (P3 tables: VARCHAR(10), DATE, SMALLINT) | Not specified | §3.3 | This WO |
| DV-04 | Key generation | Not specified | `IDENTITY(1,1)` on `INVOICE.Invoice_ID` only | This WO (alternatives: SEQUENCE, application keys) |
| DV-05 | Nullability (P3 tables) | Not specified | §3.3 | This WO |
| DV-06 | CHECK and DEFAULT constraints (P3 tables) | BRs in prose | §3.4 | D-004, D-005, D-011, D-013, D-023, this WO |
| DV-07 | `SpendingMonth` | Name only | `DATE`, first day of the Asia/Ho_Chi_Minh month of `PaidAt`, CHECK `DAY() = 1` | D-013 (approved) |
| DV-08 | Production tables | 25 entities | 4 P3-owned tables only | D-026 (restricted), Owner scope matrix |
| DV-09 | `LineNo` | Plain name | Same name, written `[LineNo]` (not a rename) | T-SQL syntax |
| DV-10 | Shared parents in the isolated database | Full entities | Key-only TEST_ONLY fixtures of 5 tables (a test artifact, not a schema deviation) | D-026 (restricted) |

No table, column, key or relationship of §10 is renamed or removed.

### 3.8 Object ownership inventory

| Object | Type | Classification | Created by |
|---|---|---|---|
| INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM, MEMBER_MONTHLY_SPENDING | Tables | P3_OWNED | V001 |
| PKs, 8 FKs, CK_INVOICE_SERVICE_ITEM_Validity | Constraints | P3_OWNED | V001 |
| `PaidAt`, 12 CHECKs, 4 DEFAULTs of §3.4 | Column and constraints | P3_OWNED | V002 |
| MEMBER, BRANCH, EMPLOYEE, SERVICE_PLAN, PRODUCT (key-only) and their PKs | Tables, constraints | TEST_ONLY_FIXTURE (entity: SHARED_DEPENDENCY) | F001, isolated database only |
| `rebuild_isolated_db.sql`, T-SCH-01, T-SCH-02, V-TOT | Scripts | TEST_ONLY | tests/ |
| DL-01 | Document | P3_OWNED | docs/ |

## 4. Tasks

**Migration approach:** forward-only production migrations applied once, in order, to a database that already contains the shared parent keys. In the isolated database those keys come from F001 (TEST_ONLY); in the team database, from the team schema. Re-runnability is shown by rebuilding the disposable database from nothing.

0. **Repository cut-over** (D-021 Part A). Confirm the clone is clean and `main` is at `792a85e` or a fast-forward of it. Create branch `p3/wo-p3-p1-01`. Copy `CLAUDE.md`, `docs/agent/` and `docs/phase2/person3/` from `C:\CSDLNC- DA` unchanged (verify checksums); never copy source documents (PDFs) or secrets. Add `.gitignore` and `.gitattributes` (as proposed in [package §E.3](../design/P0_FINAL_DECISION_PACKAGE.md#e3-proposed-repository-files)). Leave `C:\CSDLNC- DA` **untouched** (immutable archive). Update the agent's project memory for `C:\CSDLNC- DA` so that later sessions opened there are told to work in the clone. From here on, edit only in the clone. Do not change `README.md`.
1. **SQL Server preflight** (read-only; D-002). Save as `ENV-P1__<YYYYMMDD-HHMM>.txt`:
   1. version and edition: `@@SERVERNAME`, `@@VERSION`, `SERVERPROPERTY('ProductVersion')`, `'ProductMajorVersion'`, `'Edition'`, `'EngineEdition'`, `'Collation'`;
   2. compatibility level 160 available (stop if not);
   3. environment record: `SYSUTCDATETIME()`, `SYSDATETIMEOFFSET()`, database list before the run, session SET options under `sqlcmd -I`;
   4. logical-model conformance: compare §3.2–§3.4 and §3.3a with S-02 §10; every difference must be in §3.7 (stop otherwise); record the result in DL-01.
2. Write `db/migrations/V001…` and `V002…` (P3 tables only; §3.3, §3.4).
3. Write `tests/db/fixtures/F001__TEST_ONLY_shared_dependency_keys.sql` (§3.3a). Guard: refuse unless the database name matches `FitLife_P3_%` and none of the 5 tables already exists.
4. Write `tests/db/build/rebuild_isolated_db.sql`. Guard: target name must match `FitLife_P3_%`. Steps: drop the database if it exists (SINGLE_USER WITH ROLLBACK IMMEDIATE); create it; set compatibility level 160; apply F001 (only while no approved team schema exists); apply V001, then V002; stop on the first error. It contains a separate, equally guarded drop section for rollback.
5. Write `tests/db/schema/T-SCH-01_constraints.sql` (§8.1); all rows inside a transaction that is rolled back.
6. Write `tests/db/schema/T-SCH-02_conformance.sql` (§8.2).
7. Write DL-01 `docs/phase2/person3/design/PHYSICAL_DESIGN_TABLE.md` ([05 §14](../05_PHYSICAL_DESIGN_PLAN.md#14-physical-design-table-format-deliverable-dl-01)): the four P3 tables, the scope matrix, the fixture list (marked TEST_ONLY), the deviation register and the preflight result.
8. Run: rebuild → T-SCH-01 → T-SCH-02 → rebuild → T-SCH-01 → T-SCH-02; run the separation check (§8.3). Save every output.
9. Update in the clone: [01](../01_REQUIREMENTS_TRACEABILITY.md) (RQ-A01, RQ-A13, RQ-P07, RQ-P08, RQ-P09, RQ-P16), [13](../13_DELIVERABLES_AND_EVIDENCE.md) (DL-01, DL-03), [16](../16_READINESS_REPORT.md), [SESSION_LOG.md](../SESSION_LOG.md), this WO's §13.
10. Record `git status` and `git diff --stat`. Commit only if commits were authorized in the approval.

## 5. Out of scope and forbidden operations

P1 does **not** include:

- any real implementation of MEMBER, MEMBER_TIER, BRANCH, EMPLOYEE, SERVICE_PLAN or PRODUCT, or of any OUT_OF_SCOPE table;
- check-in/check-out, PT scheduling, PT sessions or commissions, employee assignment history, payroll, member registration, inventory workflows, branch, service-plan or product administration, other members' user interfaces;
- payment-processing or billing logic (invoice finalisation, settlement, cancellation) — later UC05 WOs;
- loyalty business procedures (points, spending updates, tier evaluation) — WO-P3-P3-02;
- stored procedures, functions, triggers and views;
- performance indexes, partitioned tables or indexes, partition experiments;
- seed generators, large datasets, benchmarks;
- application code;
- `ClientRequestKey`, summary tables, RCSI or other database options beyond the compatibility level.

Forbidden operations:

- Any database other than `FitLife_P3_P1`; any change to the shared team database (D-025 condition 7; D-026 condition 7).
- Deploying TEST_ONLY fixtures anywhere except the isolated database, or presenting them as the canonical schema of another member's module.
- Installing, upgrading or reconfiguring SQL Server.
- Changing `README.md`, another member's files, master prompt §1–§16, or decision statuses in [03](../03_DECISION_LOG.md).
- Renaming §10 tables or columns, or changing §10 keys or relationships.
- Any commit without explicit authorization; any push, pull request, merge or visibility change.
- Modifying anything in `C:\CSDLNC- DA` (immutable archive).
- Copying source documents or secrets into the clone; storing credentials anywhere.

## 6. Deliverables and permitted files

All paths are inside the clone, on branch `p3/wo-p3-p1-01`.

| Action | Paths | Classification |
|---|---|---|
| Create | `db/migrations/V001__p3_billing_and_spending_tables.sql`, `db/migrations/V002__p3_settlement_and_spending_constraints.sql` | P3_OWNED (production) |
| Create | `tests/db/fixtures/F001__TEST_ONLY_shared_dependency_keys.sql`, `tests/db/build/rebuild_isolated_db.sql`, `tests/db/schema/T-SCH-01_constraints.sql`, `tests/db/schema/T-SCH-02_conformance.sql` | TEST_ONLY |
| Create | `docs/phase2/person3/design/PHYSICAL_DESIGN_TABLE.md` (DL-01); evidence files of §9 | P3_OWNED (documentation) |
| Create | `.gitignore`, `.gitattributes` | Repository files (content for team ratification, D-021 Part B) |
| Copy unchanged (step 0) | `CLAUDE.md`, `docs/agent/**`, `docs/phase2/person3/**` | — |
| Update | `docs/phase2/person3/01_…`, `13_…`, `15_…` (status), `16_…`, `SESSION_LOG.md`, `work-orders/README.md` (status), this file | — |

DL-03 = the two production migrations. The fixture and build scripts are test tools, not deliverables for the shared schema.

## 7. Acceptance criteria

1. **Preflight PASS:** version, edition, collation and compatibility-level support recorded; level 160 available; conformance with S-02 §10 confirmed, every difference in §3.7.
2. **T-REPRO-01 PASS:** the build creates `FitLife_P3_P1` from nothing and applies F001, V001 and V002 without error, twice, with identical T-SCH-02 output.
3. **T-SCH-01 PASS:** every positive case accepted; every negative case rejected by the named constraint (or NOT NULL where stated); V-TOT returns zero rows for the consistent fixture graph and exactly the inconsistent invoice for P06.
4. **T-SCH-02 PASS:** zero differences for the four P3 tables, including the FK verification (8 FKs) and the classification check of all 9 tables.
5. **Separation PASS (§8.3):** production migrations create or alter only the four P3 tables; F001 creates only the five key-only fixtures; no fixture has a column, constraint or index beyond its PK.
6. Names, keys and relationships of the P3 tables equal S-02 §10; the only differences are those in §3.7.
7. No nonclustered index, trigger, procedure, function, view, partition function or scheme exists.
8. DL-01 lists every P3 column and constraint with source label and decision ID, the scope matrix, the fixtures (TEST_ONLY), the deviation register and the preflight result.
9. The database list after the run differs from the one before only by `FitLife_P3_P1`; `C:\CSDLNC- DA` unchanged (file checksums before and after step 0).
10. Only the files of §6 changed (`git status`); `README.md` unchanged; no secrets or source documents in the clone; nothing pushed. Documents of task 9 updated; §13 filled.

## 8. Verification (smoke, integrity, FK and separation tests)

### 8.1 T-SCH-01 cases

Every case starts from fixture rows (MEMBER, BRANCH, EMPLOYEE, SERVICE_PLAN, PRODUCT keys) inserted by the fixture-data block.

Positive (smoke) cases:

- **P01** A PENDING invoice with one service line and one product line whose header totals equal the lines is accepted.
- **P02** PENDING→PAID with `PaymentMethod` and `PaidAt ≥ IssuedAt` (UTC values) is accepted.
- **P03** PENDING→CANCELLED with no `PaidAt` is accepted; a PENDING invoice with a method recorded at creation is accepted (S2).
- **P04** A spending row on the first day of a month is accepted.
- **P05** V-TOT returns zero rows for the P01 graph.
- **P06** An invoice whose header Gross differs from its lines is **accepted by every CHECK** (cross-table rule) and **reported by V-TOT**.

Negative cases:

| # | Case | Expected rejection |
|---|---|---|
| N01 | Status `'DONE'` | CK_INVOICE_PaymentStatus |
| N02 | Method `'BITCOIN'` | CK_INVOICE_PaymentMethod |
| N03 | PAID with `PaidAt` NULL | CK_INVOICE_PaidAtStatus |
| N04 | PENDING or CANCELLED with `PaidAt` set | CK_INVOICE_PaidAtStatus |
| N05 | `PaidAt` earlier than `IssuedAt` | CK_INVOICE_PaidAtAfterIssued |
| N06 | PAID with method NULL | CK_INVOICE_MethodWhenPaid |
| N07 | Negative GrossAmount; negative DiscountAmount; Discount > Gross | CK_INVOICE_Amounts |
| N08 | FinalAmount ≠ Gross − Discount | CK_INVOICE_FinalAmount |
| N09 | Invoice with unknown member, branch or employee key | FK_INVOICE_MEMBER / _BRANCH / _EMPLOYEE |
| N10 | Invoice with NULL `PaymentStatus` or NULL `Member_ID` | NOT NULL (error 515) |
| N11 | `SpendingMonth` = 2026-11-15 | CK_MEMBER_MONTHLY_SPENDING_FirstDay |
| N12 | Duplicate (Member_ID, SpendingMonth) | PK_MEMBER_MONTHLY_SPENDING (error 2627) |
| N13 | Negative TotalSpend or PointsEarned | CK_MEMBER_MONTHLY_SPENDING_NonNegative |
| N14 | Spending row for an unknown member key | FK_MEMBER_MONTHLY_SPENDING_MEMBER |
| N15 | Service line with `ValidUntil < ValidFrom` | CK_INVOICE_SERVICE_ITEM_Validity |
| N16 | Product line with Quantity 0 | CK_INVOICE_PRODUCT_ITEM_Quantity |
| N17 | Negative line price or discount; line discount greater than line gross | CK_INVOICE_SERVICE_ITEM_Amounts; CK_INVOICE_PRODUCT_ITEM_Amounts |
| N18 | Line with unknown invoice, plan or product key | FK_INVOICE_SERVICE_ITEM_* / FK_INVOICE_PRODUCT_ITEM_* |
| N19 | Delete a referenced fixture row (member, branch, employee, plan, product) or a referenced invoice | The referencing P3 FK (no cascade) |

Each case prints `PASS <case>` or `FAIL <case>: <actual error>`; the script raises an error if any case failed. Transition invariants T1–T5 are tested in WO-P3-P3-01.

### 8.2 T-SCH-02 checks

1. Columns of the four P3 tables: name, type, length, precision, scale, nullability, identity — equal §3.3.
2. Constraints of the four P3 tables: every PK, CHECK and DEFAULT name of §3.4 on the right table; no extra constraint.
3. **FK verification:** exactly 8 FKs, all owned by P3 tables, each with the child column, parent table and parent key of §3.6 (= S-02 §10); NO ACTION on delete and update; `is_disabled = 0`, `is_not_trusted = 0`.
4. **Classification:** exactly 9 user tables. The 5 fixtures carry `Classification = 'TEST_ONLY_FIXTURE'` and consist of one key column and its PK only; the 4 P3 tables carry no fixture marker.
5. Object inventory: no views, procedures, functions, triggers, partition functions or schemes; the only indexes are PK indexes.
6. Every CHECK enabled and trusted; database compatibility level 160.

### 8.3 Separation check (static, read-only)

Search the scripts and record the result: `db/migrations/` creates or alters only INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM and MEMBER_MONTHLY_SPENDING; `tests/db/fixtures/` creates only the five fixture tables and nothing outside `CREATE TABLE … PRIMARY KEY` and the classification property; no file under `db/` references the fixture script.

## 9. Evidence

Saved in the clone under `docs/phase2/person3/evidence/test-results/`: `ENV-P1__<ts>.txt` (preflight, database lists, archive checksums), `T-SCH-01__<ts>.txt`, `T-SCH-02__<ts>.txt`, `T-REPRO-01__<ts>.txt`, `SEPARATION-P1__<ts>.txt`. Plus `git status` / `git diff --stat` in §13. No credentials in any file.

## 10. Dependencies and risks

| Risk | Mitigation |
|---|---|
| R-25 scope creep: shared tables built as P3 modules, or fixtures mistaken for the canonical schema | Key-only fixtures, TEST_ONLY marker, separation check, replacement before integration |
| R-03 shared schema drift: the team's real parents differ from the fixture keys | Keys follow Phase 1 and D-014; T-INT-03 after replacement; the contract in 12 §2a |
| R-13 late schema change | `PaidAt` and its CHECKs isolated in V002 |
| R-22 time-zone errors | UTC storage; local-month rules tested in UC05 (T-F05-10) |
| R-23 isolated database drift | Rebuilt from scripts every time; T-SCH-02 |
| R-24 public repository | No push authorized |

## 11. Approval requirements

The Owner passes GATE-P0 (sets WO-P3-P0-03 to `PASSED`) and approves this WO:

> "GATE-P0 passed (WO-P3-P0-03 PASSED). WO-P3-P1-01 APPROVED, mode BUILD_AUTHORIZED, scope as revised on 2026-11-07 (four P3-owned tables; TEST_ONLY key fixtures). Target database `FitLife_P3_P1` on instance <MSSQLSERVER>. Authorized: the SQL Server preflight (read-only queries); create, rebuild and drop that database; copy the planning documents into the clone and work on branch `p3/wo-p3-p1-01`. Local commits: <authorized / not authorized>. Push, PR, merge and visibility changes: not authorized. — Project Owner, <date>"

Team review of V001, V002, the fixture keys and the provisional decisions is required before any integration or merge.

## 12. Exit, rollback and next step

**Rollback:** (1) run the guarded drop section for `FitLife_P3_P1` and confirm it is gone; no other database is involved. (2) All file changes are on the local branch; discard by switching to `main` and deleting the branch, after the Owner confirms. Nothing is pushed. (3) `C:\CSDLNC- DA` is never modified, so every planning document can be restored from it.

**Exit:** set the WO to `VERIFIED` when acceptance criteria 1–10 hold; only the Owner sets `PASSED` (GATE-P1). The isolated database stays for inspection; later WOs rebuild it.

**Expected final handoff** (master prompt §15): mode and WO; branch and `git status`; files; preflight facts; T-SCH-01, T-SCH-02, T-REPRO-01 and separation results (PASS, FAIL or NOT_RUN with reason); evidence paths; deviations; outstanding decisions; proposed status `VERIFIED`; next WOs.

**Next:** [WO-P3-P1-02](WO-P3-P1-02_INTEGRATION_CONTRACT.md) (contract, including the shared-dependency interface; parallel) and [WO-P3-P0-02](WO-P3-P0-02_ENVIRONMENT_BASELINE.md) (feature probes), then WO-P3-P2-01 after GATE-P1 and the P2 decisions. _(Revised 2026-11-08, D-027: WO-P3-P1-02 is deferred to P6; the next priority after GATE-P1 is WO-P3-P2-01, with WO-P3-P0-02 before WO-P3-P2-02.)_

## 13. Execution record

**2026-11-07, mode BUILD_AUTHORIZED, single session.** Working copy `C:\Users\DELL\source\repos\CSDLNC-DA`, branch `p3/wo-p3-p1-01` (from `main` at `792a85e`). Nothing committed, pushed or merged.

**Step 0 — cut-over.** The clone was clean and `main` was still at `792a85e` (remote unchanged). `CLAUDE.md`, `docs/agent/**` and `docs/phase2/person3/**` (47 files, 588 KB; no secrets, source PDFs, datasets or credentials) were copied once; SHA-256 of all 47 copies equal the originals. `.gitignore` and `.gitattributes` added (proposed content; D-021 Part B). `C:\CSDLNC- DA` was left unchanged (47/47 checksums re-verified after the copy) and its files were marked read-only to keep it immutable (reversible with `attrib -R /S`). The agent memory for that folder now redirects to the clone.

**Step 1 — preflight** ([ENV-P1](../evidence/test-results/ENV-P1__20261107-1138.txt)): SQL Server 2025 RTM 17.0.1000.7, Standard Developer Edition (64-bit), EngineEdition 2, default instance, collation `SQL_Latin1_General_CP1_CI_AS`; connection over shared memory to the local computer; maximum compatibility level 170, so 160 is supported; login is sysadmin; host offset +07:00 (storage is UTC); `FitLife_P3_P1` did not exist; the other databases on the instance (QLDT1, NHAHANG, FOOD_DELIVERY_PRACTICE, ONTAP_SQL) are unrelated and were not touched. Logical-model conformance with S-02 §10: **PASS**. `PREFLIGHT_RESULT: PASS`. Note: `@@SERVERNAME` still reports the host's former name (benign after a rename; only replication cares).

**Acceptance criteria**

| AC | Result | Evidence |
|---|---|---|
| 1 Preflight | **PASS** | ENV-P1 |
| 2 T-REPRO-01 | **PASS**: two builds from nothing (F001 → V001 → V002), both `BUILD_RESULT: OK`; T-SCH-01 and T-SCH-02 outputs byte-identical across the two builds; safe-procedure check SAFETY-1 PASS (without the `P3_Disposable` marker the build refused to drop the database, error 51011, and the database kept its 9 tables) | [T-REPRO-01](../evidence/test-results/T-REPRO-01__20261107-1154.txt) |
| 3 T-SCH-01 | **PASS**: 54 results — 9 positive PASS, 43 negative PASS (each rejected by the named constraint or error 515/2627), 1 INFO (I01), POST PASS (all test rows rolled back); V-TOT 0 rows for consistent invoices, exactly the inconsistent invoice for P06 | [T-SCH-01](../evidence/test-results/T-SCH-01__20261107-1154.txt) |
| 4 T-SCH-02 | **PASS** 6/6: 35 columns, 34 constraints (9 PK, 8 FK, 13 CHECK, 4 DEFAULT, 0 UNIQUE), 8 FKs NO ACTION/enabled/trusted and all on P3 tables, classification (4 P3 tables unmarked, 5 fixtures `TEST_ONLY_FIXTURE` with 1 column and only a PK), no other objects, compatibility level 160 | [T-SCH-02](../evidence/test-results/T-SCH-02__20261107-1154.txt) |
| 5 Separation | **PASS**: migrations create/alter only the 4 P3 tables and never reference fixtures; F001 creates only the 5 key-only fixtures; no test script creates indexes, routines, triggers or views | [SEPARATION-P1](../evidence/test-results/SEPARATION-P1__20261107-1148.txt) |
| 6 Names, keys, relationships = §10 | **PASS** (preflight conformance; deviations only DV-01…DV-10) | ENV-P1; [DL-01 §6](../design/PHYSICAL_DESIGN_TABLE.md#6-deviation-register-differences-from-s-02-10) |
| 7 No extra objects | **PASS** (T-SCH-02 C5: no views, routines, triggers, partition objects; only PK indexes) | T-SCH-02 |
| 8 DL-01 complete | **PASS** | [PHYSICAL_DESIGN_TABLE.md](../design/PHYSICAL_DESIGN_TABLE.md) |
| 9 Database list and archive | **PASS**: after the runs the only new database is `FitLife_P3_P1` (compatibility 160, SIMPLE); archive checksums unchanged | T-REPRO-01 vs ENV-P1 |
| 10 Files, no secrets, nothing pushed; docs updated | **PASS**: only §6 paths plus the two additions below; `README.md` unchanged; no commit; 01, 13, 15, 16, SESSION_LOG, this record updated | `git status` below |

**Defects found and fixed during trial runs (test scripts only; the schema needed no change):** (1) T-SCH-02 used subqueries inside `INSERT … VALUES` (error 1046) → values precomputed into variables; (2) T-SCH-02 used a subquery inside `PRINT` (error 1046) → variable; (3) T-SCH-02 concatenated catalog columns with different collations in `STRING_AGG` (error 4191) → `COLLATE DATABASE_DEFAULT`. The recorded evidence runs used the corrected scripts.

**Deviations from this WO's text (all additions):**

1. `tests/db/build/preflight_p1.sql` — the read-only preflight as a file (§9 requires identifiable artifacts); TEST_ONLY.
2. `tests/db/build/drop_isolated_db.sql` — the guarded rollback drop as a separate file instead of "a section" of the build script, because sqlcmd cannot run a section conditionally.
3. The build script also refuses to run on a non-Developer edition (extra safety).
4. T-SCH-01 has more cases than §8.1: positives P07 (UTC defaults), P08 (valid BR13 validity and PT sessions), P09 (direct PAID with CARD); negatives split into sub-cases and N20 (duplicate line keys), N21 (duplicate Invoice_ID), N22 (PAID→PENDING keeping PaidAt); informational I01 documents that a PAID→PENDING reversal with PaidAt and method cleared is accepted by the schema (transition rules belong to the UC05 routines).
5. SAFETY-1 (marker-guard test) added to T-REPRO-01.
6. Archive files marked read-only (directive: no two editable authoritative copies).
7. **Evidence run `20261107-1148` superseded by `20261107-1154`.** The first recorded T-REPRO-01 file printed the machine name, which contains a personal name, inside a SQL Server error line. Evidence is never edited, so the whole series (SAFETY-1, two builds, T-SCH-01 and T-SCH-02 twice) was re-run with the machine name masked at capture as `<local-server>`; the results were identical (all PASS). The three superseded files were moved out of the repository (kept in the session scratchpad, not committed anywhere). `SEPARATION-P1__20261107-1148` and `ENV-P1__20261107-1138` contain no machine name and remain.

**Required UNIQUE constraints:** none on the P3-owned tables (the UNIQUE rules on MEMBER_TIER belong to its owner, 12 §2a).

**Repository state at the end** (`git status --short`, branch `p3/wo-p3-p1-01`, no commits): untracked `.gitattributes`, `.gitignore`, `CLAUDE.md`, `docs/` (52 files incl. DL-01 and 5 evidence files), `db/migrations/V001…`, `db/migrations/V002…`, `tests/db/build/preflight_p1.sql`, `tests/db/build/rebuild_isolated_db.sql`, `tests/db/build/drop_isolated_db.sql`, `tests/db/fixtures/F001…`, `tests/db/schema/T-SCH-01…`, `tests/db/schema/T-SCH-02…`. `README.md` unchanged. Remote unchanged.

**Database state at the end:** `FitLife_P3_P1` exists (empty tables, marked disposable), left for inspection as §12 states; rollback = `tests/db/build/drop_isolated_db.sql`.

**Documentation audit** (read-only script, clone, after all edits): PASS, 30 of 30 checks (links and anchors, IDs, decision states, scope matrix and separation, evidence files with PASS results, machine name absent, master prompt section 1-16 unchanged, no secrets).

**Status:** `VERIFIED`. The Owner sets `PASSED` (GATE-P1). Not started: WO-P3-P1-02, P2, P3.

## 14. Owner acceptance (GATE-P1)

**2026-11-08, Owner Directive "Approve P1 and Execute P2-01" (Claude Code session of 2026-11-08), §1.** The Owner accepted this WO on its `VERIFIED` status, provided the recorded evidence and the 10 acceptance criteria remain valid. Re-check performed before setting `PASSED` (read-only; P1 was not re-implemented and `FitLife_P3_P1` was not modified):

| Check | Result |
|---|---|
| The five P1 evidence files exist and end in PASS (`PREFLIGHT_RESULT`, `CONFORMANCE_RESULT`, `SEPARATION_RESULT`, `T-REPRO-01_RESULT`, T-SCH-01 54 cases / 0 FAIL, T-SCH-02 6 checks / 0 FAIL) | PASS |
| The migrations, fixture and test scripts were last modified before the evidence run (11:41–11:48 UTC vs 11:54 UTC on 2026-11-07); unchanged since (checksum snapshot of 2026-11-08) | PASS |
| T-SCH-02 re-run read-only against `FitLife_P3_P1`: output identical to the recorded run A line for line (only the capture footer differs) | PASS |
| `FitLife_P3_P1` still holds its 9 empty tables and its disposable marker; compatibility 160, SIMPLE | PASS |
| `README.md` unchanged; nothing committed or pushed; archive `C:\CSDLNC- DA` unchanged | PASS |

Evidence: [GATE-P1-RECHECK__20261108-0337.txt](../evidence/test-results/GATE-P1-RECHECK__20261108-0337.txt). Two earlier attempts to write this file in the same session were defective recordings (a PowerShell variable-name collision, then an unsupported wildcard that left section 1 empty); they contained no P1 result, were moved out of the repository to the session scratchpad and are not evidence. No inconsistency was found in P1 itself, so the WO is set to `PASSED` and **GATE-P1 is closed**. All P1 migrations and verification evidence are preserved unchanged.
