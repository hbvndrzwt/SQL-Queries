-- This Query is designed to get an overview of the progress on Challenges for Users

/*
Questions:
1. Is it possible for users to receive the same challenge multiple times?



*/

SELECT  *
INTO #Events
FROM PlatformAnalytics_PullPush_Platform_Event 
WHERE EventType IN('ChallengeAssigned', 'ChallengeCompleted', 'ChallengeCreditClaimed', 'ChallengeExpired', 'ChallengeStepCompleted')

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


SELECT *
INTO #ChallengeEnded
FROM
(
	SELECT * FROM #ChallengesExpired
	UNION
	SELECT * FROM #ChallengesCompleted
)a
ORDER BY OpenId

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


SELECT *
--INTO #ChallengesMerged
FROM
(
	SELECT * FROM #ChallengeEnded
	UNION
	SELECT * FROM #ChallengeNotEnded
)a
ORDER BY OpenId








/*
SELECT	a.OpenId,
		a.ChallengeId,
		a.Status,
		b.Timestamp AS TimeChallengeAssigned,
		a.DateTimeEnded,
		LastChallengeEventChangedId,
		c.Timestamp AS TimeCreditClaimed
INTO #ChallengesCompleted
FROM
(
	SELECT  a.OpenId,
			a.ChallengeId,
			a.DateTimeEnded,
			'Completed' AS Status,
			MAX(b.ChangedId) AS LastChallengeEventChangedId,
			MAX(c.ChangedId) AS LastCreditClaimedEventChangedId
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
	
	LEFT JOIN
	(
		SELECT  OpenId,
				ChangedId,
				ExtraInfo1 AS ChallengeId,
				Timestamp AS DateTimeCreditClaimed
		FROM #Events
		WHERE EventType IN ('ChallengeCreditClaimed')
	)c
	ON a.OpenId = c.OpenId AND a.ChallengeId = c.ChallengeId AND DateTimeEnded < DateTimeCreditClaimed
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
LEFT JOIN
(
	SELECT *
	FROM #Events
	WHERE EventType IN ('ChallengeCreditClaimed')
)c
ON a.LastCreditClaimedEventChangedId = c.ChangedId
*/

















	
