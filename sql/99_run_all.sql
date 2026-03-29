:setvar DatabaseName TransportationDW

:r .\00_setup\00_create_database.sql
:r .\00_setup\01_create_schemas.sql
:r .\source\01_create_source_schema.sql
:r .\01_tables\01_metadata_tables.sql
:r .\01_tables\02_staging_tables.sql
:r .\01_tables\03_dimension_tables.sql
:r .\01_tables\04_fact_tables.sql
:r .\02_procs\01_etl_batch_framework.sql
:r .\02_procs\02_validate_stage.sql
:r .\02_procs\06_stage_load_framework.sql
:r .\02_procs\03_load_dimensions.sql
:r .\02_procs\04_load_facts.sql
:r .\02_procs\05_run_incremental_load.sql
:r .\03_views\01_reporting_views.sql
:r .\04_tests\00_data_quality_checks.sql
