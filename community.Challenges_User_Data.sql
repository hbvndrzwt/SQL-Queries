
/*
A query to get Challenge Activity + Platform Activity of last 30 days on User level

Columns:
- OpenId 
- MxLevel (or Gamification Points) 
- Highest Certification
- Count Challenges Assigned (all time)
- Count Challenges Completed (all time)
- Count Challenges Credits Claimed (all time)

Activity data:
- Developer Activity: 
		'DevPortalVisit', (maybe this should be Platform Exploration??)
		'EditInWebmodelerClicked',
		'TeamserverCommit',
		'ViewAppClicked',
		'ModelDeployed',
		'SandboxDeployed',
		'WmDeployStarted',
		'WmProjectOpened',
		'ModelerDownloaded',
		
- Learning Activity:
		'OnlineLectureStarted',
		'OnlineLectureCompleted',
		
- Platform Exploration Activity: 
		'QuestionPosted',
		'CommentPosted',
		
- Knowledge Share Activity:
		'AppPublished',
		'DocumentationAdded', (is not used?)
		'BlogpostAdded',
		'AnswerPosted',

- Social Activity:
		'CompleteUserProfile',
		'ConnectionInviteAccepted',
		'ConnectionInviteSent',
		'ConnectMeetupAccount',
		'MendixReviewAdded',
		'ReferralInviteSent',
		'SetUserProfileToPublic'

*/

-- 1. Load all Events relating to Challenges (after 1-11-2018 as before the data is not really good)
SELECT  *
INTO #ChallengeEvents
FROM PlatformAnalytics_PullPush_Platform_Event 
WHERE EventType IN('ChallengeAssigned', 'ChallengeCompleted', 'ChallengeExpired', 'ChallengeCreditClaimed')
AND Timestamp > '11-1-2018'

-- 2. Load all Events from the last 30 days of users that fall in one of the categories. 
SELECT *
INTO #ActivityEvents
FROM PlatformAnalytics_PullPush_Platform_Event 
WHERE Timestamp > DATEADD(day, -30, GETDATE())
AND EventType IN ('EditInWebmodelerClicked', 'TeamserverCommit', 'ViewAppClicked', 'ModelDeployed',
				  'SandboxDeployed', 'WmDeployStarted', 'WmProjectOpened', 'ModelerDownloaded',
				  'OnlineLectureStarted', 'OnlineLectureCompleted', 'QuestionPosted', 'CommentPosted',
				  'AppPublished', 'DocumentationAdded', 'BlogpostAdded', 'AnswerPosted',
				  'CompleteUserProfile', 'ConnectionInviteAccepted', 'ConnectionInviteSent', 'ConnectMeetupAccount',
		          'MendixReviewAdded', 'ReferralInviteSent', 'SetUserProfileToPublic')
				  
-- 3. Get the counts for Challenge Events
SELECT  a.OpenId,
		CountChallengeAssigned,
		CountChallengeCompleted,
		CountChallengeExpired,
		CountChallengeCreditsClaimed,
		CountChallengeAssigned - CountChallengeCompleted - CountChallengeExpired AS CountCurrentlyActive,
		SignupDate,
		Country,
		DisplayName,
		CompanyType,
		CASE WHEN DevActivityLast30Days IS NULL THEN 0 ELSE DevActivityLast30Days END AS DevActivityLast30Days,
		CASE WHEN LearnActivityLast30Days IS NULL THEN 0 ELSE LearnActivityLast30Days END AS LearnActivityLast30Days,
		CASE WHEN ExploreActivityLast30Days IS NULL THEN 0 ELSE ExploreActivityLast30Days END AS ExploreActivityLast30Days,
		CASE WHEN KnowledgeShareActivityLast30Days IS NULL THEN 0 ELSE KnowledgeShareActivityLast30Days END AS KnowledgeShareActivityLast30Days,
		CASE WHEN SocialActivityLast30Days IS NULL THEN 0 ELSE SocialActivityLast30Days END AS SocialActivityLast30Days
		
FROM 
(
	SELECT  OpenId,
			SUM(CASE WHEN EventType = 'ChallengeAssigned' THEN 1 ELSE 0 END) AS CountChallengeAssigned,
			SUM(CASE WHEN EventType = 'ChallengeCompleted' THEN 1 ELSE 0 END) AS CountChallengeCompleted,
			SUM(CASE WHEN EventType = 'ChallengeExpired' THEN 1 ELSE 0 END) AS CountChallengeExpired,
			SUM(CASE WHEN EventType = 'ChallengeCreditClaimed' THEN 1 ELSE 0 END) AS CountChallengeCreditsClaimed
	FROM
	(
		SELECT  OpenId,
				EventType,
				ExtraInfo1 AS ChallengeId
		FROM #ChallengeEvents
		GROUP BY OpenId,
				 EventType,
				 ExtraInfo1
	)a
	GROUP BY OpenId
)a

-- 4. Add User/Company meta-data
LEFT JOIN
(
	SELECT  OpenId,
			SignupDate,
			Country,
			DisplayName,
			CompanyType
	FROM
	(
		SELECT  OpenId,
				CompanyId,
				SignupDate,
				Country
		FROM PlatformAnalytics_PullPush_Platform_User_Current
	)a
	
	LEFT JOIN
	(
		SELECT  CompanyId,
				DisplayName,
				CompanyType
		FROM PlatformAnalytics_PullPush_Platform_Company_Current
	)b
	ON a.CompanyId = b.CompanyId
)b
ON a.OpenId = b.OpenId	

-- 5. Add Non-Challenges last 30 days events
LEFT JOIN
(
	SELECT  OpenId,
			COUNT(EventType) AS DevActivityLast30Days
	FROM #ActivityEvents
	WHERE EventType IN ('EditInWebmodelerClicked', 'TeamserverCommit', 'ViewAppClicked', 'ModelDeployed',
						'SandboxDeployed', 'WmDeployStarted', 'WmProjectOpened', 'ModelerDownloaded')
	GROUP BY OpenId
)c
ON a.OpenId = c.OpenId

LEFT JOIN
(
	SELECT  OpenId,
			COUNT(EventType) AS LearnActivityLast30Days
	FROM #ActivityEvents
	WHERE EventType IN ('OnlineLectureStarted', 'OnlineLectureCompleted')
	GROUP BY OpenId
)d
ON a.OpenId = d.OpenId

LEFT JOIN
(
	SELECT  OpenId,
			COUNT(EventType) AS ExploreActivityLast30Days
	FROM #ActivityEvents
	WHERE EventType IN ('QuestionPosted', 'CommentPosted')
	GROUP BY OpenId
)e
ON a.OpenId = e.OpenId

LEFT JOIN
(
	SELECT  OpenId,
			COUNT(EventType) AS KnowledgeShareActivityLast30Days
	FROM #ActivityEvents
	WHERE EventType IN ('AppPublished', 'DocumentationAdded', 'BlogpostAdded', 'AnswerPosted')
	GROUP BY OpenId
)f
ON a.OpenId = f.OpenId

LEFT JOIN
(
	SELECT  OpenId,
			COUNT(EventType) AS SocialActivityLast30Days
	FROM #ActivityEvents
	WHERE EventType IN ('CompleteUserProfile', 'ConnectionInviteAccepted', 'ConnectionInviteSent', 'ConnectMeetupAccount',
						'MendixReviewAdded', 'ReferralInviteSent', 'SetUserProfileToPublic')
	GROUP BY OpenId
)g
ON a.OpenId = g.OpenId





		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		



