# Business Rules

## Standardization Rules

- `CarrierCode`, `LocationCode`, `ShipmentNumber`, `ExceptionCode`, and `StatusCode` are trimmed and uppercased before dimension or fact joins.
- `RouteCode` is trimmed, uppercased, and stripped of embedded spaces before dimension or fact joins.
- Carrier names are trimmed and internal repeated spaces are collapsed before loading `dw.DimCarrier`.
- Exception categories are normalized from `stg.Exception_Code_Lookup_Raw` first, with fallback to `stg.Delivery_Exception_Raw` when a code is not present in the lookup feed.

## Delivery Performance Rules

- Expected delivery is represented by `PlannedDeliveryDate` from `stg.Shipment_Raw`.
- Actual delivery is taken from `ActualDeliveryDate` in `stg.Shipment_Raw`, with fallback to the first `DELIVERED` event in `stg.Shipment_Status_History_Raw`.
- `OnTimeDeliveryFlag = 1` when actual delivery is present and less than or equal to planned delivery.
- `LateDeliveryFlag = 1` when actual delivery is present and greater than planned delivery.
- `DeliveryDelayMinutes` is positive only for late shipments and `0` for on-time or early deliveries.
- `TransitHours` and `TransitDays` are calculated from actual pickup to actual delivery, with pickup and delivery event fallbacks from shipment status history.

## Exception Rules

- `ExceptionShipmentFlag = 1` when a shipment has one or more exception rows or its latest shipment status resolves to an exception-status member.
- `FactDeliveryException` uses the normalized exception dimension so reporting groups by mastered exception categories instead of raw feed text.
- `DelayVarianceMinutes` is calculated as actual exception delay minus the lookup-based typical delay.

## Deduplication Rules

- Shipments are deduplicated in the warehouse load by normalized `ShipmentNumber`, keeping the latest `SourceModifiedAt` and then the latest stage identity row.
- Delivery events are deduplicated by normalized `ShipmentNumber` plus `EventSequenceNumber`, keeping the latest event timestamp and then the latest stage identity row.
- Delivery exceptions are deduplicated by normalized `ShipmentNumber`, `ExceptionCode`, and `ExceptionDateTime`, keeping the latest stage identity row.
- Rerun safety is enforced with conditional `MERGE` updates so unchanged matched rows are not counted as updates on a rerun.

## Incremental Restatement Rules

- SQL source deltas are detected with watermarks plus source-table identity tie-breakers.
- When a shipment, shipment status event, or delivery exception crosses a source watermark, that shipment becomes an impacted shipment for the batch.
- Impacted shipments are restaged as a current shipment snapshot plus shipment history and exception history so `dw.FactShipment` can be recalculated without waiting for the source system to resend every related row.
- `dw.FactShipment` also unions current-batch stage events and exceptions with previously loaded warehouse history so event-only or exception-only batches can still restate counts and status safely.

## Rejects Vs Unknown Members

- Stage rejects handle invalid mandatory business references:
  - missing shipment number
  - missing or invalid carrier, route, origin, or destination references
  - status history for an unknown shipment
  - delivery exception for an unknown shipment
- Unknown dimension members handle warehouse lookup gaps:
  - unresolved shipment status member
  - unresolved event location member
  - unresolved exception dimension member
  - unresolved route or location dimension during a late-arriving dimension scenario

## Reporting Enrichment

- `stg.Route_Distance_Reference_Raw` enriches `dw.DimRoute` with benchmark distance, benchmark transit hours, and fuel zone so route-efficiency reporting can compare shipment actuals to route standards.
- `stg.Exception_Code_Lookup_Raw` enriches `dw.DimDeliveryException` with normalized categories, severity, typical delay, and responsible party so carrier exception trend reporting stays consistent across batches.

## Validation Coverage

- Quick rule validation is handled by [tests/sql/01_smoke_tests.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\01_smoke_tests.sql).
- Referential and rule-detail checks are handled by [tests/sql/03_referential_integrity_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\03_referential_integrity_checks.sql).
- Demo-friendly rule summaries are exposed in [sql/04_tests/00_data_quality_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\sql\04_tests\00_data_quality_checks.sql).
