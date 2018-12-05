-- Goal of this query is to get a data table which holds the PageStatusses and Answers/Questions of all Sign-ups on the sign-up process 

-- EXPERIMENTGROUP & EXPERIMENT are not added, lead to some difficulties. 

DROP TABLE community.Signup_PageInfo_Full

-- Get all relevant Event data from the Platform Events -- USE MINIMIZED TABLE
;WITH MemberSignupSteps AS
(
    SELECT * 
    FROM community.Initiatives_Events
    WHERE EventType IN ('MemberSignupStep', 'MemberSignupStartedExtended', 'MemberSignupFormVisit')
)


-- Get the PageStatus & an JSON-Array with all the questions on that page from the JSON (per page), Unique for Sign-up (ConfirmationHash)
, GetQuestionArrays AS
(
	SELECT  ExtraInfo1 AS ConfirmationHash,
			ExtraInfo2 AS SignupFormPage,
			MIN(JSON_VALUE(ExtraInfo3,'lax$.PageStatus')) AS PageStatus,
			MIN(JSON_QUERY(ExtraInfo3,'lax$.Questions')) AS Questions
	FROM 	MemberSignupSteps	
	WHERE	EventType = 'MemberSignupStep' 
	AND ISJSON( ExtraInfo3 ) > 0
	AND ExtraInfo1 IS NOT NULL
	GROUP BY ExtraInfo1, 
			 ExtraInfo2
)

-- Decode the Question array to get the QuestionNames and a JSON-Array with all the possible answers (per Question), Unique for Sign-up, Page & Question
, QuestionsJsonDecoded AS
(
	SELECT  ConfirmationHash,
			SignupFormPage,
			PageStatus,
			Questions,
			J.QuestionName AS QuestionName,
			J.Answers AS Answers
	FROM 	GetQuestionArrays
	CROSS APPLY OPENJSON (Questions)
	WITH
	(
		QuestionName varchar(200) 'lax$.QuestionName',
		Answers      nvarchar(max) 'lax$.Answers' AS JSON
	) AS J
)

-- Decode the Answer array to get the AnswerContent, Sort Order and If Selected, Unique for Sign-up, Page, Questions & Answers
, AnswersJsonDecoded AS
(
	SELECT  ConfirmationHash,
			SignupFormPage,
			PageStatus,
			QuestionName,
			K.AnswerContent AS AnswerContent,
			K.AnswerSortOrder AS AnswerSortOrder,
			K.AnswerSelected AS AnswerSelected
	FROM 	QuestionsJsonDecoded
	CROSS APPLY OPENJSON (Answers)
	WITH
	(
		AnswerContent varchar(200) 'lax$.AnswerContent',
		AnswerSortOrder int 'lax$.SortOrder',
		AnswerSelected varchar(200) 'lax$.Selected'
	) AS K
)


-- Get CookieID for every Signup. Group By CookieId to get only 1 Signup per user. 
, CookieIdSignups AS
( 
	SELECT  MIN(ExtraInfo1) AS ConfirmationHash, 
			JSON_VALUE(ExtraInfo3, 'lax$.CookieID') AS CookieId,
			MIN(CONVERT(DATE, Timestamp)) AS SignupDate
	FROM MemberSignupSteps 
	WHERE EventType = 'MemberSignupStartedExtended' 
		AND ExtraInfo2 NOT LIKE '%Mendix%'	
		AND ExtraInfo3 <>''
	GROUP BY JSON_VALUE(ExtraInfo3, 'lax$.CookieID')
)

/*
-- Get ExperimentGroup for every Signup
,  ExperimentGroupInfo AS
(
	SELECT  ExtraInfo1 AS CookieId,
			J.GroupName AS ExperimentGroup,
			J.ExperimentId AS Experiment
	FROM MemberSignupSteps 
	CROSS APPLY OPENJSON (ExtraInfo3)
    WITH 
    (
        GroupName varchar(200) 'lax$.GroupName', 
        ExperimentId varchar(200) 'lax$.Experiment.ID'
    ) AS J
	WHERE EventType = 'MemberSignupFormVisit' 
	AND ExtraInfo1 IS NOT NULL
	AND ExtraInfo3 <>''
	GROUP BY ExtraInfo1, J.GroupName, J.ExperimentId
)
*/

-- Combine CookieId with PageInfo. 
, MemberSignupPageInfo AS
(
	SELECT  b.CookieId,
			SignupDate,
			a.ConfirmationHash,
			SignupFormPage,	
			PageStatus,
			QuestionName,
			AnswerContent,
			AnswerSortOrder,
			AnswerSelected			
	FROM 
	( 
		SELECT * FROM AnswersJsonDecoded
	) a 
	LEFT JOIN
	(
		SELECT * FROM CookieIdSignups
	) b
	ON a.ConfirmationHash = b.ConfirmationHash
	/*
	LEFT JOIN
	(
		SELECT * FROM ExperimentGroupInfo
	) c
	ON b.CookieId = c.CookieId
	*/
)

, AggregatedByDay AS
(
	SELECT 	 SignupDate,
			 SignupFormPage,
			 QuestionName,
			 AnswerContent,
			 PageStatus,
			 COUNT(DISTINCT CookieId) AS UniqueCountPageStatus,
			 SUM(CASE WHEN AnswerSelected = 'true' THEN 1 ELSE 0 END) AS ChosenAnswer
	FROM MemberSignupPageInfo
	GROUP BY SignupDate,
			 SignupFormPage,
			 QuestionName,
			 AnswerContent,
			 PageStatus
			 
)

SELECT * INTO community.Signup_PageInfo_Full FROM AggregatedByDay