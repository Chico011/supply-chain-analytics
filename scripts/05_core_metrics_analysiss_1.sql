/*
===============================================================================
Core Metrics Analysis
===============================================================================
Objective:
    - Compute key summary values to understand the overall health and scale
      of the supply chain network.
    - Establish the headline KPIs that will drive the executive dashboard
      in Power BI.
    - All metrics exclude Data Error records flagged during cleaning.
Functions Applied:
    - COUNT(), SUM(), AVG(), ROUND()
    - NULLIF() for safe division
    - ISNULL() for dirty data handling
===============================================================================
*/

-- Find the total number of shipments recorded
SELECT COUNT(shipment_key) AS total_shipments
FROM sc.fact_shipments
WHERE status != 'Data Error';

-- Find the total number of shipments delivered on time
SELECT COUNT(shipment_key) AS on_time_shipments
FROM sc.fact_shipments
WHERE ISNULL(delay_days, 0) <= 0
  AND status != 'Data Error';

-- Find the total number of shipments that arrived late
SELECT COUNT(shipment_key) AS delayed_shipments
FROM sc.fact_shipments
WHERE delay_days > 0
  AND status != 'Data Error';

-- Calculate the overall on-time delivery (OTD) rate across the network
SELECT
    ROUND(
        COUNT(CASE WHEN ISNULL(delay_days, 0) <= 0 THEN 1 END) * 100.0
        / NULLIF(COUNT(shipment_key), 0), 2
    ) AS on_time_delivery_rate_pct
FROM sc.fact_shipments
WHERE status != 'Data Error';

-- Find the average delay in days across late shipments only
SELECT
    ROUND(AVG(CAST(delay_days AS FLOAT)), 1) AS avg_delay_days_when_late
FROM sc.fact_shipments
WHERE delay_days > 0
  AND status != 'Data Error';

-- Find the total shipment cost across the entire network
SELECT ROUND(SUM(shipment_cost), 2) AS total_network_cost
FROM sc.fact_shipments
WHERE shipment_cost IS NOT NULL
  AND status != 'Data Error';

-- Find the average cost per shipment across the network
SELECT ROUND(AVG(shipment_cost), 2) AS avg_shipment_cost
FROM sc.fact_shipments
WHERE shipment_cost IS NOT NULL
  AND status != 'Data Error';

-- Find the total weight shipped across the entire network
SELECT ROUND(SUM(weight_kg), 2) AS total_weight_shipped_kg
FROM sc.fact_shipments
WHERE weight_kg IS NOT NULL
  AND status != 'Data Error';

-- Find the total number of distinct active suppliers used in shipments
SELECT COUNT(DISTINCT supplier_key) AS total_active_suppliers
FROM sc.fact_shipments
WHERE status != 'Data Error';

-- Find the total number of registered suppliers in the network
SELECT COUNT(supplier_key) AS total_registered_suppliers
FROM sc.ref_suppliers;

-- Find the total number of distinct carriers used across all shipments
SELECT COUNT(DISTINCT carrier_key) AS total_carriers_used
FROM sc.fact_shipments
WHERE status != 'Data Error';

-- Find the total number of distinct routes used across all shipments
SELECT COUNT(DISTINCT route_key) AS total_routes_used
FROM sc.fact_shipments
WHERE status != 'Data Error';

-- Find the total number of distinct warehouses handling shipments
SELECT COUNT(DISTINCT warehouse_key) AS total_warehouses_used
FROM sc.fact_shipments
WHERE status != 'Data Error';

-- Find the total number of distinct product categories being shipped
SELECT COUNT(DISTINCT category) AS total_product_categories
FROM sc.ref_products;

-- Generate a single report that shows all key supply chain metrics at once
SELECT 'Total Shipments'            AS measure_name, COUNT(shipment_key)                                                        AS measure_value FROM sc.fact_shipments WHERE status != 'Data Error'
UNION ALL
SELECT 'On-Time Shipments',         COUNT(CASE WHEN ISNULL(delay_days, 0) <= 0 THEN 1 END)                                     FROM sc.fact_shipments WHERE status != 'Data Error'
UNION ALL
SELECT 'Delayed Shipments',         COUNT(CASE WHEN delay_days > 0 THEN 1 END)                                                 FROM sc.fact_shipments WHERE status != 'Data Error'
UNION ALL
SELECT 'Total Network Cost (USD)',   ROUND(SUM(shipment_cost), 0)                                                              FROM sc.fact_shipments WHERE status != 'Data Error'
UNION ALL
SELECT 'Avg Shipment Cost (USD)',    ROUND(AVG(shipment_cost), 0)                                                              FROM sc.fact_shipments WHERE status != 'Data Error'
UNION ALL
SELECT 'Avg Delay Days (Late Only)', ROUND(AVG(CASE WHEN delay_days > 0 THEN CAST(delay_days AS FLOAT) END), 0)               FROM sc.fact_shipments WHERE status != 'Data Error'
UNION ALL
SELECT 'Total Weight Shipped (kg)', ROUND(SUM(weight_kg), 0)                                                                  FROM sc.fact_shipments WHERE status != 'Data Error'
UNION ALL
SELECT 'Active Suppliers',          COUNT(DISTINCT supplier_key)                                                               FROM sc.fact_shipments WHERE status != 'Data Error'
UNION ALL
SELECT 'Registered Suppliers',      COUNT(supplier_key)                                                                       FROM sc.ref_suppliers
UNION ALL
SELECT 'Active Carriers',           COUNT(DISTINCT carrier_key)                                                               FROM sc.fact_shipments WHERE status != 'Data Error'
UNION ALL
SELECT 'Active Routes',             COUNT(DISTINCT route_key)                                                                 FROM sc.fact_shipments WHERE status != 'Data Error'
UNION ALL
SELECT 'Active Warehouses',         COUNT(DISTINCT warehouse_key)                                                             FROM sc.fact_shipments WHERE status != 'Data Error'
UNION ALL
SELECT 'Total Product Categories',  COUNT(DISTINCT category)                                                                  FROM sc.ref_products;
