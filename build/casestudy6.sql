
select * from  clique_bait.event_identifier

select * from  clique_bait.campaign_identifier 


select * from clique_bait.page_hierarchy 



select * from clique_bait.users


select * from  clique_bait.events


-- Digital Analysis

--1. How many users are there?

select count(distinct user_id) from clique_bait.users

--2. How many cookies does each user have on average?

select avg(cookie_count) as avg_cookie_count from 
(select user_id , count(cookie_id) as cookie_count
from clique_bait.users
group by user_id) as A

--3. What is the unique number of visits by all users per month?

select  extract(month from event_time) as month , count(distinct visit_id) as unique_no_of_visit
from clique_bait.users as c1
inner join clique_bait.events as c2
on c1.cookie_id = c2.cookie_id 
group by  extract(month from event_time)  

--4. What is the number of events for each event type?

select c1.event_type , event_name , count(c1.event_type) as count_event
from clique_bait.event_identifier as c1
inner join clique_bait.events as c2
on c1.event_type = c2.event_type
group by c1.event_type , event_name
order by count_event desc

--5. What is the percentage of visits which have a purchase event?

with cte as 
(select count(distinct visit_id) as total_amount
from clique_bait.event_identifier as c1
inner join clique_bait.events as c2
on c1.event_type = c2.event_type
where event_name = 'Purchase')
, cte2 as 
(
select count(distinct visit_id) as sum_amount
from clique_bait.event_identifier as c1
inner join clique_bait.events as c2
on c1.event_type = c2.event_type
)

select (total_amount*1.0/sum_amount)*100 as percentage_vist from 
(select * from cte as c1
inner join cte2 as c2
on 1=1) as A

--7. What are the top 3 pages by number of views?

select page_name , count(*) as page_view 
from clique_bait.page_hierarchy as c1
inner join clique_bait.events as c2
on c1.page_id = c2.page_id
inner join clique_bait.event_identifier as c3
on c2.event_type = c3.event_type
where event_name = 'Page View'
group by page_name 
order by page_view desc
limit 3

--8 What is the number of views and cart adds for each product category?

select product_category , sum(case when event_name = 'Page View' then 1 else 0 end) as view_count , sum(case when event_name ='Add to Cart' then 1 else 0 end) as carts_count from clique_bait.events as c1
inner join clique_bait.event_identifier as c2
on c1.event_type = c2.event_type 
inner join clique_bait.page_hierarchy as c3
on c1.page_id = c3.page_id
where product_category not in ('null')
group by product_category 

--9 What are the top 3 products by purchases?

with cte as 
(select visit_id , product_category , product_id from clique_bait.events as c1
inner join clique_bait.event_identifier as c2
on c1.event_type = c2.event_type
inner join  clique_bait.page_hierarchy as c3
on c1.page_id = c3.page_id
where c2.event_name = 'Add to Cart'
group by product_category , product_id , visit_id) 
,cte2 as 
(select * from clique_bait.events as c1
inner join clique_bait.event_identifier as c2
on c1.event_type = c2.event_type
where event_name = 'Purchase')

select product_category , product_id , count(*) as coun from cte as c1
inner join cte2 as c2
on c1.visit_id = c2.visit_id
group by  product_category , product_id
order by coun desc
limit 3


-- Product Funnel Analysis

--Using a single SQL query - create a new output table which has the following details:

WITH cte AS (
    SELECT 
        ph.product_id,
        ph.page_name,
        ph.product_category,
        SUM(CASE WHEN ei.event_name = 'Page View' THEN 1 ELSE 0 END) AS page_count,
        SUM(CASE WHEN ei.event_name = 'Add to Cart' THEN 1 ELSE 0 END) AS cart_count
    FROM clique_bait.events e
    JOIN clique_bait.event_identifier ei ON e.event_type = ei.event_type
    JOIN clique_bait.page_hierarchy ph ON e.page_id = ph.page_id
    WHERE ph.product_category IS NOT NULL
    GROUP BY ph.product_id, ph.page_name, ph.product_category
),

-- Count of Add-to-Cart that were purchased
purchased AS (
    SELECT 
        ph.product_id,
        ph.product_category,
        COUNT(DISTINCT e_add.visit_id) AS purchased_count
    FROM clique_bait.events e_add
    JOIN clique_bait.event_identifier ei_add ON e_add.event_type = ei_add.event_type
    JOIN clique_bait.page_hierarchy ph ON e_add.page_id = ph.page_id
    WHERE ei_add.event_name = 'Add to Cart'
      AND e_add.visit_id IN (
          SELECT e_pur.visit_id
          FROM clique_bait.events e_pur
          JOIN clique_bait.event_identifier ei_pur ON e_pur.event_type = ei_pur.event_type
          WHERE ei_pur.event_name = 'Purchase'
            AND e_pur.page_id = e_add.page_id
      )
    GROUP BY ph.product_id, ph.product_category
),

-- Count of Add-to-Cart that were NOT purchased
not_purchased AS (
    SELECT 
        ph.product_id,
        ph.product_category,
        COUNT(DISTINCT e_add.visit_id) AS not_purchased_count
    FROM clique_bait.events e_add
    JOIN clique_bait.event_identifier ei_add ON e_add.event_type = ei_add.event_type
    JOIN clique_bait.page_hierarchy ph ON e_add.page_id = ph.page_id
    WHERE ei_add.event_name = 'Add to Cart'
      AND e_add.visit_id NOT IN (
          SELECT e_pur.visit_id
          FROM clique_bait.events e_pur
          JOIN clique_bait.event_identifier ei_pur ON e_pur.event_type = ei_pur.event_type
          WHERE ei_pur.event_name = 'Purchase'
            AND e_pur.page_id = e_add.page_id
      )
    GROUP BY ph.product_id, ph.product_category
)

-- Final combined report
SELECT 
    cte.product_id,
    cte.page_name,
    cte.product_category,
    cte.page_count,
    cte.cart_count,
    COALESCE(purchased.purchased_count, 0) AS purchased_count,
    COALESCE(not_purchased.not_purchased_count, 0) AS not_purchased_count
FROM cte
LEFT JOIN purchased ON cte.product_id = purchased.product_id
LEFT JOIN not_purchased ON cte.product_id = not_purchased.product_id
ORDER BY purchased_count DESC;




--Additionally, create another table which further aggregates the data for the above points but this time for each product category instead of individual products

--solution 
-- just remove the product_id and product_name 


--Use your 2 new output tables - answer the following questions:

--1. Which product had the most views, cart adds and purchases?
SELECT TOP 1 *
FROM cte 
ORDER BY views DESC;

SELECT TOP 1 *
FROM cte 
ORDER BY cart_adds DESC;

SELECT TOP 1 *
FROM cte 
ORDER BY purchases DESC;

--2. Which product was most likely to be abandoned?

SELECT TOP 1 *
FROM cte 
ORDER BY abandoned DESC;

--3 Which product had the highest view to purchase percentage?

SELECT 
  TOP 1 product_name,
  product_category,
  CAST(100.0 * purchases / views AS decimal(10, 2)) AS purchase_per_view_pct
FROM #product_summary
ORDER BY purchase_per_view_pct DESC;

--4. What is the average conversion rate from view to cart add?

SELECT 
  CAST(AVG(100.0*cart_adds/views) AS decimal(10, 2)) AS avg_view_to_cart
FROM cte 

--5. What is the average conversion rate from cart add to purchase?
SELECT 
  CAST(AVG(100.0*purchases/cart_adds) AS decimal(10, 2)) AS avg_cart_to_purchase
FROM #product_summary;
0
