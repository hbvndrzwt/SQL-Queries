-- This Query is designed to get an overview of the progress on Challenges for Users
-- Approx. QueryTime: 1min16sec


/*
Questions:
1. Is it possible for users to receive the same challenge multiple times? - Yes, it is. 



*/

DROP TABLE community.Challenges_Progress

-- 1. Load all Events needed for Challenge Assigning and Completion
SELECT  *
INTO #Events
FROM PlatformAnalytics_PullPush_Platform_Event 
WHERE EventType IN('ChallengeAssigned', 'ChallengeCompleted', 'ChallengeExpired', 'ChangedHighlightStatus')

-- 2. Link the Correct Challenge Assigned to Challenge Expired events
SELECT	a.OpenId,
		a.ChallengeId,
		a.Status,
		b.Timestamp AS TimeChallengeAssigned,
		a.DateTimeEnded,
		LastChallengeEventChangedId
INTO #ChallengesExpired
FROM
(
	SELECT  a.OpenId,
			a.ChallengeId,
			a.DateTimeEnded,
			'Expired' AS Status,
			MAX(b.ChangedId) AS LastChallengeEventChangedId
	FROM 
	(
		SELECT  OpenId,
				ExtraInfo1 AS ChallengeId,
				Timestamp AS DateTimeEnded
		FROM #Events
		WHERE EventType IN ('ChallengeExpired')
		
	)a
	LEFT JOIN
	(
		SELECT  ChangedId,
				OpenId,
				ExtraInfo1 AS ChallengeId,
				Timestamp AS DateTimeAssigned
		FROM #Events
		WHERE EventType IN ('ChallengeAssigned')
		
	)b
	ON a.OpenId = b.OpenId AND a.ChallengeId = b.ChallengeId AND DateTimeAssigned < DateTimeEnded
	GROUP BY	a.OpenId,
				a.ChallengeId,
				a.DateTimeEnded
 
)a
LEFT JOIN
(
	SELECT *
	FROM #Events
	WHERE EventType IN ('ChallengeAssigned')
)b
ON a.LastChallengeEventChangedId = b.ChangedId


-- 3. Link the Correct Challenge Assigned to Challenge Completed events
SELECT	a.OpenId,
		a.ChallengeId,
		a.Status,
		b.Timestamp AS TimeChallengeAssigned,
		a.DateTimeEnded,
		LastChallengeEventChangedId
INTO #ChallengesCompleted
FROM
(
	SELECT  a.OpenId,
			a.ChallengeId,
			a.DateTimeEnded,
			'Completed' AS Status,
			MAX(b.ChangedId) AS LastChallengeEventChangedId
	FROM 
	(
		SELECT  OpenId,
				ExtraInfo1 AS ChallengeId,
				Timestamp AS DateTimeEnded
		FROM #Events
		WHERE EventType IN ('ChallengeCompleted')
		
	)a
	LEFT JOIN
	(
		SELECT  ChangedId,
				OpenId,
				ExtraInfo1 AS ChallengeId,
				Timestamp AS DateTimeAssigned
		FROM #Events
		WHERE EventType IN ('ChallengeAssigned')
		
	)b
	ON a.OpenId = b.OpenId AND a.ChallengeId = b.ChallengeId AND DateTimeAssigned < DateTimeEnded
	GROUP BY	a.OpenId,
				a.ChallengeId,
				a.DateTimeEnded
 
)a
LEFT JOIN
(
	SELECT *
	FROM #Events
	WHERE EventType IN ('ChallengeAssigned')
)b
ON a.LastChallengeEventChangedId = b.ChangedId

-- 4. Combine all Assigned Challenges that are Completed
SELECT *
INTO #ChallengeEnded
FROM
(
	SELECT * FROM #ChallengesExpired
	UNION
	SELECT * FROM #ChallengesCompleted
)a
ORDER BY OpenId

-- 5. Find all Assigned Challenges that do not have an Ended Activity
SELECT  a.OpenId,
		a.ExtraInfo1 AS ChallengeId,
		'Currently Active' AS Status,
		a.Timestamp AS TimeChallengeAssigned,
		NULL AS DateTimeEnded,
		NULL AS LastChallengeEventChangedId
INTO #ChallengeNotEnded
FROM
(
	SELECT *
	FROM #Events
	WHERE EventType IN ('ChallengeAssigned')
)a
LEFT JOIN
(
	SELECT *
	FROM #ChallengeEnded
)b
ON a.ChangedId = b.LastChallengeEventChangedId
WHERE b.LastChallengeEventChangedId IS NULL

-- 6. Combine all Assigned Challenges
SELECT *
INTO #ChallengesMerged
FROM
(
	SELECT * FROM #ChallengeEnded
	UNION
	SELECT * FROM #ChallengeNotEnded
)a
ORDER BY OpenId

SELECT  a.*,
		CONVERT(DATE, a.TimeChallengeAssigned) AS DateChallengeAssigned,
		CONVERT(DATE, a.DateTimeEnded) AS DateEnded,
		DATEDIFF(hour, a.TimeChallengeAssigned, a.DateTimeEnded) AS TimeDiff
INTO community.Challenges_Progress
FROM 
(
	SELECT *
	FROM #ChallengesMerged as a
	WHERE OpenId =
	(
		SELECT MAX(OpenId)
		FROM PlatformAnalytics_PullPush_Platform_User_Current AS b
		WHERE a.OpenId = b.OpenId
		AND CompanyId NOT LIKE '%Mendix%'
	)
)a
















/*
-- Add HighlightStatus of Challenge
LEFT JOIN
(
	SELECT	a.OpenId,
			a.ChallengeId,
			a.ChallengeHighlightedStatus,
			b.Timestamp AS TimeChallengeAssigned,
			a.DateTimeChallengeHighlighted,
			LastChallengeEventChangedId
	FROM
	(
		SELECT  a.OpenId,
				a.ChallengeId,
				a.DateTimeChallengeHighlighted,
				ChallengeHighlightedStatus,
				MAX(b.ChangedId) AS LastChallengeEventChangedId
		FROM 
		(
			SELECT  OpenId,
					Timestamp AS DateTimeChallengeHighlighted,
					ExtraInfo1 AS ChallengeId,
					ExtraInfo2 AS ChallengeHighlightedStatus
			FROM #Events
			WHERE EventType IN('ChangedHighlightStatus')
			
		)a
		LEFT JOIN
		(
			SELECT  ChangedId,
					OpenId,
					ExtraInfo1 AS ChallengeId,
					Timestamp AS DateTimeAssigned
			FROM #Events
			WHERE EventType IN ('ChallengeAssigned')
			
		)b
		ON a.OpenId = b.OpenId AND a.ChallengeId = b.ChallengeId AND DateTimeAssigned < DateTimeChallengeHighlighted
		GROUP BY	a.OpenId,
					a.ChallengeId,
					a.DateTimeChallengeHighlighted,
					ChallengeHighlightedStatus
	)a
	LEFT JOIN
	(
		SELECT *
		FROM #Events
		WHERE EventType IN ('ChallengeAssigned')
	)b
	ON a.LastChallengeEventChangedId = b.ChangedId
)b
ON a.LastChallengeEventChangedId = b.LastChallengeEventChangedId
*/







/*
GROUP BY a.OpenId,
		 a.ChallengeId,
		 a.Status,
		 b.Timestamp AS TimeChallengeAssigned,
		 a.DateTimeEnded,
		 LastChallengeEventChangedId,
		 DateChallengeAssigned,
		 DateEnded,
		 TimeDiff
*/















	
