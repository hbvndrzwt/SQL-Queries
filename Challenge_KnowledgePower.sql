
-- Query to compare Learning Activity before and after Challenge 'Knowledge is Power' assigned to a user

/*
TO DO:
- Make sure the assign date has been 30 days ago

*/



-- 1. Load all Events relating to Challenges (after 1-11-2018 as before the data is not really good)
SELECT  *
INTO #ChallengeEvents
FROM PlatformAnalytics_PullPush_Platform_Event 
WHERE EventType IN('ChallengeAssigned', 'ChallengeCompleted', 'ChallengeExpired', 'ChallengeCreditClaimed')
AND Timestamp > '11-1-2018'

-- 2. Load all Events that are related to the Challenge 
SELECT *
INTO #LearnEvents
FROM PlatformAnalytics_PullPush_Platform_Event 
WHERE EventType IN ('OnlineLectureStarted', 'OnlineLectureCompleted')

SELECT  a.OpenId,
		a.ChallengeID,
		Timestamp,
		DateAssigned,
		CompanyId,
		SignupDate,
		CASE WHEN CountCreditsClaimed IS NULL THEN 0 ELSE CountCreditsClaimed END AS CountCreditsClaimed,
		LearnActivityBerforeChallenge,
		LearnActivityAfterChallenge,
		LearnActivityAfterChallenge - LearnActivityBerforeChallenge AS DiffLearnActivity
		
FROM
(
	SELECT   OpenId,
			 ChallengeID,
			 Timestamp,
			 DateAssigned,
			 CompanyId,
			 SignupDate,
			 SUM(CASE WHEN DateTimeLearnActivity < Timestamp THEN 1 ELSE 0 END) AS LearnActivityBerforeChallenge,
			 SUM(CASE WHEN DateTimeLearnActivity > Timestamp THEN 1 ELSE 0 END) AS LearnActivityAfterChallenge
	FROM
	(
		-- 3. Get all ChallengeAssigned events for the Challenge 'Knowledge is Power'
		SELECT  a.OpenId,
				Timestamp,
				DateAssigned,
				ChallengeID,
				CompanyId,
				SignupDate,
				DateActivity,
				DateTimeLearnActivity
		FROM
		(
		SELECT  OpenId,
				Timestamp,
				CONVERT(date, Timestamp) AS DateAssigned,
				ExtraInfo1 AS ChallengeID
		FROM #ChallengeEvents
		WHERE EventType = 'ChallengeAssigned' 
		AND ExtraInfo1 LIKE 'Qa4c8yju7a5hOU3gBvcQeZue29bDVVGF%'
		GROUP BY OpenId, 
				 Timestamp, 
				 ExtraInfo1, 
				 CONVERT(date, Timestamp)
		)a
		-- 4. Get user data to exclude Mendix employees
		LEFT JOIN
		(
			SELECT  OpenId,
					CompanyId,
					SignupDate
			FROM PlatformAnalytics_PullPush_Platform_User_Current
		)b
		ON a.OpenId = b.OpenId
		
					
		LEFT JOIN
		(
			SELECT  OpenId,
					Timestamp AS DateTimeLearnActivity,
					CONVERT(date, Timestamp) AS DateActivity
			FROM #LearnEvents
		)c
		ON a.OpenId = c.OpenId AND DateActivity > DATEADD(day, -30, DateAssigned) AND DateActivity < DATEADD(day, 30, DateAssigned)
		WHERE DATEADD(day, 30, SignupDate) < DateAssigned
		AND CompanyId NOT LIKE '%Mendix%'
	)a
	WHERE DateAssigned < DATEADD(day, -30, GETDATE())
	GROUP BY OpenId,
			 ChallengeID,
			 Timestamp,
			 DateAssigned,
			 CompanyId,
			 SignupDate
)a

LEFT JOIN
(
	SELECT  OpenId,
			ExtraInfo1 AS ChallengeId,
			COUNT(OpenId) AS CountCreditsClaimed
	FROM #ChallengeEvents
	WHERE EventType = 'ChallengeCreditClaimed' 
	GROUP BY OpenId,
			 ExtraInfo1
)b
ON a.OpenId = b.OpenId AND a.ChallengeID = b.ChallengeId





