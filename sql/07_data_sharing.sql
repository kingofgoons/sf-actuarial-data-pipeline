-- =============================================================================
-- 07_data_sharing.sql - Secure Data Sharing for Result Publication
-- =============================================================================
-- The curated actuarial results are delivered to the end client via
-- Snowflake Secure Data Sharing — no ETL, no file copies, no latency.
--
-- This is the "Result Set Publication" destination: granular IFRS 17 /
-- US GAAP data available in the client's own Snowflake account as a
-- live, always-current share.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ACTUARIAL_LAB_DB;
USE WAREHOUSE ACTUARIAL_ANALYTICS_WH;

-- =============================================================================
-- STEP 1: Create Secure Views for sharing
-- =============================================================================
-- Secure Views hide the underlying SQL definition from the consumer.
-- They also enforce row-level filtering if needed.

USE SCHEMA ANALYTICS;

-- Cohort-level summary view (shared to end client)
CREATE OR REPLACE SECURE VIEW VW_COHORT_SUMMARY
AS
SELECT
    COHORT_ID,
    VALUATION_DATE,
    REPORTING_STANDARD,
    MODEL_POINT_COUNT,
    TOTAL_BEL,
    TOTAL_RA,
    TOTAL_CSM,
    TOTAL_NET_LIABILITY,
    AVG_CSM_RATIO,
    TOTAL_REVENUE,
    TOTAL_EXPENSE,
    _UPDATED_AT
FROM CURATED.COHORT_SUMMARY;

-- Run comparison view (shared to end client)
CREATE OR REPLACE SECURE VIEW VW_RUN_COMPARISON
AS
SELECT
    RUN_ID_A,
    RUN_ID_B,
    COHORT_ID,
    REPORTING_STANDARD,
    DELTA_BEL,
    DELTA_CSM,
    DELTA_NET_LIABILITY,
    _COMPUTED_AT
FROM CURATED.RUN_COMPARISON;

-- Granular results view (optional - row-level filtering example)
-- This shows how to restrict by REPORTING_STANDARD if different clients
-- should only see data for the standard they report under.
CREATE OR REPLACE SECURE VIEW VW_RESULTS_DETAIL
AS
SELECT
    RUN_ID,
    SCENARIO_ID,
    MODEL_POINT_ID,
    COHORT_ID,
    VALUATION_DATE,
    REPORTING_STANDARD,
    PRESENT_VALUE_FUTURE_CASHFLOWS,
    CONTRACTUAL_SERVICE_MARGIN,
    LOSS_COMPONENT,
    RISK_ADJUSTMENT,
    BEST_ESTIMATE_LIABILITY,
    INSURANCE_REVENUE,
    INSURANCE_SERVICE_EXPENSE,
    NET_LIABILITY,
    CSM_RATIO
FROM STAGE.RESULTS_ENRICHED;
-- To filter by client: add WHERE REPORTING_STANDARD = CURRENT_SESSION()...
-- or use a mapping table for row-level security.

-- =============================================================================
-- STEP 2: Create the Share
-- =============================================================================

CREATE OR REPLACE SHARE ACTUARIAL_RESULTS_SHARE
    COMMENT = 'Curated actuarial results for end-client consumption (IFRS 17 / US GAAP)';

-- Grant the share access to the database and schema
GRANT USAGE ON DATABASE ACTUARIAL_LAB_DB TO SHARE ACTUARIAL_RESULTS_SHARE;
GRANT USAGE ON SCHEMA ACTUARIAL_LAB_DB.ANALYTICS TO SHARE ACTUARIAL_RESULTS_SHARE;

-- Grant the share access to the secure views
GRANT SELECT ON VIEW ACTUARIAL_LAB_DB.ANALYTICS.VW_COHORT_SUMMARY TO SHARE ACTUARIAL_RESULTS_SHARE;
GRANT SELECT ON VIEW ACTUARIAL_LAB_DB.ANALYTICS.VW_RUN_COMPARISON TO SHARE ACTUARIAL_RESULTS_SHARE;
GRANT SELECT ON VIEW ACTUARIAL_LAB_DB.ANALYTICS.VW_RESULTS_DETAIL TO SHARE ACTUARIAL_RESULTS_SHARE;

-- =============================================================================
-- STEP 3: Add consumer account(s)
-- =============================================================================
-- Replace with the end client's Snowflake account locator.
-- In a real deployment this would be their actual account identifier.

-- ALTER SHARE ACTUARIAL_RESULTS_SHARE ADD ACCOUNTS = '<client_account_locator>';

-- =============================================================================
-- STEP 4: Verify the share
-- =============================================================================

SHOW SHARES LIKE 'ACTUARIAL%';
DESC SHARE ACTUARIAL_RESULTS_SHARE;

-- =============================================================================
-- WHAT THE END CLIENT SEES
-- =============================================================================
-- On the consumer side, the end client would run:
--
--   CREATE DATABASE ACTUARIAL_RESULTS_DB FROM SHARE <provider_account>.ACTUARIAL_RESULTS_SHARE;
--   SELECT * FROM ACTUARIAL_RESULTS_DB.ANALYTICS.VW_COHORT_SUMMARY;
--
-- Key benefits:
-- 1. No data copies — consumer queries the provider's live data
-- 2. No ETL pipeline to maintain between organizations
-- 3. Always current — as soon as curated data refreshes, consumer sees it
-- 4. Provider controls access; can revoke at any time
-- 5. Consumer pays only for their own compute (queries)

-- =============================================================================
-- FUTURE: Snowflake Marketplace
-- =============================================================================
-- For broader distribution (multiple clients, external consumers),
-- consider publishing curated datasets as a Snowflake Marketplace listing.
-- This enables self-service discovery and access request workflows.
--
-- See: https://docs.snowflake.com/en/user-guide/data-marketplace
-- =============================================================================
