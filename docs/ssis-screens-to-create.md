# SSIS Screens To Create

## Purpose

This checklist tells you which SSDT and SQL Server screenshots are worth capturing for a portfolio walkthrough.

Focus on screenshots that prove the package design is connected to the real warehouse model, batch framework, and reporting outcomes.

## Must-Have Screens

1. SSDT Solution Explorer
   - Show the `TransportationDW` SSIS project with all five packages.

2. `incremental_daily_load.dtsx` control flow
   - Capture the full package canvas.
   - Make sure `meta.usp_Start_Batch`, the child package task, and `etl.usp_Run_Incremental_Load` are all visible.

3. `load_source_to_stage.dtsx` control flow
   - Capture both `SQL_SOURCE` and `FLAT_FILE` containers.
   - This proves the design supports both relational extracts and raw CSV feeds.

4. `DFT_Load_Daily_Delivery_Scan_Events` data flow
   - Show Flat File Source, Derived Column, Data Conversion, Conditional Split, Row Count, OLE DB Destination, and error output path.
   - This is the best single data-flow screenshot in the project.

5. `EST_Log_Daily_Delivery_Scan_Events` Execute SQL Task
   - Show parameter bindings into `etl.usp_Register_Flat_File_Stage_Load`.

6. `validate_stage_data.dtsx` control flow
   - Show the validation task and reject-summary task.

7. `load_dimensions.dtsx` control flow
   - Show `etl.usp_Load_DimDate` and `etl.usp_Load_Dimensions`.

8. `load_facts.dtsx` control flow
   - Show the three fact loaders in sequence.

9. SSMS query results for `meta.Batch_Run`
   - Capture one successful batch with counts populated.

10. SSMS query results for `audit.Load_Audit`
    - Show step-level insert and update counts.

11. SSMS query results for `audit.Stage_Row_Reject`
    - Show at least one real rejected row with `RejectionReason`.

12. SSMS query results for `meta.Watermark`
    - Show source watermarks and the warehouse completion watermark after a successful run.

## Best Screens For Interview Walkthroughs

If you only have time for four screenshots, use these:

1. `incremental_daily_load.dtsx` control flow
2. `load_source_to_stage.dtsx` control flow
3. `DFT_Load_Daily_Delivery_Scan_Events` data flow
4. `audit.Load_Audit` plus `meta.Watermark` query results

## Nice-To-Have Screens

1. Execute Package Task parameter mapping from `incremental_daily_load.dtsx` into `load_source_to_stage.dtsx`
2. Project parameters window showing `pLoadMode`, `pRawFolder`, and `pErrorFolder`
3. OLE DB connection manager editor pointing to `TransportationDW`
4. SSMS query results for `dw.FactShipment`
5. SSMS query results for `dw.FactDeliveryEvent`
6. SSMS query results for `rpt.vw_DeliveryPerformance`

## Recommended Caption Ideas

Use short, factual captions.

Examples:

- `Master SSIS package orchestrating batch start, stage load, and SQL-driven incremental warehouse load`
- `Daily delivery scan event data flow landing raw events to the stg schema with row counts and error redirection`
- `SQL audit trail showing inserted, updated, and rejected counts by ETL step`
- `Watermark table showing rerun-safe incremental extraction and post-load promotion`

## What To Avoid Capturing

- giant unreadable canvases at low zoom
- connection strings with credentials
- package GUID noise
- screenshots that only show a destination table and not the business flow

## Best Narrative Order

Use this order when presenting:

1. `incremental_daily_load.dtsx`
2. `load_source_to_stage.dtsx`
3. `DFT_Load_Daily_Delivery_Scan_Events`
4. `validate_stage_data.dtsx`
5. `audit.Stage_Row_Reject`
6. `audit.Load_Audit`
7. `meta.Watermark`
