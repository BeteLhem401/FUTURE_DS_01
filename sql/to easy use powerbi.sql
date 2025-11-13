-- ======================================================
-- STEP 2: POWER BI INTEGRATION PREPARATION
-- Goal: Add unique keys and relational structure
-- Author: Betelhem Hailu
-- Date: CURRENT_DATE
-- ======================================================

USE superstore_db;

-- ======================================================
-- 1️⃣ FACT TABLE: SUPERSTORE_FINAL
-- ======================================================
-- Add a unique Fact_ID key (only if not already exists)
ALTER TABLE superstore_final
ADD COLUMN IF NOT EXISTS Fact_ID VARCHAR(50);

-- Combine Order_ID and Product_ID to make a unique key
UPDATE superstore_final
SET Fact_ID = CONCAT(Order_ID, '_', Product_ID);

-- Set Fact_ID as the primary key (Power BI uses this to identify rows)
ALTER TABLE superstore_final
ADD PRIMARY KEY (Fact_ID);

-- ======================================================
-- 2️⃣ CUSTOMER DIMENSION
-- ======================================================
-- Add Primary Key for Customer table (Customer_ID is already unique)
ALTER TABLE insight_customer_value
ADD PRIMARY KEY (Customer_ID);

-- Create a Foreign Key relationship with Fact Table
ALTER TABLE superstore_final
ADD CONSTRAINT fk_fact_customer
FOREIGN KEY (Customer_ID)
REFERENCES insight_customer_value (Customer_ID);

-- ======================================================
-- 3️⃣ PRODUCT DIMENSION
-- ======================================================
-- Add Primary Key for Product table
ALTER TABLE insight_product_performance
ADD PRIMARY KEY (Product_ID);

-- Create Foreign Key in fact table to connect Product_ID
ALTER TABLE superstore_final
ADD CONSTRAINT fk_fact_product
FOREIGN KEY (Product_ID)
REFERENCES insight_product_performance (Product_ID);

-- ======================================================
-- 4️⃣ REGION DIMENSION
-- ============================
-- Check if Fact_ID already exists
SHOW COLUMNS FROM superstore_final LIKE 'Fact_ID';
ALTER TABLE superstore_final ADD COLUMN Fact_ID VARCHAR(50);
UPDATE superstore_final
SET Fact_ID = CONCAT(Order_ID, '_', Product_ID);
ALTER TABLE superstore_final
ADD PRIMARY KEY (Fact_ID);
SELECT Product_ID, COUNT(*) AS duplicate_count
FROM insight_product_performance
GROUP BY Product_ID
HAVING COUNT(*) > 1;

DELETE FROM insight_product_performance
WHERE Product_ID = 'TEC-AC-10002049'
LIMIT 1;

ALTER TABLE insight_product_performance
ADD INDEX (Product_ID);

ALTER TABLE superstore_final
ADD CONSTRAINT fk_fact_product
FOREIGN KEY (Product_ID)
REFERENCES insight_product_performance (Product_ID);
SELECT DISTINCT Product_ID
FROM superstore_final
WHERE Product_ID NOT IN (
    SELECT Product_ID FROM insight_product_performance
);

DELETE FROM superstore_final
WHERE Product_ID NOT IN (
    SELECT Product_ID FROM insight_product_performance
);
INSERT INTO insight_product_performance (Product_ID, Product_Name)
SELECT DISTINCT Product_ID, 'Unknown Product'
FROM superstore_final
WHERE Product_ID NOT IN (
    SELECT Product_ID FROM insight_product_performance
);

SELECT Product_ID, COUNT(*) AS duplicate_count
FROM insight_product_performance
GROUP BY Product_ID
HAVING COUNT(*) > 1;
-- Create a temporary table with distinct Product_IDs
CREATE TEMPORARY TABLE temp_unique_products AS
SELECT * 
FROM insight_product_performance
GROUP BY Product_ID;  -- MySQL will keep the first row it encounters

-- Remove all rows from the original table
TRUNCATE TABLE insight_product_performance;

-- Insert back the distinct rows
INSERT INTO insight_product_performance
SELECT * FROM temp_unique_products;

-- Drop temporary table
DROP TEMPORARY TABLE temp_unique_products;
CREATE TABLE backup_insight_product_performance AS
SELECT * FROM insight_product_performance;
-- Check if column exists
SHOW COLUMNS FROM superstore_final LIKE 'Fact_ID';

-- Only run this if it returns 0 rows
ALTER TABLE superstore_final ADD COLUMN Fact_ID VARCHAR(50);

UPDATE superstore_final
SET Fact_ID = CONCAT(Order_ID, '_', Product_ID);
ALTER TABLE superstore_final
ADD PRIMARY KEY (Fact_ID);
SHOW COLUMNS FROM superstore_final LIKE 'Fact_ID';


SHOW COLUMNS FROM superstore_final LIKE 'Fact_ID';
UPDATE superstore_final
SET Fact_ID = CONCAT(Order_ID, '_', Product_ID);
SHOW INDEX FROM superstore_final WHERE Key_name = 'PRIMARY';


SELECT Product_ID, COUNT(*) AS cnt
FROM insight_product_performance
GROUP BY Product_ID
HAVING cnt > 1;


SELECT DISTINCT Product_ID
FROM superstore_final
WHERE Product_ID NOT IN (
    SELECT Product_ID FROM insight_product_performance
);
-- Make a temporary table that keeps one row per Product_ID
CREATE TEMPORARY TABLE temp_unique_products AS
SELECT Product_ID, MAX(Product_Name) AS Product_Name
FROM insight_product_performance
GROUP BY Product_ID;

-- Remove all rows in the original product table
TRUNCATE TABLE insight_product_performance;

-- Put back only the unique rows
INSERT INTO insight_product_performance
SELECT * FROM temp_unique_products;

-- Drop the temporary table
DROP TEMPORARY TABLE temp_unique_products;
DROP TEMPORARY TABLE temp_unique_products;

-- 1. Create temporary table
CREATE TEMPORARY TABLE temp_unique_products AS
SELECT Product_ID, MAX(Product_Name) AS Product_Name
FROM insight_product_performance
GROUP BY Product_ID;

-- 2. Remove all rows from original table
TRUNCATE TABLE insight_product_performance;

-- 3. Insert back unique rows
INSERT INTO insight_product_performance
SELECT * FROM temp_unique_products;

-- 4. Drop the temporary table
DROP TEMPORARY TABLE temp_unique_products;

SHOW TABLES LIKE 'temp_%';



-- 1. Create temporary table
CREATE TEMPORARY TABLE temp_unique_products AS
SELECT Product_ID, MAX(Product_Name) AS Product_Name
FROM insight_product_performance
GROUP BY Product_ID;

-- 2. Remove all rows from the original table
TRUNCATE TABLE insight_product_performance;

-- 3. Insert only unique rows back
INSERT INTO insight_product_performance
SELECT * FROM temp_unique_products;

-- 4. Drop the temporary table (only once, immediately after use)
DROP TEMPORARY TABLE temp_unique_products;
INSERT INTO insight_product_performance (Product_ID, Product_Name)
SELECT Product_ID, Product_Name
FROM temp_unique_products;


-- 1. Create temporary table with only the columns you want
CREATE TEMPORARY TABLE temp_unique_products AS
SELECT Product_ID, MAX(Product_Name) AS Product_Name
FROM insight_product_performance
GROUP BY Product_ID;

-- 2. Remove all rows from the original table
TRUNCATE TABLE insight_product_performance;

-- 3. Insert back the unique rows
INSERT INTO insight_product_performance (Product_ID, Product_Name)
SELECT Product_ID, Product_Name
FROM temp_unique_products;

-- 4. Drop the temporary table
DROP TEMPORARY TABLE temp_unique_products;

SELECT DISTINCT Product_ID
FROM superstore_final
WHERE Product_ID NOT IN (
    SELECT Product_ID FROM insight_product_performance
);

-- See how many rows exist
SELECT COUNT(*) AS total_products FROM insight_product_performance;

-- Check for duplicates
SELECT Product_ID, COUNT(*) AS cnt
FROM insight_product_performance
GROUP BY Product_ID
HAVING cnt > 1;

-- View sample rows
SELECT * FROM insight_product_performance LIMIT 10;


SELECT DISTINCT Product_ID
FROM superstore_final
WHERE Product_ID NOT IN (
    SELECT Product_ID FROM insight_product_performance
);

-- Total rows in product table
SELECT COUNT(*) AS total_products FROM insight_product_performance;

-- Check duplicates
SELECT Product_ID, COUNT(*) AS cnt
FROM insight_product_performance
GROUP BY Product_ID
HAVING cnt > 1;

SELECT Product_ID, COUNT(*) AS cnt
FROM insight_product_performance
GROUP BY Product_ID
HAVING cnt > 1;
-- Insert distinct Product_IDs from the fact table
INSERT INTO insight_product_performance (Product_ID, Product_Name)
SELECT DISTINCT Product_ID, 'Unknown Product'
FROM superstore_final;

-- Insert distinct Product_IDs from the fact table
INSERT INTO insight_product_performance (Product_ID, Product_Name)
SELECT DISTINCT Product_ID, 'Unknown Product'
FROM superstore_final;


SELECT COUNT(*) AS total_products FROM insight_product_performance; 
SELECT Product_ID, COUNT(*) AS cnt
FROM insight_product_performance
GROUP BY Product_ID
HAVING cnt > 1;


SELECT DISTINCT Product_ID
FROM superstore_final
WHERE Product_ID NOT IN (
    SELECT Product_ID FROM insight_product_performance
);

-- Insert missing products
INSERT INTO insight_product_performance (Product_ID, Product_Name)
SELECT DISTINCT Product_ID, 'Unknown Product'
FROM superstore_final
WHERE Product_ID NOT IN (
    SELECT Product_ID FROM insight_product_performance
);
UPDATE superstore_final
SET Fact_ID = CONCAT(Order_ID, '_', Product_ID);

ALTER TABLE superstore_final
ADD PRIMARY KEY (Fact_ID);

ALTER TABLE superstore_final
DROP PRIMARY KEY,
ADD PRIMARY KEY (Fact_ID);
SHOW INDEX FROM superstore_final WHERE Key_name = 'PRIMARY';

-- Check duplicates in your product dimension
SELECT Product_ID, COUNT(*) AS count_duplicates
FROM insight_product_performance
GROUP BY Product_ID
HAVING COUNT(*) > 1;

-- Remove duplicate Product_IDs safely
CREATE TEMPORARY TABLE temp_unique_products AS
SELECT 
    Product_ID,
    MAX(Product_Name) AS Product_Name,
    MAX(Category) AS Category,
    MAX(Sub_Category) AS Sub_Category
FROM insight_product_performance
GROUP BY Product_ID;

TRUNCATE TABLE insight_product_performance;

INSERT INTO insight_product_performance (Product_ID, Product_Name, Category, Sub_Category)
SELECT Product_ID, Product_Name, Category, Sub_Category
FROM temp_unique_products;

DROP TEMPORARY TABLE temp_unique_products;

