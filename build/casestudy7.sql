  select * from balanced_tree.sales
  select * from balanced_tree.product_details
  select * from balanced_tree.product_hierarchy
  select * from balanced_tree.product_prices

  -- High Level Sales Analysis

--1. What was the total quantity sold for all products?
select sum(qty) as sum_qty from balanced_tree.sales

--2. What is the total generated revenue for all products before discounts?

select sum(qty*price) as revenue_generated from balanced_tree.sales

--3. What was the total discount amount for all products?

select cast(sum(qty*price*discount/100.0) as float) as total_discount from balanced_tree.sales

--Transaction Analysis

--1 How many unique transactions were there?
select count(distinct txn_id) from balanced_tree.sales

--2 What is the average unique products purchased in each transaction

with cte as 
(select txn_id , count(distinct prod_id) as count_product
from balanced_tree.sales as b
group by txn_id) 

select round(avg(count_product),1) as avg_count_per_txn_id from cte 

--4 What is the average discount value per transaction?

with cte as 
(select txn_id , sum(qty*price*discount/100.0) as avg_discount
from balanced_tree.sales
group by txn_id) 
select CAST(AVG(avg_discount) AS decimal(5, 1)) from cte 

--Q5
with cte as 
(select (case when member = 'True' then 1 else 0 end) as table_of_mem_and_nonmem
from balanced_tree.sales)
, cte2 as
(select count(case when table_of_mem_and_nonmem = '1' then 1 end) as member_yes ,  count(case when table_of_mem_and_nonmem = '0' then 0 end) as non_member from cte) 
select round(member_yes*1.0/(member_yes+non_member)*100,3) as member_split  , round(non_member*1.0/(member_yes+non_member)*100,3) as non_member from cte2


--Q6 
with cte as 
(select member , txn_id , sum(qty*price)  as total_amount
from balanced_tree.sales
group by member , txn_id) 

select member , avg(case when member= 'true' then total_amount end) as member_avg , avg(case when member= 'false' then total_amount end) as non_member_avg from cte
group by member

--Product Analysis

--1. What are the top 3 products by total revenue before discount?

select  prod_id , sum(qty*b.price) as revenue 
from balanced_tree.sales as b
inner join balanced_tree.product_details as b1 
on b.prod_id = b1.product_id
group by prod_id
order by revenue desc 
limit 3 

--Q2 What is the total quantity, revenue and discount for each segment?

select segment_id	 , sum(qty) as sum_quantity , sum(qty*b2.price) as total_revenue , sum(qty*b2.price*discount/100) as total_discount 
from balanced_tree.product_details as b1
inner join balanced_tree.sales as b2
on b1.product_id = b2.prod_id 
group by segment_id


--Q3 What is the top selling product for each segment?
with cte as 
(select segment_name , product_name , sum(qty*b2.price) as total_revenue 
from balanced_tree.product_details as b1
inner join balanced_tree.sales as b2
on b1.product_id = b2.prod_id 
group by segment_name , product_name) 

select * from 
(select *,
row_number() over(partition by segment_name order by total_revenue desc) as rn
from cte) as A
where rn = 1

--Q4 What is the total quantity, revenue and discount for each category?

select category_name , sum(qty) as sum_quantity , sum(qty*b2.price) as total_revenue , sum(qty*b2.price*discount/100) as total_discount 
from balanced_tree.product_details as b1
inner join balanced_tree.sales as b2
on b1.product_id = b2.prod_id 
group by category_name

--Q5 What is the top selling product for each category?

with cte as 
(select category_name , product_name , sum(qty*b2.price) as total_revenue 
from balanced_tree.product_details as b1
inner join balanced_tree.sales as b2
on b1.product_id = b2.prod_id 
group by category_name , product_name) 

select * from 
(select *,
row_number() over(partition by category_name order by total_revenue desc) as rn
from cte) as A
where rn = 1

--Q6 What is the percentage split of revenue by product for each segment?
with cte as 
(select segment_name , product_name , sum(qty*b2.price) as sum_revenue 
from balanced_tree.product_details as b1
inner join balanced_tree.sales as b2
on b1.product_id = b2.prod_id 
group by segment_name , product_name) 
, cte2 as 
(
 select segment_name , sum(qty*b2.price) as total_revenue 
from balanced_tree.product_details as b1
inner join balanced_tree.sales as b2
on b1.product_id = b2.prod_id 
group by segment_name )

select *, (sum_revenue*1.0/total_revenue)*100 as percentage_split from 
(select * from cte as c
inner join cte2 as c2 
on c.segment_name = c2.segment_name
order by c.segment_name , c2.segment_name)

--Q7 What is the percentage split of revenue by segment for each category?

with cte as 
(select segment_name , category_name , sum(qty*b2.price) as sum_revenue 
from balanced_tree.product_details as b1
inner join balanced_tree.sales as b2
on b1.product_id = b2.prod_id 
group by segment_name , category_name) 
, cte2 as 
(
 select category_name , sum(qty*b2.price) as total_revenue 
from balanced_tree.product_details as b1
inner join balanced_tree.sales as b2
on b1.product_id = b2.prod_id 
group by category_name )

select *, (sum_revenue*1.0/total_revenue)*100 as percentage_split from 
(select * from cte as c
inner join cte2 as c2 
on c.category_name = c2.category_name
order by c.category_name , c2.category_name)

--Q8 What is the percentage split of total revenue by category?
with cte as 
(select category_name , sum(qty*b2.price) as sum_amount
from balanced_tree.product_details as b1
inner join balanced_tree.sales as b2
on b1.product_id = b2.prod_id
group by category_name) 
,cte2 as (select sum(qty*price) as total_revenue from balanced_tree.sales )

select *, round((sum_amount*1.0/total_revenue)*100,2) as percentage_split from 
(select * from cte as c1
inner join cte2 as c2
on 1=1)

--Q9 What is the total transaction “penetration” for each product? 
   --(hint: penetration = number of transactions where at least 1 quantity
    --of a product was purchased divided by total number of transactions)
with cte as 
(select product_id , product_name , count(distinct txn_id) as sum_amount
from balanced_tree.product_details  as b1
inner join balanced_tree.sales as b2
on b1.product_id = b2.prod_id
group by product_id , product_name) 
, cte2 as 
(
    select  count(distinct txn_id) as total_amount
	from  balanced_tree.sales 
)


select *, (sum_amount*1.0/total_amount)*100 as percentage_split from
(select * from cte as c1
inner join cte2 as c2
on 1=1) as A

