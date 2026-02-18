-- =============================================================================
-- 00_setup.sql - Actuarial Result Set Publication Demo Setup
-- =============================================================================
-- ACCOUNTADMIN is used ONLY for:
--   - Creating roles and warehouses
--   - Granting integration usage
--   - Granting CREATE SHARE privilege
--
-- All database objects are created by ACTUARIAL_LAB_ROLE (least privilege).
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
CREATE OR REPLACE WAREHOUSE ACTUARIAL_INGEST_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'XS warehouse for Parquet/CSV data ingestion (COPY INTO)';

CREATE OR REPLACE WAREHOUSE ACTUARIAL_TRANSFORM_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Small warehouse for actuarial data transforms and tasks';

CREATE OR REPLACE WAREHOUSE ACTUARIAL_ANALYTICS_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Small warehouse for analytics and ad-hoc queries';

-- -----------------------------------------------------------------------------
-- 3. Grant Privileges to Demo Role (ACCOUNTADMIN grants)
-- -----------------------------------------------------------------------------
-- Warehouse usage
GRANT USAGE, OPERATE ON WAREHOUSE ACTUARIAL_INGEST_WH TO ROLE ACTUARIAL_LAB_ROLE;
GRANT USAGE, OPERATE ON WAREHOUSE ACTUARIAL_TRANSFORM_WH TO ROLE ACTUARIAL_LAB_ROLE;
GRANT USAGE, OPERATE ON WAREHOUSE ACTUARIAL_ANALYTICS_WH TO ROLE ACTUARIAL_LAB_ROLE;

-- Integration usage (needed for external S3 stages)
GRANT USAGE ON INTEGRATION S3_INT TO ROLE ACTUARIAL_LAB_ROLE;

-- Create share privilege (needed for data sharing)
GRANT CREATE SHARE ON ACCOUNT TO ROLE ACTUARIAL_LAB_ROLE;

-- Create database privilege
GRANT CREATE DATABASE ON ACCOUNT TO ROLE ACTUARIAL_LAB_ROLE;

-- =============================================================================
-- SWITCH TO LEAST-PRIVILEGE ROLE FOR ALL DATABASE OPERATIONS
-- =============================================================================
USE ROLE ACTUARIAL_LAB_ROLE;
USE WAREHOUSE ACTUARIAL_INGEST_WH;

-- -----------------------------------------------------------------------------
-- 4. Database (created by demo role - owns it)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE DATABASE ACTUARIAL_LAB_DB
    COMMENT = 'Actuarial Result Set Publication Demo - IFRS 17 / US GAAP data pipeline';

-- -----------------------------------------------------------------------------
-- 5. Schemas (Medallion Architecture)
-- -----------------------------------------------------------------------------
-- RAW: Landing zone for ingested data (bronze layer)
CREATE OR REPLACE SCHEMA ACTUARIAL_LAB_DB.RAW
    COMMENT = 'Raw ingested data - actuarial results, cashflow projections, run metadata';

-- STAGE: Cleaned and enriched data (silver layer)
CREATE OR REPLACE SCHEMA ACTUARIAL_LAB_DB.STAGE
    COMMENT = 'Enriched data - results joined with run metadata, derived metrics';

-- CURATED: Business-ready aggregates (gold layer)
CREATE OR REPLACE SCHEMA ACTUARIAL_LAB_DB.CURATED
    COMMENT = 'Curated outputs - cohort summaries, run comparisons';

-- ANALYTICS: Reporting layer for shared views
CREATE OR REPLACE SCHEMA ACTUARIAL_LAB_DB.ANALYTICS
    COMMENT = 'Analytics layer - shared views for end-client consumption';

-- -----------------------------------------------------------------------------
-- 6. Verification
-- -----------------------------------------------------------------------------
SHOW WAREHOUSES LIKE 'ACTUARIAL%';
SHOW SCHEMAS IN DATABASE ACTUARIAL_LAB_DB;
SELECT CURRENT_ROLE() AS ACTIVE_ROLE;  -- Should show ACTUARIAL_LAB_ROLE
