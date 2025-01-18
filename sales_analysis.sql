-- 1. RFM (Recency, Frequency, Monetary) Analysis
WITH rfm_table AS (SELECT
customer_id, 
EXTRACT(DAY FROM((SELECT MAX(order_date) FROM sales) - MAX(order_date)) )::INTEGER AS recency,
COUNT(*) AS frequency,
SUM(unit_price) AS monetary
FROM sales
GROUP BY 1),

rfm_score_table AS (SELECT
customer_id, 
NTILE(5) OVER(ORDER BY recency ASC) AS recency_score,
NTILE(5) OVER(ORDER BY frequency DESC) AS frequency_score,
NTILE(5) OVER(ORDER BY monetary DESC) AS monetary_score
FROM rfm_table),

rfm AS (SELECT
customer_id,
CASE 
     WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Top Customer'
     WHEN recency_score <= 2 AND frequency_score >= 4  THEN 'Loyal'
     WHEN recency_score >= 4 AND monetary_score <= 2 THEN 'At Risk'
	 ELSE 'Other'
END AS segment	
FROM rfm_score_table),

-- 2. Sales Trends Analysis
sales_table AS (SELECT
order_number, DATE(order_date) AS order_date, customer_id, product_id,
ROUND(order_quantity::NUMERIC * unit_price::NUMERIC , 2) AS revenue,
ROUND((unit_price::NUMERIC - unit_cost::NUMERIC) * order_quantity::NUMERIC, 2) AS profit
FROM sales),

sales_trends AS (SELECT
TO_CHAR(order_date, 'YYYY-MM') AS month, 
SUM(revenue) AS total_revenue ,
SUM(profit) AS total_profit, 
ROUND(SUM(profit * 1.0/ revenue)::NUMERIC, 2) AS profit_margin
FROM sales_table
GROUP BY 1
ORDER BY 1),


-- 3. Customer Lifetime Value Analysis
customer_data AS (SELECT
customer_id, 
COUNT(DISTINCT order_number) AS total_orders,
ROUND(SUM(unit_price * order_quantity)::NUMERIC, 2) AS total_revenue,
MIN(DATE(order_date)) AS first_order_date,
MAX(DATE(order_date)) AS last_order_date
FROM sales
GROUP BY 1),

customer_lifespan AS (SELECT
customer_id, 
EXTRACT(YEAR FROM AGE(last_order_date, first_order_date)) * 12 +
EXTRACT(MONTH FROM AGE(last_order_date, first_order_date)) AS lifespan
FROM customer_data),

customer_metrics AS (SELECT
c.customer_id, 
c.total_revenue * 1.0/ c.total_orders AS average_purchase_value, 
c.total_orders * 1.0 / l.lifespan AS purchase_frequency,
l.lifespan AS lifespan_months
FROM customer_data c
INNER JOIN customer_lifespan l ON c.customer_id = l.customer_id),

clv_result AS (SELECT
customer_id,
ROUND((average_purchase_value * purchase_frequency * lifespan_months)::NUMERIC, 0) AS clv
FROM customer_metrics
ORDER BY 2 DESC),

-- 4. Discount Optimization (Discount Impact on profit and revenue)
discount_sales_table AS (SELECT
s.*,
d.discount_applied AS discount,
d.sales_channel,
(d.discount_applied / s.unit_price) AS discount_rate
FROM sales s
INNER JOIN discount d ON s.product_id = d.product_id),

discount_analysis AS (SELECT
DISTINCT customer_id, 
product_id, 
order_date, 
order_quantity, 
unit_price,
unit_cost,
discount_rate, 
ROUND((unit_price * (1 - discount_rate) * order_quantity)::NUMERIC , 2) AS revenue_after_discount,
ROUND(((unit_price * (1 - discount_rate) * order_quantity - unit_cost * order_quantity))::NUMERIC, 2) AS profit_after_discount
FROM discount_sales_table)

SELECT
discount_rate, 
SUM(revenue_after_discount) AS total_revenue,
SUM(profit_after_discount) AS total_profit
FROM discount_analysis
GROUP BY 1
ORDER BY 1 DESC


