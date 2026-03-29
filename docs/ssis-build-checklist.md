# SSIS Build Checklist

## Goal

Build a single SSDT Integration Services project that matches the existing SQL repository without creating a second ETL framework.

## Before Opening SSDT

Confirm these are already working locally:

- SQL Server is installed and reachable
- `TransportationDW` can be created from [sql/99_run_all.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\sql\99_run_all.sql)
- source seed data has been loaded from [sql/source/02_seed_source_data.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\sql\source\02_seed_source_data.sql)
- raw CSV files exist under [data/raw](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\data\raw)

## Create The SSDT Project

1. Open Visual Studio 2022 with the SSIS Projects extension installed.
2. Create a new `Integration Services Project`.
3. Name the project `TransportationDW`.
4. Save the project under [ssis/TransportationDW](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\ssis\TransportationDW).
5. Use the Project Deployment Model.

## Create Project Parameters

Create these project parameters first:

- `pServerName`
- `pDatabaseName`
- `pRawFolder`
- `pErrorFolder`
- `pLoadMode`
- `pSourceName`
- `pBatchName`
- `pBatchNotes`

Recommended initial values:

- `pServerName = localhost`
- `pDatabaseName = TransportationDW`
- `pRawFolder = C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\data\raw`
- `pErrorFolder = C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\ssis\logs`
- `pLoadMode = FLAT_FILE`
- `pSourceName = RAW_CSV`

## Create Connection Managers

Create these project connection managers before building packages:

1. `CM_OLEDB_TransportationDW`
2. `CM_FF_CarrierLookup`
3. `CM_FF_Locations`
4. `CM_FF_Routes`
5. `CM_FF_Shipments`
6. `CM_FF_DeliveryScanEvents`
7. `CM_FF_DeliveryExceptions`
8. `CM_FF_ExceptionCodeLookup`
9. `CM_FF_RouteDistanceReference`

Each flat-file connection manager should point to a project-parameterized file path, not a hard-coded desktop path.

## Recommended Build Order

1. Build `load_source_to_stage.dtsx`
2. Build `validate_stage_data.dtsx`
3. Build `load_dimensions.dtsx`
4. Build `load_facts.dtsx`
5. Build `incremental_daily_load.dtsx`

Reason:

- the stage package is the only complex data-flow package
- the validation and warehouse packages are mostly Execute SQL Task wrappers
- the daily package is easiest to wire last because it depends on the child package names and parameter mappings being stable

## Package Build Notes

### `load_source_to_stage.dtsx`

Build this package first.

Checklist:

- create `SQL_SOURCE` and `FLAT_FILE` sequence containers
- add one data flow per raw file
- set `BatchID`, `SourceName`, and `SourceFileName` in Derived Column transformations
- configure row counts on success and error paths
- add one Execute SQL Task after each flat-file load to call `etl.usp_Register_Flat_File_Stage_Load`
- for SQL mode, call `etl.usp_Load_Stage_From_Source` directly instead of rebuilding the query logic in SSIS

### `validate_stage_data.dtsx`

Checklist:

- add Execute SQL Task for `etl.usp_Validate_Stage_Data`
- add Execute SQL Task to read reject count
- add precedence logic for warn or fail behavior

### `load_dimensions.dtsx`

Checklist:

- add Execute SQL Task for `etl.usp_Load_DimDate`
- add Execute SQL Task for `etl.usp_Load_Dimensions`
- add one summary query task for `audit.Load_Audit`

### `load_facts.dtsx`

Checklist:

- add Execute SQL Tasks for `etl.usp_Load_FactShipment`
- add Execute SQL Tasks for `etl.usp_Load_FactDeliveryEvent`
- add Execute SQL Tasks for `etl.usp_Load_FactDeliveryException`
- keep the same task order already used by `etl.usp_Run_Incremental_Load`

### `incremental_daily_load.dtsx`

Checklist:

- add Execute SQL Task for `meta.usp_Start_Batch`
- store returned `BatchID` in `User::BatchID`
- add Execute Package Task for `load_source_to_stage.dtsx`
- add Execute SQL Task for `etl.usp_Run_Incremental_Load`
- add failure path Execute SQL Task for `meta.usp_End_Batch` only when batch status is still `STARTED`
- add summary query tasks for batch, audit, and reject counts

## Logging Checklist

Enable SSIS logging in addition to the SQL audit tables.

Recommended:

- SSIS catalog reporting if deploying to SSISDB
- package `OnError` and `OnWarning` event handlers
- exported execution report screenshots stored under [ssis/logs](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\ssis\logs)

Do not try to mirror `audit.Load_Audit` inside SSIS with another custom logging table. The SQL model already does that.

## Testing Checklist

Flat-file path:

1. Start a batch in SSMS.
2. Run `load_source_to_stage.dtsx` in `FLAT_FILE` mode.
3. Confirm rows landed in `stg.*`.
4. Confirm file entries were written to `meta.Source_File_Log`.
5. Run `validate_stage_data.dtsx`.
6. Review `audit.Stage_Row_Reject`.
7. Run `etl.usp_Run_Incremental_Load` from SSMS or the daily package.

SQL-source path:

1. Start a batch in SSMS.
2. Run `load_source_to_stage.dtsx` in `SQL_SOURCE` mode.
3. Confirm `audit.Load_Audit` and `meta.Watermark` pending rows exist.
4. Run `incremental_daily_load.dtsx` or `etl.usp_Run_Incremental_Load`.
5. Confirm watermarks are promoted and facts are updated.

Rerun safety:

1. Re-run the same batch through `etl.usp_Run_Incremental_Load`.
2. Confirm no duplicate warehouse rows appear.
3. Confirm update counts do not inflate when nothing changed.

## Deployment Checklist

Recommended deployment target:

- SSISDB with environments for `DEV` and `LOCAL_DEMO`

Recommended environment variables:

- server name
- database name
- raw folder
- error folder
- source name
- load mode

## What To Avoid

- Do not move business rules into Script Components.
- Do not create separate SSIS-only watermark tables.
- Do not duplicate `etl.usp_Run_Incremental_Load` logic in control flow.
- Do not let package names drift from the documentation.

## Source Of Truth

For package behavior, use:

- [docs/ssis-package-design.md](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\docs\ssis-package-design.md)
- [docs/staging-design.md](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\docs\staging-design.md)
- [docs/business-rules.md](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\docs\business-rules.md)
- [docs/incremental-load-design.md](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\docs\incremental-load-design.md)
