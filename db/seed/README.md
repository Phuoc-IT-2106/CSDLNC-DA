# P3 dataset generator (WO-P3-P2-01, DL-04)

Deterministic large dataset for the four Person 3 tables (INVOICE, INVOICE_SERVICE_ITEM, INVOICE_PRODUCT_ITEM, MEMBER_MONTHLY_SPENDING) in the isolated database `FitLife_P3_P2`. Shared parents (MEMBER, BRANCH, EMPLOYEE, SERVICE_PLAN, PRODUCT) are TEST_ONLY key-only fixtures with key rows only. No inventory, PT, check-in, payroll or other member data is generated.

## Files

| File | Role |
|---|---|
| `db/seed/S001__p3_dataset_generator.sql` | Generator (S001 v1.0). Writes only the four P3 tables; creates only `#temp` tables |
| `db/seed/profiles.json` | Dataset profiles DS-S (smoke, 7 days), DS-M (3 months), DS-L (12 months, full scale): generator parameters, runtime setting, validation tolerances |
| `tests/db/build/preflight_p2.sql` | Read-only instance and target checks |
| `tests/db/build/rebuild_p2_db.sql` | Builds `FitLife_P3_P2` from nothing: F001 (TEST_ONLY), V001, V002; drops an existing copy only if it carries the `WO-P3-P2-01` marker |
| `tests/db/build/drop_p2_db.sql` | Rollback: drops `FitLife_P3_P2` (marker-guarded) |
| `tests/db/build/fingerprint_instance.sql` | Read-only fingerprint of the other databases, compared before and after a run |
| `tests/db/fixtures/F001D__TEST_ONLY_fixture_key_rows.sql` | Key rows for the five fixtures |
| `tests/db/seed/T-SEED_dataset_checks.sql` | T-SEED-01…05, V-TOT, T-REC-01, T-REC-02; row-count, distribution and storage reports |
| `tests/db/seed/T-REPRO-02_checksums.sql` | Per-table SHA-256 and dataset checksum |
| `tests/db/seed/run_p2_dataset.ps1` | Runs all of the above in order and writes the run log, checksums and manifest |

## Reproduce

Requirements: the local SQL Server instance (Windows authentication, Developer edition, compatibility level 160 available), `sqlcmd`, Windows PowerShell 5.1. Nothing is installed.

```text
powershell -NoProfile -ExecutionPolicy Bypass -File tests/db/seed/run_p2_dataset.ps1 -Dataset DS-S -RunLabel A
powershell -NoProfile -ExecutionPolicy Bypass -File tests/db/seed/run_p2_dataset.ps1 -Dataset DS-L -RunLabel B -CompareWith docs/phase2/person3/evidence/test-results/CHECKSUMS__DS-L__<timestamp>_A.txt
```

Each run rebuilds `FitLife_P3_P2`, so the database holds one dataset at a time. Use `-EvidenceDir <folder>` for trial runs outside the evidence folder. The same seed and profile always give byte-identical checksum output.

## Method (summary)

- Every pseudo-random value is a 4-byte slice of SHA-256(seed : stream : key); keys are the local date and the invoice number in that day, the member key, or the invoice and line number. No `NEWID()`, `RAND()` or clock values in the data.
- 27,000 invoices per complete calendar month (Phase 1: 900 per day × 30), spread over the days with day-of-week weights; timestamps generated on the Asia/Ho_Chi_Minh calendar and stored in UTC (D-014).
- Header totals are computed from the lines (D-023); payment states follow D-005; MEMBER_MONTHLY_SPENDING is aggregated from PAID invoices by local month of `PaidAt` with `PointsEarned = FLOOR(TotalSpend / 100000)` (D-006, D-013).
- All parameters and their basis: [10 §3.4](../../docs/phase2/person3/10_SEED_AND_BENCHMARK_PLAN.md#34-distributions-and-parameters-approved-with-d-022-on-2026-11-08-implemented-in-s001-v10).
- `MaxGrantPercent` caps memory grants so the scripts also run when the instance is short of memory (R-27); it never changes the data.
