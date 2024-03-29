/****** Local Administrator group members  ******/
use [DBAdmin]


SELECT b.[environment]
,[Member]
      ,[ComputerName]
      ,[LocalGroup]
      ,[DateCaptured]
  FROM [DBAdmin].[dbo].[Checks_LocalAdministrators_members] a
    left JOIN [dbo].[SourceServerList] b ON a.[ComputerName] = b.[MachineName]
WHERE b.ActiveStatus = 1
-- Provided as a complete list. Its up to the customer to review if these are appopriate.
--	where a.[member] not like 'Domain Admins' and a.[member] not like 'Comcare Domain Administrators' AND a.[member] not like '%SQL Administrators'

  order by b.[environment], a.[ComputerName], a.[member]