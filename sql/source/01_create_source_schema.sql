USE [$(DatabaseName)];
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'src')
BEGIN
    EXEC (N'CREATE SCHEMA src;');
END;
GO

DROP TABLE IF EXISTS src.Delivery_Exception;
GO

DROP TABLE IF EXISTS src.Shipment_Status_History;
GO

DROP TABLE IF EXISTS src.Shipment;
GO

DROP TABLE IF EXISTS src.Route;
GO

DROP TABLE IF EXISTS src.Carrier;
GO

DROP TABLE IF EXISTS src.Location;
GO

CREATE TABLE src.Location
(
    LocationID int IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_src_Location PRIMARY KEY,
    LocationCode nvarchar(30) NOT NULL,
    LocationName nvarchar(200) NOT NULL,
    LocationType nvarchar(50) NOT NULL,
    AddressLine1 nvarchar(200) NOT NULL,
    City nvarchar(100) NOT NULL,
    StateProvince nvarchar(100) NOT NULL,
    CountryCode nvarchar(10) NOT NULL,
    PostalCode nvarchar(20) NOT NULL,
    Region nvarchar(50) NOT NULL,
    Latitude decimal(9, 6) NULL,
    Longitude decimal(9, 6) NULL,
    ActiveFlag bit NOT NULL
        CONSTRAINT DF_src_Location_ActiveFlag DEFAULT 1,
    CreatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_src_Location_CreatedAt DEFAULT SYSUTCDATETIME(),
    ModifiedAt datetime2(0) NOT NULL
        CONSTRAINT DF_src_Location_ModifiedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_src_Location_LocationCode UNIQUE (LocationCode)
);
GO

CREATE TABLE src.Carrier
(
    CarrierID int IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_src_Carrier PRIMARY KEY,
    CarrierCode nvarchar(30) NOT NULL,
    SCACCode nvarchar(10) NOT NULL,
    CarrierName nvarchar(200) NOT NULL,
    CarrierMode nvarchar(50) NOT NULL,
    CarrierTier nvarchar(30) NOT NULL,
    HomeCity nvarchar(100) NULL,
    HomeStateProvince nvarchar(100) NULL,
    ActiveFlag bit NOT NULL
        CONSTRAINT DF_src_Carrier_ActiveFlag DEFAULT 1,
    CreatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_src_Carrier_CreatedAt DEFAULT SYSUTCDATETIME(),
    ModifiedAt datetime2(0) NOT NULL
        CONSTRAINT DF_src_Carrier_ModifiedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_src_Carrier_CarrierCode UNIQUE (CarrierCode),
    CONSTRAINT UQ_src_Carrier_SCACCode UNIQUE (SCACCode)
);
GO

CREATE TABLE src.Route
(
    RouteID int IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_src_Route PRIMARY KEY,
    RouteCode nvarchar(30) NOT NULL,
    OriginLocationID int NOT NULL,
    DestinationLocationID int NOT NULL,
    RouteType nvarchar(50) NOT NULL,
    StandardDistanceMiles decimal(10, 2) NOT NULL,
    StandardTransitHours decimal(10, 2) NOT NULL,
    ActiveFlag bit NOT NULL
        CONSTRAINT DF_src_Route_ActiveFlag DEFAULT 1,
    EffectiveStartDate date NOT NULL,
    EffectiveEndDate date NULL,
    ModifiedAt datetime2(0) NOT NULL
        CONSTRAINT DF_src_Route_ModifiedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_src_Route_RouteCode UNIQUE (RouteCode),
    CONSTRAINT FK_src_Route_OriginLocation
        FOREIGN KEY (OriginLocationID) REFERENCES src.Location(LocationID),
    CONSTRAINT FK_src_Route_DestinationLocation
        FOREIGN KEY (DestinationLocationID) REFERENCES src.Location(LocationID)
);
GO

CREATE TABLE src.Shipment
(
    ShipmentID bigint IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_src_Shipment PRIMARY KEY,
    ShipmentNumber nvarchar(50) NOT NULL,
    CarrierID int NOT NULL,
    RouteID int NOT NULL,
    OriginLocationID int NOT NULL,
    DestinationLocationID int NOT NULL,
    CustomerReferenceNumber nvarchar(50) NOT NULL,
    ServiceLevel nvarchar(30) NOT NULL,
    CurrentStatus nvarchar(30) NOT NULL,
    ShipmentCreateDateTime datetime2(0) NOT NULL,
    PlannedPickupDateTime datetime2(0) NOT NULL,
    ActualPickupDateTime datetime2(0) NULL,
    PlannedDeliveryDateTime datetime2(0) NOT NULL,
    ActualDeliveryDateTime datetime2(0) NULL,
    WeightLbs decimal(10, 2) NOT NULL,
    PieceCount int NOT NULL,
    ShipmentRevenue decimal(12, 2) NOT NULL,
    ShipmentCost decimal(12, 2) NOT NULL,
    PlannedDistanceMiles decimal(10, 2) NOT NULL,
    ActualDistanceMiles decimal(10, 2) NULL,
    SourceModifiedAt datetime2(0) NOT NULL,
    CreatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_src_Shipment_CreatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_src_Shipment_ShipmentNumber UNIQUE (ShipmentNumber),
    CONSTRAINT FK_src_Shipment_Carrier
        FOREIGN KEY (CarrierID) REFERENCES src.Carrier(CarrierID),
    CONSTRAINT FK_src_Shipment_Route
        FOREIGN KEY (RouteID) REFERENCES src.Route(RouteID),
    CONSTRAINT FK_src_Shipment_OriginLocation
        FOREIGN KEY (OriginLocationID) REFERENCES src.Location(LocationID),
    CONSTRAINT FK_src_Shipment_DestinationLocation
        FOREIGN KEY (DestinationLocationID) REFERENCES src.Location(LocationID)
);
GO

CREATE TABLE src.Shipment_Status_History
(
    ShipmentStatusHistoryID bigint IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_src_Shipment_Status_History PRIMARY KEY,
    ShipmentID bigint NOT NULL,
    EventSequenceNumber int NOT NULL,
    StatusCode nvarchar(30) NOT NULL,
    StatusDescription nvarchar(200) NOT NULL,
    EventDateTime datetime2(0) NOT NULL,
    LocationID int NULL,
    ScanType nvarchar(30) NOT NULL,
    EventSource nvarchar(30) NOT NULL,
    ExceptionCode nvarchar(30) NULL,
    Notes nvarchar(500) NULL,
    CONSTRAINT UQ_src_Shipment_Status_History UNIQUE (ShipmentID, EventSequenceNumber),
    CONSTRAINT FK_src_Shipment_Status_History_Shipment
        FOREIGN KEY (ShipmentID) REFERENCES src.Shipment(ShipmentID),
    CONSTRAINT FK_src_Shipment_Status_History_Location
        FOREIGN KEY (LocationID) REFERENCES src.Location(LocationID)
);
GO

CREATE TABLE src.Delivery_Exception
(
    DeliveryExceptionID bigint IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_src_Delivery_Exception PRIMARY KEY,
    ShipmentID bigint NOT NULL,
    ExceptionCode nvarchar(30) NOT NULL,
    ExceptionDescription nvarchar(200) NOT NULL,
    ExceptionCategory nvarchar(50) NOT NULL,
    SeverityCode nvarchar(20) NOT NULL,
    ExceptionStatus nvarchar(20) NOT NULL,
    ExceptionDateTime datetime2(0) NOT NULL,
    ResolvedDateTime datetime2(0) NULL,
    DelayMinutesImpact int NULL,
    ResponsibleParty nvarchar(50) NULL,
    Notes nvarchar(500) NULL,
    CreatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_src_Delivery_Exception_CreatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_src_Delivery_Exception UNIQUE (ShipmentID, ExceptionCode, ExceptionDateTime),
    CONSTRAINT FK_src_Delivery_Exception_Shipment
        FOREIGN KEY (ShipmentID) REFERENCES src.Shipment(ShipmentID)
);
GO

CREATE INDEX IX_src_Route_OriginDestination
    ON src.Route (OriginLocationID, DestinationLocationID);
GO

CREATE INDEX IX_src_Shipment_CurrentStatus
    ON src.Shipment (CurrentStatus);
GO

CREATE INDEX IX_src_Shipment_SourceModifiedAt
    ON src.Shipment (SourceModifiedAt);
GO

CREATE INDEX IX_src_Shipment_Status_History_EventDateTime
    ON src.Shipment_Status_History (EventDateTime);
GO

CREATE INDEX IX_src_Shipment_Status_History_StatusCode
    ON src.Shipment_Status_History (StatusCode);
GO

CREATE INDEX IX_src_Delivery_Exception_ExceptionDateTime
    ON src.Delivery_Exception (ExceptionDateTime);
GO

CREATE INDEX IX_src_Delivery_Exception_ExceptionCode
    ON src.Delivery_Exception (ExceptionCode);
GO

