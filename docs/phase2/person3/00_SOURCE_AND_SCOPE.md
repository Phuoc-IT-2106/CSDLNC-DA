# 00 — Sources and Scope (Person 3: Billing, Loyalty & Revenue)

| Field | Value |
|---|---|
| Document status | DRAFT — produced by WO-P3-BOOT-001 (planning only); §3 (S-18) and §5 (use-case mapping) updated 2026-11-07 by Owner Directive WO-P3-P0-FINAL |
| Audit date | 2026-11-06 |
| Scope | Phase 2, Person 3 (P3): UC05 Billing & Loyalty, UC06 Revenue Reporting |
| Build status | BUILD_NOT_STARTED — no SQL, seed, test or application code exists |

---

## 1. Classification labels

Every substantial statement or decision in the P3 documentation carries one of these labels.

| Label | Meaning | Can it be treated as mandatory? |
|---|---|---|
| `REQUIRED_BY_ASSIGNMENT` | Stated in the official assignment (S-01). | Yes |
| `DERIVED_FROM_PHASE1` | Stated in, or directly calculated from, the team's Phase 1 report (S-02). | Yes, as the approved team baseline, unless the team changes it |
| `TEAM_DECISION` | Only the team can make it, because it affects shared schema, shared code or other members. | Only after it is recorded as APPROVED in [03_DECISION_LOG.md](03_DECISION_LOG.md) |
| `TECHNICAL_RECOMMENDATION` | Recommended from course material, DBMS documentation or engineering judgement. | No. It is a proposal until approved. |
| `ASSUMPTION_PENDING_APPROVAL` | A working assumption used for planning because a source is missing or silent. | No. It must be confirmed or replaced before the affected build step. |

As of 2026-11-06, **no `TEAM_DECISION` has recorded approval.** Every decision in [03_DECISION_LOG.md](03_DECISION_LOG.md) is PROPOSED or DEFERRED.

## 2. Source precedence

The order of [P3_MASTER_PROMPT.md §2](../../agent/P3_MASTER_PROMPT.md#2-source-of-truth) (v2.0), mapped to the sources below:

1. Official assignment (S-01).
2. Approved business requirements and logical schema: the Phase 1 report (S-02).
3. Approved project decisions ([03_DECISION_LOG.md](03_DECISION_LOG.md); none approved yet), including the integration contract once agreed.
4. Verified existing implementation (none exists yet; see S-12, S-13).
5. Authoritative technical documentation: course seminars (S-07, S-08) and official DBMS documentation (S-16).
6. Proposed optimizations and AI recommendations (S-09 and any agent output, including this documentation set).

If two sources conflict, the higher one wins. The conflict is still reported and recorded as a gap ([02_GAP_ANALYSIS.md](02_GAP_ANALYSIS.md)) and a decision ([03_DECISION_LOG.md](03_DECISION_LOG.md)).

## 3. Source inventory

None of these sources is stored in the repository. The paths are local paths on the Project Owner's workstation (user profile `C:\Users\DELL`). Checksums are the first 12 hex characters of MD5. They identify the exact version that was audited.

| ID | Source | Local path | Purpose | Availability | Version / date | Relevant sections | Conflicts / missing information |
|---|---|---|---|---|---|---|---|
| S-01 | Official assignment `2627-CSDLNC-DA.CLC` (project 2627.ADB.02, CSC12002) | `Downloads\2627-CSDLNC-DA.CLC.pdf` (identical copy `... (1).pdf`) | Mandatory requirements, grading | AVAILABLE. The PDF is password-protected (AES). It was opened with a password the Project Owner supplied during the session. **The password is intentionally not recorded anywhere in the repository.** | PDF created 2026-10-09; 4 pages; md5 `90134711b47a` | p2 §3 (invoice/payment fields, loyalty: 3 tiers, 1 point = 100,000 VND); p3 problems 3 and 4, §4 suggested reports; p4 Phase 2 requirements, ≥70,000 rows, grading | Tier period is "total spending in the year" (p2), but problem 4 says the system "sums invoices of the last 12 months" (p3). No tier thresholds, no refund rules, no Phase 2 deadline found. |
| S-02 | Phase 1 report `ADB.24C03.12` | `Downloads\ADB.24C03.12 (1).pdf`; source `Downloads\ADB.24C03.12.docx` | Approved Phase 1 baseline: processes, BRs, functions, frequencies, logical schema | AVAILABLE | PDF created 2026-11-05 22:17, 22 pages, md5 `e75dccfd126d`; docx md5 `c11b9c116880` (identical to `ADB.24C03.12 (1).docx` and `FitLife_Hub_Capacity_Dong_Bo_Page8_BR_Giu_Nguyen.docx`) | §2.2, §2.5, §2.6 (printed p5–7); §3.1–3.2 (p7–8); §4.2–4.3 BR04–BR13 (p9); §5.2 F01–F34 (p10–11); §6.1–6.2 (p11–12); §7.1 UC01–UC07, §7.2 (p12–13); §10 relational schema (p15–21) | Formal grading/approval status UNVERIFIED. **The PDF text layer shifts the "main entities" column in table §5.2 by one row. The .docx table is authoritative for cell alignment** (verified during the audit). No physical data types. `PaymentStatus` domain undefined. No `PaidAt`. |
| S-03 | Unadopted draft `FitLife_Hub_Bao_Cao_Capacity_BR38_Hoan_Thien.docx` | `Downloads\` | Informative only: expanded wording of BR01–BR38 | AVAILABLE | 2026-11-05 21:00, md5 `60ea11d41504` | Draft BR04 (rolling "current month + 11 previous months" tier window); BR12 (FinalAmount = Gross − Discount ≥ 0; no repeated effects on re-processing); BR38 (capacity) | **Superseded.** The later final file is named "…BR_Giu_Nguyen" ("BRs kept unchanged") and keeps the short BR01–BR37. Draft rules are not requirements; they can only inform proposals. |
| S-04 | Earlier Phase 1 drafts: `FitLife_Hub_bo_sung_mo_hinh.docx`, `FitLife_Hub_Mo_Hinh_Quan_He_Dong_Bo_ERD_Page8.docx` (+ "(1)" copy) | `Downloads\` | History of schema evolution | AVAILABLE | 2026-11-05 19:52 (md5 `061f4c706645`); 20:27/21:08 (md5 `5631948cbca3`) | 19:52 draft: `INVOICE(..., IssuedAt, InvoiceDiscount, PaymentMethod, PaymentStatus, PaidAt)`, line `LineDiscount`, `GrantedUses` | `PaidAt` existed at 19:52 and is absent from the 20:27 draft and the final. The reason for removing it is undocumented (see G-03). |
| S-05 | ERD diagram `FitLife_Hub_Page8_Capacity_BR_Giu_Nguyen-Page-8 – FitLife Hub ERD.drawio.svg` | `Downloads\` | Conceptual ERD (page 8) | AVAILABLE | 2026-11-05 21:26 | Page "Page-8 – FitLife Hub ERD" only | The file embeds 8 draw.io pages. Pages 1–7 belong to other exercises (Pizza, GrabFood, ABC Supermarket). **`PAYMENT`, `CARD_PAYMENT` and `E_WALLET_PAYMENT` in that file belong to the GrabFood page, not to FitLife.** |
| S-06 | Earlier logical diagram `FitLifeHub_logic.svg` | `Downloads\` | History | AVAILABLE | 2026-10-31, md5 `0943b2dba875` | INVOICE definition | Superseded. It contained `PaidAt` and `InvoiceDiscount`; the final §10 uses `GrossAmount/DiscountAmount/FinalAmount` and no `PaidAt`. |
| S-07 | `Seminar 2v4.pdf` — "Seminar 2: INDEX" | `Downloads\Seminar 2v4.pdf` | Course method for indexes and execution plans | AVAILABLE | 2022-11-09; 39 pages; md5 `1664acb72ed0` | p2 physical-design inputs/decisions; p5–12 clustered, non-clustered, B-tree, composite; p13–19 execution plans (estimated vs actual; table scan vs index scan vs seek); p20–31 SQL Server index DDL, covering/INCLUDE, filtered index; p32 cost of indexes; p36–38 filtered-index demo | None |
| S-08 | `Seminar - partition (1).pdf` | `Downloads\` (identical to `Seminar - partition.pdf`) | Course method for partitioning | AVAILABLE | 2024-06-05; 18 pages; md5 `2c74e41844b1` | p4 physical-design inputs; p8–9 why and how to partition horizontally (pros/cons); p10 process (logical schema + queries + frequencies → partitioning → physical schema); p11 invoice example (~10M rows/year with operation frequencies); p12–18 filegroups, partition function, scheme, table; p17 RANGE LEFT vs RIGHT | None. The example scale (10M/year) is far above the FitLife invoice estimate (324k/year). |
| S-09 | Research report "Physical Design Research for FitLife Hub Giai đoạn 2: UC05 Billing & Loyalty and UC06 Revenue Reporting" | `Downloads\Physical Design Research for FitLife Hub Giai đoạn 2_ UC05 Billing & Loyalty and UC06 Revenue Report.pdf` | Candidate techniques, benchmark method | AVAILABLE | PDF metadata: author "ChatGPT Deep Research", WeasyPrint; 25 pages; downloaded 2026-11-06; md5 `ebd7371240d0` | Workload sizing; candidate indexes I1–I6; partition analysis; summary table; idempotent payment flow; benchmark matrix B0–B5; acceptance checklist | **Precedence level 5 (AI-generated).** It uses `MEMBER_MONTHLY_SPENDING.TotalSpending` (Phase 1 name: `TotalSpend`). It assumes `INVOICE.PaidAt` and statuses `'PAID'/'PENDING'`, which Phase 1 does not define. It proposes `PAYMENT` and `REVENUE_MONTHLY`, which are not in Phase 1. Its 07/11–16/11 dates are suggestions, not deadlines. It contains citation artifacts ("fileciteturn0file0"). Its arithmetic (81,000 / 324,000 / 178,200 / 712,800) was re-checked and is correct. |
| S-10 | Person 3 task allocation / six-use-case team assignment | — | P3 scope boundaries | **MISSING.** Searched the project folder, Downloads, Documents, Desktop and WPS Cloud Files. | — | — | It is known only through the summary in work order P3-PLANNING-BOOTSTRAP-001 (S-11). The full six-UC list and which person owns each UC cannot be verified (see G-01, D-001). |
| S-11 | Work order P3-PLANNING-BOOTSTRAP-001 | Recorded in [work-orders/WO-P3-BOOT-001_PLANNING_BOOTSTRAP.md](work-orders/WO-P3-BOOT-001_PLANNING_BOOTSTRAP.md) | Defines this planning task and the P3 scope summary | AVAILABLE | 2026-11-06 | Whole document | Its workload figures match S-02 §5.2/§6.1 (verified). |
| S-12 | Project repository `C:\CSDLNC- DA` | repository root | Code, schema, conventions | EMPTY at audit time | 2026-11-06: no files, **not a Git repository** | — | No existing conventions, CLAUDE.md, AGENTS.md, `.claude/`, migrations, tests or benchmarks. |
| S-13 | Shared modules of Persons 1 and 2 | — | Integration | **MISSING** | — | — | No shared schema, seed generator or application code is accessible (G-19). |
| S-14 | Local DBMS installation | Windows services `MSSQLSERVER`, `MSSQL$MSSQLSERVER01` | Reference DBMS candidate | AVAILABLE (not connected during this WO) | Both instances: version 17.0.1000.7 (SQL Server 2025 RTM), edition "Standard Developer Edition" (registry); both services running | — | Not yet confirmed which instance the team uses, or whether other members run the same version (G-20, D-002). |
| S-15 | Owner's seminar note `Documents\csdl-seminar-note.txt` | `C:\Users\DELL\Documents\` | Informal lecturer guidance | AVAILABLE | 2026-10-23 | Whole note | Says to analyse which tables are large and high-frequency and what time unit to partition by; choose indexes for the queries to improve; show execution plans; compare with and without the index; analyse the results. Consistent with S-01. |
| S-16 | Official SQL Server documentation | Online (URLs listed in S-09) | Technical verification | UNVERIFIED in this session (not fetched) | — | Index design guide, partitioned tables, filtered indexes, STATISTICS IO/TIME | Claims taken from S-09 must be checked against the official page before they are cited as level-4 evidence. |
| S-17 | `Chapter 2 Transaction Processing and Concurrency Control Techniques_2025 (3).pdf` | `Downloads\` | Course material on transactions and concurrency | AVAILABLE, NOT REVIEWED | 2026-11-03 | — | Optional input for concurrency design (WO-P3-P3-01, WO-P3-P3-03). |
| S-18 | Canonical GitHub repository `Phuoc-IT-2106/CSDLNC-DA` | `https://github.com/Phuoc-IT-2106/CSDLNC-DA`; read-only clone at `C:\Users\DELL\source\repos\CSDLNC-DA` | Version control for all Phase 2 work (D-021) | AVAILABLE (read verified; write NOT_VERIFIED) | Inspected 2026-11-07: public, branch `main`, 1 commit `792a85e` "Initial commit" (2026-11-05), `README.md` only | — | Named by the Project Owner (directive WO-P3-P0-FINAL §2). Public visibility to be decided before the first push (R-24). Contains no project structure yet. |

Tools observed during the audit (inspected only; nothing installed): `sqlcmd` (ODBC 17 tools), an SSMS 22 user folder, a DBeaver shortcut, Git, .NET SDK, Node.js, Python 3.14 (no PDF/DB packages) and `pdftotext`.

## 4. Verified facts most relevant to P3

| Fact | Source | Label |
|---|---|---|
| 12 branches; 30,000 active members; 900 invoices/day | S-02 §5.1; S-01 p2 (12 branches) | DERIVED_FROM_PHASE1 / REQUIRED_BY_ASSIGNMENT |
| F05 create invoice 900/day (W); F06 confirm payment 900/day (R/W, INVOICE); F07 establish purchased entitlement 180/day; F19 inventory update after sale 720/day | S-02 §5.2 (docx table) | DERIVED_FROM_PHASE1 |
| F20 update spending and points 900/day (R/W, MEMBER_MONTHLY_SPENDING, MEMBER); F21 points/tier lookup 1,200/day (R, MEMBER, MEMBER_TIER); F22 periodic tier evaluation 1 batch/day (R/W, MEMBER_MONTHLY_SPENDING, MEMBER_TIER) | S-02 §5.2 | DERIVED_FROM_PHASE1 |
| F27 branch revenue 120/day; F28 system revenue 20/day (both R on INVOICE, BRANCH); F30 best-selling products/plans 24/day (R on INVOICE_PRODUCT_ITEM, INVOICE_SERVICE_ITEM) | S-02 §5.2 | DERIVED_FROM_PHASE1 |
| INVOICE 27,000/month; INVOICE_SERVICE_ITEM 5,400/month; INVOICE_PRODUCT_ITEM 59,400/month; MEMBER_MONTHLY_SPENDING up to 30,000 new rows/month (30-day month) | S-02 §6.1 | DERIVED_FROM_PHASE1 |
| Loyalty: 3 tiers Silver–Gold–Platinum based on total spending "in the year"; 1 point = 100,000 VND | S-01 p2 | REQUIRED_BY_ASSIGNMENT |
| Payment methods: cash, VNPay, card | S-01 p2 | REQUIRED_BY_ASSIGNMENT |
| Problem 4: recomputing 12-month invoice totals at every payment to re-rank Silver/Gold/Platinum (up or down) slows invoice printing; the task is to redesign how points and tiers are stored | S-01 p3 | REQUIRED_BY_ASSIGNMENT |
| Problem 3: monthly revenue (and occupancy) reports take more than 1 minute; the task is to propose partitioning and a summary table or View/Trigger | S-01 p3 | REQUIRED_BY_ASSIGNMENT |
| Suggested reports: branch revenue by day/month/quarter/year; system-wide revenue with branch comparison; plan with the highest revenue in the last 6 months; best-selling plans/products per branch; tier distribution ratio | S-01 p3 §4 | REQUIRED_BY_ASSIGNMENT (as "suggested" reports; P3 ownership pending D-001) |
| Phase 2 deliverables: physical design table; query-improvement proposals; simulation app source; scripts for DB, query, index and partition; index screenshots with/without comparison; self-generated FK-valid data of ≥70,000 rows/table for selected tables | S-01 p4 | REQUIRED_BY_ASSIGNMENT |
| Logical schema: `INVOICE(Invoice_ID, Member_ID, Employee_ID, Branch_ID, IssuedAt, GrossAmount, DiscountAmount, FinalAmount, PaymentMethod, PaymentStatus)`; `INVOICE_SERVICE_ITEM(Invoice_ID, LineNo, Plan_ID, UnitPrice, DiscountAmount, ValidFrom, ValidUntil, PTSessionsRemaining)`; `INVOICE_PRODUCT_ITEM(Invoice_ID, LineNo, Product_ID, Quantity, UnitPrice, DiscountAmount)`; `MEMBER(..., CurrentPoints, Tier_ID)`; `MEMBER_TIER(Tier_ID, Tier_Name, SpendingThreshold)`; `MEMBER_MONTHLY_SPENDING(Member_ID, SpendingMonth, TotalSpend, PointsEarned, UpdatedAt)` | S-02 §10 | DERIVED_FROM_PHASE1 |

## 5. Use-case reconciliation: seven (Phase 1) vs six (team proposal)

**Phase 1 catalogue (S-02 §7.1, verified):**

| UC | Scenario | Functions | Must demonstrate |
|---|---|---|---|
| UC01 | Buy plan and pay | F04–F07 | Invoice and entitlement consistent |
| UC02 | Peak-hour check-in | F08–F10 | Fast validation, stable logging |
| UC03 | Two members book the same PT | F12–F14 | No overlapping bookings |
| UC04 | Sell products at a branch | F05–F06; F18–F19 | No overselling |
| **UC05** | Payment, points, tier evaluation | F06; F20–F22 | No duplicate points; lower aggregation cost |
| **UC06** | Training and revenue statistics | F27–F30 | Shorter report runtime on large data |
| UC07 | PT transfer and commission | F15; F24–F26; F33 | Correct assignment and salary at each point in time |

**Six-UC proposal (S-10 MISSING; known only from S-11):** UC05 = invoice settlement, spending aggregation, loyalty points, tier management. UC06 = revenue reporting by month, branch and whole system. The other four UCs and their owners are unknown.

Observations (none of these resolve the conflict):

1. F06 (payment confirmation) appears in UC01, UC04 and UC05. If six-UC UC05 owns "invoice settlement", the effects owned by other members (entitlement activation F07, inventory decrement F19) must join the same transaction (S-02 §7.2). See D-012.
2. Phase 1 UC06 also contains F29 (present members/occupancy, a CHECK_IN workload) and F30 (best sellers). A revenue-only UC06 would move F29 to the check-in owner and leave F30 unassigned. This is UNVERIFIED.
3. Merging UC01 and UC04 (both sell-and-pay flows sharing F05–F06) is one way to get six UCs from seven. This is a **hypothesis only**.
4. The assignment accepts 5–8 use cases (S-01 p4), so either catalogue is valid. The team must still pick one so that the report and the code are consistent.

Resolution: D-001 in [03_DECISION_LOG.md](03_DECISION_LOG.md), gap G-01 in [02_GAP_ANALYSIS.md](02_GAP_ANALYSIS.md).

**Owner statement (2026-11-07, directive WO-P3-P0-FINAL §6.1):** Person 3 remains responsible for UC05 (payment settlement and loyalty) and UC06 (revenue reporting). The other four Phase 2 UCs and their owners are still unknown (S-10).

**Phase 1 → Phase 2 mapping** (the Phase 1 report is not rewritten):

| Phase 1 UC (S-02 §7.1) | Functions | Phase 2 | P3 involvement | Note |
|---|---|---|---|---|
| UC01 Buy plan and pay | F04–F07 | Unknown (S-10) | F06 effects only (settlement in UC05) | F05 and F07 owned elsewhere |
| UC02 Peak-hour check-in | F08–F10 | Unknown | None | Reads `INVOICE.PaymentStatus` (D-005 contract) |
| UC03 Two members book the same PT | F12–F14 | Unknown | None | — |
| UC04 Sell products at a branch | F05–F06; F18–F19 | Unknown | F06 effects only | F19 inventory owned elsewhere |
| UC05 Payment, points, tier evaluation | F06; F20–F22 | **UC05** Payment settlement and loyalty | Owner | Same number |
| UC06 Training and revenue statistics | F27–F30 | **UC06** Revenue reporting (F27, F28) | Owner | F29 (occupancy) and F30 (best sellers) need named owners |
| UC07 PT transfer and commission | F15; F24–F26; F33 | Unknown | None | — |

Responsibilities that must keep a named owner in the Phase 2 catalogue: F29 occupancy and the occupancy half of Problem 3; F30 and RQ-A16/RQ-A17; RQ-A18 tier distribution (natural P3 candidate); the settlement orchestrator (D-012); the project-level partition demonstration (probably the check-in workload); the tracking tool (RQ-A20).

**Naming rule (recommended, part of D-001):** Phase 2 artifacts use the Phase 2 numbers as primary IDs; references to the old catalogue are written "Phase 1 UCxx"; the group report shows this mapping table once. For P3 the numbers coincide (UC05, UC06).

## 6. Person 3 scope

**Authoritative since 2026-11-07:** the Owner's ownership matrix (directive "Strict Person 3 Scope Enforcement"), reproduced in [WO-P3-P1-01 §3.2](work-orders/WO-P3-P1-01_PHYSICAL_SCHEMA.md#32-scope-matrix-directive-strict-person-3-scope-enforcement) and [12 §2](12_INTEGRATION_PLAN.md#2-shared-table-ownership-matrix-proposed). P3 owns INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM and MEMBER_MONTHLY_SPENDING; MEMBER, MEMBER_TIER, BRANCH, EMPLOYEE, SERVICE_PLAN and PRODUCT are shared dependencies; check-in, PT scheduling and sessions, commissions, employee assignment, payroll, member registration, inventory workflows, branch, plan and product administration and other members' UIs are excluded. Where the table below says otherwise (for example that invoice creation or the line tables belong to other members), the matrix prevails.

| Category | Items | Basis |
|---|---|---|
| **Core P3 scope** | F06 settlement *effects on loyalty and revenue*; F20; F21; F22; F27; F28; branch revenue by day/month/quarter/year; system revenue with branch comparison; Problem 4 redesign; revenue part of Problem 3; P3 physical design, indexes, partition feasibility, seed for P3 tables, benchmarks, tests, P3 application screens, P3 report section | S-01, S-02, S-11; confirmed by the Owner 2026-11-07 (UC05, UC06) |
| **Candidate scope (owner must be assigned under D-001)** | F30 best sellers; top-revenue plan in the last 6 months; tier distribution ratio; orchestration of the whole settlement transaction | S-01 §4, S-02 §7.1 |
| **Shared, owned elsewhere, integration only** | F05 invoice creation (UC01/UC04); F07 entitlement activation (UC01); F19 inventory decrement (UC04); catalogue tables BRANCH, EMPLOYEE, SERVICE_PLAN, PRODUCT, BRANCH_INVENTORY; MEMBER profile columns | S-02 §5.2, §7.1 |
| **Out of scope for P3** | Check-in (F08–F11, F29), PT booking (F12–F16), HR/payroll/commission (F23–F26, F33, F34), occupancy reports | S-02 §7.1 |
| **Explicitly not assumed** | Existence of `PAYMENT`, `LOYALTY_LEDGER`, `REVENUE_SUMMARY`/`REVENUE_MONTHLY` tables; `INVOICE.PaidAt`; `PaymentStatus` values | S-11 instruction; S-02 §10. **Update 2026-11-07:** `INVOICE.PaidAt` and the status values are now approved provisionally (D-004, D-005); no PAYMENT table (D-003) |
| **Excluded by approved scope restriction** | Loyalty point redemption, point expiration, redemption-specific tables and workflows (e.g. `LOYALTY_LEDGER`) | D-024, APPROVED 2026-11-07; consistent with S-01, S-02, S-11 |
