USE [$(DatabaseName)];
GO

CREATE TABLE stg.Carrier_Raw
(
    StageCarrierID int IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_Carrier_Raw PRIMARY KEY,
    BatchID int NOT NULL,
    CarrierCode nvarchar(30) NULL,
    SCACCode nvarchar(10) NULL,
    CarrierName nvarchar(200) NULL,
    CarrierMode nvarchar(50) NULL,
    CarrierTier nvarchar(30) NULL,
    HomeCity nvarchar(100) NULL,
    HomeStateProvince nvarchar(100) NULL,
    ActiveFlag bit NOT NULL
        CONSTRAINT DF_Carrier_Raw_ActiveFlag DEFAULT 1,
    SourceName nvarchar(100) NOT NULL
        CONSTRAINT DF_Carrier_Raw_SourceName DEFAULT N'UNKNOWN',
    SourceFileName nvarchar(260) NULL,
    SourceLoadedAt datetime2(0) NOT NULL
        CONSTRAINT DF_Carrier_Raw_SourceLoadedAt DEFAULT SYSUTCDATETIME(),
    IsValid bit NOT NULL
        CONSTRAINT DF_Carrier_Raw_IsValid DEFAULT 1,
    ValidationStatus varchar(20) NOT NULL
        CONSTRAINT DF_Carrier_Raw_ValidationStatus DEFAULT 'PENDING',
    RejectionReason nvarchar(1000) NULL,
    CONSTRAINT FK_Carrier_Raw_Batch_Run
        FOREIGN KEY (BatchID) REFERENCES meta.Batch_Run(BatchID)
);
GO

CREATE INDEX IX_Carrier_Raw_BatchID ON stg.Carrier_Raw (BatchID);
GO

CREATE TABLE stg.Location_Raw
(
    StageLocationID int IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_Location_Raw PRIMARY KEY,
    BatchID int NOT NULL,
    LocationCode nvarchar(30) NULL,
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
        CONSTRAINT DF_Location_Raw_ActiveFlag DEFAULT 1,
    SourceName nvarchar(100) NOT NULL
        CONSTRAINT DF_Location_Raw_SourceName DEFAULT N'UNKNOWN',
    SourceFileName nvarchar(260) NULL,
    SourceLoadedAt datetime2(0) NOT NULL
        CONSTRAINT DF_Location_Raw_SourceLoadedAt DEFAULT SYSUTCDATETIME(),
    IsValid bit NOT NULL
        CONSTRAINT DF_Location_Raw_IsValid DEFAULT 1,
    ValidationStatus varchar(20) NOT NULL
        CONSTRAINT DF_Location_Raw_ValidationStatus DEFAULT 'PENDING',
    RejectionReason nvarchar(1000) NULL,
    CONSTRAINT FK_Location_Raw_Batch_Run
        FOREIGN KEY (BatchID) REFERENCES meta.Batch_Run(BatchID)
);
GO

CREATE INDEX IX_Location_Raw_BatchID ON stg.Location_Raw (BatchID);
GO

CREATE TABLE stg.Route_Raw
(
    StageRouteID int IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_Route_Raw PRIMARY KEY,
    BatchID int NOT NULL,
    RouteCode nvarchar(30) NULL,
    OriginLocationCode nvarchar(30) NULL,
    DestinationLocationCode nvarchar(30) NULL,
    RouteType nvarchar(50) NULL,
    PlannedDistanceMiles decimal(10, 2) NULL,
    PlannedTransitHours decimal(10, 2) NULL,
    ActiveFlag bit NOT NULL
        CONSTRAINT DF_Route_Raw_ActiveFlag DEFAULT 1,
    EffectiveStartDate date NULL,
    EffectiveEndDate date NULL,
    SourceName nvarchar(100) NOT NULL
        CONSTRAINT DF_Route_Raw_SourceName DEFAULT N'UNKNOWN',
    SourceFileName nvarchar(260) NULL,
    SourceLoadedAt datetime2(0) NOT NULL
        CONSTRAINT DF_Route_Raw_SourceLoadedAt DEFAULT SYSUTCDATETIME(),
    IsValid bit NOT NULL
        CONSTRAINT DF_Route_Raw_IsValid DEFAULT 1,
    ValidationStatus varchar(20) NOT NULL
        CONSTRAINT DF_Route_Raw_ValidationStatus DEFAULT 'PENDING',
    RejectionReason nvarchar(1000) NULL,
    CONSTRAINT FK_Route_Raw_Batch_Run
        FOREIGN KEY (BatchID) REFERENCES meta.Batch_Run(BatchID)
);
GO

CREATE INDEX IX_Route_Raw_BatchID ON stg.Route_Raw (BatchID);
GO

CREATE TABLE stg.Shipment_Raw
(
    StageShipmentID int IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_Shipment_Raw PRIMARY KEY,
    BatchID int NOT NULL,
    ShipmentNumber nvarchar(50) NULL,
    CarrierCode nvarchar(30) NULL,
    RouteCode nvarchar(30) NULL,
    OriginLocationCode nvarchar(30) NULL,
    DestinationLocationCode nvarchar(30) NULL,
    CustomerReferenceNumber nvarchar(50) NULL,
    ShipmentStatus nvarchar(30) NULL,
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
    SourceModifiedAt datetime2(0) NULL,
    SourceName nvarchar(100) NOT NULL
        CONSTRAINT DF_Shipment_Raw_SourceName DEFAULT N'UNKNOWN',
    SourceFileName nvarchar(260) NULL,
    SourceLoadedAt datetime2(0) NOT NULL
        CONSTRAINT DF_Shipment_Raw_SourceLoadedAt DEFAULT SYSUTCDATETIME(),
    IsValid bit NOT NULL
        CONSTRAINT DF_Shipment_Raw_IsValid DEFAULT 1,
    ValidationStatus varchar(20) NOT NULL
        CONSTRAINT DF_Shipment_Raw_ValidationStatus DEFAULT 'PENDING',
    RejectionReason nvarchar(1000) NULL,
    CONSTRAINT FK_Shipment_Raw_Batch_Run
        FOREIGN KEY (BatchID) REFERENCES meta.Batch_Run(BatchID)
);
GO

CREATE INDEX IX_Shipment_Raw_BatchID ON stg.Shipment_Raw (BatchID);
GO

CREATE INDEX IX_Shipment_Raw_ShipmentNumber ON stg.Shipment_Raw (ShipmentNumber);
GO

CREATE TABLE stg.Shipment_Status_History_Raw
(
    StageShipmentStatusHistoryID int IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_Shipment_Status_History_Raw PRIMARY KEY,
    BatchID int NOT NULL,
    ShipmentNumber nvarchar(50) NULL,
    EventSequenceNumber int NULL,
    StatusCode nvarchar(30) NULL,
    StatusDescription nvarchar(200) NULL,
    EventDateTime datetime2(0) NULL,
    LocationCode nvarchar(30) NULL,
    ScanType nvarchar(30) NULL,
    EventSource nvarchar(30) NULL,
    ExceptionCode nvarchar(30) NULL,
    Notes nvarchar(500) NULL,
    SourceName nvarchar(100) NOT NULL
        CONSTRAINT DF_Shipment_Status_History_Raw_SourceName DEFAULT N'UNKNOWN',
    SourceFileName nvarchar(260) NULL,
    SourceLoadedAt datetime2(0) NOT NULL
        CONSTRAINT DF_Shipment_Status_History_Raw_SourceLoadedAt DEFAULT SYSUTCDATETIME(),
    IsValid bit NOT NULL
        CONSTRAINT DF_Shipment_Status_History_Raw_IsValid DEFAULT 1,
    ValidationStatus varchar(20) NOT NULL
        CONSTRAINT DF_Shipment_Status_History_Raw_ValidationStatus DEFAULT 'PENDING',
    RejectionReason nvarchar(1000) NULL,
    CONSTRAINT FK_Shipment_Status_History_Raw_Batch_Run
        FOREIGN KEY (BatchID) REFERENCES meta.Batch_Run(BatchID)
);
GO

CREATE INDEX IX_Shipment_Status_History_Raw_BatchID ON stg.Shipment_Status_History_Raw (BatchID);
GO

CREATE INDEX IX_Shipment_Status_History_Raw_ShipmentNumber
    ON stg.Shipment_Status_History_Raw (ShipmentNumber);
GO

CREATE TABLE stg.Delivery_Exception_Raw
(
    StageDeliveryExceptionID int IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_Delivery_Exception_Raw PRIMARY KEY,
    BatchID int NOT NULL,
    ShipmentNumber nvarchar(50) NULL,
    ExceptionCode nvarchar(30) NULL,
    ExceptionDescription nvarchar(200) NULL,
    ExceptionCategory nvarchar(50) NULL,
    SeverityCode nvarchar(20) NULL,
    ExceptionStatus nvarchar(20) NULL,
    ExceptionDateTime datetime2(0) NULL,
    DelayMinutesImpact int NULL,
    ResolvedDateTime datetime2(0) NULL,
    ResponsibleParty nvarchar(50) NULL,
    Notes nvarchar(500) NULL,
    SourceName nvarchar(100) NOT NULL
        CONSTRAINT DF_Delivery_Exception_Raw_SourceName DEFAULT N'UNKNOWN',
    SourceFileName nvarchar(260) NULL,
    SourceLoadedAt datetime2(0) NOT NULL
        CONSTRAINT DF_Delivery_Exception_Raw_SourceLoadedAt DEFAULT SYSUTCDATETIME(),
    IsValid bit NOT NULL
        CONSTRAINT DF_Delivery_Exception_Raw_IsValid DEFAULT 1,
    ValidationStatus varchar(20) NOT NULL
        CONSTRAINT DF_Delivery_Exception_Raw_ValidationStatus DEFAULT 'PENDING',
    RejectionReason nvarchar(1000) NULL,
    CONSTRAINT FK_Delivery_Exception_Raw_Batch_Run
        FOREIGN KEY (BatchID) REFERENCES meta.Batch_Run(BatchID)
);
GO

CREATE INDEX IX_Delivery_Exception_Raw_BatchID ON stg.Delivery_Exception_Raw (BatchID);
GO

CREATE INDEX IX_Delivery_Exception_Raw_ShipmentNumber ON stg.Delivery_Exception_Raw (ShipmentNumber);
GO

CREATE TABLE stg.Exception_Code_Lookup_Raw
(
    StageExceptionCodeLookupID int IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_Exception_Code_Lookup_Raw PRIMARY KEY,
    BatchID int NOT NULL,
    ExceptionCode nvarchar(30) NULL,
    ExceptionDescription nvarchar(200) NULL,
    ExceptionCategory nvarchar(50) NULL,
    SeverityCode nvarchar(20) NULL,
    TypicalDelayMinutes int NULL,
    ResponsibleParty nvarchar(50) NULL,
    ActiveFlag bit NOT NULL
        CONSTRAINT DF_Exception_Code_Lookup_Raw_ActiveFlag DEFAULT 1,
    SourceName nvarchar(100) NOT NULL
        CONSTRAINT DF_Exception_Code_Lookup_Raw_SourceName DEFAULT N'UNKNOWN',
    SourceFileName nvarchar(260) NULL,
    SourceLoadedAt datetime2(0) NOT NULL
        CONSTRAINT DF_Exception_Code_Lookup_Raw_SourceLoadedAt DEFAULT SYSUTCDATETIME(),
    IsValid bit NOT NULL
        CONSTRAINT DF_Exception_Code_Lookup_Raw_IsValid DEFAULT 1,
    ValidationStatus varchar(20) NOT NULL
        CONSTRAINT DF_Exception_Code_Lookup_Raw_ValidationStatus DEFAULT 'PENDING',
    RejectionReason nvarchar(1000) NULL,
    CONSTRAINT FK_Exception_Code_Lookup_Raw_Batch_Run
        FOREIGN KEY (BatchID) REFERENCES meta.Batch_Run(BatchID)
);
GO

CREATE INDEX IX_Exception_Code_Lookup_Raw_BatchID
    ON stg.Exception_Code_Lookup_Raw (BatchID);
GO

CREATE TABLE stg.Route_Distance_Reference_Raw
(
    StageRouteDistanceReferenceID int IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_Route_Distance_Reference_Raw PRIMARY KEY,
    BatchID int NOT NULL,
    RouteCode nvarchar(30) NULL,
    OriginLocationCode nvarchar(30) NULL,
    DestinationLocationCode nvarchar(30) NULL,
    ReferenceDistanceMiles decimal(10, 2) NULL,
    ReferenceTransitHours decimal(10, 2) NULL,
    RouteType nvarchar(50) NULL,
    FuelZone nvarchar(30) NULL,
    SourceName nvarchar(100) NOT NULL
        CONSTRAINT DF_Route_Distance_Reference_Raw_SourceName DEFAULT N'UNKNOWN',
    SourceFileName nvarchar(260) NULL,
    SourceLoadedAt datetime2(0) NOT NULL
        CONSTRAINT DF_Route_Distance_Reference_Raw_SourceLoadedAt DEFAULT SYSUTCDATETIME(),
    IsValid bit NOT NULL
        CONSTRAINT DF_Route_Distance_Reference_Raw_IsValid DEFAULT 1,
    ValidationStatus varchar(20) NOT NULL
        CONSTRAINT DF_Route_Distance_Reference_Raw_ValidationStatus DEFAULT 'PENDING',
    RejectionReason nvarchar(1000) NULL,
    CONSTRAINT FK_Route_Distance_Reference_Raw_Batch_Run
        FOREIGN KEY (BatchID) REFERENCES meta.Batch_Run(BatchID)
);
GO

CREATE INDEX IX_Route_Distance_Reference_Raw_BatchID
    ON stg.Route_Distance_Reference_Raw (BatchID);
GO

