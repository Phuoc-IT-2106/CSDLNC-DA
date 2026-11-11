# 03 — Decision Log (Person 3)

| Field | Value |
|---|---|
| Document status | DRAFT — WO-P3-BOOT-001; updated by WO-P3-P0-01 (2026-11-06), Owner Directive WO-P3-P0-FINAL the Owner Directive "Final P0 Decision Resolution" (WO-P3-P0-03 run 1) and the Owner Directive "Strict Person 3 Scope Enforcement" (WO-P3-P0-03 run 2), all 2026-11-07; Owner Directive "Reprioritize Person 3 Implementation" (2026-11-08: D-027 recorded, D-028 added, D-001 and D-012 "Needed before" updated); Owner Directive "Approve P1 and Execute P2-01" (2026-11-08: D-006 and D-022 approved; D-028 Q5 direction); Owner Directive "Urgent Unblock & Core Implementation" (2026-11-09: D-028 Owner direction and implementation recorded; status unchanged); Owner Directive "Close Invoice Creation and Prioritize Settlement" (2026-11-09: D-028 Q4, Q5 approved in the directive, Q1–Q3 confirmed by the Owner's answers in the same session, D-028 APPROVED (provisional, T2); D-012 (a) and D-019 (a) APPROVED (provisional, T2) by the Owner's answers in the same session) ; Owner Directive "UC05 Loyalty Decision Closure & Implementation Readiness" (2026-11-09, PLAN_ONLY: decision package for D-007, D-008, D-009 prepared; statuses unchanged); Owner Directive "Finalize UC05 Settlement and Implement Loyalty" (2026-11-09: D-007 (d) APPROVED T2; D-008 **rule** APPROVED T2, D-008 **values** still PROPOSED; D-009 (a) APPROVED T2); Owner Directive "Accept Loyalty & Implement UC06 Revenue Correctness" (2026-11-10: D-010 APPROVED (provisional, T2) with the nine rules of the directive §4) |
| Date | 2026-11-10 |
| Status values | `PROPOSED` (awaiting decision), `APPROVED`, `REJECTED`, `DEFERRED` (to be decided with evidence from a later work order). `APPROVED (provisional, T2)` = approved by the Project Owner for isolated development under approval rule 3 as amended on 2026-11-07 (master prompt A1, roadmap §1); recorded team approval is still required before integration, merge or any shared-database change. |
| Rule | An approver and a date are recorded **only** when the approval is verifiable. Unknown values stay `—`. A recommendation is never a requirement until its status is APPROVED. |
| Blocker classes | `BLOCKING_P1` (changes the initial physical schema), `BLOCKING_UC05`, `BLOCKING_UC06`, `BLOCKING_INTEGRATION`, `DEFERRED` (decided by measured evidence), `OUT_OF_SCOPE`. Set on 2026-11-07 by the [P0 final decision package](design/P0_FINAL_DECISION_PACKAGE.md); they replace the 2026-11-06 classes (BLOCKING_P1 / BLOCKING_FEATURE / DEFERRED). |

## How a decision gets approved

1. P3 presents the decision in the [P0 final decision package](design/P0_FINAL_DECISION_PACKAGE.md) (approval matrix in Section F).
2. The approver is the Project Owner for P3-internal decisions, or the whole team for decisions marked "Team approval".
3. The approver's choice, name or role, date and reference (meeting note, chat message, tracking-tool item) are written into the decision entry, and the status is changed.
4. Any document that depends on the decision is updated in the same session (master prompt §13; see [P3_MASTER_PROMPT.md](../../agent/P3_MASTER_PROMPT.md#13-documentation-and-evidence)).

## Index

| ID | Title | Status | Blocker class (2026-11-07) | Team approval needed | Needed before |
|---|---|---|---|---|---|
| D-001 | Use-case catalogue and P3 scope | PROPOSED | BLOCKING_UC06 | Yes | WO-P3-P4-01 candidate reports RPT-05…07 only (core RPT-01…04 not blocked, 2026-11-08); group report |
| D-002 | Reference DBMS, version, edition, compatibility level | APPROVED (provisional, T2; conditional on the P1 preflight) | BLOCKING_P1 | Yes | WO-P3-P1-01 |
| D-003 | Payment-confirmation model | APPROVED (provisional, T2) | BLOCKING_P1 | Yes | WO-P3-P1-01 |
| D-004 | Add `INVOICE.PaidAt` | APPROVED (provisional, T2) | BLOCKING_P1 | Yes | WO-P3-P1-01 |
| D-005 | PaymentStatus and PaymentMethod domains; state machine | APPROVED (provisional, T2) | BLOCKING_P1 | Yes | WO-P3-P1-01 |
| D-006 | Point formula and rounding | **APPROVED** (isolated P3 development; team review before shared integration) | BLOCKING_UC05 | No (Project Owner) | P2 seed (derived points); WO-P3-P3-01 |
| D-007 | Tier evaluation window | **APPROVED (provisional, T2)** — alternative (d), 2026-11-09 | BLOCKING_UC05 | No (Project Owner) | WO-P3-P3-02; in P2 only for the optional F002 extension (recommended before WO-P3-P2-02 for the Q-UC05-A window) |
| D-008 | Tier thresholds, base tier, boundary rule | **Rule APPROVED (provisional, T2)** 2026-11-09; **threshold values PROPOSED** (open business configuration) | BLOCKING_UC05 | No (Project Owner) | WO-P3-P3-02; in P2 only for the optional F002 extension |
| D-009 | Tier evaluation timing | **APPROVED (provisional, T2)** — alternative (a), 2026-11-09 | BLOCKING_UC05 | No (Project Owner) | WO-P3-P3-02 |
| D-010 | Definition of recognised revenue | **APPROVED (provisional, T2)** — 2026-11-10 (nine rules; team reconciliation before integration) | BLOCKING_UC06 | Yes | P2 baseline oracle; WO-P3-P4-01 (functional part executed 2026-11-10) |
| D-011 | Cancellation and refund scope | APPROVED (provisional, T2) | BLOCKING_P1 | Yes | WO-P3-P1-01 |
| D-012 | Settlement transaction boundary and ownership | **APPROVED (provisional, T2)** — alternative (a), 2026-11-09 | BLOCKING_UC05 | Yes | WO-P3-P3-01 (isolated work with hook test doubles); team confirmation in WO-P3-P1-02 at P6 |
| D-013 | `SpendingMonth` representation | APPROVED | BLOCKING_P1 | No (Project Owner) | WO-P3-P1-01 |
| D-014 | Money, key and timestamp types; time zone | APPROVED (provisional, T2) | BLOCKING_P1 | Yes | WO-P3-P1-01 |
| D-015 | Revenue summary structure | DEFERRED | DEFERRED | Yes (if adopted) | Decided in P4 (WO-P3-P4-02) |
| D-016 | Summary maintenance mechanism | DEFERRED | DEFERRED | Yes (if adopted) | Decided in P4 (WO-P3-P4-02) |
| D-017 | Partition INVOICE | DEFERRED | DEFERRED | Yes (if adopted) | Decided in P5 (WO-P3-P5-01) |
| D-018 | INVOICE clustered key and surrogate key type | APPROVED (provisional, T2) | BLOCKING_P1 | Yes | WO-P3-P1-01 |
| D-019 | Isolation and concurrency strategy | **APPROVED (provisional, T2)** — alternative (a) for the P3 write path, 2026-11-09; (b) RCSI stays a team choice | BLOCKING_UC05 | Yes | WO-P3-P3-01 |
| D-020 | Application stack and P3 feature surface | PROPOSED | BLOCKING_INTEGRATION | Yes | WO-P3-P6-01 |
| D-021 | Repository, layout, version-control workflow | APPROVED (Part A); PROPOSED (Part B) | BLOCKING_P1 (Part A); BLOCKING_INTEGRATION (Part B) | Part A: No (Project Owner). Part B: Yes (team and repository owner) | Part A: WO-P3-P1-01. Part B: first push |
| D-022 | Benchmark dataset tiers, seed tool, acceptance thresholds | **APPROVED** (dataset and generator; index adoption thresholds still proposed defaults) | BLOCKING_UC05 (also UC06) | No (Project Owner; inform team) | WO-P3-P2-01 |
| D-023 | Invoice totals rule and discount allocation | APPROVED (provisional, T2) | BLOCKING_P1 | Yes | WO-P3-P1-01 |
| D-024 | Point balance semantics (redemption, expiry) | APPROVED | OUT_OF_SCOPE | No (Project Owner) | — (confirm any time; does not block P1) |
| D-025 | Database topology for P3 development, testing and benchmarking | **APPROVED** (with constraints) | — | No: Project Owner (the approved constraints keep the shared database untouched) | — |
| D-026 | Shared dependencies for isolated P1 development (restricted) | APPROVED (restricted scope) | BLOCKING_P1 | No (Project Owner); team review before integration (condition 10) | WO-P3-P1-01 |
| D-027 | Deferral of the formal integration contract (independent P2–P5 development) | **APPROVED** | — (roadmap governance) | No: Project Owner (the contract itself still needs team approval at P6) | — (effective 2026-11-08) |
| D-028 | Invoice creation (billing): responsibility, interface, finalisation, creation idempotency | **APPROVED (provisional, T2)** — Q1–Q4 (a), Q5 (a), Q6 as stated, 2026-11-09 | BLOCKING_UC05 | Yes (other members' sale flows call it); team confirmation at P6 | WO-P3-P3-00 `VERIFIED` (done 2026-11-09) |

---

## D-001 — Use-case catalogue and P3 scope

| Field | Content |
|---|---|
| Problem | Phase 1 has 7 UCs. A newer team assignment (MISSING, S-10) has 6. P3 boundaries are unverifiable (G-01). |
| Alternatives | (a) Keep the 7 Phase 1 UCs; P3 = UC05 + UC06 as defined there (UC06 then includes F29 occupancy). (b) Adopt the 6-UC catalogue; P3 = settlement/loyalty UC05 + revenue UC06; F29 goes to the check-in owner. (c) As (b), but P3 also takes the orchestration of the whole settlement transaction (F06). |
| Evidence and constraints | S-01 p4 accepts 5–8 UCs. S-02 §7.1. S-11 summary. F06 is shared by UC01/UC04/UC05. |
| Recommended choice | TECHNICAL_RECOMMENDATION: (b), but **only after** the team publishes the full six-UC list with owners. P3 core = F06 loyalty/revenue effects, F20, F21, F22, F27, F28, RQ-A14, RQ-A15. Assign RQ-A16, RQ-A17, RQ-A18 and the settlement orchestration explicitly (to P3 or another member). **Update 2026-11-07:** the Project Owner confirmed that P3 owns UC05 (payment settlement and loyalty) and UC06 (revenue reporting) (directive WO-P3-P0-FINAL §6.1). That fixes P3's tables for P1, so D-001 no longer blocks P1. The rest (full catalogue; owners of F29, F30, RQ-A16–A18; the orchestrator, see D-012) blocks the UC06 candidate reports and the group report. Phase 1 → Phase 2 mapping and naming rule: [00 §5](00_SOURCE_AND_SCOPE.md#5-use-case-reconciliation-seven-phase-1-vs-six-team-proposal). |
| Consequences and risks | The report and code must use one numbering. Leftover F29/F30 work must have an owner (R-02). |
| Scope update (2026-11-07, strict scope) | The Owner fixed P3's table ownership: P3 owns INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM and MEMBER_MONTHLY_SPENDING; MEMBER (CurrentPoints, Tier_ID, identifiers), MEMBER_TIER (tier definitions, thresholds), BRANCH, EMPLOYEE, SERVICE_PLAN and PRODUCT are shared dependencies; check-in, PT, payroll, employee assignment, member registration, inventory workflows, branch, plan and product administration and other members' UIs are excluded. UC05 = billing, settlement, spending aggregation, loyalty points, tier management; UC06 = revenue reporting, indexing, query optimization, performance analysis. The full six-UC catalogue and owners remain open (this decision). |
| Status | PROPOSED |
| Blocker class | BLOCKING_UC06 (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: BLOCKING_P1 ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | — / — |
| Related | G-01, G-19; WO-P3-P0-01 |

## D-002 — Reference DBMS, version, edition, compatibility level

| Field | Content |
|---|---|
| Problem | The DBMS is not formally recorded. Results and features depend on version and edition (G-20). |
| Alternatives | (a) SQL Server 2025 (17.x) as installed locally (S-14). (b) An older SQL Server version shared by all members. (c) PostgreSQL (no course material, not installed). |
| Evidence and constraints | Course seminars use SQL Server (S-07, S-08). Both local instances: 17.0.1000.7, "Standard Developer Edition". Other members' environments are unknown. |
| Recommended choice | TECHNICAL_RECOMMENDATION (updated 2026-11-07): Microsoft SQL Server. P3 reference instance: the local default instance `MSSQLSERVER`, SQL Server 2025 (17.0.1000.7, Standard Developer; registry value, not yet query-verified). Databases use **compatibility level 160** (SQL Server 2022), so scripts also run on teammates' SQL Server 2022 instances; use 170 only if every member confirms SQL Server 2025. Record `@@VERSION`, `SERVERPROPERTY('Edition')`, `SERVERPROPERTY('EngineEdition')` and the compatibility level in every manifest. WO-P3-P1-01 step 1 captures the instance identity; WO-P3-P0-02 verifies partitioning, filtered indexes, indexed views (with and without NOEXPAND) and online index operations before WO-P3-P2-02. |
| Consequences and risks | Edition limits may remove some options (R-09). Version differences across members make results non-comparable (R-07). |
| Approved decision | Microsoft SQL Server is the reference DBMS. Preferred database compatibility level **160, if supported by the verified engine**. Before any migration: verify the installed version and edition, verify compatibility-level support, record the actual environment, and verify that the proposed schema does not conflict with the approved logical model (WO-P3-P1-01 preflight). No installation or upgrade. If the environment is incompatible, report the blocker instead of silently changing the design. |
| Status | **APPROVED (provisional, T2; conditional on the P1 preflight)** |
| Blocker class | BLOCKING_P1 (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: BLOCKING_P1 ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | Project Owner / 2026-11-07 (provisional under T2: team approval required before integration or merge) |
| Reference | Owner Directive "Final P0 Decision Resolution" (Claude Code session of 2026-11-07), §2 (B1) |
| BM-1 verification 2026-11-11 | Owner-selected BM-1 localhost\MSSQLSERVER01, 17.0.1000.7, Standard Developer / EngineEdition 2, compatibility 160. Filtered indexes, partitioning and indexed-view creation verified; no automatic matching observed in probe, NOEXPAND works; ONLINE refused Msg 1712. [ENVIRONMENT_P0](design/ENVIRONMENT_P0.md). Existing D-002 approval unchanged |
| Related | G-20; WO-P3-P0-02 |

## D-003 — Payment-confirmation model

| Field | Content |
|---|---|
| Problem | How to record payment and guarantee its business effect happens exactly once (G-02, G-04, G-10). |
| Alternatives | (A) **Invoice-state model:** INVOICE keeps PaymentStatus (+ `PaidAt`, D-004). Settlement is a conditional transition PENDING→PAID inside one transaction, and the invoice row is the idempotency token. (B) **PAYMENT table:** one row per attempt with a provider reference and a unique idempotency key; INVOICE status is derived or updated. (C) (A) plus a unique client request key on INVOICE, so that retried *creation* calls cannot create duplicate invoices. |
| Evidence and constraints | Phase 1 has no PAYMENT entity (S-02 §10). S-09 recommends PAYMENT only for retries, refunds or audit. The assignment lists three methods and no split payments. |
| Recommended choice | TECHNICAL_RECOMMENDATION: (A) for the Phase 2 core: one column added and the Phase 1 model preserved. Add (C) only if the application can resubmit creation. Choose (B) only if D-011 puts refunds or partial payments in scope, or the team wants VNPay callbacks modelled. |
| Consequences and risks | (A) cannot record failed attempts or several payments per invoice. (B) adds a table, joins and an index that must be justified in the report. |
| Approved decision | Option (A): `PaymentStatus` stays on INVOICE; no separate PAYMENT table in the current scope; one successful settlement per invoice; a successfully settled invoice must not be settled again. Option (C) (client request key) is not part of this approval and stays with the invoice-creation owner (integration). No settlement procedure is implemented in P1. |
| Status | **APPROVED (provisional, T2)** |
| Blocker class | BLOCKING_P1 (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: BLOCKING_P1 ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | Project Owner / 2026-11-07 (provisional under T2: team approval required before integration or merge) |
| Reference | Owner Directive "Final P0 Decision Resolution" (Claude Code session of 2026-11-07), §3 (B2) |
| Related | G-02, G-04, G-10; D-004, D-005, D-011 |

## D-004 — Add `INVOICE.PaidAt`

| Field | Content |
|---|---|
| Problem | The final schema has no payment timestamp. Revenue and spending months need one (G-03). |
| Alternatives | (a) Add `PaidAt` (nullable while PENDING) with a CHECK tying it to PaymentStatus. (b) No new column; use `IssuedAt` as the recognition time, which is valid only if payment always happens when the invoice is issued. |
| Evidence and constraints | `PaidAt` existed in the drafts of 2026-10-31 and 2026-11-05 19:52 (S-06, S-04) and was removed by 20:27 (reason unknown). It is a shared-table change. |
| Recommended choice | TECHNICAL_RECOMMENDATION: (a), **after asking the team why it was removed**. If the team confirms that payment always happens at issuance, (b) is acceptable and every PaidAt reference in the P3 plans is replaced by IssuedAt. **Update 2026-11-07:** Phase 1 separates F05 "create invoice" from F06 "confirm payment" (S-02 §5.2), and entitlements start "when the invoice is confirmed as validly paid" (§2.2 step 5). Issuance and payment are therefore distinct events, which supports (a). In WO-P3-P1-01, PaidAt and its CHECKs are isolated in migration V002, so a later rejection is cheap. |
| Consequences and risks | (a) one more column and possibly index keys; (b) mis-dated revenue for invoices paid later. |
| Approved decision | Add `INVOICE.PaidAt` to record the successful-settlement time. A successful settlement must have a valid `PaidAt`: NOT NULL exactly when PAID, `PaidAt ≥ IssuedAt`, stored in UTC (D-014). |
| Status | **APPROVED (provisional, T2)** |
| Blocker class | BLOCKING_P1 (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: BLOCKING_P1 ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | Project Owner / 2026-11-07 (provisional under T2: team approval required before integration or merge) |
| Reference | Owner Directive "Final P0 Decision Resolution" (Claude Code session of 2026-11-07), §3 (B2) |
| Related | G-03; IX-01…IX-03; D-017 |

## D-005 — PaymentStatus and PaymentMethod domains; state machine

| Field | Content |
|---|---|
| Problem | The status values are undefined (G-02, G-09). |
| Alternatives | Status: (a) PENDING, PAID, CANCELLED; (b) (a) + REFUNDED; (c) numeric codes with a lookup table. Method: CASH, VNPAY, CARD (from S-01). Method set at creation, or at settlement. |
| Evidence and constraints | S-01 p2 (three methods). The literal values become filtered-index predicates (IX-01…IX-03). |
| Recommended choice | TECHNICAL_RECOMMENDATION: (a), stored as short uppercase codes with a CHECK constraint; default PENDING. Allowed transitions: PENDING→PAID and PENDING→CANCELLED; add PAID→REFUNDED only if D-011 includes refunds. **Updated 2026-11-07:** PaymentMethod may be recorded at creation (S-02 §2.2 step 3 lists the method among the fields recorded when the invoice is created) or at settlement, and must be NOT NULL once PAID. Check-in validation reads the invoice status (S-02 §2.3 step 2), so the literals are a contract with the check-in owner. |
| Consequences and risks | Changing literals later invalidates filtered indexes and tests. |
| Approved decision | `PaymentStatus` ∈ {PENDING, PAID, CANCELLED}; `PaymentMethod` ∈ {CASH, VNPAY, CARD}. PENDING and CANCELLED are never treated as successfully paid. **`PaymentMethod` is nullable before settlement** (it may be recorded at creation, S-02 §2.2 step 3) and NOT NULL when PAID. Transition invariants: PENDING→PAID and PENDING→CANCELLED only; PAID and CANCELLED are terminal; `PaidAt` is set once. Row-level parts are CHECK constraints in P1; transition parts need the old value and are enforced by the UC05 routines (WO-P3-P3-01) — exact list in WO-P3-P1-01 §3.4. Compatibility with check-in and entitlement processing is preserved (only PAID counts as paid). Shared-contract changes remain subject to team review. |
| Status | **APPROVED (provisional, T2)** |
| Blocker class | BLOCKING_P1 (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: BLOCKING_P1 ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | Project Owner / 2026-11-07 (provisional under T2: team approval required before integration or merge) |
| Reference | Owner Directive "Final P0 Decision Resolution" (Claude Code session of 2026-11-07), §3 (B2) |
| Related | G-02, G-09; D-003, D-011 |

## D-006 — Point formula and rounding

| Field | Content |
|---|---|
| Problem | "1 point = 100,000 VND" leaves the base and the rounding open (G-05). |
| Alternatives | (a) Per invoice: `points = FLOOR(FinalAmount / 100000)`. (b) Per month cumulative: `PointsEarned(month) = FLOOR(TotalSpend(month) / 100000)`; each settlement adds the difference. (c) Over the tier window. (d) Rounding half-up instead of floor. (e) Cumulative eligible spending across all months: `CurrentPoints = FLOOR(Σ all eligible spending / 100000)`, credited incrementally (added 2026-11-07 at the Owner's request). Comparison with month-boundary examples: [P0 final package §C.2](design/P0_FINAL_DECISION_PACKAGE.md#c2-loyalty-calculation-directive-63). **Not approved; decide before UC05 loyalty behaviour (directive 2026-11-07 §6).** |
| Evidence and constraints | S-01 p2; S-02 §2.6 step 3. The rule must be deterministic, testable at the 100,000 boundaries, and reversible if refunds are in scope. |
| Recommended choice | ASSUMPTION_PENDING_APPROVAL (**changed 2026-11-07**): (b) on FinalAmount (after discounts) of the whole invoice: `PointsEarned(member, month) = FLOOR(TotalSpend(member, month) / 100000)`; each settlement adds the increase to CurrentPoints. Reasons: under (a) every purchase below 100,000 VND earns nothing, ever, and each invoice loses up to 99,999 VND, while (b) loses at most 99,999 VND per member-month; under (b) points are a function of the stored row, enforceable by a CHECK and reconcilable without reading invoices. Both are order-independent within a month. The earlier recommendation (a) remains the alternative. Analysis: [P0 final package §C.2](design/P0_FINAL_DECISION_PACKAGE.md#c2-loyalty-calculation-directive-63). |
| Consequences and risks | (b) row invariant PointsEarned = FLOOR(TotalSpend/100000), plus CurrentPoints = Σ PointsEarned (D-024). (a) the invariant is CurrentPoints = Σ FLOOR(FinalAmount/100000) over PAID invoices, which needs every invoice to verify. |
| Approved decision | Cumulative eligible spending **within each calendar month**: for each member and month, `PointsEarned = FLOOR(TotalSpend / 100000)` (alternative (b)). Only successfully paid invoices (`PaymentStatus = 'PAID'`) contribute to `TotalSpend`. `SpendingMonth` is the first day of the Asia/Ho_Chi_Minh calendar month of `PaidAt` (D-013, D-014). Incremental update at settlement: points credited = new cumulative floor − previous cumulative floor for that member-month, computed in the same statement as the `TotalSpend` increase. A settled invoice is counted once: exactly-once protection comes from the PENDING→PAID transition (T5, 06 §4.3), not from the monthly key. **Cross-month residual spending does not carry forward:** spending below the next 100,000 VND step at the end of a month earns nothing and is not added to the next month. Team review is required before shared integration (P6). |
| Status | **APPROVED** (isolated P3 development; team review before shared integration) |
| Blocker class | BLOCKING_UC05 (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: BLOCKING_FEATURE ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | Project Owner / 2026-11-08 |
| Reference | Owner Directive "Approve P1 and Execute P2-01" (Claude Code session of 2026-11-08), §2 |
| Related | G-05; T-F05-09, T-REC-02 |

## D-007 — Tier evaluation window

| Field | Content |
|---|---|
| Problem | "In the year" vs "last 12 months" (G-06). |
| Alternatives | (a) Calendar year to date (resets each 1 January). (b) Tier for year N based on spending in year N−1. (c) Rolling 12 complete months, excluding the current month. (d) Rolling current month + 11 previous months (S-03 draft BR04). (e) Exact rolling 12-month window, day-precise (added 2026-11-07). Effects on MEMBER_MONTHLY_SPENDING, evaluation and downgrades: [P0 final package §C.3](design/P0_FINAL_DECISION_PACKAGE.md#c3-tier-evaluation-period-directive-64). **Not approved; decide before UC05 tier behaviour.** |
| Evidence and constraints | S-01 p2 vs p3; S-02 §2.6 step 4 does not specify. MEMBER_MONTHLY_SPENDING supports every option with at most 12 rows per member. |
| Recommended choice | ASSUMPTION_PENDING_APPROVAL: (d). It matches the problem-4 wording, has no January cliff, and was the team's own draft wording. (a) is equally consistent with "in the year"; the Project Owner decides. **Analysis added 2026-11-07:** Problem 4 says a payment can re-rank the member **up or down**; under a calendar-year rule a payment can only raise the total, so mid-year downgrades could not happen, while a rolling window produces both. Every month-aligned window is computed exactly from at most 12 monthly rows; a day-precise 365-day window is not, and is not recommended. (d) also fits the daily batch F22; under (c) the result changes only on the 1st. No schema impact. [P0 final package §C.3](design/P0_FINAL_DECISION_PACKAGE.md#c3-tier-evaluation-period-directive-64). |
| Consequences and risks | (d) partial current month changes daily, so tier batch runs daily (F22). (a) causes mass downgrades on 1 January. |
| Approved decision (2026-11-09) | Alternative **(d)** (directive option B): the tier window is **twelve calendar months — the current Asia/Ho_Chi_Minh calendar month and the eleven preceding months**. Window spend = Σ `MEMBER_MONTHLY_SPENDING.TotalSpend` with `FromMonth ≤ SpendingMonth < NextMonth` (half-open), where NextMonth = first day of the month after the evaluation date's local month and FromMonth = NextMonth − 12 months. `PaidAt` stays in UTC; SpendingMonth = local month of PaidAt (D-013, D-014). The window advances on the first day of every local month. It is **not** an exact rolling 365-day period. Routine tier evaluation never rescans the invoice history. Subject to team reconciliation before shared integration. |
| Status | **APPROVED (provisional, T2)** |
| Blocker class | BLOCKING_UC05 (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: BLOCKING_FEATURE ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | Project Owner / 2026-11-09 (provisional under T2: team reconciliation before shared integration) |
| Reference | Owner Directive "Finalize UC05 Settlement and Implement Loyalty" (Claude Code session of 2026-11-09), §2 |
| Decision package (2026-11-09) | Sources re-checked: no source states a day-precise rolling period; S-02 leaves the period open; S-03 (unadopted) is month-aligned. Directive options A/B/C = (a)/(d)/(e). Recommendation unchanged: **(d)**. Window rules, December/January handling and downgrade without payment: [P3 loyalty decision package](design/P3_LOYALTY_DECISION_PACKAGE.md) §2; proposed approval statement §6.1. **Not approved.** |
| Related | G-06; T-F05-13 |

## D-008 — Tier thresholds, base tier, boundary rule

| Field | Content |
|---|---|
| Problem | No threshold values; BR04 requires every member to have a tier (G-07). |
| Alternatives | (a) Silver is the base tier with threshold 0; Gold and Platinum have positive thresholds. (b) A fourth "no tier" row (contradicts "3 tiers"). (c) Nullable Tier_ID (contradicts BR04). Comparison: `spend ≥ threshold` or `spend > threshold`. |
| Evidence and constraints | S-01 (three tiers); BR04; problem 4 (up and down). |
| Recommended choice | ASSUMPTION_PENDING_APPROVAL: (a) with `≥`. The member gets the highest tier whose threshold is ≤ the window spend. **Threshold values are left to the Project Owner.** Code and tests must read them from MEMBER_TIER and never hard-code them. |
| Consequences and risks | The seed distribution of tiers depends on the chosen values. |
| Scope note (2026-11-07) | MEMBER_TIER is a SHARED_DEPENDENCY, not a P3-owned table. P3 supplies the threshold values (this decision) and reads the tier definitions; the table itself and its constraints (UNIQUE name and threshold, threshold ≥ 0) are proposed to its owner through the integration contract ([12 §2a](12_INTEGRATION_PLAN.md#2a-shared-dependency-interface-required-by-p3)). |
| Approved decision — **rule only** (2026-11-09) | Alternative **(a)** with inclusive comparison: tiers Silver, Gold, Platinum; **Silver is the base tier with `SpendingThreshold = 0`**; Gold and Platinum thresholds are configurable; a member qualifies for a tier when `window spend ≥ SpendingThreshold`; the tier with the **highest eligible threshold** is selected; tier definitions and thresholds are **read from MEMBER_TIER**; **no monetary threshold is hard-coded in production routines**; a member with no qualifying spending stays Silver. |
| **Not approved — threshold values** | The Gold and Platinum **values are NOT approved** and remain a pending business configuration (no source defines them: [loyalty package §1](design/P3_LOYALTY_DECISION_PACKAGE.md#1-what-the-sources-say-checked-2026-11-09)). Explicitly labelled **synthetic** values may be used only in TEST_ONLY fixtures (F002T; the runs of 2026-11-09 use Gold 1,000,000.00 and Platinum 3,000,000.00 as TEST_ONLY_SYNTHETIC values); they are not business values and never enter production migrations, reports or evidence claims. Approval procedure: package §3. |
| Status | **Rule: APPROVED (provisional, T2). Values: PROPOSED.** |
| Blocker class | BLOCKING_UC05 (2026-11-07) for the rule — resolved 2026-11-09. The values block only a production deployment of real tier assignments (P6), not P3 implementation or tests. |
| Approver / date | Project Owner / 2026-11-09 — rule only (provisional under T2); values: — / — |
| Reference | Owner Directive "Finalize UC05 Settlement and Implement Loyalty" (Claude Code session of 2026-11-09), §3 |
| Decision package (2026-11-09) | **Official threshold values: not defined** in S-01 (audit 2026-11-06; PDF not re-opened), S-02 (docx searched: only `MEMBER_TIER.SpendingThreshold` as configuration) or S-03 ("thresholds are MEMBER_TIER configuration"). Tier names Silver/Gold/Platinum are official (S-01). Proposed split: **D-008 rule** (a) with `≥`, Silver = base at 0, values read from MEMBER_TIER — approvable; **D-008 values** — open business configuration with an approval procedure; synthetic values only in TEST_ONLY fixtures ([P3 loyalty decision package](design/P3_LOYALTY_DECISION_PACKAGE.md) §3, §6.2). **Not approved.** |
| Related | G-07; T-F05-12 |

## D-009 — Tier evaluation timing

| Field | Content |
|---|---|
| Problem | Synchronous re-ranking is the problem-4 bottleneck; Phase 1 says periodic (G-08). |
| Alternatives | (a) Daily batch only (F22). (b) Batch, plus an immediate upgrade check at settlement from at most 12 monthly rows. (c) Fully synchronous (the baseline being replaced). |
| Evidence and constraints | S-02 §2.6 step 4 and F22 (1 batch/day); S-01 problem 4. |
| Recommended choice | DERIVED_FROM_PHASE1 + TECHNICAL_RECOMMENDATION: (a). Keep (b) as an optional variant measured in T-PERF-02. (c) is implemented **only** as the baseline variant U0 for comparison. |
| Consequences and risks | Under (a), a member's tier can lag by up to one day; the report must state this. |
| Approved decision (2026-11-09) | Alternative **(a)**: periodic batch evaluation by the callable routine `dbo.usp_P3_EvaluateTiers(@AsOfDate)`, intended once per day; it applies D-007 and the D-008 rule, performs upgrades and downgrades (including members without recent payments), never rescans the invoice history, works in bounded batches, updates `Tier_ID` only when the computed tier differs, is safe to re-run for the same evaluation date, and respects concurrent settlement. **No SQL Server Agent job or other scheduler** is created (not authorized). Accepted consequence: an upgrade may become visible only after the next batch execution. The settlement path keeps no synchronous tier recalculation; alternative (c) exists only as the REFERENCE_ONLY U0; (b) is not implemented. |
| Status | **APPROVED (provisional, T2)** |
| Blocker class | BLOCKING_UC05 (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: BLOCKING_FEATURE ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | Project Owner / 2026-11-09 (provisional under T2) |
| Reference | Owner Directive "Finalize UC05 Settlement and Implement Loyalty" (Claude Code session of 2026-11-09), §4 |
| Decision package (2026-11-09) | A settlement-time check alone cannot downgrade members whose spending leaves the window without a payment, so a periodic routine is required. Recommendation unchanged: **(a)**, specified as `usp_P3_EvaluateTiers(@AsOfDate)` (config check, selection, boundaries, zero spend, concurrency, idempotency, chunking; no job or trigger created) ([P3 loyalty decision package](design/P3_LOYALTY_DECISION_PACKAGE.md) §4, §6.3). **Not approved.** |
| Related | G-08; WO-P3-P3-02 |

## D-010 — Definition of recognised revenue

| Field | Content |
|---|---|
| Problem | "Revenue" is undefined (G-11). |
| Alternatives | Amount: FinalAmount or GrossAmount. Status: PAID only, or all. Date: PaidAt or IssuedAt. Service plans: recognised at sale, or spread over validity. Refunds: reduce revenue in the refund period, or reverse the original period. Branch: issuing branch. |
| Evidence and constraints | F27/F28 entities are INVOICE and BRANCH (S-02 §5.2). Spreading revenue over validity would need far more data and is not mentioned anywhere. |
| Recommended choice | TECHNICAL_RECOMMENDATION: revenue = Σ FinalAmount of PAID invoices, dated by PaidAt (D-004) in local time, attributed to INVOICE.Branch_ID, recognised at sale. If refunds are in scope: net them in the refund period. **Updated 2026-11-07:** PaidAt is stored in UTC (D-014); report periods are Asia/Ho_Chi_Minh calendar days, months, quarters and years, converted to UTC half-open bounds before filtering. Refunds are out of scope (D-011 approved). |
| Consequences and risks | Every UC06 query, summary and oracle follows this definition. Changing it later invalidates evidence. |
| Approved decision (2026-11-10) | The nine rules of the Owner Directive "Accept Loyalty & Implement UC06 Revenue Correctness" §4, for isolated Person 3 development: (1) revenue is recognised only from successfully paid invoices (`PaymentStatus = 'PAID'`); (2) the recognised amount is `INVOICE.FinalAmount`; (3) the recognition timestamp is `INVOICE.PaidAt`; (4) reporting periods are interpreted on the Asia/Ho_Chi_Minh calendar; (5) `PaidAt` stays stored in UTC; (6) revenue is attributed to `INVOICE.Branch_ID`; (7) PENDING and CANCELLED invoices are excluded; (8) refund processing stays out of the approved scope (D-011); (9) company-wide revenue is the sum of the qualifying branch revenue under the same filters and reporting period. Consequence of rules 1–3, not a new rule: the whole `FinalAmount` is recognised at the payment time, so service-plan revenue is not spread over the plan's validity (this is the "recognised at sale" alternative of this record and of [C.5](design/P0_FINAL_DECISION_PACKAGE.md#c5-revenue-recognition-directive-66)). |
| Compatibility check (2026-11-10) | Each rule was compared with the alternatives above and with the sources. **No conflict.** Amount: FinalAmount is one of the two recorded alternatives (rule 2). Status: PAID only (rules 1, 7; D-005 literals, DEP-08). Date: PaidAt (rule 3; D-004 approved T2). Time zone: UTC storage with Asia/Ho_Chi_Minh reporting (rules 4, 5; D-014 approved T2). Branch: issuing branch `INVOICE.Branch_ID` (rule 6; BR08). Refunds: out of scope (rule 8; D-011 approved T2). System revenue = Σ branches (rule 9; C.5). Sources: S-02 (Phase 1 report, md5 `e75dccfd126d`, re-read on 2026-11-10): "doanh thu" is used without a definition; F27 "Doanh thu chi nhánh" 120/day and F28 "Doanh thu hệ thống" 20/day; `INVOICE(…, IssuedAt, GrossAmount, DiscountAmount, FinalAmount, PaymentMethod, PaymentStatus)`; BR08 (one branch per invoice). S-01 (official assignment): the file is the audited version (md5 `90134711b47a` re-verified on 2026-11-10); its text was **not re-read** because it is password-protected and the password is not stored, so the check relies on the audit recorded in [00 §4](00_SOURCE_AND_SCOPE.md) (Problem 3; suggested reports: branch revenue by day/month/quarter/year, system revenue with branch comparison; no revenue definition, no refund rule). No source defines revenue differently, and the rules select only alternatives already recorded here. |
| Status | **APPROVED (provisional, T2)** — for isolated Person 3 development. Team reconciliation is required before integration, a merge into the shared `main` branch or any shared-database change (approval rule 3). |
| Blocker class | BLOCKING_UC06 (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: BLOCKING_FEATURE ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | Project Owner / 2026-11-10 (provisional under T2) |
| Reference | Owner Directive "Accept Loyalty & Implement UC06 Revenue Correctness" (Claude Code session of 2026-11-10), §4 |
| Open under this decision | The display of branches without revenue in a period is not part of D-010: the routines follow the default of [07 §2](07_UC06_REVENUE_PLAN.md#2-revenue-semantics-d-010-approved-provisional-t2-2026-11-10) (no row; a single-branch or system total returns 0), still `ASSUMPTION_PENDING_APPROVAL`. |
| Related | G-11; T-F06-01…T-F06-05, T-F06-09…T-F06-13, T-REC-05; [WO-P3-P4-01 §13](work-orders/WO-P3-P4-01_UC06_INDEX_EXPERIMENTS.md#13-execution-record) |

## D-011 — Cancellation and refund scope

| Field | Content |
|---|---|
| Problem | No source covers them (G-09). |
| Alternatives | (a) Cancellation of PENDING invoices only. (b) (a) + full refunds of PAID invoices with reversal of points, spending and revenue. (c) Neither. |
| Evidence and constraints | No requirement in S-01 or S-02. Refunds add a state, reversal logic and tests. |
| Recommended choice | TECHNICAL_RECOMMENDATION: (a). Refunds are out of scope for the Phase 2 core and are listed as a limitation unless the team requires them. |
| Consequences and risks | The report must state the limitation. |
| Approved decision | Cancellation is allowed only before successful settlement (PENDING→CANCELLED). Refund processing is excluded from the current implementation scope. |
| Status | **APPROVED (provisional, T2)** |
| Blocker class | BLOCKING_P1 (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: BLOCKING_P1 ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | Project Owner / 2026-11-07 (provisional under T2: team approval required before integration or merge) |
| Reference | Owner Directive "Final P0 Decision Resolution" (Claude Code session of 2026-11-07), §3 (B2) |
| Related | G-09; T-F05-16, T-F05-17 |

## D-012 — Settlement transaction boundary and ownership

| Field | Content |
|---|---|
| Problem | Settlement must be consistent with entitlements, inventory, points and spending (S-02 §7.2), which belong to different owners (G-12, G-13). |
| Alternatives | (a) One transaction in one orchestrating procedure that calls per-owner sub-steps (inventory decrement, entitlement activation, loyalty, revenue) in a fixed lock order. (b) Separate transactions with compensation. (c) An AFTER UPDATE trigger on INVOICE status that performs all effects. |
| Evidence and constraints | §7.2 consistency; BR30 (no negative stock, atomic check). Triggers hide cost and ordering. |
| Recommended choice | TECHNICAL_RECOMMENDATION: (a). (b) is rejected because it violates §7.2 atomicity. (c) is not recommended for the main flow. The orchestrator's owner is a team choice; P3 is the natural owner if six-UC UC05 = "invoice settlement". The interface goes into the integration contract (DL-02). |
| Consequences and risks | Cross-member coupling, so the contract and lock order must be agreed before any code (R-04). **Update 2026-11-07:** moved out of the P1 set: it shapes routines and the integration contract (WO-P3-P1-02), not tables. |
| Scope note (2026-11-07) | INVOICE and both item tables are now P3-owned and UC05 includes billing, so invoice creation and finalisation are P3 responsibilities. Still open here: whether the sale flows of other members (plan sale, product sale) call a P3 billing interface, and who orchestrates settlement with the excluded inventory workflow (BRANCH_INVENTORY stays out of P3 scope and is reached only through an agreed hook). |
| Approved decision (2026-11-09) | Alternative **(a)**, provisionally (T2) for isolated work: the P3 routine `usp_P3_SettleInvoice` owns ONE settlement transaction and calls the inventory-decrement (UC04 owner) and entitlement-activation (UC01 owner) steps inside it, in the proposed lock order of [12 §6](12_INTEGRATION_PLAN.md#6-global-lock-order-proposal), with the composition rules of 12 §4. In isolated databases the two steps are TEST_ONLY contract-only test doubles (call log and on-request failure; no stock or entitlement logic; DEP-05). Alternatives (b) (separate transactions with compensation) and (c) (trigger) are not used. The team confirms the orchestrator, the hook interface and the lock order at P6 (WO-P3-P1-02); the real routines are tested in WO-P3-P6-01 (T-INT-01/02, T-CONC-05). No shared-database change, push or merge is authorized by this approval. |
| Status | **APPROVED (provisional, T2)** |
| Blocker class | BLOCKING_UC05 (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: BLOCKING_P1 ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | Project Owner / 2026-11-09 (provisional under T2: team approval required before integration or merge) |
| Reference | Owner Directive "Close Invoice Creation and Prioritize Settlement" (Claude Code session of 2026-11-09), §4; the Owner's answer to the decision question asked in that session ("Approve (a), T2") |
| Implementation | WO-P3-P3-01 (2026-11-09): `db/procedures/usp_P3_SettleInvoice.sql`; doubles `tests/db/doubles/D001__TEST_ONLY_settlement_hook_doubles.sql`; T-F05-21, T-F05-22 PASS |
| Timing update (2026-11-08, D-027) | The team decision is taken in WO-P3-P1-02 at P6. Before WO-P3-P3-01, the Project Owner may approve alternative (a) **provisionally (T2)** for isolated work: P3 orchestrates the settlement transaction and calls the inventory and entitlement steps through contract-only test doubles with the interface of [12 §5](12_INTEGRATION_PLAN.md#5-settlement-orchestration-interface-proposal) (DEP-05 in [12 §2b](12_INTEGRATION_PLAN.md#2b-dependency-register-interim-assumptions-until-p6)). The real routines are verified at P6 (T-INT-01/02, T-CONC-05). |
| Related | G-12, G-13; WO-P3-P1-02; [12_INTEGRATION_PLAN.md](12_INTEGRATION_PLAN.md) |

## D-013 — `SpendingMonth` representation

| Field | Content |
|---|---|
| Problem | The month key format is undefined (G-16). |
| Alternatives | (a) DATE fixed to the first day of the month, with CHECK `DAY(SpendingMonth) = 1`. (b) INT yyyymm. (c) CHAR(7) 'YYYY-MM'. |
| Evidence and constraints | Window queries need range arithmetic. (a) works with date functions and half-open ranges. |
| Recommended choice | TECHNICAL_RECOMMENDATION: (a). |
| Consequences and risks | All writers must normalise to the first day of the month; the CHECK enforces it. |
| Reconciliation (2026-11-07) | Original question: the representation of the month key of MEMBER_MONTHLY_SPENDING (G-16). Original alternatives (a) DATE first day of the month with CHECK `DAY(SpendingMonth) = 1`, (b) INT yyyymm, (c) CHAR(7) 'YYYY-MM'; recommended (a). **Gap found:** the original wording does not say which calendar defines "the month". With UTC storage (D-014 approved 2026-11-07), a payment made between 00:00 and 06:59 local time on the 1st falls in the previous month if the UTC calendar is used. **Content proposed for approval:** (a), plus "SpendingMonth = first day of the Asia/Ho_Chi_Minh calendar month that contains PaidAt". Approval requirement: Project Owner alone (P3-owned table). P1 needs only the DATE type and the CHECK; the month rule is applied by the UC05 routines and the seed. |
| Approved decision | `SpendingMonth` uses `DATE`. It stores the first day of the Asia/Ho_Chi_Minh calendar month that contains the successful payment timestamp (`PaidAt`, stored in UTC). The schema enforces the first-day-of-month invariant (CHECK `DAY(SpendingMonth) = 1`). |
| Status | **APPROVED** |
| Blocker class | BLOCKING_P1 (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: BLOCKING_P1 ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | Project Owner / 2026-11-07 |
| Reference | Owner Directive "Strict Person 3 Scope Enforcement" (Claude Code session of 2026-11-07), §4 |
| Related | G-16; RQ-P07 |

## D-014 — Money, key and timestamp types; time zone

| Field | Content |
|---|---|
| Problem | No physical types exist; they must be consistent across members (G-15). |
| Alternatives | Money: DECIMAL(18,2), DECIMAL(18,0), MONEY, BIGINT. Keys: INT vs BIGINT. Time: DATETIME2(0/3) local vs DATETIMEOFFSET vs UTC. |
| Evidence and constraints | Volumes: 324k invoices/year, 30k members, 12 branches (S-02). VND has no minor unit in practice. Narrow keys keep indexes small. |
| Recommended choice | **Superseded on 2026-11-07 by the approved decision below (timestamps stored in UTC).** Original recommendation, kept for the record: TECHNICAL_RECOMMENDATION: money DECIMAL(18,2), with amounts rounded to whole VND at line level (never FLOAT/REAL; avoid MONEY because of rounding in division). Keys INT (IDENTITY where surrogate). Timestamps DATETIME2(3) in local time (Asia/Ho_Chi_Minh, UTC+7, no DST). All period filters use half-open ranges `[from, to)`. |
| Consequences and risks | Shared by every member, so it must be agreed team-wide before DDL (R-03). |
| Approved decision | Identifiers `INT` where appropriate; money `DECIMAL(18,2)`; transaction timestamps `DATETIME2(3)` **stored in UTC**; business reporting time zone **Asia/Ho_Chi_Minh** (UTC+7, no daylight saving); Phase 1 naming kept unless a justified change is approved. **This differs from the earlier recommendation (local-time storage).** Consequences: timestamp defaults use `SYSUTCDATETIME()`; reporting periods and spending months are defined in the Asia/Ho_Chi_Minh calendar and converted to UTC bounds before filtering, so predicates stay SARGable (the column is never converted). Text, date, time and small-integer types and IDENTITY generation are physical refinements listed in WO-P3-P1-01 §3.3 and §3.7, approved with that WO and reviewed by the team. |
| Status | **APPROVED (provisional, T2)** |
| Blocker class | BLOCKING_P1 (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: BLOCKING_P1 ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | Project Owner / 2026-11-07 (provisional under T2: team approval required before integration or merge) |
| Reference | Owner Directive "Final P0 Decision Resolution" (Claude Code session of 2026-11-07), §2 (B1) |
| Related | G-15; RQ-T01 |

## D-015 — Revenue summary structure

| Field | Content |
|---|---|
| Problem | Whether a derived revenue structure is justified (RQ-A11). |
| Alternatives | (a) None (indexes only). (b) Branch × day summary (≈ 12 × 365 = 4,380 rows/year); answers day, month, quarter and year. (c) Branch × month summary (144 rows/year); cannot answer daily reports. (d) Indexed view grouped by Branch_ID and payment date. |
| Evidence and constraints | S-01 §4 requires day/month/quarter/year, which favours (b) or (d) over (c). Problem 3 explicitly allows "summary table or View/Trigger". S-09 says to measure the indexed baseline first. |
| Recommended choice | DEFERRED until WO-P3-P4-01 shows the indexed baseline cost and WO-P3-P4-02 measures the alternatives. |
| Consequences and risks | Derived data must be reconciled (T-REC-03) and adds write cost (T-PERF-06). |
| Status | DEFERRED |
| Blocker class | DEFERRED (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: DEFERRED ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | — / — |
| Related | WO-P3-P4-02 |

## D-016 — Summary maintenance mechanism

| Field | Content |
|---|---|
| Problem | How a summary (if adopted) stays correct. |
| Alternatives | (a) Inside the settlement procedure. (b) AFTER trigger on INVOICE. (c) Scheduled rebuild (stale between runs). (d) Engine-maintained indexed view. |
| Evidence and constraints | A branch-day row is updated by every settlement of that branch: about 75 per branch per day on average (900/12), a low-contention hot spot. Course problem 3 mentions View/Trigger. |
| Recommended choice | DEFERRED with D-015. The prior expectation (TECHNICAL_RECOMMENDATION) is (a) or (d), because they are visible and transactional. |
| Consequences and risks | Wrong maintenance means drift (R-16). |
| Status | DEFERRED |
| Blocker class | DEFERRED (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: DEFERRED ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | — / — |
| Related | WO-P3-P4-02 |

## D-017 — Partition INVOICE

| Field | Content |
|---|---|
| Problem | Whether partitioning helps P3 workloads (RQ-A11). |
| Alternatives | No partitioning; monthly, quarterly or yearly RANGE RIGHT on the recognition timestamp; partition only a benchmark copy as a PoC. |
| Evidence and constraints | 27k rows/month (S-02). Key/alignment problems ([09 §6](09_PARTITION_FEASIBILITY_PLAN.md#6-keys-constraints-and-alignment)). S-09 expects no benefit at this scale. |
| Recommended choice | DEFERRED until WO-P3-P5-01 delivers measured evidence. Production-schema partitioning is not planned unless the evidence passes [09 §11](09_PARTITION_FEASIBILITY_PLAN.md#11-decision-criteria). |
| Consequences and risks | Partitioning the shared INVOICE changes its PK and FKs (R-13). |
| Status | DEFERRED |
| Blocker class | DEFERRED (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: DEFERRED ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | — / — |
| Related | WO-P3-P5-01 |

## D-018 — INVOICE clustered key and surrogate key type

| Field | Content |
|---|---|
| Problem | Choose the clustered index and key type of the shared INVOICE table. |
| Alternatives | (a) Clustered PK on Invoice_ID (INT IDENTITY, ever-increasing). (b) Clustered on (PaidAt/IssuedAt, Invoice_ID) with a nonclustered PK. (c) BIGINT Invoice_ID. |
| Evidence and constraints | Course seminar: the PK becomes the clustered index by default (S-07 p11). Line tables reference Invoice_ID. Range reports can be served by nonclustered covering indexes. |
| Recommended choice | TECHNICAL_RECOMMENDATION: (a); revisit only if D-017 adopts partitioning. |
| Consequences and risks | Range scans on time need nonclustered indexes (evaluated in [08](08_INDEX_AND_QUERY_PLAN.md)). |
| Approved decision | Initial clustered primary key of INVOICE on `Invoice_ID` (`INT`). No partitioned INVOICE indexes in P1; revisit only if D-017 adopts partitioning. |
| Status | **APPROVED (provisional, T2)** |
| Blocker class | BLOCKING_P1 (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: BLOCKING_P1 ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | Project Owner / 2026-11-07 (provisional under T2: team approval required before integration or merge) |
| Reference | Owner Directive "Final P0 Decision Resolution" (Claude Code session of 2026-11-07), §2 (B1) |
| Related | D-014, D-017 |

## D-019 — Isolation and concurrency strategy

| Field | Content |
|---|---|
| Problem | Correctness under concurrent settlements, and blocking between reports and writes (G-23). |
| Alternatives | (a) Default READ COMMITTED (locking); the write path uses conditional updates and UPDLOCK/HOLDLOCK where needed. (b) Enable READ_COMMITTED_SNAPSHOT for the database (team-wide) so report readers do not block writers. (c) SERIALIZABLE for settlement (excess locking). |
| Evidence and constraints | S-02 §5.3. A database option affects every member. |
| Recommended choice | TECHNICAL_RECOMMENDATION: (a) for P3 write correctness, independent of (b). (b) is a team choice to be measured. (c) is not recommended. Correctness must never depend on the isolation option alone. |
| Consequences and risks | (b) uses the tempdb version store and changes read semantics for every member. |
| Approved decision (2026-11-09) | Alternative **(a)** for the P3 write path, provisionally (T2): default READ COMMITTED (locking); the settlement and cancellation routines read the invoice row with UPDLOCK and change its status only by a conditional update (`WHERE PaymentStatus = 'PENDING'`, exactly one row); the MEMBER_MONTHLY_SPENDING upsert uses UPDLOCK + HOLDLOCK (no unguarded check-then-insert, no MERGE); TotalSpend, PointsEarned and CurrentPoints change only by atomic increments; deadlock victims are retried only at the outermost level. Alternative (b) (database-wide READ_COMMITTED_SNAPSHOT) remains a **team** choice (DEP-12) and is not decided here; correctness must not depend on it. Alternative (c) (SERIALIZABLE for settlement) is not used. |
| Status | **APPROVED (provisional, T2)** — alternative (a); (b) open as a team choice |
| Blocker class | BLOCKING_UC05 (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: BLOCKING_FEATURE ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | Project Owner / 2026-11-09 (provisional under T2: team approval required before integration or merge) |
| Reference | Owner Directive "Close Invoice Creation and Prioritize Settlement" (Claude Code session of 2026-11-09), §4–§5; the Owner's answer to the decision question asked in that session ("Approve (a)") |
| Implementation | WO-P3-P3-01 (2026-11-09): T-CONC-01 and T-CONC-02 (3 runs each) PASS on final database state; no deadlock observed |
| Related | G-23; T-CONC-xx |

## D-020 — Application stack and P3 feature surface

| Field | Content |
|---|---|
| Problem | P6 cannot be planned in detail (G-21). |
| Alternatives | ASP.NET Core web; WinForms (.NET); Node.js web. All are allowed by S-01 ("web/winform"). .NET SDK and Node.js exist locally. |
| Recommended choice | TEAM_DECISION, required and not yet made. P3 minimum surface (TECHNICAL_RECOMMENDATION): invoice list/detail, confirm payment, member loyalty view, tier distribution (if D-001 assigns it), revenue reports by branch/system and grain. |
| Status | PROPOSED |
| Blocker class | BLOCKING_INTEGRATION (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: BLOCKING_FEATURE ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | — / — |
| Related | G-21; WO-P3-P6-01 |

## D-021 — Repository, layout, version-control workflow

| Field | Content |
|---|---|
| Problem | The working folder is not a Git repository; no team repository was known (G-19). **Update 2026-11-07:** the Project Owner named the canonical repository `Phuoc-IT-2106/CSDLNC-DA` (branch `main`). It is public, has one commit and only a README ([P0 final package §E](design/P0_FINAL_DECISION_PACKAGE.md#e-repository-readiness)). |
| Alternatives | (a) Initialise Git in `C:\CSDLNC- DA` and link the team remote. (b) Clone the team's existing repository and move these docs into it. (c) No VCS (rejected). |
| Recommended choice | TECHNICAL_RECOMMENDATION: (b) if a team repository exists, otherwise (a). Use the implementation layout in [05 §13](05_PHYSICAL_DESIGN_PLAN.md#13-proposed-implementation-layout-not-created). P3 works on branches named `p3/<work-order-id>`. Merging requires team review. **P3 never commits or pushes without explicit authorization.** **Updated 2026-11-07:** (b) applies. Local working copy `C:\Users\DELL\source\repos\CSDLNC-DA` (cloned read-only on 2026-11-07). Single working copy: at WO-P3-P1-01 step 0 the planning documents are copied unchanged into the clone, and `C:\CSDLNC- DA` becomes a read-only archive. Migrations in `db/migrations/V###__name.sql`; `.gitignore` and `.gitattributes` per the package §E.3. Repository visibility (currently public) is decided before the first push. |
| Reconciliation (2026-11-07) | Original question: repository, layout and version-control workflow, when the folder was not a Git repository and no team repository was known (G-19). Original alternatives: (a) initialise Git in `C:\CSDLNC- DA`; (b) clone the team repository and **move** the documents into it; (c) no VCS. Since 2026-11-07: the team repository exists, so (a) is superseded, and the Owner requires the original workspace and the clean clone to be preserved, so (b) becomes clone and **copy** (non-destructive). The approval requirement was inconsistent (index "Yes" vs. "Owner approves P3's working arrangement"). It is split into two parts. **Part A — P3 working arrangement (Project Owner; needed before WO-P3-P1-01):** `C:\CSDLNC- DA` is authoritative until the cut-over; the cut-over (WO-P3-P1-01 step 0) copies the documents unchanged into the clone on branch `p3/wo-p3-p1-01` and adds a marker file `ARCHIVED_SEE_REPOSITORY.md` to the old root; afterwards only the clone is edited, so at any time exactly one editable master prompt and decision log exist; P3 branches are `p3/<wo-id>`; P3 files use the proposed layout on its local branch; commits, pushes, PRs and visibility changes only with explicit authorization. **Part B — shared repository conventions (team and repository owner; needed before the first push, not before P1):** layout `docs/agent/`, `docs/phase2/person3/`, `db/migrations/`, `db/build/`, `tests/db/`; `.gitignore`, `.gitattributes` and file-safety rules ([P0 final package §E](design/P0_FINAL_DECISION_PACKAGE.md#e-repository-readiness)); review by another member before merge; repository visibility (recommended: private while the course runs). |
| Approved decision (Part A) | One authoritative working copy after a controlled local cut-over. The existing planning workspace `C:\CSDLNC- DA` is preserved as an **immutable** backup and archive (so the marker file proposed in the reconciliation is dropped; later sessions are redirected through the agent memory and the context index instead). The canonical GitHub clone `C:\Users\DELL\source\repos\CSDLNC-DA` is the intended working repository. Feature branches are named `p3/<work-order-id>` (created by the work order that needs them). No commit, push or merge is authorized by this decision. Sensitive source documents and secrets are not copied to a public repository without review. Part B (shared layout, ignore rules, review rule, visibility) stays PROPOSED for the team and the repository owner. |
| Status | **APPROVED (Part A)**; Part B PROPOSED |
| Blocker class | BLOCKING_P1 (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: BLOCKING_P1 ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | Project Owner / 2026-11-07 (Part A); Part B — / — |
| Reference | Owner Directive "Strict Person 3 Scope Enforcement" (Claude Code session of 2026-11-07), §4 |
| Related | G-19; WO-P3-P0-02 |

## D-022 — Benchmark dataset tiers, seed tool, acceptance thresholds

| Field | Content |
|---|---|
| Problem | Reproducible, large-enough data and objective adopt/reject rules (G-17). |
| Alternatives | Seed tool: T-SQL set-based with deterministic hashing; Python with a fixed seed (no DB driver installed; would need installation); a third-party generator (S-01 cites guru99). Thresholds: relative only, or absolute targets. |
| Recommended choice | TECHNICAL_RECOMMENDATION: dataset tiers DS-S/M/L/XL ([10 §3](10_SEED_AND_BENCHMARK_PLAN.md#33-dataset-tiers)); T-SQL deterministic generation (no new dependencies). Default adopt/reject thresholds ASSUMPTION_PENDING_APPROVAL as in [08 §6](08_INDEX_AND_QUERY_PLAN.md#6-adoption-and-rejection-criteria). |
| Approved decision | A deterministic, reproducible large dataset for Person 3, using the Phase 1 workload as the reference. Full-scale targets: INVOICE ≈ 324,000 rows over 12 complete calendar months; INVOICE_PRODUCT_ITEM ≈ 712,800; INVOICE_SERVICE_ITEM ≈ 64,800; MEMBER_MONTHLY_SPENDING derived from the eligible PAID invoices. The generator supports a small smoke-test scale and the full benchmark scale, a fixed seed (or equivalent deterministic generation), configurable volume, valid foreign keys, realistic distributions of branches, members, dates and items, correct payment states and amounts, correct monthly spending and points, repeatable validation queries and a documented dataset manifest. No inventory, PT, check-in or payroll data; shared fixture data minimal and TEST_ONLY. Tool: set-based T-SQL (no new dependency). **Not covered by this approval:** the index adoption and rejection thresholds of [08 §6](08_INDEX_AND_QUERY_PLAN.md#6-adoption-and-rejection-criteria) remain proposed defaults, to be confirmed before WO-P3-P4-01. |
| Status | **APPROVED** (dataset and generator) |
| Blocker class | BLOCKING_UC05 (also UC06) (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: BLOCKING_FEATURE ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | Project Owner / 2026-11-08 |
| Reference | Owner Directive "Approve P1 and Execute P2-01" (Claude Code session of 2026-11-08), §3 |
| Related | G-17; WO-P3-P2-01, WO-P3-P2-02 |

## D-023 — Invoice totals rule and discount allocation

| Field | Content |
|---|---|
| Problem | Header vs line amounts are undefined (G-13, G-14). |
| Alternatives | (a) Header DiscountAmount = Σ line discounts (no separate invoice-level discount). (b) Header discount = Σ line discounts + an invoice-level discount, allocated pro rata to lines for line reports. (c) Line reports use line net amounts and state that header-only discounts are excluded. |
| Recommended choice | TECHNICAL_RECOMMENDATION: (a). Then GrossAmount = Σ service UnitPrice + Σ product UnitPrice × Quantity; DiscountAmount = Σ line DiscountAmount; FinalAmount = GrossAmount − DiscountAmount ≥ 0. Enforce it at invoice finalisation, plus a header CHECK (FinalAmount = GrossAmount − DiscountAmount, FinalAmount ≥ 0). **Clarified 2026-11-07:** the header CHECKs are GrossAmount ≥ 0 and 0 ≤ DiscountAmount ≤ GrossAmount, and FinalAmount stays a stored column (not computed) so that other members' inserts keep working. The rule also covers the line constraints it relies on: UnitPrice ≥ 0, 0 ≤ line DiscountAmount ≤ line gross, Quantity > 0. |
| Consequences and risks | Shared with the invoice-creation owner (UC01/UC04). |
| Approved decision | `GrossAmount ≥ 0`; `DiscountAmount ≥ 0`; `DiscountAmount ≤ GrossAmount`; `FinalAmount = GrossAmount − DiscountAmount`; `FinalAmount ≥ 0`; product `Quantity > 0`; item `UnitPrice` and `DiscountAmount` valid and non-negative; an item discount never exceeds the eligible item total; existing service-validity (BR13) and PT-session rules preserved. Row-level rules are CHECK constraints. Header = Σ items is a **cross-table** invariant: a normal CHECK constraint cannot enforce it; it is enforced inside the invoice-finalisation transaction and verified by a validation query (WO-P3-P1-01 §3.4). |
| Status | **APPROVED (provisional, T2)** |
| Blocker class | BLOCKING_P1 (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: BLOCKING_P1 ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | Project Owner / 2026-11-07 (provisional under T2: team approval required before integration or merge) |
| Reference | Owner Directive "Final P0 Decision Resolution" (Claude Code session of 2026-11-07), §4 (B3) |
| Related | G-13, G-14; RQ-A16 |

## D-024 — Point balance semantics

| Field | Content |
|---|---|
| Problem | Is CurrentPoints a spendable balance (G-18)? |
| Alternatives | (a) Accrual only, no redemption or expiry in Phase 2. (b) Redemption, which needs a points ledger. (c) Expiry, which needs dated point lots. |
| Recommended choice | TECHNICAL_RECOMMENDATION: (a). Invariant: CurrentPoints = Σ PointsEarned over all MEMBER_MONTHLY_SPENDING rows of the member. **Update 2026-11-07:** classified OUT_OF_SCOPE. No source requires redemption or expiry; the existing schema is sufficient for earning and tier management; a ledger, if ever required, would be an additional table and changes no P1 table. |
| Approved decision | Loyalty point redemption, point expiration, and any redemption-specific tables or workflows are **excluded** from the current P3 scope. Consistency check: S-01 — no redemption or expiry rule was found in the 2026-11-06 audit (the PDF was not re-read on 2026-11-07 because its password is not stored); S-02 — a text search of the .docx on 2026-11-07 found no redemption or expiry terms, and §2.6 describes accrual only; S-11 (P3 allocation summary) — loyalty points and tier management only. If the six-UC allocation (S-10) or a re-read of S-01 shows such a requirement, this approval is reopened. |
| Status | **APPROVED** |
| Blocker class | OUT_OF_SCOPE (2026-11-07). Exact question, affected tables, approver and consequence of deferral: [P0 final package, Annex 1](design/P0_FINAL_DECISION_PACKAGE.md#annex-1--decision-register-directive-5). Earlier class: BLOCKING_P1 ([P0 review §3](design/P0_DECISION_REVIEW.md#3-decision-classification)). |
| Approver / date | Project Owner / 2026-11-07 |
| Reference | Owner Directive "Final P0 Decision Resolution" (Claude Code session of 2026-11-07), §7 |
| Related | G-18; T-REC-02 |

## D-025 — Database topology for P3 development, testing and benchmarking

| Field | Content |
|---|---|
| Problem | The master prompt v2.0 §11 says: "Do not create a separate database or competing application framework merely for Person 3." The work orders created by WO-P3-BOOT-001 assumed dedicated P3 development/test/benchmark databases. The two must be reconciled (master prompt §2: report the conflict and record a decision). |
| Alternatives | (a) Use only the team's shared database, for development, tests and benchmarks alike. (b) Deploy the **team's own schema scripts** into additional, disposable test/benchmark databases (same schema, not a P3-specific design), while the application uses only the team database. (c) A P3-only database with its own schema (contradicts §11). |
| Evidence and constraints | Benchmarks need a controlled, restorable dataset and exclusive use during timed runs ([10 §4.3](10_SEED_AND_BENCHMARK_PLAN.md#43-measurement-protocol)). Concurrency and fault-injection tests create temporary test-only objects ([06 §4.8](06_UC05_BILLING_LOYALTY_PLAN.md#48-transaction-rollback)), which must not disturb teammates. No team database exists yet (S-12, S-13). |
| Recommended choice | TECHNICAL_RECOMMENDATION: (b). The application and integration use the team database. Isolated databases are allowed only as disposable copies built from the team schema scripts, for tests and benchmarks, and are named in each WO approval. (The original recommendation also allowed a labelled stand-in schema until a team schema exists. **That part is superseded** by approved conditions 2–3: no P3-private stand-in schema.) (c) is rejected by master prompt §11. |
| Consequences and risks | (a) risks interfering with teammates and non-reproducible benchmarks (R-07). (b) needs the schema scripts to be re-runnable (T-REPRO-01). |
| Approved decision | (b), with the owner's seven conditions below. |
| Conditions (binding) | 1. The shared team database remains the canonical integration database. 2. Test and benchmark databases must derive from the approved shared schema and migrations. 3. Independent test databases must not evolve into incompatible Person 3 implementations. 4. Destructive, rollback, concurrency and performance experiments must run in isolated environments. 5. Benchmark environments and datasets must be documented and reproducible. 6. Experimental indexes, partitions and schema changes must not automatically propagate into the shared database. 7. No shared database modifications are authorized by this decision. |
| Status | **APPROVED** (with constraints) |
| Approver / date | Project Owner / 2026-11-06 |
| Reference | "Owner Directive — P3 Planning Approval & P0 Decision Freeze", §2 (Claude Code session of 2026-11-06) |
| Related | G-24 (closed); master prompt §11; all WO "Target database" fields; R-23 |

## D-026 — Shared dependencies for isolated P1 development (restricted)

| Field | Content |
|---|---|
| Problem | P1 readiness criterion P1-R6 requires an approved shared base schema and migrations. None exist: no member has published DDL, and the canonical repository contains only a README. D-025 conditions 2–3 require isolated databases to derive from the approved shared schema and forbid a P3-private stand-in. Without a resolution, P1 cannot build any test database. (Added 2026-11-07 by Owner Directive WO-P3-P0-FINAL.) |
| Alternatives | (a) Wait until the team publishes base migrations. (b) P3 writes migration V001 as a **faithful physical translation of the approved Phase 1 §10 logical schema** for the 10 tables P3 depends on (MEMBER_TIER, MEMBER, MEMBER_MONTHLY_SPENDING, BRANCH, EMPLOYEE, SERVICE_PLAN, PRODUCT, INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM): names unchanged, types per D-014, only §10 keys and FKs plus Phase 1 BR constraints; P3 additions in a separate V002; isolated use only; labelled "PROPOSED shared baseline" until the team ratifies it in the pull request. (c) Minimal stub parents with key columns only. (d) P3 writes the whole §10 schema (25 tables). |
| Evidence and constraints | D-025 conditions 2, 3, 6, 7; S-02 §10 is the team-approved logical schema (precedence level 2); master prompt §5 (no independent change of shared keys or interfaces); repository baseline in the [P0 final package §E](design/P0_FINAL_DECISION_PACKAGE.md#e-repository-readiness). |
| Recommended choice | TECHNICAL_RECOMMENDATION: (b). It is compatible with the approved schema by construction, changes no key or name, and leaves the domain rules of other members' tables to their owners. (a) blocks P1 on others' availability. (c) is a stand-in that contradicts D-025 condition 3. (d) builds other members' domains (check-in, PT, payroll). If the team publishes its own baseline, P3 rebases onto it and runs T-INT-03. |
| Consequences and risks | The team may change V001 types or nullability, so P1 needs small rework before merge (R-03). V001 must never be read as P3 owning those tables. |
| Owner direction and reconciliation (2026-11-07) | The Owner **authorized planning** (not implementation) of a controlled shared-schema DDL foundation in an isolated environment, under 7 conditions: (1) derive all definitions from the actual Phase 1 relational schema and approved amendments; (2) include only the shared dependencies required to establish correct constraints and FKs; (3) preserve established naming, keys and relationships; (4) no incompatible Person-3-only business models; (5) keep experimental implementation separate from the shared database; (6) record all deviations from Phase 1; (7) team review before integrating shared-schema changes. The Owner did **not** approve the implementation contract. Reconciliation: alternative (b) satisfies conditions 1–5 and 7; condition 6 is met by the deviation register in WO-P3-P1-01 §3.7; condition 2 is shown table by table in WO-P3-P1-01 §3.2. **Content proposed for approval:** the implementation contract is WO-P3-P1-01 §3.2–§3.7 (10 tables, columns, constraints, deviation register), for isolated use only. Approval requirement: Project Owner for isolated use; team review before integration or merge. |
| Approved decision (restricted scope) | D-026 is approved **only** under this scope: (1) implement the four Person 3-owned tables (INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM, MEMBER_MONTHLY_SPENDING) according to the approved logical model and physical-design decisions; (2) use the approved shared schema when available; (3) if it is unavailable, create only the minimum dependency fixtures necessary to satisfy foreign keys and execute isolated tests; (4) mark all dependency fixtures explicitly as TEST_ONLY; (5) derive fixture columns, keys and relationships from Phase 1, inventing no new domain structures; (6) no business logic or performance optimization for fixtures; (7) no modification of the shared team database; (8) fixture schemas are never the canonical implementation of another member's module; (9) replace fixtures with the approved team schema before final integration and re-run the relevant tests; (10) any shared-schema contract change needs team review before integration. D-026 does **not** authorize building all 25 Phase 1 entities or other members' modules. Alternative (b) (a faithful 10-table shared baseline written by P3) is **withdrawn**. The approved scope corresponds to alternative (c) with safeguards: the earlier objection to (c) under D-025 condition 3 is answered by conditions 4, 5, 8 and 9. D-025 itself is unchanged; for dependency fixtures in isolated P1 databases, this later and more specific Owner decision applies. Implementation contract: [WO-P3-P1-01 §3.2–§3.8](work-orders/WO-P3-P1-01_PHYSICAL_SCHEMA.md#32-scope-matrix-directive-strict-person-3-scope-enforcement) (five key-only fixtures in P1). |
| Status | **APPROVED (restricted scope)** |
| Blocker class | BLOCKING_P1 (2026-11-07). [P0 final package §B4](design/P0_FINAL_DECISION_PACKAGE.md#b4-p3-structure-and-workspace-d-013-d-021-d-026). |
| Approver / date | Project Owner / 2026-11-07 (team review before integration, condition 10) |
| Reference | Owner Directive "Strict Person 3 Scope Enforcement" (Claude Code session of 2026-11-07), §3 |
| Related | P1-R6; D-014, D-021, D-025; WO-P3-P1-01; R-03, R-23 |

## D-027 — Deferral of the formal integration contract (independent P2–P5 development)

| Field | Content |
|---|---|
| Problem | The roadmap made the integration contract (WO-P3-P1-02, team approval) a prerequisite of WO-P3-P3-01 and placed team items (seed ownership in DL-02, other members' hook routines, their regression queries, their approvals) inside P2–P4. The three members develop their modules independently, so these dependencies would block P3's own database work on other members' availability. |
| Alternatives | (a) Keep the contract in P1, before P3 (status quo). (b) Defer the formal contract to P6 and let P2–P5 proceed independently on the approved Phase 1 schema, the approved P3 physical schema, TEST_ONLY fixtures and contract-only test doubles, with a minimal dependency register. (c) Drop the formal contract. |
| Evidence and constraints | Master prompt §5 and §11 (respect shared interfaces; no independent change of shared keys); D-025 (isolated databases, no automatic propagation); D-026 restricted (key-only fixtures, no business logic); approval rule 3 (team approval before integration, merge or shared-database change). |
| Approved decision | (b). Execution order P1 → P2 → P3 → P4 → P5 → P6 → P7 → P8 ([15 §2](15_ROADMAP_AND_WORK_ORDERS.md#2-execution-order-and-dependencies)). WO-P3-P1-02 keeps its identifier and requirements; it stays `PROPOSED` and is executed at the start of P6 or immediately before the first operation that requires team integration ([15 §2.2](15_ROADMAP_AND_WORK_ORDERS.md#22-operations-that-require-team-integration-trigger-for-wo-p3-p1-02)). It is removed from the prerequisites of P2–P5. Work Order identifiers stay stable; dependencies are reordered, not renumbered. P2–P5 use the approved Phase 1 relational schema, the approved P3 physical schema, the existing eight foreign keys, the approved naming and type conventions, isolated SQL Server databases and the approved P3 business requirements. Shared tables are not redesigned and other members' business functions are not implemented. Shared-interface assumptions are kept in a minimal dependency register ([12 §2b](12_INTEGRATION_PLAN.md#2b-dependency-register-interim-assumptions-until-p6)), which is not the contract and blocks nothing. A shared dependency needed by a specific operation is represented by an explicitly isolated TEST_ONLY fixture or a contract-only test double, never by a simulated business workflow. Incompatibilities found in P2–P5 are recorded as integration risks and escalated immediately only if they make the current implementation invalid or unsafe. No shared database change happens without the required team approval. Each WO still needs its own approval; WO-P3-P1-01 stays `VERIFIED` until the Owner accepts it. |
| Consequences and risks | Integration findings arrive later, so P6 may require rework (R-26). Mitigation: the dependency register is reviewed at every gate; P3 logic stays in database routines; the real-routine tests (T-INT-01/02, T-CONC-05, T-REG-03) are planned explicitly in WO-P3-P6-01. Earlier approvals (D-002…D-026) are unchanged. |
| Status | **APPROVED** |
| Blocker class | — (roadmap governance; unblocks P2–P5) |
| Approver / date | Project Owner / 2026-11-08 |
| Reference | Owner Directive "Reprioritize Person 3 Implementation" (Claude Code session of 2026-11-08), §1–§3, §8, §9 |
| Related | WO-P3-P1-02, WO-P3-P3-01, WO-P3-P6-01; D-012, D-025, D-026; R-03, R-04, R-26 |

## D-028 — Invoice creation (billing): responsibility, interface, finalisation, creation idempotency

| Field | Content |
|---|---|
| Problem | Since 2026-11-07 INVOICE and both item tables are P3-owned and UC05 includes billing, but no decision fixes how invoices are created and finalised, who calls the creation path, and whether a retried creation is prevented (D-003 left option C, the client request key, with the "invoice-creation owner", which is now P3). No work order covered invoice creation. |
| Questions and alternatives | **Q1 responsibility:** (a) P3 provides the only write path for INVOICE and its lines; other members' sale flows (plan sale, product sale) call it at P6. (b) Each sale flow inserts the rows itself (the D-023 invariant header = Σ lines then has several writers). **Q2 interface:** (a) one call with the header values and all lines (table-valued parameter), in one transaction. (b) Header first, then one call per line (needs a draft state that the D-005 domain does not contain). **Q3 finalisation:** (a) creation is finalisation: header totals are computed from the lines inside the same transaction (D-023), the invoice is created PENDING, and its lines are not changed afterwards; a correction is a cancellation (PENDING→CANCELLED, WO-P3-P3-01) plus a new invoice. (b) PENDING invoices stay editable (each edit re-totals; edits race with settlement). **Q4 line prices:** (a) the caller supplies `UnitPrice` and `DiscountAmount` per line; P3 does not read catalogue prices (catalogue management is out of scope; DEP-04). (b) P3 reads prices from PRODUCT/SERVICE_PLAN (needs non-key shared columns and a contract item). **Q5 creation idempotency:** (a) none in the database: a retried creation may produce a second PENDING invoice, which has no business effect and can be cancelled. (b) A client request key column with a UNIQUE constraint on INVOICE (additive migration V003 on a P3-owned table; D-003 option C). **Q6 side effects at creation:** none: no stock check, no entitlement, no points (inventory and activation are other members' functions, reached only at settlement through the hooks of D-012). |
| Evidence and constraints | D-003 (A) approved; D-005 domain {PENDING, PAID, CANCELLED}, `PaymentMethod` nullable before settlement; D-011 (cancellation in scope, no refunds); D-023 (totals; cross-table invariant enforced in the finalisation transaction, X1 in WO-P3-P1-01 §3.4); D-014 (UTC `IssuedAt`); BR12 (an invoice has at least one line); strict scope (no inventory, catalogue or service activation). |
| Recommended choice | TECHNICAL_RECOMMENDATION: Q1 (a), Q2 (a), Q3 (a), Q4 (a), Q6 as stated. Q5 is an Owner choice: (a) keeps the approved schema unchanged, and the risk is limited to a visible, cancellable duplicate PENDING invoice; (b) gives a database-level guarantee against retried creation at the cost of one column and one unique index, which must then be measured like any other index (write overhead). Recommended: (a) for the current scope, with (b) recorded as the alternative. |
| Consequences and risks | Q1 (a) makes P3's creation routine part of the integration contract (callers confirmed at P6; DEP-04). Q3 (a) keeps settlement simple (lines are fixed while the invoice is PENDING). Q5 (a) leaves duplicate-creation prevention to the application. |
| Owner direction (2026-11-08) | Q5: no global uniqueness constraint may reject legitimate distinct invoices that have identical business values (so no UNIQUE on business columns). Creation-request idempotency is reviewed separately in WO-P3-P3-00. The P1 schema is not changed for D-028 during P2. (Owner Directive "Approve P1 and Execute P2-01" (Claude Code session of 2026-11-08), §5) |
| Owner direction (2026-11-09) | Owner Directive "Urgent Unblock & Core Implementation" (Claude Code session of 2026-11-09), §6–§7: WO-P3-P3-00 is authorized; P3 implements invoice creation (header and service/product lines, validation of quantities, prices and discounts, consistent totals, approved payment-state semantics, one atomic transaction, rollback, a reliable identifier and outcome); **no** inventory, catalogue, service activation, PT, check-in or registration logic (Q6 directed); no uniqueness constraint based only on member, amount or timestamp; request-level idempotency that needs an unapproved schema change stays outside the accepted scope, and exactly-once creation must not be claimed (Q5). The directive does not approve D-028 itself. |
| Implementation (2026-11-09) | Implemented in the isolated database `FitLife_P3_UC05` following the recommended answers Q1 (a), Q2 (a), Q3 (a), Q4 (a) and Q5 (a) (no request key): `db/procedures/usp_P3_CreateInvoice.sql`; tests PASS ([WO-P3-P3-00 §13](work-orders/WO-P3-P3-00_INVOICE_CREATION.md#13-execution-record)). Q2 (b) is not implementable under approved D-005/D-023; Q4 (b) needs non-key catalogue columns that D-026 fixtures do not have. |
| Approved decision (2026-11-09) | All six sub-decisions resolved; no mandatory sub-decision remains open. **Q1 (a)** P3's creation routine is the write path for INVOICE and its lines in the current scope; whether it is the *only* path for other members' sale flows is confirmed with the team at P6 (contract, DEP-14). **Q2 (a)** one call with the header and all lines (table-valued parameters), one transaction. **Q3 (a)** creation is finalisation: header totals derived from the lines in the creation transaction (D-023), lines never edited afterwards; a correction = cancellation (PENDING→CANCELLED) + a new invoice. **Q4 (a)** caller-supplied `UnitPrice` and `DiscountAmount`, under four conditions: (1) the caller is an authorized, trusted component (least privilege, T-F05-26; roles at P6, DEP-14); (2) monetary values are validated (non-negative price and discount, discount ≤ line gross, quantity > 0, DECIMAL(18,2) range: errors 51105–51109); (3) header totals are calculated by the routine from the submitted lines (Gross, Discount, Final; X1 re-checked before commit, 51115); (4) **no claim is made that prices are validated against an authoritative product or service catalogue** — no such validation exists in P3. Validating prices against the catalogue is the **caller's integration requirement** (the plan- and product-sale flows of other members), recorded as DEP-04 in [12 §2b](12_INTEGRATION_PLAN.md#2b-dependency-register-interim-assumptions-until-p6); P3 implements no catalogue or inventory logic. **Q5 (a)** no creation-request deduplication in the database: distinct valid creation requests may create distinct invoices even when their values are identical (T-F05-23); no migration V003 is added for deduplication; **exactly-once invoice creation is not claimed**. Integration implication: a caller that retries creation after a timeout may create a second PENDING invoice; it must avoid blind retries or cancel the duplicate (it has no business effect until settled) — recorded as DEP-16. Settlement remains idempotent per `Invoice_ID` (D-003 (A); WO-P3-P3-01 T-F05-06, T-CONC-01). **Q6** no side effects at creation (no stock, entitlement, points, spending). |
| Status | **APPROVED (provisional, T2)** |
| Blocker class | BLOCKING_UC05 (resolved 2026-11-09) |
| Approver / date | Project Owner / 2026-11-09 (provisional under T2: team confirmation of the callers and the interface at P6) |
| Reference | Owner Directive "Close Invoice Creation and Prioritize Settlement" (Claude Code session of 2026-11-09): §2 Q4 (caller-supplied prices, with conditions) and §2 Q5 (option (a)); Q1–Q3 (a) confirmed by the Owner's answer to the decision question asked in the same session ("Confirm Q1–Q3 (a), T2"); Q6 directed on 2026-11-09 ("Urgent Unblock & Core Implementation" §7) |
| Related | D-003, D-005, D-011, D-012, D-023; [WO-P3-P3-00](work-orders/WO-P3-P3-00_INVOICE_CREATION.md); [06 §4.1](06_UC05_BILLING_LOYALTY_PLAN.md#41-invoice-creation-billing-f05-wo-p3-p3-00-d-028) |

---
