USE [$(DatabaseName)];
GO

CREATE OR ALTER PROCEDURE etl.usp_Reset_Stage_Tables
    @BatchID int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @BatchID IS NULL
    BEGIN
        DELETE FROM audit.Stage_Row_Reject;

        DELETE FROM audit.Validation_Error
        WHERE SourceTableName IN
        (
            N'stg.Carrier_Raw',
            N'stg.Location_Raw',
            N'stg.Route_Raw',
            N'stg.Shipment_Raw',
            N'stg.Shipment_Status_History_Raw',
            N'stg.Delivery_Exception_Raw',
            N'stg.Exception_Code_Lookup_Raw',
            N'stg.Route_Distance_Reference_Raw'
        );

        DELETE FROM stg.Delivery_Exception_Raw;
        DELETE FROM stg.Shipment_Status_History_Raw;
        DELETE FROM stg.Shipment_Raw;
        DELETE FROM stg.Route_Distance_Reference_Raw;
        DELETE FROM stg.Exception_Code_Lookup_Raw;
        DELETE FROM stg.Route_Raw;
        DELETE FROM stg.Location_Raw;
        DELETE FROM stg.Carrier_Raw;

        RETURN;
    END;

    DELETE FROM audit.Stage_Row_Reject
    WHERE BatchID = @BatchID;

    DELETE FROM audit.Validation_Error
    WHERE BatchID = @BatchID
      AND SourceTableName IN
      (
          N'stg.Carrier_Raw',
          N'stg.Location_Raw',
          N'stg.Route_Raw',
          N'stg.Shipment_Raw',
          N'stg.Shipment_Status_History_Raw',
          N'stg.Delivery_Exception_Raw',
          N'stg.Exception_Code_Lookup_Raw',
          N'stg.Route_Distance_Reference_Raw'
      );

    DELETE FROM stg.Delivery_Exception_Raw WHERE BatchID = @BatchID;
    DELETE FROM stg.Shipment_Status_History_Raw WHERE BatchID = @BatchID;
    DELETE FROM stg.Shipment_Raw WHERE BatchID = @BatchID;
    DELETE FROM stg.Route_Distance_Reference_Raw WHERE BatchID = @BatchID;
    DELETE FROM stg.Exception_Code_Lookup_Raw WHERE BatchID = @BatchID;
    DELETE FROM stg.Route_Raw WHERE BatchID = @BatchID;
    DELETE FROM stg.Location_Raw WHERE BatchID = @BatchID;
    DELETE FROM stg.Carrier_Raw WHERE BatchID = @BatchID;
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Register_Flat_File_Stage_Load
    @BatchID int,
    @SourceObjectName nvarchar(150),
    @FileName nvarchar(260),
    @RowsReceived int = NULL,
    @RowsLoaded int = NULL,
    @RowsRejected int = NULL,
    @LoadStatus varchar(20) = 'LOADED',
    @FileModifiedAt datetime2(0) = NULL,
    @Message nvarchar(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM meta.Batch_Run
        WHERE BatchID = @BatchID
    )
    BEGIN
        THROW 50001, 'The supplied BatchID does not exist in meta.Batch_Run.', 1;
    END;

    MERGE meta.Source_File_Log AS target
    USING
    (
        SELECT
            @BatchID AS BatchID,
            @SourceObjectName AS SourceObjectName,
            @FileName AS FileName
    ) AS source
        ON target.BatchID = source.BatchID
       AND target.SourceType = 'FLAT_FILE'
       AND target.SourceObjectName = source.SourceObjectName
       AND target.FileName = source.FileName
    WHEN MATCHED
        THEN UPDATE
             SET RowsReceived = @RowsReceived,
                 RowsLoaded = @RowsLoaded,
                 RowsRejected = @RowsRejected,
                 FileModifiedAt = @FileModifiedAt,
                 LoadStatus = @LoadStatus,
                 LoadedAt = SYSUTCDATETIME(),
                 Message = @Message
    WHEN NOT MATCHED BY TARGET
        THEN INSERT
        (
            BatchID,
            SourceObjectName,
            SourceType,
            FileName,
            RowsReceived,
            RowsLoaded,
            RowsRejected,
            FileModifiedAt,
            LoadStatus,
            Message
        )
        VALUES
        (
            @BatchID,
            @SourceObjectName,
            'FLAT_FILE',
            @FileName,
            @RowsReceived,
            @RowsLoaded,
            @RowsRejected,
            @FileModifiedAt,
            @LoadStatus,
            @Message
        );
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Load_Stage_From_Source
    @BatchID int,
    @SourceName nvarchar(100) = N'SRC_OLTP',
    @RunValidation bit = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AuditID bigint;
    DECLARE @RowsInserted int = 0;
    DECLARE @RowsRejected int = 0;

    DECLARE @CarrierRows int = 0;
    DECLARE @LocationRows int = 0;
    DECLARE @RouteRows int = 0;
    DECLARE @ShipmentRows int = 0;
    DECLARE @ShipmentStatusRows int = 0;
    DECLARE @DeliveryExceptionRows int = 0;
    DECLARE @ExceptionLookupRows int = 0;
    DECLARE @RouteDistanceRows int = 0;

    DECLARE @ShipmentDeltaRows int = 0;
    DECLARE @ShipmentStatusDeltaRows int = 0;
    DECLARE @DeliveryExceptionDeltaRows int = 0;
    DECLARE @ImpactedShipmentRows int = 0;

    DECLARE @ShipmentWatermark datetime2(0) = '1900-01-01';
    DECLARE @ShipmentWatermarkSequence bigint = 0;
    DECLARE @ShipmentStatusWatermark datetime2(0) = '1900-01-01';
    DECLARE @ShipmentStatusWatermarkSequence bigint = 0;
    DECLARE @DeliveryExceptionWatermark datetime2(0) = '1900-01-01';
    DECLARE @DeliveryExceptionWatermarkSequence bigint = 0;

    DECLARE @NewShipmentWatermark datetime2(0);
    DECLARE @NewShipmentWatermarkSequence bigint;
    DECLARE @NewShipmentStatusWatermark datetime2(0);
    DECLARE @NewShipmentStatusWatermarkSequence bigint;
    DECLARE @NewDeliveryExceptionWatermark datetime2(0);
    DECLARE @NewDeliveryExceptionWatermarkSequence bigint;

    BEGIN TRY
        IF NOT EXISTS
        (
            SELECT 1
            FROM meta.Batch_Run
            WHERE BatchID = @BatchID
        )
        BEGIN
            THROW 50002, 'The supplied BatchID does not exist in meta.Batch_Run.', 1;
        END;

        INSERT INTO audit.Load_Audit
        (
            BatchID,
            StepName,
            TargetObjectName,
            Status
        )
        VALUES
        (
            @BatchID,
            N'Load Stage From Source',
            N'stg.* from src.*',
            'STARTED'
        );

        SET @AuditID = SCOPE_IDENTITY();

        EXEC etl.usp_Reset_Stage_Tables
            @BatchID = @BatchID;

        DELETE FROM meta.Source_File_Log
        WHERE BatchID = @BatchID
          AND SourceType = 'SQL_SERVER';

        SELECT
            @ShipmentWatermark = ISNULL(LastWatermarkValue, '1900-01-01'),
            @ShipmentWatermarkSequence = ISNULL(LastWatermarkSequence, 0)
        FROM meta.Watermark
        WHERE ProcessName = N'StageLoad_src.Shipment';

        SELECT
            @ShipmentStatusWatermark = ISNULL(LastWatermarkValue, '1900-01-01'),
            @ShipmentStatusWatermarkSequence = ISNULL(LastWatermarkSequence, 0)
        FROM meta.Watermark
        WHERE ProcessName = N'StageLoad_src.ShipmentStatusHistory';

        SELECT
            @DeliveryExceptionWatermark = ISNULL(LastWatermarkValue, '1900-01-01'),
            @DeliveryExceptionWatermarkSequence = ISNULL(LastWatermarkSequence, 0)
        FROM meta.Watermark
        WHERE ProcessName = N'StageLoad_src.DeliveryException';

        CREATE TABLE #ShipmentDelta
        (
            ShipmentID bigint NOT NULL PRIMARY KEY,
            SourceModifiedAt datetime2(0) NOT NULL
        );

        CREATE TABLE #ShipmentStatusDelta
        (
            ShipmentStatusHistoryID bigint NOT NULL PRIMARY KEY,
            ShipmentID bigint NOT NULL,
            EventDateTime datetime2(0) NOT NULL
        );

        CREATE TABLE #DeliveryExceptionDelta
        (
            DeliveryExceptionID bigint NOT NULL PRIMARY KEY,
            ShipmentID bigint NOT NULL,
            ExceptionDateTime datetime2(0) NOT NULL
        );

        CREATE TABLE #ImpactedShipment
        (
            ShipmentID bigint NOT NULL PRIMARY KEY
        );

        INSERT INTO #ShipmentDelta
        (
            ShipmentID,
            SourceModifiedAt
        )
        SELECT
            s.ShipmentID,
            s.SourceModifiedAt
        FROM src.Shipment AS s
        WHERE s.SourceModifiedAt > @ShipmentWatermark
           OR (s.SourceModifiedAt = @ShipmentWatermark AND s.ShipmentID > @ShipmentWatermarkSequence);

        INSERT INTO #ShipmentStatusDelta
        (
            ShipmentStatusHistoryID,
            ShipmentID,
            EventDateTime
        )
        SELECT
            h.ShipmentStatusHistoryID,
            h.ShipmentID,
            h.EventDateTime
        FROM src.Shipment_Status_History AS h
        WHERE h.EventDateTime > @ShipmentStatusWatermark
           OR (h.EventDateTime = @ShipmentStatusWatermark AND h.ShipmentStatusHistoryID > @ShipmentStatusWatermarkSequence);

        INSERT INTO #DeliveryExceptionDelta
        (
            DeliveryExceptionID,
            ShipmentID,
            ExceptionDateTime
        )
        SELECT
            e.DeliveryExceptionID,
            e.ShipmentID,
            e.ExceptionDateTime
        FROM src.Delivery_Exception AS e
        WHERE e.ExceptionDateTime > @DeliveryExceptionWatermark
           OR (e.ExceptionDateTime = @DeliveryExceptionWatermark AND e.DeliveryExceptionID > @DeliveryExceptionWatermarkSequence);

        INSERT INTO #ImpactedShipment
        (
            ShipmentID
        )
        SELECT d.ShipmentID
        FROM #ShipmentDelta AS d

        UNION

        SELECT d.ShipmentID
        FROM #ShipmentStatusDelta AS d

        UNION

        SELECT d.ShipmentID
        FROM #DeliveryExceptionDelta AS d;

        SELECT @ShipmentDeltaRows = COUNT(*) FROM #ShipmentDelta;
        SELECT @ShipmentStatusDeltaRows = COUNT(*) FROM #ShipmentStatusDelta;
        SELECT @DeliveryExceptionDeltaRows = COUNT(*) FROM #DeliveryExceptionDelta;
        SELECT @ImpactedShipmentRows = COUNT(*) FROM #ImpactedShipment;

        INSERT INTO stg.Carrier_Raw
        (
            BatchID,
            CarrierCode,
            SCACCode,
            CarrierName,
            CarrierMode,
            CarrierTier,
            HomeCity,
            HomeStateProvince,
            ActiveFlag,
            SourceName
        )
        SELECT
            @BatchID,
            c.CarrierCode,
            c.SCACCode,
            c.CarrierName,
            c.CarrierMode,
            c.CarrierTier,
            c.HomeCity,
            c.HomeStateProvince,
            c.ActiveFlag,
            @SourceName
        FROM src.Carrier AS c;

        SET @CarrierRows = @@ROWCOUNT;

        INSERT INTO meta.Source_File_Log
        (
            BatchID,
            SourceObjectName,
            SourceType,
            FileName,
            RowsReceived,
            RowsLoaded,
            RowsRejected,
            LoadStatus,
            Message
        )
        VALUES
        (
            @BatchID,
            N'src.Carrier',
            'SQL_SERVER',
            NULL,
            @CarrierRows,
            @CarrierRows,
            0,
            'LOADED',
            N'Full source snapshot loaded to stg.Carrier_Raw.'
        );

        INSERT INTO stg.Location_Raw
        (
            BatchID,
            LocationCode,
            LocationName,
            LocationType,
            AddressLine1,
            City,
            StateProvince,
            CountryCode,
            PostalCode,
            Region,
            Latitude,
            Longitude,
            ActiveFlag,
            SourceName
        )
        SELECT
            @BatchID,
            l.LocationCode,
            l.LocationName,
            l.LocationType,
            l.AddressLine1,
            l.City,
            l.StateProvince,
            l.CountryCode,
            l.PostalCode,
            l.Region,
            l.Latitude,
            l.Longitude,
            l.ActiveFlag,
            @SourceName
        FROM src.Location AS l;

        SET @LocationRows = @@ROWCOUNT;

        INSERT INTO meta.Source_File_Log
        (
            BatchID,
            SourceObjectName,
            SourceType,
            FileName,
            RowsReceived,
            RowsLoaded,
            RowsRejected,
            LoadStatus,
            Message
        )
        VALUES
        (
            @BatchID,
            N'src.Location',
            'SQL_SERVER',
            NULL,
            @LocationRows,
            @LocationRows,
            0,
            'LOADED',
            N'Full source snapshot loaded to stg.Location_Raw.'
        );

        INSERT INTO stg.Route_Raw
        (
            BatchID,
            RouteCode,
            OriginLocationCode,
            DestinationLocationCode,
            RouteType,
            PlannedDistanceMiles,
            PlannedTransitHours,
            ActiveFlag,
            EffectiveStartDate,
            EffectiveEndDate,
            SourceName
        )
        SELECT
            @BatchID,
            r.RouteCode,
            ol.LocationCode,
            dl.LocationCode,
            r.RouteType,
            r.StandardDistanceMiles,
            r.StandardTransitHours,
            r.ActiveFlag,
            r.EffectiveStartDate,
            r.EffectiveEndDate,
            @SourceName
        FROM src.Route AS r
        INNER JOIN src.Location AS ol
            ON r.OriginLocationID = ol.LocationID
        INNER JOIN src.Location AS dl
            ON r.DestinationLocationID = dl.LocationID;

        SET @RouteRows = @@ROWCOUNT;

        INSERT INTO meta.Source_File_Log
        (
            BatchID,
            SourceObjectName,
            SourceType,
            FileName,
            RowsReceived,
            RowsLoaded,
            RowsRejected,
            LoadStatus,
            Message
        )
        VALUES
        (
            @BatchID,
            N'src.Route',
            'SQL_SERVER',
            NULL,
            @RouteRows,
            @RouteRows,
            0,
            'LOADED',
            N'Full source snapshot loaded to stg.Route_Raw.'
        );

        INSERT INTO stg.Route_Distance_Reference_Raw
        (
            BatchID,
            RouteCode,
            OriginLocationCode,
            DestinationLocationCode,
            ReferenceDistanceMiles,
            ReferenceTransitHours,
            RouteType,
            FuelZone,
            SourceName
        )
        SELECT
            @BatchID,
            r.RouteCode,
            ol.LocationCode,
            dl.LocationCode,
            r.StandardDistanceMiles,
            r.StandardTransitHours,
            r.RouteType,
            CASE
                WHEN r.StandardDistanceMiles < 250 THEN N'Short Haul'
                WHEN r.StandardDistanceMiles < 700 THEN N'Mid Haul'
                ELSE N'Long Haul'
            END,
            @SourceName
        FROM src.Route AS r
        INNER JOIN src.Location AS ol
            ON r.OriginLocationID = ol.LocationID
        INNER JOIN src.Location AS dl
            ON r.DestinationLocationID = dl.LocationID;

        SET @RouteDistanceRows = @@ROWCOUNT;

        INSERT INTO meta.Source_File_Log
        (
            BatchID,
            SourceObjectName,
            SourceType,
            FileName,
            RowsReceived,
            RowsLoaded,
            RowsRejected,
            LoadStatus,
            Message
        )
        VALUES
        (
            @BatchID,
            N'src.RouteDistanceReference.Derived',
            'SQL_SERVER',
            NULL,
            @RouteDistanceRows,
            @RouteDistanceRows,
            0,
            'LOADED',
            N'Derived route distance reference snapshot loaded to stg.Route_Distance_Reference_Raw.'
        );

        INSERT INTO stg.Exception_Code_Lookup_Raw
        (
            BatchID,
            ExceptionCode,
            ExceptionDescription,
            ExceptionCategory,
            SeverityCode,
            TypicalDelayMinutes,
            ResponsibleParty,
            ActiveFlag,
            SourceName
        )
        SELECT
            @BatchID,
            e.ExceptionCode,
            MAX(e.ExceptionDescription),
            MAX(e.ExceptionCategory),
            MAX(e.SeverityCode),
            CAST(AVG(CAST(COALESCE(e.DelayMinutesImpact, 0) AS decimal(18, 2))) AS int),
            MAX(COALESCE(e.ResponsibleParty, N'Operations')),
            CAST(1 AS bit),
            @SourceName
        FROM src.Delivery_Exception AS e
        GROUP BY e.ExceptionCode;

        SET @ExceptionLookupRows = @@ROWCOUNT;

        INSERT INTO meta.Source_File_Log
        (
            BatchID,
            SourceObjectName,
            SourceType,
            FileName,
            RowsReceived,
            RowsLoaded,
            RowsRejected,
            LoadStatus,
            Message
        )
        VALUES
        (
            @BatchID,
            N'src.DeliveryExceptionLookup.Derived',
            'SQL_SERVER',
            NULL,
            @ExceptionLookupRows,
            @ExceptionLookupRows,
            0,
            'LOADED',
            N'Derived exception lookup snapshot loaded to stg.Exception_Code_Lookup_Raw.'
        );

        INSERT INTO stg.Shipment_Raw
        (
            BatchID,
            ShipmentNumber,
            CarrierCode,
            RouteCode,
            OriginLocationCode,
            DestinationLocationCode,
            CustomerReferenceNumber,
            ShipmentStatus,
            ShipmentCreateDate,
            PlannedPickupDate,
            ActualPickupDate,
            PlannedDeliveryDate,
            ActualDeliveryDate,
            WeightLbs,
            PieceCount,
            ShipmentRevenue,
            ShipmentCost,
            PlannedDistanceMiles,
            ActualDistanceMiles,
            ServiceLevel,
            SourceModifiedAt,
            SourceName
        )
        SELECT
            @BatchID,
            s.ShipmentNumber,
            c.CarrierCode,
            r.RouteCode,
            ol.LocationCode,
            dl.LocationCode,
            s.CustomerReferenceNumber,
            s.CurrentStatus,
            s.ShipmentCreateDateTime,
            s.PlannedPickupDateTime,
            s.ActualPickupDateTime,
            s.PlannedDeliveryDateTime,
            s.ActualDeliveryDateTime,
            s.WeightLbs,
            s.PieceCount,
            s.ShipmentRevenue,
            s.ShipmentCost,
            s.PlannedDistanceMiles,
            s.ActualDistanceMiles,
            s.ServiceLevel,
            s.SourceModifiedAt,
            @SourceName
        FROM src.Shipment AS s
        INNER JOIN #ImpactedShipment AS i
            ON s.ShipmentID = i.ShipmentID
        INNER JOIN src.Carrier AS c
            ON s.CarrierID = c.CarrierID
        INNER JOIN src.Route AS r
            ON s.RouteID = r.RouteID
        INNER JOIN src.Location AS ol
            ON s.OriginLocationID = ol.LocationID
        INNER JOIN src.Location AS dl
            ON s.DestinationLocationID = dl.LocationID;

        SET @ShipmentRows = @@ROWCOUNT;

        INSERT INTO meta.Source_File_Log
        (
            BatchID,
            SourceObjectName,
            SourceType,
            FileName,
            RowsReceived,
            RowsLoaded,
            RowsRejected,
            LoadStatus,
            Message
        )
        VALUES
        (
            @BatchID,
            N'src.Shipment',
            'SQL_SERVER',
            NULL,
            @ShipmentRows,
            @ShipmentRows,
            0,
            'LOADED',
            N'Impacted shipment snapshot loaded to stg.Shipment_Raw for shipment restatement.'
        );

        INSERT INTO stg.Shipment_Status_History_Raw
        (
            BatchID,
            ShipmentNumber,
            EventSequenceNumber,
            StatusCode,
            StatusDescription,
            EventDateTime,
            LocationCode,
            ScanType,
            EventSource,
            ExceptionCode,
            Notes,
            SourceName
        )
        SELECT
            @BatchID,
            s.ShipmentNumber,
            h.EventSequenceNumber,
            h.StatusCode,
            h.StatusDescription,
            h.EventDateTime,
            l.LocationCode,
            h.ScanType,
            h.EventSource,
            h.ExceptionCode,
            h.Notes,
            @SourceName
        FROM src.Shipment_Status_History AS h
        INNER JOIN #ImpactedShipment AS i
            ON h.ShipmentID = i.ShipmentID
        INNER JOIN src.Shipment AS s
            ON h.ShipmentID = s.ShipmentID
        LEFT JOIN src.Location AS l
            ON h.LocationID = l.LocationID;

        SET @ShipmentStatusRows = @@ROWCOUNT;

        INSERT INTO meta.Source_File_Log
        (
            BatchID,
            SourceObjectName,
            SourceType,
            FileName,
            RowsReceived,
            RowsLoaded,
            RowsRejected,
            LoadStatus,
            Message
        )
        VALUES
        (
            @BatchID,
            N'src.Shipment_Status_History',
            'SQL_SERVER',
            NULL,
            @ShipmentStatusRows,
            @ShipmentStatusRows,
            0,
            'LOADED',
            N'Full status history for impacted shipments loaded to stg.Shipment_Status_History_Raw.'
        );

        INSERT INTO stg.Delivery_Exception_Raw
        (
            BatchID,
            ShipmentNumber,
            ExceptionCode,
            ExceptionDescription,
            ExceptionCategory,
            SeverityCode,
            ExceptionStatus,
            ExceptionDateTime,
            DelayMinutesImpact,
            ResolvedDateTime,
            ResponsibleParty,
            Notes,
            SourceName
        )
        SELECT
            @BatchID,
            s.ShipmentNumber,
            e.ExceptionCode,
            e.ExceptionDescription,
            e.ExceptionCategory,
            e.SeverityCode,
            e.ExceptionStatus,
            e.ExceptionDateTime,
            e.DelayMinutesImpact,
            e.ResolvedDateTime,
            e.ResponsibleParty,
            e.Notes,
            @SourceName
        FROM src.Delivery_Exception AS e
        INNER JOIN #ImpactedShipment AS i
            ON e.ShipmentID = i.ShipmentID
        INNER JOIN src.Shipment AS s
            ON e.ShipmentID = s.ShipmentID;

        SET @DeliveryExceptionRows = @@ROWCOUNT;

        INSERT INTO meta.Source_File_Log
        (
            BatchID,
            SourceObjectName,
            SourceType,
            FileName,
            RowsReceived,
            RowsLoaded,
            RowsRejected,
            LoadStatus,
            Message
        )
        VALUES
        (
            @BatchID,
            N'src.Delivery_Exception',
            'SQL_SERVER',
            NULL,
            @DeliveryExceptionRows,
            @DeliveryExceptionRows,
            0,
            'LOADED',
            N'Full exception history for impacted shipments loaded to stg.Delivery_Exception_Raw.'
        );

        SELECT TOP (1)
            @NewShipmentWatermark = d.SourceModifiedAt,
            @NewShipmentWatermarkSequence = d.ShipmentID
        FROM #ShipmentDelta AS d
        ORDER BY d.SourceModifiedAt DESC, d.ShipmentID DESC;

        SELECT TOP (1)
            @NewShipmentStatusWatermark = d.EventDateTime,
            @NewShipmentStatusWatermarkSequence = d.ShipmentStatusHistoryID
        FROM #ShipmentStatusDelta AS d
        ORDER BY d.EventDateTime DESC, d.ShipmentStatusHistoryID DESC;

        SELECT TOP (1)
            @NewDeliveryExceptionWatermark = d.ExceptionDateTime,
            @NewDeliveryExceptionWatermarkSequence = d.DeliveryExceptionID
        FROM #DeliveryExceptionDelta AS d
        ORDER BY d.ExceptionDateTime DESC, d.DeliveryExceptionID DESC;

        IF @NewShipmentWatermark IS NOT NULL
        BEGIN
            EXEC meta.usp_Set_Pending_Watermark
                @ProcessName = N'StageLoad_src.Shipment',
                @BatchID = @BatchID,
                @WatermarkValue = @NewShipmentWatermark,
                @WatermarkSequence = @NewShipmentWatermarkSequence,
                @WatermarkText = N'SourceModifiedAt/ShipmentID';
        END;

        IF @NewShipmentStatusWatermark IS NOT NULL
        BEGIN
            EXEC meta.usp_Set_Pending_Watermark
                @ProcessName = N'StageLoad_src.ShipmentStatusHistory',
                @BatchID = @BatchID,
                @WatermarkValue = @NewShipmentStatusWatermark,
                @WatermarkSequence = @NewShipmentStatusWatermarkSequence,
                @WatermarkText = N'EventDateTime/ShipmentStatusHistoryID';
        END;

        IF @NewDeliveryExceptionWatermark IS NOT NULL
        BEGIN
            EXEC meta.usp_Set_Pending_Watermark
                @ProcessName = N'StageLoad_src.DeliveryException',
                @BatchID = @BatchID,
                @WatermarkValue = @NewDeliveryExceptionWatermark,
                @WatermarkSequence = @NewDeliveryExceptionWatermarkSequence,
                @WatermarkText = N'ExceptionDateTime/DeliveryExceptionID';
        END;

        IF @RunValidation = 1
        BEGIN
            EXEC etl.usp_Validate_Stage_Data
                @BatchID = @BatchID;
        END;

        SET @RowsInserted =
            @CarrierRows
          + @LocationRows
          + @RouteRows
          + @ShipmentRows
          + @ShipmentStatusRows
          + @DeliveryExceptionRows
          + @ExceptionLookupRows
          + @RouteDistanceRows;

        SELECT @RowsRejected = COUNT(*)
        FROM audit.Stage_Row_Reject
        WHERE BatchID = @BatchID;

        UPDATE audit.Load_Audit
        SET RowsInserted = @RowsInserted,
            RowsRejected = @RowsRejected,
            CompletedAt = SYSUTCDATETIME(),
            Status = 'SUCCEEDED',
            Message = CONCAT(
                N'Source-to-stage load completed. Impacted shipments=', @ImpactedShipmentRows,
                N'; shipment delta=', @ShipmentDeltaRows,
                N'; event delta=', @ShipmentStatusDeltaRows,
                N'; exception delta=', @DeliveryExceptionDeltaRows,
                N'. Pending watermarks recorded for promotion after successful warehouse load.'
            )
        WHERE LoadAuditID = @AuditID;
    END TRY
    BEGIN CATCH
        EXEC audit.usp_Log_Error
            @BatchID = @BatchID,
            @ProcedureName = N'etl.usp_Load_Stage_From_Source',
            @ErrorNumber = ERROR_NUMBER(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE(),
            @ErrorLine = ERROR_LINE(),
            @ErrorMessage = ERROR_MESSAGE();

        IF @AuditID IS NOT NULL
        BEGIN
            UPDATE audit.Load_Audit
            SET CompletedAt = SYSUTCDATETIME(),
                Status = 'FAILED',
                Message = ERROR_MESSAGE()
            WHERE LoadAuditID = @AuditID;
        END;

        THROW;
    END CATCH;
END;
GO
