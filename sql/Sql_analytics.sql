-- superstore_star_schema.sql

SET FOREIGN_KEY_CHECKS = 0;

-- 0. Create database and switch

CREATE DATABASE IF NOT EXISTS superstore_db CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_unicode_ci';
USE superstore_db;


-- 1. Raw table (exact import of CSV)

DROP TABLE IF EXISTS raw_orders;
CREATE TABLE raw_orders (
    Row_ID INT,
    Order_ID VARCHAR(50),
    Order_Date DATE,
    Ship_Date DATE,
    Ship_Mode VARCHAR(100),
    Customer_ID VARCHAR(50),
    Customer_Name VARCHAR(200),
    Segment VARCHAR(100),
    Country VARCHAR(100),
    City VARCHAR(100),
    State VARCHAR(100),
    Postal_Code VARCHAR(50),
    Region VARCHAR(100),
    Product_ID VARCHAR(100),
    Category VARCHAR(100),
    Sub_Category VARCHAR(100),
    Product_Name TEXT,
    Sales DECIMAL(18,2),
    Quantity INT,
    Discount DECIMAL(6,4),
    Profit DECIMAL(18,2)
) ENGINE=InnoDB;


LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/superstore_orders.csv'
INTO TABLE raw_orders
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(Row_ID, Order_ID, @Order_Date, @Ship_Date, Ship_Mode,
 Customer_ID, Customer_Name, Segment, Country, City,
 State, Postal_Code, Region, Product_ID, Category,
 Sub_Category, Product_Name, Sales, Quantity, Discount, Profit)
SET
  Order_Date = STR_TO_DATE(@Order_Date, '%m/%d/%Y'),
  Ship_Date = STR_TO_DATE(@Ship_Date, '%m/%d/%Y');

-- Backup raw data 
DROP TABLE IF EXISTS raw_orders_backup;
CREATE TABLE raw_orders_backup AS SELECT * FROM raw_orders;


-- 2. Cleaning step
--    - Remove rows with null critical fields
--    - Standardize negative/zero values

DROP TABLE IF EXISTS clean_orders;
CREATE TABLE clean_orders AS
SELECT *
FROM raw_orders
WHERE Order_ID IS NOT NULL
  AND Product_ID IS NOT NULL
  AND Customer_ID IS NOT NULL
  AND Order_Date IS NOT NULL
  AND Sales IS NOT NULL
  AND Quantity IS NOT NULL
  AND Profit IS NOT NULL
  AND Sales >= 0
  AND Quantity >= 0;

-- Remove rows zero quantity with positive sales)
DELETE FROM clean_orders WHERE Quantity = 0 AND Sales > 0;

-- -----------------------------
-- 3. Create dimension tables
-- Customer dimension
DROP TABLE IF EXISTS dim_customer;
CREATE TABLE dim_customer AS
SELECT DISTINCT
  Customer_ID,
  TRIM(Customer_Name) AS CustomerName,
  Segment
FROM clean_orders;
ALTER TABLE dim_customer
  ADD PRIMARY KEY (Customer_ID);

-- Product dimension
DROP TABLE IF EXISTS dim_product;

CREATE TABLE dim_product AS
SELECT
    Product_ID,
    ANY_VALUE(Product_Name) AS ProductName,
    ANY_VALUE(Category) AS Category,
    ANY_VALUE(Sub_Category) AS SubCategory
FROM clean_orders
GROUP BY Product_ID;

ALTER TABLE dim_product
ADD PRIMARY KEY (Product_ID);

-- Region dimension
DROP TABLE IF EXISTS dim_region;
CREATE TABLE dim_region AS
SELECT DISTINCT
  Region
FROM clean_orders;
ALTER TABLE dim_region
  ADD PRIMARY KEY (Region);

-- Calendar dimension
DROP TABLE IF EXISTS dim_calendar;
CREATE TABLE dim_calendar AS
SELECT DISTINCT
  DATE(Order_Date) AS DateValue,
  YEAR(Order_Date) AS YearNumber,
  MONTH(Order_Date) AS MonthNumber,
  DATE_FORMAT(Order_Date, '%b') AS MonthName,
  DATE_FORMAT(Order_Date, '%Y-%m') AS YearMonth,
  DAYOFWEEK(Order_Date) AS WeekdayNumber
FROM clean_orders
WHERE Order_Date IS NOT NULL
ORDER BY DateValue;
ALTER TABLE dim_calendar
  ADD PRIMARY KEY (DateValue);
  
-- 4. Fact table (aggregated to one row per Order + Product)

DROP TABLE IF EXISTS fact_orders;
CREATE TABLE fact_orders AS
SELECT
  CONCAT(Order_ID, '_', Product_ID) AS OrderLineID,
  Order_ID,
  Product_ID,
  DATE(Order_Date) AS OrderDate,
  Customer_ID,
  Region,
  SUM(Sales) AS Sales,
  SUM(Quantity) AS Quantity,
  ROUND(SUM(Profit),2) AS Profit
FROM clean_orders
GROUP BY Order_ID, Product_ID, Customer_ID, Region, DATE(Order_Date);

-- Add primary key now that duplicates are aggregated
ALTER TABLE fact_orders
  ADD PRIMARY KEY (OrderLineID);

-- Add helpful indexes

ALTER TABLE fact_orders
  ADD INDEX idx_fact_orderdate (OrderDate),
  ADD INDEX idx_fact_customer (Customer_ID),
  ADD INDEX idx_fact_product (Product_ID),
  ADD INDEX idx_fact_region (Region);

-- 5. Referential integrity 

ALTER TABLE fact_orders
  ADD CONSTRAINT fk_fact_customer FOREIGN KEY (Customer_ID)
  REFERENCES dim_customer (Customer_ID)
  ON UPDATE CASCADE
  ON DELETE SET NULL;

-- Add FK from fact -> product

ALTER TABLE fact_orders
  ADD CONSTRAINT fk_fact_product FOREIGN KEY (Product_ID)
  REFERENCES dim_product (Product_ID)
  ON UPDATE CASCADE
  ON DELETE SET NULL;

-- Add FK from fact -> region
-- Region may contain NULLs; keep ON DELETE SET NULL behavior

ALTER TABLE fact_orders
  ADD CONSTRAINT fk_fact_region FOREIGN KEY (Region)
  REFERENCES dim_region (Region)
  ON UPDATE CASCADE
  ON DELETE SET NULL;

-- Add FK from fact -> calendar (OrderDate -> DateValue)
-- To enable, create an indexed date column on dim_calendar with same type

ALTER TABLE dim_calendar
  ADD INDEX idx_calendar_date (DateValue);

ALTER TABLE fact_orders
  ADD CONSTRAINT fk_fact_calendar FOREIGN KEY (OrderDate)
  REFERENCES dim_calendar (DateValue)
  ON UPDATE CASCADE
  ON DELETE SET NULL;

-- 6. Example views for Power BI (thin semantic layer)

DROP VIEW IF EXISTS vw_fact_orders_with_dims;
CREATE VIEW vw_fact_orders_with_dims AS
SELECT
  f.OrderLineID,
  f.Order_ID,
  f.Product_ID,
  p.ProductName,
  p.Category,
  p.SubCategory,
  f.OrderDate,
  f.Customer_ID,
  c.CustomerName,
  c.Segment,
  f.Region,
  f.Sales,
  f.Quantity,
  f.Profit
FROM fact_orders f
LEFT JOIN dim_product p ON f.Product_ID = p.Product_ID
LEFT JOIN dim_customer c ON f.Customer_ID = c.Customer_ID;

-- 7. Final sanity checks & messages
-- Count rows
SELECT
  (SELECT COUNT(*) FROM raw_orders) AS raw_rows,
  (SELECT COUNT(*) FROM clean_orders) AS clean_rows,
  (SELECT COUNT(*) FROM fact_orders) AS fact_rows;

SET FOREIGN_KEY_CHECKS = 1;


