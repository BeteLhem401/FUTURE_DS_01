-- ======================================================
-- STEP 1: CREATE DATABASE AND LOAD RAW DATA
-- ======================================================
-- Initialize the database and create the raw table.
-- Load unprocessed transactional data from the CSV file.
-- All columns are imported exactly as in the source file.

CREATE DATABASE IF NOT EXISTS superstore_db;
USE superstore_db;

DROP TABLE IF EXISTS superstore_raw;

CREATE TABLE superstore_raw (
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

-- Load CSV data into the raw table with proper date conversion.
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/superstore_orders.csv'
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

-- Create a backup copy of the raw data for safety.
CREATE TABLE superstore_backup AS SELECT * FROM superstore_raw;

-- ======================================================
-- STEP 2: DATA CLEANING
-- ======================================================
-- Remove invalid records, including missing or negative numeric values.
-- Ensure all sales and quantity values are logical for analysis.

DROP TABLE IF EXISTS superstore_clean;

CREATE TABLE superstore_clean AS
SELECT *
FROM superstore_raw
WHERE Sales IS NOT NULL
  AND Quantity IS NOT NULL
  AND Profit IS NOT NULL
  AND Sales >= 0
  AND Quantity > 0;

-- Remove rows with logically inconsistent negative values.
DELETE FROM superstore_clean
WHERE Profit < 0 AND (Sales < 0 OR Quantity < 0);

-- ======================================================
-- STEP 3: BUILD THE FINAL FACT TABLE
-- ======================================================
-- Aggregate data by Order_ID and Product_ID.
-- This table serves as the central fact table for analytics.

DROP TABLE IF EXISTS superstore_final;

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

-- Add indexes to improve query performance.
CREATE INDEX idx_order_product ON superstore_final (Order_ID, Product_ID);
CREATE INDEX idx_orderdate ON superstore_final (Order_Date);
CREATE INDEX idx_customer ON superstore_final (Customer_ID);
CREATE INDEX idx_region ON superstore_final (Region);

-- ======================================================
-- STEP 4: FEATURE ENGINEERING
-- ======================================================
-- Create additional calculated fields to support analysis:
-- - Order_Year: year of the order
-- - Order_Month: year-month of the order
-- - AvgPricePerUnit: average price per unit sold

ALTER TABLE superstore_final
  ADD COLUMN Order_Year INT,
  ADD COLUMN Order_Month VARCHAR(7),
  ADD COLUMN AvgPricePerUnit DECIMAL(10,2);

UPDATE superstore_final
SET 
  Order_Year = YEAR(Order_Date),
  Order_Month = DATE_FORMAT(Order_Date, '%Y-%m'),
  AvgPricePerUnit = CASE WHEN Quantity > 0 THEN Sales / Quantity ELSE NULL END;

-- ======================================================
-- STEP 5: ANALYTICAL INSIGHT TABLES
-- ======================================================
-- Create supporting tables for dashboards and deeper analytics.

-- ---------- Category Performance ----------
DROP TABLE IF EXISTS insight_category_performance;
CREATE TABLE insight_category_performance AS
SELECT 
  Category,
  ROUND(SUM(Sales),2) AS total_sales,
  ROUND(SUM(Profit),2) AS total_profit,
  ROUND(SUM(Profit)/NULLIF(SUM(Sales),0)*100,2) AS profit_margin
FROM superstore_final
GROUP BY Category;

-- ---------- Region Performance ----------
DROP TABLE IF EXISTS insight_region_performance;
CREATE TABLE insight_region_performance AS
SELECT
  Region,
  COUNT(DISTINCT Customer_ID) AS total_customers,
  SUM(Sales) AS total_sales,
  SUM(Profit) AS total_profit,
  ROUND(SUM(Profit)/NULLIF(SUM(Sales),0)*100,2) AS profit_margin
FROM superstore_final
GROUP BY Region;

-- ---------- Customer Lifetime Value (RFM Model) ----------
DROP TABLE IF EXISTS insight_customer_value;
CREATE TABLE insight_customer_value AS
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
    NTILE(5) OVER (ORDER BY r.monetary DESC) AS monetary_score
FROM customer_stats cs
JOIN rfm r USING (Customer_ID);

-- ---------- Product Performance ----------
DROP TABLE IF EXISTS insight_product_performance;
CREATE TABLE insight_product_performance AS
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
)
SELECT
    Product_ID,
    Product_Name,
    Category,
    Sub_Category,
    total_sales,
    total_profit,
    ROUND(total_profit/NULLIF(total_sales,0)*100,2) AS profit_margin,
    total_orders,
    ROUND(total_sales/NULLIF(total_quantity,0),2) AS avg_price_per_unit
FROM product_stats;

-- ---------- Monthly Sales Growth ----------
DROP TABLE IF EXISTS insight_monthly_growth;
CREATE TABLE insight_monthly_growth AS
SELECT
  Order_Month,
  SUM(Sales) AS total_sales,
  LAG(SUM(Sales)) OVER (ORDER BY Order_Month) AS prev_month_sales,
  ROUND(((SUM(Sales) - LAG(SUM(Sales)) OVER (ORDER BY Order_Month))
         / NULLIF(LAG(SUM(Sales)) OVER (ORDER BY Order_Month),0))*100,2) AS monthly_growth_pct
FROM superstore_final
GROUP BY Order_Month;

-- ======================================================
-- STEP 6: PRIMARY KEYS & RELATIONSHIPS FOR POWER BI
-- ======================================================
-- Add primary keys and foreign key constraints to build a proper star schema.

-- FACT TABLE UNIQUE KEY
ALTER TABLE superstore_final ADD COLUMN Fact_ID VARCHAR(50);
UPDATE superstore_final SET Fact_ID = CONCAT(Order_ID, '_', Product_ID);
ALTER TABLE superstore_final ADD PRIMARY KEY (Fact_ID);

-- CUSTOMER DIMENSION KEY
ALTER TABLE insight_customer_value ADD PRIMARY KEY (Customer_ID);

-- PRODUCT DIMENSION KEY
-- Ensure uniqueness before adding primary key
CREATE TEMPORARY TABLE tmp_products AS
SELECT 
    Product_ID,
    MAX(Product_Name) AS Product_Name,
    MAX(Category) AS Category,
    MAX(Sub_Category) AS Sub_Category
FROM insight_product_performance
GROUP BY Product_ID;

TRUNCATE TABLE insight_product_performance;
INSERT INTO insight_product_performance (Product_ID, Product_Name, Category, Sub_Category)
SELECT Product_ID, Product_Name, Category, Sub_Category FROM tmp_products;
DROP TEMPORARY TABLE tmp_products;

ALTER TABLE insight_product_performance ADD PRIMARY KEY (Product_ID);

-- REGION DIMENSION KEY
ALTER TABLE insight_region_performance ADD PRIMARY KEY (Region);

-- ESTABLISH FACT–DIMENSION RELATIONSHIPS
ALTER TABLE superstore_final
ADD CONSTRAINT fk_fact_customer FOREIGN KEY (Customer_ID)
  REFERENCES insight_customer_value (Customer_ID);

ALTER TABLE superstore_final
ADD CONSTRAINT fk_fact_product FOREIGN KEY (Product_ID)
  REFERENCES insight_product_performance (Product_ID);

-- ======================================================
-- ✅ COMPLETED
-- ======================================================
SELECT '✅ Superstore BI Model Created Successfully — Ready for Power BI!' AS status_message;
