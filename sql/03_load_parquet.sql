-- =============================================================================
-- 03_load_parquet.sql - Load Sample Parquet Files (Phase 1 Demo)
-- =============================================================================
-- Run after 01_stages_formats.sql and uploading sample data to S3.
-- Demonstrates COPY INTO for Parquet with MATCH_BY_COLUMN_NAME.
--
-- Upload data first:
--   aws s3 cp data-samples/ s3://YOUR-BUCKET/actuarial-results/ \
--       --recursive --exclude "README.md"
-- =============================================================================

USE ROLE ACTUARIAL_LAB_ROLE;
USE DATABASE ACTUARIAL_LAB_DB;
USE SCHEMA RAW;
USE WAREHOUSE ACTUARIAL_INGEST_WH;

-- =============================================================================
-- Verify files are visible in stage
-- =============================================================================
LIST @RAW_S3_STAGE;

-- =============================================================================
-- Load actuarial results (Parquet)
-- =============================================================================
-- MATCH_BY_COLUMN_NAME lets Snowflake map Parquet columns to table columns
-- by name rather than position. This is essential for Parquet since column
-- order may differ between runs.

COPY INTO ACTUARIAL_RESULTS_RAW
    FROM @RAW_S3_STAGE
    FILE_FORMAT = FF_PARQUET_RESULTS
    MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
    PATTERN = '.*actuarial_results.*[.]parquet'
    ON_ERROR = 'CONTINUE'
    PURGE = FALSE;

-- =============================================================================
-- Load cashflow projections (Parquet)
-- =============================================================================

COPY INTO CASHFLOW_PROJECTIONS_RAW
    FROM @RAW_S3_STAGE
    FILE_FORMAT = FF_PARQUET_RESULTS
    MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
    PATTERN = '.*cashflow_projections.*[.]parquet'
    ON_ERROR = 'CONTINUE'
    PURGE = FALSE;

-- =============================================================================
-- Load run metadata (CSV)
-- =============================================================================

COPY INTO RUN_METADATA_RAW
    FROM @RAW_S3_STAGE
    FILE_FORMAT = FF_CSV_RESULTS
    MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
    PATTERN = '.*run_metadata.*[.]csv'
    ON_ERROR = 'CONTINUE'
    PURGE = FALSE;

-- =============================================================================
-- Verification
-- =============================================================================

-- Row counts
SELECT 'ACTUARIAL_RESULTS_RAW' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM ACTUARIAL_RESULTS_RAW
UNION ALL
SELECT 'CASHFLOW_PROJECTIONS_RAW', COUNT(*) FROM CASHFLOW_PROJECTIONS_RAW
UNION ALL
SELECT 'RUN_METADATA_RAW', COUNT(*) FROM RUN_METADATA_RAW;

-- Sample actuarial results
SELECT * FROM ACTUARIAL_RESULTS_RAW LIMIT 10;

-- Sample cashflow projections
SELECT * FROM CASHFLOW_PROJECTIONS_RAW LIMIT 10;

-- Run metadata
SELECT * FROM RUN_METADATA_RAW;
