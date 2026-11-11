# WO-P3-P0-02 — Environment and Feature Baseline

| Field | Value |
|---|---|
| Status | **BLOCKED** (2026-11-11 recovery; approved preparation complete, E6 NOT_RUN: physical-memory precondition unmet; see execution record) |
| Phase | P0 — Readiness Audit and Decision Freeze |
| Mode | BUILD_AUTHORIZED (instance memory setting on BM-1, the two disposable databases, feature probes, E6 harness `-Server` parameter) + VERIFY_ONLY (readiness tests). Originally VERIFY_ONLY |
| Approver | Project Owner |
| Approval record | **APPROVED 2026-11-10** by the Owner Directive "Execute BM-1 Readiness and Final R-27 Validation" (Claude Code session of 2026-11-10): A1 revised WO on BM-1; A2 databases `FitLife_P3_Probe` and `FitLife_P3_P2` on `MSSQLSERVER01` only; A3 `min/max server memory` 1,024/2,048 MB on `MSSQLSERVER01` only (conditional on a safety preflight; reversible); A4 "Best performance" power mode during the measurement session (restored afterwards); A5 Owner closes applications on request; A6 `-Server` parameter for the E6 harness; A7 E5 = current database-scoped configuration, M3 = validated R-27 method, V003 in B0. Not authorized: formal WO-P3-P2-02 execution, any change to `MSSQLSERVER`, commit/push/merge |
| Target database | **Instance `localhost\MSSQLSERVER01` (BM-1) only:** `FitLife_P3_Probe` (feature probes; dropped at the end) and `FitLife_P3_P2` (DS-L benchmark dataset; disposable marker WO-P3-P2-01; kept for WO-P3-P2-02). The default instance `MSSQLSERVER` and its databases are read only |

**Revision record (2026-11-07, Owner Directive WO-P3-P0-FINAL).** Re-scoped and re-sequenced. (1) The repository part is superseded: the canonical repository was identified and cloned read-only on 2026-11-07, and the documentation cut-over is step 0 of WO-P3-P1-01 ([package §E](../design/P0_FINAL_DECISION_PACKAGE.md#e-repository-readiness)). (2) The instance identity needed by P1 (version, edition, compatibility level, time-zone offset) is captured in step 1 of WO-P3-P1-01. (3) This WO keeps the hardware facts and the **feature probes**, which only the later phases need (filtered indexes and SET options for P4, partitioning for P5, indexed-view matching for P4-02). It is therefore **no longer part of GATE-P0** and must be PASSED before WO-P3-P2-02 (baseline benchmark).

## 1. Objective

Verify the environment facts that the benchmark and optimisation phases depend on: hardware, instance configuration, edition feature limits and client SET options (D-002, R-09, R-12).

## 2. Preconditions

- WO-P3-BOOT-001 PASSED; D-002 APPROVED.
- Explicit authorization for: (a) read-only server queries; (b) creating and dropping a probe database.

## 2a. Status note and feature-probe authorization request (2026-11-08)

Owner Directive "R-27 Targeted Remediation and Recheck" §7 (VERIFY_ONLY: no database created, no object created). **Status unchanged: `PROPOSED`.** It cannot be `VERIFIED` yet, because acceptance criterion 2 needs objects to be created.

| Task / criterion | Existing evidence (read-only or from earlier approved runs) | State |
|---|---|---|
| Task 1, machine facts (CPU, cores, RAM, disk, OS build, power plan) | R-27-DIAG §D1–D2 (12:21, 13:21 before/after, 15:54 before/after): i5-1135G7 4C/8T, 7.9 GB, NVMe SSD, Windows 10 Pro build 19044, Balanced | Captured; not yet in `ENVIRONMENT_P0.md` |
| Task 2, instance facts | ENV-P1 (version 17.0.1000.7, "Standard Developer Edition", **EngineEdition 2 = Standard feature set**, compatibility 160); 2026-11-08 snapshot: max server memory unlimited, min 16 MB, MAXDOP 8, cost threshold 5, optimize for ad hoc 0; `MSSQLSERVER01` in R-27-DIAG §D5 | Captured; not yet in `ENVIRONMENT_P0.md` |
| Task 3e `GENERATE_SERIES` | Used successfully by `db/seed/S001__p3_dataset_generator.sql` and `F001D` in the six WO-P3-P2-01 runs (`P2-RUN__…`) | **Equivalent evidence exists** |
| Task 3a filtered index; 3b partition function and scheme; 3c indexed view and matching without NOEXPAND; 3d `ONLINE = ON`; 3f DML on a filtered-index table with and without `-I` | None. These matter because EngineEdition 2 may restrict 3c and 3d | **NOT_RUN**: needs object creation |
| Task 4, PowerShell `System.Data.SqlClient` | Assembly present (System.Data 4.0.0.0); no connection made with it. All harnesses use `sqlcmd -E` | Partial |

**Feature probes need a separate BUILD_AUTHORIZED approval**, plus authorization (b) of §2. Exact DDL proposed (run in `sqlcmd` with `-I`, except where 3f says otherwise):

```sql
CREATE DATABASE FitLife_P3_Probe;                                  -- temporary; dropped at the end
USE FitLife_P3_Probe;
CREATE TABLE dbo.probe_t (id int NOT NULL CONSTRAINT pk_probe_t PRIMARY KEY, grp int NOT NULL, st char(4) NOT NULL, amt decimal(18,2) NOT NULL);
INSERT dbo.probe_t SELECT value, value % 10, CASE WHEN value % 2 = 0 THEN 'PAID' ELSE 'PEND' END, value FROM GENERATE_SERIES(1, 10000);
CREATE INDEX ix_probe_filtered ON dbo.probe_t (grp) INCLUDE (amt) WHERE st = 'PAID';                -- 3a
CREATE PARTITION FUNCTION pf_probe (int) AS RANGE RIGHT FOR VALUES (2, 3);                         -- 3b
CREATE PARTITION SCHEME ps_probe AS PARTITION pf_probe ALL TO ([PRIMARY]);
CREATE TABLE dbo.probe_part (id int NOT NULL CONSTRAINT pk_probe_part PRIMARY KEY) ON ps_probe (id);
INSERT dbo.probe_part VALUES (1), (2), (3);
GO
CREATE VIEW dbo.v_probe WITH SCHEMABINDING AS                                                      -- 3c
  SELECT grp, SUM(amt) AS s, COUNT_BIG(*) AS c FROM dbo.probe_t WHERE st = 'PAID' GROUP BY grp;
GO
CREATE UNIQUE CLUSTERED INDEX ix_v_probe ON dbo.v_probe (grp);
-- 3c check: actual plan of  SELECT grp, SUM(amt) FROM dbo.probe_t WHERE st = 'PAID' GROUP BY grp;  (no NOEXPAND): does it read ix_v_probe?
CREATE INDEX ix_probe_online ON dbo.probe_t (amt) WITH (ONLINE = ON);                              -- 3d (record the error text if refused)
-- 3f: UPDATE dbo.probe_t SET amt = amt + 1 WHERE id = 2;  once via sqlcmd -I, once via sqlcmd without -I (record message 1934 if any)
USE master; DROP DATABASE FitLife_P3_Probe;                                                         -- criterion 3
```

Objects created, all inside `FitLife_P3_Probe` and removed with it: tables `probe_t` and `probe_part`; partition function `pf_probe`; partition scheme `ps_probe`; view `v_probe` with index `ix_v_probe`; indexes `ix_probe_filtered` and `ix_probe_online`. No existing database is touched. Evidence: `ENV-P0__<ts>.txt` plus the database list before and after.

## 2c. Amended scope (approved 2026-11-10)

The Owner approved the amendment proposed in §2b ([BENCHMARK_ENVIRONMENT_READINESS](../design/BENCHMARK_ENVIRONMENT_READINESS.md) §3, §5). Tasks 1–5 and 7 and acceptance criteria 1–3 are unchanged. Added, all on BM-1:

| Added task | Content |
|---|---|
| 8 | Safety preflight; then `min server memory` 1,024 MB / `max server memory` 2,048 MB on `MSSQLSERVER01` (previous values recorded; rollback script) |
| 9 | Build `FitLife_P3_P2` with the unchanged P2 pipeline (`run_p2_dataset.ps1 -Server localhost\MSSQLSERVER01`, DS-L) and compare its canonical checksums with run C; apply V003 (B0 = V001 + V002 + V003, no optimisation object); validate schema, constraints and index inventory |
| 10 | Add `-Server` to the E6 harness (queries, thresholds, checks unchanged; diff reviewed) |
| 11 | One E6 campaign on BM-1 under controlled host conditions (AC, "Best performance" mode, applications closed by the Owner), thresholds of WO-P3-P2-02 §2a unchanged |

| Added acceptance criterion | Content |
|---|---|
| 5 | The BM-1 configuration change is recorded with its previous values, limited to `MSSQLSERVER01`, and reversible; `MSSQLSERVER` unchanged |
| 6 | `FitLife_P3_P2` on BM-1: dataset checksum = DS-L run C; T-SCH-02 and T-SEED PASS; V003 trusted; no non-PK index, view, trigger or partition object |
| 7 | E6 PASS on BM-1 with unchanged thresholds (R-27 closure test). A FAIL keeps R-27 OPEN and this WO not VERIFIED; it is not repeated on the same conditions |

§5 "Out of scope" is narrowed by this approval only for the items above (instance memory setting on BM-1; the DS-L project dataset on BM-1). Still out of scope: software installation, any change to `MSSQLSERVER` or other databases, formal baseline measurement (WO-P3-P2-02).

## 3. Inputs

S-14; [08 §7](../08_INDEX_AND_QUERY_PLAN.md#7-query-writing-rules); [10 §2](../10_SEED_AND_BENCHMARK_PLAN.md#2-environment-identification); [03 D-002, D-021](../03_DECISION_LOG.md).

## 4. Tasks

1. Record machine facts: CPU, cores, RAM, disk type, OS build, power plan.
2. On each instance: `@@VERSION`, `SERVERPROPERTY('Edition')`, `'EngineEdition'`, `'ProductVersion'`, max server memory, MAXDOP, cost threshold for parallelism, default compatibility level.
3. In the probe database, test and record (pass/fail plus message):
   - a filtered index;
   - a partition function and scheme on a 3-row table;
   - an indexed view and whether the optimizer matches it **without** NOEXPAND;
   - `CREATE INDEX … WITH (ONLINE = ON)`;
   - `GENERATE_SERIES`;
   - DML on a table with a filtered index from `sqlcmd` with and without `-I`.
4. Confirm the PowerShell 5.1 `System.Data.SqlClient` connectivity method (Windows authentication; no stored credentials).
5. Drop the probe database.
6. _(Superseded 2026-11-07: repository setup moved to the P0 final package §E and WO-P3-P1-01 step 0.)_
7. Write `docs/phase2/person3/design/ENVIRONMENT_P0.md` and update D-002, R-09, [16](../16_READINESS_REPORT.md) and [SESSION_LOG.md](../SESSION_LOG.md).

## 5. Out of scope

Creating project schemas or data; installing software; changing server configuration (memory, MAXDOP, etc.); touching any existing database.

## 6. Deliverables and locations

`docs/phase2/person3/design/ENVIRONMENT_P0.md`.

## 7. Acceptance criteria

1. Every environment field of [10 §2](../10_SEED_AND_BENCHMARK_PLAN.md#2-environment-identification) is filled from captured output.
2. Every feature probe has a recorded result with its error text if it failed.
3. The probe database no longer exists.
4. _(Superseded 2026-11-07: repository criterion moved to WO-P3-P1-01.)_

## 8. Verification

Captured command outputs are saved and quoted in the environment report. A second listing of databases confirms the probe was dropped.

## 9. Evidence

Raw query outputs (with no secrets) in `docs/phase2/person3/evidence/test-results/ENV-P0__<YYYYMMDD-HHMM>.txt`.

## 10. Dependencies and risks

R-09, R-17, R-20. A local instance may differ from teammates' instances; record both if known.

## 11. Approval requirements

Approval of this WO plus the two explicit authorizations in §2.

## 12. Exit and next step

Must be PASSED before WO-P3-P2-02. It can run any time after D-002 is approved, in parallel with P1.

## 13. Execution record

_(filled by the executing session)_

## 2b. Status note (2026-11-10)

Owner Directive "Accept P3 Correctness & Unblock Performance" (Claude Code session of 2026-11-10) §3–§5. **Status unchanged: `PROPOSED`.** Read-only inventory [ENV-INVENTORY__20261110-080635](../evidence/test-results/ENV-INVENTORY__20261110-080635.txt). Task 4 now has equivalent evidence: every T-CONC harness connects through PowerShell 5.1 `System.Data.SqlClient` with Windows authentication (e.g. run `P3-03-RUN__20261110-0737`). Probes 3a–3d and 3f remain `NOT_RUN` (object creation required). **Proposed amendment for approval** ([BENCHMARK_ENVIRONMENT_READINESS §3, §5](../design/BENCHMARK_ENVIRONMENT_READINESS.md)): run this WO on the dedicated instance `localhost\MSSQLSERVER01` (BM-1) and extend it with the benchmark-environment setup (memory floor/cap on BM-1, power mode, DS-L build on BM-1 with checksum = run C, harness `-Server` parameter) and the R-27 closure test E6, so that WO-P3-P2-02 can start on a proven environment. Its §5 "out of scope" (configuration changes, project data) would be changed only by that approval.

### 13.1 Recovery and execution - 2026-11-11

WO-P3-P0-02 **BLOCKED**: approved preparation completed, E6 **NOT_RUN** because the physical-memory precondition failed (observed 722-1144 MB; required >= 2,048 MB). R-27 **OPEN**. No benchmark failure or performance claim. Memory settings restored to their recorded original configuration; temporary power mode was not applied. P2-02 remains not authorized.

Recovered verified steps: preflight/memory/probes and DS-L build from 2026-11-10. Resumed: missing V003, B0 validation 14/14 PASS, all canonical hashes = C, A6 portable target routing and parse verification. No DB rebuild or feature rerun. Exact approval reconciliation, task matrix, E1-E6 and continuation: [ENVIRONMENT_P0](../design/ENVIRONMENT_P0.md). Raw controlled-session output: [ENV-P0__20261111-015319_ControlledSession.txt](../evidence/test-results/ENV-P0__20261111-015319_ControlledSession.txt); rollback: [ENV-P0__20261111-020559_MemoryRollback.txt](../evidence/test-results/ENV-P0__20261111-020559_MemoryRollback.txt). Acceptance criteria 1-3, 5-6 verified; criterion 7 unmet. No Owner acceptance recorded. Phase status unchanged except this readiness WO; formal P2-02 not authorized. Branch p3/wo-p3-p1-01 / 792a85e; initial 339 untracked paths, preserved. Changes restricted to missing V003 execution, test harness routing, evidence and affected documentation; tests: Validate 14/14, PowerShell parse 3/3, no timed E6. Next: safely meet E1-E3, re-preflight BM-1 memory, run unused single campaign; then stop for Owner gates.
