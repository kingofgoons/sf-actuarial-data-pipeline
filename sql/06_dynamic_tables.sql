-- =============================================================================
-- 06_dynamic_tables.sql - Declarative Transforms via Dynamic Tables
-- =============================================================================
-- Alternative to Streams + Tasks (05_transforms.sql).
-- Dynamic Tables define transformations declaratively; Snowflake handles
-- incremental refresh automatically based on TARGET_LAG.
--
-- Use ONE approach or the other — not both on the same data.
-- =============================================================================

USE ROLE ACTUARIAL_LAB_ROLE;
USE DATABASE ACTUARIAL_LAB_DB;
USE WAREHOUSE ACTUARIAL_TRANSFORM_WH;

-- =============================================================================
-- Dynamic Tables vs Streams + Tasks
-- =============================================================================
-- Streams + Tasks:
--   Fine-grained control over execution timing and logic.
--   Can call stored procedures, complex branching.
--   Requires manual stream consumption and task DAG management.
--
-- Dynamic Tables:
--   Declarative: define the SQL once, Snowflake auto-refreshes.
--   Built-in incremental refresh and dependency tracking.
--   TARGET_LAG controls freshness (e.g., '1 minute', '1 hour').
--   Simpler to manage; no explicit stream/task wiring.
--
-- Trade-offs:
--   Less control over exact timing. Refresh cost depends on frequency.
--   Best for straightforward transformations; complex logic may need tasks.

-- =============================================================================
-- Dynamic Table: RESULTS_ENRICHED_DT (Silver layer)
-- =============================================================================
USE SCHEMA SILVER;

CREATE OR REPLACE DYNAMIC TABLE RESULTS_ENRICHED_DT
    TARGET_LAG = '1 minute'
    WAREHOUSE = ACTUARIAL_TRANSFORM_WH
AS
    SELECT
        r.RUN_ID,
        r.SCENARIO_ID,
        r.MODEL_POINT_ID,
        r.COHORT_ID,
        r.VALUATION_DATE,
        r.REPORTING_STANDARD,
        r.PRESENT_VALUE_FUTURE_CASHFLOWS,
        r.CONTRACTUAL_SERVICE_MARGIN,
        r.LOSS_COMPONENT,
        r.RISK_ADJUSTMENT,
        r.BEST_ESTIMATE_LIABILITY,
        r.INSURANCE_REVENUE,
        r.INSURANCE_SERVICE_EXPENSE,
        -- Enrichment from run metadata
        m.MODEL_VERSION,
        m.STATUS AS RUN_STATUS,
        m.TOTAL_COMPUTE_SECONDS AS RUN_DURATION_SEC,
        -- Derived: Net Liability
        COALESCE(r.BEST_ESTIMATE_LIABILITY, 0)
            + COALESCE(r.RISK_ADJUSTMENT, 0)
            + COALESCE(r.CONTRACTUAL_SERVICE_MARGIN, 0) AS NET_LIABILITY,
        -- Derived: CSM ratio
        CASE
            WHEN r.PRESENT_VALUE_FUTURE_CASHFLOWS != 0
            THEN r.CONTRACTUAL_SERVICE_MARGIN / r.PRESENT_VALUE_FUTURE_CASHFLOWS
            ELSE NULL
        END AS CSM_RATIO
    FROM ACTUARIAL_LAB_DB.RAW.ACTUARIAL_RESULTS_RAW r
    LEFT JOIN ACTUARIAL_LAB_DB.RAW.RUN_METADATA_RAW m ON r.RUN_ID = m.RUN_ID;

-- =============================================================================
-- Dynamic Table: COHORT_SUMMARY_DT (Gold layer)
-- =============================================================================
USE SCHEMA CURATED;

CREATE OR REPLACE DYNAMIC TABLE COHORT_SUMMARY_DT
    TARGET_LAG = '5 minutes'
    WAREHOUSE = ACTUARIAL_TRANSFORM_WH
AS
    SELECT
        COHORT_ID,
        VALUATION_DATE,
        REPORTING_STANDARD,
        COUNT(*) AS MODEL_POINT_COUNT,
        SUM(BEST_ESTIMATE_LIABILITY) AS TOTAL_BEL,
        SUM(RISK_ADJUSTMENT) AS TOTAL_RA,
        SUM(CONTRACTUAL_SERVICE_MARGIN) AS TOTAL_CSM,
        SUM(NET_LIABILITY) AS TOTAL_NET_LIABILITY,
        AVG(CSM_RATIO) AS AVG_CSM_RATIO,
        SUM(INSURANCE_REVENUE) AS TOTAL_REVENUE,
        SUM(INSURANCE_SERVICE_EXPENSE) AS TOTAL_EXPENSE
    FROM ACTUARIAL_LAB_DB.SILVER.RESULTS_ENRICHED_DT
    GROUP BY COHORT_ID, VALUATION_DATE, REPORTING_STANDARD;

-- =============================================================================
-- Monitor Dynamic Tables
-- =============================================================================

-- Refresh history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY())
WHERE NAME IN ('RESULTS_ENRICHED_DT', 'COHORT_SUMMARY_DT')
ORDER BY REFRESH_END_TIME DESC
LIMIT 50;

-- Check current lag and status
SHOW DYNAMIC TABLES IN SCHEMA ACTUARIAL_LAB_DB.SILVER;
SHOW DYNAMIC TABLES IN SCHEMA ACTUARIAL_LAB_DB.CURATED;

-- =============================================================================
-- Suspend/Resume (cost control)
-- =============================================================================
-- ALTER DYNAMIC TABLE ACTUARIAL_LAB_DB.SILVER.RESULTS_ENRICHED_DT SUSPEND;
-- ALTER DYNAMIC TABLE ACTUARIAL_LAB_DB.SILVER.RESULTS_ENRICHED_DT RESUME;
