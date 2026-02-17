"""
Generate synthetic actuarial result data for the Result Set Publication demo.

Produces realistic-looking Parquet and CSV files simulating outputs from
a distributed actuarial compute grid: IFRS 17 / US GAAP measurements,
cashflow projections, and run metadata.

Usage:
    python generate_data.py [--output-dir ../data-samples] [--runs 3] [--model-points 100]
"""

import argparse
import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq

# Seed for reproducibility
random.seed(42)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
COHORTS = [
    {"id": "COH-LIFE-001", "desc": "Term Life - Individual"},
    {"id": "COH-LIFE-002", "desc": "Whole Life - Individual"},
    {"id": "COH-ANN-001",  "desc": "Fixed Annuity"},
    {"id": "COH-ANN-002",  "desc": "Variable Annuity"},
    {"id": "COH-DIS-001",  "desc": "Disability Income"},
]

SCENARIOS = ["BASE", "STRESS_UP", "STRESS_DOWN", "ADVERSE", "FAVORABLE"]

REPORTING_STANDARDS = ["IFRS17", "USGAAP"]

MODEL_VERSIONS = ["v4.2.1", "v4.3.0", "v4.3.1"]

PROJECTION_MONTHS = 360  # 30-year horizon


def _generate_run_id(run_num: int) -> str:
    return f"RUN-{run_num:03d}"


def _random_valuation_date(base: datetime, offset_days: int = 0) -> str:
    d = base + timedelta(days=offset_days)
    return d.strftime("%Y-%m-%d")


# ---------------------------------------------------------------------------
# Actuarial Results
# ---------------------------------------------------------------------------
def generate_actuarial_results(
    run_id: str,
    num_model_points: int = 100,
    valuation_date: str = "2025-12-31",
    num_scenarios: int = 3,
) -> pd.DataFrame:
    """Generate core actuarial result records for one run."""
    rows = []
    scenarios = SCENARIOS[:num_scenarios]

    for mp_idx in range(1, num_model_points + 1):
        cohort = random.choice(COHORTS)
        for scenario in scenarios:
            for standard in REPORTING_STANDARDS:
                pvfcf = round(random.uniform(50_000, 500_000), 2)
                bel = round(pvfcf * random.uniform(0.85, 1.05), 2)
                ra = round(pvfcf * random.uniform(0.02, 0.08), 2)

                # CSM is positive for profitable, negative triggers loss component
                csm_raw = round(pvfcf * random.uniform(-0.05, 0.20), 2)
                csm = max(csm_raw, 0)
                loss = abs(min(csm_raw, 0))

                revenue = round(pvfcf * random.uniform(0.03, 0.10), 2)
                expense = round(revenue * random.uniform(0.40, 0.80), 2)

                rows.append({
                    "RUN_ID": run_id,
                    "SCENARIO_ID": scenario,
                    "MODEL_POINT_ID": f"MP-{mp_idx:05d}",
                    "COHORT_ID": cohort["id"],
                    "VALUATION_DATE": valuation_date,
                    "REPORTING_STANDARD": standard,
                    "PRESENT_VALUE_FUTURE_CASHFLOWS": pvfcf,
                    "CONTRACTUAL_SERVICE_MARGIN": csm,
                    "LOSS_COMPONENT": loss,
                    "RISK_ADJUSTMENT": ra,
                    "BEST_ESTIMATE_LIABILITY": bel,
                    "INSURANCE_REVENUE": revenue,
                    "INSURANCE_SERVICE_EXPENSE": expense,
                })

    return pd.DataFrame(rows)


# ---------------------------------------------------------------------------
# Cashflow Projections
# ---------------------------------------------------------------------------
def generate_cashflow_projections(
    run_id: str,
    num_model_points: int = 100,
    months: int = PROJECTION_MONTHS,
) -> pd.DataFrame:
    """Generate monthly cashflow projection rows for one run."""
    rows = []

    for mp_idx in range(1, num_model_points + 1):
        base_premium = random.uniform(500, 5_000)
        base_claim = random.uniform(200, 3_000)
        base_expense = random.uniform(50, 500)

        for month in range(1, months + 1):
            # Decay premiums, increase claims over time (simplified)
            decay = max(0, 1 - (month / (months * 1.2)))
            growth = 1 + (month / months) * 0.3

            premium = round(base_premium * decay * random.uniform(0.9, 1.1), 2)
            claim = round(base_claim * growth * random.uniform(0.8, 1.2), 2)
            expense = round(base_expense * random.uniform(0.9, 1.1), 2)
            investment = round(premium * 0.03 * random.uniform(0.8, 1.2), 2)
            net = round(premium - claim - expense + investment, 2)
            discount = round((1 / (1 + 0.04)) ** (month / 12), 8)

            rows.append({
                "RUN_ID": run_id,
                "MODEL_POINT_ID": f"MP-{mp_idx:05d}",
                "PROJECTION_MONTH": month,
                "PREMIUM_INFLOW": premium,
                "CLAIM_OUTFLOW": claim,
                "EXPENSE_OUTFLOW": expense,
                "INVESTMENT_INCOME": investment,
                "NET_CASHFLOW": net,
                "DISCOUNT_FACTOR": discount,
            })

    return pd.DataFrame(rows)


# ---------------------------------------------------------------------------
# Run Metadata
# ---------------------------------------------------------------------------
def generate_run_metadata(
    run_id: str,
    num_model_points: int = 100,
    num_scenarios: int = 3,
    run_start: datetime | None = None,
) -> dict:
    """Generate a single run metadata record."""
    if run_start is None:
        run_start = datetime.now() - timedelta(hours=random.randint(1, 48))

    duration = random.randint(300, 7200)
    run_end = run_start + timedelta(seconds=duration)
    node_count = random.choice([8, 16, 32, 64])

    return {
        "RUN_ID": run_id,
        "RUN_START_TS": run_start.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "RUN_END_TS": run_end.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "STATUS": "COMPLETED",
        "MODEL_VERSION": random.choice(MODEL_VERSIONS),
        "SCENARIO_COUNT": num_scenarios,
        "MODEL_POINT_COUNT": num_model_points * num_scenarios * len(REPORTING_STANDARDS),
        "NODE_COUNT": node_count,
        "TOTAL_COMPUTE_SECONDS": duration * node_count,
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main(
    output_dir: str = "../data-samples",
    num_runs: int = 3,
    num_model_points: int = 100,
    num_scenarios: int = 3,
    cashflow_sample_points: int = 10,
) -> None:
    """Generate all sample data files."""
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    print("Generating synthetic actuarial data...")
    metadata_rows = []

    for run_num in range(1, num_runs + 1):
        run_id = _generate_run_id(run_num)
        val_date = _random_valuation_date(datetime(2025, 12, 31), offset_days=(run_num - 1) * 90)

        # Actuarial results
        print(f"  [{run_id}] Generating actuarial results ({num_model_points} MPs × {num_scenarios} scenarios × 2 standards)...")
        results_df = generate_actuarial_results(
            run_id=run_id,
            num_model_points=num_model_points,
            valuation_date=val_date,
            num_scenarios=num_scenarios,
        )
        results_path = output_path / f"actuarial_results_{run_id.lower().replace('-', '')}.parquet"
        results_df.to_parquet(results_path, index=False)
        print(f"    → {len(results_df)} rows → {results_path.name}")

        # Cashflow projections (subset of model points to keep file size manageable)
        sample_mps = min(cashflow_sample_points, num_model_points)
        print(f"  [{run_id}] Generating cashflow projections ({sample_mps} MPs × {PROJECTION_MONTHS} months)...")
        cf_df = generate_cashflow_projections(
            run_id=run_id,
            num_model_points=sample_mps,
            months=PROJECTION_MONTHS,
        )
        cf_path = output_path / f"cashflow_projections_{run_id.lower().replace('-', '')}.parquet"
        cf_df.to_parquet(cf_path, index=False)
        print(f"    → {len(cf_df)} rows → {cf_path.name}")

        # Run metadata
        meta = generate_run_metadata(
            run_id=run_id,
            num_model_points=num_model_points,
            num_scenarios=num_scenarios,
        )
        metadata_rows.append(meta)

    # Write run metadata as CSV
    meta_path = output_path / "run_metadata.csv"
    print(f"  Writing run metadata ({len(metadata_rows)} runs)...")
    with open(meta_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=metadata_rows[0].keys())
        writer.writeheader()
        writer.writerows(metadata_rows)
    print(f"    → {meta_path.name}")

    print(f"\nAll files written to {output_path.resolve()}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate synthetic actuarial data")
    parser.add_argument("--output-dir", default="../data-samples", help="Output directory")
    parser.add_argument("--runs", type=int, default=3, help="Number of runs to generate")
    parser.add_argument("--model-points", type=int, default=100, help="Model points per run")
    parser.add_argument("--scenarios", type=int, default=3, help="Scenarios per run")
    parser.add_argument("--cashflow-points", type=int, default=10, help="Model points with cashflow projections")
    args = parser.parse_args()

    main(
        output_dir=args.output_dir,
        num_runs=args.runs,
        num_model_points=args.model_points,
        num_scenarios=args.scenarios,
        cashflow_sample_points=args.cashflow_points,
    )
