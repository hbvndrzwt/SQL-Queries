
DROP TABLE community.WmGuidance_Full

--LOAD all events that are needed for the Initiative Metrics
;WITH WmGuidanceEvents AS
(
    SELECT * 
    FROM community.Initiatives_Events
    WHERE EventType IN( 'WmIntroTutorialBroken', 'WmIntroTutorialStep', 'SandboxDeployed', 'WmDeploySucceeded', 'OnlineLectureCompleted')
)

SELECT * INTO #WmGuidanceEvents
FROM WmGuidanceEvents

--TIME: 2min42sec
---------------------------------------------------------------------------------------------------------------------------------------
--GUIDANCE Started

;WITH GuidanceStarted AS
(
	SELECT OpenId,
		   CONVERT(DATE, Timestamp) AS StartDate,
		   -- Use Tutorial for now to allocate users to Experiment & ExperimentGroup (i.e. Journey_A:3 is Experiment 3 & Group A)
		   ExtraInfo2 AS Tutorial
	FROM #WmGuidanceEvents
	WHERE EventType = 'WmIntroTutorialStep'
	AND ExtraInfo1 = 'welcome1'
)

, UniqueUsersGuidanceStarted AS
(
	SELECT  OpenId,
			MIN(StartDate) AS FirstStartDate,
			Tutorial
	FROM GuidanceStarted
	GROUP BY OpenId,
			 Tutorial	
)

--TIME: 2min31sec
---------------------------------------------------------------------------------------------------------------------------------------
--GUIDANCE Step Completion LONG LOAD TIME (2min23sec)

, UniqueTutorialStepUser AS
(
	SELECT  OpenId,
			ExtraInfo2 AS Tutorial,
			ExtraInfo1 AS Step
	FROM	#WmGuidanceEvents
	WHERE EventType = 'WmIntroTutorialStep'
	GROUP BY OpenId,
			 ExtraInfo2,
			 ExtraInfo1
)

, UniqueCompletedSteps AS
(
	SELECT  OpenId,
			Tutorial,
			COUNT(DISTINCT Step) AS CompletedSteps
	FROM UniqueTutorialStepUser
	GROUP BY  OpenId,
			  Tutorial
)

--TIME: 0min45sec
---------------------------------------------------------------------------------------------------------------------------------------
--GUIDANCE Finished

-- Get OpenIds (only) from users that Finished the WmGuidance
, UniqueGuidanceFinished AS
(
	SELECT  OpenId,
			ExtraInfo2 AS Tutorial,
			MIN(CONVERT(DATE, Timestamp)) AS FinishDate,
			SUM(CASE WHEN ExtraInfo1 = 'Finished' THEN 1 ELSE 0 END) AS GuidanceFinished
	FROM #WmGuidanceEvents
	WHERE EventType = 'WmIntroTutorialStep'
	GROUP BY OpenId,
			 ExtraInfo2
)

--TIME: 0min26sec
---------------------------------------------------------------------------------------------------------------------------------------

-- BrokenTours  --OPENID TO JOIN WITH OTHER TABLES 
, BrokenEvents AS
(
    -- Count per user (OpenID) the BrokenTours events. Max 1 BrokenEvent per user per day.
    SELECT 	OpenId,
			CONVERT(DATE, Timestamp) AS BrokenDate,
			CASE WHEN COUNT(EventType) > 0 THEN 1 ELSE 0 END AS BrokenEvents
    FROM #WmGuidanceEvents
	WHERE EventType = 'WmIntroTutorialBroken'
	GROUP BY OpenId,
			 CONVERT(DATE, Timestamp)
)

--TIME: 0min04sec
---------------------------------------------------------------------------------------------------------------------------------------

-- Next Step
, ContinueTours AS
(
    SELECT  OpenId,
			ExtraInfo1 AS StepName
	FROM #WmGuidanceEvents
    WHERE EventType = 'WmIntroTutorialStep'
    AND ExtraInfo1 LIKE 'Continue%'
	GROUP BY OpenId, ExtraInfo1
)

--TIME: 0min04sec
---------------------------------------------------------------------------------------------------------------------------------------
-- WM Activation, Calculate if a user deploys an app (and has an applogin on that app) within 7days after finishing the WmGuidance
-- WM Academy Conversion, Calculate if a user completes an online course within 7days after finishing the WmGuidance


--Combine Finished Users + WM Activation & OnlineCourse Metrics
, CombinedMetrics AS
(
	SELECT 	a.*,
			CASE 
				WHEN SUM(CASE WHEN EventType = 'OnlineLectureCompleted' THEN 1 ELSE 0 END) > 0
					THEN 1
				ELSE 0
			END AS LectureCompleted,
			CASE 
				WHEN SUM(CASE WHEN EventType = 'SandboxDeployed' OR EventType = 'WmDeploySucceeded' THEN 1 ELSE 0 END) > 0
					THEN 1
				ELSE 0
			END AS WmActivated
	FROM
		(
			SELECT *,
				   DATEADD(day, 1, FirstStartDate) AS LowerBoundary,
				   DATEADD(day, 8, FirstStartDate) AS UpperBoundary
			FROM UniqueUsersGuidanceStarted
		) a
		
	LEFT JOIN
	(
		SELECT	OpenId,
				CONVERT(DATE, Timestamp) AS EventDate,
				EventType
		FROM 	#WmGuidanceEvents
		WHERE EventType IN ('SandboxDeployed', 'WmDeploySucceeded', 'OnlineLectureCompleted')
	)b
	ON a.OpenId = b.OpenId AND EventDate BETWEEN LowerBoundary AND UpperBoundary 
	GROUP BY  a.OpenId,
			  Tutorial,
			  FirstStartDate,
			  LowerBoundary,
			  UpperBoundary
)

--TIME: 0min59sec
---------------------------------------------------------------------------------------------------------------------------------------

-- Join OpenId Events
, JoinGuidanceEvents AS
(

		SELECT  a.OpenId,
				FirstStartDate,
				a.Tutorial,
				CONCAT(SUBSTRING(a.Tutorial, 1, CHARINDEX('_', a.Tutorial)), SUBSTRING(a.Tutorial, CHARINDEX(':', a.Tutorial)+1, LEN(a.Tutorial))) AS Experiment,
				SUBSTRING(a.Tutorial, CHARINDEX('_', a.Tutorial)+1,  1) AS ExperimentGroup,
				CASE WHEN GuidanceFinished > 0 THEN 1 ELSE 0 END AS GuidanceFinished,
				CASE WHEN GETDATE() > UpperBoundary THEN LectureCompleted ELSE NULL END AS LectureCompleted,
				CASE WHEN GETDATE() > UpperBoundary THEN WmActivated ELSE NULL END AS WmActivated,
				CASE WHEN StepName = 'Continue with learn' THEN 1 ELSE 0 END AS Learn,
				CASE WHEN StepName = 'Continue working in app' THEN 1 ELSE 0 END AS WorkInApp,
				CompletedSteps
		FROM
		(
			SELECT *
			FROM CombinedMetrics
		) a
		
		LEFT JOIN 
		(
			SELECT * 
			FROM UniqueGuidanceFinished
		) b
		ON a.OpenId = b.OpenId AND a.Tutorial = b.Tutorial
		
		LEFT JOIN
		(
			SELECT *
			FROM ContinueTours
		) c
		ON a.OpenId = c.OpenId AND a.Tutorial = b.Tutorial

		LEFT JOIN
		(
			SELECT *
			FROM UniqueCompletedSteps
		) d
		ON a.OpenId = d.OpenId
		AND a.Tutorial = d.Tutorial

)

--TIME: 1min21sec

-- Load Table with KGM 
, KeyGrowthMetrics AS
(
	SELECT *
	FROM community.Initiatives_KGM
)

--TIME: 0min01sec
-- Join Tables JoinSignupSteps & KeyGrowthMetrics
-- Join Tables JoinSignupSteps & KeyGrowthMetrics
, JoinedTable AS
(
	SELECT  *
			
	FROM
	(
		SELECT  a.*,
				b.*,
				CASE WHEN a.OpenId <>'' THEN 1 ELSE 0 END AS GuidanceStarted,
				Learn AS ChosenLearn,
				WorkInApp AS ChosenWorkInApp,
				CASE WHEN GuidanceFinished = 0 THEN CompletedSteps ELSE NULL END AS StageCompletion,
				CompletedSteps AS Maxsteps,
				ActivatedWithin30days AS Activated,
				BrokenDate,
				BrokenEvents,
				CASE WHEN DATEDIFF(DAY, SignupDate, FirstStartDate) < 8 THEN 1 ELSE 0 END AS WithinFirstWeek
			
		FROM
		(
			SELECT	* 
			FROM JoinGuidanceEvents
		) a
	
		LEFT JOIN
		(
			SELECT *
			FROM KeyGrowthMetrics
		) b
		ON a.OpenId = b.UserId
		
		LEFT JOIN
		(
			SELECT *
			FROM BrokenEvents
		) c
		ON a.OpenId = c.OpenId
	) a
	WHERE WithinFirstWeek = 1
)


SELECT * INTO community.WmGuidance_Full FROM JoinedTable
