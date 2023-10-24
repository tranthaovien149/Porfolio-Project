/* Parch & Posey Database - a paper company's sales data

Skills used: Joins, CTE, subqueries & Temporary Tables, Windows Functions, Aggregate Functions*/

/* Pull data from accounts table and orders table using JOINs */
SELECT o.*, a.*
FROM accounts  a
JOIN orders o
ON a.id = o.account_id;

/*A table provides the region for each sales_rep along with their associated accounts. 
This time only for accounts where the sales rep has a last name starting with K and in the Midwest region */
SELECT r.name region, s.name rep, a.name account
FROM sales_reps s
JOIN region r
ON s.region_id = r.id
JOIN accounts a
ON a.sales_rep_id = s.id
WHERE r.name = 'Midwest' AND s.name LIKE '% K%'
ORDER BY 3;

/*All the orders occurred in 2015*/
SELECT o.occurred_at, a.name, o.total, o.total_amt_usd
FROM accounts a
JOIN orders o
ON o.account_id = a.id
WHERE o.occurred_at BETWEEN '2015-01-01' AND '2016-01-01'
ORDER BY 1 DESC;

/*--------AGGREGATIONS FUNCTIONS---------*/
/*The account has the most order*/
SELECT a.id, a.name, COUNT(*) num_orders
FROM accounts a
JOIN orders o
ON a.id = o.account_id
GROUP BY a.id, a.name
ORDER BY num_orders DESC
LIMIT 1;
/*The accounts spent more than 30,000 usd total across all orders*/
SELECT a.id, a.name, SUM(o.total_amt_usd) total_spent
FROM accounts a
JOIN orders o
ON a.id = o.account_id
GROUP BY a.id, a.name
HAVING SUM(o.total_amt_usd) > 30000
ORDER BY total_spent;
/*The accounts used facebook as a channel to contact more than 6 times */
SELECT a.id, a.name, w.channel, COUNT(*) use_of_channel
FROM accounts a
JOIN web_events w
ON a.id = w.account_id
GROUP BY a.id, a.name, w.channel
HAVING COUNT(*) > 6 AND w.channel = 'facebook'
ORDER BY use_of_channel;
/* CASE & Aggregations - The table provides the level associated with each account */
SELECT a.name, SUM(total_amt_usd) total_spent, 
        CASE WHEN SUM(total_amt_usd) > 200000 THEN 'top'
        WHEN  SUM(total_amt_usd) > 100000 THEN 'middle'
        ELSE 'low' END AS customer_level
FROM orders o
JOIN accounts a
ON o.account_id = a.id
WHERE occurred_at > '2015-12-31' 
GROUP BY 1
ORDER BY 2 DESC;

/*---------DATE FUNCTIONS----------*/
/*In which month of which year did Walmart spend the most on gloss paper in terms of dollars?*/
SELECT extract(year_month FROM o.occurred_at) ord_date, SUM(o.gloss_amt_usd) tot_spent
FROM orders o 
JOIN accounts a
ON a.id = o.account_id
WHERE a.name = 'Walmart'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 1;
/*Which month did Parch & Posey have the greatest sales in terms of total number of orders?*/
SELECT MONTH(occurred_at) ord_month, COUNT(*) total_sales
FROM orders
WHERE occurred_at BETWEEN '2014-01-01' AND '2017-01-01'
GROUP BY 1
ORDER BY 2 DESC; 

/*------SUBQUERIES & TEMP TABLE--------*/
/*The averages of each type of paper in the first month*/
SELECT AVG(standard_qty) avg_std, AVG(gloss_qty) avg_gls, AVG(poster_qty) avg_pst
FROM orders
WHERE extract(month FROM occurred_at) = 
     (SELECT extract(month FROM MIN(occurred_at)) FROM orders);
/*Provide the name of the sales_rep in each region with the largest amount of total_amt_usd sales, using WITH for Subquery*/
WITH t1 AS (
     SELECT s.name rep_name, r.name region_name, SUM(o.total_amt_usd) total_amt
      FROM sales_reps s
      JOIN accounts a
      ON a.sales_rep_id = s.id
      JOIN orders o
      ON o.account_id = a.id
      JOIN region r
      ON r.id = s.region_id
      GROUP BY 1,2
      ORDER BY 3 DESC), 
t2 AS (
      SELECT region_name, MAX(total_amt) total_amt
      FROM t1
      GROUP BY 1)
SELECT t1.rep_name, t1.region_name, t1.total_amt
FROM t1
JOIN t2
ON t1.region_name = t2.region_name AND t1.total_amt = t2.total_amt;


/*------------DATA CLEANING SKILL------------*/
/*LEFT & RIGHT*/
/*Pull these extensions and provide how many of each website type exist in the accounts table*/
WITH t1 AS (SELECT website, RIGHT(website, 3) web_form
			FROM accounts)
SELECT web_form, COUNT(*)
FROM t1
GROUP BY 1;
/*Pull the first letter of each company name to see the distribution of company names that begin with each letter (or number)*/
SELECT LEFT(name, 1) company_1stletter, COUNT(*)
FROM accounts
GROUP BY 1 
ORDER BY 1 DESC;
/*CONCAT*/
/*Creat an email address for each primary_poc. The email address should be the first name of the primary_poc . last name primary_poc @ company name .com*/
WITH t1 AS (
  SELECT LOWER(name) AS name, primary_poc,
	LOWER(LEFT(primary_poc, POSITION(' ' IN primary_poc)-1)) AS firstname,
    LOWER(RIGHT(primary_poc, LENGTH(primary_poc)-POSITION(' ' IN primary_poc))) AS lastname
FROM accounts)
SELECT name, firstname, lastname,
       CONCAT(firstname,'.',lastname,'@',REPLACE(name,' ',''),'.com') email
FROM t1;
/*COALESCE*/
/*Fill in the orders.account_id column with the account.id for the NULL value*/
SELECT COALESCE(o.id, a.id) filled_id, a.name, a.website, a.lat, a.log, a.primary_poc, a.sales_rep_id, COALESCE(o.account_id, a.id) account_id, o.occurred_at, o.standard_qty, o.gloss_qty, o.poster_qty, o.total, o.standard_amt_usd, o.gloss_amt_usd, o.poster_amt_usd, o.total_amt_usd
FROM accounts a
LEFT JOIN orders o
ON a.id = o.account_id
WHERE o.total IS NULL;


/*-----------WINDOW FUNCTIONS---------*/
SELECT id,
       account_id,
       EXTRACT(year FROM occurred_at) AS year,
       total_amt_usd,
       SUM(total_amt_usd) OVER account_year_window AS sum_total_amt_usd,
       COUNT(total_amt_usd) OVER account_year_window AS count_total_amt_usd,
       AVG(total_amt_usd) OVER account_year_window AS avg_total_amt_usd,
       MIN(total_amt_usd) OVER account_year_window AS min_total_amt_usd,
       MAX(total_amt_usd) OVER account_year_window AS max_total_amt_usd
FROM orders 
WINDOW account_year_window AS (PARTITION BY account_id ORDER BY EXTRACT(year FROM occurred_at));
/*Compare a row to previous row*/
SELECT occurred_at,
       total_amt_usd, LEAD(total_amt_usd) OVER (ORDER BY occurred_at) AS lead_,
       LEAD(total_amt_usd) OVER (ORDER BY occurred_at) - total_amt_usd AS lead_difference
FROM (SELECT occurred_at,
       SUM(total_amt_usd) AS total_amt_usd
  FROM orders 
 GROUP BY 1
) sub;
/*Percentiles*/
SELECT account_id, occurred_at, standard_qty,
		NTILE(4) OVER (PARTITION BY account_id ORDER BY standard_qty) AS standard_quartile
FROM orders
ORDER BY account_id DESC;

/*------Inequality JOINs-------*/
SELECT accounts.name as account_name,
       accounts.primary_poc as poc_name,
       sales_reps.name as sales_rep_name
  FROM accounts
  LEFT JOIN sales_reps
    ON accounts.sales_rep_id = sales_reps.id
   AND accounts.primary_poc < sales_reps.name;
   
   /*-------UNION-------*/
   WITH double_accounts AS (
    SELECT *
      FROM accounts
    
    UNION ALL
    
    SELECT *
      FROM accounts
)

SELECT name,
       COUNT(*) AS name_count
 FROM double_accounts 
GROUP BY 1
ORDER BY 2 DESC

