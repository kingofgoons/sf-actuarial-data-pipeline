-- =============================================================================
-- 99_cleanup.sql - Tear Down All Demo Objects
-- =============================================================================
-- Run this to clean up after the demo and avoid ongoing charges.
-- Execute as ACCOUNTADMIN.
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- -----------------------------------------------------------------------------
-- 1. Suspend Tasks (must be done before dropping database)
-- -----------------------------------------------------------------------------
ALTER TASK ACTUARIAL_LAB_DB.CURATED.TASK_AGGREGATE_COHORTS SUSPEND;
ALTER TASK ACTUARIAL_LAB_DB.STAGE.TASK_ENRICH_RESULTS SUSPEND;

-- -----------------------------------------------------------------------------
-- 2. Suspend Dynamic Tables
-- -----------------------------------------------------------------------------
ALTER DYNAMIC TABLE ACTUARIAL_LAB_DB.STAGE.RESULTS_ENRICHED_DT SUSPEND;
ALTER DYNAMIC TABLE ACTUARIAL_LAB_DB.CURATED.COHORT_SUMMARY_DT SUSPEND;

-- -----------------------------------------------------------------------------
-- 3. Drop Share
-- -----------------------------------------------------------------------------
DROP SHARE IF EXISTS ACTUARIAL_RESULTS_SHARE;

-- -----------------------------------------------------------------------------
-- 4. Drop Database (cascades all schemas, tables, views, stages, pipes, etc.)
-- -----------------------------------------------------------------------------
DROP DATABASE IF EXISTS ACTUARIAL_LAB_DB;

-- -----------------------------------------------------------------------------
-- 5. Drop Warehouses
-- -----------------------------------------------------------------------------
DROP WAREHOUSE IF EXISTS ACTUARIAL_INGEST_WH;
DROP WAREHOUSE IF EXISTS ACTUARIAL_TRANSFORM_WH;
DROP WAREHOUSE IF EXISTS ACTUARIAL_ANALYTICS_WH;

-- -----------------------------------------------------------------------------
-- 6. Drop Resource Monitor
-- -----------------------------------------------------------------------------
DROP RESOURCE MONITOR IF EXISTS ACTUARIAL_LAB_MONITOR;

-- -----------------------------------------------------------------------------
-- 7. Drop Role
-- -----------------------------------------------------------------------------
DROP ROLE IF EXISTS ACTUARIAL_LAB_ROLE;

-- Verify cleanup
SHOW DATABASES LIKE 'ACTUARIAL%';
SHOW WAREHOUSES LIKE 'ACTUARIAL%';
SHOW ROLES LIKE 'ACTUARIAL%';
