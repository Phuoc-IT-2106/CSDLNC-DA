# 08 — Index and Query Plan (Person 3)

| Field | Value |
|---|---|
| Document status | DRAFT — WO-P3-BOOT-001 |
| Date | 2026-11-06 |
| Rule | **No index is final because a column appears often in queries.** An index is adopted only after its target query's Actual Execution Plan and measured workload justify it and its write cost is measured (§6). Every candidate below has status CANDIDATE. |
| If D-004 is rejected | Replace `PaidAt` with `IssuedAt` in every candidate and query. |

## 1. Principles

1. **Workload-driven:** each candidate names its target query and that query's frequency ([04 §2](04_WORKLOAD_AND_DATA_VOLUME.md#2-p3-relevant-functions-s-02-52-verified-against-the-docx-table)).
2. **One change at a time:** B0, then exactly one candidate, then re-measure ([07 §10](07_UC06_REVENUE_PLAN.md#10-benchmark-comparisons)).
3. **Key column order:** equality predicates first, then the range predicate, then grouping/ordering support. Output-only columns go in INCLUDE (course: covering index and included columns, S-07 p26–27).
4. **Filtered indexes** only when the query always uses the same literal predicate (S-07 p29–30, p36–38).
5. **Indexes cost writes and storage** (S-07 p32). INVOICE is written 900×/day by insert and 900×/day by the settlement update, and it is shared with other members.
6. **No duplicates:** no candidate may be a left-prefix duplicate of an adopted index or of another member's index (§9).
7. **FK indexes are not automatic** in SQL Server. They are evaluated like any other candidate.
8. **Index Seek is not automatically superior to Index Scan** (master prompt §7). A narrow scan of a small covering index can beat a seek followed by many key lookups. Judge by logical reads, CPU and elapsed time, not by operator names.
9. **No technique padding:** a redundant or measurably harmful index is rejected even if keeping it would add one more "implemented technique" to the report.

## 2. Baseline physical configuration (B0)

- Clustered PKs exactly as S-02 §10 (INVOICE on Invoice_ID per D-018; MEMBER_MONTHLY_SPENDING on (Member_ID, SpendingMonth); line tables on (Invoice_ID, LineNo)).
- UNIQUE constraints required by business rules (Tier_Name, SpendingThreshold; ClientRequestKey if D-003 C).
- All FK and CHECK constraints present and trusted.
- **No** nonclustered indexes, summary tables or partitioning.
- Statistics updated WITH FULLSCAN after loading ([10 §4.3](10_SEED_AND_BENCHMARK_PLAN.md#43-measurement-protocol)).

## 3. Query-to-access-path matrix

| Query | Frequency | Predicates (equality → range) | Group / order | Columns returned | Candidate(s) |
|---|---|---|---|---|---|
| Q-UC05-A (baseline U0) | 900/day in U0 | Member_ID, Status → PaidAt | — | SUM(FinalAmount) | IX-03, IX-04 |
| Q-UC05-B | 1,200/day | Member_ID (PK) | — | points, tier, ≤ 12 spending rows | None (PK paths) |
| Q-UC05-C | 1/day | SpendingMonth range | Member_ID | TotalSpend | IX-07 |
| Settlement lookup | 900/day | Invoice_ID (PK) | — | header | None (PK) |
| Pending-invoice list (app, if any) | Unknown | Status = PENDING → IssuedAt | IssuedAt | header | IX-06 |
| Q-UC06-A / C | 120/day | Branch_ID, Status → PaidAt | day | SUM(FinalAmount), COUNT | IX-01 |
| Q-UC06-B | 20/day | Status → PaidAt | Branch_ID | SUM, COUNT | IX-02 |
| Q-UC06-D | Part of F27/F28 | (Branch_ID,) Status → PaidAt | quarter/year | SUM | IX-01, IX-02 |
| Q-UC06-E | Candidate | join Invoice_ID; INVOICE PaidAt range | Plan_ID | line amounts | IX-09 (+ IX-02 for the INVOICE side) |
| Q-UC06-F | 24/day (candidate) | join Invoice_ID; Branch_ID, PaidAt range | Product_ID | Quantity, amounts | IX-08 (+ IX-01) |
| Q-UC06-G | Candidate | — | Tier_ID | COUNT | IX-11 |

## 4. Candidate index register

| ID | Table | Key columns | INCLUDE | Filter | Target query | Hypothesis (to verify) | Write / size consideration | Status |
|---|---|---|---|---|---|---|---|---|
| IX-01 | INVOICE | (Branch_ID, PaidAt) | (FinalAmount) | PaymentStatus = 'PAID' | Q-UC06-A, C, D, F | Range seek on one branch's period; no Key Lookup | Maintained on settlement (row enters the filter at PENDING→PAID) | CANDIDATE |
| IX-02 | INVOICE | (PaidAt) | (Branch_ID, FinalAmount) | PaymentStatus = 'PAID' | Q-UC06-B, D, E | Range seek over the system period | As IX-01; partly overlaps IX-01 (keep both only if both win) | CANDIDATE |
| IX-03 | INVOICE | (Member_ID, PaidAt) | (FinalAmount) | PaymentStatus = 'PAID' | Q-UC05-A (U0 baseline), member history | Seek on one member's window | May become unnecessary under U1 (S-09 note); evaluated to make the U0 comparison fair | CANDIDATE |
| IX-04 | INVOICE | (Member_ID) | — | — | FK support; member history | Alternative to IX-03; unfiltered | General-purpose, less selective | CANDIDATE |
| IX-05 | INVOICE | (Branch_ID) and/or (Employee_ID) | — | — | FK support (deletes on parents, joins) | Likely redundant with IX-01 for Branch_ID | Parent deletes are rare | CANDIDATE |
| IX-06 | INVOICE | (IssuedAt) | (Member_ID, Branch_ID, FinalAmount) | PaymentStatus = 'PENDING' | Pending-invoice list (app) | Tiny index (few pending rows) | Rows leave the index at settlement | CANDIDATE (only if the app needs the list) |
| IX-07 | MEMBER_MONTHLY_SPENDING | (SpendingMonth, Member_ID) | (TotalSpend) | — | Q-UC05-C batch | Month-first range access instead of a full clustered scan | Duplicates the PK data; S-09 flags this as "keep only if measured useful" | CANDIDATE |
| IX-08 | INVOICE_PRODUCT_ITEM | (Product_ID) | (Quantity, UnitPrice, DiscountAmount) | — | Q-UC06-F | Supports grouping by product | P3-owned table since 2026-11-07; other members' reads are checked by T-REG-03 at P6 | CANDIDATE (scope D-001) |
| IX-09 | INVOICE_SERVICE_ITEM | (Plan_ID) | (UnitPrice, DiscountAmount) | — | Q-UC06-E | Supports grouping by plan | P3-owned table since 2026-11-07; heavy use by check-in/PT, so T-REG-03 (at P6) is mandatory before promotion | CANDIDATE (scope D-001) |
| IX-10 | INVOICE | Nonclustered columnstore (Branch_ID, PaidAt, FinalAmount, PaymentStatus) | — | — | Q-UC06-B, D | Batch-mode aggregation | Likely unjustified at this scale (S-09); optional advanced experiment | CANDIDATE (optional) |
| IX-11 | MEMBER | (Tier_ID) | — | — | Q-UC06-G; FK support | Small gain; 30k rows | Updated only by the tier batch; MEMBER is a shared table, so the index is proposed to its owner at P6, not created in P4 | CANDIDATE (scope D-001; P6) |

S-09 candidates I3/I4 (PAYMENT table) apply only if D-003 chooses option (B).

## 5. Evaluation protocol (per candidate)

1. Start from the B0 database snapshot of the dataset (DS-M, then DS-L).
2. Run the target query with the fixed parameter sets; capture the B0 plan, IO, TIME and result hash ([10 §4.3](10_SEED_AND_BENCHMARK_PLAN.md#43-measurement-protocol)).
3. Create **only** the candidate; update statistics; record index size (pages, MB).
4. Re-run the target query; capture the same evidence.
5. Run the settlement write-overhead test with and without the candidate (T-PERF-06).
6. Run the regression set: all P3 queries + registered queries of other members on the same table (T-REG-01, T-REG-03).
7. Drop the candidate (return to B0) before testing the next one, or restore the snapshot.
8. Record the outcome in the index decision record (DL-10): ADOPTED / REJECTED, with evidence links. `ADOPTED` means *recommended for promotion*. The index reaches the canonical shared database only through the separately approved promotion step (D-025 conditions 6–7).

## 6. Adoption and rejection criteria

Proposed default thresholds (`ASSUMPTION_PENDING_APPROVAL`, approved under D-022). A candidate is **ADOPTED** only if **all** of these hold on DS-L:

1. The target query's Actual Execution Plan uses the index (seek or a materially narrower scan).
2. Median logical reads of the target query fall by **≥ 50%** vs B0, **and** the median CPU or elapsed time improves by more than the run-to-run noise (the difference exceeds the larger interquartile range of the two configurations).
3. Results are identical to B0 (hash match).
4. Settlement write overhead with the index is within **+10% median / +20% p95** latency vs without it (U1 path).
5. No other registered query on the same table regresses by more than **10% in logical reads** (T-REG-03).
6. The candidate is not a left-prefix duplicate of an adopted index.
7. **Workload-weighted check:** Σ over P3 queries of (daily frequency × median logical reads) decreases.

Otherwise the candidate is **REJECTED**, and the rejection and its evidence are kept for the report. A measured rejection is a valid result.

## 7. Query-writing rules

1. **SARGable predicates:** never wrap indexed columns in functions (`YEAR(PaidAt)`, `CAST(...)` in WHERE). Use half-open ranges `PaidAt >= @From AND PaidAt < @To`. The non-SARGable form appears only as the teaching variant Q-UC06-A0. Timestamps are stored in UTC (D-014): convert the local period bounds to UTC parameters; never apply `AT TIME ZONE` or `DATEADD` to the column in WHERE.
2. **Literal status:** write `PaymentStatus = 'PAID'` as a literal so filtered indexes match. If a routine receives the status as a parameter, the filtered index cannot be guaranteed to apply.
3. **Matching types:** parameter types equal column types (DATETIME2(3) parameters for DATETIME2 columns; VARCHAR literals for VARCHAR columns). This avoids implicit conversions that can prevent seeks.
4. **Required SET options:** filtered indexes and indexed views require specific session SET options (e.g. QUOTED_IDENTIFIER, ANSI_NULLS ON). With the wrong settings, DML on the table **fails**. `sqlcmd` connects with QUOTED_IDENTIFIER OFF unless started with `-I`. Verify this in WO-P3-P0-02 and document the client settings in the integration contract (R-12).
5. **No SELECT \*:** return only the needed columns, so covering is possible.
6. **Plan stability:** one routine per query shape; record whether `OPTION (RECOMPILE)` is used; benchmark with the same parameter sets in every configuration.

## 8. Statistics and index maintenance

- Update statistics WITH FULLSCAN on affected tables after seeding and after each index change, so every configuration starts from the same statistics state.
- Report fragmentation and page density (`sys.dm_db_index_physical_stats`) as evidence. Do **not** rebuild blindly. Rebuild only to reset a configuration to a documented state, and say so in the run manifest.
- Record index sizes (`sys.dm_db_partition_stats`) for every adopted index (storage cost in the report).

## 9. Coordination with other members

- **Timing (2026-11-08, D-027):** the registry and the regression queries of other members are collected in WO-P3-P1-02 at P6. In P4, P3 evaluates candidates on its own tables against its own queries and records them in `design/INDEX_DECISIONS.md`; T-REG-03 runs in WO-P3-P6-01 before any promotion.
- A **shared index registry** (part of DL-02) lists every index on shared tables (INVOICE, line tables, MEMBER): owner, target query, status.
- P3 checks the registry before proposing a candidate on a shared table. Candidates on tables owned by others (IX-08, IX-09) need that owner's approval.
- Other members' high-frequency queries on shared tables (e.g. entitlement lookups on INVOICE_SERVICE_ITEM during check-in) are registered as regression queries for T-REG-03.

## 10. Evidence required per index

| Evidence | Location |
|---|---|
| Creation script with a header comment naming the target query and workload | `db/indexes/` (proposed) |
| B0 vs candidate Actual Execution Plans (`.sqlplan`) and screenshots | `docs/phase2/person3/evidence/execution-plans/`, `.../screenshots/` |
| STATISTICS IO/TIME raw output and summary CSV | `docs/phase2/person3/evidence/benchmark-results/<RUN_ID>/` |
| Index size and write-overhead measurements | same RUN_ID folder |
| Decision record (ADOPTED/REJECTED + criteria table) | DL-10 |
