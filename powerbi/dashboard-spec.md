# Dashboard Specification

## Design Direction

Build one Power BI report with five pages:

1. Executive Overview
2. Delivery Performance
3. Route Efficiency
4. Carrier Exceptions
5. Operational Detail

Recommended report style:

- 16:9 layout
- light background with restrained accent colors
- green for on-time
- amber for delays
- red for exceptions
- blue for route-efficiency visuals

Keep the pages easy to talk through in order from summary to diagnosis.

## KPI Definitions

- `Total Shipments`
  Count of shipment fact rows using `FactShipment[ShipmentCount]`.
- `On-Time Delivery %`
  On-time shipments divided by delivered shipments.
- `Delayed Shipments`
  Shipments where `LateDeliveryFlag = 1`.
- `Avg Transit Days`
  Average `FactShipment[TransitDays]` where present.
- `Avg Delay Minutes`
  Average `FactShipment[DeliveryDelayMinutes]` across late shipments only.
- `Exception Rate`
  Exception shipments divided by total shipments.
- `Shipments by Carrier`
  `Total Shipments` shown in carrier filter context.
- `Shipments by Route`
  `Total Shipments` shown in route filter context.

## Page 1: Executive Overview

### Page Objective

Give a fast summary of shipment volume, delivery performance, route coverage, and exception exposure.

### Visuals To Place

- KPI cards:
  - `Total Shipments`
  - `Delivered Shipments`
  - `On-Time Delivery %`
  - `Delayed Shipments`
  - `Exception Rate`
- Line and clustered column chart:
  - axis: `DimDate[CalendarYear]` + `DimDate[MonthName]`
  - columns: `Total Shipments`
  - line: `On-Time Delivery %`
- Bar chart:
  - axis: `DimCarrier[CarrierName]`
  - value: `Shipments by Carrier`
- Bar chart:
  - axis: `DimDeliveryException[ExceptionCategory]`
  - value: `Total Exceptions`
- Table or matrix:
  - `DimRoute[RouteCode]`
  - `DimCarrier[CarrierName]`
  - `On-Time Delivery %`
  - `Avg Delay Minutes`
  - `Exception Rate`

### KPIs And Cards

- `Total Shipments`
- `On-Time Delivery %`
- `Delayed Shipments`
- `Exception Rate`
- `Avg Transit Days`

### Slicers

- `DimDate[CalendarYear]`
- `DimCarrier[CarrierName]`
- `FactShipment[ServiceLevel]`
- `DimRoute[RouteType]`

### Drill-Through Ideas

- drill through to `Delivery Performance` by `CarrierName`
- drill through to `Carrier Exceptions` by `ExceptionCategory`
- drill through to `Operational Detail` by `ShipmentNumber`

### Tooltip Ideas

- show shipment count, on-time %, avg delay, and exception rate for the hovered carrier or route

### Business Question

How is the transportation network performing overall, and where should attention go first?

## Page 2: Delivery Performance

### Page Objective

Analyze late deliveries, service-level performance, and destination-level trends.

### Visuals To Place

- KPI cards:
  - `Delivered Shipments`
  - `On-Time Delivery %`
  - `Delayed Shipments`
  - `Avg Delay Minutes`
  - `Avg Transit Days`
- Line chart:
  - axis: `DimDate[CalendarYear]` + `DimDate[MonthName]`
  - values:
    - `On-Time Delivery %`
    - `Avg Delay Minutes`
- Stacked bar chart:
  - axis: `DimCarrier[CarrierName]`
  - values:
    - `On-Time Shipments`
    - `Delayed Shipments`
- Matrix:
  - rows: `FactShipment[ServiceLevel]`, `DimCarrier[CarrierName]`
  - values:
    - `Total Shipments`
    - `On-Time Delivery %`
    - `Avg Transit Days`
    - `Avg Delay Minutes`
- Bar chart:
  - axis: `DimLocation_Destination[StateProvince]`
  - value: `Delayed Shipments`

### KPIs And Cards

- `On-Time Delivery %`
- `Delayed Shipments`
- `Avg Delay Minutes`
- `Avg Transit Days`

### Slicers

- `DimDate[CalendarYear]`
- `DimCarrier[CarrierName]`
- `FactShipment[ServiceLevel]`
- `DimLocation_Origin[StateProvince]`
- `DimLocation_Destination[StateProvince]`

### Drill-Through Ideas

- drill through to `Operational Detail` by `ShipmentNumber`
- drill through to `Route Efficiency` by `RouteCode`

### Tooltip Ideas

- show planned distance, actual distance, transit hours, and exception rate for the hovered route or carrier

### Business Question

Which carriers, service levels, and destinations are driving late delivery performance?

## Page 3: Route Efficiency

### Page Objective

Compare actual shipment performance against route benchmark distance and transit expectations.

### Visuals To Place

- KPI cards:
  - `Total Shipments`
  - `Avg Actual Distance Miles`
  - `Avg Transit Hours`
  - `Avg Distance Variance To Reference Miles`
  - `Route Benchmark Coverage %`
- Scatter chart:
  - x-axis: `Avg Actual Distance Miles`
  - y-axis: `Avg Transit Variance Hours`
  - size: `Total Shipments`
  - details: `DimRoute[RouteCode]`
  - legend: `DimRoute[FuelZone]`
- Bar chart:
  - axis: `DimRoute[RouteCode]`
  - value: `Avg Transit Variance Hours`
- Matrix:
  - rows: `DimRoute[RouteCode]`
  - columns optional: `DimCarrier[CarrierName]`
  - values:
    - `Total Shipments`
    - `Avg Actual Distance Miles`
    - `Avg Distance Variance To Reference Miles`
    - `Avg Transit Variance Hours`
    - `Cost Per Actual Mile`
- Bar chart:
  - axis: `DimLocation_Origin[City]`
  - value: `Shipments by Route`

### KPIs And Cards

- `Avg Distance Variance To Reference Miles`
- `Avg Transit Variance Hours`
- `Route Benchmark Coverage %`
- `Cost Per Actual Mile`

### Slicers

- `DimDate[CalendarYear]`
- `DimCarrier[CarrierName]`
- `DimRoute[RouteType]`
- `DimRoute[FuelZone]`
- `DimLocation_Origin[City]`
- `DimLocation_Destination[City]`

### Drill-Through Ideas

- drill through to `Operational Detail` by `RouteCode`
- drill through to `Delivery Performance` for a route or carrier slice

### Tooltip Ideas

- show route benchmark distance, benchmark transit hours, on-time %, and exception rate

### Business Question

Which routes are over benchmark on miles or transit time, and which lanes are most efficient?

## Page 4: Carrier Exceptions

### Page Objective

Show normalized exception trends by carrier, category, severity, and responsible party.

### Visuals To Place

- KPI cards:
  - `Total Exceptions`
  - `Distinct Shipments Affected`
  - `Exception Rate`
  - `Avg Exception Delay Minutes`
  - `Resolved Within 24 Hours %`
- Stacked column chart:
  - axis: `DimDate[CalendarYear]` + `DimDate[MonthName]`
  - legend: `DimDeliveryException[ExceptionCategory]`
  - value: `Total Exceptions`
- Bar chart:
  - axis: `DimCarrier[CarrierName]`
  - value: `Total Exceptions`
- Bar chart:
  - axis: `DimDeliveryException[ResponsibleParty]`
  - value: `Total Exceptions`
- Matrix:
  - rows:
    - `DimCarrier[CarrierName]`
    - `DimDeliveryException[ExceptionCategory]`
    - `DimDeliveryException[ExceptionCode]`
  - values:
    - `Total Exceptions`
    - `Distinct Shipments Affected`
    - `Avg Exception Delay Minutes`
    - `Avg Delay Variance Minutes`
    - `Resolved Within 24 Hours %`

### KPIs And Cards

- `Total Exceptions`
- `Exception Rate`
- `Distinct Shipments Affected`
- `Resolved Within 24 Hours %`

### Slicers

- `DimDate[CalendarYear]`
- `DimCarrier[CarrierName]`
- `DimDeliveryException[ExceptionCategory]`
- `DimDeliveryException[SeverityCode]`
- `DimDeliveryException[ResponsibleParty]`

### Drill-Through Ideas

- drill through to `Operational Detail` by `ShipmentNumber`
- drill through to `Delivery Performance` for the selected carrier

### Tooltip Ideas

- show category, average delay impact, average variance to typical delay, and distinct shipments affected

### Business Question

Which carriers and exception categories create the most operational disruption, and how quickly are they resolved?

## Page 5: Operational Detail

### Page Objective

Provide shipment-level, event-level, and exception-level detail for drill-through and root-cause investigation.

### Visuals To Place

- KPI cards:
  - `Total Shipments`
  - `Total Scan Events`
  - `Total Exceptions`
  - `Avg Events Per Shipment`
- Shipment detail table:
  - `FactShipment[ShipmentNumber]`
  - `DimCarrier[CarrierName]`
  - `DimRoute[RouteCode]`
  - `FactShipment[ServiceLevel]`
  - `FactShipment[ShipmentStatus]`
  - `FactShipment[TransitDays]`
  - `FactShipment[DeliveryDelayMinutes]`
  - `FactShipment[ExceptionShipmentFlag]`
- Delivery event table:
  - `FactDeliveryEvent[ShipmentNumber]`
  - `FactDeliveryEvent[EventSequenceNumber]`
  - `FactDeliveryEvent[EventDateTime]`
  - `DimShipmentStatus[StatusDescription]`
  - `FactDeliveryEvent[ScanType]`
  - `FactDeliveryEvent[EventSource]`
  - `DimLocation_Event[City]`
  - `DimLocation_Event[StateProvince]`
- Delivery exception table:
  - `FactDeliveryException[ShipmentNumber]`
  - `FactDeliveryException[ExceptionDateTime]`
  - `DimDeliveryException[ExceptionCategory]`
  - `DimDeliveryException[ExceptionCode]`
  - `DimDeliveryException[SeverityCode]`
  - `FactDeliveryException[DelayMinutesImpact]`
  - `FactDeliveryException[DelayVarianceMinutes]`
  - `FactDeliveryException[ResolvedWithin24HoursFlag]`

### KPIs And Cards

- `Total Scan Events`
- `Total Exceptions`
- `Avg Events Per Shipment`

### Slicers

- `FactShipment[ShipmentNumber]`
- `DimCarrier[CarrierName]`
- `DimRoute[RouteCode]`
- `DimShipmentStatus[StatusGroup]`
- `DimDeliveryException[ExceptionCategory]`

### Drill-Through Ideas

- make this the main drill-through page from all other pages using:
  - `FactShipment[ShipmentNumber]`
  - `DimCarrier[CarrierName]`
  - `DimRoute[RouteCode]`

### Tooltip Ideas

- shipment summary tooltip with carrier, route, service level, on-time flag, total events, and total exceptions

### Business Question

What event trail and exception history explain the KPI result for a selected shipment, carrier, or route?

## Hidden Fields And UX Guidance

- hide all technical keys and ETL fields from the report field list
- keep measures grouped in the `Measures` table
- keep slicers consistent in placement across pages
- use a left-side slicer rail or a top filter band consistently
- sync the main date and carrier slicers across pages
