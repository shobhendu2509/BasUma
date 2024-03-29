USE [DBAdmin]
GO

--Checks if it already exists, if not it creates the procedure, if so it just alters it.
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Disk_Free]') AND type in (N'P', N'PC'))
BEGIN

EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Disk_Free] AS'

END
GO

ALTER PROCEDURE [dbo].[sp_Disk_Free] 

-- Disk Free parameter with default of 100
@PercentFree INT = 100 

AS 

/*
	Purpose:	Use this stored procedure to return any disks with less than 25% free.
	
	Title:			INVENTORY - Database server information		
	Version			1.0
	Created by:		Tim Roberts
	Date Created:	2019-04-01

	Changes:
	Author		Date		Ver		Notes
	--------------------------------------------------------------------------------------
	TR			2019-04-01	1.0		Initial Release.


IMPORTANT NOTES
===============
Create a stored procedure using this code.

*/



SELECT SS.Environment
	,[ComputerName]
      ,[Name]
      ,[Label]
      ,[Capacity]
      ,[Free]
      ,[PercentFree]
      ,[BlockSize]
      ,[IsSqlDisk]
      ,[DateCaptured]
  FROM [DBAdmin].[dbo].[Checks_ServerDiskInformation] DINF
  INNER join [DBAdmin].[dbo].[SourceServerList] SS on SS.[MachineName] = DINF.[ComputerName]
  where PercentFree < @PercentFree --< 25
  Order by SS.Environment, [ComputerName], [Name]