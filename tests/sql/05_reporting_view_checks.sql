USE [TransportationDW];
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.views
    WHERE object_id = OBJECT_ID(N'rpt.vw_DeliveryPerformance')
)
BEGIN
    THROW 50000, 'rpt.vw_DeliveryPerformance is missing.', 1;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.views
    WHERE object_id = OBJECT_ID(N'rpt.vw_RouteEfficiency')
)
BEGIN
    THROW 50000, 'rpt.vw_RouteEfficiency is missing.', 1;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.views
    WHERE object_id = OBJECT_ID(N'rpt.vw_CarrierExceptionTrends')
)
BEGIN
    THROW 50000, 'rpt.vw_CarrierExceptionTrends is missing.', 1;
END;
GO

DECLARE @DeliveredFactShipmentCount bigint =
(
    SELECT ISNULL(SUM(ShipmentCount), 0)
    FROM dw.FactShipment
    WHERE ActualDeliveryDateKey > 0
);

DECLARE @DeliveryPerformanceShipmentCount bigint =
(
    SELECT ISNULL(SUM(ShipmentCount), 0)
    FROM rpt.vw_DeliveryPerformance
);

DECLARE @RouteEfficiencyShipmentCount bigint =
(
    SELECT ISNULL(SUM(ShipmentCount), 0)
    FROM rpt.vw_RouteEfficiency
);

DECLARE @FactShipmentCount bigint =
(
    SELECT ISNULL(SUM(ShipmentCount), 0)
    FROM dw.FactShipment
);

DECLARE @FactDeliveryExceptionCount bigint =
(
    SELECT ISNULL(SUM(ExceptionCount), 0)
    FROM dw.FactDeliveryException
);

DECLARE @CarrierExceptionTrendCount bigint =
(
    SELECT ISNULL(SUM(ExceptionCount), 0)
    FROM rpt.vw_CarrierExceptionTrends
);

IF @DeliveredFactShipmentCount > 0
AND NOT EXISTS (SELECT 1 FROM rpt.vw_DeliveryPerformance)
BEGIN
    THROW 50000, 'rpt.vw_DeliveryPerformance returned no rows despite delivered shipments existing.', 1;
END;

IF @FactShipmentCount > 0
AND NOT EXISTS (SELECT 1 FROM rpt.vw_RouteEfficiency)
BEGIN
    THROW 50000, 'rpt.vw_RouteEfficiency returned no rows despite shipment facts existing.', 1;
END;

IF @FactDeliveryExceptionCount > 0
AND NOT EXISTS (SELECT 1 FROM rpt.vw_CarrierExceptionTrends)
BEGIN
    THROW 50000, 'rpt.vw_CarrierExceptionTrends returned no rows despite exception facts existing.', 1;
END;

IF @DeliveredFactShipmentCount <> @DeliveryPerformanceShipmentCount
BEGIN
    THROW 50000, 'rpt.vw_DeliveryPerformance shipment totals do not reconcile to delivered shipment facts.', 1;
END;

IF @FactShipmentCount <> @RouteEfficiencyShipmentCount
BEGIN
    THROW 50000, 'rpt.vw_RouteEfficiency shipment totals do not reconcile to FactShipment.', 1;
END;

IF @FactDeliveryExceptionCount <> @CarrierExceptionTrendCount
BEGIN
    THROW 50000, 'rpt.vw_CarrierExceptionTrends totals do not reconcile to FactDeliveryException.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM rpt.vw_DeliveryPerformance
    WHERE ShipmentCount <= 0
       OR OnTimeShipmentCount < 0
       OR LateShipmentCount < 0
       OR ExceptionShipmentCount < 0
       OR ExceptionCount < 0
       OR OnTimeShipmentCount + LateShipmentCount > ShipmentCount
       OR ExceptionShipmentCount > ShipmentCount
       OR OnTimeDeliveryPct < 0
       OR OnTimeDeliveryPct > 100
       OR AvgDelayMinutes < 0
       OR AvgTransitDays < 0
       OR AvgTransitHours < 0
)
BEGIN
    THROW 50000, 'rpt.vw_DeliveryPerformance contains invalid KPI values.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM rpt.vw_RouteEfficiency
    WHERE ShipmentCount <= 0
       OR RouteBenchmarkCoveragePct < 0
       OR RouteBenchmarkCoveragePct > 100
       OR OnTimeDeliveryPct < 0
       OR OnTimeDeliveryPct > 100
       OR AvgShipmentPlannedDistanceMiles < 0
       OR AvgActualDistanceMiles < 0
       OR AvgActualTransitHours < 0
       OR CostPerActualMile < 0
)
BEGIN
    THROW 50000, 'rpt.vw_RouteEfficiency contains invalid KPI values.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM rpt.vw_CarrierExceptionTrends
    WHERE ExceptionCount <= 0
       OR DistinctShipmentsAffected <= 0
       OR AvgDelayMinutesImpact < 0
       OR AvgTypicalDelayMinutes < 0
       OR ResolvedWithin24HoursPct < 0
       OR ResolvedWithin24HoursPct > 100
)
BEGIN
    THROW 50000, 'rpt.vw_CarrierExceptionTrends contains invalid KPI values.', 1;
END;

SELECT
    N'rpt.vw_DeliveryPerformance' AS ViewName,
    COUNT(*) AS RowCount,
    ISNULL(SUM(ShipmentCount), 0) AS TotalBusinessCount
FROM rpt.vw_DeliveryPerformance
UNION ALL
SELECT
    N'rpt.vw_RouteEfficiency',
    COUNT(*),
    ISNULL(SUM(ShipmentCount), 0)
FROM rpt.vw_RouteEfficiency
UNION ALL
SELECT
    N'rpt.vw_CarrierExceptionTrends',
    COUNT(*),
    ISNULL(SUM(ExceptionCount), 0)
FROM rpt.vw_CarrierExceptionTrends;

SELECT
    N'Reporting view checks completed successfully.' AS TestStatus;
GO
