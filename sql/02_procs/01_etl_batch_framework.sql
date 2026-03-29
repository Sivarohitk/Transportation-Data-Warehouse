USE [$(DatabaseName)];
GO

CREATE OR ALTER PROCEDURE meta.usp_Start_Batch
    @BatchName nvarchar(150),
    @SourceName nvarchar(100) = NULL,
    @TriggeredBy sysname = NULL,
    @Notes nvarchar(1000) = NULL,
    @BatchID int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO meta.Batch_Run
    (
        BatchName,
        SourceName,
        TriggeredBy,
        Notes
    )
    VALUES
    (
        @BatchName,
        @SourceName,
        ISNULL(@TriggeredBy, SUSER_SNAME()),
        @Notes
    );

    SET @BatchID = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE meta.usp_End_Batch
    @BatchID int,
    @Status varchar(20),
    @RowsRead int = NULL,
    @RowsInserted int = NULL,
    @RowsUpdated int = NULL,
    @RowsLoaded int = NULL,
    @RowsRejected int = NULL,
    @Notes nvarchar(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE meta.Batch_Run
    SET EndTime = SYSUTCDATETIME(),
        Status = @Status,
        RowsRead = @RowsRead,
        RowsInserted = @RowsInserted,
        RowsUpdated = @RowsUpdated,
        RowsLoaded = COALESCE(@RowsLoaded, ISNULL(@RowsInserted, 0) + ISNULL(@RowsUpdated, 0)),
        RowsRejected = @RowsRejected,
        Notes = COALESCE(@Notes, Notes)
    WHERE BatchID = @BatchID;
END;
GO

CREATE OR ALTER PROCEDURE meta.usp_Set_Pending_Watermark
    @ProcessName nvarchar(150),
    @BatchID int,
    @WatermarkValue datetime2(0) = NULL,
    @WatermarkSequence bigint = NULL,
    @WatermarkText nvarchar(260) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    MERGE meta.Watermark AS target
    USING
    (
        SELECT
            @ProcessName AS ProcessName,
            @BatchID AS PendingBatchID,
            @WatermarkValue AS PendingWatermarkValue,
            @WatermarkSequence AS PendingWatermarkSequence,
            @WatermarkText AS PendingWatermarkText
    ) AS source
        ON target.ProcessName = source.ProcessName
    WHEN MATCHED
        THEN UPDATE
             SET PendingBatchID = source.PendingBatchID,
                 PendingWatermarkValue = source.PendingWatermarkValue,
                 PendingWatermarkSequence = source.PendingWatermarkSequence,
                 PendingWatermarkText = source.PendingWatermarkText,
                 UpdatedAt = SYSUTCDATETIME()
    WHEN NOT MATCHED BY TARGET
        THEN INSERT
        (
            ProcessName,
            PendingBatchID,
            PendingWatermarkValue,
            PendingWatermarkSequence,
            PendingWatermarkText,
            UpdatedAt
        )
        VALUES
        (
            source.ProcessName,
            source.PendingBatchID,
            source.PendingWatermarkValue,
            source.PendingWatermarkSequence,
            source.PendingWatermarkText,
            SYSUTCDATETIME()
        );
END;
GO

CREATE OR ALTER PROCEDURE meta.usp_Promote_Batch_Watermarks
    @BatchID int
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE meta.Watermark
    SET LastSuccessfulBatchID = @BatchID,
        LastWatermarkValue = PendingWatermarkValue,
        LastWatermarkSequence = PendingWatermarkSequence,
        LastWatermarkText = PendingWatermarkText,
        PendingBatchID = NULL,
        PendingWatermarkValue = NULL,
        PendingWatermarkSequence = NULL,
        PendingWatermarkText = NULL,
        UpdatedAt = SYSUTCDATETIME()
    WHERE PendingBatchID = @BatchID;
END;
GO

CREATE OR ALTER PROCEDURE audit.usp_Log_Error
    @BatchID int = NULL,
    @ProcedureName sysname = NULL,
    @ErrorNumber int = NULL,
    @ErrorSeverity int = NULL,
    @ErrorState int = NULL,
    @ErrorLine int = NULL,
    @ErrorMessage nvarchar(4000)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO audit.Error_Log
    (
        BatchID,
        ProcedureName,
        ErrorNumber,
        ErrorSeverity,
        ErrorState,
        ErrorLine,
        ErrorMessage
    )
    VALUES
    (
        @BatchID,
        @ProcedureName,
        @ErrorNumber,
        @ErrorSeverity,
        @ErrorState,
        @ErrorLine,
        @ErrorMessage
    );
END;
GO
