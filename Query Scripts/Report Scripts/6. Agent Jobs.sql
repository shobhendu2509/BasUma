/****** Agent Jobs ******/
USE [DBAdmin]
SELECT b.[environment]
		, [ServerName]
      ,[InstanceName]
      ,[OwnerName]
      ,[name]
      ,[description]
      ,[enabled]
      ,[OperatorName]
      ,[date_created]
      ,[date_modified]
      ,[job_id]
      ,[LastRun]
      ,[NextRun]
  FROM [DBAdmin].[dbo].[Checks_AgentJobs] a
  left JOIN [dbo].[SourceServerList] b ON a.[ServerName] = b.[SQL Instance Name]
  WHERE b.ActiveStatus = 1
  
  order by b.[environment], a.[ServerName]