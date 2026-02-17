# Sample Data

Synthetic actuarial result files for the demo. **All data is fictional.**

## Generating Data

```bash
cd python
pip install -r requirements.txt
python utils/generate_data.py --output-dir ../data-samples
```

## Files

| File | Format | Description |
|------|--------|-------------|
| `actuarial_results_run*.parquet` | Parquet | Core run outputs (IFRS 17 / US GAAP measurements) |
| `cashflow_projections_run*.parquet` | Parquet | Projected cash flows per model point (360 months) |
| `run_metadata.csv` | CSV | Run configuration and compute statistics |

## Upload to S3

```bash
aws s3 cp data-samples/ s3://YOUR-BUCKET/actuarial-results/ --recursive --exclude "README.md"
```
