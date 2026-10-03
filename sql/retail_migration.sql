USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS RETAIL_WH
WAREHOUSE_SIZE = 'XSMALL'
AUTO_SUSPEND = 60
AUTO_RESUME = TRUE;

CREATE OR REPLACE DATABASE RETAIL_MIGRATION;
CREATE SCHEMA IF NOT EXISTS RETAIL_MIGRATION.RAW;
CREATE SCHEMA IF NOT EXISTS RETAIL_MIGRATION.ANALYTICS;
CREATE SCHEMA IF NOT EXISTS RETAIL_MIGRATION.QUALITY;

USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_MIGRATION;

CREATE OR REPLACE TABLE RAW.SALES_RAW (
INVOICE VARCHAR,
STOCKCODE VARCHAR,
DESCRIPTION VARCHAR,
QUANTITY VARCHAR,
INVOICE_DATE VARCHAR,
PRICE VARCHAR,
CUSTOMER_ID VARCHAR,
COUNTRY VARCHAR
);

SHOW SCHEMAS IN DATABASE RETAIL_MIGRATION;

SELECT COUNT(*) FROM RAW.SALES_RAW;
SELECT * FROM RAW.SALES_RAW LIMIT 5;

SELECT COUNT_IF(TRY_TO_TIMESTAMP(INVOICE_DATE,'MM/DD/YY HH24:MI') IS NULL) AS bad_dates
FROM RAW.SALES_RAW;

SELECT COUNT_IF(NULLIF(TRIM(CUSTOMER_ID),'') IS NULL) AS no_clients, COUNT(*) AS Total
FROM RAW.SALES_RAW;

SELECT COUNT_IF(INVOICE LIKE 'C%') AS cancelled_orders
FROM RAW.SALES_RAW;

SELECT COUNT_IF(TRY_TO_NUMBER(QUANTITY)<0) AS negative_quantities
FROM RAW.SALES_RAW;

SELECT COUNT_IF(TRY_TO_DECIMAL(PRICE,12,2)<=0) AS zero_negative_prices
FROM RAW.SALES_RAW;

SELECT COUNT_IF(NOT REGEXP_LIKE(STOCKCODE,'[0-9]{5}.*')) AS error_codes
FROM RAW.SALES_RAW;

SELECT COUNT_IF(NULLIF(TRIM(DESCRIPTION),'') IS NULL) AS error_descriptions
FROM RAW.SALES_RAW;

SELECT COUNT(*) - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM RAW.SALES_RAW)) AS doublons, COUNT(*) AS total
FROM RAW.SALES_RAW;

SELECT *
FROM RAW.SALES_RAW
WHERE TRY_TO_NUMBER(QUANTITY) < 0
  AND INVOICE NOT LIKE 'C%'
LIMIT 20;

CREATE OR REPLACE TABLE QUALITY.ANOMALIES AS
SELECT 'Missing customer ID' AS rule_name,COUNT_IF(NULLIF(TRIM(CUSTOMER_ID),'')IS NULL) AS rows_affected,COUNT(*) AS total_rows
FROM RAW.SALES_RAW
UNION ALL
SELECT 'Cancelled invoices', COUNT_IF(INVOICE LIKE 'C%'), COUNT(*)
FROM RAW.SALES_RAW
UNION ALL
SELECT 'Negative quantities', COUNT_IF(TRY_TO_NUMBER(QUANTITY)<0), COUNT(*)
FROM RAW.SALES_RAW
UNION ALL
SELECT 'Zero or negative prices',COUNT_IF(TRY_TO_DECIMAL(PRICE,12,2)<=0), COUNT(*)
FROM RAW.SALES_RAW
UNION ALL
SELECT 'Non-product code', COUNT_IF(NOT REGEXP_LIKE(STOCKCODE,'[0-9]{5}.*')), COUNT(*)
FROM RAW.SALES_RAW
UNION ALL
SELECT 'Missing description', COUNT_IF(NULLIF(TRIM(DESCRIPTION),'') IS NULL), COUNT(*)
FROM RAW.SALES_RAW
UNION ALL
SELECT 'Exact Duplicates', COUNT(*) - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM RAW.SALES_RAW)), COUNT(*)
FROM RAW.SALES_RAW;


SELECT *, ROUND(100 * rows_affected / total_rows, 2) AS pct_affected
FROM QUALITY.ANOMALIES
ORDER BY rows_affected DESC;

SELECT Count(*) FROM (SELECT DISTINCT * FROM RAW.SALES_RAW);
SELECT
  COUNT(*) AS apres_doublons,
  COUNT_IF(INVOICE NOT LIKE 'C%') AS apres_regle_2,
  COUNT_IF(INVOICE NOT LIKE 'C%'
       AND TRY_TO_NUMBER(QUANTITY) > 0) AS apres_regle_3,
  COUNT_IF(INVOICE NOT LIKE 'C%'
       AND TRY_TO_NUMBER(QUANTITY) > 0
       AND TRY_TO_DECIMAL(PRICE, 12, 2) > 0) AS apres_regle_4,
  COUNT_IF(INVOICE NOT LIKE 'C%'
       AND TRY_TO_NUMBER(QUANTITY) > 0
       AND TRY_TO_DECIMAL(PRICE, 12, 2) > 0
       AND REGEXP_LIKE(STOCKCODE, '[0-9]{5}.*')) AS apres_regle_5,
  COUNT_IF(INVOICE NOT LIKE 'C%'
       AND TRY_TO_NUMBER(QUANTITY) > 0
       AND TRY_TO_DECIMAL(PRICE, 12, 2) > 0
       AND REGEXP_LIKE(STOCKCODE, '[0-9]{5}.*')
       AND NULLIF(TRIM(CUSTOMER_ID), '') IS NOT NULL) AS apres_regle_6
FROM (SELECT DISTINCT * FROM RAW.SALES_RAW);


SELECT COUNT_IF(TRY_TO_DECIMAL(PRICE, 12, 2) IS NULL) AS prix_illisibles
FROM RAW.SALES_RAW;
 
SELECT PRICE, COUNT(*) AS nb
FROM RAW.SALES_RAW
WHERE TRY_TO_DECIMAL(PRICE, 12, 2) IS NULL
GROUP BY PRICE
ORDER BY nb DESC
LIMIT 20;

SELECT COUNT_IF(CUSTOMER_ID LIKE '%,%') AS clients_avec_virgule
FROM RAW.SALES_RAW;

CREATE OR REPLACE TABLE ANALYTICS.FACT_SALES AS
SELECT
  INVOICE                                           AS invoice_id,
  UPPER(TRIM(STOCKCODE))                           AS product_id,
  TRY_TO_DECIMAL(CUSTOMER_ID, 12, 1)::INT           AS customer_id,
  TRY_TO_NUMBER(QUANTITY)                           AS quantity,
  TRY_TO_DECIMAL(REPLACE(PRICE,',','.'), 12, 2)     AS unit_price,
  TRY_TO_NUMBER(QUANTITY) * TRY_TO_DECIMAL(REPLACE(PRICE,',','.'), 12, 2) AS revenue,
  TRY_TO_TIMESTAMP(INVOICE_DATE, 'MM/DD/YY HH24:MI') AS invoice_ts,
  TRY_TO_TIMESTAMP(INVOICE_DATE, 'MM/DD/YY HH24:MI')::DATE AS invoice_date,
  COUNTRY                                           AS country
FROM (SELECT DISTINCT * FROM RAW.SALES_RAW)                 
WHERE INVOICE NOT LIKE 'C%'                                 
  AND TRY_TO_NUMBER(QUANTITY) > 0                           
  AND TRY_TO_DECIMAL(REPLACE(PRICE,',','.'), 12, 2) > 0            
  AND REGEXP_LIKE(STOCKCODE, '[0-9]{5}.*')                 
  AND NULLIF(TRIM(CUSTOMER_ID),'') IS NOT NULL;          

SELECT COUNT(*) FROM ANALYTICS.FACT_SALES;

SELECT
  COUNT_IF(quantity <= 0)        AS qty_problems,
  COUNT_IF(unit_price <= 0)      AS price_problems,
  COUNT_IF(customer_id IS NULL)  AS customer_problems,
  COUNT_IF(invoice_date IS NULL) AS date_problems
FROM ANALYTICS.FACT_SALES;

SELECT COUNT_IF(unit_price IS NULL) AS prix_vides,
       COUNT_IF(revenue IS NULL) AS ca_vide
FROM ANALYTICS.FACT_SALES;

SELECT DATE_TRUNC('month',TRY_TO_TIMESTAMP(INVOICE_DATE,'MM/DD/YY HH24:MI'))::DATE AS month, COUNT(*) AS src_rows, SUM(TRY_TO_NUMBER(QUANTITY) * TRY_TO_DECIMAL(REPLACE(PRICE,',','.'),12,2)) AS src_revenue
FROM RAW.SALES_RAW
GROUP BY 1
ORDER BY 1;

SELECT DATE_TRUNC('month',invoice_date) AS month, COUNT(*) AS tgt_rows, SUM(revenue) AS tgt_revenue
FROM ANALYTICS.FACT_SALES
GROUP BY 1
ORDER BY 1;

CREATE OR REPLACE TABLE QUALITY.GAP_BY_MONTH AS 
WITH src AS (
SELECT DATE_TRUNC('month',TRY_TO_TIMESTAMP(INVOICE_DATE,'MM/DD/YY HH24:MI'))::DATE AS month, COUNT(*) AS src_rows, SUM(TRY_TO_NUMBER(QUANTITY) * TRY_TO_DECIMAL(REPLACE(PRICE,',','.'),12,2)) AS src_revenue
FROM RAW.SALES_RAW
GROUP BY 1
ORDER BY 1
), tgt AS (
SELECT DATE_TRUNC('month',invoice_date) AS month, COUNT(*) AS tgt_rows, SUM(revenue) AS tgt_revenue
FROM ANALYTICS.FACT_SALES
GROUP BY 1
ORDER BY 1
)
SELECT src.month, src_rows, COALESCE(tgt_rows,0) AS tgt_rows, src_rows - COALESCE(tgt_rows,0) AS row_gap,src_revenue,COALESCE(tgt_revenue,0) AS tgt_revenue, src_revenue - COALESCE(tgt_revenue,0) AS revenue_gap
FROM src
LEFT JOIN tgt ON src.month = tgt.month;

SELECT * FROM QUALITY.GAP_BY_MONTH ORDER BY month;


SELECT month, row_gap, revenue_gap,
       ROUND(100 * row_gap / src_rows, 2) AS row_gap_pct
FROM QUALITY.GAP_BY_MONTH
ORDER BY row_gap_pct DESC
LIMIT 5;
  
SELECT DATE_TRUNC('month', TRY_TO_TIMESTAMP(INVOICE_DATE, 'MM/DD/YY HH24:MI'))::DATE AS month,
       SUM(nb - 1) AS doublons
FROM (
  SELECT INVOICE, STOCKCODE, DESCRIPTION, QUANTITY, INVOICE_DATE, PRICE, CUSTOMER_ID, COUNTRY, COUNT(*) AS nb
  FROM RAW.SALES_RAW
  GROUP BY ALL
  HAVING COUNT(*) > 1
)
GROUP BY 1
ORDER BY doublons DESC;

SELECT INVOICE, INVOICE_DATE, CUSTOMER_ID, DESCRIPTION, QUANTITY, PRICE
FROM RAW.SALES_RAW
WHERE INVOICE LIKE 'C%'
  AND TRY_TO_NUMBER(QUANTITY) < -1000
ORDER BY TRY_TO_NUMBER(QUANTITY);

WITH annulations AS (
  SELECT INVOICE AS cancel_invoice,
         CUSTOMER_ID,
         STOCKCODE,
         -TRY_TO_NUMBER(QUANTITY) AS qty,
         TRY_TO_DECIMAL(REPLACE(PRICE, ',', '.'), 12, 2) AS price,      -- AJOUTÉ
         TRY_TO_TIMESTAMP(INVOICE_DATE, 'MM/DD/YY HH24:MI') AS cancel_ts
  FROM RAW.SALES_RAW
  WHERE INVOICE LIKE 'C%'
),
commandes AS (
  SELECT INVOICE AS order_invoice,
         CUSTOMER_ID,
         STOCKCODE,
         TRY_TO_NUMBER(QUANTITY) AS qty,
         TRY_TO_DECIMAL(REPLACE(PRICE, ',', '.'), 12, 2) AS price,
         TRY_TO_TIMESTAMP(INVOICE_DATE, 'MM/DD/YY HH24:MI') AS order_ts
  FROM RAW.SALES_RAW
  WHERE INVOICE NOT LIKE 'C%'
),
paires AS (  
  SELECT a.cancel_invoice,a.stockcode AS stockcode, c.order_invoice,
         a.price AS cancel_price, c.price AS order_price,
         c.qty * c.price AS order_revenue
  FROM annulations a
  JOIN commandes c
    ON  a.CUSTOMER_ID = c.CUSTOMER_ID
    AND a.STOCKCODE   = c.STOCKCODE
    AND a.qty         = c.qty
    AND c.order_ts   <= a.cancel_ts
        AND a.price = c.price
  QUALIFY ROW_NUMBER() OVER (
            PARTITION BY a.cancel_invoice, a.STOCKCODE
            ORDER BY c.order_ts DESC
          ) = 1
)
SELECT COUNT(*) AS nb_paires,
       SUM(order_revenue) AS ca_gonfle
FROM paires;
SELECT SUM(revenue) AS ca_cible FROM ANALYTICS.FACT_SALES;

SELECT * FROM paires WHERE cancel_price <> order_price;

SELECT COUNT(*) AS nb_paires,
       SUM(order_revenue) AS ca_gonfle
FROM paires;

CREATE OR REPLACE TABLE QUALITY.EXCLUSIONS AS
WITH source_sans_doublons AS (
  SELECT DISTINCT * FROM RAW.SALES_RAW
),
lignes AS (
  SELECT
    TRY_TO_NUMBER(QUANTITY) * TRY_TO_DECIMAL(REPLACE(PRICE, ',', '.'), 12, 2) AS revenue,
    CASE
      WHEN INVOICE LIKE 'C%'                                         THEN 'Cancelled invoice'
      WHEN TRY_TO_NUMBER(QUANTITY) <= 0                              THEN 'Non-positive quantity'
      WHEN TRY_TO_DECIMAL(REPLACE(PRICE, ',', '.'), 12, 2) <= 0      THEN 'Non-positive price'
      WHEN NOT REGEXP_LIKE(STOCKCODE, '[0-9]{5}.*')                  THEN 'Non-product code'
      WHEN NULLIF(TRIM(CUSTOMER_ID), '') IS NULL                     THEN 'Missing customer ID'
      ELSE 'Kept in target'
    END AS reason
  FROM source_sans_doublons
)
 
SELECT 'Exact duplicates' AS reason,
       (SELECT COUNT(*) FROM RAW.SALES_RAW)
         - (SELECT COUNT(*) FROM source_sans_doublons)                    AS rows_excluded,
       (SELECT SUM(TRY_TO_NUMBER(QUANTITY) * TRY_TO_DECIMAL(REPLACE(PRICE, ',', '.'), 12, 2))
          FROM RAW.SALES_RAW)
         - (SELECT SUM(revenue) FROM lignes)                              AS revenue_excluded
UNION ALL

SELECT reason, COUNT(*), SUM(revenue)
FROM lignes
WHERE reason <> 'Kept in target'
GROUP BY reason;

SELECT * FROM QUALITY.EXCLUSIONS ORDER BY rows_excluded DESC;

SELECT
  (SELECT COUNT(*) FROM RAW.SALES_RAW)                  AS source_rows,
  (SELECT COUNT(*) FROM ANALYTICS.FACT_SALES)           AS target_rows,
  (SELECT SUM(rows_excluded) FROM QUALITY.EXCLUSIONS)   AS excluded_rows,
  source_rows - target_rows - excluded_rows             AS unexplained_rows,

  (SELECT SUM(src_revenue) FROM QUALITY.GAP_BY_MONTH)   AS source_revenue,
  (SELECT SUM(revenue) FROM ANALYTICS.FACT_SALES)       AS target_revenue,
  (SELECT SUM(revenue_excluded) FROM QUALITY.EXCLUSIONS) AS excluded_revenue,
  source_revenue - target_revenue - excluded_revenue    AS unexplained_revenue;

  SELECT * FROM QUALITY.EXCLUSIONS ORDER BY rows_excluded DESC;

  SELECT INVOICE, STOCKCODE, DESCRIPTION, QUANTITY, PRICE
FROM RAW.SALES_RAW
WHERE TRY_TO_DECIMAL(REPLACE(PRICE, ',', '.'), 12, 2) < 0;

CREATE OR REPLACE TABLE QUALITY.WATERFALL AS
SELECT 0 AS step, 'Source revenue' AS label, SUM(src_revenue) AS amount
FROM QUALITY.GAP_BY_MONTH
UNION ALL
SELECT ROW_NUMBER() OVER (ORDER BY revenue_excluded DESC),
       reason,
       -revenue_excluded
FROM QUALITY.EXCLUSIONS;

SELECT * FROM QUALITY.WATERFALL ORDER BY step;