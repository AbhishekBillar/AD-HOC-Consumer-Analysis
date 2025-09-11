SELECT * FROM gdb023.dim_customer;
SELECT * FROM gdb023.dim_product;
SELECT * FROM gdb023.fact_gross_price;
SELECT * FROM gdb023.fact_manufacturing_cost;
SELECT * FROM gdb023.fact_pre_invoice_deductions;
SELECT * FROM gdb023.fact_sales_monthly;

-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region
SELECT 
	DISTINCT market 
FROM dim_customer
WHERE customer = "AtliQ Exclusive" AND region = "APAC";

-- 2. What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields,
-- unique_products_2020
-- unique_products_2021
-- percentage_chg
WITH cte1 AS (
SELECT 
	count(DISTINCT product_code) AS unique_products_2020 
FROM fact_sales_monthly
WHERE fiscal_year="2020"
),
cte2 AS (
SELECT 
	count(DISTINCTROW product_code) AS unique_products_2021 
FROM fact_sales_monthly
WHERE fiscal_year="2021"
)
SELECT unique_products_2020, 
		unique_products_2021, 
        (unique_products_2021 - unique_products_2020) * 100 / unique_products_2020 as percentage_chg
FROM cte1 c1
JOIN cte2 c2;


-- 3. Provide a report with all the unique product counts for each segment and
-- sort them in descending order of product counts. The final output contains
-- 2 fields,
-- segment
-- product_count
SELECT  segment,
	count(DISTINCT product_code) product_count 
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;


-- 4. Follow-up: Which segment had the most increase in unique products in
-- 2021 vs 2020? The final output contains these fields,
-- segment
-- product_count_2020
-- product_count_2021
-- difference
WITH product_20 AS (SELECT p.segment, 
                           COUNT(DISTINCT s.product_code) AS product_count_2020
                    FROM fact_sales_monthly s
                    JOIN dim_product p 
                    ON s.product_code = p.product_code
                    WHERE s.fiscal_year = 2020
                    GROUP BY p.segment),

product_21 AS (SELECT p.segment,
                      COUNT(DISTINCT s.product_code) AS product_count_2021
               FROM fact_sales_monthly s
               JOIN dim_product p 
               ON s.product_code = p.product_code
               WHERE s.fiscal_year = 2021
               GROUP BY p.segment)

SELECT p20.segment,
       product_count_2020, 
       product_count_2021,
       product_count_2021 - product_count_2020 AS difference 
FROM product_20 p20 
JOIN product_21 p21 
ON p20.segment = p21.segment
ORDER BY difference DESC;


-- or

WITH unique_products AS(
SELECT
	segment,
    COUNT(DISTINCT(CASE WHEN fiscal_year = 2020 THEN s.product_code END)) AS product_count_2020,
    COUNT(DISTINCT(CASE WHEN fiscal_year = 2021 THEN s.product_code END)) AS product_count_2021
FROM dim_product p
JOIN fact_sales_monthly s
	USING (product_code)
GROUP BY p.segment
    
)

SELECT 
*,
	product_count_2021 - product_count_2020 AS difference
FROM unique_products
order by difference desc;


-- 5.Get the products that have the highest and lowest manufacturing costs.
--    The final output should contain these fields,
--    product_code
--    product
--    manufacturing_cost
SELECT f.product_code, 
       p.product, 
       f.manufacturing_cost AS manufacturing_cost
FROM fact_manufacturing_cost f
JOIN dim_product p 
ON f.product_code = p.product_code
WHERE f.manufacturing_cost = (SELECT MIN(manufacturing_cost) 
                              FROM fact_manufacturing_cost)

UNION ALL

SELECT f.product_code, 
       p.product, 
       f.manufacturing_cost AS manufacturing_cost
FROM fact_manufacturing_cost f
JOIN dim_product p 
ON f.product_code = p.product_code
WHERE f.manufacturing_cost = (SELECT MAX(manufacturing_cost)
                              FROM fact_manufacturing_cost);


-- or

(SELECT 
	p.product_code,
    p.product,
    m.manufacturing_cost
FROM fact_manufacturing_cost m
JOIN dim_product p
	USING(product_code)
ORDER BY m.manufacturing_cost DESC
LIMIT 1 )

UNION 

(SELECT 
	p.product_code,
    p.product,
    m.manufacturing_cost
FROM fact_manufacturing_cost m
JOIN dim_product p
	USING(product_code)
ORDER BY m.manufacturing_cost ASC
LIMIT 1 );


-- 6. Generate a report which contains the top 5 customers who received an
-- average high pre_invoice_discount_pct for the fiscal year 2021 and in the
-- Indian market. The final output contains these fields,
-- customer_code
-- customer
-- average_discount_percentage
WITH CTE1 AS(
			SELECT *
			FROM fact_pre_invoice_deductions 
			JOIN dim_customer c
			USING (customer_code)
			WHERE 
				fiscal_year = 2021 and
				c.market = 'India'
)

SELECT 
	customer_code,
    customer,
	concat(round(avg(pre_invoice_discount_pct) * 100 , 2), ' %') as average_discount_percentage
FROM CTE1
WHERE 
	fiscal_year = 2021 and
	market = "India"
GROUP BY customer_code, customer
ORDER BY avg(pre_invoice_discount_pct) * 100 DESC
LIMIT 5;


-- OR

SELECT pre.customer_code,
       c.customer,
       concat(ROUND(pre.pre_invoice_discount_pct*100, 2), ' %') AS average_discount_percentage
FROM fact_pre_invoice_deductions pre
JOIN dim_customer c
ON pre.customer_code = c.customer_code
WHERE pre.pre_invoice_discount_pct > (SELECT AVG(pre_invoice_discount_pct) 
                                      FROM fact_pre_invoice_deductions) 
      AND
      pre.fiscal_year = 2021 
      AND
      c.market = "India"
ORDER BY average_discount_percentage DESC
LIMIT 5;


-- 7. Get the complete report of the Gross sales amount for the customer “Atliq
--   Exclusive” for each month. This analysis helps to get an idea of low and
--   high-performing months and take strategic decisions.
--   The final report contains these columns:
--   Month
--   Year
--   Gross sales Amount
SELECT
	MONTHNAME(s.date) AS month,
    s.fiscal_year AS year,
    sum(gross_price * sold_quantity) AS gross_sales
FROM fact_sales_monthly s
JOIN dim_customer c
	USING (customer_code)
JOIN fact_gross_price g 
	USING (product_code)
WHERE c.customer = 'Atliq Exclusive'
GROUP BY month, year
ORDER BY year ASC;


-- 8. In which quarter of 2020, got the maximum total_sold_quantity? The final
--   output contains these fields sorted by the total_sold_quantity,
--   Quarter
--   total_sold_quantity
SELECT
		CASE 
			WHEN month(date) IN (9, 10, 11) THEN	"Q1"
			WHEN month(date) IN (12, 1, 2) 	THEN 	"Q2"
			WHEN month(date) IN (3, 4, 5) 	THEN 	"Q3"
			WHEN month(date) IN (6, 7, 8) 	THEN 	"Q4"
			END  AS quarter,
    SUM(sold_quantity) as total_sold_qty
FROM fact_sales_monthly
where fiscal_year = 2020 
GROUP BY quarter
ORDER BY total_sold_qty DESC;


-- 9. Which channel helped to bring more gross sales in the fiscal year 2021
--   and the percentage of contribution? The final output contains these fields,
--   channel
--   gross_sales_mln
--   percentage
WITH channel_gross_sales AS    
                           (SELECT c.channel,
                                   SUM(g.gross_price*f.sold_quantity)/1000000 AS gross_sales_mln
                            FROM fact_sales_monthly f
                            JOIN fact_gross_price g
                            ON f.product_code = g.product_code AND f.fiscal_year = g.fiscal_year
                            JOIN dim_customer c
                            ON f.customer_code = c.customer_code
                            WHERE f.fiscal_year = 2021
                            GROUP BY c.channel)

SELECT *, 
       ROUND(gross_sales_mln*100/SUM(gross_sales_mln) OVER(), 2) AS percentage
FROM channel_gross_sales;


-- OR

WITH gross_sales_2021 AS (
SELECT 
    channel,
    round(sum(gross_price * sold_quantity) / 1000000 ,2) AS gross_sales_mln
    FROM 
        fact_sales_monthly s
    JOIN 
        fact_gross_price g 
        ON s.product_code = g.product_code 
    JOIN 
        dim_customer c 
        ON s.customer_code = c.customer_code
    WHERE 
        s.fiscal_year = 2021
    GROUP BY 
        c.channel
), 
s_total AS (
SELECT 
	sum(gross_sales_mln) as total
FROM gross_sales_2021)
SELECT 
	channel,
    gross_sales_mln,
    concat(round((gross_sales_mln / total) * 100,2), ' %') AS pct_contrubtion
FROM gross_sales_2021  
CROSS JOIN s_total 
ORDER BY gross_sales_mln desc;


-- 10. Get the Top 3 products in each division that have a high
-- total_sold_quantity in the fiscal_year 2021? The final output contains these
--  fields,
--  division
--  product_code
--  product
--  total_sold_quantity
--  rank_order
WITH product_by_sold_quantity AS ( SELECT f.product_code,
                                          SUM(f.sold_quantity) AS total_sold_quantity
                                   FROM fact_sales_monthly f
                                   WHERE fiscal_year = 2021
                                   GROUP BY f.product_code),

ranks AS ( SELECT p.division,
                  q.product_code, 
                  p.product,
                  q.total_sold_quantity,
                  DENSE_RANK() OVER (PARTITION BY p.division ORDER BY total_sold_quantity DESC) AS rank_order
           FROM product_by_sold_quantity q
           JOIN dim_product p
           ON q.product_code = p.product_code)

SELECT * FROM ranks
WHERE rank_order <=3;


-- OR

WITH cte1 AS (
    SELECT
        p.division,
        p.product_code,
        CONCAT(p.product, " (", p.variant, ")") AS product,
        SUM(sold_quantity) AS total_sold_qty,
        RANK() OVER(PARTITION BY p.division ORDER BY SUM(sold_quantity) DESC) AS rank_order
    FROM fact_sales_monthly fs 
    JOIN dim_product p 
        ON p.product_code = fs.product_code
    WHERE fiscal_year = 2021
    GROUP BY p.division, p.product_code, p.product, p.variant
)
SELECT 
    *
FROM cte1
WHERE rank_order <= 3
ORDER BY division, rank_order ASC;








































































































































































































































