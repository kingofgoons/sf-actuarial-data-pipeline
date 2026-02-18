-- =============================================================================
-- 99_cleanup.sql - Tear Down All Demo Objects
-- =============================================================================
-- Run this to clean up after the demo and avoid ongoing charges.
-- NOTE: ACCOUNTADMIN is required to drop roles, warehouses, resource monitors,
-- and shares. This is one of the few scripts that legitimately needs it.
--
-- NOTE: You likely used EITHER Streams+Tasks (05) OR Dynamic Tables (06),
-- not both. Some ALTER statements below may fail with "does not exist" —
-- this is expected. Continue running the rest of the script.
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- -----------------------------------------------------------------------------
-- 1. Suspend Tasks (if you used 05_transforms.sql)
-- These may fail if you used Dynamic Tables instead — that's OK, continue.
-- -----------------------------------------------------------------------------
ALTER TASK IF EXISTS ACTUARIAL_LAB_DB.CURATED.TASK_AGGREGATE_COHORTS SUSPEND;
ALTER TASK IF EXISTS ACTUARIAL_LAB_DB.SILVER.TASK_ENRICH_RESULTS SUSPEND;

-- -----------------------------------------------------------------------------
-- 2. Suspend Dynamic Tables (if you used 06_dynamic_tables.sql)
-- These may fail if you used Streams+Tasks instead — that's OK, continue.
-- -----------------------------------------------------------------------------
ALTER DYNAMIC TABLE IF EXISTS ACTUARIAL_LAB_DB.SILVER.RESULTS_ENRICHED_DT SUSPEND;
ALTER DYNAMIC TABLE IF EXISTS ACTUARIAL_LAB_DB.CURATED.COHORT_SUMMARY_DT SUSPEND;

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
