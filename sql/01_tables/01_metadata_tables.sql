USE [$(DatabaseName)];
GO

CREATE TABLE meta.Batch_Run
(
    BatchID int IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_Batch_Run PRIMARY KEY,
    BatchName nvarchar(150) NOT NULL,
    SourceName nvarchar(100) NULL,
    StartTime datetime2(0) NOT NULL
        CONSTRAINT DF_Batch_Run_StartTime DEFAULT SYSUTCDATETIME(),
    EndTime datetime2(0) NULL,
    Status varchar(20) NOT NULL
        CONSTRAINT DF_Batch_Run_Status DEFAULT 'STARTED',
    TriggeredBy sysname NOT NULL
        CONSTRAINT DF_Batch_Run_TriggeredBy DEFAULT SUSER_SNAME(),
    RowsRead int NULL,
    RowsInserted int NULL,
    RowsUpdated int NULL,
    RowsLoaded int NULL,
    RowsRejected int NULL,
    Notes nvarchar(1000) NULL
);
GO

ALTER TABLE meta.Batch_Run
ADD CONSTRAINT CK_Batch_Run_Status
CHECK (Status IN ('STARTED', 'SUCCEEDED', 'FAILED'));
GO

CREATE TABLE meta.Watermark
(
    ProcessName nvarchar(150) NOT NULL
        CONSTRAINT PK_Watermark PRIMARY KEY,
    LastSuccessfulBatchID int NULL,
    LastWatermarkValue datetime2(0) NULL,
    LastWatermarkSequence bigint NULL,
    LastWatermarkText nvarchar(260) NULL,
    PendingBatchID int NULL,
    PendingWatermarkValue datetime2(0) NULL,
    PendingWatermarkSequence bigint NULL,
    PendingWatermarkText nvarchar(260) NULL,
    UpdatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_Watermark_UpdatedAt DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE meta.Source_File_Log
(
    SourceFileLogID int IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_Source_File_Log PRIMARY KEY,
    BatchID int NOT NULL,
    SourceObjectName nvarchar(150) NOT NULL,
    SourceType varchar(30) NOT NULL,
    FileName nvarchar(260) NULL,
    RowsReceived int NULL,
    RowsLoaded int NULL,
    RowsRejected int NULL,
    FileModifiedAt datetime2(0) NULL,
    LoadStatus varchar(20) NOT NULL
        CONSTRAINT DF_Source_File_Log_LoadStatus DEFAULT 'RECEIVED',
    LoadedAt datetime2(0) NOT NULL
        CONSTRAINT DF_Source_File_Log_LoadedAt DEFAULT SYSUTCDATETIME(),
    Message nvarchar(1000) NULL,
    CONSTRAINT FK_Source_File_Log_Batch_Run
        FOREIGN KEY (BatchID) REFERENCES meta.Batch_Run(BatchID)
);
GO

ALTER TABLE meta.Source_File_Log
ADD CONSTRAINT CK_Source_File_Log_SourceType
CHECK (SourceType IN ('FLAT_FILE', 'SQL_SERVER'));
GO

ALTER TABLE meta.Source_File_Log
ADD CONSTRAINT CK_Source_File_Log_LoadStatus
CHECK (LoadStatus IN ('RECEIVED', 'LOADED', 'FAILED'));
GO

CREATE UNIQUE INDEX UX_Source_File_Log_FlatFileRegistration
    ON meta.Source_File_Log (BatchID, SourceObjectName, FileName)
    WHERE SourceType = 'FLAT_FILE'
      AND FileName IS NOT NULL;
GO

CREATE TABLE audit.Load_Audit
(
    LoadAuditID bigint IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_Load_Audit PRIMARY KEY,
    BatchID int NULL,
    StepName nvarchar(150) NOT NULL,
    TargetObjectName nvarchar(150) NOT NULL,
    RowsInserted int NOT NULL
        CONSTRAINT DF_Load_Audit_RowsInserted DEFAULT 0,
    RowsUpdated int NOT NULL
        CONSTRAINT DF_Load_Audit_RowsUpdated DEFAULT 0,
    RowsRejected int NOT NULL
        CONSTRAINT DF_Load_Audit_RowsRejected DEFAULT 0,
    StartedAt datetime2(0) NOT NULL
        CONSTRAINT DF_Load_Audit_StartedAt DEFAULT SYSUTCDATETIME(),
    CompletedAt datetime2(0) NULL,
    Status varchar(20) NOT NULL
        CONSTRAINT DF_Load_Audit_Status DEFAULT 'STARTED',
    Message nvarchar(1000) NULL,
    CONSTRAINT FK_Load_Audit_Batch_Run
        FOREIGN KEY (BatchID) REFERENCES meta.Batch_Run(BatchID)
);
GO

ALTER TABLE audit.Load_Audit
ADD CONSTRAINT CK_Load_Audit_Status
CHECK (Status IN ('STARTED', 'SUCCEEDED', 'FAILED'));
GO

CREATE TABLE audit.Validation_Error
(
    ValidationErrorID bigint IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_Validation_Error PRIMARY KEY,
    BatchID int NULL,
    SourceTableName nvarchar(150) NOT NULL,
    BusinessKey nvarchar(150) NULL,
    ColumnName nvarchar(128) NULL,
    RuleName nvarchar(150) NOT NULL,
    ErrorMessage nvarchar(1000) NOT NULL,
    LoggedAt datetime2(0) NOT NULL
        CONSTRAINT DF_Validation_Error_LoggedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Validation_Error_Batch_Run
        FOREIGN KEY (BatchID) REFERENCES meta.Batch_Run(BatchID)
);
GO

CREATE TABLE audit.Error_Log
(
    ErrorLogID bigint IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_Error_Log PRIMARY KEY,
    BatchID int NULL,
    ProcedureName sysname NULL,
    ErrorNumber int NULL,
    ErrorSeverity int NULL,
    ErrorState int NULL,
    ErrorLine int NULL,
    ErrorMessage nvarchar(4000) NOT NULL,
    LoggedAt datetime2(0) NOT NULL
        CONSTRAINT DF_Error_Log_LoggedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Error_Log_Batch_Run
        FOREIGN KEY (BatchID) REFERENCES meta.Batch_Run(BatchID)
);
GO

CREATE TABLE audit.Stage_Row_Reject
(
    StageRejectID bigint IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_Stage_Row_Reject PRIMARY KEY,
    BatchID int NOT NULL,
    SourceTableName nvarchar(150) NOT NULL,
    StageRowID bigint NULL,
    BusinessKey nvarchar(150) NULL,
    SourceName nvarchar(100) NULL,
    SourceFileName nvarchar(260) NULL,
    RejectionReason nvarchar(2000) NOT NULL,
    RejectedAt datetime2(0) NOT NULL
        CONSTRAINT DF_Stage_Row_Reject_RejectedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Stage_Row_Reject_Batch_Run
        FOREIGN KEY (BatchID) REFERENCES meta.Batch_Run(BatchID)
);
GO
