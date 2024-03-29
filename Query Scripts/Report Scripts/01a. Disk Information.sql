/****** 

Disk free interpretation  
Useful to get a quick reference of the capacity sizes in something meaningful.

******/

-- Use the name of the customer inventory database
use [DBAdmin]

SELECT 
b.[environment]
,a.[ComputerName]
  ,[Name]
  ,[Label]
,[PercentFree]
      ,[BlockSize]
      ,[IsSqlDisk]
      ,[DateCaptured]
,CAST([Capacity]/1024.0/1024.0 AS decimal(10,2)) AS CapacityInMB
,CAST([Capacity]/1024.0/1024.0/1024.0 AS decimal(10,2)) AS CapacityInGB
,CAST([Capacity]/1024.0/1024.0/1024.0/1024.0 AS decimal(10,2)) AS CapacityInTB
      
,CAST([Free]/1024.0/1024.0 AS decimal(10,2)) AS FreeInMB
,CAST([Free]/1024.0/1024.0/1024.0 AS decimal(10,2)) AS FreeInGB
,CAST([Free]/1024.0/1024.0/1024.0/1024.0 AS decimal(10,2)) AS FreeInTB
      
      
  FROM [dbo].[Checks_ServerDiskInformation] a
  LEFT JOIN [dbo].[SourceServerList] b ON a.ComputerName = b.MachineName
 WHERE ActiveStatus = 1
 -- Use this to look for any low on disk
 --where a.[PercentFree] <= 20

 order by b.[environment], a.[ComputerName]
 


 
 --Use this if you want to search by a particular date.
 -- where a.[DateCaptured]  >= '2018-10-08 08:50:38.7480076' AND [PercentFree] < 10