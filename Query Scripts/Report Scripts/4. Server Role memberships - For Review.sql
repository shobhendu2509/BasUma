/****** Script for SelectTopNRows command from SSMS  ******/
USE [DBAdmin]

SELECT b.[environment]
,a.[SQL Instance Name]
      ,[DateCaptured]
      ,[loginname]
      ,[type]
      ,[type_desc]
      ,[is_disabled]
      ,[sysadmin]
      ,[securityadmin]
      ,[serveradmin]
      ,[setupadmin]
      ,[processadmin]
      ,[diskadmin]
      ,[dbcreator]
      ,[bulkadmin]
      ,[create_date]
      ,[modify_date]
  FROM [DBAdmin].[dbo].[Checks_ServerRoleMembers] a
    left JOIN [dbo].[SourceServerList] b ON a.[SQL Instance Name] = b.[SQL Instance Name]

  Where 
(  [sysadmin] > 0
OR [securityadmin] > 0
OR  [serveradmin] > 0
OR  [setupadmin] > 0
OR [processadmin] > 0
OR [diskadmin] > 0
OR [dbcreator] > 0
OR  [bulkadmin] > 0)

AND [loginname] NOT LIKE 'NT AUTHORITY%' AND [loginname] NOT LIKE 'NT SERVICE%' AND [loginname] NOT LIKE 'sa'
AND b.ActiveStatus = 1
order by b.[environment], a.[SQL Instance Name], a.[loginname]