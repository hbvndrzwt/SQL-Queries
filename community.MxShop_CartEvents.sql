-- This query is set up to keep track of MxShop cart conversion

/*
To-do:
 - Cannot link added/deleted from cart events to CartCheckouts (which orderlines are part of the order?)

*/


DROP TABLE community.MxShop_CartEvents

SELECT *
INTO #Events
FROM PlatformAnalytics_PullPush_Platform_Event 
WHERE EventType IN ('MxShopItemAddedToCart', 'MxShopItemDeletedFromCart', 'MxShopCartCheckout')

SELECT  OpenId,
		Timestamp,
		EventType,
		OrderLineId,
		StockId,
		Quantity
INTO community.MxShop_CartEvents
FROM
(
	SELECT  OpenId,
			Timestamp,
			EventType,
			ExtraInfo1 AS OrderLineId,
			ExtraInfo2 AS StockId,
			ExtraInfo3 AS Quantity
	FROM #Events
	WHERE EventType IN ('MxShopItemAddedToCart', 'MxShopItemDeletedFromCart')
	AND CompanyId NOT LIKE '%Mendix%'
)a

