# P3 Loyalty Decision Package — D-007, D-008, D-009, U0 and WO-P3-P3-02 readiness

| Field | Value |
|---|---|
| Prepared by | Owner Directive "UC05 Loyalty Decision Closure & Implementation Readiness" (Claude Code session of 2026-11-09), mode **PLAN_ONLY** |
| Status | **PROPOSED — nothing in this package is approved.** The approval statements in §6 take effect only when the Project Owner gives them |
| Database work | None. No routine, fixture, migration or test was written or run for this package |
| Verified baseline (read-only, 2026-11-09) | WO-P3-P0-01, WO-P3-P1-01, WO-P3-P2-01 `PASSED`; WO-P3-P3-00 `PASSED` (functional); WO-P3-P3-01 `IN_PROGRESS` (run `UC05S-RUN__20261109-1447`, `UC05S-RUN_RESULT: PASS`); WO-P3-P2-02 `BLOCKED`; R-27 OPEN. Deployed in `FitLife_P3_UC05`: `usp_P3_CreateInvoice`, `usp_P3_SettleInvoice`, `usp_P3_CancelInvoice`, `tvf_P3_SpendingMonth` + the two TEST_ONLY hook doubles. None of these is changed by this package |

## 1. What the sources say (checked 2026-11-09)

| Source | Tier names | Tier period | Thresholds | Timing |
|---|---|---|---|---|
| S-01 assignment (audit of 2026-11-06; the PDF is password-protected and was **not re-opened** today — the password is never stored) | Silver, Gold, Platinum (3 tiers) | p2: "based on total spending **in the year**"; p3 Problem 4 describes the current system re-summing "**the last 12 months**" at every payment and re-ranking **up or down** | **Not specified** (G-07) | Problem 4: synchronous re-rank at payment is the bottleneck to remove |
| S-02 Phase 1 report (docx text searched today) | — (only `MEMBER_TIER(Tier_ID, Tier_Name, SpendingThreshold)`) | §2.6 step 4: "theo kỳ xét hạng" (per evaluation period), **period not defined** | §2.6 step 4: compared with `SpendingThreshold` of MEMBER_TIER; **no numeric value anywhere** (no "VND", "triệu" or amount in the document) | §2.6 step 4 "định kỳ" (periodically); F22 "Xét hạng định kỳ", **1 đợt/ngày** (one batch per day); step 5: avoid recomputing all invoices in the payment flow |
| S-03 unadopted draft (informative only) | — | BR04: "12 tháng gần nhất theo kỳ tháng (tháng hiện tại và 11 tháng trước)" = current month + 11 previous months | "ngưỡng cụ thể do cấu hình MEMBER_TIER quy định" — thresholds are MEMBER_TIER configuration | — |

**Conclusions.** (1) The tier **names** are official (S-01). (2) **No official threshold values exist** in any available source. (3) No source defines an exact (day-precise) rolling period as a requirement: S-01 uses "in the year" for the rule and "the last 12 months" only to describe the current slow system; S-02 leaves the period open; the only explicit definition (S-03, unadopted) is month-aligned. Choosing a period is therefore an Owner decision, not a reinterpretation of a stated exact rule. If the Owner's reading of S-01 is day-precise, alternative C below must be chosen, with its schema cost.

## 2. D-007 — tier evaluation period

Letters: the directive's A/B/C correspond to decision-log alternatives (a)/(d)/(e). Log alternatives (b) "year N based on year N−1" and (c) "12 complete months excluding the current month" remain listed and are not recommended.

| | A = (a) Calendar year | **B = (d) Current month + 11 previous months** | C = (e) Exact rolling 12 months |
|---|---|---|---|
| Window for evaluation date 2027-01-15 (local) | 2027-01-01 → now | 2026-02-01 ≤ SpendingMonth < 2027-02-01 (Feb 2026 … Jan 2027) | 2026-01-16 00:00 → 2027-01-15 24:00 local |
| From MEMBER_MONTHLY_SPENDING | Exact (≤ 12 rows) | **Exact (≤ 12 rows)** | **Not exact**: the oldest month is partly inside. Needs a new daily aggregate table (schema change) or re-reading invoices of the oldest month (needs an index; reintroduces invoice reads) |
| Schema impact | None | **None** | New production table or index (not approved) |
| Upgrades | As spending accumulates | Same | Same |
| Downgrades | Only on 1 January, everyone at once; never within a year | **On the 1st of a month, when the oldest month leaves the window, also without any payment** | Any day |
| Fit with Problem 4 "up or down" | Poor | Good | Good |
| Fit with S-01 "in the year" | Literal | "Within a year" reading | "Within a year" reading |

**Local-calendar rules for B (all already implemented or approved):**

1. `SpendingMonth` = first day of the Asia/Ho_Chi_Minh month of `PaidAt` (D-013). `PaidAt` is stored in UTC (D-014); local = UTC + 7 h, no daylight saving; implemented once in `dbo.tvf_P3_SpendingMonth` and verified against an independent `AT TIME ZONE` oracle (T-F05-10, 9,012 instants, 0 mismatches). Example: `2026-01-31 17:00:00.000` UTC = 1 Feb 00:00 local → February.
2. Evaluation date `@AsOfDate` is a **local** date (default: today in Asia/Ho_Chi_Minh = `CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS date)`).
3. Window: `@To = DATEADD(MONTH, 1, DATEFROMPARTS(YEAR(@AsOfDate), MONTH(@AsOfDate), 1))`, `@From = DATEADD(MONTH, -12, @To)`; spend = Σ `TotalSpend` where `@From ≤ SpendingMonth < @To` (half-open, SARGable on the key; no conversion of the column).
4. December/January: nothing special. A payment at `2026-12-31 17:00` UTC belongs to January 2027 (local) and therefore to every window whose last month is ≥ January 2027. The window for January 2027 is Feb 2026 … Jan 2027: there is no reset on 1 January.
5. Downgrade without payment: spending of month M counts in the windows whose last month is M … M+11; on the first evaluation in month M+12 it leaves the window, the spend falls, and the member drops to the tier that the remaining spend qualifies for, even if the member paid nothing.
6. Existing aggregation schema: unchanged. At most 12 rows per member are read. Older rows stay as history (no deletion is proposed).

**Recommendation: B** (log (d)). It is computed exactly from the approved Phase 1 aggregate, needs no schema change, produces upgrades and downgrades, and has no 1 January cliff. Day-precise C is not recommended unless the Owner states that the requirement is day-precise.

## 3. D-008 — thresholds, base tier, boundary rule

**Official threshold values: NOT DEFINED** (§1). They are recorded as an **unresolved business configuration**. Nothing below invents them.

Split of D-008 (proposed):

| Part | Content | Proposed status |
|---|---|---|
| D-008 rule | Alternative (a): three tiers Silver, Gold, Platinum (names from S-01); **Silver is the base tier with `SpendingThreshold = 0`** (the only option compatible with BR04 "every member has exactly one tier" and "3 tiers": alternative (b) adds a 4th tier, (c) makes Tier_ID nullable); a member gets the tier with the **highest `SpendingThreshold` ≤ window spend** (comparison `≥`: spend equal to a threshold qualifies); spend 0 → Silver; thresholds are **read from MEMBER_TIER, never hard-coded**; a routine refuses to run on an invalid configuration (no tier at 0, duplicate or negative thresholds) | Approvable now (provisional T2) |
| D-008 values | Gold and Platinum thresholds in VND of window spend | **Open** business configuration |

**Approval procedure for the values.** The Owner (with the team, if it wishes) states two amounts: `Gold = G VND`, `Platinum = P VND`, `0 < G < P`, applied to the D-007 window spend. P3 records them in D-008 with approver and date. They reach the shared MEMBER_TIER through its owner's configuration at P6 (MEMBER_TIER is a SHARED_DEPENDENCY; P3 supplies values, it does not own or redesign the table; 12 §2a). P3 production SQL never contains them.

**Until then — TEST_ONLY synthetic thresholds.** Allowed only in an isolated fixture, labelled `TEST_ONLY_SYNTHETIC`, e.g. Silver 0 / Gold 1,000,000.00 / Platinum 3,000,000.00 (chosen only to keep test invoices small; not a proposal). Tests compute every boundary from the MEMBER_TIER rows they read, so the real values can replace the synthetic ones without changing any test or routine. Synthetic values never appear in `db/`, in reports or in evidence as business values.

## 4. D-009 — re-evaluation timing

| | (a) Periodic batch only | (b) Batch + immediate upgrade check at settlement | (c) Synchronous re-rank at every settlement |
|---|---|---|---|
| Upgrades | At the next run (lag ≤ 1 cycle) | Immediately (upgrade only) | Immediately |
| Downgrades when the window advances without a payment | Yes (the batch runs whether or not anyone pays) | Only through the batch | **No** — nothing runs without a payment |
| Settlement path | Unchanged (verified routine kept) | Extra ≤ 12-row read + MEMBER update per payment; changes or wraps the verified routine | The Problem 4 bottleneck (window recompute) |
| Source fit | S-02 §2.6 step 4, F22 "1 đợt/ngày" | Optional business wish (G-08 open) | What Problem 4 asks to replace |

**Settlement-time re-evaluation alone cannot be correct**: month-boundary downgrades happen without payments. A periodic process is therefore mandatory; a settlement-time check would only be an optional upgrade accelerator.

**Recommendation: (a)**, specified as follows (no job, trigger or production table is created; who schedules the daily call is an integration item for P6):

| Aspect | Specification |
|---|---|
| Routine | `dbo.usp_P3_EvaluateTiers @AsOfDate DATE = NULL` (local date; NULL = today local) |
| When | Once per day after local midnight (F22), invoked by the scheduler chosen at P6; any re-run is safe |
| Config check | Before any write: ≥ 1 tier, exactly one tier at 0, thresholds unique and ≥ 0; else error, nothing written |
| Selection | Per member: spend = Σ TotalSpend in the D-007 window (0 when no row); target = tier with the highest threshold ≤ spend (D-008 rule) |
| Boundaries | `spend ≥ threshold` qualifies; amounts are DECIMAL(18,2), compared exactly |
| Zero spending | Base tier (threshold 0) |
| Writes | Only `MEMBER.Tier_ID`, only where `Tier_ID <> target` (no repeated updates; second run with the same data changes 0 rows) |
| Set-based and bounded | Targets computed into a temporary set first (reads committed MMS rows, no MMS locks kept), then updated in Member_ID-range chunks, each a short own transaction below lock escalation (06 §4.6, R-15) |
| Concurrency | Settlement writes MMS and `CurrentPoints`; the batch writes only `Tier_ID`. No lost update (different columns, atomic statements). No lock cycle (the batch holds no MMS lock while updating MEMBER; settlement order MMS → MEMBER). A payment committed after the batch read is reflected at the next run (documented lag). Deadlock victim: the chunk rolls back and the routine is re-run |
| Failure | A failed chunk rolls back completely; already committed chunks are correct for the same `@AsOfDate`; a re-run completes the rest (idempotent) |
| Output | Counts: upgrades, downgrades, unchanged |
| Lookup | `usp_P3_GetMemberLoyalty` (F21, read-only): CurrentPoints, tier, window spend, gap to next tier |
| Settlement | **Unchanged.** `usp_P3_SettleInvoice` keeps its verified definition (SHA-256 `96C877A8…7E44`) |

(c) is implemented **only** as the benchmark-only U0 (§5). (b) is not implemented unless the Owner asks for instant upgrades.

## 5. WO-P3-P3-01 task 2 (U0) — what it actually requires

Exact text. Task 2: "Implement `usp_P3_SettleInvoice_Baseline` (U0) with the same contract, recomputing window spend from INVOICE and re-ranking the tier synchronously. Mark it **benchmark-only**." Criterion 4: "The U0 variant is not called by any application path (code search documented)."

| Requirement | Required in WO-P3-P3-01? |
|---|---|
| A valid, tier-aware routine (window recompute from INVOICE + tier update) | **Yes** — needs D-007 (window) and D-008 rule; values come from MEMBER_TIER (synthetic in TEST_ONLY fixtures is enough) |
| Functional verification with F002 | Not literally listed, but "same contract" must be shown: **recommended** minimal test T-F05-36/37 (same business effects as U1; tier = oracle; repeat and rollback) |
| Benchmark timing | **No** — U0/U1 timing is WO-P3-P3-03 task 3 (T-PERF-02), blocked by R-27 there |
| Comparison against the optimized version | **No** — WO-P3-P3-03 |
| Code search (criterion 4) | **Yes** — documented search that no application path or other routine calls U0 |

**Narrowest correct path.** After D-007 and the D-008 rule are approved and the F002 tier fixture exists, resume WO-P3-P3-01 under its existing approval (task 2 only): implement U0 as a separate benchmark-only procedure that opens/joins the transaction, calls the unchanged `usp_P3_SettleInvoice`, and — only for outcome `SETTLED` — recomputes the window spend from PAID invoices (UTC bounds derived from the local window), selects the tier by the D-008 rule and updates `MEMBER.Tier_ID` if different. This reuses the verified routine instead of rewriting it, and the later benchmark isolates exactly the synchronous re-rank cost. Then run the code search and T-F05-36/37, re-run the WO-P3-P3-01 suite as a new recorded run, and set `VERIFIED`. U0 is never marked PASS for performance; no move to another WO is assumed.

## 6. Owner approval statements (proposed, not given)

1. **D-007:** "D-007 APPROVED (provisional, T2): alternative (d) [directive option B]. The tier window is the twelve Asia/Ho_Chi_Minh calendar months formed by the month of the evaluation date and the eleven preceding months; window spend = Σ MEMBER_MONTHLY_SPENDING.TotalSpend with `@From ≤ SpendingMonth < @To`. It is not day-precise. Spending leaves the window on the first evaluation of the twelfth following month."
2. **D-008 rule:** "D-008 rule APPROVED (provisional, T2): alternative (a): tiers Silver, Gold, Platinum; Silver is the base tier with threshold 0; a member gets the tier with the highest threshold ≤ window spend (`≥`); thresholds are read from MEMBER_TIER and never hard-coded. Gold and Platinum threshold **values remain open**. Until they are approved, synthetic values may be used only in TEST_ONLY isolated fixtures labelled as synthetic."
3. **D-009:** "D-009 APPROVED (provisional, T2): alternative (a): tiers are re-evaluated only by the idempotent, set-based routine `usp_P3_EvaluateTiers(@AsOfDate)`, daily, upgrades and downgrades; settlement does not re-rank; (c) only as the benchmark-only U0; (b) not implemented. No job or trigger is created by P3; scheduling is a P6 integration item. A tier may lag by one evaluation cycle."
4. **F002 tier extension:** "Approved as TEST_ONLY (F002T): fixture MEMBER_TIER(Tier_ID INT PK, Tier_Name NVARCHAR(50) NOT NULL, SpendingThreshold DECIMAL(18,2) NOT NULL) with three rows Silver 0 / Gold / Platinum (synthetic thresholds), and MEMBER.Tier_ID INT NOT NULL with the Phase 1 FK, all existing members on the base tier."
5. **WO-P3-P3-01 task 2:** "Resume WO-P3-P3-01 task 2 under its existing approval, as specified in package §5; no timing."
6. **WO-P3-P3-02:** "WO-P3-P3-02 APPROVED, BUILD_AUTHORIZED, target `FitLife_P3_UC05`; precondition 'WO-P3-P3-01 PASSED' is met by [the Owner's acceptance of WO-P3-P3-01 after task 2 is VERIFIED]; scope additions: T-CONC-04F (functional, no timing) and the tests of §8; DS-L check (criterion 3) in a new disposable database `[name]` built by the unchanged P2 pipeline plus TEST_ONLY F002P/F002T and a TEST_ONLY loyalty loader — or: DS-L check moved to WO-P3-P3-03. No commit, push or merge."

## 7. Required F002 fixture changes (smallest)

Existing: F002P (`MEMBER.CurrentPoints`). Proposed new TEST_ONLY script `tests/db/fixtures/F002T__TEST_ONLY_member_tier.sql`, after F001U and F002P, in `FitLife_P3_UC05` only:

1. `CREATE TABLE dbo.MEMBER_TIER (Tier_ID INT NOT NULL PK, Tier_Name NVARCHAR(50) NOT NULL, SpendingThreshold DECIMAL(18,2) NOT NULL)` — Phase 1 columns (S-02 §10), D-014 money type; classification `TEST_ONLY_FIXTURE`; **no** UNIQUE/CHECK (they belong to the table owner, 12 §2a; the P3 routine validates the configuration itself).
2. Rows: (1, Silver, 0.00), (2, Gold, synthetic), (3, Platinum, synthetic); extended property `TEST_ONLY_SYNTHETIC_THRESHOLDS`.
3. `MEMBER.Tier_ID INT NOT NULL` + FK `FK_MEMBER_MEMBER_TIER` → MEMBER_TIER (Phase 1 FK, BR04): add nullable, set every member to the base tier, then make NOT NULL (no default constraint is invented).
4. Tests/integrity updates (new versions, old evidence kept): T-SCH-05 (catalog = P1 + exact F002P/F002T items + doubles; write scope: batch writes only `MEMBER.Tier_ID`, lookup read-only, U0 benchmark-only), V-UC05T (V-UC05S + tier invariants), runners with new evidence names.

Not changed: P3 migrations V001/V002 (except the additive CHECK `PointsEarned = FLOOR(TotalSpend / 100000)` that WO-P3-P3-02 already plans because D-006 (b) is approved — V003 on the P3-owned table, to be confirmed in the WO approval), the seed generator, `FitLife_P3_P1`, `FitLife_P3_P2`.

## 8. Test design (functional; no benchmark acceptance)

Thresholds are always read from MEMBER_TIER; historical months are produced by TEST_ONLY PAID invoices inserted directly with past `PaidAt` and their consistent MMS rows and points (settlement itself always uses the server time, DEP-17), and by calling the batch with explicit `@AsOfDate` values.

| # | Directive item | Test | Existing / new | What passes |
|---|---|---|---|---|
| 1 | Spending below / equal / above point thresholds | T-F05-09 | Existing (PASS 1447); regression | 0/0/1/1/2 points |
| 2 | Many small invoices in a month | T-F05-32 | New | 25 × 4,000 VND → 0 points until the 25th, then 1 |
| 3 | Settlement across a month boundary | T-F05-10 (+ T-F05-33) | Existing; new window part | Month function at 16:59:59.999 / 17:00:00.000 UTC; history rows in Jan vs Feb fall into different windows |
| 4 | Across a year boundary | T-F05-10 E01 + T-F05-13b | Existing; new | 2026-12-31 17:00 UTC → Jan 2027; window for Jan 2027 = Feb 2026…Jan 2027, no reset |
| 5 | Repeated settlement | T-F05-06, T-F05-36 | Existing; new (U0) | No second effect; no tier change on repeat |
| 6 | Concurrent settlement, same member | T-CONC-02; T-CONC-04F | Existing; new | No lost spending/points; settlement concurrent with the batch: final tier = oracle at the next run, CurrentPoints intact, no deadlock surfaced |
| 7 | Tier upgrade | T-F05-12 | New | Spend crosses a threshold → upgrade at the next run |
| 8 | Tier downgrade | T-F05-12, T-F05-13 | New | Spend falls below → downgrade |
| 9 | Exact threshold boundaries | T-F05-12 | New | threshold − 0.01 / = / + 0.01 for each tier; spend 0 → base |
| 10 | Window expiration | T-F05-13 | New | Spend in month M: qualifies through M+11, not in M+12 |
| 11 | No payment during the downgrade period | T-F05-13 | New | Downgrade happens with no settlement at all |
| 12 | Rollback during loyalty updates | T-F05-08, T-F05-34, T-F05-37 | Existing; new | Settlement rollback (existing); failed batch chunk leaves its members unchanged, re-run completes; U0 rollback leaves nothing |
| 13 | CurrentPoints = Σ PointsEarned = paid invoices | V-UC05S U3–U5 → V-UC05T; T-REC-01/02/04 | Existing; extended | 0 mismatches after every stage; T-REC-04: Tier_ID = oracle after a run |
| 14 | No unauthorized change to shared modules | T-SCH-05, fingerprint, DS-L checksum | New / existing | Only the F002P/F002T fixture items; batch writes only `MEMBER.Tier_ID`; other databases unchanged |
| — | Idempotent batch | T-F05-14 | New | Second run: 0 changes |
| — | Invalid tier configuration | T-F05-35 | New | Error, nothing written |
| — | Loyalty lookup | T-F05-15 | New | Equals the oracle |

Benchmark items stay separate and are not acceptance criteria of WO-P3-P3-02 or of WO-P3-P3-01 task 2: T-PERF-01/02/08 and the creation-cost baseline (WO-P3-P3-03), all blocked by R-27.

## 9. Readiness of WO-P3-P3-02

| Item | State |
|---|---|
| D-006, D-024 | APPROVED ✔ |
| D-007, D-008 rule, D-009 | **PROPOSED** — statements §6.1–§6.3 |
| D-008 values | Open business configuration; not needed for implementation or tests (synthetic TEST_ONLY) |
| F002 tier part | Needs approval §6.4 |
| Precondition "WO-P3-P3-01 PASSED" | Not met: task 2 pending (§5); Owner acceptance needed after it |
| Target database for fixture tests | `FitLife_P3_UC05` (disposable, marker verified) |
| DS-L check (criterion 3, §8 of the WO) | Needs a new disposable database name, or a move to WO-P3-P3-03; `FitLife_P3_P2` stays read-only |
| Task 0 (Q-UC05-B/C baseline) | Plans, logical reads and row counts valid; timings DIAGNOSTIC_ONLY (R-27) |
| Scope boundary | Only P3 loyalty: aggregation, points, tier evaluation, lookup. No registration, membership administration, inventory, check-in, PT, or other members' modules |

**Verdict: NOT READY today; READY once §6.1–§6.6 are given.** Nothing else blocks it.
