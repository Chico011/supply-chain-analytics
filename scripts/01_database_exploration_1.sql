/*
===============================================================================
Database Exploration
===============================================================================
Purpose:
    - Get a clear picture of what tables exist in the database and how they
      are organised across the supply chain schema.
    - Examine the structure, column details, and data types of all six tables.
    - Perform an initial row count check to confirm all CSV files loaded
      correctly before any analysis begins.
Tables Referenced:
    - INFORMATION_SCHEMA.TABLES
    - INFORMATION_SCHEMA.COLUMNS
    - sc.ref_suppliers
    - sc.ref_carriers
    - sc.ref_routes
    - sc.ref_warehouses
    - sc.ref_products
    - sc.fact_shipments
===============================================================================
*/

-- Pull a full list of all available tables in the sc schema
SELECT
    TABLE_CATALOG,
    TABLE_SCHEMA,
    TABLE_NAME,
    TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'sc'
ORDER BY TABLE_NAME;

-- Look up the column details for the ref_suppliers table
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ref_suppliers'
ORDER BY ORDINAL_POSITION;

-- Look up the column details for the ref_carriers table
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ref_carriers'
ORDER BY ORDINAL_POSITION;

-- Look up the column details for the ref_routes table
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ref_routes'
ORDER BY ORDINAL_POSITION;

-- Look up the column details for the ref_warehouses table
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ref_warehouses'
ORDER BY ORDINAL_POSITION;

-- Look up the column details for the ref_products table
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ref_products'
ORDER BY ORDINAL_POSITION;

-- Look up the column details for the fact_shipments table
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'fact_shipments'
ORDER BY ORDINAL_POSITION;

-- Confirm row counts across all six tables to verify data loaded correctly
SELECT 'ref_suppliers'  AS table_name, COUNT(*) AS row_count FROM sc.ref_suppliers
UNION ALL
SELECT 'ref_carriers',COUNT(*) FROM sc.ref_carriers
UNION ALL
SELECT 'ref_routes',COUNT(*) FROM sc.ref_routes
UNION ALL
SELECT 'ref_warehouses',COUNT(*) FROM sc.ref_warehouses
UNION ALL
SELECT 'ref_products',COUNT(*) FROM sc.ref_products
UNION ALL
SELECT 'fact_shipments',COUNT(*) FROM sc.fact_shipments
ORDER BY table_name;
