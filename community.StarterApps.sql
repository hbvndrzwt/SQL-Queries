
---------------------------
-- ##Use of Starter Apps##
---------------------------

-- Use TemplateBrowserProjectCreationSucceeded
-- Use PlatformAnalytics_Processed_Platform_ProjectsV2

/*
Columns needed: 

ProjectId (Unique): Get it from 'TemplateBrowserProjectCreationSucceeded' event, which is triggered when a user creates a new project from the Template Browser
OpenId: Unique ID for the user who creates the Project
Name (Starter) App: Use Template UUID from the 'TemplateBrowserProjectCreationSucceeded' event. Still need to link this to Template data gathered from the app (OData)
Timestamp Project Creation succeeded
Timestamp First Deploy (if available)
TimeDiff
#Users in the project (so far)
#Deploys made on the project (so far)
*/

/*
Need to do:
- Add Userinfo (exclude Mendix) - DONE
- Add Number of Project Created (first app, second, etc..) 
- Retrieve Template data from the app - IS IN ODATA CONNECTION IN POWER BI 

*/


SELECT *
INTO #Events
FROM [PlatformAnalytics_PullPush_Platform_Event]
WHERE EventType IN ('AppInviteSent', 'ProjectInviteSent', 'TemplateBrowserProjectCreationSucceeded', 'AppDownload', 'WmDeploySucceeded', 'WmDeployStarted', 'SandboxDeployed', 'ModelDeployed', 'DeployAppPackage')

DROP TABLE community.StarterApps_Templates

SELECT *
INTO community.StarterApps_Templates
FROM
(
	SELECT  a.ProjectID,
			TemplateID,
			OpenID,
			DateTimeProjectCreated,
			FirstDeployDateTime,
			CONVERT(DATE, FirstDeployDateTime) AS FirstDeployDate,
			DATEDIFF(minute, DateTimeProjectCreated, FirstDeployDateTime) AS TimeDiffFirstDeploy,
			NumberOfDeploys
	FROM 
	(
		SELECT  ExtraInfo3 AS ProjectID,
				ExtraInfo2 AS TemplateID,
				OpenId,
				Timestamp AS DateTimeProjectCreated
		FROM #Events
		WHERE EventType = 'TemplateBrowserProjectCreationSucceeded'
		GROUP BY ExtraInfo3,
				 ExtraInfo2,
				 OpenId,
				 Timestamp	
	)a

	LEFT JOIN
	(
		SELECT  ExtraInfo1 AS ProjectID,
				MIN(Timestamp) AS FirstDeployDateTime,
				COUNT(Timestamp) AS NumberOfDeploys
		FROM #Events
		WHERE EventType IN ('WmDeploySucceeded', 'SandboxDeployed', 'ModelDeployed', 'DeployAppPackage')
		GROUP BY ExtraInfo1
	)b
	ON a.ProjectID = b.ProjectID
)a

LEFT JOIN
(
	SELECT  S_UUID,
			ProjectName,
			CreatedDate,
			CreatorCompanyPlatformName,
			ProjectIsDeleted,
			EnvironmentType,
			AppType,
			ProjectMemberCount,
			FirstSandboxLogin,
			LastSandboxLogin,
			DATEDIFF(minute, CreatedDate, LastSandboxLogin) AS TimeDiffLastActiveDate,
			AppStatus
	FROM PlatformAnalytics_Processed_Platform_ProjectsV2
)b
ON a.ProjectID = b.S_UUID
WHERE CreatorCompanyPlatformName NOT LIKE '%Mendix%'





