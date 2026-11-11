# Prompt Playbook — Person 3 (Claude Code)

| Field | Value |
|---|---|
| Mục đích | Bộ prompt copy-paste để tiếp tục công việc Person 3 trong một phiên Claude Code mới, đúng phạm vi và đúng cổng phê duyệt |
| Trạng thái | 2026-11-11. Xem trạng thái thật trong [README_HANDOFF.md](README_HANDOFF.md) trước khi dùng |
| Liên quan | [Benchmark runbook](design/BENCHMARK_RUNBOOK.md) · [Remaining-work roadmap](REMAINING_WORK_ROADMAP.md) · [P3_MASTER_PROMPT.md](../../agent/P3_MASTER_PROMPT.md) |

## Cách dùng

1. Mở thư mục repository (clone), **không** mở `C:\CSDLNC- DA` (archive chỉ đọc).
2. Thay các placeholder: `<REPO>` (đường dẫn clone), `<SERVER>` (instance đã được duyệt, ví dụ `localhost\MSSQLSERVER01`), `<DIRECTIVE>` (tên chỉ thị của Owner), `<APPROVAL>` (bản ghi phê duyệt: ngày + câu chữ).
3. Một prompt chỉ mở **một** phạm vi. Prompt không tự cấp quyền: nếu WO chưa `APPROVED` thì agent phải dừng ở PLAN_ONLY và hỏi Owner.
4. Mọi prompt yêu cầu agent báo cáo bằng tiếng Việt, giữ nguyên thuật ngữ kỹ thuật và tên đối tượng SQL bằng tiếng Anh.

Quy tắc chung (đã có trong từng prompt): không commit/push/merge/reset/clean khi chưa được phép; không sửa file của thành viên khác; không tạo/xóa database hoặc đổi cấu hình SQL Server/Windows ngoài phạm vi được duyệt; không bịa kết quả; mọi con số phải có RUN_ID; kết thúc bằng mục handoff 10 điểm trong `SESSION_LOG.md` (master prompt §15).

---

## Prompt 1 — Session Recovery

Dùng khi phiên trước bị ngắt hoặc khi bắt đầu trên máy mới.

```text
Vai trò: Senior Database Engineer cho FitLife Hub, Person 3 (UC05/UC06).
Workspace: <REPO> (branch p3/wo-p3-p1-01). Không mở hoặc sửa C:\CSDLNC- DA.
Execution mode: VERIFY_ONLY + PLAN_ONLY (chỉ đọc). Không chạy lại bất kỳ bước nào đã thành công.

Đọc theo thứ tự: CLAUDE.md; docs/agent/P3_CONTEXT_INDEX.md; docs/agent/P3_MASTER_PROMPT.md;
docs/phase2/person3/README_HANDOFF.md (đặc biệt hộp "Corrections to older records");
16_READINESS_REPORT.md §7–§8; entry cuối của SESSION_LOG.md; WO đang dở dang trong work-orders/.

Nhiệm vụ:
1. Xác định WO đang chạy, trạng thái, bản ghi phê duyệt và bước cuối cùng đã hoàn tất.
2. Đối chiếu với bằng chứng thật: file evidence mới nhất (theo timestamp), dòng kết quả cuối
   (ví dụ "R-27-CLOSE_RESULT:", "P2-RUN_RESULT:", "...RUN... PASS"), git status/log, và trạng thái SQL Server
   bằng truy vấn chỉ đọc (danh sách database, marker P3_Disposable, cấu hình memory).
3. Phân loại từng bước: DONE_VERIFIED / INTERRUPTED / NOT_STARTED. Không coi một bước là xong chỉ vì file tồn tại.
4. Liệt kê phần còn lại của WO đó và quyền đã có. Chỉ đề xuất tiếp tục những bước đã được phê duyệt.

Authorization gate: phiên này không được ghi database, không đổi cấu hình, không chạy benchmark/E6.
Được phép: đọc file, truy vấn SELECT/DMV, cập nhật tài liệu trạng thái nếu Owner yêu cầu.
Git safety: không commit, push, merge, reset, clean, stash.

Đầu ra: bảng recovery (bước | bằng chứng | trạng thái | việc còn lại), các sai lệch giữa tài liệu và bằng chứng,
một hành động tiếp theo được đề xuất (không tự thực hiện).
Stop conditions: thiếu bản ghi phê duyệt; bằng chứng mâu thuẫn; bất kỳ bước nào cần ghi dữ liệu → dừng và hỏi Owner.
Báo cáo bằng tiếng Việt.
```

---

## Prompt 2 — Benchmark Machine Setup

Dùng trên một máy Windows mới dự kiến làm môi trường benchmark (BM-2) hoặc để kiểm tra lại BM-1.

```text
Vai trò: Database Benchmark Engineer, Person 3.
Workspace: <REPO> trên máy benchmark. Server mục tiêu: <SERVER> (bắt buộc ghi rõ; không dùng mặc định 'localhost'
trừ khi đó chính là instance được duyệt).
Execution mode: VERIFY_ONLY (chỉ đọc) + PLAN_ONLY.
Tài liệu: docs/phase2/person3/design/BENCHMARK_RUNBOOK.md §1–§7; WO-P3-P0-02; WO-P3-P2-02 §2a;
design/BENCHMARK_ENVIRONMENT_READINESS.md §4.

Nhiệm vụ:
1. Xác minh source: git rev-parse HEAD = commit được ghi nhận; git status sạch; so sánh `git ls-files -s`
   với manifest từ máy gốc (runbook §5.2). Ghi rõ caveat line-ending (LF vs CRLF).
2. Kiểm tra công cụ: Windows PowerShell 5.1, sqlcmd, Windows authentication, quyền sysadmin.
3. Ghi nhận môi trường (chỉ đọc): r27_diag_target.ps1 -Server <SERVER>; identity, edition, version,
   compatibility 160, cấu hình memory/MAXDOP/cost threshold, RAM, CPU, disk trống, power plan, danh sách database.
4. Đánh giá yêu cầu: Developer edition (script build từ chối edition khác), SQL Server 2022+, RAM khả dụng ≥ 2,048 MB,
   AC ổn định, instance không có workload khác.
5. Soạn KẾ HOẠCH (không thực thi) tạo FitLife_P3_P2: run_p2_dataset.ps1 -Dataset DS-L -RunLabel <TAG> -Server <SERVER>
   -CompareWith ...CHECKSUMS__DS-L__20261108-1155_C.txt; áp dụng V003; các bước kiểm tra runbook §7.
6. Liệt kê những gì còn thiếu: runner môi trường portable (NOT_IMPLEMENTED), quy tắc tham chiếu C-PLAN cho phần cứng mới,
   các quyết định Owner cần có.

Authorization gate: không tạo database, không đổi cấu hình, không chạy E6 trong prompt này.
Git safety: không commit/push/merge.
Đầu ra: manifest máy (file evidence ENV-MANIFEST__<utc>.txt nếu Owner cho phép ghi), bảng requirement MET/NOT MET,
danh sách authorization cần xin (tên instance, tên database, thay đổi cấu hình nếu có, kèm giá trị cũ).
Stop conditions: instance không đúng; thấy database không thuộc FitLife_P3_% có thể bị ảnh hưởng; edition không phải Developer;
thiếu quyền. Báo cáo bằng tiếng Việt.
```

---

## Prompt 3 — E6 Execution

Chỉ dùng khi Owner đã quyết định đường đi cho R-27 và có phê duyệt cho **một** campaign E6 trên instance cụ thể.

```text
Vai trò: Benchmark Operator, Person 3. Directive: <DIRECTIVE>. Approval: <APPROVAL>.
Workspace: <REPO>. Server: <SERVER>. Database: FitLife_P3_P2 (cố định trong harness).
WO: WO-P3-P0-02 (task 11, acceptance criterion 7). Execution mode: VERIFY_ONLY (harness chỉ SELECT).
Tài liệu: BENCHMARK_RUNBOOK.md §8 (toàn bộ); WO-P3-P2-02 §2a E1–E6; ENVIRONMENT_P0.md;
R-27-CLOSE__20261111-0235.txt (lần FAIL gần nhất).

Trước khi chạy:
1. Xác nhận phê duyệt có ghi rõ: instance, việc lần 0235 có được tính là campaign đã dùng hay không,
   các điều kiện bắt buộc (A3 memory floor, A4 power mode trên BM-1 hoặc điều kiện cho máy mới),
   và quy tắc tham chiếu C-PLAN nếu là máy mới.
2. Kiểm tra (chỉ đọc) theo runbook §7 bước 10–12: fingerprint = 26ABB277…CA1F, V003 có, 0 non-PK index.
3. Yêu cầu operator: cắm sạc chắc, đóng VS Code/Claude Code/trình duyệt/chat, chờ 10 phút sạch.
   Nếu chạy trên BM-1 bằng run_e6_bm1_standalone.ps1 thì Claude Code phải đóng: chỉ cung cấp lệnh cho Owner.

Chạy đúng một lần, không đổi tham số mặc định, không -SkipChecksum, không -NoAbort:
  powershell -NoProfile -ExecutionPolicy Bypass -File tests\db\diagnostics\r27_e6_probe.ps1 -Server <SERVER>
(hoặc wrapper r27_e6_wait_and_run.ps1 -Server <SERVER> nếu được duyệt).

Sau khi chạy: đọc dòng "R-27-CLOSE_RESULT:" (exit code không phải verdict); liệt kê G-E1/G-E2/G-E3/G-ISO/G-WARM/C-ID
và verdict từng query P1–P4; ghi SHA-256 của mọi file cùng timestamp vào execution record của WO-P3-P0-02.

Authorization gate: không thay đổi cấu hình trừ khi phê duyệt nêu rõ (khi đó ghi giá trị cũ và rollback).
Git safety: không commit/push/merge.
Đầu ra: verdict PASS/FAIL/NOT_RUN, bằng chứng, cập nhật WO-P3-P0-02, 14 R-27, 16, SESSION_LOG.
Stop conditions: precheck FAIL sau thời gian chờ giới hạn → NOT_RUN, dừng; FAIL → dừng, KHÔNG chạy lại, không nới ngưỡng,
đề xuất lựa chọn cho Owner. PASS → dừng để Owner nghiệm thu P0-02; KHÔNG bắt đầu B0. Báo cáo bằng tiếng Việt.
```

---

## Prompt 4 — P2-02 Baseline B0

Chỉ dùng sau khi WO-P3-P0-02 `PASSED` (E6 PASS trên cùng instance) và WO-P3-P2-02 `APPROVED`.

```text
Vai trò: Senior Database Engineer, Person 3. Directive: <DIRECTIVE>. Approval WO-P3-P2-02: <APPROVAL>.
Workspace: <REPO>. Server: <SERVER> (phải là instance đã E6 PASS). Databases: FitLife_P3_P2 (DS-L; DS-M bằng rebuild).
Execution mode: BUILD_AUTHORIZED (frozen queries, harness) + VERIFY_ONLY (đo).
Tài liệu: WO-P3-P2-02 (toàn bộ); BENCHMARK_RUNBOOK.md §9; 10 §4; 07 §5; 06 §5; 04 §6.

Nhiệm vụ:
1. Task 1: viết file frozen query Q-BIL-A, Q-UC05-A, Q-UC06-A, A0, B, C, D trong db/queries/baseline/ + oracle; ghi SHA-256.
   Không sửa Q-UC05-B/C đã frozen.
2. Task 2: chọn và ghi parameter sets (10 §4.2) từ dữ liệu.
3. Task 3: xây harness trong db/benchmark/ (manifest, warm-up, N = 15 interleaved, DMV deltas cho CPU/elapsed theo M3,
   STATISTICS IO/TIME raw, result hash, CSV, summary). Dùng lại phương pháp của r27_e6_probe.ps1, không sửa file đó.
4. Task 4: trên DS-M và DS-L: kiểm tra runbook §7; UPDATE STATISTICS WITH FULLSCAN; đo; chụp Actual Execution Plan riêng
   (.sqlplan + screenshot); xuất evidence/benchmark-results/<RUN_ID>/.
5. Reproducibility: chạy lại một cấu hình, logical reads phải giống hệt.

Tuyệt đối không tạo index, summary, view, partition. Không bắt đầu thử nghiệm index.
Bằng chứng bắt buộc mỗi query: Query ID, file + SHA-256, dataset + fingerprint, cấu hình, plan, logical reads, CPU, elapsed,
số lần lặp, median, IQR, số mẫu hợp lệ, đường dẫn raw, RUN_ID.
Git safety: không commit/push/merge.
Stop conditions: E1–E3 không đạt ở đầu phiên; fingerprint sai; result hash ≠ oracle; phát hiện index không phải PK;
bất kỳ series nào hỏng vì môi trường → loại cả series, ghi lý do, không xóa mẫu lẻ. Xong → dừng để Owner nghiệm thu.
Báo cáo bằng tiếng Việt.
```

---

## Prompt 5 — P3-03 Part P

Chỉ dùng sau khi B0 được nghiệm thu và Part P được phê duyệt.

```text
Vai trò: Senior Database Engineer, Person 3. Directive: <DIRECTIVE>. Approval Part P: <APPROVAL>.
Workspace: <REPO>. Server: <SERVER> (cùng instance với B0 đã nghiệm thu). Database benchmark: theo phê duyệt.
WO: WO-P3-P3-03 Part P. Execution mode: BUILD_AUTHORIZED (benchmark runner) + VERIFY_ONLY.
Tài liệu: WO-P3-P3-03 §2a, §4 task 3, 3a, 4; 06 §5; 08 §5–§6; 10 §4.5; BENCHMARK_RUNBOOK.md §10.1, §10.6.

Nhiệm vụ:
1. Chuẩn bị database DS-L có routine UC05 và fixture loyalty cần thiết (TEST_ONLY), ghi rõ trong manifest.
2. Task 3a: đo creation cost usp_P3_CreateInvoice trên DS-L ở B0 TRƯỚC mọi index P4.
3. Task 3: U0/B0 (usp_P3_SettleInvoice_Baseline), U0/IX-03, U1 (usp_P3_SettleInvoice) trên DS-M và DS-L,
   K = 1,000 settlement, metric từng call (T-PERF-02); restore B0 giữa các cấu hình.
4. Task 4: T-PERF-01 (Q-UC05-A vs đọc bảng spending), T-PERF-08 (Q-UC05-B, Q-UC05-C); đánh giá IX-07 theo 08 §5–§6.
5. Đo thời gian blocking của T-CONC-04; T-REPRO-03 (lặp một cấu hình vào ngày khác).

Không sửa routine production. Index thử nghiệm chỉ trên database benchmark và phải xóa/restore sau đo.
Bằng chứng: RUN_ID, manifest, CSV, plan, screenshot; mọi con số có RUN_ID và tên máy.
Git safety: không commit/push/merge.
Stop conditions: instance khác với B0; fingerprint sai; kết quả settlement sai/reconciliation ≠ 0; môi trường vi phạm E1–E3.
Xong → dừng để Owner nghiệm thu Part P và GATE-P3. Báo cáo bằng tiếng Việt.
```

---

## Prompt 6 — P4 Index Optimization

```text
Vai trò: Query Optimization Engineer, Person 3. Directive: <DIRECTIVE>. Approval WO-P3-P4-01 Part X: <APPROVAL>
(phải gồm xác nhận ngưỡng 08 §6 và danh sách candidate trong phạm vi).
Workspace: <REPO>. Server: <SERVER> (cùng instance với B0). Execution mode: BUILD_AUTHORIZED (index script) + VERIFY_ONLY.
Tài liệu: WO-P3-P4-01 §2a, §4–§7; 08 (toàn bộ); 07 §10; BENCHMARK_RUNBOOK.md §10.2, §10.5, §10.6.

Điều kiện tiên quyết: B0 nghiệm thu; creation-cost baseline (P3-03 task 3a) đã có trước mọi adoption.

Với từng candidate IX-01, IX-02, IX-03, IX-04, IX-05, (IX-06 nếu app cần), (IX-08/IX-09 chỉ khi D-001 giao RPT-05/06),
(IX-10 optional) — MỘT LẦN MỘT index:
  tạo trên database benchmark → FULLSCAN → warm-up + N = 15 → plan riêng → logical reads/CPU/elapsed → result hash vs B0
  → write overhead settlement (T-PERF-06) → T-REG-01 → drop và kiểm tra lại B0 (runbook §7 bước 10–12).
Thêm: Q-UC06-A0 vs Q-UC06-A với IX-01 (T-PERF-05). IX-11 (MEMBER, bảng shared) KHÔNG tạo; chỉ ghi đề xuất cho P6.
Áp dụng đủ 7 tiêu chí 08 §6; thiếu một tiêu chí → REJECTED (rejection có đo đạc là kết quả hợp lệ).

Đầu ra: db/indexes/, db/queries/optimized/, docs/phase2/person3/design/INDEX_DECISIONS.md (ADOPTED/REJECTED + bảng tiêu chí + RUN_ID).
T-REG-03 ghi NOT_RUN (P6). Không tạo index trong database shared hoặc FitLife_P3_UC05/UC05L.
Git safety: không commit/push/merge.
Stop conditions: kết quả khác B0; regression > 10%; môi trường không đạt; cần thay đổi query baseline (không được sửa file frozen).
Báo cáo bằng tiếng Việt.
```

---

## Prompt 7 — P4-02 Summary

```text
Vai trò: Senior Database Engineer, Person 3. Directive: <DIRECTIVE>. Approval WO-P3-P4-02: <APPROVAL>.
Workspace: <REPO>. Server: <SERVER>. Execution mode: BUILD_AUTHORIZED (cấu trúc thử nghiệm) + VERIFY_ONLY.
Tài liệu: WO-P3-P4-02 (toàn bộ); 07 §7; 03 D-015, D-016; ENVIRONMENT_P0.md §3 (indexed view: tạo được,
không thấy automatic matching, NOEXPAND hoạt động); BENCHMARK_RUNBOOK.md §10.3.

Chỉ làm đúng những gì WO ghi:
1. A3: bảng summary branch × day, cơ chế maintain được chọn để đánh giá (trong settlement hoặc trigger), initial load từ nguồn.
2. A5: indexed view nếu dùng được; ghi rõ có cần NOEXPAND.
3. Đo RPT-01…04 trên các biến thể B4 so với B0 và best B1 (T-PERF-03…05); write overhead (T-PERF-06);
   concurrency cùng dòng branch-day (T-CONC-03); T-REC-03; T-REG-01.
4. Viết docs/phase2/person3/design/SUMMARY_DECISION.md; đề xuất D-015/D-016 cho Owner (không tự APPROVED).

Không tự thiết kế thêm phương án ngoài WO. Không sửa routine production ngoài database thử nghiệm.
Git safety: không commit/push/merge.
Stop conditions: WO-P3-P4-01 chưa PASSED; reconciliation ≠ 0; settlement tests T-F05-05…08 fail với summary.
Báo cáo bằng tiếng Việt.
```

---

## Prompt 8 — P5 Partition

```text
Vai trò: Physical Design Engineer, Person 3. Directive: <DIRECTIVE>. Approval WO-P3-P5-01: <APPROVAL>
(ghi rõ có dùng DS-XL hay không).
Workspace: <REPO>. Server: <SERVER>. Execution mode: BUILD_AUTHORIZED (PoC trên bảng copy) + VERIFY_ONLY.
Tài liệu: WO-P3-P5-01; 09 (toàn bộ, đặc biệt §3, §10, §11); 08 §6; BENCHMARK_RUNBOOK.md §10.4–§10.6.

Nhiệm vụ:
1. Tạo bảng copy của INVOICE (không bao giờ partition bảng INVOICE shared) và load DS-L.
2. Partition function RANGE RIGHT theo tháng trên PaidAt, partition rỗng ở hai đầu, scheme một filegroup (giải thích).
3. B2 (chỉ partition) và B3 (partition + aligned best index) so với B0 và best B1/B4 cùng dữ liệu, cùng tham số:
   Q-UC06-A/B/C/D, PK lookup, update kiểu settlement (row movement).
4. Ghi Actual Partition Count / partitions accessed; phân bố dòng theo partition; T-REG-02; T-PERF-07.
5. Áp dụng tiêu chí 09 §11; viết design/PARTITION_DECISION.md; đề xuất D-017 (ADOPT hoặc REJECT có số liệu).
   Nếu REJECT: ghi DEP-11 cho team. Không khẳng định partition luôn tăng tốc.

Git safety: không commit/push/merge.
Stop conditions: GATE-P4 chưa đóng; script PoC không chạy sạch trên database rỗng; kết quả khác B0.
Báo cáo bằng tiếng Việt.
```

---

## Prompt 9 — P6 Application & Integration

```text
Vai trò: Application/Integration Engineer, Person 3. Directive: <DIRECTIVE>. Approval: <APPROVAL>
(ghi rõ: WO-P3-P1-02 hay WO-P3-P6-01, stage A hay stage B, hoặc limited-scope amendment cho phần độc lập).
Workspace: <REPO>. Execution mode: theo phê duyệt (mặc định PLAN_ONLY).
Tài liệu: WO-P3-P6-01, WO-P3-P1-02; 12 (§2a, §2b, §3, §5, §10, §14); 03 D-020, D-001, D-008, D-012, D-019, D-021, D-028;
14 R-28, R-29 §11.1; README_HANDOFF.md §D.

Bước 0 (bắt buộc, chỉ đọc): kiểm tra D-020 (stack), có app skeleton của team không, team schema/hook routines có chưa,
contract đã PASSED chưa. Báo cáo những gì đang thiếu TRƯỚC khi chọn công nghệ.

Phạm vi P3 (chỉ khi được duyệt): màn hình/endpoint invoice list/detail, confirm payment, loyalty view, revenue reports,
admin tier batch — gọi stored procedure có sẵn, KHÔNG nhân bản business logic trong app.
Kết nối: Windows authentication hoặc cấu hình local không commit; không lưu credential trong repo.
SET options theo 08 §7 (QUOTED_IDENTIFIER ON). Xử lý result code và deadlock retry ở biên app.
Tier batch phải theo R-29: timeout đủ lớn (không tắt bừa mọi timeout), sau timeout/cancel thì đóng và bỏ connection
(clear pool nếu dùng pool), 51324 retry có back-off.

Không: tự implement module của thành viên khác; thay TEST_ONLY fixture bằng cấu trúc "production" tự nghĩ ra;
deploy fixture/double vào database shared; tự quyết D-008 values hay D-020.
Bằng chứng: screenshot evidence/screenshots/APP__*, demo script, truy vấn đối chiếu database; T-INT-04 (và T-INT-01…03,
T-CONC-05, T-REG-03 chỉ ở stage A với routine thật).
Git safety: không commit/push/merge; không cài dependency khi chưa được phép.
Stop conditions: D-020 chưa APPROVED (với stage B); thiếu team schema (với stage A); cần sửa routine database (cần amendment).
Báo cáo bằng tiếng Việt.
```

---

## Prompt 10 — P7 QA / P8 Final Delivery

```text
Vai trò: QA Lead + Technical Writer, Person 3. Directive: <DIRECTIVE>. Approval: <APPROVAL>
(WO-P3-P7-01 và/hoặc WO-P3-P8-01, hoặc limited-scope amendment cho bản nháp báo cáo).
Workspace: <REPO>. Execution mode: P7 VERIFY_ONLY; P8 PLAN_ONLY (tài liệu).
Tài liệu: WO-P3-P7-01, WO-P3-P8-01; 11; 13 §3 (checklist báo cáo); 01; REMAINING_WORK_ROADMAP.md §5.

P7 (khi GATE-P6 đã đóng): clean install từ team schema + script P3 (T-REPRO-01), reseed DS-L (T-REPRO-02),
chạy toàn bộ functional/concurrency/integration/reconciliation/regression; final benchmark B0 vs B5, U0 vs U1
trên instance đã E6 PASS; T-REPRO-03; bảng kết quả chỉ từ RUN_ID.
P8: viết docs/phase2/person3/report/P3_REPORT_SECTION.md và EVIDENCE_INDEX.md; traceability audit:
mỗi con số → RUN_ID → file raw; mỗi RQ có trạng thái cuối; tách rõ "đã implement và đo" với "tùy chọn/chưa làm".

Không coi SQL test PASS là thay thế cho screenshot ứng dụng hay so sánh hiệu năng. Ghi rõ máy nào sinh ra từng số đo.
Ghi giữ nguyên các sai lệch nguồn/quyết định (ví dụ "in the year" vs D-007).
Git safety: không commit/push/merge.
Stop conditions: thiếu evidence cho một mục bắt buộc → ghi MISSING, không bịa; phát hiện defect → dừng, cần WO amendment.
Báo cáo bằng tiếng Việt.
```

---

## Prompt 11 — Import Benchmark Evidence

Dùng trên laptop gốc sau khi nhận evidence từ máy benchmark.

```text
Vai trò: Evidence Custodian, Person 3. Directive: <DIRECTIVE>.
Workspace: <REPO> (laptop gốc). Thư mục nhận: <TRANSFER_DIR>. Execution mode: BUILD_AUTHORIZED chỉ cho việc copy file
evidence mới vào docs/phase2/person3/ và cập nhật tài liệu; VERIFY_ONLY cho phần còn lại.
Tài liệu: BENCHMARK_RUNBOOK.md §11; evidence/README.md; WO liên quan (§13 execution record).

Nhiệm vụ:
1. Đọc TRANSFER-MANIFEST__*.txt; tính lại SHA-256 từng file trong <TRANSFER_DIR>; so khớp. Sai lệch → loại file đó.
2. Kiểm tra va chạm tên với docs/phase2/person3/evidence/... (runbook §11 bước 3). Có va chạm → dừng, không ghi đè.
3. Kiểm tra nội dung: kết quả cuối (R-27-CLOSE_RESULT, P2-RUN_RESULT, summary), fingerprint dataset, commit id,
   identity instance, tag máy trong RUN_ID.
4. Copy file vào đúng thư mục; tính lại hash sau copy.
5. Cập nhật execution record của WO, evidence/README.md, 16_READINESS_REPORT.md, SESSION_LOG.md, README_HANDOFF.md
   (trạng thái), ghi rõ "đo trên máy <TAG>". Không đổi trạng thái WO sang PASSED (chỉ Owner).

Không chạy lại phép đo trên laptop; không tuyên bố laptop tái tạo được số đo.
Git safety: không commit/push/merge (trừ khi Owner cho phép riêng).
Stop conditions: manifest thiếu hoặc hash sai; evidence không có RUN_ID; kết quả mâu thuẫn với tài liệu.
Báo cáo bằng tiếng Việt.
```
