# 11 — Test and QA Plan (Person 3)

| Field | Value |
|---|---|
| Document status | DRAFT — WO-P3-BOOT-001; test status and WO-P3-P3-00 tests (T-SCH-03, T-F05-23…26, V-UC05) added 2026-11-09 |
| Date | 2026-11-09 |
| Test status | Implemented and run (runtime evidence in `evidence/test-results/`): T-SCH-01, T-SCH-02, T-REPRO-01 (WO-P3-P1-01); T-SEED-01…05, T-REPRO-02, T-REC-01, T-REC-02 row part (WO-P3-P2-01); **T-SCH-03, T-F05-01, -03, -04, -18, -19, -23…-26, T-CONC-06, V-UC05 (WO-P3-P3-00, 2026-11-09, all PASS)**. Every other test below is PLANNED. |
| Rules that depend on decisions | Expected values that depend on an open decision cite it, e.g. "per D-006". Tests are finalised in the work order that builds the feature, after the decision is APPROVED. |

## 1. Test approach

| Aspect | Plan |
|---|---|
| Framework | Plain T-SQL test scripts: arrange (fixture) → act → assert (raise an error on mismatch) → clean up. Each script prints `PASS <TEST_ID>` or fails with a message. Installing a framework such as tSQLt is **not authorized**; it can be proposed later as a decision. |
| Result values | `PASS`, `FAIL`, or `NOT_RUN` with its reason and impact (master prompt §10). A test that was not executed is never reported as PASS. |
| Isolation | Tests run in isolated, disposable test databases built from the approved shared schema and migrations (D-025 conditions 2–4), never in the canonical shared database or a teammate's working database; rebuilt from scripts (T-REPRO-01). |
| Fixtures | Small hand-built fixtures for functional and boundary tests. DS-S/M/L for reconciliation, regression and performance. |
| Concurrency harness | Windows PowerShell 5.1 + built-in `System.Data.SqlClient`: N sessions started together (synchronised by a shared start time or an application lock released by the controller). Each calls the routine under test and records its outcome; the controller then asserts the database state. |
| Output | Every run saves its output to `docs/phase2/person3/evidence/test-results/<TEST_ID>__<YYYYMMDD-HHMM>.txt` ([10 §4.9](10_SEED_AND_BENCHMARK_PLAN.md#49-screenshot-and-evidence-conventions)). |
| Oracle | Correctness of aggregates is checked against deliberately simple recomputation queries over source invoices (no summaries, no hints). |

## 2. Test catalogue

### 2.1 Schema (WO-P3-P1-01)

| ID | Purpose | Expected result |
|---|---|---|
| T-SCH-01 | Constraint tests on the four P3-owned tables: invalid status/method, negative amounts, Final ≠ Gross − Discount, PaidAt without PAID, PaidAt < IssuedAt, SpendingMonth not on day 1, duplicate (Member_ID, SpendingMonth), missing FK parents (TEST_ONLY fixture keys), validation query V-TOT (cases in WO-P3-P1-01 §8.1) | Every invalid insert/update is rejected by the intended constraint; valid rows are accepted |
| T-SCH-02 | Deployed schema conforms to DL-01: P3 tables' columns, types, nullability, identity, defaults, keys, the 8 FKs, CHECK names; table classification (4 P3_OWNED, 5 key-only TEST_ONLY fixtures); no other user objects (no views, routines, triggers, or indexes beyond PK); every constraint enabled and trusted; compatibility level | Zero differences (catalog views vs the expected specification) |
| T-SCH-03 | UC05 database after the invoice-creation routine (WO-P3-P3-00; added 2026-11-09): table catalog identical to the accepted `FitLife_P3_P1` (read-only cross-database comparison); object inventory = P1 + 1 procedure + 2 table types; type definitions; write scope of the routine by dependency analysis (only the three invoice tables modified; shared tables read by key; no MEMBER_MONTHLY_SPENDING); no dynamic SQL; no extra principal or permission | All 6 checks PASS (`tests/db/schema/T-SCH-03_uc05_catalog_and_scope.sql`) |

### 2.2 Seed (WO-P3-P2-01)

| ID | Purpose | Expected result |
|---|---|---|
| T-SEED-01 | Row counts per tier ([10 §3.3](10_SEED_AND_BENCHMARK_PLAN.md#33-dataset-tiers)) | INVOICE per local month exact; line counts within tolerance; ≥ 70,000 where required; fixture key rows as configured |
| T-SEED-02 | Referential integrity, constraint trust, schema unchanged | Zero orphans on the 8 FKs; zero untrusted or disabled constraints; every CHECK re-evaluated without violation; every invoice has a line; no duplicate monthly key; fixtures key-only; no index, routine or partition added |
| T-SEED-03 | Distributions vs configuration | Within ± 2 percentage points, or 4 standard errors when the sample is small |
| T-SEED-04 | Payment states and timestamps (added 2026-11-08) | PAID rows have `PaidAt ≥ IssuedAt` and a method; PENDING and CANCELLED rows have neither; all timestamps inside the dataset range; delay ≤ 24 h |
| T-SEED-05 | Local-calendar month boundaries (added 2026-11-08) | Boundary rows at 23:59:59.999, 00:00:00.000 and 03:30 local exist for every month boundary; payments at 00:00–06:59 local on the 1st are counted in the local month |

Implemented in `tests/db/seed/T-SEED_dataset_checks.sql` (with V-TOT, T-REC-01 and T-REC-02 row part); T-REPRO-02 in `tests/db/seed/T-REPRO-02_checksums.sql`; runner `tests/db/seed/run_p2_dataset.ps1`.

### 2.3 UC05 functional (WO-P3-P3-01, WO-P3-P3-02)

Also WO-P3-P3-00 (invoice creation: T-F05-01, T-F05-03, T-F05-04, T-F05-18…T-F05-20), added 2026-11-08, and T-F05-23…T-F05-26, added 2026-11-09. Implemented in `tests/db/functional/T-F05_invoice_creation.sql` (43 cases; V-TOT after every case) with the whole-database check `tests/db/functional/V-UC05_integrity.sql` (V-UC05, I1–I10) after every stage; runner `tests/db/functional/run_uc05_invoice_creation.ps1`. **WO-P3-P3-01 (2026-11-09):** settlement and cancellation cases T-F05-02, -05…-11, -16, -21, -22 and T-F05-27…-31 in `tests/db/functional/T-F05S_settlement.sql` (47 cases; whole-state hash before/after every call) with `tests/db/functional/V-UC05S_settlement_integrity.sql` (U1–U10) and runner `tests/db/functional/run_uc05_settlement.ps1`; T-CONC-01/02 run there as well (harness `tests/db/concurrency/T-CONC-01_02_parallel_settlement.ps1`, final-state checks). **WO-P3-P3-01 task 2 and WO-P3-P3-02 (2026-11-09):** T-F05-36/37 in `tests/db/functional/T-F05-U0_settlement_baseline.sql`; T-F05-12…-15 and -32…-35 in `tests/db/functional/T-F05L_loyalty_tiers.sql`; T-REC-01/02/04 in `tests/db/reconciliation/T-REC_loyalty.sql`; whole-database check V-UC05T; runners `run_uc05_settlement_u0.ps1`, `run_uc05_loyalty.ps1`. Thresholds are TEST_ONLY synthetic values read from MEMBER_TIER.

| ID | Case | Expected result |
|---|---|---|
| T-F05-01 | Valid invoice with ≥ 1 line; header totals = Σ lines (D-023) | Accepted; totals consistent |
| T-F05-02 | Settle an invoice with zero lines (BR12) | Rejected with the P3 error; no state change |
| T-F05-03 | Invalid amounts (negative quantity/price, discount > gross, Final < 0) | Rejected |
| T-F05-04 | Unknown member/branch/employee/plan/product | Rejected by FK |
| T-F05-05 | Settle a PENDING invoice | PAID; PaidAt and method set; spending row +FinalAmount; points per D-006; CurrentPoints increased; summary updated if adopted — each exactly once |
| T-F05-06 | Settle the same invoice again (sequential repeat) | `ALREADY_SETTLED`; no second effect on any table |
| T-F05-07 | Settle a CANCELLED or non-existent invoice | Rejected; no side effects |
| T-F05-08 | Rollback: injected failure in a late step (test-only trigger, [06 §4.8](06_UC05_BILLING_LOYALTY_PLAN.md#48-transaction-rollback)) | Status, PaidAt, spending, points, inventory, entitlements, summary all unchanged |
| T-F05-09 | Point boundaries: one invoice of 0; 99,999; 100,000; 199,999; 200,000 VND in an otherwise empty month; then two invoices of 60,000 VND in one month (per D-006) | 0, 0, 1, 1, 2 under both rules; the two 60,000 VND invoices give 1 point under (b) (proposed) and 0 under (a) |
| T-F05-10 | Month boundary in local time with UTC storage: PaidAt `2026-01-31 16:59:59.999` UTC (= Jan 31 23:59:59.999 local) vs `2026-01-31 17:00:00.000` UTC (= Feb 1 00:00 local) | January vs February SpendingMonth respectively (per D-004, D-013, D-014) |
| T-F05-11 | First vs subsequent payment of a member within a month | First inserts the spending row; later ones update the same row (BR06) |
| T-F05-12 | Tier thresholds: spend just below, exactly at and above each threshold; upgrade; downgrade; unchanged (per D-008) | Correct tier; ≥ rule applied |
| T-F05-13 | Window boundary: spending leaves the window (per D-007) | Downgrade at the next evaluation when the window spend falls below the threshold |
| T-F05-14 | Run the tier batch twice for the same as-of date | Second run changes nothing |
| T-F05-15 | Loyalty lookup | Returned points, tier, window spend and gap to next tier equal the oracle |
| T-F05-16 | Cancel a PENDING invoice (if D-011 includes it) | CANCELLED; no loyalty or revenue effects; cannot be settled afterwards |
| T-F05-17 | Refund (only if D-011 includes refunds) | Reversal per approved rule; reconciliation still holds |
| T-F05-18 | Create an invoice with zero lines (BR12) | Rejected with the P3 error; no header row remains |
| T-F05-19 | Creation fails on one line (e.g. unknown product, invalid amount) | Nothing is created: no header, no lines |
| T-F05-20 | Repeat a creation with the same client request key (only if D-028 Q5 (b)) | The existing invoice is returned; no second invoice |
| T-F05-21 | Settlement calls each hook (test double) exactly once per settled invoice, in the lock order, and never on a repeated or rejected settlement | Call log shows one call per hook per settlement |
| T-F05-22 | A hook (test double) raises an error | Whole settlement rolled back: status, PaidAt, spending, points unchanged; error passed through |
| T-F05-23 | Repeat an identical creation request (no request key; D-028 Q5 not (b)) | Two distinct PENDING invoices with identical business values; no rejection by any uniqueness on business values. Exactly-once creation is not provided and not claimed |
| T-F05-24 | Side effects of creation | None: no MEMBER_MONTHLY_SPENDING row, shared key fixtures unchanged, ValidFrom/ValidUntil/PTSessionsRemaining NULL, every invoice PENDING with PaidAt NULL |
| T-F05-25 | Creation inside a caller's transaction (12 §4) | Commit keeps the invoice; rollback removes it; a routine error leaves the caller's transaction uncommittable and one rollback removes all its work |
| T-F05-26 | Least privilege (RQ-P15; TEST_ONLY role and user) | EXECUTE on the routine and its line types suffices to create invoices; direct INSERT/UPDATE on the invoice tables is denied |
| T-F05-27 | Settlement payment-method rules (D-005; DEP-18): method outside the domain or not exact (`CHEQUE`, `cash`, `CASH `, empty); no method supplied or recorded; supplied method differs from the one recorded at creation | Rejected (51202, 51207, 51208); nothing written; the recorded method then settles |
| T-F05-28 | Settle an invoice whose header totals differ from its lines (TEST_ONLY row inserted directly; D-023 X1) | Rejected (51206); nothing written |
| T-F05-29 | Settlement inside a caller's transaction (12 §4) | Commit keeps all effects; rollback removes all; a later error leaves the transaction uncommittable and one rollback removes the earlier settlement |
| T-F05-30 | Least privilege for settlement (RQ-P15; TEST_ONLY role and user) | EXECUTE on the routines suffices; direct PAID→PENDING update, points or spending changes and direct hook calls denied (229) |
| T-F05-31 | Settle an invoice whose IssuedAt is later than the settlement time (TEST_ONLY row; D-004) | Rejected (51212); nothing written |
| T-F05-32 | 25 settled invoices of 4,000 VND in one month (D-006) | Points per call 0 x24, then 1 at the cumulative 100,000; one month row |
| T-F05-33 | Payments at 2025-12-31 16:59:59.999 / 17:00:00.000 UTC (TEST_ONLY history helper; same month function as settlement) | December 2025 row / January 2026 row |
| T-F05-34 | Failure injected in one chunk of usp_P3_EvaluateTiers (TEST_ONLY trigger, chunk size 1) | That chunk and later chunks unchanged, earlier chunks kept, error passed through; a re-run completes and equals the oracle |
| T-F05-35 | Invalid MEMBER_TIER configuration (second tier at 0; duplicate threshold) | Batch and lookup refuse (51322 / 51323); nothing written |
| T-F05-36 | U0 reference variant (WO-P3-P3-01 task 2): settlement contract kept; window recomputed from INVOICE; boundaries; repeat; rejected requests | As U1 plus exactly the synchronous re-rank; no change on repeat or rejection |
| T-F05-37 | U0 rollback: failure at its tier update; inside a caller transaction | Everything rolled back; caller transaction uncommittable after an error |

### 2.4 UC06 functional (WO-P3-P4-01, WO-P3-P4-02)

| ID | Case | Expected result |
|---|---|---|
| T-F06-01 | Branch revenue by day/month/quarter/year | Equals oracle for every branch and period in the dataset |
| T-F06-02 | System revenue and per-branch share | System total = Σ branches = oracle; shares sum to 100% (rounding stated) |
| T-F06-03 | Status filter | PENDING and CANCELLED excluded |
| T-F06-04 | Half-open boundaries (local periods converted to UTC bounds) | Row at @From included; row at @To excluded; a payment at 00:30 local on the 1st belongs to the new month |
| T-F06-05 | Empty period / branch without sales | Behaviour as specified in [07 §2](07_UC06_REVENUE_PLAN.md#2-revenue-semantics-pending-d-010): totals return one row with 0.00 and 0 invoices; grouped reports return no row |
| T-F06-06 | Top plans by revenue, last 6 months (if in scope) | Equals oracle, ranking ties defined |
| T-F06-07 | Best sellers per branch (if in scope) | Equals oracle |
| T-F06-08 | Tier distribution (if in scope) | Counts and percentages equal oracle |
| T-F06-09 | PaidAt, not IssuedAt, decides the period (added 2026-11-10, WO-P3-P4-01 Part F) | An invoice issued in one local month and paid in the next counts in the payment month; a report dated by IssuedAt would give a different, known amount |
| T-F06-10 | Discounts exactly once; multi-line invoices | Revenue = FinalAmount (not gross, not discounted twice); an invoice with several lines contributes once; report = line-level reference |
| T-F06-11 | Real path through the UC05 routines | 0 while PENDING; + FinalAmount after settlement; unchanged after a repeated settlement, a cancelled invoice and a pending invoice |
| T-F06-12 | Invalid parameters | NULL 51401; `@FromDate >= @ToDate` 51402; unknown branch 51403; invalid grain 51404; nothing returned |
| T-F06-13 | Detail = aggregate | Day, month, quarter and year rows, branch totals, the system total and an independent invoice-level reference all agree |

T-F06-01…05 and 09…13 are implemented in `tests/db/functional/T-F06_revenue_reports.sql` (fixture R001, literal expectations). The comparison "for every branch and period in the dataset" (T-F06-01, T-F06-02) is T-REC-05 (§2.7).

### 2.5 Concurrency (WO-P3-P3-03)

| ID | Case | Expected result |
|---|---|---|
| T-CONC-01 | N = 10 parallel settlements of the same invoice | Exactly 1 `SETTLED`, N−1 `ALREADY_SETTLED` (or a defined retryable error); effects applied once |
| T-CONC-02 | Parallel settlements of different invoices of the same member, same month | Spending row TotalSpend = Σ; points = Σ; no PK violation surfaces to the caller; no lost update |
| T-CONC-03 | Parallel settlements in the same branch-day (if a summary is adopted) | Summary = Σ; no lost update |
| T-CONC-04 | Settlements running concurrently with the tier batch and report queries | No inconsistency; deadlocks (if any) only produce retryable error 1205, handled by retry; blocking duration recorded |
| T-CONC-05 | Settlement vs a concurrent sale of the same scarce product (with the UC04 owner; real inventory routine, so WO-P3-P6-01) | No negative stock; the losing settlement rolls back completely |
| T-CONC-06 | N = 10 sessions create invoices in parallel (WO-P3-P3-00) | Distinct invoices; every header equals the sum of its lines (V-TOT = 0); no lost or misattached lines |
| T-CONC-04F | Functional variant of T-CONC-04 (WO-P3-P3-02): 8 settlement sessions concurrent with 2 tier-batch sessions, then quiescent runs | All SETTLED; no downgrade reported while spending only grows; final Tier_ID = oracle from INVOICE; no lost spending or points; second final run changes nothing. No timing |
| T-CONC-04R | Report part of T-CONC-04 (WO-P3-P3-03 Part C, 2026-11-10; `tests/db/concurrency/T-CONC-04R_reports_vs_settlement.ps1`). R1: each of the five report routines started while a settlement is uncommitted, then ROLLBACK / COMMIT. R2: 6 committing + 2 aborting (x.01 VND, rolled back) settlement sessions vs 3 report sessions. R3: two report statements in one caller-chosen SERIALIZABLE transaction while a settlement commits | R1: the report waits for the writer and returns exactly the before value after ROLLBACK, before + amount after COMMIT. R2: no observed total contains rolled-back cents (no dirty read); every value between the committed state before and after; company totals non-decreasing per session; single-statement sums consistent; final delta = committed amounts; aborted invoices without any effect. R3: the settlement waits; both statements agree; the settlement is reported after COMMIT. Database isolation settings unchanged (RCSI and snapshot OFF). No timing |
| T-CONC-07 | Tier batch vs tier batch (WO-P3-P3-03 Part C; `tests/db/concurrency/T-CONC-07_tier_batch_serialisation.ps1`). T1 deterministic stale-overwrite scenario (older run held after its snapshot, payment, newer run); T2 application lock held elsewhere; T3 failure inside a chunk; T4 client timeout (characterisation) | T1: the newer run waits on the application lock and never overlaps; no downgrade; final tier = oracle. T2: error 51324, nothing written; after release the upgrade is applied. T3: error passed on; no application lock and no open transaction left; the re-run completes. T4: closing the cancelled session releases everything; re-run correct (lock behaviour during the open session recorded). No timing |

### 2.5a Integrated workflow (WO-P3-P3-03 Part C)

| ID | Case | Expected result |
|---|---|---|
| T-WF-01 | `tests/db/functional/T-WF-01_uc05_uc06_workflow.sql`: 14 invoices of members 1-10 (service, product, mixed lines, discounts, three branches); settlement, repeats, cancellation, a PENDING invoice, hook faults, a method mismatch, a caller transaction rolled back after create + settle; daily tier batch twice; all five report routines | Checked on the final database state: W1 header = lines; W2 at most one settlement and one call per hook per PAID invoice; W3 PaidAt rules; W4 CANCELLED/PENDING without effect; W5 monthly spending = PAID per local month; W6 D-006 on the monthly total; W7 tiers = literal (threshold inclusive) = oracle, second run no change; W8 revenue per branch/company = harness amounts; W9 every report = independent reference and = monthly spending; W10 unrelated rows and shared fixtures unchanged; W11 injected failures leave nothing |

### 2.6 Integration (WO-P3-P6-01; contract-level checks in WO-P3-P3-01)

Since 2026-11-08 (D-027), T-INT-01…T-INT-03 run against the real shared objects in WO-P3-P6-01 stage A; in P3 the hook contract is tested with test doubles (T-F05-21, T-F05-22).


| ID | Case | Expected result |
|---|---|---|
| T-INT-01 | Settlement activates service entitlements exactly once (UC01 contract) | Entitlement usable after settlement, not before; not doubled on repeat |
| T-INT-02 | Settlement decrements inventory atomically; insufficient stock aborts all | Stock correct; on abort nothing changes |
| T-INT-03 | P3 scripts deploy on top of the team's shared base schema, after the TEST_ONLY fixtures are replaced (D-026 condition 9) | No errors; FK types and names compatible |
| T-INT-04 | Application screens/endpoints call P3 routines and show values equal to the database | Screenshots plus database query match; permissions respected (RQ-P15) |

### 2.7 Reconciliation (WO-P3-P2-01, WO-P3-P3-03, WO-P3-P4-02, WO-P3-P7-01)

| ID | Invariant |
|---|---|
| T-REC-01 | For every (member, month): TotalSpend = Σ FinalAmount of PAID invoices recognised in that month |
| T-REC-02 | PointsEarned per row and CurrentPoints per member follow D-006/D-024 (e.g. CurrentPoints = Σ PointsEarned) |
| T-REC-03 | Revenue summary or indexed view = oracle aggregation for every branch and day (if adopted) |
| T-REC-04 | MEMBER.Tier_ID = tier computed from window spend as of the last evaluation |
| T-REC-05 | Added 2026-11-10 (WO-P3-P4-01 Part F): every revenue report routine = an independent reference (AT TIME ZONE local dates per PAID invoice) for every branch and local month of the data and all four grains; branches sum to the system total; report = line-level amounts of the PAID invoices; and, where the UC05 aggregate exists, Σ MEMBER_MONTHLY_SPENDING.TotalSpend per month = system revenue of that month (`tests/db/reconciliation/T-REC_revenue.sql`, checks V1–V11) |

Expected result for each: zero mismatching rows.

### 2.8 Regression (WO-P3-P4-01, WO-P3-P5-01, WO-P3-P7-01)

| ID | Case | Expected result |
|---|---|---|
| T-REG-01 | After every index/summary change: all functional and reconciliation tests; all P3 queries give the B0 result hash | All pass; hashes equal |
| T-REG-02 | Partitioned copy vs non-partitioned table for the same queries | Hashes equal |
| T-REG-03 | Other members' registered queries on shared tables, before vs after P3 changes | No logical-read regression > 10% ([08 §6](08_INDEX_AND_QUERY_PLAN.md#6-adoption-and-rejection-criteria)) |

### 2.9 Performance (measured per [10](10_SEED_AND_BENCHMARK_PLAN.md))

| ID | Measurement |
|---|---|
| T-PERF-01 | Q-UC05-A (INVOICE recomputation) vs bounded spending-table read, DS-M and DS-L |
| T-PERF-02 | Settlement U0 vs U0/IX-03 vs U1 (vs U1 + D-009 b): per-call logical reads, CPU, elapsed |
| T-PERF-03 | Q-UC06-A across B0–B5 |
| T-PERF-04 | Q-UC06-B across B0–B5 |
| T-PERF-05 | Q-UC06-C and Q-UC06-D across B0–B5; Q-UC06-A0 vs Q-UC06-A (sargability demonstration) |
| T-PERF-06 | Write overhead of each candidate index/summary on settlement and invoice insert |
| T-PERF-07 | Partition PoC: elimination evidence and metrics (B2, B3) |
| T-PERF-08 | Q-UC05-B loyalty lookup and Q-UC05-C tier batch runtime |

Performance tests have no pass/fail on absolute time unless the team sets targets (D-022). They pass when evidence is complete and reproducible; adoption decisions use [08 §6](08_INDEX_AND_QUERY_PLAN.md#6-adoption-and-rejection-criteria).

### 2.10 Reproducibility

| ID | Case | Expected result |
|---|---|---|
| T-REPRO-01 | Clean install of all P3 scripts on an empty database in documented order | Success, with no manual steps |
| T-REPRO-02 | Seed twice with the same seed | Identical per-table checksums |
| T-REPRO-03 | Re-run a benchmark configuration on another day, same machine | Logical reads identical; elapsed medians within the documented noise band; deviations explained |

## 3. Entry and exit criteria

| Phase | Entry | Exit (all must hold) |
|---|---|---|
| P1 | Decisions listed in the WO approved | T-SCH-01, T-SCH-02, T-REPRO-01 pass; T-INT-03 passes if the shared schema exists |
| P2 | GATE-P1 passed | T-SEED-01…03, V-TOT, T-REC-01, T-REC-02 (row part), T-REPRO-02 pass; baseline evidence complete |
| P3 | GATE-P2 passed | T-F05-xx (in scope, incl. T-F05-18…22), T-CONC-01…04, T-CONC-06, T-REC-01/02/04 pass; T-PERF-01/02/08 evidence complete; T-INT-01/02 (real routines) and T-CONC-05 `NOT_RUN` until P6 |
| P4 | GATE-P2 passed (WO-P3-P3-01 PASSED for write-overhead tests) | T-F06-xx, T-REG-01, T-REC-03 (if summary) pass; T-PERF-03…06 evidence complete; T-REG-03 `NOT_RUN` until P6 |
| P5 | GATE-P4 passed (best B1 results available) | T-REG-02 pass; T-PERF-07 evidence complete; D-017 decided |
| P6 | GATE-P3, GATE-P4, GATE-P5 passed; WO-P3-P1-02 PASSED; D-020 APPROVED | T-SCH-01/02, T-INT-01…04, T-CONC-05, T-REG-03 pass |
| P7 | GATE-P3…GATE-P6 passed | Full regression green; T-REPRO-01…03 pass; final benchmark complete |

## 4. Defect handling

- Any failure of a correctness, concurrency or reconciliation test **blocks phase exit**. There are no waivers without Project Owner approval recorded in the WO.
- A defect is recorded in the WO execution record: ID, test, symptom, cause, fix, re-test result.
- A performance result that contradicts a hypothesis is **not** a defect. It is recorded as a finding.
