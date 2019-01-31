/*
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

-- Load all Events from the last 30 days of users that fall in one of the categories. 
SELECT *
INTO #ActivityEvents
FROM PlatformAnalytics_PullPush_Platform_Event 
WHERE Timestamp BETWEEN '11-1-2018' AND '1-1-2019' 
AND EventType IN ('EditInWebmodelerClicked', 'TeamserverCommit', 'ViewAppClicked', 'ModelDeployed',
				  'SandboxDeployed', 'WmDeployStarted', 'WmProjectOpened', 'ModelerDownloaded',
				  'OnlineLectureStarted', 'OnlineLectureCompleted', 'QuestionPosted', 'CommentPosted',
				  'AppPublished', 'DocumentationAdded', 'BlogpostAdded', 'AnswerPosted',
				  'CompleteUserProfile', 'ConnectionInviteAccepted', 'ConnectionInviteSent', 'ConnectMeetupAccount',
		          'MendixReviewAdded', 'ReferralInviteSent', 'SetUserProfileToPublic')
				  

SELECT 	 a.OpenId,
		 ChallengeId,
		 Status,
		 TimeChallengeAssigned,
		 DateTimeEnded,
		 LastChallengeEventChangedId,
		 CONVERT(DATE, TimeChallengeAssigned) AS DateAssigned,
		 CONVERT(DATE, DateTimeEnded) AS DateEnded,
		 DATEDIFF(hour, TimeChallengeAssigned, DateTimeEnded) AS TimeDiff,
		 COUNT(c.EventType) AS DevActivity
INTO #DevActivity
FROM
(
	SELECT *
	FROM community.Challenges_Progress
)a

-- Add Developer Activity metrics
LEFT JOIN
(
	SELECT  OpenId,
			Timestamp,
			EventType
	FROM #ActivityEvents 
	WHERE EventType IN ('EditInWebmodelerClicked', 'TeamserverCommit', 'ViewAppClicked', 'ModelDeployed',
						'SandboxDeployed', 'WmDeployStarted', 'WmProjectOpened', 'ModelerDownloaded')
)c
ON a.OpenId = c.OpenId AND c.Timestamp BETWEEN a.TimeChallengeAssigned AND DATEADD(day, 30, a.TimeChallengeAssigned)
GROUP BY a.OpenId,
		 ChallengeId,
		 Status,
		 TimeChallengeAssigned,
		 DateTimeEnded,
		 LastChallengeEventChangedId,
		 CONVERT(DATE, TimeChallengeAssigned),
		 CONVERT(DATE, DateTimeEnded),
		 DATEDIFF(hour, TimeChallengeAssigned, DateTimeEnded)
		 

SELECT 	 a.OpenId,
		 ChallengeId,
		 Status,
		 TimeChallengeAssigned,
		 DateTimeEnded,
		 LastChallengeEventChangedId,
		 DateAssigned,
		 DateEnded,
		 TimeDiff,
		 DevActivity,
		 COUNT(c.EventType) AS LearnActivity
INTO #LearnActivity
FROM
(
	SELECT *
	FROM #DevActivity
)a

-- Add Learn Activity metrics
LEFT JOIN
(
	SELECT  OpenId,
			Timestamp,
			EventType
	FROM #ActivityEvents 
	WHERE EventType IN ('OnlineLectureStarted', 'OnlineLectureCompleted')
)c
ON a.OpenId = c.OpenId AND c.Timestamp BETWEEN a.TimeChallengeAssigned AND DATEADD(day, 30, a.TimeChallengeAssigned)
GROUP BY a.OpenId,
		 ChallengeId,
		 Status,
		 TimeChallengeAssigned,
		 DateTimeEnded,
		 LastChallengeEventChangedId,
		 DateAssigned,
		 DateEnded,
		 TimeDiff,
		 DevActivity

		 
SELECT 	 a.OpenId,
		 ChallengeId,
		 Status,
		 TimeChallengeAssigned,
		 DateTimeEnded,
		 LastChallengeEventChangedId,
		 DateAssigned,
		 DateEnded,
		 TimeDiff,
		 DevActivity,
		 LearnActivity,
		 COUNT(c.EventType) AS ExploreActivity
INTO #ExploreActivity
FROM
(
	SELECT *
	FROM #LearnActivity
)a

-- Add Explore Activity metrics
LEFT JOIN
(
	SELECT  OpenId,
			Timestamp,
			EventType
	FROM #ActivityEvents 
	WHERE EventType IN ('QuestionPosted', 'CommentPosted')
)c
ON a.OpenId = c.OpenId AND c.Timestamp BETWEEN a.TimeChallengeAssigned AND DATEADD(day, 30, a.TimeChallengeAssigned)
GROUP BY a.OpenId,
		 ChallengeId,
		 Status,
		 TimeChallengeAssigned,
		 DateTimeEnded,
		 LastChallengeEventChangedId,
		 DateAssigned,
		 DateEnded,
		 TimeDiff,
		 DevActivity,
		 LearnActivity


SELECT 	 a.OpenId,
		 ChallengeId,
		 Status,
		 TimeChallengeAssigned,
		 DateTimeEnded,
		 LastChallengeEventChangedId,
		 DateAssigned,
		 DateEnded,
		 TimeDiff,
		 DevActivity,
		 LearnActivity,
		 ExploreActivity,
		 COUNT(c.EventType) AS ShareActivity
INTO #ShareActivity
FROM
(
	SELECT *
	FROM #ExploreActivity
)a

-- Add Knowledge Share Activity metrics
LEFT JOIN
(
	SELECT  OpenId,
			Timestamp,
			EventType
	FROM #ActivityEvents 
	WHERE EventType IN ('AppPublished', 'DocumentationAdded', 'BlogpostAdded', 'AnswerPosted')
)c
ON a.OpenId = c.OpenId AND c.Timestamp BETWEEN a.TimeChallengeAssigned AND DATEADD(day, 30, a.TimeChallengeAssigned)
GROUP BY a.OpenId,
		 ChallengeId,
		 Status,
		 TimeChallengeAssigned,
		 DateTimeEnded,
		 LastChallengeEventChangedId,
		 DateAssigned,
		 DateEnded,
		 TimeDiff,
		 DevActivity,
		 LearnActivity,
		 ExploreActivity

SELECT 	 a.OpenId,
		 ChallengeId,
		 Status,
		 TimeChallengeAssigned,
		 DateTimeEnded,
		 LastChallengeEventChangedId,
		 DateAssigned,
		 DateEnded,
		 TimeDiff,
		 DevActivity,
		 LearnActivity,
		 ExploreActivity,
		 ShareActivity,
		 COUNT(c.EventType) AS SocialActivity
INTO #SocialActivity
FROM
(
	SELECT *
	FROM #ShareActivity
)a

-- Add Knowledge Share Activity metrics
LEFT JOIN
(
	SELECT  OpenId,
			Timestamp,
			EventType
	FROM #ActivityEvents 
	WHERE EventType IN ('CompleteUserProfile', 'ConnectionInviteAccepted', 'ConnectionInviteSent', 'ConnectMeetupAccount',
						'MendixReviewAdded', 'ReferralInviteSent', 'SetUserProfileToPublic')
)c
ON a.OpenId = c.OpenId AND c.Timestamp BETWEEN a.TimeChallengeAssigned AND DATEADD(day, 30, a.TimeChallengeAssigned)
GROUP BY a.OpenId,
		 ChallengeId,
		 Status,
		 TimeChallengeAssigned,
		 DateTimeEnded,
		 LastChallengeEventChangedId,
		 DateAssigned,
		 DateEnded,
		 TimeDiff,
		 DevActivity,
		 LearnActivity,
		 ExploreActivity,
		 ShareActivity
		 
SELECT * FROM #SocialActivity