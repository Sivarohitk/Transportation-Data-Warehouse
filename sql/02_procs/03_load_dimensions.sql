USE [$(DatabaseName)];
GO

CREATE OR ALTER PROCEDURE etl.usp_Load_DimDate
    @StartDate date = '2024-01-01',
    @EndDate date = '2030-12-31'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentDate date = @StartDate;

    WHILE @CurrentDate <= @EndDate
    BEGIN
        IF NOT EXISTS
        (
            SELECT 1
            FROM dw.DimDate
            WHERE DateKey = CAST(CONVERT(char(8), @CurrentDate, 112) AS int)
        )
        BEGIN
            INSERT INTO dw.DimDate
            (
                DateKey,
                FullDate,
                CalendarYear,
                CalendarQuarter,
                CalendarMonth,
                MonthName,
                DayOfMonth,
                DayName,
                WeekOfYear,
                IsWeekend
            )
            VALUES
            (
                CAST(CONVERT(char(8), @CurrentDate, 112) AS int),
                @CurrentDate,
                YEAR(@CurrentDate),
                DATEPART(QUARTER, @CurrentDate),
                MONTH(@CurrentDate),
                DATENAME(MONTH, @CurrentDate),
                DAY(@CurrentDate),
                DATENAME(WEEKDAY, @CurrentDate),
                DATEPART(ISO_WEEK, @CurrentDate),
                CASE WHEN DATENAME(WEEKDAY, @CurrentDate) IN (N'Saturday', N'Sunday') THEN 1 ELSE 0 END
            );
        END;

        SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
    END;
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Load_Dimensions
    @BatchID int
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AuditID bigint;
    DECLARE @RowsInserted int = 0;
    DECLARE @RowsUpdated int = 0;

    DECLARE @CarrierMergeActions TABLE (ActionName nvarchar(10));
    DECLARE @LocationMergeActions TABLE (ActionName nvarchar(10));
    DECLARE @RouteMergeActions TABLE (ActionName nvarchar(10));
    DECLARE @ExceptionMergeActions TABLE (ActionName nvarchar(10));
    DECLARE @ShipmentStatusMergeActions TABLE (ActionName nvarchar(10));

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
            N'Load Dimensions',
            N'dw.DimCarrier, dw.DimLocation, dw.DimRoute, dw.DimDeliveryException, dw.DimShipmentStatus',
            'STARTED'
        );

        SET @AuditID = SCOPE_IDENTITY();

        CREATE TABLE #CarrierSource
        (
            CarrierCode nvarchar(30) NOT NULL,
            SCACCode nvarchar(10) NULL,
            CarrierName nvarchar(200) NOT NULL,
            CarrierMode nvarchar(50) NULL,
            CarrierTier nvarchar(30) NULL,
            HomeCity nvarchar(100) NULL,
            HomeStateProvince nvarchar(100) NULL,
            ActiveFlag bit NOT NULL
        );

        INSERT INTO #CarrierSource
        (
            CarrierCode,
            SCACCode,
            CarrierName,
            CarrierMode,
            CarrierTier,
            HomeCity,
            HomeStateProvince,
            ActiveFlag
        )
        SELECT
            src.CarrierCode,
            src.SCACCode,
            src.CarrierName,
            src.CarrierMode,
            src.CarrierTier,
            src.HomeCity,
            src.HomeStateProvince,
            src.ActiveFlag
        FROM
        (
            SELECT
                UPPER(LTRIM(RTRIM(c.CarrierCode))) AS CarrierCode,
                NULLIF(UPPER(LTRIM(RTRIM(c.SCACCode))), N'') AS SCACCode,
                REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(c.CarrierName)), N'  ', N' '), N'  ', N' '), N'  ', N' ') AS CarrierName,
                NULLIF(LTRIM(RTRIM(c.CarrierMode)), N'') AS CarrierMode,
                NULLIF(LTRIM(RTRIM(c.CarrierTier)), N'') AS CarrierTier,
                NULLIF(LTRIM(RTRIM(c.HomeCity)), N'') AS HomeCity,
                NULLIF(UPPER(LTRIM(RTRIM(c.HomeStateProvince))), N'') AS HomeStateProvince,
                c.ActiveFlag,
                ROW_NUMBER() OVER
                (
                    PARTITION BY UPPER(LTRIM(RTRIM(c.CarrierCode)))
                    ORDER BY c.StageCarrierID DESC
                ) AS rn
            FROM stg.Carrier_Raw AS c
            WHERE c.BatchID = @BatchID
              AND c.IsValid = 1
        ) AS src
        WHERE src.rn = 1;

        CREATE TABLE #LocationSource
        (
            LocationCode nvarchar(30) NOT NULL,
            LocationName nvarchar(200) NULL,
            LocationType nvarchar(50) NULL,
            AddressLine1 nvarchar(200) NULL,
            City nvarchar(100) NULL,
            StateProvince nvarchar(100) NULL,
            CountryCode nvarchar(10) NULL,
            PostalCode nvarchar(20) NULL,
            Region nvarchar(50) NULL,
            Latitude decimal(9, 6) NULL,
            Longitude decimal(9, 6) NULL,
            ActiveFlag bit NOT NULL
        );

        INSERT INTO #LocationSource
        (
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
            ActiveFlag
        )
        SELECT
            src.LocationCode,
            src.LocationName,
            src.LocationType,
            src.AddressLine1,
            src.City,
            src.StateProvince,
            src.CountryCode,
            src.PostalCode,
            src.Region,
            src.Latitude,
            src.Longitude,
            src.ActiveFlag
        FROM
        (
            SELECT
                UPPER(LTRIM(RTRIM(l.LocationCode))) AS LocationCode,
                NULLIF(LTRIM(RTRIM(l.LocationName)), N'') AS LocationName,
                NULLIF(LTRIM(RTRIM(l.LocationType)), N'') AS LocationType,
                NULLIF(LTRIM(RTRIM(l.AddressLine1)), N'') AS AddressLine1,
                NULLIF(LTRIM(RTRIM(l.City)), N'') AS City,
                NULLIF(UPPER(LTRIM(RTRIM(l.StateProvince))), N'') AS StateProvince,
                NULLIF(UPPER(LTRIM(RTRIM(l.CountryCode))), N'') AS CountryCode,
                NULLIF(LTRIM(RTRIM(l.PostalCode)), N'') AS PostalCode,
                NULLIF(LTRIM(RTRIM(l.Region)), N'') AS Region,
                l.Latitude,
                l.Longitude,
                l.ActiveFlag,
                ROW_NUMBER() OVER
                (
                    PARTITION BY UPPER(LTRIM(RTRIM(l.LocationCode)))
                    ORDER BY l.StageLocationID DESC
                ) AS rn
            FROM stg.Location_Raw AS l
            WHERE l.BatchID = @BatchID
              AND l.IsValid = 1
        ) AS src
        WHERE src.rn = 1;

        CREATE TABLE #RouteReferenceSource
        (
            RouteCode nvarchar(30) NOT NULL,
            OriginLocationCode nvarchar(30) NOT NULL,
            DestinationLocationCode nvarchar(30) NOT NULL,
            ReferenceDistanceMiles decimal(10, 2) NULL,
            ReferenceTransitHours decimal(10, 2) NULL,
            RouteType nvarchar(50) NULL,
            FuelZone nvarchar(30) NULL
        );

        INSERT INTO #RouteReferenceSource
        (
            RouteCode,
            OriginLocationCode,
            DestinationLocationCode,
            ReferenceDistanceMiles,
            ReferenceTransitHours,
            RouteType,
            FuelZone
        )
        SELECT
            src.RouteCode,
            src.OriginLocationCode,
            src.DestinationLocationCode,
            src.ReferenceDistanceMiles,
            src.ReferenceTransitHours,
            src.RouteType,
            src.FuelZone
        FROM
        (
            SELECT
                UPPER(REPLACE(LTRIM(RTRIM(rr.RouteCode)), N' ', N'')) AS RouteCode,
                UPPER(LTRIM(RTRIM(rr.OriginLocationCode))) AS OriginLocationCode,
                UPPER(LTRIM(RTRIM(rr.DestinationLocationCode))) AS DestinationLocationCode,
                rr.ReferenceDistanceMiles,
                rr.ReferenceTransitHours,
                NULLIF(LTRIM(RTRIM(rr.RouteType)), N'') AS RouteType,
                NULLIF(LTRIM(RTRIM(rr.FuelZone)), N'') AS FuelZone,
                ROW_NUMBER() OVER
                (
                    PARTITION BY
                        UPPER(REPLACE(LTRIM(RTRIM(rr.RouteCode)), N' ', N'')),
                        UPPER(LTRIM(RTRIM(rr.OriginLocationCode))),
                        UPPER(LTRIM(RTRIM(rr.DestinationLocationCode)))
                    ORDER BY rr.StageRouteDistanceReferenceID DESC
                ) AS rn
            FROM stg.Route_Distance_Reference_Raw AS rr
            WHERE rr.BatchID = @BatchID
              AND rr.IsValid = 1
        ) AS src
        WHERE src.rn = 1;

        CREATE TABLE #RouteSource
        (
            RouteCode nvarchar(30) NOT NULL,
            OriginLocationCode nvarchar(30) NULL,
            DestinationLocationCode nvarchar(30) NULL,
            RouteType nvarchar(50) NULL,
            PlannedDistanceMiles decimal(10, 2) NULL,
            PlannedTransitHours decimal(10, 2) NULL,
            ReferenceDistanceMiles decimal(10, 2) NULL,
            ReferenceTransitHours decimal(10, 2) NULL,
            FuelZone nvarchar(30) NULL,
            ActiveFlag bit NOT NULL,
            EffectiveStartDate date NULL,
            EffectiveEndDate date NULL
        );

        INSERT INTO #RouteSource
        (
            RouteCode,
            OriginLocationCode,
            DestinationLocationCode,
            RouteType,
            PlannedDistanceMiles,
            PlannedTransitHours,
            ReferenceDistanceMiles,
            ReferenceTransitHours,
            FuelZone,
            ActiveFlag,
            EffectiveStartDate,
            EffectiveEndDate
        )
        SELECT
            src.RouteCode,
            src.OriginLocationCode,
            src.DestinationLocationCode,
            COALESCE(ref.RouteType, src.RouteType) AS RouteType,
            src.PlannedDistanceMiles,
            src.PlannedTransitHours,
            COALESCE(ref.ReferenceDistanceMiles, src.PlannedDistanceMiles) AS ReferenceDistanceMiles,
            COALESCE(ref.ReferenceTransitHours, src.PlannedTransitHours) AS ReferenceTransitHours,
            COALESCE
            (
                ref.FuelZone,
                CASE
                    WHEN src.PlannedDistanceMiles < 250 THEN N'Short Haul'
                    WHEN src.PlannedDistanceMiles < 700 THEN N'Mid Haul'
                    WHEN src.PlannedDistanceMiles IS NOT NULL THEN N'Long Haul'
                    ELSE N'Unknown'
                END
            ) AS FuelZone,
            src.ActiveFlag,
            src.EffectiveStartDate,
            src.EffectiveEndDate
        FROM
        (
            SELECT
                UPPER(REPLACE(LTRIM(RTRIM(r.RouteCode)), N' ', N'')) AS RouteCode,
                UPPER(LTRIM(RTRIM(r.OriginLocationCode))) AS OriginLocationCode,
                UPPER(LTRIM(RTRIM(r.DestinationLocationCode))) AS DestinationLocationCode,
                NULLIF(LTRIM(RTRIM(r.RouteType)), N'') AS RouteType,
                r.PlannedDistanceMiles,
                r.PlannedTransitHours,
                r.ActiveFlag,
                r.EffectiveStartDate,
                r.EffectiveEndDate,
                ROW_NUMBER() OVER
                (
                    PARTITION BY UPPER(REPLACE(LTRIM(RTRIM(r.RouteCode)), N' ', N''))
                    ORDER BY r.StageRouteID DESC
                ) AS rn
            FROM stg.Route_Raw AS r
            WHERE r.BatchID = @BatchID
              AND r.IsValid = 1
        ) AS src
        LEFT JOIN #RouteReferenceSource AS ref
            ON src.RouteCode = ref.RouteCode
           AND src.OriginLocationCode = ref.OriginLocationCode
           AND src.DestinationLocationCode = ref.DestinationLocationCode
        WHERE src.rn = 1;

        CREATE TABLE #ExceptionSource
        (
            ExceptionCode nvarchar(30) NOT NULL,
            ExceptionDescription nvarchar(200) NULL,
            ExceptionCategory nvarchar(50) NULL,
            SeverityCode nvarchar(20) NULL,
            TypicalDelayMinutes int NULL,
            ResponsibleParty nvarchar(50) NULL,
            ActiveFlag bit NOT NULL
        );

        ;WITH CombinedExceptionSource AS
        (
            SELECT
                UPPER(LTRIM(RTRIM(x.ExceptionCode))) AS ExceptionCode,
                NULLIF(LTRIM(RTRIM(x.ExceptionDescription)), N'') AS ExceptionDescription,
                CASE
                    WHEN UPPER(LTRIM(RTRIM(x.ExceptionCode))) = N'WX'
                      OR UPPER(LTRIM(RTRIM(x.ExceptionCategory))) IN (N'WEATHER', N'WEATHER DELAY', N'WEATHER HOLD')
                        THEN N'Weather'
                    WHEN UPPER(LTRIM(RTRIM(x.ExceptionCode))) = N'DAMG'
                      OR UPPER(LTRIM(RTRIM(x.ExceptionCategory))) IN (N'DAMAGE', N'DAMAGED')
                        THEN N'Damage'
                    WHEN UPPER(LTRIM(RTRIM(x.ExceptionCode))) = N'MSCN'
                      OR UPPER(LTRIM(RTRIM(x.ExceptionCategory))) IN (N'PROCESS', N'OPERATIONAL', N'SCAN COMPLIANCE')
                        THEN N'Process'
                    WHEN UPPER(LTRIM(RTRIM(x.ExceptionCode))) = N'ADDR'
                      OR UPPER(LTRIM(RTRIM(x.ExceptionCategory))) = N'ADDRESS'
                        THEN N'Address'
                    WHEN UPPER(LTRIM(RTRIM(x.ExceptionCode))) = N'MECH'
                      OR UPPER(LTRIM(RTRIM(x.ExceptionCategory))) = N'MECHANICAL'
                        THEN N'Mechanical'
                    WHEN UPPER(LTRIM(RTRIM(x.ExceptionCode))) = N'CAP'
                      OR UPPER(LTRIM(RTRIM(x.ExceptionCategory))) = N'CAPACITY'
                        THEN N'Capacity'
                    WHEN NULLIF(LTRIM(RTRIM(x.ExceptionCategory)), N'') IS NOT NULL
                        THEN LEFT(UPPER(LEFT(LTRIM(RTRIM(x.ExceptionCategory)), 1)) + LOWER(SUBSTRING(LTRIM(RTRIM(x.ExceptionCategory)), 2, 49)), 50)
                    ELSE N'Other'
                END AS ExceptionCategory,
                NULLIF(UPPER(LTRIM(RTRIM(x.SeverityCode))), N'') AS SeverityCode,
                x.TypicalDelayMinutes,
                NULLIF(LTRIM(RTRIM(x.ResponsibleParty)), N'') AS ResponsibleParty,
                x.ActiveFlag,
                CAST(1 AS tinyint) AS SourcePriority,
                x.StageExceptionCodeLookupID AS SequenceID
            FROM stg.Exception_Code_Lookup_Raw AS x
            WHERE x.BatchID = @BatchID
              AND x.IsValid = 1

            UNION ALL

            SELECT
                UPPER(LTRIM(RTRIM(e.ExceptionCode))) AS ExceptionCode,
                NULLIF(LTRIM(RTRIM(e.ExceptionDescription)), N'') AS ExceptionDescription,
                CASE
                    WHEN UPPER(LTRIM(RTRIM(e.ExceptionCode))) = N'WX'
                      OR UPPER(LTRIM(RTRIM(e.ExceptionCategory))) IN (N'WEATHER', N'WEATHER DELAY', N'WEATHER HOLD')
                        THEN N'Weather'
                    WHEN UPPER(LTRIM(RTRIM(e.ExceptionCode))) = N'DAMG'
                      OR UPPER(LTRIM(RTRIM(e.ExceptionCategory))) IN (N'DAMAGE', N'DAMAGED')
                        THEN N'Damage'
                    WHEN UPPER(LTRIM(RTRIM(e.ExceptionCode))) = N'MSCN'
                      OR UPPER(LTRIM(RTRIM(e.ExceptionCategory))) IN (N'PROCESS', N'OPERATIONAL', N'SCAN COMPLIANCE')
                        THEN N'Process'
                    WHEN UPPER(LTRIM(RTRIM(e.ExceptionCode))) = N'ADDR'
                      OR UPPER(LTRIM(RTRIM(e.ExceptionCategory))) = N'ADDRESS'
                        THEN N'Address'
                    WHEN UPPER(LTRIM(RTRIM(e.ExceptionCode))) = N'MECH'
                      OR UPPER(LTRIM(RTRIM(e.ExceptionCategory))) = N'MECHANICAL'
                        THEN N'Mechanical'
                    WHEN UPPER(LTRIM(RTRIM(e.ExceptionCode))) = N'CAP'
                      OR UPPER(LTRIM(RTRIM(e.ExceptionCategory))) = N'CAPACITY'
                        THEN N'Capacity'
                    WHEN NULLIF(LTRIM(RTRIM(e.ExceptionCategory)), N'') IS NOT NULL
                        THEN LEFT(UPPER(LEFT(LTRIM(RTRIM(e.ExceptionCategory)), 1)) + LOWER(SUBSTRING(LTRIM(RTRIM(e.ExceptionCategory)), 2, 49)), 50)
                    ELSE N'Other'
                END AS ExceptionCategory,
                NULLIF(UPPER(LTRIM(RTRIM(e.SeverityCode))), N'') AS SeverityCode,
                e.DelayMinutesImpact AS TypicalDelayMinutes,
                NULLIF(LTRIM(RTRIM(e.ResponsibleParty)), N'') AS ResponsibleParty,
                CAST(1 AS bit) AS ActiveFlag,
                CAST(2 AS tinyint) AS SourcePriority,
                e.StageDeliveryExceptionID AS SequenceID
            FROM stg.Delivery_Exception_Raw AS e
            WHERE e.BatchID = @BatchID
              AND e.IsValid = 1
              AND NULLIF(LTRIM(RTRIM(e.ExceptionCode)), N'') IS NOT NULL
        )
        INSERT INTO #ExceptionSource
        (
            ExceptionCode,
            ExceptionDescription,
            ExceptionCategory,
            SeverityCode,
            TypicalDelayMinutes,
            ResponsibleParty,
            ActiveFlag
        )
        SELECT
            src.ExceptionCode,
            COALESCE(src.ExceptionDescription, N'Unknown exception description'),
            src.ExceptionCategory,
            COALESCE(src.SeverityCode, N'UNKNOWN'),
            src.TypicalDelayMinutes,
            COALESCE(src.ResponsibleParty, N'Operations'),
            src.ActiveFlag
        FROM
        (
            SELECT
                c.ExceptionCode,
                c.ExceptionDescription,
                c.ExceptionCategory,
                c.SeverityCode,
                c.TypicalDelayMinutes,
                c.ResponsibleParty,
                c.ActiveFlag,
                ROW_NUMBER() OVER
                (
                    PARTITION BY c.ExceptionCode
                    ORDER BY c.SourcePriority, c.SequenceID DESC
                ) AS rn
            FROM CombinedExceptionSource AS c
        ) AS src
        WHERE src.rn = 1;

        CREATE TABLE #ShipmentStatusSource
        (
            StatusCode nvarchar(30) NOT NULL,
            StatusDescription nvarchar(200) NOT NULL,
            StatusGroup nvarchar(50) NULL,
            StatusSortOrder int NOT NULL,
            IsTerminalStatus bit NOT NULL,
            IsExceptionStatus bit NOT NULL,
            ActiveFlag bit NOT NULL
        );

        ;WITH CombinedStatusSource AS
        (
            SELECT
                UPPER(LTRIM(RTRIM(h.StatusCode))) AS StatusCode,
                NULLIF(LTRIM(RTRIM(h.StatusDescription)), N'') AS StatusDescription,
                CAST(1 AS tinyint) AS SourcePriority,
                h.StageShipmentStatusHistoryID AS SequenceID
            FROM stg.Shipment_Status_History_Raw AS h
            WHERE h.BatchID = @BatchID
              AND h.IsValid = 1
              AND NULLIF(LTRIM(RTRIM(h.StatusCode)), N'') IS NOT NULL

            UNION ALL

            SELECT
                CASE UPPER(LTRIM(RTRIM(s.ShipmentStatus)))
                    WHEN 'DELIVERED' THEN N'DELIVERED'
                    WHEN 'EXCEPTION' THEN N'EXCEPTION_OPEN'
                    WHEN 'IN TRANSIT' THEN N'IN_TRANSIT'
                    WHEN 'OUT FOR DELIVERY' THEN N'OUT_FOR_DELIVERY'
                    WHEN 'CREATED' THEN N'CREATED'
                    ELSE N'UNKNOWN'
                END AS StatusCode,
                CASE UPPER(LTRIM(RTRIM(s.ShipmentStatus)))
                    WHEN 'DELIVERED' THEN N'Delivered'
                    WHEN 'EXCEPTION' THEN N'Exception Open'
                    WHEN 'IN TRANSIT' THEN N'In Transit'
                    WHEN 'OUT FOR DELIVERY' THEN N'Out for Delivery'
                    WHEN 'CREATED' THEN N'Created'
                    ELSE N'Unknown'
                END AS StatusDescription,
                CAST(2 AS tinyint) AS SourcePriority,
                s.StageShipmentID AS SequenceID
            FROM stg.Shipment_Raw AS s
            WHERE s.BatchID = @BatchID
              AND s.IsValid = 1
        )
        INSERT INTO #ShipmentStatusSource
        (
            StatusCode,
            StatusDescription,
            StatusGroup,
            StatusSortOrder,
            IsTerminalStatus,
            IsExceptionStatus,
            ActiveFlag
        )
        SELECT
            src.StatusCode,
            COALESCE(src.StatusDescription, REPLACE(src.StatusCode, N'_', N' ')) AS StatusDescription,
            CASE
                WHEN src.StatusCode IN (N'CREATED', N'PICKUP_SCHEDULED') THEN N'Planning'
                WHEN src.StatusCode IN (N'PICKED_UP', N'DEPARTED_ORIGIN', N'IN_TRANSIT', N'AT_DESTINATION_HUB', N'OUT_FOR_DELIVERY') THEN N'In Transit'
                WHEN src.StatusCode = N'DELIVERED' THEN N'Delivered'
                WHEN src.StatusCode = N'RESOLVED' THEN N'Recovered'
                WHEN src.StatusCode IN (N'EXCEPTION_OPEN', N'WEATHER_HOLD', N'MISSED_SCAN_ALERT', N'ADDRESS_REVIEW', N'DAMAGE_REPORTED', N'CAPACITY_DELAY', N'EQUIPMENT_BREAKDOWN') THEN N'Exception'
                ELSE N'Unknown'
            END AS StatusGroup,
            CASE src.StatusCode
                WHEN N'CREATED' THEN 10
                WHEN N'PICKUP_SCHEDULED' THEN 20
                WHEN N'PICKED_UP' THEN 30
                WHEN N'DEPARTED_ORIGIN' THEN 40
                WHEN N'IN_TRANSIT' THEN 50
                WHEN N'AT_DESTINATION_HUB' THEN 60
                WHEN N'OUT_FOR_DELIVERY' THEN 70
                WHEN N'WEATHER_HOLD' THEN 75
                WHEN N'MISSED_SCAN_ALERT' THEN 76
                WHEN N'ADDRESS_REVIEW' THEN 77
                WHEN N'DAMAGE_REPORTED' THEN 78
                WHEN N'CAPACITY_DELAY' THEN 79
                WHEN N'EQUIPMENT_BREAKDOWN' THEN 80
                WHEN N'EXCEPTION_OPEN' THEN 81
                WHEN N'RESOLVED' THEN 85
                WHEN N'DELIVERED' THEN 90
                ELSE 999
            END AS StatusSortOrder,
            CASE WHEN src.StatusCode = N'DELIVERED' THEN 1 ELSE 0 END AS IsTerminalStatus,
            CASE
                WHEN src.StatusCode IN (N'EXCEPTION_OPEN', N'WEATHER_HOLD', N'MISSED_SCAN_ALERT', N'ADDRESS_REVIEW', N'DAMAGE_REPORTED', N'CAPACITY_DELAY', N'EQUIPMENT_BREAKDOWN')
                    THEN 1
                ELSE 0
            END AS IsExceptionStatus,
            CAST(1 AS bit) AS ActiveFlag
        FROM
        (
            SELECT
                c.StatusCode,
                c.StatusDescription,
                ROW_NUMBER() OVER
                (
                    PARTITION BY c.StatusCode
                    ORDER BY c.SourcePriority, c.SequenceID DESC
                ) AS rn
            FROM CombinedStatusSource AS c
            WHERE c.StatusCode IS NOT NULL
        ) AS src
        WHERE src.rn = 1;

        MERGE dw.DimCarrier AS target
        USING #CarrierSource AS source
            ON target.CarrierCode = source.CarrierCode
        WHEN MATCHED AND EXISTS
        (
            SELECT
                target.SCACCode,
                target.CarrierName,
                target.CarrierMode,
                target.CarrierTier,
                target.HomeCity,
                target.HomeStateProvince,
                target.ActiveFlag
            EXCEPT
            SELECT
                source.SCACCode,
                source.CarrierName,
                source.CarrierMode,
                source.CarrierTier,
                source.HomeCity,
                source.HomeStateProvince,
                source.ActiveFlag
        )
            THEN UPDATE
                 SET SCACCode = source.SCACCode,
                     CarrierName = source.CarrierName,
                     CarrierMode = source.CarrierMode,
                     CarrierTier = source.CarrierTier,
                     HomeCity = source.HomeCity,
                     HomeStateProvince = source.HomeStateProvince,
                     ActiveFlag = source.ActiveFlag,
                     UpdatedAt = SYSUTCDATETIME()
        WHEN NOT MATCHED BY TARGET
            THEN INSERT
            (
                CarrierCode,
                SCACCode,
                CarrierName,
                CarrierMode,
                CarrierTier,
                HomeCity,
                HomeStateProvince,
                ActiveFlag
            )
            VALUES
            (
                source.CarrierCode,
                source.SCACCode,
                source.CarrierName,
                source.CarrierMode,
                source.CarrierTier,
                source.HomeCity,
                source.HomeStateProvince,
                source.ActiveFlag
            )
        OUTPUT $action INTO @CarrierMergeActions(ActionName);

        MERGE dw.DimLocation AS target
        USING #LocationSource AS source
            ON target.LocationCode = source.LocationCode
        WHEN MATCHED AND EXISTS
        (
            SELECT
                target.LocationName,
                target.LocationType,
                target.AddressLine1,
                target.City,
                target.StateProvince,
                target.CountryCode,
                target.PostalCode,
                target.Region,
                target.Latitude,
                target.Longitude,
                target.ActiveFlag
            EXCEPT
            SELECT
                source.LocationName,
                source.LocationType,
                source.AddressLine1,
                source.City,
                source.StateProvince,
                source.CountryCode,
                source.PostalCode,
                source.Region,
                source.Latitude,
                source.Longitude,
                source.ActiveFlag
        )
            THEN UPDATE
                 SET LocationName = source.LocationName,
                     LocationType = source.LocationType,
                     AddressLine1 = source.AddressLine1,
                     City = source.City,
                     StateProvince = source.StateProvince,
                     CountryCode = source.CountryCode,
                     PostalCode = source.PostalCode,
                     Region = source.Region,
                     Latitude = source.Latitude,
                     Longitude = source.Longitude,
                     ActiveFlag = source.ActiveFlag,
                     UpdatedAt = SYSUTCDATETIME()
        WHEN NOT MATCHED BY TARGET
            THEN INSERT
            (
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
                ActiveFlag
            )
            VALUES
            (
                source.LocationCode,
                source.LocationName,
                source.LocationType,
                source.AddressLine1,
                source.City,
                source.StateProvince,
                source.CountryCode,
                source.PostalCode,
                source.Region,
                source.Latitude,
                source.Longitude,
                source.ActiveFlag
            )
        OUTPUT $action INTO @LocationMergeActions(ActionName);

        MERGE dw.DimRoute AS target
        USING #RouteSource AS source
            ON target.RouteCode = source.RouteCode
        WHEN MATCHED AND EXISTS
        (
            SELECT
                target.OriginLocationCode,
                target.DestinationLocationCode,
                target.RouteType,
                target.PlannedDistanceMiles,
                target.PlannedTransitHours,
                target.ReferenceDistanceMiles,
                target.ReferenceTransitHours,
                target.FuelZone,
                target.ActiveFlag,
                target.EffectiveStartDate,
                target.EffectiveEndDate
            EXCEPT
            SELECT
                source.OriginLocationCode,
                source.DestinationLocationCode,
                source.RouteType,
                source.PlannedDistanceMiles,
                source.PlannedTransitHours,
                source.ReferenceDistanceMiles,
                source.ReferenceTransitHours,
                source.FuelZone,
                source.ActiveFlag,
                source.EffectiveStartDate,
                source.EffectiveEndDate
        )
            THEN UPDATE
                 SET OriginLocationCode = source.OriginLocationCode,
                     DestinationLocationCode = source.DestinationLocationCode,
                     RouteType = source.RouteType,
                     PlannedDistanceMiles = source.PlannedDistanceMiles,
                     PlannedTransitHours = source.PlannedTransitHours,
                     ReferenceDistanceMiles = source.ReferenceDistanceMiles,
                     ReferenceTransitHours = source.ReferenceTransitHours,
                     FuelZone = source.FuelZone,
                     ActiveFlag = source.ActiveFlag,
                     EffectiveStartDate = source.EffectiveStartDate,
                     EffectiveEndDate = source.EffectiveEndDate,
                     UpdatedAt = SYSUTCDATETIME()
        WHEN NOT MATCHED BY TARGET
            THEN INSERT
            (
                RouteCode,
                OriginLocationCode,
                DestinationLocationCode,
                RouteType,
                PlannedDistanceMiles,
                PlannedTransitHours,
                ReferenceDistanceMiles,
                ReferenceTransitHours,
                FuelZone,
                ActiveFlag,
                EffectiveStartDate,
                EffectiveEndDate
            )
            VALUES
            (
                source.RouteCode,
                source.OriginLocationCode,
                source.DestinationLocationCode,
                source.RouteType,
                source.PlannedDistanceMiles,
                source.PlannedTransitHours,
                source.ReferenceDistanceMiles,
                source.ReferenceTransitHours,
                source.FuelZone,
                source.ActiveFlag,
                source.EffectiveStartDate,
                source.EffectiveEndDate
            )
        OUTPUT $action INTO @RouteMergeActions(ActionName);

        MERGE dw.DimDeliveryException AS target
        USING #ExceptionSource AS source
            ON target.ExceptionCode = source.ExceptionCode
        WHEN MATCHED AND EXISTS
        (
            SELECT
                target.ExceptionDescription,
                target.ExceptionCategory,
                target.SeverityCode,
                target.TypicalDelayMinutes,
                target.ResponsibleParty,
                target.ActiveFlag
            EXCEPT
            SELECT
                source.ExceptionDescription,
                source.ExceptionCategory,
                source.SeverityCode,
                source.TypicalDelayMinutes,
                source.ResponsibleParty,
                source.ActiveFlag
        )
            THEN UPDATE
                 SET ExceptionDescription = source.ExceptionDescription,
                     ExceptionCategory = source.ExceptionCategory,
                     SeverityCode = source.SeverityCode,
                     TypicalDelayMinutes = source.TypicalDelayMinutes,
                     ResponsibleParty = source.ResponsibleParty,
                     ActiveFlag = source.ActiveFlag,
                     UpdatedAt = SYSUTCDATETIME()
        WHEN NOT MATCHED BY TARGET
            THEN INSERT
            (
                ExceptionCode,
                ExceptionDescription,
                ExceptionCategory,
                SeverityCode,
                TypicalDelayMinutes,
                ResponsibleParty,
                ActiveFlag
            )
            VALUES
            (
                source.ExceptionCode,
                source.ExceptionDescription,
                source.ExceptionCategory,
                source.SeverityCode,
                source.TypicalDelayMinutes,
                source.ResponsibleParty,
                source.ActiveFlag
            )
        OUTPUT $action INTO @ExceptionMergeActions(ActionName);

        MERGE dw.DimShipmentStatus AS target
        USING #ShipmentStatusSource AS source
            ON target.StatusCode = source.StatusCode
        WHEN MATCHED AND EXISTS
        (
            SELECT
                target.StatusDescription,
                target.StatusGroup,
                target.StatusSortOrder,
                target.IsTerminalStatus,
                target.IsExceptionStatus,
                target.ActiveFlag
            EXCEPT
            SELECT
                source.StatusDescription,
                source.StatusGroup,
                source.StatusSortOrder,
                source.IsTerminalStatus,
                source.IsExceptionStatus,
                source.ActiveFlag
        )
            THEN UPDATE
                 SET StatusDescription = source.StatusDescription,
                     StatusGroup = source.StatusGroup,
                     StatusSortOrder = source.StatusSortOrder,
                     IsTerminalStatus = source.IsTerminalStatus,
                     IsExceptionStatus = source.IsExceptionStatus,
                     ActiveFlag = source.ActiveFlag,
                     UpdatedAt = SYSUTCDATETIME()
        WHEN NOT MATCHED BY TARGET
            THEN INSERT
            (
                StatusCode,
                StatusDescription,
                StatusGroup,
                StatusSortOrder,
                IsTerminalStatus,
                IsExceptionStatus,
                ActiveFlag
            )
            VALUES
            (
                source.StatusCode,
                source.StatusDescription,
                source.StatusGroup,
                source.StatusSortOrder,
                source.IsTerminalStatus,
                source.IsExceptionStatus,
                source.ActiveFlag
            )
        OUTPUT $action INTO @ShipmentStatusMergeActions(ActionName);

        SELECT @RowsInserted =
            ISNULL((SELECT COUNT(*) FROM @CarrierMergeActions WHERE ActionName = N'INSERT'), 0)
          + ISNULL((SELECT COUNT(*) FROM @LocationMergeActions WHERE ActionName = N'INSERT'), 0)
          + ISNULL((SELECT COUNT(*) FROM @RouteMergeActions WHERE ActionName = N'INSERT'), 0)
          + ISNULL((SELECT COUNT(*) FROM @ExceptionMergeActions WHERE ActionName = N'INSERT'), 0)
          + ISNULL((SELECT COUNT(*) FROM @ShipmentStatusMergeActions WHERE ActionName = N'INSERT'), 0);

        SELECT @RowsUpdated =
            ISNULL((SELECT COUNT(*) FROM @CarrierMergeActions WHERE ActionName = N'UPDATE'), 0)
          + ISNULL((SELECT COUNT(*) FROM @LocationMergeActions WHERE ActionName = N'UPDATE'), 0)
          + ISNULL((SELECT COUNT(*) FROM @RouteMergeActions WHERE ActionName = N'UPDATE'), 0)
          + ISNULL((SELECT COUNT(*) FROM @ExceptionMergeActions WHERE ActionName = N'UPDATE'), 0)
          + ISNULL((SELECT COUNT(*) FROM @ShipmentStatusMergeActions WHERE ActionName = N'UPDATE'), 0);

        UPDATE audit.Load_Audit
        SET RowsInserted = @RowsInserted,
            RowsUpdated = @RowsUpdated,
            CompletedAt = SYSUTCDATETIME(),
            Status = 'SUCCEEDED',
            Message = N'Dimension load completed with standardized business keys and lookup mastering.'
        WHERE LoadAuditID = @AuditID;
    END TRY
    BEGIN CATCH
        EXEC audit.usp_Log_Error
            @BatchID = @BatchID,
            @ProcedureName = N'etl.usp_Load_Dimensions',
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
