/*
===============================================================================
Shipments Report
===============================================================================
Purpose:
    - Brings together every dimension of a shipment into a single flat view
      for Power BI to connect to directly across all four dashboard pages.
    - Eliminates the need for Power BI to join tables or handle nulls —
      everything is pre-cleaned, pre-joined, and pre-classified here.
Highlights:
    1. Joins all six tables into one enriched shipment record and handles
       all remaining dirty data inline using ISNULL and TRIM.
    2. Classifies each shipment by delay severity, cost band, warehouse
       load status, and route risk level.
    3. Aggregates shipment-level metrics at the fact grain:
       - actual transit days
       - days over or under the promised delivery window
       - delivery flag (On Time / Delayed)
       - cost efficiency classification
    4. Derives key KPIs per shipment row:
       - delay severity label
       - warehouse utilisation at time of shipment
       - product value exposure on delayed shipments
       - cost band classification
===============================================================================
*/

IF OBJECT_ID('sc.report_shipments', 'V') IS NOT NULL
    DROP VIEW sc.report_shipments;
GO

CREATE VIEW sc.report_shipments AS

WITH base_query AS (
/*---------------------------------------------------------------------------
1) Base Query: Joins all six tables into one enriched shipment record
   Handles all dirty data inline before it reaches Power BI
   Excludes impossible date records flagged during data cleaning
---------------------------------------------------------------------------*/
    SELECT
        f.shipment_key,
        f.shipment_id,
        f.order_date,
        f.promised_date,
        f.actual_date,
        ISNULL(f.delay_days, 0)                                         AS delay_days,
        ISNULL(TRIM(f.status), 'Unknown')                               AS shipment_status,
        ISNULL(f.shipment_cost, 0)                                      AS shipment_cost,
        ISNULL(f.weight_kg, 0)                                          AS weight_kg,
        ISNULL(f.quantity, 0)                                           AS quantity,

        -- Supplier fields
        s.supplier_key,
        ISNULL(s.supplier_name, 'Unknown Supplier')                     AS supplier_name,
        ISNULL(s.country, 'Unknown')                                    AS supplier_country,
        ISNULL(s.contract_tier, 'Unknown')                              AS contract_tier,
        ISNULL(s.category, 'Unknown')                                   AS supplier_category,
        ISNULL(CAST(s.rating AS NVARCHAR), 'Unrated')                   AS supplier_rating,

        -- Carrier fields
        c.carrier_key,
        ISNULL(c.carrier_name, 'Unknown Carrier')                       AS carrier_name,
        ISNULL(c.transport_mode, 'Unknown')                             AS transport_mode,
        ISNULL(c.avg_cost_per_km, 0)                                    AS avg_cost_per_km,

        -- Route fields
        r.route_key,
        ISNULL(r.origin, 'Unknown')                                     AS route_origin,
        ISNULL(r.destination, 'Unknown')                                AS route_destination,
        ISNULL(r.region, 'Unknown')                                     AS route_region,
        ISNULL(r.distance_km, 0)                                        AS distance_km,
        ISNULL(r.avg_transit_days, 0)                                   AS expected_transit_days,

        -- Warehouse fields
        w.warehouse_key,
        ISNULL(w.location, 'Unknown')                                   AS warehouse_location,
        ISNULL(w.region, 'Unknown')                                     AS warehouse_region,
        ISNULL(w.capacity, 0)                                           AS warehouse_capacity,
        ISNULL(w.current_load, 0)                                       AS warehouse_load,
        ROUND(
            ISNULL(w.current_load, 0) * 100.0
            / NULLIF(w.capacity, 0), 1
        )                                                               AS warehouse_utilisation_pct,

        -- Product fields
        p.product_key,
        ISNULL(p.product_name, 'Unknown Product')                       AS product_name,
        ISNULL(p.category, 'Unknown')                                   AS product_category,
        ISNULL(p.fragility, 'Unknown')                                  AS product_fragility,
        ISNULL(p.value_usd, 0)                                          AS product_value_usd

    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_suppliers  s ON s.supplier_key  = f.supplier_key
    LEFT JOIN sc.ref_carriers   c ON c.carrier_key   = f.carrier_key
    LEFT JOIN sc.ref_routes     r ON r.route_key     = f.route_key
    LEFT JOIN sc.ref_warehouses w ON w.warehouse_key = f.warehouse_key
    LEFT JOIN sc.ref_products   p ON p.product_key   = f.product_key
    WHERE f.order_date IS NOT NULL
      AND f.status     != 'Data Error'
)

/*---------------------------------------------------------------------------
2) Final Query: Adds all derived fields and classifications
   This is what Power BI connects to for all four dashboard pages
---------------------------------------------------------------------------*/
SELECT
    shipment_key,
    shipment_id,
    order_date,
    promised_date,
    actual_date,
    delay_days,
    shipment_status,
    shipment_cost,
    weight_kg,
    quantity,

    -- Supplier
    supplier_key,
    supplier_name,
    supplier_country,
    contract_tier,
    supplier_category,
    supplier_rating,

    -- Carrier
    carrier_key,
    carrier_name,
    transport_mode,
    avg_cost_per_km,

    -- Route
    route_key,
    route_origin,
    route_destination,
    route_region,
    distance_km,
    expected_transit_days,

    -- Warehouse
    warehouse_key,
    warehouse_location,
    warehouse_region,
    warehouse_capacity,
    warehouse_load,
    warehouse_utilisation_pct,

    -- Product
    product_key,
    product_name,
    product_category,
    product_fragility,
    product_value_usd,

    -- Derived: how many days did the actual delivery actually take?
    DATEDIFF(day, order_date, actual_date)                              AS actual_transit_days,

    -- Derived: how many days over or under the promised window?
    DATEDIFF(day, promised_date, actual_date)                           AS days_vs_promise,

    -- Derived: financial exposure on this shipment if delayed
    CASE
        WHEN delay_days > 0 THEN shipment_cost
        ELSE 0
    END                                                                 AS delayed_shipment_cost,

    -- Derived: product value at risk on delayed shipments
    CASE
        WHEN delay_days > 0 THEN product_value_usd
        ELSE 0
    END                                                                 AS product_value_at_risk,

    -- On-time flag for Power BI slicer and KPI card
    CASE
        WHEN delay_days <= 0 THEN 'On Time'
        ELSE                      'Delayed'
    END                                                                 AS delivery_flag,

    -- Delay severity classification
    CASE
        WHEN delay_days <= 0             THEN 'On Time'
        WHEN delay_days BETWEEN 1 AND 3  THEN 'Minor     (1 - 3 days)'
        WHEN delay_days BETWEEN 4 AND 7  THEN 'Moderate  (4 - 7 days)'
        WHEN delay_days BETWEEN 8 AND 14 THEN 'Severe    (8 - 14 days)'
        ELSE                                  'Critical  (15+ days)'
    END                                                                 AS delay_severity,

    -- Shipment cost band classification
    CASE
        WHEN shipment_cost < 500                    THEN 'Low       (Below $500)'
        WHEN shipment_cost BETWEEN 500  AND 1500    THEN 'Mid       ($500 - $1,500)'
        WHEN shipment_cost BETWEEN 1501 AND 5000    THEN 'High      ($1,500 - $5,000)'
        WHEN shipment_cost BETWEEN 5001 AND 10000   THEN 'Premium   ($5,000 - $10,000)'
        ELSE                                             'Elite     (Above $10,000)'
    END                                                                 AS cost_band,

    -- Warehouse operational status at time of shipment
    CASE
        WHEN warehouse_utilisation_pct >= 90    THEN 'Critical Capacity'
        WHEN warehouse_utilisation_pct >= 75    THEN 'High Load'
        WHEN warehouse_utilisation_pct >= 50    THEN 'Moderate Load'
        ELSE                                         'Normal Operations'
    END                                                                 AS warehouse_status,

    -- Route risk classification based on distance
    CASE
        WHEN distance_km < 1000                     THEN 'Short Haul'
        WHEN distance_km BETWEEN 1000 AND 3000      THEN 'Medium Haul'
        WHEN distance_km BETWEEN 3001 AND 7000      THEN 'Long Haul'
        ELSE                                             'Ultra Haul'
    END                                                                 AS route_distance_band,

    -- Product fragility risk flag on delayed shipments
    CASE
        WHEN delay_days > 0 AND product_fragility = 'High'      THEN 'High Risk — Fragile & Late'
        WHEN delay_days > 0 AND product_fragility = 'Medium'    THEN 'Medium Risk — Delayed'
        WHEN delay_days > 0                                      THEN 'Low Risk — Delayed'
        ELSE                                                          'No Risk — On Time'
    END                                                                 AS fragility_risk_flag

FROM base_query;
GO
