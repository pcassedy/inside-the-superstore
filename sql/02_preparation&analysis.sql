-- Data Preparation and Analysis
USE superstore;

-- Part 1: Explore the Data
-- 1.1 Preview the first rows
SELECT * FROM orders LIMIT 10;

-- 1.2 Date range covered
SELECT MIN(order_date) AS first_order,
	   MAX(order_date) AS last_order
FROM orders;

-- 1.3 How many unique values in key columns
SELECT COUNT(DISTINCT order_id) AS orders,
	   COUNT(DISTINCT customer_id) AS customers,
       COUNT(DISTINCT product_id) AS products,
       COUNT(DISTINCT city) AS cities,
       COUNT(DISTINCT state) AS states
FROM orders;

-- 1.4 Missing or empty values in each column
SELECT 
	SUM(order_id IS NULL OR order_id = '') AS order_id,
    SUM(order_date IS NULL) AS order_date,
    SUM(ship_date IS NULL) AS ship_date,
    SUM(customer_id IS NULL OR customer_id = '') AS customer_id,
    SUM(postal_code IS NULL OR postal_code = '') AS postal_code,
    SUM(product_id IS NULL OR product_id = '') AS product_id,
    SUM(product_name IS NULL OR product_name = '') AS product_name,
    SUM(sales is NULL) AS sales,
    SUM(profit is NULL) AS profit
FROM orders;

-- 1.5 Ranges of the number columns
SELECT MIN(sales) AS min_sales, MAX(sales) AS max_sales, AVG(sales) AS avg_sales,
	   MIN(quantity) AS min_qty, MAX(quantity) AS max_qty, 
       MIN(discount) AS min_discount, MAX(discount) AS max_discount,
       MIN(profit) AS min_profit, MAX(profit) AS max_profit
FROM orders;
       
-- 1.6 The values in each category column
SELECT ship_mode, COUNT(*) AS rows_count FROM orders GROUP BY ship_mode;
SELECT segment,   COUNT(*) AS rows_count FROM orders GROUP BY segment;
SELECT country,   COUNT(*) AS rows_count FROM orders GROUP BY country;
SELECT region,    COUNT(*) AS rows_count FROM orders GROUP BY region;
SELECT category, sub_category, COUNT(*) AS rows_count
FROM orders GROUP BY category, sub_category ORDER BY category, sub_category;

-- 1.7 Which region do the Canadian rows belong to?
SELECT country, region, COUNT(*) AS rows_count
FROM orders
GROUP BY country, region
ORDER BY country, region;

-- 2.2 Duplicate rows (same order, product and values)
SELECT order_id, product_id, sales, quantity, COUNT(*) AS times_found
FROM orders
GROUP BY order_id, product_id, sales, quantity
HAVING COUNT(*) > 1;

-- 1.8 Ship date before order date
SELECT COUNT(*) AS bad_ship_dates
FROM orders
WHERE ship_date < order_date;

-- 1.9 Does each customer ID always have the same name?
SELECT customer_id, COUNT(DISTINCT customer_name) AS name_count
FROM orders
GROUP BY customer_id
HAVING COUNT(DISTINCT customer_name) > 1;

-- 1.10 Does each product ID always have the same name?
SELECT product_id, COUNT(DISTINCT product_name) AS name_count
FROM orders
GROUP BY product_id
HAVING COUNT(DISTINCT product_name) > 1;

-- 1.11 Postal code lengths in each country
SELECT country, LENGTH(postal_code) AS code_length, COUNT(*) AS rows_count
FROM orders
GROUP BY country, LENGTH(postal_code)
ORDER BY country, code_length;

-- 1.12 Look at the possible duplicates in full
SELECT *
FROM orders
WHERE (order_id = 'US-2023-150119' AND product_id = 'FUR-CH-10002965')
   OR (order_id = 'CA-2023-153623' AND product_id = 'FUR-FU-10002501')
ORDER BY order_id, row_id;

-- 1.13 Look at the two names for each product ID
SELECT product_id, product_name, category, sub_category, COUNT(*) AS rows_count
FROM orders
WHERE product_id IN (
    SELECT product_id
    FROM orders
    GROUP BY product_id
    HAVING COUNT(DISTINCT product_name) > 1
)
GROUP BY product_id, product_name, category, sub_category
ORDER BY product_id;

-- 1.14 Compare the remaining columns of the possible duplicates
SELECT row_id, order_id, product_name, sales, quantity, discount, profit
FROM orders
WHERE row_id IN (391, 392, 1699, 1700);

-- Part 2: Cleaning
-- 2.1 Create the clean view
CREATE VIEW orders_clean AS
WITH numbered AS (
    SELECT o.*,
           ROW_NUMBER() OVER (
               PARTITION BY order_id, product_id, sales, quantity, discount, profit
               ORDER BY row_id
           ) AS copy_number
    FROM orders o
)
SELECT
    n.row_id, n.order_id, n.order_date, n.ship_date, n.ship_mode,
    n.customer_id, n.customer_name, n.segment, n.country, n.city, n.state,
    -- fix: add the missing leading zero to 4-digit US postal codes
    CASE WHEN n.country = 'United States' AND LENGTH(n.postal_code) = 4
         THEN LPAD(n.postal_code, 5, '0')
         ELSE n.postal_code
    END AS postal_code,
    n.region, n.product_id, n.product_name, n.category, n.sub_category,
    n.sales, n.quantity, n.discount, n.profit,
    -- added columns for the analysis
    ROUND(n.profit / n.sales, 4) AS profit_margin,
    CASE WHEN n.discount = 0     THEN 'No discount'
         WHEN n.discount <= 0.20 THEN '1-20%'
         WHEN n.discount <= 0.40 THEN '21-40%'
         ELSE 'Over 40%'
    END AS discount_band,
    DATEDIFF(n.ship_date, n.order_date) AS ship_days,
    YEAR(n.order_date) AS order_year,
    DATE_FORMAT(n.order_date, '%Y-%m') AS order_month,
    CASE WHEN n.order_id IN (SELECT order_id FROM returns)
         THEN 'Yes' ELSE 'No'
    END AS returned,
    p.regional_manager
FROM numbered n
LEFT JOIN people p ON n.region = p.region
-- fix: keep only the first copy of each duplicate
WHERE n.copy_number = 1;

-- 2.2 Check the clean view
SELECT COUNT(*) AS clean_rows FROM orders_clean;

SELECT country, LENGTH(postal_code) AS code_length, COUNT(*) AS rows_count
FROM orders_clean
GROUP BY country, LENGTH(postal_code);

SELECT * FROM orders_clean LIMIT 10;

-- Part 3: Analysis
-- Q1: How have sales and profit changed over time?
-- 3.1 Yearly sales, profit, margin and growth
WITH yearly AS (
    SELECT order_year,
           COUNT(DISTINCT order_id) AS total_orders,
           ROUND(SUM(sales), 2)     AS total_sales,
           ROUND(SUM(profit), 2)    AS total_profit
    FROM orders_clean
    GROUP BY order_year
)
SELECT order_year,
       total_orders,
       total_sales,
       total_profit,
       ROUND(total_profit / total_sales * 100, 2) AS profit_margin_pct,
       ROUND((total_sales - LAG(total_sales) OVER (ORDER BY order_year))
             / LAG(total_sales) OVER (ORDER BY order_year) * 100, 2) AS sales_growth_pct,
       ROUND((total_profit - LAG(total_profit) OVER (ORDER BY order_year))
             / LAG(total_profit) OVER (ORDER BY order_year) * 100, 2) AS profit_growth_pct
FROM yearly
ORDER BY order_year;

-- 3.2 Monthly sales and profit (to spot seasonal patterns)
SELECT order_month,
       ROUND(SUM(sales), 2)  AS total_sales,
       ROUND(SUM(profit), 2) AS total_profit
FROM orders_clean
GROUP BY order_month
ORDER BY order_month;

-- Q2: Which categories and sub-categories make or lose money?
-- Sales and profit by category
SELECT category,
       ROUND(SUM(sales), 2)  AS total_sales,
       ROUND(SUM(profit), 2) AS total_profit,
       ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct,
       ROUND(SUM(sales) / (SELECT SUM(sales) FROM orders_clean) * 100, 2) AS share_of_sales_pct
FROM orders_clean
GROUP BY category
ORDER BY total_profit DESC;

-- 3.4 Sales and profit by sub-category (lowest profit first)
SELECT category,
       sub_category,
       ROUND(SUM(sales), 2)  AS total_sales,
       ROUND(SUM(profit), 2) AS total_profit,
       ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM orders_clean
GROUP BY category, sub_category
ORDER BY total_profit ASC;

-- Q3: How do discounts affect profit, and at what level do orders start losing money?
-- 3.5 Profit by discount band
SELECT discount_band,
       COUNT(*)              AS order_lines,
       ROUND(SUM(sales), 2)  AS total_sales,
       ROUND(SUM(profit), 2) AS total_profit,
       ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct,
       ROUND(AVG(profit < 0) * 100, 2)          AS pct_lines_at_loss
FROM orders_clean
GROUP BY discount_band
ORDER BY MIN(discount);

-- 3.6 Profit at each exact discount level
SELECT discount,
       COUNT(*)              AS order_lines,
       ROUND(SUM(profit), 2) AS total_profit,
       ROUND(AVG(profit), 2) AS avg_profit_per_line,
       ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM orders_clean
GROUP BY discount
ORDER BY discount;

-- Q4: Which regions underperform, and do discounts or returns explain it?
-- 3.7 Region scorecard
SELECT region,
       regional_manager,
       ROUND(SUM(sales), 2)  AS total_sales,
       ROUND(SUM(profit), 2) AS total_profit,
       ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct,
       ROUND(AVG(discount) * 100, 2)            AS avg_discount_pct,
       ROUND(COUNT(DISTINCT CASE WHEN returned = 'Yes' THEN order_id END)
             / COUNT(DISTINCT order_id) * 100, 2) AS return_rate_pct
FROM orders_clean
GROUP BY region, regional_manager
ORDER BY profit_margin_pct ASC;

-- 3.8 Profit by region and category
SELECT region,
       category,
       ROUND(SUM(sales), 2)  AS total_sales,
       ROUND(SUM(profit), 2) AS total_profit,
       ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct,
       ROUND(AVG(discount) * 100, 2)            AS avg_discount_pct
FROM orders_clean
GROUP BY region, category
ORDER BY region, total_profit ASC;

-- Q5: Which customers bring in the most profit?
-- 3.9 Top 10 customers by profit
SELECT customer_id,
       customer_name,
       segment,
       COUNT(DISTINCT order_id) AS total_orders,
       ROUND(SUM(sales), 2)     AS total_sales,
       ROUND(SUM(profit), 2)    AS total_profit
FROM orders_clean
GROUP BY customer_id, customer_name, segment
ORDER BY total_profit DESC
LIMIT 10;

-- 3.10 Share of profit by customer group (top 20%, next 20%, ...)
WITH customer_profit AS (
    SELECT customer_id,
           SUM(profit) AS total_profit
    FROM orders_clean
    GROUP BY customer_id
),
ranked AS (
    SELECT customer_id,
           total_profit,
           NTILE(5) OVER (ORDER BY total_profit DESC) AS customer_group
    FROM customer_profit
)
SELECT customer_group,
       COUNT(*)                    AS customers,
       ROUND(SUM(total_profit), 2) AS group_profit,
       ROUND(SUM(total_profit) / (SELECT SUM(total_profit) FROM customer_profit) * 100, 2) AS share_of_profit_pct
FROM ranked
GROUP BY customer_group
ORDER BY customer_group;

-- 3.11 Profit by customer segment
SELECT segment,
       COUNT(DISTINCT customer_id) AS customers,
       ROUND(SUM(sales), 2)        AS total_sales,
       ROUND(SUM(profit), 2)       AS total_profit,
       ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM orders_clean
GROUP BY segment
ORDER BY total_profit DESC;

-- Q6: Which products should Superstore protect, fix, grow or drop?
-- 3.12 Product matrix by sub-category
WITH sub_stats AS (
    SELECT category,
           sub_category,
           SUM(sales)  AS total_sales,
           SUM(profit) AS total_profit,
           SUM(profit) / SUM(sales) AS margin
    FROM orders_clean
    GROUP BY category, sub_category
),
benchmarks AS (
    SELECT AVG(total_sales)                 AS avg_sales,
           SUM(total_profit) / SUM(total_sales) AS overall_margin
    FROM sub_stats
)
SELECT s.category,
       s.sub_category,
       ROUND(s.total_sales, 2)  AS total_sales,
       ROUND(s.total_profit, 2) AS total_profit,
       ROUND(s.margin * 100, 2) AS profit_margin_pct,
       CASE
           WHEN s.total_sales >= b.avg_sales AND s.margin >= b.overall_margin THEN 'Protect'
           WHEN s.total_sales >= b.avg_sales AND s.margin <  b.overall_margin THEN 'Fix'
           WHEN s.total_sales <  b.avg_sales AND s.margin >= b.overall_margin THEN 'Grow'
           ELSE 'Review / drop'
       END AS action
FROM sub_stats s
CROSS JOIN benchmarks b
ORDER BY action, total_profit DESC;

-- 3.13 The 10 products that lost the most money
SELECT product_id,
       product_name,
       sub_category,
       SUM(quantity)         AS units_sold,
       ROUND(SUM(sales), 2)  AS total_sales,
       ROUND(SUM(profit), 2) AS total_profit,
       ROUND(AVG(discount) * 100, 2) AS avg_discount_pct
FROM orders_clean
GROUP BY product_id, product_name, sub_category
ORDER BY total_profit ASC
LIMIT 10;

-- Q7: How much profit was lost on orders discounted above 20%?
-- 3.14 Profit and losses on heavily discounted lines
SELECT COUNT(*)              AS order_lines,
       ROUND(SUM(sales), 2)  AS total_sales,
       ROUND(SUM(profit), 2) AS net_profit,
       ROUND(SUM(CASE WHEN profit < 0 THEN profit ELSE 0 END), 2) AS total_losses,
       ROUND(SUM(CASE WHEN profit < 0 THEN profit ELSE 0 END)
             / (SELECT SUM(profit) FROM orders_clean WHERE profit < 0) * 100, 2) AS share_of_all_losses_pct
FROM orders_clean
WHERE discount > 0.20;

-- 3.15 Where those losses come from (by sub-category)
SELECT category,
       sub_category,
       COUNT(*)              AS order_lines,
       ROUND(SUM(sales), 2)  AS total_sales,
       ROUND(SUM(profit), 2) AS net_profit
FROM orders_clean
WHERE discount > 0.20
GROUP BY category, sub_category
ORDER BY net_profit ASC;

-- Saving the clean data
SELECT * FROM orders_clean;