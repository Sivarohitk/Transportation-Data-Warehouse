USE [$(DatabaseName)];
GO

CREATE OR ALTER PROCEDURE etl.usp_Run_Incremental_Load
    @BatchID int,
    @Notes nvarchar(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RowsRead int = 0;
    DECLARE @RowsInserted int = 0;
    DECLARE @RowsUpdated int = 0;
    DECLARE @RowsLoaded int = 0;
    DECLARE @RowsRejected int = 0;

    BEGIN TRY
        IF NOT EXISTS
        (
            SELECT 1
            FROM meta.Batch_Run
            WHERE BatchID = @BatchID
        )
        BEGIN
            THROW 50000, 'The supplied BatchID does not exist in meta.Batch_Run.', 1;
        END;

        EXEC etl.usp_Load_DimDate
            @StartDate = '2024-01-01',
            @EndDate = '2030-12-31';

        EXEC etl.usp_Validate_Stage_Data
            @BatchID = @BatchID;

        EXEC etl.usp_Load_Dimensions
            @BatchID = @BatchID;

        EXEC etl.usp_Load_FactShipment
            @BatchID = @BatchID;

        EXEC etl.usp_Load_FactDeliveryEvent
            @BatchID = @BatchID;

        EXEC etl.usp_Load_FactDeliveryException
            @BatchID = @BatchID;

        SELECT @RowsRead =
            ISNULL((SELECT COUNT(*) FROM stg.Carrier_Raw WHERE BatchID = @BatchID), 0)
          + ISNULL((SELECT COUNT(*) FROM stg.Location_Raw WHERE BatchID = @BatchID), 0)
          + ISNULL((SELECT COUNT(*) FROM stg.Route_Raw WHERE BatchID = @BatchID), 0)
          + ISNULL((SELECT COUNT(*) FROM stg.Shipment_Raw WHERE BatchID = @BatchID), 0)
          + ISNULL((SELECT COUNT(*) FROM stg.Shipment_Status_History_Raw WHERE BatchID = @BatchID), 0)
          + ISNULL((SELECT COUNT(*) FROM stg.Delivery_Exception_Raw WHERE BatchID = @BatchID), 0)
          + ISNULL((SELECT COUNT(*) FROM stg.Exception_Code_Lookup_Raw WHERE BatchID = @BatchID), 0)
          + ISNULL((SELECT COUNT(*) FROM stg.Route_Distance_Reference_Raw WHERE BatchID = @BatchID), 0);

        SELECT @RowsLoaded =
            ISNULL((SELECT SUM(RowsInserted + RowsUpdated) FROM audit.Load_Audit WHERE BatchID = @BatchID), 0);

        SELECT @RowsInserted =
            ISNULL((SELECT SUM(RowsInserted) FROM audit.Load_Audit WHERE BatchID = @BatchID), 0);

        SELECT @RowsUpdated =
            ISNULL((SELECT SUM(RowsUpdated) FROM audit.Load_Audit WHERE BatchID = @BatchID), 0);

        SELECT @RowsRejected =
            ISNULL((SELECT COUNT(*) FROM audit.Stage_Row_Reject WHERE BatchID = @BatchID), 0);

        MERGE meta.Watermark AS target
        USING
        (
            SELECT
                N'WarehouseIncrementalLoad' AS ProcessName,
                @BatchID AS LastSuccessfulBatchID,
                SYSUTCDATETIME() AS LastWatermarkValue,
                CAST(NULL AS bigint) AS LastWatermarkSequence,
                N'Warehouse batch completion timestamp' AS LastWatermarkText
        ) AS source
            ON target.ProcessName = source.ProcessName
        WHEN MATCHED
            THEN UPDATE
                 SET LastSuccessfulBatchID = source.LastSuccessfulBatchID,
                     LastWatermarkValue = source.LastWatermarkValue,
                     LastWatermarkSequence = source.LastWatermarkSequence,
                     LastWatermarkText = source.LastWatermarkText,
                     PendingBatchID = NULL,
                     PendingWatermarkValue = NULL,
                     PendingWatermarkSequence = NULL,
                     PendingWatermarkText = NULL,
                     UpdatedAt = SYSUTCDATETIME()
        WHEN NOT MATCHED BY TARGET
            THEN INSERT
            (
                ProcessName,
                LastSuccessfulBatchID,
                LastWatermarkValue,
                LastWatermarkSequence,
                LastWatermarkText,
                UpdatedAt
            )
            VALUES
            (
                source.ProcessName,
                source.LastSuccessfulBatchID,
                source.LastWatermarkValue,
                source.LastWatermarkSequence,
                source.LastWatermarkText,
                SYSUTCDATETIME()
            );

        EXEC meta.usp_Promote_Batch_Watermarks
            @BatchID = @BatchID;

        MERGE meta.Watermark AS target
        USING
        (
            SELECT
                CONCAT(N'FlatFile.', s.SourceObjectName) AS ProcessName,
                @BatchID AS LastSuccessfulBatchID,
                MAX(s.LoadedAt) AS LastWatermarkValue,
                CAST(NULL AS bigint) AS LastWatermarkSequence,
                MAX(s.FileName) AS LastWatermarkText
            FROM meta.Source_File_Log AS s
            WHERE s.BatchID = @BatchID
              AND s.SourceType = 'FLAT_FILE'
              AND s.LoadStatus = 'LOADED'
            GROUP BY s.SourceObjectName
        ) AS source
            ON target.ProcessName = source.ProcessName
        WHEN MATCHED
            THEN UPDATE
                 SET LastSuccessfulBatchID = source.LastSuccessfulBatchID,
                     LastWatermarkValue = source.LastWatermarkValue,
                     LastWatermarkSequence = source.LastWatermarkSequence,
                     LastWatermarkText = source.LastWatermarkText,
                     PendingBatchID = NULL,
                     PendingWatermarkValue = NULL,
                     PendingWatermarkSequence = NULL,
                     PendingWatermarkText = NULL,
                     UpdatedAt = SYSUTCDATETIME()
        WHEN NOT MATCHED BY TARGET
            THEN INSERT
            (
                ProcessName,
                LastSuccessfulBatchID,
                LastWatermarkValue,
                LastWatermarkSequence,
                LastWatermarkText,
                UpdatedAt
            )
            VALUES
            (
                source.ProcessName,
                source.LastSuccessfulBatchID,
                source.LastWatermarkValue,
                source.LastWatermarkSequence,
                source.LastWatermarkText,
                SYSUTCDATETIME()
            );

        EXEC meta.usp_End_Batch
            @BatchID = @BatchID,
            @Status = 'SUCCEEDED',
            @RowsRead = @RowsRead,
            @RowsInserted = @RowsInserted,
            @RowsUpdated = @RowsUpdated,
            @RowsLoaded = @RowsLoaded,
            @RowsRejected = @RowsRejected,
            @Notes = @Notes;

        SELECT @BatchID AS BatchID;
    END TRY
    BEGIN CATCH
        EXEC audit.usp_Log_Error
            @BatchID = @BatchID,
            @ProcedureName = N'etl.usp_Run_Incremental_Load',
            @ErrorNumber = ERROR_NUMBER(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE(),
            @ErrorLine = ERROR_LINE(),
            @ErrorMessage = ERROR_MESSAGE();

        IF @BatchID IS NOT NULL
        BEGIN
            EXEC meta.usp_End_Batch
                @BatchID = @BatchID,
                @Status = 'FAILED',
                @RowsRead = @RowsRead,
                @RowsInserted = @RowsInserted,
                @RowsUpdated = @RowsUpdated,
                @RowsLoaded = @RowsLoaded,
                @RowsRejected = @RowsRejected,
                @Notes = ERROR_MESSAGE();
        END;

        THROW;
    END CATCH;
END;
GO
