/*
===============================================================================
Shipment Date Analysis
===============================================================================
Purpose:
    - Identify the earliest and latest dates across all key shipment
      date columns to understand the full time span of the data.
    - Measure the gap between promised and actual delivery dates to
      establish a baseline for delay analysis.
    - Flag impossible or suspicious date combinations that indicate
      dirty data before the cleaning script runs.
SQL Functions Used:
    - MIN(), MAX(), DATEDIFF()
    - COUNT(), AVG()
    - CASE for anomaly detection
===============================================================================
*/

-- Determine the first and last shipment order date and the total span in months
SELECT
    MIN(order_date)  AS first_order_date,
    MAX(order_date)  AS last_order_date,
    DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS data_range_months
FROM sc.fact_shipments
WHERE order_date IS NOT NULL;

-- Determine the first and last actual delivery date recorded
SELECT
    MIN(actual_date)  AS first_delivery_date,
    MAX(actual_date)  AS last_delivery_date,
    DATEDIFF(MONTH, MIN(actual_date), MAX(actual_date))  AS delivery_range_months
FROM sc.fact_shipments
WHERE actual_date IS NOT NULL;

-- Find the shortest and longest promised delivery windows across all shipments
-- This tells us how aggressive or conservative the delivery promises are
SELECT
    MIN(DATEDIFF(DAY, order_date, promised_date))   AS shortest_promised_window_days,
    MAX(DATEDIFF(DAY, order_date, promised_date))   AS longest_promised_window_days,
    AVG(DATEDIFF(DAY, order_date, promised_date))   AS avg_promised_window_days
FROM sc.fact_shipments
WHERE order_date    IS NOT NULL
  AND promised_date IS NOT NULL;

-- Find the shortest and longest actual transit times across all delivered shipments
-- Compare against the promised window to understand how often the network overruns
SELECT
    MIN(DATEDIFF(DAY, order_date, actual_date))     AS shortest_actual_transit_days,
    MAX(DATEDIFF(DAY, order_date, actual_date))     AS longest_actual_transit_days,
    AVG(DATEDIFF(DAY, order_date, actual_date))     AS avg_actual_transit_days
FROM sc.fact_shipments
WHERE order_date    IS NOT NULL
  AND actual_date   IS NOT NULL;

-- Find the earliest and latest supplier onboarding dates
-- to understand how long the supplier network has been active
SELECT
    MIN(onboarded_date)   AS first_supplier_onboarded,
    MAX(onboarded_date)   AS last_supplier_onboarded,
    DATEDIFF(YEAR, MIN(onboarded_date), MAX(onboarded_date))   AS supplier_network_span_years
FROM sc.ref_suppliers
WHERE onboarded_date IS NOT NULL;

-- Break down shipment volume by year to see how data is distributed over time
-- Uneven distribution across years may affect trend analysis
SELECT
    YEAR(order_date)   AS shipment_year,
    COUNT(shipment_key)   AS total_shipments
FROM sc.fact_shipments
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY YEAR(order_date);

-- Flag records where actual_date is before order_date
-- These are impossible dates and must be excluded from all analysis
SELECT
    COUNT(*) AS impossible_date_records
FROM sc.fact_shipments
WHERE actual_date < order_date;

-- Flag records where promised_date is before order_date
-- A promise cannot be made before the order was placed
SELECT
    COUNT(*) AS promised_before_ordered
FROM sc.fact_shipments
WHERE promised_date < order_date;

-- Count how many shipments are missing an actual delivery date entirely
-- These cannot be included in any delay or transit time calculations
SELECT
    COUNT(*) AS shipments_missing_actual_date
FROM sc.fact_shipments
WHERE actual_date IS NULL;
