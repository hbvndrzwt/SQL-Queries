--====================================================================================================================================================
--= Invite Conversion for Invites Sent to Non-Members
	-- Query time: 2min19sec
--====================================================================================================================================================

-- Drop the current table in the datalake 
DROP TABLE community.Product_Invite_Conversion


SELECT	OpenIdSender,
		EmailAddressRetriever,
		MonthYear,
		InviteType,
		CASE WHEN InviteDate < SignupDate OR SignupDate IS NULL THEN 1 ELSE 0 END AS InviteToNonMember,
		CASE WHEN InviteDate < SignupDate AND datediff(day, InviteDate, SignupDate) <= 30 AND NOT(SignupDate IS NULL) THEN 1 ELSE 0 END InviteToNonMemberLeadingToSignup
INTO community.Product_Invite_Conversion
FROM 
( 
	SELECT	OpenIdSender,
			EmailAddressRetriever,
			InviteDate,
			InviteType,
			/*
			-- If the created date of the company is not set in platform analytics, this value will be NULL (4 cases known on 20180525)
			CASE 
				WHEN CompanyType IS NULL
					THEN 'Other'
				ELSE CompanyType
			END AS CompanyType,	
			*/
			dateadd(month,datediff(month,0,InviteDate),0) AS MonthYear,
			SignupDate
	FROM 
	(
		SELECT	OpenId AS OpenIdSender,
				ExtraInfo1 AS EmailAddressRetriever, 
				Timestamp AS InviteDate,
				EventType AS InviteType
		FROM PlatformAnalytics_PullPush_Platform_Event 
		WHERE EventType IN ('AppInviteSent','PlatformInviteSent','ProjectInviteSent','ReferralInviteSent')
		AND NOT(CompanyId LIKE '%Mendix%') AND OpenId != ''
	) a

	LEFT JOIN 
	(
		SELECT  OpenId, 
				CompanyId, 
				email, 
				OldSignupDate AS SignupDate 
		FROM PlatformAnalytics_PullPush_Platform_User_Current
	) b
	ON a.EmailAddressRetriever = b.email
/*
	LEFT JOIN 
	(
		SELECT	CompanyId,
				CASE 
					WHEN SUM(CASE WHEN IsPartner = 1 THEN 1 ELSE 0 END) > 0 THEN 'Partner'	
					WHEN SUM(CASE WHEN IsCustomer = 1 THEN 1 ELSE 0 END) > 0 THEN 'Customer'				
					WHEN SUM(CASE WHEN IsUniversity = 1 THEN 1 ELSE 0 END) > 0 THEN 'University'
					ELSE 'Other'
				END AS CompanyType
		FROM PlatformAnalytics_PullPush_Platform_Company_Current	
		GROUP BY CompanyId	
	) c
	ON b.CompanyId = c.CompanyId
*/
) a
WHERE MonthYear < dateadd(month,datediff(month,0,GETDATE()),0)
