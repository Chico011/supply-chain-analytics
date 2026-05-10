/*
===============================================================================
Category Contribution Analysis
===============================================================================
Objective:
    - Evaluate how each dimension of the supply chain contributes to total
      shipment volume, total cost, and total delays across the network.
    - Identify which suppliers, carriers, routes, warehouses, and product
      categories carry the heaviest financial and operational weight.
    - Support resource allocation and contract prioritisation decisions
      by showing exactly where the most impact is concentrated.
Techniques Used:
    - Aggregation (SUM, COUNT)
    - Window functions (SUM() OVER())
    - Percentage calculations
    - NULLIF for safe division
Summary:
    These queries break down total shipments, costs, and delays by category
    and calculate each segment's share of the overall total — highlighting
    where the most value and the most risk sit in the network.
===============================================================================
*/

-- Which supplier country contributes the most to total shipment volume?
WITH country_shipments AS (
    SELECT
        ISNULL(s.country, 'Unknown')                                    AS supplier_country,
        COUNT(f.shipment_key)                                           AS total_shipments
    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_suppliers s
        ON s.supplier_key = f.supplier_key
    WHERE f.status != 'Data Error'
    GROUP BY ISNULL(s.country, 'Unknown')
)
SELECT
    supplier_country,
    total_shipments,
    SUM(total_shipments)    OVER ()                                                         AS overall_shipments,
    ROUND(
        (CAST(total_shipments AS FLOAT) / NULLIF(SUM(total_shipments) OVER (), 0)) * 100, 2
    )                                                                   AS percentage_of_total
FROM country_shipments
ORDER BY total_shipments DESC;

-- Which carrier transport mode contributes the most to total shipment cost?
WITH mode_cost AS (
    SELECT
        ISNULL(c.transport_mode, 'Unknown')                             AS transport_mode,
        ROUND(SUM(f.shipment_cost), 2)                                  AS total_cost
    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_carriers c
        ON c.carrier_key = f.carrier_key
    WHERE f.shipment_cost IS NOT NULL
      AND f.status        != 'Data Error'
    GROUP BY ISNULL(c.transport_mode, 'Unknown')
)
SELECT
    transport_mode,
    total_cost,
    SUM(total_cost)         OVER ()                                                         AS overall_cost,
    ROUND(
        (CAST(total_cost AS FLOAT) / NULLIF(SUM(total_cost) OVER (), 0)) * 100, 2
    )                                                                   AS percentage_of_total
FROM mode_cost
ORDER BY total_cost DESC;

-- Which route region contributes the most to total delayed shipments?
-- Shows where delay pressure is geographically concentrated
WITH region_delays AS (
    SELECT
        ISNULL(r.region, 'Unknown')                                     AS route_region,
        COUNT(CASE WHEN f.delay_days > 0 THEN 1 END)                    AS total_delayed,
        COUNT(f.shipment_key)                                           AS total_shipments
    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_routes r
        ON r.route_key = f.route_key
    WHERE f.status != 'Data Error'
    GROUP BY ISNULL(r.region, 'Unknown')
)
SELECT
    route_region,
    total_delayed,
    total_shipments,
    SUM(total_delayed)      OVER ()                                                         AS overall_delayed,
    ROUND(
        (CAST(total_delayed AS FLOAT) / NULLIF(SUM(total_delayed) OVER (), 0)) * 100, 2
    )                                                                   AS percentage_of_total_delays
FROM region_delays
ORDER BY total_delayed DESC;

-- Which product category contributes the most to total shipment cost?
WITH product_cost AS (
    SELECT
        ISNULL(p.category, 'Unknown')                                   AS product_category,
        ROUND(SUM(f.shipment_cost), 2)                                  AS total_cost,
        COUNT(f.shipment_key)                                           AS total_shipments
    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_products p
        ON p.product_key = f.product_key
    WHERE f.shipment_cost IS NOT NULL
      AND f.status        != 'Data Error'
    GROUP BY ISNULL(p.category, 'Unknown')
)
SELECT
    product_category,
    total_shipments,
    total_cost,
    SUM(total_cost)         OVER ()                                                         AS overall_cost,
    ROUND(
        (CAST(total_cost AS FLOAT) / NULLIF(SUM(total_cost) OVER (), 0)) * 100, 2
    )                                                                   AS percentage_of_total
FROM product_cost
ORDER BY total_cost DESC;

-- Which warehouse location handles the largest share of total shipment volume?
WITH warehouse_volume AS (
    SELECT
        ISNULL(w.location, 'Unknown')                                   AS warehouse_location,
        ISNULL(w.region, 'Unknown')                                     AS warehouse_region,
        COUNT(f.shipment_key)                                           AS total_shipments,
        ROUND(SUM(f.shipment_cost), 2)                                  AS total_cost
    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_warehouses w
        ON w.warehouse_key = f.warehouse_key
    WHERE f.status != 'Data Error'
    GROUP BY ISNULL(w.location, 'Unknown'), ISNULL(w.region, 'Unknown')
)
SELECT
    warehouse_location,
    warehouse_region,
    total_shipments,
    total_cost,
    SUM(total_shipments)    OVER ()                                                         AS overall_shipments,
    ROUND(
        (CAST(total_shipments AS FLOAT) / NULLIF(SUM(total_shipments) OVER (), 0)) * 100, 2
    )                                                                   AS percentage_of_total
FROM warehouse_volume
ORDER BY total_shipments DESC;

-- Which supplier contract tier drives the most total cost in the network?
-- Critical for understanding whether Platinum suppliers justify their premium
WITH tier_cost AS (
    SELECT
        ISNULL(s.contract_tier, 'Unknown')                              AS contract_tier,
        COUNT(f.shipment_key)                                           AS total_shipments,
        ROUND(SUM(f.shipment_cost), 2)                                  AS total_cost,
        COUNT(CASE WHEN f.delay_days > 0 THEN 1 END)                    AS total_delayed
    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_suppliers s
        ON s.supplier_key = f.supplier_key
    WHERE f.shipment_cost IS NOT NULL
      AND f.status        != 'Data Error'
    GROUP BY ISNULL(s.contract_tier, 'Unknown')
)
SELECT
    contract_tier,
    total_shipments,
    total_cost,
    total_delayed,
    SUM(total_cost)         OVER ()                                                         AS overall_cost,
    ROUND(
        (CAST(total_cost AS FLOAT) / NULLIF(SUM(total_cost) OVER (), 0)) * 100, 2
    )                                                                   AS pct_of_total_cost,
    -- What share of that tier's shipments were delayed?
    ROUND(
        CAST(total_delayed AS FLOAT)
        / NULLIF(total_shipments, 0) * 100, 2
    )                                                                   AS delay_rate_within_tier
FROM tier_cost
ORDER BY total_cost DESC;
