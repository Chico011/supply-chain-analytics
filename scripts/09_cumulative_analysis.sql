/*
===============================================================================
Cumulative Performance Analysis
===============================================================================
Objective:
    - Compute progressive totals and rolling averages for key supply chain
      indicators to monitor how cost exposure and delay pressure build over time.
    - Reveal whether the network is accumulating risk faster or slower
      than previous periods.
    - Provide the rolling trend lines that power the executive dashboard
      in Power BI.
Techniques Used:
    - Window functions: SUM() OVER(), AVG() OVER()
    - Running totals and moving averages
    - ROWS BETWEEN for controlled rolling window calculations
Summary:
    The queries below evaluate shipment cost, delay volume, and on-time
    performance over time and apply window functions to highlight cumulative
    network exposure — showing leadership exactly how the problem has
    grown and whether recent months are moving in the right direction.
===============================================================================
*/

-- Calculate total shipment cost per month
-- and the running total of cost exposure over time
SELECT
    shipment_month,
    monthly_shipments,
    monthly_cost,
    delayed_shipments,
    SUM(monthly_cost)           OVER (ORDER BY shipment_month)          AS running_total_cost,
    AVG(monthly_delay_rate)     OVER (ORDER BY shipment_month)          AS moving_avg_delay_rate
FROM
(
    SELECT
        DATETRUNC(month, order_date)                                    AS shipment_month,
        COUNT(shipment_key)                                             AS monthly_shipments,
        COUNT(CASE WHEN delay_days > 0 THEN 1 END)                      AS delayed_shipments,
        ROUND(SUM(shipment_cost), 2)                                    AS monthly_cost,
        ROUND(
            COUNT(CASE WHEN delay_days > 0 THEN 1 END) * 100.0
            / NULLIF(COUNT(shipment_key), 0), 2
        )                                                               AS monthly_delay_rate
    FROM sc.fact_shipments
    WHERE order_date    IS NOT NULL
      AND shipment_cost IS NOT NULL
      AND status        != 'Data Error'
    GROUP BY DATETRUNC(month, order_date)
) t
ORDER BY shipment_month;

-- Calculate total delayed shipments per month
-- and the running total of delays accumulating over time
-- 3-month rolling average smooths out noise for cleaner trend reading
SELECT
    shipment_month,
    monthly_delayed,
    SUM(monthly_delayed)        OVER (ORDER BY shipment_month)          AS running_total_delayed,
    AVG(CAST(monthly_delayed AS FLOAT))
        OVER (
            ORDER BY shipment_month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        )                                                               AS rolling_3m_avg_delayed
FROM
(
    SELECT
        DATETRUNC(month, order_date)                                    AS shipment_month,
        COUNT(CASE WHEN delay_days > 0 THEN 1 END)                      AS monthly_delayed
    FROM sc.fact_shipments
    WHERE order_date IS NOT NULL
      AND status     != 'Data Error'
    GROUP BY DATETRUNC(month, order_date)
) t
ORDER BY shipment_month;

-- Calculate total shipment cost per year
-- and the running total of network cost across all years
SELECT
    shipment_year,
    yearly_shipments,
    yearly_cost,
    yearly_delayed,
    SUM(yearly_cost)            OVER (ORDER BY shipment_year)           AS running_total_cost,
    AVG(CAST(yearly_cost AS FLOAT))
        OVER (ORDER BY shipment_year)                                   AS moving_avg_yearly_cost,
    AVG(avg_delay_days)         OVER (ORDER BY shipment_year)           AS moving_avg_delay_days
FROM
(
    SELECT
        DATETRUNC(year, order_date)                                     AS shipment_year,
        COUNT(shipment_key)                                             AS yearly_shipments,
        COUNT(CASE WHEN delay_days > 0 THEN 1 END)                      AS yearly_delayed,
        ROUND(SUM(shipment_cost), 2)                                    AS yearly_cost,
        ROUND(
            AVG(CASE WHEN delay_days > 0
                     THEN CAST(delay_days AS FLOAT) END), 2
        )                                                               AS avg_delay_days
    FROM sc.fact_shipments
    WHERE order_date    IS NOT NULL
      AND shipment_cost IS NOT NULL
      AND status        != 'Data Error'
    GROUP BY DATETRUNC(year, order_date)
) t
ORDER BY shipment_year;

-- Calculate cumulative on-time shipments vs delayed shipments per month
-- Shows whether the gap between on-time and delayed is widening or closing
SELECT
    shipment_month,
    monthly_on_time,
    monthly_delayed,
    SUM(monthly_on_time)        OVER (ORDER BY shipment_month)          AS running_total_on_time,
    SUM(monthly_delayed)        OVER (ORDER BY shipment_month)          AS running_total_delayed,
    -- Running on-time rate across all months so far
    ROUND(
        SUM(monthly_on_time) OVER (ORDER BY shipment_month) * 100.0
        / NULLIF(
            SUM(monthly_on_time)    OVER (ORDER BY shipment_month)
            + SUM(monthly_delayed)  OVER (ORDER BY shipment_month), 0
        ), 2
    )                                                                   AS cumulative_otd_rate_pct
FROM
(
    SELECT
        DATETRUNC(month, order_date)                                    AS shipment_month,
        COUNT(CASE WHEN ISNULL(delay_days, 0) <= 0 THEN 1 END)          AS monthly_on_time,
        COUNT(CASE WHEN delay_days > 0 THEN 1 END)                      AS monthly_delayed
    FROM sc.fact_shipments
    WHERE order_date IS NOT NULL
      AND status     != 'Data Error'
    GROUP BY DATETRUNC(month, order_date)
) t
ORDER BY shipment_month;

-- Calculate cumulative cost of delayed shipments per year
-- This is the financial exposure figure — how much delay has cost the business
-- cumulatively — the number that gets executive attention
SELECT
    shipment_year,
    cost_of_delays,
    total_cost,
    SUM(cost_of_delays)         OVER (ORDER BY shipment_year)           AS running_cost_of_delays,
    SUM(total_cost)             OVER (ORDER BY shipment_year)           AS running_total_cost,
    -- What percentage of total cumulative cost is attributed to delays?
    ROUND(
        SUM(cost_of_delays) OVER (ORDER BY shipment_year) * 100.0
        / NULLIF(SUM(total_cost) OVER (ORDER BY shipment_year), 0), 2
    )                                                                   AS cumulative_delay_cost_pct
FROM
(
    SELECT
        DATETRUNC(year, order_date)                                     AS shipment_year,
        ROUND(
            SUM(CASE WHEN delay_days > 0
                     THEN shipment_cost ELSE 0 END), 2
        )                                                               AS cost_of_delays,
        ROUND(SUM(shipment_cost), 2)                                    AS total_cost
    FROM sc.fact_shipments
    WHERE order_date    IS NOT NULL
      AND shipment_cost IS NOT NULL
      AND status        != 'Data Error'
    GROUP BY DATETRUNC(year, order_date)
) t
ORDER BY shipment_year;
