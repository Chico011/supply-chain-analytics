/*
===============================================================================
Performance Ranking Analysis
===============================================================================
Objective:
    - Rank suppliers, carriers, routes, and warehouses by delivery performance
      and cost efficiency across the supply chain network.
    - Identify the best and worst performers across every dimension so the
      operations team knows exactly where to focus intervention.
    - Move beyond simple TOP N — use window functions to build flexible,
      reusable rankings that Power BI can slice and filter.
Techniques Used:
    - Ranking functions (RANK, DENSE_RANK, NTILE, ROW_NUMBER)
    - Aggregation (SUM, COUNT, AVG)
    - GROUP BY and ORDER BY
    - Multi-table LEFT JOIN
    - NULLIF for safe division
Summary:
    The queries below rank every key entity in the network by delay rate,
    on-time delivery performance, and cost efficiency — identifying which
    suppliers are destroying performance, which carriers deliver value,
    which routes are chronically broken, and which warehouses are bottlenecks.
===============================================================================
*/

-- Which 5 suppliers have the highest delay rates?
-- Simple Ranking
SELECT TOP 5
    s.supplier_name,
    s.country,
    s.contract_tier,
    COUNT(f.shipment_key)                                               AS total_shipments,
    COUNT(CASE WHEN f.delay_days > 0 THEN 1 END)                        AS delayed_shipments,
    ROUND(
        COUNT(CASE WHEN f.delay_days > 0 THEN 1 END) * 100.0
        / NULLIF(COUNT(f.shipment_key), 0), 2
    )                                                                   AS delay_rate_pct
FROM sc.fact_shipments f
LEFT JOIN sc.ref_suppliers s
    ON s.supplier_key = f.supplier_key
GROUP BY s.supplier_name, s.country, s.contract_tier
ORDER BY delay_rate_pct DESC;

-- Complex but Flexible Supplier Delay Ranking Using Window Functions
-- Ranks all suppliers — filter to any depth without rewriting the query
SELECT *
FROM (
    SELECT
        s.supplier_name,
        s.country,
        s.contract_tier,
        s.rating                                                        AS supplier_rating,
        COUNT(f.shipment_key)                                           AS total_shipments,
        COUNT(CASE WHEN f.delay_days > 0 THEN 1 END)                    AS delayed_shipments,
        ROUND(
            COUNT(CASE WHEN f.delay_days > 0 THEN 1 END) * 100.0
            / NULLIF(COUNT(f.shipment_key), 0), 2
        )                                                               AS delay_rate_pct,
        ROUND(SUM(f.shipment_cost), 2)                                  AS total_cost,
        RANK() OVER (
            ORDER BY
                COUNT(CASE WHEN f.delay_days > 0 THEN 1 END) * 100.0
                / NULLIF(COUNT(f.shipment_key), 0) DESC
        )                                                               AS delay_rank
    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_suppliers s
        ON s.supplier_key = f.supplier_key
    GROUP BY s.supplier_name, s.country, s.contract_tier, s.rating
) AS ranked_suppliers
WHERE delay_rank <= 10;

-- What are the 5 best performing suppliers by on-time delivery rate?
-- Knowing the top performers is as important as knowing the worst
SELECT TOP 5
    s.supplier_name,
    s.country,
    s.contract_tier,
    COUNT(f.shipment_key)                                               AS total_shipments,
    ROUND(
        COUNT(CASE WHEN ISNULL(f.delay_days, 0) <= 0 THEN 1 END) * 100.0
        / NULLIF(COUNT(f.shipment_key), 0), 2
    )                                                                   AS on_time_rate_pct
FROM sc.fact_shipments f
LEFT JOIN sc.ref_suppliers s
    ON s.supplier_key = f.supplier_key
GROUP BY s.supplier_name, s.country, s.contract_tier
ORDER BY on_time_rate_pct DESC;

-- Rank all carriers by their actual on-time delivery rate
-- Compare contracted rate vs actual rate to identify who is underdelivering
SELECT *
FROM (
    SELECT
        c.carrier_name,
        c.transport_mode,
        c.on_time_rate                                                  AS contracted_otd_rate,
        COUNT(f.shipment_key)                                           AS total_shipments,
        ROUND(
            COUNT(CASE WHEN ISNULL(f.delay_days, 0) <= 0 THEN 1 END) * 100.0
            / NULLIF(COUNT(f.shipment_key), 0), 2
        )                                                               AS actual_otd_rate_pct,
        -- Gap between what was promised vs what was actually delivered
        ROUND(
            c.on_time_rate -
            COUNT(CASE WHEN ISNULL(f.delay_days, 0) <= 0 THEN 1 END) * 100.0
            / NULLIF(COUNT(f.shipment_key), 0), 2
        )                                                               AS otd_gap_vs_contract,
        ROUND(AVG(f.shipment_cost), 2)                                  AS avg_shipment_cost,
        RANK() OVER (
            ORDER BY
                COUNT(CASE WHEN ISNULL(f.delay_days, 0) <= 0 THEN 1 END) * 100.0
                / NULLIF(COUNT(f.shipment_key), 0) DESC
        )                                                               AS reliability_rank
    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_carriers c
        ON c.carrier_key = f.carrier_key
    GROUP BY c.carrier_name, c.transport_mode, c.on_time_rate
) AS ranked_carriers
ORDER BY reliability_rank;

-- Rank the top 10 most delayed routes in the entire network
-- Routes with high delay rates and high volume are the biggest risk to contracts
SELECT *
FROM (
    SELECT
        r.origin,
        r.destination,
        r.region,
        r.distance_km,
        r.avg_transit_days                                              AS expected_transit_days,
        COUNT(f.shipment_key)                                           AS total_shipments,
        COUNT(CASE WHEN f.delay_days > 0 THEN 1 END)                    AS delayed_shipments,
        ROUND(
            COUNT(CASE WHEN f.delay_days > 0 THEN 1 END) * 100.0
            / NULLIF(COUNT(f.shipment_key), 0), 2
        )                                                               AS delay_rate_pct,
        ROUND(
            AVG(CASE WHEN f.delay_days > 0
                     THEN CAST(f.delay_days AS FLOAT) END), 1
        )                                                               AS avg_delay_days_when_late,
        RANK() OVER (
            ORDER BY
                COUNT(CASE WHEN f.delay_days > 0 THEN 1 END) * 100.0
                / NULLIF(COUNT(f.shipment_key), 0) DESC
        )                                                               AS route_delay_rank
    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_routes r
        ON r.route_key = f.route_key
    GROUP BY r.origin, r.destination, r.region, r.distance_km, r.avg_transit_days
) AS ranked_routes
WHERE route_delay_rank <= 10;

-- Rank warehouses by delay rate to identify the biggest bottleneck locations
-- Cross-reference with utilisation to see if overload is the root cause
SELECT *
FROM (
    SELECT
        w.location,
        w.region,
        w.capacity,
        w.current_load,
        ROUND(w.current_load * 100.0 / NULLIF(w.capacity, 0), 1)       AS utilisation_pct,
        w.processing_time_avg,
        COUNT(f.shipment_key)                                           AS total_shipments,
        COUNT(CASE WHEN f.delay_days > 0 THEN 1 END)                    AS delayed_shipments,
        ROUND(
            COUNT(CASE WHEN f.delay_days > 0 THEN 1 END) * 100.0
            / NULLIF(COUNT(f.shipment_key), 0), 2
        )                                                               AS delay_rate_pct,
        RANK() OVER (
            ORDER BY
                COUNT(CASE WHEN f.delay_days > 0 THEN 1 END) * 100.0
                / NULLIF(COUNT(f.shipment_key), 0) DESC
        )                                                               AS bottleneck_rank
    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_warehouses w
        ON w.warehouse_key = f.warehouse_key
    GROUP BY
        w.location, w.region, w.capacity,
        w.current_load, w.processing_time_avg
) AS ranked_warehouses
WHERE bottleneck_rank <= 5;

-- Divide all suppliers into four performance quartiles using NTILE
-- Quartile 1 = worst performers, Quartile 4 = best performers
-- This feeds directly into the supplier scorecard in Power BI
SELECT
    supplier_name,
    country,
    contract_tier,
    total_shipments,
    delay_rate_pct,
    NTILE(4) OVER (ORDER BY delay_rate_pct DESC)                        AS performance_quartile,
    CASE
        WHEN NTILE(4) OVER (ORDER BY delay_rate_pct DESC) = 1 THEN 'Critical — Immediate Action'
        WHEN NTILE(4) OVER (ORDER BY delay_rate_pct DESC) = 2 THEN 'At Risk — Close Monitoring'
        WHEN NTILE(4) OVER (ORDER BY delay_rate_pct DESC) = 3 THEN 'Acceptable — Standard Review'
        ELSE                                                            'Healthy — Best Practice'
    END                                                                 AS quartile_label
FROM (
    SELECT
        s.supplier_name,
        s.country,
        s.contract_tier,
        COUNT(f.shipment_key)                                           AS total_shipments,
        ROUND(
            COUNT(CASE WHEN f.delay_days > 0 THEN 1 END) * 100.0
            / NULLIF(COUNT(f.shipment_key), 0), 2
        )                                                               AS delay_rate_pct
    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_suppliers s
        ON s.supplier_key = f.supplier_key
    GROUP BY s.supplier_name, s.country, s.contract_tier
) AS supplier_summary
ORDER BY performance_quartile, delay_rate_pct DESC;

-- Rank product categories by total cost of delayed shipments
-- Identifies which product types are most financially exposed to delays
SELECT *
FROM (
    SELECT
        ISNULL(p.category, 'Unknown')                                   AS product_category,
        COUNT(f.shipment_key)                                           AS total_shipments,
        COUNT(CASE WHEN f.delay_days > 0 THEN 1 END)                    AS delayed_shipments,
        ROUND(
            SUM(CASE WHEN f.delay_days > 0
                     THEN f.shipment_cost ELSE 0 END), 2
        )                                                               AS cost_of_delayed_shipments,
        ROUND(
            COUNT(CASE WHEN f.delay_days > 0 THEN 1 END) * 100.0
            / NULLIF(COUNT(f.shipment_key), 0), 2
        )                                                               AS delay_rate_pct,
        RANK() OVER (
            ORDER BY SUM(CASE WHEN f.delay_days > 0
                              THEN f.shipment_cost ELSE 0 END) DESC
        )                                                               AS cost_exposure_rank
    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_products p
        ON p.product_key = f.product_key
    GROUP BY ISNULL(p.category, 'Unknown')
) AS ranked_products
ORDER BY cost_exposure_rank;
