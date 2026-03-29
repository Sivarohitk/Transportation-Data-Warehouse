# Power BI Workspace

Use this folder for the `.pbix` file, screenshots, semantic-model notes, DAX documentation, and dashboard design assets.

## Recommended Report Name

- `TransportationDW_Portfolio.pbix`

## Recommended Model Strategy

Use the `dw` fact and dimension tables as the primary Power BI semantic model.

Use the `rpt` views only for SQL-side validation and KPI cross-checking.

## Report Pages

- Executive Overview
- Delivery Performance
- Route Efficiency
- Carrier Exceptions
- Operational Detail

## Main References

- [powerbi/model-design.md](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\powerbi\model-design.md)
- [powerbi/dax-measures.md](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\powerbi\dax-measures.md)
- [powerbi/dashboard-spec.md](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\powerbi\dashboard-spec.md)
- [docs/powerbi-build-steps.md](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\docs\powerbi-build-steps.md)

## Recommended Build Order

1. Import the `dw` fact and dimension tables into Power BI Desktop.
2. Create the role-playing `DimLocation` reference tables for origin, destination, and event location.
3. Build the relationships and mark `DimDate` as the date table.
4. Create the `Measures` table and paste in the approved DAX measures.
5. Build the five report pages in the order defined by [powerbi/dashboard-spec.md](C:\Users\sivar\OneDrive\Documents\GitHub\Transportation Data Warehouse\powerbi\dashboard-spec.md).
6. Validate KPI totals against the SQL `rpt` views and the reporting-view test checks.
