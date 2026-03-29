# Interview Q&A

## 30-Second Summary

I built a transportation data warehouse in SQL Server that ingests both relational source tables and flat-file feeds, validates data in staging, loads a Kimball-style warehouse, supports rerun-safe incremental loading with shipment restatement, and exposes analytics-ready outputs for Power BI reporting.

## What I Built End To End

Q: What did you build in this project end to end?

A: I built the source schema, the batch-aware staging layer, validation and reject handling, the dimensional warehouse, the incremental load framework with watermarks, the SQL test suite, and the reporting outputs. I also documented the SSIS package design and the Power BI semantic model so the desktop-tool pieces can be built locally against the same SQL framework.

## What Is Automated

Q: What parts are automated today?

A: The SQL side is automated. I can generate source data, build the database from scripts, seed the source schema, load stage from the relational source path, run the incremental warehouse load, and validate the results with SQL tests. Batch control, watermark promotion, load audit counts, and shipment restatement are all handled in T-SQL procedures.

## What Is Still Manual

Q: What parts are still manual?

A: The actual `.dtsx` packages and `.pbix` file still need to be created in SSDT and Power BI Desktop. I documented both carefully instead of checking in fake XML or a placeholder report. That keeps the repo honest while still showing exactly how the desktop artifacts should be built.

## Why This Schema

Q: Why did you choose a Kimball-style dimensional model?

A: The business questions are measurement-heavy and sliceable by carrier, route, location, date, status, and exception type. A star schema makes those questions easy to answer in SQL and Power BI, and it is much easier to explain than exposing normalized operational tables to BI users.

## Why Keep `FactDeliveryEvent`

Q: Why did you keep an event fact instead of only a shipment fact?

A: The daily scan-event feed added real analytical value. Keeping `FactDeliveryEvent` preserved shipment lifecycle detail like pickup, in-transit, out-for-delivery, delivered, and exception events. That supports missed-scan analysis, event timing, and operational drill-through without bloating the main shipment fact.

## Why The Incremental Strategy

Q: Why did you choose this incremental-load design?

A: I wanted one simple framework instead of multiple overlapping runners. SQL sources use timestamp plus identity watermarks, flat files use file registration plus batch tracking, and watermarks are promoted only after successful warehouse completion. That keeps reruns safe and easy to explain.

## How Shipment Restatement Works

Q: How do you handle later events or exceptions that arrive after the shipment row?

A: Later events or exceptions make that shipment an impacted shipment for the new batch. I restage the current shipment snapshot plus the shipment's event and exception history, then recalculate `FactShipment` so KPIs like status, scan count, exception count, transit timing, and on-time flags stay current.

## Rejects Vs Unknown Members

Q: How did you decide between rejects and unknown members?

A: Invalid mandatory operational rows are rejected in stage. For example, a shipment without a valid route or carrier should not reach the warehouse. Unknown dimension members are only used later as a safety net for analytic lookups, such as a late-arriving event location or unresolved exception lookup.

## How Duplicates Are Prevented

Q: How do you prevent duplicate loads?

A: I deduplicate stage data by business key and use unique business-key grains in the warehouse. `FactShipment` is unique by shipment number, `FactDeliveryEvent` by shipment number plus event sequence, and `FactDeliveryException` by shipment number plus exception key and timestamp. The merge logic is conditional so unchanged reruns do not inflate counts.

## What The Power BI Report Answers

Q: What metrics does the Power BI layer answer?

A: It answers total shipments, on-time delivery percentage, delayed shipments, average transit days, average delay minutes, exception rate, shipments by carrier, shipments by route, route benchmark variance, and carrier exception trends. It also supports an operational detail page for shipment, event, and exception drill-through.

## Why Power BI Uses `dw` Tables Instead Of `rpt` Views

Q: Why not just build the report on the reporting views?

A: The `rpt` views are useful for KPI cross-checking, but the warehouse already has a clean star schema. Building the semantic model directly on `dw` tables preserves drill-through, keeps the model closer to the warehouse grain, and makes the design easier to explain.

## Best Artifacts To Show Live

Q: What should I show first in a demo?

A: Start with the README architecture diagram, then show `meta.Batch_Run`, `audit.Load_Audit`, `meta.Watermark`, one reject example, `FactShipment`, `FactDeliveryEvent`, and one `rpt` view. After that, show the SSIS package design and the Power BI dashboard spec.

## What I Would Do Next

Q: What would you add next if you had more time?

A: I would build the actual SSDT packages, create the `.pbix`, capture final screenshots, and add a short demo runbook. After that, the next technical improvements would be SCD Type 2 handling for route benchmark history, deployment automation, and possibly a SQL Server Agent or SSISDB execution story.
