
-- GOAL of the query is to generate significance tests (T-tests) for the Signup Experiments

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
			JSON_VALUE(ExtraInfo3,'$.CookieID') AS CookieId
    FROM #SignupEvents 
    WHERE EventType = 'MemberSignupStartedExtended'
	AND ExtraInfo2 NOT LIKE '%mendix%'
)

, UniqueSignupStarted AS
(
	SELECT CookieId,
		   MAX(ConfirmationHash) AS ConfirmationHash,
		   MAX(Email) AS Email
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

, UniqueSignupFormVisit AS
(
	SELECT  ExtraInfo1 AS CookieId,
			J.GroupName AS ExperimentGroup,
			J.ExperimentId AS Experiment,
			MIN(Timestamp) AS FirstSignupPageVisit,
			COUNT (ExtraInfo1) AS CountSignupPageVisits
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

, JoinSignupSteps AS
(
	SELECT  a.CookieId,
			OpenId,
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
	SELECT  *
	FROM community.Initiatives_KGM
)

-- Join Tables JoinSignupSteps & KeyGrowthMetrics
, JoinedTable AS
(
	SELECT  *,
			CASE WHEN DATEADD(day, 30, SignupDate) < CONVERT(DATE, GETDATE()) THEN ActivatedWithin30days ELSE NULL END AS Activated	
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
)

, UnpivotTable AS
(
	SELECT  FirstSignupPageVisit,
			ExperimentGroup,
			Experiment,
			u.Metric,
			u.Value
	FROM 	JoinedTable
	UNPIVOT
	(
		Value
		FOR Metric IN (SignupStarted, SignupCompleted, Activated) 
	)u
)

, SignificanceTesting AS
(
	SELECT  CONVERT(DATE, GETDATE()) AS CurrentDate,
			Experiment,
			Metric,
			MAX(CASE WHEN ExperimentGroup = 'A' THEN ExperimentGroup ELSE NULL END)  AS G1,
			MAX(CASE WHEN ExperimentGroup = 'B' THEN ExperimentGroup ELSE NULL END)  AS G2,
			SUM(CASE WHEN ExperimentGroup = 'A' THEN N ELSE NULL END) AS N1,
			SUM(CASE WHEN ExperimentGroup = 'B' THEN N ELSE NULL END) AS N2,
			SUM(CASE WHEN ExperimentGroup = 'A' THEN Mu ELSE NULL END) AS Mu1,
			SUM(CASE WHEN ExperimentGroup = 'B' THEN Mu ELSE NULL END) AS Mu2,
			CASE WHEN SQRT(SUM(SampleVariance/N)) = 0 THEN NULL ELSE (MAX(Mu)-MIN(Mu))/SQRT(SUM(SampleVariance/N)) END AS Zscore
	FROM
	(

		SELECT		Experiment,
					ExperimentGroup,
					Metric,
					N,
					Mu,
					CASE WHEN (N-1) = 0 THEN NULL ELSE SUM(Deviance)/(N-1) END AS SampleVariance
		FROM
		(

			SELECT		a.*,
						POWER(Value-Mu, 2) AS Deviance
			
			FROM 
			(
				SELECT  a.Experiment,
						a.ExperimentGroup,
						a.Metric,
						a.Value,
						b.Mu,
						b.N
				FROM
				(
					SELECT  Experiment,
							ExperimentGroup,
							Metric,
							Value
					FROM UnpivotTable
					WHERE ExperimentGroup != '' AND NOT(ExperimentGroup IS NULL)
				)a
				LEFT JOIN
				(
					SELECT  Experiment,
							ExperimentGroup, 
							Metric,
							AVG(CAST(Value AS NUMERIC)) AS Mu,
							COUNT(Metric) AS N
					FROM UnpivotTable
					WHERE ExperimentGroup != '' AND NOT(ExperimentGroup IS NULL)
					GROUP BY ExperimentGroup,
							 Experiment,
							 Metric
				)b
				ON a.ExperimentGroup = b.ExperimentGroup AND a.Experiment = b.Experiment AND a.Metric = b.Metric
			)a
		)c
		GROUP BY  Experiment,
				  ExperimentGroup,
				  Metric,
				  N,
				  Mu
	) d
	GROUP BY Experiment,
			 Metric
)

, CheckEndDate AS
(
	SELECT  CurrentDate,
			Experiment,
			Metric,
			G1,
			G2,
			N1,
			N2,
			Mu1,
			Mu2,
			Zscore
	FROM
	(
		SELECT  *,
				CONVERT(DATE, DATEADD(day, 30, EndDate)) AS UpperBoundary
		FROM
		(
			SELECT * 
			FROM SignificanceTesting
		)a
		LEFT JOIN
		(
			SELECT  UniqueId,
					CONVERT(DATE, StartDate) AS StartDate,
					CONVERT(DATE, EndDate) AS EndDate
			FROM InitiativeTrackr_PullPush_Experiment_Current
		)b
		ON a.Experiment = b.UniqueId
	)a
	WHERE CurrentDate > StartDate AND EndDate IS NULL OR UpperBoundary > CurrentDate OR StartDate IS NULL
)




INSERT INTO community.Signup_SignificanceTest
SELECT * FROM CheckEndDate




