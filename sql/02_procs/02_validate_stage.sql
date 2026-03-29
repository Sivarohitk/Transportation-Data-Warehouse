USE [$(DatabaseName)];
GO

CREATE OR ALTER PROCEDURE audit.usp_Sync_Stage_Rejections
    @BatchID int
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StageErrors TABLE
    (
        SourceTableName nvarchar(150) NOT NULL,
        BusinessKey nvarchar(150) NOT NULL,
        RejectionReason nvarchar(2000) NOT NULL
    );

    INSERT INTO @StageErrors
    (
        SourceTableName,
        BusinessKey,
        RejectionReason
    )
    SELECT
        v.SourceTableName,
        v.BusinessKey,
        LEFT(STRING_AGG(CONVERT(nvarchar(max), v.ErrorMessage), N'; '), 2000) AS RejectionReason
    FROM audit.Validation_Error AS v
    WHERE v.BatchID = @BatchID
      AND v.SourceTableName IN
      (
          N'stg.Carrier_Raw',
          N'stg.Location_Raw',
          N'stg.Route_Raw',
          N'stg.Shipment_Raw',
          N'stg.Shipment_Status_History_Raw',
          N'stg.Delivery_Exception_Raw',
          N'stg.Exception_Code_Lookup_Raw',
          N'stg.Route_Distance_Reference_Raw'
      )
    GROUP BY
        v.SourceTableName,
        v.BusinessKey;

    DELETE FROM audit.Stage_Row_Reject
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

    UPDATE c
    SET RejectionReason = se.RejectionReason
    FROM stg.Carrier_Raw AS c
    LEFT JOIN @StageErrors AS se
        ON se.SourceTableName = N'stg.Carrier_Raw'
       AND se.BusinessKey = COALESCE(NULLIF(LTRIM(RTRIM(c.CarrierCode)), N''), CONCAT(N'StageCarrierID=', c.StageCarrierID))
    WHERE c.BatchID = @BatchID;

    UPDATE l
    SET RejectionReason = se.RejectionReason
    FROM stg.Location_Raw AS l
    LEFT JOIN @StageErrors AS se
        ON se.SourceTableName = N'stg.Location_Raw'
       AND se.BusinessKey = COALESCE(NULLIF(LTRIM(RTRIM(l.LocationCode)), N''), CONCAT(N'StageLocationID=', l.StageLocationID))
    WHERE l.BatchID = @BatchID;

    UPDATE r
    SET RejectionReason = se.RejectionReason
    FROM stg.Route_Raw AS r
    LEFT JOIN @StageErrors AS se
        ON se.SourceTableName = N'stg.Route_Raw'
       AND se.BusinessKey = COALESCE(NULLIF(LTRIM(RTRIM(r.RouteCode)), N''), CONCAT(N'StageRouteID=', r.StageRouteID))
    WHERE r.BatchID = @BatchID;

    UPDATE s
    SET RejectionReason = se.RejectionReason
    FROM stg.Shipment_Raw AS s
    LEFT JOIN @StageErrors AS se
        ON se.SourceTableName = N'stg.Shipment_Raw'
       AND se.BusinessKey = COALESCE(NULLIF(LTRIM(RTRIM(s.ShipmentNumber)), N''), CONCAT(N'StageShipmentID=', s.StageShipmentID))
    WHERE s.BatchID = @BatchID;

    UPDATE h
    SET RejectionReason = se.RejectionReason
    FROM stg.Shipment_Status_History_Raw AS h
    LEFT JOIN @StageErrors AS se
        ON se.SourceTableName = N'stg.Shipment_Status_History_Raw'
       AND se.BusinessKey = CASE
                                WHEN NULLIF(LTRIM(RTRIM(h.ShipmentNumber)), N'') IS NOT NULL
                                 AND h.EventSequenceNumber IS NOT NULL
                                    THEN CONCAT(h.ShipmentNumber, N'|SEQ=', CONVERT(nvarchar(20), h.EventSequenceNumber))
                                ELSE CONCAT(N'StageShipmentStatusHistoryID=', h.StageShipmentStatusHistoryID)
                            END
    WHERE h.BatchID = @BatchID;

    UPDATE e
    SET RejectionReason = se.RejectionReason
    FROM stg.Delivery_Exception_Raw AS e
    LEFT JOIN @StageErrors AS se
        ON se.SourceTableName = N'stg.Delivery_Exception_Raw'
       AND se.BusinessKey = CASE
                                WHEN NULLIF(LTRIM(RTRIM(e.ShipmentNumber)), N'') IS NOT NULL
                                 AND NULLIF(LTRIM(RTRIM(e.ExceptionCode)), N'') IS NOT NULL
                                 AND e.ExceptionDateTime IS NOT NULL
                                    THEN CONCAT(e.ShipmentNumber, N'|EXC=', e.ExceptionCode, N'|DT=', CONVERT(nvarchar(19), e.ExceptionDateTime, 120))
                                ELSE CONCAT(N'StageDeliveryExceptionID=', e.StageDeliveryExceptionID)
                            END
    WHERE e.BatchID = @BatchID;

    UPDATE x
    SET RejectionReason = se.RejectionReason
    FROM stg.Exception_Code_Lookup_Raw AS x
    LEFT JOIN @StageErrors AS se
        ON se.SourceTableName = N'stg.Exception_Code_Lookup_Raw'
       AND se.BusinessKey = COALESCE(NULLIF(LTRIM(RTRIM(x.ExceptionCode)), N''), CONCAT(N'StageExceptionCodeLookupID=', x.StageExceptionCodeLookupID))
    WHERE x.BatchID = @BatchID;

    UPDATE rr
    SET RejectionReason = se.RejectionReason
    FROM stg.Route_Distance_Reference_Raw AS rr
    LEFT JOIN @StageErrors AS se
        ON se.SourceTableName = N'stg.Route_Distance_Reference_Raw'
       AND se.BusinessKey = CASE
                                WHEN NULLIF(LTRIM(RTRIM(rr.RouteCode)), N'') IS NOT NULL
                                 AND NULLIF(LTRIM(RTRIM(rr.OriginLocationCode)), N'') IS NOT NULL
                                 AND NULLIF(LTRIM(RTRIM(rr.DestinationLocationCode)), N'') IS NOT NULL
                                    THEN CONCAT(rr.RouteCode, N'|', rr.OriginLocationCode, N'|', rr.DestinationLocationCode)
                                ELSE CONCAT(N'StageRouteDistanceReferenceID=', rr.StageRouteDistanceReferenceID)
                            END
    WHERE rr.BatchID = @BatchID;

    INSERT INTO audit.Stage_Row_Reject
    (
        BatchID,
        SourceTableName,
        StageRowID,
        BusinessKey,
        SourceName,
        SourceFileName,
        RejectionReason
    )
    SELECT
        c.BatchID,
        N'stg.Carrier_Raw',
        c.StageCarrierID,
        COALESCE(NULLIF(LTRIM(RTRIM(c.CarrierCode)), N''), CONCAT(N'StageCarrierID=', c.StageCarrierID)),
        c.SourceName,
        c.SourceFileName,
        COALESCE(c.RejectionReason, N'Validation failed.')
    FROM stg.Carrier_Raw AS c
    WHERE c.BatchID = @BatchID
      AND c.IsValid = 0;

    INSERT INTO audit.Stage_Row_Reject
    (
        BatchID,
        SourceTableName,
        StageRowID,
        BusinessKey,
        SourceName,
        SourceFileName,
        RejectionReason
    )
    SELECT
        l.BatchID,
        N'stg.Location_Raw',
        l.StageLocationID,
        COALESCE(NULLIF(LTRIM(RTRIM(l.LocationCode)), N''), CONCAT(N'StageLocationID=', l.StageLocationID)),
        l.SourceName,
        l.SourceFileName,
        COALESCE(l.RejectionReason, N'Validation failed.')
    FROM stg.Location_Raw AS l
    WHERE l.BatchID = @BatchID
      AND l.IsValid = 0;

    INSERT INTO audit.Stage_Row_Reject
    (
        BatchID,
        SourceTableName,
        StageRowID,
        BusinessKey,
        SourceName,
        SourceFileName,
        RejectionReason
    )
    SELECT
        r.BatchID,
        N'stg.Route_Raw',
        r.StageRouteID,
        COALESCE(NULLIF(LTRIM(RTRIM(r.RouteCode)), N''), CONCAT(N'StageRouteID=', r.StageRouteID)),
        r.SourceName,
        r.SourceFileName,
        COALESCE(r.RejectionReason, N'Validation failed.')
    FROM stg.Route_Raw AS r
    WHERE r.BatchID = @BatchID
      AND r.IsValid = 0;
    INSERT INTO audit.Stage_Row_Reject
    (
        BatchID,
        SourceTableName,
        StageRowID,
        BusinessKey,
        SourceName,
        SourceFileName,
        RejectionReason
    )
    SELECT
        s.BatchID,
        N'stg.Shipment_Raw',
        s.StageShipmentID,
        COALESCE(NULLIF(LTRIM(RTRIM(s.ShipmentNumber)), N''), CONCAT(N'StageShipmentID=', s.StageShipmentID)),
        s.SourceName,
        s.SourceFileName,
        COALESCE(s.RejectionReason, N'Validation failed.')
    FROM stg.Shipment_Raw AS s
    WHERE s.BatchID = @BatchID
      AND s.IsValid = 0;

    INSERT INTO audit.Stage_Row_Reject
    (
        BatchID,
        SourceTableName,
        StageRowID,
        BusinessKey,
        SourceName,
        SourceFileName,
        RejectionReason
    )
    SELECT
        h.BatchID,
        N'stg.Shipment_Status_History_Raw',
        h.StageShipmentStatusHistoryID,
        CASE
            WHEN NULLIF(LTRIM(RTRIM(h.ShipmentNumber)), N'') IS NOT NULL
             AND h.EventSequenceNumber IS NOT NULL
                THEN CONCAT(h.ShipmentNumber, N'|SEQ=', CONVERT(nvarchar(20), h.EventSequenceNumber))
            ELSE CONCAT(N'StageShipmentStatusHistoryID=', h.StageShipmentStatusHistoryID)
        END,
        h.SourceName,
        h.SourceFileName,
        COALESCE(h.RejectionReason, N'Validation failed.')
    FROM stg.Shipment_Status_History_Raw AS h
    WHERE h.BatchID = @BatchID
      AND h.IsValid = 0;

    INSERT INTO audit.Stage_Row_Reject
    (
        BatchID,
        SourceTableName,
        StageRowID,
        BusinessKey,
        SourceName,
        SourceFileName,
        RejectionReason
    )
    SELECT
        e.BatchID,
        N'stg.Delivery_Exception_Raw',
        e.StageDeliveryExceptionID,
        CASE
            WHEN NULLIF(LTRIM(RTRIM(e.ShipmentNumber)), N'') IS NOT NULL
             AND NULLIF(LTRIM(RTRIM(e.ExceptionCode)), N'') IS NOT NULL
             AND e.ExceptionDateTime IS NOT NULL
                THEN CONCAT(e.ShipmentNumber, N'|EXC=', e.ExceptionCode, N'|DT=', CONVERT(nvarchar(19), e.ExceptionDateTime, 120))
            ELSE CONCAT(N'StageDeliveryExceptionID=', e.StageDeliveryExceptionID)
        END,
        e.SourceName,
        e.SourceFileName,
        COALESCE(e.RejectionReason, N'Validation failed.')
    FROM stg.Delivery_Exception_Raw AS e
    WHERE e.BatchID = @BatchID
      AND e.IsValid = 0;

    INSERT INTO audit.Stage_Row_Reject
    (
        BatchID,
        SourceTableName,
        StageRowID,
        BusinessKey,
        SourceName,
        SourceFileName,
        RejectionReason
    )
    SELECT
        x.BatchID,
        N'stg.Exception_Code_Lookup_Raw',
        x.StageExceptionCodeLookupID,
        COALESCE(NULLIF(LTRIM(RTRIM(x.ExceptionCode)), N''), CONCAT(N'StageExceptionCodeLookupID=', x.StageExceptionCodeLookupID)),
        x.SourceName,
        x.SourceFileName,
        COALESCE(x.RejectionReason, N'Validation failed.')
    FROM stg.Exception_Code_Lookup_Raw AS x
    WHERE x.BatchID = @BatchID
      AND x.IsValid = 0;

    INSERT INTO audit.Stage_Row_Reject
    (
        BatchID,
        SourceTableName,
        StageRowID,
        BusinessKey,
        SourceName,
        SourceFileName,
        RejectionReason
    )
    SELECT
        rr.BatchID,
        N'stg.Route_Distance_Reference_Raw',
        rr.StageRouteDistanceReferenceID,
        CASE
            WHEN NULLIF(LTRIM(RTRIM(rr.RouteCode)), N'') IS NOT NULL
             AND NULLIF(LTRIM(RTRIM(rr.OriginLocationCode)), N'') IS NOT NULL
             AND NULLIF(LTRIM(RTRIM(rr.DestinationLocationCode)), N'') IS NOT NULL
                THEN CONCAT(rr.RouteCode, N'|', rr.OriginLocationCode, N'|', rr.DestinationLocationCode)
            ELSE CONCAT(N'StageRouteDistanceReferenceID=', rr.StageRouteDistanceReferenceID)
        END,
        rr.SourceName,
        rr.SourceFileName,
        COALESCE(rr.RejectionReason, N'Validation failed.')
    FROM stg.Route_Distance_Reference_Raw AS rr
    WHERE rr.BatchID = @BatchID
      AND rr.IsValid = 0;
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Validate_Stage_Data
    @BatchID int
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AuditID bigint;
    DECLARE @RowsRejected int = 0;

    BEGIN TRY
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
            N'Validate Stage Data',
            N'stg.*',
            'STARTED'
        );

        SET @AuditID = SCOPE_IDENTITY();

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

        UPDATE stg.Carrier_Raw
        SET IsValid = 1,
            ValidationStatus = 'VALID',
            RejectionReason = NULL
        WHERE BatchID = @BatchID;

        UPDATE stg.Location_Raw
        SET IsValid = 1,
            ValidationStatus = 'VALID',
            RejectionReason = NULL
        WHERE BatchID = @BatchID;

        UPDATE stg.Route_Raw
        SET IsValid = 1,
            ValidationStatus = 'VALID',
            RejectionReason = NULL
        WHERE BatchID = @BatchID;

        UPDATE stg.Shipment_Raw
        SET IsValid = 1,
            ValidationStatus = 'VALID',
            RejectionReason = NULL
        WHERE BatchID = @BatchID;

        UPDATE stg.Shipment_Status_History_Raw
        SET IsValid = 1,
            ValidationStatus = 'VALID',
            RejectionReason = NULL
        WHERE BatchID = @BatchID;

        UPDATE stg.Delivery_Exception_Raw
        SET IsValid = 1,
            ValidationStatus = 'VALID',
            RejectionReason = NULL
        WHERE BatchID = @BatchID;
        UPDATE stg.Exception_Code_Lookup_Raw
        SET IsValid = 1,
            ValidationStatus = 'VALID',
            RejectionReason = NULL
        WHERE BatchID = @BatchID;

        UPDATE stg.Route_Distance_Reference_Raw
        SET IsValid = 1,
            ValidationStatus = 'VALID',
            RejectionReason = NULL
        WHERE BatchID = @BatchID;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Carrier_Raw',
            COALESCE(NULLIF(LTRIM(RTRIM(c.CarrierCode)), N''), CONCAT(N'StageCarrierID=', c.StageCarrierID)),
            N'CarrierCode',
            N'RequiredCarrierCode',
            N'Carrier code is required.'
        FROM stg.Carrier_Raw AS c
        WHERE c.BatchID = @BatchID
          AND NULLIF(LTRIM(RTRIM(c.CarrierCode)), N'') IS NULL;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Carrier_Raw',
            COALESCE(NULLIF(LTRIM(RTRIM(c.CarrierCode)), N''), CONCAT(N'StageCarrierID=', c.StageCarrierID)),
            N'CarrierName',
            N'RequiredCarrierName',
            N'Carrier name is required.'
        FROM stg.Carrier_Raw AS c
        WHERE c.BatchID = @BatchID
          AND NULLIF(LTRIM(RTRIM(c.CarrierName)), N'') IS NULL;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Location_Raw',
            COALESCE(NULLIF(LTRIM(RTRIM(l.LocationCode)), N''), CONCAT(N'StageLocationID=', l.StageLocationID)),
            N'LocationCode',
            N'RequiredLocationCode',
            N'Location code is required.'
        FROM stg.Location_Raw AS l
        WHERE l.BatchID = @BatchID
          AND NULLIF(LTRIM(RTRIM(l.LocationCode)), N'') IS NULL;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Location_Raw',
            COALESCE(NULLIF(LTRIM(RTRIM(l.LocationCode)), N''), CONCAT(N'StageLocationID=', l.StageLocationID)),
            N'LocationName',
            N'RequiredLocationName',
            N'Location name is required.'
        FROM stg.Location_Raw AS l
        WHERE l.BatchID = @BatchID
          AND NULLIF(LTRIM(RTRIM(l.LocationName)), N'') IS NULL;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Route_Raw',
            COALESCE(NULLIF(LTRIM(RTRIM(r.RouteCode)), N''), CONCAT(N'StageRouteID=', r.StageRouteID)),
            N'RouteCode',
            N'RequiredRouteCode',
            N'Route code is required.'
        FROM stg.Route_Raw AS r
        WHERE r.BatchID = @BatchID
          AND NULLIF(LTRIM(RTRIM(r.RouteCode)), N'') IS NULL;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Route_Raw',
            COALESCE(NULLIF(LTRIM(RTRIM(r.RouteCode)), N''), CONCAT(N'StageRouteID=', r.StageRouteID)),
            N'OriginLocationCode',
            N'ValidOriginLocation',
            N'Route origin location is missing or invalid.'
        FROM stg.Route_Raw AS r
        LEFT JOIN
        (
            SELECT DISTINCT LocationCode
            FROM stg.Location_Raw
            WHERE BatchID = @BatchID
            UNION
            SELECT LocationCode
            FROM dw.DimLocation
        ) AS l
            ON r.OriginLocationCode = l.LocationCode
        WHERE r.BatchID = @BatchID
          AND (NULLIF(LTRIM(RTRIM(r.OriginLocationCode)), N'') IS NULL OR l.LocationCode IS NULL);

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Route_Raw',
            COALESCE(NULLIF(LTRIM(RTRIM(r.RouteCode)), N''), CONCAT(N'StageRouteID=', r.StageRouteID)),
            N'DestinationLocationCode',
            N'ValidDestinationLocation',
            N'Route destination location is missing or invalid.'
        FROM stg.Route_Raw AS r
        LEFT JOIN
        (
            SELECT DISTINCT LocationCode
            FROM stg.Location_Raw
            WHERE BatchID = @BatchID
            UNION
            SELECT LocationCode
            FROM dw.DimLocation
        ) AS l
            ON r.DestinationLocationCode = l.LocationCode
        WHERE r.BatchID = @BatchID
          AND (NULLIF(LTRIM(RTRIM(r.DestinationLocationCode)), N'') IS NULL OR l.LocationCode IS NULL);

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Route_Raw',
            COALESCE(NULLIF(LTRIM(RTRIM(r.RouteCode)), N''), CONCAT(N'StageRouteID=', r.StageRouteID)),
            N'PlannedDistanceMiles',
            N'PositivePlannedDistanceMiles',
            N'Planned distance must be greater than zero.'
        FROM stg.Route_Raw AS r
        WHERE r.BatchID = @BatchID
          AND ISNULL(r.PlannedDistanceMiles, 0) <= 0;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Route_Raw',
            COALESCE(NULLIF(LTRIM(RTRIM(r.RouteCode)), N''), CONCAT(N'StageRouteID=', r.StageRouteID)),
            N'PlannedTransitHours',
            N'PositivePlannedTransitHours',
            N'Planned transit hours must be greater than zero.'
        FROM stg.Route_Raw AS r
        WHERE r.BatchID = @BatchID
          AND ISNULL(r.PlannedTransitHours, 0) <= 0;
        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Shipment_Raw',
            COALESCE(NULLIF(LTRIM(RTRIM(s.ShipmentNumber)), N''), CONCAT(N'StageShipmentID=', s.StageShipmentID)),
            N'ShipmentNumber',
            N'RequiredShipmentNumber',
            N'Shipment number is required.'
        FROM stg.Shipment_Raw AS s
        WHERE s.BatchID = @BatchID
          AND NULLIF(LTRIM(RTRIM(s.ShipmentNumber)), N'') IS NULL;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Shipment_Raw',
            COALESCE(NULLIF(LTRIM(RTRIM(s.ShipmentNumber)), N''), CONCAT(N'StageShipmentID=', s.StageShipmentID)),
            N'CarrierCode',
            N'ValidCarrierCode',
            N'Shipment carrier is missing or invalid.'
        FROM stg.Shipment_Raw AS s
        LEFT JOIN
        (
            SELECT DISTINCT CarrierCode
            FROM stg.Carrier_Raw
            WHERE BatchID = @BatchID
            UNION
            SELECT CarrierCode
            FROM dw.DimCarrier
        ) AS c
            ON s.CarrierCode = c.CarrierCode
        WHERE s.BatchID = @BatchID
          AND (NULLIF(LTRIM(RTRIM(s.CarrierCode)), N'') IS NULL OR c.CarrierCode IS NULL);

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Shipment_Raw',
            COALESCE(NULLIF(LTRIM(RTRIM(s.ShipmentNumber)), N''), CONCAT(N'StageShipmentID=', s.StageShipmentID)),
            N'RouteCode',
            N'ValidRouteCode',
            N'Shipment route is missing or invalid.'
        FROM stg.Shipment_Raw AS s
        LEFT JOIN
        (
            SELECT DISTINCT RouteCode
            FROM stg.Route_Raw
            WHERE BatchID = @BatchID
            UNION
            SELECT RouteCode
            FROM dw.DimRoute
        ) AS r
            ON s.RouteCode = r.RouteCode
        WHERE s.BatchID = @BatchID
          AND (NULLIF(LTRIM(RTRIM(s.RouteCode)), N'') IS NULL OR r.RouteCode IS NULL);

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Shipment_Raw',
            COALESCE(NULLIF(LTRIM(RTRIM(s.ShipmentNumber)), N''), CONCAT(N'StageShipmentID=', s.StageShipmentID)),
            N'OriginLocationCode',
            N'ValidOriginLocation',
            N'Shipment origin location is missing or invalid.'
        FROM stg.Shipment_Raw AS s
        LEFT JOIN
        (
            SELECT DISTINCT LocationCode
            FROM stg.Location_Raw
            WHERE BatchID = @BatchID
            UNION
            SELECT LocationCode
            FROM dw.DimLocation
        ) AS l
            ON s.OriginLocationCode = l.LocationCode
        WHERE s.BatchID = @BatchID
          AND (NULLIF(LTRIM(RTRIM(s.OriginLocationCode)), N'') IS NULL OR l.LocationCode IS NULL);

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Shipment_Raw',
            COALESCE(NULLIF(LTRIM(RTRIM(s.ShipmentNumber)), N''), CONCAT(N'StageShipmentID=', s.StageShipmentID)),
            N'DestinationLocationCode',
            N'ValidDestinationLocation',
            N'Shipment destination location is missing or invalid.'
        FROM stg.Shipment_Raw AS s
        LEFT JOIN
        (
            SELECT DISTINCT LocationCode
            FROM stg.Location_Raw
            WHERE BatchID = @BatchID
            UNION
            SELECT LocationCode
            FROM dw.DimLocation
        ) AS l
            ON s.DestinationLocationCode = l.LocationCode
        WHERE s.BatchID = @BatchID
          AND (NULLIF(LTRIM(RTRIM(s.DestinationLocationCode)), N'') IS NULL OR l.LocationCode IS NULL);

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Shipment_Raw',
            COALESCE(NULLIF(LTRIM(RTRIM(s.ShipmentNumber)), N''), CONCAT(N'StageShipmentID=', s.StageShipmentID)),
            N'ShipmentCreateDate',
            N'RequiredShipmentCreateDate',
            N'Shipment create date is required.'
        FROM stg.Shipment_Raw AS s
        WHERE s.BatchID = @BatchID
          AND s.ShipmentCreateDate IS NULL;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Shipment_Raw',
            COALESCE(NULLIF(LTRIM(RTRIM(s.ShipmentNumber)), N''), CONCAT(N'StageShipmentID=', s.StageShipmentID)),
            N'PlannedDeliveryDate',
            N'RequiredPlannedDeliveryDate',
            N'Planned delivery date is required.'
        FROM stg.Shipment_Raw AS s
        WHERE s.BatchID = @BatchID
          AND s.PlannedDeliveryDate IS NULL;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Shipment_Raw',
            COALESCE(NULLIF(LTRIM(RTRIM(s.ShipmentNumber)), N''), CONCAT(N'StageShipmentID=', s.StageShipmentID)),
            N'ActualDeliveryDate',
            N'ChronologicalShipmentDates',
            N'Actual delivery date cannot be earlier than actual pickup date.'
        FROM stg.Shipment_Raw AS s
        WHERE s.BatchID = @BatchID
          AND s.ActualPickupDate IS NOT NULL
          AND s.ActualDeliveryDate IS NOT NULL
          AND s.ActualDeliveryDate < s.ActualPickupDate;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Shipment_Status_History_Raw',
            CASE
                WHEN NULLIF(LTRIM(RTRIM(h.ShipmentNumber)), N'') IS NOT NULL
                 AND h.EventSequenceNumber IS NOT NULL
                    THEN CONCAT(h.ShipmentNumber, N'|SEQ=', CONVERT(nvarchar(20), h.EventSequenceNumber))
                ELSE CONCAT(N'StageShipmentStatusHistoryID=', h.StageShipmentStatusHistoryID)
            END,
            N'ShipmentNumber',
            N'RequiredShipmentNumber',
            N'Status history shipment number is required.'
        FROM stg.Shipment_Status_History_Raw AS h
        WHERE h.BatchID = @BatchID
          AND NULLIF(LTRIM(RTRIM(h.ShipmentNumber)), N'') IS NULL;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Shipment_Status_History_Raw',
            CASE
                WHEN NULLIF(LTRIM(RTRIM(h.ShipmentNumber)), N'') IS NOT NULL
                 AND h.EventSequenceNumber IS NOT NULL
                    THEN CONCAT(h.ShipmentNumber, N'|SEQ=', CONVERT(nvarchar(20), h.EventSequenceNumber))
                ELSE CONCAT(N'StageShipmentStatusHistoryID=', h.StageShipmentStatusHistoryID)
            END,
            N'EventSequenceNumber',
            N'RequiredEventSequenceNumber',
            N'Event sequence number is required.'
        FROM stg.Shipment_Status_History_Raw AS h
        WHERE h.BatchID = @BatchID
          AND h.EventSequenceNumber IS NULL;
        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Shipment_Status_History_Raw',
            CASE
                WHEN NULLIF(LTRIM(RTRIM(h.ShipmentNumber)), N'') IS NOT NULL
                 AND h.EventSequenceNumber IS NOT NULL
                    THEN CONCAT(h.ShipmentNumber, N'|SEQ=', CONVERT(nvarchar(20), h.EventSequenceNumber))
                ELSE CONCAT(N'StageShipmentStatusHistoryID=', h.StageShipmentStatusHistoryID)
            END,
            N'StatusCode',
            N'RequiredStatusCode',
            N'Status code is required.'
        FROM stg.Shipment_Status_History_Raw AS h
        WHERE h.BatchID = @BatchID
          AND NULLIF(LTRIM(RTRIM(h.StatusCode)), N'') IS NULL;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Shipment_Status_History_Raw',
            CASE
                WHEN NULLIF(LTRIM(RTRIM(h.ShipmentNumber)), N'') IS NOT NULL
                 AND h.EventSequenceNumber IS NOT NULL
                    THEN CONCAT(h.ShipmentNumber, N'|SEQ=', CONVERT(nvarchar(20), h.EventSequenceNumber))
                ELSE CONCAT(N'StageShipmentStatusHistoryID=', h.StageShipmentStatusHistoryID)
            END,
            N'EventDateTime',
            N'RequiredEventDateTime',
            N'Event timestamp is required.'
        FROM stg.Shipment_Status_History_Raw AS h
        WHERE h.BatchID = @BatchID
          AND h.EventDateTime IS NULL;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Shipment_Status_History_Raw',
            CASE
                WHEN NULLIF(LTRIM(RTRIM(h.ShipmentNumber)), N'') IS NOT NULL
                 AND h.EventSequenceNumber IS NOT NULL
                    THEN CONCAT(h.ShipmentNumber, N'|SEQ=', CONVERT(nvarchar(20), h.EventSequenceNumber))
                ELSE CONCAT(N'StageShipmentStatusHistoryID=', h.StageShipmentStatusHistoryID)
            END,
            N'ShipmentNumber',
            N'KnownShipmentReference',
            N'Status history does not reference a known shipment.'
        FROM stg.Shipment_Status_History_Raw AS h
        LEFT JOIN
        (
            SELECT DISTINCT ShipmentNumber
            FROM stg.Shipment_Raw
            WHERE BatchID = @BatchID
            UNION
            SELECT ShipmentNumber
            FROM dw.FactShipment
        ) AS s
            ON h.ShipmentNumber = s.ShipmentNumber
        WHERE h.BatchID = @BatchID
          AND NULLIF(LTRIM(RTRIM(h.ShipmentNumber)), N'') IS NOT NULL
          AND s.ShipmentNumber IS NULL;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Shipment_Status_History_Raw',
            CASE
                WHEN NULLIF(LTRIM(RTRIM(h.ShipmentNumber)), N'') IS NOT NULL
                 AND h.EventSequenceNumber IS NOT NULL
                    THEN CONCAT(h.ShipmentNumber, N'|SEQ=', CONVERT(nvarchar(20), h.EventSequenceNumber))
                ELSE CONCAT(N'StageShipmentStatusHistoryID=', h.StageShipmentStatusHistoryID)
            END,
            N'LocationCode',
            N'ValidLocationCode',
            N'Status history location is invalid.'
        FROM stg.Shipment_Status_History_Raw AS h
        LEFT JOIN
        (
            SELECT DISTINCT LocationCode
            FROM stg.Location_Raw
            WHERE BatchID = @BatchID
            UNION
            SELECT LocationCode
            FROM dw.DimLocation
        ) AS l
            ON h.LocationCode = l.LocationCode
        WHERE h.BatchID = @BatchID
          AND NULLIF(LTRIM(RTRIM(h.LocationCode)), N'') IS NOT NULL
          AND l.LocationCode IS NULL;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Delivery_Exception_Raw',
            CASE
                WHEN NULLIF(LTRIM(RTRIM(e.ShipmentNumber)), N'') IS NOT NULL
                 AND NULLIF(LTRIM(RTRIM(e.ExceptionCode)), N'') IS NOT NULL
                 AND e.ExceptionDateTime IS NOT NULL
                    THEN CONCAT(e.ShipmentNumber, N'|EXC=', e.ExceptionCode, N'|DT=', CONVERT(nvarchar(19), e.ExceptionDateTime, 120))
                ELSE CONCAT(N'StageDeliveryExceptionID=', e.StageDeliveryExceptionID)
            END,
            N'ExceptionCode',
            N'RequiredExceptionCode',
            N'Exception code is required.'
        FROM stg.Delivery_Exception_Raw AS e
        WHERE e.BatchID = @BatchID
          AND NULLIF(LTRIM(RTRIM(e.ExceptionCode)), N'') IS NULL;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Delivery_Exception_Raw',
            CASE
                WHEN NULLIF(LTRIM(RTRIM(e.ShipmentNumber)), N'') IS NOT NULL
                 AND NULLIF(LTRIM(RTRIM(e.ExceptionCode)), N'') IS NOT NULL
                 AND e.ExceptionDateTime IS NOT NULL
                    THEN CONCAT(e.ShipmentNumber, N'|EXC=', e.ExceptionCode, N'|DT=', CONVERT(nvarchar(19), e.ExceptionDateTime, 120))
                ELSE CONCAT(N'StageDeliveryExceptionID=', e.StageDeliveryExceptionID)
            END,
            N'ExceptionDateTime',
            N'RequiredExceptionDateTime',
            N'Exception timestamp is required.'
        FROM stg.Delivery_Exception_Raw AS e
        WHERE e.BatchID = @BatchID
          AND e.ExceptionDateTime IS NULL;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Delivery_Exception_Raw',
            CASE
                WHEN NULLIF(LTRIM(RTRIM(e.ShipmentNumber)), N'') IS NOT NULL
                 AND NULLIF(LTRIM(RTRIM(e.ExceptionCode)), N'') IS NOT NULL
                 AND e.ExceptionDateTime IS NOT NULL
                    THEN CONCAT(e.ShipmentNumber, N'|EXC=', e.ExceptionCode, N'|DT=', CONVERT(nvarchar(19), e.ExceptionDateTime, 120))
                ELSE CONCAT(N'StageDeliveryExceptionID=', e.StageDeliveryExceptionID)
            END,
            N'ShipmentNumber',
            N'KnownShipmentReference',
            N'Delivery exception does not reference a known shipment.'
        FROM stg.Delivery_Exception_Raw AS e
        LEFT JOIN
        (
            SELECT DISTINCT ShipmentNumber
            FROM stg.Shipment_Raw
            WHERE BatchID = @BatchID
            UNION
            SELECT ShipmentNumber
            FROM dw.FactShipment
        ) AS s
            ON e.ShipmentNumber = s.ShipmentNumber
        WHERE e.BatchID = @BatchID
          AND (NULLIF(LTRIM(RTRIM(e.ShipmentNumber)), N'') IS NULL OR s.ShipmentNumber IS NULL);

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Exception_Code_Lookup_Raw',
            COALESCE(NULLIF(LTRIM(RTRIM(x.ExceptionCode)), N''), CONCAT(N'StageExceptionCodeLookupID=', x.StageExceptionCodeLookupID)),
            N'ExceptionCode',
            N'RequiredExceptionCode',
            N'Lookup exception code is required.'
        FROM stg.Exception_Code_Lookup_Raw AS x
        WHERE x.BatchID = @BatchID
          AND NULLIF(LTRIM(RTRIM(x.ExceptionCode)), N'') IS NULL;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Exception_Code_Lookup_Raw',
            COALESCE(NULLIF(LTRIM(RTRIM(x.ExceptionCode)), N''), CONCAT(N'StageExceptionCodeLookupID=', x.StageExceptionCodeLookupID)),
            N'ExceptionDescription',
            N'RequiredExceptionDescription',
            N'Lookup exception description is required.'
        FROM stg.Exception_Code_Lookup_Raw AS x
        WHERE x.BatchID = @BatchID
          AND NULLIF(LTRIM(RTRIM(x.ExceptionDescription)), N'') IS NULL;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Exception_Code_Lookup_Raw',
            COALESCE(NULLIF(LTRIM(RTRIM(x.ExceptionCode)), N''), CONCAT(N'StageExceptionCodeLookupID=', x.StageExceptionCodeLookupID)),
            N'TypicalDelayMinutes',
            N'NonNegativeTypicalDelayMinutes',
            N'Lookup typical delay minutes cannot be negative.'
        FROM stg.Exception_Code_Lookup_Raw AS x
        WHERE x.BatchID = @BatchID
          AND ISNULL(x.TypicalDelayMinutes, 0) < 0;
        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Route_Distance_Reference_Raw',
            CASE
                WHEN NULLIF(LTRIM(RTRIM(rr.RouteCode)), N'') IS NOT NULL
                 AND NULLIF(LTRIM(RTRIM(rr.OriginLocationCode)), N'') IS NOT NULL
                 AND NULLIF(LTRIM(RTRIM(rr.DestinationLocationCode)), N'') IS NOT NULL
                    THEN CONCAT(rr.RouteCode, N'|', rr.OriginLocationCode, N'|', rr.DestinationLocationCode)
                ELSE CONCAT(N'StageRouteDistanceReferenceID=', rr.StageRouteDistanceReferenceID)
            END,
            N'RouteCode',
            N'RequiredRouteCode',
            N'Route distance reference route code is required.'
        FROM stg.Route_Distance_Reference_Raw AS rr
        WHERE rr.BatchID = @BatchID
          AND NULLIF(LTRIM(RTRIM(rr.RouteCode)), N'') IS NULL;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Route_Distance_Reference_Raw',
            CASE
                WHEN NULLIF(LTRIM(RTRIM(rr.RouteCode)), N'') IS NOT NULL
                 AND NULLIF(LTRIM(RTRIM(rr.OriginLocationCode)), N'') IS NOT NULL
                 AND NULLIF(LTRIM(RTRIM(rr.DestinationLocationCode)), N'') IS NOT NULL
                    THEN CONCAT(rr.RouteCode, N'|', rr.OriginLocationCode, N'|', rr.DestinationLocationCode)
                ELSE CONCAT(N'StageRouteDistanceReferenceID=', rr.StageRouteDistanceReferenceID)
            END,
            N'RouteCode',
            N'KnownRouteReference',
            N'Route distance reference does not map to a known route.'
        FROM stg.Route_Distance_Reference_Raw AS rr
        LEFT JOIN
        (
            SELECT DISTINCT RouteCode
            FROM stg.Route_Raw
            WHERE BatchID = @BatchID
            UNION
            SELECT RouteCode
            FROM dw.DimRoute
        ) AS r
            ON rr.RouteCode = r.RouteCode
        WHERE rr.BatchID = @BatchID
          AND NULLIF(LTRIM(RTRIM(rr.RouteCode)), N'') IS NOT NULL
          AND r.RouteCode IS NULL;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Route_Distance_Reference_Raw',
            CASE
                WHEN NULLIF(LTRIM(RTRIM(rr.RouteCode)), N'') IS NOT NULL
                 AND NULLIF(LTRIM(RTRIM(rr.OriginLocationCode)), N'') IS NOT NULL
                 AND NULLIF(LTRIM(RTRIM(rr.DestinationLocationCode)), N'') IS NOT NULL
                    THEN CONCAT(rr.RouteCode, N'|', rr.OriginLocationCode, N'|', rr.DestinationLocationCode)
                ELSE CONCAT(N'StageRouteDistanceReferenceID=', rr.StageRouteDistanceReferenceID)
            END,
            N'ReferenceDistanceMiles',
            N'PositiveReferenceDistanceMiles',
            N'Reference distance must be greater than zero.'
        FROM stg.Route_Distance_Reference_Raw AS rr
        WHERE rr.BatchID = @BatchID
          AND ISNULL(rr.ReferenceDistanceMiles, 0) <= 0;

        INSERT INTO audit.Validation_Error
        (
            BatchID,
            SourceTableName,
            BusinessKey,
            ColumnName,
            RuleName,
            ErrorMessage
        )
        SELECT
            @BatchID,
            N'stg.Route_Distance_Reference_Raw',
            CASE
                WHEN NULLIF(LTRIM(RTRIM(rr.RouteCode)), N'') IS NOT NULL
                 AND NULLIF(LTRIM(RTRIM(rr.OriginLocationCode)), N'') IS NOT NULL
                 AND NULLIF(LTRIM(RTRIM(rr.DestinationLocationCode)), N'') IS NOT NULL
                    THEN CONCAT(rr.RouteCode, N'|', rr.OriginLocationCode, N'|', rr.DestinationLocationCode)
                ELSE CONCAT(N'StageRouteDistanceReferenceID=', rr.StageRouteDistanceReferenceID)
            END,
            N'ReferenceTransitHours',
            N'PositiveReferenceTransitHours',
            N'Reference transit hours must be greater than zero.'
        FROM stg.Route_Distance_Reference_Raw AS rr
        WHERE rr.BatchID = @BatchID
          AND ISNULL(rr.ReferenceTransitHours, 0) <= 0;

        UPDATE c
        SET IsValid = 0,
            ValidationStatus = 'INVALID'
        FROM stg.Carrier_Raw AS c
        WHERE c.BatchID = @BatchID
          AND EXISTS
          (
              SELECT 1
              FROM audit.Validation_Error AS v
              WHERE v.BatchID = @BatchID
                AND v.SourceTableName = N'stg.Carrier_Raw'
                AND v.BusinessKey = COALESCE(NULLIF(LTRIM(RTRIM(c.CarrierCode)), N''), CONCAT(N'StageCarrierID=', c.StageCarrierID))
          );

        UPDATE l
        SET IsValid = 0,
            ValidationStatus = 'INVALID'
        FROM stg.Location_Raw AS l
        WHERE l.BatchID = @BatchID
          AND EXISTS
          (
              SELECT 1
              FROM audit.Validation_Error AS v
              WHERE v.BatchID = @BatchID
                AND v.SourceTableName = N'stg.Location_Raw'
                AND v.BusinessKey = COALESCE(NULLIF(LTRIM(RTRIM(l.LocationCode)), N''), CONCAT(N'StageLocationID=', l.StageLocationID))
          );

        UPDATE r
        SET IsValid = 0,
            ValidationStatus = 'INVALID'
        FROM stg.Route_Raw AS r
        WHERE r.BatchID = @BatchID
          AND EXISTS
          (
              SELECT 1
              FROM audit.Validation_Error AS v
              WHERE v.BatchID = @BatchID
                AND v.SourceTableName = N'stg.Route_Raw'
                AND v.BusinessKey = COALESCE(NULLIF(LTRIM(RTRIM(r.RouteCode)), N''), CONCAT(N'StageRouteID=', r.StageRouteID))
          );

        UPDATE s
        SET IsValid = 0,
            ValidationStatus = 'INVALID'
        FROM stg.Shipment_Raw AS s
        WHERE s.BatchID = @BatchID
          AND EXISTS
          (
              SELECT 1
              FROM audit.Validation_Error AS v
              WHERE v.BatchID = @BatchID
                AND v.SourceTableName = N'stg.Shipment_Raw'
                AND v.BusinessKey = COALESCE(NULLIF(LTRIM(RTRIM(s.ShipmentNumber)), N''), CONCAT(N'StageShipmentID=', s.StageShipmentID))
          );

        UPDATE h
        SET IsValid = 0,
            ValidationStatus = 'INVALID'
        FROM stg.Shipment_Status_History_Raw AS h
        WHERE h.BatchID = @BatchID
          AND EXISTS
          (
              SELECT 1
              FROM audit.Validation_Error AS v
              WHERE v.BatchID = @BatchID
                AND v.SourceTableName = N'stg.Shipment_Status_History_Raw'
                AND v.BusinessKey = CASE
                                        WHEN NULLIF(LTRIM(RTRIM(h.ShipmentNumber)), N'') IS NOT NULL
                                         AND h.EventSequenceNumber IS NOT NULL
                                            THEN CONCAT(h.ShipmentNumber, N'|SEQ=', CONVERT(nvarchar(20), h.EventSequenceNumber))
                                        ELSE CONCAT(N'StageShipmentStatusHistoryID=', h.StageShipmentStatusHistoryID)
                                    END
          );

        UPDATE e
        SET IsValid = 0,
            ValidationStatus = 'INVALID'
        FROM stg.Delivery_Exception_Raw AS e
        WHERE e.BatchID = @BatchID
          AND EXISTS
          (
              SELECT 1
              FROM audit.Validation_Error AS v
              WHERE v.BatchID = @BatchID
                AND v.SourceTableName = N'stg.Delivery_Exception_Raw'
                AND v.BusinessKey = CASE
                                        WHEN NULLIF(LTRIM(RTRIM(e.ShipmentNumber)), N'') IS NOT NULL
                                         AND NULLIF(LTRIM(RTRIM(e.ExceptionCode)), N'') IS NOT NULL
                                         AND e.ExceptionDateTime IS NOT NULL
                                            THEN CONCAT(e.ShipmentNumber, N'|EXC=', e.ExceptionCode, N'|DT=', CONVERT(nvarchar(19), e.ExceptionDateTime, 120))
                                        ELSE CONCAT(N'StageDeliveryExceptionID=', e.StageDeliveryExceptionID)
                                    END
          );

        UPDATE x
        SET IsValid = 0,
            ValidationStatus = 'INVALID'
        FROM stg.Exception_Code_Lookup_Raw AS x
        WHERE x.BatchID = @BatchID
          AND EXISTS
          (
              SELECT 1
              FROM audit.Validation_Error AS v
              WHERE v.BatchID = @BatchID
                AND v.SourceTableName = N'stg.Exception_Code_Lookup_Raw'
                AND v.BusinessKey = COALESCE(NULLIF(LTRIM(RTRIM(x.ExceptionCode)), N''), CONCAT(N'StageExceptionCodeLookupID=', x.StageExceptionCodeLookupID))
          );

        UPDATE rr
        SET IsValid = 0,
            ValidationStatus = 'INVALID'
        FROM stg.Route_Distance_Reference_Raw AS rr
        WHERE rr.BatchID = @BatchID
          AND EXISTS
          (
              SELECT 1
              FROM audit.Validation_Error AS v
              WHERE v.BatchID = @BatchID
                AND v.SourceTableName = N'stg.Route_Distance_Reference_Raw'
                AND v.BusinessKey = CASE
                                        WHEN NULLIF(LTRIM(RTRIM(rr.RouteCode)), N'') IS NOT NULL
                                         AND NULLIF(LTRIM(RTRIM(rr.OriginLocationCode)), N'') IS NOT NULL
                                         AND NULLIF(LTRIM(RTRIM(rr.DestinationLocationCode)), N'') IS NOT NULL
                                            THEN CONCAT(rr.RouteCode, N'|', rr.OriginLocationCode, N'|', rr.DestinationLocationCode)
                                        ELSE CONCAT(N'StageRouteDistanceReferenceID=', rr.StageRouteDistanceReferenceID)
                                    END
          );

        EXEC audit.usp_Sync_Stage_Rejections
            @BatchID = @BatchID;

        SELECT @RowsRejected = COUNT(*)
        FROM audit.Stage_Row_Reject
        WHERE BatchID = @BatchID;

        UPDATE audit.Load_Audit
        SET RowsRejected = @RowsRejected,
            CompletedAt = SYSUTCDATETIME(),
            Status = 'SUCCEEDED',
            Message = N'Validation completed.'
        WHERE LoadAuditID = @AuditID;
    END TRY
    BEGIN CATCH
        EXEC audit.usp_Log_Error
            @BatchID = @BatchID,
            @ProcedureName = N'etl.usp_Validate_Stage_Data',
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
