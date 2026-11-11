# WO-P3-P4-01 — UC06 Report Routines and Index Experiments

| Field | Value |
|---|---|
| Status | **Part F: PASSED** (2026-11-10, Project Owner; conditional acceptance re-checked read-only, [§14](#14-owner-acceptance-of-part-f-2026-11-10)); VERIFIED since the recovered completion in §13. **Whole WO: IN_PROGRESS**, not VERIFIED or PASSED. **Part X: PROPOSED, not approved; execution BLOCKED** by WO-P3-P2-02 / R-27 and its own approval. Original performance obligations remain mandatory |
| Phase | P4 — Revenue Reporting and Index Optimization |
| Mode | BUILD_AUTHORIZED (report routines, index scripts) + VERIFY_ONLY (experiments) |
| Approver | Project Owner |
| Approval record | **Part F only: APPROVED 2026-11-10, BUILD_AUTHORIZED**, by the Owner Directive "Accept Loyalty & Implement UC06 Revenue Correctness" (Claude Code session of 2026-11-10) §3, §5, as a controlled execution-order exception (functional P4 work before GATE-P3 and GATE-P2). Precondition D-010: APPROVED (provisional, T2) 2026-11-10; D-023 ✔. Part X: no approval. No commit, push or merge authorized |
| Target database | **Part F:** `FitLife_P3_UC05` (fixtures; rebuilt from scripts; disposable marker verified) and the existing DS-L copy `FitLife_P3_UC05L` (report routines deployed, tables read only; dataset checksum = run C before and after). Both are the disposable Person 3 databases already authorized on 2026-11-09; no new database. `FitLife_P3_P1`, `FitLife_P3_P2` and every other database unchanged. **Part X:** isolated benchmark databases per D-025 (DS-M, DS-L), restored to B0 between candidates (to be named when Part X is approved) |
| Revision | 2026-11-08 (Owner Directive "Reprioritize Person 3 Implementation" (2026-11-08, D-027)): core reports RPT-01…04 first and not blocked by D-001; T-REG-03 and IX-11 (shared MEMBER) moved to P6; IX-08/IX-09 are on P3-owned tables; priority rules of [07 §11](../07_UC06_REVENUE_PLAN.md#11-p4-priority-and-independence-2026-11-08). 2026-11-09 (Owner Directive "Urgent Unblock & Core Implementation" §3, §10): the report routines and their correctness tests (T-F06-01…05 against the oracle) may be prepared independently of performance tuning and of R-27; **index adoption and any improvement claim stay blocked** by WO-P3-P2-02 / R-27. D-010 must be approved before the affected revenue semantics are accepted; it was not approved by the directive. 2026-11-10 (Owner Directive "Accept Loyalty & Implement UC06 Revenue Correctness"): D-010 approved (provisional, T2); the WO is split into Part F and Part X by the controlled scope amendment of §2a; Part F approved and executed; every original acceptance criterion is kept |

## 1. Objective

Implement the revenue report routines. Evaluate the candidate indexes one at a time and adopt only those that meet [08 §6](../08_INDEX_AND_QUERY_PLAN.md#6-adoption-and-rejection-criteria).

## 2. Preconditions

GATE-P2 passed; D-010 APPROVED (in P2) and D-023 ✔. D-001 is needed only for the candidate reports RPT-05…07; the core reports RPT-01…04 (branch, monthly, system-wide revenue) proceed without it. No other member's approval or query is required (D-027). The write-overhead step (T-PERF-06) needs WO-P3-P3-01 PASSED; if it is not yet available, that step is deferred and recorded.

## 2a. Controlled scope amendment (2026-11-10)

Authority: Owner Directive "Accept Loyalty & Implement UC06 Revenue Correctness" §3 and §5 ("If the Work Order combines reporting correctness and performance optimization, record a controlled scope amendment"). This WO combines both, so it is split into two parts. **No task and no acceptance criterion is removed or weakened**; each one is assigned to exactly one part.

| Part | Tasks (§4) | Acceptance criteria (§7) | Status on 2026-11-10 |
|---|---|---|---|
| **F — functional report correctness** | 1 (report routines RPT-01…RPT-04, as stored procedures in `db/procedures/`); 2 (T-F06-01…T-F06-05 against the oracle, extended by T-F06-09…T-F06-13 and T-REC-05, see [11 §2.4](../11_TEST_AND_QA_PLAN.md)); 7 (documentation) | F1: T-F06-01…05 and the added functional tests pass on fixtures and on DS-L (the T-F06 part of criterion 1). F2: UC05 regression passes with the report routines deployed. F3: the routines are read-only, add no index, table, view or summary, and leave the approved UC05 routines and the table catalog unchanged | **VERIFIED** (2026-11-10; §13); executed under BUILD_AUTHORIZED |
| **X — index experiments and performance evidence** | 3 (candidate protocol), 4 (Q-UC06-A0 vs Q-UC06-A), 5 (T-REG-01; T-REG-03 `NOT_RUN` until P6), 6 (`design/INDEX_DECISIONS.md`); `db/queries/optimized/`, `db/indexes/` | The T-REG-01 part of criterion 1; criteria 2, 3, 4 | **PROPOSED**; needs its own approval, GATE-P2 (WO-P3-P2-02 `PASSED`: frozen baseline queries and B0), R-27 closed, and the creation-cost baseline of WO-P3-P3-03 before any adoption |

Conditions of the exception (directive §3, §9):

1. WO-P3-P3-03 stays pending (GATE-P3 is not closed) and R-27 stays OPEN.
2. Every performance obligation stays mandatory: WO-P3-P2-02 formal baseline, WO-P3-P3-03 UC05 comparisons, Part X of this WO, WO-P3-P4-02, WO-P3-P5-01.
3. No measured-optimisation claim is made by Part F. Plans, logical reads, row counts and the index inventory recorded by Part F are `DIAGNOSTIC_ONLY` reference material, not a baseline.
4. No index, partition, summary table or indexed view is created.
5. Candidate reports RPT-05…RPT-07 stay out of scope (D-001 `PROPOSED`).
6. This WO cannot become `PASSED` before Part X is approved, executed and verified. Part F may be reported `VERIFIED` on its own.

## 3. Inputs

[07](../07_UC06_REVENUE_PLAN.md); [08](../08_INDEX_AND_QUERY_PLAN.md); DL-05, DL-06 (B0 evidence). The regression registry of other members' queries arrives with DL-02 at P6 (DEP-09).

## 4. Tasks

1. Implement the report routines (one per query shape) for RPT-01…RPT-04 first (+ RPT-05/06 only if D-001 assigns them); optimised query files go into `db/queries/optimized/`.
2. Functional tests T-F06-01…T-F06-07 (in scope) against the oracle (PAID invoices only, D-010).
3. For each candidate derived from the actual predicates of the frozen queries — IX-01, IX-02, IX-03 (UC06 use), IX-04, IX-05, IX-06 (if the app needs it), IX-08/IX-09 (if RPT-05/06 are in scope), IX-10 (optional) — run the protocol of [08 §5](../08_INDEX_AND_QUERY_PLAN.md#5-evaluation-protocol-per-candidate), including write overhead. IX-11 is on the shared MEMBER table and is proposed to its owner at P6, not created here.
4. Run Q-UC06-A0 vs Q-UC06-A with IX-01 (sargability demonstration, T-PERF-05).
5. Run T-REG-01 for each candidate. T-REG-03 (other members' queries) is `NOT_RUN` here by design and runs in WO-P3-P6-01.
6. Write the index decision record `docs/phase2/person3/design/INDEX_DECISIONS.md` (ADOPTED/REJECTED + criteria table + RUN_IDs) (it seeds the shared index registry of DL-02 at P6). An index that is redundant or harmful is rejected, even if keeping it would add a technique (08 §1).
7. Update [01](../01_REQUIREMENTS_TRACEABILITY.md), [16](../16_READINESS_REPORT.md) and [SESSION_LOG.md](../SESSION_LOG.md).

## 5. Out of scope

Summary tables / indexed views (WO-P3-P4-02); partitioning (WO-P3-P5-01); creating any index in the canonical shared database. `ADOPTED` means *recommended for promotion*; promotion needs the separately approved promotion step (D-025 conditions 6–7).

## 6. Deliverables and locations

DL-10: `db/queries/optimized/`, `db/indexes/`, `docs/phase2/person3/design/INDEX_DECISIONS.md`; evidence in `evidence/`.

## 7. Acceptance criteria

1. T-F06-xx (in scope) and T-REG-01 pass; T-REG-03 recorded as `NOT_RUN` (P6).
2. Every evaluated candidate has a decision with evidence links; no index is adopted without passing every criterion of [08 §6](../08_INDEX_AND_QUERY_PLAN.md#6-adoption-and-rejection-criteria).
3. T-PERF-03…T-PERF-06 evidence complete (or T-PERF-06 explicitly deferred with its reason).
4. Every screenshot has a matching `.sqlplan`.

## 8. Verification

Hash comparison for every configuration; re-run of the adopted configuration from a clean B0 restore.

## 9. Evidence

Plans, screenshots, CSVs and the decision record.

## 10. Dependencies and risks

R-08, R-11, R-12.

## 11. Approval requirements

WO approval with the target databases named; separate authorization for commits. Indexes recommended for promotion are reviewed by the team at P6.

## 12. Exit and next step

Part F is complete and **PASSED** (Owner, 2026-11-10, §14). Stop here. Whole WO remains IN_PROGRESS until Part X is authorized and verified; WO-P3-P4-02 is the roadmap successor and is not ready. Next separately authorized work recommended: WO-P3-P3-03, initially limited to outstanding correctness/concurrency checks; its performance criteria retain all prerequisites. No next WO starts through recovery.

## 13. Execution record

### 13.1 Recovered state and authority (2026-11-10)

Active scope: **Part F**, BUILD_AUTHORIZED under the recorded Owner Directive of 2026-11-10 (§2a), resumed by "SESSION RECOVERY & RESUME — FITLIFE HUB PERSON 3". P3-02 was already **PASSED** by the Owner ([§14](WO-P3-P3-02_LOYALTY_AND_TIER.md#14-owner-acceptance-2026-11-10)); D-010 was already APPROVED (provisional, T2). No new approval is inferred.

The interruption occurred after the complete `UC06-RUN__20261110-0206` (78 steps, 0 failures), D-010 and P3-02 acceptance records, this scope amendment and updates to 07/11, but before the execution record and aggregate handoff. No production repair or redeployment was needed.

| Task / Acceptance Criterion | Existing evidence | Status at recovery | Required action / disposition |
|---|---|---|---|
| P3-02 acceptance; D-010 semantics | P3-02 §14; D-010 nine approved rules | DONE_VERIFIED | Preserve recorded approvals |
| Task 1: five report procedures, two functions | Source and full 0206 deployment/test log | DONE_VERIFIED | Live definitions confirmed; 7/7 report objects match in each target |
| F1: correct revenue and reconciliation | 0206: T-F06 16/16; T-REC-05 fixtures, regression and DS-L | DONE_VERIFIED | Reuse validated evidence; current UC05 reconciliation also PASS |
| F2: UC05 regression with reports | 0206: creation 43/43, settlement 47/47, U0 9/9, loyalty 10/10; concurrency/integrity | DONE_VERIFIED | Source hashes validated; current integrity/loyalty checked |
| F3: read-only reports; unchanged catalog/UC05 | 0206: T-SCH-06, catalog digests, checksums/fingerprints | DONE_VERIFIED | Repeat catalog/scope/preservation checks; PASS |
| Live deployment; interrupted transactions | Historical evidence existed; no fresh inspection yet | DONE_UNVERIFIED | Now DONE_VERIFIED: 16 UC05 / 11 UC05L modules match files; catalog matches 0206; no open user transaction/active user request |
| Task 7: documentation and evidence handoff | §13 empty; readiness/indexes stale | PARTIAL | Completed in recovery; affected records and links audited |
| Part X: indexes and performance criteria | R-27 OPEN; P2-02 BLOCKED; Part X not approved | BLOCKED | No execution; all obligations retained |

### 13.2 Recovered implementation (unchanged during recovery)

`db/procedures/usp_P3_RevenueReports.sql` (SHA-256 `1B262CA819087C632AE73939B5EF3CCDBBC8FA494AD7C5E272D67E6A4410D128`) defines `usp_P3_RptBranchRevenue`, `usp_P3_RptSystemRevenue`, `usp_P3_RptSystemRevenueByBranch`, `usp_P3_RptBranchRevenueByPeriod`, `usp_P3_RptSystemRevenueByPeriod`, `tvf_P3_ReportPeriodUtc`, `tvf_P3_ReportPeriodStart`. Interfaces: [07 §12](../07_UC06_REVENUE_PLAN.md#12-implemented-report-routines-wo-p3-p4-01-part-f-2026-11-10).

Existing supporting artifacts: R001 fixture; T-F06 revenue tests; T-REC revenue reconciliation; T-SCH-06 scope check; catalog_digest; V-UC06R integrity; run_uc06_revenue runner; capture_uc06_reference. No `db/` or `tests/` file changed in recovery; no database creation/drop/rebuild/deployment/data mutation.

### 13.3 Acceptance evidence

| Criterion | Actual result | Evidence |
|---|---|---|
| F1 — PAID only, FinalAmount, PaidAt, branch/system totals, local day/month/quarter/year, UTC boundaries, empty periods, no duplicate invoice, create/settle/report path | PASS: 16 literal-expectation cases; independent time-zone oracle. T-REC-05: R001 9 checks, regression 10, DS-L 10; line and spending totals agree | [Full run](../evidence/test-results/UC06-RUN__20261110-0206.txt); [functional cases](../evidence/test-results/T-F06__20261110-0206.txt); [DS-L](../evidence/test-results/T-REC-05__20261110-0206_DS-L.txt) |
| F2 — UC05 preserved with reports deployed | PASS: creation 43; settlement/cancellation 47; U0 9; loyalty 10; T-CONC-01/02/04F/06 and integrity checks | Full run stages A/C; matching `20261110-0206` T-CONC files; [prior loyalty](../evidence/test-results/UC05LOY-RUN__20261109-1636.txt) |
| F3 — read-only scope, catalog and approved routines preserved | PASS: T-SCH-06 both targets; no non-PK index/view/trigger/partition; before/after catalog and data match; P2 checksum and other-database fingerprint unchanged | Full run C19/C30/C31, D1…D9, Z1/Z2; [recovery](../evidence/test-results/RECOVERY-UC06__20261110-043737.txt) |
| Task 7 — documentation | Completed; Part F alone VERIFIED, approvals/evidence retained | Traceability, design, deliverable/evidence indexes, roadmap, readiness and session log |

DS-L: 324,000 invoices; 65,177 service items; 712,789 product items; 169,040 monthly-spending rows. Four-table checksum remains `26ABB2776BD71C1347D2478D880B926FF35D8B6E7BA8F583D76E56D4DD82CA1F`.

### 13.4 Recovery verification actually executed

[Recovery](../evidence/test-results/RECOVERY-UC06__20261110-043737.txt): **26 checks, 25 PASS, one timeout** at the 180-second client limit (DS-L loyalty reconciliation; no incorrect result reported). [Targeted retry](../evidence/test-results/RECOVERY-UC06-RECHECK__20261110-045109.txt): same unmodified script/assertions with a 600-second client allowance, **T-REC-01/02/04: 3 checks, 0 failures, PASS**. The timeout stays recorded; no benchmark conclusion or R-27 closure follows.

39/39 UC06 and 33/33 loyalty source hashes match historical runs. Live comparison removes only leading batch comments, SQL Server's stored CREATE normalization, line endings and outer whitespace; all remaining definition text matches source. SQL Server 17.0.1000.7 Standard Developer, EngineEdition 2; compatibility 160; four P3 DBs ONLINE. No open user transaction/active user request at initial/final checks. No incomplete deployment observed; catalogs/constraints match the completed run.

Read-only reruns: T-SCH-06 both targets (5 checks each); V-UC06R (10); T-REC-05 on preserved UC05 data (10); T-REC-01/02/04 on UC05 (last batch date 2026-11-10) and UC05L (2026-01-15); catalog digests, data checksums and fingerprints. Before/after datasets and catalogs identical. P2 read only; P1 and other databases unchanged by fingerprint.

Reused without rebuilding: 16 literal fixture cases, full UC05 mutation/concurrency regression, DS-L revenue reconciliation and 8 actual plans from 0206. Valid source/deployed definitions and unchanged DS-L data justify reuse. Plans/logical reads remain **DIAGNOSTIC_ONLY**, not B0 or a speedup claim.

### 13.5 Retained failures and open scope

- Original `UC06-RUN__20261110-0153`: 2 FAIL in S2 metadata inspection. Existing test header records an engine access violation at C30 and corrupted metadata at D4 from `sys.dm_sql_referenced_entities`. Prior session changed only the inspector to static catalog/text checks, then completed 0206. Failed evidence retained; recovery did not call that DMV.
- Recovery scratch attempts `RECOVERY-UC06__20261110-043548` / `043655` failed on sqlcmd output-option conflict / stored CREATE normalization. Harness corrected; no production change. Logs retained. The later DS-L timeout was resolved by the targeted retry above.
- NOT_RUN here: Part X T-PERF-03…06, index-configuration T-REG-01 (not authorized; baseline/R-27 prerequisites missing); T-REG-03 and real hooks (P6); full report-vs-settlement T-CONC-04 (P3-03); RPT-05…07 (D-001); UI/integration. No Part F functional test remains outstanding.
- D-008 business thresholds remain open. Grouped empty-bucket behavior is the explicit assumption in 07 §2, not a newly approved rule. Provisional T2 decisions still need team reconciliation at P6.

### 13.6 Completion boundary

**Part F VERIFIED; whole WO IN_PROGRESS; Part X PROPOSED / execution BLOCKED.** Owner review/acceptance of the functional scope is next; recovery does not set PASSED. GATE-P2/P3/P4 remain open. R-27 OPEN. Branch `p3/wo-p3-p1-01`, HEAD `792a85e`; prior untracked work preserved, nothing committed/pushed/merged/reset. No next WO started.


## 14. Owner acceptance of Part F (2026-11-10)

The Project Owner conditionally approved the UC06 functional scope in the Owner Directive "Accept UC06 Functional Results & Execute Integrated Correctness Verification" (Claude Code session of 2026-11-10) §2: record Part F `PASSED` if the mandatory functional criteria remain satisfied, keep the whole WO `IN_PROGRESS`, do not rerun completed tests unnecessarily. The check below is **read-only**: no functional test was repeated, nothing was deployed, rebuilt or changed. It was executed **before** WO-P3-P3-03 rebuilt `FitLife_P3_UC05`.

Evidence: [ACCEPT-P4-01F__20261110-070518](../evidence/test-results/ACCEPT-P4-01F__20261110-070518.txt) — **27 checks, 27 PASS** ([harness text](../evidence/test-results/ACCEPT-P4-01F__20261110-070518__harness.py.txt)).

| Item the directive asks to verify | Result | Checks |
|---|---|---|
| UC06 functional results 78/78 PASS | `UC06-RUN__20261110-0206`: 78 steps, 0 FAIL, `UC06-RUN_RESULT: PASS` | E1 |
| Revenue correctness; UTC/local-calendar boundaries | T-F06 16 cases, 0 FAIL (literal expectations incl. 16:59:59.999 / 17:00:00.000 UTC, month/quarter/year, empty periods) | E2 |
| Branch and company reconciliation | T-REC-05 fixtures 9/0 FAIL, regression 10/0, DS-L 10/0 (every branch × month vs independent `AT TIME ZONE` reference; company = Σ branches; line level; spending cross-check) | E3–E5 |
| Billing and Loyalty regression | T-F05 43/43; T-F05S 47/0 FAIL; T-F05L 10/0 FAIL; recovery 25 PASS + 1 client timeout resolved by the targeted retry (3 checks, 0 FAIL) | E6–E10 |
| SQL definition consistency | 39/39 (UC06 run) and 33/33 (loyalty run) recorded source hashes = current files; no file under `db/` or `tests/` modified after the accepted run; deployed module definitions = source (16 in `FitLife_P3_UC05`, 11 in `FitLife_P3_UC05L`, 7 report objects each) | S1, S2, D2 |
| Dataset integrity | `FitLife_P3_UC05L` and `FitLife_P3_P2` DS-L checksum = run C `26ABB277…CA1F`; catalog digests = the accepted run in both databases | X1, D3 |
| No unauthorized shared-module modification | T-SCH-06 PASS in both databases; RCSI/snapshot OFF (D-019 (a) unchanged); instance fingerprint unchanged; no open transaction | D4, I1–I3, Z1 |

**Part F: `PASSED` (2026-11-10, Project Owner, conditional acceptance verified).** Existing evidence is kept unchanged.

**Whole WO-P3-P4-01: `IN_PROGRESS`.** Part X is not passed, not approved and its execution stays BLOCKED. Remaining Part X obligations, all unchanged: tasks 3–6 (candidate index protocol IX-01…IX-10 with write overhead, Q-UC06-A0 vs Q-UC06-A sargability demonstration T-PERF-05, T-REG-01 per candidate, `design/INDEX_DECISIONS.md`); the T-REG-01 part of criterion 1; criteria 2, 3 (T-PERF-03…T-PERF-06) and 4 (screenshot ↔ `.sqlplan`). Prerequisites: own approval, GATE-P2 (WO-P3-P2-02 `PASSED`, frozen B0), R-27 closed, and the creation-cost baseline of WO-P3-P3-03 (criterion 5) before any adoption. T-REG-03 stays `NOT_RUN` until P6.
