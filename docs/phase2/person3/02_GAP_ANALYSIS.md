# 02 — Gap Analysis (Person 3)

| Field | Value |
|---|---|
| Document status | DRAFT — WO-P3-BOOT-001; blocking levels updated 2026-11-07 (Owner Directive WO-P3-P0-FINAL) |
| Date | 2026-11-07 |
| Rule | No gap is resolved here. Each gap names the decision (D-xxx in [03_DECISION_LOG.md](03_DECISION_LOG.md)) or information request that closes it. |

Blocking levels:

- **B1**: blocks P1 (physical schema).
- **B2**: blocks P2 (seed data with derived loyalty values, and the baseline revenue oracle).
- **B3**: blocks P3 (UC05 build).
- **B4**: blocks P4 (UC06 build).
- **B6**: blocks P6 (application).
- **NB**: does not block a phase, but must be resolved before the final report.

## Summary

| ID | Gap | Blocking | Closed by |
|---|---|---|---|
| G-01 | Seven Phase 1 UCs vs six proposed UCs; P3 boundaries | B4 (was B1; P3 scope confirmed by the Owner 2026-11-07) | D-001 |
| G-02 | Payment-confirmation semantics | CLOSED (provisional, 2026-11-07; team ratification pending) | D-003, D-005 |
| G-03 | `PaidAt` absent from final schema | CLOSED (provisional, 2026-11-07) | D-004 |
| G-04 | Whether a dedicated payment table is needed | CLOSED (provisional, 2026-11-07: no PAYMENT table) | D-003 |
| G-05 | Point calculation base and rounding | B2 | D-006 |
| G-06 | Tier window: calendar year vs rolling 12 months | B2 | D-007 |
| G-07 | Tier thresholds, base tier, boundary comparison | B2 | D-008 |
| G-08 | When tiers are evaluated (synchronous vs batch) | B3 | D-009 |
| G-09 | Refunds and cancellations | CLOSED (provisional, 2026-11-07: cancel PENDING only, no refunds) | D-011, D-005 |
| G-10 | Duplicate settlement and duplicate invoice-creation requests | B3 (settlement guard designed in UC05); creation retries at integration (D-003 option C not approved) | D-003 |
| G-11 | Definition of recognised revenue | RESOLVED for isolated P3 work (2026-11-10); team confirmation at P6 | D-010 APPROVED provisional T2 |
| G-12 | Relationship of settlement with inventory and service entitlements | B3 (was B1) | D-012 |
| G-13 | Invoice creation ownership and header-total consistency | B3 (D-023 approved provisionally 2026-11-07; ownership open in D-012) | D-012, D-023 |
| G-14 | Discount allocation for per-plan/per-product revenue | CLOSED (provisional, 2026-11-07) | D-023 |
| G-15 | Physical data types, key types, time zone | CLOSED (provisional, 2026-11-07: UTC storage, Asia/Ho_Chi_Minh reporting) | D-014 |
| G-16 | `SpendingMonth` representation, including which calendar defines the month | CLOSED (2026-11-07) | D-013 |
| G-17 | No numeric response-time targets for P3 | NB | D-022 |
| G-18 | Point redemption and expiry | CLOSED (2026-11-07: excluded from scope) | D-024 |
| G-19 | Missing shared artifacts (repo, other members' code, six-UC document, team tracking tool) | Repository resolved (D-021 Part A); missing shared schema handled for isolated tests by TEST_ONLY fixtures (D-026, restricted); team schema needed before integration (B6); six-UC document and tool open | D-021, D-026, D-001 |
| G-20 | DBMS version/edition consistency and edition feature limits | B1 until the P1 preflight verifies the engine (D-002 approved provisionally 2026-11-07); edition feature limits B2 (WO-P3-P0-02) | D-002 |
| G-21 | Application stack undecided | B6 | D-020 |
| G-22 | Phase 2 deadline and report format unknown | NB (blocks scheduling) | Information from Project Owner |
| G-23 | Team-wide isolation/concurrency settings | B3 | D-019 |
| G-24 | Database topology for P3 tests/benchmarks vs master prompt §11 | CLOSED | D-025 (APPROVED 2026-11-06) |

## Details

### G-01 — Use-case catalogue and P3 boundaries

- **Evidence:** S-02 §7.1 defines UC01–UC07. S-11 says a newer team assignment proposes six UCs, with UC05 = settlement, spending aggregation, points, tiers and UC06 = revenue by month, branch and system. S-10 (the six-UC document) is MISSING. F06 appears in UC01, UC04 and UC05. Phase 1 UC06 includes F29 (occupancy; CHECK_IN) and F30 (best sellers).
- **Missing:** the full six-UC list, the owner of each UC, where F05/F06/F07/F19/F29/F30 belong, and who owns the suggested reports in RQ-A16–RQ-A18.
- **Impact:** without it, P3 may duplicate or miss shared work, the report may describe a different UC catalogue than the code, and the RQ-A08 numbering cannot be finalised.
- **Analysis:** [00_SOURCE_AND_SCOPE.md §5](00_SOURCE_AND_SCOPE.md#5-use-case-reconciliation-seven-phase-1-vs-six-team-proposal).
- **Update 2026-11-07:** the Owner confirmed P3 = UC05 + UC06 (directive WO-P3-P0-FINAL §6.1). That fixes P3's tables, so this gap no longer blocks P1; it blocks the UC06 candidate reports (B4) and the group report.

### G-02 — Payment-confirmation semantics

- **Evidence:** S-02 §2.2 step 3 says staff create an INVOICE recording issue time, totals, method and status. Step 5 says entitlements take effect "when the invoice is confirmed as validly paid". F05 (create, 900/d) and F06 (confirm payment, 900/d, R/W INVOICE) are separate functions. S-01 p2 lists cash, VNPay and card.
- **Missing:** whether creation and payment are two separate steps (pending, then paid, e.g. for an asynchronous VNPay callback) or one counter transaction. The `PaymentStatus` domain and allowed transitions. Whether `PaymentMethod` is known at creation or at payment.
- **Impact:** decides the state machine, the exactly-once mechanism, the filtered-index predicates and the seed status mix.

### G-03 — `PaidAt` absent from the final schema

- **Evidence:** S-06 (2026-10-31) and S-04 (2026-11-05 19:52) had `INVOICE.PaidAt`. The 20:27 draft and the final S-02 §10 do not. No reason is recorded. S-09 assumes `PaidAt` throughout.
- **Missing:** why it was removed, and which timestamp defines the spending month and the revenue date.
- **Impact:** without `PaidAt`, revenue and spending must be dated by `IssuedAt`, so an invoice issued on the 31st and paid on the 1st falls into the wrong month. It also changes every candidate index (IX-01…IX-03) and the partition key.
- **Constraint:** adding a column to the shared INVOICE table is a schema change outside the approved Phase 1 baseline, so it needs a `TEAM_DECISION`.

### G-04 — Dedicated payment table

- **Evidence:** No PAYMENT entity exists in the FitLife model. The PAYMENT entities in S-05 belong to the GrabFood page. S-09 recommends PAYMENT only if retries, refunds, external references or audit are needed.
- **Missing:** whether multiple payment attempts, split payments, provider transaction references or refunds are in scope.
- **Impact:** a PAYMENT table changes the settlement procedure, the revenue source table and the indexes.

### G-05 — Point calculation and rounding

- **Evidence:** S-01 p2 says "1 point = 100,000 VND". S-02 §2.6 step 3 says the same.
- **Missing:** which amount is the base (FinalAmount after discount, or GrossAmount); whether points are rounded per invoice, per month cumulatively, or over the window; what happens to the remainder; and how points are reversed on refund.
- **Impact:** decides `PointsEarned` semantics, the reconciliation invariant (T-REC-02) and the boundary tests (T-F05-09).

### G-06 — Tier evaluation window

- **Evidence:** S-01 p2 says "based on total spending **in the year**". S-01 p3 problem 4 describes the current system summing "**the last 12 months**". It describes the slow behaviour; it does not set the rule. S-02 §2.6 step 4 says "per tier-evaluation period" without defining the period. S-03 (unadopted) proposed "current month + 11 previous months".
- **Missing:** calendar year (resetting each January), calendar year based on the previous year, rolling 12 complete months, or rolling current + 11 months.
- **Impact:** decides the evaluation query, the boundary tests (T-F05-13) and seed history length. A calendar-year rule causes a mass re-evaluation every 1 January.

### G-07 — Tier thresholds, base tier and boundaries

- **Evidence:** S-02 §10 has `MEMBER_TIER(Tier_ID, Tier_Name, SpendingThreshold)`. BR04 says every member is in exactly one tier at a time. S-01 names exactly three tiers. Problem 4 says tiers can go up or down.
- **Missing:** numeric thresholds; whether Silver is the base tier with threshold 0 (needed so new members satisfy BR04); whether qualification uses ≥ or >; whether downgrades happen immediately or at a period boundary.
- **Impact:** test data, tier-distribution realism, and the T-F05-12 boundary cases.

### G-08 — Tier evaluation timing

- **Evidence:** S-02 §2.6 step 4 says tiers are evaluated periodically, and F22 says one batch per day. S-01 problem 4 says synchronous recomputation at payment is the bottleneck.
- **Missing:** whether the business expects an immediate upgrade after a large purchase.
- **Impact:** a synchronous upgrade check adds a bounded read to the settlement path and must be measured (T-PERF-02).

### G-09 — Refunds and cancellations

- **Evidence:** No source defines refunds, cancellations, voids or chargebacks.
- **Missing:** whether pending invoices can be cancelled, whether paid invoices can be refunded, and how revenue, points and spending are reversed (in the original month or the refund month).
- **Impact:** state machine, revenue definition (G-11) and tests T-F05-16/17.

### G-10 — Duplicate settlement and duplicate invoice creation

- **Evidence:** S-02 UC05 requires "no duplicate points". No mechanism is specified. S-09 suggests idempotency keys.
- **Missing:** whether the client can retry *invoice creation* (which would create a second invoice) or only *payment confirmation* on an existing invoice.
- **Impact:** a conditional state transition protects repeated confirmation of the same invoice. A client request key is needed only if creation can be retried.

### G-11 — Definition of recognised revenue

**Resolved for isolated P3 development (2026-11-10):** D-010 approved provisionally by the Owner; nine recorded rules define PAID-only FinalAmount revenue by PaidAt, UTC storage/local reporting and issuing branch. P4-01 Part F VERIFIED. The original gap analysis below is historical; team reconciliation remains P6.

- **Evidence:** "Doanh thu" (revenue) is used in S-01 and S-02 without a definition. F27/F28 read INVOICE and BRANCH.
- **Missing:** FinalAmount or GrossAmount; only paid invoices or all invoices; date by `PaidAt` or `IssuedAt`; whether service-plan revenue is recognised at sale or spread over the plan's validity; treatment of refunds; branch attribution (issuing branch vs branch where the service is used).
- **Impact:** every UC06 query, every summary design and the reconciliation oracle.

### G-12 — Settlement vs inventory and entitlements

- **Evidence:** S-02 §7.2 says payment must be consistent with entitlement recording, inventory adjustment, points and spending. §2.2 step 5 activates entitlements on confirmation. §2.5 step 5 decrements inventory after confirmation, never below zero. F07 (180/d) and F19 (720/d) belong to UC01 and UC04.
- **Missing:** who orchestrates the single transaction, the lock order across modules, the error contract, and whether insufficient stock aborts the whole settlement.
- **Impact:** without this, the system can end up with partial effects (paid but stock not decremented, or points without entitlement), cross-module deadlocks, or duplicated logic.

### G-13 — Invoice creation ownership and header totals

- **Evidence:** INVOICE has GrossAmount, DiscountAmount and FinalAmount. Each line has UnitPrice and DiscountAmount (§10). S-03 (unadopted) defined FinalAmount = Gross − Discount ≥ 0. BR07 requires a member on every invoice.
- **Missing:** whether header DiscountAmount equals the sum of line discounts or adds an invoice-level discount; who computes the totals and when; whether walk-in (non-member) retail sales exist (BR07 implies they do not).
- **Impact:** CHECK constraints, revenue correctness and the seed generator.

### G-14 — Discount allocation for line-level revenue

- **Evidence:** RQ-A16 (top plan by revenue) and F30 (best sellers) need revenue per line, but header-level discounts are not allocated to lines.
- **Impact:** a per-plan revenue total may not add up to invoice revenue. The approved rule must be stated in the report.

### G-15 — Physical data types, key types, time zone

- **Evidence:** S-02 has no physical types. S-09 suggests bigint keys, `datetime2` and decimal amounts.
- **Missing:** a team-wide type standard for keys (INT vs BIGINT), money (DECIMAL precision/scale, VND has no minor unit) and timestamps (`datetime2` precision; local time vs UTC; Vietnam is UTC+7 with no daylight saving).
- **Impact:** FK compatibility across members, index width, boundary tests.

### G-16 — `SpendingMonth` representation

- **Evidence:** PK (Member_ID, SpendingMonth). S-03 (unadopted) suggested "first day of month".
- **Missing:** DATE first-of-month vs INT yyyymm vs CHAR(7).
- **Impact:** window queries and BR06 uniqueness. Any non-normalised date would allow two rows for the same month.

### G-17 — No numeric response-time targets for P3

- **Evidence:** S-02 §7.2 says "in an appropriate time". S-01 problem 3 describes the current symptom (more than 1 minute) but no target. The only numeric target (<50 ms) is for check-in, outside P3.
- **Impact:** acceptance must be **relative and evidence-based** (baseline vs optimised on the same data) unless the team sets absolute targets.

### G-18 — Point redemption and expiry

- **Evidence:** `MEMBER.CurrentPoints` is "current points", which implies a spendable balance. No source describes redemption or expiry.
- **Impact:** if redemption exists, CurrentPoints can no longer be reconciled as Σ PointsEarned and a ledger becomes necessary.

### G-19 — Missing shared artifacts

- **Evidence:** the repository is empty and not under version control (S-12). No code from other members (S-13). The six-UC document is missing (S-10). RQ-A20 requires a team tracking tool, which is unknown.
- **Impact:** no conventions to follow; risk of incompatible schemas; no shared seed; no change history.
- **Update 2026-11-07:** the canonical repository is `Phuoc-IT-2106/CSDLNC-DA` (public, one commit, README only); a read-only clone exists at `C:\Users\DELL\source\repos\CSDLNC-DA`. Still missing: other members' code and schema (handled for P1 by D-026), the six-UC document (D-001) and the tracking tool (RQ-A20).

### G-20 — DBMS version, edition and feature limits

- **Evidence:** S-14 shows two local SQL Server 2025 instances (17.0.1000.7) in "Standard Developer Edition". The course material uses SQL Server (S-07, S-08).
- **Missing:** which instance and compatibility level the team uses; whether all members run the same version; which features the edition allows. Examples to verify in WO-P3-P0-02: online index operations, and automatic matching of indexed views without the NOEXPAND hint, are commonly Enterprise-only. Partitioning and filtered indexes are expected to be available. **All of these are UNVERIFIED until tested.**
- **Impact:** some optimisation options may be unavailable or behave differently from the documentation examples.

### G-21 — Application stack

- **Evidence:** S-01 allows web or winform. Locally available: .NET SDK and Node.js. Nothing has been chosen.
- **Impact:** blocks P6 and the RQ-A03/RQ-A09 evidence.

### G-22 — Deadline and report format

- **Evidence:** S-01 says 10 weeks and submission via Moodle. No Phase 2 due date or report template was found.
- **Impact:** the roadmap ([15](15_ROADMAP_AND_WORK_ORDERS.md)) is sequenced but not dated.

### G-23 — Isolation and concurrency settings

- **Evidence:** S-02 §5.3 says payment and point accrual must be atomic under concurrency. Database options such as READ_COMMITTED_SNAPSHOT apply to the whole shared database.
- **Missing:** a team decision on the isolation strategy.
- **Impact:** blocking between reports and settlements, the deadlock profile, and tempdb version-store usage.

### G-24 — Database topology for P3 tests and benchmarks

- **Evidence:** master prompt v2.0 §11 forbids a separate database "merely for Person 3". The bootstrap work orders named dedicated P3 test/benchmark databases as targets.
- **Missing:** a team decision on whether disposable test/benchmark copies of the team schema are acceptable, and where they live.
- **Impact:** every build and verification WO needs a declared target database (approval rule 4). Without this decision, P1 cannot name one.
- **Status:** CLOSED. D-025 was APPROVED with seven conditions by the Project Owner on 2026-11-06.
