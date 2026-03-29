# Staging Design

## Purpose

The `stg` schema is the controlled landing area between the source system and the dimensional warehouse. It preserves raw business keys, keeps source-specific context for troubleshooting, and gives SSIS a stable set of batch-aware target tables.

This repo now supports two stage-load paths:

- Relational extracts from the `src` schema by using `etl.usp_Load_Stage_From_Source`
- Flat-file loads from `data/raw` through SSIS data flows into the same `stg` tables

## Reused Assets

The staging design reuses the metadata and orchestration patterns already in the repo:

- `meta.Batch_Run` for batch control
- `meta.Source_File_Log` for source feed logging
- `meta.Watermark` for incremental source extracts
- `audit.Load_Audit` for step-level ETL auditing
- `audit.Validation_Error` for rule-level validation failures
- `etl.usp_Validate_Stage_Data` as the main stage validation entry point

The main refinement was to expand those assets to cover all staging entities instead of introducing a second staging framework.

## Stage Tables

The stage layer uses one raw table per inbound entity or lookup:

- `stg.Carrier_Raw`
- `stg.Location_Raw`
- `stg.Route_Raw`
- `stg.Shipment_Raw`
- `stg.Shipment_Status_History_Raw`
- `stg.Delivery_Exception_Raw`
- `stg.Exception_Code_Lookup_Raw`
- `stg.Route_Distance_Reference_Raw`

Each table preserves the original business keys and includes:

- `BatchID`
- `SourceName`
- `SourceFileName`
- `SourceLoadedAt`
- `IsValid`
- `ValidationStatus`
- `RejectionReason`

## Feed Strategy

| Feed | Stage Table | Load Pattern | Incremental Candidate |
|---|---|---|---|
| `src.Carrier` or `carrier_lookup.csv` | `stg.Carrier_Raw` | Full snapshot | No |
| `src.Location` or `locations.csv` | `stg.Location_Raw` | Full snapshot | No |
| `src.Route` or `routes.csv` | `stg.Route_Raw` | Full snapshot | No |
| `src.Shipment` or `shipments.csv` | `stg.Shipment_Raw` | Delta by source timestamp | Yes |
| `src.Shipment_Status_History` or `daily_delivery_scan_events.csv` | `stg.Shipment_Status_History_Raw` | Delta by event timestamp | Yes |
| `src.Delivery_Exception` or `delivery_exceptions.csv` | `stg.Delivery_Exception_Raw` | Delta by exception timestamp | Yes |
| `exception_code_lookup.csv` | `stg.Exception_Code_Lookup_Raw` | Full lookup refresh | No |
| `route_distance_reference.csv` | `stg.Route_Distance_Reference_Raw` | Full lookup refresh | No |

## Relational Vs Flat-File Loads

### SQL source path

Use `etl.usp_Load_Stage_From_Source` when loading directly from the normalized `src` schema.

Behavior:

- Resets the current batch's stage rows before reloading
- Loads full snapshots for carriers, locations, routes, exception lookup, and route distance reference
- Loads incremental rows for shipments, scan history, and delivery exceptions by reading `meta.Watermark`
- Writes source load entries into `meta.Source_File_Log` with `SourceType = 'SQL_SERVER'`
- Optionally runs `etl.usp_Validate_Stage_Data`

### Flat-file path

Use SSIS flat-file data flows to land the CSV feeds from `data/raw` into the same `stg` tables.

Behavior:

- SSIS maps raw CSV columns directly to stage columns and supplies the shared `BatchID`
- `SourceName` should identify the feed, such as `RAW_CSV`
- `SourceFileName` should capture the actual CSV file name
- After each file load, call `etl.usp_Register_Flat_File_Stage_Load`
- After all files for the batch are landed, call `etl.usp_Validate_Stage_Data`

## Reject And Audit Flow

Validation runs through `etl.usp_Validate_Stage_Data`.

Rule failures are first written to `audit.Validation_Error` with the batch, source table, business key, and rule metadata.

Row-level rejects are then summarized into `audit.Stage_Row_Reject` by `audit.usp_Sync_Stage_Rejections`. That same step also writes the aggregated rejection text back to each failed stage row in `RejectionReason`.

This gives three useful views of bad data:

- Rule-by-rule failure detail in `audit.Validation_Error`
- One reject row per failed stage record in `audit.Stage_Row_Reject`
- Inline row status in the `stg` tables through `IsValid`, `ValidationStatus`, and `RejectionReason`

## Reset And Reload Pattern

`etl.usp_Reset_Stage_Tables` clears either:

- One batch at a time, which is the normal rerun pattern
- All stage data, when called with `@BatchID = NULL`

Deletes are used instead of `TRUNCATE TABLE` because the stage tables are batch-aware and linked to metadata.

## SSIS Implementation Notes

The current staging design is SSIS-friendly because:

- All stage tables are append-by-batch targets
- Raw business keys are preserved without early surrogate-key lookups
- Reject handling stays in SQL Server, not only inside package data viewers
- Full-load and incremental-load behavior is explicit before warehouse loads start

## Current Boundary

The staging layer is now ready for dimensional loads, but the actual SSIS packages and control-flow orchestration still need to be built in SSDT.

## Validation Coverage

- Stage-to-warehouse reconciliation is covered by [tests/sql/02_row_count_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\02_row_count_checks.sql).
- Reject summaries and validation-detail reporting are exposed in [sql/04_tests/00_data_quality_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\sql\04_tests\00_data_quality_checks.sql).


