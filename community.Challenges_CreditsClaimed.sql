-- This Query is designed to get an overview of the progress on Challenges for Users
-- Approx. QueryTime: 0min00sec



DROP TABLE community.Challenges_CreditsClaimed

-- 1. Load all 'ChallengeCreditClaimed', 'ChallengeCompleted' events into a temporary table
SELECT  *
INTO #Events
FROM PlatformAnalytics_PullPush_Platform_Event 
WHERE EventType IN('ChallengeCreditClaimed', 'ChallengeCompleted')

-- 2. Get all ChallengeCompleted events and group them by User & Challenge
SELECT  a.OpenId,
		a.ChallengeId,
		CountCompletedChallenge,
		CASE WHEN CountCreditsClaimed IS NULL THEN 0 ELSE CountCreditsClaimed END AS CountCreditsClaimed
INTO #UserChallenges
FROM 
(
	SELECT  OpenId,
			ChallengeId,
			COUNT(ChallengeId) AS CountCompletedChallenge
	FROM 
	(
		SELECT  OpenId,
				ExtraInfo1 AS ChallengeId,
				Timestamp
		FROM #Events
		WHERE EventType = 'ChallengeCompleted'
		GROUP BY OpenId,
				 ExtraInfo1,
				 Timestamp
	)a
	GROUP BY OpenId,
			 ChallengeId
)a

-- 3. Join CreditsClaimed events to user/challenge where the user claimed credits
LEFT JOIN
(
	SELECT OpenId,
			ExtraInfo1 AS ChallengeId,
			COUNT(ExtraInfo1) AS CountCreditsClaimed
	FROM #Events
	WHERE EventType = 'ChallengeCreditClaimed'
	GROUP BY OpenId,
			 ExtraInfo1	
)b
ON a.OpenId = b.OpenId AND a.ChallengeId = b.ChallengeId

-- 4. Join User data and write to table in datalake
SELECT a.*
INTO community.Challenges_CreditsClaimed
FROM
(
	SELECT *
	FROM #UserChallenges
)a

LEFT JOIN
(
	SELECT  OpenId,
			CompanyId
	FROM PlatformAnalytics_PullPush_Platform_User_Current
)b
ON a.OpenId = b.OpenId
WHERE NOT(CompanyId LIKE '%Mendix%')
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	