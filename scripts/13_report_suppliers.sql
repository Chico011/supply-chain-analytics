/*
===============================================================================
Supplier Performance Report
===============================================================================
Purpose:
    - Consolidates key supplier delivery metrics and performance patterns
      into one clean, reusable view for Power BI to connect to directly.
Highlights:
    1. Pulls essential fields such as supplier name, country, category,
       contract tier, rating, and onboarding date.
    2. Classifies suppliers into performance tiers and account types.
    3. Aggregates supplier-level metrics:
       - total shipments
       - total delayed shipments
       - total on-time shipments
       - total shipment cost
       - average cost per shipment
       - average delay days (when late only)
       - relationship lifespan in months
    4. Derives key KPIs:
       - on-time delivery rate
       - delay rate
       - recency (months since last shipment)
       - average monthly shipments
       - cost per on-time delivery
===============================================================================
*/

IF OBJECT_ID('sc.report_suppliers', 'V') IS NOT NULL
    DROP VIEW sc.report_suppliers;
GO

CREATE VIEW sc.report_suppliers AS

WITH base_query AS (
/*---------------------------------------------------------------------------
1) Base Query: Pulls core columns from fact_shipments and ref_suppliers
   Filters out impossible date records flagged during data cleaning
---------------------------------------------------------------------------*/
    SELECT
        f.shipment_key,
        f.shipment_id,
        f.order_date,
        f.actual_date,
        f.delay_days,
        f.shipment_cost,
        f.status,
        s.supplier_key,
        s.supplier_id,
        s.supplier_name,
        s.country,
        s.category,
        s.contract_tier,
        s.rating                                                        AS supplier_rating,
        s.onboarded_date
    FROM sc.fact_shipments f
    LEFT JOIN sc.ref_suppliers s
        ON s.supplier_key = f.supplier_key
    WHERE f.order_date IS NOT NULL
      AND f.status     != 'Data Error'
),

supplier_aggregation AS (
/*---------------------------------------------------------------------------
2) Supplier Aggregations: Summarizes key metrics at the supplier level
---------------------------------------------------------------------------*/
    SELECT
        supplier_key,
        supplier_id,
        supplier_name,
        country,
        category,
        contract_tier,
        supplier_rating,
        onboarded_date,
        COUNT(shipment_key)                                             AS total_shipments,
        COUNT(CASE WHEN delay_days > 0 THEN 1 END)                      AS total_delayed,
        COUNT(CASE WHEN ISNULL(delay_days, 0) <= 0 THEN 1 END)          AS total_on_time,
        ROUND(SUM(shipment_cost), 2)                                    AS total_cost,
        ROUND(AVG(CAST(shipment_cost AS FLOAT)), 2)                     AS avg_cost_per_shipment,
        ROUND(
            AVG(CASE WHEN delay_days > 0
                     THEN CAST(delay_days AS FLOAT) END), 1
        )                                                               AS avg_delay_days_when_late,
        MAX(order_date)                                                 AS last_shipment_date,
        DATEDIFF(month, MIN(order_date), MAX(order_date))               AS lifespan
    FROM base_query
    GROUP BY
        supplier_key,
        supplier_id,
        supplier_name,
        country,
        category,
        contract_tier,
        supplier_rating,
        onboarded_date
)

/*---------------------------------------------------------------------------
3) Final Query: Combines all supplier results and derives KPIs
---------------------------------------------------------------------------*/
SELECT
    supplier_key,
    supplier_id,
    supplier_name,
    country,
    category,
    contract_tier,
    supplier_rating,
    onboarded_date,
    last_shipment_date,
    DATEDIFF(month, last_shipment_date, GETDATE())                      AS recency_months,
    total_shipments,
    total_delayed,
    total_on_time,
    total_cost,
    avg_cost_per_shipment,
    avg_delay_days_when_late,
    lifespan,

    -- On-time delivery rate
    ROUND(
        CAST(total_on_time AS FLOAT)
        / NULLIF(total_shipments, 0) * 100, 2
    )                                                                   AS on_time_rate_pct,

    -- Delay rate
    ROUND(
        CAST(total_delayed AS FLOAT)
        / NULLIF(total_shipments, 0) * 100, 2
    )                                                                   AS delay_rate_pct,

    -- Average monthly shipments over supplier lifespan
    CASE
        WHEN lifespan = 0 THEN total_shipments
        ELSE total_shipments / lifespan
    END                                                                 AS avg_monthly_shipments,

    -- Cost per on-time delivery — measures true value of the supplier
    ROUND(
        CAST(total_cost AS FLOAT)
        / NULLIF(total_on_time, 0), 2
    )                                                                   AS cost_per_on_time_delivery,

    -- Supplier performance tier classification
    CASE
        WHEN ROUND(CAST(total_delayed AS FLOAT) / NULLIF(total_shipments, 0) * 100, 2) >= 40 THEN 'Critical'
        WHEN ROUND(CAST(total_delayed AS FLOAT) / NULLIF(total_shipments, 0) * 100, 2) >= 25 THEN 'At Risk'
        WHEN ROUND(CAST(total_delayed AS FLOAT) / NULLIF(total_shipments, 0) * 100, 2) >= 10 THEN 'Monitor'
        ELSE                                                                                       'Healthy'
    END                                                                 AS performance_tier,

    -- Supplier relationship segment based on volume and lifespan
    CASE
        WHEN lifespan >= 18 AND total_shipments > 100   THEN 'Strategic Partner'
        WHEN lifespan >= 12 AND total_shipments > 50    THEN 'Key Supplier'
        WHEN lifespan >= 6  AND total_shipments > 20    THEN 'Developing Supplier'
        ELSE                                                 'New / Low Volume'
    END                                                                 AS relationship_segment,

    -- Contract account type
    CASE
        WHEN contract_tier = 'Platinum'     THEN 'Strategic'
        WHEN contract_tier = 'Gold'         THEN 'Key Account'
        WHEN contract_tier = 'Silver'       THEN 'Standard'
        WHEN contract_tier = 'Bronze'       THEN 'Basic'
        ELSE                                     'Unclassified'
    END                                                                 AS account_type

FROM supplier_aggregation;
GO
