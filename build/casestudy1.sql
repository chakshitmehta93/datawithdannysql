

CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');

  select * from sales
  select * from members
  select * from menu


  

  --Q1
  select customer_id , sum(price) as total_spend from
  sales as s
  inner join menu as m 
  on s.product_id = m.product_id
  group by customer_id

  --Q2
  select customer_id , count(distinct order_date) as visted
  from sales 
  group by customer_id

--Q3
with cte as 
(select customer_id , m.product_name ,
dense_rank() over(partition by customer_id order by order_date ) as rn
from sales as s
inner join menu as m 
on s.product_id  = m.product_id) 

select customer_id ,product_name 
from cte 
where rn<=1

--Q4

with cte as 
(select  m.product_name
from sales as s
inner join menu as m
on s.product_id = m.product_id) 

select top 1 *,count(product_name) as count_product
from cte 
group by product_name
order by count_product desc


--Q5 

with cte as 
(select customer_id , product_name , count(product_name) as count_product from
sales as s 
inner join menu as m
on s.product_id = m.product_id 
group by customer_id , product_name) 

select * from 
(select *,
dense_rank() over(partition by customer_id order by count_product desc) as rn
from cte ) as A
where rn<=1




--Q6 

 with cte as 
 (select s.*, m.join_date , m2.product_name , m2.price 
  from sales as s 
  inner join members as m
  on s.customer_id = m.customer_id
  inner join menu as m2
  on m2.product_id = s.product_id) 

  select * from 
  (select *,
  dense_rank() over(partition by customer_id order by order_date asc) as rn
  from cte 
  where join_date <= order_date) as A
  where rn<=1

--Q7 

 with cte as 
 (select s.*, m.join_date , m2.product_name , m2.price 
  from sales as s 
  inner join members as m
  on s.customer_id = m.customer_id
  inner join menu as m2
  on m2.product_id = s.product_id) 

  select * from 
  (select *,
  dense_rank() over(partition by customer_id order by order_date asc) as rn
  from cte 
  where join_date >= order_date) as A
  
--Q8

with cte as 
(select s.* , m2.product_name , m2.price , m.join_date
from sales as s
inner join members as  m 
on s.customer_id  = m.customer_id 
inner join menu as m2 
on m2.product_id = s.product_id) 

select customer_id ,  count(product_name) as total_item , sum(price) as amount_spend
from cte 
where order_date < join_date
group by customer_id


--Q9 

with cte as
(select s.*  , m2.product_name , m2.price 
  from sales as s 
  inner join menu as m2
  on m2.product_id = s.product_id) 

  select customer_id ,  sum(case when product_name = 'sushi' then price*20 else price*10 end) as rating
  from cte 
  group by customer_id 


--Q10 

with cte as 
(select s.* , m2.product_name , m2.price , m.join_date
from sales as s
inner join members as  m 
on s.customer_id  = m.customer_id 
inner join menu as m2 
on m2.product_id = s.product_id) 

select customer_id , 
sum(case
when order_date between join_date and DATEADD(day , 6 , join_date) then price*20 
when product_name = 'sushi' then price*20 else price*10
end ) as rating
from cte
group by customer_id


--bonus question
with cte as 
(select s.*, m.join_date , m2.product_name , m2.price 
  from sales as s 
  left join members as m
  on s.customer_id = m.customer_id
  inner join menu as m2
  on m2.product_id = s.product_id)
  
  select *, case when member='Y' then row_number() over(partition by customer_id order by order_date desc) end as ranking from 
  (select *,
  case when order_date >= join_date then 'Y' else 'N' end as member
  from cte)  as A
  