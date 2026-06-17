
-- Bronzze Ejercicio 1

-- » 1. Escriu la consulta que uneix (JOIN) transaccions i companyies.

SELECT * FROM sprint3_bronze.transactions_raw as t
INNER JOIN sprint3_bronze.companies_raw as c ON c.company_id = t.business_id

-- > Código filtrando por Alemania y fecha

SELECT * FROM sprint3_silver.transactions_clean as t
INNER JOIN `sprint3_silver.companies_clean` as c ON c.company_id = t.business_id
WHERE date(timestamp) = '2022-03-12' and c.country = 'Germany'


-- Bronze Ejercicio 2
-- Pas 1:

CREATE OR REPLACE TABLE sprint3_silver.transactions_recent AS
SELECT
  * EXCEPT(timestamp),
  TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL CAST(RAND() * 50 AS INT64) DAY) AS timestamp
FROM sprint3_silver.transactions_clean;

-- Pas 2: Creació de la Taula Optimitzada (Partitioning & Clustering) :

CREATE OR REPLACE TABLE sprint3_gold.fact_transactions_optimized
PARTITION BY DATE(timestamp)
CLUSTER BY business_id
AS
  SELECT *  
FROM sprint3_silver.transactions_recent

-- Bronze Ejercicio 3 

-- Codigo Dry Run Gold

SELECT
  DATE(timestamp) AS dia,
  COUNT(*) AS total_transaccions
FROM sprint3_gold.fact_transactions_optimized
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY dia
ORDER BY dia DESC;

-- Codigo Dry Run Silver

SELECT
  DATE(timestamp) AS dia,
  COUNT(*) AS total_transaccions
FROM `sprint3_silver.transactions_recent`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY dia
ORDER BY dia DESC;


-- Bronze Ejercicio 4

CREATE OR REPLACE MATERIALIZED VIEW sprint3_gold.mv_daily_sales AS
  SELECT SUM(amount) AS total, DATE(timestamp) AS fecha
  FROM `sprint3_silver.transactions_recent`
  GROUP BY fecha;


  SELECT fecha, CONCAT(ROUND(total, 2), '€') AS total_rounded FROM sprint3_gold.mv_daily_sales


-- Silver Ejercicio 1

WITH VIP_Stats AS (
  SELECT
  user_id,
  SUM(amount) AS gasto_total,
  ROUND(AVG(amount), 2) as tiquet_promedio,
  MAX(amount) as max_compra,
  COUNT(*) as num_compras
FROM sprint3_gold.fact_transactions_optimized
GROUP BY user_id
ORDER BY gasto_total DESC
)


SELECT
  v.user_id AS id,
  u.name AS nombre,
  u.surname AS apellido,
  u.email AS correo,
  v.tiquet_promedio,
  v.max_compra,
  v.num_compras as numero_compras,
  round(v.gasto_total, 2) as total_gastado


FROM VIP_Stats as v
INNER JOIN sprint3_silver.users_combined as u
  ON v.user_id = u.user_id
WHERE gasto_total >= 500


-- Silver Ejercicio 2

SELECT
  fecha AS Data,
  total AS ventas_hoy,
  CONCAT(ROUND(LAG(total, 1, 0) OVER (ORDER BY fecha ASC), 2), '€') AS ventas_ayer,
  CONCAT(ROUND(
    ((total - LAG(total, 1, 0) OVER (ORDER BY fecha ASC))
    / NULLIF(LAG(total, 1, 0) OVER (ORDER BY fecha ASC), 0)) * 100,
    2
  ), '%') AS Diff_Percentual
FROM `sprint3_gold.mv_daily_sales`
ORDER BY fecha ASC;


-- Silver Ejercicio 3

SELECT
    fecha,
    CONCAT(ROUND(total, 2), "€") AS ventas_dia,   
    ROUND(
        SUM(total) OVER (
            PARTITION BY EXTRACT(YEAR FROM fecha)
            ORDER BY fecha ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 2
    ) AS ventas_ytd
FROM `sprint3_gold.mv_daily_sales`
ORDER BY fecha ASC;


-- Silver Ejercicio 4

WITH compras_ordenadas AS (
  SELECT
    user_id,
    timestamp,
    amount,
    ROW_NUMBER() OVER(
      PARTITION BY user_id
      ORDER BY timestamp ASC
    ) AS num_compra
  FROM `sprint3_gold.fact_transactions_optimized`
  QUALIFY num_compra <= 3
),


metricas_usuario AS (
  SELECT
    user_id,
    MAX(CASE WHEN num_compra = 3 THEN timestamp END) AS timestamp_3a_compra,
    MAX(CASE WHEN num_compra = 3 THEN amount END) AS amount_3a_compra,
    AVG(amount) AS ticket_medio_3_primeres,
    COUNT(1) AS total_compras_subset
  FROM compras_ordenadas
  GROUP BY user_id
  HAVING total_compras_subset = 3
)


SELECT
  u.user_id,
  u.name,
  u.email,
  m.timestamp_3a_compra,
  m.amount_3a_compra,
  ROUND(m.ticket_medio_3_primeres, 2) AS ticket_medio_3_primeres
FROM metricas_usuario m
JOIN `sprint3-analytics-alex.sprint3_silver.users_combined` u ON m.user_id = u.user_id
ORDER BY ticket_medio_3_primeres DESC;


-- Gold Ejercicio 1

WITH
  transacciones_desanidadas AS (
    SELECT
      t.transaction_id,
      t.timestamp,
      t.amount,
      single_product_id
    FROM `sprint3_gold.fact_transactions_optimized` t
    CROSS JOIN UNNEST(t.product_ids) AS single_product_id
  )


SELECT
  t.transaction_id,
  t.timestamp,
  t.amount AS total_ticket_global,
  p.name AS product_name,
  p.price AS product_price


FROM transacciones_desanidadas t


JOIN `sprint3-analytics-alex.sprint3_gold.product_sales_ranking` p
  ON t.single_product_id = p.product_id


ORDER BY total_ticket_global DESC, product_price DESC;

