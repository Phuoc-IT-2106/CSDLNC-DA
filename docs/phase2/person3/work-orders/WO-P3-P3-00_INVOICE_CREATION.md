# WO-P3-P3-00 — Invoice Creation (Billing)

| Field | Value |
|---|---|
| Status | **PASSED — functional acceptance** (2026-11-09). `VERIFIED` by this session against amended criteria 1–4 (§13.8: D-028 APPROVED (provisional, T2); fresh regression run `UC05-RUN__20261109-1446`, 19/19 PASS); recorded `PASSED` on the Project Owner's explicit conditional acceptance (Owner Directive "Close Invoice Creation and Prioritize Settlement" §3), whose condition (functional verification) is confirmed — same rule as WO-P3-P0-01 and WO-P3-P2-01. **Performance is NOT accepted here:** original criterion 5 (creation-cost RUN_ID) was transferred by a formal scope amendment to **WO-P3-P3-03 criterion 5** (§7a); it is open and not PASS |
| Readiness | Functional scope complete. The creation-cost baseline stays required and is measured in WO-P3-P3-03 once R-27 is closed |
| Phase | P3 — Billing, Settlement and Loyalty Implementation |
| Mode | BUILD_AUTHORIZED |
| Approver | Project Owner (the callers of the interface, i.e. other members' sale flows, are confirmed at P6 in WO-P3-P1-02) |
| Approval record | Owner Directive "Urgent Unblock & Core Implementation" (Claude Code session of 2026-11-09), §6: BUILD_AUTHORIZED execution within the approved P3 scope, subject to verification of the business and schema prerequisites; if a material decision is unresolved, only the independently valid portion is implemented and the WO is not marked `VERIFIED`. §3/§6: GATE-P2, WO-P3-P2-02 and R-27 are not prerequisites unless a requirement demonstrably depends on them. Precondition check and the resulting scope: §13.1 |
| Target database | `FitLife_P3_UC05` (isolated, disposable, marker `WO-P3-P3-00…`; directive §8), built from F001 (TEST_ONLY), V001, V002. `FitLife_P3_P1` and `FitLife_P3_P2` read only. The creation-cost measurement on DS-L (task 5) is not authorized by the directive (no change to `FitLife_P3_P2`, no formal benchmark) |
| Scope rule | **Person 3 only.** Writes INVOICE, INVOICE_SERVICE_ITEM and INVOICE_PRODUCT_ITEM. No inventory, catalogue, service-activation or PT logic. |

## 0. Revision record

| Date | Change |
|---|---|
| 2026-11-08 | Created by the Owner Directive "Reprioritize Person 3 Implementation" §5: no existing WO covered invoice creation since INVOICE and both item tables became P3-owned (2026-11-07). The identifier 00 places it before WO-P3-P3-01 without renumbering any existing WO. |
| 2026-11-09 | Owner Directive "Urgent Unblock & Core Implementation": authorized (§6); independently valid portion executed in `FitLife_P3_UC05`; status `IN_PROGRESS`; execution record §13. No acceptance criterion was changed. |
| 2026-11-09 (2) | Owner Directive "Close Invoice Creation and Prioritize Settlement" §3: **formal scope amendment** separating functional from performance acceptance. Criterion 5 is transferred unchanged to WO-P3-P3-03 (§7a); the original text stays in §7 (struck through for this WO, not deleted). D-028 APPROVED (provisional, T2). Functional criteria re-verified (§13.8); status `VERIFIED`, then `PASSED` (functional acceptance) under the Owner's conditional acceptance. |

## 1. Objective

Implement P3's billing write path: create and finalise an invoice (header and all lines) in **one transaction**, in status PENDING, with header totals derived from the lines (D-023). Prove positive, negative, atomicity and concurrency behaviour.

**Responsibility split (explicit):**

| Responsibility | Work order |
|---|---|
| Invoice creation and finalisation (F05): header + lines, totals, PENDING | **This WO** |
| Settlement PENDING→PAID with loyalty and revenue effects; cancellation PENDING→CANCELLED | WO-P3-P3-01 |
| Loyalty lookup and tier evaluation | WO-P3-P3-02 |
| Concurrency suite and UC05 benchmarks | WO-P3-P3-03 |
| Stock check and decrement, entitlement activation, PT sessions, catalogue prices | Other members (reached only through the settlement hooks; DEP-04, DEP-05, DEP-06) |

## 2. Preconditions

1. GATE-P2 passed.
2. D-028 APPROVED (at least provisionally, T2, for isolated work): responsibility, interface, finalisation, line prices, creation idempotency.
3. Already approved: D-003 (A), D-005, D-011, D-014, D-023.
4. Not required (D-027): WO-P3-P1-02, other members' sale flows or approval. The assumptions used are DEP-01, DEP-04, DEP-06, DEP-10 ([12 §2b](../12_INTEGRATION_PLAN.md#2b-dependency-register-interim-assumptions-until-p6)).

## 3. Inputs

[06 §4.1, §8](../06_UC05_BILLING_LOYALTY_PLAN.md#41-invoice-creation-billing-f05-wo-p3-p3-00-d-028); [03 D-028](../03_DECISION_LOG.md#d-028--invoice-creation-billing-responsibility-interface-finalisation-creation-idempotency); [WO-P3-P1-01 §3.4](WO-P3-P1-01_PHYSICAL_SCHEMA.md#34-keys-foreign-keys-and-constraints) (S1–S5, X1); [12 §4](../12_INTEGRATION_PLAN.md#4-transaction-composition-rules); [11 §2.3, §2.5](../11_TEST_AND_QA_PLAN.md#23-uc05-functional-wo-p3-p3-01-wo-p3-p3-02); DL-03.

## 4. Tasks

1. Implement the creation routine (placeholder name `usp_P3_CreateInvoice`; name per D-021) according to the approved D-028 answers. Planned steps (for the recommended answers): validate parameters (member, branch, employee present; at least one line, BR12; line amounts valid); begin one transaction with `XACT_ABORT ON`; insert the header PENDING with `IssuedAt` in UTC (D-014) and the optional `PaymentMethod` (D-005); insert all lines (service lines with `ValidFrom`, `ValidUntil`, `PTSessionsRemaining` NULL; DEP-06); compute `GrossAmount`, `DiscountAmount`, `FinalAmount` from the lines (D-023, X1); commit; return the new `Invoice_ID`. Errors use the P3 range 51000–51999 and leave nothing behind.
2. If D-028 Q5 (b) is approved: additive migration V003 (request-key column + UNIQUE constraint on INVOICE), and the routine returns the existing invoice for a repeated key. Otherwise no schema change.
3. Permissions: invoice rows are written only through the routine in the isolated database (least privilege, RQ-P15); recorded for the contract at P6.
4. Tests: T-F05-01, T-F05-03, T-F05-04, T-F05-18, T-F05-19, T-F05-20 (if Q5 (b)) and T-CONC-06; V-TOT after every test.
5. Measure the creation cost (insert path, [10 §4.5](../10_SEED_AND_BENCHMARK_PLAN.md#45-write-overhead-measurement)) on DS-L in the B0 configuration, as the write baseline for later index decisions.
6. Update [01](../01_REQUIREMENTS_TRACEABILITY.md), [16](../16_READINESS_REPORT.md), [SESSION_LOG.md](../SESSION_LOG.md) and the dependency register.

## 5. Out of scope

Settlement, cancellation, loyalty and revenue effects (WO-P3-P3-01…03); stock checks, inventory, entitlement activation, PT sessions, catalogue management or price lookup (other members); editing lines of an existing invoice (D-028 Q3); nonclustered indexes; the application; the canonical shared database.

## 6. Deliverables and locations

Part of DL-07: routine in `db/procedures/`; V003 in `db/migrations/` only if Q5 (b); tests in `tests/db/functional/` and `tests/db/concurrency/`; outputs in `evidence/test-results/`.

## 7. Acceptance criteria

1. All listed tests pass; V-TOT returns zero mismatches after every test.
2. A failure in any line leaves no header and no lines (T-F05-19).
3. Concurrent creations produce distinct invoices with correct totals and no lost lines (T-CONC-06).
4. No inventory, entitlement or catalogue logic in the routine (code review recorded).
5. ~~The creation-cost baseline has a RUN_ID.~~ **Transferred on 2026-11-09 to WO-P3-P3-03 criterion 5 (§7a).** Not met, not waived.

## 7a. Scope amendment of 2026-11-09 (criterion 5)

| Item | Record |
|---|---|
| Authority | Project Owner, Owner Directive "Close Invoice Creation and Prioritize Settlement" (Claude Code session of 2026-11-09), §3: "formal scope amendment to separate functional acceptance from performance acceptance" |
| Original criterion (kept verbatim) | "5. The creation-cost baseline has a RUN_ID." (task 5: measure the creation cost, insert path, [10 §4.5](../10_SEED_AND_BENCHMARK_PLAN.md#45-write-overhead-measurement), on DS-L in the B0 configuration, as the write baseline for later index decisions) |
| Destination | **WO-P3-P3-03 — UC05 Verification and U0 vs U1 Benchmark, acceptance criterion 5 and task 3a** (added there the same day). Reason for this destination: WO-P3-P3-03 already owns the UC05 write-path benchmarks with the same protocol (10 §4.5: K = 1,000 calls, per-call median and p95, B0 on DS-L) and the U0/U1 settlement measurements; the baseline must still be captured **before any P4 index is adopted** (R-11), which the roadmap order P3 → P4 preserves |
| Justification | R-27 (OPEN): this machine is not a stable measurement environment (E6 FAIL twice on 2026-11-08), so a creation-cost RUN_ID cannot be produced reliably now. Functional correctness does not depend on timings |
| What is NOT done | No benchmark is reported as PASS. No R-27 diagnostic timing (DIAGNOSTIC_ONLY) is used as evidence. The academic performance requirement is not removed: it is unchanged and owned by WO-P3-P3-03 (traceability: [01](../01_REQUIREMENTS_TRACEABILITY.md) RQ-A13 row; [15](../15_ROADMAP_AND_WORK_ORDERS.md) dependencies) |
| Effect on this WO | Functional acceptance only (criteria 1–4). The performance obligation travels with WO-P3-P3-03 and GATE-P3 |

## 8. Verification

Run the full test set on a freshly built isolated database; repeat T-CONC-06 at least 3 times.

## 9. Evidence

`evidence/test-results/T-F05-*__*.txt`, `T-CONC-06__*.txt`; the creation-cost RUN_ID folder.

## 10. Dependencies and risks

R-10, R-16, R-26.

## 11. Approval requirements

WO approval with the target database named; the D-028 answers; separate authorization for commits.

## 12. Exit and next step

Set `VERIFIED` when criteria 1–5 hold; the Owner sets `PASSED`. Next: WO-P3-P3-01 (settlement). _Amended 2026-11-09: criteria 1–4 (criterion 5 transferred, §7a); `PASSED` recorded on the Owner's conditional acceptance (§13.8)._

## 13. Execution record

Session of 2026-11-09 (Owner Directive "Urgent Unblock & Core Implementation"), mode BUILD_AUTHORIZED. Clone `C:\Users\DELL\source\repos\CSDLNC-DA`, branch `p3/wo-p3-p1-01`, HEAD `792a85e`; nothing committed.

### 13.1 Precondition check (directive §6) and resulting scope

| Precondition (§2) | State on 2026-11-09 | Effect |
|---|---|---|
| 1. GATE-P2 passed | Not passed (WO-P3-P2-02 BLOCKED). Directive §3/§6: not a prerequisite unless a requirement demonstrably depends on it | Only task 5 / criterion 5 (creation-cost baseline) depends on it, through R-27. The functional scope does not |
| 2. D-028 APPROVED (at least T2) | **PROPOSED** (no approver recorded) | Material for full acceptance. Handled per directive §6: the independently valid portion only; WO not `VERIFIED`. Item-by-item basis below |
| 3. D-003 (A), D-005, D-011, D-014, D-023 | APPROVED (provisional, T2) ✔ | Implemented as approved |
| 4. Not required (D-027) | WO-P3-P1-02 and other members not needed ✔ | DEP-01, DEP-04, DEP-06, DEP-10, DEP-13 relied on; DEP-14, DEP-15 added ([12 §2b](../12_INTEGRATION_PLAN.md#2b-dependency-register-interim-assumptions-until-p6)) |

D-028, question by question (what the implementation rests on; no answer was approved by this session):

| D-028 item | Basis used | Open for the Owner |
|---|---|---|
| Q1 responsibility | P3 implements invoice creation (directive §7; P3 owns the three tables since 2026-11-07). Who else may write the tables is an integration question (P6) | Confirm (a) "single write path" for the contract |
| Q2 interface | One call, header + all lines (table-valued parameters). Alternative (b) needs a draft state that the approved D-005 domain does not have, and would break D-023/BR12 between calls, so it is not implementable under approved decisions | Confirm (a) |
| Q3 finalisation | Totals computed from the lines in the creation transaction (D-023 approved). No edit routine exists; editing is out of scope (§5) | Confirm (a) |
| Q4 line prices | Caller supplies `UnitPrice` and `DiscountAmount` (DEP-04, D-027 register). Alternative (b) needs non-key catalogue columns, which the restricted fixtures (D-026) do not have | **Material: the price source is a business rule.** Confirm (a) |
| Q5 creation idempotency | Owner directions of 2026-11-08 and 2026-11-09 §7: no uniqueness on business values; a request key needs an unapproved schema change (V003), so it stays outside the accepted scope. Implemented behaviour: a repeated request creates a second, distinct PENDING invoice (T-F05-23). **Exactly-once creation is not claimed** | Choose (a) as implemented, or (b) with V003 (then T-F05-20 and a write-overhead measurement are added) |
| Q6 side effects | None at creation (directive §7 exclusions and §9 integrity list) | — (directed) |

### 13.2 Implemented

| File | Classification | Content |
|---|---|---|
| [db/procedures/usp_P3_CreateInvoice.sql](../../../../db/procedures/usp_P3_CreateInvoice.sql) | P3_OWNED, programmability only | Table types `dbo.tt_P3_InvoiceServiceLine` (LineNo PK, Plan_ID, UnitPrice, DiscountAmount) and `dbo.tt_P3_InvoiceProductLine` (LineNo PK, Product_ID, Quantity, UnitPrice, DiscountAmount), all NOT NULL; procedure `dbo.usp_P3_CreateInvoice`. Re-runnable (types created when missing and checked against the expected definition; `CREATE OR ALTER`). No table, column, constraint or index created or changed |
| [tests/db/build/rebuild_uc05_db.sql](../../../../tests/db/build/rebuild_uc05_db.sql), [drop_uc05_db.sql](../../../../tests/db/build/drop_uc05_db.sql) | TEST_ONLY harness | Guarded build and rollback of `FitLife_P3_UC05` (refuses P1/P2 names, non-Developer instances and databases without the `WO-P3-P3-00` marker) |
| [tests/db/fixtures/F001U__TEST_ONLY_uc05_key_rows.sql](../../../../tests/db/fixtures/F001U__TEST_ONLY_uc05_key_rows.sql) | TEST_ONLY fixture data | Key rows only: BRANCH 1–3, EMPLOYEE 1–6, MEMBER 1–40, SERVICE_PLAN 1–5, PRODUCT 1–10 |
| [tests/db/functional/T-F05_invoice_creation.sql](../../../../tests/db/functional/T-F05_invoice_creation.sql) | Test | 43 cases (§13.4) |
| [tests/db/functional/V-UC05_integrity.sql](../../../../tests/db/functional/V-UC05_integrity.sql) | Test | Whole-database integrity I1–I10, run after every test stage |
| [tests/db/schema/T-SCH-03_uc05_catalog_and_scope.sql](../../../../tests/db/schema/T-SCH-03_uc05_catalog_and_scope.sql) | Test | Catalog vs `FitLife_P3_P1`, inventory, type definitions, write scope (criterion 4) |
| [tests/db/concurrency/T-CONC-06_parallel_creation.ps1](../../../../tests/db/concurrency/T-CONC-06_parallel_creation.ps1) | Test | 10 sessions released together by a gate, 20 creations each, full reconciliation; 300 s watchdog |
| [tests/db/functional/run_uc05_invoice_creation.ps1](../../../../tests/db/functional/run_uc05_invoice_creation.ps1) | Test runner | Steps 1–14 with masked evidence |

**Routine contract.** Inputs: `@Member_ID`, `@Employee_ID`, `@Branch_ID` (required), `@ServiceLines`, `@ProductLines` (at least one row in total), `@PaymentMethod` (optional; NULL until settlement, D-005). Outputs: `@Invoice_ID`, `@Outcome = 'CREATED'`, return value 0. On any failure an error is raised and nothing is written.

**Steps.** (1) Validation, reads only: header keys present (51101); `PaymentMethod` NULL or exactly `CASH`/`VNPAY`/`CARD`, compared in binary without trailing spaces (51102); at least one line, BR12 (51103); `LineNo ≥ 1` (51104); `Quantity > 0` (51105); `UnitPrice ≥ 0` (51106); `DiscountAmount ≥ 0` (51107); line discount ≤ line gross (service `UnitPrice`, product `UnitPrice × Quantity`; 51108); invoice gross within DECIMAL(18,2), computed at DECIMAL(38,2) (51109); member, employee, branch, plans and products exist, by key only (51110–51114). (2) One transaction (`XACT_ABORT ON`; joins a caller's open transaction without committing or rolling it back, 12 §4): header `PENDING`, `PaidAt` NULL, `IssuedAt = SYSUTCDATETIME()` (D-014), Gross = Σ line gross, Discount = Σ line discounts, Final = Gross − Discount (D-023); `OUTPUT INSERTED.Invoice_ID`; service lines with `ValidFrom`, `ValidUntil`, `PTSessionsRemaining` NULL (DEP-06); product lines; X1 and BR12 re-checked against the stored rows before commit (51115); commit. Constraint and engine errors (547, 2627, 8115…) are re-raised unchanged.

**Code review for criterion 4 (recorded).** The routine reads MEMBER, EMPLOYEE, BRANCH, SERVICE_PLAN and PRODUCT by key column only and writes only INVOICE, INVOICE_SERVICE_ITEM and INVOICE_PRODUCT_ITEM. It has no stock check, inventory reference, catalogue price lookup, entitlement activation (the three entitlement and PT columns are inserted as literal NULL only), points, monthly spending or tier logic, no dynamic SQL and no nested call. Confirmed mechanically by T-SCH-03 K4/K5 (dependency analysis with `sys.dm_sql_referenced_entities`; definition SHA-256 `3513176C…3013`).

### 13.3 Verification run

`UC05-RUN__20261109-0829` (08:29–08:30:41 UTC), on a freshly built `FitLife_P3_UC05`. Steps 1–14 all **PASS**: fingerprint before; DS-L checksum before = run C reference; build; T-SCH-01 (53 PASS / 1 INFO, P1 regression); T-SCH-02 (6/6, P1 regression before the routine); routine applied; T-SCH-03 (6/6); key rows; T-F05 (43/43); V-UC05 (10/10); T-CONC-06 runs A, B, C (5/5 each) with V-UC05 after each (10/10); T-SCH-03 again (6/6); fingerprint after = before; DS-L checksum after = before = run C (`26ABB277…CA1F`). Final content of the disposable database: 613 invoices, 157 service lines, 1,245 product lines, 0 spending rows. No power event during the run; the machine was on AC. The times in the logs are context only, not measurements (R-27).

### 13.4 Test results

| Test | Cases | Result | What it shows |
|---|---|---|---|
| T-F05-01 | 9 | PASS | Product-only, service-only and mixed invoices; cents (3 × 99,999.99 = 299,999.97); line discounts; zero-price line; product discount above the unit price but within the line gross; Final = 0; largest DECIMAL(18,2) gross; stored lines equal the request; `PENDING`, `PaidAt` NULL, method as supplied or NULL, `IssuedAt` in UTC |
| T-F05-03 | 16 | PASS | Quantity 0 and negative; negative price and discount (service, product); discount > line gross (service, product); gross overflow (one line; sum of valid lines); `LineNo` 0; method `CHEQUE`, `cash`, `CASH ` (trailing space); duplicate `LineNo` and missing price rejected by the line type before the call. Nothing written |
| T-F05-04 | 7 | PASS | Unknown member, employee, branch, plan; missing member or branch key; **B02:** parent deleted after validation inside the transaction (TEST_ONLY trigger) → error 547 passed through unchanged, header, lines and the delete rolled back |
| T-F05-18 | 1 | PASS | No line (BR12) → 51103, nothing written |
| T-F05-19 | 4 | PASS | Bad third line among valid ones (unknown product; negative price); mixed request with one bad product line; **B01:** failure injected after the header and the service line were inserted (identity `last_value` advanced 10 → 11) → nothing remains |
| T-F05-20 | — | NOT_RUN | Defined only for D-028 Q5 (b), which is not approved. Impact: no database-level duplicate-creation guarantee |
| T-F05-23 | 1 | PASS | Same request twice → two distinct `PENDING` invoices with identical business values; no false rejection. Exactly-once creation not provided |
| T-F05-24 | 1 | PASS | No spending row, fixtures unchanged (hash), entitlement and PT columns NULL, every invoice `PENDING` without `PaidAt` |
| T-F05-25 | 3 | PASS | Inside a caller transaction: commit keeps the invoice; rollback removes it; a routine error leaves the caller's transaction uncommittable (`XACT_STATE() = -1`) and one rollback removes all its work |
| T-F05-26 | 1 | PASS | Least privilege (TEST_ONLY role and user, dropped): without EXECUTE on the line types the call fails (229); with EXECUTE on routine and types it succeeds; direct INSERT/UPDATE on the invoice tables denied (229) |
| T-CONC-06 | 3 runs × 200 | PASS ×3 | Per run: 200 of 200 calls succeeded; 200 distinct ids; exactly 200 new invoices; each holds its own request (460 lines, 50 mixed invoices, 0 mismatches); V-TOT 0; no orphan; sessions overlapped |
| V-TOT / V-UC05 | after every case and stage | PASS | V-TOT 0 after each of the 43 T-F05 cases (in-script) and after every stage (I1–I10) |
| T-SCH-01, T-SCH-02 | P1 regression | PASS | The approved P1 schema builds and behaves as accepted |
| T-SCH-03 | 6 checks, twice | PASS | Table catalog identical to `FitLife_P3_P1` (108 items); only 1 procedure and 2 types added; write scope as in the code review; no leftover principal or permission |

Evidence: [UC05-RUN__20261109-0829.txt](../evidence/test-results/UC05-RUN__20261109-0829.txt), [T-F05-CREATE__20261109-0829.txt](../evidence/test-results/T-F05-CREATE__20261109-0829.txt), [T-CONC-06__20261109-0829_A.txt](../evidence/test-results/T-CONC-06__20261109-0829_A.txt), [_B](../evidence/test-results/T-CONC-06__20261109-0829_B.txt), [_C](../evidence/test-results/T-CONC-06__20261109-0829_C.txt). Session-start baseline (read-only): [UC05-BASELINE__20261109-0806__fingerprint_before.txt](../evidence/test-results/UC05-BASELINE__20261109-0806__fingerprint_before.txt), [UC05-BASELINE__20261109-0806__p2_checksum_before.txt](../evidence/test-results/UC05-BASELINE__20261109-0806__p2_checksum_before.txt).

### 13.5 Acceptance criteria (§7)

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | All listed tests pass; V-TOT zero after every test | **MET** for T-F05-01, -03, -04, -18, -19 and T-CONC-06. T-F05-20 `NOT_RUN` by design (Q5 (b) not approved) | §13.4 |
| 2 | A failure in any line leaves no header and no lines (T-F05-19) | **MET** (incl. a failure after the header insert, B01, and an FK failure inside the transaction, B02) | T-F05-CREATE |
| 3 | Concurrent creations: distinct invoices, correct totals, no lost lines (T-CONC-06) | **MET**, 3 runs | T-CONC-06 A/B/C |
| 4 | No inventory, entitlement or catalogue logic (code review recorded) | **MET** | §13.2; T-SCH-03 K4/K5 |
| 5 | The creation-cost baseline has a RUN_ID | **NOT MET — BLOCKED by R-27** (task 5 `NOT_RUN`). The directive does not authorize a formal benchmark or a change to `FitLife_P3_P2`, and timings on this machine are DIAGNOSTIC_ONLY ([14 R-27 §7](../14_RISK_REGISTER.md#7-disposition-2026-11-09-owner-directive-urgent-unblock--core-implementation)). Impact: no write baseline for later index decisions (R-11) until a reliable environment exists | — |

### 13.6 Deviations and notes

1. Tests added beyond §4 (definitions in [11](../11_TEST_AND_QA_PLAN.md)): T-F05-23…26, T-SCH-03, V-UC05. They implement the directive's §9 list (repeat requests, no side effects, rollback inside a caller's transaction, least privilege).
2. Task 3 (permissions): demonstrated with TEST_ONLY principals only. Granting roles is a contract item for P6 (DEP-14); no permission is deployed.
3. `IssuedAt` is always the server UTC time of creation; callers cannot back-date. Settlement tests that need older invoices (T-F05-10 in WO-P3-P3-01) must insert TEST_ONLY rows directly, unless the Owner approves an issue-time input (DEP-15).
4. Service and product lines are numbered independently (the two item tables have separate primary keys); no approved rule requires one shared numbering.
5. Development incident (not evidence): a dry run of an earlier T-CONC-06 draft looped without end (PowerShell variable names are case-insensitive: `$k` and `$K`). It was stopped after about 5 minutes. It wrote only to the disposable `FitLife_P3_UC05` (about 139,500 invoices, all consistent by V-UC05), which the recorded run rebuilt from nothing. The harness now has a 300 s watchdog. Dry-run outputs stayed in the session scratchpad.

### 13.7 To reach `VERIFIED`

1. Owner decision on D-028 (provisional T2 is enough for isolated work): Q1–Q4 (a) as implemented; Q5 (a) as implemented, or (b) with an approved V003.
2. Criterion 5: a reliable benchmark environment (R-27), or an Owner decision, taken before any measurement, to move the creation-cost baseline into the formal benchmark WO (WO-P3-P2-02 or WO-P3-P3-03). This session does not change the criterion.
3. If Q5 (b) is chosen: V003, T-F05-20 and a re-run of `run_uc05_invoice_creation.ps1`.

### 13.8 Functional verification and acceptance (2026-11-09, Owner Directive "Close Invoice Creation and Prioritize Settlement")

**Preconditions now.** D-028 **APPROVED (provisional, T2)**: Q4 (a) and Q5 (a) by the directive §2, Q1–Q3 (a) by the Owner's answer in the same session, Q6 directed earlier ([03 D-028](../03_DECISION_LOG.md#d-028--invoice-creation-billing-responsibility-interface-finalisation-creation-idempotency)). No D-028 sub-decision remains open. GATE-P2 is not a precondition of the functional scope (directive 2026-11-09 §3/§6; now also §3 of this directive, criterion 5 transferred).

**Conditions of Q4 checked against the implementation:**

| Q4 condition | Where it holds | Evidence |
|---|---|---|
| Caller is an authorized, trusted component | Only a principal with EXECUTE on the routine and the two line types can create; direct INSERT/UPDATE denied | T-F05-26 PASS (run 1446) |
| Monetary values validated | 51105–51109: quantity > 0, price ≥ 0, discount ≥ 0, discount ≤ line gross, totals within DECIMAL(18,2) | T-F05-03 (16 cases) PASS |
| Header totals calculated consistently from the submitted lines | Gross, Discount, Final computed by the routine; X1 and BR12 re-checked before commit (51115) | T-F05-01, V-TOT after each of 43 cases, V-UC05 I1, T-CONC-06 C3/C4 |
| No catalogue-validation claim | The routine reads PRODUCT and SERVICE_PLAN by key only (T-SCH-03 K4); no price lookup exists, and none is claimed. Upstream price validation = integration requirement DEP-04 (callers) | T-SCH-03 K4/K5 PASS |

**Q5 (a) checked.** T-F05-23: an identical repeated request creates a second, distinct PENDING invoice; no uniqueness on business values; no V003. Exactly-once creation is not claimed (DEP-16). Settlement is idempotent per `Invoice_ID` (WO-P3-P3-01 T-F05-06, T-CONC-01).

**Fresh regression run.** `UC05-RUN__20261109-1446` (14:46:40–14:47:22 UTC) — the unchanged runner `tests/db/functional/run_uc05_invoice_creation.ps1` on a freshly rebuilt `FitLife_P3_UC05`: **19 of 19 steps PASS** (T-SCH-01 53 PASS / 1 INFO; T-SCH-02 6/6; T-SCH-03 6/6 twice; T-F05 43/43; V-UC05 10/10 after T-F05 and after each of T-CONC-06 A, B, C; fingerprint after = before; DS-L checksum `26ABB277…CA1F` before = after = run C). The procedure definition is unchanged (SHA-256 `3513176C…3013` in T-SCH-03 K5 and in WO-P3-P3-01 T-SCH-04 K5); only the file's header comment was updated to the approved D-028 wording, so the file hash differs from run 0829. The routine was exercised again in run `UC05S-RUN__20261109-1447` (creation of every settlement test invoice; T-CONC-06 run R 5/5 with the settlement objects deployed).

Evidence: [UC05-RUN__20261109-1446.txt](../evidence/test-results/UC05-RUN__20261109-1446.txt), [T-F05-CREATE__20261109-1446.txt](../evidence/test-results/T-F05-CREATE__20261109-1446.txt), [T-CONC-06__20261109-1446_A.txt](../evidence/test-results/T-CONC-06__20261109-1446_A.txt), [_B](../evidence/test-results/T-CONC-06__20261109-1446_B.txt), [_C](../evidence/test-results/T-CONC-06__20261109-1446_C.txt); earlier run 0829 (§13.4) unchanged.

**Amended acceptance criteria:**

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | All listed tests pass; V-TOT zero after every test | **MET** (T-F05-20 `NOT_RUN` by design: Q5 (b) not chosen — the decision is now (a), so the test does not apply) | runs 0829 and 1446 |
| 2 | Failure in any line leaves nothing (T-F05-19) | **MET** | T-F05-CREATE 0829, 1446 |
| 3 | Concurrent creations correct (T-CONC-06) | **MET** (6 runs: 0829 A/B/C, 1446 A/B/C; plus 1447 R) | T-CONC-06 files |
| 4 | No inventory, entitlement or catalogue logic | **MET** | §13.2; T-SCH-03 K4/K5 |
| 5 | ~~Creation-cost RUN_ID~~ | **TRANSFERRED** to WO-P3-P3-03 criterion 5 (§7a); open, not PASS | — |

**Status decision.** Every amended mandatory criterion is met and every precondition decision is approved, so this session sets `VERIFIED`. The Owner's directive §3 states a conditional acceptance of the functional completion "once that verification is confirmed"; master prompt A1 rule 1 accepts an explicit in-session Owner instruction as the approval, and this project already recorded `PASSED` in the same way after a conditional Owner acceptance (WO-P3-P0-01 addendum of 2026-11-07; WO-P3-P2-01 §14). The status is therefore recorded as **`PASSED` (functional acceptance), approver: Project Owner, 2026-11-09**. The agent did not approve it on its own. Performance acceptance of invoice creation remains open in WO-P3-P3-03.
