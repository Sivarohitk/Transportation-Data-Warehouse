USE [TransportationDW];
GO

DECLARE @LatestBatchID int =
(
    SELECT MAX(BatchID)
    FROM meta.Batch_Run
    WHERE Status = 'SUCCEEDED'
);

IF @LatestBatchID IS NULL
BEGIN
    THROW 50000, 'No succeeded batch exists. Run a warehouse load before executing row count checks.', 1;
END;

;WITH Reconciliation AS
(
    SELECT *
    FROM
    (
        VALUES
        (
            N'DimCarrier from valid stage carriers',
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT UPPER(LTRIM(RTRIM(CarrierCode))) AS CarrierCode
                 FROM stg.Carrier_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND NULLIF(LTRIM(RTRIM(CarrierCode)), N'') IS NOT NULL
             ) AS s),
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT UPPER(LTRIM(RTRIM(CarrierCode))) AS CarrierCode
                 FROM stg.Carrier_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND NULLIF(LTRIM(RTRIM(CarrierCode)), N'') IS NOT NULL
             ) AS s
             INNER JOIN dw.DimCarrier AS d
                ON s.CarrierCode = d.CarrierCode)
        ),
        (
            N'DimLocation from valid stage locations',
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT UPPER(LTRIM(RTRIM(LocationCode))) AS LocationCode
                 FROM stg.Location_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND NULLIF(LTRIM(RTRIM(LocationCode)), N'') IS NOT NULL
             ) AS s),
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT UPPER(LTRIM(RTRIM(LocationCode))) AS LocationCode
                 FROM stg.Location_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND NULLIF(LTRIM(RTRIM(LocationCode)), N'') IS NOT NULL
             ) AS s
             INNER JOIN dw.DimLocation AS d
                ON s.LocationCode = d.LocationCode)
        ),
        (
            N'DimRoute from valid stage routes',
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT UPPER(REPLACE(LTRIM(RTRIM(RouteCode)), N' ', N'')) AS RouteCode
                 FROM stg.Route_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND NULLIF(LTRIM(RTRIM(RouteCode)), N'') IS NOT NULL
             ) AS s),
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT UPPER(REPLACE(LTRIM(RTRIM(RouteCode)), N' ', N'')) AS RouteCode
                 FROM stg.Route_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND NULLIF(LTRIM(RTRIM(RouteCode)), N'') IS NOT NULL
             ) AS s
             INNER JOIN dw.DimRoute AS d
                ON s.RouteCode = d.RouteCode)
        ),
        (
            N'DimDeliveryException from valid exception lookup rows',
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT UPPER(LTRIM(RTRIM(ExceptionCode))) AS ExceptionCode
                 FROM stg.Exception_Code_Lookup_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND NULLIF(LTRIM(RTRIM(ExceptionCode)), N'') IS NOT NULL
             ) AS s),
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT UPPER(LTRIM(RTRIM(ExceptionCode))) AS ExceptionCode
                 FROM stg.Exception_Code_Lookup_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND NULLIF(LTRIM(RTRIM(ExceptionCode)), N'') IS NOT NULL
             ) AS s
             INNER JOIN dw.DimDeliveryException AS d
                ON s.ExceptionCode = d.ExceptionCode)
        ),
        (
            N'DimShipmentStatus from valid stage event statuses',
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT UPPER(LTRIM(RTRIM(StatusCode))) AS StatusCode
                 FROM stg.Shipment_Status_History_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND NULLIF(LTRIM(RTRIM(StatusCode)), N'') IS NOT NULL
             ) AS s),
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT UPPER(LTRIM(RTRIM(StatusCode))) AS StatusCode
                 FROM stg.Shipment_Status_History_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND NULLIF(LTRIM(RTRIM(StatusCode)), N'') IS NOT NULL
             ) AS s
             INNER JOIN dw.DimShipmentStatus AS d
                ON s.StatusCode = d.StatusCode)
        ),
        (
            N'FactShipment from valid stage shipments',
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT UPPER(LTRIM(RTRIM(ShipmentNumber))) AS ShipmentNumber
                 FROM stg.Shipment_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND NULLIF(LTRIM(RTRIM(ShipmentNumber)), N'') IS NOT NULL
             ) AS s),
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT UPPER(LTRIM(RTRIM(ShipmentNumber))) AS ShipmentNumber
                 FROM stg.Shipment_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND NULLIF(LTRIM(RTRIM(ShipmentNumber)), N'') IS NOT NULL
             ) AS s
             INNER JOIN dw.FactShipment AS f
                ON s.ShipmentNumber = f.ShipmentNumber)
        ),
        (
            N'FactDeliveryEvent from valid stage events',
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT
                     UPPER(LTRIM(RTRIM(ShipmentNumber))) AS ShipmentNumber,
                     EventSequenceNumber
                 FROM stg.Shipment_Status_History_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND NULLIF(LTRIM(RTRIM(ShipmentNumber)), N'') IS NOT NULL
                   AND EventSequenceNumber IS NOT NULL
             ) AS s),
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT
                     UPPER(LTRIM(RTRIM(ShipmentNumber))) AS ShipmentNumber,
                     EventSequenceNumber
                 FROM stg.Shipment_Status_History_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND NULLIF(LTRIM(RTRIM(ShipmentNumber)), N'') IS NOT NULL
                   AND EventSequenceNumber IS NOT NULL
             ) AS s
             INNER JOIN dw.FactDeliveryEvent AS f
                ON s.ShipmentNumber = f.ShipmentNumber
               AND s.EventSequenceNumber = f.EventSequenceNumber)
        ),
        (
            N'FactDeliveryException from valid stage exceptions',
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT
                     UPPER(LTRIM(RTRIM(ShipmentNumber))) AS ShipmentNumber,
                     UPPER(LTRIM(RTRIM(ExceptionCode))) AS ExceptionCode,
                     ExceptionDateTime
                 FROM stg.Delivery_Exception_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND NULLIF(LTRIM(RTRIM(ShipmentNumber)), N'') IS NOT NULL
                   AND NULLIF(LTRIM(RTRIM(ExceptionCode)), N'') IS NOT NULL
                   AND ExceptionDateTime IS NOT NULL
             ) AS s),
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT
                     UPPER(LTRIM(RTRIM(ShipmentNumber))) AS ShipmentNumber,
                     UPPER(LTRIM(RTRIM(ExceptionCode))) AS ExceptionCode,
                     ExceptionDateTime
                 FROM stg.Delivery_Exception_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND NULLIF(LTRIM(RTRIM(ShipmentNumber)), N'') IS NOT NULL
                   AND NULLIF(LTRIM(RTRIM(ExceptionCode)), N'') IS NOT NULL
                   AND ExceptionDateTime IS NOT NULL
             ) AS s
             INNER JOIN dw.DimDeliveryException AS d
                ON s.ExceptionCode = d.ExceptionCode
             INNER JOIN dw.FactDeliveryException AS f
                ON s.ShipmentNumber = f.ShipmentNumber
               AND d.DeliveryExceptionKey = f.DeliveryExceptionKey
               AND s.ExceptionDateTime = f.ExceptionDateTime)
        )
    ) AS r(CheckName, StageDistinctCount, WarehouseMatchedCount)
)
SELECT
    @LatestBatchID AS BatchID,
    CheckName,
    StageDistinctCount,
    WarehouseMatchedCount,
    StageDistinctCount - WarehouseMatchedCount AS MissingWarehouseRows
FROM Reconciliation
ORDER BY CheckName;

IF EXISTS
(
    SELECT 1
    FROM Reconciliation
    WHERE StageDistinctCount <> WarehouseMatchedCount
)
BEGIN
    THROW 50000, 'Row count reconciliation failed for one or more stage-to-warehouse checks.', 1;
END;

SELECT
    N'Row count reconciliation completed successfully.' AS TestStatus,
    @LatestBatchID AS LatestSuccessfulBatchID;
GO
