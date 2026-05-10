/*
===============================================================================
Performance Analysis (Year-over-Year & Benchmarking)
===============================================================================
Purpose:
    - Measure delivery performance trends across time periods for every
      key entity in the supply chain network.
    - Compare each supplier's and carrier's current year performance against
      their own historical average and against the prior year.
    - Identify which entities are genuinely improving, which are declining,
      and which are consistently above or below the network benchmark.
Key Concepts:
    - Window functions: LAG(), AVG() OVER(), PARTITION BY
    - Year-over-year comparisons
    - Conditional logic using CASE statements
Overview:
    These queries evaluate supplier delay rates, carrier on-time performance,
    route cost trends, and warehouse utilisation year over year — giving the
    operations team a clear picture of who is getting better, who is getting
    worse, and where the business benchmark sits.
===============================================================================
*/

-- Year-over-Year Delay Rate per Supplier
-- Compares each supplier's delay rate against their own historical average
-- and against what they delivered the previous year
WITH yearly_supplier_delays AS (
    SELECT
        YEAR(f.order_date)                                              AS shipment_year,
        s.supplier_name,
        s.country,
        s.contract_tier,
        ROUND(
            COUNT(CASE WHEN f.delay_days > 0 THEN 1 END) * 100.0
            / NULLIF(COUNT(f.shipment_key), 0), 2
        )                                                               AS current_delay_rate
    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_suppliers s
        ON s.supplier_key = f.supplier_key
    WHERE f.order_date IS NOT NULL
      AND f.status     != 'Data Error'
    GROUP BY
        YEAR(f.order_date),
        s.supplier_name,
        s.country,
        s.contract_tier
)
SELECT
    shipment_year,
    supplier_name,
    country,
    contract_tier,
    current_delay_rate,
    AVG(current_delay_rate) OVER (PARTITION BY supplier_name)                           AS avg_delay_rate,
    ROUND(
        current_delay_rate -
        AVG(current_delay_rate) OVER (PARTITION BY supplier_name), 2
    )                                                                   AS diff_from_avg,
    CASE
        WHEN current_delay_rate - AVG(current_delay_rate) OVER (PARTITION BY supplier_name) > 0 THEN 'Above Avg'
        WHEN current_delay_rate - AVG(current_delay_rate) OVER (PARTITION BY supplier_name) < 0 THEN 'Below Avg'
        ELSE 'Avg'
    END                                                                 AS avg_change,
    -- Year-over-Year Analysis
    LAG(current_delay_rate) OVER (PARTITION BY supplier_name ORDER BY shipment_year)    AS py_delay_rate,
    ROUND(
        current_delay_rate -
        LAG(current_delay_rate) OVER (PARTITION BY supplier_name ORDER BY shipment_year), 2
    )                                                                   AS diff_py,
    CASE
        WHEN current_delay_rate -
             LAG(current_delay_rate) OVER (PARTITION BY supplier_name ORDER BY shipment_year) > 0 THEN 'Worsening'
        WHEN current_delay_rate -
             LAG(current_delay_rate) OVER (PARTITION BY supplier_name ORDER BY shipment_year) < 0 THEN 'Improving'
        WHEN LAG(current_delay_rate) OVER (PARTITION BY supplier_name ORDER BY shipment_year) IS NULL THEN 'Baseline'
        ELSE                                                                                              'No Change'
    END                                                                 AS py_change
FROM yearly_supplier_delays
ORDER BY supplier_name, shipment_year;

-- Year-over-Year On-Time Delivery Rate per Carrier
-- Compares each carrier's actual OTD rate against their own average
-- and flags whether they are improving or declining year over year
WITH yearly_carrier_otd AS (
    SELECT
        YEAR(f.order_date)                                              AS shipment_year,
        c.carrier_name,
        c.transport_mode,
        ROUND(
            COUNT(CASE WHEN ISNULL(f.delay_days, 0) <= 0 THEN 1 END) * 100.0
            / NULLIF(COUNT(f.shipment_key), 0), 2
        )                                                               AS current_otd_rate
    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_carriers c
        ON c.carrier_key = f.carrier_key
    WHERE f.order_date IS NOT NULL
      AND f.status     != 'Data Error'
    GROUP BY
        YEAR(f.order_date),
        c.carrier_name,
        c.transport_mode
)
SELECT
    shipment_year,
    carrier_name,
    transport_mode,
    current_otd_rate,
    AVG(current_otd_rate) OVER (PARTITION BY carrier_name)                              AS avg_otd_rate,
    ROUND(
        current_otd_rate -
        AVG(current_otd_rate) OVER (PARTITION BY carrier_name), 2
    )                                                                   AS diff_from_avg,
    CASE
        WHEN current_otd_rate - AVG(current_otd_rate) OVER (PARTITION BY carrier_name) > 0 THEN 'Above Avg'
        WHEN current_otd_rate - AVG(current_otd_rate) OVER (PARTITION BY carrier_name) < 0 THEN 'Below Avg'
        ELSE 'Avg'
    END                                                                 AS avg_change,
    -- Year-over-Year Analysis
    LAG(current_otd_rate) OVER (PARTITION BY carrier_name ORDER BY shipment_year)       AS py_otd_rate,
    ROUND(
        current_otd_rate -
        LAG(current_otd_rate) OVER (PARTITION BY carrier_name ORDER BY shipment_year), 2
    )                                                                   AS diff_py,
    CASE
        WHEN current_otd_rate -
             LAG(current_otd_rate) OVER (PARTITION BY carrier_name ORDER BY shipment_year) > 0 THEN 'Improving'
        WHEN current_otd_rate -
             LAG(current_otd_rate) OVER (PARTITION BY carrier_name ORDER BY shipment_year) < 0 THEN 'Declining'
        WHEN LAG(current_otd_rate) OVER (PARTITION BY carrier_name ORDER BY shipment_year) IS NULL THEN 'Baseline'
        ELSE                                                                                           'No Change'
    END                                                                 AS py_change
FROM yearly_carrier_otd
ORDER BY carrier_name, shipment_year;

-- Year-over-Year Total Shipment Cost per Route Region
-- Identifies whether costs on specific regional lanes are rising
-- and whether the increase correlates with worsening delay rates
WITH yearly_region_cost AS (
    SELECT
        YEAR(f.order_date)                                              AS shipment_year,
        ISNULL(r.region, 'Unknown')                                     AS route_region,
        ROUND(SUM(f.shipment_cost), 2)                                  AS current_cost,
        ROUND(
            COUNT(CASE WHEN f.delay_days > 0 THEN 1 END) * 100.0
            / NULLIF(COUNT(f.shipment_key), 0), 2
        )                                                               AS current_delay_rate
    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_routes r
        ON r.route_key = f.route_key
    WHERE f.order_date    IS NOT NULL
      AND f.shipment_cost IS NOT NULL
      AND f.status        != 'Data Error'
    GROUP BY
        YEAR(f.order_date),
        ISNULL(r.region, 'Unknown')
)
SELECT
    shipment_year,
    route_region,
    current_cost,
    current_delay_rate,
    AVG(current_cost) OVER (PARTITION BY route_region)                                  AS avg_cost,
    ROUND(
        current_cost -
        AVG(current_cost) OVER (PARTITION BY route_region), 2
    )                                                                   AS diff_from_avg,
    CASE
        WHEN current_cost - AVG(current_cost) OVER (PARTITION BY route_region) > 0 THEN 'Above Avg'
        WHEN current_cost - AVG(current_cost) OVER (PARTITION BY route_region) < 0 THEN 'Below Avg'
        ELSE 'Avg'
    END                                                                 AS avg_change,
    -- Year-over-Year Analysis
    LAG(current_cost) OVER (PARTITION BY route_region ORDER BY shipment_year)           AS py_cost,
    ROUND(
        current_cost -
        LAG(current_cost) OVER (PARTITION BY route_region ORDER BY shipment_year), 2
    )                                                                   AS diff_py,
    CASE
        WHEN current_cost -
             LAG(current_cost) OVER (PARTITION BY route_region ORDER BY shipment_year) > 0 THEN 'Increase'
        WHEN current_cost -
             LAG(current_cost) OVER (PARTITION BY route_region ORDER BY shipment_year) < 0 THEN 'Decrease'
        WHEN LAG(current_cost) OVER (PARTITION BY route_region ORDER BY shipment_year) IS NULL THEN 'Baseline'
        ELSE                                                                                        'No Change'
    END                                                                 AS py_change
FROM yearly_region_cost
ORDER BY route_region, shipment_year;

-- Year-over-Year Delay Rate per Warehouse
-- Identifies whether specific warehouses are getting better or worse
-- Cross-reference with utilisation to test the overload hypothesis
WITH yearly_warehouse_delays AS (
    SELECT
        YEAR(f.order_date)                                              AS shipment_year,
        ISNULL(w.location, 'Unknown')                                   AS warehouse_location,
        ISNULL(w.region, 'Unknown')                                     AS warehouse_region,
        ROUND(w.current_load * 100.0 / NULLIF(w.capacity, 0), 1)       AS utilisation_pct,
        ROUND(
            COUNT(CASE WHEN f.delay_days > 0 THEN 1 END) * 100.0
            / NULLIF(COUNT(f.shipment_key), 0), 2
        )                                                               AS current_delay_rate
    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_warehouses w
        ON w.warehouse_key = f.warehouse_key
    WHERE f.order_date IS NOT NULL
      AND f.status     != 'Data Error'
    GROUP BY
        YEAR(f.order_date),
        ISNULL(w.location, 'Unknown'),
        ISNULL(w.region, 'Unknown'),
        w.current_load,
        w.capacity
)
SELECT
    shipment_year,
    warehouse_location,
    warehouse_region,
    utilisation_pct,
    current_delay_rate,
    AVG(current_delay_rate) OVER (PARTITION BY warehouse_location)                      AS avg_delay_rate,
    ROUND(
        current_delay_rate -
        AVG(current_delay_rate) OVER (PARTITION BY warehouse_location), 2
    )                                                                   AS diff_from_avg,
    CASE
        WHEN current_delay_rate - AVG(current_delay_rate) OVER (PARTITION BY warehouse_location) > 0 THEN 'Above Avg'
        WHEN current_delay_rate - AVG(current_delay_rate) OVER (PARTITION BY warehouse_location) < 0 THEN 'Below Avg'
        ELSE 'Avg'
    END                                                                 AS avg_change,
    -- Year-over-Year Analysis
    LAG(current_delay_rate) OVER (PARTITION BY warehouse_location ORDER BY shipment_year) AS py_delay_rate,
    ROUND(
        current_delay_rate -
        LAG(current_delay_rate) OVER (PARTITION BY warehouse_location ORDER BY shipment_year), 2
    )                                                                   AS diff_py,
    CASE
        WHEN current_delay_rate -
             LAG(current_delay_rate) OVER (PARTITION BY warehouse_location ORDER BY shipment_year) > 0 THEN 'Worsening'
        WHEN current_delay_rate -
             LAG(current_delay_rate) OVER (PARTITION BY warehouse_location ORDER BY shipment_year) < 0 THEN 'Improving'
        WHEN LAG(current_delay_rate) OVER (PARTITION BY warehouse_location ORDER BY shipment_year) IS NULL THEN 'Baseline'
        ELSE                                                                                                   'No Change'
    END                                                                 AS py_change
FROM yearly_warehouse_delays
ORDER BY warehouse_location, shipment_year;
