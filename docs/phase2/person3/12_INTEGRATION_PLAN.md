# 12 — Integration Plan (Person 3)

| Field | Value |
|---|---|
| Document status | DRAFT — WO-P3-BOOT-001; §2b dependency register, §14 P6 sequence and §13 timing added by the Owner Directive "Reprioritize Person 3 Implementation" (2026-11-08, D-027); DEP-14, DEP-15 added by WO-P3-P3-00 (2026-11-09) |
| Date | 2026-11-09 |
| Current state | No shared repository, schema or code from other members is accessible (S-12, S-13). Member-to-UC ownership is unknown (S-10 MISSING). Everything here is a **proposal** for the integration contract (DL-02), which WO-P3-P1-02 negotiates **at P6** (D-027). Until then P3 develops independently against the interface of §2a and the assumptions of §2b. |
| Decisions | D-001, D-012, D-014, D-019, D-020, D-021 |

## 1. Purpose

Make sure P3's billing, loyalty and revenue work fits the team's shared schema and code without overwriting or duplicating other members' work, and that the settlement transaction meets S-02 §7.2: payment consistent with entitlements, inventory, points and spending.

## 2. Shared-table ownership matrix (proposed)

Updated 2026-11-07 to the Owner's strict Person 3 scope. Classes as in [WO-P3-P1-01 §3.2](work-orders/WO-P3-P1-01_PHYSICAL_SCHEMA.md#32-scope-matrix-directive-strict-person-3-scope-enforcement).

| Table | Class | Schema owner | Writers | P3 access |
|---|---|---|---|---|
| INVOICE | P3_OWNED | **P3** | P3 (billing: create and finalise; settlement). Other members' sale flows call the P3 billing interface (D-012, open) | Full |
| INVOICE_SERVICE_ITEM | P3_OWNED | **P3** | P3 (insert at billing); entitlement activation writes `ValidFrom`, `ValidUntil`; PT owner writes `PTSessionsRemaining` (owners per D-001/D-012) | Full; check-in and PT read |
| INVOICE_PRODUCT_ITEM | P3_OWNED | **P3** | P3 | Full |
| MEMBER_MONTHLY_SPENDING | P3_OWNED | **P3** | P3 | Full |
| Revenue summary (if D-015) | P3_OWNED | **P3** | P3 (per D-016) | Full |
| MEMBER | SHARED_DEPENDENCY | Profile owner (TBD) | Profile owner (F03); **P3 for CurrentPoints, Tier_ID** | Read; write P3 columns only |
| MEMBER_TIER | SHARED_DEPENDENCY | Team (TBD) | Tier-table owner; threshold values supplied by P3 (D-008) | Read |
| BRANCH, EMPLOYEE | SHARED_DEPENDENCY | Team / HR owner | Their owners | Read (identifiers; report grouping) |
| SERVICE_PLAN, PRODUCT | SHARED_DEPENDENCY | Catalogue owner (TBD) | Their owners | Read (identifiers) |
| BRANCH_INVENTORY | OUT_OF_SCOPE | Inventory owner | Inventory routines (F19) | None; reached only through the agreed settlement hook (D-012) |
| Other Phase 1 tables (check-in, access points, PT, facilities, branch services, employee subtypes and assignments, salary, payroll) | OUT_OF_SCOPE | Other members | Their owners | None |

## 2a. Shared-dependency interface required by P3

Until the integration contract (DL-02, WO-P3-P1-02, deferred to P6 by D-027) is agreed, this table **is** the documented interface through which P3 references shared tables. P3 does not implement these tables. A missing shared schema never justifies building another member's module (D-026, restricted).

| Shared table | Key P3 needs (Phase 1 name, D-014 type) | Columns P3 reads or writes | Constraints P3 relies on (proposed to the owner; team review) | TEST_ONLY fixture in P1 |
|---|---|---|---|---|
| MEMBER | `Member_ID INT` PK | Later (UC05): writes `CurrentPoints`, `Tier_ID` | `CurrentPoints INT NOT NULL DEFAULT 0`, `CurrentPoints >= 0`; `Tier_ID NOT NULL` FK → MEMBER_TIER (BR04) | Key only |
| MEMBER_TIER | `Tier_ID INT` PK (through MEMBER) | Reads `Tier_Name`, `SpendingThreshold` (UC05) | UNIQUE `Tier_Name`; UNIQUE `SpendingThreshold`; `SpendingThreshold >= 0`; base tier with threshold 0 (D-008) | None in P1 |
| BRANCH | `Branch_ID INT` PK | Reads `Branch_ID` (later `Branch_Name` for report labels) | — | Key only |
| EMPLOYEE | `Employee_ID INT` PK | Reads `Employee_ID` | — | Key only |
| SERVICE_PLAN | `Plan_ID INT` PK | Reads `Plan_ID` (later `Plan_Name` for candidate reports) | — | Key only |
| PRODUCT | `Product_ID INT` PK | Reads `Product_ID` (later `Product_Name`) | — | Key only |

Fixture rules: [WO-P3-P1-01 §3.3a](work-orders/WO-P3-P1-01_PHYSICAL_SCHEMA.md#33a-test_only-dependency-fixtures-isolated-database-only). Before final integration the fixtures are replaced by the approved team schema and T-SCH-01, T-SCH-02 and T-INT-03 are re-run (D-026 condition 9).

## 2b. Dependency register (interim assumptions until P6)

Added 2026-11-08 (D-027). This is a **minimal register of assumptions** about shared interfaces that P3 relies on during independent development (P2–P5). It is **not** the integration contract, needs no team approval and blocks no P2–P5 work. Each row says what stands in for the shared object in isolated databases and when the assumption is verified. WO-P3-P1-02 resolves every row at P6.

Rules: (1) a new assumption gets a row before the WO that relies on it is executed; (2) a stand-in is a TEST_ONLY fixture (Phase 1 names and types, no business logic; D-026 restricted) or a contract-only test double (agreed signature, records the call, can raise an error on request; no stock, entitlement or other domain logic); (3) a finding that contradicts a row is recorded here and as an integration risk (R-26), and is escalated immediately only if it makes the current implementation invalid or unsafe.

| ID | Assumption about a shared interface | P3 work that relies on it | Stand-in in isolated databases | Verified at P6 by | State |
|---|---|---|---|---|---|
| DEP-01 | Shared keys keep their Phase 1 names and D-014 types: `MEMBER.Member_ID`, `BRANCH.Branch_ID`, `EMPLOYEE.Employee_ID`, `SERVICE_PLAN.Plan_ID`, `PRODUCT.Product_ID`, all `INT` primary keys | The 8 FKs of V001; seed; every query joining them | F001 key-only fixtures | T-INT-03; T-SCH-01/02 re-run on the team schema | ASSUMED |
| DEP-02 | `MEMBER.CurrentPoints INT NOT NULL` (default 0) and `MEMBER.Tier_ID INT NOT NULL` FK → MEMBER_TIER exist, and P3 is their only writer | Settlement (WO-P3-P3-01), tier batch and lookup (WO-P3-P3-02), Q-UC05-B/C | F002 fixture extension (deferred by the Owner on 2026-11-08 until its first justified consumer, with the Q-UC05-B/C baseline captured before any loyalty index; Phase 1 columns and the Phase 1 FK only; the CHECKs proposed in §2a stay with the owner, and P3 tests assert the properties directly) | Contract item 4; T-INT-03 | ASSUMED. 2026-11-09: settlement (WO-P3-P3-01) increments `MEMBER.CurrentPoints` in its transaction; stand-in = **F002P** (TEST_ONLY, `CurrentPoints INT NOT NULL DEFAULT 0` only; no Tier_ID, no MEMBER_TIER; Owner-approved points-only subset)  2026-11-09: tier part added as **F002T** (TEST_ONLY MEMBER.Tier_ID NOT NULL + FK, all members start on the base tier); `Tier_ID` is written only by `usp_P3_EvaluateTiers` (and the REFERENCE_ONLY U0) |
| DEP-03 | MEMBER_TIER has `Tier_ID`, `Tier_Name`, `SpendingThreshold`; three tiers; base tier with threshold 0; threshold values supplied by P3 (D-008) | Tier batch, lookup, Q-UC05-B/C | F002T (TEST_ONLY): Silver 0 + **synthetic** Gold and Platinum thresholds, because the D-008 values are not approved (only the rule, 2026-11-09). The real values reach MEMBER_TIER through its owner at P6 | Contract item 4 | ASSUMED |
| DEP-04 | The callers of the P3 billing interface (plan and product sale flows) supply `UnitPrice` and `DiscountAmount` per line; P3 does not read catalogue prices | Invoice creation (WO-P3-P3-00, D-028); seed | Seed configuration price list (TEST_ONLY, deterministic per key); test inputs | Contract items 4, 5, 12 | ASSUMED. **Integration requirement (D-028 Q4, approved 2026-11-09):** the calling sale flows are authorized, trusted components and are responsible for validating `UnitPrice` and `DiscountAmount` against the authoritative plan/product catalogue **before** calling; P3 validates only monetary consistency (non-negative, discount ≤ line gross, quantity > 0, range) and derives the header totals. P3 makes no catalogue-validation claim and implements no catalogue logic |
| DEP-05 | The inventory decrement (UC04 owner) and entitlement activation (UC01 owner) can be called inside the P3 settlement transaction with the interface of §5, follow §4 and the lock order of §6, and raise an error to abort | Settlement orchestration (WO-P3-P3-01, D-012 provisional) | Contract-only test doubles in the isolated database | T-INT-01, T-INT-02, T-CONC-05 with the real routines | ASSUMED. 2026-11-09 (D-012 (a) APPROVED T2): names and signature assumed by `usp_P3_SettleInvoice`: `dbo.usp_HOOK_InventoryDecrementForInvoice @Invoice_ID INT` and `dbo.usp_HOOK_EntitlementActivationForInvoice @Invoice_ID INT`, each called exactly once per settlement, inventory first, inside the open transaction, before the PENDING→PAID update; abort by raising an error. Doubles: `tests/db/doubles/D001…` |
| DEP-06 | `INVOICE_SERVICE_ITEM.ValidFrom`, `ValidUntil` (entitlement owner) and `PTSessionsRemaining` (PT owner) are written by those owners; P3 inserts them as NULL and no P3 query reads them | Invoice creation; seed; UC06 queries | Left NULL; no simulated activation or PT workflow | Contract item 4 | ASSUMED |
| DEP-07 | Every member stores timestamps in UTC and reports in Asia/Ho_Chi_Minh (D-014) | Spending month, revenue periods, boundary tests | — (P3 tables follow it) | Contract item 3 | ASSUMED |
| DEP-08 | Only `PaymentStatus = 'PAID'` counts as paid in every module (D-005) | Revenue definition (D-010); other members' entitlement checks | — | Contract item 3 | ASSUMED |
| DEP-09 | Other members' high-frequency queries on P3 tables (e.g. check-in reading INVOICE_SERVICE_ITEM) are unknown; P3 index decisions in P4 consider P3 queries only | Index decisions (WO-P3-P4-01) | — | T-REG-03 (WO-P3-P6-01) | OPEN |
| DEP-10 | `INVOICE.Employee_ID` is validated only by its FK; branch assignment of employees (out of scope) is not checked by P3 | Invoice creation; seed (the seed draws each invoice's employee key from a fixed block of keys per branch, a seed convention only; no assignment is stored) | F001 | Contract item 4 (the owner decides whether a rule is needed) | ASSUMED |
| DEP-11 | Another member (probably the check-in workload) can cover the project-level partition requirement if P3 rejects INVOICE partitioning | WO-P3-P5-01 conclusion | — | WO-P3-P1-02 at P6 (master prompt §8) | OPEN |
| DEP-12 | Database-wide options are team decisions: READ_COMMITTED_SNAPSHOT (D-019 b) and the client SET options of [08 §7](08_INDEX_AND_QUERY_PLAN.md#7-query-writing-rules); P3 isolated databases use the default READ COMMITTED (locking) and record the setting in every manifest | Concurrency tests; filtered indexes; benchmarks | Isolated database settings | Contract item 8 | ASSUMED |
| DEP-13 | P3 uses error numbers 51000–51999 and the result codes of §5 | UC05 routines (invoice creation uses 51101–51115 and the outcome `CREATED`, 2026-11-09) | — | Contract item 7 | ASSUMED |
| DEP-14 | Callers of invoice creation (other members' plan and product sale flows, the application) call `dbo.usp_P3_CreateInvoice` with the table types `dbo.tt_P3_InvoiceServiceLine` and `dbo.tt_P3_InvoiceProductLine`; their role needs EXECUTE on the procedure and on both types and no direct INSERT/UPDATE on the invoice tables (RQ-P15). Added 2026-11-09 | WO-P3-P3-00 (D-028 Q1, Q2) | TEST_ONLY role and user in T-F05-26 (created and dropped by the test); no permission deployed | Contract items 4, 5, 12; T-INT-04 | ASSUMED |
| DEP-15 | `INVOICE.IssuedAt` is the server UTC time at creation; callers cannot supply or back-date it (D-014). Added 2026-11-09 | WO-P3-P3-00; settlement tests with past dates (WO-P3-P3-01 T-F05-10) insert TEST_ONLY invoice rows directly | — | Contract item 4 (the owners of the sale flows confirm whether a supplied issue time is ever needed, e.g. offline sales) | ASSUMED |
| DEP-16 | Callers of invoice creation do not retry a creation blindly after a timeout: there is no database-level request deduplication (D-028 Q5 (a), approved 2026-11-09), so a retry can create a second, distinct PENDING invoice. The caller checks for, or cancels, a duplicate (a PENDING invoice has no business effect until settled). Exactly-once creation is not claimed; settlement stays idempotent per `Invoice_ID`. Added 2026-11-09 | WO-P3-P3-00 (T-F05-23) | — | Contract items 4, 5 (the sale-flow owners confirm their retry policy) | ASSUMED |
| DEP-17 | `INVOICE.PaidAt` is the server UTC time of the settlement call; callers cannot supply or back-date the payment time (the optional PaidAt input of §5 is not implemented). Added 2026-11-09 | WO-P3-P3-01 | — | Contract item 4 (e.g. offline or delayed payments would need an approved input) | ASSUMED |
| DEP-18 | Settlement payment method: optional at settlement; if NULL the method recorded at creation is used; a supplied method that differs from a recorded one is rejected (51208) instead of overwriting it. Added 2026-11-09 | WO-P3-P3-01 (T-F05-27) | — | Contract item 4 (the application owner confirms the rule) | ASSUMED |
| DEP-19 | The daily tier evaluation (D-009 (a)) is invoked once per day after local midnight by a scheduler that the team chooses at P6 (SQL Server Agent job, application job or another); P3 provides only the callable routine `usp_P3_EvaluateTiers(@AsOfDate)` (no job created; not authorized). The caller treats error 51324 (another run still active) as retryable. **2026-11-10 (T-CONC-07 T4, R-29):** the caller sets no client command timeout on this call, or closes/discards its connection after a timeout or cancel, because a client-cancelled run keeps the session-owned application lock until its session ends; recovery procedure and pre-integration tests in [14 §11.1](14_RISK_REGISTER.md#111-r-29-assessment--interrupted-tier-batch-keeps-its-application-lock). Added 2026-11-09 | WO-P3-P3-02 | Tests call the routine directly with explicit dates | Contract items 4, 8 | ASSUMED |
| DEP-20 | The owner of MEMBER_TIER loads the approved Gold and Platinum thresholds (D-008 values, still open) and keeps exactly one tier at 0 with unique non-negative thresholds; P3 routines refuse other configurations (51322/51323). Added 2026-11-09 | WO-P3-P3-02 | F002T synthetic values (TEST_ONLY) | Contract item 4 | ASSUMED |

## 3. Integration contract contents (DL-02)

1. UC catalogue and ownership (D-001).
2. Naming conventions: schema (`dbo` or per-module schemas), object prefixes, file naming in `db/` (D-021).
3. Shared type standard: keys, money, timestamps, time zone, status literals (D-005, D-014; approved provisionally 2026-11-07: timestamps stored in UTC, reporting in Asia/Ho_Chi_Minh — every member's timestamp columns should follow it, subject to team review).
4. Table ownership matrix (§2), the shared-dependency interface (§2a), and the column-level write rights on MEMBER, INVOICE and INVOICE_SERVICE_ITEM.
5. Settlement orchestration interface (§5) and transaction composition rules (§4).
6. Global lock order (§6).
7. Error-number ranges per member (P3 proposes **51000–51999**) and the result codes returned to the application.
8. Required client SET options (QUOTED_IDENTIFIER, ANSI_NULLS, etc.; [08 §7](08_INDEX_AND_QUERY_PLAN.md#7-query-writing-rules)).
9. Migration ordering and deployment script order (§7).
10. Seed pipeline ownership and the shared dataset tiers (§8).
11. Shared index registry (§9).
12. Application integration points (§10).
13. Change-control rule (§11).

## 4. Transaction composition rules

1. **One owner of the transaction:** the orchestrating routine begins and commits the settlement transaction. Sub-routines (inventory, entitlement, loyalty, revenue) never begin an independent transaction, and never commit or roll back the caller's.
2. Sub-routines check that a transaction is active and fail fast if they are called outside one, when they require one.
3. All routines run with `XACT_ABORT ON`. Errors propagate unchanged (re-raised) to the orchestrator, which rolls back once.
4. No sub-routine swallows errors or returns success after a failed statement.
5. Sub-routines touch rows in the global lock order (§6).
6. Deadlock victims are retried only at the outermost level (application or wrapper), never inside the transaction.

## 5. Settlement orchestration interface (proposal)

| Item | Proposal |
|---|---|
| Entry point | `usp_P3_SettleInvoice` (placeholder; name per D-021), if D-012 assigns orchestration to P3 |
| Inputs | Invoice_ID; PaymentMethod; PaidAt (optional, default now); optional client request key (D-003 C) |
| Outputs | Result code (`SETTLED`, `ALREADY_SETTLED`); points earned; new points balance |
| Errors | P3 range 51000–51999 (not payable, no lines, invalid method); sub-routine errors pass through unchanged (e.g. insufficient stock from the UC04 routine) |
| Hooks called | Inventory decrement for all product lines of the invoice (UC04 owner; set-based, atomic, no negative stock); entitlement activation for all service lines (UC01 owner) |
| Guarantees | All-or-nothing; idempotent on repeat; safe under concurrency (T-CONC-01…05) |

If the team assigns orchestration to another member, P3 instead provides a **loyalty/revenue sub-routine** with the same rules, and this table moves into that member's contract.

## 6. Global lock order (proposal)

INVOICE row → BRANCH_INVENTORY rows (ascending Product_ID) → INVOICE_SERVICE_ITEM rows (ascending LineNo) → MEMBER_MONTHLY_SPENDING row → MEMBER row → revenue-summary row.

The tier batch reads MEMBER_MONTHLY_SPENDING without holding locks into the MEMBER update phase (READ COMMITTED), and updates MEMBER in chunks ([06 §4.6](06_UC05_BILLING_LOYALTY_PLAN.md#46-periodic-tier-evaluation-f22-pending-d-007-d-008-d-009)).

## 7. Schema change and migration ordering

1. Shared base tables (team schema; in isolated test databases only, the TEST_ONLY key fixtures of D-026) → P3 tables INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM, MEMBER_MONTHLY_SPENDING (V001) → P3 constraints and `PaidAt` (V002) → routines → adopted indexes → summary (if adopted). P3 migrations never create or alter shared tables.
2. Every script is re-runnable on an empty database in the documented order (T-REPRO-01).
3. A change to a shared table is proposed as a decision, approved by the team, and only then scripted (R-03, R-13).
4. **D-025 (APPROVED 2026-11-06):** the shared team database is the canonical integration database. P3 test and benchmark databases are isolated, disposable copies built from the approved shared schema and migrations, and must not drift into an incompatible P3 implementation. Experimental indexes, partitions and schema changes never propagate automatically. Moving an adopted P3 object into the shared database is a separate, team-approved **promotion** step, and D-025 itself authorizes no shared-database modification.

## 8. Seed and test-data coordination

- One team seed pipeline with deterministic seeds. P3 contributes the generator for invoices, lines (if their owners agree), spending, points and tiers, or consumes the shared generator.
- Shared parameter sets for benchmarks so that members' results are comparable.
- **P2 (2026-11-08):** WO-P3-P2-01 generates data for the four P3 tables only. BRANCH_INVENTORY and the data of other members' modules are not generated by P3.
- Parent-table data comes from the team seed pipeline, or from a parent-table seed agreed in DL-02 at P6. While no team schema exists, isolated databases use the TEST_ONLY key fixtures of D-026 (restricted) and P3 inserts key rows only; fixtures are replaced by the team schema before integration. No P3-private implementation of a shared table is built.

## 9. Shared index registry

One table in DL-02 (built at P6): index name, table, keys/INCLUDE/filter, owner, target query, status (CANDIDATE/ADOPTED/REJECTED), evidence link. Until then P3 keeps its own index decision record (WO-P3-P4-01). Rules are in [08 §9](08_INDEX_AND_QUERY_PLAN.md#9-coordination-with-other-members).

## 10. Application integration (pending D-020)

| P3 feature | Users (S-02 §1.3) | Backing routine/query | Frequency class |
|---|---|---|---|
| Confirm payment | Receptionist / sales staff | `usp_P3_SettleInvoice` | High |
| Member loyalty view | Member, receptionist | Q-UC05-B | High |
| Branch revenue report (grain selector) | Branch manager | Q-UC06-A/C/D | Low |
| System revenue and branch comparison | Board of directors | Q-UC06-B/D | Low |
| Tier distribution (if in scope) | Board | Q-UC06-G | Low |
| Run tier evaluation (admin) | Administrator | `usp_P3_EvaluateTiers` | Low |

Endpoint names suggested by S-09 (e.g. `POST /api/invoices/{id}/payments`) are illustrations only, not requirements. The application must not cache payment or loyalty state, and report caching must be disabled or measured separately in benchmarks.

## 11. Communication and change control

- Integration decisions are recorded in [03_DECISION_LOG.md](03_DECISION_LOG.md) and in the team tracking tool (RQ-A20, once known).
- P3 never edits another member's files. Requests go through the owner.
- A change to the contract creates a new contract version with a change note. Affected tests (T-INT-xx, T-REG-03) are re-run.

## 12. Integration tests

T-INT-01…T-INT-04, T-CONC-05, T-REG-03 ([11](11_TEST_AND_QA_PLAN.md)).

## 13. Open items

| Item | Needed from | Blocks |
|---|---|---|
| Six-UC list with owners | Team (D-001) | UC06 candidate reports; group report (no longer P1, 2026-11-07) |
| Orchestrator ownership | Team (D-012) | WO-P3-P1-02 (P6). WO-P3-P3-01 proceeds on a provisional (T2) approval with test doubles (DEP-05) |
| Shared type standard | Team (D-014) | P1 |
| Repository and layout | Project Owner (D-021); team ratifies in the first PR | P1 |
| Review of the shared-dependency interface (§2a); replacement of TEST_ONLY fixtures by the team schema | Team (D-026 conditions 9–10) | Integration, merge |
| Who calls the P3 billing interface (plan and product sale flows); writers of `ValidFrom`, `ValidUntil`, `PTSessionsRemaining` | Team (D-001, D-012) | WO-P3-P1-02 (P6). WO-P3-P3-00 proceeds on DEP-04 and DEP-06 |
| Application stack | Team (D-020) | P6 |
| Other members' high-frequency queries for regression | Other members | T-REG-03 in WO-P3-P6-01 (moved from P4, D-027; DEP-09) |
| Database topology for tests/benchmarks (master prompt §11) | Closed: D-025 APPROVED 2026-11-06 | — |
| Which member demonstrates project-level partitioning (likely the check-in workload) if P3 rejects INVOICE partitioning | Team | WO-P3-P1-02 at P6 (DEP-11); does not block P5 |

## 14. Formal integration at P6 (sequence)

Added 2026-11-08 (D-027). Formal integration starts at P6, or earlier immediately before the first operation that requires team integration ([15 §2.2](15_ROADMAP_AND_WORK_ORDERS.md#22-operations-that-require-team-integration-trigger-for-wo-p3-p1-02)).

| Step | Work order | Content | Team approval |
|---|---|---|---|
| 1 | WO-P3-P1-02 | Formal schema reconciliation with the team schema; contract DL-02 (the 13 items of §3); every row of §2b confirmed or turned into a change request; settlement orchestration owner (D-012) and billing-interface callers (D-028); index registry and regression queries; promotion procedure; project-level partition owner (DEP-11) | Yes |
| 2 | Promotion WO (drafted from the agreed procedure) | Shared-schema migration review; promotion of the adopted P3 objects (tables, routines, indexes, summary if any) into the canonical shared database | Yes (D-025 conditions 6–7) |
| 3 | WO-P3-P6-01, stage A | Integration rehearsal in an isolated database built from the team schema: TEST_ONLY fixtures and test doubles replaced (D-026 condition 9); T-SCH-01/02 and T-INT-03; T-INT-01/02 with the real routines; T-CONC-05; T-REG-03; cross-module queries and transactions | Members concerned |
| 4 | WO-P3-P6-01, stage B | Application integration (T-INT-04) on the shared database; integration regression | Yes (shared application) |

No shared database change occurs without the recorded team approval (approval rule 3). Any difference found between the team schema and the P3 assumptions is handled as a contract change (§11), and the affected P3 tests are re-run.
