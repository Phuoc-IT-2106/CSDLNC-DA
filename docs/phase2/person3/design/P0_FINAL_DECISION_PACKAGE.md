# P0 Final Decision Package — Person 3 (for Project Owner and team approval)

| Field | Value |
|---|---|
| Authority | Owner Directive **WO-P3-P0-FINAL** (v1 of this package) and Owner Directive **"Final P0 Decision Resolution"** (v2), both in Claude Code sessions of 2026-11-07; mode `PLAN_ONLY` |
| Version | **v3, 2026-11-07.** v1 recommended the decisions; v2 recorded B0–B3 and D-024; **v3** records the Owner Directive "Strict Person 3 Scope Enforcement": D-013 and D-021 Part A approved, D-026 approved with a **restricted scope** (four P3-owned tables; TEST_ONLY key fixtures for shared dependencies), and the Owner's ownership matrix. |
| State | BOOTSTRAP `PASSED` · WO-P3-P0-01 `PASSED` · WO-P3-P0-03 `PASSED` (GATE-P0 closed 2026-11-07) · 13 decisions approved (8 provisionally under T2) · **WO-P3-P1-01 `VERIFIED`** (executed 2026-11-07; awaiting GATE-P1) · P1 schema IMPLEMENTED in the isolated test database |
| Supersedes | [P0_DECISION_REVIEW.md](P0_DECISION_REVIEW.md) §3–§7 for decision classification and P1 readiness. That review stays as the historical WO-P3-P0-01 deliverable. |
| Authoritative for approval states | [03_DECISION_LOG.md](../03_DECISION_LOG.md). This package summarises and recommends; the log holds each approved text, approver, date and reference. |

## 0. Summary

**P1 was approved and executed on 2026-11-07** (WO-P3-P1-01 `VERIFIED`; evidence in its §13). Earlier text of this package describes the decision state before execution. P1 built only the four Person 3-owned tables; shared tables are dependencies, represented in isolated tests by key-only TEST_ONLY fixtures.

| Status on 2026-11-07 | Decisions |
|---|---|
| APPROVED | D-013, D-021 (Part A), D-024 (scope restriction), D-025 (topology, with constraints), D-026 (restricted scope) |
| APPROVED (provisional, T2) | D-002 (also conditional on the P1 preflight), D-003, D-004, D-005, D-011, D-014, D-018, D-023 |
| PROPOSED — blocks P1 | none |
| PROPOSED — blocks UC05 | D-006, D-007, D-008, D-009, D-012, D-019, D-022 |
| PROPOSED — blocks UC06 | D-001, D-010 |
| PROPOSED — blocks integration | D-020, D-021 (Part B) |
| DEFERRED (decided by measured evidence) | D-015, D-016, D-017 |

What changed with the Owner's answers:

1. **Timestamps are stored in UTC** (D-014), with Asia/Ho_Chi_Minh as the reporting time zone. This replaces the earlier local-time recommendation. Consequences: `SYSUTCDATETIME()` defaults; spending months and report periods are defined on the local calendar and converted to UTC bounds; monthly partition boundaries (if ever used) must be UTC instants of local month starts.
2. **Approval rule 3 now has the T2 exception**, identical in [master prompt A1](../../../agent/P3_MASTER_PROMPT.md#a1-approval-gates) and [15 §1](../15_ROADMAP_AND_WORK_ORDERS.md#1-approval-rules).
3. **D-021 was split** into Part A (P3's working arrangement; Owner; blocks P1) and Part B (shared repository conventions and visibility; team and repository owner; blocks the first push).
4. **D-013 gained a time-zone clause**: the month is the Asia/Ho_Chi_Minh calendar month of `PaidAt`.
5. **D-026** is approved with a **restricted scope** (v3): production DDL only for INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM and MEMBER_MONTHLY_SPENDING; key-only TEST_ONLY fixtures for MEMBER, BRANCH, EMPLOYEE, SERVICE_PLAN and PRODUCT only while the team schema is unavailable. The v2 idea of a P3-written 10-table shared baseline is withdrawn.

## A. Already resolved

| Item | State | Evidence |
|---|---|---|
| WO-P3-BOOT-001 | `PASSED` 2026-11-06 | [WO file](../work-orders/WO-P3-BOOT-001_PLANNING_BOOTSTRAP.md) |
| WO-P3-P0-01 | `PASSED` 2026-11-07 | Directive WO-P3-P0-FINAL §4 (conditional; conditions verified) |
| D-025 database topology | `APPROVED` 2026-11-06 | [03 D-025](../03_DECISION_LOG.md#d-025--database-topology-for-p3-development-testing-and-benchmarking) |
| Canonical repository | Identified 2026-11-07 | `Phuoc-IT-2106/CSDLNC-DA` (Section E) |
| Person 3 scope | UC05 (payment settlement and loyalty) and UC06 (revenue reporting) | Directive WO-P3-P0-FINAL §6.1 |
| **B0 — team-approval timing** | **Option T2 approved with restrictions** (2026-11-07) | Approval rule 3 amended: Owner may approve team-level decisions provisionally for isolated local work under an approved BUILD_AUTHORIZED WO; derive from the approved Phase 1 logical schema; experimental schemas are not the team schema; team review before integration or merge; no shared-database change, push or merge authorized |
| **B1** — D-002, D-014, D-018 | APPROVED (provisional, T2) | SQL Server; compatibility level 160 if supported by the verified engine; INT identifiers; DECIMAL(18,2); DATETIME2(3) **UTC**; reporting time zone Asia/Ho_Chi_Minh; clustered PK on Invoice_ID; Phase 1 naming. Preflight required before any migration (WO-P3-P1-01 step 1). |
| **B2** — D-003, D-004, D-005, D-011 | APPROVED (provisional, T2) | Status on INVOICE; no PAYMENT table; `PaidAt`; PENDING/PAID/CANCELLED; CASH/VNPAY/CARD; cancel only before settlement; no refunds; no re-settlement. Invariants S1–S5 and T1–T5 in [WO-P3-P1-01 §3.4](../work-orders/WO-P3-P1-01_PHYSICAL_SCHEMA.md#34-keys-foreign-keys-and-constraints). `PaymentMethod` is nullable before settlement. |
| **B3** — D-023 | APPROVED (provisional, T2) | Row-level monetary CHECKs; header = Σ items is a cross-table invariant, enforced in the finalisation transaction and verified by query V-TOT (not by a CHECK) |
| **D-024** redemption scope | APPROVED (scope restriction) | Redemption, expiry and redemption-specific tables are excluded. Consistent with S-01 (2026-11-06 audit), S-02 (text search 2026-11-07) and S-11. Reopened if S-10 or a re-read of S-01 shows such a requirement. |
| **Ownership matrix** (v3) | Fixed by the Owner 2026-11-07 | P3_OWNED: INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM, MEMBER_MONTHLY_SPENDING. SHARED_DEPENDENCY: MEMBER, MEMBER_TIER, BRANCH, EMPLOYEE, SERVICE_PLAN, PRODUCT. OUT_OF_SCOPE: the other 15 Phase 1 tables and the excluded workflows. [WO-P3-P1-01 §3.2](../work-orders/WO-P3-P1-01_PHYSICAL_SCHEMA.md#32-scope-matrix-directive-strict-person-3-scope-enforcement) |
| **D-013** | APPROVED (v3) | DATE; first day of the Asia/Ho_Chi_Minh month of the successful payment; first-day invariant enforced by CHECK |
| **D-021 Part A** | APPROVED (v3) | One authoritative working copy after a controlled cut-over; planning workspace kept as an **immutable** archive (no marker file); clone = working repository; `p3/<work-order-id>` branches; no commit, push or merge; no sensitive source documents or secrets to a public repository without review |
| **D-026** | APPROVED, restricted scope (v3) | Ten conditions in [03 D-026](../03_DECISION_LOG.md#d-026--shared-dependencies-for-isolated-p1-development-restricted); does not authorize building other members' tables or modules |

The exact approved texts, approvers, dates and references are in each entry of [03_DECISION_LOG.md](../03_DECISION_LOG.md).

## B. Recommended for immediate approval

Status after the Owner directive of 2026-11-07: **B0–B3 approved; B4 and B5 open.**

### B0. Team-approval timing (choose one)

**Outcome: T2 approved with restrictions** (see Section A). Applied as the exception in approval rule 3. WO-P3-P0-03 run 1 recorded it.

### B1. Physical standard: D-002, D-014, D-018

**Outcome: APPROVED (provisional, T2), with UTC storage and a preflight condition.** The approved text differs from the v1 recommendation in one point: timestamps are stored in UTC, not local time. Before any migration, WO-P3-P1-01 step 1 must verify the version and edition, verify that compatibility level 160 is supported, record the environment, and confirm conformance with the logical model. If the environment is incompatible, the WO stops and reports instead of changing the design. Text, date, time and small-integer types and `IDENTITY` are physical refinements in the WO's deviation register (DV-03, DV-04); they are approved with the WO and reviewed by the team.

### B2. Payment state on INVOICE: D-003, D-004, D-005, D-011 (directive §6.2)

**Outcome: APPROVED (provisional, T2).** The physical specification now states every invariant:

- Row-level invariants S1–S5 are CHECK, NOT NULL and DEFAULT constraints in P1.
- Transition invariants T1–T5 need the old value or other tables, so the UC05 routines enforce them (WO-P3-P3-01).
- `PaymentMethod` is **nullable before settlement** and NOT NULL when PAID.
- Check-in and entitlement compatibility is preserved: only `PAID` counts as paid.
- No settlement procedure is part of P1.

### B3. Invoice totals: D-023

**Outcome: APPROVED (provisional, T2).**

- The header rules (`GrossAmount ≥ 0`, `0 ≤ DiscountAmount ≤ GrossAmount`, `FinalAmount = GrossAmount − DiscountAmount`, `FinalAmount ≥ 0`) are CHECK constraints.
- The line rules (`UnitPrice ≥ 0`, `0 ≤ DiscountAmount ≤` line gross, `Quantity > 0`) are CHECK constraints too.
- Header = Σ lines and BR12 are **cross-table invariants**. A normal CHECK cannot enforce them, and a CHECK calling a function is rejected because it fires only when the header row changes. They are enforced in the invoice-finalisation and settlement transactions.
- P1 keeps them verifiable through the validation query V-TOT. Test P06 proves the limitation.

### B4. P3 structure and workspace: D-013, D-021, D-026

**Outcome (v3, 2026-11-07): D-013 and D-021 Part A APPROVED; D-026 APPROVED with a restricted scope** (see Section A). The reconciliation below is kept as the record of v2. Differences from it: the archive marker file is dropped (the archive must be immutable), and D-026's content is no longer the 10-table translation but the four P3 tables plus key-only TEST_ONLY fixtures.

| ID | Original question and alternatives | What the reconciliation found | Content proposed for approval | Approver | Blocks |
|---|---|---|---|---|---|
| D-013 | Month-key format of MEMBER_MONTHLY_SPENDING. (a) DATE first of month + CHECK `DAY() = 1`; (b) INT yyyymm; (c) CHAR(7). Recommended (a). | The wording never said which calendar defines the month. With UTC storage, payments between 00:00 and 06:59 local time on the 1st would land in the previous month under the UTC calendar. | (a), plus: SpendingMonth = first day of the **Asia/Ho_Chi_Minh** calendar month containing `PaidAt` | Project Owner (P3-owned table) | P1 (type and CHECK) |
| D-021 Part A | Repository, layout and workflow. (a) init Git here; (b) clone the team repository and *move* the docs; (c) no VCS. | (a) is superseded (the team repository exists). "Move" conflicts with preserving the original workspace, so it becomes "copy". The approver was inconsistent ("Yes" vs. "Owner approves P3's arrangement"), so the decision is split. | `C:\CSDLNC- DA` authoritative until the cut-over; cut-over in WO-P3-P1-01 step 0 copies the docs unchanged into the clone on `p3/wo-p3-p1-01` and adds the marker `ARCHIVED_SEE_REPOSITORY.md` to the old root; afterwards only the clone is edited (exactly one editable master prompt and decision log at any time); branches `p3/<wo-id>`; P3 files in the proposed layout on its local branch; commits, pushes, PRs and visibility changes only with explicit authorization | Project Owner | P1 |
| D-021 Part B | (same decision) | Shared conventions affect every member | Layout `docs/agent/`, `docs/phase2/person3/`, `db/migrations/`, `db/build/`, `tests/db/`; `.gitignore`, `.gitattributes` and file-safety rules (§E.3–§E.4); review by another member before merge; repository visibility (recommended: private) | Team and repository owner | First push (not P1) |
| D-026 | How P1 gets a shared baseline when no team DDL exists. (a) wait; (b) faithful §10 translation of the dependency closure; (c) stub parents; (d) whole §10. | The Owner authorized **planning** under 7 conditions. (b) meets conditions 1–5 and 7. Condition 6 (record all deviations) needed a deviation register, now WO-P3-P1-01 §3.7. Condition 2 needed a per-table justification, now §3.2. | Implementation contract = WO-P3-P1-01 §3.2–§3.7 (10 tables, columns, constraints, deviation register), isolated use only | Project Owner for isolated use; team review before integration | P1 |

Approval statements (one each):

> "D-013 APPROVED: SpendingMonth is DATE, the first day of the Asia/Ho_Chi_Minh calendar month that contains PaidAt, enforced by CHECK (DAY(SpendingMonth) = 1). — Project Owner, <date>"

> "D-021 Part A APPROVED as reconciled in P0_FINAL_DECISION_PACKAGE v2 §B4 (authoritative copy, single cut-over with archive marker, p3/<wo-id> branches, proposed layout on the local branch, no commit/push/PR/visibility change without explicit authorization). Part B stays open for the team. — Project Owner, <date>"

> "D-026 APPROVED for isolated development: the implementation contract is WO-P3-P1-01 §3.2–§3.7 as of <date>, under the seven conditions of 2026-11-07; team review before any integration or merge. — Project Owner, <date>"

### B5. Work order

B4 is approved and recorded (WO-P3-P0-03 run 2), so WO-P3-P1-01 is READY_FOR_APPROVAL. The current approval statement, including the GATE-P0 pass, is in [WO-P3-P1-01 §11](../work-orders/WO-P3-P1-01_PHYSICAL_SCHEMA.md#11-approval-requirements); the v2 statement below is superseded:

> "WO-P3-P1-01 APPROVED, mode BUILD_AUTHORIZED. Target database `FitLife_P3_P1` on instance <MSSQLSERVER>. Authorized: the SQL Server preflight (read-only queries); create, rebuild and drop that database; copy the planning documents into the clone and work on branch `p3/wo-p3-p1-01`; create the archive marker in `C:\CSDLNC- DA`. Local commits: <authorized / not authorized>. Push, PR, merge and visibility changes: not authorized. — Project Owner, <date>"

Specification: [WO-P3-P1-01 — Physical Schema Foundation](../work-orders/WO-P3-P1-01_PHYSICAL_SCHEMA.md).

## C. Future decisions

None of these changes the P1 tables. Each must be approved before the phase shown.

| ID | Class | Needed before | Recommended (short) | Approver | Consequence of deferral |
|---|---|---|---|---|---|
| D-006 Point formula and rounding | BLOCKING_UC05 | P2 seed, WO-P3-P3-01 | Monthly cumulative floor, incremental (C.2) | Project Owner | Points cannot be seeded or settled |
| D-007 Tier window | BLOCKING_UC05 | P2 seed, WO-P3-P3-02 | Twelve calendar months including the current month (C.3) | Project Owner | Tiers cannot be derived |
| D-008 Thresholds, base tier, boundary | BLOCKING_UC05 | P2 seed, WO-P3-P3-02 | Base tier threshold 0; `≥`; **values from the Owner** | Project Owner | No tier data |
| D-009 Tier evaluation timing | BLOCKING_UC05 | WO-P3-P3-02 | Daily batch (F22); immediate-upgrade check only as a measured variant | Project Owner | Batch design open |
| D-012 Settlement boundary and ownership | BLOCKING_UC05 | WO-P3-P1-02, WO-P3-P3-01 | One transaction, one orchestrator, fixed lock order | Team | Settlement cannot be built |
| D-019 Isolation and concurrency | BLOCKING_UC05 | WO-P3-P3-01 | READ COMMITTED + conditional updates and update locks | Team | Concurrency design open |
| D-022 Dataset tiers, seed tool, thresholds | BLOCKING_UC05 (also UC06) | WO-P3-P2-01 | DS-S/M/L, deterministic T-SQL, thresholds of [08 §6](../08_INDEX_AND_QUERY_PLAN.md#6-adoption-and-rejection-criteria) | Project Owner | No seed |
| D-001 Use-case catalogue | BLOCKING_UC06 | WO-P3-P4-01; group report | Six-UC catalogue with owners (C.1) | Team | Candidate reports unowned |
| D-010 Recognised revenue | BLOCKING_UC06 | P2 oracle, WO-P3-P4-01 | C.5 | Team | UC06 results undefined |
| D-020 Application stack | BLOCKING_INTEGRATION | WO-P3-P6-01 | Team choice | Team | P6 late |
| D-021 Part B | BLOCKING_INTEGRATION | First push | §B4, §E | Team and repository owner | No push possible |
| D-015, D-016, D-017 | DEFERRED | WO-P3-P4-02, WO-P3-P5-01 | Decide on measured evidence | Team if adopted | None now |

### C.1 Use-case mapping (directive §6.1)

The Phase 1 → Phase 2 mapping table is in [00 §5](../00_SOURCE_AND_SCOPE.md#5-use-case-reconciliation-seven-phase-1-vs-six-team-proposal). P3's UC05 and UC06 keep the same numbers. F29 (occupancy), F30 (best sellers), RQ-A16–A18, the settlement orchestrator and the project-level partition demonstration need named owners in the six-UC catalogue.

### C.2 Loyalty calculation (directive §6.3)

**Not approved.** Decide before UC05 loyalty behaviour. This does not block P1.

Common ground for every option:

- The eligible amount is `INVOICE.FinalAmount` of the whole invoice at its PENDING→PAID transition (S-02 §2.6 step 1).
- The rate is 1 point per 100,000 VND (S-01 p2), always rounded down.
- `PointsEarned` (per member-month) is what was earned; `MEMBER.CurrentPoints` is the balance, which equals Σ earned because redemption is excluded (D-024).
- Only PENDING→PAID credits points; cancellation applies only to PENDING invoices, so nothing is ever reversed.
- The month is the Asia/Ho_Chi_Minh calendar month of `PaidAt` (D-013, approved).

**The three options:**

| | (a) Per invoice | (b) Monthly cumulative | (e) Cumulative across all months |
|---|---|---|---|
| Rule | `points = FLOOR(FinalAmount / 100000)` per invoice | `PointsEarned(month) = FLOOR(TotalSpend(month) / 100000)` | `CurrentPoints = FLOOR(Σ all eligible spending / 100000)` |
| Maximum loss to rounding | 99,999 VND per invoice | 99,999 VND per member-month | 99,999 VND per member, ever |
| Cost in the payment path | Constant | Constant: the same single-row update that adds to TotalSpend | Needs the member's lifetime spend: read all of the member's monthly rows (grows with membership age), or add a lifetime-spend column to MEMBER (a shared-table change needing team review) |
| Row-level check possible | No | **Yes**: CHECK `PointsEarned = FLOOR(TotalSpend / 100000)` | No (`PointsEarned` = credits made in that month) |
| Reconciliation | Needs every invoice | Row CHECK + Σ rows = CurrentPoints | CurrentPoints = FLOOR(Σ TotalSpend / 100000) |
| Schema impact | None | None (optional CHECK) | None, or one new MEMBER column |

**Worked examples** (local times; amounts in VND):

| Case | (a) | (b) | (e) |
|---|---|---|---|
| 60,000 on Jan 10 and 60,000 on Jan 20 (same month) | 0 + 0 = **0** | Jan total 120,000 → **1** | **1** |
| 60,000 on **Jan 31 23:00** and 60,000 on **Feb 1 09:00** (across the month boundary) | **0** | Jan 60,000 → 0, Feb 60,000 → 0 = **0** | Lifetime 120,000 → **1** (credited on Feb 1) |
| 150,000 in Jan and 150,000 in Feb | 1 + 1 = **2** | 1 + 1 = **2** | 300,000 → **3** (1 in Jan, +2 in Feb) |
| One invoice of 250,000 | **2** | **2** | **2** |
| `PaidAt` = 2026-01-31 17:30 UTC (= Feb 1 00:30 local) | Unaffected | Counts in **February** (local month); counting it in January would be wrong | Unaffected (no month reset) |

**Incremental updates under (b)** (the Owner's requirement: never re-credit the monthly total). In the settlement transaction, one statement adds `FinalAmount` to the member-month's TotalSpend and recomputes `PointsEarned = FLOOR(new TotalSpend / 100000)`, returning the old and new values. Only the difference `new PointsEarned − old PointsEarned` (0 or more) is added to `CurrentPoints`. For the member's first payment in the month, the row is inserted with `PointsEarned = FLOOR(FinalAmount / 100000)`, and that value is the difference.

Example: Jan 10 pays 60,000 → row (60,000; 0), difference 0. Jan 20 pays 60,000 → row (120,000; 1), difference 1, so `CurrentPoints` +1. A third payment of 30,000 → row (150,000; 1), difference 0. Crediting the monthly total instead would have added 1 + 1 = 2 points for 150,000 VND.

Under (e), the difference is computed the same way, from the lifetime total before and after the payment.

**Recommendation (not approved):** (b). It keeps the payment path constant-cost, needs no schema change, and makes points self-checking per row. (e) is the most generous to members; choose it if minimal loss matters more than the extra read or the extra MEMBER column.

### C.3 Tier evaluation period (directive §6.4)

**Not approved.** Decide before UC05 tier behaviour. This does not block P1. Thresholds are not invented (D-008).

| | (1) Calendar-year spending | (2) Twelve calendar months including the current month | (3) Exact rolling 12-month window |
|---|---|---|---|
| Window on 2026-11-07 | 2026-01-01 → now | 2025-12-01 → now (Dec 2025 … Nov 2026) | 2025-11-08 → 2026-11-07 (day-precise) |
| Computed from MEMBER_MONTHLY_SPENDING | **Exactly**, ≤ 12 rows of the current year | **Exactly**, ≤ 12 rows | **Not exactly**: the oldest month is only partly inside. Needs a daily spending table (≈ 365 rows per member; a schema change), or the oldest month recomputed from INVOICE (needs an index on Member_ID, PaidAt; reintroduces invoice reads), or a full invoice scan (the Problem 4 design) |
| Retention needed | Current year | 12 months | 12 months + daily detail |
| When tiers go up | When spending accumulates (daily batch) | Same | Same |
| When tiers go down | **Only on 1 January**, for everyone at once (spending resets to 0) | On the 1st of a month, when the oldest month leaves the window; gradual | Any day, as old spending ages out; needs a daily evaluation of every member |
| Fit with S-01 p2 ("spending in the year") | Literal reading | "Within a year" reading | "Within a year" reading |
| Fit with Problem 4 ("re-ranks up **or down** at each payment") | Poor: a payment can never lower the year-to-date total | Good | Good |

**Periodic evaluation vs. the original requirements.** The assignment describes the current system as slow because it re-sums 12 months of invoices at every payment, and asks for a storage redesign so payment is not blocked (S-01 p3, Problem 4). Phase 1 answered with MEMBER_MONTHLY_SPENDING plus periodic evaluation: S-02 §2.6 steps 4–5, F22 one batch per day. That answer meets the requirement only if the window can be computed from monthly rows, which is true for (1) and (2) and false for (3). The price of periodic evaluation is that a tier can lag by up to one day. That is a documented limitation; the optional immediate-upgrade check (D-009 (b)) reads at most 12 rows if the business needs instant upgrades.

**Recommendation (not approved):** (2). It is exact from the Phase 1 table, avoids the January mass downgrade, matches "up or down", and fits the daily batch.

### C.4 Loyalty redemption (directive §6.5, §7)

**APPROVED 2026-11-07 as a scope restriction (D-024).** Redemption, expiry and redemption-specific tables and workflows are excluded.

- Consistency evidence: no redemption or expiry rule in S-01 (2026-11-06 audit; not re-read on 2026-11-07 because the password is not stored), in S-02 (text search 2026-11-07), or in the P3 allocation summary S-11.
- No mandatory requirement was changed.
- The existing schema is sufficient for earning and tier management.

### C.5 Revenue recognition (directive §6.6)

| Element | Definition (D-010, not yet approved) |
|---|---|
| Recognition event | Successful payment (PENDING→PAID), not issuance |
| Amount | `FinalAmount` |
| Population | `PaymentStatus = 'PAID'` only |
| Date | `PaidAt`, stored in UTC; reported on the Asia/Ho_Chi_Minh calendar |
| Periods | Local calendar day, month, quarter and year as half-open ranges, converted to UTC bounds before filtering (e.g. local January 2026 = `[2025-12-31 17:00, 2026-01-31 17:00)` UTC) |
| Branch | `INVOICE.Branch_ID` (issuing branch, BR08) |
| System revenue | Σ over branches of the same definition |
| Refunds | Out of scope (D-011 approved) |
| Service plans | Recognised at sale |

### C.6 DBMS and environment (directive §6.7)

| Item | State | How known |
|---|---|---|
| DBMS | Microsoft SQL Server | D-002 approved (provisional) |
| Instances | `MSSQLSERVER` and `MSSQLSERVER01`, both **running** | Windows services, 2026-11-07 |
| Version / edition | 17.0.1000.7 (SQL Server 2025 RTM), "Standard Developer Edition" | Registry `Setup` keys and `sqlservr.exe` file version `2025.0170.1000.07`, 2026-11-07. **NOT_VERIFIED by query.** |
| Server collation | `SQL_Latin1_General_CP1_CI_AS` (both instances) | Registry, 2026-11-07 |
| Compatibility level 160 | Supported by SQL Server 2022 and later according to the product documentation | **NOT_VERIFIED**: P1 preflight |
| Host time zone | Windows "SE Asia Standard Time" (UTC+07:00, no DST) | `tzutil`, 2026-11-07. Storage is UTC, so this only matters for conversions. |
| Tools | `sqlcmd` (ODBC 17 tools); SSMS 22 user folder | File system |
| Feature limits | NOT_VERIFIED | WO-P3-P0-02, before WO-P3-P2-02 |

**Readiness:** the engine and edition look compatible with the approved design. The formal verification is P1 step 1. No installation or upgrade is needed or authorized.

## D. Remaining blockers

| # | Blocker | Blocks | Resolution | Approver |
|---|---|---|---|---|
| 1 | GATE-P0 not passed (WO-P3-P0-03 `VERIFIED`) | P1 start | Owner sets `PASSED` | Project Owner |
| 2 | Billing (invoice creation and finalisation) has no work order since INVOICE and the item tables became P3-owned | UC05 billing | Extend WO-P3-P3-01 or confirm a P3 billing interface used by other members' sale flows (D-012) | Project Owner / Team |
| 3 | WO-P3-P1-01 not approved | P1 | Statement in WO-P3-P1-01 §11 | Project Owner |
| 5 | SQL Server preflight not run | First migration (inside P1) | WO-P3-P1-01 step 1 | — |
| 6 | D-021 Part B, including visibility | First push | Team and repository owner | Team |
| 7 | Team review of the provisional decisions and of V001/V002 | Integration, merge | First PR review | Team |
| 8 | UC05 and UC06 decisions (Section C) | P2, P3, P4 | Owner/team before those phases | Owner / Team |
| 9 | Six-UC catalogue; promotion WO; deadline | UC06 scope; P6; scheduling | Team; Owner | Team / Owner |

## E. Repository readiness

### E.1 Baseline (inspected 2026-11-07, re-checked the same day; read operations only)

| Item | Finding |
|---|---|
| Repository | `https://github.com/Phuoc-IT-2106/CSDLNC-DA`, owner account `Phuoc-IT-2106`, created 2026-11-05 |
| Visibility | **Public**; no license file |
| Default branch | `main`; not protected; no other branches, pull requests, open issues or forks |
| History | 1 commit, `792a85e` "Initial commit" (2026-11-05 03:19 UTC); unchanged at the re-check |
| Content | `README.md` only (11 bytes); no `.gitignore`, no `.gitattributes` |
| Read access | Verified (`git ls-remote`, clone, REST API without credentials) |
| Write access | NOT_VERIFIED (no write attempted) |
| Local planning workspace | `C:\CSDLNC- DA`, **not a Git repository**, documentation only. **This is the authoritative location of the planning files** until the cut-over. |
| Local clone | `C:\Users\DELL\source\repos\CSDLNC-DA` on `main` at `792a85e`, working tree clean; nothing copied into it |
| Line endings | System `core.autocrlf=true`; the planning documents use LF |

### E.2 Documentation migration (non-destructive)

No document has been copied yet. The migration happens once, as step 0 of WO-P3-P1-01, after D-021 Part A is approved:

1. Confirm the clone is clean and `main` is at the recorded commit (or a fast-forward of it).
2. Create the local branch `p3/wo-p3-p1-01`.
3. Copy `CLAUDE.md`, `docs/agent/` and `docs/phase2/person3/` unchanged, with the same relative paths, and compare checksums with the originals.
4. Add `.gitignore` and `.gitattributes` (E.3).
5. Leave `C:\CSDLNC- DA` **untouched** (immutable archive, D-021 Part A). Update the agent's project memory for that folder so that later sessions opened there are sent to the clone. (The v2 marker file is dropped.)
6. From then on, edit only in the clone. There is never more than one editable master prompt or decision log: before the cut-over only in `C:\CSDLNC- DA`, afterwards only in the clone.
7. Run the file-safety checks (E.4) before any commit. Commits, pushes, PRs, merges and visibility changes each need explicit authorization; the directive of 2026-11-07 authorizes none of them.

### E.3 Proposed repository files

For later approval (D-021 Part B).

`.gitattributes`:

```text
* text=auto eol=lf
*.png binary
*.jpg binary
*.sqlplan -text
```

`.gitignore`:

```text
# SQL Server data, log, backup and export files
*.mdf
*.ldf
*.ndf
*.bak
*.trn
*.bacpac
*.dacpac
# generated large datasets and raw dumps (seed scripts are versioned, their output is not)
db/seed/output/
*.bcp
*.dat
*.zip
*.7z
*.rar
# local configuration, credentials and machine-specific files
.env
.env.*
*.local.*
*.user
.vs/
.vscode/
.claude/settings.local.json
connectionstrings*.json
# build output
bin/
obj/
node_modules/
```

### E.4 File-safety rules (before every commit)

1. **Secrets:** no passwords, connection strings with credentials, or tokens. The assignment PDF password is never stored anywhere. Scan the staged files for password keywords, connection-string credential keys and GitHub token prefixes.
2. **Database credentials:** Windows authentication only; nothing to commit.
3. **Machine-specific configuration:** no IDE, Claude or local settings files (covered by `.gitignore`).
4. **Large or generated data:** no database files, backups, archives or generated datasets. Evidence text files (`results.csv`, logs, `.sqlplan`) are committed; anything over 1 MB needs a recorded reason.
5. **Personal information:** no e-mail addresses, phone numbers or personal names beyond the team's own report entries. The documents contain machine paths (`C:\Users\DELL\…`) in about ten places. They are acceptable in a private repository; replace them with placeholders (for example `%USERPROFILE%`) before any public push.
6. **Allowed types:** `.md`, `.sql`, `.txt`, `.csv`, `.sqlplan`, `.png`, `.gitkeep`, `.gitignore`, `.gitattributes`.
7. **Review:** `git status` and `git diff --stat` reviewed; `README.md` unchanged unless the repository owner agrees.

**Visibility recommendation: private** while the course runs, with teammates (and the lecturer, if required) added as collaborators. Reasons:

- The documents quote the official assignment (course material that is not the team's to publish).
- They contain team-internal planning and, later, the solution, which other groups could copy (academic-integrity risk).
- They contain machine paths.
- GitHub private repositories allow collaborators at no cost.

Making the repository public after grading remains possible. The repository owner decides; P3 does not change visibility.

## F. Approval matrix

Rows with an outcome were decided on 2026-11-07. Open rows are not preselected.

| # | Item | Recommendation | Class | Approver | Outcome (2026-11-07) | APPROVE_RECOMMENDATION | SELECT_ALTERNATIVE | DEFER | REJECT |
|---|---|---|---|---|---|---|---|---|---|
| 1 | B0 team-approval timing | T2 | — | Project Owner | **T2 approved with restrictions** | — | — | — | — |
| 2 | B1: D-002, D-014, D-018 | SQL Server, compat 160; INT, DECIMAL(18,2), DATETIME2(3) | BLOCKING_P1 | Owner (T2) | **Approved, provisional; UTC storage** | — | — | — | — |
| 3 | B2: D-003, D-004, D-005, D-011 | Invoice-state model, PaidAt, 3 statuses, 3 methods, no refunds | BLOCKING_P1 | Owner (T2) | **Approved, provisional** | — | — | — | — |
| 4 | B3: D-023 | Monetary CHECKs; cross-table totals outside CHECKs | BLOCKING_P1 | Owner (T2) | **Approved, provisional** | — | — | — | — |
| 5 | D-013 | §B4 statement (local month of PaidAt) | BLOCKING_P1 | Project Owner | **Approved (v3)** | — | — | — | — |
| 6 | D-021 Part A | §B4 statement | BLOCKING_P1 | Project Owner | **Approved (v3; immutable archive, no marker)** | — | — | — | — |
| 7 | D-026 | Restricted scope (four P3 tables; TEST_ONLY key fixtures) | BLOCKING_P1 | Project Owner | **Approved, restricted (v3)** | — | — | — | — |
| 8 | GATE-P0 + WO-P3-P1-01 | Statement in WO-P3-P1-01 §11 | — | Project Owner | **Approved and executed 2026-11-07 (GATE-P0 closed; WO VERIFIED)** | — | — | — | — |
| 9 | D-021 Part B | §B4, §E (visibility: ☐ private ☐ public) | BLOCKING_INTEGRATION | Team and repository owner | Open | ☐ | ☐ | ☐ | ☐ |
| 10 | D-006 | (b) monthly cumulative, incremental | BLOCKING_UC05 | Project Owner | Open | ☐ | ☐ (a) ☐ (e) | ☐ | ☐ |
| 11 | D-007 | (2) twelve calendar months incl. current | BLOCKING_UC05 | Project Owner | Open | ☐ | ☐ (1) ☐ (3) | ☐ | ☐ |
| 12 | D-008 | Base tier 0, `≥`; values Silver 0 / Gold ____ / Platinum ____ | BLOCKING_UC05 | Project Owner | Open | ☐ | ☐ | ☐ | ☐ |
| 13 | D-009 | Daily batch | BLOCKING_UC05 | Project Owner | Open | ☐ | ☐ | ☐ | ☐ |
| 14 | D-012 | One transaction, one orchestrator; owner: ____ | BLOCKING_UC05 | Team | Open | ☐ | ☐ | ☐ | ☐ |
| 15 | D-019 | READ COMMITTED + update locks | BLOCKING_UC05 | Team | Open | ☐ | ☐ | ☐ | ☐ |
| 16 | D-022 | DS-S/M/L, T-SQL seed, 08 §6 thresholds | BLOCKING_UC05 | Project Owner | Open | ☐ | ☐ | ☐ | ☐ |
| 17 | D-001 | Six-UC catalogue with owners | BLOCKING_UC06 | Team | Open | ☐ | ☐ | ☐ | ☐ |
| 18 | D-010 | C.5 | BLOCKING_UC06 | Team | Open | ☐ | ☐ | ☐ | ☐ |
| 19 | D-020 | Team application stack | BLOCKING_INTEGRATION | Team | Open | ☐ | ☐ | ☐ | ☐ |
| 20 | D-024 | Accrual only | OUT_OF_SCOPE | Project Owner | **Approved (scope restriction)** | — | — | — | — |

---

## Annex 1 — Decision register (directive §5)

Alternatives, evidence and full reasoning are in each entry of [03_DECISION_LOG.md](../03_DECISION_LOG.md). "Next WO" = does the decision affect WO-P3-P1-01?

| ID | Exact question | Key evidence | Alternatives | Recommended / approved | Affected tables / UC | Next WO | Approver | Status | Class | Consequence of deferral |
|---|---|---|---|---|---|---|---|---|---|---|
| D-001 | Which UC catalogue, and who owns F06 orchestration, F29, F30, RQ-A16–A18? | S-02 §7.1; S-10 missing | 7 UCs / 6 UCs / 6 UCs + P3 orchestrates | 6-UC catalogue with owners | Report scope; UC06 | No | Team | PROPOSED | BLOCKING_UC06 | Candidate reports unowned |
| D-002 | Which engine, version, compatibility level? | S-07, S-08, S-14 | SQL Server 2025 / older / PostgreSQL | SQL Server; compat 160 if supported | All DDL | Yes | Owner (T2), team before merge | APPROVED (provisional, T2; preflight) | BLOCKING_P1 | — |
| D-003 | How is payment recorded exactly once? | S-02 §5.2 F06, §10 | Invoice state / PAYMENT table / + request key | Invoice state | INVOICE; UC05 | Yes | Owner (T2) | APPROVED (provisional, T2) | BLOCKING_P1 | — |
| D-004 | Add `INVOICE.PaidAt`? | F05≠F06; §2.2 step 5 | Add / use IssuedAt | Add (UTC) | INVOICE; UC05, UC06 | Yes | Owner (T2) | APPROVED (provisional, T2) | BLOCKING_P1 | — |
| D-005 | Status and method values and transitions? | S-01 p2; S-02 §2.2, §2.3 | 3 / 4 statuses / lookup codes | PENDING/PAID/CANCELLED; CASH/VNPAY/CARD | INVOICE; UC02, UC05, UC06 | Yes | Owner (T2) | APPROVED (provisional, T2) | BLOCKING_P1 | — |
| D-006 | Points: base amount, rounding? | S-01 p2; S-02 §2.6 | (a) per invoice / (b) monthly / (e) lifetime cumulative | (b), not approved | MEMBER_MONTHLY_SPENDING, MEMBER; UC05 | No | Owner | PROPOSED | BLOCKING_UC05 | No points |
| D-007 | Tier window? | S-01 p2 vs p3 | Calendar year / 12 calendar months incl. current / exact rolling | 12 calendar months incl. current, not approved | MEMBER_MONTHLY_SPENDING; UC05 | No | Owner | PROPOSED | BLOCKING_UC05 | No tiers |
| D-008 | Thresholds, base tier, boundary? | S-01; BR04 | Base 0 / extra tier / nullable tier; ≥ / > | Base 0, ≥, values from Owner | MEMBER_TIER; UC05 | No | Owner | PROPOSED | BLOCKING_UC05 | No tier data |
| D-009 | When are tiers evaluated? | F22; Problem 4 | Daily / daily + upgrade / synchronous | Daily | MEMBER; UC05 | No | Owner | PROPOSED | BLOCKING_UC05 | Batch open |
| D-010 | What is recognised revenue? | F27/F28 on INVOICE | Amount, status, date, recognition variants | C.5 | INVOICE; UC06 | No | Team | PROPOSED | BLOCKING_UC06 | No oracle |
| D-011 | Cancellations and refunds? | No source | Cancel pending / + refunds / none | Cancel pending only | INVOICE; UC05 | Yes | Owner (T2) | APPROVED (provisional, T2) | BLOCKING_P1 | — |
| D-012 | One settlement transaction? Who orchestrates? | S-02 §7.2; BR30 | One orchestrator / compensation / trigger | One orchestrator | Procedures; UC01, UC04, UC05 | No | Team | PROPOSED | BLOCKING_UC05 | No settlement |
| D-013 | Month key format and its calendar? | BR06 | DATE / INT yyyymm / CHAR(7) | DATE day 1, local month of PaidAt | MEMBER_MONTHLY_SPENDING; UC05 | Yes | Owner | APPROVED | BLOCKING_P1 | — |
| D-014 | Shared type standard? | S-02 has no types | INT/BIGINT; DECIMAL/MONEY; local/UTC | INT, DECIMAL(18,2), DATETIME2(3) **UTC** | All tables | Yes | Owner (T2) | APPROVED (provisional, T2) | BLOCKING_P1 | — |
| D-015 | Revenue summary structure? | Problem 3 | None / branch-day / branch-month / indexed view | Measure first | Summary; UC06 | No | Team if adopted | DEFERRED | DEFERRED | None |
| D-016 | Summary maintenance? | — | Procedure / trigger / batch / indexed view | With D-015 | Summary; UC06 | No | Team if adopted | DEFERRED | DEFERRED | None |
| D-017 | Partition INVOICE? | S-08; 27k rows/month | None / monthly / quarterly / yearly / PoC | PoC evidence | INVOICE; UC06 | No | Team if adopted | DEFERRED | DEFERRED | None |
| D-018 | INVOICE clustered key and key type? | S-07 p11 | Invoice_ID / (date, id) / BIGINT | Invoice_ID INT | INVOICE | Yes | Owner (T2) | APPROVED (provisional, T2) | BLOCKING_P1 | — |
| D-019 | Isolation and concurrency strategy? | S-02 §5.3 | READ COMMITTED / RCSI / SERIALIZABLE | READ COMMITTED + locks | Database option; UC05 | No | Team | PROPOSED | BLOCKING_UC05 | Concurrency open |
| D-020 | Application stack? | S-01 "web/winform" | ASP.NET / WinForms / Node | Team choice | App; P6 | No | Team | PROPOSED | BLOCKING_INTEGRATION | P6 late |
| D-021 | Repository, layout, workflow? | Section E | Init here / clone + copy / none | Part A: single working copy, immutable archive; Part B: shared conventions, private | Files, branches | Yes (Part A) | A: Owner; B: team | APPROVED (Part A); PROPOSED (Part B) | BLOCKING_P1 | Part B: no push |
| D-022 | Dataset tiers, seed tool, thresholds? | S-02 §6.1 | T-SQL / Python / third-party | DS-S/M/L, T-SQL | Seed; P2 | No | Owner | PROPOSED | BLOCKING_UC05 | No seed |
| D-023 | Invoice totals and discount allocation? | S-02 §2.2 step 3 | Σ line discounts / + invoice discount / line-net reports | Σ line discounts; row CHECKs; V-TOT | INVOICE, lines; UC05, UC06 | Yes | Owner (T2) | APPROVED (provisional, T2) | BLOCKING_P1 | — |
| D-024 | Redemption or expiry of points? | No source | Accrual only / redemption / expiry | Accrual only | MEMBER; UC05 | No | Owner | APPROVED | OUT_OF_SCOPE | — |
| D-025 | Database topology? | Master prompt §11 | Shared only / isolated copies / P3-only DB | Isolated copies | All WOs | Yes (target DB) | Owner | APPROVED | — | — |
| D-026 | How does P1 handle shared dependencies when no team DDL exists? | D-025 cond. 2–3; empty repo | Wait / 10-table translation / key-only stubs / whole §10 | Restricted: four P3 tables + key-only TEST_ONLY fixtures (10-table translation withdrawn) | 4 P3 tables; 5 fixtures | Yes | Owner (team before integration) | APPROVED (restricted scope) | BLOCKING_P1 | — |

## Annex 2 — Changes and verification

The changes of each directive are listed in the [session log](../SESSION_LOG.md) entries of 2026-11-07, with the documentation-audit results (items 4–6 of each entry). No SQL was written or executed, no database was created, changed or queried, and nothing was committed or pushed.
