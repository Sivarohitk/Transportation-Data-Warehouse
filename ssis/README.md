# SSIS Guide

This folder is for the SSDT solution and Integration Services project that sit on top of the existing SQL Server ETL framework.

The package design now aligns to the real repo objects:

- `meta.usp_Start_Batch`
- `etl.usp_Load_Stage_From_Source`
- `etl.usp_Validate_Stage_Data`
- `etl.usp_Load_Dimensions`
- `etl.usp_Load_FactShipment`
- `etl.usp_Load_FactDeliveryEvent`
- `etl.usp_Load_FactDeliveryException`
- `etl.usp_Run_Incremental_Load`

## Project Name

- `TransportationDW`

## Package Set

- `load_source_to_stage.dtsx`
- `validate_stage_data.dtsx`
- `load_dimensions.dtsx`
- `load_facts.dtsx`
- `incremental_daily_load.dtsx`

## Design Rule

Keep SSIS responsible for orchestration, file ingestion, row counts, and error redirection.

Keep business rules, validation, dimensions, facts, watermarks, and shipment restatement in T-SQL.

## Main References

- [docs/ssis-package-design.md](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\docs\ssis-package-design.md)
- [docs/ssis-build-checklist.md](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\docs\ssis-build-checklist.md)
- [docs/ssis-screens-to-create.md](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\docs\ssis-screens-to-create.md)
