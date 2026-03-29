# Demo Runbook

Use this runbook for the final local portfolio demo.

The recommended end-to-end demo path uses the implemented relational source flow first. The flat-file SSIS path and the Power BI report build remain manual desktop steps and are called out separately below.

## Fully Implemented In Repo

- source data generator
- source schema and source seed script
- SQL database build
- stage load from the `src` schema
- stage validation, rejects, and audits
- dimension and fact loads through `etl.usp_Run_Incremental_Load`
- incremental restatement and rerun safety
- SQL test suite and reporting-view checks

## Still Manual Outside Repo

- create the actual `.dtsx` packages in SSDT
- create the actual `.pbix` in Power BI Desktop
- capture final screenshots after local execution

## 1. Source Setup

Open a PowerShell session at the repo root:

```powershell
Set-Location "C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse"
```

Confirm prerequisites:

- SQL Server instance is reachable
- Python 3.11+ is installed
- `sqlcmd` is available
- `data/generator/generate_transport_data.py` exists

For the repeatable demo path, use the implemented `src` schema flow. The SSIS flat-file path is documented but still manual.

## 2. Sample Data Generation

```powershell
python .\data\generator\generate_transport_data.py --output-dir .\data\generated --raw-output-dir .\data\raw --sql-seed-path .\sql\source\02_seed_source_data.sql
```

Confirm:

- `data/raw` contains the CSV feeds
- `sql/source/02_seed_source_data.sql` exists and is current

## 3. Database Build

Run the SQLCMD build from inside the `sql` folder because `sql/99_run_all.sql` uses relative `:r` includes:

```powershell
Push-Location .\sql
sqlcmd -S localhost -E -b -v DatabaseName=TransportationDW -i .\99_run_all.sql
Pop-Location
```

Alternative:

- Open `sql/99_run_all.sql` in SSMS.
- Enable SQLCMD Mode.
- Execute it from SSMS.

## 4. Source Seed

```powershell
sqlcmd -S localhost -E -b -d TransportationDW -i .\sql\source\02_seed_source_data.sql
```

Quick verification:

```powershell
sqlcmd -S localhost -E -d TransportationDW -Q "SELECT COUNT(*) AS ShipmentRows FROM src.Shipment; SELECT COUNT(*) AS EventRows FROM src.Shipment_Status_History; SELECT COUNT(*) AS ExceptionRows FROM src.Delivery_Exception;"
```

## 5. Stage Load

Use the implemented relational source loader first. This avoids depending on SSDT for the core demo.

Run in SSMS or with `sqlcmd`:

```sql
USE [TransportationDW];
GO
DECLARE @BatchID int;
EXEC meta.usp_Start_Batch
    @BatchName = N'INITIAL_STAGE_LOAD',
    @SourceName = N'SRC_OLTP',
    @BatchID = @BatchID OUTPUT;

EXEC etl.usp_Load_Stage_From_Source
    @BatchID = @BatchID,
    @SourceName = N'SRC_OLTP',
    @RunValidation = 0;

SELECT @BatchID AS BatchID;
GO
```

Save the returned `BatchID`. You will reuse it in the next step.

Optional verification before warehouse loading:

```sql
USE [TransportationDW];
GO
SELECT COUNT(*) AS StageShipmentRows FROM stg.Shipment_Raw WHERE BatchID = <BatchID>;
SELECT COUNT(*) AS StageEventRows FROM stg.Shipment_Status_History_Raw WHERE BatchID = <BatchID>;
SELECT COUNT(*) AS StageExceptionRows FROM stg.Delivery_Exception_Raw WHERE BatchID = <BatchID>;
GO
```

## 6. Dimension And Fact Load

Run the existing warehouse runner. This step loads dimensions, facts, audits, and watermark promotion in the supported order.

```sql
USE [TransportationDW];
GO
DECLARE @BatchID int = <BatchID>;

EXEC etl.usp_Run_Incremental_Load
    @BatchID = @BatchID,
    @Notes = N'Initial demo load';
GO
```

Recommended quick checks:

```sql
USE [TransportationDW];
GO
SELECT TOP (5) * FROM meta.Batch_Run ORDER BY BatchID DESC;
SELECT TOP (10) * FROM audit.Load_Audit ORDER BY LoadAuditID DESC;
SELECT COUNT(*) AS FactShipmentRows FROM dw.FactShipment;
SELECT COUNT(*) AS FactDeliveryEventRows FROM dw.FactDeliveryEvent;
SELECT COUNT(*) AS FactDeliveryExceptionRows FROM dw.FactDeliveryException;
GO
```

## 7. Incremental Rerun Test

This is the strongest technical demo because it proves shipment restatement works when only later operational activity arrives.

Insert an event-only change:

```sql
USE [TransportationDW];
GO
DECLARE @ShipmentID bigint = (SELECT TOP (1) ShipmentID FROM src.Shipment ORDER BY ShipmentID);
DECLARE @NextSeq int = ISNULL((SELECT MAX(EventSequenceNumber) + 1 FROM src.Shipment_Status_History WHERE ShipmentID = @ShipmentID), 1);
DECLARE @LocationID int = (SELECT DestinationLocationID FROM src.Shipment WHERE ShipmentID = @ShipmentID);

INSERT INTO src.Shipment_Status_History
(
    ShipmentID,
    EventSequenceNumber,
    StatusCode,
    StatusDescription,
    EventDateTime,
    LocationID,
    ScanType,
    EventSource,
    ExceptionCode,
    Notes
)
VALUES
(
    @ShipmentID,
    @NextSeq,
    N'OUT_FOR_DELIVERY',
    N'Out for Delivery',
    DATEADD(MINUTE, 5, SYSUTCDATETIME()),
    @LocationID,
    N'DELIVERY_SCAN',
    N'DEMO_EVENT_ONLY',
    NULL,
    N'Incremental restatement demo'
);
GO
```

Run the next batch:

```sql
USE [TransportationDW];
GO
DECLARE @BatchID int;
EXEC meta.usp_Start_Batch
    @BatchName = N'INCREMENTAL_SRC_LOAD',
    @SourceName = N'SRC_OLTP',
    @BatchID = @BatchID OUTPUT;

EXEC etl.usp_Load_Stage_From_Source
    @BatchID = @BatchID,
    @SourceName = N'SRC_OLTP',
    @RunValidation = 0;

EXEC etl.usp_Run_Incremental_Load
    @BatchID = @BatchID,
    @Notes = N'Event-only incremental demo';

SELECT @BatchID AS BatchID;
GO
```

Show:

- the new row in `dw.FactDeliveryEvent`
- updated batch audit rows
- updated watermark rows
- the related shipment still present and consistent in `dw.FactShipment`

## 8. Validation Checks

Run the fast validation pass:

```powershell
sqlcmd -S localhost -E -i .\tests\sql\01_smoke_tests.sql
sqlcmd -S localhost -E -i .\tests\sql\05_reporting_view_checks.sql
sqlcmd -S localhost -E -v DatabaseName=TransportationDW -i .\sql\04_tests\00_data_quality_checks.sql
```

Optional deeper checks:

```powershell
sqlcmd -S localhost -E -i .\tests\sql\02_row_count_checks.sql
sqlcmd -S localhost -E -i .\tests\sql\03_referential_integrity_checks.sql
sqlcmd -S localhost -E -i .\tests\sql\04_incremental_load_checks.sql
```

## 9. SSIS Build Order

These steps are manual in SSDT.

Build order:

1. `load_source_to_stage.dtsx`
2. `validate_stage_data.dtsx`
3. `load_dimensions.dtsx`
4. `load_facts.dtsx`
5. `incremental_daily_load.dtsx`

Use:

- `docs/ssis-package-design.md`
- `docs/ssis-build-checklist.md`
- `docs/ssis-screens-to-create.md`

## 10. Power BI Build Order

These steps are manual in Power BI Desktop.

Build order:

1. Import the `dw` fact and dimension tables.
2. Create `DimLocation_Origin`, `DimLocation_Destination`, and `DimLocation_Event` as role-playing references.
3. Build the relationships and mark `DimDate` as the date table.
4. Create the `Measures` table and add the documented DAX.
5. Build report pages in this order:
   - Executive Overview
   - Delivery Performance
   - Route Efficiency
   - Carrier Exceptions
   - Operational Detail
6. Validate KPI totals against the `rpt` views and SQL test outputs.

Use:

- `powerbi/model-design.md`
- `powerbi/dax-measures.md`
- `powerbi/dashboard-spec.md`
- `docs/powerbi-build-steps.md`

## 11. Screenshots To Capture

Capture these first:

1. `meta.Batch_Run` plus `audit.Load_Audit`
2. `meta.Watermark`
3. `audit.Stage_Row_Reject`
4. `dw.FactShipment`
5. `dw.FactDeliveryEvent`
6. `rpt.vw_DeliveryPerformance`
7. SSIS `incremental_daily_load.dtsx` control flow
8. Power BI model view
9. Power BI Executive Overview page
10. one Operational Detail drill-through example

Use `docs/screenshot-checklist.md` as the detailed capture guide.

## 12. Final Interview Demo Flow

Use this order for the live walkthrough:

1. README and architecture diagram
2. source-system and raw-feed explanation
3. stage layer and reject handling
4. batch control, load audit, and watermarks
5. warehouse model and fact grain
6. reporting views and SQL validation checks
7. incremental rerun and shipment restatement demo
8. SSIS package design
9. Power BI model and dashboard design
10. resume-bullet mapping and interview talking points

## Best Supporting Docs

- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/demo-setup-guide.md`
- `docs/interview-qa.md`
- `docs/resume-bullet-mapping.md`
- `docs/screenshot-checklist.md`

## Honest Closing Statement

The SQL implementation is complete enough to build, load, validate, and demo locally from source-controlled scripts.

The remaining work outside this repo is the creation of the actual SSDT packages, the Power BI `.pbix`, and the final screenshot set from successful local execution.
