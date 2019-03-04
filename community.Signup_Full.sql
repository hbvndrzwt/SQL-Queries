-- Goal of this query is to create an aggregated table (day) which contains all conversions metrics for the SignupForm (which can be aggregated by day). It is also grouped by Experiment & ExperimentGroup 

-- TO_DO: -INVITES SHOULD BE AN AVERAGE OF TOTAL SIGNUPS
		  -- IF SignupDate is not Empty (thus a user does a Signup) --> Check if SignupDate & FirstSignupPageVisit are close to each other 
		  -- Should Users be grouped by CookieId or CookieId & Date"?? --> So Unique Visitors per Day (instead of Unique Visitors overall)

DROP TABLE community.Signup_Full

;WITH SignupEvents AS
(
    SELECT * 
    FROM community.Initiatives_Events
    WHERE EventType IN ('MemberSignupFormVisit', 'MemberSignupStartedExtended', 'MemberSignupCompleted', 'SignupConfirmationEmailSentSuccessful')
)

SELECT *
INTO #SignupEvents
FROM SignupEvents

;WITH SignupStarted AS
(
	SELECT  ExtraInfo1 AS ConfirmationHash,
			ExtraInfo2 AS Email,
			JSON_VALUE(ExtraInfo3,'$.CookieID') AS CookieId,
			JSON_VALUE(ExtraInfo3,'$.HasStudentDomain') AS HasStudentDomain,
			JSON_VALUE(ExtraInfo3,'$.StudentType') AS StudentType,
			JSON_VALUE(ExtraInfo3,'$.Brand') AS Brand,
			JSON_VALUE(ExtraInfo3,'$.Source') AS Source,
			JSON_VALUE(ExtraInfo3,'$.IpAddress') AS IpAddress,
			JSON_VALUE(ExtraInfo3,'$.AreaOfFocus') AS AreaOfFocus,
			JSON_VALUE(ExtraInfo3,'$.JobRole') AS JobRole
    FROM #SignupEvents 
    WHERE EventType = 'MemberSignupStartedExtended'
	AND ExtraInfo2 NOT LIKE '%mendix%'
	-- AND JSON_VALUE(ExtraInfo3,'$.IpAddress') NOT IN ('85.146.242.34') 
)

, UniqueSignupStarted AS
(
	SELECT CookieId,
		   MAX(HasStudentDomain) AS HasStudentDomain,
		   MAX(StudentType) AS StudentType,
		   MAX(Brand) AS Brand,
		   MAX(Source) AS Source,
		   MAX(ConfirmationHash) AS ConfirmationHash,
		   MAX(Email) AS Email,
		   MAX(AreaOfFocus) AS AreaOfFocus,
		   MAX(JobRole) AS JobRole,
		   COUNT(Brand) AS NumberOfSignups
	FROM SignupStarted
	GROUP BY CookieId
)

, SignupCompleted AS
(
	SELECT  OpenId,
			ExtraInfo3 AS ConfirmationHash
	FROM #SignupEvents
	WHERE EventType = 'MemberSignupCompleted' 
	GROUP BY OpenId,
			 ExtraInfo3
)

, SignupEmailSent AS
(
	SELECT ExtraInfo1 AS ConfirmationHash
	FROM #SignupEvents 
	WHERE EventType = 'SignupConfirmationEmailSentSuccessful'
	GROUP BY ExtraInfo1
)

, UniqueSignupFormVisit AS
(
	SELECT  ExtraInfo1 AS CookieId,
			J.GroupName AS ExperimentGroup,
			J.ExperimentId AS Experiment,
			MIN(Timestamp) AS FirstSignupPageVisit,
			CASE WHEN COUNT (ExtraInfo1) > 0 THEN 1 ELSE 0 END AS CountSignupPageVisits
	FROM #SignupEvents 
	CROSS APPLY OPENJSON (ExtraInfo3)
    WITH 
    (
        GroupName varchar(200) '$.GroupName', 
        ExperimentId varchar(200) '$.Experiment.ID'
    ) AS J
	WHERE EventType = 'MemberSignupFormVisit' AND ExtraInfo3 != ''
	GROUP BY ExtraInfo1, 
			 J.GroupName, 
			 J.ExperimentId
)

, JoinSignupSteps AS
(
	SELECT  a.CookieId,
			OpenId,
			HasStudentDomain,
			StudentType,
			Brand,
			Source,
			AreaOfFocus,
			JobRole,
			--CASE WHEN ExperimentGroup = 'A' AND Experiment = 'Job role' THEN NULL ELSE AreaOfFocus END AS AreaOfFocus,
			--CASE WHEN ExperimentGroup = 'A' AND Experiment = 'Job role' THEN NULL ELSE JobRole END AS JobRole,
			CONVERT(DATE, FirstSignupPageVisit) AS FirstSignupPageVisit,
			ExperimentGroup,
			Experiment,
			-- b.ConfirmationHash,
			Email,
			CountSignupPageVisits,
			CASE 
				WHEN b.ConfirmationHash IS NULL 
					THEN 0 
				ELSE 1 
			END AS SignupStarted,
			CASE 
				WHEN d.ConfirmationHash IS NULL 
					THEN 0 
				ELSE 1 
			END AS EmailSuccessfulSent,
            CASE 
				WHEN d.ConfirmationHash IS NULL 
					THEN NULL 
				ELSE 
				CASE 
					WHEN c.ConfirmationHash IS NULL 
						THEN 0 
					ELSE 1 
				END 
			END AS SignupCompleted
	FROM
	(
		SELECT * 
		FROM UniqueSignupFormVisit
	) a
	
	LEFT JOIN
	(
		SELECT * 
		FROM UniqueSignupStarted
	) b
	ON a.CookieId = b.CookieId
	
	LEFT JOIN
	(
		SELECT *
		FROM SignupCompleted
	) c
	ON b.ConfirmationHash = c.ConfirmationHash
	
	LEFT JOIN
	(
		SELECT *
		FROM SignupEmailSent
	) d
	ON b.ConfirmationHash = d.ConfirmationHash
)


-- Load Table with KGM 
, KeyGrowthMetrics AS
(
	SELECT *
	FROM community.Initiatives_KGM
)

-- Join Tables JoinSignupSteps & KeyGrowthMetrics
, JoinedTable AS
(
	SELECT *,
		   CASE WHEN DATEADD(day, 30, SignupDate) < CONVERT(date, GETDATE()) THEN ActivatedWithin30days ELSE NULL END AS Activated,
		   CASE WHEN DATEADD(day, 60, SignupDate) < CONVERT(date, GETDATE()) THEN Retained ELSE NULL END AS Retained1
	FROM
	(
		SELECT	* 
		FROM JoinSignupSteps
	) a
	
	LEFT JOIN
	(
		SELECT *
		FROM KeyGrowthMetrics
	) b
	ON a.OpenId = b.UserId 
	WHERE (SignupDate IS NULL OR FirstSignupPageVisit <= SignupDate)
)


SELECT  a.*,
		CustomerType
INTO community.Signup_Full 
FROM 
(
	SELECT *
	FROM JoinedTable
)a
LEFT JOIN
(
	SELECT  OpenId,
			CustomerType
	FROM community.CustomerTypes
)b
ON a.OpenId = b.OpenId
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	