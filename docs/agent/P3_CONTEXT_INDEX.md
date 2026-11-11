# P3 Context Index — What to Read When Starting a Person 3 Session

Read in this order and stop when you have enough for the task. Do **not** load every document by default.

## 0. Where to work

- Canonical repository: `https://github.com/Phuoc-IT-2106/CSDLNC-DA` (branch `main`; public as of 2026-11-07).
- Local clone: `C:\Users\DELL\source\repos\CSDLNC-DA`.
- **The cut-over happened on 2026-11-07 (WO-P3-P1-01 step 0).** Edit only in the clone (branch `p3/wo-p3-p1-01`). `C:\CSDLNC- DA` is an immutable, read-only archive of the documents as they were before the cut-over; never edit it.
- **Execution order (2026-11-08, D-027):** P1 → P2 → P3 → P4 → P5 → P6 → P7 → P8; the integration contract WO-P3-P1-02 is deferred to P6 and blocks no P2–P5 work ([15 §2](../phase2/person3/15_ROADMAP_AND_WORK_ORDERS.md#2-execution-order-and-dependencies)).
- **Scope:** Person 3 only. P3 implements INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM and MEMBER_MONTHLY_SPENDING; shared tables are dependencies ([12 §2a](../phase2/person3/12_INTEGRATION_PLAN.md#2a-shared-dependency-interface-required-by-p3)), never P3 modules.

## 1. Always (every P3 session)

| # | File | Why |
|---|---|---|
| 1 | [P3_MASTER_PROMPT.md](P3_MASTER_PROMPT.md) | Operating contract: modes, approval gates, rules |
| 2 | [../phase2/person3/16_READINESS_REPORT.md](../phase2/person3/16_READINESS_REPORT.md) | Current status and blockers |
| 3 | The last entry of [../phase2/person3/SESSION_LOG.md](../phase2/person3/SESSION_LOG.md) | What happened last and what is next |
| 4 | The WO you are asked to execute, in [../phase2/person3/work-orders/](../phase2/person3/work-orders/README.md) | Scope, preconditions, acceptance criteria |
| 5 | The index table of [../phase2/person3/03_DECISION_LOG.md](../phase2/person3/03_DECISION_LOG.md) | Which rules are APPROVED |

If no WO is named, or the named WO is not `APPROVED`, work in PLAN_ONLY mode (master prompt §3) and ask the Project Owner.

## 2. Additional reading per work order

| Work order | Read also |
|---|---|
| WO-P3-P0-01 | 00, 02, 03 (full), 15 |
| WO-P3-P0-03 | 03 (full), the P0 final decision package (`design/P0_FINAL_DECISION_PACKAGE.md`, Section F and Annex 1), 16 §2 |
| WO-P3-P0-02 | 10 §2, 08 §7, 03 D-002 |
| WO-P3-P1-02 (deferred to P6, D-027) | 12 (§2a, §2b register, §14), 05 §1, 03 (approved decisions, D-012, D-026, D-027, D-028) |
| WO-P3-P1-01 | The WO itself (§3 is the full specification, §3.2 the scope matrix), 12 §2a (shared-dependency interface), 03 D-026 (restricted scope), the P0 final package §E, 05 §13–§14, 01 (RQ-A01, RQ-A13, RQ-P07–P09, RQ-P11, RQ-P16), 11 §2.1 |
| WO-P3-P2-01 | 10 §3, 04, 12 §2b, WO-P3-P1-01 §3.3a (fixture rules) |
| WO-P3-P2-02 | 10 §4, 07 §5, 04 §6 |
| WO-P3-P3-00 | 06 §4.1 and §8, 03 D-028, 11 §2.3/§2.5, 12 §2b |
| WO-P3-P3-01 / -02 / -03 | 06 (incl. §8), 11 §2.3/§2.5/§2.7, 12 §2b, §4–§6 |
| WO-P3-P4-01 / -02 | 07, 08, 10 §4 |
| WO-P3-P5-01 | 09, 08 §6 |
| WO-P3-P6-01 | 12 §10, §14, integration contract |
| WO-P3-P7-01 | 11, 10 |
| WO-P3-P8-01 | 13, 01 |

Numbers refer to files in `docs/phase2/person3/` (e.g. 06 = `06_UC05_BILLING_LOYALTY_PLAN.md`).

## 3. Source documents (outside the repository)

Original sources are **not** in the repository. Their local paths, versions and checksums are in [../phase2/person3/00_SOURCE_AND_SCOPE.md §3](../phase2/person3/00_SOURCE_AND_SCOPE.md#3-source-inventory). Open them only when a task needs a fact that the planning documents do not already quote. The official assignment PDF is password-protected: ask the Project Owner for the password at runtime, and never store it.

## 4. Do not

- Do not treat the research report (S-09) or these planning documents as requirements.
- Do not start implementation because a document "describes" it. Only an APPROVED WO authorizes it.
