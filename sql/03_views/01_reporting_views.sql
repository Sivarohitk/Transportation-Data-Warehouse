USE [$(DatabaseName)];
GO

CREATE OR ALTER VIEW rpt.vw_DeliveryPerformance
AS
SELECT
    dd.CalendarYear,
    dd.CalendarMonth,
    dd.MonthName,
    c.CarrierName,
    fs.ServiceLevel,
    SUM(fs.ShipmentCount) AS ShipmentCount,
    SUM(CASE WHEN fs.OnTimeDeliveryFlag = 1 THEN fs.ShipmentCount ELSE 0 END) AS OnTimeShipmentCount,
    SUM(CASE WHEN fs.LateDeliveryFlag = 1 THEN fs.ShipmentCount ELSE 0 END) AS LateShipmentCount,
    SUM(CASE WHEN fs.ExceptionShipmentFlag = 1 THEN fs.ShipmentCount ELSE 0 END) AS ExceptionShipmentCount,
    SUM(fs.ExceptionCount) AS ExceptionCount,
    CAST(100.0 * SUM(CASE WHEN fs.OnTimeDeliveryFlag = 1 THEN fs.ShipmentCount ELSE 0 END) / NULLIF(SUM(fs.ShipmentCount), 0) AS decimal(5, 2)) AS OnTimeDeliveryPct,
    CAST(AVG(CAST(fs.DeliveryDelayMinutes AS decimal(12, 2))) AS decimal(12, 2)) AS AvgDelayMinutes,
    CAST(AVG(fs.TransitDays) AS decimal(12, 2)) AS AvgTransitDays,
    CAST(AVG(fs.TransitHours) AS decimal(12, 2)) AS AvgTransitHours,
    CAST(AVG(CAST(fs.ScanEventCount AS decimal(12, 2))) AS decimal(12, 2)) AS AvgScanEventsPerShipment,
    CAST(AVG(fs.ShipmentRevenue) AS decimal(12, 2)) AS AvgRevenuePerShipment,
    CAST(AVG(fs.ShipmentCost) AS decimal(12, 2)) AS AvgCostPerShipment
FROM dw.FactShipment AS fs
INNER JOIN dw.DimDate AS dd
    ON fs.ActualDeliveryDateKey = dd.DateKey
INNER JOIN dw.DimCarrier AS c
    ON fs.CarrierKey = c.CarrierKey
GROUP BY
    dd.CalendarYear,
    dd.CalendarMonth,
    dd.MonthName,
    c.CarrierName,
    fs.ServiceLevel;
GO

CREATE OR ALTER VIEW rpt.vw_RouteEfficiency
AS
SELECT
    r.RouteCode,
    r.RouteType,
    r.FuelZone,
    ol.City AS OriginCity,
    dl.City AS DestinationCity,
    c.CarrierName,
    SUM(fs.ShipmentCount) AS ShipmentCount,
    MAX(r.ReferenceDistanceMiles) AS RouteReferenceDistanceMiles,
    CAST(AVG(fs.PlannedDistanceMiles) AS decimal(12, 2)) AS AvgShipmentPlannedDistanceMiles,
    CAST(AVG(fs.ActualDistanceMiles) AS decimal(12, 2)) AS AvgActualDistanceMiles,
    CAST(AVG(ISNULL(fs.ActualDistanceMiles, 0) - ISNULL(r.ReferenceDistanceMiles, 0)) AS decimal(12, 2)) AS AvgDistanceVarianceToReferenceMiles,
    MAX(r.ReferenceTransitHours) AS RouteReferenceTransitHours,
    CAST(AVG(fs.TransitHours) AS decimal(12, 2)) AS AvgActualTransitHours,
    CAST(AVG(ISNULL(fs.TransitHours, 0) - ISNULL(r.ReferenceTransitHours, 0)) AS decimal(12, 2)) AS AvgTransitVarianceHours,
    CAST(100.0 * SUM(CASE WHEN r.ReferenceDistanceMiles IS NOT NULL AND r.ReferenceTransitHours IS NOT NULL THEN fs.ShipmentCount ELSE 0 END) / NULLIF(SUM(fs.ShipmentCount), 0) AS decimal(5, 2)) AS RouteBenchmarkCoveragePct,
    CAST(SUM(fs.ShipmentCost) / NULLIF(SUM(fs.ActualDistanceMiles), 0) AS decimal(12, 4)) AS CostPerActualMile,
    CAST(100.0 * SUM(CASE WHEN fs.OnTimeDeliveryFlag = 1 THEN fs.ShipmentCount ELSE 0 END) / NULLIF(SUM(fs.ShipmentCount), 0) AS decimal(5, 2)) AS OnTimeDeliveryPct
FROM dw.FactShipment AS fs
INNER JOIN dw.DimRoute AS r
    ON fs.RouteKey = r.RouteKey
INNER JOIN dw.DimCarrier AS c
    ON fs.CarrierKey = c.CarrierKey
INNER JOIN dw.DimLocation AS ol
    ON fs.OriginLocationKey = ol.LocationKey
INNER JOIN dw.DimLocation AS dl
    ON fs.DestinationLocationKey = dl.LocationKey
GROUP BY
    r.RouteCode,
    r.RouteType,
    r.FuelZone,
    ol.City,
    dl.City,
    c.CarrierName;
GO

CREATE OR ALTER VIEW rpt.vw_CarrierExceptionTrends
AS
SELECT
    dd.CalendarYear,
    dd.CalendarMonth,
    dd.MonthName,
    c.CarrierName,
    de.ExceptionCategory,
    de.ExceptionCode,
    de.ResponsibleParty,
    SUM(fe.ExceptionCount) AS ExceptionCount,
    COUNT(DISTINCT fe.ShipmentNumber) AS DistinctShipmentsAffected,
    CAST(AVG(CAST(fe.DelayMinutesImpact AS decimal(12, 2))) AS decimal(12, 2)) AS AvgDelayMinutesImpact,
    CAST(AVG(CAST(fe.TypicalDelayMinutes AS decimal(12, 2))) AS decimal(12, 2)) AS AvgTypicalDelayMinutes,
    CAST(AVG(CAST(fe.DelayVarianceMinutes AS decimal(12, 2))) AS decimal(12, 2)) AS AvgDelayVarianceMinutes,
    CAST(100.0 * SUM(CASE WHEN fe.ResolvedWithin24HoursFlag = 1 THEN fe.ExceptionCount ELSE 0 END) / NULLIF(SUM(fe.ExceptionCount), 0) AS decimal(5, 2)) AS ResolvedWithin24HoursPct
FROM dw.FactDeliveryException AS fe
INNER JOIN dw.DimDate AS dd
    ON fe.ExceptionDateKey = dd.DateKey
INNER JOIN dw.DimCarrier AS c
    ON fe.CarrierKey = c.CarrierKey
INNER JOIN dw.DimDeliveryException AS de
    ON fe.DeliveryExceptionKey = de.DeliveryExceptionKey
GROUP BY
    dd.CalendarYear,
    dd.CalendarMonth,
    dd.MonthName,
    c.CarrierName,
    de.ExceptionCategory,
    de.ExceptionCode,
    de.ResponsibleParty;
GO
