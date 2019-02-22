
DROP TABLE community.Signup_Funnel

;WITH SignupEvents AS
(
    SELECT * 
    FROM community.Initiatives_Events
    WHERE EventType IN ('MemberSignupFormVisit', 'MemberSignupStep', 'MemberSignupStartedExtended', 'MemberSignupCompleted', 'SignupConfirmationEmailSentSuccessful')
)

SELECT *
INTO #SignupEvents
FROM SignupEvents

;WITH SignupStarted AS
(
	SELECT  ExtraInfo1 AS ConfirmationHash,
			ExtraInfo2 AS Email,
			JSON_VALUE(ExtraInfo3,'$.CookieID') AS CookieId,
			CONVERT(DATE, Timestamp) AS SignupDateStarted
    FROM #SignupEvents 
    WHERE EventType = 'MemberSignupStartedExtended'
	AND ExtraInfo2 NOT LIKE '%mendix%'
	-- AND JSON_VALUE(ExtraInfo3,'$.IpAddress') NOT IN ('85.146.242.34') 
)

, UniqueSignupStarted AS
(
	SELECT CookieId,
		   MAX(ConfirmationHash) AS ConfirmationHash,
		   MAX(Email) AS Email,
		   MIN(SignupDateStarted) AS SignupDateStarted
	FROM SignupStarted
	GROUP BY CookieId
)

, SignupCompleted AS
(
	SELECT  OpenId,
			ExtraInfo3 AS ConfirmationHash
	FROM #SignupEvents
	WHERE EventType = 'MemberSignupCompleted' 
)

, SignupEmailSent AS
(
	SELECT ExtraInfo1 AS ConfirmationHash
	FROM #SignupEvents 
	WHERE EventType = 'SignupConfirmationEmailSentSuccessful'
)
/*
, UniqueSignupFormVisit AS
(
	SELECT  ExtraInfo1 AS CookieId,
			J.GroupName AS ExperimentGroup,
			J.ExperimentId AS Experiment
	FROM #SignupEvents 
	CROSS APPLY OPENJSON (ExtraInfo3)
    WITH 
    (
        GroupName varchar(200) '$.GroupName', 
        ExperimentId varchar(200) '$.Experiment.ID'
    ) AS J
	WHERE EventType = 'MemberSignupFormVisit' AND ExtraInfo3 != ''
	GROUP BY ExtraInfo1, J.GroupName, J.ExperimentId
)
*/
, SignupStepCompletion AS
(
	SELECT  ExtraInfo1 AS ConfirmationHash,
			MAX(CASE WHEN ExtraInfo2 = 'OptimizeExperiencePage' THEN 1 ELSE 0 END) AS OptimizeExperiencePage,
			MAX(CASE WHEN ExtraInfo2 = 'AgreeToEmail' THEN 1 ELSE 0 END) AS AgreeToEmail,
			MAX(CASE WHEN ExtraInfo2 = 'Project created, forwarding user' THEN 1 ELSE 0 END) AS ProjectCreated
	FROM 	#SignupEvents	
	WHERE	EventType = 'MemberSignupStep' 
	AND ExtraInfo1 IS NOT NULL
	GROUP BY ExtraInfo1
)

, JoinSignupSteps AS
(
	SELECT  b.CookieId,
			SignupDateStarted,
			OpenId,
			-- b.ConfirmationHash,
			Email,
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
			END AS SignupCompleted,
			OptimizeExperiencePage,
			AgreeToEmail,
			ProjectCreated
	FROM
	(
		SELECT * 
		FROM UniqueSignupStarted
	) b
	
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
	
	LEFT JOIN
	(
		SELECT *
		FROM SignupStepCompletion
	) e
	ON b.ConfirmationHash = e.ConfirmationHash
)

SELECT * INTO community.Signup_Funnel FROM JoinSignupSteps







