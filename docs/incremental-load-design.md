# Incremental Load Design

## Design Goals

- Keep one batch framework and one warehouse runner.
- Advance source watermarks only after a successful warehouse load.
- Support reruns without duplicate facts.
- Restate shipments when later events or exceptions change shipment-level KPIs.

## Watermark Strategy

The project uses pending and successful watermarks.

- `StageLoad_src.Shipment`
  - watermark key: `SourceModifiedAt + ShipmentID`
- `StageLoad_src.ShipmentStatusHistory`
  - watermark key: `EventDateTime + ShipmentStatusHistoryID`
- `StageLoad_src.DeliveryException`
  - watermark key: `ExceptionDateTime + DeliveryExceptionID`
- `FlatFile.<SourceObjectName>`
  - watermark key: successful `BatchID + FileName`

`etl.usp_Load_Stage_From_Source` reads only the last successful watermark values. It records new high-water marks as pending values. `etl.usp_Run_Incremental_Load` promotes those pending values only after the dimension and fact loads succeed.

## SQL Source Incremental Logic

The relational source path works in two steps:

1. Detect source deltas by watermark.
2. Build the impacted shipment set from:
   - changed shipment master rows
   - new shipment status history rows
   - new delivery exception rows

For every impacted shipment, the stage load lands:

- the current shipment snapshot
- the full shipment status history for that shipment
- the full delivery exception history for that shipment

This keeps shipment restatement simple because the warehouse load can recalculate the shipment fact from the batch stage set.

## Flat-File Incremental Logic

The flat-file path is batch based.

- Each file is registered through `etl.usp_Register_Flat_File_Stage_Load`.
- Registration is an upsert by `BatchID + SourceObjectName + FileName`.
- The file log becomes the processed-file ledger for SSIS packages.
- On successful warehouse completion, `etl.usp_Run_Incremental_Load` records a successful flat-file watermark per source object.

## Shipment Restatement

`dw.FactShipment` is recalculated for impacted shipments when:

- a shipment master row changes
- a new delivery scan event arrives
- a new delivery exception arrives

The fact load combines:

- current-batch shipment stage rows
- current-batch stage events and exceptions
- previously loaded warehouse event and exception history for the same shipment when needed

That design lets late-arriving events update:

- latest shipment status
- scan-event count
- exception count
- pickup and delivery event timing
- on-time / late status

## Rerun Behavior

- Rerunning `etl.usp_Run_Incremental_Load` for the same staged batch is safe because facts and dimensions use business-key-based `MERGE` logic.
- Matched updates are conditional, so unchanged rows do not inflate update counts on reruns.
- A failed batch does not promote source SQL watermarks, so the same source delta can be reloaded and rerun safely.

## Interview Summary

The incremental design is intentionally simple:

- SQL sources use timestamp plus identity watermarks.
- Flat files use file registration plus batch tracking.
- Watermarks are promoted only after a successful warehouse batch.
- Shipment restatement is driven by impacted shipments rather than full-table reloads.
- All warehouse loads are idempotent at the business-key grain.

## Validation Coverage

- Incremental audit, watermark, and restatement checks are covered by [tests/sql/04_incremental_load_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\04_incremental_load_checks.sql).
- The optional rerun probe in that script re-executes `etl.usp_Run_Incremental_Load` inside a rollback transaction to validate idempotency without permanently changing warehouse data.
