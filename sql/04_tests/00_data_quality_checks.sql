USE [$(DatabaseName)];
GO

DECLARE @LatestBatchID int =
(
    SELECT MAX(BatchID)
    FROM meta.Batch_Run
    WHERE Status = 'SUCCEEDED'
);

SELECT
    N'Context' AS ReportSection,
    DB_NAME() AS DatabaseName,
    @LatestBatchID AS LatestSuccessfulBatchID,
    (SELECT COUNT(*) FROM meta.Batch_Run WHERE Status = 'SUCCEEDED') AS SuccessfulBatchCount,
    (SELECT COUNT(*) FROM dw.FactShipment) AS FactShipmentRows,
    (SELECT COUNT(*) FROM dw.FactDeliveryEvent) AS FactDeliveryEventRows,
    (SELECT COUNT(*) FROM dw.FactDeliveryException) AS FactDeliveryExceptionRows;
GO

SELECT TOP (25)
    N'Latest Validation Errors' AS ReportSection,
    *
FROM audit.Validation_Error
ORDER BY LoggedAt DESC;
GO

SELECT TOP (25)
    N'Latest Stage Rejects' AS ReportSection,
    BatchID,
    SourceTableName,
    BusinessKey,
    SourceName,
    SourceFileName,
    RejectionReason,
    RejectedAt
FROM audit.Stage_Row_Reject
ORDER BY RejectedAt DESC;
GO

SELECT
    N'Batch Summary' AS ReportSection,
    BatchID,
    BatchName,
    SourceName,
    Status,
    RowsRead,
    RowsInserted,
    RowsUpdated,
    RowsLoaded,
    RowsRejected,
    StartTime,
    EndTime
FROM meta.Batch_Run
ORDER BY BatchID DESC;
GO

SELECT
    N'Load Audit Summary' AS ReportSection,
    BatchID,
    StepName,
    TargetObjectName,
    RowsInserted,
    RowsUpdated,
    RowsRejected,
    Status,
    StartedAt,
    CompletedAt
FROM audit.Load_Audit
ORDER BY LoadAuditID DESC;
GO

SELECT
    N'Watermark Summary' AS ReportSection,
    ProcessName,
    LastSuccessfulBatchID,
    LastWatermarkValue,
    LastWatermarkSequence,
    LastWatermarkText,
    PendingBatchID,
    PendingWatermarkValue,
    PendingWatermarkSequence,
    PendingWatermarkText,
    UpdatedAt
FROM meta.Watermark
ORDER BY ProcessName;
GO

SELECT TOP (50)
    N'Source File Log' AS ReportSection,
    BatchID,
    SourceObjectName,
    SourceType,
    FileName,
    RowsReceived,
    RowsLoaded,
    RowsRejected,
    FileModifiedAt,
    LoadStatus,
    LoadedAt,
    Message
FROM meta.Source_File_Log
ORDER BY SourceFileLogID DESC;
GO

DECLARE @LatestBatchID int =
(
    SELECT MAX(BatchID)
    FROM meta.Batch_Run
    WHERE Status = 'SUCCEEDED'
);

;WITH RowCountReconciliation AS
(
    SELECT *
    FROM
    (
        VALUES
        (
            N'Valid stage shipments matched to FactShipment',
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT ShipmentNumber
                 FROM stg.Shipment_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND ShipmentNumber IS NOT NULL
             ) AS s),
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT ShipmentNumber
                 FROM stg.Shipment_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND ShipmentNumber IS NOT NULL
             ) AS s
             INNER JOIN dw.FactShipment AS fs
                ON s.ShipmentNumber = fs.ShipmentNumber)
        ),
        (
            N'Valid stage events matched to FactDeliveryEvent',
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT ShipmentNumber, EventSequenceNumber
                 FROM stg.Shipment_Status_History_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND ShipmentNumber IS NOT NULL
                   AND EventSequenceNumber IS NOT NULL
             ) AS s),
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT ShipmentNumber, EventSequenceNumber
                 FROM stg.Shipment_Status_History_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND ShipmentNumber IS NOT NULL
                   AND EventSequenceNumber IS NOT NULL
             ) AS s
             INNER JOIN dw.FactDeliveryEvent AS fe
                ON s.ShipmentNumber = fe.ShipmentNumber
               AND s.EventSequenceNumber = fe.EventSequenceNumber)
        ),
        (
            N'Valid stage exceptions matched to FactDeliveryException',
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT ShipmentNumber, ExceptionCode, ExceptionDateTime
                 FROM stg.Delivery_Exception_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND ShipmentNumber IS NOT NULL
                   AND ExceptionCode IS NOT NULL
                   AND ExceptionDateTime IS NOT NULL
             ) AS s),
            (SELECT COUNT(*)
             FROM
             (
                 SELECT DISTINCT ShipmentNumber, ExceptionCode, ExceptionDateTime
                 FROM stg.Delivery_Exception_Raw
                 WHERE BatchID = @LatestBatchID
                   AND IsValid = 1
                   AND ShipmentNumber IS NOT NULL
                   AND ExceptionCode IS NOT NULL
                   AND ExceptionDateTime IS NOT NULL
             ) AS s
             INNER JOIN dw.DimDeliveryException AS de
                ON s.ExceptionCode = de.ExceptionCode
             INNER JOIN dw.FactDeliveryException AS fe
                ON s.ShipmentNumber = fe.ShipmentNumber
               AND s.ExceptionDateTime = fe.ExceptionDateTime
               AND de.DeliveryExceptionKey = fe.DeliveryExceptionKey)
        )
    ) AS r(CheckName, StageDistinctCount, WarehouseMatchedCount)
)
SELECT
    N'Row Count Reconciliation' AS ReportSection,
    @LatestBatchID AS BatchID,
    CheckName,
    StageDistinctCount,
    WarehouseMatchedCount,
    StageDistinctCount - WarehouseMatchedCount AS MissingWarehouseRows
FROM RowCountReconciliation
ORDER BY CheckName;
GO

SELECT
    N'Warehouse Integrity Counts' AS ReportSection,
    CheckName,
    IssueCount
FROM
(
    SELECT N'Duplicate shipments in FactShipment' AS CheckName, COUNT(*) AS IssueCount
    FROM
    (
        SELECT ShipmentNumber
        FROM dw.FactShipment
        GROUP BY ShipmentNumber
        HAVING COUNT(*) > 1
    ) AS d

    UNION ALL

    SELECT N'Duplicate events in FactDeliveryEvent', COUNT(*)
    FROM
    (
        SELECT ShipmentNumber, EventSequenceNumber
        FROM dw.FactDeliveryEvent
        GROUP BY ShipmentNumber, EventSequenceNumber
        HAVING COUNT(*) > 1
    ) AS d

    UNION ALL

    SELECT N'Duplicate exceptions in FactDeliveryException', COUNT(*)
    FROM
    (
        SELECT ShipmentNumber, DeliveryExceptionKey, ExceptionDateTime
        FROM dw.FactDeliveryException
        GROUP BY ShipmentNumber, DeliveryExceptionKey, ExceptionDateTime
        HAVING COUNT(*) > 1
    ) AS d

    UNION ALL

    SELECT N'FactShipment null required fields', COUNT(*)
    FROM dw.FactShipment
    WHERE ShipmentNumber IS NULL
       OR ShipmentStatus IS NULL

    UNION ALL

    SELECT N'FactDeliveryEvent null required fields', COUNT(*)
    FROM dw.FactDeliveryEvent
    WHERE ShipmentNumber IS NULL
       OR EventDateTime IS NULL

    UNION ALL

    SELECT N'FactDeliveryException null required fields', COUNT(*)
    FROM dw.FactDeliveryException
    WHERE ShipmentNumber IS NULL
       OR ExceptionDateTime IS NULL

    UNION ALL

    SELECT N'Late/on-time rule mismatches', COUNT(*)
    FROM dw.FactShipment AS fs
    WHERE (fs.LateDeliveryFlag = 1 AND ISNULL(fs.DeliveryDelayMinutes, 0) <= 0)
       OR (fs.OnTimeDeliveryFlag = 1 AND ISNULL(fs.DeliveryDelayMinutes, 0) <> 0)
       OR (fs.OnTimeDeliveryFlag = 1 AND fs.LateDeliveryFlag = 1)

    UNION ALL

    SELECT N'Negative transit or delay metrics', COUNT(*)
    FROM dw.FactShipment
    WHERE ISNULL(TransitHours, 0) < 0
       OR ISNULL(TransitDays, 0) < 0
       OR ISNULL(DeliveryDelayMinutes, 0) < 0

    UNION ALL

    SELECT N'Event sequences with decreasing timestamps', COUNT(*)
    FROM
    (
        SELECT
            ShipmentNumber,
            EventSequenceNumber,
            EventDateTime,
            LAG(EventDateTime) OVER
            (
                PARTITION BY ShipmentNumber
                ORDER BY EventSequenceNumber
            ) AS PreviousEventDateTime
        FROM dw.FactDeliveryEvent
    ) AS d
    WHERE d.PreviousEventDateTime IS NOT NULL
      AND d.EventDateTime < d.PreviousEventDateTime

    UNION ALL

    SELECT N'Exception flag mismatches', COUNT(*)
    FROM dw.FactShipment AS fs
    LEFT JOIN dw.DimShipmentStatus AS ss
        ON fs.ShipmentStatusKey = ss.ShipmentStatusKey
    WHERE (fs.ExceptionShipmentFlag = 0 AND (fs.ExceptionCount > 0 OR ISNULL(ss.IsExceptionStatus, 0) = 1))
       OR (fs.ExceptionShipmentFlag = 1 AND fs.ExceptionCount = 0 AND ISNULL(ss.IsExceptionStatus, 0) = 0)
)
AS q
ORDER BY CheckName;
GO

SELECT
    N'Unknown Member Usage' AS ReportSection,
    FactName,
    UnknownType,
    IssueCount
FROM
(
    SELECT N'FactShipment' AS FactName, N'CarrierKey' AS UnknownType, COUNT(*) AS IssueCount
    FROM dw.FactShipment
    WHERE CarrierKey = 0

    UNION ALL

    SELECT N'FactShipment', N'RouteKey', COUNT(*)
    FROM dw.FactShipment
    WHERE RouteKey = 0

    UNION ALL

    SELECT N'FactShipment', N'OriginLocationKey', COUNT(*)
    FROM dw.FactShipment
    WHERE OriginLocationKey = 0

    UNION ALL

    SELECT N'FactShipment', N'DestinationLocationKey', COUNT(*)
    FROM dw.FactShipment
    WHERE DestinationLocationKey = 0

    UNION ALL

    SELECT N'FactShipment', N'ShipmentStatusKey', COUNT(*)
    FROM dw.FactShipment
    WHERE ShipmentStatusKey = 0

    UNION ALL

    SELECT N'FactDeliveryEvent', N'EventLocationKey', COUNT(*)
    FROM dw.FactDeliveryEvent
    WHERE EventLocationKey = 0

    UNION ALL

    SELECT N'FactDeliveryEvent', N'DeliveryExceptionKey', COUNT(*)
    FROM dw.FactDeliveryEvent
    WHERE DeliveryExceptionKey = 0

    UNION ALL

    SELECT N'FactDeliveryException', N'DeliveryExceptionKey', COUNT(*)
    FROM dw.FactDeliveryException
    WHERE DeliveryExceptionKey = 0
) AS q
ORDER BY FactName, UnknownType;
GO

DECLARE @LatestBatchID int =
(
    SELECT MAX(BatchID)
    FROM meta.Batch_Run
    WHERE Status = 'SUCCEEDED'
);

SELECT
    N'Reject Summary By Source Table' AS ReportSection,
    @LatestBatchID AS BatchID,
    SourceTableName,
    COUNT(*) AS RejectCount
FROM audit.Stage_Row_Reject
WHERE BatchID = @LatestBatchID
GROUP BY SourceTableName
ORDER BY RejectCount DESC, SourceTableName;
GO

DECLARE @LatestBatchID int =
(
    SELECT MAX(BatchID)
    FROM meta.Batch_Run
    WHERE Status = 'SUCCEEDED'
);

SELECT
    N'Incremental Audit Validation' AS ReportSection,
    @LatestBatchID AS BatchID,
    b.RowsRead,
    stage_counts.StageRowCount,
    b.RowsInserted,
    audit_counts.AuditRowsInserted,
    b.RowsUpdated,
    audit_counts.AuditRowsUpdated,
    b.RowsLoaded,
    audit_counts.AuditRowsLoaded,
    b.RowsRejected,
    reject_counts.RejectCount
FROM meta.Batch_Run AS b
CROSS APPLY
(
    SELECT
        ISNULL((SELECT COUNT(*) FROM stg.Carrier_Raw WHERE BatchID = b.BatchID), 0)
      + ISNULL((SELECT COUNT(*) FROM stg.Location_Raw WHERE BatchID = b.BatchID), 0)
      + ISNULL((SELECT COUNT(*) FROM stg.Route_Raw WHERE BatchID = b.BatchID), 0)
      + ISNULL((SELECT COUNT(*) FROM stg.Shipment_Raw WHERE BatchID = b.BatchID), 0)
      + ISNULL((SELECT COUNT(*) FROM stg.Shipment_Status_History_Raw WHERE BatchID = b.BatchID), 0)
      + ISNULL((SELECT COUNT(*) FROM stg.Delivery_Exception_Raw WHERE BatchID = b.BatchID), 0)
      + ISNULL((SELECT COUNT(*) FROM stg.Exception_Code_Lookup_Raw WHERE BatchID = b.BatchID), 0)
      + ISNULL((SELECT COUNT(*) FROM stg.Route_Distance_Reference_Raw WHERE BatchID = b.BatchID), 0) AS StageRowCount
) AS stage_counts
CROSS APPLY
(
    SELECT
        ISNULL(SUM(RowsInserted), 0) AS AuditRowsInserted,
        ISNULL(SUM(RowsUpdated), 0) AS AuditRowsUpdated,
        ISNULL(SUM(RowsInserted + RowsUpdated), 0) AS AuditRowsLoaded
    FROM audit.Load_Audit
    WHERE BatchID = b.BatchID
) AS audit_counts
CROSS APPLY
(
    SELECT COUNT(*) AS RejectCount
    FROM audit.Stage_Row_Reject
    WHERE BatchID = b.BatchID
) AS reject_counts
WHERE b.BatchID = @LatestBatchID;
GO

DECLARE @LatestBatchID int =
(
    SELECT MAX(BatchID)
    FROM meta.Batch_Run
    WHERE Status = 'SUCCEEDED'
);

SELECT
    N'Restatement Validation' AS ReportSection,
    @LatestBatchID AS BatchID,
    COUNT(*) AS EventOrExceptionShipmentsInBatch,
    SUM(CASE WHEN s.ShipmentNumber IS NOT NULL THEN 1 ELSE 0 END) AS ShipmentsWithShipmentStageRow,
    SUM(CASE WHEN fs.ShipmentNumber IS NOT NULL THEN 1 ELSE 0 END) AS ShipmentsResolvedToFactShipment
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
LEFT JOIN stg.Shipment_Raw AS s
    ON i.ShipmentNumber = s.ShipmentNumber
   AND s.BatchID = @LatestBatchID
   AND s.IsValid = 1
LEFT JOIN dw.FactShipment AS fs
    ON i.ShipmentNumber = fs.ShipmentNumber;
GO

DECLARE @LatestBatchID int =
(
    SELECT MAX(BatchID)
    FROM meta.Batch_Run
    WHERE Status = 'SUCCEEDED'
);

SELECT
    N'Event-Only Restatement Checks' AS ReportSection,
    @LatestBatchID AS BatchID,
    e.ShipmentNumber,
    e.BatchEventCount,
    fs.ScanEventCount,
    fs.ActualDeliveryDateKey,
    e.HasDeliveredEvent
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
ORDER BY e.BatchEventCount DESC, e.ShipmentNumber;
GO

DECLARE @LatestBatchID int =
(
    SELECT MAX(BatchID)
    FROM meta.Batch_Run
    WHERE Status = 'SUCCEEDED'
);

SELECT
    N'Exception-Only Restatement Checks' AS ReportSection,
    @LatestBatchID AS BatchID,
    x.ShipmentNumber,
    x.BatchExceptionCount,
    fs.ExceptionCount,
    fs.ExceptionShipmentFlag
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
ORDER BY x.BatchExceptionCount DESC, x.ShipmentNumber;
GO

SELECT
    N'Route Benchmark Coverage' AS ReportSection,
    COUNT(*) AS ShipmentCount,
    SUM(CASE WHEN r.ReferenceDistanceMiles IS NOT NULL AND r.ReferenceTransitHours IS NOT NULL THEN 1 ELSE 0 END) AS BenchmarkCoveredShipments,
    CAST
    (
        100.0 * SUM(CASE WHEN r.ReferenceDistanceMiles IS NOT NULL AND r.ReferenceTransitHours IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0)
        AS decimal(5, 2)
    ) AS BenchmarkCoveragePct
FROM dw.FactShipment AS fs
INNER JOIN dw.DimRoute AS r
    ON fs.RouteKey = r.RouteKey;
GO

SELECT
    N'Exception Category Distribution' AS ReportSection,
    de.ExceptionCategory,
    COUNT(*) AS ExceptionRows
FROM dw.FactDeliveryException AS fe
INNER JOIN dw.DimDeliveryException AS de
    ON fe.DeliveryExceptionKey = de.DeliveryExceptionKey
GROUP BY de.ExceptionCategory
ORDER BY ExceptionRows DESC, de.ExceptionCategory;
GO

SELECT
    N'Reporting View Counts' AS ReportSection,
    ViewName,
    RowCount,
    TotalBusinessCount
FROM
(
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
    FROM rpt.vw_CarrierExceptionTrends
) AS v
ORDER BY ViewName;
GO

SELECT TOP (10)
    N'Delivery Performance Sample' AS ReportSection,
    *
FROM rpt.vw_DeliveryPerformance
ORDER BY CalendarYear DESC, CalendarMonth DESC, CarrierName;
GO

SELECT TOP (10)
    N'Route Efficiency Sample' AS ReportSection,
    *
FROM rpt.vw_RouteEfficiency
ORDER BY ShipmentCount DESC, RouteCode;
GO

SELECT TOP (10)
    N'Carrier Exception Trends Sample' AS ReportSection,
    *
FROM rpt.vw_CarrierExceptionTrends
ORDER BY CalendarYear DESC, CalendarMonth DESC, CarrierName;
GO
