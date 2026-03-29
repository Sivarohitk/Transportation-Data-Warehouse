USE [$(DatabaseName)];
GO

CREATE TABLE dw.DimDate
(
    DateKey int NOT NULL
        CONSTRAINT PK_DimDate PRIMARY KEY,
    FullDate date NULL,
    CalendarYear smallint NULL,
    CalendarQuarter tinyint NULL,
    CalendarMonth tinyint NULL,
    MonthName nvarchar(20) NULL,
    DayOfMonth tinyint NULL,
    DayName nvarchar(20) NULL,
    WeekOfYear tinyint NULL,
    IsWeekend bit NOT NULL
        CONSTRAINT DF_DimDate_IsWeekend DEFAULT 0
);
GO

CREATE TABLE dw.DimCarrier
(
    CarrierKey int IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_DimCarrier PRIMARY KEY,
    CarrierCode nvarchar(30) NOT NULL,
    SCACCode nvarchar(10) NULL,
    CarrierName nvarchar(200) NOT NULL,
    CarrierMode nvarchar(50) NULL,
    CarrierTier nvarchar(30) NULL,
    HomeCity nvarchar(100) NULL,
    HomeStateProvince nvarchar(100) NULL,
    ActiveFlag bit NOT NULL
        CONSTRAINT DF_DimCarrier_ActiveFlag DEFAULT 1,
    CreatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_DimCarrier_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_DimCarrier_UpdatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_DimCarrier_CarrierCode UNIQUE (CarrierCode)
);
GO

CREATE TABLE dw.DimLocation
(
    LocationKey int IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_DimLocation PRIMARY KEY,
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
        CONSTRAINT DF_DimLocation_ActiveFlag DEFAULT 1,
    CreatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_DimLocation_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_DimLocation_UpdatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_DimLocation_LocationCode UNIQUE (LocationCode)
);
GO

CREATE TABLE dw.DimRoute
(
    RouteKey int IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_DimRoute PRIMARY KEY,
    RouteCode nvarchar(30) NOT NULL,
    OriginLocationCode nvarchar(30) NULL,
    DestinationLocationCode nvarchar(30) NULL,
    RouteType nvarchar(50) NULL,
    PlannedDistanceMiles decimal(10, 2) NULL,
    PlannedTransitHours decimal(10, 2) NULL,
    ReferenceDistanceMiles decimal(10, 2) NULL,
    ReferenceTransitHours decimal(10, 2) NULL,
    FuelZone nvarchar(30) NULL,
    ActiveFlag bit NOT NULL
        CONSTRAINT DF_DimRoute_ActiveFlag DEFAULT 1,
    EffectiveStartDate date NULL,
    EffectiveEndDate date NULL,
    CreatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_DimRoute_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_DimRoute_UpdatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_DimRoute_RouteCode UNIQUE (RouteCode)
);
GO

CREATE TABLE dw.DimDeliveryException
(
    DeliveryExceptionKey int IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_DimDeliveryException PRIMARY KEY,
    ExceptionCode nvarchar(30) NOT NULL,
    ExceptionDescription nvarchar(200) NULL,
    ExceptionCategory nvarchar(50) NULL,
    SeverityCode nvarchar(20) NULL,
    TypicalDelayMinutes int NULL,
    ResponsibleParty nvarchar(50) NULL,
    ActiveFlag bit NOT NULL
        CONSTRAINT DF_DimDeliveryException_ActiveFlag DEFAULT 1,
    CreatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_DimDeliveryException_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_DimDeliveryException_UpdatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_DimDeliveryException_ExceptionCode UNIQUE (ExceptionCode)
);
GO

CREATE TABLE dw.DimShipmentStatus
(
    ShipmentStatusKey int IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_DimShipmentStatus PRIMARY KEY,
    StatusCode nvarchar(30) NOT NULL,
    StatusDescription nvarchar(200) NOT NULL,
    StatusGroup nvarchar(50) NULL,
    StatusSortOrder int NOT NULL
        CONSTRAINT DF_DimShipmentStatus_StatusSortOrder DEFAULT 999,
    IsTerminalStatus bit NOT NULL
        CONSTRAINT DF_DimShipmentStatus_IsTerminalStatus DEFAULT 0,
    IsExceptionStatus bit NOT NULL
        CONSTRAINT DF_DimShipmentStatus_IsExceptionStatus DEFAULT 0,
    ActiveFlag bit NOT NULL
        CONSTRAINT DF_DimShipmentStatus_ActiveFlag DEFAULT 1,
    CreatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_DimShipmentStatus_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_DimShipmentStatus_UpdatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_DimShipmentStatus_StatusCode UNIQUE (StatusCode)
);
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimDate WHERE DateKey = 0)
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
    (0, NULL, NULL, NULL, NULL, N'Unknown', NULL, N'Unknown', NULL, 0);
END;
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimCarrier WHERE CarrierKey = 0)
BEGIN
    SET IDENTITY_INSERT dw.DimCarrier ON;

    INSERT INTO dw.DimCarrier
    (
        CarrierKey,
        CarrierCode,
        SCACCode,
        CarrierName,
        CarrierMode,
        CarrierTier,
        HomeCity,
        HomeStateProvince,
        ActiveFlag,
        CreatedAt,
        UpdatedAt
    )
    VALUES
    (0, N'UNKNOWN', N'UNKN', N'Unknown Carrier', N'Unknown', N'Unknown', N'Unknown', N'Unknown', 1, SYSUTCDATETIME(), SYSUTCDATETIME());

    SET IDENTITY_INSERT dw.DimCarrier OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimLocation WHERE LocationKey = 0)
BEGIN
    SET IDENTITY_INSERT dw.DimLocation ON;

    INSERT INTO dw.DimLocation
    (
        LocationKey,
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
        CreatedAt,
        UpdatedAt
    )
    VALUES
    (0, N'UNKNOWN', N'Unknown Location', N'Unknown', N'Unknown', N'Unknown', N'Unknown', N'UNK', N'00000', N'Unknown', NULL, NULL, 1, SYSUTCDATETIME(), SYSUTCDATETIME());

    SET IDENTITY_INSERT dw.DimLocation OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimRoute WHERE RouteKey = 0)
BEGIN
    SET IDENTITY_INSERT dw.DimRoute ON;

    INSERT INTO dw.DimRoute
    (
        RouteKey,
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
        EffectiveEndDate,
        CreatedAt,
        UpdatedAt
    )
    VALUES
    (0, N'UNKNOWN', N'UNKNOWN', N'UNKNOWN', N'Unknown', 0.00, 0.00, 0.00, 0.00, N'Unknown', 1, NULL, NULL, SYSUTCDATETIME(), SYSUTCDATETIME());

    SET IDENTITY_INSERT dw.DimRoute OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimDeliveryException WHERE DeliveryExceptionKey = 0)
BEGIN
    SET IDENTITY_INSERT dw.DimDeliveryException ON;

    INSERT INTO dw.DimDeliveryException
    (
        DeliveryExceptionKey,
        ExceptionCode,
        ExceptionDescription,
        ExceptionCategory,
        SeverityCode,
        TypicalDelayMinutes,
        ResponsibleParty,
        ActiveFlag,
        CreatedAt,
        UpdatedAt
    )
    VALUES
    (0, N'UNKNOWN', N'Unknown Exception', N'Unknown', N'Unknown', 0, N'Unknown', 1, SYSUTCDATETIME(), SYSUTCDATETIME());

    SET IDENTITY_INSERT dw.DimDeliveryException OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimShipmentStatus WHERE ShipmentStatusKey = 0)
BEGIN
    SET IDENTITY_INSERT dw.DimShipmentStatus ON;

    INSERT INTO dw.DimShipmentStatus
    (
        ShipmentStatusKey,
        StatusCode,
        StatusDescription,
        StatusGroup,
        StatusSortOrder,
        IsTerminalStatus,
        IsExceptionStatus,
        ActiveFlag,
        CreatedAt,
        UpdatedAt
    )
    VALUES
    (0, N'UNKNOWN', N'Unknown shipment status', N'Unknown', 999, 0, 0, 1, SYSUTCDATETIME(), SYSUTCDATETIME());

    SET IDENTITY_INSERT dw.DimShipmentStatus OFF;
END;
GO
