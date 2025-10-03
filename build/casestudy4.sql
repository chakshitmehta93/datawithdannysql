select * from regions
select * from customer_nodes
select * from customer_transactions



-- A. Customer Nodes Exploration

--Q1
select count(distinct node_id) as uniques_nodes from customer_nodes

--Q2

select region_name , count(distinct node_id) as node_count
from regions as r
inner join customer_nodes as c
on r.region_id = c.region_id
group by region_name

--Q3

select region_name , count(distinct customer_id) as customer_count
from regions as r
inner join customer_nodes as c
on r.region_id = c.region_id
group by region_name

--Q4 
with cte as
(select customer_id , node_id , sum(datediff(day , start_date , end_date)) as date_diff
from customer_nodes
where end_date != '9999-12-31'
group by customer_id , node_id )

select avg(date_diff) as avg_diff from cte


-- B. Customer Transactions

--Q1

select distinct txn_type , sum(txn_amount) as total_amount
from customer_transactions
group by txn_type

--Q2
with cte as 
(select customer_id ,count(txn_type) as txn_count , sum(txn_amount) as total_amount
from customer_transactions
where txn_type = 'deposit'
group by customer_id) 

select avg(txn_count) , avg(total_amount) from cte

--Q3
WITH cte_transaction AS (
  SELECT 
    customer_id,
    MONTH(txn_date) AS months,
    SUM(CASE WHEN txn_type = 'deposit' THEN 1 ELSE 0 END) AS deposit_count,
    SUM(CASE WHEN txn_type = 'purchase' THEN 1 ELSE 0 END) AS purchase_count,
    SUM(CASE WHEN txn_type = 'withdrawal' THEN 1 ELSE 0 END) AS withdrawal_count
  FROM customer_transactions
  GROUP BY customer_id, MONTH(txn_date)
)

SELECT 
  months,
  COUNT(customer_id) AS customer_count
FROM cte_transaction
WHERE deposit_count > 1
  AND (purchase_count = 1 OR withdrawal_count = 1)
GROUP BY months;