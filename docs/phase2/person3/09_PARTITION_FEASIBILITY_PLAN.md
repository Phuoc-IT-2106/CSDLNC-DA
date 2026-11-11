# 09 — Partition Feasibility Plan (Person 3)

| Field | Value |
|---|---|
| Document status | DRAFT — WO-P3-BOOT-001; ownership and P6 coordination updated by the Owner Directive "Reprioritize Person 3 Implementation" (2026-11-08, D-027) |
| Date | 2026-11-06 |
| Decision | D-017, DEFERRED until WO-P3-P5-01 produces evidence |
| Rule | Partitioning is **evaluated**, not assumed. Showing that a table has partitions proves nothing; only measured partition elimination and a cost/benefit comparison against the best non-partitioned design count. |

## 1. Question

Is horizontal partitioning justified for any P3 table at the Phase 1 workload? If not, can P3 still show the course technique (S-08) correctly, through a proof-of-concept on a benchmark copy and a measured rejection?

## 2. Course and assignment context

- S-01 problem 3 asks for a partitioning **proposal** for exploding log tables and slow revenue reports. The log part (check-in and training history, more than 300,000 rows/month) belongs to other members. P3 handles the revenue part.
- S-08 p10 method: logical schema + queries/updates + their frequencies → partitioning decision → physical schema. S-08 p11 example: an invoice table of about 10,000,000 rows/year with operations of different frequencies.
- S-08 p12–18 SQL Server steps: filegroups → partition function (RANGE LEFT/RIGHT, p17) → partition scheme → partitioned table.
- The FitLife invoice volume (27,000/month, 324,000/year) is about 30× smaller than the course example. S-09 (AI-generated, level 5) expects no benefit at this scale and calls CHECK_IN the team's stronger partition candidate. **This is a hypothesis to test, not a conclusion.**

## 3. Candidate tables and partition keys

| Table | Candidate key | Assessment |
|---|---|---|
| INVOICE | PaidAt (revenue recognition time, D-004/D-010) | Best match for revenue queries; mutable and NULL while PENDING (§6) |
| INVOICE | IssuedAt | Immutable and never NULL; does **not** match the revenue predicate if revenue is dated by PaidAt |
| INVOICE_PRODUCT_ITEM | — (no date column) | Not partitionable by time without copying a date into the table (denormalisation of a P3-owned table, with consistency cost). **Reject.** |
| INVOICE_SERVICE_ITEM | — | Same as above. **Reject.** |
| MEMBER_MONTHLY_SPENDING | SpendingMonth | Compact; accessed by member, not by month range; ≤ 360k rows/year. **Reject.** |
| Revenue summary (if any) | — | ≤ 4,380 rows/year. **Reject.** |

So the only P3 candidate is **INVOICE**, evaluated on a benchmark copy.

## 4. Interval analysis (INVOICE, DS-L = 12 months, 324,000 rows)

| Interval | Partitions per year | Rows per partition | Elimination for a one-month report | Elimination for a quarter/year report | Comment |
|---|---|---|---|---|---|
| Monthly | 12 (+ empty boundary partitions) | ≈ 27,000 | 1 of 12 | 3 of 12 / 12 of 12 | Matches the most frequent grain (F27); most boundaries to maintain |
| Quarterly | 4 | ≈ 81,000 | 1 of 4 (scans 3× more than needed) | 1 of 4 / 4 of 4 | Fewer partitions |
| Yearly | 1 | ≈ 324,000 | none within a year | none / 1 | No benefit at DS-L |

With IX-01 in place, a branch-month query already reads about 2,250 rows ([04 §5.1](04_WORKLOAD_AND_DATA_VOLUME.md#51-invoice-shared-p3-settles-reads-and-reports)). Monthly partitioning on top of that index is expected to add little. This is a hypothesis for B3.

## 5. Partition elimination opportunities

| Query | Elimination possible? | Condition |
|---|---|---|
| Q-UC06-A, C | Yes | Key = the column in the range predicate, written in SARGable form |
| Q-UC06-B | Yes (time range), no (branch) | As above |
| Q-UC06-D (year, system) | Little or none | It touches every partition in the range |
| Q-UC05-A (U0) | Yes, if the window is expressed on the key | — |
| Settlement (PK lookup by Invoice_ID) | **No.** Invoice_ID is not the partition key, so a lookup probes every partition unless the date is also known | Risk of slowing the most frequent write path |
| Member history (no date filter) | No | All partitions are scanned |

## 6. Keys, constraints and alignment

1. **Aligned unique indexes must contain the partition column.** The PK on Invoice_ID alone can either (a) become (Invoice_ID, PaidAt), or (b) stay unique but non-aligned. Option (b) prevents fast SWITCH-based maintenance.
2. **Child FKs** (INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM → INVOICE.Invoice_ID) need a unique index on Invoice_ID alone, so in practice they force option (b). The alternative is composite FKs that add the date to tables owned by other members. **Either way this is a shared-schema change (TEAM_DECISION, R-13).**
3. **PaidAt is NULL while PENDING.** With RANGE RIGHT, NULLs go to the leftmost partition. Every settlement then changes the partition key from NULL to a date, so SQL Server moves the row to another partition (internally a delete plus an insert). That is an extra write cost on the 900/day settlement path, which T-PERF-06 must measure.
4. **IssuedAt as key** avoids row movement but breaks elimination for PaidAt-based revenue queries, unless the business accepts a bounded payment delay that could be added as a redundant predicate. That would change query semantics and is **not recommended**.
5. **Clustered index:** an aligned clustered index must be built on the partition scheme, for example (PaidAt, Invoice_ID). This contradicts D-018 (clustered Invoice_ID) for the shared table.
6. **UTC storage (D-014, 2026-11-07):** monthly boundaries must be the UTC instants of local month starts (for January 2026: `2025-12-31 17:00:00` UTC). Boundaries on UTC month starts would split every local-month report across two partitions.

**Mitigation for the PoC:** use a separate benchmark table (copy of INVOICE, no child FKs pointing to it) inside an isolated benchmark database (D-025). The shared schema is untouched, and PoC structures never propagate to it automatically (D-025 condition 6).

## 7. Maintenance costs

- Boundaries must be added ahead of time (SPLIT on an empty partition) and old ones merged. Keep empty partitions at both ends so SPLIT/MERGE do not move data.
- Sliding-window archiving (SWITCH out) needs aligned indexes and matching staging tables.
- Filegroups: the course demonstrates several filegroups (S-08 p14–15). A single filegroup is acceptable for the PoC. The report will justify multiple filegroups only if a backup/storage-tier need exists (none is stated in the sources).
- Monthly boundaries add about 12 maintenance operations per year. An automation script would be part of a production design, not of the PoC.

## 8. Cross-partition queries

Year-level and member-history queries touch every partition. If partition count grows, planning and execution overhead can grow. The PoC records the Actual Partition Count and the plan shape for Q-UC06-D and for the PK lookup.

## 9. Alternatives to partitioning

| Alternative | Addresses | Note |
|---|---|---|
| Covering/filtered index (IX-01, IX-02) | Range reads | Primary candidate ([08](08_INDEX_AND_QUERY_PLAN.md)) |
| Summary table / indexed view (D-015) | Repeated aggregation | Tiny structures |
| Manual horizontal split (current table + history table + view) | Lifecycle | The course's general horizontal-partitioning idea (S-08 p9); more application complexity |
| Archive policy only | Size | No retention requirement exists |

## 10. Proof-of-concept design (WO-P3-P5-01)

1. Benchmark copy table with the same columns as INVOICE, loaded from DS-L (and DS-XL ≥ 1,000,000 rows if the Project Owner approves the extra time).
2. Partition function RANGE RIGHT on the recognition timestamp, monthly boundaries covering the data plus one empty partition at each end; one filegroup (justified in §7).
3. Configurations: B2 (partitioned, no extra index) and B3 (partitioned + aligned IX-01-equivalent), compared with B0 and the best B1 on the **same data and parameters**.
4. Evidence: plans showing Actual Partition Count and the partitions accessed; IO/TIME; row distribution per partition (`sys.partitions`); settlement-like update cost with row movement; PK lookup cost.
5. Correctness: identical result hashes vs non-partitioned runs (T-REG-02).

## 11. Decision criteria

Partition the **shared** INVOICE (approve D-017) only if **all** hold:

1. Actual plans show partition elimination for the target report queries.
2. B2 or B3 beats the best non-partitioned configuration (best of B1/B4) on DS-L by the adoption thresholds in [08 §6](08_INDEX_AND_QUERY_PLAN.md#6-adoption-and-rejection-criteria) **or** the team has a real lifecycle need (archive/purge) that partitioning satisfies.
3. The settlement path (row movement, PK lookups) stays within the write-overhead thresholds.
4. The key and FK changes are acceptable for the P3 tables and their readers; adoption into the shared database is reviewed and approved by the team at P6 (promotion, D-025 conditions 6–7).
5. Results are identical.

Otherwise: **reject for the shared schema.** The report will present the PoC script, the elimination evidence and the measured comparison as a justified rejection. This still provides the partition script (RQ-A04) and the analysis (RQ-A11).

If partitioning is rejected for P3, P3 also **coordinates with the team on the project-level partition requirement** (master prompt §8). The check-in/training-history workload (>300,000 rows/month, S-01 problem 3) grows very differently from the invoice workload (27,000/month) and must not be conflated with it. Until P6 this is recorded as DEP-11 in the [dependency register](12_INTEGRATION_PLAN.md#2b-dependency-register-interim-assumptions-until-p6); at P6, WO-P3-P1-02 records in the integration contract which member demonstrates partitioning for the project, and P3 shares the PoC findings with them. P3 does not implement another member's partition design. Open item in [12 §13](12_INTEGRATION_PLAN.md#13-open-items).

## 12. Prior expectation (hypothesis only)

Based on volume and the key issues above, the prior expectation is that INVOICE partitioning will **not** be adopted for the shared schema at Phase 1 scale. This statement is a hypothesis to be tested in WO-P3-P5-01 and must not appear in the report as a finding.
