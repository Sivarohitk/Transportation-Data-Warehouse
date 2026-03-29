USE [TransportationDW];
GO

IF OBJECT_ID('tempdb..#IntegrityChecks') IS NOT NULL
BEGIN
    DROP TABLE #IntegrityChecks;
END;

CREATE TABLE #IntegrityChecks
(
    CheckArea nvarchar(100) NOT NULL,
    CheckName nvarchar(200) NOT NULL,
    IssueCount bigint NOT NULL
);

INSERT INTO #IntegrityChecks (CheckArea, CheckName, IssueCount)
SELECT N'Null Checks', N'DimCarrier required fields', COUNT(*)
FROM dw.DimCarrier
WHERE CarrierCode IS NULL
   OR CarrierName IS NULL;

INSERT INTO #IntegrityChecks (CheckArea, CheckName, IssueCount)
SELECT N'Null Checks', N'DimLocation required fields', COUNT(*)
FROM dw.DimLocation
WHERE LocationCode IS NULL;

INSERT INTO #IntegrityChecks (CheckArea, CheckName, IssueCount)
SELECT N'Null Checks', N'DimRoute required fields', COUNT(*)
FROM dw.DimRoute
WHERE RouteCode IS NULL;

INSERT INTO #IntegrityChecks (CheckArea, CheckName, IssueCount)
SELECT N'Null Checks', N'DimDeliveryException required fields', COUNT(*)
FROM dw.DimDeliveryException
WHERE ExceptionCode IS NULL;

INSERT INTO #IntegrityChecks (CheckArea, CheckName, IssueCount)
SELECT N'Null Checks', N'DimShipmentStatus required fields', COUNT(*)
FROM dw.DimShipmentStatus
WHERE StatusCode IS NULL
   OR StatusDescription IS NULL;

INSERT INTO #IntegrityChecks (CheckArea, CheckName, IssueCount)
SELECT N'Null Checks', N'FactShipment required fields', COUNT(*)
FROM dw.FactShipment
WHERE ShipmentNumber IS NULL
   OR ShipmentStatus IS NULL;

INSERT INTO #IntegrityChecks (CheckArea, CheckName, IssueCount)
SELECT N'Null Checks', N'FactDeliveryEvent required fields', COUNT(*)
FROM dw.FactDeliveryEvent
WHERE ShipmentNumber IS NULL
   OR EventDateTime IS NULL;

INSERT INTO #IntegrityChecks (CheckArea, CheckName, IssueCount)
SELECT N'Null Checks', N'FactDeliveryException required fields', COUNT(*)
FROM dw.FactDeliveryException
WHERE ShipmentNumber IS NULL
   OR ExceptionDateTime IS NULL;

INSERT INTO #IntegrityChecks (CheckArea, CheckName, IssueCount)
SELECT N'Date Rules', N'FactShipment negative transit or delay metrics', COUNT(*)
FROM dw.FactShipment
WHERE ISNULL(TransitHours, 0) < 0
   OR ISNULL(TransitDays, 0) < 0
   OR ISNULL(DeliveryDelayMinutes, 0) < 0;

INSERT INTO #IntegrityChecks (CheckArea, CheckName, IssueCount)
SELECT N'Date Rules', N'FactShipment planned pickup after planned delivery', COUNT(*)
FROM dw.FactShipment
WHERE PlannedPickupDateKey > 0
  AND PlannedDeliveryDateKey > 0
  AND PlannedPickupDateKey > PlannedDeliveryDateKey;

INSERT INTO #IntegrityChecks (CheckArea, CheckName, IssueCount)
SELECT N'Date Rules', N'FactShipment actual pickup after actual delivery', COUNT(*)
FROM dw.FactShipment
WHERE ActualPickupDateKey > 0
  AND ActualDeliveryDateKey > 0
  AND ActualPickupDateKey > ActualDeliveryDateKey;

INSERT INTO #IntegrityChecks (CheckArea, CheckName, IssueCount)
SELECT N'Date Rules', N'FactDeliveryEvent decreasing timestamps by event sequence', COUNT(*)
FROM
(
    SELECT
        fe.ShipmentNumber,
        fe.EventSequenceNumber,
        fe.EventDateTime,
        LAG(fe.EventDateTime) OVER
        (
            PARTITION BY fe.ShipmentNumber
            ORDER BY fe.EventSequenceNumber
        ) AS PreviousEventDateTime
    FROM dw.FactDeliveryEvent AS fe
) AS d
WHERE d.PreviousEventDateTime IS NOT NULL
  AND d.EventDateTime < d.PreviousEventDateTime;

INSERT INTO #IntegrityChecks (CheckArea, CheckName, IssueCount)
SELECT N'Missing Lookups', N'FactShipment missing dimensional rows', COUNT(*)
FROM dw.FactShipment AS fs
LEFT JOIN dw.DimCarrier AS c
    ON fs.CarrierKey = c.CarrierKey
LEFT JOIN dw.DimRoute AS r
    ON fs.RouteKey = r.RouteKey
LEFT JOIN dw.DimLocation AS ol
    ON fs.OriginLocationKey = ol.LocationKey
LEFT JOIN dw.DimLocation AS dl
    ON fs.DestinationLocationKey = dl.LocationKey
LEFT JOIN dw.DimShipmentStatus AS ss
    ON fs.ShipmentStatusKey = ss.ShipmentStatusKey
LEFT JOIN dw.DimDate AS od
    ON fs.OrderDateKey = od.DateKey
LEFT JOIN dw.DimDate AS pp
    ON fs.PlannedPickupDateKey = pp.DateKey
LEFT JOIN dw.DimDate AS pd
    ON fs.PlannedDeliveryDateKey = pd.DateKey
WHERE c.CarrierKey IS NULL
   OR r.RouteKey IS NULL
   OR ol.LocationKey IS NULL
   OR dl.LocationKey IS NULL
   OR ss.ShipmentStatusKey IS NULL
   OR od.DateKey IS NULL
   OR pp.DateKey IS NULL
   OR pd.DateKey IS NULL;

INSERT INTO #IntegrityChecks (CheckArea, CheckName, IssueCount)
SELECT N'Missing Lookups', N'FactDeliveryEvent missing dimensional rows', COUNT(*)
FROM dw.FactDeliveryEvent AS fe
LEFT JOIN dw.DimDate AS dd
    ON fe.EventDateKey = dd.DateKey
LEFT JOIN dw.DimShipmentStatus AS ss
    ON fe.ShipmentStatusKey = ss.ShipmentStatusKey
LEFT JOIN dw.DimCarrier AS c
    ON fe.CarrierKey = c.CarrierKey
LEFT JOIN dw.DimRoute AS r
    ON fe.RouteKey = r.RouteKey
LEFT JOIN dw.DimLocation AS ol
    ON fe.OriginLocationKey = ol.LocationKey
LEFT JOIN dw.DimLocation AS dl
    ON fe.DestinationLocationKey = dl.LocationKey
LEFT JOIN dw.DimLocation AS el
    ON fe.EventLocationKey = el.LocationKey
LEFT JOIN dw.DimDeliveryException AS de
    ON fe.DeliveryExceptionKey = de.DeliveryExceptionKey
WHERE dd.DateKey IS NULL
   OR ss.ShipmentStatusKey IS NULL
   OR c.CarrierKey IS NULL
   OR r.RouteKey IS NULL
   OR ol.LocationKey IS NULL
   OR dl.LocationKey IS NULL
   OR el.LocationKey IS NULL
   OR de.DeliveryExceptionKey IS NULL;

INSERT INTO #IntegrityChecks (CheckArea, CheckName, IssueCount)
SELECT N'Missing Lookups', N'FactDeliveryException missing dimensional rows', COUNT(*)
FROM dw.FactDeliveryException AS fe
LEFT JOIN dw.DimDate AS dd
    ON fe.ExceptionDateKey = dd.DateKey
LEFT JOIN dw.DimShipmentStatus AS ss
    ON fe.ShipmentStatusKey = ss.ShipmentStatusKey
LEFT JOIN dw.DimCarrier AS c
    ON fe.CarrierKey = c.CarrierKey
LEFT JOIN dw.DimRoute AS r
    ON fe.RouteKey = r.RouteKey
LEFT JOIN dw.DimLocation AS ol
    ON fe.OriginLocationKey = ol.LocationKey
LEFT JOIN dw.DimLocation AS dl
    ON fe.DestinationLocationKey = dl.LocationKey
LEFT JOIN dw.DimDeliveryException AS de
    ON fe.DeliveryExceptionKey = de.DeliveryExceptionKey
WHERE dd.DateKey IS NULL
   OR ss.ShipmentStatusKey IS NULL
   OR c.CarrierKey IS NULL
   OR r.RouteKey IS NULL
   OR ol.LocationKey IS NULL
   OR dl.LocationKey IS NULL
   OR de.DeliveryExceptionKey IS NULL;

INSERT INTO #IntegrityChecks (CheckArea, CheckName, IssueCount)
SELECT N'Orphan Facts', N'FactDeliveryEvent without FactShipment parent', COUNT(*)
FROM dw.FactDeliveryEvent AS fe
LEFT JOIN dw.FactShipment AS fs
    ON fe.ShipmentNumber = fs.ShipmentNumber
WHERE fs.ShipmentNumber IS NULL;

INSERT INTO #IntegrityChecks (CheckArea, CheckName, IssueCount)
SELECT N'Orphan Facts', N'FactDeliveryException without FactShipment parent', COUNT(*)
FROM dw.FactDeliveryException AS fe
LEFT JOIN dw.FactShipment AS fs
    ON fe.ShipmentNumber = fs.ShipmentNumber
WHERE fs.ShipmentNumber IS NULL;

INSERT INTO #IntegrityChecks (CheckArea, CheckName, IssueCount)
SELECT N'Unknown Members', N'FactShipment unknown-key usage', COUNT(*)
FROM dw.FactShipment
WHERE CarrierKey = 0
   OR RouteKey = 0
   OR OriginLocationKey = 0
   OR DestinationLocationKey = 0
   OR ShipmentStatusKey = 0;

INSERT INTO #IntegrityChecks (CheckArea, CheckName, IssueCount)
SELECT N'Unknown Members', N'FactDeliveryEvent unknown-key usage', COUNT(*)
FROM dw.FactDeliveryEvent
WHERE ShipmentStatusKey = 0
   OR CarrierKey = 0
   OR RouteKey = 0
   OR OriginLocationKey = 0
   OR DestinationLocationKey = 0
   OR EventLocationKey = 0
   OR DeliveryExceptionKey = 0;

INSERT INTO #IntegrityChecks (CheckArea, CheckName, IssueCount)
SELECT N'Unknown Members', N'FactDeliveryException unknown-key usage', COUNT(*)
FROM dw.FactDeliveryException
WHERE ShipmentStatusKey = 0
   OR CarrierKey = 0
   OR RouteKey = 0
   OR OriginLocationKey = 0
   OR DestinationLocationKey = 0
   OR DeliveryExceptionKey = 0;

SELECT
    CheckArea,
    CheckName,
    IssueCount
FROM #IntegrityChecks
ORDER BY CheckArea, CheckName;

IF EXISTS
(
    SELECT 1
    FROM #IntegrityChecks
    WHERE CheckArea <> N'Unknown Members'
      AND IssueCount > 0
)
BEGIN
    THROW 50000, 'Referential integrity checks found one or more failures.', 1;
END;

SELECT
    N'Referential integrity checks completed successfully.' AS TestStatus;
GO
