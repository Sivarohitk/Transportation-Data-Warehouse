# DAX Measures

## Measure Table

Create all measures in a dedicated table named `Measures`.

Recommended measure groups:

- `Overview`
- `Delivery Performance`
- `Route Efficiency`
- `Carrier Exceptions`
- `Operational Detail`

## Core Measures

### Total Shipments

```DAX
Total Shipments =
SUM ( FactShipment[ShipmentCount] )
```

Counts shipment fact rows at shipment grain.

Assumption:

- `FactShipment[ShipmentCount]` is always `1` per shipment.

### Delivered Shipments

```DAX
Delivered Shipments =
CALCULATE (
    [Total Shipments],
    FactShipment[ActualDeliveryDateKey] > 0
)
```

Counts shipments that have an actual delivery date.

Assumption:

- delivered shipments are represented by `ActualDeliveryDateKey > 0`.

### On-Time Shipments

```DAX
On-Time Shipments =
CALCULATE (
    [Total Shipments],
    FactShipment[OnTimeDeliveryFlag] = TRUE ()
)
```

Counts shipments flagged as on time in the warehouse.

### Delayed Shipments

```DAX
Delayed Shipments =
CALCULATE (
    [Total Shipments],
    FactShipment[LateDeliveryFlag] = TRUE ()
)
```

Counts shipments flagged as late in the warehouse.

### On-Time Delivery %

```DAX
On-Time Delivery % =
DIVIDE ( [On-Time Shipments], [Delivered Shipments] )
```

Shows the share of delivered shipments that arrived on time.

Assumption:

- the denominator should be delivered shipments, not all shipments.

### Avg Transit Days

```DAX
Avg Transit Days =
AVERAGE ( FactShipment[TransitDays] )
```

Averages shipment transit days across rows where `TransitDays` is populated.

### Avg Delay Minutes

```DAX
Avg Delay Minutes =
AVERAGEX (
    FILTER ( FactShipment, FactShipment[LateDeliveryFlag] = TRUE () ),
    FactShipment[DeliveryDelayMinutes]
)
```

Averages delay minutes across late shipments only.

Assumption:

- on-time shipments with `0` delay are excluded so the measure reflects actual late-shipment severity.

### Exception Shipments

```DAX
Exception Shipments =
CALCULATE (
    [Total Shipments],
    FactShipment[ExceptionShipmentFlag] = TRUE ()
)
```

Counts shipment rows flagged as exception shipments.

### Exception Rate

```DAX
Exception Rate =
DIVIDE ( [Exception Shipments], [Total Shipments] )
```

Shows the share of shipments that had at least one exception.

### Shipments by Carrier

```DAX
Shipments by Carrier =
[Total Shipments]
```

Context-sensitive shipment count intended for visuals with `DimCarrier[CarrierName]` on the axis.

### Shipments by Route

```DAX
Shipments by Route =
[Total Shipments]
```

Context-sensitive shipment count intended for visuals with `DimRoute[RouteCode]` on the axis.

## Delivery Performance Measures

### Late Delivery %

```DAX
Late Delivery % =
DIVIDE ( [Delayed Shipments], [Delivered Shipments] )
```

Shows the share of delivered shipments that were late.

### Avg Transit Hours

```DAX
Avg Transit Hours =
AVERAGE ( FactShipment[TransitHours] )
```

Averages shipment transit hours where the fact row contains a value.

### Avg Scan Events Per Shipment

```DAX
Avg Scan Events Per Shipment =
DIVIDE ( [Total Scan Events], [Total Shipments] )
```

Shows average event volume per shipment.

## Route Efficiency Measures

### Avg Actual Distance Miles

```DAX
Avg Actual Distance Miles =
AVERAGE ( FactShipment[ActualDistanceMiles] )
```

Averages actual shipment distance.

### Avg Planned Distance Miles

```DAX
Avg Planned Distance Miles =
AVERAGE ( FactShipment[PlannedDistanceMiles] )
```

Averages planned shipment distance.

### Avg Distance Variance To Reference Miles

```DAX
Avg Distance Variance To Reference Miles =
AVERAGEX (
    FILTER (
        FactShipment,
        NOT ISBLANK ( FactShipment[ActualDistanceMiles] )
            && NOT ISBLANK ( RELATED ( DimRoute[ReferenceDistanceMiles] ) )
    ),
    FactShipment[ActualDistanceMiles] - RELATED ( DimRoute[ReferenceDistanceMiles] )
)
```

Compares actual shipment miles to the route benchmark stored in `DimRoute`.

Assumption:

- positive values mean actual miles exceeded the route reference.

### Avg Transit Variance Hours

```DAX
Avg Transit Variance Hours =
AVERAGEX (
    FILTER (
        FactShipment,
        NOT ISBLANK ( FactShipment[TransitHours] )
            && NOT ISBLANK ( RELATED ( DimRoute[ReferenceTransitHours] ) )
    ),
    FactShipment[TransitHours] - RELATED ( DimRoute[ReferenceTransitHours] )
)
```

Compares actual transit hours to the route benchmark transit hours.

### Route Benchmark Shipments

```DAX
Route Benchmark Shipments =
COUNTROWS (
    FILTER (
        FactShipment,
        NOT ISBLANK ( RELATED ( DimRoute[ReferenceDistanceMiles] ) )
            && NOT ISBLANK ( RELATED ( DimRoute[ReferenceTransitHours] ) )
    )
)
```

Counts shipment rows that have usable route benchmark attributes.

### Route Benchmark Coverage %

```DAX
Route Benchmark Coverage % =
DIVIDE ( [Route Benchmark Shipments], [Total Shipments] )
```

Shows how much of the shipment population is benchmark-enabled for route analysis.

### Cost Per Actual Mile

```DAX
Cost Per Actual Mile =
DIVIDE ( SUM ( FactShipment[ShipmentCost] ), SUM ( FactShipment[ActualDistanceMiles] ) )
```

Calculates shipment cost per actual mile traveled.

## Carrier Exception Measures

### Total Exceptions

```DAX
Total Exceptions =
SUM ( FactDeliveryException[ExceptionCount] )
```

Counts exception occurrences at fact-exception grain.

### Distinct Shipments Affected

```DAX
Distinct Shipments Affected =
DISTINCTCOUNT ( FactDeliveryException[ShipmentNumber] )
```

Counts unique shipments that had one or more exception fact rows.

### Avg Exception Delay Minutes

```DAX
Avg Exception Delay Minutes =
AVERAGE ( FactDeliveryException[DelayMinutesImpact] )
```

Averages actual delay impact captured on exception rows.

### Avg Delay Variance Minutes

```DAX
Avg Delay Variance Minutes =
AVERAGE ( FactDeliveryException[DelayVarianceMinutes] )
```

Compares actual exception delay to the mastered typical delay.

### Resolved Within 24 Hours %

```DAX
Resolved Within 24 Hours % =
DIVIDE (
    CALCULATE (
        [Total Exceptions],
        FactDeliveryException[ResolvedWithin24HoursFlag] = TRUE ()
    ),
    [Total Exceptions]
)
```

Shows the share of exception rows resolved within 24 hours.

## Operational Detail Measures

### Total Scan Events

```DAX
Total Scan Events =
SUM ( FactDeliveryEvent[EventCount] )
```

Counts all scan events loaded to the event fact.

### Exception Events

```DAX
Exception Events =
CALCULATE (
    [Total Scan Events],
    FactDeliveryEvent[ExceptionEventFlag] = TRUE ()
)
```

Counts event rows that were exception-related.

### Avg Events Per Shipment

```DAX
Avg Events Per Shipment =
DIVIDE ( [Total Scan Events], [Total Shipments] )
```

Shows average event density across shipments.

## Formatting Guidance

Recommended formats:

- counts: whole number
- percentages: `0.0%`
- days and hours: `0.00`
- miles: `0.00`
- currency: `$#,0.00`
- delay minutes: whole number or `0.0` depending on page

Keep the measure names aligned to [powerbi/dashboard-spec.md](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\powerbi\dashboard-spec.md) so screenshots, DAX, and spoken walkthroughs all use the same labels.

## Validation Guidance

After adding the measures:

- compare executive totals to [rpt.vw_DeliveryPerformance](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\sql\03_views\01_reporting_views.sql)
- compare route KPIs to [rpt.vw_RouteEfficiency](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\sql\03_views\01_reporting_views.sql)
- compare exception KPIs to [rpt.vw_CarrierExceptionTrends](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\sql\03_views\01_reporting_views.sql)
- run [tests/sql/05_reporting_view_checks.sql](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\tests\sql\05_reporting_view_checks.sql) before finalizing screenshots
