# WO-P3-P3-02 — Incremental Loyalty and Tier Evaluation

| Field | Value |
|---|---|
| Status | **PASSED** (2026-11-10): accepted by the Project Owner (Owner Directive "Accept Loyalty & Implement UC06 Revenue Correctness" §2, conditional on the evidence staying consistent; re-checked the same day, [§14](#14-owner-acceptance-2026-11-10)). `VERIFIED` since 2026-11-09: all four acceptance criteria met with recorded evidence (run `UC05LOY-RUN__20261109-1636`, 62/62 steps PASS; §13) |
| Phase | P3 — Billing, Settlement and Loyalty Implementation |
| Mode | BUILD_AUTHORIZED |
| Approver | Project Owner |
| Approval record | **APPROVED 2026-11-09, BUILD_AUTHORIZED**, by the Owner Directive "Finalize UC05 Settlement and Implement Loyalty" (Claude Code session of 2026-11-09) §1 item 5 and §8, effective after the WO-P3-P3-01 gate: WO-P3-P3-01 `PASSED` 2026-11-09. Preconditions: D-006 ✔, D-007 (d) ✔ T2, D-008 **rule** ✔ T2 (values not approved: TEST_ONLY synthetic), D-009 (a) ✔ T2, D-024 ✔, F002 (F002P + F002T TEST_ONLY) ✔. No scheduler, commit, push or merge authorized |
| Target database | `FitLife_P3_UC05` (fixtures; disposable marker verified) and **`FitLife_P3_UC05L`** (DS-L copy for criterion 3 and task 0; approved by the Owner's answer in the same session; built by the unchanged P2 generator, dataset checksum = run C). `FitLife_P3_P1`, `FitLife_P3_P2` and other databases unchanged |
| Revision | 2026-11-08 (Owner Directive "Reprioritize Person 3 Implementation" (2026-11-08, D-027)): MEMBER loyalty columns and MEMBER_TIER through the F002 TEST_ONLY extension (DEP-02, DEP-03); Q-UC05-B/C baseline here if not captured in P2. 2026-11-09 (Owner Directive "Urgent Unblock & Core Implementation" §3, §5, §10): R-27 does not block the loyalty functions or their tests; for task 0, query texts, actual plans, logical reads and row counts are valid, while timings stay DIAGNOSTIC_ONLY until R-27 is closed, and no loyalty index is adopted before a comparison baseline exists. D-007, D-008, D-009 remain `PROPOSED` and were not approved by the directive . 2026-11-09 (2) (Owner Directive "UC05 Loyalty Decision Closure & Implementation Readiness", PLAN_ONLY): readiness assessed in the [P3 loyalty decision package](../design/P3_LOYALTY_DECISION_PACKAGE.md) §7–§9 — NOT READY until D-007, D-008 rule, D-009, the F002 tier fixture, the target for the DS-L check and the WO-P3-P3-01 acceptance are given; proposed tests T-F05-12…-15, -32…-35, T-CONC-04F; no change to the settlement routine. Status unchanged |

## 1. Objective

Implement the loyalty lookup (F21) and the periodic tier evaluation (F22), plus the tier distribution report if D-001 assigns it to P3. Prove the point, tier and window rules at their boundaries.

## 2. Preconditions

WO-P3-P3-01 PASSED; F002 exists (DEP-02, DEP-03); D-006, D-007, D-008, D-009 APPROVED; D-024 confirmed (accrual only; reclassified OUT_OF_SCOPE and removed from the P1 set on 2026-11-07). If D-006 option (b) is approved, this WO adds the CHECK `PointsEarned = FLOOR(TotalSpend / 100000)` as an additive migration.

## 3. Inputs

[06 §4.5–§4.7](../06_UC05_BILLING_LOYALTY_PLAN.md#46-periodic-tier-evaluation-f22-pending-d-007-d-008-d-009); [11 §2.3](../11_TEST_AND_QA_PLAN.md#23-uc05-functional-wo-p3-p3-01-wo-p3-p3-02).

## 4. Tasks

0. If WO-P3-P2-02 did not baseline Q-UC05-B/C: freeze them and capture their B0 (protocol of [10 §4.3](../10_SEED_AND_BENCHMARK_PLAN.md#43-measurement-protocol)) **before** any loyalty index or routine change.
1. Implement `usp_P3_GetMemberLoyalty` (F21).
2. Implement `usp_P3_EvaluateTiers(@AsOfDate)`: set-based, updates only changed rows, chunked below lock escalation, idempotent, returns change counts.
3. If D-009(b) is approved as an option: implement the immediate-upgrade variant behind a clearly named separate routine or parameter, for measurement.
4. Tier distribution query (Q-UC06-G) if in scope.
5. Tests: T-F05-09, T-F05-12…T-F05-15, T-F06-08 (if in scope), T-REC-01, T-REC-02, T-REC-04.
6. Update [01](../01_REQUIREMENTS_TRACEABILITY.md), [16](../16_READINESS_REPORT.md) and [SESSION_LOG.md](../SESSION_LOG.md).

## 5. Out of scope

Concurrency suite and benchmarks (WO-P3-P3-03); new indexes (IX-07 is evaluated in WO-P3-P3-03).

## 6. Deliverables and locations

DL-08 in `db/procedures/`; tests in `tests/db/functional/` and `tests/db/reconciliation/`.

## 7. Acceptance criteria

1. All listed tests pass.
2. The tier batch run twice gives the same state (T-F05-14).
3. Reconciliation queries return zero mismatches on DS-L after a batch run.
4. Thresholds are read from MEMBER_TIER (code review: no hard-coded threshold values).

## 8. Verification

Run the tests on fixtures and on DS-L; save the outputs.

## 9. Evidence

`evidence/test-results/` outputs for each test ID.

## 10. Dependencies and risks

R-15, R-16.

## 11. Approval requirements

WO approval; separate authorization for commits.

## 12. Exit and next step

Next: WO-P3-P3-03.

## 13. Execution record

Session of 2026-11-09 (Owner Directive "Finalize UC05 Settlement and Implement Loyalty"), mode BUILD_AUTHORIZED. Clone `C:\Users\DELL\source\repos\CSDLNC-DA`, branch `p3/wo-p3-p1-01`, HEAD `792a85e`; nothing committed.

### 13.1 Implemented

| File | Classification | Content |
|---|---|---|
| [db/procedures/usp_P3_EvaluateTiers.sql](../../../../db/procedures/usp_P3_EvaluateTiers.sql) | P3_OWNED, programmability | `tvf_P3_TierWindow` (D-007), `tvf_P3_TierForSpend` (D-008 rule, reads MEMBER_TIER), `usp_P3_EvaluateTiers(@AsOfDate, @ChunkSize)` (task 2): config check (51322/51323), refuses a caller transaction (51320), window spend from MEMBER_MONTHLY_SPENDING only (no INVOICE), spend 0 → base tier, updates `MEMBER.Tier_ID` only where different, chunks ≤ 4,500 in own transactions, run serialisation by `sp_getapplock` (51324), returns upgrade/downgrade/unchanged counts |
| [db/procedures/usp_P3_GetMemberLoyalty.sql](../../../../db/procedures/usp_P3_GetMemberLoyalty.sql) | P3_OWNED, read-only | F21 lookup (task 1): points, stored and evaluated tier, window, spend, next tier and gap (51330/51331) |
| [db/migrations/V003__p3_points_earned_rule.sql](../../../../db/migrations/V003__p3_points_earned_rule.sql) | P3_OWNED migration, additive | CHECK `PointsEarned = FLOOR(TotalSpend / 100000)` on MEMBER_MONTHLY_SPENDING (§2: D-006 (b) approved), validated WITH CHECK on fixtures and on all DS-L rows |
| [db/queries/baseline/Q-UC05-B.sql](../../../../db/queries/baseline/Q-UC05-B.sql), [Q-UC05-C.sql](../../../../db/queries/baseline/Q-UC05-C.sql) | Frozen baseline queries (task 0) | Never edited afterwards |
| [tests/db/functional/T-F05L_loyalty_tiers.sql](../../../../tests/db/functional/T-F05L_loyalty_tiers.sql) | Test | T-F05-12…-15, -32…-35 (10 cases) |
| [tests/db/reconciliation/T-REC_loyalty.sql](../../../../tests/db/reconciliation/T-REC_loyalty.sql) | Test | T-REC-01, -02, -04 (tier oracle computed from INVOICE, never from the aggregate) |
| [tests/db/concurrency/T-CONC-04F_settlement_vs_tier_batch.ps1](../../../../tests/db/concurrency/T-CONC-04F_settlement_vs_tier_batch.ps1) | Test | Settlement concurrent with the batch, final-state checks C1–C6 |
| [tests/db/schema/T-SCH-05_loyalty_catalog_and_scope.sql](../../../../tests/db/schema/T-SCH-05_loyalty_catalog_and_scope.sql) | Test | Catalog, inventory, write scopes, no hard-coded threshold, approved routines unchanged |
| [tests/db/loyalty/capture_q_uc05_bc_b0.ps1](../../../../tests/db/loyalty/capture_q_uc05_bc_b0.ps1) | Test harness (task 0) | Plans, STATISTICS IO, row counts, result hashes; no timing |
| [tests/db/build/rebuild_uc05l_db.sql](../../../../tests/db/build/rebuild_uc05l_db.sql), [tests/db/fixtures/L001__TEST_ONLY_dsl_loyalty_state.sql](../../../../tests/db/fixtures/L001__TEST_ONLY_dsl_loyalty_state.sql) | TEST_ONLY | DS-L copy build (guarded; marker); CurrentPoints = Σ PointsEarned loader |
| [tests/db/functional/run_uc05_loyalty.ps1](../../../../tests/db/functional/run_uc05_loyalty.ps1) | Runner | Stage 1 fixtures + regression; stage 2 DS-L |

Reused without change: `usp_P3_SettleInvoice` (monthly spending and incremental points: the WO's "incremental loyalty" part already lives there and is not duplicated), `usp_P3_CreateInvoice`, `usp_P3_CancelInvoice`, `tvf_P3_SpendingMonth` (definition hashes checked by T-SCH-05 K6). TEST_ONLY F002T/F003H and the REFERENCE_ONLY U0 come from WO-P3-P3-01 task 2.

**Defect found and fixed during development (before the recorded run).** Two overlapping batch runs could let the run with the older spending snapshot overwrite the newer run's result (a spurious downgrade). The routine now serialises runs with an application lock; T-CONC-04F (two batch sessions in parallel with eight settlement sessions) shows no downgrade. A runner defect (helper functions returning their log text, which would not have stopped the run on a failed deployment step; failures were still counted) was fixed after the dry run. Dry runs wrote only to the session scratchpad.

### 13.2 Verification run `UC05LOY-RUN__20261109-1636` (16:36–16:41:45 UTC): 62 of 62 steps PASS

Stage 1 (`FitLife_P3_UC05`): P1 regression (T-SCH-01 53 PASS / 1 INFO, T-SCH-02 6/6); P3-00/01 deployment and scope (T-SCH-03, T-SCH-04); F002T (synthetic Gold 1,000,000.00 / Platinum 3,000,000.00), F003H, U0, V003, loyalty routines; T-SCH-05 7/7 (twice); regression T-F05S 47/47, T-F05-U0 9/9, T-CONC-06 R, T-CONC-01 A, T-CONC-02 A; T-F05L 10/10; T-CONC-04F A/B/C 6/6 each; V-UC05T 10/10 after every stage (8×); T-REC-01/02/04 after T-F05L and after each T-CONC-04F run (4×). Stage 2 (`FitLife_P3_UC05L`): DS-L generated by S001, checksum `26ABB277…CA1F` = run C before and after the loyalty work; F002P, F002T, L001; task 0; V003; batch and reconciliation for two dates. Fingerprint of all other databases before = after; `FitLife_P3_P2` checksum = run C before and after.

### 13.3 Test results

| Test | Result | Evidence of behaviour |
|---|---|---|
| T-F05-09 (points boundaries) | PASS (T-F05S A07–A13) | 0 / 99,999 / 100,000 / 199,999 / 200,000 VND → 0, 0, 1, 1, 2; two × 60,000 → +1 |
| T-F05-12 (selection, boundaries, upgrade) | PASS (L01, L03) | Spend 0, Gold − 0.01 → Silver; = Gold, Gold + 0.01, Platinum − 0.01 → Gold; = Platinum, above → Platinum; a 0.01 payment keeps Silver until the next batch, which upgrades exactly that member (accepted D-009 (a) latency) |
| T-F05-13 (window expiry, no-payment downgrade, Dec/Jan) | PASS (L04, L05b) | Platinum spend in the oldest window month (Dec 2025): Platinum on 2026-11-09 and 2026-11-30, Silver on 2026-12-01 with no payment; Dec 2025 + Jan 2026 payments: 2026-11-30 both count, 2026-12-01 only January, 2027-01-01 none |
| T-F05-14 (idempotent batch) | PASS (L02; DS-L steps 41, 44; T-CONC-04F C6) | Second run for the same date: 0 upgrades, 0 downgrades, no row written |
| T-F05-15 (lookup) | PASS (L06) | Gold member: spend 1,000,000.00, next Platinum, gap 2,000,000.00; Silver member: spend 0, gap 1,000,000.00; Platinum member: no next tier; unknown/NULL member rejected |
| T-F05-32 (25 small invoices) | PASS (L07) | Points per call 0 ×24 then 1 at 100,000 VND |
| T-F05-33 (month boundary) | PASS (L05a) | 2025-12-31 16:59:59.999 UTC → December row, 17:00:00.000 UTC → January row |
| T-F05-34 (batch rollback) | PASS (L09) | Failure in member 20's chunk: member 19 (earlier chunk) committed correctly, member 20 and all later members unchanged, error 52930 passed through; re-run equals the oracle |
| T-F05-35 (invalid configuration) | PASS (L08) | Second tier at 0 → 51322, duplicate threshold → 51323; nothing written |
| T-REC-01/02/04 (fixtures) | PASS ×4 | 0 mismatches; Tier_ID = INVOICE-based oracle |
| T-REC-01/02/04 (DS-L, as of 2025-12-31) | PASS | 30,000 members evaluated; 29,521 upgrades from the initial base tier, 0 downgrades; distribution (synthetic thresholds) Silver 479 / Gold 1,604 / Platinum 27,917 |
| T-REC-01/02/04 (DS-L, as of 2026-01-15, no new payment) | PASS | January 2025 left the window: **668 downgrades, 0 upgrades**; Silver 679 / Gold 1,956 / Platinum 27,365; re-run 0 changes |
| T-CONC-04F A/B/C | PASS ×3 | 200/200 settlements each; 24/22/16 batch runs in parallel (20/20/15 overlapping settlements); upgrades during the run 13/14/0, **downgrades 0**; final Tier_ID = oracle; no lost spending or points; final re-run 0 changes; 0 deadlocks |
| T-SCH-05 | PASS ×2 | Batch reads no INVOICE and writes only `MEMBER.Tier_ID`; lookup read-only; no 6+ digit literal or dynamic SQL; create/settle/cancel/month function unchanged; no leftover principal |
| Regression (T-F05S, T-F05-U0, T-CONC-01/02/06, V-UC05T, T-SCH-01…04) | PASS | Invoice creation, settlement, cancellation, payment-state integrity, spending consistency, FK integrity (U10), no unauthorized shared write |
| T-F06-08 (tier distribution report), task 4 | NOT_RUN (out of scope) | Only "if D-001 assigns it to P3"; D-001 is PROPOSED. Distribution counts above are context, not the report |
| Task 3 (D-009 (b) variant) | NOT_RUN (not approved) | D-009 (a) chosen |

Task 0 ([T0-QUC05BC__20261109-1636.txt](../evidence/test-results/T0-QUC05BC__20261109-1636.txt), plans `execution-plans/Q-UC05-*__B0__DS-L__P*__20261109-1636.sqlplan`), B0, before any loyalty routine or index, statistics FULLSCAN: Q-UC05-B (member 1, member 30000): 7 logical reads each (MEMBER 2, MEMBER_TIER 2, MEMBER_MONTHLY_SPENDING 3; clustered index seeks); Q-UC05-C (window 2025, window Feb 2025–Jan 2026): 759 logical reads each (clustered index scan + stream aggregate; 29,870 and 29,804 rows). **No timing recorded** (R-27); index candidate IX-07 is evaluated in WO-P3-P3-03.

Evidence: [UC05LOY-RUN__20261109-1636.txt](../evidence/test-results/UC05LOY-RUN__20261109-1636.txt), [T-F05L__20261109-1636.txt](../evidence/test-results/T-F05L__20261109-1636.txt), [T-CONC-04F _A](../evidence/test-results/T-CONC-04F__20261109-1636_A.txt), [_B](../evidence/test-results/T-CONC-04F__20261109-1636_B.txt), [_C](../evidence/test-results/T-CONC-04F__20261109-1636_C.txt), [T0-QUC05BC](../evidence/test-results/T0-QUC05BC__20261109-1636.txt), and the regression files of the same timestamp (T-F05S-SETTLE, T-F05-U0, T-CONC-06 R, T-CONC-01 A, T-CONC-02 A).

### 13.4 Acceptance criteria (§7)

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | All listed tests pass | **MET** (T-F05-09, -12…-15, T-REC-01/02/04; T-F06-08 out of scope, D-001) | §13.3 |
| 2 | Batch run twice gives the same state (T-F05-14) | **MET** | L02; DS-L steps 41, 44 |
| 3 | Reconciliation zero-mismatch on DS-L after a batch run | **MET** (two evaluation dates) | Steps 40, 43 |
| 4 | Thresholds read from MEMBER_TIER (no hard-coded values) | **MET** | T-SCH-05 K3/K5; synthetic values exist only in the TEST_ONLY fixture and the runners' parameters |

**Status: `VERIFIED`.** Not `PASSED` (Owner decision). Open, outside this WO: D-008 threshold **values** (business configuration); the daily scheduler (integration, DEP-19); timings of Q-UC05-B/C, the batch and U0/U1 (WO-P3-P3-03, R-27).

## 14. Owner acceptance (2026-11-10)

The Project Owner conditionally approved this WO in the Owner Directive "Accept Loyalty & Implement UC06 Revenue Correctness" (Claude Code session of 2026-11-10) §2: set `PASSED` if the evidence remains consistent. The check below is read-only. No dataset was regenerated and no test was repeated for the acceptance itself (the UC05 regression of the same session, [`UC06-RUN`](WO-P3-P4-01_UC06_INDEX_EXPERIMENTS.md#13-execution-record), is separate evidence).

| Item the directive asks to verify | Result | Evidence |
|---|---|---|
| Every mandatory acceptance criterion (§7, 1–4) | MET (4 of 4) | §13.4; run log `UC05LOY-RUN_RESULT: PASS`, 62 steps, FAIL 0 |
| Evidence of `UC05LOY-RUN__20261109-1636` | Present and complete (791 lines; every step listed in its summary is PASS) | [UC05LOY-RUN__20261109-1636.txt](../evidence/test-results/UC05LOY-RUN__20261109-1636.txt) and the files of the same timestamp |
| Scripts unchanged since the run | 33 of 33 SHA-256 values in the run log equal the files in the working copy on 2026-11-10 | Run log lines 5–37 |
| Functional and concurrency results | T-F05L 10/10; T-F05S 47/47; T-F05-U0 9/9; T-CONC-04F A/B/C 6/6 each (0 downgrades while spending only grew, 0 deadlocks); T-CONC-01/02/06 regression PASS | Steps 21–27 |
| Correct tier upgrades and downgrades | Upgrades at the exact boundaries (L01, L03); downgrade without a payment when a month leaves the window (L04, L05b); DS-L: 29,521 upgrades then 668 downgrades and 0 upgrades, each equal to the INVOICE-based oracle (T-REC-04, 0 wrong tiers) | Steps 26, 39–43 |
| Batch idempotency and rollback | Second run for the same date writes nothing (L02; DS-L steps 41, 44; T-CONC-04F C6); failure in one chunk keeps earlier chunks, leaves later ones unchanged and the re-run equals the oracle (L09) | Steps 26, 41, 44 |
| No unauthorized change to shared modules | The batch writes only `MEMBER.Tier_ID`; the lookup is read-only; create, settle, cancel and the month function unchanged (definition hashes); no index, trigger, principal or permission | T-SCH-05 K1–K7 (steps 20, 28) |
| No change to the validated P1/P2 datasets | Instance fingerprint before = after; `FitLife_P3_P2` checksum = run C before and after; DS-L copy checksum = run C before and after | Steps 1–2, 32, 45–47 |

Not part of the acceptance and still open: T-F06-08 and task 4 (out of scope while D-001 is `PROPOSED`); task 3 (D-009 (b) not approved); D-008 threshold **values**; the scheduler (DEP-19); all timings (WO-P3-P3-03, R-27).

**Status: `PASSED` (2026-11-10, Project Owner).** Implementation and test artifacts are kept unchanged.

