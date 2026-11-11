# WO-P3-P3-01 — Settlement Routine

| Field | Value |
|---|---|
| Status | **PASSED** (2026-11-09, functional and reference-variant acceptance). `VERIFIED` by this session (§13.8): all four acceptance criteria met — criteria 1–3 by runs `UC05S-RUN__20261109-1447` and `UC05S-RUN__20261109-1610` (full regression, 32/32 each), criterion 4 by run `UC05U-RUN__20261109-1610` (U0 implemented as REFERENCE_ONLY, T-F05-36/37 PASS, code search recorded). Recorded `PASSED` on the Project Owner's explicit conditional acceptance (Owner Directive "Finalize UC05 Settlement and Implement Loyalty" §1 item 4, §7). **Not included:** U0 vs U1 timing and comparison, which stay in WO-P3-P3-03 (R-27) |
| Phase | P3 — Billing, Settlement and Loyalty Implementation |
| Mode | BUILD_AUTHORIZED |
| Approver | Project Owner (the UC01/UC04 owners review the real hooks at P6) |
| Approval record | **APPROVED 2026-11-09, BUILD_AUTHORIZED**, by the Owner Directive "Close Invoice Creation and Prioritize Settlement" (Claude Code session of 2026-11-09) §4, conditional on every mandatory prerequisite being approved. Condition met in the same session: D-012 (a) and D-019 (a) APPROVED (provisional, T2) and the F002 points-only TEST_ONLY extension approved by the Owner's answers to the decision questions; D-003, D-004, D-005, D-006, D-011, D-013, D-014, D-023 already approved; WO-P3-P3-00 `PASSED` (functional). Not approved: moving task 2 (U0) out of this WO. No commit, push, merge or deployment authorized |
| Target database | `FitLife_P3_UC05` (isolated, disposable; P3_Disposable marker verified before every rebuild by `tests/db/build/rebuild_uc05_db.sql`; directive §6). `FitLife_P3_P1`, `FitLife_P3_P2` and all other databases read only and unchanged (fingerprint and DS-L checksum before = after) |
| Revision | 2026-11-08 (Owner Directive "Reprioritize Person 3 Implementation" (2026-11-08, D-027)): WO-P3-P1-02 removed from the preconditions; hooks are contract-only test doubles (D-026 condition 6, DEP-05); D-012 provisional (T2) for isolated work; real-routine T-INT-01/02 moved to WO-P3-P6-01; invoice creation moved to WO-P3-P3-00. 2026-11-09 (Owner Directive "Urgent Unblock & Core Implementation" §3, §10): GATE-P2 / WO-P3-P2-02 / R-27 are **not** preconditions of the functional settlement scope (tasks 1, 3, 3a–3c, 4, 5); only measurements of the U0 variant depend on R-27, and they belong to WO-P3-P3-03. The creation routine exists (WO-P3-P3-00 `IN_PROGRESS`, functional tests PASS); settlement may build on it once this WO is approved, before WO-P3-P3-00 is `PASSED`, if the Owner says so. Test note: the creation routine sets `IssuedAt` to the current UTC time, so month-boundary tests (T-F05-10) need TEST_ONLY invoice rows inserted directly, or an approved issue-time input (DEP-15). Still required: D-012 (a) at least T2, D-019, F002. Not approved by the directive. 2026-11-09 (2) (Owner Directive "Close Invoice Creation and Prioritize Settlement"): D-012 (a), D-019 (a) and F002 points-only approved; WO approved and executed except task 2 (§13). No acceptance criterion was changed |

## 1. Objective

Implement the atomic, idempotent settlement routine (F06 + F20 effects: PENDING→PAID), the benchmark-only baseline variant U0, and cancellation (PENDING→CANCELLED; D-011). Prove functional correctness, rollback and the hook contract with test doubles. Invoice creation is **not** part of this WO (WO-P3-P3-00); the real inventory and entitlement routines are verified at P6.

## 2. Preconditions

For the functional scope (2026-11-09): WO-P3-P3-00 creation routine available (`PASSED`, or the Owner accepts its `IN_PROGRESS` functional portion); GATE-P2 only for any timing measurement; D-006 and D-019 APPROVED; **D-012 alternative (a) APPROVED, at least provisionally (T2) for isolated work** (P3 orchestrates; hooks per [12 §5](../12_INTEGRATION_PLAN.md#5-settlement-orchestration-interface-proposal)); D-003, D-004, D-005, D-011 ✔. The F002 fixture extension exists or is created here (settlement increments `MEMBER.CurrentPoints`; DEP-02). **Not required (D-027):** WO-P3-P1-02, other members' hook routines, their approval. The inventory decrement and entitlement activation are represented by **contract-only test doubles** in the isolated database: the agreed signature, a TEST_ONLY call log, and an on-request error for fault injection; no stock, entitlement or other domain logic (D-026 condition 6). They are replaced by the real routines in WO-P3-P6-01, where T-INT-01/02 run against them.

## 3. Inputs

[06 §4.2–§4.5, §4.8, §4.9, §8](../06_UC05_BILLING_LOYALTY_PLAN.md#42-payment-confirmation-settlement-f06); [12 §2b, §4–§6](../12_INTEGRATION_PLAN.md#4-transaction-composition-rules); DL-03, DL-04; the WO-P3-P3-00 creation routine.

## 4. Tasks

1. Implement `usp_P3_SettleInvoice` (name per D-021) following [06 §4.2](../06_UC05_BILLING_LOYALTY_PLAN.md#42-payment-confirmation-settlement-f06): one transaction, update lock on the invoice, conditional transition, BR12 check, hooks in the lock order, points per D-006, safe spending upsert, points increment, result codes, P3 error range.
2. Implement `usp_P3_SettleInvoice_Baseline` (U0) with the same contract, recomputing window spend from INVOICE and re-ranking the tier synchronously. Mark it **benchmark-only**.
3. Implement cancellation (PENDING→CANCELLED only; D-011 approved provisionally 2026-11-07).
3a. Enforce the transition invariants T1–T5 of [WO-P3-P1-01 §3.4](WO-P3-P1-01_PHYSICAL_SCHEMA.md#34-keys-foreign-keys-and-constraints): conditional updates in the routines, and status changes allowed only through the routines (permissions). An AFTER UPDATE guard trigger is an optional defence-in-depth variant; adopt it only if measured and approved.
3b. Compute SpendingMonth as the Asia/Ho_Chi_Minh calendar month of PaidAt (PaidAt stored in UTC; D-013, D-014).
3c. Create the contract-only hook test doubles (TEST_ONLY, `tests/db/doubles/`), called in the lock order of [12 §6](../12_INTEGRATION_PLAN.md#6-global-lock-order-proposal).
4. Write tests T-F05-02, T-F05-05…T-F05-08, T-F05-10, T-F05-11, T-F05-16, T-F05-21, T-F05-22, using fixtures, the test doubles and test-only fault-injection objects created and dropped by the test scripts. T-INT-01/02 with the real routines are `NOT_RUN` here by design (WO-P3-P6-01).
5. Run the tests and save the outputs. Update [01](../01_REQUIREMENTS_TRACEABILITY.md), [16](../16_READINESS_REPORT.md) and [SESSION_LOG.md](../SESSION_LOG.md).

## 5. Out of scope

Invoice creation (WO-P3-P3-00); real inventory or entitlement logic and any simulated workflow (other members' modules); tier batch and lookup (WO-P3-P3-02); concurrency suite and U0/U1 benchmark (WO-P3-P3-03); revenue summary maintenance (only if D-015/D-016 are already decided; otherwise added in WO-P3-P4-02); new indexes; fault-injection or rollback tests outside an isolated database (D-025 condition 4); deploying routines to the canonical shared database (D-025 conditions 6–7).

## 6. Deliverables and locations

DL-07 in `db/procedures/`; tests in `tests/db/functional/`; outputs in `evidence/test-results/`.

## 7. Acceptance criteria

1. All listed tests pass.
2. A repeated settlement produces no second effect (T-F05-06).
3. An injected failure leaves no partial effect (T-F05-08).
4. The U0 variant is not called by any application path (code search documented).

## 8. Verification

Run the full listed test set on a freshly installed database (DL-03 + DS-S fixtures) and save the outputs.

## 9. Evidence

`evidence/test-results/T-F05-*__*.txt`.

## 10. Dependencies and risks

R-04, R-10, R-16, R-26.

## 11. Approval requirements

WO approval with the target database named; the D-012 provisional approval; separate authorization for commits. The hook owners' agreement is obtained at P6 (WO-P3-P1-02).

## 12. Exit and next step

Next: WO-P3-P3-02.

## 13. Execution record

Session of 2026-11-09 (Owner Directive "Close Invoice Creation and Prioritize Settlement"), mode BUILD_AUTHORIZED. Clone `C:\Users\DELL\source\repos\CSDLNC-DA`, branch `p3/wo-p3-p1-01`, HEAD `792a85e`; nothing committed.

### 13.1 Precondition check (§2) and resulting scope

| Precondition | State on 2026-11-09 | Effect |
|---|---|---|
| Creation routine available | WO-P3-P3-00 `PASSED` (functional, 2026-11-09) | Settlement tests create their invoices through `usp_P3_CreateInvoice` |
| D-006 | APPROVED (2026-11-08) | Points per member-month, incremental, same statement as TotalSpend |
| D-012 (a) | **APPROVED (provisional, T2)** 2026-11-09 (Owner's answer in this session) | One transaction owned by P3; hooks as TEST_ONLY doubles |
| D-019 (a) | **APPROVED (provisional, T2)** 2026-11-09 (Owner's answer in this session) | READ COMMITTED; UPDLOCK on the invoice; UPDLOCK+HOLDLOCK upsert; atomic increments |
| D-003, D-004, D-005, D-011, D-013, D-014, D-023 | APPROVED ✔ | Transition, PaidAt, domains, cancellation only, month rule, UTC, totals |
| F002 | **Points-only subset approved** 2026-11-09 (Owner's answer): MEMBER.CurrentPoints only; no Tier_ID, no MEMBER_TIER, no thresholds | `tests/db/fixtures/F002P__…` |
| GATE-P2 / R-27 | Not a precondition of the functional scope (revision of 2026-11-09; directive §8) | No timing is reported |
| Task 2 (U0) | Needs tier window and thresholds (D-007, D-008 `PROPOSED`); directive §4 forbids invented thresholds; moving it out was not approved | **Not implemented**; criterion 4 `NOT_RUN` |

**Does settlement have to update MEMBER_MONTHLY_SPENDING and MEMBER in the same transaction?** Yes. D-006 (approved) credits points "incrementally at settlement … in the same statement as the TotalSpend increase", D-024 (approved) fixes CurrentPoints = Σ PointsEarned, and D-012 (a) puts all effects in one transaction with the PENDING→PAID transition as the only exactly-once token (06 §4.3). A PAID invoice without these effects would break D-006/D-024, so both are applied inside the settlement transaction. Tier evaluation is **not** a settlement effect in the approved contract (D-009 open; periodic batch in WO-P3-P3-02), and the revenue summary is deferred (D-015/D-016), so neither is touched. No unapproved tier rule is used.

### 13.2 Design choices inside the approved decisions (smallest compatible scope)

| Choice | Reason | Recorded as |
|---|---|---|
| `PaidAt` = server UTC time of the settlement; no caller-supplied payment time (the optional input of 12 §5 is not implemented) | D-004/D-014: UTC; avoids back-dating, as for `IssuedAt` (DEP-15). Month-boundary behaviour is therefore tested on the month function and end to end (T-F05-10) | DEP-17 |
| `@PaymentMethod` optional: if NULL the method recorded at creation is used; if both exist and differ the request is rejected (51208), never overwritten | D-005 allows the method at creation or settlement and requires it when PAID; no approved rule says which wins, so the conservative choice keeps the recorded value | DEP-18 (callers confirm at P6) |
| Repeat on a PAID invoice → `ALREADY_SETTLED`, no effect, stored PaidAt returned (whatever method is supplied); repeat cancellation → `ALREADY_CANCELLED` | D-003 (A) idempotency token; 06 §4.3 | §13.5 |
| Both hooks are called exactly once per settlement, inventory first, before the transition, while the invoice row is locked | D-012 (a); lock order 12 §6; T-F05-21 | DEP-05 (hook names `usp_HOOK_InventoryDecrementForInvoice`, `usp_HOOK_EntitlementActivationForInvoice`, parameter `@Invoice_ID`) |
| Spending row `UpdatedAt` = latest PaidAt of the row (kept monotonic when commits interleave) | Same definition as the seed generator S001 (`MAX(PaidAt)`), so P2 and P3 data agree | V-UC05S U3 |
| Eligibility re-checked inside the transaction: PENDING, ≥ 1 line (BR12), header = Σ lines (D-023 X1), settlement time ≥ IssuedAt | Directive §5 ("only eligible PENDING invoices", "totals consistent before settlement") | 51204–51206, 51212 |

### 13.3 Implemented

| File | Classification | Content |
|---|---|---|
| [db/procedures/usp_P3_SettleInvoice.sql](../../../../db/procedures/usp_P3_SettleInvoice.sql) | P3_OWNED, programmability only | `dbo.tvf_P3_SpendingMonth` (inline function, UTC → first day of the Asia/Ho_Chi_Minh month, UTC+7) and `dbo.usp_P3_SettleInvoice` (task 1; 3a; 3b). Errors 51201–51212 |
| [db/procedures/usp_P3_CancelInvoice.sql](../../../../db/procedures/usp_P3_CancelInvoice.sql) | P3_OWNED, programmability only | `dbo.usp_P3_CancelInvoice` (task 3; PENDING→CANCELLED; PAID refused, 51223). Errors 51221–51224 |
| [tests/db/fixtures/F002P__TEST_ONLY_member_current_points.sql](../../../../tests/db/fixtures/F002P__TEST_ONLY_member_current_points.sql) | TEST_ONLY fixture | `MEMBER.CurrentPoints INT NOT NULL DEFAULT 0` on the key-only fixture; nothing else |
| [tests/db/doubles/D001__TEST_ONLY_settlement_hook_doubles.sql](../../../../tests/db/doubles/D001__TEST_ONLY_settlement_hook_doubles.sql) | TEST_ONLY doubles (task 3c) | Two contract-only hook procedures, `TEST_HookCallLog`, `TEST_HookFault` (call log, fault injection 52901/52902; no domain logic) |
| [tests/db/functional/T-F05S_settlement.sql](../../../../tests/db/functional/T-F05S_settlement.sql) | Test | 47 cases (§13.5) |
| [tests/db/functional/V-UC05S_settlement_integrity.sql](../../../../tests/db/functional/V-UC05S_settlement_integrity.sql) | Test | Whole-database checks U1–U10 incl. spending reconciliation with an independent month oracle |
| [tests/db/schema/T-SCH-04_settlement_catalog_and_scope.sql](../../../../tests/db/schema/T-SCH-04_settlement_catalog_and_scope.sql) | Test | Catalog vs `FitLife_P3_P1`, inventory, write scope of settle and cancel, no dynamic SQL |
| [tests/db/concurrency/T-CONC-01_02_parallel_settlement.ps1](../../../../tests/db/concurrency/T-CONC-01_02_parallel_settlement.ps1) | Test | Barrier-synchronised sessions; final-state checks C1–C5; 300 s watchdog |
| [tests/db/functional/run_uc05_settlement.ps1](../../../../tests/db/functional/run_uc05_settlement.ps1) | Test runner | Steps 1–21 with masked evidence |

Changed: [db/procedures/usp_P3_CreateInvoice.sql](../../../../db/procedures/usp_P3_CreateInvoice.sql) header comment only (D-028 now approved); definition unchanged (SHA-256 `3513176C…3013`). No table, column, constraint or index of a P3 table was created or changed (T-SCH-04 K1); no migration added.

**Settlement contract.** Inputs `@Invoice_ID` (required), `@PaymentMethod` (optional). Outputs `@Outcome` (`SETTLED` | `ALREADY_SETTLED`), `@PaidAt` (UTC), `@PointsEarned` (this call), `@CurrentPoints` (balance after). Steps: validate parameters → own or join the transaction (`XACT_ABORT ON`) → read the invoice with UPDLOCK → PAID: `ALREADY_SETTLED`, no effect → not PENDING: 51204 → eligibility (method 51207/51208, BR12 51205, X1 51206, time 51212) → inventory hook → entitlement hook → conditional `PENDING→PAID` (exactly one row, else 51209) → spending upsert (UPDLOCK+HOLDLOCK update, else insert; TotalSpend, PointsEarned = FLOOR(total/100000) in the same statement; OUTPUT old/new points) → `MEMBER.CurrentPoints += new − old` → commit. Any error: rollback (own transaction) or doomed caller transaction; error passed through unchanged.

**Code review (scope).** Settlement modifies only INVOICE (status, PaidAt, method), MEMBER_MONTHLY_SPENDING and MEMBER.CurrentPoints; reads the two line tables; calls only the two hooks and the month function; no tier, MEMBER_TIER, catalogue, stock, entitlement or TEST_ reference; no dynamic SQL (T-SCH-04 K3, K5). Cancellation reads INVOICE and writes only PaymentStatus (K4). Definition SHA-256: settle `96C877A8…7E44`, cancel `9C2EE95C…39D4`, function `7E8A717B…B780`.

### 13.4 Verification run

`UC05S-RUN__20261109-1447` (14:47:29–14:48:45 UTC) on a freshly built `FitLife_P3_UC05`: **32 of 32 steps PASS** — fingerprint and DS-L checksum before; build; T-SCH-01 (53 PASS / 1 INFO) and T-SCH-02 (6/6) P1 regression; creation routine; T-SCH-03 6/6; F001U; F002P; D001; settle; cancel; T-SCH-04 6/6 (+1 INFO); T-F05S 47/47; V-UC05S 10/10 after T-F05S and after each of the 7 concurrency runs; T-CONC-06 run R 5/5; T-CONC-01 A/B/C 5/5 each; T-CONC-02 A/B/C 5/5 each; T-SCH-04 again 6/6; fingerprint after = before; DS-L checksum `26ABB277…CA1F` before = after = run C. Server clock: UTC 14:47:29.69 = local 21:47:29.69 +07:00 (PaidAt values in the evidence are UTC). The machine was on AC. Final disposable content: 877 invoices (200 PENDING from T-CONC-06, 673 PAID, 4 CANCELLED), 24 spending rows, 247 points, 1,346 hook calls. Times are context, not measurements (R-27).

Dry runs before the recorded run (same scripts, outputs kept only in the session scratchpad, not evidence) found and fixed three script defects: a compile-time column reference in F002P (split into two batches), a catalog collation conflict in T-SCH-04, and a PRINT with a subquery in T-F05S.

### 13.5 Test results

| Test | Cases | Result | What it shows |
|---|---|---|---|
| T-F05-05 | 4 | PASS | PENDING → PAID; PaidAt within the call's UTC window and returned; method from the call or from creation; spending +FinalAmount; points and balance as returned; one call per hook |
| T-F05-06 | 3 | PASS | Repeat (same method, other method, none): `ALREADY_SETTLED`, whole-state hash unchanged, stored PaidAt and method preserved |
| T-F05-07 | 5 | PASS | Unknown id (51203), NULL id (51201), CANCELLED invoice (51204); cancel unknown (51222) / NULL (51221); nothing written |
| T-F05-08 | 3 | PASS | Injected failure at the MEMBER step (52910) and at the spending step (52911): status, PaidAt, method, spending, points and hook log unchanged; then the same invoice settles once (300,000 → 3 points) |
| T-F05-09 | 7 | PASS | D-006: 0 → 0; 99,999 → 0; 100,000 → 1; 199,999 → 1; 200,000 → 2; two × 60,000 in one month → 0 then +1 |
| T-F05-10 | 3 | PASS | 2026-01-31 16:59:59.999 UTC → January, 17:00:00.000 → February, year end, leap day; 9,012 instants vs `AT TIME ZONE` oracle, 0 mismatches; every PAID invoice in its local-month row |
| T-F05-11 | 1 | PASS | Second payment in the month updates the same row (230,000 → 2 points, +1) |
| T-F05-16 | 3 | PASS | Cancel PENDING → CANCELLED without any effect; repeat → `ALREADY_CANCELLED`; PAID cannot be cancelled (51223) |
| T-F05-02 | 1 | PASS | PENDING invoice without lines (TEST_ONLY direct insert) → 51205, nothing written |
| T-F05-21 | 1 | PASS | Every settled invoice: one inventory then one entitlement call, inside the transaction, while PENDING; none for repeated, rejected, rolled-back or cancelled requests |
| T-F05-22 | 2 | PASS | Inventory-hook fault (52901) and entitlement-hook fault (52902) pass through unchanged; everything rolled back, including the inventory call |
| T-F05-27 | 6 | PASS | Method conflict (51208), none available (51207), `CHEQUE`, `cash`, `CASH `, empty (51202); then the recorded method settles |
| T-F05-28 | 2 | PASS | Header gross ≠ lines, header discount ≠ line discounts (TEST_ONLY rows) → 51206, nothing written |
| T-F05-29 | 4 | PASS | Inside a caller transaction: commit keeps everything; rollback removes everything; a later error leaves `XACT_STATE() = -1` and one rollback removes the earlier settlement; the invoice then settles once |
| T-F05-30 | 1 | PASS | TEST_ONLY role with EXECUTE only: settles; cancel of PAID refused; direct PAID→PENDING update, points update, spending insert and hook call all denied (229); principals dropped |
| T-F05-31 | 1 | PASS | IssuedAt in the future → 51212 (PaidAt ≥ IssuedAt, D-004) |
| T-CONC-01 | 3 runs × 200 calls | PASS ×3 | 10 sessions released together on each of 20 invoices (up to 10 calls in flight): exactly one `SETTLED` per PAID invoice, all others `ALREADY_SETTLED` with the stored PaidAt; settle-vs-cancel race on 12 invoices: 3 ended CANCELLED (no settlement, no effect), 9 PAID (cancel refused 51223); hooks once; spending, points and returned increments reconcile; 0 deadlocks |
| T-CONC-02 | 3 runs × 200 calls | PASS ×3 | 10 sessions × 20 rounds settling different invoices of two fresh members (round 1 = concurrent first insert of the month row): 600/600 `SETTLED`, one row per member-month, no PK violation, TotalSpend = Σ FinalAmount, PointsEarned = FLOOR, CurrentPoints = Σ PointsEarned = Σ returned increments (no lost update), UpdatedAt = latest PaidAt; 0 deadlocks |
| T-CONC-06 | 1 run (R) | PASS | Creation regression with the settlement objects deployed |
| V-UC05S | 8 stages | PASS | U1–U10 after every stage |
| T-SCH-04 | 6 checks, twice | PASS | Catalog = P1 + F002P items + TEST_ONLY double tables; inventory; write scope; no dynamic SQL; no leftover principal |
| T-INT-01, T-INT-02 | — | NOT_RUN (by design) | Real UC04/UC01 routines do not exist yet; WO-P3-P6-01. Impact: hook behaviour proven against the contract doubles only |

Evidence: [UC05S-RUN__20261109-1447.txt](../evidence/test-results/UC05S-RUN__20261109-1447.txt), [T-F05S-SETTLE__20261109-1447.txt](../evidence/test-results/T-F05S-SETTLE__20261109-1447.txt), [T-CONC-01 _A](../evidence/test-results/T-CONC-01__20261109-1447_A.txt), [_B](../evidence/test-results/T-CONC-01__20261109-1447_B.txt), [_C](../evidence/test-results/T-CONC-01__20261109-1447_C.txt), [T-CONC-02 _A](../evidence/test-results/T-CONC-02__20261109-1447_A.txt), [_B](../evidence/test-results/T-CONC-02__20261109-1447_B.txt), [_C](../evidence/test-results/T-CONC-02__20261109-1447_C.txt), [T-CONC-06 _R](../evidence/test-results/T-CONC-06__20261109-1447_R.txt).

### 13.6 Acceptance criteria (§7)

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | All listed tests pass | **MET** for the task-4 list (T-F05-02, -05…-08, -10, -11, -16, -21, -22) plus T-F05-09, -27…-31, T-CONC-01/02. T-INT-01/02 `NOT_RUN` by design (WO-P3-P6-01) | §13.5 |
| 2 | Repeated settlement produces no second effect (T-F05-06) | **MET** (whole-state hash unchanged; also T-CONC-01) | T-F05S A04–A06 |
| 3 | Injected failure leaves no partial effect (T-F05-08) | **MET** (also T-F05-22, T-F05-29) | T-F05S C01–C05, D01–D04 |
| 4 | U0 variant not called by any application path | **NOT_RUN — blocked**: the U0 variant (task 2) does not exist; it needs D-007 (window) and D-008 (thresholds), both `PROPOSED`, and the directive forbids invented thresholds. No object named `%Baseline%` exists (T-SCH-04 K7) | — |

### 13.7 To reach `VERIFIED`

One of: (a) the Owner approves D-007 and D-008 (at least provisionally) and task 2 is implemented and criterion 4 checked; or (b) the Owner approves moving task 2 and criterion 4 to WO-P3-P3-03 (where U0 is benchmarked) or WO-P3-P3-02, after which criteria 1–3 already suffice. Nothing else is open in this WO.

_2026-11-09 (PLAN_ONLY review):_ task 2 needs a valid tier-aware routine and a documented code search, **not** timing or a comparison with U1 (both WO-P3-P3-03, R-27). It needs D-007 and only the D-008 **rule** (threshold values can be TEST_ONLY synthetic), plus the F002 tier fixture. Narrowest path, minimal functional tests and approval statements: [P3 loyalty decision package §5–§6](../design/P3_LOYALTY_DECISION_PACKAGE.md). Status unchanged (`IN_PROGRESS`).

### 13.8 Task 2 (U0) completion, verification and acceptance (2026-11-09, Owner Directive "Finalize UC05 Settlement and Implement Loyalty")

**Preconditions now.** D-007 (d) and the D-008 **rule** APPROVED (provisional, T2) on 2026-11-09; F002T approved as TEST_ONLY. D-008 threshold **values** remain open: U0 reads whatever MEMBER_TIER holds; the tests use TEST_ONLY_SYNTHETIC values (Gold 1,000,000.00, Platinum 3,000,000.00) and derive every boundary from the table.

**Implemented (task 2 only).**

| File | Classification | Content |
|---|---|---|
| [db/reference/usp_P3_SettleInvoice_Baseline.sql](../../../../db/reference/usp_P3_SettleInvoice_Baseline.sql) | REFERENCE_ONLY (benchmark-only U0), outside `db/procedures/` | One transaction: calls the **unchanged** `usp_P3_SettleInvoice`; only on `SETTLED` it recomputes the member's D-007 window spend from the full INVOICE history (UTC bounds of the local months) and re-ranks the tier by the D-008 rule from MEMBER_TIER (`≥`, highest threshold, base 0). Error 51311 for an invalid tier configuration; all settlement errors pass through. Extended property `REFERENCE_ONLY` |
| [tests/db/fixtures/F002T__TEST_ONLY_member_tier.sql](../../../../tests/db/fixtures/F002T__TEST_ONLY_member_tier.sql) | TEST_ONLY fixture | MEMBER_TIER (Phase 1 columns; Silver 0 + synthetic Gold/Platinum from sqlcmd variables) and MEMBER.Tier_ID NOT NULL + FK; all members on Silver |
| [tests/db/fixtures/F003H__TEST_ONLY_paid_history_helper.sql](../../../../tests/db/fixtures/F003H__TEST_ONLY_paid_history_helper.sql) | TEST_ONLY helper | Consistent past PAID invoices (invoice, line, month row, points) for window tests, listed in `TEST_HistoryInvoice` |
| [tests/db/functional/T-F05-U0_settlement_baseline.sql](../../../../tests/db/functional/T-F05-U0_settlement_baseline.sql) | Test | T-F05-36 (U01–U06), T-F05-37 (U07–U08), K01 |
| [tests/db/functional/V-UC05T_loyalty_integrity.sql](../../../../tests/db/functional/V-UC05T_loyalty_integrity.sql) | Test | Successor of V-UC05S for databases with tiers and history (allowed-object list; history invoices excluded from the hook check) |
| [tests/db/functional/run_uc05_settlement_u0.ps1](../../../../tests/db/functional/run_uc05_settlement_u0.ps1) | Runner | Unchanged P3-01 runner first, then the U0 stage and the repository code search |

Also changed: `tests/db/fixtures/F002P__…` guard only (allows the Owner-approved DS-L copy `FitLife_P3_UC05L`; content unchanged). `usp_P3_SettleInvoice` is **not** modified (definition SHA-256 `96C877A8…7E44` checked in K01).

**Run `UC05U-RUN__20261109-1610`** (16:08–16:11:42 UTC): 10/10 steps PASS — fingerprint before; the **unchanged** runner `run_uc05_settlement.ps1` as full regression on a fresh build (`UC05S-RUN__20261109-1610`: 32/32, T-F05S 47/47, T-CONC-01 ×3, T-CONC-02 ×3, T-CONC-06 R, V-UC05S ×8, T-SCH-03/04); F002T; F003H; U0; T-F05-U0 9/9; V-UC05T 10/10; code search; fingerprint after = before; DS-L checksum `26ABB277…CA1F` = run C.

| Case | Test | Result | What it shows |
|---|---|---|---|
| U01 | T-F05-36 | PASS | U0 keeps the settlement contract (PAID, PaidAt, spending, points, one call per hook); spend Gold − 0.01 → Silver |
| U02 | T-F05-36 | PASS | Spend = Gold threshold → Gold (inclusive) |
| U03 | T-F05-36 | PASS | Repeat → `ALREADY_SETTLED`, whole state incl. Tier_ID unchanged |
| U04 | T-F05-36 | PASS | Window from INVOICE: month 12 back (Platinum-level) ignored, month 11 back counted (independent `AT TIME ZONE` oracle = Gold); stale Platinum lowered to Gold |
| U05 | T-F05-36 | PASS | The production routine alone leaves Tier_ID unchanged (D-009 (a)) |
| U06 | T-F05-36 | PASS | CANCELLED (51204), invalid method (51202), invalid tier configuration (51311): nothing written |
| U07 | T-F05-37 | PASS | Failure injected at the U0 tier update (52920): status, PaidAt, spending, points, hook calls, tier all rolled back; retry settles once |
| U08 | T-F05-37 | PASS | Caller transaction: rollback removes everything; later error → `XACT_STATE = -1`, one rollback removes all |
| K01 | AC4 | PASS | No module references U0; marker REFERENCE_ONLY; settlement routine unchanged |
| Code search | AC4 | PASS | "SettleInvoice_Baseline" occurs only in `db/reference/usp_P3_SettleInvoice_Baseline.sql` and TEST_ONLY scripts under `tests/` (5 files); none in `db/procedures`, `db/migrations`, `db/seed`; the repository contains no application code |

Evidence: [UC05U-RUN__20261109-1610.txt](../evidence/test-results/UC05U-RUN__20261109-1610.txt), [T-F05-U0__20261109-1610.txt](../evidence/test-results/T-F05-U0__20261109-1610.txt), [UC05S-RUN__20261109-1610.txt](../evidence/test-results/UC05S-RUN__20261109-1610.txt) with its T-F05S, T-CONC-01/02/06 files of the same timestamp. Earlier evidence (run 1447) is kept unchanged.

**Acceptance criteria (§7), final.**

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | All listed tests pass | **MET** (runs 1447 and 1610; T-INT-01/02 `NOT_RUN` by design, WO-P3-P6-01) | §13.5; UC05S-RUN 1610 |
| 2 | Repeated settlement: no second effect | **MET** | T-F05-06, T-CONC-01, U03 |
| 3 | Injected failure: no partial effect | **MET** | T-F05-08, -22, -29, U07, U08 |
| 4 | U0 not called by any application path (code search documented) | **MET** | K01; code search step 8 |

**Status decision.** Every mandatory criterion is met and every precondition decision is approved, so this session set `VERIFIED`. The Owner's directive (§1 item 4, §7) gives an explicit conditional acceptance once all mandatory criteria are verified; as for WO-P3-P3-00, master prompt A1 rule 1 accepts such an in-session instruction, so the status is recorded **`PASSED`, approver: Project Owner, 2026-11-09**. Not part of this acceptance and not reported as PASS: U0/U1 timings and the U0 vs U1 comparison (WO-P3-P3-03, blocked by R-27).
