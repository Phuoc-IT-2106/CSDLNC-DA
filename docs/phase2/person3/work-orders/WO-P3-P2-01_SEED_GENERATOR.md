# WO-P3-P2-01 — Large Dataset: Deterministic Seed Generator

| Field | Value |
|---|---|
| Status | **PASSED** (2026-11-08; GATE-P2-01 closed — [§14](#14-owner-acceptance-gate-p2-01)) |
| Readiness | Executed 2026-11-08; acceptance criteria 1–8 have evidence (§13); independently re-checked and accepted by the Owner (§14). No team prerequisite (D-027). |
| Phase | P2 — Large Dataset and Baseline Measurement |
| Mode | BUILD_AUTHORIZED |
| Approver | Project Owner |
| Approval record | **APPROVED** 2026-11-08 by the Owner Directive "Approve P1 and Execute P2-01" (Claude Code session of 2026-11-08), §6: mode BUILD_AUTHORIZED; scope = the deterministic P3 dataset generator, the isolated database setup, validation scripts and supporting documentation; target database `FitLife_P3_P2` (§4 of the directive); F002 deferred (§5); no commit, push or merge; WO-P3-P2-02 not started automatically. |
| Target database | **`FitLife_P3_P2`** on the local default instance (named by the Owner on 2026-11-08), isolated and disposable per D-025, built from V001/V002 and the TEST_ONLY fixtures and carrying a `WO-P3-P2-01` disposable marker. One dataset tier at a time (the build script rebuilds it); the final state is DS-L. `FitLife_P3_P1` and every other database are not touched. |
| Scope rule | **Person 3 only.** Data is generated for INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM and MEMBER_MONTHLY_SPENDING. Shared parents receive key rows only (TEST_ONLY). No other member's data or workflow is generated. |

## 0. Revision record

| Date | Change |
|---|---|
| 2026-11-06 | Created by WO-P3-BOOT-001 |
| 2026-11-07 | UTC timestamps (D-014) and boundary rows in local time |
| 2026-11-08 | Owner Directive "Reprioritize Person 3 Implementation" (D-027): P3 tables only on TEST_ONLY key fixtures; BRANCH_INVENTORY and shared-module data removed; "seed ownership agreed in DL-02" and the team approver removed; D-007/D-008 only for the optional F002 extension; workload review, logical-consistency checks and V-TOT added |
| 2026-11-08 (2) | Approved by the Owner Directive "Approve P1 and Execute P2-01": target `FitLife_P3_P2` instead of three databases; F002 deferred until its first justified consumer |
| 2026-11-08 (3) | Accepted by the Owner Directive "Accept P2-01 and Resolve R-27": status `PASSED`, GATE-P2-01 closed (§14) |

## 1. Objective

Build a deterministic, set-based, FK-valid seed generator for DS-S, DS-M and DS-L (DS-XL only if approved) that meets RQ-A06 and produces **logically consistent** P3 data: invoice totals, payment states, member references and monthly spending agree with each other. Derived data is computed from the generated invoices, never invented.

## 2. Preconditions

1. GATE-P1 passed (WO-P3-P1-01 `PASSED`).
2. D-006 APPROVED (the rule for `MEMBER_MONTHLY_SPENDING.PointsEarned`, a NOT NULL column).
3. D-022 APPROVED (dataset tiers, T-SQL generation, the distributions and parameters of [10 §3.4](../10_SEED_AND_BENCHMARK_PLAN.md#34-distributions-and-parameters-defaults-are-assumption_pending_approval)).
4. Already approved: D-005, D-013, D-014, D-023, D-025, D-026 (restricted).
5. **Only if the approval includes the F002 loyalty-state extension:** D-007 and D-008 APPROVED.

No integration contract, team schema, team seed pipeline or other member's approval is required (D-027). The shared-interface assumptions used here are DEP-01, DEP-02/03 (only with F002), DEP-04, DEP-06 and DEP-10 of [12 §2b](../12_INTEGRATION_PLAN.md#2b-dependency-register-interim-assumptions-until-p6).

## 3. Inputs

[10 §3](../10_SEED_AND_BENCHMARK_PLAN.md#3-seed-data-plan); [04](../04_WORKLOAD_AND_DATA_VOLUME.md); DL-03 (V001, V002); `tests/db/fixtures/F001__TEST_ONLY_shared_dependency_keys.sql`; `tests/db/build/rebuild_isolated_db.sql`; [WO-P3-P1-01 §3.3a](WO-P3-P1-01_PHYSICAL_SCHEMA.md#33a-test_only-dependency-fixtures-isolated-database-only) (fixture rules).

## 4. Tasks

0. **Workload and volume review.** Re-check [04 §1–§3](../04_WORKLOAD_AND_DATA_VOLUME.md) against the Phase 1 workload (S-02 §5–§6, as quoted in the planning documents; open the source only if a fact is missing). Confirm or correct the DS tiers and the parameters of 10 §3.4 and record the result in §13. Approved decisions are not changed here.
1. **Configuration:** one configuration block or table holding every parameter of 10 §3.4 and the seed value; written into the dataset manifest.
2. **Fixture key rows (TEST_ONLY):** a data script in `tests/db/fixtures/` that inserts key rows into the F001 fixtures (12 branches, 30,000 members, employee, plan and product keys per 10 §3.4). Keys only.
3. **F002 extension (only if approved):** a TEST_ONLY script in `tests/db/fixtures/` adding `MEMBER.CurrentPoints`, `MEMBER.Tier_ID` and a MEMBER_TIER fixture (`Tier_ID`, `Tier_Name`, `SpendingThreshold`) with Phase 1 names, D-014 types and the Phase 1 FK only (fixture rule 4; DEP-02, DEP-03).
4. **Generation** of the four P3 tables in the order of [10 §3.2](../10_SEED_AND_BENCHMARK_PLAN.md#32-generation-order), set-based, with hash-based determinism (no unseeded randomness for data values). Line prices come from the seed price list (DEP-04); `ValidFrom`, `ValidUntil` and `PTSessionsRemaining` stay NULL (DEP-06).
5. **Derived data:** MEMBER_MONTHLY_SPENDING (TotalSpend, `PointsEarned` per D-006) by set-based aggregation of the PAID invoices by Asia/Ho_Chi_Minh month of `PaidAt` (D-013); with F002 also `CurrentPoints` (D-006, D-024) and `Tier_ID` as of the dataset end date (D-007, D-008).
6. **Boundary rows:** month, quarter and year edges defined on the Asia/Ho_Chi_Minh calendar, stored in UTC (D-014; [10 §3.1](../10_SEED_AND_BENCHMARK_PLAN.md#31-principles)), including payments between 00:00 and 06:59 local time on the 1st.
7. **Validation scripts:** T-SEED-01…03, V-TOT, T-REC-01, T-REC-02 (row part; member part and T-REC-04 only with F002), per-table checksums for T-REPRO-02. Re-run T-SCH-02 on a seeded database (the schema is unchanged by seeding).
8. **Generate** DS-S, DS-M and DS-L. Record timings, row counts and the measured sizes (`sp_spaceused`), which replace the estimate of [04 §4](../04_WORKLOAD_AND_DATA_VOLUME.md#4-rough-storage-estimate-assumption_pending_approval-verify-with-sp_spaceused-after-seeding) in the evidence (the estimate stays labelled ESTIMATE).
9. Update [01](../01_REQUIREMENTS_TRACEABILITY.md), [16](../16_READINESS_REPORT.md), [SESSION_LOG.md](../SESSION_LOG.md) and the dependency register if an assumption changed.

## 5. Out of scope

Invoice creation, settlement and loyalty routines (P3); nonclustered indexes, summaries or partitions (the datasets are the B0 configuration); benchmarks (WO-P3-P2-02); **BRANCH_INVENTORY and any data of other members' modules** (stock, entitlements, PT sessions, check-ins, employee assignments, catalogue names or prices in shared tables, member profiles); simulated workflows in fixtures; seeding the canonical shared database (D-025 conditions 1 and 7); DS-XL unless approved; installing software.

## 6. Deliverables and locations

DL-04: generator and configuration in `db/seed/` (P3 tables only); fixture key-row and F002 scripts in `tests/db/fixtures/` (TEST_ONLY); validation scripts in `tests/db/seed/`; outputs in `docs/phase2/person3/evidence/test-results/`.

## 7. Acceptance criteria

1. T-SEED-01, T-SEED-02, T-SEED-03 pass for DS-S, DS-M and DS-L.
2. INVOICE and INVOICE_PRODUCT_ITEM ≥ 70,000 rows in DS-M; INVOICE, INVOICE_PRODUCT_ITEM and MEMBER_MONTHLY_SPENDING ≥ 70,000 rows in DS-L (actual counts reported; a shortfall is reported, not hidden).
3. V-TOT, T-REC-01 and T-REC-02 (row part) return zero mismatches; with F002 also the member part of T-REC-02 and T-REC-04.
4. T-REPRO-02: two generations with the same seed give identical per-table checksums.
5. All constraints enabled and trusted after loading; T-SCH-02 passes on a seeded database.
6. Separation: nothing under `db/` creates or alters a non-P3 table; fixtures contain key columns only (plus the F002 Phase 1 columns if approved); no BRANCH_INVENTORY or other shared-module data exists.
7. The workload review (task 0) is recorded in §13.
8. No nonclustered index, summary or partition exists in the generated databases.

## 8. Verification

Run the generator twice on fresh databases and compare checksums; run the validation scripts and save their outputs; run the separation check.

## 9. Evidence

Row-count table, distribution report, checksum report, size report and timing log in `evidence/test-results/` (`T-SEED-0x__<YYYYMMDD-HHMM>.txt`, `T-REC-0x__…`, `V-TOT__…`, `T-REPRO-02__…`).

## 10. Dependencies and risks

R-05, R-06, R-25, R-26. The fixtures are replaced by the team schema at P6; the validation is re-run then (D-026 condition 9).

## 11. Approval requirements

WO approval with the target databases named; separate authorization for commits. Proposed approval statement (historical, 2026-11-08 before approval; the Owner approved one database, `FitLife_P3_P2`, instead of the three named here):

> "WO-P3-P2-01 APPROVED, mode BUILD_AUTHORIZED. Target databases <FitLife_P3_DS_S, FitLife_P3_DS_M, FitLife_P3_DS_L> on instance <MSSQLSERVER>: create, rebuild, load and drop. F002 loyalty-state extension: <included / not included>. DS-XL: <approved / not approved>. Branch `p3/wo-p3-p2-01`. Local commits: <authorized / not authorized>. Push, PR and merge: not authorized. — Project Owner, <date>"

## 12. Exit and next step

Set `VERIFIED` when criteria 1–8 hold; the Owner sets `PASSED`. Next: WO-P3-P2-02 (after WO-P3-P0-02 is `PASSED` and D-010 is approved).

## 13. Execution record

**2026-11-08, mode BUILD_AUTHORIZED** (Owner Directive "Approve P1 and Execute P2-01"). Working copy `C:\Users\DELL\source\repos\CSDLNC-DA`, branch `p3/wo-p3-p1-01`, HEAD `792a85e`; all P3 work untracked; nothing committed, pushed or merged. Target `FitLife_P3_P2` only; `FitLife_P3_P1` and every other database unchanged (fingerprint identical before and after every run).

### 13.1 Environment

SQL Server 2025 RTM 17.0.1000.7, Standard Developer (64-bit), local default instance, Windows authentication over shared memory, compatibility level 160, `FitLife_P3_P2` SIMPLE recovery, owner = the current login. Machine: 8 logical CPUs, 7.9 GB RAM, Windows Balanced power plan; on battery during the last run. **Memory condition (R-27):** Windows reported low available memory (about 0.5–1 GB free), SQL Server committed about 320 MB and its query-memory pool was 7.8 MB of a 250 MB maximum during most of the session; it grew to about 790 MB at the end, when more RAM was free. The laptop entered connected standby at 03:46–04:07 and 04:08–04:39 UTC and slept from 04:39 to 11:49 UTC (Windows System log, Kernel-Power events 506/507/42/107, Power-Troubleshooter 1).

### 13.2 Task 0 — workload and volume review

The Phase 1 workload as quoted in [04 §1–§3](../04_WORKLOAD_AND_DATA_VOLUME.md) was re-checked against the approved D-022 targets: 12 branches, 30,000 active members, 900 invoices per day and 30 days per month (27,000 per month, 324,000 per year), 180 service lines and 1,980 product lines per day (20% service invoices with one line; 80% product invoices with 2.75 lines on average). These derive the DS-L targets exactly (324,000; 712,800; 64,800), so the tiers stay as planned. Two corrections, recorded in [10 §3.4](../10_SEED_AND_BENCHMARK_PLAN.md) and [04 §3](../04_WORKLOAD_AND_DATA_VOLUME.md): (1) "3% PENDING only in the last days" cannot hold (the last days hold less than 1% of the invoices), so PENDING is 30% of the last three days' invoices; (2) MEMBER_MONTHLY_SPENDING has about 14,000 rows per month (distinct paying members), not the 30,000 upper bound, so it reaches 70,000 rows only in DS-L. No approved decision was changed.

### 13.3 Method and files

Generator `db/seed/S001__p3_dataset_generator.sql` (S001 v1.0): set-based T-SQL; every pseudo-random value is a 4-byte slice of SHA-256(seed : stream : key), keyed by local date and invoice number in the day, member key, or invoice and line number; seed 20261108; no `NEWID()`, `RAND()` or clock values in the data; Invoice_ID assigned in (IssuedAt, key) order and inserted explicitly. Local Asia/Ho_Chi_Minh business times, stored in UTC. Header totals from the lines (D-023); payment states per D-005; monthly spending from PAID invoices by local month of `PaidAt`, `PointsEarned = FLOOR(TotalSpend / 100000)` (D-006, D-013). Parameters: `db/seed/profiles.json` and [10 §3.4](../10_SEED_AND_BENCHMARK_PLAN.md). Fixture key rows: `tests/db/fixtures/F001D__TEST_ONLY_fixture_key_rows.sql` (keys only). Build, rollback and safety: `tests/db/build/preflight_p2.sql`, `rebuild_p2_db.sql`, `drop_p2_db.sql`, `fingerprint_instance.sql` (the P1 harness `rebuild_isolated_db.sql` is unchanged because it is P1 evidence). Validation: `tests/db/seed/T-SEED_dataset_checks.sql` (T-SEED-01…05, V-TOT, T-REC-01, T-REC-02) and `T-REPRO-02_checksums.sql`. Runner: `tests/db/seed/run_p2_dataset.ps1` (writes the run log, checksums and manifest; masks the machine and server names). Reproduction: [db/seed/README.md](../../../../db/seed/README.md).

### 13.4 Recorded runs

| Run | Dataset | Result | Generator (s) | Validation (s) | Conditions | Evidence |
|---|---|---|---|---|---|---|
| DS-S A | 7 days | PASS (31 PASS, 3 INFO) | 1.9 | 1.9 | normal | [log](../evidence/test-results/P2-RUN__DS-S__20261108-0337_A.txt), [manifest](../evidence/test-results/DATASET-MANIFEST__DS-S__20261108-0337_A.md) |
| DS-S B | 7 days | PASS; checksums = A | 2.1 | 1.9 | normal | [log](../evidence/test-results/P2-RUN__DS-S__20261108-0338_B.txt) |
| DS-M A | 3 months | PASS (33 PASS, 1 INFO) | 368 | 5 | memory paging (no standby) | [log](../evidence/test-results/P2-RUN__DS-M__20261108-0338_A.txt), [manifest](../evidence/test-results/DATASET-MANIFEST__DS-M__20261108-0338_A.md) |
| DS-L A | 12 months | PASS (33 PASS, 1 INFO) | 52 | 1,302 | validation overlapped connected standby | [log](../evidence/test-results/P2-RUN__DS-L__20261108-0345_A.txt), [manifest](../evidence/test-results/DATASET-MANIFEST__DS-L__20261108-0345_A.md) |
| DS-L B | 12 months | PASS; checksums = A | 1,143 | 26,036 | standby and sleep 04:08–11:49 UTC | [log](../evidence/test-results/P2-RUN__DS-L__20261108-0408_B.txt) |
| **DS-L C** | 12 months | **PASS; checksums = A** | **168** | **96** | no power event; on battery | [log](../evidence/test-results/P2-RUN__DS-L__20261108-1155_C.txt), [manifest](../evidence/test-results/DATASET-MANIFEST__DS-L__20261108-1155_C.md) |

Times are wall-clock times of an isolated generation run on this laptop, recorded for reproduction planning. **They are not performance measurements** and are not used as benchmark evidence. Run C (whole run 5 min 10 s) is the only DS-L run without a power event; DS-M and runs A and B were slowed by memory paging, standby or sleep. The database now holds DS-L (run C).

### 13.5 Actual row counts and storage

| Table | DS-S | DS-M | DS-L | DS-L reserved |
|---|---|---|---|---|
| INVOICE | 6,479 | 81,000 | **324,000** | 25.70 MB (3,289 pages) |
| INVOICE_PRODUCT_ITEM | 14,044 | 178,518 | **712,789** | 28.38 MB |
| INVOICE_SERVICE_ITEM | 1,334 | 16,268 | **65,177** | 3.07 MB |
| MEMBER_MONTHLY_SPENDING | 5,471 | 42,059 | **169,040** | 6.01 MB |
| Fixture keys (TEST_ONLY) | MEMBER 30,000; BRANCH 12; EMPLOYEE 120; SERVICE_PLAN 30; PRODUCT 200 | same | same | 0.79 MB |

DS-L data file: 68.5 MB used of 72 MB; log 8 MB. Measured DS-L distributions: CANCELLED 2.04%; PENDING 28.9% of the last three days (n = 2,587); methods CASH 39.9 / VNPAY 35.1 / CARD 25.0%; service invoices 20.1%; 2.754 lines per product invoice; branch shares within 0.34 pp of the weights; top 20% of members 60.1% of invoices; discounted lines 20.0%; evening peak 47.3%; 402 payments at 00:00–06:59 local on the 1st; 34 boundary rows. D-006 effect (INFO): 6,110,230 points under the monthly rule vs 6,055,718 under a per-invoice floor; 7,537,761,600 VND of month-end residual not carried over.

### 13.6 Acceptance criteria

| AC | Result | Evidence |
|---|---|---|
| 1 T-SEED-01…03 for DS-S, DS-M, DS-L | **PASS** (T-SEED-04 and -05 added; also PASS) | run logs, step 7 |
| 2 ≥ 70,000 rows: INVOICE, INVOICE_PRODUCT_ITEM in DS-M; plus MEMBER_MONTHLY_SPENDING in DS-L | **PASS** (81,000 / 178,518; 324,000 / 712,789 / 169,040) | T-SEED-01 C04 |
| 3 V-TOT, T-REC-01, T-REC-02 (row part) zero mismatches | **PASS** (also the incremental-replay check of D-006); member part of T-REC-02 and T-REC-04 `NOT_RUN`: F002 deferred by the Owner | C29–C33 |
| 4 T-REPRO-02 identical checksums | **PASS**: DS-S A = B; DS-L A = B = C (dataset checksum `26ABB277…CA1F`). A DS-L trial run kept in the session scratchpad gave the same checksum; it is not evidence | CHECKSUMS files; step 8 compare |
| 5 Constraints enabled and trusted; T-SCH-02 on a seeded database | **PASS** (8 FK, 13 CHECK trusted; every CHECK re-evaluated; T-SCH-02 6/6) | C07, C08; step 6 |
| 6 Separation | **PASS** | [SEPARATION-P2](../evidence/test-results/SEPARATION-P2__20261108-0339.txt); C12 |
| 7 Workload review recorded | **PASS** | §13.2 |
| 8 No nonclustered index, summary or partition | **PASS** | C13; T-SCH-02 C5 |

### 13.7 Deviations from this WO's text

1. One target database `FitLife_P3_P2` (Owner, §4 of the directive) instead of three; each run rebuilds it.
2. Validation consolidated into one script plus the checksum script; evidence named `P2-RUN__`, `CHECKSUMS__`, `DATASET-MANIFEST__` instead of one file per test ID. T-SEED-04 (payment states) and T-SEED-05 (month boundaries) added; share tolerances are ±2 pp or 4 standard errors for small samples (DS-S).
3. Parameter refinements listed as "Changed" in 10 §3.4 (PENDING definition, employee key blocks per branch, boundary rows at `.999`).
4. Statistics are not updated by the generator; WO-P3-P2-02 updates them per configuration.
5. Because of the memory condition: `DBCC CHECKCONSTRAINTS` replaced by re-evaluating each CHECK definition (same check for CHECK constraints; FKs by anti-joins), and large statements carry `OPTION (MAX_GRANT_PERCENT = 2)` (`runtime.MaxGrantPercent`), which changes memory use, not data.
6. Run C was added to obtain a generation time without a power event.

### 13.8 Defects and incidents

1. **Trial runs** (scratchpad, not evidence): the first DS-S trial passed every check but took 154 s for 6,479 invoices, because queries waited on RESOURCE_SEMAPHORE (query-memory pool 7.68 MB). The generator was restructured (materialised hash uniforms, ranks and IDs computed at insert, indexes declared with the temporary tables) and the grant cap added; the next DS-S trial took 2.2 s. A DS-L trial passed with the same dataset checksum as the recorded runs.
2. **Superseded recordings** (moved out of the repository to the session scratchpad; they are not evidence): two GATE-P1-RECHECK files from defective recording scripts (a PowerShell variable-name collision; an unsupported wildcard) and one SEPARATION-P2 output with a false positive (the word "assignment" in an error-message string matched a substring rule). The checker now ignores comments and string literals and matches table identifiers only.
3. **Orchestration bug:** the first batch of recorded runs stopped after DS-S A, because the wrapper took the runner's printed output as its return value. DS-S A itself passed; the batch was resumed from DS-S B.
4. **Coordination incident:** run C's rebuild (`SINGLE_USER WITH ROLLBACK IMMEDIATE`) terminated a read-only re-checksum query that another Claude session (P2-01 completion audit) was running on `FitLife_P3_P2` at 11:55:33 UTC. No data outside `FitLife_P3_P2` was affected. A rebuild should be announced to other sessions first.

### 13.9 Status

`VERIFIED`: acceptance criteria 1–8 have evidence. The Owner sets `PASSED`. WO-P3-P2-02 is not started. _(Superseded 2026-11-08 by §14: `PASSED`.)_

## 14. Owner acceptance (GATE-P2-01)

**2026-11-08, Owner Directive "Accept P2-01 and Resolve R-27" (Claude Code session csdlnc-da-32 of 2026-11-08), §1.** The Owner accepted this WO on its `VERIFIED` status. The acceptance was conditional on three things: the mandatory acceptance criteria hold, the execution record and its evidence are present, and the two documentation errors reported by the completion audit are corrected. Re-check performed before setting `PASSED` (VERIFY_ONLY, read-only; no dataset was regenerated and `FitLife_P3_P2` was not modified):

| Check | Result |
|---|---|
| All 11 evidence files linked from §13 exist; the six run logs end in `P2-RUN_RESULT: PASS` | PASS |
| The ten script SHA-256 values in all six manifests equal the current files (generator, profile, fixtures, build, migrations, validation, runner) | PASS |
| T-REPRO-02: checksum files DS-L A = B = C and DS-S A = B (identical file SHA-256); `T-REPRO-02_checksums.sql` re-run on the live database gives the same output | PASS |
| `T-SEED_dataset_checks.sql` re-run on the live DS-L database: 34 checks, 33 PASS, 0 FAIL, 1 INFO (C34, D-006 effect) | PASS |
| Independent queries written by the auditor rather than taken from the team scripts. Local month computed by `AT TIME ZONE` rather than the scripts' fixed +7 h. Results: V-TOT 0 mismatches; T-REC-01 0 (431 payments whose UTC month differs from the local month are all counted in the local month); D-006 0; duplicate member-months 0; 8/8 FK and 13/13 CHECK enabled and trusted; no nonclustered index, partition function, view, routine or trigger; no non-P3 table; fixtures key-only; disposable marker present | PASS |
| Audit findings corrected: 15 rule 7 and the §2.3 diagram show WO-P3-P1-01 `PASSED`; §13.6 AC4 labels the scratchpad trial "not evidence" | PASS |
| RQ-A06 consistent across 01 (line 27 official wording kept; line 74 per tier), 04 §3, 10 §3.5, 13 DL-04 and §13.5/§13.6: DS-M INVOICE 81,000 and INVOICE_PRODUCT_ITEM 178,518; DS-L adds MEMBER_MONTHLY_SPENDING 169,040; DS-M MEMBER_MONTHLY_SPENDING 42,059 is not claimed as ≥ 70,000 | PASS |

Evidence: [GATE-P2-01-RECHECK__20261108-1233.txt](../evidence/test-results/GATE-P2-01-RECHECK__20261108-1233.txt), recorded in one pass by a recorder script; every check of the table above was re-run in it. Two earlier recordings were defective and were moved out of the repository to the session scratchpad; they are not evidence:
- `…__20261108-1206.txt`: its script-version block was corrected in place after capture, which breaks evidence rule 1. The correction itself came from a grep pattern that had matched nothing.
- `…__20261108-1231.txt`: the independent-query step never ran, because sqlcmd rejected the path to the query file.

Neither defect concerned the data. The finding was raised by session `csdlnc-da-11`.

No inconsistency was found, so the WO is set to **`PASSED`** and **GATE-P2-01 is closed**: WO-P3-P2-01 `PASSED` is the precondition of WO-P3-P2-02. GATE-P2 (end of phase P2) remains open until WO-P3-P2-02 passes. The seed datasets, `FitLife_P3_P2` (DS-L, run C) and all evidence are preserved unchanged.

The run timings in §13.4 remain non-measurements. Benchmark readiness is assessed separately under R-27 ([14](../14_RISK_REGISTER.md)) and in [WO-P3-P2-02 §2a](WO-P3-P2-02_BASELINE_BENCHMARK.md#2a-benchmark-readiness-checklist-r-27).
