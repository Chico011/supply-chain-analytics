/*
=============================================================
Create Database and Schemas
=============================================================
Script Purpose:
    This script creates a new database named 'SupplyChainDW' after checking
    if it already exists. If the database exists, it is dropped and recreated.
    Additionally, this script creates a schema called 'sc' and loads six
    tables: sc.ref_suppliers, sc.ref_carriers, sc.ref_routes,
    sc.ref_warehouses, sc.ref_products, and sc.fact_shipments.

WARNING:
    Running this script will drop the entire 'SupplyChainDW' database if it exists.
    All data in the database will be permanently deleted. Proceed with caution
    and ensure you have proper backups before running this script.

File Path Instructions:
    Before running this script, download all 6 CSV files and save them to:
    C:\sql\supply-chain-project\datasets\csv-files\
    If you choose a different folder, update the file paths in the
    BULK INSERT sections below to match your local directory.
=============================================================
*/

USE master;
GO

-- Drop and recreate the 'SupplyChainDW' database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'SupplyChainDW')
BEGIN
    ALTER DATABASE SupplyChainDW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SupplyChainDW;
END;
GO

-- Create the 'SupplyChainDW' database
CREATE DATABASE SupplyChainDW;
GO

USE SupplyChainDW;
GO

-- Create Schema
CREATE SCHEMA sc;
GO

/*
=============================================================
Table: sc.ref_suppliers
Description: Supplier reference table — one row per registered supplier.
Rows: 250
Dirty Data Notes:
    - Nulls and blanks in: supplier_name, country, category,
      contract_tier, rating, onboarded_date, status
    - Inconsistent casing on country (e.g. 'GERMANY', 'germany')
    - Clean these columns before running supplier analysis
=============================================================
*/
CREATE TABLE sc.ref_suppliers (
    supplier_key        INT,
    supplier_id         NVARCHAR(50),
    supplier_name       NVARCHAR(100),
    country             NVARCHAR(50),
    category            NVARCHAR(50),
    contract_tier       NVARCHAR(20),
    rating              DECIMAL(3,1),
    onboarded_date      DATE,
    status              NVARCHAR(20)
);
GO

/*
=============================================================
Table: sc.ref_carriers
Description: Carrier reference table — one row per logistics carrier.
Rows: 60
Dirty Data Notes:
    - Nulls and blanks in: carrier_name, transport_mode,
      on_time_rate, avg_cost_per_km, coverage_region, status
    - Inconsistent casing on transport_mode (e.g. 'road', 'ROAD')
    - Clean these columns before running carrier performance analysis
=============================================================
*/
CREATE TABLE sc.ref_carriers (
    carrier_key         INT,
    carrier_id          NVARCHAR(50),
    carrier_name        NVARCHAR(100),
    transport_mode      NVARCHAR(20),
    on_time_rate        DECIMAL(5,2),
    avg_cost_per_km     DECIMAL(8,4),
    coverage_region     NVARCHAR(50),
    status              NVARCHAR(20)
);
GO

/*
=============================================================
Table: sc.ref_routes
Description: Route reference table — one row per origin-destination lane.
Rows: 200
Dirty Data Notes:
    - Nulls and blanks in: origin, destination, region, distance_km,
      avg_transit_days
    - Clean origin and destination before running route delay analysis
=============================================================
*/
CREATE TABLE sc.ref_routes (
    route_key           INT,
    route_id            NVARCHAR(50),
    origin              NVARCHAR(100),
    destination         NVARCHAR(100),
    region              NVARCHAR(50),
    distance_km         INT,
    avg_transit_days    TINYINT
);
GO

/*
=============================================================
Table: sc.ref_warehouses
Description: Warehouse reference table — one row per distribution centre.
Rows: 40
Dirty Data Notes:
    - Small number of nulls in: processing_time_avg, capacity
    - Least dirty table — warehouse data tends to be well maintained
=============================================================
*/
CREATE TABLE sc.ref_warehouses (
    warehouse_key       INT,
    warehouse_id        NVARCHAR(50),
    location            NVARCHAR(100),
    country             NVARCHAR(50),
    region              NVARCHAR(50),
    capacity            INT,
    current_load        INT,
    processing_time_avg DECIMAL(4,1)
);
GO

/*
=============================================================
Table: sc.ref_products
Description: Product reference table — one row per product SKU.
Rows: 250
Dirty Data Notes:
    - Nulls and blanks in: product_name, category, weight_kg,
      fragility, value_usd
    - Clean category and fragility before running product analysis
=============================================================
*/
CREATE TABLE sc.ref_products (
    product_key         INT,
    product_id          NVARCHAR(50),
    product_name        NVARCHAR(100),
    category            NVARCHAR(50),
    weight_kg           DECIMAL(10,2),
    fragility           NVARCHAR(20),
    value_usd           DECIMAL(12,2)
);
GO

/*
=============================================================
Table: sc.fact_shipments
Description: Shipments fact table — one row per individual shipment.
Rows: 18,000
Dirty Data Notes:
    - Nulls and blanks in: actual_date, delay_days, status,
      shipment_cost, weight_kg, quantity
    - delay_days is null on some rows even when actual_date exists
      — these need to be recalculated as DATEDIFF(day, promised_date, actual_date)
    - actual_date is null on ~4% of rows — exclude from delay analysis
      or flag as 'Undelivered'
    - This is the core fact table — clean thoroughly before analysis
=============================================================
*/
CREATE TABLE sc.fact_shipments (
    shipment_key        INT,
    shipment_id         NVARCHAR(50),
    supplier_key        INT,
    carrier_key         INT,
    route_key           INT,
    warehouse_key       INT,
    product_key         INT,
    order_date          DATE,
    promised_date       DATE,
    actual_date         DATE,
    status              NVARCHAR(20),
    delay_days          INT,
    shipment_cost       DECIMAL(12,2),
    weight_kg           DECIMAL(10,2),
    quantity            INT
);
GO

-- =============================================================
-- Load: sc.ref_suppliers
-- Update the file path below if your folder location is different
-- =============================================================
TRUNCATE TABLE sc.ref_suppliers;
GO

BEGIN TRY
    BULK INSERT sc.ref_suppliers
    FROM 'C:\sql\supply-chain-project\datasets\csv-files\sc.ref_suppliers.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        TABLOCK
    );
    PRINT 'sc.ref_suppliers loaded successfully.';
END TRY
BEGIN CATCH
    PRINT 'ERROR loading sc.ref_suppliers: ' + ERROR_MESSAGE();
END CATCH;
GO

-- =============================================================
-- Load: sc.ref_carriers
-- Update the file path below if your folder location is different
-- =============================================================
TRUNCATE TABLE sc.ref_carriers;
GO

BEGIN TRY
    BULK INSERT sc.ref_carriers
    FROM 'C:\sql\supply-chain-project\datasets\csv-files\sc.ref_carriers.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        TABLOCK
    );
    PRINT 'sc.ref_carriers loaded successfully.';
END TRY
BEGIN CATCH
    PRINT 'ERROR loading sc.ref_carriers: ' + ERROR_MESSAGE();
END CATCH;
GO

-- =============================================================
-- Load: sc.ref_routes
-- Update the file path below if your folder location is different
-- =============================================================
TRUNCATE TABLE sc.ref_routes;
GO

BEGIN TRY
    BULK INSERT sc.ref_routes
    FROM 'C:\sql\supply-chain-project\datasets\csv-files\sc.ref_routes.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        TABLOCK
    );
    PRINT 'sc.ref_routes loaded successfully.';
END TRY
BEGIN CATCH
    PRINT 'ERROR loading sc.ref_routes: ' + ERROR_MESSAGE();
END CATCH;
GO

-- =============================================================
-- Load: sc.ref_warehouses
-- Update the file path below if your folder location is different
-- =============================================================
TRUNCATE TABLE sc.ref_warehouses;
GO

BEGIN TRY
    BULK INSERT sc.ref_warehouses
    FROM 'C:\sql\supply-chain-project\datasets\csv-files\sc.ref_warehouses.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        TABLOCK
    );
    PRINT 'sc.ref_warehouses loaded successfully.';
END TRY
BEGIN CATCH
    PRINT 'ERROR loading sc.ref_warehouses: ' + ERROR_MESSAGE();
END CATCH;
GO

-- =============================================================
-- Load: sc.ref_products
-- Update the file path below if your folder location is different
-- =============================================================
TRUNCATE TABLE sc.ref_products;
GO

BEGIN TRY
    BULK INSERT sc.ref_products
    FROM 'C:\sql\supply-chain-project\datasets\csv-files\sc.ref_products.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        TABLOCK
    );
    PRINT 'sc.ref_products loaded successfully.';
END TRY
BEGIN CATCH
    PRINT 'ERROR loading sc.ref_products: ' + ERROR_MESSAGE();
END CATCH;
GO

-- =============================================================
-- Load: sc.fact_shipments
-- Update the file path below if your folder location is different
-- =============================================================
TRUNCATE TABLE sc.fact_shipments;
GO

BEGIN TRY
    BULK INSERT sc.fact_shipments
    FROM 'C:\sql\supply-chain-project\datasets\csv-files\sc.fact_shipments.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        TABLOCK
    );
    PRINT 'sc.fact_shipments loaded successfully.';
END TRY
BEGIN CATCH
    PRINT 'ERROR loading sc.fact_shipments: ' + ERROR_MESSAGE();
END CATCH;
GO
