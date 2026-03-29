# Transportation Data Warehouse Project Specification

## 1. Purpose

This project demonstrates a realistic transportation analytics warehouse built in SQL Server with SSIS-driven ETL and Power BI reporting outputs. It is designed to match a resume narrative around dimensional modeling, repeatable ETL, incremental loading, validation logic, and BI-ready datasets.

## 2. Business Scenario

A logistics operations team needs reliable reporting on shipment execution, carrier performance, route efficiency, and delivery exceptions. Source data arrives from a mix of flat files and operational systems. The business needs a warehouse that standardizes these inputs, validates core lookups, logs data quality issues, and publishes consistent reporting datasets.

## 3. Scope

Included in this repo:

- SQL Server warehouse schemas and DDL
- Staging, metadata, validation, audit, and warehouse objects
- T-SQL load procedures for incremental warehouse processing
- Analytics-ready views for SQL-side KPI validation and lightweight BI prototypes
- Synthetic flat-file source data generator
- SSIS package design guidance and folder layout
- SQL smoke tests and build scripts

Out of scope for the initial repository scaffold:

- Production scheduling via SQL Server Agent
- CI/CD pipelines
- Role-based security model
- Slowly changing dimension Type 2 history
- Production-scale partitioning

## 4. Architectural Principles

- Kimball-style dimensional model with surrogate keys in warehouse dimensions
- Separate staging from warehouse and reporting layers
- Batch-based ETL with explicit metadata and audit history
- Validation before warehouse loads
- Incremental upserts into dimensions and facts
- SQL Server syntax only for database objects and ETL procedures
- SSIS packages act as orchestration and source-ingestion layer, while T-SQL handles warehouse logic

## 5. Data Domains

### Core Dimensions

- `dw.DimDate`
- `dw.DimCarrier`
- `dw.DimLocation`
- `dw.DimRoute`
- `dw.DimDeliveryException`
- `dw.DimShipmentStatus`

### Core Facts

- `dw.FactShipment`
- `dw.FactDeliveryEvent`
- `dw.FactDeliveryException`

## 6. Fact Grain

### Shipment Fact Grain

One row per shipment number representing the latest warehouse-approved shipment state for delivery performance and route analytics.

### Delivery Event Fact Grain

One row per shipment status event representing scan-level operational history such as pickup, in-transit, out-for-delivery, exception, and delivered events.

### Delivery Exception Fact Grain

One row per shipment number, exception type, and exception timestamp representing a distinct delivery exception event.

## 7. Source Data Assumptions

### Flat File Sources

- `carrier_lookup.csv`
- `locations.csv`
- `routes.csv`
- `shipments.csv`
- `daily_delivery_scan_events.csv`
- `delivery_exceptions.csv`
- `exception_code_lookup.csv`
- `route_distance_reference.csv`

### Relational Source Extension

The repo includes a normalized `src` schema that simulates the operational transportation source system. SSIS can load from that same database locally or be redirected later to a separate source database without changing the warehouse design.

## 8. Data Quality Rules

- Carrier, route, origin location, and destination location are required for shipments.
- Shipment create date and planned delivery date are required.
- Actual delivery date cannot be earlier than actual pickup date.
- Routes must reference valid origin and destination locations.
- Delivery exceptions must reference a known shipment and include an exception code and timestamp.
- Invalid staging rows are flagged and logged to `audit.Validation_Error` instead of loaded into facts.

## 9. Incremental Load Strategy

- SSIS starts a batch in `meta.Batch_Run` and lands each source extract into its corresponding `stg` table with that shared `BatchID`.
- Validation logic runs against the current batch.
- Dimensions are upserted first.
- Shipment fact data is merged by `ShipmentNumber`.
- Delivery event fact data is merged by `ShipmentNumber + EventSequenceNumber`.
- Delivery exception fact data is merged by `ShipmentNumber + DeliveryExceptionKey + ExceptionDateTime`.
- Impacted shipments are restaged and recalculated when later events or exceptions arrive.
- Watermarks and batch status are recorded in metadata tables.

## 10. Reporting Outputs

### Delivery Performance Dataset

Measures:

- shipment counts
- on-time delivery counts and percentage
- average delay minutes
- average transit hours
- average revenue and cost per shipment

### Route Efficiency Dataset

Measures:

- average planned vs actual miles
- miles variance
- cost per mile
- shipment volume
- on-time delivery percentage by route and carrier

### Carrier Exception Trends Dataset

Measures:

- exception counts
- impacted shipments
- average delay impact
- resolved-within-24-hours percentage

## 11. Success Criteria

- The database can be created from source-controlled SQL scripts.
- The synthetic data generator produces realistic flat files for a demo run.
- Warehouse procedures execute in a repeatable batch sequence.
- Validation and runtime errors are traceable in audit tables.
- Reporting views are usable for SQL-side KPI validation.
- The documented Power BI model can be built on top of the warehouse tables directly.
- The design is simple enough to explain clearly in an interview.

## 12. Target User Workflow

1. Generate sample source files.
2. Run the SQL build script.
3. Seed the `src` schema or create SSIS packages in SSDT using the documented package inventory.
4. Load staging tables through `etl.usp_Load_Stage_From_Source` or SSIS flat-file packages.
5. Execute `etl.usp_Run_Incremental_Load`.
6. Validate outputs using SQL tests.
7. Build a Power BI report on top of the `dw` fact and dimension tables and validate KPI totals against the `rpt` views.
