-- Ejercicio 1

-- Algunos puntos se hacen con la consola de Google cloud y otros con el UI

-- Creación Dataset Físico mediante SQL (silver)

CREATE SCHEMA `sprint3-analytics-alex.sprint3_silver`
OPTIONS(
  location = 'EU'
);


-- Ejercicio 2: Crear Transactions_raw

-- Parte 1

CREATE OR REPLACE EXTERNAL TABLE `sprint3-analytics-alex.sprint3_bronze.transactions_raw` OPTIONS ( format = 'CSV', uris = ['gs://bootcamp-data-analytics-public/ERP/transactions.csv'], skip_leading_rows = 1, field_delimiter = ';' ); 

-- Parte 2

SELECT * FROM `sprint3-analytics-alex.sprint3_bronze.transactions_raw`
LIMIT 10;

-- Crear Companies_raw 

CREATE OR REPLACE EXTERNAL TABLE `sprint3-analytics-alex.sprint3_bronze.companies_raw` (
  company_id STRING,
  company_name STRING,
  phone STRING,
  email STRING,
  country STRING,
  website STRING
)
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/ERP/companies.csv'],
  skip_leading_rows = 1,
  field_delimiter = ','
);

-- Ver código

SELECT * FROM `sprint3-analytics-alex.sprint3_bronze.companies_raw`
LIMIT 10;

-- Crear American_users_raw

CREATE OR REPLACE EXTERNAL TABLE `sprint3-analytics-alex.sprint3_bronze.american_users_raw` OPTIONS ( format = 'CSV', uris = ['gs://bootcamp-data-analytics-public/CRM/american_users.csv'], skip_leading_rows = 1, field_delimiter = ',' ); 

--  Crear European_users_raw

CREATE OR REPLACE EXTERNAL TABLE `sprint3-analytics-alex.sprint3_bronze.european_users_raw` OPTIONS ( format = 'CSV', uris = ['gs://bootcamp-data-analytics-public/CRM/european_users.csv'], skip_leading_rows = 1, field_delimiter = ',' ); 

-- Crear Credit_Card_raw

CREATE OR REPLACE EXTERNAL TABLE `sprint3-analytics-alex.sprint3_bronze.credit_cards_raw`
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/credit_cards.csv'],
  skip_leading_rows = 1,
  field_delimiter = ','
);

-- Ejercicio 3 

-- Casi todo se hace en UI, salvo el select

SELECT * FROM `sprint3-analytics-alex.sprint3_bronze.products_raw` LIMIT 1000

-- Ejercicio 4

CREATE TABLE sprint3_bronze.transactions_raw_native AS
SELECT * FROM sprint3_bronze.transactions_raw;

-- Comprobar que la tabla está hecha

SELECT * FROM sprint3_bronze.transactions_raw_native;

-- Comprobar Bytes procesados/Facturados en raw

SELECT * FROM sprint3_bronze.transactions_raw; 

-- Comprobar bytes procesados/facturados en raw native

SELECT id FROM sprint3_bronze.transactions_raw_native;

 -- Select con LIMIT 10
 
 SELECT * FROM transactions_raw_native LIMIT 10
 
 -- Ejercicio 5
 
 SELECT
  EXTRACT(DATE FROM timestamp) AS fecha,
  CONCAT(ROUND(SUM(amount), 2), '€') AS ingresos_totales
FROM
  sprint3_bronze.transactions_raw_native
WHERE
  EXTRACT(YEAR FROM timestamp) = 2021
GROUP BY
  fecha
ORDER BY
  ingresos_totales DESC
LIMIT 5;

-- Ejercicio 6

SELECT
  c.company_name AS nom_empresa,
  c.country AS pais,
  EXTRACT(DATE FROM t.timestamp) AS data_transaccio
FROM
  sprint3_bronze.transactions_raw_native AS t
JOIN
  sprint3_bronze.companies_raw AS c
  ON t.business_id = c.company_id
WHERE
  t.amount BETWEEN 100 AND 200
  AND EXTRACT(DATE FROM t.timestamp) IN ('2015-04-29', '2018-07-20', '2024-03-13')
ORDER BY
  data_transaccio ASC;

-- Nivel 2 ejercicio 1

CREATE OR REPLACE TABLE sprint3_silver.products_clean AS
SELECT
  id AS product_id,                                  
  product_name AS name,
  price,
  colour,
  weight,
  CAST(SUBSTR(warehouse_id, 4, 2) AS INT64) AS warehouse_id,
  category,
  brand,
  cost,
  launch_date
FROM
  sprint3_bronze.products_raw

-- Resultado

Select * FROM `sprint3_silver.products_clean`

-- Nivel 2 ejercicio 2

CREATE OR REPLACE TABLE sprint3_silver.transactions_clean AS
SELECT
  id AS transaction_id,      
  card_id,
  business_id,
  SAFE_CAST(timestamp AS timestamp) AS timestamp,
  IFNULL(SAFE_CAST(amount AS FLOAT64), 0.0) AS amount,
  declined,
  ARRAY(
    SELECT SAFE_CAST(id_element AS INT64)
    FROM UNNEST(SPLIT(product_ids, ',')) AS id_element
  ) AS product_ids,  
  user_id,
  SAFE_CAST(lat as FLOAT64) AS latitude,
  SAFE_CAST(longitude as FLOAT64) AS longitude
FROM
  sprint3_bronze.transactions_raw;

-- Resultados

Select * from sprint3_silver.transactions_clean;

-- Nivel 2 ejercicio 3

CREATE OR REPLACE TABLE sprint3_silver.users_combined AS


SELECT
  id as user_id,
  name,
  surname,
  phone,
  email,
  birth_date,
  country,
  city,
  postal_code,
  address
  FROM sprint3_bronze.european_users_raw

  UNION ALL

  SELECT
  id as user_id,
  name,
  surname,
  phone,
  email,
  birth_date,
  country,
  city,
  postal_code,
  address
  FROM sprint3_bronze.american_users_raw;

-- Nivel 2 ejercicio 4

-- Se hace con UI

-- Nivel 3 ejercicio 1

CREATE OR REPLACE VIEW `sprint3_gold.v_marketing_kpis` AS
SELECT
    c.company_name,
    c.phone,
    c.country,
    round(AVG(t.amount), 2) AS cantidad,
    CASE
    WHEN AVG(t.amount) > 260 then 'Premium'
      ELSE 'Standard'
    END AS client_tier


FROM `sprint3_silver.companies_clean` as c
INNER JOIN `sprint3_silver.transactions_clean` as t ON t.business_id = c.company_id
GROUP BY c.company_name, c.phone, c.country

-- Resultado

SELECT * FROM sprint3_gold.v_marketing_kpis;

-- Nivel 3 ejercicio 2

CREATE OR REPLACE TABLE `sprint3_gold.product_sales_ranking` AS


SELECT p.product_id, count(t.transaction_id) AS total_solds, p.name, p.price, p.colour


FROM sprint3_silver.transactions_clean AS t,


UNNEST(t.product_ids) AS IDs_separadas
LEFT JOIN `sprint3_silver.products_clean` AS p ON IDs_separadas = p.product_id


GROUP BY p.product_id, p.name, p.colour, p.price
ORDER BY p.price DESC;
Select * from `sprint3_gold.product_sales_ranking`

-- Nivel 3 ejercicio 3

-- Todo en UI


