-- Goal of this query is to create a table of Product metrics on User-level which are used on Initiative-level

DROP TABLE community.Initiatives_KGM

;WITH UserCurrent AS
(
    SELECT  OpenId AS UserId, 
			CompanyId,
			email,
			CONVERT(date, OldSignupDate)AS SignupDate,
			dateadd(day, 30, OldSignupDate) AS LowerBoundary,
			dateadd(day, 60, OldSignupDate) AS UpperBoundary			
	FROM PlatformAnalytics_PullPush_Platform_User_Current 
	WHERE NOT(CompanyId LIKE '%Mendix%') AND OpenId != ''	
)

SELECT * INTO #UserCurrent 
FROM UserCurrent

;WITH EventData AS
(
	SELECT *
	FROM PlatformAnalytics_PullPush_Platform_Event
	WHERE EventType IN(
			'OnlineLectureStarted', 'TrainingAppLogin', 'AppLogin','AppPublished', 'AppReviewAdded', 'AppDownload',
			'BlogpostAdded', 'MendixReviewAdded', 'ModelerDownloaded', 'ModelshareDownloaded', 'ModelshareUploaded', 'TeamserverCommit',
			'DevPortalVisit', 'LaunchpadVisit', 'MessagePosted', 'PostCreated', 
			'ProjectCreated', 'StoryCreated', 'SuccessfulModelerLogin', 'ViewAppClicked',
			'FeedbackItemReplied', 'FeedbackItemCreated', 'AnswerPosted', 
			'CommentPosted', 'QuestionPosted', 'AppInviteSent', 'PlatformInviteSent',
			'ProjectInviteSent', 'ModelDeployed', 'CommentAdded', 
			'SandboxDeployed', 'EditInWebmodelerClicked', 'WmProjectOpened', 'WmDeploySucceeded',
			'ReferralInviteSent')
	AND Timestamp > '2017-12-01'
)		

SELECT * INTO #EventData
FROM EventData

-- ACTIVATION -- 	

;WITH EventDataActivation AS
(
	SELECT  OpenId,
			Timestamp AS EventDate,
			EventType
	FROM #EventData 
	WHERE EventType IN ('SandboxDeployed', 'WmDeploySucceeded') 
)

, EventsUniqueUser AS
(
	SELECT	OpenId,
			MIN(EventDate) AS EventDate
	FROM	EventDataActivation
	GROUP BY OpenId
)

, JoinUserEventDataActivation AS
(
	SELECT *
	FROM 
	(
		SELECT	UserId, 
				CompanyId,
				SignupDate,
				LowerBoundary,
				UpperBoundary
		FROM #UserCurrent
	) a
	LEFT JOIN 
	(
		SELECT *
		FROM EventsUniqueUser
	) b
	ON a.UserId = b.OpenId
)

-- Company Current is used in multiple parts of the Query, not only for Activation
, CompanyCurrent AS
(
	SELECT	CompanyId,
			CASE 
				WHEN SUM(CASE WHEN IsPartner = 1 THEN 1 ELSE 0 END) > 0 THEN 'Partner'	
				WHEN SUM(CASE WHEN IsCustomer = 1 THEN 1 ELSE 0 END) > 0 THEN 'Customer'
				WHEN SUM(CASE WHEN IsUniversity = 1 THEN 1 ELSE 0 END) > 0 THEN 'University'
				ELSE 'Other'
			END AS CompanyType
	FROM PlatformAnalytics_PullPush_Platform_Company_Current		
	GROUP BY CompanyId
)

, JoinCompanyUserEventActivation AS
(
	SELECT	a.UserId,
			a.CompanyId,
			SignupDate,
			LowerBoundary,
			UpperBoundary,
			EventDate,
			CASE 
				WHEN CompanyType IS NULL
					THEN 'Other'
				ELSE CompanyType
			END AS CompanyType
	FROM 
	(
		SELECT *
		FROM JoinUserEventDataActivation 
	) a
	LEFT JOIN
	(
		SELECT * 
		FROM CompanyCurrent
	) b
	ON a.CompanyId = b. CompanyId
)

, GroupedActivation AS
(
	SELECT	UserId,
			CompanyType,
			SignupDate,
			LowerBoundary,
			UpperBoundary,
			CASE WHEN datediff(day, SignupDate, MIN(EventDate)) <= 30 THEN 1 ELSE 0 END AS ActivatedWithin30days,
			MIN(EventDate) AS FirstDateOfEvent
	FROM JoinCompanyUserEventActivation
	GROUP BY UserId, CompanyType, SignupDate, LowerBoundary, UpperBoundary
)

--------------------------------------------------------------------------------------------------------------------------------

-- RETENTION --

, JoinCompanyUserRetention AS
(
	SELECT	a.UserId, 
			-- If the created date of the company is not set in platform analytics, this value will be NULL (4 cases known on 20180525)
			CASE 
				WHEN CompanyType IS NULL
					THEN 'Other'
				ELSE CompanyType
			END AS CompanyType,				
			SignupDate,
			LowerBoundary, 
			UpperBoundary
	FROM
	(
		SELECT	UserId, 
				CompanyId,
				SignupDate,
				LowerBoundary,
				UpperBoundary 
		FROM #UserCurrent
	) a
	LEFT JOIN
	(
		SELECT *
		FROM CompanyCurrent
	) b
	ON a.CompanyId = b.CompanyId
)

, EventDataRetention AS
(
	SELECT	OpenId,
			dateadd(day,datediff(day,0,Timestamp),0) AS YearMonthDay
	FROM #EventData
	GROUP BY OpenId, dateadd(day,datediff(day,0,Timestamp),0)
)

, GroupedRetention AS
(
	SELECT a.UserId, 
			CompanyType,					
			SignupDate, 
			LowerBoundary, 
			UpperBoundary, 
			COUNT(DISTINCT(YearMonthDay)) AS DaysActiveInSecondMonth 
	FROM 
	(
		SELECT *
		FROM JoinCompanyUserRetention
	) a
	LEFT JOIN
	(
		SELECT * 
		FROM EventDataRetention
	) b
	ON a.UserId = b.OpenId AND YearMonthDay BETWEEN LowerBoundary AND UpperBoundary
	GROUP BY a.UserId,
			 CompanyType,
			 SignupDate,
			 LowerBoundary, 
			 UpperBoundary
)

--------------------------------------------------------------------------------------------------------------------------------

-- INVITES SENT -- 

, EventDataInvites AS
(
	SELECT	OpenIdSender,
			SignupDateSender,
			CompanyType,
			SignupDateReceiver,
			InviteDate
			
	FROM 
	(
		SELECT	OpenId,
				ExtraInfo1 AS EmailAddressReceiver, 
				Timestamp AS InviteDate 
		FROM #EventData
		WHERE EventType IN ('AppInviteSent','PlatformInviteSent','ProjectInviteSent','ReferralInviteSent')
		AND NOT(CompanyId LIKE '%Mendix%') AND OpenId != ''
	) a
	
	LEFT JOIN
	(
		SELECT	CompanyId AS CompanyIdReceiver,
				email,
				SignupDate AS SignupDateReceiver 
		FROM #UserCurrent
	) b
	ON a.EmailAddressReceiver = b.email
	
	RIGHT JOIN
	(
		SELECT	UserId AS OpenIdSender,
				CompanyId AS CompanyIdSender,
				SignupDate AS SignupDateSender 
		FROM #UserCurrent
	) c 
	ON a.OpenId = c.OpenIdSender
	
	LEFT JOIN
	(
		SELECT *
		FROM CompanyCurrent
	) d
	ON c.CompanyIdSender = d.CompanyId
)

, GroupedInvites AS
(
	SELECT	OpenIdSender,
			SignupDateSender,

			-- If the created date of the company is not set in platform analytics, this value will be NULL (4 cases known on 20180525)
			CASE 
				WHEN CompanyType IS NULL
					THEN 'Other'
				ELSE CompanyType
			END AS CompanyType,				
			SUM(CASE WHEN InviteDate < SignupDateReceiver OR (SignupDateReceiver IS NULL AND NOT(InviteDate IS NULL)) THEN 1 ELSE 0 END) AS NumberInvitesToNonMembers,
			SUM(CASE WHEN (InviteDate < SignupDateReceiver OR (SignupDateReceiver IS NULL AND NOT(InviteDate IS NULL))) AND DATEDIFF(day, SignupDateSender, InviteDate) <= 30 THEN 1 ELSE 0 END) AS NumberInvitesToNonMembersWithinFirst30Days
	FROM EventDataInvites
	GROUP BY OpenIdSender,
			 SignupDateSender,
			 CompanyType
)


--------------------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------------------------------------------------------

--From here the Grouped tables will be merged into a table with all KGM (relevant for Initiative) grouped per user\

, KeyGrowthMetrics AS
(
	SELECT	a.UserId,
			a.CompanyType,
			a.SignupDate,
			a.LowerBoundary,
			a.UpperBoundary,
			ActivatedWithin30days,
			CASE 
				WHEN DaysActiveInSecondMonth > 0
					THEN 1
				ELSE 0
			END AS Retained,
			NumberInvitesToNonMembers,
			NumberInvitesToNonMembersWithinFirst30Days
			
	FROM
	( 
		SELECT *
		FROM GroupedActivation
	) a
	
	LEFT JOIN
	(
		SELECT *
		FROM GroupedRetention
	) b
	ON a.UserId = b.UserId
	
	LEFT JOIN
	(
		SELECT *
		FROM GroupedInvites
	) c
	ON a.UserId = c.OpenIdSender
)
	
SELECT * INTO community.Initiatives_KGM FROM KeyGrowthMetrics













			
			
			
			
			
			
			
			
			
			
			
			
	