# 07 — UC06 Revenue Reporting Plan

| Field | Value |
|---|---|
| Document status | DRAFT — WO-P3-BOOT-001; §11 (P4 priority) added by the Owner Directive "Reprioritize Person 3 Implementation" (2026-11-08, D-027); §2–§4 updated and §12 (implemented report routines) added by the Owner Directive "Accept Loyalty & Implement UC06 Revenue Correctness" (2026-11-10: D-010 approved T2; WO-P3-P4-01 Part F) |
| Date | 2026-11-10 |
| Functions | F27 branch revenue (120/day), F28 system revenue (20/day); candidates F30 / RQ-A16 / RQ-A18 (D-001) |
| Requirements | RQ-A11, RQ-A14–RQ-A18, RQ-P02, RQ-P04 |
| Decisions | Open: D-001 (scope of RPT-05…07). Approved provisionally (T2): **D-010 (definition, 2026-11-10)**; D-004 (PaidAt), D-014 (UTC storage, Asia/Ho_Chi_Minh reporting), D-023 (line revenue) (2026-11-07). D-015–D-017 decided by evidence. |

## 1. Problem statement

- **S-01 p3, Problem 3 (REQUIRED_BY_ASSIGNMENT):** monthly revenue reports take more than 1 minute. The task is to propose partitioning and a summary table or View/Trigger.
- **S-01 §4 (suggested reports):** branch revenue by day/month/quarter/year; system revenue with branch comparison; top plan by revenue (6 months); best sellers per branch; tier distribution.
- **S-02 §7.1 UC06:** reduce report runtime on large data.
- **Honesty constraint:** the P3 invoice volume (324,000 rows/year) is unlikely to reproduce a 1-minute runtime on modern hardware ([04 §4](04_WORKLOAD_AND_DATA_VOLUME.md#4-rough-storage-estimate-assumption_pending_approval-verify-with-sp_spaceused-after-seeding)). The report will present **measured** baseline numbers, whatever they are. It will compare configurations by logical reads, CPU and elapsed time, and will not claim to have reproduced or fixed a 1-minute problem unless a measurement shows one (R-08).

<a id="2-revenue-semantics-pending-d-010"></a>

## 2. Revenue semantics (D-010 approved, provisional T2, 2026-11-10)

The rules below are the approved definition for isolated Person 3 development ([D-010](03_DECISION_LOG.md#d-010--definition-of-recognised-revenue): nine rules of the Owner Directive of 2026-11-10 §4). Team reconciliation is required before integration. The last row (empty periods) is not part of D-010 and stays an assumption.

| Element | Rule | Label |
|---|---|---|
| Amount | INVOICE.FinalAmount (after discounts) | D-010 rule 2 (APPROVED T2) |
| Population | PaymentStatus = 'PAID' only; PENDING and CANCELLED excluded | D-010 rules 1, 7 (D-005 literal) |
| Date | PaidAt (D-004), never IssuedAt | D-010 rule 3 |
| Branch | INVOICE.Branch_ID (issuing branch) | D-010 rule 6; DERIVED_FROM_PHASE1 (BR08) |
| Company-wide revenue | Sum of the qualifying branch revenue under the same filters and period | D-010 rule 9 |
| Recognition | The whole FinalAmount at the payment time; service plans are not spread over their validity | Consequence of D-010 rules 1–3 |
| Refunds | Out of scope (D-011) | D-010 rule 8 |
| Periods | Half-open `[From, To)` on the Asia/Ho_Chi_Minh calendar; grains day, month, quarter, year. PaidAt is stored in UTC (D-014, 2026-11-07), so the local bounds are converted to UTC (subtract 7 hours) **once, on the parameters**, and the predicate stays `PaidAt >= @FromUtc AND PaidAt < @ToUtc`. Grouping by local day/month uses the converted value in the SELECT list and GROUP BY, never in WHERE. As implemented (§12), the routines take the local dates and do this conversion themselves, so every caller gets the same rule. | D-010 rules 4, 5; REQUIRED_BY_ASSIGNMENT (grains), TECHNICAL_RECOMMENDATION (half-open), D-014 (UTC) |
| Currency | VND, DECIMAL(18,2) (D-014) | TECHNICAL_RECOMMENDATION |
| Empty periods | Branch rows with zero revenue are shown only if the report spec says so; default: omit rows, the application fills zeros. Implemented default (§12): the two total routines always return one row (0.00, 0 invoices); the grouped routines return no row for a branch or bucket without a paid invoice | ASSUMPTION_PENDING_APPROVAL (not part of D-010) |

## 3. Filters and parameters

| Parameter | Meaning | Note |
|---|---|---|
| @Branch_ID | One branch (F27) | System report (F28) has no branch filter; keep it a separate query shape (see [05 §7](05_PHYSICAL_DESIGN_PLAN.md#7-stored-procedures-and-transaction-boundaries-planned-not-implemented)). Unknown branch: error 51403 |
| @FromDate, @ToDate (planned as @From, @To) | Half-open period of **local** calendar dates: `[@FromDate 00:00, @ToDate 00:00)` Asia/Ho_Chi_Minh | A month is (first day, first day of the next month). Never passed as YEAR()/MONTH() values. NULL: 51401; `@FromDate >= @ToDate`: 51402 |
| @Grain | DAY, MONTH, QUARTER, YEAR | Grouping expression on the local payment date (SELECT / GROUP BY only). Other values: 51404 |

## 4. Report catalogue

| Report | Query ID | Content | Scope | Routine (§12) |
|---|---|---|---|---|
| RPT-01 Branch revenue, single period | Q-UC06-A | Total revenue and invoice count of one branch in [From, To) | Core (RQ-A14) | `usp_P3_RptBranchRevenue` |
| RPT-02 System revenue by branch | Q-UC06-B | Per-branch revenue, count, share of system total, system total | Core (RQ-A15) | `usp_P3_RptSystemRevenueByBranch`; total alone: `usp_P3_RptSystemRevenue` |
| RPT-03 Branch daily series | Q-UC06-C | Revenue per day in a month for one branch | Core (RQ-A14) | `usp_P3_RptBranchRevenueByPeriod` (`@Grain = 'DAY'`) |
| RPT-04 Quarter/year revenue | Q-UC06-D | Revenue per quarter/year, per branch or system | Core (RQ-A14, RQ-A15) | `usp_P3_RptBranchRevenueByPeriod` (MONTH, QUARTER, YEAR); `usp_P3_RptSystemRevenueByPeriod` |
| RPT-05 Top plans by revenue, last 6 months | Q-UC06-E | Plan revenue from service lines (D-023) | Candidate (RQ-A16) | Not implemented (D-001) |
| RPT-06 Best sellers per branch | Q-UC06-F | Quantity and revenue per product/plan | Candidate (RQ-A17) | Not implemented (D-001) |
| RPT-07 Tier distribution | Q-UC06-G | Member count and % per tier | Candidate (RQ-A18) | Not implemented (D-001) |

## 5. Baseline query candidates (specifications, to be frozen in WO-P3-P2-02)

These are **specifications**. The exact SQL text is written and frozen in `db/queries/baseline/` by WO-P3-P2-02 and is never edited afterwards, so that comparisons stay valid.

| Query | Specification |
|---|---|
| Q-UC06-A | From INVOICE where Branch_ID = @Branch_ID and PaymentStatus = 'PAID' and PaidAt ≥ @From and PaidAt < @To: SUM(FinalAmount), COUNT_BIG(*) |
| Q-UC06-A0 | **Teaching variant:** same result, written with YEAR(PaidAt) = @Y and MONTH(PaidAt) = @M (non-SARGable). It demonstrates why predicates on the column must stay sargable (S-07 execution-plan method). Not a configuration baseline. |
| Q-UC06-B | From INVOICE where PaymentStatus = 'PAID' and PaidAt in [From, To), grouped by Branch_ID: SUM, COUNT_BIG; share = branch / total (window aggregate or second pass) |
| Q-UC06-C | As Q-UC06-A, grouped by CAST(PaidAt AS DATE) |
| Q-UC06-D | As Q-UC06-B over a multi-month range, grouped by calendar quarter or year of PaidAt |
| Q-UC06-E | INVOICE_SERVICE_ITEM joined to INVOICE (PAID, last 6 months), grouped by Plan_ID: SUM(UnitPrice − DiscountAmount), ranked descending |
| Q-UC06-F | INVOICE_PRODUCT_ITEM joined to INVOICE (PAID, branch, period), grouped by Product_ID: SUM(Quantity), SUM(UnitPrice × Quantity − DiscountAmount) |
| Q-UC06-G | MEMBER grouped by Tier_ID joined to MEMBER_TIER: COUNT, percentage |

Benchmark parameter sets (fixed for every configuration) are defined in [10 §4.2](10_SEED_AND_BENCHMARK_PLAN.md#42-fixed-parameter-sets).

## 6. Index candidates to evaluate

From [08 §4](08_INDEX_AND_QUERY_PLAN.md#4-candidate-index-register): IX-01 (Branch_ID, PaidAt) for Q-UC06-A/C/D; IX-02 (PaidAt) for Q-UC06-B/D; IX-08 and IX-09 for Q-UC06-F/E; IX-11 for Q-UC06-G; IX-10 (nonclustered columnstore, optional advanced experiment).

## 7. Aggregation alternatives

| Alternative | How it answers RPT-01–04 | Pros | Cons / risks | Decision |
|---|---|---|---|---|
| A1 Direct aggregation on INVOICE (B0) | Scan + aggregate | No extra structures | Cost grows with history | Baseline |
| A2 Covering (filtered) index | Range seek + aggregate on a narrow index | Small, transparent, no derived data | Write cost on INVOICE; filtered-index caveats ([08 §7](08_INDEX_AND_QUERY_PLAN.md#7-query-writing-rules)) | WO-P3-P4-01 |
| A3 Branch × day summary table | Sum ≤ 31 rows/month/branch; ≤ 4,380 rows/year | Answers all four grains; tiny | Derived data, so it needs maintenance (D-016) and reconciliation (T-REC-03); hot row per branch-day | WO-P3-P4-02 |
| A4 Branch × month summary | ≤ 144 rows/year | Smallest | **Cannot answer daily reports (RPT-03)** | Not recommended alone |
| A5 Indexed view grouped by branch and payment date | Engine-maintained aggregate | Always consistent; course "View" option | Restrictions (SCHEMABINDING, COUNT_BIG, deterministic expressions, non-nullable SUM argument); edition-dependent automatic matching (NOEXPAND may be required, G-20) | WO-P3-P4-02 |
| A6 Nonclustered columnstore on INVOICE | Batch-mode scan | Strong for large scans | Questionable at 324k rows; write overhead; advanced/optional | Optional in WO-P3-P4-01 |
| A7 Partitioning | Partition elimination | Course technique | Key/alignment cost; scale likely too small ([09](09_PARTITION_FEASIBILITY_PLAN.md)) | WO-P3-P5-01 |

## 8. Expected execution-plan observations (hypotheses to verify)

| Config | Hypothesis for Q-UC06-A | What would falsify it |
|---|---|---|
| B0 | Clustered Index Scan of INVOICE; residual predicate on Branch/PaidAt/Status; Stream or Hash Aggregate; logical reads ≈ all INVOICE pages | A seek appears (impossible without an index), or reads are far below the page count |
| B1 + IX-01 | Index Seek on (Branch_ID, PaidAt) range; no Key Lookup (FinalAmount included); Stream Aggregate; logical reads ≈ pages of one branch-month slice | Optimizer chooses a scan (check estimates; check whether the status literal matches the filter) |
| B1 + IX-02 for Q-UC06-B | Index Seek on the PaidAt range, Hash Aggregate on Branch_ID | — |
| B4 (summary) | Seek on the summary PK range; tens of rows read | — |
| Q-UC06-A0 vs Q-UC06-A with IX-01 | A0 cannot seek on the PaidAt range (scan of the index or table) | A0 seeks (would contradict the sargability rule) |

## 9. Data consistency checks

- Oracle query: a deliberately simple, obviously-correct aggregation over INVOICE (no summary, no hints), used as the reference for T-F06-01…T-F06-05.
- Every optimised configuration must return identical rows (compared by a result hash) on the same parameters (T-REG-01).
- Summary/indexed-view totals must equal the oracle for every branch and period in the dataset (T-REC-03).
- Boundary rows: invoices at exactly @From are included and at exactly @To excluded (T-F06-04).

## 10. Benchmark comparisons

| Config | Indexes | Partition | Summary | Question answered |
|---|---|---|---|---|
| B0 | PK + required UNIQUE only | No | No | Baseline cost |
| B1 | B0 + one candidate (one run per candidate) | No | No | What does each index contribute? |
| B2 | B0 | Yes (benchmark copy) | No | What does partitioning alone contribute? |
| B3 | B1 best candidate, aligned | Yes | No | Do index and partition complement each other? |
| B4 | B0 | No | Yes | What does the summary contribute? |
| B5 | Adopted items only | Per D-017 | Per D-015 | Final design |

Each configuration is tested on DS-M and DS-L with identical parameter sets. One structure is changed at a time (S-09 method, consistent with S-07). Protocol: [10](10_SEED_AND_BENCHMARK_PLAN.md).

## 11. P4 priority and independence (2026-11-08)

P4 runs independently of the other members (D-027) and follows this order:

1. **Core reports first:** revenue by branch (RPT-01, RPT-03: Q-UC06-A, C), monthly revenue (RPT-01/03 over a month; RPT-04 by month: Q-UC06-A, C, D) and system-wide revenue with branch comparison (RPT-02, RPT-04: Q-UC06-B, D). These need D-010, not D-001.
2. **Correctness before speed:** every report equals the oracle over **PAID invoices only** (D-010, DEP-08), including the half-open local-calendar boundaries (T-F06-04), before any configuration is measured (T-F06-xx, T-REG-01).
3. **Baseline versus optimised plans:** B0 from WO-P3-P2-02, then B1 with exactly one candidate at a time, same data and parameters; Actual Execution Plans, logical reads, CPU, elapsed time, and the write overhead on creation and settlement (T-PERF-06).
4. **Candidates from the actual predicates** of the frozen queries ([08 §3–§4](08_INDEX_AND_QUERY_PLAN.md#3-query-to-access-path-matrix)): IX-01 and IX-02 first, then IX-03 (UC06 use), IX-04/IX-05 (FK support), IX-10 (optional). IX-08/IX-09 only if RPT-05/06 are assigned to P3 (D-001).
5. **Evidence-backed decision** for each candidate: ADOPTED or REJECTED against [08 §6](08_INDEX_AND_QUERY_PLAN.md#6-adoption-and-rejection-criteria), recorded in `design/INDEX_DECISIONS.md`. Unnecessary indexes are not kept to demonstrate a technique.
6. **Deferred to P6:** other members' regression queries (T-REG-03, DEP-09) and indexes on shared tables (IX-11 on MEMBER). An index adopted in P4 is a recommendation for promotion, reviewed by the team at P6.

## 12. Implemented report routines (WO-P3-P4-01 Part F, 2026-11-10)

Functional scope only. Status, evidence and test results: [WO-P3-P4-01 §13](work-orders/WO-P3-P4-01_UC06_INDEX_EXPERIMENTS.md#13-execution-record). File: [db/procedures/usp_P3_RevenueReports.sql](../../../../db/procedures/usp_P3_RevenueReports.sql). **No index, summary, view or partition exists, and no performance statement is attached to these routines** (§10 stays as planned; WO-P3-P2-02, WO-P3-P4-01 Part X, WO-P3-P4-02, WO-P3-P5-01).

### 12.1 Objects

| Object | Report | Parameters | Result |
|---|---|---|---|
| `dbo.usp_P3_RptBranchRevenue` | RPT-01 | `@Branch_ID`, `@FromDate`, `@ToDate`; OUTPUT `@Revenue`, `@InvoiceCount` | Always one row: Branch_ID, FromDate, ToDate, Revenue, InvoiceCount (0.00 and 0 when nothing is paid) |
| `dbo.usp_P3_RptSystemRevenue` | RPT-02 (total) | `@FromDate`, `@ToDate`; OUTPUT `@Revenue`, `@InvoiceCount` | Always one row: FromDate, ToDate, Revenue, InvoiceCount |
| `dbo.usp_P3_RptSystemRevenueByBranch` | RPT-02 (comparison) | `@FromDate`, `@ToDate` | One row per branch with a paid invoice: Branch_ID, Revenue, InvoiceCount, SystemRevenue, SystemInvoiceCount, SharePct |
| `dbo.usp_P3_RptBranchRevenueByPeriod` | RPT-03, RPT-04 (branch) | `@Branch_ID`, `@FromDate`, `@ToDate`, `@Grain` | One row per bucket with a paid invoice: PeriodStart, Revenue, InvoiceCount |
| `dbo.usp_P3_RptSystemRevenueByPeriod` | RPT-04 (system) | `@FromDate`, `@ToDate`, `@Grain` | One row per bucket and branch: PeriodStart, Branch_ID, Revenue, InvoiceCount, PeriodSystemRevenue, PeriodSystemInvoiceCount |
| `dbo.tvf_P3_ReportPeriodUtc` | — | `@FromDate`, `@ToDate` (local) | FromUtc, ToUtc (local midnight minus 7 hours) |
| `dbo.tvf_P3_ReportPeriodStart` | — | `@PaidAtUtc`, `@Grain` | PeriodStart: first local day of the day, month, quarter or year of the payment |

### 12.2 Rules built into the routines

1. **One statement over INVOICE per routine**, always with the same filter: `PaymentStatus = 'PAID' AND PaidAt >= @FromUtc AND PaidAt < @ToUtc` (plus `Branch_ID = @Branch_ID` in the branch reports). The status is a literal (08 §7 rule 2). No function is applied to `PaidAt` in a filter (08 §7 rule 1).
2. **Local calendar:** the UTC bounds are the local dates minus 7 hours (Asia/Ho_Chi_Minh has no daylight saving; the same fixed rule as `tvf_P3_SpendingMonth` and the seed generator). Example: local January 2026 = `[2025-12-31 17:00:00.000, 2026-01-31 17:00:00.000)` UTC.
3. **Header only:** revenue is `SUM(INVOICE.FinalAmount)`. The line tables are never joined, so an invoice contributes once whatever its number of lines, and the discount is the one already contained in FinalAmount (D-023).
4. **Company-wide = sum of branches:** `SystemRevenue` and `PeriodSystemRevenue` are window sums over the branch rows of the same statement; `usp_P3_RptSystemRevenue` uses the same filter without the branch predicate.
5. **SharePct** = branch revenue × 100 / system revenue, rounded to 2 decimals; NULL when the system revenue is 0. The rounded shares of a period can differ from 100.00 by up to 0.01 per branch.
6. **Partial buckets:** a bucket cut by the requested period contains only the part inside the period and is still labelled by its first local day.
7. **Read-only:** no write, no transaction, default READ COMMITTED, no hint. `BRANCH` is read by key only (existence check of `@Branch_ID`).
8. **Errors:** 51401 NULL parameter; 51402 `@FromDate >= @ToDate`; 51403 unknown branch; 51404 invalid grain.

### 12.3 What is not decided or not done

| Item | State |
|---|---|
| Rows for branches or buckets without revenue | Omitted (assumption of §2); the application fills zeros, or the team decides otherwise at P6 |
| RPT-05…RPT-07 | Not implemented (D-001) |
| Frozen benchmark queries Q-UC06-A, A0, B, C, D and their B0 | WO-P3-P2-02 (BLOCKED, R-27) |
| Index candidates IX-01, IX-02, IX-10 and any measured comparison | WO-P3-P4-01 Part X (not approved) |
| Summary table or indexed view | WO-P3-P4-02 |
| Partitioning | WO-P3-P5-01 |
| Consistency of a report that runs while settlements commit | Not tested here. Each routine is one statement under READ COMMITTED (locking); snapshot semantics (RCSI) stay a team choice (D-019 (b)). Planned in T-CONC-04 (WO-P3-P3-03) |
| Permissions for report users | Not created (RQ-P15; P6) |

### 12.4 Verification and recovery (2026-11-10)

**Part F VERIFIED.** [UC06 run](evidence/test-results/UC06-RUN__20261110-0206.txt) completed 78/78 steps (16 literal cases, fixture/DS-L independent reconciliation, UC05 regression, catalog/preservation checks). The 0153 run failed its metadata inspector; the corrected static-catalog check passed in 0206. [recovery](evidence/test-results/RECOVERY-UC06__20261110-043737.txt) validates source/live definitions and preserved data; [targeted retry](evidence/test-results/RECOVERY-UC06-RECHECK__20261110-045109.txt) resolves a recovery-only DS-L loyalty timeout. Details: [WO execution record](work-orders/WO-P3-P4-01_UC06_INDEX_EXPERIMENTS.md#13-execution-record). Part X/performance remain pending; no §2 business rule changed.
