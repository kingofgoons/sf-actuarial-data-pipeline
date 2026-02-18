-- =============================================================================
-- 01_stages_formats.sql - Stages, File Formats, and Raw Tables
-- =============================================================================
-- Run after 00_setup.sql
-- Creates: File formats, stages, raw tables for actuarial result ingestion
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ACTUARIAL_LAB_DB;
USE SCHEMA ACTUARIAL_LAB_DB.RAW;
USE WAREHOUSE ACTUARIAL_INGEST_WH;

-- -----------------------------------------------------------------------------
-- 1. File Formats
-- -----------------------------------------------------------------------------

-- Parquet format for actuarial result files (primary format)
CREATE OR REPLACE FILE FORMAT FF_PARQUET_RESULTS
    TYPE = PARQUET
    COMMENT = 'Parquet format for actuarial result and cashflow files';

-- CSV format for run metadata and legacy CSV outputs
CREATE OR REPLACE FILE FORMAT FF_CSV_RESULTS
    TYPE = CSV
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL', 'null', 'NA')
    TRIM_SPACE = TRUE
    COMMENT = 'CSV format for run metadata and legacy result files';

-- JSON format (optional - for run config payloads)
CREATE OR REPLACE FILE FORMAT FF_JSON_METADATA
    TYPE = JSON
    STRIP_OUTER_ARRAY = TRUE
    COMMENT = 'JSON format for run configuration payloads';

-- -----------------------------------------------------------------------------
-- 2. External Stage (AWS S3)
-- -----------------------------------------------------------------------------
-- Uses existing S3_INT storage integration
-- See: https://docs.snowflake.com/en/user-guide/data-load-s3-config-storage-integration

-- =============================================================================
-- STORAGE INTEGRATION REFERENCE (assumes S3_INT already exists)
-- =============================================================================
-- A storage integration delegates S3 authentication to Snowflake via IAM.
-- Your existing S3_INT was created like:
--
-- CREATE OR REPLACE STORAGE INTEGRATION S3_INT
--     TYPE = EXTERNAL_STAGE
--     STORAGE_PROVIDER = 'S3'
--     ENABLED = TRUE
--     STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<account-id>:role/<role-name>'
--     STORAGE_ALLOWED_LOCATIONS = ('s3://<bucket-name>/');
--
-- To verify: DESC INTEGRATION S3_INT;
-- =============================================================================

-- Verify the integration exists
DESC INTEGRATION S3_INT;

-- NOTE: GRANT USAGE ON INTEGRATION S3_INT is done in 00_setup.sql by ACCOUNTADMIN

-- ⚠️ EDIT THIS: Replace with your S3 bucket name
CREATE OR REPLACE STAGE RAW_S3_STAGE
    STORAGE_INTEGRATION = S3_INT
    URL = 's3://blandsman/actuarial-results/'
    FILE_FORMAT = FF_PARQUET_RESULTS
    COMMENT = 'External S3 stage for actuarial result Parquet files';

-- Verify the stage and list files
SHOW STAGES LIKE 'RAW_S3%';
LIST @RAW_S3_STAGE;

-- -----------------------------------------------------------------------------
-- 3. Raw Tables
-- -----------------------------------------------------------------------------

-- Core actuarial engine run outputs (from Parquet)
CREATE OR REPLACE TABLE ACTUARIAL_RESULTS_RAW (
    RUN_ID              STRING          NOT NULL    COMMENT 'Unique run identifier',
    SCENARIO_ID         STRING          NOT NULL    COMMENT 'Scenario identifier (base, stress, etc.)',
    MODEL_POINT_ID      STRING          NOT NULL    COMMENT 'Individual policy/contract model point',
    COHORT_ID           STRING          NOT NULL    COMMENT 'Grouping cohort for IFRS 17 aggregation',
    VALUATION_DATE      DATE            NOT NULL    COMMENT 'Valuation/reporting date',
    REPORTING_STANDARD  STRING          NOT NULL    COMMENT 'IFRS17 or USGAAP',
    PRESENT_VALUE_FUTURE_CASHFLOWS NUMBER(18,2)     COMMENT 'PV of future cash flows',
    CONTRACTUAL_SERVICE_MARGIN     NUMBER(18,2)     COMMENT 'CSM balance (IFRS 17)',
    LOSS_COMPONENT      NUMBER(18,2)                COMMENT 'Loss component for onerous contracts',
    RISK_ADJUSTMENT     NUMBER(18,2)                COMMENT 'Risk adjustment for non-financial risk',
    BEST_ESTIMATE_LIABILITY        NUMBER(18,2)     COMMENT 'Best estimate liability',
    INSURANCE_REVENUE   NUMBER(18,2)                COMMENT 'Insurance revenue recognized',
    INSURANCE_SERVICE_EXPENSE      NUMBER(18,2)     COMMENT 'Insurance service expense',
    _LOADED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP() COMMENT 'ETL load timestamp'
)
COMMENT = 'Raw actuarial engine outputs - IFRS 17 / US GAAP measurements';

-- Projected cash flows per model point (from Parquet)
CREATE OR REPLACE TABLE CASHFLOW_PROJECTIONS_RAW (
    RUN_ID              STRING          NOT NULL    COMMENT 'Run identifier (FK to results)',
    MODEL_POINT_ID      STRING          NOT NULL    COMMENT 'Model point identifier',
    PROJECTION_MONTH    NUMBER(6,0)     NOT NULL    COMMENT 'Projection month (1-360)',
    PREMIUM_INFLOW      NUMBER(18,2)                COMMENT 'Premium cash inflow',
    CLAIM_OUTFLOW       NUMBER(18,2)                COMMENT 'Claim payment outflow',
    EXPENSE_OUTFLOW     NUMBER(18,2)                COMMENT 'Expense outflow',
    INVESTMENT_INCOME   NUMBER(18,2)                COMMENT 'Investment income component',
    NET_CASHFLOW        NUMBER(18,2)                COMMENT 'Net cash flow for the month',
    DISCOUNT_FACTOR     NUMBER(12,8)                COMMENT 'Discount factor applied',
    _LOADED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP() COMMENT 'ETL load timestamp'
)
COMMENT = 'Projected cash flows per model point - 360 month horizon';

-- Run metadata and configuration (from CSV)
CREATE OR REPLACE TABLE RUN_METADATA_RAW (
    RUN_ID              STRING          NOT NULL    COMMENT 'Run identifier',
    RUN_START_TS        TIMESTAMP_NTZ   NOT NULL    COMMENT 'Run start timestamp',
    RUN_END_TS          TIMESTAMP_NTZ               COMMENT 'Run end timestamp',
    STATUS              STRING          NOT NULL    COMMENT 'COMPLETED, FAILED, RUNNING',
    MODEL_VERSION       STRING                      COMMENT 'Model version identifier',
    SCENARIO_COUNT      NUMBER(6,0)                 COMMENT 'Number of scenarios in run',
    MODEL_POINT_COUNT   NUMBER(10,0)                COMMENT 'Number of model points processed',
    NODE_COUNT          NUMBER(6,0)                 COMMENT 'Compute grid nodes used',
    TOTAL_COMPUTE_SECONDS NUMBER(12,0)              COMMENT 'Total compute time across all nodes',
    _LOADED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP() COMMENT 'ETL load timestamp'
)
COMMENT = 'Run configuration and compute statistics from the actuarial engine';

-- -----------------------------------------------------------------------------
-- 4. Verification
-- -----------------------------------------------------------------------------
SELECT 'ACTUARIAL_RESULTS_RAW' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM ACTUARIAL_RESULTS_RAW
UNION ALL
SELECT 'CASHFLOW_PROJECTIONS_RAW', COUNT(*) FROM CASHFLOW_PROJECTIONS_RAW
UNION ALL
SELECT 'RUN_METADATA_RAW', COUNT(*) FROM RUN_METADATA_RAW;
