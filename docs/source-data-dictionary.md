# Source Data Dictionary

## Purpose

This document describes the source-system layer added for the transportation warehouse demo. The source model is intentionally simple and OLTP-oriented: it stores operational shipment records, scan history, and exceptions, and it also publishes flat-file extracts that can be consumed by SSIS.

## SQL Server Source Schema

### `src.Carrier`

Operational carrier master used by shipments and source lookups.

Columns:

- `CarrierID`: surrogate primary key
- `CarrierCode`: stable business key used in flat files and downstream warehouse loads
- `SCACCode`: carrier SCAC-style code
- `CarrierName`: carrier display name
- `CarrierMode`: transport mode such as truckload, LTL, intermodal, or parcel
- `CarrierTier`: reporting tier such as national, regional, or last mile
- `HomeCity`: carrier home city
- `HomeStateProvince`: carrier home state
- `ActiveFlag`: active/inactive indicator

### `src.Location`

Operational location master for origin, destination, depot, hub, and distribution-center references.

Columns:

- `LocationID`: surrogate primary key
- `LocationCode`: stable business key used in routes, shipments, and flat files
- `LocationName`: location display name
- `LocationType`: distribution center, hub, depot, or cross dock
- `AddressLine1`: operational address
- `City`: city name
- `StateProvince`: US state or province code
- `CountryCode`: country code
- `PostalCode`: postal code
- `Region`: reporting region
- `Latitude` / `Longitude`: mapping coordinates
- `ActiveFlag`: active/inactive indicator

### `src.Route`

Lane-level route master connecting origin and destination locations.

Columns:

- `RouteID`: surrogate primary key
- `RouteCode`: stable route business key
- `OriginLocationID`: foreign key to `src.Location`
- `DestinationLocationID`: foreign key to `src.Location`
- `RouteType`: regional or long-haul lane category
- `StandardDistanceMiles`: expected lane distance
- `StandardTransitHours`: expected lane transit time
- `ActiveFlag`: active/inactive indicator
- `EffectiveStartDate`: lane effective date
- `EffectiveEndDate`: optional end date

### `src.Shipment`

Shipment header table representing the current operational state of a shipment.

Columns:

- `ShipmentID`: surrogate primary key
- `ShipmentNumber`: stable shipment business key
- `CarrierID`: foreign key to `src.Carrier`
- `RouteID`: foreign key to `src.Route`
- `OriginLocationID`: foreign key to `src.Location`
- `DestinationLocationID`: foreign key to `src.Location`
- `CustomerReferenceNumber`: external customer/order reference
- `ServiceLevel`: standard, priority, or expedited
- `CurrentStatus`: current operational status such as delivered, in transit, out for delivery, or exception
- `ShipmentCreateDateTime`: shipment creation timestamp
- `PlannedPickupDateTime`: planned pickup timestamp
- `ActualPickupDateTime`: actual pickup timestamp
- `PlannedDeliveryDateTime`: planned delivery timestamp
- `ActualDeliveryDateTime`: actual delivery timestamp when delivered
- `WeightLbs`: shipment weight
- `PieceCount`: package or pallet count
- `ShipmentRevenue`: revenue amount
- `ShipmentCost`: cost amount
- `PlannedDistanceMiles`: expected shipment miles
- `ActualDistanceMiles`: realized shipment miles
- `SourceModifiedAt`: last source update timestamp

### `src.Shipment_Status_History`

Operational event history used to simulate carrier scans and daily delivery event feeds.

Columns:

- `ShipmentStatusHistoryID`: surrogate primary key
- `ShipmentID`: foreign key to `src.Shipment`
- `EventSequenceNumber`: per-shipment event ordering
- `StatusCode`: compact status code such as `PICKED_UP`, `OUT_FOR_DELIVERY`, `WEATHER_HOLD`
- `StatusDescription`: business-friendly event description
- `EventDateTime`: event timestamp
- `LocationID`: optional foreign key to `src.Location`
- `ScanType`: event type such as system, scan, alert, or delivery
- `EventSource`: source channel such as TMS, handheld scan, or carrier EDI
- `ExceptionCode`: optional linked exception code
- `Notes`: event note or context

### `src.Delivery_Exception`

Operational exception table used to track carrier and delivery issues.

Columns:

- `DeliveryExceptionID`: surrogate primary key
- `ShipmentID`: foreign key to `src.Shipment`
- `ExceptionCode`: business exception code
- `ExceptionDescription`: exception description
- `ExceptionCategory`: grouped category such as weather, damage, process, or address
- `SeverityCode`: low, medium, or high severity
- `ExceptionStatus`: open or closed
- `ExceptionDateTime`: exception start timestamp
- `ResolvedDateTime`: exception resolution timestamp
- `DelayMinutesImpact`: delay impact estimate in minutes
- `ResponsibleParty`: carrier, customer, or operations owner
- `Notes`: explanatory note

## Flat-File Source Extracts

The generator writes the following raw files into `data/raw/`.

### `carrier_lookup.csv`

Carrier reference extract for source lookups and SSIS flat-file ingestion.

Key fields:

- `CarrierCode`
- `SCACCode`
- `CarrierName`
- `CarrierMode`
- `CarrierTier`
- `HomeCity`
- `HomeStateProvince`

### `locations.csv`

Operational location extract aligned to `src.Location`.

Key fields:

- `LocationCode`
- `LocationName`
- `LocationType`
- `AddressLine1`
- `City`
- `StateProvince`
- `PostalCode`
- `Region`

### `routes.csv`

Operational route extract aligned to `src.Route`.

Key fields:

- `RouteCode`
- `OriginLocationCode`
- `DestinationLocationCode`
- `RouteType`
- `StandardDistanceMiles`
- `StandardTransitHours`

### `shipments.csv`

Operational shipment header extract aligned to `src.Shipment`.

Key fields:

- `ShipmentNumber`
- `CarrierCode`
- `RouteCode`
- `OriginLocationCode`
- `DestinationLocationCode`
- `CurrentStatus`
- `ShipmentCreateDateTime`
- `PlannedDeliveryDateTime`
- `ActualDeliveryDateTime`

### `daily_delivery_scan_events.csv`

Event-level operational scan feed aligned to `src.Shipment_Status_History`.

Key fields:

- `ShipmentNumber`
- `EventSequenceNumber`
- `StatusCode`
- `StatusDescription`
- `EventDateTime`
- `LocationCode`
- `ScanType`
- `EventSource`
- `ExceptionCode`

### `delivery_exceptions.csv`

Shipment exception extract aligned to `src.Delivery_Exception`.

Key fields:

- `ShipmentNumber`
- `ExceptionCode`
- `ExceptionCategory`
- `SeverityCode`
- `ExceptionStatus`
- `ExceptionDateTime`
- `ResolvedDateTime`
- `DelayMinutesImpact`

### `exception_code_lookup.csv`

Reference file for exception validation and reporting standardization.

Key fields:

- `ExceptionCode`
- `ExceptionDescription`
- `ExceptionCategory`
- `SeverityCode`
- `TypicalDelayMinutes`
- `ResponsibleParty`

### `route_distance_reference.csv`

Reference file for route-distance validation and lane benchmarking.

Key fields:

- `RouteCode`
- `OriginLocationCode`
- `DestinationLocationCode`
- `ReferenceDistanceMiles`
- `ReferenceTransitHours`
- `FuelZone`

## Data Characteristics

The synthetic source set is designed to support meaningful analytics and ETL demos:

- 10,000 shipments by default
- multiple carriers across multiple US cities and states
- delivered, delayed, in-transit, and exception shipments
- weather delays
- damaged shipments
- missed scans
- address issues
- capacity and equipment exceptions
- event-level delivery scan history for operational timeline analysis

