/*
==================================================================================================================
Existing Active User Retention Rate
==================================================================================================================]
Estimation of runtime: 12m35s

Definitions
-----------
- Existing User: For the last active day in a given month, the user performed an activity 30-60 days before that day. ( The user was active the month before a given month).
- New Existing User: A user that is an Existing user for the first time. 
- Resurrected Existing User: A user with an activity in a given month, who was a churned user in the previous month.
- Churned User: A user with no activity in a given month and has been Existing user in the past.

Goal
----
We need to understand how many (and which) of the Existing Active Users we can retain.  

Rationale
---------
We need a measure that captures how many of the users that are using Mendix we can retain over time. 
Therefore, this metric excludes 'New Users' for a reason; to eliminate the effect of sudden increases of New Users (who too often do not really use the platform after their signup). 
If we observe a drop in this metric, we need to understand why we are losing users that have previously used Mendix. 

Required splits
---------------
- What type of Existing user a user is in a given month


Required output for PowerBI (Taking into account the splits)
---------------------------
- User data of all Existing Active Users per month
- User data of all Retained Existing Active Users of that month (this means we will miss the last two months of data)
- User intensity of the given month (how many active days the user has) 


Query Plan
---------
1) Retrieve All the active users in a given month
2) Determine their last activity date in a month
3) Check whether their signup date is 30 days before their last activity date
4) Filter out users for who their signup date is not 30 days before their last activity date (so now we only have Existing Active Users)
5) Use the last activity date to set a lowerbound (+30 days) and upperbound (+60 days)
6) Based on the lower- and upperbound, check whether the users show any activity during that time period (if yes, this is a retained user)
7) ...
*/


DROP TABLE community.Product_Existing_Users

SELECT  UserId,
		MonthYear,
		LastActiveDateInMonth,
		ActiveDaysInMonth,
		LastActiveDateBeforeMonth,
		IsChurner,
		ExistingUser,
		IsDeveloper,
		DaysActiveInSecondMonth,
		CASE WHEN DATEDIFF(month, MonthYear, dateadd(month,datediff(month,0,GETDATE()),0)) > 2 THEN ExistingUsersActiveInSecondMonth ELSE 0 END AS ExistingUsersActiveInSecondMonth,
		CASE WHEN DATEDIFF(month, MonthYear, dateadd(month,datediff(month,0,GETDATE()),0)) > 2 THEN ExistingUsersNotActiveInSecondMonth ELSE 0 END AS ExistingUsersNotActiveInSecondMonth 

INTO #ExistingUsers			
FROM
(
	SELECT 	a.UserId,
			a.MonthYear,
			a.LastActiveDateInMonth,	
			ActiveDaysInMonth,
			MAX(b.LastActiveDateInMonth) AS LastActiveDateBeforeMonth,
			CASE WHEN DATEDIFF ( month , MAX(b.LastActiveDateInMonth) , a.MonthYear ) > 1  THEN 1 ELSE 0 END AS IsChurner,
			-- AND DATEDIFF ( month , MAX(b.LastActiveDateInMonth) , a.MonthYear ) <= 12
			ExistingUser,
			IsDeveloper,
			DaysActiveInSecondMonth,
			CASE WHEN ExistingUser = 1 AND DaysActiveInSecondMonth > 0 THEN 1 ELSE 0 END AS ExistingUsersActiveInSecondMonth,
			CASE WHEN ExistingUser = 1 AND DaysActiveInSecondMonth = 0 THEN 1 ELSE 0 END AS ExistingUsersNotActiveInSecondMonth
			
	FROM 
	(
		SELECT 	a.UserId,
				MonthYear,
				LowerBoundary,
				UpperBoundary,
				SignupDate,
				LastActiveDateInMonth,	
				ActiveDaysInMonth,
				CASE WHEN datediff(day, SignupDate, LastActiveDateInMonth) > 30 THEN 1 ELSE 0 END AS ExistingUser,
				CASE WHEN IsDeveloper > 0 THEN 1 ELSE 0 END AS IsDeveloper,
				COUNT(DISTINCT(b.YearMonthDay)) AS DaysActiveInSecondMonth
		FROM 
		(
			SELECT	UserId,
					MonthYear,
					LastActiveDateInMonth,
					ActiveDaysInMonth,
					dateadd(day, 30, MAX(LastActiveDateInMonth)) AS LowerBoundary,
					dateadd(day, 60, MAX(LastActiveDateInMonth)) AS UpperBoundary,
					IsDeveloper,
					SignupDate
			FROM 
			(
				SELECT	UserId, 
						MonthYear, 
						FirstActiveDateInMonth,
						LastActiveDateInMonth,
						ActiveDaysInMonth,
						SUM(CASE WHEN UserTypeMonth = 'Developer' THEN 1 ELSE 0 END) AS IsDeveloper
				FROM PlatformAnalytics_Processed_Users_Month  
				WHERE ActiveMonth = 'Active' AND NOT(CompanyId LIKE '%Mendix%') AND UserId != ''
				GROUP BY UserId,
						 MonthYear, 
						 FirstActiveDateInMonth, 
						 LastActiveDateInMonth, 
						 ActiveDaysInMonth
			) a

			LEFT JOIN 
			(
				SELECT  OpenId, 
						OldSignupDate AS SignupDate 
				FROM PlatformAnalytics_PullPush_Platform_User_Current
			) b
			ON a.UserId = b.OpenId
			-- Added Group BY 
			GROUP BY UserId, 
					 MonthYear, 
					 LastActiveDateInMonth, 
					 ActiveDaysInMonth,
					 IsDeveloper, 
					 SignupDate
		) a

		LEFT JOIN 
		(
			SELECT	OpenId, 
					dateadd(day,datediff(day,0,Timestamp),0) AS YearMonthDay	
			FROM PlatformAnalytics_PullPush_Platform_Event 
			WHERE EventType IN(
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

		ON a.UserId = b.OpenId AND YearMonthDay BETWEEN LowerBoundary AND UpperBoundary

		GROUP BY a.UserId,
				 MonthYear,
				 LowerBoundary,
				 UpperBoundary,
				 SignupDate,
				 LastActiveDateInMonth,	
				 ActiveDaysInMonth,
				 IsDeveloper
	) a

	-- 2) Secondly, for each month, we need to know the last Date in which the User was considered 'Active' that is in (or before) the month we are looking at
	LEFT JOIN 
	(
		SELECT  UserId, 
				MonthYear, 
				LastActiveDateInMonth
		FROM PlatformAnalytics_Processed_Users_Month
		GROUP BY UserId, 
				 MonthYear, 
				 LastActiveDateInMonth
	) b
	ON b.MonthYear < a.MonthYear AND b.UserId = a.UserId AND b.LastActiveDateInMonth >= SignupDate 

	GROUP BY a.UserId,
			 a.MonthYear,
			 a.LastActiveDateInMonth, 
			 ActiveDaysInMonth,
			 IsDeveloper, 
			 ExistingUser, 
			 DaysActiveInSecondMonth

)a
WHERE MonthYear < dateadd(month,datediff(month,0,GETDATE()),0) AND ExistingUser = 1


SELECT  a.UserId,
		MonthYear,
		LastActiveDateInMonth,
		ActiveDaysInMonth,
		LastActiveDateBeforeMonth,
		IsDeveloper,
		ExistingUsersActiveInSecondMonth,
		DaysActiveInSecondMonth,
		CASE 
			WHEN b.FirstMonthExistingUser IS NOT NULL THEN 'New Existing User'
			WHEN b.FirstMonthExistingUser IS NULL AND IsChurner = 1 THEN 'Resurrected Existing User'
			ELSE 'Existing User'
		END AS ExistingUserType
INTO #ExistingUsersTotal
FROM 
(
	SELECT *
	FROM #ExistingUsers
)a

LEFT JOIN
(
	SELECT  UserId, 
			MIN(MonthYear) AS FirstMonthExistingUser
	FROM #ExistingUsers
	GROUP BY UserId
)b
ON a.UserId = b.UserId AND a.MonthYear = b.FirstMonthExistingUser



/*
SELECT  a.*,
		CASE WHEN NumberInvitesToNonMembers IS NULL THEN 0 ELSE NumberInvitesToNonMembers END AS NumberInvitesToNonMembers,
		InvitesSent
INTO #InvitesPerUser
FROM
(
	SELECT *
	FROM #ExistingUsersTotal
)a

LEFT JOIN
(
	SELECT  OpenIdSender,
			YearMonth,	
			COUNT(OpenIdSender) AS InvitesSent,		
			SUM(CASE WHEN InviteDate < SignupDateReceiver OR (SignupDateReceiver IS NULL AND NOT(InviteDate IS NULL)) THEN 1 ELSE 0 END) AS NumberInvitesToNonMembers
	FROM
	(
		SELECT	OpenIdSender,
				SignupDateReceiver,
				InviteDate,
				DATEADD(month, DATEDIFF(month, 0, InviteDate), 0) AS YearMonth		
		FROM 
		(
			SELECT	OpenId AS OpenIdSender,
					ExtraInfo1 AS EmailAddressReceiver, 
					Timestamp AS InviteDate 
			FROM PlatformAnalytics_PullPush_Platform_Event
			WHERE EventType IN ('AppInviteSent','PlatformInviteSent','ProjectInviteSent','ReferralInviteSent')
			AND NOT(CompanyId LIKE '%Mendix%') AND OpenId != ''
		) a
		
		LEFT JOIN
		(
			SELECT	CompanyId AS CompanyIdReceiver,
					email,
					OldSignupDate AS SignupDateReceiver 
			FROM PlatformAnalytics_PullPush_Platform_User_Current 
			WHERE NOT(CompanyId LIKE '%Mendix%') AND OpenId != ''
		) b
		ON a.EmailAddressReceiver = b.email
	)a
	GROUP BY OpenIdSender,
			 YearMonth
)b
ON a.UserId = b.OpenIdSender AND a.MonthYear = b.YearMonth
*/

SELECT  *
INTO community.Product_Existing_Users
FROM #ExistingUsersTotal




















