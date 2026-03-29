USE [TransportationDW];
GO

IF NOT EXISTS (SELECT 1 FROM meta.Batch_Run WHERE Status = 'SUCCEEDED')
BEGIN
    THROW 50000, 'No succeeded batch exists. Run an initial warehouse load before executing smoke tests.', 1;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimDate WHERE DateKey = 0)
BEGIN
    THROW 50000, 'DimDate unknown member is missing.', 1;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimCarrier WHERE CarrierKey = 0)
BEGIN
    THROW 50000, 'DimCarrier unknown member is missing.', 1;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimLocation WHERE LocationKey = 0)
BEGIN
    THROW 50000, 'DimLocation unknown member is missing.', 1;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimRoute WHERE RouteKey = 0)
BEGIN
    THROW 50000, 'DimRoute unknown member is missing.', 1;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimDeliveryException WHERE DeliveryExceptionKey = 0)
BEGIN
    THROW 50000, 'DimDeliveryException unknown member is missing.', 1;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimShipmentStatus WHERE ShipmentStatusKey = 0)
BEGIN
    THROW 50000, 'DimShipmentStatus unknown member is missing.', 1;
END;
GO

IF EXISTS
(
    SELECT ShipmentNumber
    FROM dw.FactShipment
    GROUP BY ShipmentNumber
    HAVING COUNT(*) > 1
)
BEGIN
    THROW 50000, 'FactShipment contains duplicate shipment numbers.', 1;
END;
GO

IF EXISTS
(
    SELECT ShipmentNumber, EventSequenceNumber
    FROM dw.FactDeliveryEvent
    GROUP BY ShipmentNumber, EventSequenceNumber
    HAVING COUNT(*) > 1
)
BEGIN
    THROW 50000, 'FactDeliveryEvent contains duplicate shipment events.', 1;
END;
GO

IF EXISTS
(
    SELECT ShipmentNumber, DeliveryExceptionKey, ExceptionDateTime
    FROM dw.FactDeliveryException
    GROUP BY ShipmentNumber, DeliveryExceptionKey, ExceptionDateTime
    HAVING COUNT(*) > 1
)
BEGIN
    THROW 50000, 'FactDeliveryException contains duplicate shipment exceptions.', 1;
END;
GO

IF EXISTS
(
    SELECT 1
    FROM dw.FactShipment AS fs
    WHERE fs.ShipmentNumber IS NULL
       OR fs.ShipmentStatus IS NULL
)
BEGIN
    THROW 50000, 'FactShipment contains null required fields.', 1;
END;
GO

IF EXISTS
(
    SELECT 1
    FROM dw.FactDeliveryEvent AS fe
    WHERE fe.ShipmentNumber IS NULL
       OR fe.EventDateTime IS NULL
)
BEGIN
    THROW 50000, 'FactDeliveryEvent contains null required fields.', 1;
END;
GO

IF EXISTS
(
    SELECT 1
    FROM dw.FactDeliveryException AS fe
    WHERE fe.ShipmentNumber IS NULL
       OR fe.ExceptionDateTime IS NULL
)
BEGIN
    THROW 50000, 'FactDeliveryException contains null required fields.', 1;
END;
GO

IF EXISTS
(
    SELECT 1
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
    WHERE c.CarrierKey IS NULL
       OR r.RouteKey IS NULL
       OR ol.LocationKey IS NULL
       OR dl.LocationKey IS NULL
       OR ss.ShipmentStatusKey IS NULL
)
BEGIN
    THROW 50000, 'FactShipment contains invalid dimensional references.', 1;
END;
GO

IF EXISTS
(
    SELECT 1
    FROM dw.FactDeliveryEvent AS fe
    LEFT JOIN dw.FactShipment AS fs
        ON fe.ShipmentNumber = fs.ShipmentNumber
    LEFT JOIN dw.DimShipmentStatus AS ss
        ON fe.ShipmentStatusKey = ss.ShipmentStatusKey
    LEFT JOIN dw.DimCarrier AS c
        ON fe.CarrierKey = c.CarrierKey
    LEFT JOIN dw.DimRoute AS r
        ON fe.RouteKey = r.RouteKey
    LEFT JOIN dw.DimLocation AS el
        ON fe.EventLocationKey = el.LocationKey
    LEFT JOIN dw.DimDeliveryException AS de
        ON fe.DeliveryExceptionKey = de.DeliveryExceptionKey
    WHERE fs.ShipmentNumber IS NULL
       OR ss.ShipmentStatusKey IS NULL
       OR c.CarrierKey IS NULL
       OR r.RouteKey IS NULL
       OR el.LocationKey IS NULL
       OR de.DeliveryExceptionKey IS NULL
)
BEGIN
    THROW 50000, 'FactDeliveryEvent contains invalid shipment or dimension references.', 1;
END;
GO

IF EXISTS
(
    SELECT 1
    FROM dw.FactDeliveryException AS fe
    LEFT JOIN dw.FactShipment AS fs
        ON fe.ShipmentNumber = fs.ShipmentNumber
    LEFT JOIN dw.DimShipmentStatus AS ss
        ON fe.ShipmentStatusKey = ss.ShipmentStatusKey
    LEFT JOIN dw.DimCarrier AS c
        ON fe.CarrierKey = c.CarrierKey
    LEFT JOIN dw.DimRoute AS r
        ON fe.RouteKey = r.RouteKey
    LEFT JOIN dw.DimDeliveryException AS de
        ON fe.DeliveryExceptionKey = de.DeliveryExceptionKey
    WHERE fs.ShipmentNumber IS NULL
       OR ss.ShipmentStatusKey IS NULL
       OR c.CarrierKey IS NULL
       OR r.RouteKey IS NULL
       OR de.DeliveryExceptionKey IS NULL
)
BEGIN
    THROW 50000, 'FactDeliveryException contains invalid shipment or dimension references.', 1;
END;
GO

IF EXISTS
(
    SELECT 1
    FROM dw.FactShipment
    WHERE (LateDeliveryFlag = 1 AND ISNULL(DeliveryDelayMinutes, 0) <= 0)
       OR (OnTimeDeliveryFlag = 1 AND ISNULL(DeliveryDelayMinutes, 0) <> 0)
       OR (OnTimeDeliveryFlag = 1 AND LateDeliveryFlag = 1)
       OR ISNULL(TransitHours, 0) < 0
       OR ISNULL(TransitDays, 0) < 0
       OR ISNULL(DeliveryDelayMinutes, 0) < 0
       OR (PlannedPickupDateKey > 0 AND PlannedDeliveryDateKey > 0 AND PlannedPickupDateKey > PlannedDeliveryDateKey)
       OR (ActualPickupDateKey > 0 AND ActualDeliveryDateKey > 0 AND ActualPickupDateKey > ActualDeliveryDateKey)
)
BEGIN
    THROW 50000, 'FactShipment contains invalid date sequencing or KPI derivations.', 1;
END;
GO

IF EXISTS
(
    SELECT 1
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
      AND d.EventDateTime < d.PreviousEventDateTime
)
BEGIN
    THROW 50000, 'FactDeliveryEvent contains an event sequence with decreasing timestamps.', 1;
END;
GO

IF EXISTS
(
    SELECT 1
    FROM dw.FactShipment AS fs
    LEFT JOIN dw.DimShipmentStatus AS ss
        ON fs.ShipmentStatusKey = ss.ShipmentStatusKey
    WHERE (fs.ExceptionShipmentFlag = 0 AND (fs.ExceptionCount > 0 OR ISNULL(ss.IsExceptionStatus, 0) = 1))
       OR (fs.ExceptionShipmentFlag = 1 AND fs.ExceptionCount = 0 AND ISNULL(ss.IsExceptionStatus, 0) = 0)
)
BEGIN
    THROW 50000, 'FactShipment contains invalid exception shipment flags.', 1;
END;
GO

IF EXISTS
(
    SELECT 1
    FROM meta.Watermark AS w
    LEFT JOIN meta.Batch_Run AS b
        ON w.LastSuccessfulBatchID = b.BatchID
    WHERE w.LastSuccessfulBatchID IS NOT NULL
      AND (b.BatchID IS NULL OR b.Status <> 'SUCCEEDED')
)
BEGIN
    THROW 50000, 'Watermark table references a batch that did not succeed.', 1;
END;
GO

IF EXISTS
(
    SELECT 1
    FROM meta.Watermark AS w
    INNER JOIN meta.Batch_Run AS b
        ON w.PendingBatchID = b.BatchID
    WHERE b.Status = 'SUCCEEDED'
)
BEGIN
    THROW 50000, 'Pending watermarks were not cleared for a succeeded batch.', 1;
END;
GO

IF EXISTS
(
    SELECT BatchID, SourceObjectName, FileName
    FROM meta.Source_File_Log
    WHERE SourceType = 'FLAT_FILE'
      AND FileName IS NOT NULL
    GROUP BY BatchID, SourceObjectName, FileName
    HAVING COUNT(*) > 1
)
BEGIN
    THROW 50000, 'Flat-file registration contains duplicate file entries for the same batch.', 1;
END;
GO

DECLARE @LatestBatchID int =
(
    SELECT MAX(BatchID)
    FROM meta.Batch_Run
    WHERE Status = 'SUCCEEDED'
);

IF @LatestBatchID IS NOT NULL
AND EXISTS
(
    SELECT 1
    FROM
    (
        SELECT DISTINCT ShipmentNumber
        FROM stg.Shipment_Status_History_Raw
        WHERE BatchID = @LatestBatchID
          AND IsValid = 1

        UNION

        SELECT DISTINCT ShipmentNumber
        FROM stg.Delivery_Exception_Raw
        WHERE BatchID = @LatestBatchID
          AND IsValid = 1
    ) AS i
    LEFT JOIN dw.FactShipment AS fs
        ON i.ShipmentNumber = fs.ShipmentNumber
    WHERE fs.ShipmentNumber IS NULL
)
BEGIN
    THROW 50000, 'Latest batch contains event or exception shipments that did not resolve to FactShipment.', 1;
END;

IF @LatestBatchID IS NOT NULL
AND EXISTS
(
    SELECT 1
    FROM
    (
        SELECT
            h.ShipmentNumber,
            COUNT(*) AS BatchEventCount,
            MAX(CASE WHEN UPPER(LTRIM(RTRIM(h.StatusCode))) = N'DELIVERED' THEN 1 ELSE 0 END) AS HasDeliveredEvent
        FROM stg.Shipment_Status_History_Raw AS h
        WHERE h.BatchID = @LatestBatchID
          AND h.IsValid = 1
          AND NOT EXISTS
          (
              SELECT 1
              FROM stg.Shipment_Raw AS s
              WHERE s.BatchID = @LatestBatchID
                AND s.IsValid = 1
                AND s.ShipmentNumber = h.ShipmentNumber
          )
        GROUP BY h.ShipmentNumber
    ) AS e
    LEFT JOIN dw.FactShipment AS fs
        ON e.ShipmentNumber = fs.ShipmentNumber
    WHERE fs.ShipmentNumber IS NULL
       OR ISNULL(fs.ScanEventCount, 0) < e.BatchEventCount
       OR (e.HasDeliveredEvent = 1 AND ISNULL(fs.ActualDeliveryDateKey, 0) = 0)
)
BEGIN
    THROW 50000, 'Event-only batch restatement checks failed for the latest batch.', 1;
END;

IF @LatestBatchID IS NOT NULL
AND EXISTS
(
    SELECT 1
    FROM
    (
        SELECT
            e.ShipmentNumber,
            COUNT(*) AS BatchExceptionCount
        FROM stg.Delivery_Exception_Raw AS e
        WHERE e.BatchID = @LatestBatchID
          AND e.IsValid = 1
          AND NOT EXISTS
          (
              SELECT 1
              FROM stg.Shipment_Raw AS s
              WHERE s.BatchID = @LatestBatchID
                AND s.IsValid = 1
                AND s.ShipmentNumber = e.ShipmentNumber
          )
        GROUP BY e.ShipmentNumber
    ) AS x
    LEFT JOIN dw.FactShipment AS fs
        ON x.ShipmentNumber = fs.ShipmentNumber
    WHERE fs.ShipmentNumber IS NULL
       OR fs.ExceptionShipmentFlag = 0
       OR ISNULL(fs.ExceptionCount, 0) < x.BatchExceptionCount
)
BEGIN
    THROW 50000, 'Exception-only batch restatement checks failed for the latest batch.', 1;
END;

SELECT
    N'Smoke tests completed successfully.' AS TestStatus,
    @LatestBatchID AS LatestSuccessfulBatchID;
GO
