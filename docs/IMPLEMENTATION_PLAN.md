# Phased Implementation Plan

## Phase 1: Foundation

Deliverables:

- repository structure
- project specification
- architecture documentation
- SQLCMD build script
- schema and table DDL

Exit criteria:

- database objects build successfully from source control

## Phase 2: Source Data and Staging

Deliverables:

- synthetic source-data generator
- landing file conventions
- staging tables and metadata tables
- file-level load logging pattern

Exit criteria:

- sample files can be generated and mapped into staging through SSIS

## Phase 3: Validation and Incremental Warehouse Loads

Deliverables:

- batch control procedures
- validation rules with rejection logging
- dimension upsert procedures
- shipment, event, and exception fact merge procedures
- shipment restatement logic for later events and exceptions
- watermark updates

Exit criteria:

- a batch can be processed repeatedly without duplicating facts

## Phase 4: SSIS Buildout

Deliverables:

- SSDT solution and SSIS project
- flat-file connection managers
- SQL Server connection managers
- package parameters and environment configuration
- control flow sequence that ends with `etl.usp_Run_Incremental_Load`

Exit criteria:

- packages run locally and populate staging plus warehouse layers

## Phase 5: Reporting and Power BI

Deliverables:

- Power BI model connected to `dw` fact and dimension tables
- KPI validation against the `rpt` views
- pages for delivery performance, route efficiency, carrier exception trends, and operational detail
- report-level filters and KPI cards

Exit criteria:

- the report supports a clear portfolio demo with drill-down analytics

## Phase 6: Testing and Portfolio Polish

Deliverables:

- smoke tests
- screenshot checklist and demo setup guide
- data dictionary summary
- interview-ready talking points in README

Exit criteria:

- repo is presentation-ready and easy to explain end to end
