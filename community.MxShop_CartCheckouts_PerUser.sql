-- List all Cart Checkouts per User 
-- Est. Query-time: 00m06s

DROP TABLE community.MxShop_CartCheckouts_PerUser

SELECT  OpenId,
		COUNT(ExtraInfo1) AS CountOrders
INTO community.MxShop_CartCheckouts_PerUser
FROM PlatformAnalytics_PullPush_Platform_Event AS a
WHERE EventType IN ('MxShopCartCheckout')
AND OpenId =
(
	SELECT MAX(OpenId)
	FROM PlatformAnalytics_PullPush_Platform_User_Current AS b
	WHERE a.OpenId = b.OpenId
	AND CompanyId NOT LIKE '%Mendix%'
)
GROUP BY OpenId