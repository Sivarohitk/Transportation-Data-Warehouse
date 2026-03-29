USE [TransportationDW];
GO

DECLARE @LatestBatchID int =
(
    SELECT MAX(BatchID)
    FROM meta.Batch_Run
    WHERE Status = 'SUCCEEDED'
);

DECLARE @RunRerunProbe bit = 0;

IF @LatestBatchID IS NULL
BEGIN
    THROW 50000, 'No succeeded batch exists. Run a warehouse load before executing incremental checks.', 1;
END;

IF OBJECT_ID('tempdb..#IncrementalChecks') IS NOT NULL
BEGIN
    DROP TABLE #IncrementalChecks;
END;

CREATE TABLE #IncrementalChecks
(
    CheckArea nvarchar(100) NOT NULL,
    CheckName nvarchar(200) NOT NULL,
    IssueCount bigint NOT NULL
);

INSERT INTO #IncrementalChecks (CheckArea, CheckName, IssueCount)
SELECT N'Batch Audit', N'Latest batch missing expected warehouse load steps', COUNT(*)
FROM
(
    SELECT N'Validate Stage Data' AS StepName
    UNION ALL SELECT N'Load Dimensions'
    UNION ALL SELECT N'Load Fact Shipment'
    UNION ALL SELECT N'Load Fact Delivery Event'
    UNION ALL SELECT N'Load Fact Delivery Exception'
) AS expected_steps
LEFT JOIN audit.Load_Audit AS a
    ON a.BatchID = @LatestBatchID
   AND a.StepName = expected_steps.StepName
   AND a.Status = 'SUCCEEDED'
WHERE a.LoadAuditID IS NULL;

INSERT INTO #IncrementalChecks (CheckArea, CheckName, IssueCount)
SELECT N'Batch Audit', N'Latest batch row-count mismatch against stage tables', COUNT(*)
FROM
(
    SELECT
        b.BatchID,
        b.RowsRead,
        stage_counts.StageRowCount
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
    WHERE b.BatchID = @LatestBatchID
) AS d
WHERE ISNULL(d.RowsRead, -1) <> d.StageRowCount;

INSERT INTO #IncrementalChecks (CheckArea, CheckName, IssueCount)
SELECT N'Batch Audit', N'Latest batch RowsLoaded does not equal RowsInserted + RowsUpdated', COUNT(*)
FROM meta.Batch_Run
WHERE BatchID = @LatestBatchID
  AND ISNULL(RowsLoaded, -1) <> ISNULL(RowsInserted, 0) + ISNULL(RowsUpdated, 0);

INSERT INTO #IncrementalChecks (CheckArea, CheckName, IssueCount)
SELECT N'Batch Audit', N'Latest batch RowsRejected does not equal reject table count', COUNT(*)
FROM meta.Batch_Run
WHERE BatchID = @LatestBatchID
  AND ISNULL(RowsRejected, -1) <>
      (
          SELECT COUNT(*)
          FROM audit.Stage_Row_Reject
          WHERE BatchID = @LatestBatchID
      );

INSERT INTO #IncrementalChecks (CheckArea, CheckName, IssueCount)
SELECT N'Watermarks', N'WarehouseIncrementalLoad watermark not promoted to latest batch', COUNT(*)
FROM meta.Watermark
WHERE ProcessName = N'WarehouseIncrementalLoad'
  AND ISNULL(LastSuccessfulBatchID, -1) <> @LatestBatchID;

INSERT INTO #IncrementalChecks (CheckArea, CheckName, IssueCount)
SELECT N'Watermarks', N'Pending watermarks remain attached to latest succeeded batch', COUNT(*)
FROM meta.Watermark
WHERE PendingBatchID = @LatestBatchID;

INSERT INTO #IncrementalChecks (CheckArea, CheckName, IssueCount)
SELECT N'Watermarks', N'Successful watermark points to a non-succeeded batch', COUNT(*)
FROM meta.Watermark AS w
LEFT JOIN meta.Batch_Run AS b
    ON w.LastSuccessfulBatchID = b.BatchID
WHERE w.LastSuccessfulBatchID IS NOT NULL
  AND (b.BatchID IS NULL OR b.Status <> 'SUCCEEDED');

INSERT INTO #IncrementalChecks (CheckArea, CheckName, IssueCount)
SELECT N'Watermarks', N'Flat-file loads missing a matching successful flat-file watermark', COUNT(*)
FROM
(
    SELECT DISTINCT CONCAT(N'FlatFile.', SourceObjectName) AS ProcessName
    FROM meta.Source_File_Log
    WHERE BatchID = @LatestBatchID
      AND SourceType = 'FLAT_FILE'
      AND LoadStatus = 'LOADED'
) AS ff
LEFT JOIN meta.Watermark AS w
    ON ff.ProcessName = w.ProcessName
   AND w.LastSuccessfulBatchID = @LatestBatchID
WHERE w.ProcessName IS NULL;

INSERT INTO #IncrementalChecks (CheckArea, CheckName, IssueCount)
SELECT N'Restatement', N'Latest batch event-only shipments missing FactShipment or scan restatement', COUNT(*)
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
   OR (e.HasDeliveredEvent = 1 AND ISNULL(fs.ActualDeliveryDateKey, 0) = 0);

INSERT INTO #IncrementalChecks (CheckArea, CheckName, IssueCount)
SELECT N'Restatement', N'Latest batch exception-only shipments missing FactShipment or exception restatement', COUNT(*)
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
   OR ISNULL(fs.ExceptionCount, 0) < x.BatchExceptionCount;

SELECT
    @LatestBatchID AS BatchID,
    CheckArea,
    CheckName,
    IssueCount
FROM #IncrementalChecks
ORDER BY CheckArea, CheckName;

IF EXISTS
(
    SELECT 1
    FROM #IncrementalChecks
    WHERE IssueCount > 0
)
BEGIN
    THROW 50000, 'Incremental load checks found one or more failures.', 1;
END;

IF @RunRerunProbe = 1
BEGIN
    DECLARE @FactShipmentCountBefore bigint = (SELECT COUNT(*) FROM dw.FactShipment);
    DECLARE @FactDeliveryEventCountBefore bigint = (SELECT COUNT(*) FROM dw.FactDeliveryEvent);
    DECLARE @FactDeliveryExceptionCountBefore bigint = (SELECT COUNT(*) FROM dw.FactDeliveryException);
    DECLARE @AuditBefore bigint = ISNULL((SELECT MAX(LoadAuditID) FROM audit.Load_Audit), 0);

    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    BEGIN TRY
        EXEC etl.usp_Run_Incremental_Load
            @BatchID = @LatestBatchID,
            @Notes = N'Idempotency probe';

        IF (SELECT COUNT(*) FROM dw.FactShipment) <> @FactShipmentCountBefore
        BEGIN
            THROW 50000, 'Idempotency probe changed FactShipment row count on rerun.', 1;
        END;

        IF (SELECT COUNT(*) FROM dw.FactDeliveryEvent) <> @FactDeliveryEventCountBefore
        BEGIN
            THROW 50000, 'Idempotency probe changed FactDeliveryEvent row count on rerun.', 1;
        END;

        IF (SELECT COUNT(*) FROM dw.FactDeliveryException) <> @FactDeliveryExceptionCountBefore
        BEGIN
            THROW 50000, 'Idempotency probe changed FactDeliveryException row count on rerun.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM audit.Load_Audit
            WHERE LoadAuditID > @AuditBefore
              AND BatchID = @LatestBatchID
              AND StepName IN
              (
                  N'Load Dimensions',
                  N'Load Fact Shipment',
                  N'Load Fact Delivery Event',
                  N'Load Fact Delivery Exception'
              )
              AND (RowsInserted <> 0 OR RowsUpdated <> 0)
        )
        BEGIN
            THROW 50000, 'Idempotency probe recorded non-zero inserts or updates on rerun.', 1;
        END;

        ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        THROW;
    END CATCH;
END;

SELECT
    N'Incremental load checks completed successfully.' AS TestStatus,
    @LatestBatchID AS LatestSuccessfulBatchID,
    @RunRerunProbe AS RerunProbeExecuted;
GO
