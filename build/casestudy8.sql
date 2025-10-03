--Data Exploration and Cleansing

--1. Update the fresh_segments.interest_metrics table by modifying the month_year column to be a date data type with the start of the month
-- Convert month_year from text → date (first day of that month)
ALTER TABLE fresh_segments.interest_metrics
ALTER COLUMN month_year TYPE DATE
USING TO_DATE('01-' || month_year, 'DD-MM-YYYY');

SELECT month_year 
FROM fresh_segments.interest_metrics 
LIMIT 10;


--2. What is count of records in the fresh_segments.interest_metrics 
--for each month_year value sorted in chronological order (earliest to latest) 
--with the null values appearing first?

select month_year , count(*)
from fresh_segments.interest_metrics
group by month_year
order by month_year asc

--3. What do you think we should do with these null values in the fresh_segments.interest_metrics

--The null values appear in _month, _year, month_year, and interest_id, with the exception of interest_id 2124
--interest_id = 21246 have NULL _month, _year, and month_year
SELECT *
FROM interest_metrics
WHERE month_year IS NULL
ORDER BY interest_id DESC;

--Since the corresponding values in composition, index_value, ranking, and percentile_ranking fields are not meaningful without the specific information on interest_id, I will delete rows with null interest_id.
--Delete rows that are null in column interest_id (1193 rows)
DELETE FROM interest_metrics
WHERE interest_id IS NULL;

--Now the table interest_metrics only has a row (interest_id = 21246) that has null value in _month, _year, month_year.


--4. How many interest_id values exist in the fresh_segments.interest_metrics table
--but not in the fresh_segments.interest_map table? What about the other way around?
SELECT 
    COUNT(DISTINCT map.id) AS map_id_count,
    COUNT(DISTINCT c1.interest_id) AS metrics_id_count,
    SUM(CASE WHEN map.id IS NULL THEN 1 ELSE 0 END) AS not_in_map,
    SUM(CASE WHEN c1.interest_id IS NULL THEN 1 ELSE 0 END) AS not_in_metrics
FROM fresh_segments.interest_metrics AS c1
FULL JOIN fresh_segments.interest_map AS map
    ON CAST(c1.interest_id AS INT) = map.id;

--5. Summarise the id values in the fresh_segments.interest_map by its total record count in this table
SELECT COUNT(*) AS map_id_count
FROM fresh_segments.interest_map

--6. What sort of table join should we perform for our analysis and why? Check your logic by checking the rows where interest_id = 21246 in your joined output and include all columns from fresh_segments.interest_metrics and all columns from fresh_segments.interest_map except from the id column.
SELECT 
  metrics.*,
  map.interest_name,
  map.interest_summary,
  map.created_at,
  map.last_modified
FROM fresh_segments.interest_metrics metrics
JOIN fresh_segments.interest_map map
  ON CAST(metrics.interest_id AS INT) = map.id
WHERE CAST(metrics.interest_id AS INT) = 21246;


--7. Are there any records in your joined table where the month_year value is before the created_at value from the fresh_segments.interest_map table? Do you think these values are valid and why?


SELECT COUNT(*) AS cnt
FROM fresh_segments.interest_metrics metrics
JOIN fresh_segments.interest_map map
  ON  CAST(metrics.interest_id AS INT) = map.id
WHERE metrics.month_year < CAST(map.created_at AS DATE);




--B. Interest Analysis

--1. Which interests have been present in all month_year dates in our dataset?
WITH unique_months AS (
  SELECT COUNT(DISTINCT month_year) AS cnt
  FROM fresh_segments.interest_metrics
)
SELECT 
    interest_id,
    COUNT(month_year) AS cnt
FROM fresh_segments.interest_metrics, unique_months
GROUP BY interest_id, unique_months.cnt
HAVING COUNT(month_year) = unique_months.cnt;

--2. Using this same total_months measure - calculate the cumulative percentage of all records starting at 14 months - which total_months value passes the 90% cumulative percentage value?

WITH interest_months AS (
  SELECT
    interest_id,
    COUNT(DISTINCT month_year) AS total_months
  FROM fresh_segments.interest_metrics
  WHERE interest_id IS NOT NULL
  GROUP BY interest_id
),
interest_count AS (
  SELECT
    total_months,
    COUNT(interest_id) AS interests
  FROM interest_months
  GROUP BY total_months
)

SELECT *,
  CAST(100.0 * SUM(interests) OVER(ORDER BY total_months DESC)
	/ SUM(interests) OVER() AS decimal(10, 2)) AS cumulative_pct
FROM interest_count;

--3. If we were to remove all interest_id values which are lower than the total_months value we found in the previous question - how many total data points would we be removing
WITH interest_months AS (
  SELECT
    interest_id,
    COUNT(DISTINCT month_year) AS total_months
  FROM fresh_segments.interest_metrics
  WHERE interest_id IS NOT NULL
  GROUP BY interest_id
)

SELECT 
  COUNT(interest_id) AS interests,
  COUNT(DISTINCT interest_id) AS unique_interests
FROM fresh_segments.interest_metrics
WHERE interest_id IN (
  SELECT interest_id 
  FROM interest_months
  WHERE total_months < 6);

--4.  Does this decision make sense to remove these data points from a business perspective? Use an example where there are all 14 months present to a removed interest example for your arguments - think about what it means to have less months present from a segment perspective.

SELECT 
  month_year,
  COUNT(DISTINCT interest_id) interest_count,
  MIN(ranking) AS highest_rank,
  MAX(composition) AS composition_max,
  MAX(index_value) AS index_max
FROM fresh_segments.interest_metrics metrics
WHERE interest_id IN (
  SELECT interest_id
  FROM fresh_segments.interest_metrics
  WHERE interest_id IS NOT NULL
  GROUP BY interest_id
  HAVING COUNT(DISTINCT month_year) = 14)
GROUP BY month_year
ORDER BY month_year, highest_rank;

--C. Segment Analysis

--Q1.  Using our filtered dataset by removing the interests with less than 6 months worth of data, which are the top 10 and bottom 10 interests which have the largest composition values in any month_year? Only use the maximum composition value for each interest but you must keep the corresponding month_year.

WITH max_composition AS (
  SELECT 
    month_year,
    interest_id,
    MAX(composition) OVER(PARTITION BY interest_id) AS largest_composition
  FROM interest_metrics_edited -- filtered dataset in which interests with less than 6 months are removed
  WHERE month_year IS NOT NULL
),
composition_rank AS (
  SELECT *,
    DENSE_RANK() OVER(ORDER BY largest_composition DESC) AS rnk
  FROM max_composition
)

--Top 10 interests that have the largest composition values
SELECT 
  cr.interest_id,
  im.interest_name,
  cr.rnk
FROM composition_rank cr
JOIN interest_map im ON cr.interest_id = im.id
WHERE cr.rnk <= 10
ORDER BY cr.rnk;


--Q2. Which 5 interests had the lowest average ranking value?
SELECT 
  TOP 5 metrics.interest_id,
  map.interest_name,
  CAST(AVG(1.0*metrics.ranking) AS decimal(10,2)) AS avg_ranking
FROM interest_metrics_edited metrics
JOIN interest_map map
  ON metrics.interest_id = map.id
GROUP BY metrics.interest_id, map.interest_name
ORDER BY avg_ranking;

--Q3.  Which 5 interests had the largest standard deviation in their percentile_ranking value?

SELECT 
  DISTINCT TOP 5 metrics.interest_id,
  map.interest_name,
  ROUND(STDEV(metrics.percentile_ranking) 
    OVER(PARTITION BY metrics.interest_id), 2) AS std_percentile_ranking
FROM #interest_metrics_edited metrics
JOIN interest_map map
ON metrics.interest_id = map.id
ORDER BY std_percentile_ranking DESC;

--Q5. How would you describe our customers in this segment based off their composition and ranking values? What sort of products or services should we show to these customers and what should we avoid?

--Customers in this segment love travelling and personalized gifts but they just want to spend once. That's why we can see that in one month of 2018, the percentile_ranking was very high; but in another month of 2019, that value was quite low. These customers are also interested in new trends in tech and entertainment industries.
--Therefore, we should only recommend only one-time accomodation services and personalized gift to them. We can ask them to sign-up to newsletters for tech products or new trends in entertainment industry as well.

--D. Index Analysis

--Q1.  What is the top 10 interests by the average composition for each month?
WITH avg_composition_rank AS (
  SELECT 
    metrics.interest_id,
    map.interest_name,
    metrics.month_year,
    ROUND(metrics.composition / metrics.index_value, 2) AS avg_composition,
    DENSE_RANK() OVER(PARTITION BY metrics.month_year ORDER BY metrics.composition / metrics.index_value DESC) AS rnk
  FROM interest_metrics metrics
  JOIN interest_map map 
    ON metrics.interest_id = map.id
  WHERE metrics.month_year IS NOT NULL
) 
SELECT *
FROM avg_composition_rank
--filter top 10 interests for each month
WHERE rnk <= 10; 

--2. For all of these top 10 interests - which interest appears the most often?

WITH avg_composition_rank AS (
  SELECT 
    metrics.interest_id,
    map.interest_name,
    metrics.month_year,
    ROUND(metrics.composition / metrics.index_value, 2) AS avg_composition,
    DENSE_RANK() OVER(PARTITION BY metrics.month_year ORDER BY metrics.composition / metrics.index_value DESC) AS rnk
  FROM interest_metrics metrics
  JOIN interest_map map 
    ON metrics.interest_id = map.id
  WHERE metrics.month_year IS NOT NULL
),
frequent_interests AS (
  SELECT 
    interest_id,
    interest_name,
    COUNT(*) AS freq
  FROM avg_composition_rank
  WHERE rnk <= 10	--filter top 10 interests for each month
  GROUP BY interest_id, interest_name
)

SELECT * 
FROM frequent_interests
WHERE freq IN (SELECT MAX(freq) FROM frequent_interests);

--Q3. What is the average of the average composition for the top 10 interests for each month?

WITH avg_composition_rank AS (
  SELECT 
    metrics.interest_id,
    map.interest_name,
    metrics.month_year,
    ROUND(metrics.composition / metrics.index_value, 2) AS avg_composition,
    DENSE_RANK() OVER(PARTITION BY metrics.month_year ORDER BY metrics.composition / metrics.index_value DESC) AS rnk
  FROM interest_metrics metrics
  JOIN interest_map map 
    ON metrics.interest_id = map.id
  WHERE metrics.month_year IS NOT NULL
)

SELECT 
  month_year,
  AVG(avg_composition) AS avg_of_avg_composition
FROM avg_composition_rank
WHERE rnk <= 10 --filter top 10 interests for each month
GROUP BY month_year;

--Q5. Provide a possible reason why the max average composition might change from month to month? Could it signal something is not quite right with the overall business model for Fresh Segments?

The max average composition decreased overtime because top interests were mostly travel-related services, which were in high seasonal demands for some months throughout a year. Customers wanted to go on a trip during the last and first 3 months of a year. You can see max_index_composition were high from September 2018 to March 2019.

This also means that Fresh Segments's business heavily relied on travel-related services. Other products and services didn't receive much interest from customers

