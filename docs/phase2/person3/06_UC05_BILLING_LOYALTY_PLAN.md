# 06 — UC05 Billing & Loyalty Plan

| Field | Value |
|---|---|
| Document status | DRAFT — WO-P3-BOOT-001; billing (§4.1), work orders (§7) and the P3 readiness checklist (§8) updated by the Owner Directive "Reprioritize Person 3 Implementation" (2026-11-08, D-027); **loyalty design updated to the approved D-007, D-008 rule, D-009 and the implementation of WO-P3-P3-01/-02 (2026-11-09, §4.5–§4.7, §4.10)** |
| Date | 2026-11-09 |
| Functions | F05 (invoice creation, P3 since 2026-11-07), F06 (settlement), F20, F21, F22; integration with F07, F19 |
| Requirements | RQ-A10, RQ-A12, RQ-A13, RQ-P01, RQ-P03, RQ-P05–RQ-P10, RQ-P14 |
| Decisions | Open: D-006, D-007, D-008, D-009, D-012, D-019, D-028. Approved provisionally (T2, 2026-11-07): D-003, D-004, D-005, D-011, D-014, D-023. Approved: D-013, D-024 (no redemption or expiry), D-026 (restricted). Scope (2026-11-07): P3 owns INVOICE, both item tables and MEMBER_MONTHLY_SPENDING; MEMBER and MEMBER_TIER are shared dependencies. |

> Everything below is a **planned design**. Steps are written as numbered actions, not code. Any rule that depends on an open decision is marked with that decision ID.

## 1. Problem statement

- **Official problem (S-01 p3, Problem 4, REQUIRED_BY_ASSIGNMENT):** every new invoice payment re-sums 12 months of invoices to re-rank the member (up or down) and compute points. This slows invoice printing. The storage of points and tiers must be redesigned so payment is not blocked.
- **Phase 1 answer (S-02 §2.6, DERIVED_FROM_PHASE1):** add spending to MEMBER_MONTHLY_SPENDING per member-month, keep CurrentPoints on MEMBER, evaluate tiers periodically from the monthly aggregate, and avoid recomputing all invoices in the payment flow.
- **Phase 1 UC05 requirement (S-02 §7.1):** no duplicate points; lower aggregation cost.

## 2. Functions and actors

| Function | Actor | Frequency | P3 responsibility |
|---|---|---|---|
| F05 Create invoice | Receptionist / sales staff (through other members' sale flows) | 900/day | **Core since 2026-11-07:** P3 creation routine (WO-P3-P3-00, D-028); callers confirmed at P6 |
| F06 Confirm payment | Receptionist / sales staff; payment gateway callback if D-003 models VNPay | 900/day | Settlement transaction and its loyalty/revenue effects |
| F20 Update spending and points | System (inside F06) | 900/day | Core |
| F21 Look up points/tier | Member, receptionist | 1,200/day | Core |
| F22 Periodic tier evaluation | System scheduler | 1 batch/day | Core |

## 3. Invoice state model (pending D-005, D-011)

```text
            create (F05)
                 │
                 ▼
            ┌─────────┐   settle (F06)    ┌──────┐   refund (only if D-011 includes it)   ┌──────────┐
            │ PENDING │ ────────────────▶ │ PAID │ ─────────────────────────────────────▶ │ REFUNDED │
            └─────────┘                   └──────┘                                         └──────────┘
                 │ cancel (if D-011)
                 ▼
            ┌───────────┐
            │ CANCELLED │
            └───────────┘
```

- Only PENDING→PAID produces loyalty and revenue effects.
- PAID and CANCELLED are terminal. D-011 (approved provisionally 2026-11-07) excludes refunds, so the REFUNDED branch above is **not** implemented; it stays in the diagram only to show what was excluded. Exact invariants S1–S5 and T1–T5: [WO-P3-P1-01 §3.4](work-orders/WO-P3-P1-01_PHYSICAL_SCHEMA.md#34-keys-foreign-keys-and-constraints).
- If the team decides payment always happens when the invoice is created (D-003/D-004 alternative), creation and settlement run in one transaction, but the same transition rules apply.

## 4. Workflow

### 4.1 Invoice creation (billing, F05; WO-P3-P3-00, D-028)

_Revised 2026-11-08: INVOICE and both item tables are P3-owned, so invoice creation is a P3 routine (WO-P3-P3-00). Other members' sale flows call it at P6 (DEP-04). The steps below follow the recommended D-028 answers._

1. The P3 creation routine inserts the INVOICE header in PENDING status and all its lines in one transaction (the caller supplies line prices; no stock check, no entitlement, no points).
2. Header totals follow D-023: Gross = Σ line gross, Discount = Σ line discounts, Final = Gross − Discount ≥ 0.
3. P3 relies on these invariants and verifies them in settlement (a defensive check) and in T-F05-01.
4. Creation is finalisation: lines are not edited afterwards; a correction is a cancellation plus a new invoice (D-028 Q3).
5. If clients can retry creation, a client request key (D-003 option C; D-028 Q5 (b)) prevents duplicate invoices (G-10); under the recommended Q5 (a) a duplicate is a visible PENDING invoice that can be cancelled.

### 4.2 Payment confirmation (settlement, F06)

Planned steps of `usp_P3_SettleInvoice` (placeholder name):

1. Validate parameters: invoice exists; PaymentMethod in the D-005 domain; PaidAt (default: now) not before IssuedAt.
2. Begin one transaction with `XACT_ABORT ON`.
3. Read the invoice row **with an update lock** (so concurrent settlers queue on this row). Read status, member, branch, FinalAmount and line count.
   - Status PAID → end the transaction and return `ALREADY_SETTLED` with no side effects (idempotent outcome).
   - Status not PENDING → roll back and raise a P3 error (51000–51999 range): "invoice not payable".
   - Zero lines → roll back and raise "invoice has no lines" (BR12).
4. Integration steps (D-012), in the agreed lock order:
   1. Inventory decrement for product lines (UC04 owner's routine). Any line with insufficient stock aborts the **whole** settlement (BR30).
   2. Entitlement activation for service lines (UC01 owner's routine).
5. Conditional transition: set status PAID, PaidAt and PaymentMethod **only where status is still PENDING**. Assert exactly one row changed. Otherwise roll back and raise an error (defence in depth).
6. Compute points per D-006.
7. Upsert the member's MEMBER_MONTHLY_SPENDING row for the month of the recognition timestamp (§4.4).
8. Increase MEMBER.CurrentPoints by the points.
9. If D-015/D-016 choose in-procedure maintenance: upsert the revenue-summary row for (branch, day).
10. Optional variant (D-009 b): immediate upgrade check using ≤ 12 monthly rows. Measured separately.
11. Commit. Return `SETTLED` with points earned and the new balance.

### 4.3 Exactly-once business effect

- **Single source of truth:** the PENDING→PAID transition of the invoice row. All effects (steps 4–9) happen in the same transaction as the transition. Either everything commits once, or nothing does.
- **Repeated requests** (double click, client retry after a timeout): the repeat finds PAID and returns `ALREADY_SETTLED` (T-F05-06).
- **Concurrent requests** for the same invoice: the update lock in step 3 serialises them. The second one sees PAID after the first commits (T-CONC-01).
- **Deadlock victim** (error 1205): the whole transaction is rolled back, so the caller may retry safely. The planned policy is up to 3 retries with a short back-off, implemented in the application or a wrapper (T-CONC-04).
- If D-003 chooses option (B), the uniqueness of the payment idempotency key becomes an additional guard. The invoice transition remains the primary one.
- **The composite PK (Member_ID, SpendingMonth) of MEMBER_MONTHLY_SPENDING does not prevent duplicate settlement** (master prompt §6). It only prevents two rows for the same member-month. A second settlement of the same invoice would simply add to the existing row. Exactly-once protection comes from the invoice state transition, and is verified by T-F05-06 and T-CONC-01, separately from any performance test.

### 4.4 Monthly spending update

- Key: (Member_ID, SpendingMonth = first day of the Asia/Ho_Chi_Minh calendar month that contains PaidAt) (D-013). PaidAt is stored in UTC (D-014), so the month is computed after converting to local time; e.g. PaidAt 2026-01-31 17:30 UTC = 2026-02-01 00:30 local → February.
- **Safe upsert pattern (planned):** first try to update the existing row, holding an update lock with range protection on the key. If no row exists, insert it. Concurrent first payments of the same member in the same month must not both insert (PK violation) or overwrite each other.
- Rejected pattern: an unguarded "check if exists, then insert" (race), and MERGE without a range lock (known race behaviour). The chosen pattern is proven by T-CONC-02.
- Effect: TotalSpend += FinalAmount; PointsEarned += points; UpdatedAt = now.

### 4.5 Loyalty point calculation (D-006 (b) APPROVED 2026-11-08; enforced per row by V003 since 2026-11-09)

| Option | Formula | Property |
|---|---|---|
| (a) per invoice — alternative | points = FLOOR(FinalAmount / 100,000) | Independent per invoice; simple reversal; loses fractions below 100,000 per invoice, so purchases under 100,000 VND never earn points |
| (b) monthly cumulative — **proposed** (changed 2026-11-07, D-006) | PointsEarned(month) = FLOOR(TotalSpend(month) / 100,000); a settlement adds the difference to CurrentPoints | Loses at most 99,999 VND per member-month; row invariant enforceable by a CHECK; computed in the same UPDATE as TotalSpend |

Boundary cases (T-F05-09): 0 → 0; 99,999 → 0; 100,000 → 1; 199,999 → 1; 200,000 → 2. Under (b), two invoices of 60,000 in the same month give 1 point; under (a) they give 0.

### 4.6 Periodic tier evaluation (F22; D-007 (d), D-008 rule, D-009 (a) APPROVED T2 2026-11-09 — implemented as described in §4.10)

Planned behaviour of `usp_P3_EvaluateTiers(@AsOfDate)`:

1. Compute the window from @AsOfDate per D-007. Proposed option (d): from the first day of the month 11 months before, up to (excluding) the first day of the next month.
2. For each member: window spend = Σ TotalSpend of MEMBER_MONTHLY_SPENDING rows in the window. Members with no rows have spend 0.
3. Target tier = the tier with the highest SpendingThreshold ≤ window spend (D-008). The base tier has threshold 0, so every member gets a tier (BR04).
4. Update MEMBER.Tier_ID **only where it differs** (up or down). This is set-based and processed in chunks of Member_ID ranges. Each chunk is its own short transaction, sized to stay below lock escalation (about 5,000 locks), so concurrent settlements are not blocked (R-15).
5. Running it twice for the same @AsOfDate yields the same result (idempotent, T-F05-14).
6. Return counts per tier change (upgrades, downgrades, unchanged) for logging and evidence.

The cost is bounded: at most 12 monthly rows per member, about 30,000 × 12 = 360,000 rows per run in the worst case (DS-L upper bound), once per day, outside the payment path.

### 4.7 Loyalty lookup (F21)

Return CurrentPoints, the current tier and its name, the window spend (≤ 12 rows), and the amount still needed for the next tier. Expected access: PK seek on MEMBER, PK range seek on MEMBER_MONTHLY_SPENDING, and a 3-row MEMBER_TIER read. Measured in T-PERF-08.

### 4.8 Transaction rollback

- `XACT_ABORT ON`, plus error handling that rolls back when a transaction is open and re-raises the original error. Sub-routines must never commit or roll back the caller's transaction (contract in [12 §4](12_INTEGRATION_PLAN.md#4-transaction-composition-rules)).
- **Fault injection for tests (planned; test database only):**
  - (i) a temporary test-only trigger on MEMBER that raises an error, which makes the late step 8 fail;
  - (ii) insufficient stock on one product line, which makes step 4 fail.

  In both cases the test verifies that the invoice status, PaidAt, MEMBER_MONTHLY_SPENDING, CurrentPoints, inventory, entitlements and any summary row are unchanged (T-F05-08, T-INT-02). Test-only objects are created and dropped by the test script. They are never part of the deployable schema.

### 4.9 Concurrent settlement handling

| Scenario | Protection | Test |
|---|---|---|
| Same invoice, N parallel settlements | Update lock on the invoice row + conditional transition | T-CONC-01 |
| Same member, different invoices, same month | Safe upsert on MEMBER_MONTHLY_SPENDING; atomic increment of CurrentPoints | T-CONC-02 |
| Same branch-day summary row (if adopted) | Atomic increment under the row lock | T-CONC-03 |
| Settlement vs tier batch vs report readers | Fixed lock order; chunked batch; isolation per D-019 | T-CONC-04 |
| Settlement vs another sale of the same product | Inventory check-and-decrement in the same statement (UC04 owner) | T-CONC-05 |

**Proposed global lock order** (to be confirmed in the integration contract): INVOICE row → BRANCH_INVENTORY rows (ascending Product_ID) → INVOICE_SERVICE_ITEM rows → MEMBER_MONTHLY_SPENDING row → MEMBER row → revenue-summary row.

## 5. Baseline vs optimised evaluation

| Config | Description | Purpose |
|---|---|---|
| U0 / B0 | Baseline settlement (`usp_P3_SettleInvoice_Baseline`): recomputes window spend from INVOICE (Q-UC05-A) and re-ranks the tier synchronously; no extra index | Reproduces the Problem 4 design |
| U0 / IX-03 | Same, with the best candidate index for Q-UC05-A | A fair baseline: is the bottleneck solvable by an index alone? |
| U1 | Incremental settlement (§4.2) + daily batch (§4.6) | Proposed design |
| U1 + D-009(b) | U1 + immediate upgrade check | Cost of instant upgrades |

Metrics (per settlement, over K consecutive settlements on DS-M and DS-L): logical reads, CPU time, elapsed (median and p95), plus the tier-batch runtime for U1. Expected *hypothesis*, not a result: U0's cost grows with the member's invoice history and the data size, while U1's per-settlement cost stays roughly constant. Measurement procedure: [10](10_SEED_AND_BENCHMARK_PLAN.md); tests: T-PERF-01, T-PERF-02, T-PERF-08.

## 6. Business correctness tests

Defined in [11_TEST_AND_QA_PLAN.md](11_TEST_AND_QA_PLAN.md): T-F05-01…T-F05-17, T-CONC-01…T-CONC-05, T-REC-01, T-REC-02, T-REC-04, T-INT-01, T-INT-02.

## 7. Work orders

WO-P3-P3-00 (invoice creation), WO-P3-P3-01 (settlement), WO-P3-P3-02 (loyalty and tiers), WO-P3-P3-03 (concurrency, rollback, reconciliation, U0 vs U1 benchmark), in that order. Preconditions: GATE-P2 (schema and data); no integration contract (D-027).

## 8. Readiness for P3 implementation (Owner Directive 2026-11-08 §5)

Each item must be settled before the P3 work order that needs it is approved. "Defined" means specified in this plan or an approved decision; "open" means a decision is still `PROPOSED`.

| Item | Where it is defined | State | Needed before |
|---|---|---|---|
| Responsibility for invoice creation | §4.1; [D-028](03_DECISION_LOG.md#d-028--invoice-creation-billing-responsibility-interface-finalisation-creation-idempotency) Q1; scope 2026-11-07 (P3 owns INVOICE and both item tables) | Open (D-028) | WO-P3-P3-00 |
| Creation interface, finalisation, line prices, creation idempotency | D-028 Q2–Q6 | Open (D-028) | WO-P3-P3-00 |
| Settlement transitions | D-005 ✔; invariants S1–S5 (CHECKs, built) and T1–T5 ([WO-P3-P1-01 §3.4](work-orders/WO-P3-P1-01_PHYSICAL_SCHEMA.md#34-keys-foreign-keys-and-constraints)); §3 | Defined | WO-P3-P3-01 |
| Settlement idempotency | §4.3 (the PENDING→PAID transition is the single source of truth; repeat returns `ALREADY_SETTLED`); D-003 (A) ✔ | Defined | WO-P3-P3-01 |
| Settlement orchestration and hooks | D-012 (a), §4.2 step 4; hooks as contract-only test doubles until P6 (DEP-05) | Open (D-012; provisional T2 sufficient) | WO-P3-P3-01 |
| Transaction behaviour | §4.8; [12 §4](12_INTEGRATION_PLAN.md#4-transaction-composition-rules) (one owner, `XACT_ABORT ON`, no swallowed errors, retry only at the outermost level) | Defined | WO-P3-P3-00, WO-P3-P3-01 |
| Concurrency behaviour | §4.9 (update lock on the invoice, safe upsert, atomic increments, lock order); D-019 | Open (D-019; recommended (a)) | WO-P3-P3-01 |
| Points calculation | §4.5; D-006 | Open (D-006; also needed by P2) | WO-P3-P2-01, WO-P3-P3-01 |
| Tier rules: window, thresholds, timing | §4.6; D-007, D-008, D-009 | Open | WO-P3-P3-02 |
| Monthly spending | §4.4 (local month of `PaidAt`, safe upsert, TotalSpend and PointsEarned in one statement); D-013 ✔; the composite PK does not prevent duplicate settlement | Defined (points part needs D-006) | WO-P3-P3-01 |
| Refunds, reversals | D-011 ✔ (out of scope; cancellation of PENDING only) | Defined | — |
| Positive tests | T-F05-01, T-F05-05, T-F05-09…T-F05-15 | Defined ([11 §2.3](11_TEST_AND_QA_PLAN.md#23-uc05-functional-wo-p3-p3-01-wo-p3-p3-02)) | Per WO |
| Negative tests | T-F05-02…T-F05-04, T-F05-06…T-F05-08, T-F05-16, T-F05-18, T-F05-19, T-F05-22 | Defined | Per WO |
| Concurrency tests | T-CONC-01…T-CONC-04, T-CONC-06 (P3); T-CONC-05 (P6, real inventory routine) | Defined ([11 §2.5](11_TEST_AND_QA_PLAN.md#25-concurrency-wo-p3-p3-03)) | WO-P3-P3-00, WO-P3-P3-03 |
| External behaviour (inventory, entitlement) | Contract-only test doubles in P3 (T-F05-21, T-F05-22); T-INT-01/02 with the real routines at P6 | Defined | WO-P3-P3-01; WO-P3-P6-01 |

Not implemented by P3 at any stage: inventory, product catalogue management, service activation, PT sessions (other members' modules).

### 4.10 Implemented loyalty design (2026-11-09; WO-P3-P3-01 task 2, WO-P3-P3-02)

Approved basis: D-006 (b); D-007 (d) — twelve Asia/Ho_Chi_Minh calendar months (current month + 11 previous), half-open `[FromMonth, NextMonth)` on `SpendingMonth`, advancing on the 1st of each local month, not a rolling 365-day period; D-008 **rule** — Silver base tier at 0, `spend ≥ threshold`, highest eligible threshold, thresholds read from MEMBER_TIER, nothing hard-coded (**threshold values not approved**: TEST_ONLY synthetic values only); D-009 (a) — periodic batch, intended daily, no scheduler created, an upgrade may become visible only after the next run (accepted latency).

| Element | Implementation | Notes |
|---|---|---|
| Monthly spending and points | `usp_P3_SettleInvoice` (unchanged since WO-P3-P3-01) | One UPDLOCK+HOLDLOCK upsert per settlement; points = new floor − old floor, same statement; CurrentPoints atomic increment. V003 adds CHECK `PointsEarned = FLOOR(TotalSpend / 100000)` |
| Window | `dbo.tvf_P3_TierWindow(@AsOfDate)` | Local date → `FromMonth = first day of month − 11`, `NextMonth = first day of next month` |
| Tier rule | `dbo.tvf_P3_TierForSpend(@Spend)` | `TOP (1) … WHERE SpendingThreshold <= @Spend ORDER BY SpendingThreshold DESC` on MEMBER_TIER |
| Tier evaluation (F22) | `dbo.usp_P3_EvaluateTiers(@AsOfDate, @ChunkSize)` | Reads only MEMBER_MONTHLY_SPENDING (≤ 12 rows per member), MEMBER and MEMBER_TIER — never INVOICE; members without rows → spend 0 → Silver; updates only `Tier_ID` and only where different, in Member_ID chunks (≤ 4,500, own short transactions); refuses an open caller transaction and an invalid tier configuration; runs serialised by an application lock (a newer run can never be overwritten by an older snapshot); idempotent for the same date |
| Lookup (F21) | `dbo.usp_P3_GetMemberLoyalty(@Member_ID, @AsOfDate)` | Read-only: points, stored tier, window spend, evaluated tier, next tier and gap |
| Reference U0 | `db/reference/usp_P3_SettleInvoice_Baseline.sql` (REFERENCE_ONLY) | Calls the unchanged settlement, then recomputes the window from INVOICE and re-ranks synchronously — the Problem 4 design, kept only for the WO-P3-P3-03 benchmark |
| Month and year boundaries | `tvf_P3_SpendingMonth` (UTC + 7 h) for spending months; local evaluation dates for windows | 2025-12-31 16:59:59.999 UTC → December, 17:00:00.000 UTC → January; the window crosses the year without any reset |
| Downgrades without payment | The batch evaluates every member on each run; on the 1st of a month the oldest month leaves the window | Proven by T-F05-13 (fixtures) and by the DS-L run as of 2026-01-15 |
| Concurrency | Settlement writes spending then `CurrentPoints`; the batch writes only `Tier_ID` after a lock-free read; no lock cycle; no lost column | T-CONC-04F (settlement concurrent with the batch), T-CONC-02 |

Shared-table boundary: MEMBER and MEMBER_TIER stay other members' tables. In isolated databases they are TEST_ONLY fixtures (F002P, F002T); P3 writes only `MEMBER.CurrentPoints` (settlement) and `MEMBER.Tier_ID` (batch, U0) — DEP-02 — and reads MEMBER_TIER (DEP-03).
