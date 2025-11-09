
-- 1. DATABASE AND RAW DATA LOAD

CREATE DATABASE IF NOT EXISTS superstore_db;
USE superstore_db;

CREATE TABLE IF NOT EXISTS superstore_raw (
    Row_ID INT,
    Order_ID VARCHAR(20),
    Order_Date DATE,
    Ship_Date DATE,
    Ship_Mode VARCHAR(50),
    Customer_ID VARCHAR(20),
    Customer_Name VARCHAR(100),
    Segment VARCHAR(50),
    Country VARCHAR(50),
    City VARCHAR(50),
    State VARCHAR(50),
    Postal_Code VARCHAR(20),
    Region VARCHAR(50),
    Product_ID VARCHAR(50),
    Category VARCHAR(50),
    Sub_Category VARCHAR(50),
    Product_Name TEXT,
    Sales DECIMAL(10,2),
    Quantity INT,
    Discount DECIMAL(5,2),
    Profit DECIMAL(10,2)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 9.3/Uploads/superstore - orders.csv'
INTO TABLE superstore_raw
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    Row_ID, Order_ID, @Order_Date, @Ship_Date, Ship_Mode,
    Customer_ID, Customer_Name, Segment, Country, City,
    State, Postal_Code, Region, Product_ID, Category,
    Sub_Category, Product_Name, Sales, Quantity, Discount, Profit
)
SET
    Order_Date = STR_TO_DATE(@Order_Date, '%m/%d/%Y'),
    Ship_Date  = STR_TO_DATE(@Ship_Date, '%m/%d/%Y');
-- back up
CREATE TABLE IF NOT EXISTS superstore_backup AS
SELECT * FROM superstore_raw;

-- 2. DATA CLEANING AND VALIDATION
-- ==================================
CREATE TABLE superstore_clean AS
SELECT *
FROM superstore_raw
WHERE Sales IS NOT NULL
  AND Quantity IS NOT NULL
  AND Profit IS NOT NULL
  AND Sales >= 0
  AND Quantity > 0
  AND Order_ID IS NOT NULL
  AND Customer_ID IS NOT NULL;

-- Check for anomalies
SELECT
  COUNT(*) AS total_rows,
  SUM(CASE WHEN Profit < 0 THEN 1 ELSE 0 END) AS negative_profit,
  SUM(CASE WHEN Sales = 0 THEN 1 ELSE 0 END) AS zero_sales,
  SUM(CASE WHEN Quantity <= 0 THEN 1 ELSE 0 END) AS invalid_quantity
FROM superstore_clean;

--  clean-up invalid negative profit if any
DELETE FROM superstore_clean
WHERE Profit < 0 AND (Sales < 0 OR Quantity < 0);

-- 3. FINAL CONSOLIDATED TABLE
-- ==================================
CREATE TABLE superstore_final AS
SELECT 
    Order_ID,
    Product_ID,
    MAX(Order_Date) AS Order_Date,
    MAX(Ship_Date) AS Ship_Date,
    MAX(Customer_ID) AS Customer_ID,
    MAX(Customer_Name) AS Customer_Name,
    MAX(Segment) AS Segment,
    MAX(Country) AS Country,
    MAX(City) AS City,
    MAX(State) AS State,
    MAX(Postal_Code) AS Postal_Code,
    MAX(Region) AS Region,
    MAX(Product_Name) AS Product_Name,
    MAX(Category) AS Category,
    MAX(Sub_Category) AS Sub_Category,
    SUM(Sales) AS Sales,
    SUM(Quantity) AS Quantity,
    ROUND(AVG(Discount),2) AS Discount,
    SUM(Profit) AS Profit
FROM superstore_clean
GROUP BY Order_ID, Product_ID;

-- Add useful indexes
CREATE INDEX idx_order_product ON superstore_final (Order_ID, Product_ID);
CREATE INDEX idx_orderdate ON superstore_final (Order_Date);
CREATE INDEX idx_customer ON superstore_final (Customer_ID);
CREATE INDEX idx_region ON superstore_final (Region);


-- 4. FEATURE ENGINEERING
-- ==================================
ALTER TABLE superstore_final
  ADD COLUMN Order_Year INT,
  ADD COLUMN Order_Month VARCHAR(7),
  ADD COLUMN AvgPricePerUnit DECIMAL(10,2);

UPDATE superstore_final
SET 
  Order_Year = YEAR(Order_Date),
  Order_Month = DATE_FORMAT(Order_Date, '%Y-%m'),
  AvgPricePerUnit = CASE WHEN Quantity > 0 THEN Sales / Quantity ELSE NULL END;

-- 5. STAGING FOR DASHBOARDS
-- ==================================
CREATE TABLE IF NOT EXISTS stg_daily_sales AS
SELECT
  DATE(Order_Date) AS order_date,
  Region,
  Category,
  Sub_Category,
  COUNT(DISTINCT Order_ID) AS total_orders,
  SUM(Sales) AS total_sales,
  SUM(Profit) AS total_profit,
  SUM(Quantity) AS total_quantity,
  ROUND(SUM(Profit)/NULLIF(SUM(Sales),0)*100,2) AS profit_margin
FROM superstore_final
GROUP BY DATE(Order_Date), Region, Category, Sub_Category;


-- 6. INSIGHT TABLES FOR POWER BI
-- ==================================

-- Category performance
CREATE TABLE IF NOT EXISTS insight_category_performance AS
SELECT 
  Category,
  ROUND(SUM(Sales),2) AS total_sales,
  ROUND(SUM(Profit),2) AS total_profit,
  ROUND(SUM(Profit)/NULLIF(SUM(Sales),0)*100,2) AS profit_margin
FROM superstore_final
GROUP BY Category
ORDER BY total_profit DESC;

-- Monthly trends
CREATE TABLE IF NOT EXISTS insight_monthly_trend AS
SELECT 
  Order_Month,
  SUM(Sales) AS total_sales,
  SUM(Profit) AS total_profit
FROM superstore_final
GROUP BY Order_Month
ORDER BY Order_Month;

-- Top profitable products
CREATE TABLE IF NOT EXISTS insight_top_products AS
SELECT
  Product_Name,
  ROUND(SUM(Profit),2) AS total_profit,
  SUM(Sales) AS total_sales
FROM superstore_final
GROUP BY Product_Name
ORDER BY total_profit DESC
LIMIT 10;

-- Regional insights
CREATE TABLE IF NOT EXISTS insight_region_performance AS
SELECT
  Region,
  COUNT(DISTINCT Customer_ID) AS total_customers,
  SUM(Sales) AS total_sales,
  SUM(Profit) AS total_profit,
  ROUND(SUM(Profit)/NULLIF(SUM(Sales),0)*100,2) AS profit_margin
FROM superstore_final
GROUP BY Region;

-- Segment behavior
CREATE TABLE IF NOT EXISTS insight_segment_behavior AS
SELECT
  Segment,
  COUNT(DISTINCT Customer_ID) AS total_customers,
  ROUND(SUM(Sales),2) AS total_sales,
  ROUND(SUM(Profit),2) AS total_profit,
  ROUND(SUM(Profit)/NULLIF(SUM(Sales),0)*100,2) AS profit_margin,
  ROUND(SUM(Sales)/NULLIF(COUNT(DISTINCT Customer_ID),0),2) AS avg_sales_per_customer
FROM superstore_final
GROUP BY Segment
ORDER BY total_profit DESC;

-- Customer behavior
CREATE TABLE IF NOT EXISTS insight_customer_behavior AS
SELECT
  Customer_ID,
  Customer_Name,
  COUNT(DISTINCT Order_ID) AS total_orders,
  ROUND(SUM(Sales),2) AS total_sales,
  ROUND(SUM(Profit),2) AS total_profit,
  ROUND(SUM(Sales)/NULLIF(COUNT(DISTINCT Order_ID),0),2) AS avg_order_value,
  ROUND(SUM(Profit)/NULLIF(COUNT(DISTINCT Order_ID),0),2) AS avg_profit_per_order
FROM superstore_final
GROUP BY Customer_ID, Customer_Name
ORDER BY total_profit DESC
LIMIT 200;

-- Customer Lifetime Value (RFM)
CREATE TABLE IF NOT EXISTS insight_customer_value AS
WITH customer_stats AS (
    SELECT
        Customer_ID,
        Customer_Name,
        Segment,
        MIN(Order_Date) AS first_purchase,
        MAX(Order_Date) AS last_purchase,
        COUNT(DISTINCT Order_ID) AS total_orders,
        SUM(Sales) AS total_sales,
        SUM(Profit) AS total_profit,
        SUM(Quantity) AS total_quantity
    FROM superstore_final
    GROUP BY Customer_ID, Customer_Name, Segment
),
rfm AS (
    SELECT
        cs.Customer_ID,
        DATEDIFF((SELECT MAX(Order_Date) FROM superstore_final), cs.last_purchase) AS recency_days,
        cs.total_orders AS frequency,
        cs.total_sales AS monetary
    FROM customer_stats cs
)
SELECT
    cs.Customer_ID,
    cs.Customer_Name,
    cs.Segment,
    cs.first_purchase,
    cs.last_purchase,
    DATEDIFF(cs.last_purchase, cs.first_purchase) AS active_days,
    cs.total_orders,
    cs.total_sales,
    cs.total_profit,
    cs.total_quantity,
    ROUND(cs.total_sales / NULLIF(cs.total_orders,0),2) AS avg_order_value,
    ROUND(cs.total_profit / NULLIF(cs.total_orders,0),2) AS avg_profit_per_order,
    r.recency_days,
    r.frequency,
    r.monetary,
    NTILE(5) OVER (ORDER BY r.recency_days ASC) AS recency_score,
    NTILE(5) OVER (ORDER BY r.frequency DESC) AS frequency_score,
    NTILE(5) OVER (ORDER BY r.monetary DESC) AS monetary_score,
    CONCAT(
        NTILE(5) OVER (ORDER BY r.recency_days ASC),
        NTILE(5) OVER (ORDER BY r.frequency DESC),
        NTILE(5) OVER (ORDER BY r.monetary DESC)
    ) AS rfm_score
FROM customer_stats cs
JOIN rfm r USING (Customer_ID)
ORDER BY cs.total_profit DESC;

-- Product performance
CREATE TABLE IF NOT EXISTS insight_product_performance AS
WITH product_stats AS (
    SELECT
        Product_ID,
        Product_Name,
        Category,
        Sub_Category,
        SUM(Sales) AS total_sales,
        SUM(Profit) AS total_profit,
        SUM(Quantity) AS total_quantity,
        COUNT(DISTINCT Order_ID) AS total_orders
    FROM superstore_final
    GROUP BY Product_ID, Product_Name, Category, Sub_Category
),
totals AS (
    SELECT SUM(Sales) AS global_sales, SUM(Profit) AS global_profit
    FROM superstore_final
)
SELECT
    p.Product_ID,
    p.Product_Name,
    p.Category,
    p.Sub_Category,
    p.total_sales,
    p.total_profit,
    ROUND(p.total_profit/NULLIF(p.total_sales,0)*100,2) AS profit_margin,
    p.total_orders,
    ROUND(p.total_sales/NULLIF(p.total_quantity,0),2) AS avg_price_per_unit,
    ROUND(p.total_profit/NULLIF(p.total_orders,0),2) AS avg_profit_per_order,
    ROUND(p.total_sales/NULLIF(t.global_sales,0)*100,2) AS sales_share_percent,
    ROUND(p.total_profit/NULLIF(t.global_profit,0)*100,2) AS profit_share_percent
FROM product_stats p
CROSS JOIN totals t
ORDER BY p.total_profit DESC
LIMIT 200;
