IF DB_ID(N'$(DatabaseName)') IS NULL
BEGIN
    EXEC (N'CREATE DATABASE [$(DatabaseName)];');
END;
GO

ALTER DATABASE [$(DatabaseName)] SET RECOVERY SIMPLE;
GO

