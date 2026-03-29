# Resume Bullet Mapping

## Resume Bullet

`Designed and implemented a transportation data warehouse in SQL Server with fact and dimension tables for shipments, carriers, routes, locations, and delivery exceptions.
Developed SSIS ETL packages to extract data from flat files and relational sources, perform cleansing and transformation, and load validated data into staging and warehouse layers.
Built incremental load workflows, lookup validations, and error-handling logic to improve data consistency and support repeatable reporting processes.
Created analytics-ready datasets for delivery performance, route efficiency, and carrier exception trends, enabling dashboard development and BI reporting.`

## Line-By-Line Evidence

| Resume Claim | Repo Evidence | Notes |
|---|---|---|
| Designed and implemented a transportation data warehouse in SQL Server | `sql/01_tables/03_dimension_tables.sql`, `sql/01_tables/04_fact_tables.sql`, `docs/dimensional-model.md` | The warehouse includes `DimDate`, `DimCarrier`, `DimLocation`, `DimRoute`, `DimDeliveryException`, `DimShipmentStatus`, `FactShipment`, `FactDeliveryEvent`, and `FactDeliveryException`. |
| Fact and dimension tables for shipments, carriers, routes, locations, and delivery exceptions | `dw.FactShipment`, `dw.FactDeliveryEvent`, `dw.FactDeliveryException`, plus the dimensional tables in `sql/01_tables/03_dimension_tables.sql` | The model also includes scan-event detail through `FactDeliveryEvent`, which strengthens the transportation story. |
| Developed SSIS ETL packages to extract data from flat files and relational sources | `docs/ssis-package-design.md`, `docs/ssis-build-checklist.md`, `docs/staging-design.md` | The repo documents five SSDT packages aligned to the real SQL objects. The actual `.dtsx` files still need to be created manually in SSDT. |
| Perform cleansing and transformation, and load validated data into staging and warehouse layers | `sql/02_procs/06_stage_load_framework.sql`, `sql/02_procs/03_load_dimensions.sql`, `sql/02_procs/04_load_facts.sql`, `docs/business-rules.md` | Standardization, validation, lookup handling, deduplication, and fact derivations are implemented in SQL Server. |
| Built incremental load workflows | `sql/02_procs/01_etl_batch_framework.sql`, `sql/02_procs/05_run_incremental_load.sql`, `docs/incremental-load-design.md` | Batch control, pending and successful watermarks, idempotent reruns, and impacted-shipment restatement are all covered. |
| Lookup validations and error-handling logic | `etl.usp_Validate_Stage_Data`, `audit.Validation_Error`, `audit.Stage_Row_Reject`, `audit.Error_Log`, `sql/04_tests/00_data_quality_checks.sql` | Invalid operational rows are rejected in stage; unresolved analytic lookups can use unknown members later in the warehouse. |
| Support repeatable reporting processes | `tests/sql`, `sql/04_tests/00_data_quality_checks.sql`, `README.md` run steps | The repo includes a repeatable local build, load, validate, and rerun sequence. |
| Created analytics-ready datasets for delivery performance, route efficiency, and carrier exception trends | `sql/03_views/01_reporting_views.sql`, `powerbi/model-design.md`, `powerbi/dashboard-spec.md` | The `rpt` views provide SQL-side validation datasets, while the Power BI design uses the `dw` star schema directly. |
| Enabling dashboard development and BI reporting | `powerbi/dax-measures.md`, `powerbi/dashboard-spec.md`, `docs/powerbi-build-steps.md` | The semantic model, DAX, page layouts, and build steps are fully documented. The actual `.pbix` still needs to be built in Power BI Desktop. |

## Honest Portfolio Positioning

What is fully implemented in source control:

- SQL source, staging, warehouse, incremental logic, reporting views, and SQL tests
- synthetic data generation
- SSIS and Power BI implementation guidance

What still needs manual desktop work:

- create `.dtsx` packages in SSDT
- create the `.pbix` report in Power BI Desktop
- capture final screenshots after successful local runs

## Best Short Explanation

If you need a concise interview version, use this:

`I built the full SQL Server warehouse, staging, validation, audit, incremental, and reporting layers in source-controlled T-SQL. I also documented the SSDT package design and the Power BI semantic model so the repo is reproducible locally without hiding business logic inside tool-specific binaries.`
