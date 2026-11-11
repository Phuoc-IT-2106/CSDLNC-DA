# BM-1 environment baseline and session recovery - 2026-11-11

| Field | Verified result |
|---|---|
| Active WO / final status | WO-P3-P0-02 / **BLOCKED**, not VERIFIED or PASSED |
| Scope / mode | Recorded Owner approval 2026-11-10, WO approval record and amended section 2c: bounded BUILD_AUTHORIZED + VERIFY_ONLY. This recovery adds no authority |
| Working copy | `C:\Users\DELL\source\repos\CSDLNC-DA`; branch `p3/wo-p3-p1-01`; HEAD `792a85e`. Archive `C:\CSDLNC- DA` unchanged |
| BM-1 | **`localhost\MSSQLSERVER01`**, service and InstanceName `MSSQLSERVER01`; same local machine verified |
| Engine | SQL Server 2025 RTM 17.0.1000.7, Standard Developer (64-bit), EngineEdition 2; collation SQL_Latin1_General_CP1_CI_AS |
| Machine | Intel i5-1135G7, 4 cores / 8 logical CPUs; 7,915 MB visible RAM; Windows 10 Pro build 19044; physical disk reports SSD / RAID, 238 GB (NVMe was a historical description, not re-proven by the current bus report) |
| Power | Base plan Balanced `381b4222-f694-41f0-9685-ff5bb260df2e`; original actual/effective overlay `00000000-0000-0000-0000-000000000000`. AC regained during recovery; no slider or policy change applied because memory gate never passed |
| BM-1 configuration at recovery | min/max server memory 1,024 / 2,048 MB already applied 2026-11-10; MAXDOP 8, cost threshold 5, ad hoc optimization 0; show advanced options 0 |
| Original and final BM-1 memory | Configured min **0** (engine reports 16 MB in use), max **2,147,483,647** MB, advanced options 0. Restored after failed preflight; exact original values take precedence over proposal shorthand '16 MB' |
| Protected default instance | `localhost` / `MSSQLSERVER`, 8 user databases; original min configured 0 / in use 16, max 2,147,483,647; never reconfigured, stopped, rebuilt or cache-cleared |
| BM-1 databases | `FitLife_P3_Probe` absent (created, tested and dropped 2026-11-10); only user database `FitLife_P3_P2` ONLINE with `P3_Disposable = WO-P3-P2-01...`; created 2026-11-10 15:31:26 local |
| Database B0 | V001 + V002 + V003, compatibility 160, SIMPLE, RCSI OFF, snapshot OFF, auto stats create/update ON, async OFF; Query Store READ_WRITE/AUTO; adaptive database settings retained (A7) |
| Files | Data 72 MB, log 8 MB, under named-instance DATA directory; exact paths in [metadata](../evidence/test-results/ENV-P0__20261111-015411_RecoveryMetadata.txt) |
| Dataset / run | DS-L, S001 v1.0, seed 20261108, 2025 local calendar year; run `20261110-0831_BM1`; operator Project Owner, recovery runner Codex; Windows authentication, PowerShell 5.1.19041.3031 |
| Measurement controls | Warm-cache only, no cache clear; E6 would use two series >=10 minutes apart, warm-up + 15 interleaved samples; timing by validated DMV deltas (M3); no series executed |
| Last completed step | V003 + schema/integrity/fingerprint validation **14/14 PASS**; A6 harness diff and PowerShell parse PASS; bounded readiness wait ended at failed E2 |

## 1. Authorization reconciliation

The latest approval is recorded in [WO-P3-P0-02](../work-orders/WO-P3-P0-02_ENVIRONMENT_BASELINE.md), dated 2026-11-10 and attributed to Owner Directive "Execute BM-1 Readiness and Final R-27 Validation". Earlier proposal rows and the last pre-interruption session entry are historical, not evidence that the approved execution never started. No separate original chat transcript is stored in the repository; authorization here relies on the explicit dated WO approval record, allowed by master prompt A1.

| Approval | Recovered authorization | Actual action |
|---|---|---|
| A1 | Amended P0-02 on BM-1 | Resumed only this WO |
| A2 | Disposable Probe and P2 on BM-1 | Existing valid build/probe results preserved; neither recreated |
| A3 | Conditional 1,024/2,048 MB on BM-1 | Already applied; not reapplied. Original configured values recovered, current pressure checked; restored on cleanup |
| A4 | Temporary Best performance mode; restore afterwards | Authorized but not applied: E2 prevented measurement; original overlay retained |
| A5 | Owner controls applications, AC, 10 clean minutes | Owner reported ready, then agreed to reconnect AC/free RAM; no application killed by agent. Bounded 12-minute wait with process keep-awake, subsequently released |
| A6 | Explicit Server and portable paths in E6 harness/helper | Completed; all four sqlcmd sites and both diagnostic calls route to selected server; original diagnostic preserved, new target adapter |
| A7 | E5=current database configuration; M3=validated method; V003 in B0 | Recorded; V003 missing at recovery, applied only on marked BM-1 P2. No formal P2-02 approval inferred |

## 2. Recovery matrix

| Task | Before recovery / evidence | Recovery action | Final status / remaining action |
|---|---|---|---|
| Identify approval, branch and true stopping point | WO IN_PROGRESS; session/readiness documents stale | Reconciled approval with timestamps, raw logs and live state | DONE_VERIFIED |
| BM-1 identity and configuration | Preflight 20261110-083038 and Memory 083049 completed | Read current identity, original/current config, protected default inventory | DONE_VERIFIED |
| Feature probes and cleanup | Probes 20261110-083101 has terminal PASS | Inspected individual results and verified probe database absent; no rerun | DONE_VERIFIED |
| DS-L build | P2-RUN 20261110-0831_BM1 terminal PASS, checksum = C | Preserved build and all raw evidence | DONE_VERIFIED |
| V003/B0 validation | V003 absent; Validate had not run | Applied trusted CHECK and completed 14 checks | DONE_VERIFIED |
| Canonical fingerprint | Earlier BM-1 checksum identical to C | Rehashed all tables after V003; default P2 read-only hash also = C | DONE_VERIFIED |
| A6 target routing | No Server parameter in interrupted harness/helper | Portable parameters, target diagnostic adapter, reviewed diff and parse checks | DONE_VERIFIED |
| Controlled host E1-E3 / A4-A5 | Interrupted before controlled E6; host initially battery/low RAM | Bounded wait; AC restored, final power-event count 0; RAM 722-1144 MB | BLOCKED: E2 requires >=2,048 MB; A4 deferred |
| E6 campaign on BM-1 | NOT_STARTED; only old default-instance FAIL runs exist | No timed series started; exact preconditions retained in controlled-session log | BLOCKED / NOT_RUN; no campaign consumed |
| R-27 closure | OPEN | No passing E6, therefore remains OPEN | BLOCKED |
| Environment report and handoff | ENVIRONMENT_P0 missing; execution record blank | This report, minimal status reconciliation and session append | DONE_VERIFIED; WO acceptance criteria 5-6 verified, criterion 7 not met |
| Memory/power cleanup | BM-1 floor/cap still active from interrupted session | Guarded restore to actual original 0/unlimited; power unchanged; keep-awake released | DONE_VERIFIED |
| Formal P2-02, indexes, partition, UI/integration | Not authorized | No execution | NOT_STARTED (P2-02 remains BLOCKED) |

No existing artifact was accepted merely because its file existed. Terminal markers, individual outputs and live database state were checked. Missing V003 was classified NOT_STARTED before resumption; no interrupted migration was blindly replayed.

## 3. Feature results (existing raw run, verified without replay)

| Probe | Actual result |
|---|---|
| 3a filtered index | SUPPORTED; actual plan used ix_probe_filtered |
| 3b partition function/scheme | SUPPORTED; 3 partitions, one row each |
| 3c indexed view | Creation SUPPORTED; no automatic matching observed on this tested query; NOEXPAND used ix_v_probe. This is the observed plan result, not a proof covering every possible query |
| 3d ONLINE=ON | REFUSED, **Msg 1712**, edition restriction; error preserved |
| 3e GENERATE_SERIES | SUPPORTED at compatibility 160, 10,000 rows |
| 3f DML | With sqlcmd -I succeeds; without -I refused, **Msg 1934 QUOTED_IDENTIFIER** |
| Task 4 SqlClient | Windows-auth connection reached MSSQLSERVER01 / FitLife_P3_Probe, QI=1, 10,000 rows |
| Optional 3g from previous session | Nonclustered columnstore supported, batch execution observed. Already executed as INFO; not re-executed or used as an optimization result |
| Cleanup | Probe dropped, database lists before/after identical; still absent at recovery |

Evidence: [Probes](../evidence/test-results/ENV-P0__20261110-083101_Probes.txt). A refused capability is a recorded feature result, not a missing probe. R-09 is characterized; D-002 approval unchanged.

## 4. Dataset and schema verification

[Validate](../evidence/test-results/ENV-P0__20261111-014844_Validate.txt) finished **14/14 PASS**. Rows: INVOICE 324,000; service items 65,177; product items 712,789; monthly spending 169,040; fixtures MEMBER/BRANCH/EMPLOYEE/SERVICE_PLAN/PRODUCT = 30,000/12/120/30/200. Nine PKs, eight FKs, fourteen CHECKs, four DEFAULTs; all FK/CHECK constraints enabled and trusted. Nine tables, clustered PK indexes only; zero non-PK indexes, views, triggers, partition objects, routines or compressed partitions. Header/line, payment-state, spending and point-rule mismatches all zero.

All nine canonical table hashes and dataset checksum match DS-L run C. Full hash:

`26ABB2776BD71C1347D2478D880B926FF35D8B6E7BA8F583D76E56D4DD82CA1F`

Catalog digest after V003: `A3291B5E862A39E1613DB29A9BB830F4504947EA8448678FB83D3F1C2EDF8A71` (105 items). [Canonical checksum output](../evidence/test-results/ENV-P0__20261111-014844_Validate__checksums.txt). Default-instance P2 checksum remains C. No functional routine or migration source was changed; V003 was only executed on the approved target.

**Existing manifest metadata correction (raw file preserved):** `DATASET-MANIFEST__DS-L__20261110-0831_BM1.md` says "local default instance" and its runner log starts "local default (localhost\MSSQLSERVER01)". These labels are inaccurate: that same raw log records -S localhost\MSSQLSERVER01, shared-memory local transport and InstanceName MSSQLSERVER01. Live identity independently confirms BM-1. Historical timings remain DIAGNOSTIC_ONLY and are not baseline measurements.

## 5. E1-E6 and decisive R-27 disposition

| Check | Final recovered result |
|---|---|
| E1 power | AC Online at final wait; last ten-minute event count 0; no E1 measurement claim because no series ran |
| E2 memory | **NOT MET**: 722-1144 MB during bounded wait, final 1057 MB; threshold >=2,048 MB. BM-1 low flag/semaphore final MSSQLSERVER01|0|793 |
| E3 resource waits/load | No timed series, therefore NOT_RUN for per-series waits/spills/forced-grant deltas. Historical cumulative counters cannot prove E3 PASS |
| E4 configuration | Captured in metadata, snapshot and Validate; memory setup and cleanup evidence retained |
| E5 repeatability settings | Current database-scoped values retained, equal to default reference (V10 PASS), Query Store READ_WRITE/AUTO; no configuration switch |
| E6 | **NOT_RUN on BM-1**. No medians, IQR, reads or plan-stability measurement to report. This is an environmental blocker, not E6 FAIL |

Raw standing-condition record: [ENV-P0__20261111-015319_ControlledSession.txt](../evidence/test-results/ENV-P0__20261111-015319_ControlledSession.txt). Original criteria remain cross-series median deviation <=10%, IQR/median <=20%, identical logical reads, stable plans, no disqualifying waits and valid AC/memory throughout. The older 2026-11-08 E6 runs on MSSQLSERVER remain FAIL/DIAGNOSTIC_ONLY; they are not BM-1 results. No passing E6 means **R-27 cannot close**, P0-02 cannot be VERIFIED/PASSED, and P2-02 cannot begin.

## 6. Progress, safety and continuation boundary

P0/P1/P2-01 PASSED; P0-02 BLOCKED; P2-02 BLOCKED; P3-00/01/02 PASSED; P3-03 Part C PASSED / Part P pending; P4-01 Part F PASSED / Part X blocked; P4-02 and P5-P8 NOT_STARTED.

Remaining obligations: formal P2-02 baseline and reproducibility; P3-03 Part P (U0/U1, creation cost, T-PERF-01/02/08 and blocking duration); P4-01 Part X indexes; P4-02 summary/indexed-view experiment; P5 partition feasibility. None executed here.

Memory rollback: [ENV-P0__20261111-020559_MemoryRollback.txt](../evidence/test-results/ENV-P0__20261111-020559_MemoryRollback.txt); applied on local MSSQLSERVER01 only after checking its identity, current values and pressure. Power overlay never changed, keep-awake released. Marked BM-1 DS-L database kept; probe absent. Default instance and its eight user databases protected; only SELECTs issued there. Archive untouched; no software installed, app closed, cache cleared, commit, push, PR, merge or destructive Git command.

Initial Git state: **339 untracked paths** with -uall (6 collapsed directory entries in default short status), no tracked diff; approximate earlier count 330 is historical. All pre-existing changes retained. New/modified code: `r27_e6_probe.ps1`, `r27_e6_wait_and_run.ps1`, new `r27_diag_target.ps1`; original `r27_diag.ps1` preserved. [A6 diff](../evidence/test-results/R-27-HARNESS-DIFF__20261111-015043_BM1.txt) proves unchanged frozen Criteria/Method/Q/QH/QPH/Kq blocks and explicit routing; all three scripts parsed successfully. Evidence outputs are appended with unique names; raw prior evidence is immutable.

**Completion boundary:** all safe executable approved preparation is complete; measurement remains blocked by a concrete failed precondition. P0-02 is **BLOCKED**, not finished at its mandatory E6 gate. The single authorized BM-1 campaign remains unused. Owner can prepare enough free physical RAM and stable AC, then resume the same bounded readiness workflow under A1-A7 (memory preflight must be rerun because settings were restored). A different machine/configuration or a statistical-design change requires a new explicit Owner decision before execution. After a passing E6 only: verify P0-02, Owner acceptance/PASSED, then separate **WO-P3-P2-02 authorization**. Do not automatically run it.

Sources: [recovery metadata](../evidence/test-results/ENV-P0__20261111-015411_RecoveryMetadata.txt), [snapshot](../evidence/test-results/ENV-P0__20261111-015114_RecoverySnapshot.txt), [memory change](../evidence/test-results/ENV-P0__20261110-083049_Memory.txt), [old build](../evidence/test-results/P2-RUN__DS-L__20261110-0831_BM1.txt), [WO approval](../work-orders/WO-P3-P0-02_ENVIRONMENT_BASELINE.md).
