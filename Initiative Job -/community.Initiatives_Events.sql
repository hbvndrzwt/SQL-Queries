-- Goal of this query is minimize the load-time for the Initiative queries, by creating a table with only the needed events & timeframe.

DROP TABLE community.Initiatives_Events

;WITH InitiativeEvents AS
(
    SELECT * 
    FROM PlatformAnalytics_PullPush_Platform_Event
    WHERE EventType IN ('MemberSignupFormVisit', 'MemberSignupStartedExtended', 'MemberSignupCompleted', 'SignupConfirmationEmailSentSuccessful',
						 'MemberSignupStep', 'WmIntroTutorialBroken', 'WmIntroTutorialStep', 'GuidanceTourStarted', 'GuidanceTourEnded',
						 'SandboxDeployed', 'WmDeploySucceeded', 'OnlineLectureCompleted')
	AND Timestamp > '2016-12-01'
)

SELECT * INTO community.Initiatives_Events FROM InitiativeEvents