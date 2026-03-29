USE [$(DatabaseName)];
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'stg')
BEGIN
    EXEC (N'CREATE SCHEMA stg;');
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'dw')
BEGIN
    EXEC (N'CREATE SCHEMA dw;');
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'meta')
BEGIN
    EXEC (N'CREATE SCHEMA meta;');
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'audit')
BEGIN
    EXEC (N'CREATE SCHEMA audit;');
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'etl')
BEGIN
    EXEC (N'CREATE SCHEMA etl;');
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'rpt')
BEGIN
    EXEC (N'CREATE SCHEMA rpt;');
END;
GO

