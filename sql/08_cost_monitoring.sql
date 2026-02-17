-- =============================================================================
-- 08_cost_monitoring.sql - Cost Control and Usage Monitoring
-- =============================================================================
-- Resource monitors for budget control and queries for monitoring usage.
-- Run as ACCOUNTADMIN.
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- =============================================================================
-- 1. Resource Monitor
-- =============================================================================

CREATE OR REPLACE RESOURCE MONITOR ACTUARIAL_LAB_MONITOR
    WITH
        CREDIT_QUOTA = 100
        FREQUENCY = MONTHLY
        START_TIMESTAMP = IMMEDIATELY
        END_TIMESTAMP = NULL
    TRIGGERS
        ON 50 PERCENT DO NOTIFY
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND
        ON 110 PERCENT DO SUSPEND_IMMEDIATE;

-- Assign to demo warehouses
ALTER WAREHOUSE ACTUARIAL_INGEST_WH SET RESOURCE_MONITOR = ACTUARIAL_LAB_MONITOR;
ALTER WAREHOUSE ACTUARIAL_TRANSFORM_WH SET RESOURCE_MONITOR = ACTUARIAL_LAB_MONITOR;
ALTER WAREHOUSE ACTUARIAL_ANALYTICS_WH SET RESOURCE_MONITOR = ACTUARIAL_LAB_MONITOR;

SHOW RESOURCE MONITORS;

-- =============================================================================
-- 2. Warehouse Credit Consumption (Last 7 Days)
-- =============================================================================

SELECT
    WAREHOUSE_NAME,
    DATE_TRUNC('hour', START_TIME) AS HOUR,
    SUM(CREDITS_USED) AS CREDITS_USED,
    SUM(CREDITS_USED_COMPUTE) AS COMPUTE_CREDITS,
    SUM(CREDITS_USED_CLOUD_SERVICES) AS CLOUD_SERVICES_CREDITS
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE WAREHOUSE_NAME LIKE 'ACTUARIAL%'
  AND START_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY 1, 2
ORDER BY WAREHOUSE_NAME, HOUR DESC;

-- =============================================================================
-- 3. Daily Credit Summary
-- =============================================================================

SELECT
    WAREHOUSE_NAME,
    DATE_TRUNC('day', START_TIME) AS DAY,
    ROUND(SUM(CREDITS_USED), 4) AS TOTAL_CREDITS,
    COUNT(DISTINCT DATE_TRUNC('hour', START_TIME)) AS ACTIVE_HOURS
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE WAREHOUSE_NAME LIKE 'ACTUARIAL%'
  AND START_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY 1, 2
ORDER BY DAY DESC, WAREHOUSE_NAME;

-- =============================================================================
-- 4. Task Execution History
-- =============================================================================

SELECT
    NAME AS TASK_NAME,
    DATABASE_NAME,
    SCHEMA_NAME,
    STATE,
    SCHEDULED_TIME,
    COMPLETED_TIME,
    TIMESTAMPDIFF('second', SCHEDULED_TIME, COMPLETED_TIME) AS DURATION_SEC,
    ERROR_CODE,
    ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('day', -1, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 100
))
WHERE DATABASE_NAME = 'ACTUARIAL_LAB_DB'
ORDER BY SCHEDULED_TIME DESC;

-- =============================================================================
-- 5. Snowpipe Credit Usage
-- =============================================================================

SELECT
    PIPE_NAME,
    DATE_TRUNC('hour', START_TIME) AS HOUR,
    SUM(CREDITS_USED) AS PIPE_CREDITS,
    SUM(FILES_INSERTED) AS FILES_LOADED,
    SUM(BYTES_INSERTED) / (1024*1024) AS MB_LOADED
FROM SNOWFLAKE.ACCOUNT_USAGE.PIPE_USAGE_HISTORY
WHERE PIPE_NAME LIKE 'ACTUARIAL%' OR PIPE_NAME LIKE 'CASHFLOW%' OR PIPE_NAME LIKE 'RUN_METADATA%'
ORDER BY HOUR DESC
LIMIT 50;

-- =============================================================================
-- 6. Storage Usage
-- =============================================================================

SELECT
    TABLE_CATALOG AS DATABASE_NAME,
    TABLE_SCHEMA,
    TABLE_NAME,
    ROW_COUNT,
    BYTES / (1024*1024) AS SIZE_MB,
    ACTIVE_BYTES / (1024*1024) AS ACTIVE_MB,
    TIME_TRAVEL_BYTES / (1024*1024) AS TIME_TRAVEL_MB
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
WHERE TABLE_CATALOG = 'ACTUARIAL_LAB_DB'
  AND DELETED = FALSE
ORDER BY BYTES DESC;

-- =============================================================================
-- 7. Estimated Monthly Cost
-- =============================================================================

WITH daily_credits AS (
    SELECT
        DATE_TRUNC('day', START_TIME) AS DAY,
        SUM(CREDITS_USED) AS CREDITS
    FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
    WHERE WAREHOUSE_NAME LIKE 'ACTUARIAL%'
      AND START_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP())
    GROUP BY 1
)
SELECT
    ROUND(AVG(CREDITS), 4) AS AVG_DAILY_CREDITS,
    ROUND(AVG(CREDITS) * 30, 2) AS EST_MONTHLY_CREDITS,
    ROUND(AVG(CREDITS) * 30 * 3, 2) AS EST_MONTHLY_COST_USD  -- ~$3/credit
FROM daily_credits;
