# DL-01 — Physical Design Table (Person 3)

| Field | Value |
|---|---|
| Deliverable | DL-01 (RQ-A01, RQ-P16) |
| Produced by | WO-P3-P1-01 — Physical Schema Foundation, 2026-11-07 |
| Scope | The four Person 3-owned tables only: INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM, MEMBER_MONTHLY_SPENDING. Shared tables are dependencies ([12 §2a](../12_INTEGRATION_PLAN.md#2a-shared-dependency-interface-required-by-p3)); their TEST_ONLY fixtures are listed in §5 for transparency, not as P3 design. |
| Implementation | `db/migrations/V001__p3_billing_and_spending_tables.sql`, `db/migrations/V002__p3_settlement_and_spending_constraints.sql` (P3_OWNED, production) |
| DBMS | Microsoft SQL Server 2025 RTM 17.0.1000.7, Standard Developer Edition; database compatibility level 160; server collation `SQL_Latin1_General_CP1_CI_AS` ([ENV-P1](../evidence/test-results/ENV-P1__20261107-1138.txt)) |
| Verified by | T-SCH-01 (53 PASS, 0 FAIL, 1 INFO), T-SCH-02 (6/6 PASS), T-REPRO-01 (PASS), separation check (PASS) — [WO-P3-P1-01 §13](../work-orders/WO-P3-P1-01_PHYSICAL_SCHEMA.md#13-execution-record) |
| Source labels | `P1` = DERIVED_FROM_PHASE1 (S-02 §10 or a BR); `D-xxx` = approved decision; `WO` = physical refinement approved with WO-P3-P1-01 |

## 1. Columns

Timestamps are stored in UTC (D-014); business periods use the Asia/Ho_Chi_Minh calendar.

| Table | Column | Type | Null | Default | Key / constraint | Index participation | Source | Rationale |
|---|---|---|---|---|---|---|---|---|
| INVOICE | Invoice_ID | INT IDENTITY(1,1) | NOT NULL | — | PK_INVOICE | Clustered PK | P1; D-014, D-018; WO (IDENTITY) | Narrow ever-increasing key; ~324,000 rows/year |
| INVOICE | Member_ID | INT | NOT NULL | — | FK_INVOICE_MEMBER | — (FK index is a P4 candidate) | P1 (BR07); D-014 | Every invoice belongs to one member |
| INVOICE | Employee_ID | INT | NOT NULL | — | FK_INVOICE_EMPLOYEE | — | P1 (BR08) | Issuing employee |
| INVOICE | Branch_ID | INT | NOT NULL | — | FK_INVOICE_BRANCH | — (IX-01 candidate, P4) | P1 (BR08) | Issuing branch; revenue attribution |
| INVOICE | IssuedAt | DATETIME2(3) | NOT NULL | — | CK_INVOICE_PaidAtAfterIssued | — | P1; D-014 (UTC) | Supplied by the billing logic |
| INVOICE | GrossAmount | DECIMAL(18,2) | NOT NULL | — | CK_INVOICE_Amounts, CK_INVOICE_FinalAmount | — | P1; D-014, D-023 | Exact money |
| INVOICE | DiscountAmount | DECIMAL(18,2) | NOT NULL | — | CK_INVOICE_Amounts, CK_INVOICE_FinalAmount | — | P1; D-023 | 0 ≤ Discount ≤ Gross |
| INVOICE | FinalAmount | DECIMAL(18,2) | NOT NULL | — | CK_INVOICE_FinalAmount | — | P1; D-023 | Stored (not computed) so other modules' inserts keep working; = Gross − Discount, ≥ 0 |
| INVOICE | PaymentMethod | VARCHAR(10) | NULL | — | CK_INVOICE_PaymentMethod, CK_INVOICE_MethodWhenPaid | — | P1; D-005 | Nullable before settlement; CASH/VNPAY/CARD; NOT NULL when PAID |
| INVOICE | PaymentStatus | VARCHAR(10) | NOT NULL | 'PENDING' | CK_INVOICE_PaymentStatus, CK_INVOICE_MethodWhenPaid, CK_INVOICE_PaidAtStatus | — | P1; D-005, D-011 | PENDING/PAID/CANCELLED; only PAID counts as paid (check-in contract) |
| INVOICE | PaidAt | DATETIME2(3) | NULL | — | CK_INVOICE_PaidAtStatus, CK_INVOICE_PaidAtAfterIssued | — | **D-004 (DV-01)** | Successful-settlement time, UTC; revenue and spending month |
| INVOICE_SERVICE_ITEM | Invoice_ID | INT | NOT NULL | — | PK (1/2), FK_INVOICE_SERVICE_ITEM_INVOICE | Clustered PK prefix | P1 (BR09) | — |
| INVOICE_SERVICE_ITEM | [LineNo] | SMALLINT | NOT NULL | — | PK (2/2) | Clustered PK | P1; WO (type) | Reserved word: always `[LineNo]` |
| INVOICE_SERVICE_ITEM | Plan_ID | INT | NOT NULL | — | FK_INVOICE_SERVICE_ITEM_SERVICE_PLAN | — (IX-09 candidate) | P1 (BR10) | — |
| INVOICE_SERVICE_ITEM | UnitPrice | DECIMAL(18,2) | NOT NULL | — | CK_INVOICE_SERVICE_ITEM_Amounts | — | P1 (BR13); D-023 | Actual price at sale |
| INVOICE_SERVICE_ITEM | DiscountAmount | DECIMAL(18,2) | NOT NULL | — | CK_INVOICE_SERVICE_ITEM_Amounts | — | P1; D-023 | 0 ≤ discount ≤ UnitPrice |
| INVOICE_SERVICE_ITEM | ValidFrom | DATE | NULL | — | CK_INVOICE_SERVICE_ITEM_Validity | — | P1 (BR13); WO (nullability) | Set at entitlement activation (writer per contract) |
| INVOICE_SERVICE_ITEM | ValidUntil | DATE | NULL | — | CK_INVOICE_SERVICE_ITEM_Validity | — | P1 (BR13) | ValidUntil ≥ ValidFrom |
| INVOICE_SERVICE_ITEM | PTSessionsRemaining | INT | NULL | — | — | — | P1; WO (nullability) | Written by the PT owner; no P3 rule |
| INVOICE_PRODUCT_ITEM | Invoice_ID | INT | NOT NULL | — | PK (1/2), FK_INVOICE_PRODUCT_ITEM_INVOICE | Clustered PK prefix | P1 (BR09) | — |
| INVOICE_PRODUCT_ITEM | [LineNo] | SMALLINT | NOT NULL | — | PK (2/2) | Clustered PK | P1; WO (type) | Reserved word |
| INVOICE_PRODUCT_ITEM | Product_ID | INT | NOT NULL | — | FK_INVOICE_PRODUCT_ITEM_PRODUCT | — (IX-08 candidate) | P1 (BR11) | — |
| INVOICE_PRODUCT_ITEM | Quantity | INT | NOT NULL | — | CK_INVOICE_PRODUCT_ITEM_Quantity, _Amounts | — | P1; D-023 | > 0 |
| INVOICE_PRODUCT_ITEM | UnitPrice | DECIMAL(18,2) | NOT NULL | — | CK_INVOICE_PRODUCT_ITEM_Amounts | — | P1; D-023 | ≥ 0 |
| INVOICE_PRODUCT_ITEM | DiscountAmount | DECIMAL(18,2) | NOT NULL | — | CK_INVOICE_PRODUCT_ITEM_Amounts | — | P1; D-023 | 0 ≤ discount ≤ UnitPrice × Quantity |
| MEMBER_MONTHLY_SPENDING | Member_ID | INT | NOT NULL | — | PK (1/2), FK_MEMBER_MONTHLY_SPENDING_MEMBER | Clustered PK prefix | P1 (BR05, BR06) | Member-first access for the tier window |
| MEMBER_MONTHLY_SPENDING | SpendingMonth | DATE | NOT NULL | — | PK (2/2), CK_MEMBER_MONTHLY_SPENDING_FirstDay | Clustered PK | P1; **D-013** | First day of the Asia/Ho_Chi_Minh month of PaidAt |
| MEMBER_MONTHLY_SPENDING | TotalSpend | DECIMAL(18,2) | NOT NULL | 0 | CK_MEMBER_MONTHLY_SPENDING_NonNegative | — | P1; D-014 | Σ FinalAmount of PAID invoices in the month (T-REC-01, later) |
| MEMBER_MONTHLY_SPENDING | PointsEarned | INT | NOT NULL | 0 | CK_MEMBER_MONTHLY_SPENDING_NonNegative | — | P1 | Rule per D-006 (open) |
| MEMBER_MONTHLY_SPENDING | UpdatedAt | DATETIME2(3) | NOT NULL | SYSUTCDATETIME() | — | — | P1; D-014 | UTC |

## 2. Constraints as deployed

Definitions as reported by the catalog ([T-SCH-02 evidence](../evidence/test-results/T-SCH-02__20261107-1154.txt)).

| Constraint | Table | Definition | Source | File |
|---|---|---|---|---|
| PK_INVOICE | INVOICE | Clustered (Invoice_ID) | P1; D-018 | V001 |
| PK_INVOICE_SERVICE_ITEM | INVOICE_SERVICE_ITEM | Clustered (Invoice_ID, LineNo) | P1 | V001 |
| PK_INVOICE_PRODUCT_ITEM | INVOICE_PRODUCT_ITEM | Clustered (Invoice_ID, LineNo) | P1 | V001 |
| PK_MEMBER_MONTHLY_SPENDING | MEMBER_MONTHLY_SPENDING | Clustered (Member_ID, SpendingMonth) | P1 (BR06) | V001 |
| FK_INVOICE_MEMBER | INVOICE | Member_ID → MEMBER.Member_ID, NO ACTION | P1 (BR07) | V001 |
| FK_INVOICE_EMPLOYEE | INVOICE | Employee_ID → EMPLOYEE.Employee_ID, NO ACTION | P1 (BR08) | V001 |
| FK_INVOICE_BRANCH | INVOICE | Branch_ID → BRANCH.Branch_ID, NO ACTION | P1 (BR08) | V001 |
| FK_INVOICE_SERVICE_ITEM_INVOICE | INVOICE_SERVICE_ITEM | Invoice_ID → INVOICE.Invoice_ID, NO ACTION | P1 (BR09) | V001 |
| FK_INVOICE_SERVICE_ITEM_SERVICE_PLAN | INVOICE_SERVICE_ITEM | Plan_ID → SERVICE_PLAN.Plan_ID, NO ACTION | P1 (BR10) | V001 |
| FK_INVOICE_PRODUCT_ITEM_INVOICE | INVOICE_PRODUCT_ITEM | Invoice_ID → INVOICE.Invoice_ID, NO ACTION | P1 (BR09) | V001 |
| FK_INVOICE_PRODUCT_ITEM_PRODUCT | INVOICE_PRODUCT_ITEM | Product_ID → PRODUCT.Product_ID, NO ACTION | P1 (BR11) | V001 |
| FK_MEMBER_MONTHLY_SPENDING_MEMBER | MEMBER_MONTHLY_SPENDING | Member_ID → MEMBER.Member_ID, NO ACTION | P1 (BR05) | V001 |
| CK_INVOICE_SERVICE_ITEM_Validity | INVOICE_SERVICE_ITEM | `[ValidUntil]>=[ValidFrom]` | P1 (BR13) | V001 |
| CK_INVOICE_PaymentStatus | INVOICE | `[PaymentStatus]='CANCELLED' OR …='PAID' OR …='PENDING'` | D-005, D-011 (S1) | V002 |
| CK_INVOICE_PaymentMethod | INVOICE | `[PaymentMethod]='CARD' OR …='VNPAY' OR …='CASH'` | D-005 (S2) | V002 |
| CK_INVOICE_MethodWhenPaid | INVOICE | `[PaymentStatus]<>'PAID' OR [PaymentMethod] IS NOT NULL` | D-005 (S3) | V002 |
| CK_INVOICE_PaidAtStatus | INVOICE | `[PaymentStatus]='PAID' AND [PaidAt] IS NOT NULL OR [PaymentStatus]<>'PAID' AND [PaidAt] IS NULL` | D-004 (S4) | V002 |
| CK_INVOICE_PaidAtAfterIssued | INVOICE | `[PaidAt]>=[IssuedAt]` | D-004 (S5) | V002 |
| CK_INVOICE_Amounts | INVOICE | `[GrossAmount]>=(0) AND [DiscountAmount]>=(0) AND [DiscountAmount]<=[GrossAmount]` | D-023 | V002 |
| CK_INVOICE_FinalAmount | INVOICE | `[FinalAmount]=([GrossAmount]-[DiscountAmount]) AND [FinalAmount]>=(0)` | D-023 | V002 |
| CK_INVOICE_SERVICE_ITEM_Amounts | INVOICE_SERVICE_ITEM | `[UnitPrice]>=(0) AND [DiscountAmount]>=(0) AND [DiscountAmount]<=[UnitPrice]` | D-023 | V002 |
| CK_INVOICE_PRODUCT_ITEM_Quantity | INVOICE_PRODUCT_ITEM | `[Quantity]>(0)` | D-023 | V002 |
| CK_INVOICE_PRODUCT_ITEM_Amounts | INVOICE_PRODUCT_ITEM | `[UnitPrice]>=(0) AND [DiscountAmount]>=(0) AND [DiscountAmount]<=[UnitPrice]*[Quantity]` | D-023 | V002 |
| CK_MEMBER_MONTHLY_SPENDING_FirstDay | MEMBER_MONTHLY_SPENDING | `datepart(day,[SpendingMonth])=(1)` | D-013 | V002 |
| CK_MEMBER_MONTHLY_SPENDING_NonNegative | MEMBER_MONTHLY_SPENDING | `[TotalSpend]>=(0) AND [PointsEarned]>=(0)` | WO | V002 |
| DF_INVOICE_PaymentStatus | INVOICE | `('PENDING')` | D-005 | V002 |
| DF_MEMBER_MONTHLY_SPENDING_TotalSpend / _PointsEarned / _UpdatedAt | MEMBER_MONTHLY_SPENDING | `((0))` / `((0))` / `(sysutcdatetime())` | D-014 | V002 |

No UNIQUE constraint is required on the P3-owned tables. All CHECK and FK constraints are enabled and trusted (T-SCH-02 C3, C6).

## 3. Rules the schema does not enforce (by design)

| # | Rule | Kind | Enforced by | Verified by |
|---|---|---|---|---|
| T1–T4 | Only PENDING→PAID and PENDING→CANCELLED; PAID and CANCELLED terminal; PaidAt and method fixed after PAID | Transition (needs the old value) | UC05 routines (WO-P3-P3-01); T-SCH-01 case I01 documents that the schema alone accepts a PAID→PENDING reversal when PaidAt and method are cleared | T-F05-05…07, T-CONC-01 (later) |
| T5 | Loyalty and revenue effects exactly once | Cross-table | Settlement transaction (D-012) | T-F05-06, T-CONC-01 (later) |
| X1, X2 | Header Gross and Discount = sums of the lines | Cross-table | P3 billing/finalisation logic; settlement defensive check | Validation query V-TOT (T-SCH-01 P05, P06) |
| X3 | A confirmed invoice has ≥ 1 line (BR12) | Cross-table | Settlement | T-F05-02 (later); V-TOT also lists invoices without lines |

A CHECK calling a function that reads the line tables is deliberately not used: it would run only when the header row changes, not when lines change.

## 4. Indexes and derived structures

| Item | State |
|---|---|
| Indexes | Only the 4 clustered PK indexes of the P3 tables (plus 5 fixture PKs in the isolated database). No nonclustered, unique-performance or partitioned index (B0 rule; candidates IX-01…IX-11 are evaluated in P4) |
| MEMBER_MONTHLY_SPENDING | Derived per-member-month aggregate (Phase 1). Maintained by settlement (WO-P3-P3-01/02); reconciliation T-REC-01/T-REC-02 (later) |

## 5. Shared dependencies and TEST_ONLY fixtures (not P3 design)

| Shared table | Required interface | Fixture in `FitLife_P3_P1` | File |
|---|---|---|---|
| MEMBER | `Member_ID INT` PK | Key only, marked `Classification = TEST_ONLY_FIXTURE` | `tests/db/fixtures/F001__TEST_ONLY_shared_dependency_keys.sql` |
| BRANCH | `Branch_ID INT` PK | Key only, marked | same |
| EMPLOYEE | `Employee_ID INT` PK | Key only, marked | same |
| SERVICE_PLAN | `Plan_ID INT` PK | Key only, marked | same |
| PRODUCT | `Product_ID INT` PK | Key only, marked | same |
| MEMBER_TIER | `Tier_ID INT` PK (through MEMBER) | None in P1 | — |

The fixtures are replaced by the approved team schema before integration, and the tests are re-run (D-026 condition 9).

## 6. Deviation register (differences from S-02 §10)

| # | Item | Phase 1 | Implemented | Authority |
|---|---|---|---|---|
| DV-01 | `INVOICE.PaidAt` | Absent | `DATETIME2(3) NULL`, UTC | D-004 (provisional, T2) |
| DV-02 | Identifier, money, timestamp types | Not specified | INT, DECIMAL(18,2), DATETIME2(3) UTC | D-014 (provisional, T2) |
| DV-03 | Other types | Not specified | VARCHAR(10) (method, status), DATE (validity, month), SMALLINT (LineNo) | WO-P3-P1-01 |
| DV-04 | Key generation | Not specified | IDENTITY(1,1) on Invoice_ID only | WO-P3-P1-01 |
| DV-05 | Nullability | Not specified | §1 | WO-P3-P1-01 |
| DV-06 | CHECK and DEFAULT constraints | BRs in prose | §2 | D-004, D-005, D-011, D-013, D-023, WO |
| DV-07 | SpendingMonth | Name only | DATE, first day of the local month, CHECK | D-013 |
| DV-08 | Production tables | 25 entities | 4 P3-owned tables | D-026 (restricted) |
| DV-09 | `LineNo` | Plain name | Same name, quoted `[LineNo]` | T-SQL syntax |
| DV-10 | Shared parents in the isolated database | Full entities | 5 key-only TEST_ONLY fixtures | D-026 (restricted) |

No table, column, key or relationship of §10 was renamed or removed. **Preflight conformance (WO step 1.4): PASS** — the four tables' columns equal §10 in name and order (INVOICE plus `PaidAt`, DV-01), PKs equal §10, the 8 FKs equal §10, and every fixture key is the Phase 1 PK ([ENV-P1](../evidence/test-results/ENV-P1__20261107-1138.txt)).
