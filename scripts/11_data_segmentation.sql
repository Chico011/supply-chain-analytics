/*
===============================================================================
Data Segmentation Analysis
===============================================================================
Purpose:
    - Group suppliers, carriers, routes, warehouses, and shipments into
      meaningful performance and operational categories.
    - Move beyond averages — understand the distribution of performance
      across the entire network so interventions are targeted, not broad.
    - Every segment here maps directly to a recommendation in the final report.
SQL Functions Used:
    - CASE: Defines custom segmentation logic
    - GROUP BY: Groups data into segments
    - CTEs: Multi-step segmentation with aggregation before classification
    - NULLIF, ISNULL: Dirty data handling within segmentation logic
===============================================================================
*/

/* Segment suppliers into performance tiers based on delay rate
   and count how many fall into each tier
   — tells the ops team how many suppliers need immediate action */
WITH supplier_delay_rates AS (
    SELECT
        s.supplier_key,
        s.supplier_name,
        s.contract_tier,
        ROUND(
            COUNT(CASE WHEN f.delay_days > 0 THEN 1 END) * 100.0
            / NULLIF(COUNT(f.shipment_key), 0), 2
        )                                                               AS delay_rate_pct
    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_suppliers s
        ON s.supplier_key = f.supplier_key
    WHERE f.status != 'Data Error'
    GROUP BY s.supplier_key, s.supplier_name, s.contract_tier
)
SELECT
    performance_tier,
    COUNT(supplier_key)                                                 AS total_suppliers
FROM (
    SELECT
        supplier_key,
        CASE
            WHEN delay_rate_pct >= 40   THEN 'Critical  (40%+ delay rate)'
            WHEN delay_rate_pct >= 25   THEN 'At Risk   (25% - 39%)'
            WHEN delay_rate_pct >= 10   THEN 'Monitor   (10% - 24%)'
            ELSE                             'Healthy   (Below 10%)'
        END                                                             AS performance_tier
    FROM supplier_delay_rates
) AS segmented_suppliers
GROUP BY performance_tier
ORDER BY total_suppliers DESC;

/* Segment shipments into cost bands and
   count how many shipments fall into each band
   — reveals whether high-cost shipments are being delayed more than low-cost ones */
WITH cost_segments AS (
    SELECT
        shipment_key,
        shipment_id,
        shipment_cost,
        delay_days,
        CASE
            WHEN shipment_cost < 500                        THEN 'Low       (Below $500)'
            WHEN shipment_cost BETWEEN 500    AND 1500      THEN 'Mid       ($500 - $1,500)'
            WHEN shipment_cost BETWEEN 1501   AND 5000      THEN 'High      ($1,500 - $5,000)'
            WHEN shipment_cost BETWEEN 5001   AND 10000     THEN 'Premium   ($5,000 - $10,000)'
            ELSE                                                 'Elite     (Above $10,000)'
        END                                                             AS cost_band
    FROM sc.fact_shipments
    WHERE shipment_cost IS NOT NULL
      AND status        != 'Data Error'
)
SELECT
    cost_band,
    COUNT(shipment_key)                                                 AS total_shipments,
    COUNT(CASE WHEN delay_days > 0 THEN 1 END)                          AS delayed_shipments,
    ROUND(
        COUNT(CASE WHEN delay_days > 0 THEN 1 END) * 100.0
        / NULLIF(COUNT(shipment_key), 0), 2
    )                                                                   AS delay_rate_pct
FROM cost_segments
GROUP BY cost_band
ORDER BY total_shipments DESC;

/* Classify shipments into delay severity tiers based on how late they arrived
   and measure the average cost within each tier
   — shows the financial weight of the most severe delays */
WITH delay_segments AS (
    SELECT
        shipment_key,
        delay_days,
        shipment_cost,
        CASE
            WHEN delay_days <= 0             THEN 'On Time'
            WHEN delay_days BETWEEN 1 AND 3  THEN 'Minor     (1 - 3 days)'
            WHEN delay_days BETWEEN 4 AND 7  THEN 'Moderate  (4 - 7 days)'
            WHEN delay_days BETWEEN 8 AND 14 THEN 'Severe    (8 - 14 days)'
            ELSE                                  'Critical  (15+ days)'
        END                                                             AS delay_tier
    FROM sc.fact_shipments
    WHERE delay_days    IS NOT NULL
      AND status        != 'Data Error'
)
SELECT
    delay_tier,
    COUNT(shipment_key)                                                 AS total_shipments,
    ROUND(SUM(shipment_cost), 2)                                        AS total_cost_in_tier,
    ROUND(AVG(shipment_cost), 2)                                        AS avg_cost_in_tier
FROM delay_segments
GROUP BY delay_tier
ORDER BY total_shipments DESC;

/* Classify suppliers into relationship segments based on
   shipment volume and contract tier — mirrors a real supplier
   relationship management (SRM) framework used in enterprise operations */
WITH supplier_volume AS (
    SELECT
        s.supplier_key,
        s.supplier_name,
        s.contract_tier,
        COUNT(f.shipment_key)                                           AS total_shipments,
        ROUND(SUM(f.shipment_cost), 2)                                  AS total_spend,
        MIN(f.order_date)                                               AS first_shipment,
        MAX(f.order_date)                                               AS last_shipment,
        DATEDIFF(month, MIN(f.order_date), MAX(f.order_date))           AS relationship_months
    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_suppliers s
        ON s.supplier_key = f.supplier_key
    WHERE f.status != 'Data Error'
    GROUP BY
        s.supplier_key,
        s.supplier_name,
        s.contract_tier
)
SELECT
    supplier_segment,
    COUNT(supplier_key)                                                 AS total_suppliers
FROM (
    SELECT
        supplier_key,
        CASE
            WHEN relationship_months >= 18 AND total_shipments > 100   THEN 'Strategic Partner'
            WHEN relationship_months >= 12 AND total_shipments > 50    THEN 'Key Supplier'
            WHEN relationship_months >= 6  AND total_shipments > 20    THEN 'Developing Supplier'
            ELSE                                                             'New / Low Volume'
        END                                                             AS supplier_segment
    FROM supplier_volume
) AS segmented_suppliers
GROUP BY supplier_segment
ORDER BY total_suppliers DESC;

/* Segment warehouses by utilisation level
   to identify which facilities are overloaded and at risk of driving delays */
WITH warehouse_load AS (
    SELECT
        w.warehouse_key,
        w.location,
        w.region,
        w.capacity,
        w.current_load,
        ROUND(w.current_load * 100.0 / NULLIF(w.capacity, 0), 1)       AS utilisation_pct
    FROM sc.ref_warehouses w
)
SELECT
    load_segment,
    COUNT(warehouse_key)                                                AS total_warehouses
FROM (
    SELECT
        warehouse_key,
        CASE
            WHEN utilisation_pct >= 90  THEN 'Critical  (90%+ capacity)'
            WHEN utilisation_pct >= 75  THEN 'High Load (75% - 89%)'
            WHEN utilisation_pct >= 50  THEN 'Moderate  (50% - 74%)'
            ELSE                             'Low Load  (Below 50%)'
        END                                                             AS load_segment
    FROM warehouse_load
) AS segmented_warehouses
GROUP BY load_segment
ORDER BY total_warehouses DESC;

/* Segment routes by distance band and measure delay rate within each band
   — tests whether longer routes are inherently more delay-prone */
WITH route_distance AS (
    SELECT
        r.route_key,
        r.origin,
        r.destination,
        r.region,
        r.distance_km,
        COUNT(f.shipment_key)                                           AS total_shipments,
        ROUND(
            COUNT(CASE WHEN f.delay_days > 0 THEN 1 END) * 100.0
            / NULLIF(COUNT(f.shipment_key), 0), 2
        )                                                               AS delay_rate_pct
    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_routes r
        ON r.route_key = f.route_key
    WHERE f.status != 'Data Error'
    GROUP BY r.route_key, r.origin, r.destination, r.region, r.distance_km
)
SELECT
    distance_band,
    COUNT(route_key)                                                    AS total_routes,
    ROUND(AVG(delay_rate_pct), 2)                                       AS avg_delay_rate_pct,
    ROUND(AVG(CAST(distance_km AS FLOAT)), 0)                           AS avg_distance_km
FROM (
    SELECT
        route_key,
        delay_rate_pct,
        distance_km,
        CASE
            WHEN distance_km < 1000                         THEN 'Short Haul   (Below 1,000 km)'
            WHEN distance_km BETWEEN 1000 AND 3000          THEN 'Medium Haul  (1,000 - 3,000 km)'
            WHEN distance_km BETWEEN 3001 AND 7000          THEN 'Long Haul    (3,000 - 7,000 km)'
            ELSE                                                 'Ultra Haul   (Above 7,000 km)'
        END                                                             AS distance_band
    FROM route_distance
) AS segmented_routes
GROUP BY distance_band
ORDER BY avg_delay_rate_pct DESC;
