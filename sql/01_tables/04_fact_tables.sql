USE [$(DatabaseName)];
GO

CREATE TABLE dw.FactShipment
(
    ShipmentFactKey bigint IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_FactShipment PRIMARY KEY,
    ShipmentNumber nvarchar(50) NOT NULL,
    OrderDateKey int NOT NULL
        CONSTRAINT DF_FactShipment_OrderDateKey DEFAULT 0,
    PlannedPickupDateKey int NOT NULL
        CONSTRAINT DF_FactShipment_PlannedPickupDateKey DEFAULT 0,
    ActualPickupDateKey int NOT NULL
        CONSTRAINT DF_FactShipment_ActualPickupDateKey DEFAULT 0,
    PlannedDeliveryDateKey int NOT NULL
        CONSTRAINT DF_FactShipment_PlannedDeliveryDateKey DEFAULT 0,
    ActualDeliveryDateKey int NOT NULL
        CONSTRAINT DF_FactShipment_ActualDeliveryDateKey DEFAULT 0,
    ShipmentStatusKey int NOT NULL
        CONSTRAINT DF_FactShipment_ShipmentStatusKey DEFAULT 0,
    CarrierKey int NOT NULL
        CONSTRAINT DF_FactShipment_CarrierKey DEFAULT 0,
    RouteKey int NOT NULL
        CONSTRAINT DF_FactShipment_RouteKey DEFAULT 0,
    OriginLocationKey int NOT NULL
        CONSTRAINT DF_FactShipment_OriginLocationKey DEFAULT 0,
    DestinationLocationKey int NOT NULL
        CONSTRAINT DF_FactShipment_DestinationLocationKey DEFAULT 0,
    ShipmentStatus nvarchar(30) NOT NULL,
    ServiceLevel nvarchar(30) NULL,
    WeightLbs decimal(10, 2) NULL,
    PieceCount int NULL,
    ShipmentRevenue decimal(12, 2) NULL,
    ShipmentCost decimal(12, 2) NULL,
    PlannedDistanceMiles decimal(10, 2) NULL,
    ActualDistanceMiles decimal(10, 2) NULL,
    TransitHours decimal(12, 2) NULL,
    TransitDays decimal(12, 2) NULL,
    DeliveryDelayMinutes int NULL,
    OnTimeDeliveryFlag bit NOT NULL,
    LateDeliveryFlag bit NOT NULL
        CONSTRAINT DF_FactShipment_LateDeliveryFlag DEFAULT 0,
    ShipmentCount int NOT NULL
        CONSTRAINT DF_FactShipment_ShipmentCount DEFAULT 1,
    ScanEventCount int NOT NULL
        CONSTRAINT DF_FactShipment_ScanEventCount DEFAULT 0,
    ExceptionCount int NOT NULL
        CONSTRAINT DF_FactShipment_ExceptionCount DEFAULT 0,
    ExceptionShipmentFlag bit NOT NULL
        CONSTRAINT DF_FactShipment_ExceptionShipmentFlag DEFAULT 0,
    BatchID int NOT NULL,
    SourceModifiedAt datetime2(0) NULL,
    CreatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_FactShipment_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_FactShipment_UpdatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_FactShipment_ShipmentNumber UNIQUE (ShipmentNumber),
    CONSTRAINT FK_FactShipment_DimDate_OrderDate
        FOREIGN KEY (OrderDateKey) REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactShipment_DimDate_PlannedPickupDate
        FOREIGN KEY (PlannedPickupDateKey) REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactShipment_DimDate_ActualPickupDate
        FOREIGN KEY (ActualPickupDateKey) REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactShipment_DimDate_PlannedDeliveryDate
        FOREIGN KEY (PlannedDeliveryDateKey) REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactShipment_DimDate_ActualDeliveryDate
        FOREIGN KEY (ActualDeliveryDateKey) REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactShipment_DimShipmentStatus
        FOREIGN KEY (ShipmentStatusKey) REFERENCES dw.DimShipmentStatus(ShipmentStatusKey),
    CONSTRAINT FK_FactShipment_DimCarrier
        FOREIGN KEY (CarrierKey) REFERENCES dw.DimCarrier(CarrierKey),
    CONSTRAINT FK_FactShipment_DimRoute
        FOREIGN KEY (RouteKey) REFERENCES dw.DimRoute(RouteKey),
    CONSTRAINT FK_FactShipment_DimLocation_Origin
        FOREIGN KEY (OriginLocationKey) REFERENCES dw.DimLocation(LocationKey),
    CONSTRAINT FK_FactShipment_DimLocation_Destination
        FOREIGN KEY (DestinationLocationKey) REFERENCES dw.DimLocation(LocationKey),
    CONSTRAINT FK_FactShipment_Batch_Run
        FOREIGN KEY (BatchID) REFERENCES meta.Batch_Run(BatchID)
);
GO

CREATE INDEX IX_FactShipment_ActualDeliveryDateKey ON dw.FactShipment (ActualDeliveryDateKey);
GO

CREATE INDEX IX_FactShipment_CarrierKey ON dw.FactShipment (CarrierKey);
GO

CREATE INDEX IX_FactShipment_RouteKey ON dw.FactShipment (RouteKey);
GO

CREATE INDEX IX_FactShipment_ShipmentStatusKey ON dw.FactShipment (ShipmentStatusKey);
GO

CREATE TABLE dw.FactDeliveryEvent
(
    DeliveryEventFactKey bigint IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_FactDeliveryEvent PRIMARY KEY,
    ShipmentNumber nvarchar(50) NOT NULL,
    EventDateKey int NOT NULL
        CONSTRAINT DF_FactDeliveryEvent_EventDateKey DEFAULT 0,
    ShipmentStatusKey int NOT NULL
        CONSTRAINT DF_FactDeliveryEvent_ShipmentStatusKey DEFAULT 0,
    CarrierKey int NOT NULL
        CONSTRAINT DF_FactDeliveryEvent_CarrierKey DEFAULT 0,
    RouteKey int NOT NULL
        CONSTRAINT DF_FactDeliveryEvent_RouteKey DEFAULT 0,
    OriginLocationKey int NOT NULL
        CONSTRAINT DF_FactDeliveryEvent_OriginLocationKey DEFAULT 0,
    DestinationLocationKey int NOT NULL
        CONSTRAINT DF_FactDeliveryEvent_DestinationLocationKey DEFAULT 0,
    EventLocationKey int NOT NULL
        CONSTRAINT DF_FactDeliveryEvent_EventLocationKey DEFAULT 0,
    DeliveryExceptionKey int NOT NULL
        CONSTRAINT DF_FactDeliveryEvent_DeliveryExceptionKey DEFAULT 0,
    EventSequenceNumber int NOT NULL,
    EventDateTime datetime2(0) NOT NULL,
    ScanType nvarchar(30) NULL,
    EventSource nvarchar(30) NULL,
    EventCount int NOT NULL
        CONSTRAINT DF_FactDeliveryEvent_EventCount DEFAULT 1,
    ExceptionEventFlag bit NOT NULL
        CONSTRAINT DF_FactDeliveryEvent_ExceptionEventFlag DEFAULT 0,
    BatchID int NOT NULL,
    CreatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_FactDeliveryEvent_CreatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_FactDeliveryEvent_Event UNIQUE (ShipmentNumber, EventSequenceNumber),
    CONSTRAINT FK_FactDeliveryEvent_DimDate
        FOREIGN KEY (EventDateKey) REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactDeliveryEvent_DimShipmentStatus
        FOREIGN KEY (ShipmentStatusKey) REFERENCES dw.DimShipmentStatus(ShipmentStatusKey),
    CONSTRAINT FK_FactDeliveryEvent_DimCarrier
        FOREIGN KEY (CarrierKey) REFERENCES dw.DimCarrier(CarrierKey),
    CONSTRAINT FK_FactDeliveryEvent_DimRoute
        FOREIGN KEY (RouteKey) REFERENCES dw.DimRoute(RouteKey),
    CONSTRAINT FK_FactDeliveryEvent_DimLocation_Origin
        FOREIGN KEY (OriginLocationKey) REFERENCES dw.DimLocation(LocationKey),
    CONSTRAINT FK_FactDeliveryEvent_DimLocation_Destination
        FOREIGN KEY (DestinationLocationKey) REFERENCES dw.DimLocation(LocationKey),
    CONSTRAINT FK_FactDeliveryEvent_DimLocation_Event
        FOREIGN KEY (EventLocationKey) REFERENCES dw.DimLocation(LocationKey),
    CONSTRAINT FK_FactDeliveryEvent_DimDeliveryException
        FOREIGN KEY (DeliveryExceptionKey) REFERENCES dw.DimDeliveryException(DeliveryExceptionKey),
    CONSTRAINT FK_FactDeliveryEvent_FactShipment
        FOREIGN KEY (ShipmentNumber) REFERENCES dw.FactShipment(ShipmentNumber),
    CONSTRAINT FK_FactDeliveryEvent_Batch_Run
        FOREIGN KEY (BatchID) REFERENCES meta.Batch_Run(BatchID)
);
GO

CREATE INDEX IX_FactDeliveryEvent_EventDateKey ON dw.FactDeliveryEvent (EventDateKey);
GO

CREATE INDEX IX_FactDeliveryEvent_ShipmentStatusKey ON dw.FactDeliveryEvent (ShipmentStatusKey);
GO

CREATE INDEX IX_FactDeliveryEvent_CarrierKey ON dw.FactDeliveryEvent (CarrierKey);
GO

CREATE TABLE dw.FactDeliveryException
(
    DeliveryExceptionFactKey bigint IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_FactDeliveryException PRIMARY KEY,
    ShipmentNumber nvarchar(50) NOT NULL,
    ExceptionDateKey int NOT NULL
        CONSTRAINT DF_FactDeliveryException_ExceptionDateKey DEFAULT 0,
    ShipmentStatusKey int NOT NULL
        CONSTRAINT DF_FactDeliveryException_ShipmentStatusKey DEFAULT 0,
    CarrierKey int NOT NULL
        CONSTRAINT DF_FactDeliveryException_CarrierKey DEFAULT 0,
    RouteKey int NOT NULL
        CONSTRAINT DF_FactDeliveryException_RouteKey DEFAULT 0,
    OriginLocationKey int NOT NULL
        CONSTRAINT DF_FactDeliveryException_OriginLocationKey DEFAULT 0,
    DestinationLocationKey int NOT NULL
        CONSTRAINT DF_FactDeliveryException_DestinationLocationKey DEFAULT 0,
    DeliveryExceptionKey int NOT NULL
        CONSTRAINT DF_FactDeliveryException_DeliveryExceptionKey DEFAULT 0,
    ExceptionDateTime datetime2(0) NOT NULL,
    DelayMinutesImpact int NULL,
    TypicalDelayMinutes int NULL,
    DelayVarianceMinutes int NULL,
    ResolvedWithin24HoursFlag bit NOT NULL,
    ExceptionCount int NOT NULL
        CONSTRAINT DF_FactDeliveryException_ExceptionCount DEFAULT 1,
    BatchID int NOT NULL,
    CreatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_FactDeliveryException_CreatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_FactDeliveryException_Event UNIQUE (ShipmentNumber, DeliveryExceptionKey, ExceptionDateTime),
    CONSTRAINT FK_FactDeliveryException_DimDate
        FOREIGN KEY (ExceptionDateKey) REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactDeliveryException_DimShipmentStatus
        FOREIGN KEY (ShipmentStatusKey) REFERENCES dw.DimShipmentStatus(ShipmentStatusKey),
    CONSTRAINT FK_FactDeliveryException_DimCarrier
        FOREIGN KEY (CarrierKey) REFERENCES dw.DimCarrier(CarrierKey),
    CONSTRAINT FK_FactDeliveryException_DimRoute
        FOREIGN KEY (RouteKey) REFERENCES dw.DimRoute(RouteKey),
    CONSTRAINT FK_FactDeliveryException_DimLocation_Origin
        FOREIGN KEY (OriginLocationKey) REFERENCES dw.DimLocation(LocationKey),
    CONSTRAINT FK_FactDeliveryException_DimLocation_Destination
        FOREIGN KEY (DestinationLocationKey) REFERENCES dw.DimLocation(LocationKey),
    CONSTRAINT FK_FactDeliveryException_DimDeliveryException
        FOREIGN KEY (DeliveryExceptionKey) REFERENCES dw.DimDeliveryException(DeliveryExceptionKey),
    CONSTRAINT FK_FactDeliveryException_FactShipment
        FOREIGN KEY (ShipmentNumber) REFERENCES dw.FactShipment(ShipmentNumber),
    CONSTRAINT FK_FactDeliveryException_Batch_Run
        FOREIGN KEY (BatchID) REFERENCES meta.Batch_Run(BatchID)
);
GO

CREATE INDEX IX_FactDeliveryException_ExceptionDateKey ON dw.FactDeliveryException (ExceptionDateKey);
GO

CREATE INDEX IX_FactDeliveryException_CarrierKey ON dw.FactDeliveryException (CarrierKey);
GO

CREATE INDEX IX_FactDeliveryException_ShipmentStatusKey ON dw.FactDeliveryException (ShipmentStatusKey);
GO
