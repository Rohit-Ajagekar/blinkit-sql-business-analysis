use blinkit_db;

select * from blinkit_orders
limit 50;
-- unique stores
select 
	count(distinct store_id)
from blinkit_orders;


select * from blinkit_orders
limit 2;

-- Q1. How many total orders are in our dataset, and what is the date range covered?
select count(distinct order_id) as total_orders,
count(distinct order_year) as yrs
from blinkit_orders;

-- Q2. What is the total GMV (revenue) year-wise, and how has it grown each year? --> incresed steadly fro 2022-25 then decresed in 2026
select sum(grand_total) as Total_GMV,
order_year
from blinkit_orders
group by order_year;

-- Q3. What is the overall order status split (Delivered, Cancelled, Returned, Partial), and 
-- how is our delivery success rate trending each year? --> decresed cancellation till 2024 then heavy increase and heavy decrease.
select * from blinkit_orders
limit 10;

select order_year,
	sum(case when order_status = "Delivered" then 1 else 0 end) as delivered,
    sum(case when order_status = "Partially Delivered" then 1 else 0 end) as 'Partially Delivered',
    sum(case when order_status = "Returned" then 1 else 0 end) as Returned,
    sum(case when order_status = "Cancelled" then 1 else 0 end) as Cancelled
from blinkit_orders
group by order_year;

/* Q4. Which top 5 cities contribute the most to our total GMV, and what is their share in percentage?
First I tried to use window fxn inside the cte but that not the way we do it as i already used group by in cte.
*/

with city_revenue as (
select store_city,
	sum(grand_total) as GMV
from blinkit_orders
group by store_city
)
select store_city, GMV, round(GMV /(sum(GMV) over())*100,2) as share_percentage from city_revenue
order by GMV desc
limit 5;

/*Q5. Which dark stores are the top 10 performers by revenue, and which are the bottom 10
(underperformers)?
As many store_ids are repeated accross many cities I'm treating unique pair of 
(store_id,store_city,store_zone) as one dark store
*/

select store_id,store_city,store_zone,
	sum(grand_total) as GMV
from blinkit_orders
group by store_id,store_city,store_zone
order by GMV desc
limit 10;
select store_id,store_city,store_zone,
	sum(grand_total) as GMV
from blinkit_orders
group by store_id,store_city,store_zone
order by GMV asc
limit 10;

/*
Q6. Which pincode areas have the highest order volume, and what is the average order
value there?
--> 400014	36244	1006.34
*/

select customer_pincode,
count(*) as order_volume,
round(avg(grand_total),2) as avg_order_value
from blinkit_orders
group by customer_pincode
order by order_volume desc;

/*'
Q7. What are the peak hours of the day for orders, and how does the pattern differ on
weekdays vs weekends?
Peak demand occurs at 10-11 AM and 5-6–7 PM. weekdays have more orders
 
*/

with tbl as (select 
(case when order_day_of_week in ("sunday","saturday") then "weekends"
else "weekdays" end) as day_type ,
order_hour,
count(*) as order_count
from blinkit_orders
group by order_hour,day_type
),

tbl2 as (select day_type,order_hour,order_count ,rank() over(partition by day_type order by order_count desc) as rn
from tbl)
select day_type,order_hour,order_count from tbl2
where rn in (1,2,3,4,5);

/*
Q8. Which month of the year gives us the highest GMV, and which festive months show
clear spikes?
--> oct and nov have festive spikes
as i solve question i noticed that gnv related to orders is repitative so im creating a view related to the orders financials

*/
-- view for orders financials
create view vw_order_financials as
select
    order_id,
    order_date,
    order_year,
    order_month,
    order_month_name,
    store_city,
    store_zone,
    customer_pincode,
    user_id,
    user_tier,
    order_status,
    grand_total as GMV,
    promo_discount,
    cashback_earned,
    delivery_fee,
    tip
from blinkit_orders;

select order_month,
order_month_name,
sum(GMV) as GMV
from vw_order_financials
where order_year < 2026
group by order_month,order_month_name
order by order_month;

/*
-- december have very low gmv lets check if we have all decembers from 2022
==> My bussiness insight is that November was the strongest sales month due to festive shopping. 
December sales dropped because order volume decreased, while customer spending per order remained stable.
*/

select order_year, order_month,
order_month_name,
sum(GMV) as GMV
from vw_order_financials
where order_year < 2026
group by order_year,order_month,order_month_name
order by order_year, order_month;

-- dec 2025 has very low gmv lets check the reason
-- lets check if cancellation increased or avg cart value decreased
SELECT
    order_month_name,
    COUNT(*) AS total_orders,
    order_status,
    ROUND(SUM(GMV),2) AS total_gmv
FROM vw_order_financials
WHERE order_year = 2025
  AND order_month IN (11,12)
GROUP BY order_month_name,order_status
order by order_month_name desc;

-- every portion dropped proportionally lets check if all dates are included

select min(order_date),
max(order_date)
from vw_order_financials
where order_year = 2025;

SELECT
    order_year,
    order_month,
    order_month_name,
    COUNT(DISTINCT order_date) AS days_present
FROM blinkit_orders
GROUP BY
    order_year,
    order_month,
    order_month_name
ORDER BY
    order_year,
    order_month;
    
/*
Q9. What is the weekend effect — how much more do we sell on Fri-Sat-Sun compared to
Mon-Thu?
-- we sale 271608005.97 more on Fri-Sat-Sun Fri-Sat-Sun compared to Mon-Thu
*/

select 
(case when order_day_of_week in ("friday","sunday","saturday") then "weekends"
else "weekdays" end) as day_type ,
sum(grand_total) as order_revnue
from blinkit_orders
group by day_type;

with tbl as (select 
sum(case when order_day_of_week in ("friday","sunday","saturday") then grand_total else 0 end) as weekends,
sum(case when order_day_of_week not in ("friday","sunday","saturday") then grand_total else 0 end) as weekdays
from blinkit_orders)

select *,weekends-weekdays from tbl;


-- checking if there is duplicate in customer
SELECT
    COUNT(*) AS total_pairs
FROM (
    SELECT
        user_id,
        user_tier,
        customer_pincode
    FROM blinkit_orders
    GROUP BY
        user_id,
        user_tier,
        customer_pincode
    HAVING COUNT(*) > 1
) t;

-- checking if theres dublicate pairs of (store_id,store_city,store_zone)
SELECT
    COUNT(*) AS total_pairs
FROM (
    SELECT
        store_id,store_city,store_zone
    FROM blinkit_orders
    GROUP BY
        store_id,store_city,store_zone
    HAVING COUNT(*) > 1
) t;

/*
Q10. What is the payment method mix (UPI, COD, Card, etc.), and how has UPI adoption 
grown over the years? 


*/

select 
payment_method,
round((sum(case when order_year = 2022 then 1 else 0 end)/
(select count(order_id) from blinkit_orders where order_year = 2022))*100,2) as '2022',
round((sum(case when order_year = 2023 then 1 else 0 end)/
(select count(order_id) from blinkit_orders where order_year = 2023))*100,2) as '2023',
round((sum(case when order_year = 2024 then 1 else 0 end)/
(select count(order_id) from blinkit_orders where order_year = 2024))*100,2) as '2024',
round((sum(case when order_year = 2025 then 1 else 0 end)/
(select count(order_id) from blinkit_orders where order_year = 2025))*100,2) as '2025',
round((sum(case when order_year = 2026 then 1 else 0 end)/
(select count(order_id) from blinkit_orders where order_year = 2026))*100,2) as '2026'
from blinkit_orders
group by payment_method;


/*
Q11. Which delivery slot is most popular (10-min Express, Turbo, Scheduled), and what is 
the average delivery time per slot? 
--> 10- minute express is the most pupular slot.

*/
create view vw_store_orders as 
select 
	order_id,
    store_id,
    store_city,
    store_zone,
    order_date,
    order_year,
    order_month,
    order_month_name,
    order_day_of_week,
    order_hour,
    delivery_slot,
    delivery_time_mins,
    order_status,
    order_rating,
    platform,
    payment_method,
    grand_total ,
    delivery_fee,
    tip,
    num_items_ordered,
    total_qty
from blinkit_orders;

select 
	delivery_slot,
    count(order_id) as orders,
    avg(delivery_time_mins) as avg_delivery_time
from vw_store_orders
group by delivery_slot
order by orders desc;



/*
Q12. What is the platform split between Android, iOS, and Web, and which platform users 
spend more per order? 
-- iOS platform users spend more per order.
*/

select platform,
(sum(grand_total)/(select sum(grand_total) from blinkit_orders))*100 as percentage_split,
avg(grand_total) as avg_spend
from vw_store_orders
group by platform
order by avg_spend desc;




/*
Q13. How do the four user tiers (Bronze, Silver, Gold, Platinum) compare in terms of 
average order value, order frequency, and cancellation rate? 
*/
-- Average Order Value
SELECT
    user_tier,
    ROUND(AVG(grand_total),2) AS avg_order_value
FROM blinkit_orders
GROUP BY user_tier
ORDER BY avg_order_value DESC;

-- Order Frequency
SELECT
    user_tier,
    COUNT(*) AS total_orders,
    COUNT(DISTINCT user_id) AS customers,
    ROUND(COUNT(*) / COUNT(DISTINCT user_id),2) AS avg_orders_per_customer
FROM blinkit_orders
GROUP BY user_tier;

-- Cancellation Rate
SELECT
    user_tier,
    COUNT(*) AS total_orders,
    SUM(order_status='Cancelled') AS cancelled_orders,
    ROUND(
        SUM(order_status='Cancelled')*100/COUNT(*),
        2
    ) AS cancellation_rate
FROM blinkit_orders
GROUP BY user_tier;


/*
Q14. What percentage of our orders are from repeat customers vs first-time customers, and 
how has this changed year-on-year? 
*/

SELECT
order_year,
SUM(is_first_order) first_orders,
SUM(is_reorder) repeat_orders,
ROUND(SUM(is_reorder)*100/COUNT(*),2) repeat_percentage
FROM blinkit_orders
GROUP BY order_year
ORDER BY order_year;

/*
Q15. Who are our top 20 customers by lifetime GMV, and which cities/tiers do they belong 
to? 
*/

SELECT
user_id,
store_city,
user_tier,
COUNT(*) total_orders,
ROUND(SUM(grand_total),2) lifetime_gmv
FROM blinkit_orders
GROUP BY user_id, store_city, user_tier
ORDER BY lifetime_gmv DESC
LIMIT 20;


-- Section 6: PROMO & DISCOUNT ANALYSIS (Margin)
-- Q16. Which promo codes are used most, and what is the average discount given per code?
use blinkit_db;
select 
      promo_code,
      count(promo_code) as Count_Promo_Code_Used,
      avg(product_discount) as Avg_discount
from blinkit_orders 
group by promo_code
order by Count_Promo_Code_Used DESC;      
 
 
 
 
 
-- Q17. What percentage of our GMV is being lost to promo discounts and cashback, broken
-- down by user tier?
with total_gmv_table as (
select 
        user_tier,
       sum(promo_discount+cashback_earned) as Total_GMV
from blinkit_orders
group by user_tier )  

select 
      distinct tg.user_tier,
      round(tg.Total_GMV*100.0/SUM(o.grand_total) over(),2) as Discount_Percent_of_GMV
from blinkit_orders as o,total_gmv_table as tg
order by Discount_Percent_of_GMV desc ;


-- Section 7: OPERATIONAL GROWTH (Ops)
-- Q18. What are the top 5 reasons for cancellation and return, and which cities have the
-- highest cancellation rates?
select 
    store_city,
    COUNT(case when order_status = 'Cancelled' then 1 end) * 100.0 / COUNT(*) as cancellation_rate
from blinkit_orders
group by  store_city
order by cancellation_rate desc;  


-- Q19. What is the average delivery time by city and delivery slot, and which stores
-- consistently deliver faster or slower than average?

with StoreStats as (
    select 
        store_city,
        store_id,
        delivery_slot,
        avg(delivery_time_mins) as store_avg_delivery_time
    from blinkit_orders
    group by store_city, store_id, delivery_slot
),
BenchmarkStats as (
    select *,
        avg(store_avg_delivery_time) over (
            partition by store_city, delivery_slot
        ) as city_slot_benchmark
    from StoreStats
)
select 
    store_city,
    delivery_slot,
    store_id,
    ROUND(store_avg_delivery_time, 2) as store_avg,
    ROUND(city_slot_benchmark, 2) as benchmark_avg,
    ROUND(store_avg_delivery_time - city_slot_benchmark, 2) as difference
from BenchmarkStats
order by store_city, delivery_slot, difference;









-- Section 8: GROWTH AND TREND (Strategy)

-- Q20. What is the month-over-month GMV growth, and can we identify any month where
-- growth stalled or reversed — and why (linked to cancellations, low promos, or city issues)?


with MonthlyGMV as (
    select 
        DATE_FORMAT(order_date, '%Y-%m') as month_key,
        SUM(grand_total) as total_gmv
    from blinkit_orders 
    group by 1
)
select 
    month_key,
    ((total_gmv - lag(total_gmv) over (order by month_key)) / 
     lag(total_gmv) over (order by month_key)) * 100 as Mom_growth_percentage
from MonthlyGMV
order by month_key;


