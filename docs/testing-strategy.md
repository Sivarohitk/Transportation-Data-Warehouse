# Testing Strategy

## Purpose

The SQL test layer is designed to validate the existing source, staging, warehouse, incremental, and reporting flow without introducing a second testing framework.

The project uses two testing levels:

- quick smoke tests under [tests/sql/01_smoke_tests.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\01_smoke_tests.sql)
- deeper domain checks under the rest of [tests/sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql) plus the report-style dashboard in [sql/04_tests/00_data_quality_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\sql\04_tests\00_data_quality_checks.sql)

## Test Layout

- [tests/sql/01_smoke_tests.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\01_smoke_tests.sql)
  Quick fail-fast checks after a load.
- [tests/sql/02_row_count_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\02_row_count_checks.sql)
  Stage-to-dimension and stage-to-fact reconciliation for the latest successful batch.
- [tests/sql/03_referential_integrity_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\03_referential_integrity_checks.sql)
  Required-field, date-sequence, lookup, orphan-fact, and unknown-member checks.
- [tests/sql/04_incremental_load_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\04_incremental_load_checks.sql)
  Batch audit, watermark, restatement, and optional rerun-probe checks.
- [tests/sql/05_reporting_view_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\05_reporting_view_checks.sql)
  Reporting-view existence, KPI sanity, and aggregate reconciliation checks.
- [sql/04_tests/00_data_quality_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\sql\04_tests\00_data_quality_checks.sql)
  Demo-friendly report script for browsing validation results and current data quality status.

## Coverage Matrix

| Test Area | Primary Script | What It Checks | Expected Success Condition | Likely Failure Meaning | Best Run Timing |
|---|---|---|---|---|---|
| Row count reconciliation | `tests/sql/02_row_count_checks.sql` | Distinct valid stage business keys match warehouse rows for carriers, locations, routes, shipment statuses, shipments, events, and exceptions | Stage distinct counts equal matched warehouse counts | Load procedure missed valid rows, join logic failed, or dimensional mastering is incomplete | Initial and incremental |
| Null checks on required fields | `tests/sql/01_smoke_tests.sql`, `tests/sql/03_referential_integrity_checks.sql` | Required warehouse columns are populated | No nulls in required dimension or fact columns | Broken load mapping, failed standardization, or incomplete source records bypassed validation | Initial and incremental |
| Duplicate business keys | `tests/sql/01_smoke_tests.sql` | Unique business-key grain is preserved in shipment, event, and exception facts | No duplicate shipment numbers, event keys, or exception keys | Merge grain is wrong or deduplication logic regressed | Initial and incremental |
| Invalid date and event sequences | `tests/sql/01_smoke_tests.sql`, `tests/sql/03_referential_integrity_checks.sql` | Pickup and delivery dates are ordered correctly and event timestamps do not go backwards by sequence | No negative transit metrics and no decreasing event timeline | Delivery KPI derivation or status-history handling is wrong | Initial and incremental |
| Missing dimension lookups | `tests/sql/03_referential_integrity_checks.sql` | Fact keys resolve to dimensions; unknown-member usage is surfaced separately | No missing dimension joins; unknown-member counts are reviewable | Broken dimension load, late-arriving dimension problem, or bad fact lookup logic | Initial and incremental |
| Orphan facts | `tests/sql/01_smoke_tests.sql`, `tests/sql/03_referential_integrity_checks.sql` | Event and exception facts still resolve to shipment facts | No orphan delivery events or exceptions | Shipment load failed before dependent facts or referential logic regressed | Initial and incremental |
| Rejected records summary | `sql/04_tests/00_data_quality_checks.sql` | Latest rejects by source table, rule, and reason | Reject counts are explainable and aligned to validation intent | Feed quality problem or unexpected validation spike | Initial and incremental |
| Incremental load audit validation | `tests/sql/04_incremental_load_checks.sql` | Batch counts, audit step coverage, watermark promotion, and file watermark coverage | Latest batch counts reconcile and required steps succeeded | Batch runner, load audit, or watermark promotion logic regressed | Incremental, but still valid after initial |
| Rerun and idempotency validation | `tests/sql/04_incremental_load_checks.sql` | Optional rerun probe executes `etl.usp_Run_Incremental_Load` inside a rollback transaction and checks for no new inserts or updates | Rerun produces no new fact rows and no new non-zero merge counts | Conditional merge logic regressed or same-batch reruns are no longer safe | Incremental rerun testing |
| Shipment restatement after event-only or exception-only changes | `tests/sql/01_smoke_tests.sql`, `tests/sql/04_incremental_load_checks.sql` | Shipments affected only by stage events or exceptions still resolve to `dw.FactShipment` and have updated counts and flags | Event-only and exception-only shipments are reflected in shipment KPIs | Impacted-shipment restatement logic regressed | Incremental only |
| Reporting view validation | `tests/sql/05_reporting_view_checks.sql` | Reporting views exist, return rows, and reconcile to fact totals | View totals match fact totals and KPI percentages stay within valid ranges | Broken view logic, unexpected nulls, or measure derivation errors | Initial and incremental |

## How To Run

Recommended order:

1. [tests/sql/01_smoke_tests.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\01_smoke_tests.sql)
2. [tests/sql/02_row_count_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\02_row_count_checks.sql)
3. [tests/sql/03_referential_integrity_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\03_referential_integrity_checks.sql)
4. [tests/sql/04_incremental_load_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\04_incremental_load_checks.sql)
5. [tests/sql/05_reporting_view_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\05_reporting_view_checks.sql)
6. [sql/04_tests/00_data_quality_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\sql\04_tests\00_data_quality_checks.sql) for the human-readable report

## Demo Guidance

For demos and interviews:

- run the smoke tests first to show the warehouse is sound
- run the incremental checks after a later batch or rerun scenario
- finish with the report-style data-quality script to show reject patterns, watermark state, reconciliation, and reporting-view samples

## Current Boundary

This testing layer validates the SQL implementation thoroughly, but it does not replace:

- manual SSDT package execution tests
- SSIS catalog deployment tests
- Power BI semantic-model and dashboard validation
