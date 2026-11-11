# 04 — Workload and Data Volume (Person 3)

| Field | Value |
|---|---|
| Document status | DRAFT — WO-P3-BOOT-001 |
| Date | 2026-11-06 |
| Basis | Phase 1 estimates (S-02 §5–§6). **These are planning estimates, not measured production statistics.** Everything not stated in S-02 is labelled `ASSUMPTION_PENDING_APPROVAL` or "derived". |

## 1. Baseline assumptions from Phase 1

| Parameter | Value | Label |
|---|---|---|
| Branches | 12 | REQUIRED_BY_ASSIGNMENT (S-01 p2), DERIVED_FROM_PHASE1 |
| Active members | 30,000 | DERIVED_FROM_PHASE1 (S-02 §5.1) |
| Invoices per day | 900 | DERIVED_FROM_PHASE1 (S-02 §5.1) |
| Days per month | 30 | DERIVED_FROM_PHASE1 (S-02 §6.1) |
| Check-in peak (context only, not P3) | 10,500 of 15,000 daily check-ins between 17:00 and 20:00 | DERIVED_FROM_PHASE1 |
| Branch opening hours | Unknown (BRANCH.OpeningTime/ClosingTime exist but have no values) | MISSING |

## 2. P3-relevant functions (S-02 §5.2, verified against the .docx table)

| Function | Name | Type | Frequency | Main entities | P3 role |
|---|---|---|---|---|---|
| F05 | Create invoice | Write | 900/day | INVOICE, INVOICE_*_ITEM | Integration (owner per D-001/D-012) |
| F06 | Confirm payment | Read/Write | 900/day | INVOICE | **Core (UC05)**: loyalty and revenue effects |
| F07 | Establish purchased entitlement | Read/Write | 180/day | INVOICE_SERVICE_ITEM | Integration (UC01) |
| F19 | Update inventory after sale | Read/Write | 720/day | BRANCH_INVENTORY | Integration (UC04) |
| F20 | Update spending and points | Read/Write | 900/day | MEMBER_MONTHLY_SPENDING, MEMBER | **Core (UC05)** |
| F21 | Look up points/tier | Read | 1,200/day | MEMBER, MEMBER_TIER | **Core (UC05)** |
| F22 | Periodic tier evaluation | Read/Write | 1 batch/day | MEMBER_MONTHLY_SPENDING, MEMBER_TIER | **Core (UC05)** |
| F27 | Branch revenue | Read | 120/day | INVOICE, BRANCH | **Core (UC06)** |
| F28 | System revenue | Read | 20/day | INVOICE, BRANCH | **Core (UC06)** |
| F30 | Best-selling products/plans | Read | 24/day | INVOICE_PRODUCT_ITEM, INVOICE_SERVICE_ITEM | Candidate (D-001) |

**Derived observation (inference, to confirm with the team; it affects the seed generator):** F07 = 180/day equals the 180 service lines/day, and F19 = 720/day plus 180 equals 900 invoices/day. This suggests each invoice is either a service sale (one service line) or a product sale (on average 1,980 / 720 = 2.75 product lines). Overall, 2,160 lines / 900 invoices = 2.4 lines per invoice.

**Average arrival rate (derived):** 900 settlements/day is 37.5/hour over 24 h, or 60/hour if all sales happen in an assumed 15-hour opening day (ASSUMPTION_PENDING_APPROVAL). Even at 3× peak, that is about 3 settlements per minute system-wide. Contention is low; the concurrency risk is **duplicate or racing requests**, not throughput.

## 3. Projected row counts (straight-line extrapolation of S-02 §6.1)

| Table | Per day | Per month | 3 months (DS-M) | 12 months (DS-L) | 24 months | Months to reach 70,000 rows |
|---|---|---|---|---|---|---|
| INVOICE | 900 | 27,000 | 81,000 | 324,000 | 648,000 | ≈ 2.6 |
| INVOICE_PRODUCT_ITEM | 1,980 | 59,400 | 178,200 | 712,800 | 1,425,600 | ≈ 1.2 |
| INVOICE_SERVICE_ITEM | 180 | 5,400 | 16,200 | 64,800 | 129,600 | ≈ 13.0 |
| MEMBER_MONTHLY_SPENDING | updated per payment | ≤ 30,000 new rows (upper bound); **measured ≈ 14,000** | ≤ 90,000; **measured 42,059** | ≤ 360,000; **measured 169,040** | ≤ 720,000 | ≥ 2.3 upper bound; **≈ 5 measured** |
| MEMBER | — | +≤ 4,500 (F03 = 150/day registrations *or* updates; split unknown) | 30,000 active | 30,000 active | — | Not reached by Phase 1 numbers |
| MEMBER_TIER | — | — | 3 | 3 | 3 | n/a |
| BRANCH | — | — | 12 | 12 | 12 | n/a |
| Candidate branch-day summary (D-015) | 12 | ≈ 360 | ≈ 1,080 | ≈ 4,380 | ≈ 8,760 | n/a |

Measured on 2026-11-08 (WO-P3-P2-01, generator S001 v1.0, the 10 §3.4 distributions; [manifest](evidence/test-results/DATASET-MANIFEST__DS-L__20261108-0345_A.md)): INVOICE 81,000 (DS-M) and 324,000 (DS-L) exactly; INVOICE_PRODUCT_ITEM 178,518 and 712,789; INVOICE_SERVICE_ITEM 16,268 and 65,177; MEMBER_MONTHLY_SPENDING 42,059 and 169,040. The monthly-spending count is the number of distinct paying members per month (about 14,000 of 30,000, because 20% of members produce 60% of the invoices), well below the 30,000 upper bound. These are generated-data measurements, not production statistics.

Consequences for RQ-A06 (≥70,000 rows for demonstration tables):

- INVOICE, INVOICE_PRODUCT_ITEM and MEMBER_MONTHLY_SPENDING exceed 70,000 rows in DS-L, and INVOICE and INVOICE_PRODUCT_ITEM already do in DS-M (MEMBER_MONTHLY_SPENDING does not: 42,059 measured). These are the **P3 demonstration tables**; S-01 asks for ≥70,000 rows in selected tables without naming a tier, so DS-L satisfies it for all three.
- INVOICE_SERVICE_ITEM stays below 70,000 in DS-L (64,800). If RQ-A16 (top plan by revenue) becomes a P3 index demonstration, generate at least 13 months or document why this table is not a demonstration table.
- MEMBER does not need ≥70,000 rows: its P3 access path is a primary-key lookup.

## 4. Rough storage estimate (ASSUMPTION_PENDING_APPROVAL; verify with `sp_spaceused` after seeding)

Based on the proposed types in [05 §3](05_PHYSICAL_DESIGN_PLAN.md#3-column-data-types-d-014-approved-provisionally-2026-11-07). Rough estimate only.

| Table (DS-L) | Approx. row size | Rows | Approx. data size |
|---|---|---|---|
| INVOICE | ~85 bytes | 324,000 | ~27 MB |
| INVOICE_PRODUCT_ITEM | ~45 bytes | 712,800 | ~33 MB |
| MEMBER_MONTHLY_SPENDING | ~36 bytes | ≤ 360,000 | ≤ ~14 MB |

**Benchmark consequence:** the whole P3 working set (well under 100 MB) will fit in the buffer pool of a typical laptop. Once caches are warm, physical reads will be close to zero. Elapsed-time differences will be small in absolute terms, so **logical reads and CPU time are the primary comparison metrics** (see [10](10_SEED_AND_BENCHMARK_PLAN.md) and R-08).

## 5. Per-table workload profiles

The ownership labels in the headings below predate 2026-11-07. Current ownership: INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM and MEMBER_MONTHLY_SPENDING are P3-owned; MEMBER and MEMBER_TIER are shared dependencies ([12 §2](12_INTEGRATION_PLAN.md#2-shared-table-ownership-matrix-proposed)). The workload figures are unaffected.

### 5.1 INVOICE (shared; P3 settles, reads and reports)

| Aspect | Profile |
|---|---|
| Rows and growth | 27,000/month; 324,000/year (§3) |
| Writes | Insert at F05 (900/day). One status update at F06 (900/day). Cancellations if D-011 allows them. |
| Reads | Settlement PK lookup (900/day). F27 (120/day) and F28 (20/day) range aggregations. Member history (frequency unknown). Baseline U0 recomputation (comparison only). |
| Filter attributes | Invoice_ID (equality); Branch_ID (equality); PaidAt or IssuedAt (range, D-004); PaymentStatus (equality, literal); Member_ID (equality) |
| Join attributes | Invoice_ID → line tables; Branch_ID → BRANCH; Member_ID → MEMBER; Employee_ID → EMPLOYEE |
| Group/sort attributes | Branch_ID; date grain (day/month/quarter/year) of the recognition timestamp |
| Time-based pattern | Append-mostly in time order; reports read recent months and year ranges |
| Selectivity (ASSUMPTION, uniform case) | One branch ≈ 8.3%; one month of DS-L ≈ 8.3%; branch × month ≈ 0.7% (≈ 2,250 rows); one member ≈ 10.8 invoices/year on average (skewed) |
| Status distribution (ASSUMPTION) | Mostly PAID (seed default 95% PAID, 3% PENDING, 2% CANCELLED; to be approved in D-022). Because PAID dominates, a `PaymentStatus = 'PAID'` filter barely reduces index size. Its value is defining exactly the report population. A PENDING-only filtered index would be very small. |
| Concurrency | Low arrival rate. Risks: repeated confirmation of the same invoice; settlement vs report readers (D-019). |
| Existing keys/indexes (verified) | Logical PK (Invoice_ID); FKs Member_ID, Employee_ID, Branch_ID (S-02 §10). **No physical indexes exist** (no database yet). SQL Server does not create FK indexes automatically. |
| Response-time target | None numeric for P3 (G-17). Symptom in S-01 problem 3: "more than 1 minute" for monthly revenue. |
| Storage/retention | Financial record; assumed to be kept indefinitely; no archive requirement in the sources |
| Missing measurements | Hour-of-day distribution of sales; delay between issue and payment; status mix; branch-size skew; refund rate |

### 5.2 INVOICE_PRODUCT_ITEM (owned by the UC04 owner; P3 reads)

| Aspect | Profile |
|---|---|
| Rows and growth | 59,400/month; 712,800/year |
| Writes | Insert with F05 (≈ 1,980 lines/day); no updates expected |
| Reads | Best sellers F30 (24/day, candidate); per-product revenue; invoice detail |
| Filter / join / group | Join on Invoice_ID (PK prefix); filter and group by Product_ID; aggregate Quantity and UnitPrice × Quantity − DiscountAmount |
| Time-based pattern | No date column. Time filters need a join to INVOICE. Partitioning by time is impossible without copying a date column into the table ([09](09_PARTITION_FEASIBILITY_PLAN.md)). |
| Distribution (ASSUMPTION) | Product popularity skewed (a few best sellers); 1–5 lines per product invoice, average 2.75 |
| Existing keys | Logical PK (Invoice_ID, LineNo); FKs Invoice_ID, Product_ID |
| Missing measurements | Product popularity; lines per invoice distribution |

### 5.3 INVOICE_SERVICE_ITEM (owned by the UC01 owner; P3 reads)

| Aspect | Profile |
|---|---|
| Rows and growth | 5,400/month; 64,800/year |
| Writes | Insert with F05 (180/day). PTSessionsRemaining updated by the PT workflow (not P3). |
| Reads | Check-in validation and PT booking (other members, high frequency). Top plan by revenue (RQ-A16, candidate). |
| Filter / join / group | Invoice_ID join; Plan_ID group |
| Note | Heavily used by other members' high-frequency queries, so any P3 index here must pass T-REG-03 |

### 5.4 MEMBER (shared; P3 owns CurrentPoints and Tier_ID updates)

| Aspect | Profile |
|---|---|
| Rows | 30,000 active |
| Writes by P3 | CurrentPoints increment per settlement (900/day). Tier_ID update by the daily batch (only rows whose tier changes). |
| Reads by P3 | F21 PK lookup (1,200/day); tier distribution grouped by Tier_ID (candidate) |
| Concurrency | Same-member concurrent settlements are rare but must not lose updates. The batch updating many rows can escalate locks (SQL Server attempts escalation at about 5,000 locks on one object), which could block settlements; batch design must chunk or run off-peak (R-15). |
| Existing keys | PK Member_ID; FK Tier_ID |

### 5.5 MEMBER_TIER (P3)

3 rows; read on every tier evaluation and lookup; changed only by administrators. No performance concern. It needs uniqueness on Tier_Name and SpendingThreshold (D-008).

### 5.6 MEMBER_MONTHLY_SPENDING (P3)

| Aspect | Profile |
|---|---|
| Rows and growth | ≤ 30,000 new rows/month (upper bound) |
| Writes | Upsert per settlement (900/day): insert for the member's first payment in the month, otherwise update |
| Reads | Tier window (≤ 12 rows per member) in F21 and F22; reconciliation |
| Filter / group | Member_ID equality + SpendingMonth range (PK order fits); batch grouping by Member_ID over the window |
| Concurrency | Two simultaneous settlements of the same member in the same month must not both insert (PK violation) or lose an update. This needs a safe upsert pattern ([06 §4.4](06_UC05_BILLING_LOYALTY_PLAN.md#44-monthly-spending-update)). |
| Existing keys | PK (Member_ID, SpendingMonth); FK Member_ID |
| Retention | Only the window is needed for tiers. History is kept for reconciliation (no purge requirement). |

## 6. Query workload catalogue

Full definitions are in [07](07_UC06_REVENUE_PLAN.md) and [10 §4.1](10_SEED_AND_BENCHMARK_PLAN.md#41-query-set).

| Query ID | Purpose | Frequency basis | Predicate shape |
|---|---|---|---|
| Q-BIL-A | Invoice detail (header + lines) for payment confirmation (added 2026-11-08) | F06 900/day (read step) | Invoice_ID = @id (PK) on INVOICE and both item tables |
| Q-UC05-A | Member spend over the tier window recomputed from INVOICE (baseline U0, Problem 4) | 900/day (it runs at every payment in the baseline design) | Member_ID = @m AND status = PAID AND time ∈ [from, to) |
| Q-UC05-B | Loyalty lookup: points, tier, window spend | F21 1,200/day | PK lookup on MEMBER + ≤ 12 MEMBER_MONTHLY_SPENDING rows |
| Q-UC05-C | Tier batch evaluation over all members | F22 1/day | All MEMBER_MONTHLY_SPENDING rows in the window, grouped by member |
| Q-UC06-A | Branch revenue, one period | F27 120/day | Branch_ID = @b AND status = PAID AND time ∈ [from, to) |
| Q-UC06-B | System revenue by branch, one period | F28 20/day | status = PAID AND time ∈ [from, to), GROUP BY Branch_ID |
| Q-UC06-C | Daily series for a branch | Part of F27 | As Q-UC06-A, GROUP BY day |
| Q-UC06-D | Quarter/year revenue | Part of F27/F28 | Multi-month range GROUP BY period |
| Q-UC06-E | Top plan by revenue, last 6 months | Candidate (RQ-A16) | Join service lines → INVOICE in range, GROUP BY Plan_ID |
| Q-UC06-F | Best sellers per branch | F30 24/day (candidate) | Join product lines → INVOICE, GROUP BY Product_ID |
| Q-UC06-G | Tier distribution | Candidate (RQ-A18) | GROUP BY MEMBER.Tier_ID |

## 7. Missing measurements (to collect or assume explicitly in WO-P3-P0-01 / WO-P3-P2-01)

1. Hour-of-day and day-of-week distribution of invoices.
2. Delay between invoice issue and payment, if D-003 makes them separate steps.
3. PaymentStatus mix.
4. Lines per invoice and the service/product invoice split.
5. Branch-size skew.
6. Member spending distribution (needed for a realistic tier distribution under D-008 thresholds).
7. Product and plan popularity.
8. Refund/cancellation rate (if D-011 includes them).
9. Hardware of the benchmark machine (WO-P3-P0-02).
