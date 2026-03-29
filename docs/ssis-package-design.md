# SSIS Package Design

## Purpose

This document defines the SSDT package design for the existing Transportation Data Warehouse repository.

The design intentionally reuses the current SQL Server ETL framework instead of moving business logic into SSIS script tasks or duplicate package-only transformations.

## Design Principles

- `incremental_daily_load.dtsx` is the primary end-to-end package for demos and scheduled runs.
- `load_source_to_stage.dtsx` is the only package that should contain meaningful row-by-row data flows.
- Validation, dimensional transformations, fact loading, watermark promotion, restatement, and audit logging stay in the existing T-SQL procedures.
- `validate_stage_data.dtsx`, `load_dimensions.dtsx`, and `load_facts.dtsx` are still useful as reusable development and demo packages, but the production daily flow should continue to call `etl.usp_Run_Incremental_Load`.
- Flat-file parsing errors are handled in SSIS error outputs.
- Business-rule rejects remain in SQL Server through `audit.Validation_Error` and `audit.Stage_Row_Reject`.

## Manual In SSDT Vs SQL-Driven

Manual in SSDT:

- Create the SSIS project and packages.
- Configure connection managers and package parameters.
- Build the flat-file data flows for `data/raw`.
- Map package variables to Execute SQL Task parameters.
- Add row counts, error redirection, and package logging.
- Configure Execute Package Tasks inside the master package.

Already handled in SQL Server:

- `meta.Batch_Run` batch control
- `meta.Watermark` pending and successful watermarks
- `meta.Source_File_Log` file registration and source load logging
- `etl.usp_Load_Stage_From_Source`
- `etl.usp_Validate_Stage_Data`
- `etl.usp_Load_DimDate`
- `etl.usp_Load_Dimensions`
- `etl.usp_Load_FactShipment`
- `etl.usp_Load_FactDeliveryEvent`
- `etl.usp_Load_FactDeliveryException`
- `etl.usp_Run_Incremental_Load`
- `audit.Load_Audit`, `audit.Validation_Error`, `audit.Stage_Row_Reject`, and `audit.Error_Log`

## Package To Procedure Mapping

| Package | Primary Use | Stored Procedures Called | Notes |
|---|---|---|---|
| `load_source_to_stage.dtsx` | Stage landing | `etl.usp_Load_Stage_From_Source` for SQL mode, `etl.usp_Reset_Stage_Tables` and `etl.usp_Register_Flat_File_Stage_Load` for flat-file mode | Only package with real data flows |
| `validate_stage_data.dtsx` | Validation checkpoint | `etl.usp_Validate_Stage_Data` | Mostly for flat-file runs and demos |
| `load_dimensions.dtsx` | Dimension-only reload | `etl.usp_Load_DimDate`, `etl.usp_Load_Dimensions` | Useful for isolated reruns |
| `load_facts.dtsx` | Fact-only reload | `etl.usp_Load_FactShipment`, `etl.usp_Load_FactDeliveryEvent`, `etl.usp_Load_FactDeliveryException` | Useful for isolated reruns |
| `incremental_daily_load.dtsx` | Main orchestration | `meta.usp_Start_Batch`, `etl.usp_Run_Incremental_Load`, `meta.usp_End_Batch` on package-level failure only | Keep this as the main walkthrough package |

## Shared Connection Managers

Use project-level connection managers where possible.

| Connection Manager | Type | Purpose |
|---|---|---|
| `CM_OLEDB_TransportationDW` | OLE DB | Main connection to `TransportationDW` for `src`, `stg`, `dw`, `meta`, `audit`, and `etl` |
| `CM_FF_CarrierLookup` | Flat File | `data/raw/carrier_lookup.csv` |
| `CM_FF_Locations` | Flat File | `data/raw/locations.csv` |
| `CM_FF_Routes` | Flat File | `data/raw/routes.csv` |
| `CM_FF_Shipments` | Flat File | `data/raw/shipments.csv` |
| `CM_FF_DeliveryScanEvents` | Flat File | `data/raw/daily_delivery_scan_events.csv` |
| `CM_FF_DeliveryExceptions` | Flat File | `data/raw/delivery_exceptions.csv` |
| `CM_FF_ExceptionCodeLookup` | Flat File | `data/raw/exception_code_lookup.csv` |
| `CM_FF_RouteDistanceReference` | Flat File | `data/raw/route_distance_reference.csv` |

For this repo, a separate SQL source connection manager is optional because the `src` schema is already built inside the same `TransportationDW` database. If you later split source and warehouse databases, add `CM_OLEDB_SourceOLTP` and keep package logic unchanged.

## Shared Project Parameters

Recommended project parameters:

- `pServerName`
- `pDatabaseName`
- `pRawFolder`
- `pErrorFolder`
- `pLoadMode`
- `pSourceName`
- `pBatchName`
- `pBatchNotes`

Recommended `pLoadMode` values:

- `SQL_SOURCE`
- `FLAT_FILE`

Recommended `pSourceName` values:

- `SRC_OLTP`
- `RAW_CSV`

## Package Design

### `load_source_to_stage.dtsx`

#### Purpose

Land source data into the `stg` schema for a supplied `BatchID`.

This package supports two distinct modes:

- direct SQL-source extraction from `src.*`
- flat-file ingestion from `data/raw/*.csv`

#### Control Flow

Recommended control flow:

1. `SC_SQL_Source_Load`
2. `SC_Flat_File_Loads`

Use precedence constraints with expressions so only one container runs:

- `@[$Package::pLoadMode] == "SQL_SOURCE"`
- `@[$Package::pLoadMode] == "FLAT_FILE"`

Inside `SC_SQL_Source_Load`:

1. `EST_Load_Stage_From_Source`
   - Execute:
   ```sql
   EXEC etl.usp_Load_Stage_From_Source
       @BatchID = ?,
       @SourceName = ?,
       @RunValidation = 0;
   ```

Inside `SC_Flat_File_Loads`:

1. `EST_Reset_Batch_Stage`
   - Execute:
   ```sql
   EXEC etl.usp_Reset_Stage_Tables @BatchID = ?;
   ```
2. `DFT_Load_Carrier_Lookup`
3. `EST_Log_Carrier_Lookup`
4. `DFT_Load_Locations`
5. `EST_Log_Locations`
6. `DFT_Load_Routes`
7. `EST_Log_Routes`
8. `DFT_Load_Exception_Code_Lookup`
9. `EST_Log_Exception_Code_Lookup`
10. `DFT_Load_Route_Distance_Reference`
11. `EST_Log_Route_Distance_Reference`
12. `DFT_Load_Shipments`
13. `EST_Log_Shipments`
14. `DFT_Load_Daily_Delivery_Scan_Events`
15. `EST_Log_Daily_Delivery_Scan_Events`
16. `DFT_Load_Delivery_Exceptions`
17. `EST_Log_Delivery_Exceptions`

Recommended load order:

- lookup and master-style feeds first
- shipment master next
- shipment events and exceptions last

That ordering keeps flat-file batches aligned with later validation rules that check shipment existence.

#### Data Flow

Use one data flow per file. Keep transformations thin.

Common pattern:

1. Flat File Source
2. Derived Column
3. Data Conversion where needed
4. Conditional Split for obviously unusable file rows
5. Row Count on success path
6. OLE DB Destination to matching `stg` table
7. Error output redirected to a batch-specific CSV in `ssis/logs`
8. Row Count on error path

Feed-to-table mapping:

| Flat File | Destination Table |
|---|---|
| `carrier_lookup.csv` | `stg.Carrier_Raw` |
| `locations.csv` | `stg.Location_Raw` |
| `routes.csv` | `stg.Route_Raw` |
| `exception_code_lookup.csv` | `stg.Exception_Code_Lookup_Raw` |
| `route_distance_reference.csv` | `stg.Route_Distance_Reference_Raw` |
| `shipments.csv` | `stg.Shipment_Raw` |
| `daily_delivery_scan_events.csv` | `stg.Shipment_Status_History_Raw` |
| `delivery_exceptions.csv` | `stg.Delivery_Exception_Raw` |

Derived columns to set on every stage row:

- `BatchID`
- `SourceName`
- `SourceFileName`
- `SourceLoadedAt` only if you choose to override the table default

Keep business-key standardization out of SSIS. The warehouse procedures already trim and standardize keys before dimensional joins.

#### Connection Managers

- `CM_OLEDB_TransportationDW`
- All eight flat-file connection managers listed above

#### Package Parameters

- `pBatchID`
- `pLoadMode`
- `pSourceName`
- `pRawFolder`
- `pErrorFolder`

Recommended defaults:

- `pLoadMode = FLAT_FILE`
- `pSourceName = RAW_CSV`

#### Variables

- `User::BatchID`
- `User::RowsLoaded_CarrierLookup`
- `User::RowsRejected_CarrierLookup`
- `User::RowsLoaded_Locations`
- `User::RowsRejected_Locations`
- `User::RowsLoaded_Routes`
- `User::RowsRejected_Routes`
- `User::RowsLoaded_ExceptionCodeLookup`
- `User::RowsRejected_ExceptionCodeLookup`
- `User::RowsLoaded_RouteDistanceReference`
- `User::RowsRejected_RouteDistanceReference`
- `User::RowsLoaded_Shipments`
- `User::RowsRejected_Shipments`
- `User::RowsLoaded_DeliveryScanEvents`
- `User::RowsRejected_DeliveryScanEvents`
- `User::RowsLoaded_DeliveryExceptions`
- `User::RowsRejected_DeliveryExceptions`

#### Lookup Transformations

Default recommendation:

- no row-level business lookups inside SSIS

Reason:

- route, carrier, location, shipment, exception, and status lookups are already implemented in SQL validation and warehouse load procedures
- keeping those lookups in SQL makes the package easier to explain and rerun

Optional control-flow lookup:

- before a flat-file data flow, execute a lightweight SQL check against `meta.Source_File_Log` to show whether the same `BatchID + SourceObjectName + FileName` has already been logged

#### Conditional Split Logic

Use Conditional Split only for file-quality issues that should not reach SQL Server:

- blank trailer rows
- header rows accidentally included as data
- rows where the primary business key column is empty

Recommended primary business key by feed:

- carriers: `CarrierCode`
- locations: `LocationCode`
- routes: `RouteCode`
- shipments: `ShipmentNumber`
- scan events: `ShipmentNumber + EventSequenceNumber`
- delivery exceptions: `ShipmentNumber + ExceptionCode + ExceptionDateTime`
- exception lookup: `ExceptionCode`
- route distance reference: `RouteCode + OriginLocationCode + DestinationLocationCode`

Do not duplicate semantic validation in the package. Cross-row and cross-table rules still belong in `etl.usp_Validate_Stage_Data`.

#### Error Outputs

Use SSIS error outputs for:

- bad file formats
- date conversion failures
- numeric conversion failures
- truncation risks

Write those rows to:

- `ssis/logs/load_source_to_stage/<feed>_error_rows_<BatchID>.csv`

This package should still log file-level counts with `etl.usp_Register_Flat_File_Stage_Load`.

Semantic rejects are not handled here. They are written later to:

- `audit.Validation_Error`
- `audit.Stage_Row_Reject`

#### Logging And Auditing

SQL-source mode:

- all load auditing is already handled by `etl.usp_Load_Stage_From_Source`
- the procedure writes to `audit.Load_Audit`, `meta.Source_File_Log`, and pending watermarks in `meta.Watermark`

Flat-file mode:

- use Row Count transforms for rows received, loaded, and redirected
- after each file load, call:
  ```sql
  EXEC etl.usp_Register_Flat_File_Stage_Load
      @BatchID = ?,
      @SourceObjectName = ?,
      @FileName = ?,
      @RowsReceived = ?,
      @RowsLoaded = ?,
      @RowsRejected = ?,
      @LoadStatus = ?,
      @FileModifiedAt = ?,
      @Message = ?;
  ```

#### Stored Procedures Called

- `etl.usp_Load_Stage_From_Source`
- `etl.usp_Reset_Stage_Tables`
- `etl.usp_Register_Flat_File_Stage_Load`

#### Expected Source And Destination Tables

SQL-source mode:

- source tables: `src.Carrier`, `src.Location`, `src.Route`, `src.Shipment`, `src.Shipment_Status_History`, `src.Delivery_Exception`
- destination tables: all `stg.*_Raw` tables

Flat-file mode:

- source files: `data/raw/*.csv`
- destination tables: all `stg.*_Raw` tables

#### Portfolio Screens

- Full control flow with separate `SQL_SOURCE` and `FLAT_FILE` containers
- One data flow screenshot for `daily_delivery_scan_events.csv`
- One Execute SQL Task editor screenshot for `etl.usp_Register_Flat_File_Stage_Load`
- One connection manager screenshot showing project parameterized file paths

### `validate_stage_data.dtsx`

#### Purpose

Run stage validation explicitly for a batch and expose rejects before warehouse loading.

This package is most useful for:

- flat-file loads
- demo walkthroughs
- isolated validation reruns during development

#### Control Flow

1. `EST_Validate_Stage_Data`
   - Execute:
   ```sql
   EXEC etl.usp_Validate_Stage_Data @BatchID = ?;
   ```
2. `EST_Get_Reject_Count`
   - Query `audit.Stage_Row_Reject` for the batch
3. `EST_Get_Validation_Summary`
   - Query `audit.Validation_Error` grouped by source table and rule
4. Optional success or warning branch depending on reject count

#### Data Flow

- none

Validation is intentionally SQL-driven because the current repo already captures row-level reject reasons in the database.

#### Connection Managers

- `CM_OLEDB_TransportationDW`

#### Package Parameters

- `pBatchID`
- `pFailOnRejects`

#### Variables

- `User::BatchID`
- `User::RejectCount`
- `User::ValidationErrorCount`

#### Lookup Transformations

- none in SSIS

All validation lookups already happen inside `etl.usp_Validate_Stage_Data` against `stg`, `dw`, and `audit`.

#### Conditional Split Logic

Use control-flow expressions after `EST_Get_Reject_Count`:

- continue when `User::RejectCount == 0`
- warn or fail when `User::RejectCount > 0` and `pFailOnRejects = True`

#### Error Outputs

- no row-level SSIS error output
- procedure failures are logged to `audit.Error_Log`
- package failures should still surface in SSIS catalog execution reports

#### Logging And Auditing

- procedure writes to `audit.Load_Audit`
- rule failures write to `audit.Validation_Error`
- consolidated row rejects write to `audit.Stage_Row_Reject`
- stage row status is updated in-place through `IsValid`, `ValidationStatus`, and `RejectionReason`

#### Stored Procedures Called

- `etl.usp_Validate_Stage_Data`

#### Expected Source And Destination Tables

Reads:

- all `stg.*_Raw` tables for the supplied batch

Writes:

- `audit.Load_Audit`
- `audit.Validation_Error`
- `audit.Stage_Row_Reject`
- `stg.*_Raw` validation columns

#### Portfolio Screens

- Control flow with validate and reject-summary tasks
- SSMS result grid for `audit.Stage_Row_Reject`
- SSMS result grid for `audit.Validation_Error` grouped by rule

### `load_dimensions.dtsx`

#### Purpose

Run dimensional loads only for an already staged batch.

This package is useful for:

- isolated development testing
- demo walkthroughs
- backfills when stage data already exists

#### Control Flow

1. `EST_Load_DimDate`
   - Execute:
   ```sql
   EXEC etl.usp_Load_DimDate @StartDate = ?, @EndDate = ?;
   ```
2. `EST_Load_Dimensions`
   - Execute:
   ```sql
   EXEC etl.usp_Load_Dimensions @BatchID = ?;
   ```
3. `EST_Read_Dimension_Audit`
   - Query latest `audit.Load_Audit` rows for the batch and dimension load step

#### Data Flow

- none

The dimension logic is already set-based and lookup-heavy in T-SQL, so SSIS should not duplicate it with row-by-row data flows.

#### Connection Managers

- `CM_OLEDB_TransportationDW`

#### Package Parameters

- `pBatchID`
- `pDimDateStart`
- `pDimDateEnd`

#### Variables

- `User::BatchID`
- `User::DimRowsInserted`
- `User::DimRowsUpdated`

#### Lookup Transformations

- none in SSIS

Dimension lookups and mastering already happen inside `etl.usp_Load_Dimensions`, including:

- route benchmark enrichment from `stg.Route_Distance_Reference_Raw`
- exception mastering from `stg.Exception_Code_Lookup_Raw`
- shipment status mastering from `stg.Shipment_Status_History_Raw`

#### Conditional Split Logic

- none

#### Error Outputs

- no SSIS row-level error output
- failures are logged through `audit.Error_Log`

#### Logging And Auditing

- `etl.usp_Load_Dimensions` writes step-level results to `audit.Load_Audit`
- merge insert and update counts are already recorded

#### Stored Procedures Called

- `etl.usp_Load_DimDate`
- `etl.usp_Load_Dimensions`

#### Expected Source And Destination Tables

Reads:

- `stg.Carrier_Raw`
- `stg.Location_Raw`
- `stg.Route_Raw`
- `stg.Exception_Code_Lookup_Raw`
- `stg.Route_Distance_Reference_Raw`
- `stg.Delivery_Exception_Raw`
- `stg.Shipment_Status_History_Raw`
- `stg.Shipment_Raw`

Writes:

- `dw.DimDate`
- `dw.DimCarrier`
- `dw.DimLocation`
- `dw.DimRoute`
- `dw.DimDeliveryException`
- `dw.DimShipmentStatus`

#### Portfolio Screens

- Control flow with two Execute SQL Tasks
- Audit query showing dimension insert and update counts
- SSMS screenshot of `dw.DimRoute` with benchmark columns populated

### `load_facts.dtsx`

#### Purpose

Run fact loads only for an already staged batch.

This package is best treated as a reusable support package, not the primary scheduled package.

#### Control Flow

1. `EST_Load_FactShipment`
   - Execute:
   ```sql
   EXEC etl.usp_Load_FactShipment @BatchID = ?;
   ```
2. `EST_Load_FactDeliveryEvent`
   - Execute:
   ```sql
   EXEC etl.usp_Load_FactDeliveryEvent @BatchID = ?;
   ```
3. `EST_Load_FactDeliveryException`
   - Execute:
   ```sql
   EXEC etl.usp_Load_FactDeliveryException @BatchID = ?;
   ```
4. `EST_Read_Fact_Audit`
   - Query `audit.Load_Audit` for the batch

Keep the same order already used by `etl.usp_Run_Incremental_Load`.

#### Data Flow

- none

Fact restatement, unknown member handling, and deduplication already live in the T-SQL procedures and should stay there.

#### Connection Managers

- `CM_OLEDB_TransportationDW`

#### Package Parameters

- `pBatchID`

#### Variables

- `User::BatchID`
- `User::FactRowsInserted`
- `User::FactRowsUpdated`

#### Lookup Transformations

- none in SSIS

Fact-level lookups to dimensions and unknown members already happen in SQL.

#### Conditional Split Logic

- none

#### Error Outputs

- no SSIS row-level error output
- failures are logged through `audit.Error_Log`

#### Logging And Auditing

- all three fact loaders write to `audit.Load_Audit`
- insert and update counts are already returned through SQL audit tables

#### Stored Procedures Called

- `etl.usp_Load_FactShipment`
- `etl.usp_Load_FactDeliveryEvent`
- `etl.usp_Load_FactDeliveryException`

#### Expected Source And Destination Tables

Reads:

- `stg.Shipment_Raw`
- `stg.Shipment_Status_History_Raw`
- `stg.Delivery_Exception_Raw`
- warehouse dimensions
- existing warehouse facts for rerun-safe restatement

Writes:

- `dw.FactShipment`
- `dw.FactDeliveryEvent`
- `dw.FactDeliveryException`

#### Portfolio Screens

- Control flow with the three fact tasks
- SSMS screenshot of `dw.FactShipment` showing `TransitDays`, `DeliveryDelayMinutes`, and `ExceptionShipmentFlag`
- SSMS screenshot of `dw.FactDeliveryEvent` showing event grain

### `incremental_daily_load.dtsx`

#### Purpose

This is the main orchestration package and the best package to use in an interview walkthrough.

It starts the batch, loads stage data, calls the existing SQL incremental runner, and captures end-of-run summaries without creating a second ETL framework.

#### Control Flow

Recommended control flow:

1. `EST_Start_Batch`
   - Execute:
   ```sql
   EXEC meta.usp_Start_Batch
       @BatchName = ?,
       @SourceName = ?,
       @Notes = ?,
       @BatchID = ? OUTPUT;
   ```
2. `EPT_Load_Source_To_Stage`
   - Execute child package `load_source_to_stage.dtsx`
   - Pass `pBatchID`, `pLoadMode`, `pSourceName`, `pRawFolder`, and `pErrorFolder`
3. `EST_Run_Incremental_Load`
   - Execute:
   ```sql
   EXEC etl.usp_Run_Incremental_Load
       @BatchID = ?,
       @Notes = ?;
   ```
4. `EST_Read_Batch_Summary`
   - Query `meta.Batch_Run`
5. `EST_Read_Load_Audit_Summary`
   - Query `audit.Load_Audit`
6. `EST_Read_Reject_Summary`
   - Query `audit.Stage_Row_Reject`

Failure path:

If stage loading fails before `etl.usp_Run_Incremental_Load` is called, add a failure precedence constraint to:

1. `EST_End_Batch_Failed`
   - Execute only when the batch is still `STARTED`
   - Execute:
   ```sql
   IF EXISTS
   (
       SELECT 1
       FROM meta.Batch_Run
       WHERE BatchID = ?
         AND Status = 'STARTED'
   )
   BEGIN
       EXEC meta.usp_End_Batch
           @BatchID = ?,
           @Status = 'FAILED',
           @Notes = ?;
   END;
   ```

Do not call `validate_stage_data.dtsx`, `load_dimensions.dtsx`, and `load_facts.dtsx` from the daily package if you are already calling `etl.usp_Run_Incremental_Load`, because the runner already performs those steps.

#### Data Flow

- none directly

This package is orchestration only. The stage landing happens in the child package and the transformation logic remains in SQL procedures.

#### Connection Managers

- `CM_OLEDB_TransportationDW`
- child package connection managers inherited through project parameters

#### Package Parameters

- `pBatchName`
- `pSourceName`
- `pLoadMode`
- `pRawFolder`
- `pErrorFolder`
- `pBatchNotes`

#### Variables

- `User::BatchID`
- `User::BatchStatus`
- `User::RowsRead`
- `User::RowsLoaded`
- `User::RowsRejected`

#### Lookup Transformations

- none

This package is control-flow only.

#### Conditional Split Logic

Use precedence constraints instead of a data-flow Conditional Split:

- success path after `EST_Start_Batch`
- failure path to `EST_End_Batch_Failed`

The `pLoadMode` decision is delegated to `load_source_to_stage.dtsx`.

#### Error Outputs

- no row-level SSIS error output
- rely on SSIS catalog execution reports plus SQL `audit.Error_Log`

#### Logging And Auditing

- batch start and end are stored in `meta.Batch_Run`
- stage load auditing is stored in `meta.Source_File_Log` and `audit.Load_Audit`
- validation rejects are stored in `audit.Stage_Row_Reject`
- warehouse load counts and statuses are stored in `audit.Load_Audit`
- successful completion promotes watermarks inside `meta.Watermark`

#### Stored Procedures Called

- `meta.usp_Start_Batch`
- `etl.usp_Run_Incremental_Load`
- `meta.usp_End_Batch` on package-level failure only

#### Expected Source And Destination Tables

Reads and writes across:

- `meta.Batch_Run`
- `meta.Source_File_Log`
- `meta.Watermark`
- all `stg.*` tables
- all `dw.*` tables
- all `audit.*` tables

#### Portfolio Screens

- Full control flow for the package
- Execute Package Task parameter mapping into `load_source_to_stage.dtsx`
- Execute SQL Task editor for `etl.usp_Run_Incremental_Load`
- SSMS screenshot of `meta.Batch_Run`, `audit.Load_Audit`, and `meta.Watermark` after a successful batch

## Interview Summary

The cleanest interview explanation is:

1. SSIS handles orchestration, file parsing, parameterization, and error routing.
2. SQL Server handles batch control, validation, standardization, dimensions, facts, watermarks, and shipment restatement.
3. The main daily package is thin on purpose because the business logic is already centralized and testable in T-SQL.
