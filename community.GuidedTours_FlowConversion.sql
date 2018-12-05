
/*
GOAL of this query is to get the Start/Finish conversion for all Flows in the GuidanceEngine
*/


--LOAD the Event + User Data

DROP TABLE  community.GuidedTours_FlowConversions

;WITH GuidanceTourEvents AS
(
	SELECT *
	FROM community.Initiatives_Events
	WHERE EventType IN ('GuidanceTourStarted', 'GuidanceTourEnded')
)

, UserCurrent AS
(
    SELECT  OpenId AS UserId, 
			CompanyId,
			email,
			CONVERT(date, OldSignupDate)AS SignupDate			
	FROM PlatformAnalytics_PullPush_Platform_User_Current 
	WHERE NOT(CompanyId LIKE '%Mendix%') AND OpenId != ''	
)

---------------------------------------------------------------------------------------------------

--GUIDEDTOUR Started

, GuidanceTourStarted AS
(
	SELECT  OpenId,
			MIN(CONVERT(date, Timestamp)) AS FirstStartDate,
			ExtraInfo1 AS FlowID,
			MAX(ExtraInfo3) AS Revision,
			--ExtraInfo2 AS ExperimentGroup,
			COUNT(OpenId) AS TimesStarted
	FROM GuidanceTourEvents
	WHERE EventType LIKE 'GuidanceTourStarted'
	GROUP BY OpenId, ExtraInfo1 --ExtraInfo2
)

---------------------------------------------------------------------------------------------------

--GUIDEDTOUR Ended


, GuidanceTourEnded AS
(
	SELECT  OpenId,
			ExtraInfo1 AS FlowID,
			SUM(CASE WHEN ExtraInfo2 LIKE 'completed' THEN 1 ELSE 0 END) AS CountCompleted,
			SUM(CASE WHEN ExtraInfo2 LIKE 'closed' THEN 1 ELSE 0 END) AS CountClosed,
			-- Figure out how to add LastStep
			AVG(CASE WHEN ExtraInfo2 LIKE 'closed' THEN ExtraInfo3 ELSE 1000 END) AS LastStep
	FROM GuidanceTourEvents
	WHERE EventType LIKE 'GuidanceTourEnded'
	GROUP BY OpenId, ExtraInfo1
)

---------------------------------------------------------------------------------------------------

--COMBINE Events

, JoinEvents AS
(
	SELECT  a.OpenId,
			a.FlowID,
			Revision,
			FirstStartDate,
			TimesStarted,
			CASE WHEN CountCompleted IS NULL THEN 0 ELSE CountCompleted END AS CountCompleted,
			CASE WHEN CountClosed IS NULL THEN 0 ELSE CountClosed END AS CountClosed,
			CASE WHEN TimesStarted > 0 THEN 1 ELSE 0 END AS Started,
			LastStep
	FROM 
	(
		SELECT * 
		FROM GuidanceTourStarted
	)a
	LEFT JOIN 
	(
		SELECT *
		FROM GuidanceTourEnded
	)b
	ON a.OpenId = b.OpenId AND a.FlowID = b.FlowID
	WHERE CASE WHEN CountCompleted IS NULL THEN 0 ELSE CountCompleted END + CASE WHEN CountClosed IS NULL THEN 0 ELSE CountClosed END < 2
)

SELECT * INTO community.GuidedTours_FlowConversions FROM JoinEvents

