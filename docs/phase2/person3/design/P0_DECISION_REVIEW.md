# P0 Decision Review — Person 3 (for Project Owner approval)

| Field | Value |
|---|---|
| Work order | WO-P3-P0-01 — Decision Freeze and Implementation Readiness (mode PLAN_ONLY) |
| Authority | "Owner Directive — P3 Planning Approval & P0 Decision Freeze", 2026-11-06 |
| Date | 2026-11-06 |
| State | BOOTSTRAP `PASSED` · D-025 `APPROVED` · WO-P3-P0-01 `VERIFIED` · P1 `NOT_STARTED` · BUILD `NOT_STARTED` |
| Rule applied | No unresolved decision is marked APPROVED. Recommendations are labelled and are **not** approved business requirements. |
| Superseded (2026-11-07) | For decision classification, recommendations and P1 readiness, see [P0_FINAL_DECISION_PACKAGE.md](P0_FINAL_DECISION_PACKAGE.md). This review is kept unchanged as the historical WO-P3-P0-01 deliverable. Its WO numbers predate the renumbering: its "WO-P3-P1-01" is today's WO-P3-P1-02 (integration contract) and its "WO-P3-P1-02" is today's WO-P3-P1-01 (physical schema foundation). |

## 1. Bootstrap work order

**WO-P3-BOOT-001 is `PASSED`** (Project Owner, 2026-11-06, directive §1), based on its documentation audit. The approval covers planning deliverables only. Master prompt v2.0 remains the governing contract and was not modified.

## 2. D-025 — APPROVED with constraints

Disposable, isolated test and benchmark databases are approved under seven binding conditions. They are recorded in [03 D-025](../03_DECISION_LOG.md):

1. The shared team database remains the canonical integration database.
2. Test and benchmark databases derive from the approved shared schema and migrations.
3. Independent test databases must not evolve into incompatible Person 3 implementations.
4. Destructive, rollback, concurrency and performance experiments run in isolated environments.
5. Benchmark environments and datasets are documented and reproducible.
6. Experimental indexes, partitions and schema changes do not automatically propagate into the shared database.
7. No shared-database modifications are authorized by this decision.

Effects on the plan: every WO's target database refers to these conditions. WO-P3-P1-02 no longer allows a P3-private stand-in schema (conditions 2–3). "ADOPTED" index/summary/partition results now mean "recommended for promotion" (condition 6). WO-P3-P6-01 needs a separately approved promotion step (condition 7). New risk R-23 covers drift. Gap G-24 is closed.

One field changed: D-025's "Team approval needed" is now "No: Project Owner", because the approved constraints keep the shared database untouched. **Please confirm or revert.**

## 3. Decision classification

Classes: **BLOCKING_P1** (must be decided before WO-P3-P1-02 can produce DDL), **BLOCKING_FEATURE** (blocks a later phase only), **DEFERRED** (decided by evidence in a later WO). Labels: TR = TECHNICAL_RECOMMENDATION, ASM = ASSUMPTION_PENDING_APPROVAL, P1 = DERIVED_FROM_PHASE1.

The source evidence, full alternatives and technical justification of every decision are in its section of [03_DECISION_LOG.md](../03_DECISION_LOG.md). This table adds the classification, dependencies, risk, approver and whether work can proceed without the decision.

| ID | Decision | Class | Unresolved question | Recommendation | Depends on | Risk if unresolved or wrong | Approver | Can implementation proceed without it? |
|---|---|---|---|---|---|---|---|---|
| D-001 | Use-case catalogue, P3 scope | BLOCKING_P1 | 7 Phase 1 UCs or the 6-UC set? Who owns F06 orchestration, F29, F30, RQ-A16–18? | 6-UC set once the full list with owners is published; P3 core = F06 effects, F20–F22, F27, F28 (TR) | S-10 document | Duplicated or orphaned work; report ≠ code | Team | No: contract and DDL scope |
| D-002 | DBMS, version, edition, compat level | BLOCKING_P1 | Which engine, version and compatibility level everyone uses | SQL Server 2025 (17.x), one fixed compatibility level; verify edition features in WO-P3-P0-02 (TR) | WO-P3-P0-02 | Incomparable results; missing features (R-09) | Team | No: DDL syntax and features |
| D-003 | Payment-confirmation model | BLOCKING_P1 | Invoice-state model or PAYMENT table? Client request key? | Invoice state + conditional PENDING→PAID; request key only if creation can be retried; PAYMENT table only for refunds/partials (TR) | D-005, D-011 | Wrong exactly-once mechanism; late table addition | Team | No: schema shape |
| D-004 | `INVOICE.PaidAt` | BLOCKING_P1 | Add PaidAt, or date revenue by IssuedAt? Why was it removed on 5 Nov? | Add PaidAt (NULL until PAID) after the team explains the removal (TR) | D-003, D-010 | Mis-dated revenue and spending | Team | No: column, indexes, partition key |
| D-005 | Status and method domains | BLOCKING_P1 | Status values and transitions; when the method is set | PENDING/PAID/CANCELLED (+REFUNDED only if D-011); CASH/VNPAY/CARD; method set at settlement (TR) | D-011 | CHECKs and filtered-index literals change later | Team | No: CHECK constraints |
| D-006 | Point formula and rounding | BLOCKING_FEATURE (P2, P3) | Base amount; per invoice or cumulative; rounding | FLOOR(FinalAmount / 100,000) per invoice (ASM) | — | Wrong reconciliation invariant | Project Owner | Yes for P1 (no schema impact); no for P2/P3 |
| D-007 | Tier window | BLOCKING_FEATURE (P2, P3) | Calendar year or rolling 12 months | Rolling current month + 11 previous months, evaluated daily (ASM) | — | Wrong tiers; January cliff under a calendar rule | Project Owner | Yes for P1; no for P2/P3 |
| D-008 | Tier thresholds, base tier, boundary | BLOCKING_FEATURE (P2, P3) | Threshold values; Silver as base tier at 0; ≥ or > | Silver = 0 as base tier, `≥` rule; values to be set by the owner (ASM) | D-007 | Unrealistic tier distribution | Project Owner | Yes for P1 (BR04 NOT NULL is already fixed); no for P2/P3 |
| D-009 | Tier evaluation timing | BLOCKING_FEATURE (P3) | Daily batch or immediate upgrade | Daily batch (F22), optional measured upgrade check (P1 + TR) | D-007 | Payment path slowed (Problem 4) | Project Owner | Yes for P1/P2; no for P3 |
| D-010 | Recognised revenue | BLOCKING_FEATURE (P2, P4) | Amount, status, date, recognition, refunds, branch | Σ FinalAmount of PAID invoices, by PaidAt, issuing branch, recognised at sale (TR) | D-004, D-011 | Every UC06 result wrong | Team | Yes for P1 (once D-004 is decided); no for the P2 baseline |
| D-011 | Cancellation and refund scope | BLOCKING_P1 | Cancel pending? Refund paid? | Cancel PENDING only; refunds out of scope and stated as a limitation (TR) | — | State machine or PAYMENT table changes late | Team | No: status domain |
| D-012 | Settlement boundary and ownership | BLOCKING_P1 | One transaction? Who orchestrates? | One transaction, one orchestrator, fixed lock order; owner per D-001 (TR) | D-001 | Partial effects; cross-module deadlocks | Team | No: integration contract |
| D-013 | `SpendingMonth` representation | BLOCKING_P1 | DATE first-of-month or yyyymm | DATE with `DAY() = 1` CHECK (TR) | — | Duplicate month rows | Project Owner | No: PK column type |
| D-014 | Money, key, timestamp types; time zone | BLOCKING_P1 | Shared type standard | INT keys, DECIMAL(18,2), DATETIME2(3) local time UTC+7 (TR) | D-002 | FK type mismatches across members | Team | No: all DDL |
| D-015 | Revenue summary | DEFERRED (P4) | Needed? Which grain? | Decide after the measured index baseline | P4 evidence | Unnecessary derived data | Team if adopted | Yes: decided by evidence |
| D-016 | Summary maintenance | DEFERRED (P4) | Procedure, trigger, batch or indexed view | Decide with D-015 | D-015 | Drift | Team if adopted | Yes |
| D-017 | Partition INVOICE | DEFERRED (P5) | Partition at all? | Decide after the PoC | P4 results, D-004 | PK/FK change on a shared table | Team if adopted | Yes |
| D-018 | INVOICE clustered key, key type | BLOCKING_P1 | Clustered on Invoice_ID? INT or BIGINT? | Clustered PK on Invoice_ID, INT IDENTITY (TR) | D-014, D-017 | Rebuilding a shared table later | Team | No: shared-table DDL |
| D-019 | Isolation strategy | BLOCKING_FEATURE (P3) | RCSI on the team DB? Write-path locking | Default READ COMMITTED + conditional updates/UPDLOCK; RCSI is a measured team choice (TR) | D-002 | Blocking or lost updates | Team | Yes for P1/P2; no for P3 |
| D-020 | Application stack | BLOCKING_FEATURE (P6) | Web or WinForms; .NET or Node | Team choice; keep P3 logic in database routines (TR) | — | P6 late (R-21) | Team | Yes until P6 |
| D-021 | Repository and workflow | BLOCKING_P1 | Canonical repository, layout, branches | Clone the team repository; `p3/<WO-ID>` branches; review before merge (TR) | Owner names the repository | Lost work or overwrites (R-17) | Team | No: nowhere to version scripts |
| D-022 | Dataset tiers, seed tool, thresholds | BLOCKING_FEATURE (P2) | Tiers, generator, adopt/reject thresholds | DS-S/M/L(/XL); deterministic T-SQL; thresholds of [08 §6](../08_INDEX_AND_QUERY_PLAN.md#6-adoption-and-rejection-criteria) (TR/ASM) | D-002 | Irreproducible or uninformative benchmarks | Project Owner | Yes for P1; no for P2 |
| D-023 | Invoice totals and discount allocation | BLOCKING_P1 | Header discount = Σ line discounts? | Yes; Final = Gross − Discount ≥ 0, enforced by a header CHECK (TR) | D-012 (invoice-creation owner) | Revenue inconsistent with lines | Team | No: CHECKs on the shared INVOICE |
| D-024 | Point balance semantics | BLOCKING_P1 | Redemption or expiry? | Accrual only; CurrentPoints = Σ PointsEarned (TR) | — | Redemption would later need a ledger table | Project Owner | No: a ledger would change the schema |

Totals: **13 BLOCKING_P1, 8 BLOCKING_FEATURE, 3 DEFERRED** (+ D-025 APPROVED).

## 4. Blocking decisions requiring owner approval

Reply with "approve as recommended" or your alternative for each item. WO-P3-P0-03 will then record the answers.

| Decision | Recommended option | Who must approve |
|---|---|---|
| D-013 SpendingMonth | DATE, first day of month | **You alone** |
| D-024 Point balance | Accrual only, no redemption or expiry | **You alone** |
| D-001 UC catalogue | Six-UC set with owners (needs the document) | Team |
| D-002 DBMS | SQL Server 2025 + fixed compatibility level | Team |
| D-003 Payment model | Invoice-state model | Team |
| D-004 PaidAt | Add it (after the team explains the removal) | Team |
| D-005 Domains | PENDING/PAID/CANCELLED; CASH/VNPAY/CARD | Team |
| D-011 Cancel/refund | Cancel PENDING only; no refunds | Team |
| D-012 Settlement owner | One transaction, one orchestrator | Team |
| D-014 Types | INT, DECIMAL(18,2), DATETIME2(3) local | Team |
| D-018 Clustered key | Invoice_ID INT IDENTITY | Team |
| D-021 Repository | Clone the canonical team repository | Team |
| D-023 Invoice totals | Header discount = Σ line discounts; header CHECK | Team |

You can also decide D-006, D-007, D-008, D-009 and D-022 (owner-level) now. That would unblock P2 early.

Information needed from you:

- the six-UC allocation document (S-10);
- the canonical repository (host, URL, maintainer);
- why `PaidAt` was removed on 5 Nov;
- tier threshold values;
- the Phase 2 deadline;
- the team tracking tool.

## 5. Recommended decisions: evidence and trade-offs

| Priority area | Recommendation | Evidence | Trade-off |
|---|---|---|---|
| **DBMS and version** (D-002) | SQL Server 2025 (17.0.1000.7), one compatibility level for all members | Course seminars use SQL Server (S-07, S-08); both local instances are 17.0.1000.7 "Standard Developer" (S-14) | Newest version may differ from teammates' installs. Standard-edition behaviour may lack some Enterprise features (online index operations, automatic indexed-view matching); verify in WO-P3-P0-02 |
| **Physical schema compatibility** (D-014, D-018, D-013, D-023) | INT keys, DECIMAL(18,2), DATETIME2(3) local time; clustered Invoice_ID; DATE month key; header-total CHECK | S-02 §10 has no physical types; volumes are small (324,000 invoices/year, 30,000 members) | INT vs BIGINT costs nothing now but is hard to change later; DECIMAL(18,2) carries unused decimals for VND |
| **Settlement semantics** (D-003, D-005, D-011, D-012) | Invoice-state model, one orchestrated transaction, cancellation of PENDING only | S-02 §2.2 step 5 and §2.5 step 5 (effects on confirmation), §7.2 (payment consistent with entitlements, inventory, points, spending); F05 and F06 are separate functions at 900/day | A PAYMENT table would give attempt history and refunds but adds a table that is not in Phase 1 |
| **Loyalty calculation and rounding** (D-006, D-024) | `FLOOR(FinalAmount / 100,000)` per invoice; accrual only | S-01 p2 "1 point = 100,000 VND"; S-02 §2.6 step 3 | Per invoice loses fractions (two 60,000 VND invoices earn 0 points; monthly-cumulative would give 1) but reverses cleanly and is order-independent |
| **Tier evaluation period** (D-007, D-008, D-009) | Rolling current + 11 months, daily batch, Silver base at 0, `≥` | S-01 p2 "in the year" vs p3 problem 4 "last 12 months"; S-02 §2.6 step 4 and F22 (1 batch/day); unadopted draft BR04 (S-03) | A calendar year matches "in the year" literally but causes mass downgrades every 1 January; rolling changes a little every day |
| **Payment timestamp and revenue recognition** (D-004, D-010) | Add PaidAt; revenue = Σ FinalAmount of PAID invoices by PaidAt, issuing branch, recognised at sale | PaidAt existed in S-06 (31 Oct) and S-04 (5 Nov 19:52), and was removed by 20:27 with no reason recorded; F27/F28 read INVOICE | One more column on a shared table, versus mis-dated revenue whenever payment lags issue |
| **Duplicate payments and concurrency** (D-003, D-019) | Conditional transition under an update lock; safe upsert of monthly spending; atomic increments; default READ COMMITTED | S-02 UC05 "no duplicate points", §5.3; master prompt §6 (composite PK ≠ duplicate protection) | READ_COMMITTED_SNAPSHOT reduces reader/writer blocking but is team-wide and uses tempdb; correctness must not depend on it |
| **Integration with the shared database** (D-012, D-021, D-025) | Integration contract (WO-P3-P1-01) plus a separately approved **promotion** step for adopted P3 objects | D-025 conditions 1, 6, 7; no team schema or code exists yet (S-12, S-13) | The extra promotion step costs process time but prevents experimental structures from leaking into the shared database |
| **UC mapping Phase 1 → Phase 2** (D-001) | Adopt the six-UC set when its full list and owners are available; until then keep the Phase 1 numbering in the planning docs | S-02 §7.1 (UC01–UC07); S-11 summary; S-01 p4 accepts 5–8 UCs | Seven UCs avoid renumbering the Phase 1 report; six UCs match the newer allocation. Either way, F06/F29/F30 need named owners |

## 6. Repository readiness findings

Inspection was read-only on 2026-11-06. **No `git init`, clone, commit or push was performed.**

| Finding | Detail |
|---|---|
| Working folder | `C:\CSDLNC- DA` is **not a Git repository**, and no parent folder is one |
| Team repository | None known. No local clone of a FitLife or team repository was found (search of the user profile for `.git` folders found only unrelated repositories) |
| Git tooling | Git 2.54.0.windows.1; global user name and email configured; credential helper `manager`; system `core.autocrlf=true` |
| Other tooling | GitHub Desktop installed; GitHub CLI (`gh`) not installed; default `Documents\GitHub` clone folder absent |
| Content to move | Documentation only (UTF-8, LF line endings) plus empty evidence folders |
| Path note | The folder name contains a space (`CSDLNC- DA`). Scripts must quote paths; a clone path without spaces is advisable |

Prerequisites for adopting the canonical repository. These are recorded as **P1-R5**.

1. The owner or team identifies the canonical repository: host, URL, default branch, maintainer. If none exists, the team creates one; that is outside P3's authority.
2. P3's account has access (write, or fork plus pull request).
3. Explicit authorization to clone it into a chosen local path.
4. Layout agreed (D-021), including where `docs/agent/` and `docs/phase2/person3/` go. The P3 section of `CLAUDE.md` is merged into the team's instructions without replacing them.
5. Branch convention (`p3/<WO-ID>`) and review/merge rules agreed.
6. `.gitignore` covers local config, credentials, database files (`*.mdf`, `*.ldf`, `*.bak`) and large raw dumps; `.gitattributes` sets the line-ending and encoding policy.
7. Explicit authorization for the first commit and pull request of these planning documents.

Options: (A) **recommended**: clone the team repository, add these documents on a P3 branch, and open a pull request. (B) If no team repository exists, the team creates one first, then (A). (C) Initialise this folder as the canonical repository, only if the team designates it. Not recommended, because it holds only P3 documents.

## 7. Implementation readiness: P1 criteria and work-order review

**P1 readiness criteria** (defined in [15 §3, P1](../15_ROADMAP_AND_WORK_ORDERS.md#p1--physical-schema-and-integration-contract); current state in [16 §2](../16_READINESS_REPORT.md#2-go--no-go-for-p1-physical-schema)):

| ID | Criterion | State |
|---|---|---|
| P1-R1 | WO-P3-BOOT-001 PASSED | ✔ |
| P1-R2 | WO-P3-P0-01 PASSED | Awaiting your gate |
| P1-R3 | 13 BLOCKING_P1 decisions APPROVED (recorded by WO-P3-P0-03) | 0 / 13 |
| P1-R4 | D-025 APPROVED | ✔ |
| P1-R5 | Repository readiness (§6) | ✘ |
| P1-R6 | Approved shared base schema and migrations (D-025 conditions 2–3) | ✘ |
| P1-R7 | Environment verified (WO-P3-P0-02 PASSED) | ✘ |
| P1-R8 | Six-UC allocation obtained | ✘ |

**Work-order review (P1–P8).** All WOs have dependencies, inputs, acceptance criteria, tests, evidence and approval sections (audit check 5).

| WO | Finding | Change made |
|---|---|---|
| WO-P3-P0-02 | Still needed for environment facts (D-002) and repository setup; needs 3 authorizations and the repository URL. Its probe database counts as isolated and disposable under D-025. | Target-database note references D-025 |
| WO-P3-P0-03 (new) | Needed to record the owner's and team's answers. It carries the P0-01 criterion that P0-01 cannot meet itself (see [WO-P3-P0-01 §0](../work-orders/WO-P3-P0-01_DECISION_FREEZE.md#0-amendment-record-owner-directive-2026-11-06)). | Created as PROPOSED |
| WO-P3-P1-01 | Preconditions lacked D-002 (types, SET options) and D-005 (status literals). The promotion procedure was undefined. Other members' schema drafts are MISSING. | D-002, D-005 added; task 5 added (record D-025, agree the promotion procedure) |
| WO-P3-P1-02 | Preconditions lacked D-002, D-011, D-024 and repository and shared-baseline readiness. Task 4 (P3 stand-in parent schema) **conflicted with D-025 conditions 2–3**. Shared-schema impact: INVOICE and MEMBER columns and constraints. | Preconditions = P1-R1…R8; stand-in removed (BLOCKED if no baseline); shared-DB application out of scope |
| WO-P3-P2-01 / P2-02 | Seeding and benchmarks must stay in isolated, reproducible databases | D-025 conditions written into out-of-scope |
| WO-P3-P3-01 | Settlement computes points, but D-006 was not a precondition. Rules for hook stand-ins were missing. | D-006 added; stand-in rules and isolation for fault injection added |
| WO-P3-P3-02 | Preconditions out of date after D-024 was reclassified | Corrected to D-006, D-007, D-008, D-009 |
| WO-P3-P3-03 | Concurrency runs must be isolated | Added |
| WO-P3-P4-01 / P4-02 / P5-01 | "ADOPTED" could be read as deployment to the shared database | Defined as "recommended for promotion"; shared-DB creation out of scope |
| WO-P3-P6-01 | Needs P3 objects in the canonical shared database, but **no WO performs that promotion** | Target = canonical DB, execute/read only; promotion added as a precondition |
| WO-P3-P7-01 | Clean install must derive from the shared schema and migrations | Updated; canonical-DB checks read-only |
| WO-P3-P8-01 | No issue | — |

**Restructuring that needs your approval (not done):** add a work order **"Promotion of adopted P3 objects into the shared schema"** (BUILD_AUTHORIZED on the canonical database, team-approved migration), between GATE-P5 and WO-P3-P6-01. Without it, P6 cannot start under D-025 condition 7. I documented the need but did not create the WO, because it changes the roadmap's structure and touches the shared database.

## 8. Changed documentation files

New:

- `docs/phase2/person3/design/P0_DECISION_REVIEW.md`
- `docs/phase2/person3/work-orders/WO-P3-P0-03_DECISION_RECORDING.md`

Changed:

- Plan documents in `docs/phase2/person3/`: `02_GAP_ANALYSIS.md`, `03_DECISION_LOG.md`, `08_INDEX_AND_QUERY_PLAN.md`, `09_PARTITION_FEASIBILITY_PLAN.md`, `10_SEED_AND_BENCHMARK_PLAN.md`, `11_TEST_AND_QA_PLAN.md`, `12_INTEGRATION_PLAN.md`, `14_RISK_REGISTER.md`, `15_ROADMAP_AND_WORK_ORDERS.md`, `16_READINESS_REPORT.md`, `README.md`, `SESSION_LOG.md`.
- Work orders in `docs/phase2/person3/work-orders/`: `README.md`, `WO-P3-BOOT-001`, `WO-P3-P0-01`, `WO-P3-P1-01`, `WO-P3-P1-02`, `WO-P3-P2-01`, `WO-P3-P2-02`, `WO-P3-P3-01`, `WO-P3-P3-02`, `WO-P3-P3-03`, `WO-P3-P4-01`, `WO-P3-P4-02`, `WO-P3-P5-01`, `WO-P3-P6-01`, `WO-P3-P7-01`.
- Agent files: `docs/agent/P3_CONTEXT_INDEX.md`.

Not changed: `docs/agent/P3_MASTER_PROMPT.md` (v2.0 preserved), `CLAUDE.md`, the other planning documents, `WO-P3-P0-02`, `WO-P3-P8-01`.

## 9. Documentation verification results

The read-only audit script (session scratchpad, not in the repository) ran on 2026-11-06 after all edits. **Result: PASS.**

| Check | Result |
|---|---|
| Expected files present and non-trivial | PASS (46 files in the repository, documentation only) |
| Relative links and anchors | PASS: 377 checked, 0 broken |
| IDs defined | PASS: 25 D, 24 G, 23 R, 57 T, 11 IX, 15 DL, 40 RQ, 17 S, 11 Q, 17 WO; 0 undefined references |
| Traceability tables | PASS: RQ Table A 40 = Table B 40 |
| WO structure and statuses | PASS: BOOT `PASSED`, P0-01 `VERIFIED`, 15 others `PROPOSED`; all use v2.0 mode names; all have acceptance and verification sections |
| Only D-025 APPROVED | PASS |
| BLOCKING_P1 set identical in 03 index, review §3, 15 P1-R3, 16 §2, WO-P3-P1-02, WO-P3-P0-03 | PASS (13 decisions in each) |
| Approval rules (master prompt A1 = roadmap §1) | PASS (6 = 6, identical) |
| Stale v1.0 vocabulary | PASS: 0 |
| Secrets (assignment PDF password) | PASS: 0 files |
| Performance claims | PASS: no measured numbers; only the official <50 ms check-in target is quoted |
| Implementation files | PASS: none (`.md` and `.gitkeep` only) |
| Superseded "P3 stand-in schema" wording | PASS: removed from 03, 10, 12 and WO-P3-P1-02 (manual search) |

Database, code and benchmark tests: `NOT_RUN`. Nothing is built, and building is not authorized.

## 10. Recommended next work order

1. **You:** review this document and set WO-P3-P0-01 to `PASSED` (or request changes). Confirm the D-025 approver-field change (§2), confirm the move of the P0-01 criterion to WO-P3-P0-03 (WO-P3-P0-01 §0), and decide on the proposed promotion WO (§7).
2. **Next work order: WO-P3-P0-02 — Environment, Repository and Tooling Baseline** (VERIFY_ONLY). It needs the canonical repository URL and three explicit authorizations: read-only server queries; one disposable probe database (D-025); clone of the canonical repository. It produces P1-R7 and part of P1-R5.
3. **In parallel:** collect your and the team's answers on §4, then approve **WO-P3-P0-03** to record them (P1-R3, P1-R8).

P1 stays `NOT_STARTED` until P1-R1…P1-R8 all hold.
