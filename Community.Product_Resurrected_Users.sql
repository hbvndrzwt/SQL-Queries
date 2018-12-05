
--====================================================================================================================================================
--= Resurrection
--====================================================================================================================================================

-- Resurrection Rate
-- Definition of Ressurrection: has churned in the past, but became active again for the first time in the current month.


SELECT	MonthYear,
		UserId, 
		IsCurrentChurner,
		IsNonCurrentChurner,
		IsExistingUser,
		CASE WHEN (IsCurrentChurner = 1  OR IsNonCurrentChurner = 1) AND ActiveInMonth = 1 THEN 1 ELSE 0 END AS Resurrected,
		CASE WHEN IsCurrentChurner = 1 AND IsExistingUser = 1 THEN 1 ELSE 0 END AS ExistingChurners,
		CASE WHEN IsCurrentChurner = 1 AND ActiveInMonth = 1 THEN 1 ELSE 0 END AS CurrentChurnersResurrected,
		CASE WHEN IsNonCurrentChurner = 1 AND ActiveInMonth = 1 THEN 1 ELSE 0 END AS NonCurrentChurnersResurrected
INTO #ChurnedUsers
FROM
(
	SELECT	a.UserId, 
			IsExistingUser, 
			IsCurrentChurner,
			IsNonCurrentChurner,
			MonthYear, 
			SUM(NumberProjectsActiveInMonth) AS NumberProjectsActiveInMonth, 
			CASE WHEN SUM(NumberProjectsActiveInMonth) > 0 THEN 1 ELSE 0 END AS ActiveInMonth
	FROM 
	(
		SELECT	a.UserId, 
				MonthYear, 
				LastActiveDate,
				SignupDate, 
				IsCurrentChurner,
				IsNonCurrentChurner,				
				IsExistingUser,
				ISNULL(NumberProjectsActiveInMonth,0) AS NumberProjectsActiveInMonth
		FROM 
		(	

			SELECT	UserId, 
					MonthYear, 
					SignupDate, 
					LastActiveDate, 
					IsExistingUser,
					-- A Churner is defined as someone who have had inactivity for at least one month (with a max of 12 months)
					CASE WHEN DATEDIFF ( month , LastActiveDate , MonthYear ) >=2 AND DATEDIFF ( month , LastActiveDate , MonthYear ) <= 12 THEN 1 ELSE 0 END AS IsCurrentChurner,
					CASE WHEN DATEDIFF ( month , LastActiveDate , MonthYear ) > 12 THEN 1 ELSE 0 END AS IsNonCurrentChurner
			FROM 
			(
				SELECT	a.UserId, 
						a.MonthYear, 
						SignupDate, 
						MAX(LastActiveDateInMonth) AS LastActiveDate,
						-- An existing user is a user that has shown activity at least 30 days after their signup
						CASE WHEN datediff(day, SignupDate, MAX(LastActiveDateInMonth)) > 30 THEN 1 ELSE 0 END AS IsExistingUser
				FROM
				(
					-- 1) Define the churn population per month
					-- The first thing we need is a cross joined table of all the users and months. We can already exclude the months that are before a user signup date.
					SELECT  DISTINCT UserId,
							MonthYear, 
							SignupDate
					FROM 
					(
						SELECT DISTINCT(MonthYear) AS MonthYear 
						FROM PlatformAnalytics_Processed_Users_Month
					) a
					CROSS JOIN 
					(
						SELECT  UserId, 
								SignupDate
						FROM (
							SELECT DISTINCT UserId
							FROM PlatformAnalytics_Processed_Users_Month
							WHERE UserId != '' AND NOT(CompanyId LIKE '%Mendix%')
						) a

						LEFT JOIN
						(
							SELECT  OpenId, 
									OldSignupDate AS SignupDate 
							FROM PlatformAnalytics_PullPush_Platform_User_Current
						) b
						On a.UserId = b.OpenId
					) b
					WHERE b.SignupDate <= MonthYear
				)a
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
				ON b.MonthYear < a.MonthYear AND b.UserId = a.UserId

				WHERE LastActiveDateInMonth >= SignupDate 
				GROUP BY a.UserId, 
						 a.MonthYear, 
						 SignupDate
			)a
		)a
		-- For all Churners, We need to know whether they have been active in this month
		LEFT JOIN 
		(
			SELECT	UserId,
					COUNT(UserId) AS NumberProjectsActiveInMonth, 
					MonthYear AS ActivityMonthYear
			FROM PlatformAnalytics_Processed_Users_Month 
			WHERE ActiveMonth = 'Active' AND UserId != '' AND NOT(MonthYear IS NULL)
			GROUP BY UserId, 
					 MonthYear
		) b
		ON b.ActivityMonthYear = a.MonthYear AND a.UserId = b.UserId 

	) a
	GROUP BY  a.UserId,
			  IsExistingUser, 
			  IsCurrentChurner,
			  IsNonCurrentChurner,			  
			  MonthYear
)a

DROP TABLE community.Product_Resurrected_Users

SELECT *
INTO community.Product_Resurrected_Users
FROM #ChurnedUsers
WHERE MonthYear < dateadd(month,datediff(month,0,GETDATE()),0)
AND IsExistingUser = 1
AND (IsCurrentChurner = 1  OR IsNonCurrentChurner = 1)

