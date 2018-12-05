
DROP TABLE community.Signup_Experiment_Allocation


;WITH MemberSignupFormVisitEvents AS
(
    SELECT * 
    FROM community.Initiatives_Events
    WHERE EventType = 'MemberSignupFormVisit'
)

, MemberSignupFormVisitEventsJsonDecoded AS
(
    SELECT    ExtraInfo1 AS CookieId, 
            J.GroupName,
            J.ExperimentId,
            MIN(Timestamp) AS FirstSignupPageVisit,
            COUNT(Timestamp) AS NumberOfSignupPageVisits 
    FROM MemberSignupFormVisitEvents

    CROSS APPLY OPENJSON (ExtraInfo3)
    WITH 
    (
        GroupName varchar(200) '$.GroupName', 
        ExperimentId varchar(200) '$.Experiment.ID'
    ) AS J
    WHERE ExtraInfo3 != ''
    GROUP BY ExtraInfo1, J.GroupName, J.ExperimentId 
)

SELECT * INTO community.Signup_Experiment_Allocation FROM MemberSignupFormVisitEventsJsonDecoded