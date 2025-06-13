-- project_queries.sql
-- Dashboard Queries for Project
-- ==========================================================================================================
-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its
-- business in the APAC region.

SELECT distinct(market) FROM atliq_hardware.dim_customer
where region= "APAC" and customer="Atliq Exclusive";
-- ==========================================================================================================
-- Request 2. What is the percentage of unique product increase in 2021 vs. 2020? The
-- final output contains these fields,
-- unique_products_2020
-- unique_products_2021
-- percentage_chg

WITH product_counts AS (  
    SELECT  
        s.fiscal_year,  
        COUNT(DISTINCT p.product_code) AS unique_products  
    FROM dim_product p  
    INNER JOIN fact_sales_monthly s  
        ON s.product_code = p.product_code  
    WHERE s.fiscal_year IN (2020, 2021)  
    GROUP BY s.fiscal_year  
)  
SELECT  
    MAX(CASE WHEN fiscal_year = 2020 THEN unique_products END) AS unique_products_2020,  
    MAX(CASE WHEN fiscal_year = 2021 THEN unique_products END) AS unique_products_2021,  
    ROUND(  
        (MAX(CASE WHEN fiscal_year = 2021 THEN unique_products END) -  
         MAX(CASE WHEN fiscal_year = 2020 THEN unique_products END)) * 100.0 /  
         NULLIF(MAX(CASE WHEN fiscal_year = 2020 THEN unique_products END), 0),  
        2  
    ) AS percentage_chg  
FROM product_counts;
-- ==========================================================================================================
-- Request 3. Provide a report with all the unique product counts for each segment and
-- sort them in descending order of product counts. The final output contains
-- 2 fields,
-- segment
-- product_count

SELECT 
    segment, COUNT(product) AS product_count
FROM atliq_hardware.dim_product
GROUP BY segment
ORDER BY product_count DESC;
-- ==========================================================================================================
-- 4. Follow-up: Which segment had the most increase in unique products in
-- 2021 vs 2020? The final output contains these fields,
-- segment product_count_2020
-- product_count_2021
-- difference

WITH product_count AS (
    SELECT 
        dp.segment, 
        fsm.fiscal_year, 
        COUNT(DISTINCT dp.product_code) AS product_count
    FROM atliq_hardware.fact_sales_monthly fsm
    JOIN atliq_hardware.dim_product dp 
        ON fsm.product_code = dp.product_code
    WHERE fsm.fiscal_year IN (2020, 2021)
    GROUP BY dp.segment, fsm.fiscal_year
)
SELECT 
    segment,
    COALESCE(MAX(CASE WHEN fiscal_year = 2020 THEN product_count END), 0) AS product_count_2020,
    COALESCE(MAX(CASE WHEN fiscal_year = 2021 THEN product_count END), 0) AS product_count_2021,
    COALESCE(MAX(CASE WHEN fiscal_year = 2021 THEN product_count END), 0) - 
    COALESCE(MAX(CASE WHEN fiscal_year = 2020 THEN product_count END), 0) AS difference
FROM product_count
GROUP BY segment
ORDER BY difference DESC;
-- ==========================================================================================================
-- request 5. Get the products that have the highest and lowest manufacturing costs.
-- The final output should contain these fields,
-- product_code, product, manufacturing_cost

WITH cost_data AS (
    SELECT dp.product_code, dp.product, fmc.manufacturing_cost,
        RANK() OVER (ORDER BY fmc.manufacturing_cost ASC) AS lowest_rank,
        RANK() OVER (ORDER BY fmc.manufacturing_cost DESC) AS highest_rank
    FROM atliq_hardware.fact_manufacturing_cost fmc
    JOIN atliq_hardware.dim_product dp 
        ON fmc.product_code = dp.product_code)
SELECT 
    product_code, product, manufacturing_cost
FROM cost_data
WHERE lowest_rank = 1 OR highest_rank = 1;
-- ==========================================================================================================
-- Request 6. Generate a report which contains the top 5 customers who received an
-- average high pre_invoice_discount_pct for the fiscal year 2021 and in the
-- Indian market. The final output contains these fields,
-- customer_code customer
-- average_discount_percentage
 
SELECT fpid.customer_code, dim.customer, 
       ROUND(AVG(fpid.pre_invoice_discount_pct) * 100, 2) AS average_discount_percentage
FROM atliq_hardware.fact_pre_invoice_deductions AS fpid
JOIN atliq_hardware.dim_customer AS dim 
ON fpid.customer_code = dim.customer_code
WHERE fpid.fiscal_year = 2021 
AND dim.market = 'India'
GROUP BY fpid.customer_code, dim.customer
ORDER BY average_discount_percentage DESC
LIMIT 5;
-- ==========================================================================================================
-- 7. Get the complete report of the Gross sales amount for the customer “Atliq
-- Exclusive” for each month. This analysis helps to get an idea of low and
-- high-performing months and take strategic decisions.
-- The final report contains these columns: Month, Year, Gross sales Amount
SELECT 
    MONTHNAME(fsm.date) AS 'month',
    fsm.fiscal_year as 'Year',
       ROUND(SUM(fgp.gross_price * fsm.sold_quantity), 2) AS Gross_sales_Amount
FROM fact_sales_monthly fsm
JOIN 
    fact_gross_price fgp 
    ON fgp.product_code = fsm.product_code 
JOIN atliq_hardware.dim_customer dc 
ON fsm.customer_code = dc.customer_code
WHERE dc.customer = 'Atliq Exclusive'
GROUP BY month, fsm.fiscal_year 
ORDER BY fsm.fiscal_year ;
-- ==========================================================================================================
-- 8. In which quarter of 2020, got the maximum total_sold_quantity? The final
-- output contains these fields sorted by the total_sold_quantity,
-- Quarter, total_sold_quantity

SELECT 
  CASE
    WHEN date BETWEEN '2019-09-01' AND '2019-11-01' THEN 'Q1'
    WHEN date BETWEEN '2019-12-01' AND '2020-02-01' THEN 'Q2'
    WHEN date BETWEEN '2020-03-01' AND '2020-05-01' THEN 'Q3'
    WHEN date BETWEEN '2020-06-01' AND '2020-08-01' THEN 'Q4'
  END AS Quarter,
  SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = 2020
GROUP BY Quarter;
-- ==========================================================================================================
-- 9. Which channel helped to bring more gross sales in the fiscal year 2021
-- and the percentage of contribution? The final output contains these fields,
-- channel gross_sales_mln, percentage

WITH channel_sales AS (
    SELECT dc.channel, 
        round(SUM(fgp.gross_price * fsm.sold_quantity) / 1000000, 2) AS gross_sales_mln
    FROM atliq_hardware.fact_sales_monthly fsm
    JOIN 
        atliq_hardware.fact_gross_price fgp 
        ON fsm.product_code = fgp.product_code 
        AND fsm.fiscal_year = fgp.fiscal_year
    JOIN 
        atliq_hardware.dim_customer dc 
        ON fsm.customer_code = dc.customer_code
    WHERE fsm.fiscal_year = 2021
    GROUP BY dc.channel)
SELECT 
    channel, 
    gross_sales_mln, 
    round((gross_sales_mln / SUM(gross_sales_mln) OVER()) * 100, 2) AS percentage
FROM channel_sales
ORDER BY gross_sales_mln DESC;
-- ==========================================================================================================
-- 10. Get the Top 3 products in each division that have a high
-- total_sold_quantity in the fiscal_year 2021? The final output contains these
-- fields, division, product_code

WITH product_sales AS (
    SELECT dp.division, fsm.product_code, 
        SUM(fsm.sold_quantity) AS total_sold_quantity,
        RANK() OVER (PARTITION BY dp.division ORDER BY SUM(fsm.sold_quantity) DESC) AS rnk
    FROM atliq_hardware.fact_sales_monthly fsm
    JOIN 
        atliq_hardware.dim_product dp 
        ON fsm.product_code = dp.product_code
    WHERE fsm.fiscal_year = 2021
    GROUP BY dp.division, fsm.product_code)
SELECT division, product_code
FROM product_sales
WHERE rnk <= 3
ORDER BY division, rnk;
