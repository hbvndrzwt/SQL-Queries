


/*
Developer Activity: 'SandboxDeployed', 'WmDeploySucceeded', 'TeamserverCommit', 'SuccessfulModelerLogin', 'ModelDeployed'
Learn Activity: 'OnlineCourseStarted', 'OnlineLectureStarted', 'OnlineModuleStarted', 'OnlineCourseCompleted', 'OnlineLectureCompleted', 'OnlineModuleCompleted'
Other Activity: 'StoryCreated', 'CompleteUserProfile', 'ProjectInviteSent', 'CommentAdded', 'ConnectionInviteSent', 'QuestionPosted', 'ConnectMeetupAccount', 'Upvoted'
*/

DROP TABLE community.Onboarding_New_Users

SELECT  *
INTO #Events
FROM PlatformAnalytics_PullPush_Platform_Event 
WHERE EventType IN('SandboxDeployed', 'WmDeploySucceeded', 'TeamserverCommit', 'SuccessfulModelerLogin', 'ModelDeployed',
					'OnlineCourseStarted', 'OnlineLectureStarted', 'OnlineModuleStarted', 'OnlineCourseCompleted', 'OnlineLectureCompleted', 'OnlineModuleCompleted',
					'StoryCreated', 'CompleteUserProfile', 'ProjectInviteSent', 'CommentAdded', 'ConnectionInviteSent', 'QuestionPosted', 'ConnectMeetupAccount', 'Upvoted')




SELECT	UserId,
		CompanyId,
		DisplayName,
		CompanyType,
		Source,
		MonthYear,
		SignupDate,
		FirstActivationDate,
		Activated
INTO #FullUsers
FROM 
(
	SELECT	a.OpenId AS UserId,
			a.CompanyId,
			DisplayName,
			CompanyType,
			MonthYear,
			SignupDate,
			Source,
			FirstActivationDate,
			CASE 
				WHEN datediff(day, SignupDate, FirstActivationDate) <= 30 
					THEN 1 
				ELSE 0 
			END AS Activated
	FROM 
	(
		SELECT	a.OpenId, 
				a.CompanyId,
				DisplayName,
				-- If the created date of the company is not set in platform analytics, this value will be NULL (4 cases known on 20180525)
				CASE 
					WHEN CompanyType IS NULL
						THEN 'Other'
					ELSE CompanyType
				END AS CompanyType,				
				MonthYear, 
				SignupDate, 
				CASE 
					WHEN SignupReason IN ('App Invitation', 'Platform Invitation', 'Project Invitation') 
						THEN 'Invites'
					ELSE 'Marketing Inbound'
				END AS Source
		FROM 
		(
			SELECT	OpenId, 
					CompanyId, 
					CONVERT(DATE, OldSignupDate) AS SignupDate,
					dateadd(month,datediff(month,0,OldSignupDate),0) AS MonthYear 
			FROM PlatformAnalytics_PullPush_Platform_User_Current 
			WHERE OpenId != '' AND NOT(CompanyId LIKE '%Mendix%')
		) a

		LEFT JOIN 
		(
			SELECT  OpenId, 
					MAX(ExtraInfo1) As SignupReason
			FROM PlatformAnalytics_PullPush_Platform_Event
			WHERE EventType = 'MemberSignupCompleted' AND OpenId != ''
			GROUP BY OpenId
		) b
		ON a.OpenId = b.OpenId

		LEFT JOIN 
		(
			SELECT	CompanyId,
					DisplayName,
					CASE 
						WHEN SUM(CASE WHEN IsPartner = 1 THEN 1 ELSE 0 END) > 0 THEN 'Partner'	
						WHEN SUM(CASE WHEN IsCustomer = 1 THEN 1 ELSE 0 END) > 0 THEN 'Customer'
						WHEN SUM(CASE WHEN IsUniversity = 1 THEN 1 ELSE 0 END) > 0 THEN 'University'
						ELSE 'Other'
					END AS CompanyType
			FROM PlatformAnalytics_PullPush_Platform_Company_Current	
			GROUP BY CompanyId,
					 DisplayName
		) c
		ON a.CompanyId = c.CompanyId
	) a

	-- Activation moment
	-- Determine what the first date is of a deploy is for the user
	LEFT JOIN 
	(
		SELECT	OpenId,
				MIN(EventDate) AS FirstActivationDate
		FROM 
		(
			SELECT	OpenId, 
					Timestamp AS EventDate,
					EventType
			FROM #Events
			WHERE EventType IN ('SandboxDeployed', 'WmDeploySucceeded')
		) a
		GROUP BY OpenId
	) b
	ON a.OpenId = b.OpenId
	WHERE MonthYear < dateadd(month,datediff(month,0,GETDATE()),0)
) a


;WITH DevActivityAdded AS
(
	SELECT  a.*,
			SUM(CASE WHEN YearMonthDayDev = SignupDate THEN 1 ELSE 0 END) AS ActiveFirstDayDev,
			SUM(CASE WHEN YearMonthDayDev BETWEEN dateadd(day, 1, SignupDate) AND dateadd(day, 8, SignupDate) THEN 1 ELSE 0 END) AS ActiveDays1To8DaysAfterSignupDev,
			SUM(CASE WHEN YearMonthDayDev BETWEEN dateadd(day, 1, SignupDate) AND dateadd(day, 14, SignupDate) THEN 1 ELSE 0 END) AS ActiveDays1To15DaysAfterSignupDev,
			SUM(CASE WHEN YearMonthDayDev BETWEEN dateadd(day, 1, SignupDate) AND dateadd(day, 30, SignupDate) THEN 1 ELSE 0 END) AS ActiveDays1To30DaysAfterSignupDev
	FROM
	(
		SELECT *
		FROM #FullUsers
	) a
	
	LEFT JOIN
	(
		SELECT	OpenId, 
				dateadd(day,datediff(day,0,Timestamp),0) AS YearMonthDayDev
		FROM #Events
		WHERE EventType IN ('ModelerDownloaded', 'SandboxDeployed', 'AppDownload', 'WmDeploySucceeded', 'TeamserverCommit', 'SuccessfulModelerLogin', 'ModelDeployed')
		GROUP BY OpenId, 
				 dateadd(day,datediff(day,0,Timestamp),0)
	) b
	ON a.UserId = b.OpenId AND YearMonthDayDev BETWEEN SignupDate AND dateadd(day, 30, SignupDate)
	
	GROUP BY    UserId, 
				CompanyId,
				DisplayName,				 
				CompanyType, 
				MonthYear, 
				SignupDate, 
				Source, 
				FirstActivationDate,
				Activated
)

, LearnActivityAdded AS
(
	SELECT  a.*,
			SUM(CASE WHEN YearMonthDayLearn = SignupDate THEN 1 ELSE 0 END) AS ActiveFirstDayLearn,
			SUM(CASE WHEN YearMonthDayLearn BETWEEN dateadd(day, 1, SignupDate) AND dateadd(day, 8, SignupDate) THEN 1 ELSE 0 END) AS ActiveDays1To8DaysAfterSignupLearn,
			SUM(CASE WHEN YearMonthDayLearn BETWEEN dateadd(day, 1, SignupDate) AND dateadd(day, 14, SignupDate) THEN 1 ELSE 0 END) AS ActiveDays1To15DaysAfterSignupLearn,
			SUM(CASE WHEN YearMonthDayLearn BETWEEN dateadd(day, 1, SignupDate) AND dateadd(day, 30, SignupDate) THEN 1 ELSE 0 END) AS ActiveDays1To30DaysAfterSignupLearn
	FROM
	(
		SELECT *
		FROM DevActivityAdded
	) a
	
	LEFT JOIN
	(
		SELECT	OpenId, 
				dateadd(day,datediff(day,0,Timestamp),0) AS YearMonthDayLearn
		FROM #Events
		WHERE EventType IN ('OnlineCourseStarted', 'OnlineLectureStarted', 'OnlineModuleStarted', 'OnlineCourseCompleted', 'OnlineLectureCompleted', 'OnlineModuleCompleted')
		GROUP BY OpenId, 
				 dateadd(day,datediff(day,0,Timestamp),0)
	) b
	ON a.UserId = b.OpenId AND YearMonthDayLearn BETWEEN SignupDate AND dateadd(day, 30, SignupDate)
	
	GROUP BY    UserId, 
				CompanyId,
				DisplayName,				 
				CompanyType, 
				MonthYear, 
				SignupDate, 
				Source, 
				FirstActivationDate,
				Activated,
				ActiveFirstDayDev,
				ActiveDays1To8DaysAfterSignupDev,
				ActiveDays1To15DaysAfterSignupDev,
				ActiveDays1To30DaysAfterSignupDev
)
	
, OtherActivityAdded AS
(
	SELECT  a.*,
			SUM(CASE WHEN YearMonthDayOther = SignupDate THEN 1 ELSE 0 END) AS ActiveFirstDayOther,
			SUM(CASE WHEN YearMonthDayOther BETWEEN dateadd(day, 1, SignupDate) AND dateadd(day, 8, SignupDate) THEN 1 ELSE 0 END) AS ActiveDays1To8DaysAfterSignupOther,
			SUM(CASE WHEN YearMonthDayOther BETWEEN dateadd(day, 1, SignupDate) AND dateadd(day, 14, SignupDate) THEN 1 ELSE 0 END) AS ActiveDays1To15DaysAfterSignupOther,
			SUM(CASE WHEN YearMonthDayOther BETWEEN dateadd(day, 1, SignupDate) AND dateadd(day, 30, SignupDate) THEN 1 ELSE 0 END) AS ActiveDays1To30DaysAfterSignupOther
	FROM
	(
		SELECT *
		FROM LearnActivityAdded
	) a
	
	LEFT JOIN
	(
		SELECT	OpenId, 
				dateadd(day,datediff(day,0,Timestamp),0) AS YearMonthDayOther
		FROM #Events
		WHERE EventType IN ('StoryCreated', 'MessagePosted', 'ProjectInviteSent', 'CommentAdded', 'FeedbackItemCreated', 'QuestionPosted')
		GROUP BY OpenId, 
				 dateadd(day,datediff(day,0,Timestamp),0)
	) b
	ON a.UserId = b.OpenId AND YearMonthDayOther BETWEEN SignupDate AND dateadd(day, 30, SignupDate)
	
	GROUP BY    UserId, 
				CompanyId,
				DisplayName,				 
				CompanyType, 
				MonthYear, 
				SignupDate, 
				Source, 
				FirstActivationDate,
				Activated,
				ActiveFirstDayDev,
				ActiveDays1To8DaysAfterSignupDev,
				ActiveDays1To15DaysAfterSignupDev,
				ActiveDays1To30DaysAfterSignupDev,
				ActiveFirstDayLearn,
				ActiveDays1To8DaysAfterSignupLearn,
				ActiveDays1To15DaysAfterSignupLearn,
				ActiveDays1To30DaysAfterSignupLearn
)	

, TotalActivityAdded AS
(
	SELECT  a.*,
			SUM(CASE WHEN YearMonthDay BETWEEN dateadd(day, 1, SignupDate) AND dateadd(day, 30, SignupDate) THEN 1 ELSE 0 END) AS ActiveDays1To30DaysAfterSignup,
			SUM(CASE WHEN YearMonthDay BETWEEN dateadd(day, 30, SignupDate) AND dateadd(day, 60, SignupDate) THEN 1 ELSE 0 END) AS ActiveDays30To60DaysAfterSignup
	FROM
	(
		SELECT *
		FROM OtherActivityAdded
	) a
	
	LEFT JOIN
	(
		SELECT	OpenId, 
				dateadd(day,datediff(day,0,Timestamp),0) AS YearMonthDay
		FROM PlatformAnalytics_PullPush_Platform_Event
		WHERE EventType IN (
					'OnlineCourseStarted', 'OnlineLectureStarted', 'OnlineModuleStarted', 'OnlineCourseCompleted', 'OnlineLectureCompleted', 'OnlineModuleCompleted',
					'AppLogin', 'AppNewVersion', 'AppPublished', 'AppReviewAdded', 'AppDownload',
					'BlogpostAdded', 'MeetupAttended', 'MeetupOrganized', 'MendixReviewAdded',
					'ModelerDownloaded', 'SandboxDeployed', 'AppDownload', 'WmDeploySucceeded', 'TeamserverCommit', 'SuccessfulModelerLogin', 'ModelDeployed',
					'DevPortalVisit', 'LaunchpadVisit', 'MessagePosted', 'PostCreated', 'PostLiked', 'PostUnliked', 'ProjectCreated', 'StoryCreated', 'SuccessfulModelerLogin', 'ViewAppClicked',
					'AcceptedAnswerRemoved', 'AnswerPosted', 'LikedQuestion', 'MarkedAnswerAsAccepted', 'QuestionPosted', 'Upvoted', 'UpvoteRemoved',
					'AppInviteSent', 'PlatformInviteSent', 'ProjectInviteSent', 'ModelDeployed', 'CommentAdded', 'CommentLiked', 'SandboxDeployed',
					'EditInWebmodelerClicked', 'WmProjectOpened')
		GROUP BY OpenId, 
				 dateadd(day,datediff(day,0,Timestamp),0)
	) b
	ON a.UserId = b.OpenId AND YearMonthDay BETWEEN SignupDate AND dateadd(day, 60, SignupDate)
	GROUP BY    UserId, 
			CompanyId,
			DisplayName,				 
			CompanyType, 
			MonthYear, 
			SignupDate, 
			Source, 
			FirstActivationDate,
			Activated,
			ActiveFirstDayDev,
			ActiveDays1To8DaysAfterSignupDev,
			ActiveDays1To15DaysAfterSignupDev,
			ActiveDays1To30DaysAfterSignupDev,
			ActiveFirstDayLearn,
			ActiveDays1To8DaysAfterSignupLearn,
			ActiveDays1To15DaysAfterSignupLearn,
			ActiveDays1To30DaysAfterSignupLearn,
			ActiveFirstDayOther,
			ActiveDays1To8DaysAfterSignupOther,
			ActiveDays1To15DaysAfterSignupOther,
			ActiveDays1To30DaysAfterSignupOther
)	

, SignupQuestionAdded AS
(
	SELECT  a.*,
			CustomerType
	FROM
	(
		SELECT  *,
				CASE WHEN ActiveDays30To60DaysAfterSignup > 0 THEN 1 ELSE 0 END AS Retained
		FROM TotalActivityAdded
	) a
		
	LEFT JOIN
	(
		SELECT  OpenId,
				CustomerType
		FROM community.CustomerTypes
	) b
	ON a.UserId = b.OpenId
	
)
		
		
SELECT * 
INTO community.Onboarding_New_Users
FROM SignupQuestionAdded