-- =============================================================================
-- 02_csv_optimization.sql - CSV Partitioning & Bulk Loading Best Practices
-- =============================================================================
-- Tactical fix: best practices for partitioning and loading large CSV files.
-- This addresses immediate data-loading pain with the legacy CSV pipeline.
--
-- Run after 01_stages_formats.sql
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ACTUARIAL_LAB_DB;
USE SCHEMA RAW;
USE WAREHOUSE ACTUARIAL_INGEST_WH;

-- =============================================================================
-- KEY PRINCIPLES FOR CSV OPTIMIZATION
-- =============================================================================
--
-- 1. FILE SIZING: Split CSVs into 100-250 MB compressed files.
--    - Snowflake loads each file in a single thread.
--    - Too-large files → underutilized parallelism.
--    - Too-small files → overhead per file (especially with Snowpipe).
--
-- 2. PARALLELISM: Number of files should be >= number of warehouse nodes.
--    - XS = 1 node, S = 2, M = 4, L = 8, XL = 16.
--    - If you have 1 GB of data, split into at least 4 files for a SMALL WH.
--
-- 3. COMPRESSION: Always compress with GZIP or ZSTD before upload.
--    - Reduces S3 transfer time significantly.
--    - Snowflake decompresses automatically on load.
--
-- 4. COLUMN ORDERING: Use MATCH_BY_COLUMN_NAME to decouple file layout
--    from table DDL. This protects against column reordering in source.
--
-- 5. ERROR HANDLING: Use VALIDATION_MODE for dry-run before bulk loads.
-- =============================================================================

-- =============================================================================
-- EXAMPLE: Loading a Large CSV with Best-Practice Options
-- =============================================================================

-- File format tuned for large actuarial CSV outputs
CREATE OR REPLACE FILE FORMAT FF_CSV_OPTIMIZED
    TYPE = CSV
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL', 'null', 'NA', 'N/A')
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE   -- Tolerate extra trailing columns
    COMMENT = 'Optimized CSV format for large actuarial result files';

-- =============================================================================
-- DRY RUN: Validate CSV files before committing to a load
-- =============================================================================
-- VALIDATION_MODE = 'RETURN_ERRORS' scans the files and reports issues
-- without loading any data. Use this to catch encoding, delimiter, and
-- type-casting problems early.

-- Example: validate CSV files from S3 stage
-- COPY INTO ACTUARIAL_RESULTS_RAW
--     FROM @RAW_S3_STAGE
--     FILE_FORMAT = FF_CSV_OPTIMIZED
--     PATTERN = '.*results.*[.]csv[.]gz'
--     VALIDATION_MODE = 'RETURN_ERRORS';

-- =============================================================================
-- BULK LOAD: Recommended COPY INTO pattern for large CSV batches
-- =============================================================================

-- Example: Load with best-practice options
-- COPY INTO RUN_METADATA_RAW
--     FROM @RAW_S3_STAGE
--     FILE_FORMAT = FF_CSV_OPTIMIZED
--     PATTERN = '.*run_metadata.*[.]csv'
--     MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE  -- Match columns by header name
--     ON_ERROR = 'CONTINUE'                     -- Skip bad rows, don't abort
--     SIZE_LIMIT = 0                            -- No per-file size limit (load all)
--     PURGE = FALSE                             -- Keep files in S3 after load
--     FORCE = FALSE;                            -- Skip already-loaded files

-- =============================================================================
-- PARTITIONING GUIDANCE (Pre-Upload)
-- =============================================================================
-- If the source system produces a single massive CSV, split it before upload:
--
-- Linux/Mac:
--   # Split into ~200MB chunks with header preserved
--   head -1 big_results.csv > header.csv
--   tail -n +2 big_results.csv | split -b 200m - results_part_
--   for f in results_part_*; do cat header.csv "$f" > "${f}.csv" && rm "$f"; done
--   rm header.csv
--
--   # Compress each chunk
--   gzip results_part_*.csv
--
--   # Upload to S3
--   aws s3 cp . s3://YOUR-BUCKET/actuarial-results/ --recursive --include "*.csv.gz"
--
-- Python (pandas):
--   import pandas as pd
--   df = pd.read_csv('big_results.csv')
--   chunk_size = 500_000  # rows per file; tune based on row width
--   for i, start in enumerate(range(0, len(df), chunk_size)):
--       chunk = df.iloc[start:start+chunk_size]
--       chunk.to_csv(f'results_part_{i:03d}.csv.gz', index=False, compression='gzip')
--
-- Key: aim for 100-250 MB compressed per file.
-- =============================================================================

-- =============================================================================
-- MONITORING: Check Load History for Errors
-- =============================================================================

-- Recent COPY history (what loaded, what failed)
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'RUN_METADATA_RAW',
    START_TIME => DATEADD('hour', -24, CURRENT_TIMESTAMP())
))
ORDER BY LAST_LOAD_TIME DESC
LIMIT 20;

-- Validate a specific set of files (returns first N errors)
-- SELECT * FROM TABLE(VALIDATE(RUN_METADATA_RAW, JOB_ID => '_last'));

-- =============================================================================
-- SUMMARY: CSV Loading Checklist
-- =============================================================================
-- [ ] Split files to 100-250 MB compressed
-- [ ] Compress with GZIP or ZSTD
-- [ ] Upload to S3 with meaningful prefixes (e.g., /results/, /metadata/)
-- [ ] Use VALIDATION_MODE = 'RETURN_ERRORS' for dry-run
-- [ ] Load with MATCH_BY_COLUMN_NAME and ON_ERROR = 'CONTINUE'
-- [ ] Monitor with COPY_HISTORY and VALIDATE functions
-- [ ] Scale warehouse up (M or L) for very large batch loads, then scale back
-- =============================================================================
