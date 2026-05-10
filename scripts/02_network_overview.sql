/*
===============================================================================
Network Overview
===============================================================================
Purpose:
    - Dig into the reference tables to understand the unique values and
      categories that make up the supply chain network.
    - Identify the range of suppliers, carriers, routes, warehouses, and
      products before any analysis begins.
    - Flag early signs of dirty data such as nulls, blanks, and inconsistent
      casing that will need to be handled in the cleaning script.
SQL Functions Used:
    - DISTINCT
    - ORDER BY
    - ISNULL, TRIM
===============================================================================
*/

-- Find all the distinct countries suppliers operate from
SELECT DISTINCT
    country
FROM sc.ref_suppliers
ORDER BY country;

-- Find all the distinct supplier categories in the network
SELECT DISTINCT
    category
FROM sc.ref_suppliers
ORDER BY category;

-- Find all the distinct contract tiers assigned to suppliers
SELECT DISTINCT
    contract_tier
FROM sc.ref_suppliers
ORDER BY contract_tier;

-- Break down the supplier network by country, category, and contract tier
SELECT DISTINCT
    country,
    category,
    contract_tier
FROM sc.ref_suppliers
ORDER BY country, category, contract_tier;

-- Find all the distinct supplier statuses in the network
SELECT DISTINCT
    status
FROM sc.ref_suppliers
ORDER BY status;

-- Check for suppliers with null or blank names — dirty data flag
SELECT DISTINCT
    supplier_key,
    supplier_id,
    supplier_name
FROM sc.ref_suppliers
WHERE TRIM(ISNULL(supplier_name, '')) = '';

-- Find all the distinct transport modes used by carriers
SELECT DISTINCT
    transport_mode
FROM sc.ref_carriers
ORDER BY transport_mode;

-- Find all the distinct coverage regions across all carriers
SELECT DISTINCT
    coverage_region
FROM sc.ref_carriers
ORDER BY coverage_region;

-- Break down the carrier network by transport mode and coverage region
SELECT DISTINCT
    transport_mode,
    coverage_region
FROM sc.ref_carriers
ORDER BY transport_mode, coverage_region;

-- Find all the distinct regions covered by routes in the network
SELECT DISTINCT
    region
FROM sc.ref_routes
ORDER BY region;

-- Find all the distinct origin cities across all routes
SELECT DISTINCT
    origin
FROM sc.ref_routes
ORDER BY origin;

-- Find all the distinct destination cities across all routes
SELECT DISTINCT
    destination
FROM sc.ref_routes
ORDER BY destination;

-- Find all the distinct warehouse regions in the network
SELECT DISTINCT
    region
FROM sc.ref_warehouses
ORDER BY region;

-- Find all the distinct countries where warehouses are located
SELECT DISTINCT
    country
FROM sc.ref_warehouses
ORDER BY country;

-- Find all the distinct product categories being shipped
SELECT DISTINCT
    category
FROM sc.ref_products
ORDER BY category;

-- Find all the distinct fragility levels across all products
SELECT DISTINCT
    fragility
FROM sc.ref_products
ORDER BY fragility;

-- Break down the product catalogue by category and fragility level
SELECT DISTINCT
    category,
    fragility
FROM sc.ref_products
ORDER BY category, fragility;

-- Find all the distinct shipment statuses recorded in the fact table
SELECT DISTINCT
    status
FROM sc.fact_shipments
ORDER BY status;

-- Check for shipments with null or blank status — dirty data flag
SELECT DISTINCT
    shipment_key,
    shipment_id,
    status
FROM sc.fact_shipments
WHERE TRIM(ISNULL(status, '')) = '';

-- Check for shipments where actual_date is missing — incomplete records flag
SELECT
    COUNT(*) AS shipments_missing_actual_date
FROM sc.fact_shipments
WHERE TRIM(ISNULL(CAST(actual_date AS NVARCHAR), '')) = '';

-- Check for shipments where delay_days is null but actual_date exists
-- These records need delay_days recalculated in the cleaning script
SELECT
    COUNT(*) AS delay_days_not_calculated
FROM sc.fact_shipments
WHERE delay_days IS NULL
  AND actual_date IS NOT NULL;
