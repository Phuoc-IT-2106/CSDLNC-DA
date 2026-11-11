# Person 3 — Evidence

**Contains evidence since WO-P3-P1-01 (2026-11-07):** `test-results/ENV-P1__…`, `T-SCH-01__…`, `T-SCH-02__…`, `T-REPRO-01__…`, `SEPARATION-P1__…`. **Since WO-P3-P2-01 (2026-11-08):** `GATE-P1-RECHECK__…`, `SEPARATION-P2__…`, and per dataset run `P2-RUN__<DATASET>__<YYYYMMDD-HHMM>_<label>.txt` (full run log), `CHECKSUMS__…` (T-REPRO-02 input) and `DATASET-MANIFEST__…md`. **Since the GATE-P2-01 acceptance (2026-11-08):** `GATE-P2-01-RECHECK__…` (independent read-only re-check) and `R-27-DIAG__…` (read-only environment diagnostic). **R-27 E6 runs (2026-11-08, diagnostic, not baselines):** `R-27-PROBE__…` (harness v1), `R-27-CALIB__…` (timing-instrument calibration), `R-27-HARNESS-DIFF__…` (before/after record of the harness correction), `R-27-CLOSE__<ts>…` (harness v2: summary, `__precheck`, `__checksum_before/after`, `__raw_S1/S2`, `__P1…P4.sqlplan`). The harness scripts are in `tests/db/diagnostics/`. **Since 2026-11-09 (Owner Directive "Urgent Unblock & Core Implementation"):** `R-27-DIAG__20261109-0800_e6-precheck.txt` (read-only precheck; the optional final E6 attempt was not performed, [14 R-27 §7](../14_RISK_REGISTER.md#7-disposition-2026-11-09-owner-directive-urgent-unblock--core-implementation)); `UC05-BASELINE__20261109-0806__fingerprint_before.txt` and `__p2_checksum_before.txt` (read-only session-start baseline); WO-P3-P3-00 run `UC05-RUN__20261109-0829.txt` (full log of build, P1 regression, T-SCH-03, V-UC05 and before/after checks), `T-F05-CREATE__20261109-0829.txt` (43 functional cases), `T-CONC-06__20261109-0829_A/_B/_C.txt` (three concurrency runs). **Since the Owner Directive "Close Invoice Creation and Prioritize Settlement" (2026-11-09):** WO-P3-P3-00 regression run `UC05-RUN__20261109-1446.txt` with `T-F05-CREATE__20261109-1446.txt` and `T-CONC-06__20261109-1446_A/_B/_C.txt`; WO-P3-P3-01 run `UC05S-RUN__20261109-1447.txt` (full log: build, P1 regression, T-SCH-03, T-SCH-04, V-UC05S after every stage, before/after checks), `T-F05S-SETTLE__20261109-1447.txt` (47 settlement and cancellation cases), `T-CONC-01__20261109-1447_A/_B/_C.txt` (same-invoice concurrency incl. settle-vs-cancel race), `T-CONC-02__20261109-1447_A/_B/_C.txt` (same-member concurrency), `T-CONC-06__20261109-1447_R.txt` (creation regression with settlement deployed). **Owner Directive "Finalize UC05 Settlement and Implement Loyalty" (2026-11-09):** WO-P3-P3-01 completion run `UC05U-RUN__20261109-1610.txt` with `T-F05-U0__20261109-1610.txt` and the full settlement regression `UC05S-RUN__20261109-1610.txt` (+ its T-F05S, T-CONC-01/02/06 files); WO-P3-P3-02 run `UC05LOY-RUN__20261109-1636.txt` with `T-F05L__…`, `T-CONC-04F__…_A/_B/_C`, `T0-QUC05BC__…` (task 0 B0: plans and logical reads, no timing; plans in `execution-plans/Q-UC05-B|C__B0__DS-L__P1|P2__20261109-1636.sqlplan`) and regression files of the same timestamp. Tier thresholds in these runs are TEST_ONLY synthetic values. Their timestamps and durations are context, not measurements. Nothing in this folder may be created by hand to look like a measurement. Every file comes from an actual run.

| Folder | Content | Naming |
|---|---|---|
| `execution-plans/` | Actual Execution Plans (`.sqlplan`) | `<QUERY_ID>__<CONFIG>__<DATASET>.sqlplan` |
| `screenshots/` | Plan and STATISTICS IO/TIME screenshots; application screenshots | `<QUERY_ID>__<CONFIG>__<DATASET>__plan.png`, `...__stats.png`, `APP__<FEATURE>__<YYYYMMDD>.png` |
| `benchmark-results/` | One folder per run: `manifest.md`, `results.csv`, `summary.md`, `raw/` | `<RUN_ID>/` with RUN_ID = `YYYYMMDD-HHMM_<DATASET>_<CONFIG>` |
| `test-results/` | Test run outputs | `<TEST_ID>__<YYYYMMDD-HHMM>.txt` |

Rules (from [10_SEED_AND_BENCHMARK_PLAN.md](../10_SEED_AND_BENCHMARK_PLAN.md) §4.8–§5):

1. Evidence is never edited after capture. A correction is a new run.
2. Every screenshot has a matching raw artifact.
3. No secrets (passwords, credentials) in any file or screenshot.
4. Report numbers cite their RUN_ID.

The `.gitkeep` files only keep the empty folders under version control once a repository exists.

## UC06 correctness and session recovery (2026-11-10)

| Evidence | Result and use |
|---|---|
| [UC06-RUN__20261110-0206](test-results/UC06-RUN__20261110-0206.txt) | **78/78 PASS**: 16 functional cases, UC05 regression, fixture/DS-L reconciliation, scope/preservation. Final Part F run |
| [UC06-RUN__20261110-0153](test-results/UC06-RUN__20261110-0153.txt) | **2 FAIL** in metadata inspection, retained; static catalog/text check replaced problematic DMV before successful 0206 run |
| [RECOVERY-UC06__20261110-043737](test-results/RECOVERY-UC06__20261110-043737.txt) | **25 PASS, one timeout**; source/live definitions, catalogs, integrity, reconciliation/preservation. Timeout resolved below |
| [RECOVERY-UC06-RECHECK__20261110-045109](test-results/RECOVERY-UC06-RECHECK__20261110-045109.txt) | **PASS**, unchanged DS-L loyalty reconciliation, 3 checks/0 failures; client allowance 600 instead of 180 seconds, same assertions |
| [Recovery 043548](test-results/RECOVERY-UC06__20261110-043548.txt), [043655](test-results/RECOVERY-UC06__20261110-043655.txt) | Retained scratch-inspection failures: sqlcmd output-option conflict / stored CREATE normalization; no production change |
| [Recovery harness](test-results/RECOVERY-UC06__20261110-043737__harness.py.txt), [retry harness](test-results/RECOVERY-UC06-RECHECK__20261110-045109__harness.py.txt) | Exact temporary verification scripts archived as text for audit |
| [UC06-REF__20261110-0206](test-results/UC06-REF__20261110-0206.txt) and 8 matching `.sqlplan` files | DIAGNOSTIC_ONLY definitions, reads, row counts and plans; **not B0 or benchmark evidence** |

Acceptance mapping: [WO §13](../work-orders/WO-P3-P4-01_UC06_INDEX_EXPERIMENTS.md#13-execution-record). All pre-existing evidence retained byte-for-byte. R-27 OPEN.

## P4-01 Part F acceptance and P3-03 Part C (2026-11-10)

| Evidence | Result and use |
|---|---|
| [ACCEPT-P4-01F__20261110-070518](test-results/ACCEPT-P4-01F__20261110-070518.txt) ([harness text](test-results/ACCEPT-P4-01F__20261110-070518__harness.py.txt)) | **27/27 PASS**, read-only: recorded evidence, source/deployed definitions, catalogs, DS-L checksums, fingerprint. Basis of the Owner acceptance of P4-01 Part F |
| [P3-03-RUN__20261110-0737](test-results/P3-03-RUN__20261110-0737.txt) and every file of timestamp `20261110-0737` | **100/100 PASS. Final WO-P3-P3-03 Part C evidence**: T-WF-01, T-CONC-01/02/04F ×3, T-CONC-04R, T-CONC-06, T-CONC-07, T-CONC-08, rollback suites, reconciliation, scope, preservation |
| [P3-03-RUN__20261110-0728](test-results/P3-03-RUN__20261110-0728.txt) and its files | **98/98 PASS**; complete earlier run without T-CONC-08 |
| [P3-03-RUN__20261110-0724](test-results/P3-03-RUN__20261110-0724.txt) and its files | **FAIL** (2 steps), retained: engine returned a corrupted column name from `sys.dm_sql_referenced_entities` in T-SCH-05 K3; stage C stopped; not a P3 defect (WO-P3-P3-03 §13.4) |

No timing in these files is a measurement (R-27 OPEN). All earlier evidence retained unchanged.

## P3-03 Part C acceptance and benchmark-environment inventory (2026-11-10)

| Evidence | Result and use |
|---|---|
| [ACCEPT-P3-03C__20261110-080412](test-results/ACCEPT-P3-03C__20261110-080412.txt) ([harness text](test-results/ACCEPT-P3-03C__20261110-080412__harness.py.txt)) | **13/13 PASS**, read-only; basis of the Owner acceptance of WO-P3-P3-03 Part C |
| [ENV-INVENTORY__20261110-080635](test-results/ENV-INVENTORY__20261110-080635.txt) | Read-only inventory of machine, power, processes, SQL Server instances and virtualisation; input to [BENCHMARK_ENVIRONMENT_READINESS](../design/BENCHMARK_ENVIRONMENT_READINESS.md). Context only, not a measurement |

## BM-1 interrupted-session recovery - 2026-11-11

Prior raw artifacts preserved: `ENV-P0__20261110-083038_Preflight`, `083049_Memory`, `083101_Probes`, `P2-RUN__DS-L__20261110-0831_BM1` and its checksums/manifest. Newly captured: [ENV-P0__20261111-014844_Validate.txt](test-results/ENV-P0__20261111-014844_Validate.txt) (14/14, V003/B0 and hashes), checksum companion, [R-27-HARNESS-DIFF__20261111-015043_BM1.txt](test-results/R-27-HARNESS-DIFF__20261111-015043_BM1.txt) (A6 routing review), [ENV-P0__20261111-015411_RecoveryMetadata.txt](test-results/ENV-P0__20261111-015411_RecoveryMetadata.txt), [ENV-P0__20261111-015114_RecoverySnapshot.txt](test-results/ENV-P0__20261111-015114_RecoverySnapshot.txt) and RecoveryHost JSON, [ENV-P0__20261111-015319_ControlledSession.txt](test-results/ENV-P0__20261111-015319_ControlledSession.txt) (failed standing preconditions; E6 NOT_RUN), [ENV-P0__20261111-020559_MemoryRollback.txt](test-results/ENV-P0__20261111-020559_MemoryRollback.txt) (original memory restored). These are readiness/diagnostic evidence, never formal P2-02 baseline results. [Environment report](../design/ENVIRONMENT_P0.md).
