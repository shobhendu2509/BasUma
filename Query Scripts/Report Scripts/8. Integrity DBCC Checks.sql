/****** Last know DBCC checks results ******/
USE [DBAdmin]
SELECT 
b.[environment]
,[ComputerName]
      ,[InstanceName]
      ,[SqlInstance]
      ,[Database]
      ,[DatabaseCreated]
      ,[LastGoodCheckDb]
      ,[DaysSinceDbCreated]
      ,[DaysSinceLastGoodCheckDb]
      ,[Status]
      ,[DataPurityEnabled]
      ,[CreateVersion]
      ,[DbccFlags]
  FROM [DBAdmin].[dbo].[Checks_DBCCLastGoodCheck] a
    left JOIN [dbo].[SourceServerList] b ON a.[ComputerName] = b.[MachineName]
  WHERE b.ActiveStatus = 1
  order by b.[environment], a.[InstanceName]