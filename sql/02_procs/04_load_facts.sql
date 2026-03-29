USE [$(DatabaseName)];
GO

CREATE OR ALTER PROCEDURE etl.usp_Load_FactShipment
    @BatchID int
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AuditID bigint;
    DECLARE @RowsInserted int = 0;
    DECLARE @RowsUpdated int = 0;
    DECLARE @MergeActions TABLE (ActionName nvarchar(10));

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
            N'Load Fact Shipment',
            N'dw.FactShipment',
            'STARTED'
        );

        SET @AuditID = SCOPE_IDENTITY();

        CREATE TABLE #ShipmentStage
        (
            ShipmentNumber nvarchar(50) NOT NULL,
            CarrierCode nvarchar(30) NULL,
            RouteCode nvarchar(30) NULL,
            OriginLocationCode nvarchar(30) NULL,
            DestinationLocationCode nvarchar(30) NULL,
            CustomerReferenceNumber nvarchar(50) NULL,
            DerivedShipmentStatusCode nvarchar(30) NOT NULL,
            ShipmentCreateDate datetime2(0) NULL,
            PlannedPickupDate datetime2(0) NULL,
            ActualPickupDate datetime2(0) NULL,
            PlannedDeliveryDate datetime2(0) NULL,
            ActualDeliveryDate datetime2(0) NULL,
            WeightLbs decimal(10, 2) NULL,
            PieceCount int NULL,
            ShipmentRevenue decimal(12, 2) NULL,
            ShipmentCost decimal(12, 2) NULL,
            PlannedDistanceMiles decimal(10, 2) NULL,
            ActualDistanceMiles decimal(10, 2) NULL,
            ServiceLevel nvarchar(30) NULL,
            SourceModifiedAt datetime2(0) NULL
        );

        INSERT INTO #ShipmentStage
        (
            ShipmentNumber,
            CarrierCode,
            RouteCode,
            OriginLocationCode,
            DestinationLocationCode,
            CustomerReferenceNumber,
            DerivedShipmentStatusCode,
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
            SourceModifiedAt
        )
        SELECT
            src.ShipmentNumber,
            src.CarrierCode,
            src.RouteCode,
            src.OriginLocationCode,
            src.DestinationLocationCode,
            src.CustomerReferenceNumber,
            src.DerivedShipmentStatusCode,
            src.ShipmentCreateDate,
            src.PlannedPickupDate,
            src.ActualPickupDate,
            src.PlannedDeliveryDate,
            src.ActualDeliveryDate,
            src.WeightLbs,
            src.PieceCount,
            src.ShipmentRevenue,
            src.ShipmentCost,
            src.PlannedDistanceMiles,
            src.ActualDistanceMiles,
            src.ServiceLevel,
            src.SourceModifiedAt
        FROM
        (
            SELECT
                UPPER(LTRIM(RTRIM(s.ShipmentNumber))) AS ShipmentNumber,
                NULLIF(UPPER(LTRIM(RTRIM(s.CarrierCode))), N'') AS CarrierCode,
                NULLIF(UPPER(REPLACE(LTRIM(RTRIM(s.RouteCode)), N' ', N'')), N'') AS RouteCode,
                NULLIF(UPPER(LTRIM(RTRIM(s.OriginLocationCode))), N'') AS OriginLocationCode,
                NULLIF(UPPER(LTRIM(RTRIM(s.DestinationLocationCode))), N'') AS DestinationLocationCode,
                NULLIF(LTRIM(RTRIM(s.CustomerReferenceNumber)), N'') AS CustomerReferenceNumber,
                CASE UPPER(LTRIM(RTRIM(s.ShipmentStatus)))
                    WHEN 'DELIVERED' THEN N'DELIVERED'
                    WHEN 'EXCEPTION' THEN N'EXCEPTION_OPEN'
                    WHEN 'IN TRANSIT' THEN N'IN_TRANSIT'
                    WHEN 'OUT FOR DELIVERY' THEN N'OUT_FOR_DELIVERY'
                    WHEN 'CREATED' THEN N'CREATED'
                    ELSE N'UNKNOWN'
                END AS DerivedShipmentStatusCode,
                s.ShipmentCreateDate,
                s.PlannedPickupDate,
                s.ActualPickupDate,
                s.PlannedDeliveryDate,
                s.ActualDeliveryDate,
                s.WeightLbs,
                s.PieceCount,
                s.ShipmentRevenue,
                s.ShipmentCost,
                s.PlannedDistanceMiles,
                s.ActualDistanceMiles,
                NULLIF(LTRIM(RTRIM(s.ServiceLevel)), N'') AS ServiceLevel,
                s.SourceModifiedAt,
                ROW_NUMBER() OVER
                (
                    PARTITION BY UPPER(LTRIM(RTRIM(s.ShipmentNumber)))
                    ORDER BY ISNULL(s.SourceModifiedAt, '1900-01-01') DESC, s.StageShipmentID DESC
                ) AS rn
            FROM stg.Shipment_Raw AS s
            WHERE s.BatchID = @BatchID
              AND s.IsValid = 1
        ) AS src
        WHERE src.rn = 1;

        CREATE TABLE #EventStage
        (
            ShipmentNumber nvarchar(50) NOT NULL,
            EventSequenceNumber int NOT NULL,
            StatusCode nvarchar(30) NOT NULL,
            StatusDescription nvarchar(200) NULL,
            EventDateTime datetime2(0) NOT NULL,
            LocationCode nvarchar(30) NULL,
            ScanType nvarchar(30) NULL,
            EventSource nvarchar(30) NULL,
            ExceptionCode nvarchar(30) NULL
        );

        INSERT INTO #EventStage
        (
            ShipmentNumber,
            EventSequenceNumber,
            StatusCode,
            StatusDescription,
            EventDateTime,
            LocationCode,
            ScanType,
            EventSource,
            ExceptionCode
        )
        SELECT
            src.ShipmentNumber,
            src.EventSequenceNumber,
            src.StatusCode,
            src.StatusDescription,
            src.EventDateTime,
            src.LocationCode,
            src.ScanType,
            src.EventSource,
            src.ExceptionCode
        FROM
        (
            SELECT
                UPPER(LTRIM(RTRIM(h.ShipmentNumber))) AS ShipmentNumber,
                h.EventSequenceNumber,
                UPPER(LTRIM(RTRIM(h.StatusCode))) AS StatusCode,
                NULLIF(LTRIM(RTRIM(h.StatusDescription)), N'') AS StatusDescription,
                h.EventDateTime,
                NULLIF(UPPER(LTRIM(RTRIM(h.LocationCode))), N'') AS LocationCode,
                NULLIF(LTRIM(RTRIM(h.ScanType)), N'') AS ScanType,
                NULLIF(LTRIM(RTRIM(h.EventSource)), N'') AS EventSource,
                NULLIF(UPPER(LTRIM(RTRIM(h.ExceptionCode))), N'') AS ExceptionCode,
                ROW_NUMBER() OVER
                (
                    PARTITION BY UPPER(LTRIM(RTRIM(h.ShipmentNumber))), h.EventSequenceNumber
                    ORDER BY h.EventDateTime DESC, h.StageShipmentStatusHistoryID DESC
                ) AS rn
            FROM stg.Shipment_Status_History_Raw AS h
            WHERE h.BatchID = @BatchID
              AND h.IsValid = 1
        ) AS src
        WHERE src.rn = 1;

        CREATE TABLE #ExceptionStage
        (
            ShipmentNumber nvarchar(50) NOT NULL,
            ExceptionCode nvarchar(30) NOT NULL,
            ExceptionDateTime datetime2(0) NOT NULL,
            DelayMinutesImpact int NULL,
            ResolvedDateTime datetime2(0) NULL
        );

        INSERT INTO #ExceptionStage
        (
            ShipmentNumber,
            ExceptionCode,
            ExceptionDateTime,
            DelayMinutesImpact,
            ResolvedDateTime
        )
        SELECT
            src.ShipmentNumber,
            src.ExceptionCode,
            src.ExceptionDateTime,
            src.DelayMinutesImpact,
            src.ResolvedDateTime
        FROM
        (
            SELECT
                UPPER(LTRIM(RTRIM(e.ShipmentNumber))) AS ShipmentNumber,
                UPPER(LTRIM(RTRIM(e.ExceptionCode))) AS ExceptionCode,
                e.ExceptionDateTime,
                e.DelayMinutesImpact,
                e.ResolvedDateTime,
                ROW_NUMBER() OVER
                (
                    PARTITION BY UPPER(LTRIM(RTRIM(e.ShipmentNumber))), UPPER(LTRIM(RTRIM(e.ExceptionCode))), e.ExceptionDateTime
                    ORDER BY e.StageDeliveryExceptionID DESC
                ) AS rn
            FROM stg.Delivery_Exception_Raw AS e
            WHERE e.BatchID = @BatchID
              AND e.IsValid = 1
        ) AS src
        WHERE src.rn = 1;

        CREATE TABLE #ImpactedShipment
        (
            ShipmentNumber nvarchar(50) NOT NULL PRIMARY KEY
        );

        INSERT INTO #ImpactedShipment
        (
            ShipmentNumber
        )
        SELECT ShipmentNumber FROM #ShipmentStage
        UNION
        SELECT ShipmentNumber FROM #EventStage
        UNION
        SELECT ShipmentNumber FROM #ExceptionStage;

        CREATE TABLE #ShipmentBase
        (
            ShipmentNumber nvarchar(50) NOT NULL,
            CarrierCode nvarchar(30) NULL,
            RouteCode nvarchar(30) NULL,
            OriginLocationCode nvarchar(30) NULL,
            DestinationLocationCode nvarchar(30) NULL,
            CustomerReferenceNumber nvarchar(50) NULL,
            DerivedShipmentStatusCode nvarchar(30) NOT NULL,
            ShipmentCreateDate datetime2(0) NULL,
            PlannedPickupDate datetime2(0) NULL,
            ActualPickupDate datetime2(0) NULL,
            PlannedDeliveryDate datetime2(0) NULL,
            ActualDeliveryDate datetime2(0) NULL,
            WeightLbs decimal(10, 2) NULL,
            PieceCount int NULL,
            ShipmentRevenue decimal(12, 2) NULL,
            ShipmentCost decimal(12, 2) NULL,
            PlannedDistanceMiles decimal(10, 2) NULL,
            ActualDistanceMiles decimal(10, 2) NULL,
            ServiceLevel nvarchar(30) NULL,
            SourceModifiedAt datetime2(0) NULL
        );

        INSERT INTO #ShipmentBase
        (
            ShipmentNumber,
            CarrierCode,
            RouteCode,
            OriginLocationCode,
            DestinationLocationCode,
            CustomerReferenceNumber,
            DerivedShipmentStatusCode,
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
            SourceModifiedAt
        )
        SELECT
            s.ShipmentNumber,
            s.CarrierCode,
            s.RouteCode,
            s.OriginLocationCode,
            s.DestinationLocationCode,
            s.CustomerReferenceNumber,
            s.DerivedShipmentStatusCode,
            s.ShipmentCreateDate,
            s.PlannedPickupDate,
            s.ActualPickupDate,
            s.PlannedDeliveryDate,
            s.ActualDeliveryDate,
            s.WeightLbs,
            s.PieceCount,
            s.ShipmentRevenue,
            s.ShipmentCost,
            s.PlannedDistanceMiles,
            s.ActualDistanceMiles,
            s.ServiceLevel,
            s.SourceModifiedAt
        FROM #ShipmentStage AS s;

        INSERT INTO #ShipmentBase
        (
            ShipmentNumber,
            CarrierCode,
            RouteCode,
            OriginLocationCode,
            DestinationLocationCode,
            CustomerReferenceNumber,
            DerivedShipmentStatusCode,
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
            SourceModifiedAt
        )
        SELECT
            fs.ShipmentNumber,
            c.CarrierCode,
            r.RouteCode,
            ol.LocationCode,
            dl.LocationCode,
            NULL AS CustomerReferenceNumber,
            fs.ShipmentStatus,
            CAST(ddo.FullDate AS datetime2(0)),
            CAST(ddpp.FullDate AS datetime2(0)),
            CAST(ddap.FullDate AS datetime2(0)),
            CAST(ddpd.FullDate AS datetime2(0)),
            CAST(ddad.FullDate AS datetime2(0)),
            fs.WeightLbs,
            fs.PieceCount,
            fs.ShipmentRevenue,
            fs.ShipmentCost,
            fs.PlannedDistanceMiles,
            fs.ActualDistanceMiles,
            fs.ServiceLevel,
            fs.SourceModifiedAt
        FROM dw.FactShipment AS fs
        INNER JOIN #ImpactedShipment AS i
            ON fs.ShipmentNumber = i.ShipmentNumber
        LEFT JOIN #ShipmentStage AS s
            ON fs.ShipmentNumber = s.ShipmentNumber
        LEFT JOIN dw.DimCarrier AS c
            ON fs.CarrierKey = c.CarrierKey
        LEFT JOIN dw.DimRoute AS r
            ON fs.RouteKey = r.RouteKey
        LEFT JOIN dw.DimLocation AS ol
            ON fs.OriginLocationKey = ol.LocationKey
        LEFT JOIN dw.DimLocation AS dl
            ON fs.DestinationLocationKey = dl.LocationKey
        LEFT JOIN dw.DimDate AS ddo
            ON fs.OrderDateKey = ddo.DateKey
        LEFT JOIN dw.DimDate AS ddpp
            ON fs.PlannedPickupDateKey = ddpp.DateKey
        LEFT JOIN dw.DimDate AS ddap
            ON fs.ActualPickupDateKey = ddap.DateKey
        LEFT JOIN dw.DimDate AS ddpd
            ON fs.PlannedDeliveryDateKey = ddpd.DateKey
        LEFT JOIN dw.DimDate AS ddad
            ON fs.ActualDeliveryDateKey = ddad.DateKey
        WHERE s.ShipmentNumber IS NULL;

        CREATE TABLE #AllEventHistory
        (
            ShipmentNumber nvarchar(50) NOT NULL,
            EventSequenceNumber int NOT NULL,
            StatusCode nvarchar(30) NOT NULL,
            EventDateTime datetime2(0) NOT NULL,
            LocationCode nvarchar(30) NULL,
            ScanType nvarchar(30) NULL,
            EventSource nvarchar(30) NULL,
            ExceptionCode nvarchar(30) NULL,
            PRIMARY KEY (ShipmentNumber, EventSequenceNumber)
        );

        INSERT INTO #AllEventHistory
        (
            ShipmentNumber,
            EventSequenceNumber,
            StatusCode,
            EventDateTime,
            LocationCode,
            ScanType,
            EventSource,
            ExceptionCode
        )
        SELECT
            e.ShipmentNumber,
            e.EventSequenceNumber,
            e.StatusCode,
            e.EventDateTime,
            e.LocationCode,
            e.ScanType,
            e.EventSource,
            e.ExceptionCode
        FROM #EventStage AS e;

        INSERT INTO #AllEventHistory
        (
            ShipmentNumber,
            EventSequenceNumber,
            StatusCode,
            EventDateTime,
            LocationCode,
            ScanType,
            EventSource,
            ExceptionCode
        )
        SELECT
            fe.ShipmentNumber,
            fe.EventSequenceNumber,
            COALESCE(ss.StatusCode, N'UNKNOWN'),
            fe.EventDateTime,
            el.LocationCode,
            fe.ScanType,
            fe.EventSource,
            de.ExceptionCode
        FROM dw.FactDeliveryEvent AS fe
        INNER JOIN #ImpactedShipment AS i
            ON fe.ShipmentNumber = i.ShipmentNumber
        LEFT JOIN #EventStage AS e
            ON fe.ShipmentNumber = e.ShipmentNumber
           AND fe.EventSequenceNumber = e.EventSequenceNumber
        LEFT JOIN dw.DimShipmentStatus AS ss
            ON fe.ShipmentStatusKey = ss.ShipmentStatusKey
        LEFT JOIN dw.DimLocation AS el
            ON fe.EventLocationKey = el.LocationKey
        LEFT JOIN dw.DimDeliveryException AS de
            ON fe.DeliveryExceptionKey = de.DeliveryExceptionKey
        WHERE e.ShipmentNumber IS NULL;

        CREATE TABLE #AllExceptionHistory
        (
            ShipmentNumber nvarchar(50) NOT NULL,
            ExceptionCode nvarchar(30) NOT NULL,
            ExceptionDateTime datetime2(0) NOT NULL,
            PRIMARY KEY (ShipmentNumber, ExceptionCode, ExceptionDateTime)
        );

        INSERT INTO #AllExceptionHistory
        (
            ShipmentNumber,
            ExceptionCode,
            ExceptionDateTime
        )
        SELECT
            e.ShipmentNumber,
            e.ExceptionCode,
            e.ExceptionDateTime
        FROM #ExceptionStage AS e;

        INSERT INTO #AllExceptionHistory
        (
            ShipmentNumber,
            ExceptionCode,
            ExceptionDateTime
        )
        SELECT
            fe.ShipmentNumber,
            COALESCE(de.ExceptionCode, N'UNKNOWN'),
            fe.ExceptionDateTime
        FROM dw.FactDeliveryException AS fe
        INNER JOIN #ImpactedShipment AS i
            ON fe.ShipmentNumber = i.ShipmentNumber
        LEFT JOIN dw.DimDeliveryException AS de
            ON fe.DeliveryExceptionKey = de.DeliveryExceptionKey
        LEFT JOIN #ExceptionStage AS e
            ON fe.ShipmentNumber = e.ShipmentNumber
           AND fe.ExceptionDateTime = e.ExceptionDateTime
           AND COALESCE(de.ExceptionCode, N'UNKNOWN') = e.ExceptionCode
        WHERE e.ShipmentNumber IS NULL;

        ;WITH ShipmentEventAggregate AS
        (
            SELECT
                e.ShipmentNumber,
                COUNT(*) AS ScanEventCount,
                MIN(CASE WHEN e.StatusCode = N'PICKED_UP' THEN e.EventDateTime END) AS FirstPickupEventDateTime,
                MIN(CASE WHEN e.StatusCode = N'DELIVERED' THEN e.EventDateTime END) AS FirstDeliveredEventDateTime
            FROM #AllEventHistory AS e
            GROUP BY e.ShipmentNumber
        ),
        LatestShipmentStatus AS
        (
            SELECT
                src.ShipmentNumber,
                src.StatusCode
            FROM
            (
                SELECT
                    e.ShipmentNumber,
                    e.StatusCode,
                    ROW_NUMBER() OVER
                    (
                        PARTITION BY e.ShipmentNumber
                        ORDER BY e.EventDateTime DESC, e.EventSequenceNumber DESC
                    ) AS rn
                FROM #AllEventHistory AS e
            ) AS src
            WHERE src.rn = 1
        ),
        ShipmentExceptionAggregate AS
        (
            SELECT
                e.ShipmentNumber,
                COUNT(*) AS ExceptionCount
            FROM #AllExceptionHistory AS e
            GROUP BY e.ShipmentNumber
        )
        MERGE dw.FactShipment AS target
        USING
        (
            SELECT
                s.ShipmentNumber,
                ISNULL(CAST(CONVERT(char(8), CAST(s.ShipmentCreateDate AS date), 112) AS int), 0) AS OrderDateKey,
                ISNULL(CAST(CONVERT(char(8), CAST(s.PlannedPickupDate AS date), 112) AS int), 0) AS PlannedPickupDateKey,
                ISNULL(CAST(CONVERT(char(8), CAST(drv.ActualPickupDateTime AS date), 112) AS int), 0) AS ActualPickupDateKey,
                ISNULL(CAST(CONVERT(char(8), CAST(s.PlannedDeliveryDate AS date), 112) AS int), 0) AS PlannedDeliveryDateKey,
                ISNULL(CAST(CONVERT(char(8), CAST(drv.ActualDeliveryDateTime AS date), 112) AS int), 0) AS ActualDeliveryDateKey,
                ISNULL(ss.ShipmentStatusKey, 0) AS ShipmentStatusKey,
                ISNULL(c.CarrierKey, 0) AS CarrierKey,
                ISNULL(r.RouteKey, 0) AS RouteKey,
                ISNULL(ol.LocationKey, 0) AS OriginLocationKey,
                ISNULL(dl.LocationKey, 0) AS DestinationLocationKey,
                drv.ShipmentStatusCode AS ShipmentStatus,
                s.ServiceLevel,
                s.WeightLbs,
                s.PieceCount,
                s.ShipmentRevenue,
                s.ShipmentCost,
                s.PlannedDistanceMiles,
                s.ActualDistanceMiles,
                CASE
                    WHEN drv.ActualPickupDateTime IS NOT NULL
                     AND drv.ActualDeliveryDateTime IS NOT NULL
                        THEN CAST(DATEDIFF(MINUTE, drv.ActualPickupDateTime, drv.ActualDeliveryDateTime) / 60.0 AS decimal(12, 2))
                    ELSE NULL
                END AS TransitHours,
                CASE
                    WHEN drv.ActualPickupDateTime IS NOT NULL
                     AND drv.ActualDeliveryDateTime IS NOT NULL
                        THEN CAST(DATEDIFF(MINUTE, drv.ActualPickupDateTime, drv.ActualDeliveryDateTime) / 1440.0 AS decimal(12, 2))
                    ELSE NULL
                END AS TransitDays,
                CASE
                    WHEN s.PlannedDeliveryDate IS NOT NULL
                     AND drv.ActualDeliveryDateTime IS NOT NULL
                     AND drv.ActualDeliveryDateTime > s.PlannedDeliveryDate
                        THEN DATEDIFF(MINUTE, s.PlannedDeliveryDate, drv.ActualDeliveryDateTime)
                    WHEN s.PlannedDeliveryDate IS NOT NULL
                     AND drv.ActualDeliveryDateTime IS NOT NULL
                        THEN 0
                    ELSE NULL
                END AS DeliveryDelayMinutes,
                CASE
                    WHEN s.PlannedDeliveryDate IS NOT NULL
                     AND drv.ActualDeliveryDateTime IS NOT NULL
                     AND drv.ActualDeliveryDateTime <= s.PlannedDeliveryDate
                        THEN 1
                    ELSE 0
                END AS OnTimeDeliveryFlag,
                CASE
                    WHEN s.PlannedDeliveryDate IS NOT NULL
                     AND drv.ActualDeliveryDateTime IS NOT NULL
                     AND drv.ActualDeliveryDateTime > s.PlannedDeliveryDate
                        THEN 1
                    ELSE 0
                END AS LateDeliveryFlag,
                1 AS ShipmentCount,
                ISNULL(sea.ScanEventCount, 0) AS ScanEventCount,
                ISNULL(exa.ExceptionCount, 0) AS ExceptionCount,
                CASE
                    WHEN ISNULL(exa.ExceptionCount, 0) > 0
                      OR ISNULL(ss.IsExceptionStatus, 0) = 1
                        THEN 1
                    ELSE 0
                END AS ExceptionShipmentFlag,
                s.SourceModifiedAt
            FROM #ShipmentBase AS s
            LEFT JOIN ShipmentEventAggregate AS sea
                ON s.ShipmentNumber = sea.ShipmentNumber
            LEFT JOIN LatestShipmentStatus AS lss
                ON s.ShipmentNumber = lss.ShipmentNumber
            LEFT JOIN ShipmentExceptionAggregate AS exa
                ON s.ShipmentNumber = exa.ShipmentNumber
            OUTER APPLY
            (
                SELECT
                    COALESCE(lss.StatusCode, s.DerivedShipmentStatusCode, N'UNKNOWN') AS ShipmentStatusCode,
                    COALESCE(s.ActualPickupDate, sea.FirstPickupEventDateTime) AS ActualPickupDateTime,
                    COALESCE(s.ActualDeliveryDate, sea.FirstDeliveredEventDateTime) AS ActualDeliveryDateTime
            ) AS drv
            LEFT JOIN dw.DimShipmentStatus AS ss
                ON drv.ShipmentStatusCode = ss.StatusCode
            LEFT JOIN dw.DimCarrier AS c
                ON s.CarrierCode = c.CarrierCode
            LEFT JOIN dw.DimRoute AS r
                ON s.RouteCode = r.RouteCode
            LEFT JOIN dw.DimLocation AS ol
                ON s.OriginLocationCode = ol.LocationCode
            LEFT JOIN dw.DimLocation AS dl
                ON s.DestinationLocationCode = dl.LocationCode
        ) AS source
            ON target.ShipmentNumber = source.ShipmentNumber
        WHEN MATCHED AND EXISTS
        (
            SELECT
                target.OrderDateKey,
                target.PlannedPickupDateKey,
                target.ActualPickupDateKey,
                target.PlannedDeliveryDateKey,
                target.ActualDeliveryDateKey,
                target.ShipmentStatusKey,
                target.CarrierKey,
                target.RouteKey,
                target.OriginLocationKey,
                target.DestinationLocationKey,
                target.ShipmentStatus,
                target.ServiceLevel,
                target.WeightLbs,
                target.PieceCount,
                target.ShipmentRevenue,
                target.ShipmentCost,
                target.PlannedDistanceMiles,
                target.ActualDistanceMiles,
                target.TransitHours,
                target.TransitDays,
                target.DeliveryDelayMinutes,
                target.OnTimeDeliveryFlag,
                target.LateDeliveryFlag,
                target.ShipmentCount,
                target.ScanEventCount,
                target.ExceptionCount,
                target.ExceptionShipmentFlag,
                target.SourceModifiedAt
            EXCEPT
            SELECT
                source.OrderDateKey,
                source.PlannedPickupDateKey,
                source.ActualPickupDateKey,
                source.PlannedDeliveryDateKey,
                source.ActualDeliveryDateKey,
                source.ShipmentStatusKey,
                source.CarrierKey,
                source.RouteKey,
                source.OriginLocationKey,
                source.DestinationLocationKey,
                source.ShipmentStatus,
                source.ServiceLevel,
                source.WeightLbs,
                source.PieceCount,
                source.ShipmentRevenue,
                source.ShipmentCost,
                source.PlannedDistanceMiles,
                source.ActualDistanceMiles,
                source.TransitHours,
                source.TransitDays,
                source.DeliveryDelayMinutes,
                source.OnTimeDeliveryFlag,
                source.LateDeliveryFlag,
                source.ShipmentCount,
                source.ScanEventCount,
                source.ExceptionCount,
                source.ExceptionShipmentFlag,
                source.SourceModifiedAt
        )
            THEN UPDATE
                 SET OrderDateKey = source.OrderDateKey,
                     PlannedPickupDateKey = source.PlannedPickupDateKey,
                     ActualPickupDateKey = source.ActualPickupDateKey,
                     PlannedDeliveryDateKey = source.PlannedDeliveryDateKey,
                     ActualDeliveryDateKey = source.ActualDeliveryDateKey,
                     ShipmentStatusKey = source.ShipmentStatusKey,
                     CarrierKey = source.CarrierKey,
                     RouteKey = source.RouteKey,
                     OriginLocationKey = source.OriginLocationKey,
                     DestinationLocationKey = source.DestinationLocationKey,
                     ShipmentStatus = source.ShipmentStatus,
                     ServiceLevel = source.ServiceLevel,
                     WeightLbs = source.WeightLbs,
                     PieceCount = source.PieceCount,
                     ShipmentRevenue = source.ShipmentRevenue,
                     ShipmentCost = source.ShipmentCost,
                     PlannedDistanceMiles = source.PlannedDistanceMiles,
                     ActualDistanceMiles = source.ActualDistanceMiles,
                     TransitHours = source.TransitHours,
                     TransitDays = source.TransitDays,
                     DeliveryDelayMinutes = source.DeliveryDelayMinutes,
                     OnTimeDeliveryFlag = source.OnTimeDeliveryFlag,
                     LateDeliveryFlag = source.LateDeliveryFlag,
                     ShipmentCount = source.ShipmentCount,
                     ScanEventCount = source.ScanEventCount,
                     ExceptionCount = source.ExceptionCount,
                     ExceptionShipmentFlag = source.ExceptionShipmentFlag,
                     BatchID = @BatchID,
                     SourceModifiedAt = source.SourceModifiedAt,
                     UpdatedAt = SYSUTCDATETIME()
        WHEN NOT MATCHED BY TARGET
            THEN INSERT
            (
                ShipmentNumber,
                OrderDateKey,
                PlannedPickupDateKey,
                ActualPickupDateKey,
                PlannedDeliveryDateKey,
                ActualDeliveryDateKey,
                ShipmentStatusKey,
                CarrierKey,
                RouteKey,
                OriginLocationKey,
                DestinationLocationKey,
                ShipmentStatus,
                ServiceLevel,
                WeightLbs,
                PieceCount,
                ShipmentRevenue,
                ShipmentCost,
                PlannedDistanceMiles,
                ActualDistanceMiles,
                TransitHours,
                TransitDays,
                DeliveryDelayMinutes,
                OnTimeDeliveryFlag,
                LateDeliveryFlag,
                ShipmentCount,
                ScanEventCount,
                ExceptionCount,
                ExceptionShipmentFlag,
                BatchID,
                SourceModifiedAt
            )
            VALUES
            (
                source.ShipmentNumber,
                source.OrderDateKey,
                source.PlannedPickupDateKey,
                source.ActualPickupDateKey,
                source.PlannedDeliveryDateKey,
                source.ActualDeliveryDateKey,
                source.ShipmentStatusKey,
                source.CarrierKey,
                source.RouteKey,
                source.OriginLocationKey,
                source.DestinationLocationKey,
                source.ShipmentStatus,
                source.ServiceLevel,
                source.WeightLbs,
                source.PieceCount,
                source.ShipmentRevenue,
                source.ShipmentCost,
                source.PlannedDistanceMiles,
                source.ActualDistanceMiles,
                source.TransitHours,
                source.TransitDays,
                source.DeliveryDelayMinutes,
                source.OnTimeDeliveryFlag,
                source.LateDeliveryFlag,
                source.ShipmentCount,
                source.ScanEventCount,
                source.ExceptionCount,
                source.ExceptionShipmentFlag,
                @BatchID,
                source.SourceModifiedAt
            )
        OUTPUT $action INTO @MergeActions(ActionName);

        SELECT @RowsInserted = COUNT(*) FROM @MergeActions WHERE ActionName = N'INSERT';
        SELECT @RowsUpdated = COUNT(*) FROM @MergeActions WHERE ActionName = N'UPDATE';

        UPDATE audit.Load_Audit
        SET RowsInserted = @RowsInserted,
            RowsUpdated = @RowsUpdated,
            CompletedAt = SYSUTCDATETIME(),
            Status = 'SUCCEEDED',
            Message = N'Shipment fact load completed with impacted-shipment restatement and rerun-safe updates.'
        WHERE LoadAuditID = @AuditID;
    END TRY
    BEGIN CATCH
        EXEC audit.usp_Log_Error
            @BatchID = @BatchID,
            @ProcedureName = N'etl.usp_Load_FactShipment',
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

CREATE OR ALTER PROCEDURE etl.usp_Load_FactDeliveryEvent
    @BatchID int
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AuditID bigint;
    DECLARE @RowsInserted int = 0;
    DECLARE @RowsUpdated int = 0;
    DECLARE @MergeActions TABLE (ActionName nvarchar(10));

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
            N'Load Fact Delivery Event',
            N'dw.FactDeliveryEvent',
            'STARTED'
        );

        SET @AuditID = SCOPE_IDENTITY();

        CREATE TABLE #EventStage
        (
            ShipmentNumber nvarchar(50) NOT NULL,
            EventSequenceNumber int NOT NULL,
            StatusCode nvarchar(30) NOT NULL,
            EventDateTime datetime2(0) NOT NULL,
            LocationCode nvarchar(30) NULL,
            ScanType nvarchar(30) NULL,
            EventSource nvarchar(30) NULL,
            ExceptionCode nvarchar(30) NULL
        );

        INSERT INTO #EventStage
        (
            ShipmentNumber,
            EventSequenceNumber,
            StatusCode,
            EventDateTime,
            LocationCode,
            ScanType,
            EventSource,
            ExceptionCode
        )
        SELECT
            src.ShipmentNumber,
            src.EventSequenceNumber,
            src.StatusCode,
            src.EventDateTime,
            src.LocationCode,
            src.ScanType,
            src.EventSource,
            src.ExceptionCode
        FROM
        (
            SELECT
                UPPER(LTRIM(RTRIM(h.ShipmentNumber))) AS ShipmentNumber,
                h.EventSequenceNumber,
                UPPER(LTRIM(RTRIM(h.StatusCode))) AS StatusCode,
                h.EventDateTime,
                NULLIF(UPPER(LTRIM(RTRIM(h.LocationCode))), N'') AS LocationCode,
                NULLIF(LTRIM(RTRIM(h.ScanType)), N'') AS ScanType,
                NULLIF(LTRIM(RTRIM(h.EventSource)), N'') AS EventSource,
                NULLIF(UPPER(LTRIM(RTRIM(h.ExceptionCode))), N'') AS ExceptionCode,
                ROW_NUMBER() OVER
                (
                    PARTITION BY UPPER(LTRIM(RTRIM(h.ShipmentNumber))), h.EventSequenceNumber
                    ORDER BY h.EventDateTime DESC, h.StageShipmentStatusHistoryID DESC
                ) AS rn
            FROM stg.Shipment_Status_History_Raw AS h
            WHERE h.BatchID = @BatchID
              AND h.IsValid = 1
        ) AS src
        WHERE src.rn = 1;

        MERGE dw.FactDeliveryEvent AS target
        USING
        (
            SELECT
                e.ShipmentNumber,
                ISNULL(CAST(CONVERT(char(8), CAST(e.EventDateTime AS date), 112) AS int), 0) AS EventDateKey,
                ISNULL(ss.ShipmentStatusKey, 0) AS ShipmentStatusKey,
                fs.CarrierKey,
                fs.RouteKey,
                fs.OriginLocationKey,
                fs.DestinationLocationKey,
                ISNULL(el.LocationKey, 0) AS EventLocationKey,
                ISNULL(de.DeliveryExceptionKey, 0) AS DeliveryExceptionKey,
                e.EventSequenceNumber,
                e.EventDateTime,
                e.ScanType,
                e.EventSource,
                1 AS EventCount,
                CASE
                    WHEN ISNULL(ss.IsExceptionStatus, 0) = 1
                      OR e.ExceptionCode IS NOT NULL
                        THEN 1
                    ELSE 0
                END AS ExceptionEventFlag
            FROM #EventStage AS e
            INNER JOIN dw.FactShipment AS fs
                ON e.ShipmentNumber = fs.ShipmentNumber
            LEFT JOIN dw.DimShipmentStatus AS ss
                ON e.StatusCode = ss.StatusCode
            LEFT JOIN dw.DimLocation AS el
                ON e.LocationCode = el.LocationCode
            LEFT JOIN dw.DimDeliveryException AS de
                ON e.ExceptionCode = de.ExceptionCode
        ) AS source
            ON target.ShipmentNumber = source.ShipmentNumber
           AND target.EventSequenceNumber = source.EventSequenceNumber
        WHEN MATCHED AND EXISTS
        (
            SELECT
                target.EventDateKey,
                target.ShipmentStatusKey,
                target.CarrierKey,
                target.RouteKey,
                target.OriginLocationKey,
                target.DestinationLocationKey,
                target.EventLocationKey,
                target.DeliveryExceptionKey,
                target.EventDateTime,
                target.ScanType,
                target.EventSource,
                target.EventCount,
                target.ExceptionEventFlag
            EXCEPT
            SELECT
                source.EventDateKey,
                source.ShipmentStatusKey,
                source.CarrierKey,
                source.RouteKey,
                source.OriginLocationKey,
                source.DestinationLocationKey,
                source.EventLocationKey,
                source.DeliveryExceptionKey,
                source.EventDateTime,
                source.ScanType,
                source.EventSource,
                source.EventCount,
                source.ExceptionEventFlag
        )
            THEN UPDATE
                 SET EventDateKey = source.EventDateKey,
                     ShipmentStatusKey = source.ShipmentStatusKey,
                     CarrierKey = source.CarrierKey,
                     RouteKey = source.RouteKey,
                     OriginLocationKey = source.OriginLocationKey,
                     DestinationLocationKey = source.DestinationLocationKey,
                     EventLocationKey = source.EventLocationKey,
                     DeliveryExceptionKey = source.DeliveryExceptionKey,
                     EventDateTime = source.EventDateTime,
                     ScanType = source.ScanType,
                     EventSource = source.EventSource,
                     EventCount = source.EventCount,
                     ExceptionEventFlag = source.ExceptionEventFlag,
                     BatchID = @BatchID
        WHEN NOT MATCHED BY TARGET
            THEN INSERT
            (
                ShipmentNumber,
                EventDateKey,
                ShipmentStatusKey,
                CarrierKey,
                RouteKey,
                OriginLocationKey,
                DestinationLocationKey,
                EventLocationKey,
                DeliveryExceptionKey,
                EventSequenceNumber,
                EventDateTime,
                ScanType,
                EventSource,
                EventCount,
                ExceptionEventFlag,
                BatchID
            )
            VALUES
            (
                source.ShipmentNumber,
                source.EventDateKey,
                source.ShipmentStatusKey,
                source.CarrierKey,
                source.RouteKey,
                source.OriginLocationKey,
                source.DestinationLocationKey,
                source.EventLocationKey,
                source.DeliveryExceptionKey,
                source.EventSequenceNumber,
                source.EventDateTime,
                source.ScanType,
                source.EventSource,
                source.EventCount,
                source.ExceptionEventFlag,
                @BatchID
            )
        OUTPUT $action INTO @MergeActions(ActionName);

        SELECT @RowsInserted = COUNT(*) FROM @MergeActions WHERE ActionName = N'INSERT';
        SELECT @RowsUpdated = COUNT(*) FROM @MergeActions WHERE ActionName = N'UPDATE';

        UPDATE audit.Load_Audit
        SET RowsInserted = @RowsInserted,
            RowsUpdated = @RowsUpdated,
            CompletedAt = SYSUTCDATETIME(),
            Status = 'SUCCEEDED',
            Message = N'Delivery event fact load completed with rerun-safe merge logic.'
        WHERE LoadAuditID = @AuditID;
    END TRY
    BEGIN CATCH
        EXEC audit.usp_Log_Error
            @BatchID = @BatchID,
            @ProcedureName = N'etl.usp_Load_FactDeliveryEvent',
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

CREATE OR ALTER PROCEDURE etl.usp_Load_FactDeliveryException
    @BatchID int
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AuditID bigint;
    DECLARE @RowsInserted int = 0;
    DECLARE @RowsUpdated int = 0;
    DECLARE @MergeActions TABLE (ActionName nvarchar(10));

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
            N'Load Fact Delivery Exception',
            N'dw.FactDeliveryException',
            'STARTED'
        );

        SET @AuditID = SCOPE_IDENTITY();

        CREATE TABLE #ExceptionStage
        (
            ShipmentNumber nvarchar(50) NOT NULL,
            ExceptionCode nvarchar(30) NOT NULL,
            ExceptionDateTime datetime2(0) NOT NULL,
            DelayMinutesImpact int NULL,
            ResolvedDateTime datetime2(0) NULL
        );

        INSERT INTO #ExceptionStage
        (
            ShipmentNumber,
            ExceptionCode,
            ExceptionDateTime,
            DelayMinutesImpact,
            ResolvedDateTime
        )
        SELECT
            src.ShipmentNumber,
            src.ExceptionCode,
            src.ExceptionDateTime,
            src.DelayMinutesImpact,
            src.ResolvedDateTime
        FROM
        (
            SELECT
                UPPER(LTRIM(RTRIM(e.ShipmentNumber))) AS ShipmentNumber,
                UPPER(LTRIM(RTRIM(e.ExceptionCode))) AS ExceptionCode,
                e.ExceptionDateTime,
                e.DelayMinutesImpact,
                e.ResolvedDateTime,
                ROW_NUMBER() OVER
                (
                    PARTITION BY UPPER(LTRIM(RTRIM(e.ShipmentNumber))), UPPER(LTRIM(RTRIM(e.ExceptionCode))), e.ExceptionDateTime
                    ORDER BY e.StageDeliveryExceptionID DESC
                ) AS rn
            FROM stg.Delivery_Exception_Raw AS e
            WHERE e.BatchID = @BatchID
              AND e.IsValid = 1
        ) AS src
        WHERE src.rn = 1;

        CREATE TABLE #EventStage
        (
            ShipmentNumber nvarchar(50) NOT NULL,
            EventSequenceNumber int NOT NULL,
            StatusCode nvarchar(30) NOT NULL,
            EventDateTime datetime2(0) NOT NULL
        );

        INSERT INTO #EventStage
        (
            ShipmentNumber,
            EventSequenceNumber,
            StatusCode,
            EventDateTime
        )
        SELECT
            src.ShipmentNumber,
            src.EventSequenceNumber,
            src.StatusCode,
            src.EventDateTime
        FROM
        (
            SELECT
                UPPER(LTRIM(RTRIM(h.ShipmentNumber))) AS ShipmentNumber,
                h.EventSequenceNumber,
                UPPER(LTRIM(RTRIM(h.StatusCode))) AS StatusCode,
                h.EventDateTime,
                ROW_NUMBER() OVER
                (
                    PARTITION BY UPPER(LTRIM(RTRIM(h.ShipmentNumber))), h.EventSequenceNumber
                    ORDER BY h.EventDateTime DESC, h.StageShipmentStatusHistoryID DESC
                ) AS rn
            FROM stg.Shipment_Status_History_Raw AS h
            WHERE h.BatchID = @BatchID
              AND h.IsValid = 1
        ) AS src
        WHERE src.rn = 1;

        MERGE dw.FactDeliveryException AS target
        USING
        (
            SELECT
                e.ShipmentNumber,
                ISNULL(CAST(CONVERT(char(8), CAST(e.ExceptionDateTime AS date), 112) AS int), 0) AS ExceptionDateKey,
                ISNULL(ss.ShipmentStatusKey, fs.ShipmentStatusKey) AS ShipmentStatusKey,
                fs.CarrierKey,
                fs.RouteKey,
                fs.OriginLocationKey,
                fs.DestinationLocationKey,
                ISNULL(de.DeliveryExceptionKey, 0) AS DeliveryExceptionKey,
                e.ExceptionDateTime,
                e.DelayMinutesImpact,
                de.TypicalDelayMinutes,
                CASE
                    WHEN e.DelayMinutesImpact IS NOT NULL
                     AND de.TypicalDelayMinutes IS NOT NULL
                        THEN e.DelayMinutesImpact - de.TypicalDelayMinutes
                    ELSE NULL
                END AS DelayVarianceMinutes,
                CASE
                    WHEN e.ResolvedDateTime IS NOT NULL
                     AND DATEDIFF(HOUR, e.ExceptionDateTime, e.ResolvedDateTime) <= 24
                        THEN 1
                    ELSE 0
                END AS ResolvedWithin24HoursFlag
            FROM #ExceptionStage AS e
            INNER JOIN dw.FactShipment AS fs
                ON e.ShipmentNumber = fs.ShipmentNumber
            LEFT JOIN dw.DimDeliveryException AS de
                ON e.ExceptionCode = de.ExceptionCode
            OUTER APPLY
            (
                SELECT TOP (1)
                    h.StatusCode
                FROM #EventStage AS h
                WHERE h.ShipmentNumber = e.ShipmentNumber
                  AND h.EventDateTime <= e.ExceptionDateTime
                ORDER BY h.EventDateTime DESC, h.EventSequenceNumber DESC
            ) AS es
            LEFT JOIN dw.DimShipmentStatus AS ss
                ON es.StatusCode = ss.StatusCode
        ) AS source
            ON target.ShipmentNumber = source.ShipmentNumber
           AND target.DeliveryExceptionKey = source.DeliveryExceptionKey
           AND target.ExceptionDateTime = source.ExceptionDateTime
        WHEN MATCHED AND EXISTS
        (
            SELECT
                target.ExceptionDateKey,
                target.ShipmentStatusKey,
                target.CarrierKey,
                target.RouteKey,
                target.OriginLocationKey,
                target.DestinationLocationKey,
                target.DelayMinutesImpact,
                target.TypicalDelayMinutes,
                target.DelayVarianceMinutes,
                target.ResolvedWithin24HoursFlag,
                target.ExceptionCount
            EXCEPT
            SELECT
                source.ExceptionDateKey,
                source.ShipmentStatusKey,
                source.CarrierKey,
                source.RouteKey,
                source.OriginLocationKey,
                source.DestinationLocationKey,
                source.DelayMinutesImpact,
                source.TypicalDelayMinutes,
                source.DelayVarianceMinutes,
                source.ResolvedWithin24HoursFlag,
                1
        )
            THEN UPDATE
                 SET ExceptionDateKey = source.ExceptionDateKey,
                     ShipmentStatusKey = source.ShipmentStatusKey,
                     CarrierKey = source.CarrierKey,
                     RouteKey = source.RouteKey,
                     OriginLocationKey = source.OriginLocationKey,
                     DestinationLocationKey = source.DestinationLocationKey,
                     DelayMinutesImpact = source.DelayMinutesImpact,
                     TypicalDelayMinutes = source.TypicalDelayMinutes,
                     DelayVarianceMinutes = source.DelayVarianceMinutes,
                     ResolvedWithin24HoursFlag = source.ResolvedWithin24HoursFlag,
                     BatchID = @BatchID
        WHEN NOT MATCHED BY TARGET
            THEN INSERT
            (
                ShipmentNumber,
                ExceptionDateKey,
                ShipmentStatusKey,
                CarrierKey,
                RouteKey,
                OriginLocationKey,
                DestinationLocationKey,
                DeliveryExceptionKey,
                ExceptionDateTime,
                DelayMinutesImpact,
                TypicalDelayMinutes,
                DelayVarianceMinutes,
                ResolvedWithin24HoursFlag,
                ExceptionCount,
                BatchID
            )
            VALUES
            (
                source.ShipmentNumber,
                source.ExceptionDateKey,
                source.ShipmentStatusKey,
                source.CarrierKey,
                source.RouteKey,
                source.OriginLocationKey,
                source.DestinationLocationKey,
                source.DeliveryExceptionKey,
                source.ExceptionDateTime,
                source.DelayMinutesImpact,
                source.TypicalDelayMinutes,
                source.DelayVarianceMinutes,
                source.ResolvedWithin24HoursFlag,
                1,
                @BatchID
            )
        OUTPUT $action INTO @MergeActions(ActionName);

        SELECT @RowsInserted = COUNT(*) FROM @MergeActions WHERE ActionName = N'INSERT';
        SELECT @RowsUpdated = COUNT(*) FROM @MergeActions WHERE ActionName = N'UPDATE';

        UPDATE audit.Load_Audit
        SET RowsInserted = @RowsInserted,
            RowsUpdated = @RowsUpdated,
            CompletedAt = SYSUTCDATETIME(),
            Status = 'SUCCEEDED',
            Message = N'Delivery exception fact load completed with rerun-safe merge logic.'
        WHERE LoadAuditID = @AuditID;
    END TRY
    BEGIN CATCH
        EXEC audit.usp_Log_Error
            @BatchID = @BatchID,
            @ProcedureName = N'etl.usp_Load_FactDeliveryException',
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
