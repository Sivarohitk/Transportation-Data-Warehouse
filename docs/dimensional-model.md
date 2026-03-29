# Dimensional Model

## Model Summary

The warehouse keeps a simple Kimball-style core:

- `dw.DimDate`
- `dw.DimCarrier`
- `dw.DimLocation`
- `dw.DimRoute`
- `dw.DimDeliveryException`
- `dw.DimShipmentStatus`
- `dw.FactShipment`
- `dw.FactDeliveryEvent`
- `dw.FactDeliveryException`

The model stays aligned to the existing repo structure and does not introduce parallel fact tables for the same business process.

`dw.DimDate` is the conformed calendar dimension shared across shipment, delivery-event, and delivery-exception facts.

## Fact Grain

`dw.FactShipment`

- One row per shipment number.
- This is the main fact for delivery performance, transit, cost, and route efficiency reporting.

`dw.FactDeliveryEvent`

- One row per shipment status event from `stg.Shipment_Status_History_Raw`.
- This preserves scan-level lifecycle detail such as pickup, in-transit, out-for-delivery, exception, and delivered events.

`dw.FactDeliveryException`

- One row per shipment exception occurrence by shipment, exception code, and exception timestamp.
- This supports carrier exception trend reporting without collapsing multiple exceptions on the same shipment into a single row.

## Dimensions And SCD Approach

`dw.DimDate`

- SCD Type 0.
- Calendar attributes should never change after they are loaded.

`dw.DimCarrier`

- SCD Type 1.
- Carrier name, tier, mode, and home office attributes are treated as current-state reporting attributes.

`dw.DimLocation`

- SCD Type 1.
- The project keeps location corrections simple and updates the current location profile in place.

`dw.DimRoute`

- SCD Type 1 in this runnable implementation.
- Route benchmark values are maintained as the current operational standard to keep the project simple.
- If route benchmark history becomes important, this is the best candidate to upgrade to Type 2 later.

`dw.DimDeliveryException`

- SCD Type 1.
- Exception descriptions, categories, severity, responsible party, and typical delay are treated as the latest mastered lookup attributes.

`dw.DimShipmentStatus`

- SCD Type 1.
- Shipment status codes and lifecycle groupings are reference-style attributes that are updated in place if wording changes.

## Why `FactDeliveryEvent` Was Kept

`FactDeliveryEvent` is worth keeping because the repo now has a realistic daily scan-event feed and that data would be lost if it were only rolled up into shipment-level counts.

It adds real value by supporting:

- event-level shipment lifecycle analysis
- scan compliance and missed-scan reporting
- exception-event timing analysis
- future operational dashboards without redesigning the warehouse later

The model still stays simple because shipment performance and exception trend reporting remain anchored on `FactShipment` and `FactDeliveryException`.

## How New Staging Assets Improve Reporting

`stg.Route_Distance_Reference_Raw`

- populates benchmark route distance, transit hours, and fuel-zone attributes in `dw.DimRoute`
- improves route efficiency reporting by separating route benchmark values from shipment-level actuals

`stg.Exception_Code_Lookup_Raw`

- populates mastered exception attributes in `dw.DimDeliveryException`
- improves exception analysis by adding typical delay and responsible-party context

`stg.Shipment_Status_History_Raw`

- populates `dw.DimShipmentStatus`
- feeds `dw.FactDeliveryEvent`
- improves `dw.FactShipment` by supplying scan-event counts, fallback pickup and delivery timestamps, and current status logic

## Measures

Primary measures now supported in the warehouse include:

- `ShipmentCount`
- `TransitHours`
- `TransitDays`
- `DeliveryDelayMinutes`
- `OnTimeDeliveryFlag`
- `LateDeliveryFlag`
- `ScanEventCount`
- `ExceptionCount`
- `ExceptionShipmentFlag`
- `DelayMinutesImpact`
- `TypicalDelayMinutes`
- `DelayVarianceMinutes`
- `EventCount`

`DeliveryDelayMinutes` is stored as a non-negative measure. Late shipments carry the positive delay value and on-time or early shipments carry `0`.

## Unknown Members And Rejects

The warehouse uses both stage rejects and unknown dimension members, but for different purposes.

- Stage rejects are used for missing or invalid mandatory operational references such as shipment numbers, carrier codes, route codes, and invalid route or location references.
- Unknown dimension members are used as a warehouse safety net for late-arriving or optional analytic lookups, such as an event location not yet mastered in a dimension or an exception code that does not resolve during fact loading.
- The unknown members keep fact loads repeatable without allowing clearly bad operational rows to bypass stage validation.

## Reporting Fit

Delivery performance reporting centers on `dw.FactShipment`.

Route efficiency reporting uses `dw.FactShipment` plus route benchmarks from `dw.DimRoute`.

Carrier exception trend analysis uses `dw.FactDeliveryException` plus lookup attributes from `dw.DimDeliveryException`.
