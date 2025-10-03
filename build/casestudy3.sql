select * from subscriptions;
select * from plans


-- section A

select top 100 s.customer_id ,p.plan_name , p.price , s.start_date 
from plans as p
inner join subscriptions as s
on p.plan_id = s.plan_id

-- section B

--Q1
select count(distinct customer_id) as customer_count
from subscriptions


--Q2


 
select  datepart(month , start_date) as mnth , count(customer_id) as trail_member
from plans as p 
inner join subscriptions as s 
on p.plan_id = s.plan_id
where plan_name = 'trial'
group by datepart(month , start_date)


--Q3

with cte as 
(select plan_name , datepart(year , start_date) as yr  , count(customer_id) as customer_count
from plans as p 
inner join subscriptions as s 
on p.plan_id = s.plan_id
group by plan_name , datepart(year , start_date))

select * from cte 
where yr >2020

--Q4
with cte as 
(select count(customer_id) as customer_count_with_churn
from plans as p 
inner join subscriptions as s 
on p.plan_id = s.plan_id
where plan_name = 'churn'),
newcte as (
  
  select count(distinct customer_id) as total_count
  from  subscriptions as s 
)
select customer_count_with_churn,  round((CAST(customer_count_with_churn AS FLOAT)/total_count)*1.0*100,1) as percentage_contr from 
(select * from cte as c 
inner join newcte as n 
on 1=1) as A



--Q5 

with cte as 
(select customer_id , plan_name , start_date from plans as p
inner join subscriptions as s
on p.plan_id = s.plan_id) 

select count(customer_id) as customer_count  ,  round(count(customer_id)*1.0/(select count(distinct customer_id) from subscriptions)*100,1) as percentage_c from 
(select *,
row_number() over(partition by customer_id order by start_date) as rn
from cte) as A
where rn=2 and plan_name = 'churn'


--Q6 

with cte as 
(select customer_id , plan_name , start_date from plans as p
inner join subscriptions as s
on p.plan_id = s.plan_id) 
, cte2 as 
(select *,
row_number() over(partition by customer_id order by start_date) as rn
from cte) 

select plan_name , count(customer_id) as customer_count ,  round(count(customer_id)*1.0/(select count(distinct customer_id) from subscriptions)*100,2) as percentage_c 
from cte2
where rn=2
group by plan_name


--Q8
with cte as 
(select customer_id , plan_name , datepart(year , start_date) as yr 
from plans as p
inner join subscriptions as s
on p.plan_id = s.plan_id
where plan_name = 'pro annual' and datepart(year , start_date) = 2020) 

select count(customer_id) as upgraded_annual_plan from cte 


--Q9


with cte as 
(select customer_id , plan_name , start_date 
from plans as p
inner join subscriptions as s
on p.plan_id = s.plan_id
where plan_name = 'trial'),
annual as 
(
select customer_id , plan_name , start_date 
from plans as p
inner join subscriptions as s
on p.plan_id = s.plan_id
where plan_name = 'pro annual'
)

select  avg(datediff(day ,c.start_date , a.start_date)) as avg_day from cte as c
inner join  annual as a 
on c.customer_id = a.customer_id


--Q11

with cte as 
(select customer_id , plan_name , start_date from plans as p
inner join subscriptions as s
on p.plan_id = s.plan_id
where plan_name = 'pro monthly') ,
 cte2 as 
(select customer_id , plan_name , start_date from plans as p
inner join subscriptions as s
on p.plan_id = s.plan_id
where plan_name = 'basic monthly')


select * from cte as c
inner join cte2 as c2 
on c.customer_id = c2.customer_id
where c.start_date < c2.start_date and DATEPART(year , c.start_date) = 2020




