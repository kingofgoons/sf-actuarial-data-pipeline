-- =============================================================================
-- 09_scale_planning.sql - 30TB Scale Planning and Optimization
-- =============================================================================
-- Planning queries and configuration guidance for scaling the result set
-- publication architecture to ~30TB of actuarial data.
--
-- This is a discussion script — run the queries to generate sizing estimates,
-- then talk through the recommendations.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ACTUARIAL_LAB_DB;
USE WAREHOUSE ACTUARIAL_ANALYTICS_WH;

-- =============================================================================
-- 1. SIZING ESTIMATES: 30TB Ingestion
-- =============================================================================
-- Assumptions (adjust for your actual workload):
--   - 30 TB total Parquet data per reporting cycle
--   - Files are ~250 MB compressed (Snappy/ZSTD)
--   - Each run produces ~500 GB - 2 TB of output
--
-- Back-of-envelope:
--   30 TB / 250 MB per file = ~120,000 files per cycle
--
-- Warehouse sizing for COPY INTO:
--   XL warehouse (16 nodes) can load ~16 files in parallel
--   120,000 files / 16 parallel = ~7,500 rounds
--   At ~5 seconds per round ≈ 10-12 hours on XL
--   Consider 2XL or 3XL for faster bulk loads.

SELECT
    30 * 1024 AS TOTAL_GB,
    250 AS FILE_SIZE_MB,
    CEIL((30 * 1024 * 1024) / 250) AS ESTIMATED_FILES,
    16 AS XL_PARALLEL_THREADS,
    CEIL(CEIL((30 * 1024 * 1024) / 250) / 16) AS LOAD_ROUNDS_XL,
    CEIL(CEIL((30 * 1024 * 1024) / 250) / 16) * 5 / 3600 AS EST_HOURS_XL;

-- =============================================================================
-- 2. SNOWPIPE vs COPY INTO: Cost Comparison at Scale
-- =============================================================================
-- Snowpipe serverless cost: ~0.06 credits per 1,000 files
--   120,000 files × 0.06 / 1000 = ~7.2 credits per cycle
--
-- COPY INTO with XL warehouse:
--   XL = 16 credits/hour
--   ~10 hours = ~160 credits per cycle
--
-- But Snowpipe cost is per-file overhead; COPY INTO pays for compute time.
-- For large batches arriving at once, COPY INTO with a right-sized warehouse
-- is typically more cost-effective.
--
-- Snowpipe wins when files trickle in continuously across many small runs.

SELECT
    120000 AS FILES_PER_CYCLE,
    ROUND(120000 * 0.06 / 1000, 2) AS SNOWPIPE_CREDITS,
    16 AS XL_CREDITS_PER_HOUR,
    10 AS EST_LOAD_HOURS_XL,
    16 * 10 AS COPY_INTO_CREDITS,
    'Snowpipe cheaper for trickle; COPY INTO cheaper for large batches' AS GUIDANCE;

-- =============================================================================
-- 3. CLUSTERING KEY RECOMMENDATIONS
-- =============================================================================
-- For actuarial query patterns, typical access is:
--   - By VALUATION_DATE (time series across reporting periods)
--   - By COHORT_ID (aggregation unit for IFRS 17)
--   - By REPORTING_STANDARD (IFRS17 vs USGAAP partition)
--
-- Recommended clustering keys:

-- ALTER TABLE RAW.ACTUARIAL_RESULTS_RAW
--     CLUSTER BY (VALUATION_DATE, REPORTING_STANDARD, COHORT_ID);

-- For cashflow projections (queried by run + model point):
-- ALTER TABLE RAW.CASHFLOW_PROJECTIONS_RAW
--     CLUSTER BY (RUN_ID, MODEL_POINT_ID);

-- Monitor clustering depth:
-- SELECT SYSTEM$CLUSTERING_INFORMATION('ACTUARIAL_RESULTS_RAW', '(VALUATION_DATE, REPORTING_STANDARD)');

-- =============================================================================
-- 4. MULTI-CLUSTER WAREHOUSE for Concurrent Analysts
-- =============================================================================
-- If multiple analysts query curated data simultaneously, use a multi-cluster
-- warehouse to avoid queuing.

-- ALTER WAREHOUSE ACTUARIAL_ANALYTICS_WH SET
--     MIN_CLUSTER_COUNT = 1
--     MAX_CLUSTER_COUNT = 4
--     SCALING_POLICY = 'STANDARD';  -- Scale out when queries queue

-- =============================================================================
-- 5. STORAGE OPTIMIZATION
-- =============================================================================
-- At 30TB, storage costs matter. Key levers:
--
-- a) TIME_TRAVEL_RETENTION: Default 1 day. For raw landing tables that are
--    append-only, consider reducing to 0 days if recovery isn't critical.
--    ALTER TABLE RAW.ACTUARIAL_RESULTS_RAW SET DATA_RETENTION_TIME_IN_DAYS = 0;
--
-- b) TRANSIENT TABLES: For staging/intermediate tables that are recomputable,
--    use TRANSIENT to skip Fail-safe storage (saves ~7 days of storage).
--
-- c) Parquet compression: Ensure source files use Snappy or ZSTD.
--    Snowflake re-encodes internally but ingestion is faster with pre-compressed.

-- Current storage footprint
SELECT
    TABLE_SCHEMA,
    SUM(BYTES) / (1024*1024*1024) AS TOTAL_GB,
    SUM(ACTIVE_BYTES) / (1024*1024*1024) AS ACTIVE_GB,
    SUM(TIME_TRAVEL_BYTES) / (1024*1024*1024) AS TIME_TRAVEL_GB,
    SUM(FAILSAFE_BYTES) / (1024*1024*1024) AS FAILSAFE_GB
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
WHERE TABLE_CATALOG = 'ACTUARIAL_LAB_DB'
  AND DELETED = FALSE
GROUP BY TABLE_SCHEMA
ORDER BY TOTAL_GB DESC;

-- =============================================================================
-- 6. PHASE 2: Synthetic 30TB Data Generation (Future Work)
-- =============================================================================
-- To demonstrate ingestion at realistic scale, a future phase would:
--   1. Scale up the Python data generator to produce ~120,000 Parquet files
--   2. Upload to S3 in batches
--   3. Run COPY INTO with an XL or 2XL warehouse and measure throughput
--   4. Compare Snowpipe vs COPY INTO cost/latency at actual scale
--
-- This is not part of the Phase 1 demo. Phase 1 uses small sample files
-- to prove the architecture works end-to-end.
-- =============================================================================
