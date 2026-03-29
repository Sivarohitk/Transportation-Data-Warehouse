# Tools and Software To Install

## Required

- SQL Server Developer Edition 2019 or later
- SQL Server Management Studio 20 or later
- Visual Studio 2022
- SQL Server Integration Services Projects extension for Visual Studio
- Power BI Desktop
- Python 3.11 or later
- Git

## Recommended

- ODBC Driver 18 for SQL Server
- Azure Data Studio for lightweight SQL editing
- 7-Zip for handling source extracts and sample archives

## Windows Build Notes

- Run SSMS as a user with permission to create databases locally.
- Enable SQLCMD Mode in SSMS before running `sql/99_run_all.sql`.
- Install the SSIS extension from inside Visual Studio before creating the SSIS project.
- Keep Power BI Desktop and SQL Server on the same machine for the simplest demo setup.

## Suggested Local Stack

- Local SQL Server instance: `localhost`
- Warehouse database: `TransportationDW`
- SSIS solution location: `ssis/TransportationDW`
- Sample source file location: `data/generated`
