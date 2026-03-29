# SSDT Project Folder

Create the Visual Studio solution and SSIS project here.

Recommended project name:

- `TransportationDW`

Recommended package names:

- `load_source_to_stage.dtsx`
- `validate_stage_data.dtsx`
- `load_dimensions.dtsx`
- `load_facts.dtsx`
- `incremental_daily_load.dtsx`

Use [docs/ssis-package-design.md](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\docs\ssis-package-design.md) as the source of truth when building the packages in SSDT.
