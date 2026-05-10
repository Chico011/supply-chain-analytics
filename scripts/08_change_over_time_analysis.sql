/*
===============================================================================
Change Over Time Analysis
===============================================================================
Objective:
    - Examine how shipment volumes, delay rates, and costs evolve over time.
    - Detect whether the delay problem is structural (always bad) or seasonal
      (peaks at specific times of year) — each requires a different fix.
    - Identify months and quarters where the network is most exposed so the
      operations team can plan capacity and staffing in advance.
Techniques Used:
    - Date functions (YEAR, MONTH, DATETRUNC, FORMAT, DATEPART)
    - Aggregation (SUM, COUNT, AVG)
    - LAG() for month-over-month change detection
    - CASE for seasonal pattern classification
Summary:
    The queries below evaluate shipment performance across monthly, quarterly,
    and yearly intervals — revealing whether delays are trending up or down,
    which seasons drive the highest cost exposure, and whether the network
    is improving or deteriorating over time.
===============================================================================
*/

-- Analyse shipment volume, delay rate, and cost performance over time
-- Quick Date Functions
SELECT
    YEAR(order_date)                                                    AS shipment_year,
    MONTH(order_date)                                                   AS shipment_month,
    COUNT(shipment_key)                                                 AS total_shipments,
    COUNT(CASE WHEN delay_days > 0 THEN 1 END)                          AS delayed_shipments,
    ROUND(
        COUNT(CASE WHEN delay_days > 0 THEN 1 END) * 100.0
        / NULLIF(COUNT(shipment_key), 0), 2
    )                                                                   AS delay_rate_pct,
    ROUND(SUM(shipment_cost), 2)                                        AS total_cost,
    ROUND(AVG(shipment_cost), 2)                                        AS avg_cost_per_shipment,
    ROUND(AVG(CASE WHEN delay_days > 0
                   THEN CAST(delay_days AS FLOAT) END), 1)              AS avg_delay_days_when_late
FROM sc.fact_shipments
WHERE order_date IS NOT NULL
  AND status != 'Data Error'
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date);

-- DATETRUNC() version — cleaner for Power BI direct connection
SELECT
    DATETRUNC(month, order_date)                                        AS shipment_month,
    COUNT(shipment_key)                                                 AS total_shipments,
    COUNT(CASE WHEN delay_days > 0 THEN 1 END)                          AS delayed_shipments,
    ROUND(
        COUNT(CASE WHEN delay_days > 0 THEN 1 END) * 100.0
        / NULLIF(COUNT(shipment_key), 0), 2
    )                                                                   AS delay_rate_pct,
    ROUND(SUM(shipment_cost), 2)                                        AS total_cost,
    ROUND(AVG(CAST(shipment_cost AS FLOAT)), 2)                         AS avg_cost_per_shipment
FROM sc.fact_shipments
WHERE order_date IS NOT NULL
  AND status != 'Data Error'
GROUP BY DATETRUNC(month, order_date)
ORDER BY DATETRUNC(month, order_date);

-- FORMAT() version — human-readable labels for presentations and reports
SELECT
    FORMAT(order_date, 'yyyy-MMM')                                      AS shipment_month,
    COUNT(shipment_key)                                                 AS total_shipments,
    COUNT(CASE WHEN delay_days > 0 THEN 1 END)                          AS delayed_shipments,
    ROUND(
        COUNT(CASE WHEN delay_days > 0 THEN 1 END) * 100.0
        / NULLIF(COUNT(shipment_key), 0), 2
    )                                                                   AS delay_rate_pct,
    ROUND(SUM(shipment_cost), 2)                                        AS total_cost
FROM sc.fact_shipments
WHERE order_date IS NOT NULL
  AND status != 'Data Error'
GROUP BY FORMAT(order_date, 'yyyy-MMM')
ORDER BY FORMAT(order_date, 'yyyy-MMM');

-- Analyse delay rate and cost trends by quarter
-- Quarterly view reveals seasonal patterns that monthly data can obscure
SELECT
    YEAR(order_date)                                                    AS shipment_year,
    DATEPART(QUARTER, order_date)                                       AS shipment_quarter,
    COUNT(shipment_key)                                                 AS total_shipments,
    COUNT(CASE WHEN delay_days > 0 THEN 1 END)                          AS delayed_shipments,
    ROUND(
        COUNT(CASE WHEN delay_days > 0 THEN 1 END) * 100.0
        / NULLIF(COUNT(shipment_key), 0), 2
    )                                                                   AS delay_rate_pct,
    ROUND(SUM(shipment_cost), 2)                                        AS total_cost,
    -- Classify quarter performance against a 30% delay threshold
    CASE
        WHEN COUNT(CASE WHEN delay_days > 0 THEN 1 END) * 100.0
             / NULLIF(COUNT(shipment_key), 0) >= 35 THEN 'High Risk Quarter'
        WHEN COUNT(CASE WHEN delay_days > 0 THEN 1 END) * 100.0
             / NULLIF(COUNT(shipment_key), 0) >= 25 THEN 'Elevated Risk Quarter'
        ELSE                                              'Normal Quarter'
    END                                                                 AS quarter_risk_flag
FROM sc.fact_shipments
WHERE order_date IS NOT NULL
  AND status != 'Data Error'
GROUP BY YEAR(order_date), DATEPART(QUARTER, order_date)
ORDER BY YEAR(order_date), DATEPART(QUARTER, order_date);

-- Track total shipment cost and delay rate year over year
-- This is the headline trend that goes on the executive dashboard
SELECT
    YEAR(order_date)                                                    AS shipment_year,
    COUNT(shipment_key)                                                 AS total_shipments,
    COUNT(CASE WHEN delay_days > 0 THEN 1 END)                          AS delayed_shipments,
    ROUND(
        COUNT(CASE WHEN delay_days > 0 THEN 1 END) * 100.0
        / NULLIF(COUNT(shipment_key), 0), 2
    )                                                                   AS delay_rate_pct,
    ROUND(SUM(shipment_cost), 2)                                        AS total_cost,
    ROUND(AVG(shipment_cost), 2)                                        AS avg_cost_per_shipment
FROM sc.fact_shipments
WHERE order_date IS NOT NULL
  AND status != 'Data Error'
GROUP BY YEAR(order_date)
ORDER BY YEAR(order_date);

-- Track month-over-month change in delay rate using LAG()
-- Tells the operations team whether the network is improving or getting worse
-- each month compared to the previous month
WITH monthly_delays AS (
    SELECT
        DATETRUNC(month, order_date)                                    AS shipment_month,
        ROUND(
            COUNT(CASE WHEN delay_days > 0 THEN 1 END) * 100.0
            / NULLIF(COUNT(shipment_key), 0), 2
        )                                                               AS delay_rate_pct,
        ROUND(SUM(shipment_cost), 2)                                    AS monthly_cost
    FROM sc.fact_shipments
    WHERE order_date IS NOT NULL
      AND status != 'Data Error'
    GROUP BY DATETRUNC(month, order_date)
)
SELECT
    shipment_month,
    delay_rate_pct,
    monthly_cost,
    LAG(delay_rate_pct) OVER (ORDER BY shipment_month)                  AS prev_month_delay_rate,
    ROUND(
        delay_rate_pct -
        LAG(delay_rate_pct) OVER (ORDER BY shipment_month), 2
    )                                                                   AS mom_delay_change,
    CASE
        WHEN delay_rate_pct -
             LAG(delay_rate_pct) OVER (ORDER BY shipment_month) > 0    THEN 'Worsening'
        WHEN delay_rate_pct -
             LAG(delay_rate_pct) OVER (ORDER BY shipment_month) < 0    THEN 'Improving'
        WHEN LAG(delay_rate_pct) OVER (ORDER BY shipment_month) IS NULL THEN 'Baseline'
        ELSE                                                                 'No Change'
    END                                                                 AS trend_direction
FROM monthly_delays
ORDER BY shipment_month;

-- Track how delay rates shift by transport mode over time
-- Identifies whether a specific carrier mode is deteriorating
SELECT
    YEAR(f.order_date)                                                  AS shipment_year,
    ISNULL(c.transport_mode, 'Unknown')                                 AS transport_mode,
    COUNT(f.shipment_key)                                               AS total_shipments,
    ROUND(
        COUNT(CASE WHEN f.delay_days > 0 THEN 1 END) * 100.0
        / NULLIF(COUNT(f.shipment_key), 0), 2
    )                                                                   AS delay_rate_pct,
    ROUND(SUM(f.shipment_cost), 2)                                      AS total_cost
FROM sc.fact_shipments f
LEFT JOIN sc.ref_carriers c
    ON c.carrier_key = f.carrier_key
WHERE f.order_date IS NOT NULL
  AND f.status != 'Data Error'
GROUP BY YEAR(f.order_date), ISNULL(c.transport_mode, 'Unknown')
ORDER BY YEAR(f.order_date), transport_mode;

-- Track how delay rates shift by route region over time
-- Pinpoints whether a specific region is driving the overall trend
SELECT
    YEAR(f.order_date)                                                  AS shipment_year,
    ISNULL(r.region, 'Unknown')                                         AS route_region,
    COUNT(f.shipment_key)                                               AS total_shipments,
    ROUND(
        COUNT(CASE WHEN f.delay_days > 0 THEN 1 END) * 100.0
        / NULLIF(COUNT(f.shipment_key), 0), 2
    )                                                                   AS delay_rate_pct,
    ROUND(SUM(f.shipment_cost), 2)                                      AS total_cost
FROM sc.fact_shipments f
LEFT JOIN sc.ref_routes r
    ON r.route_key = f.route_key
WHERE f.order_date IS NOT NULL
  AND f.status != 'Data Error'
GROUP BY YEAR(f.order_date), ISNULL(r.region, 'Unknown')
ORDER BY YEAR(f.order_date), route_region;
