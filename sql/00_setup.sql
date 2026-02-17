-- =============================================================================
-- 00_setup.sql - Actuarial Result Set Publication Demo Setup
-- =============================================================================
-- Run as ACCOUNTADMIN (trial account OK)
-- Creates: Role, Warehouses, Database, Schemas for actuarial data pipeline
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- -----------------------------------------------------------------------------
-- 1. Demo Role
-- -----------------------------------------------------------------------------
CREATE OR REPLACE ROLE ACTUARIAL_LAB_ROLE
    COMMENT = 'Role for Actuarial Result Set Publication demo';

GRANT ROLE ACTUARIAL_LAB_ROLE TO ROLE ACCOUNTADMIN;

-- -----------------------------------------------------------------------------
-- 2. Warehouses (sized for different workload types)
-- -----------------------------------------------------------------------------
-- Ingest WH: XSmall for COPY INTO / Snowpipe operations (bursty, short-running)
CREATE OR REPLACE WAREHOUSE ACTUARIAL_INGEST_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'XS warehouse for Parquet/CSV data ingestion (COPY INTO)';

-- Transform WH: Small for Streams/Tasks and enrichment
CREATE OR REPLACE WAREHOUSE ACTUARIAL_TRANSFORM_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Small warehouse for actuarial data transforms and tasks';

-- Analytics WH: Small for ad-hoc queries and reporting
CREATE OR REPLACE WAREHOUSE ACTUARIAL_ANALYTICS_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Small warehouse for analytics and ad-hoc queries';

-- -----------------------------------------------------------------------------
-- 3. Database and Schemas (Medallion Architecture)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE DATABASE ACTUARIAL_LAB_DB
    COMMENT = 'Actuarial Result Set Publication Demo - IFRS 17 / US GAAP data pipeline';

-- RAW: Landing zone for ingested data (bronze layer)
CREATE OR REPLACE SCHEMA ACTUARIAL_LAB_DB.RAW
    COMMENT = 'Raw ingested data - actuarial results, cashflow projections, run metadata';

-- STAGE: Cleaned and enriched data (silver layer)
CREATE OR REPLACE SCHEMA ACTUARIAL_LAB_DB.STAGE
    COMMENT = 'Enriched data - results joined with run metadata, derived metrics';

-- CURATED: Business-ready aggregates (gold layer)
CREATE OR REPLACE SCHEMA ACTUARIAL_LAB_DB.CURATED
    COMMENT = 'Curated outputs - cohort summaries, run comparisons';

-- ANALYTICS: Reporting layer
CREATE OR REPLACE SCHEMA ACTUARIAL_LAB_DB.ANALYTICS
    COMMENT = 'Analytics layer - shared views for end-client consumption';

-- -----------------------------------------------------------------------------
-- 4. Grant Privileges to Demo Role
-- -----------------------------------------------------------------------------
-- Database access
GRANT USAGE ON DATABASE ACTUARIAL_LAB_DB TO ROLE ACTUARIAL_LAB_ROLE;

-- Schema access (current and future)
GRANT USAGE ON ALL SCHEMAS IN DATABASE ACTUARIAL_LAB_DB TO ROLE ACTUARIAL_LAB_ROLE;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE ACTUARIAL_LAB_DB TO ROLE ACTUARIAL_LAB_ROLE;

-- Full privileges on schemas for demo flexibility
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE ACTUARIAL_LAB_DB TO ROLE ACTUARIAL_LAB_ROLE;
GRANT ALL PRIVILEGES ON FUTURE SCHEMAS IN DATABASE ACTUARIAL_LAB_DB TO ROLE ACTUARIAL_LAB_ROLE;

-- Table privileges (current and future)
GRANT ALL PRIVILEGES ON ALL TABLES IN DATABASE ACTUARIAL_LAB_DB TO ROLE ACTUARIAL_LAB_ROLE;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN DATABASE ACTUARIAL_LAB_DB TO ROLE ACTUARIAL_LAB_ROLE;

-- View privileges (for Secure Data Sharing later)
GRANT ALL PRIVILEGES ON ALL VIEWS IN DATABASE ACTUARIAL_LAB_DB TO ROLE ACTUARIAL_LAB_ROLE;
GRANT ALL PRIVILEGES ON FUTURE VIEWS IN DATABASE ACTUARIAL_LAB_DB TO ROLE ACTUARIAL_LAB_ROLE;

-- Warehouse access
GRANT USAGE, OPERATE ON WAREHOUSE ACTUARIAL_INGEST_WH TO ROLE ACTUARIAL_LAB_ROLE;
GRANT USAGE, OPERATE ON WAREHOUSE ACTUARIAL_TRANSFORM_WH TO ROLE ACTUARIAL_LAB_ROLE;
GRANT USAGE, OPERATE ON WAREHOUSE ACTUARIAL_ANALYTICS_WH TO ROLE ACTUARIAL_LAB_ROLE;

-- -----------------------------------------------------------------------------
-- 5. Verification
-- -----------------------------------------------------------------------------
SHOW WAREHOUSES LIKE 'ACTUARIAL%';
SHOW SCHEMAS IN DATABASE ACTUARIAL_LAB_DB;
-- SHOW GRANTS TO ROLE ACTUARIAL_LAB_ROLE;
