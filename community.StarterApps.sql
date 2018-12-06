
-- ##Use of Starter Apps##

/*
Columns needed: 

ProjectId (Unique)
OpenId
Name (Starter) App
Timestamp Download
Timestamp First Deploy (if available)
TimeDiff
#Users (so far)
#Deploys (so far)
*/

/*
Need to do:
- Add Userinfo (exclude Mendix)
- Add Number of Project Created (first app, second, etc..)


*/


SELECT *
INTO #Events
FROM [PlatformAnalytics_PullPush_Platform_Event]
WHERE EventType IN ('AppInviteSent', 'ProjectInviteSent', 'ProjectCreated', 'AppDownload', 'WmDeploySucceeded', 'WmDeployStarted', 'SandboxDeployed')

SELECT  ExtraInfo1 AS ProjectID,
		OpenID,
		Timestamp AS DateTimeProjectCreated,
		FirstDeployDateTime,
		CONVERT(DATE, FirstDeployDateTime) AS FirstDeployDate,
		DATEDIFF(minute, Timestamp, FirstDeployDateTime) AS TimeDiffFirstDeploy,
		NumberOfDeploys
FROM 
(
	SELECT *
	FROM #Events
	WHERE EventType = 'ProjectCreated'
)a

LEFT JOIN
(
	SELECT  ExtraInfo1 AS ProjectID,
			MIN(Timestamp) AS FirstDeployDateTime,
			COUNT(Timestamp) AS NumberOfDeploys
	FROM #Events
	WHERE EventType IN ('WmDeploySucceeded', 'SandboxDeployed')
	GROUP BY ExtraInfo1
)b
ON a.ExtraInfo1 = b.ProjectID