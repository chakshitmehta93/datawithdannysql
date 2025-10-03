select * from runners
select * from customer_orders
select * from runner_orders
select * from pizza_names
select * from pizza_recipes
select * from pizza_toppings



--A. Pizza Metrics

--1. How many pizzas were ordered?

select count(order_id) as pizza_count
from  customer_orders  

--2. How many unique customer orders were made?

select count(distinct order_id) as unique_customer
from customer_orders

--Q3 How many successful orders were delivered by each runner?


select runner_id , count(order_id) as successfull_order
from  runner_orders_temp
where cancellation is null
group by runner_id

--Q4 How many of each type of pizza was delivered?

select pizza_name , count(c.order_id)  from customer_orders as c
inner join pizza_names as p
on c.pizza_id = p.pizza_id
inner join  runner_orders_temp as r 
on c.order_id = r.order_id
where cancellation is null
group by pizza_name

--Q5 How many Vegetarian and Meatlovers were ordered by each customer?

select customer_id , pizza_name , c.pizza_id , count(pizza_name) over(partition by customer_id)  from customer_orders_temp as c
inner join pizza_names as p
on c.pizza_id = p.pizza_id
group by customer_id , pizza_name , c.pizza_id

--Q6 What was the maximum number of pizzas delivered in a single order?

SELECT  EXTRACT(DAY FROM order_time) as day , count(c.order_id) AS count_pizza
FROM customer_orders as c 
inner join runner_orders_temp as r 
on c.order_id = r.order_id
where cancellation is null
group by EXTRACT(DAY FROM order_time)
order by count_pizza desc
limit 1 

--Q7


--Q8 How many pizzas were delivered that had both exclusions and extras?

SELECT count(c.order_id) AS count_pizza
FROM customer_orders_temp as c 
inner join runner_orders_temp as r 
on c.order_id = r.order_id
where cancellation is null and exclusions !='' and extras !=''


--Q9 What was the total volume of pizzas ordered for each hour of the day?

SELECT count(order_id) AS count_pizza , EXTRACT(hour FROM order_time) as hour
FROM customer_orders_temp 
group by EXTRACT(hour FROM order_time) 
order by hour


--Q10 What was the volume of orders for each day of the week?

SELECT 
    COUNT(order_id) AS count_pizza, 
    EXTRACT(DOW FROM order_time) AS week_day
FROM customer_orders_temp 
GROUP BY EXTRACT(DOW FROM order_time) 
ORDER BY week_day;  


--B. Runner and Customer Experience

--Q1 How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)

 
SELECT 
    EXTRACT(WEEK FROM registration_date) AS registration_week,
    COUNT(runner_id) AS runner_count
FROM runners
GROUP BY EXTRACT(WEEK FROM registration_date)

--Q2 What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?

with cte as 
(SELECT 
    r.runner_id, 
    EXTRACT(EPOCH FROM (r.pickup_time - c.order_time)) / 60 AS minutes_diff
FROM customer_orders_temp AS c
INNER JOIN runner_orders_temp AS r
    ON c.order_id = r.order_id
	 WHERE r.cancellation IS NULL
	group by runner_id ,  EXTRACT(EPOCH FROM (r.pickup_time - c.order_time)) / 60) 

	select runner_id , round(avg(minutes_diff)) from cte 
	group by runner_id


--Q3 Is there any relationship between the number of pizzas and how long the order takes to prepare?

with cte as 
(SELECT 
    r.runner_id, count(pizza_id) as pizza_count,
    EXTRACT(EPOCH FROM (r.pickup_time - c.order_time)) / 60 AS minutes_diff
FROM customer_orders_temp AS c
INNER JOIN runner_orders_temp AS r
    ON c.order_id = r.order_id
	 WHERE r.cancellation IS NULL
	group by runner_id ,  EXTRACT(EPOCH FROM (r.pickup_time - c.order_time)) / 60) 

	select  pizza_count ,round(avg(minutes_diff)) from cte 
	group by  pizza_count

--Q4 What was the average distance travelled for each customer?

select customer_id , round(avg(duration),2) as avg_distance from
runner_orders_temp as r
inner join customer_orders_temp AS c
on r.order_id = c.order_id
group by customer_id  
order by customer_id 

--Q5 What was the difference between the longest and shortest delivery times for all orders?

SELECT MAX(duration) - MIN(duration) AS time_difference
FROM runner_orders_temp;

--Q6 What was the average speed for each runner for each delivery and do you notice any trend for these values?


select order_id , runner_id , avg(distance*1.0/duration*60) as total_speed 
from runner_orders_temp
WHERE cancellation IS NULL
group by order_id , runner_id
order by runner_id , order_id

--Q7 What is the successful delivery percentage for each runner?

with cte as
(select runner_id , count(distance) as success_delivered , count(order_id) as total_order
from runner_orders_temp
group by runner_id 
order by runner_id) 

select *, (success_delivered*1.0/total_order)*100 as percentage_success from cte
 


--C. Ingredient Optimisation

--data cleaning 

--1 Create a new temporary table #toppingsBreak to separate toppings into multiple rows

SELECT 

with cte as
(SELECT 
    pizza_id, 
    UNNEST(STRING_TO_ARRAY(toppings, ', '))::INT AS topping_id
FROM pizza_recipes as p)

select * from cte as c
inner join pizza_toppings as p
on c.topping_id = p.topping_id

--2 Add an identity column record_id to #customer_orders_temp to select each ordered pizza more easily

ALTER TABLE customer_orders_temp
ADD COLUMN record_id SERIAL;


SELECT *
FROM customer_orders_temp;

--3. Create a new temporary table extrasBreak to separate extras into multiple row
CREATE TABLE extrasbreak AS
SELECT 
    c.record_id,
    trim(both ' ' from extra_id) AS extra_id
FROM customer_orders_temp c,
LATERAL unnest(string_to_array(c.extras, ',')) AS extra_id;

-- Step 2: View the results
SELECT * 
FROM extrasbreak
ORDER BY record_id, extra_id;


--4. . Create a new temporary table exclusionsBreak to separate into exclusions into multiple rows
-- Create table exclusionsbreak
CREATE TABLE exclusionsbreak AS
SELECT 
    c.record_id,
    TRIM(both ' ' FROM e.exclusion_id) AS exclusion_id
FROM customer_orders_temp c,
LATERAL unnest(string_to_array(c.exclusions, ',')) AS e(exclusion_id);

-- Now select from it
SELECT *
FROM exclusionsbreak;


--Q1.What are the standard ingredients for each pizza?
SELECT 
  p.pizza_name,
  STRING_AGG(t.topping_name, ', ') AS ingredients
FROM toppingsBreak t
JOIN pizza_names p 
  ON t.pizza_id = p.pizza_id
GROUP BY p.pizza_name;

--Q2. What was the most commonly added extra?


SELECT 
  p.topping_name,
  COUNT(*) AS extra_count
FROM extrasBreak e
JOIN pizza_toppings p
  ON e.extra_id = p.topping_id
GROUP BY p.topping_name
ORDER BY COUNT(*) DESC;

--Q3. What was the most common exclusion?

SELECT 
  p.topping_name,
  COUNT(*) AS exclusion_count
FROM exclusionsBreak e
JOIN pizza_toppings p
  ON e.exclusion_id = p.topping_id
GROUP BY p.topping_name
ORDER BY COUNT(*) DESC;



--D.  Pricing and Ratings

--Q1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?
SELECT
  SUM(CASE WHEN p.pizza_name = 'Meatlovers' THEN 12
        ELSE 10 END) AS money_earned
FROM customer_orders_temp c
JOIN pizza_names p
  ON c.pizza_id = p.pizza_id
JOIN runner_orders_temp r
  ON c.order_id = r.order_id
WHERE r.cancellation IS NULL;

--Q3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5. 

-- Drop the table if it exists
DROP TABLE IF EXISTS ratings;


CREATE TABLE ratings (
  order_id INT,
  rating INT
);


INSERT INTO ratings (order_id, rating)
VALUES 
  (1, 3),
  (2, 5),
  (3, 3),
  (4, 1),
  (5, 5),
  (7, 3),
  (8, 4),
  (10, 3);


SELECT *
FROM ratings;

--Q4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
--customer_id
--order_id
--runner_id
--rating
--order_time
--pickup_time
--Time between order and pickup
--Delivery duration
--Average speed
--Total number of pizzas

SELECT 
  c.customer_id,
  c.order_id,
  r.runner_id,
  c.order_time,
  r.pickup_time,
  EXTRACT(EPOCH FROM (r.pickup_time - c.order_time)) / 60 AS mins_difference,
  r.duration,
  AVG(r.distance / r.duration * 60) AS avg_speed,
  COUNT(c.order_id) AS pizza_count
FROM customer_orders_temp c
JOIN runner_orders_temp r 
  ON r.order_id = c.order_id
GROUP BY 
  c.customer_id,
  c.order_id,
  r.runner_id,
  c.order_time,
  r.pickup_time,
  r.duration;




