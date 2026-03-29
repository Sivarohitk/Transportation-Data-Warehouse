# Power BI Model Design

## Recommendation

Use the `dw` dimension and fact tables as the primary Power BI semantic model.

Do not use the `rpt` views as the main report model for this portfolio build.

Reason:

- the warehouse already follows a Kimball-style star schema
- direct fact and dimension tables support slicers, drill-through, and detailed operational analysis
- the `rpt` views are useful for validating totals and explaining the reporting layer, but they are already aggregated and would limit interactive analysis

Recommended approach:

- primary model: `dw.*` tables
- validation reference: `rpt.vw_DeliveryPerformance`, `rpt.vw_RouteEfficiency`, `rpt.vw_CarrierExceptionTrends`
- connection mode: `Import`

## Recommended Tables To Import

Import these SQL Server tables:

- `dw.DimDate`
- `dw.DimCarrier`
- `dw.DimRoute`
- `dw.DimLocation`
- `dw.DimDeliveryException`
- `dw.DimShipmentStatus`
- `dw.FactShipment`
- `dw.FactDeliveryEvent`
- `dw.FactDeliveryException`

Do not import the `stg`, `src`, `meta`, or `audit` tables into the production report model.

Do not import the `rpt` views into the main report model. Use them only as SQL-side validation references while checking totals.

## Recommended Power Query Table Names

Keep the fact and dimension naming close to SQL:

- `DimDate`
- `DimCarrier`
- `DimRoute`
- `DimDeliveryException`
- `DimShipmentStatus`
- `FactShipment`
- `FactDeliveryEvent`
- `FactDeliveryException`

Create role-playing location tables by referencing `DimLocation` in Power Query:

- `DimLocation_Origin`
- `DimLocation_Destination`
- `DimLocation_Event`

This keeps origin, destination, and event-location slicing clean without ambiguous relationships.

## Relationship Strategy

Use single-direction filtering from dimensions to facts.

Avoid bidirectional relationships unless a later specific use case requires them.

Recommended active relationships:

| From | To | Status |
|---|---|---|
| `DimDate[DateKey]` | `FactShipment[ActualDeliveryDateKey]` | Active |
| `DimDate[DateKey]` | `FactDeliveryEvent[EventDateKey]` | Active |
| `DimDate[DateKey]` | `FactDeliveryException[ExceptionDateKey]` | Active |
| `DimCarrier[CarrierKey]` | `FactShipment[CarrierKey]` | Active |
| `DimCarrier[CarrierKey]` | `FactDeliveryEvent[CarrierKey]` | Active |
| `DimCarrier[CarrierKey]` | `FactDeliveryException[CarrierKey]` | Active |
| `DimRoute[RouteKey]` | `FactShipment[RouteKey]` | Active |
| `DimRoute[RouteKey]` | `FactDeliveryEvent[RouteKey]` | Active |
| `DimRoute[RouteKey]` | `FactDeliveryException[RouteKey]` | Active |
| `DimShipmentStatus[ShipmentStatusKey]` | `FactShipment[ShipmentStatusKey]` | Active |
| `DimShipmentStatus[ShipmentStatusKey]` | `FactDeliveryEvent[ShipmentStatusKey]` | Active |
| `DimShipmentStatus[ShipmentStatusKey]` | `FactDeliveryException[ShipmentStatusKey]` | Active |
| `DimDeliveryException[DeliveryExceptionKey]` | `FactDeliveryEvent[DeliveryExceptionKey]` | Active |
| `DimDeliveryException[DeliveryExceptionKey]` | `FactDeliveryException[DeliveryExceptionKey]` | Active |
| `DimLocation_Origin[LocationKey]` | `FactShipment[OriginLocationKey]` | Active |
| `DimLocation_Origin[LocationKey]` | `FactDeliveryEvent[OriginLocationKey]` | Active |
| `DimLocation_Origin[LocationKey]` | `FactDeliveryException[OriginLocationKey]` | Active |
| `DimLocation_Destination[LocationKey]` | `FactShipment[DestinationLocationKey]` | Active |
| `DimLocation_Destination[LocationKey]` | `FactDeliveryEvent[DestinationLocationKey]` | Active |
| `DimLocation_Destination[LocationKey]` | `FactDeliveryException[DestinationLocationKey]` | Active |
| `DimLocation_Event[LocationKey]` | `FactDeliveryEvent[EventLocationKey]` | Active |

Recommended inactive relationships on `FactShipment`:

- `DimDate[DateKey]` -> `FactShipment[OrderDateKey]`
- `DimDate[DateKey]` -> `FactShipment[PlannedPickupDateKey]`
- `DimDate[DateKey]` -> `FactShipment[ActualPickupDateKey]`
- `DimDate[DateKey]` -> `FactShipment[PlannedDeliveryDateKey]`

Those inactive date roles are useful later with `USERELATIONSHIP`, but they do not need to drive the first portfolio version.

## Date Table Guidance

Use `DimDate` as the report date table.

Recommended settings:

- mark `DimDate` as the date table using `FullDate`
- sort `MonthName` by `CalendarMonth`
- use `CalendarYear`, `CalendarMonth`, `MonthName`, and `FullDate` for time slicing

Use `ActualDeliveryDateKey` as the primary shipment-date lens for this first version because:

- it aligns to delivery-performance KPIs
- it aligns to the current `rpt.vw_DeliveryPerformance` logic
- it keeps one consistent executive date slicer across shipment, event, and exception pages

## Recommended Hidden Columns

Hide all technical keys and ETL-only fields.

Hide these types of columns:

- surrogate keys such as `CarrierKey`, `RouteKey`, `LocationKey`, `DeliveryExceptionKey`, `ShipmentStatusKey`, and fact identity keys
- fact foreign keys such as `CarrierKey`, `RouteKey`, `OriginLocationKey`, `DestinationLocationKey`, `EventLocationKey`, `ShipmentStatusKey`, and `DeliveryExceptionKey`
- ETL columns such as `BatchID`, `CreatedAt`, `UpdatedAt`, and `SourceModifiedAt`
- raw additive columns that should only be exposed through measures:
  - `FactShipment[ShipmentCount]`
  - `FactShipment[ScanEventCount]`
  - `FactShipment[ExceptionCount]`
  - `FactDeliveryEvent[EventCount]`
  - `FactDeliveryException[ExceptionCount]`

Keep these visible for report authoring:

- `DimCarrier[CarrierName]`, `CarrierMode`, `CarrierTier`
- `DimRoute[RouteCode]`, `RouteType`, `FuelZone`, `ReferenceDistanceMiles`, `ReferenceTransitHours`
- `DimLocation_Origin[City]`, `StateProvince`, `Region`
- `DimLocation_Destination[City]`, `StateProvince`, `Region`
- `DimLocation_Event[City]`, `StateProvince`
- `DimDeliveryException[ExceptionCategory]`, `ExceptionCode`, `SeverityCode`, `ResponsibleParty`
- `DimShipmentStatus[StatusDescription]`, `StatusGroup`
- `FactShipment[ServiceLevel]`, `ShipmentNumber`, `ShipmentStatus`
- `FactDeliveryEvent[EventDateTime]`, `EventSequenceNumber`, `ScanType`, `EventSource`, `ShipmentNumber`
- `FactDeliveryException[ExceptionDateTime]`, `ShipmentNumber`, `DelayMinutesImpact`, `DelayVarianceMinutes`, `ResolvedWithin24HoursFlag`

## Recommended Slicers

Use these fields as the main slicers across the report:

- `DimDate[CalendarYear]`
- `DimDate[MonthName]`
- `DimCarrier[CarrierName]`
- `DimCarrier[CarrierMode]`
- `FactShipment[ServiceLevel]`
- `DimRoute[RouteType]`
- `DimRoute[FuelZone]`
- `DimLocation_Origin[StateProvince]`
- `DimLocation_Destination[StateProvince]`
- `DimDeliveryException[ExceptionCategory]`
- `DimDeliveryException[SeverityCode]`
- `DimDeliveryException[ResponsibleParty]`
- `DimShipmentStatus[StatusGroup]`

Keep `ShipmentNumber` as a page-level or drill-through filter, not a primary global slicer.

## Measures Table

Create one dedicated measures table named `Measures`.

Recommended setup:

- create a small manual table named `Measures`
- place all DAX measures there
- hide the dummy storage column
- use display folders such as:
  - `Overview`
  - `Delivery Performance`
  - `Route Efficiency`
  - `Carrier Exceptions`
  - `Operational Detail`

## Semantic Model Diagram In Words

At the center of the model is `FactShipment`, which drives shipment-level KPIs such as volume, on-time performance, transit, delay, and exception flags.

`FactDeliveryEvent` extends that model with scan-level operational detail and connects to the same carrier, route, shipment status, date, and location dimensions.

`FactDeliveryException` extends the model with exception occurrence detail and connects to the same shared dimensions plus `DimDeliveryException`.

`DimDate`, `DimCarrier`, `DimRoute`, `DimShipmentStatus`, and `DimDeliveryException` are shared conformed dimensions.

`DimLocation` is split into three report-role tables so origin, destination, and event-location slicing remain easy to explain and easy to use.

## Why This Model Is Best For Interviews

- it directly reflects the Kimball warehouse already built in SQL Server
- it keeps the semantic model explainable as a star schema
- it supports both executive KPIs and row-level drill-through
- it lets you explain why the SQL `rpt` views exist without forcing the report to depend on pre-aggregated datasets

## Hybrid Note

A hybrid model is possible, but it is not recommended for the first portfolio `.pbix`.

Using the `rpt` views beside the fact tables would duplicate some metrics at a different grain and make the semantic story harder to explain in an interview.

For this project, the cleanest build is:

- `dw` tables for the report model
- `rpt` views for validation and demo cross-checks

## Validation Guidance

Before publishing screenshots or demoing the report, compare the Power BI page totals to:

- [tests/sql/05_reporting_view_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\05_reporting_view_checks.sql)
- [sql/04_tests/00_data_quality_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\sql\04_tests\00_data_quality_checks.sql)
