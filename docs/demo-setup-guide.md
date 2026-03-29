# Demo Setup Guide

## Goal

Use this guide to prepare a local demo that shows the real SQL implementation first, then the SSIS and Power BI design layers.

This guide assumes:

- Windows
- SQL Server on `localhost`
- repository opened at the repo root

If your instance name is different, replace `localhost` in the commands below.

## Recommended Demo Order

1. Generate source data.
2. Build the database.
3. Seed the source schema.
4. Run the first batch from source to warehouse.
5. Run the fast SQL validations.
6. Show audit, watermark, and reporting outputs.
7. Optionally simulate an incremental event-only change and rerun the load.
8. Walk through the SSIS design docs.
9. Walk through the Power BI model and dashboard docs.

## 1. Generate Source Data

```powershell
python .\data\generator\generate_transport_data.py --output-dir .\data\generated --raw-output-dir .\data\raw --sql-seed-path .\sql\source\02_seed_source_data.sql
```

What to verify:

- `data/raw` contains the CSV feeds
- `sql/source/02_seed_source_data.sql` was refreshed

## 2. Build The Database

```powershell
Push-Location .\sql
sqlcmd -S localhost -E -b -v DatabaseName=TransportationDW -i .\99_run_all.sql
Pop-Location
```

What to verify:

- `TransportationDW` exists
- schemas `src`, `stg`, `dw`, `meta`, `audit`, `etl`, and `rpt` exist

## 3. Seed The Source Schema

```powershell
sqlcmd -S localhost -E -b -d TransportationDW -i .\sql\source\02_seed_source_data.sql
```

What to verify:

- `src.Shipment` contains at least 10,000 rows
- `src.Shipment_Status_History` and `src.Delivery_Exception` contain realistic operational history

## 4. Run The First Warehouse Batch

```powershell
sqlcmd -S localhost -E -d TransportationDW -Q "DECLARE @BatchID int; EXEC meta.usp_Start_Batch @BatchName=N'INITIAL_SRC_LOAD', @SourceName=N'SRC_OLTP', @BatchID=@BatchID OUTPUT; EXEC etl.usp_Load_Stage_From_Source @BatchID=@BatchID, @SourceName=N'SRC_OLTP', @RunValidation=0; EXEC etl.usp_Run_Incremental_Load @BatchID=@BatchID; SELECT @BatchID AS BatchID;"
```

What to verify:

- `meta.Batch_Run` shows a successful batch
- `meta.Watermark` contains successful values
- `dw.FactShipment`, `dw.FactDeliveryEvent`, and `dw.FactDeliveryException` contain rows

## 5. Run The Fast Validation Pass

```powershell
sqlcmd -S localhost -E -i .\tests\sql\01_smoke_tests.sql
sqlcmd -S localhost -E -i .\tests\sql\05_reporting_view_checks.sql
sqlcmd -S localhost -E -v DatabaseName=TransportationDW -i .\sql\04_tests\00_data_quality_checks.sql
```

What to verify:

- smoke tests do not throw errors
- reporting-view checks pass
- data-quality report shows sensible audit, reject, and reconciliation output

## 6. Show The Most Useful SQL Screens

Recommended live queries:

```sql
SELECT TOP (10) * FROM meta.Batch_Run ORDER BY BatchID DESC;
SELECT TOP (20) * FROM audit.Load_Audit ORDER BY LoadAuditID DESC;
SELECT TOP (20) * FROM meta.Watermark ORDER BY WatermarkID DESC;
SELECT TOP (20) * FROM audit.Stage_Row_Reject ORDER BY StageRejectID DESC;
SELECT TOP (20) * FROM dw.FactShipment ORDER BY ShipmentFactKey DESC;
SELECT TOP (20) * FROM dw.FactDeliveryEvent ORDER BY DeliveryEventFactKey DESC;
SELECT TOP (20) * FROM rpt.vw_DeliveryPerformance;
```

Use these to explain:

- batch control
- rerun safety
- reject handling
- shipment-level KPIs
- event-level operational detail

## 7. Optional Incremental Restatement Demo

This is the strongest technical demo because it shows that later events can restate shipment KPIs.

Insert one new event for an existing shipment:

```powershell
sqlcmd -S localhost -E -d TransportationDW -Q "DECLARE @ShipmentID bigint = (SELECT TOP (1) ShipmentID FROM src.Shipment ORDER BY ShipmentID); DECLARE @NextSeq int = ISNULL((SELECT MAX(EventSequenceNumber) + 1 FROM src.Shipment_Status_History WHERE ShipmentID = @ShipmentID), 1); DECLARE @LocationID int = (SELECT DestinationLocationID FROM src.Shipment WHERE ShipmentID = @ShipmentID); INSERT INTO src.Shipment_Status_History (ShipmentID, EventSequenceNumber, StatusCode, StatusDescription, EventDateTime, LocationID, ScanType, EventSource, ExceptionCode, Notes) VALUES (@ShipmentID, @NextSeq, N'OUT_FOR_DELIVERY', N'Out for Delivery', DATEADD(MINUTE, 5, SYSUTCDATETIME()), @LocationID, N'DELIVERY_SCAN', N'DEMO_EVENT_ONLY', NULL, N'Incremental restatement demo');"
```

Run the incremental batch:

```powershell
sqlcmd -S localhost -E -d TransportationDW -Q "DECLARE @BatchID int; EXEC meta.usp_Start_Batch @BatchName=N'INCREMENTAL_SRC_LOAD', @SourceName=N'SRC_OLTP', @BatchID=@BatchID OUTPUT; EXEC etl.usp_Load_Stage_From_Source @BatchID=@BatchID, @SourceName=N'SRC_OLTP', @RunValidation=0; EXEC etl.usp_Run_Incremental_Load @BatchID=@BatchID; SELECT @BatchID AS BatchID;"
```

Then show:

- the new event in `dw.FactDeliveryEvent`
- updated shipment counts or status in `dw.FactShipment`
- new audit rows and watermark movement

## 8. SSIS Walkthrough

The actual packages are not created in this repo yet. For the demo, use the documented package design and explain what would be built in SSDT.

Open:

- `docs/ssis-package-design.md`
- `docs/ssis-build-checklist.md`
- `docs/ssis-screens-to-create.md`

Primary talking point:

- SSIS is used for ingestion and orchestration, while SQL Server procedures own validation, warehouse logic, watermarks, and audit counts.

## 9. Power BI Walkthrough

The `.pbix` file is also still manual. For the demo, use the model and dashboard docs to explain the planned semantic layer.

Open:

- `powerbi/model-design.md`
- `powerbi/dax-measures.md`
- `powerbi/dashboard-spec.md`
- `docs/powerbi-build-steps.md`

Primary talking point:

- Power BI should use the `dw` tables directly, with `rpt` views kept as SQL-side validation references.

## Best 10-Minute Demo Flow

1. Start with the README architecture diagram.
2. Show `src`, `stg`, and `dw` objects in SSMS.
3. Show `meta.Batch_Run`, `audit.Load_Audit`, and `meta.Watermark`.
4. Show `dw.FactShipment` and `dw.FactDeliveryEvent`.
5. Show one reporting view.
6. Show the incremental restatement demo.
7. Finish with the SSIS and Power BI design docs plus screenshot checklist.

## Honest Portfolio Boundary

This repo already demonstrates the SQL implementation end to end.

The remaining manual artifacts to build locally are:

- SSDT `.dtsx` packages
- Power BI `.pbix` report
- actual screenshots from successful local runs
