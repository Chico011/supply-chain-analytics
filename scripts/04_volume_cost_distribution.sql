/*
===============================================================================
Volume & Cost Distribution
===============================================================================
Objective:
    - Aggregate data to understand how shipment volumes, costs, and delays
      are distributed across every dimension of the supply chain network.
    - Identify which suppliers, carriers, routes, warehouses, and product
      categories carry the most weight in the network.
Techniques Used:
    - Aggregation (SUM, COUNT, AVG)
    - GROUP BY and ORDER BY
    - LEFT JOIN across reference and fact tables
    - ISNULL for dirty data handling
Summary:
    The following queries explore key dimensions such as supplier geography,
    carrier modes, route regions, warehouse locations, and product categories
    to uncover meaningful distribution patterns before deep analysis begins.
===============================================================================
*/

-- Find total shipments by supplier country
SELECT
    ISNULL(s.country, 'Unknown')      AS country,
    COUNT(f.shipment_key)    AS total_shipments
FROM sc.fact_shipments f
LEFT JOIN sc.ref_suppliers s
    ON s.supplier_key = f.supplier_key
GROUP BY ISNULL(s.country, 'Unknown')
ORDER BY total_shipments DESC;

-- Find total shipments by supplier category
SELECT
    ISNULL(s.category, 'Unknown')   AS supplier_category,
    COUNT(f.shipment_key)   AS total_shipments
FROM sc.fact_shipments f
LEFT JOIN sc.ref_suppliers s
    ON s.supplier_key = f.supplier_key
GROUP BY ISNULL(s.category, 'Unknown')
ORDER BY total_shipments DESC;

-- Find total shipments by supplier contract tier
SELECT
    ISNULL(s.contract_tier, 'Unknown')  AS contract_tier,
    COUNT(f.shipment_key)   AS total_shipments
FROM sc.fact_shipments f
LEFT JOIN sc.ref_suppliers s
    ON s.supplier_key = f.supplier_key
GROUP BY ISNULL(s.contract_tier, 'Unknown')
ORDER BY total_shipments DESC;

-- Find total shipments and total cost by carrier transport mode
SELECT
    ISNULL(c.transport_mode, 'Unknown') AS transport_mode,
    COUNT(f.shipment_key)               AS total_shipments,
    ROUND(SUM(f.shipment_cost), 2)      AS total_cost,
    ROUND(AVG(f.shipment_cost), 2)      AS avg_cost_per_shipment
FROM sc.fact_shipments f
LEFT JOIN sc.ref_carriers c
    ON c.carrier_key = f.carrier_key
GROUP BY ISNULL(c.transport_mode, 'Unknown')
ORDER BY total_shipments DESC;

-- Find total shipments and average cost by carrier coverage region
SELECT
    ISNULL(c.coverage_region, 'Unknown')    AS coverage_region,
    COUNT(f.shipment_key)                   AS total_shipments,
    ROUND(AVG(f.shipment_cost), 2)          AS avg_cost_per_shipment
FROM sc.fact_shipments f
LEFT JOIN sc.ref_carriers c
    ON c.carrier_key = f.carrier_key
GROUP BY ISNULL(c.coverage_region, 'Unknown')
ORDER BY total_shipments DESC;

-- Find total shipments and average cost by route region
SELECT
    ISNULL(r.region, 'Unknown')         AS route_region,
    COUNT(f.shipment_key)               AS total_shipments,
    ROUND(AVG(f.shipment_cost), 2)      AS avg_cost_per_shipment,
    ROUND(AVG(r.distance_km), 0)        AS avg_distance_km
FROM sc.fact_shipments f
LEFT JOIN sc.ref_routes r
    ON r.route_key = f.route_key
GROUP BY ISNULL(r.region, 'Unknown')
ORDER BY total_shipments DESC;

-- Find total shipments processed through each warehouse location
SELECT
    ISNULL(w.location, 'Unknown')       AS warehouse_location,
    ISNULL(w.region, 'Unknown')         AS warehouse_region,
    COUNT(f.shipment_key)               AS total_shipments,
    ROUND(SUM(f.shipment_cost), 2)      AS total_cost
FROM sc.fact_shipments f
LEFT JOIN sc.ref_warehouses w
    ON w.warehouse_key = f.warehouse_key
GROUP BY ISNULL(w.location, 'Unknown'), ISNULL(w.region, 'Unknown')
ORDER BY total_shipments DESC;

-- Find total shipments and total cost by product category
SELECT
    ISNULL(p.category, 'Unknown')       AS product_category,
    COUNT(f.shipment_key)               AS total_shipments,
    ROUND(SUM(f.shipment_cost), 2)      AS total_cost,
    ROUND(AVG(f.weight_kg), 2)          AS avg_weight_kg
FROM sc.fact_shipments f
LEFT JOIN sc.ref_products p
    ON p.product_key = f.product_key
GROUP BY ISNULL(p.category, 'Unknown')
ORDER BY total_shipments DESC;

-- Find total shipments and total cost by product fragility level
SELECT
    ISNULL(p.fragility, 'Unknown')      AS fragility_level,
    COUNT(f.shipment_key)               AS total_shipments,
    ROUND(SUM(f.shipment_cost), 2)      AS total_cost,
    ROUND(AVG(f.shipment_cost), 2)      AS avg_cost_per_shipment
FROM sc.fact_shipments f
LEFT JOIN sc.ref_products p
    ON p.product_key = f.product_key
GROUP BY ISNULL(p.fragility, 'Unknown')
ORDER BY total_shipments DESC;

-- What is the distribution of shipments by current status?
SELECT
    ISNULL(TRIM(status), 'Unknown')     AS shipment_status,
    COUNT(shipment_key)                 AS total_shipments,
    ROUND(SUM(shipment_cost), 2)        AS total_cost
FROM sc.fact_shipments
GROUP BY ISNULL(TRIM(status), 'Unknown')
ORDER BY total_shipments DESC;

-- What is the distribution of delay severity across all late shipments?
SELECT
    CASE
        WHEN delay_days <= 0             THEN 'On Time'
        WHEN delay_days BETWEEN 1 AND 3  THEN '1 - 3 Days Late'
        WHEN delay_days BETWEEN 4 AND 7  THEN '4 - 7 Days Late'
        WHEN delay_days BETWEEN 8 AND 14 THEN '8 - 14 Days Late'
        ELSE                                  'Over 14 Days Late'
    END                                 AS delay_bucket,
    COUNT(shipment_key)                 AS total_shipments,
    ROUND(AVG(shipment_cost), 2)        AS avg_cost_in_bucket
FROM sc.fact_shipments
WHERE delay_days IS NOT NULL
GROUP BY
    CASE
        WHEN delay_days <= 0  THEN 'On Time'
        WHEN delay_days BETWEEN 1 AND 3  THEN '1 - 3 Days Late'
        WHEN delay_days BETWEEN 4 AND 7  THEN '4 - 7 Days Late'
        WHEN delay_days BETWEEN 8 AND 14 THEN '8 - 14 Days Late'
        ELSE  'Over 14 Days Late'
    END
ORDER BY total_shipments DESC;

-- What is the total and average shipment cost per supplier contract tier?
-- This shows whether higher tier suppliers cost more to work with
SELECT
    ISNULL(s.contract_tier, 'Unknown')  AS contract_tier,
    COUNT(f.shipment_key)               AS total_shipments,
    ROUND(SUM(f.shipment_cost), 2)      AS total_cost,
    ROUND(AVG(f.shipment_cost), 2)      AS avg_cost_per_shipment
FROM sc.fact_shipments f
LEFT JOIN sc.ref_suppliers s
    ON s.supplier_key = f.supplier_key
GROUP BY ISNULL(s.contract_tier, 'Unknown')
ORDER BY avg_cost_per_shipment DESC;

-- What is the average shipment cost and total weight by transport mode?
-- Higher weight on cheaper modes validates the carrier selection strategy
SELECT
    ISNULL(c.transport_mode, 'Unknown') AS transport_mode,
    ROUND(AVG(f.shipment_cost), 2)      AS avg_cost,
    ROUND(MIN(f.shipment_cost), 2)      AS min_cost,
    ROUND(MAX(f.shipment_cost), 2)      AS max_cost,
    ROUND(SUM(f.weight_kg), 2)          AS total_weight_kg
FROM sc.fact_shipments f
LEFT JOIN sc.ref_carriers c
    ON c.carrier_key = f.carrier_key
WHERE f.shipment_cost IS NOT NULL
GROUP BY ISNULL(c.transport_mode, 'Unknown')
ORDER BY avg_cost DESC;
