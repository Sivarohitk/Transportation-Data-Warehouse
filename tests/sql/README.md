# SQL Test Folder

This folder stores runnable SQL validation scripts for the warehouse after an initial or incremental load.

Current layout:

- `01_smoke_tests.sql`
  Quick fail-fast validation for unknown members, duplicates, key business rules, watermarks, and restatement safety.
- `02_row_count_checks.sql`
  Row-count reconciliation from valid stage business keys to dimensions and facts.
- `03_referential_integrity_checks.sql`
  Required-field, date-sequence, lookup, orphan-fact, and unknown-member checks.
- `04_incremental_load_checks.sql`
  Batch audit, watermark, rerun-safety, and shipment-restatement checks.
- `05_reporting_view_checks.sql`
  Reporting-view existence, aggregate reconciliation, and KPI sanity checks.

Run these with `sqlcmd` after a warehouse load. Use `01_smoke_tests.sql` first.
