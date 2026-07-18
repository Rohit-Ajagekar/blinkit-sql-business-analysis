cre

use blinkit_db;

-- Insight 1 – Revenue Contribution 
SELECT
    user_tier,
    ROUND(SUM(grand_total),2) AS revenue,
    ROUND(SUM(grand_total)*100/(SELECT SUM(grand_total)FROM blinkit_orders),2) AS revenue_share
FROM blinkit_orders
GROUP BY user_tier
ORDER BY revenue DESC;


/* Platinum customers contribute only 8% of customers but generate 18% of revenue.
This helps identify which customer segment contributes the maximum revenue, 
enabling the business to focus its marketing and loyalty efforts on high-value customers. */
-- Insight 2 – Average Basket Size
SELECT
    user_tier,
    ROUND(AVG(num_items_ordered),2) AS avg_basket_size
FROM blinkit_orders
GROUP BY user_tier;


/* This analysis shows which customer tier buys more products in each order. 
Customers with larger basket sizes contribute more revenue and are good targets for premium offers and combo deals. 
The average basket size remains nearly constant across all customer tiers, ranging from 3.96 to 4.00 items per order. 
This indicates that higher-tier customers do not buy substantially more items; 
instead, their higher revenue contribution is likely driven by higher-value purchases or more frequent ordering.
Although higher-tier customers spend more overall, they are not necessarily buying significantly more products per order.*/

-- Insight 3 – Average Delivery Time
SELECT
    user_tier,
    ROUND(AVG(delivery_time_mins),2) AS avg_delivery_time
FROM blinkit_orders
GROUP BY user_tier;

-- Insight 4 – Delivery Time Comparison
SELECT
CASE
WHEN is_first_order=1
THEN 'First Order'
ELSE 'Repeat Order'
END customer_type,
ROUND(AVG(delivery_time_mins),2) avg_delivery
FROM blinkit_orders
GROUP BY customer_type;

-- Insight 5 – VIP Customer Detection
WITH customer_summary AS(
SELECT
user_id,
user_tier,
COUNT(*) frequency,
SUM(grand_total) monetary,
AVG(order_rating) rating,
AVG(delivery_time_mins) delivery_time
FROM blinkit_orders
GROUP BY user_id, user_tier
)
SELECT *,
CASE WHEN monetary>=50000
AND frequency>=25
THEN 'VIP'
WHEN monetary>=25000
THEN 'Loyal'
WHEN frequency>=10
THEN 'Regular'
ELSE 'Occasional'
END customer_segment
FROM customer_summary
ORDER BY monetary DESC;