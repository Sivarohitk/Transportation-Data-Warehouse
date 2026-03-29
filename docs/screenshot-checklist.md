# Screenshot Checklist

## Purpose

Capture only screenshots that prove the implemented design and the documented desktop-tool work fit together.

Do not create mock screenshots. Capture only after you have actually built or run the relevant step locally.

## Priority Order

Capture these first:

1. `meta.Batch_Run` and `audit.Load_Audit`
2. `meta.Watermark`
3. `audit.Stage_Row_Reject`
4. `dw.FactShipment`
5. `dw.FactDeliveryEvent`
6. `rpt.vw_DeliveryPerformance`
7. SSIS `incremental_daily_load.dtsx` control flow
8. Power BI model view
9. Power BI Executive Overview page
10. README architecture diagram

## SQL Server Screens

### Source And Staging

- `src.Shipment`
  Show that the source schema is populated with realistic data.
- `src.Shipment_Status_History`
  Show scan-event history exists and supports the event fact.
- `stg.Shipment_Raw`
  Show `BatchID`, `SourceName`, and validation fields.
- `stg.Shipment_Status_History_Raw`
  Show event data landed in stage.

### Validation And Audit

- `audit.Stage_Row_Reject`
  Show at least one real rejected row with `RejectionReason`.
- `audit.Validation_Error`
  Show rule-level validation detail.
- `meta.Batch_Run`
  Show one successful batch.
- `audit.Load_Audit`
  Show inserted and updated counts by step.
- `meta.Watermark`
  Show successful watermarks after a completed run.

### Warehouse And Reporting

- `dw.DimRoute`
  Show route benchmark attributes such as reference miles and reference transit hours.
- `dw.FactShipment`
  Show shipment-level KPIs and flags.
- `dw.FactDeliveryEvent`
  Show event-level grain and scan history.
- `dw.FactDeliveryException`
  Show exception-level grain.
- `rpt.vw_DeliveryPerformance`
  Show a sample delivery KPI output.
- `rpt.vw_RouteEfficiency`
  Show route benchmark comparison output.
- `rpt.vw_CarrierExceptionTrends`
  Show normalized carrier exception trend output.

## SSIS Screens

Use the detailed SSIS checklist in `docs/ssis-screens-to-create.md` as the package-specific source of truth.

The first SSIS screens to capture should be:

- Solution Explorer with the five documented packages
- `incremental_daily_load.dtsx` control flow
- `load_source_to_stage.dtsx` control flow
- `DFT_Load_Daily_Delivery_Scan_Events` data flow
- project parameters and one connection manager

## SQL Test Screens

- `tests/sql/01_smoke_tests.sql`
  Capture a successful run with no thrown errors.
- `tests/sql/04_incremental_load_checks.sql`
  Capture output that shows watermark and restatement checks.
- `tests/sql/05_reporting_view_checks.sql`
  Capture the reporting reconciliation output.
- `sql/04_tests/00_data_quality_checks.sql`
  Capture the most demo-friendly summary sections.

## Power BI Screens

Capture these after the `.pbix` is actually built:

- model view with all active relationships visible
- `Measures` table with the main KPI measures
- Executive Overview page
- Delivery Performance page
- Route Efficiency page
- Carrier Exceptions page
- Operational Detail page
- one tooltip example
- one drill-through example

## Suggested Captions

- `Batch history and ETL audit trail for an end-to-end transportation warehouse load`
- `Watermark state showing rerun-safe incremental extraction and post-load promotion`
- `Stage reject handling with row-level rejection reasons`
- `Shipment event fact preserving scan-level operational history`
- `Power BI star schema modeled directly on the warehouse tables`

## What To Avoid

- unreadable wide screenshots at low zoom
- screenshots with credentials or full connection strings
- screenshots that only show table names without meaningful data
- screenshots from documentation pages instead of the actual local run, unless the screenshot is explicitly meant to show design guidance
