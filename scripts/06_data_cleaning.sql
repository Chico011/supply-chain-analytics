/*
===============================================================================
Data Cleaning & Dirty Data Handling
===============================================================================
Purpose:
    - Identify, document, and resolve all data quality issues discovered
      during the exploration scripts (01 through 05).
    - Ensure the fact and reference tables are clean, consistent, and
      trustworthy before any analytical queries are run.
    - A single bad record in a business report destroys credibility.
      This script exists so that never happens.
Issues Resolved:
    1. Null and blank values in supplier_name, country, category,
       contract_tier, rating, status across ref_suppliers
    2. Inconsistent casing on country and transport_mode columns
    3. Null and blank values in carrier_name, transport_mode,
       on_time_rate, avg_cost_per_km across ref_carriers
    4. Null and blank origin, destination, region in ref_routes
    5. Missing delay_days where actual_date exists in fact_shipments
    6. Null and blank status, shipment_cost, weight_kg in fact_shipments
    7. Impossible date records where actual_date < order_date
SQL Functions Used:
    - ISNULL(), NULLIF(), TRIM(), UPPER(), LEN()
    - TRY_CAST() for safe type conversion
    - DATEDIFF() to recalculate missing delay_days
    - UPDATE statements to fix dirty records in place
    - SELECT COUNT() checks before and after every fix
===============================================================================
*/

-- =============================================================================
-- STEP 1: AUDIT — Count all dirty records before cleaning begins
-- Run this block first so you have a before snapshot to compare against
-- =============================================================================

-- How many suppliers have a null or blank supplier_name?
SELECT COUNT(*) AS suppliers_missing_name
FROM sc.ref_suppliers
WHERE TRIM(ISNULL(supplier_name, '')) = '';

-- How many suppliers have a null or blank country?
SELECT COUNT(*) AS suppliers_missing_country
FROM sc.ref_suppliers
WHERE TRIM(ISNULL(country, '')) = '';

-- How many suppliers have a null or blank contract_tier?
SELECT COUNT(*) AS suppliers_missing_tier
FROM sc.ref_suppliers
WHERE TRIM(ISNULL(contract_tier, '')) = '';

-- How many suppliers have a null or blank rating?
SELECT COUNT(*) AS suppliers_missing_rating
FROM sc.ref_suppliers
WHERE TRIM(ISNULL(CAST(rating AS NVARCHAR), '')) = '';

-- How many suppliers have a null or blank status?
SELECT COUNT(*) AS suppliers_missing_status
FROM sc.ref_suppliers
WHERE TRIM(ISNULL(status, '')) = '';

-- How many carriers have a null or blank transport_mode?
SELECT COUNT(*) AS carriers_missing_mode
FROM sc.ref_carriers
WHERE TRIM(ISNULL(transport_mode, '')) = '';

-- How many carriers have a null or blank on_time_rate?
SELECT COUNT(*) AS carriers_missing_otd_rate
FROM sc.ref_carriers
WHERE on_time_rate IS NULL;

-- How many routes have a null or blank origin or destination?
SELECT COUNT(*) AS routes_missing_origin_or_destination
FROM sc.ref_routes
WHERE TRIM(ISNULL(origin, '')) = ''
   OR TRIM(ISNULL(destination, '')) = '';

-- How many shipments are missing an actual_date?
SELECT COUNT(*) AS shipments_missing_actual_date
FROM sc.fact_shipments
WHERE actual_date IS NULL;

-- How many shipments have delay_days null but actual_date exists?
-- These need delay_days recalculated
SELECT COUNT(*) AS shipments_delay_not_calculated
FROM sc.fact_shipments
WHERE delay_days IS NULL
  AND actual_date IS NOT NULL;

-- How many shipments have an impossible date (actual before order)?
SELECT COUNT(*) AS impossible_date_records
FROM sc.fact_shipments
WHERE actual_date < order_date;

-- How many shipments are missing shipment_cost?
SELECT COUNT(*) AS shipments_missing_cost
FROM sc.fact_shipments
WHERE shipment_cost IS NULL;

-- How many shipments have a null or blank status?
SELECT COUNT(*) AS shipments_missing_status
FROM sc.fact_shipments
WHERE TRIM(ISNULL(status, '')) = '';

-- =============================================================================
-- STEP 2: CLEAN ref_suppliers
-- =============================================================================

-- Replace null or blank supplier_name with 'Unknown Supplier'
UPDATE sc.ref_suppliers
SET supplier_name = 'Unknown Supplier'
WHERE TRIM(ISNULL(supplier_name, '')) = '';

-- Replace null or blank country with 'Unknown'
UPDATE sc.ref_suppliers
SET country = 'Unknown'
WHERE TRIM(ISNULL(country, '')) = '';

-- Standardise country casing — Title Case using UPPER on first letter
-- Fixes records like 'GERMANY' or 'germany' → 'Germany'
UPDATE sc.ref_suppliers
SET country = UPPER(LEFT(TRIM(country), 1)) + LOWER(SUBSTRING(TRIM(country), 2, LEN(country)))
WHERE country IS NOT NULL
  AND TRIM(country) != '';

-- Replace null or blank category with 'Unknown'
UPDATE sc.ref_suppliers
SET category = 'Unknown'
WHERE TRIM(ISNULL(category, '')) = '';

-- Replace null or blank contract_tier with 'Unknown'
UPDATE sc.ref_suppliers
SET contract_tier = 'Unknown'
WHERE TRIM(ISNULL(contract_tier, '')) = '';

-- Replace null rating with 0.0 — flagged as unrated, not removed
UPDATE sc.ref_suppliers
SET rating = 0.0
WHERE rating IS NULL;

-- Replace null or blank status with 'Unknown'
UPDATE sc.ref_suppliers
SET status = 'Unknown'
WHERE TRIM(ISNULL(status, '')) = '';

-- Confirm ref_suppliers is clean
SELECT COUNT(*) AS remaining_dirty_supplier_records
FROM sc.ref_suppliers
WHERE TRIM(ISNULL(supplier_name, '')) = ''
   OR TRIM(ISNULL(country, '')) = ''
   OR TRIM(ISNULL(contract_tier, '')) = ''
   OR TRIM(ISNULL(status, '')) = '';

-- =============================================================================
-- STEP 3: CLEAN ref_carriers
-- =============================================================================

-- Replace null or blank carrier_name with 'Unknown Carrier'
UPDATE sc.ref_carriers
SET carrier_name = 'Unknown Carrier'
WHERE TRIM(ISNULL(carrier_name, '')) = '';

-- Replace null or blank transport_mode with 'Unknown'
UPDATE sc.ref_carriers
SET transport_mode = 'Unknown'
WHERE TRIM(ISNULL(transport_mode, '')) = '';

-- Standardise transport_mode casing — Title Case
-- Fixes records like 'road', 'ROAD' → 'Road'
UPDATE sc.ref_carriers
SET transport_mode = UPPER(LEFT(TRIM(transport_mode), 1)) + LOWER(SUBSTRING(TRIM(transport_mode), 2, LEN(transport_mode)))
WHERE transport_mode IS NOT NULL
  AND TRIM(transport_mode) != ''
  AND transport_mode != 'Unknown';

-- Replace null on_time_rate with 0.00 — flagged as unrated
UPDATE sc.ref_carriers
SET on_time_rate = 0.00
WHERE on_time_rate IS NULL;

-- Replace null avg_cost_per_km with 0.00 — flagged as unknown cost
UPDATE sc.ref_carriers
SET avg_cost_per_km = 0.00
WHERE avg_cost_per_km IS NULL;

-- Replace null or blank coverage_region with 'Unknown'
UPDATE sc.ref_carriers
SET coverage_region = 'Unknown'
WHERE TRIM(ISNULL(coverage_region, '')) = '';

-- Replace null or blank status with 'Unknown'
UPDATE sc.ref_carriers
SET status = 'Unknown'
WHERE TRIM(ISNULL(status, '')) = '';

-- Confirm ref_carriers is clean
SELECT COUNT(*) AS remaining_dirty_carrier_records
FROM sc.ref_carriers
WHERE TRIM(ISNULL(carrier_name, '')) = ''
   OR TRIM(ISNULL(transport_mode, '')) = ''
   OR on_time_rate IS NULL
   OR avg_cost_per_km IS NULL;

-- =============================================================================
-- STEP 4: CLEAN ref_routes
-- =============================================================================

-- Replace null or blank origin with 'Unknown'
UPDATE sc.ref_routes
SET origin = 'Unknown'
WHERE TRIM(ISNULL(origin, '')) = '';

-- Replace null or blank destination with 'Unknown'
UPDATE sc.ref_routes
SET destination = 'Unknown'
WHERE TRIM(ISNULL(destination, '')) = '';

-- Replace null or blank region with 'Unknown'
UPDATE sc.ref_routes
SET region = 'Unknown'
WHERE TRIM(ISNULL(region, '')) = '';

-- Replace null distance_km with 0 — flagged as unknown distance
UPDATE sc.ref_routes
SET distance_km = 0
WHERE distance_km IS NULL;

-- Replace null avg_transit_days with 0 — flagged as unknown transit time
UPDATE sc.ref_routes
SET avg_transit_days = 0
WHERE avg_transit_days IS NULL;

-- Confirm ref_routes is clean
SELECT COUNT(*) AS remaining_dirty_route_records
FROM sc.ref_routes
WHERE TRIM(ISNULL(origin, '')) = ''
   OR TRIM(ISNULL(destination, '')) = ''
   OR TRIM(ISNULL(region, '')) = '';

-- =============================================================================
-- STEP 5: CLEAN ref_products
-- =============================================================================

-- Replace null or blank product_name with 'Unknown Product'
UPDATE sc.ref_products
SET product_name = 'Unknown Product'
WHERE TRIM(ISNULL(product_name, '')) = '';

-- Replace null or blank category with 'Unknown'
UPDATE sc.ref_products
SET category = 'Unknown'
WHERE TRIM(ISNULL(category, '')) = '';

-- Replace null weight_kg with 0.00 — flagged as unweighed
UPDATE sc.ref_products
SET weight_kg = 0.00
WHERE weight_kg IS NULL;

-- Replace null or blank fragility with 'Unknown'
UPDATE sc.ref_products
SET fragility = 'Unknown'
WHERE TRIM(ISNULL(fragility, '')) = '';

-- Replace null value_usd with 0.00 — flagged as unvalued
UPDATE sc.ref_products
SET value_usd = 0.00
WHERE value_usd IS NULL;

-- Confirm ref_products is clean
SELECT COUNT(*) AS remaining_dirty_product_records
FROM sc.ref_products
WHERE TRIM(ISNULL(product_name, '')) = ''
   OR TRIM(ISNULL(category, '')) = ''
   OR TRIM(ISNULL(fragility, '')) = '';

-- =============================================================================
-- STEP 6: CLEAN fact_shipments
-- =============================================================================

-- Recalculate delay_days where it is null but actual_date exists
-- delay_days = number of days between promised_date and actual_date
-- Negative values mean early delivery, positive means late
UPDATE sc.fact_shipments
SET delay_days = DATEDIFF(DAY, promised_date, actual_date)
WHERE delay_days IS NULL
  AND actual_date  IS NOT NULL
  AND promised_date IS NOT NULL;

-- Flag shipments with impossible dates as 'Data Error' in status
-- Do NOT delete these — flag them so they are excluded from analysis
-- but visible for audit purposes
UPDATE sc.fact_shipments
SET status = 'Data Error'
WHERE actual_date < order_date
  AND actual_date IS NOT NULL;

-- Replace null or blank status with 'Unknown'
UPDATE sc.fact_shipments
SET status = 'Unknown'
WHERE TRIM(ISNULL(status, '')) = '';

-- Replace null shipment_cost with 0.00 — flagged as uncosted
UPDATE sc.fact_shipments
SET shipment_cost = 0.00
WHERE shipment_cost IS NULL;

-- Replace null weight_kg with 0.00 — flagged as unweighed
UPDATE sc.fact_shipments
SET weight_kg = 0.00
WHERE weight_kg IS NULL;

-- Replace null quantity with 0 — flagged as unrecorded
UPDATE sc.fact_shipments
SET quantity = 0
WHERE quantity IS NULL;

-- Confirm fact_shipments delay_days recalculation is complete
SELECT COUNT(*) AS delay_days_still_null_with_actual_date
FROM sc.fact_shipments
WHERE delay_days IS NULL
  AND actual_date IS NOT NULL;

-- Confirm no remaining blank statuses
SELECT COUNT(*) AS remaining_blank_statuses
FROM sc.fact_shipments
WHERE TRIM(ISNULL(status, '')) = '';

-- Confirm no remaining null costs
SELECT COUNT(*) AS remaining_null_costs
FROM sc.fact_shipments
WHERE shipment_cost IS NULL;

-- =============================================================================
-- STEP 7: FINAL AUDIT — Confirm everything is clean
-- Run this block last and compare against the Step 1 snapshot
-- All counts should return 0
-- =============================================================================

SELECT 'ref_suppliers — dirty names'         AS check_name, COUNT(*) AS remaining_issues FROM sc.ref_suppliers  WHERE TRIM(ISNULL(supplier_name, '')) = ''
UNION ALL
SELECT 'ref_suppliers — dirty countries',    COUNT(*) FROM sc.ref_suppliers  WHERE TRIM(ISNULL(country, '')) = ''
UNION ALL
SELECT 'ref_carriers — dirty modes',         COUNT(*) FROM sc.ref_carriers   WHERE TRIM(ISNULL(transport_mode, '')) = ''
UNION ALL
SELECT 'ref_carriers — null on_time_rate',   COUNT(*) FROM sc.ref_carriers   WHERE on_time_rate IS NULL
UNION ALL
SELECT 'ref_routes — dirty origins',         COUNT(*) FROM sc.ref_routes     WHERE TRIM(ISNULL(origin, '')) = ''
UNION ALL
SELECT 'ref_routes — dirty destinations',    COUNT(*) FROM sc.ref_routes     WHERE TRIM(ISNULL(destination, '')) = ''
UNION ALL
SELECT 'ref_products — dirty names',         COUNT(*) FROM sc.ref_products   WHERE TRIM(ISNULL(product_name, '')) = ''
UNION ALL
SELECT 'fact_shipments — blank status',      COUNT(*) FROM sc.fact_shipments WHERE TRIM(ISNULL(status, '')) = ''
UNION ALL
SELECT 'fact_shipments — null cost',         COUNT(*) FROM sc.fact_shipments WHERE shipment_cost IS NULL
UNION ALL
SELECT 'fact_shipments — null delay_days',   COUNT(*) FROM sc.fact_shipments WHERE delay_days IS NULL AND actual_date IS NOT NULL
UNION ALL
SELECT 'fact_shipments — impossible dates',  COUNT(*) FROM sc.fact_shipments WHERE status = 'Data Error';
