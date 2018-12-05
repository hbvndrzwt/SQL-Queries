


DROP TABLE community.New_Users

;WITH SignupEvents AS
(
    SELECT * 
    FROM community.Initiatives_Events
    WHERE EventType IN ('MemberSignupCompleted', 'MemberSignupStartedExtended')
)

SELECT *
INTO #SignupEvents
FROM SignupEvents


;WITH SignupStarted AS
(
	SELECT  ExtraInfo1 AS ConfirmationHash,
			JSON_VALUE(ExtraInfo3,'$.HasStudentDomain') AS HasStudentDomain,
			JSON_VALUE(ExtraInfo3,'$.StudentType') AS StudentType
    FROM #SignupEvents 
    WHERE EventType = 'MemberSignupStartedExtended'
	AND ExtraInfo2 NOT LIKE '%mendix%'
	-- AND JSON_VALUE(ExtraInfo3,'$.IpAddress') NOT IN ('85.146.242.34') 
)

, UniqueSignupStarted AS
(
	SELECT HasStudentDomain,
		   StudentType,
		   ConfirmationHash 
	FROM SignupStarted
)

, SignupCompleted AS
(
	SELECT  OpenId,
			ExtraInfo3 AS ConfirmationHash,
			CompanyId,
			ExtraInfo1 AS SignupReason,
			-- (10-10) Possible SignupReasons: App Invitation, Platform Invitation, Project Invitation, Sprintr REST Service, ??
			CASE 
				WHEN ExtraInfo1 IN ('App Invitation', 'Platform Invitation', 'Project Invitation') 
					THEN 'Invites'
				ELSE 'Marketing Inbound'
			END AS SignupSource
	FROM #SignupEvents
	WHERE EventType = 'MemberSignupCompleted' 
)

, JoinSignupSteps AS
(
	SELECT  
			OpenId,
			HasStudentDomain,
			StudentType,
			SignupReason,
			SignupSource,
			CASE 
				WHEN b.ConfirmationHash IS NULL 
					THEN 0 
				ELSE 1 
			
			END AS SignupCompleted
	FROM
	(
		SELECT * 
		FROM UniqueSignupStarted
	) a
	
	RIGHT JOIN
	(
		SELECT *
		FROM SignupCompleted
	) b
	ON a.ConfirmationHash = b.ConfirmationHash
	
)

-- Load Table with KGM 
, KeyGrowthMetrics AS
(
	SELECT *
	FROM community.Initiatives_KGM
)

, UserData AS
(
	SELECT  OpenId,
			Country,
			CONVERT(DATE, SignupDate) AS SignupDateUser,
			Brand,
			CompanyId,
			Email
	FROM 	PlatformAnalytics_PullPush_Platform_User_Current
)

, CompanyData AS
(
	SELECT  CompanyId,
			DisplayName
	FROM PlatformAnalytics_PullPush_Platform_Company_Current
)

, JoinedTable AS
(
	SELECT  c.*,
		    b.CompanyType,
			Country,
			SignupDateUser,
			Brand,
			a.CompanyId,
			Email,
			DisplayName
	FROM
	(
		SELECT	* 
		FROM UserData 
	) a
	
	LEFT JOIN
	(
		SELECT CompanyType,
			   UserId
		FROM KeyGrowthMetrics
	) b
	ON a.OpenId = b.UserId
	
	LEFT JOIN
	(
		SELECT *
		FROM JoinSignupSteps
	) c
	ON a.OpenId = c.OpenId
	
	LEFT JOIN
	(
		SELECT *
		FROM CompanyData
	) d
	ON a.CompanyId = d.CompanyId
	
	WHERE SignupDateUser > '01-01-2017'
)

SELECT * INTO community.New_Users FROM JoinedTable



