-- =============================================================================
-- 04_snowpipe.sql - Continuous Parquet Ingestion via Snowpipe
-- =============================================================================
-- Run after 01_stages_formats.sql (requires external stage and integration).
-- Creates Snowpipe definitions for auto-ingesting new Parquet files as the
-- actuarial compute farm writes them to S3.
-- =============================================================================

USE ROLE ACTUARIAL_LAB_ROLE;
USE DATABASE ACTUARIAL_LAB_DB;
USE SCHEMA RAW;

-- =============================================================================
-- Snowpipe vs COPY INTO: Choosing the Right Pattern
-- =============================================================================
-- COPY INTO (batch):
--   Best for: scheduled bulk loads, backfills, infrequent file arrivals.
--   Cost: warehouse compute only when COPY runs.
--   Latency: depends on schedule (minutes to hours).
--
-- Snowpipe (continuous):
--   Best for: near-real-time ingestion, frequent small files, event-driven.
--   Cost: serverless (~0.06 credits per 1000 files); no warehouse needed.
--   Latency: typically < 1 minute after file lands.
--
-- At 30TB scale (actuarial result publication):
--   If the compute farm writes files in large batches after each run
--   (thousands of Parquet files at once), COPY INTO with a larger WH may
--   be more cost-effective. Snowpipe shines when files trickle in
--   continuously across many runs.

-- =============================================================================
-- Snowpipe: Actuarial Results (Parquet)
-- =============================================================================
CREATE OR REPLACE PIPE ACTUARIAL_RESULTS_PIPE
    AUTO_INGEST = TRUE
AS
    COPY INTO ACTUARIAL_LAB_DB.RAW.ACTUARIAL_RESULTS_RAW
    FROM @ACTUARIAL_LAB_DB.RAW.RAW_S3_STAGE
    FILE_FORMAT = (FORMAT_NAME = 'FF_PARQUET_RESULTS')
    MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
    PATTERN = '.*actuarial_results.*[.]parquet';

-- =============================================================================
-- Snowpipe: Cashflow Projections (Parquet)
-- =============================================================================
CREATE OR REPLACE PIPE CASHFLOW_PROJECTIONS_PIPE
    AUTO_INGEST = TRUE
AS
    COPY INTO ACTUARIAL_LAB_DB.RAW.CASHFLOW_PROJECTIONS_RAW
    FROM @ACTUARIAL_LAB_DB.RAW.RAW_S3_STAGE
    FILE_FORMAT = (FORMAT_NAME = 'FF_PARQUET_RESULTS')
    MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
    PATTERN = '.*cashflow_projections.*[.]parquet';

-- =============================================================================
-- Snowpipe: Run Metadata (CSV)
-- =============================================================================
CREATE OR REPLACE PIPE RUN_METADATA_PIPE
    AUTO_INGEST = TRUE
AS
    COPY INTO ACTUARIAL_LAB_DB.RAW.RUN_METADATA_RAW
    FROM @ACTUARIAL_LAB_DB.RAW.RAW_S3_STAGE
    FILE_FORMAT = (FORMAT_NAME = 'FF_CSV_RESULTS')
    MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
    PATTERN = '.*run_metadata.*[.]csv';

-- =============================================================================
-- Get SQS ARN for S3 Event Notifications
-- =============================================================================
-- After creating pipes, retrieve the notification channel (SQS ARN):
SHOW PIPES;

-- The "notification_channel" column contains the SQS ARN.
-- Use this ARN to configure S3 bucket event notifications.

-- =============================================================================
-- AWS S3 Event Notification Setup (summary)
-- =============================================================================
-- 1) In AWS S3 Console → bucket → Properties → Event notifications
-- 2) Create event notification:
--      Name: e.g., "snowpipe-actuarial"
--      Prefix: "actuarial-results/"
--      Event types: "All object create events" (s3:ObjectCreated:*)
--      Destination: SQS queue
--      SQS ARN: paste the notification_channel from SHOW PIPES
--
-- For detailed steps, see:
-- https://docs.snowflake.com/en/user-guide/data-load-snowpipe-auto-s3

-- =============================================================================
-- Monitor Snowpipe
-- =============================================================================

-- Pipe status
SELECT SYSTEM$PIPE_STATUS('ACTUARIAL_RESULTS_PIPE');
SELECT SYSTEM$PIPE_STATUS('CASHFLOW_PROJECTIONS_PIPE');
SELECT SYSTEM$PIPE_STATUS('RUN_METADATA_PIPE');

-- Recent copy history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'ACTUARIAL_RESULTS_RAW',
    START_TIME => DATEADD('hour', -24, CURRENT_TIMESTAMP())
))
ORDER BY LAST_LOAD_TIME DESC
LIMIT 20;

-- Pipe credit usage
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.PIPE_USAGE_HISTORY
WHERE PIPE_NAME IN ('ACTUARIAL_RESULTS_PIPE', 'CASHFLOW_PROJECTIONS_PIPE', 'RUN_METADATA_PIPE')
ORDER BY START_TIME DESC
LIMIT 50;

-- =============================================================================
-- Manual refresh (for testing or backfill)
-- =============================================================================
-- ALTER PIPE ACTUARIAL_RESULTS_PIPE REFRESH;
-- ALTER PIPE CASHFLOW_PROJECTIONS_PIPE REFRESH;
-- ALTER PIPE RUN_METADATA_PIPE REFRESH;
