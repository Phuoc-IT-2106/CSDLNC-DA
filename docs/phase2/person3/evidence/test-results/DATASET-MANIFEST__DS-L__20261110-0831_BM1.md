# Dataset manifest - DS-L, run BM1

| Field | Value |
|---|---|
| Work order | WO-P3-P2-01 (BUILD_AUTHORIZED) |
| Run (UTC) | 20261110-0831 |
| Purpose | Full benchmark scale: 12 complete calendar months (January-December 2025) |
| Target database | FitLife_P3_P2 (isolated, disposable; P3_Disposable marker WO-P3-P2-01) |
| Instance | local default instance, Windows authentication (identity in the run log, step 1) |
| Generator | S001 v1.0 (set-based T-SQL; SHA-256 seeded streams) |
| Overall result | **PASS** |
| Run log | P2-RUN__DS-L__20261110-0831_BM1.txt |
| Checksums | CHECKSUMS__DS-L__20261110-0831_BM1.txt |

## Parameters

| Parameter | Value |
|---|---|
| Seed | 20261108 |
| StartDateLocal | 2025-01-01 |
| EndDateLocal | 2026-01-01 |
| InvoicesPerMonth | 27000 |
| MemberCount | 30000 |
| BranchCount | 12 |
| EmployeesPerBranch | 10 |
| PlanCount | 30 |
| ProductCount | 200 |
| ServiceInvoiceShare | 0.20 |
| CancelledShare | 0.02 |
| PendingWindowDays | 3 |
| PendingShareInWindow | 0.30 |
| HeavyMemberShare | 0.20 |
| HeavyInvoiceShare | 0.60 |
| HomeBranchShare | 0.85 |
| DiscountLineShare | 0.20 |
| PeakShare | 0.35 |
| (runtime) MaxGrantPercent | 2 |
| (validation) CountTolerancePct | 2 |
| (validation) DistTolerancePP | 2 |
| (validation) LinesMeanTolerance | 0.05 |
| (validation) Demo70k | 2 |
| (validation) SkewCheck | 1 |

## Results

| Step | Result |
|---|---|
| preflight | PASS |
| build | OK |
| fixture_rows | OK |
| generator | OK |
| T-SCH-02 | PASS |
| T-SEED | PASS |
| checksums | OK |
| other_databases_unchanged | PASS |
| T-REPRO-02 vs CHECKSUMS__DS-L__20261108-1155_C.txt | PASS |

## Timings (ms, wall clock of each sqlcmd call)

| Step | ms |
|---|---|
| 1 preflight (read-only) | 119 |
| 2 instance fingerprint before | 142 |
| 3 rebuild FitLife_P3_P2 (F001 TEST_ONLY, V001, V002) | 269 |
| 4 F001D fixture key rows (TEST_ONLY) | 126 |
| 5 S001 generator | 31347 |
| 6 T-SCH-02 conformance on the seeded database | 963 |
| 7 T-SEED dataset checks | 11303 |
| 8 T-REPRO-02 checksums | 11078 |
| 9 instance fingerprint after | 142 |
| (generator) step=calendar_members_prices ms=583 |  |
| (generator) step=invoice_headers ms=16934 |  |
| (generator) step=invoice_lines ms=5120 |  |
| (generator) step=load_invoice_tables ms=7595 |  |
| (generator) step=monthly_spending ms=934 |  |
| (generator) step=total_generator ms=31166 |  |

## Row counts and checksums

```text
tbl|row_count|sha256
---|---------|------
INVOICE|324000|B321C5C8E689358C865EDA03B5D98BFF2DA8F92248CB5CEEDEC82E5E853A4FB7
INVOICE_SERVICE_ITEM|65177|F087DEEB3C1FAA14D80ACC396B133F1DDAE5A63B5C6E20E4B09049FC8F6C8281
INVOICE_PRODUCT_ITEM|712789|EC62F651B28F857F648A5C394ACFE48B1D32921396E36F83653817A4EEA4CBF1
MEMBER_MONTHLY_SPENDING|169040|D25C9C8EFC99AE2C1782CC4A49800862E9BF117E51E34E62DCDBA4CF938E7BFC
MEMBER (TEST_ONLY keys)|30000|B876C95BA3DFAF2B11377790815E242164DE5963E015BD5BBB7793D5DFC6E062
BRANCH (TEST_ONLY keys)|12|7909937ABE135B51143FAF006BA1713D4C139E3337325AD10F9B81807CD66786
EMPLOYEE (TEST_ONLY keys)|120|1C4732EAF0B754EF54C34467457CBBE4D233B277B73E72505AAEF7DBB4C5BD08
SERVICE_PLAN (TEST_ONLY keys)|30|A8DA6DC1099B8B38805D26F04C1E8A49B9D3870506F9586535105A3C3BE64FDB
PRODUCT (TEST_ONLY keys)|200|2066223C021D5FE0C60E02FCC68BFE6F618DE108F9E5AFC21200D86B620C305B
item|sha256
----|------
DATASET_CHECKSUM|26ABB2776BD71C1347D2478D880B926FF35D8B6E7BA8F583D76E56D4DD82CA1F
```

## Script versions (SHA-256)

| File | SHA-256 |
|---|---|
| `db/seed/S001__p3_dataset_generator.sql` | `2bb5a101c5382aaca945e90fb8f52417308cd2b647ac6676310047b77d690ff5` |
| `db/seed/profiles.json` | `415583893eb48dbf1347da02b2b4efbfe937b6323b7cdcda1bf3fa3d950a6f3e` |
| `tests/db/fixtures/F001D__TEST_ONLY_fixture_key_rows.sql` | `ca492a71edffca48580fb4b93ba68f245db3b19518a0846b204143063afaf112` |
| `tests/db/build/rebuild_p2_db.sql` | `19e96bb76d66f8d8fec06b06097b403e527344306d9577f3582be7ce7300d3c7` |
| `tests/db/fixtures/F001__TEST_ONLY_shared_dependency_keys.sql` | `193d855666e9a5047aafd871671f8a9ce8218805bd53752b3581c22d29536e72` |
| `db/migrations/V001__p3_billing_and_spending_tables.sql` | `65a31c124b57dea63d8998f59cf5fd4ab50df1875dfa87d6821ff270758b8094` |
| `db/migrations/V002__p3_settlement_and_spending_constraints.sql` | `adcf99e6d954a3202622b7bffb25358bfbe90c9c174cd871dd8b8459c5fafd67` |
| `tests/db/seed/T-SEED_dataset_checks.sql` | `f819c1e2c9325e9b05e7cb5e56cff03bf2d74f7340676f0060f3742fbb56c49b` |
| `tests/db/seed/T-REPRO-02_checksums.sql` | `d731f90c57f82553b4d1a292f1ec2f73ebda2b6ef722728c0a5526032acbaabe` |
| `tests/db/seed/run_p2_dataset.ps1` | `1c5c773e0885233297ef61a060fc23f25e4c1c0ac5e042d2ac875b73597284b6` |

## Reproduce

```text
powershell -NoProfile -ExecutionPolicy Bypass -File tests/db/seed/run_p2_dataset.ps1 -Dataset DS-L -RunLabel <label> -CompareWith <this run's CHECKSUMS file>
```
Same seed and profile give byte-identical checksum output (T-REPRO-02). Storage and distribution reports are in the run log, step 7.
