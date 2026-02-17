# Result Set Publication - Snowflake Demo

Demonstrates how a legacy actuarial compute farm can publish granular IFRS 17 / US GAAP results at scale using Parquet files, S3 external stages, Snowpipe, and Secure Data Sharing.

## Architecture

```
Actuarial Compute Farm
        │
        │  Write Parquet files
        ▼
    AWS S3 (External Stage)
        │
        │  Snowpipe AUTO_INGEST
        ▼
┌─────────────────── SNOWFLAKE ───────────────────┐
│                                                  │
│  RAW ──► STAGE ──► CURATED ──► ANALYTICS        │
│  (bronze)  (silver)  (gold)     (shared views)   │
│                                      │           │
│                              Secure Share         │
│                                      │           │
└──────────────────────────────────────┼───────────┘
                                       ▼
                              End Client Account
```

## Quick Start

### 1. Generate Sample Data

```bash
cd python
pip install -r requirements.txt
python utils/generate_data.py --output-dir ../data-samples
```

### 2. Upload to S3

```bash
aws s3 cp data-samples/ s3://YOUR-BUCKET/actuarial-results/ --recursive --exclude "README.md"
```

### 3. Run SQL Scripts (in order)

In Snowsight, run each script as `ACCOUNTADMIN`:

| # | Script | What It Does |
|---|--------|--------------|
| 0 | `00_setup.sql` | Database, schemas, warehouses, roles |
| 1 | `01_stages_formats.sql` | S3 stage, file formats, raw tables |
| 2 | `02_csv_optimization.sql` | CSV bulk loading best practices (discussion) |
| 3 | `03_load_parquet.sql` | Load sample Parquet files |
| 4 | `04_snowpipe.sql` | Snowpipe for continuous ingestion |
| 5 | `05_transforms.sql` | Streams + Tasks pipeline |
| 6 | `06_dynamic_tables.sql` | Alternative: Dynamic Tables |
| 7 | `07_data_sharing.sql` | Secure Data Sharing to end client |
| 8 | `08_cost_monitoring.sql` | Resource monitors and cost queries |
| 9 | `09_scale_planning.sql` | 30TB sizing and optimization |

> Edit `01_stages_formats.sql` to use your S3 bucket URL before running.

## Repository Structure

```
├── sql/                          # Run in Snowsight (in order)
│   ├── 00_setup.sql              # Foundation
│   ├── 01_stages_formats.sql     # Ingestion setup (edit S3 URL)
│   ├── 02_csv_optimization.sql   # CSV best practices
│   ├── 03_load_parquet.sql       # Phase 1: load Parquet
│   ├── 04_snowpipe.sql           # Continuous ingestion
│   ├── 05_transforms.sql         # Streams + Tasks
│   ├── 06_dynamic_tables.sql     # Alternative transforms
│   ├── 07_data_sharing.sql       # Secure Data Sharing
│   ├── 08_cost_monitoring.sql    # Cost control
│   ├── 09_scale_planning.sql     # 30TB planning
│   └── 99_cleanup.sql            # Tear-down
│
├── python/                       # Data generation
│   ├── requirements.txt
│   └── utils/generate_data.py
│
├── data-samples/                 # Generated sample files
├── docs/                         # Demo documentation
│   ├── SE-GUIDE.md               # Demo prep and talk track
│   ├── scale-30tb.md             # 30TB best practices
│   └── snowpark-cpp-roadmap.md   # Future vision
└── PLAN.md                       # Design document
```

## Cleanup

```sql
-- Run: sql/99_cleanup.sql
```

## Documentation

| Document | Audience |
|----------|----------|
| [docs/SE-GUIDE.md](docs/SE-GUIDE.md) | Demo prep for SEs |
| [docs/scale-30tb.md](docs/scale-30tb.md) | 30TB planning discussion |
| [docs/snowpark-cpp-roadmap.md](docs/snowpark-cpp-roadmap.md) | Long-term vision |
