# Power BI Build Steps

## Goal

Build a Power BI Desktop report that sits directly on top of the existing warehouse model and uses the SQL `rpt` views only as validation references.

## Recommended Source Strategy

- primary semantic model source: `dw` tables
- validation reference source: `rpt` views
- connectivity mode: `Import`

Reason:

- the dataset size in this portfolio project is small enough for fast local imports
- `Import` keeps the demo responsive
- direct `dw` tables preserve the star schema and drill-through detail

## Before Opening Power BI Desktop

Confirm these are already complete:

- the SQL build succeeded from [sql/99_run_all.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\sql\99_run_all.sql)
- source data was seeded
- at least one successful warehouse batch exists
- [tests/sql/01_smoke_tests.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\01_smoke_tests.sql) passes
- [tests/sql/05_reporting_view_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\05_reporting_view_checks.sql) passes

## Exact Build Order In Power BI Desktop

1. Open Power BI Desktop.
2. Select `Get Data` -> `SQL Server`.
3. Enter your SQL Server instance and database `TransportationDW`.
4. Choose `Import`.
5. Select these tables:
   - `dw.DimDate`
   - `dw.DimCarrier`
   - `dw.DimRoute`
   - `dw.DimLocation`
   - `dw.DimDeliveryException`
   - `dw.DimShipmentStatus`
   - `dw.FactShipment`
   - `dw.FactDeliveryEvent`
   - `dw.FactDeliveryException`
6. Load the selected tables.
7. In Power Query, reference `DimLocation` three times and rename the queries:
   - `DimLocation_Origin`
   - `DimLocation_Destination`
   - `DimLocation_Event`
8. Disable load for the original `DimLocation` query if you only want the role-playing tables in the final model.
9. Apply and close.
10. In model view, create the relationships described in [powerbi/model-design.md](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\powerbi\model-design.md).
11. Mark `DimDate` as the date table using `FullDate`.
12. Sort `DimDate[MonthName]` by `DimDate[CalendarMonth]`.
13. Create a dedicated `Measures` table.
14. Add the DAX measures from [powerbi/dax-measures.md](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\powerbi\dax-measures.md).
15. Hide technical keys, ETL columns, and raw additive columns.
16. Format the measures.
17. Build the report pages in this order:
   - `Executive Overview`
   - `Delivery Performance`
   - `Route Efficiency`
   - `Carrier Exceptions`
   - `Operational Detail`
18. Validate totals against the SQL reporting views.
19. Save the report as a `.pbix` file under [powerbi](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\powerbi).

## Relationship Build Notes

Recommended relationship behavior:

- one-to-many from dimensions to facts
- single-direction filter
- use role-playing location tables
- keep `DimDate` active to:
  - `FactShipment[ActualDeliveryDateKey]`
  - `FactDeliveryEvent[EventDateKey]`
  - `FactDeliveryException[ExceptionDateKey]`

Do not use both-direction filters for convenience. Keep the model explainable.

## Measures Table Setup

Simple setup:

1. Click `Enter Data`.
2. Create one column named `Placeholder`.
3. Enter one row such as `Measures`.
4. Name the table `Measures`.
5. Hide the `Placeholder` column.
6. Store all DAX measures in that table.

## Fields To Hide

Hide:

- all surrogate keys
- all fact foreign keys
- `BatchID`
- `CreatedAt`
- `UpdatedAt`
- `SourceModifiedAt`
- raw count columns that should be used through measures

Keep visible:

- business-friendly dimension attributes
- `ShipmentNumber` for drill-through
- `ServiceLevel`
- `ShipmentStatus`
- event and exception timestamps for detail pages

## Recommended Slicer Setup

Sync these slicers across the main pages:

- `DimDate[CalendarYear]`
- `DimCarrier[CarrierName]`

Use page-specific slicers where appropriate:

- Delivery page:
  - `ServiceLevel`
  - origin and destination state
- Route page:
  - `RouteType`
  - `FuelZone`
- Exceptions page:
  - `ExceptionCategory`
  - `SeverityCode`
  - `ResponsibleParty`

## Validation Steps

After building the first version:

1. Compare executive shipment totals to `dw.FactShipment`.
2. Compare delivery KPIs to `rpt.vw_DeliveryPerformance`.
3. Compare route KPIs to `rpt.vw_RouteEfficiency`.
4. Compare exception KPIs to `rpt.vw_CarrierExceptionTrends`.
5. Re-run:
   - [tests/sql/01_smoke_tests.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\01_smoke_tests.sql)
   - [tests/sql/05_reporting_view_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\05_reporting_view_checks.sql)

## Portfolio Tips

- keep the executive page clean and high-level
- use consistent colors for on-time, late, and exception states
- make `Operational Detail` the main drill-through page
- save one screenshot of model view after relationships are complete
- save one screenshot per page after KPI validation
