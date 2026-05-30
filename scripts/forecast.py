"""Phase 4 session 4 — Holt-Winters revenue forecast for the S&P 100 universe.

Reads the post-cascade mart_pl_trend revenue surface from Athena, fits a
per-company Holt-Winters Exponential Smoothing model with an additive
trend over the available 10-year fiscal-year history, projects 3 years
forward at 95% prediction intervals, and writes the result as Parquet
to s3://<bucket>/forecasts/canonical_concept=revenue/as_of_date=<YYYY-MM-DD>/.

Companies with fewer than 4 fiscal-year observations or with a flat /
non-trended series that fails the Holt-Winters fit fall back to an
ARIMA(1,1,0) drift-walk forecast — also computed via statsmodels —
keeping the per-company coverage complete. Companies with fewer than 2
observations are skipped (insufficient signal for ANY forecast).

Forecast horizon = 3 fiscal years beyond the latest observed fiscal year
per company. Forecast values + lower/upper 95% prediction bounds are
emitted on the same row as the model that produced them; the model name
and the AIC of the fit ship as columns so downstream PBI consumers can
filter / colour by which model rendered which point.

Per Risk 38 lock (LEARNINGS, 2026-05-29 Phase 3 session 14 forward-verify):
statsmodels.tsa.holtwinters.ExponentialSmoothing is the senior-DE choice
for annual cadence financial time series — pure-Python install (no Stan
C++ compile step), classical methods fit the 10-year horizon cleanly,
prediction intervals out of the box.

Forecast architecture = Option A (Phase 4 session 4 direction-check,
2026-05-30): Python writes Parquet directly to S3; dbt-athena consumes
via a sources entry + external table (sql/ddl/03_create_forecast_external_table.sql).
Clean compute / consumption separation. mart_growth_forecast is a thin
dbt model UNION-ing the historical mart_pl_trend revenue rows with the
forecast surface from this script.

Run:
    python scripts/forecast.py                         # default: all S&P 100 CIKs
    python scripts/forecast.py --cik 320193            # Apple only
    python scripts/forecast.py --horizon-years 5       # 5-year forecast
    python scripts/forecast.py --dry-run               # fit but skip S3 write

Exit codes:
    0 — forecast pipeline ran end-to-end and Parquet landed on S3
    1 — unexpected error
    2 — credentials missing or invalid
    3 — S3 bucket inaccessible
    4 — Athena query failure
    5 — no historical rows returned (empty mart_pl_trend revenue surface)
    6 — Parquet write failure

Walkthrough: GOLD_MARTS_PIPELINE.md section 10 + DBT_PIPELINE.md section 9.6.
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
import time
import warnings
from datetime import date, datetime, timezone
from io import BytesIO

import boto3
import numpy as np
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from botocore.exceptions import (
    ClientError,
    EndpointConnectionError,
    NoCredentialsError,
    PartialCredentialsError,
)
from dotenv import load_dotenv
from statsmodels.tsa.arima.model import ARIMA
from statsmodels.tsa.holtwinters import ExponentialSmoothing

EXIT_OK = 0
EXIT_UNEXPECTED = 1
EXIT_AUTH = 2
EXIT_BUCKET = 3
EXIT_ATHENA = 4
EXIT_EMPTY_INPUT = 5
EXIT_S3_PUT = 6

REQUIRED_ENV_VARS = (
    "AWS_DBT_ACCESS_KEY_ID",
    "AWS_DBT_SECRET_ACCESS_KEY",
    "AWS_DEFAULT_REGION",
    "S3_BUCKET_NAME",
)

# Athena coordinates — match the dbt-athena profile and the existing
# workgroup convention.
ATHENA_DATABASE = "financial_analytics_silver"
ATHENA_WORKGROUP = "wg_financial_analytics"

# Forecast scope — revenue only for session 4. Risk 38 locked the surface
# as analyst-conventional 10-K-equivalent annual revenue trajectory.
# Forecast horizon defaulted to 3 years (analyst-conventional 3-year out
# view; PBI consumers can filter further).
FORECAST_CANONICAL = "revenue"
DEFAULT_HORIZON_YEARS = 3

# Minimum observation count per company for Holt-Winters (needs at least
# 4 points for a meaningful trend fit) + ARIMA fallback (needs 2 for
# any first-difference signal).
MIN_OBS_HOLT_WINTERS = 4
MIN_OBS_ARIMA = 2

# Confidence level for prediction intervals. 95% is the project default
# matching analyst convention; 80% / 99% alternatives are a downstream
# PBI consumer concern, not a script concern.
CONFIDENCE_LEVEL = 0.95

# S3 partition layout — canonical_concept first (forward-compatible with
# net_income / operating_income forecasts in a future session), then
# as_of_date so partition pruning at the dbt + PBI layer matches the
# rest of the marts surface.
#
# Prefix sits UNDER zone=silver/ to inherit the project's standing S3
# IAM scope. phil-dbt's lakehouse-dbt-runtime-access policy grants
# S3SilverReadWrite on arn:aws:s3:::phil-financial-analytics-lakehouse/zone=silver/*
# — co-locating the forecast surface here means no IAM scope expansion
# is needed for the Python writer or downstream dbt-athena reader.
# Matches the project's zone= S3 layout convention (zone=bronze/ raw,
# zone=silver/ dbt-managed + this forecast surface, zone=gold/ reserved).
S3_FORECAST_PREFIX = "zone=silver/forecasts"

# Forecast output schema. Pinned explicitly so the Parquet rowgroup metadata
# matches the dbt sources entry + the external-table DDL exactly. Adding /
# reordering columns requires a coordinated change across all three.
FORECAST_SCHEMA = pa.schema([
    pa.field("cik", pa.string()),
    pa.field("forecast_year", pa.int32()),
    pa.field("forecast_value", pa.float64()),
    pa.field("lower_ci_95", pa.float64()),
    pa.field("upper_ci_95", pa.float64()),
    pa.field("model_name", pa.string()),
    pa.field("model_aic", pa.float64()),
    pa.field("historical_obs_count", pa.int32()),
    pa.field("latest_historical_year", pa.int32()),
    pa.field("load_datetime", pa.timestamp("us", tz="UTC")),
    pa.field("record_source", pa.string()),
])

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-7s %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("forecast")

# Silence statsmodels convergence warnings — fall-through to ARIMA fallback
# handles the failure path cleanly. Convergence warnings during fit are
# noise in the per-company loop output; real fit failures surface as
# exceptions and route to the fallback.
warnings.filterwarnings("ignore", category=UserWarning, module="statsmodels")
warnings.filterwarnings("ignore", category=RuntimeWarning, module="statsmodels")


def load_config() -> dict[str, str]:
    """Load .env and validate all required env vars present."""
    load_dotenv()
    missing = [name for name in REQUIRED_ENV_VARS if not os.getenv(name)]
    if missing:
        log.error("Missing required env vars: %s", ", ".join(missing))
        sys.exit(EXIT_AUTH)
    return {name: os.environ[name] for name in REQUIRED_ENV_VARS}


def build_aws_clients(config: dict[str, str]) -> tuple[object, object]:
    """Build boto3 Athena + S3 clients using the phil-dbt programmatic identity."""
    session = boto3.Session(
        aws_access_key_id=config["AWS_DBT_ACCESS_KEY_ID"],
        aws_secret_access_key=config["AWS_DBT_SECRET_ACCESS_KEY"],
        region_name=config["AWS_DEFAULT_REGION"],
    )
    return session.client("athena"), session.client("s3")


def run_athena_query(athena_client, s3_client, bucket: str, sql: str,
                     dtype: dict[str, type] | None = None) -> pd.DataFrame:
    """Submit a query to Athena, wait for completion, return result as DataFrame.

    Uses the workgroup's default query-result location (configured at workgroup
    setup time). Polls every 1s with a 120s wall-clock cap — annual-mart-scale
    queries return in <10s typically.

    dtype: optional pandas dtype mapping passed to read_csv. Required for
    string-shaped identifiers like cik that pandas would otherwise infer as
    int64 (stripping leading zeros) from the CSV result file.
    """
    output_location = f"s3://{bucket}/athena-results/"
    response = athena_client.start_query_execution(
        QueryString=sql,
        QueryExecutionContext={"Database": ATHENA_DATABASE},
        WorkGroup=ATHENA_WORKGROUP,
        ResultConfiguration={"OutputLocation": output_location},
    )
    query_id = response["QueryExecutionId"]
    log.info("Athena query submitted — id=%s", query_id)

    deadline = time.time() + 120
    while time.time() < deadline:
        status = athena_client.get_query_execution(QueryExecutionId=query_id)
        state = status["QueryExecution"]["Status"]["State"]
        if state == "SUCCEEDED":
            break
        if state in ("FAILED", "CANCELLED"):
            reason = status["QueryExecution"]["Status"].get("StateChangeReason", "unknown")
            log.error("Athena query %s — %s: %s", query_id, state, reason)
            sys.exit(EXIT_ATHENA)
        time.sleep(1.0)
    else:
        log.error("Athena query %s timed out after 120s", query_id)
        sys.exit(EXIT_ATHENA)

    # Read the result CSV that Athena dropped into the workgroup output path.
    result_key = f"athena-results/{query_id}.csv"
    obj = s3_client.get_object(Bucket=bucket, Key=result_key)
    df = pd.read_csv(BytesIO(obj["Body"].read()), dtype=dtype)
    log.info("Athena result loaded — %d rows, %d cols", len(df), len(df.columns))
    return df


def fetch_historical_revenue(athena_client, s3_client, bucket: str, cik_filter: list[str] | None) -> pd.DataFrame:
    """Pull the revenue history from mart_pl_trend at the latest as_of_date.

    Per-company latest snapshot only — historical revenue trajectory per
    company doesn't change across as_of_dates in the current single-Bronze-
    extract data, and forecasting against the latest snapshot matches what
    PBI consumers will see. mart_pl_trend already applies the Risk 42 dedup +
    Risk 48 period-shape filter; this script consumes the clean surface.
    """
    cik_clause = ""
    if cik_filter:
        quoted = ", ".join(f"'{c}'" for c in cik_filter)
        cik_clause = f"AND cik IN ({quoted})"

    sql = f"""
    WITH latest_as_of AS (
        SELECT MAX(as_of_date) AS as_of_date_latest
        FROM mart_pl_trend
        WHERE canonical_concept = '{FORECAST_CANONICAL}'
    )
    SELECT
        m.cik,
        m.entity_name,
        m.fiscal_year,
        CAST(m.value_numeric AS DOUBLE) AS value_numeric,
        m.as_of_date
    FROM mart_pl_trend m
    INNER JOIN latest_as_of l
        ON m.as_of_date = l.as_of_date_latest
    WHERE m.canonical_concept = '{FORECAST_CANONICAL}'
      AND m.value_numeric IS NOT NULL
      {cik_clause}
    ORDER BY m.cik, m.fiscal_year
    """
    # cik forced to string dtype at CSV read — pandas would otherwise auto-
    # infer it as int64 from the all-numeric Athena result, stripping the
    # 10-digit zero-padding and breaking the downstream Parquet schema +
    # the join surface against mart_pl_trend (cik string '0000320193').
    df = run_athena_query(athena_client, s3_client, bucket, sql,
                          dtype={"cik": str})
    if df.empty:
        log.error("No historical revenue rows returned — aborting forecast pipeline")
        sys.exit(EXIT_EMPTY_INPUT)
    # Defensive zero-pad in case Athena ever returns cik without leading zeros.
    df["cik"] = df["cik"].astype(str).str.zfill(10)
    return df


def forecast_company(cik: str, series: pd.Series, horizon: int) -> pd.DataFrame:
    """Fit Holt-Winters → fallback ARIMA → emit forecast rows for one company.

    series: pandas Series indexed by fiscal_year (int), values in USD.
    Returns a DataFrame with horizon rows — one row per forecast year.
    """
    n_obs = len(series)
    latest_year = int(series.index.max())
    forecast_years = list(range(latest_year + 1, latest_year + 1 + horizon))

    # Holt-Winters with additive trend fits annual revenue cleanly when the
    # series has enough points + a non-degenerate trend. Otherwise the fit
    # raises and we fall through to ARIMA.
    if n_obs >= MIN_OBS_HOLT_WINTERS:
        try:
            model = ExponentialSmoothing(
                series.values,
                trend="add",
                seasonal=None,
                initialization_method="estimated",
            )
            fit = model.fit(optimized=True)
            # Force ndarray to bypass any Series-index alignment surprises
            # at the downstream DataFrame constructor.
            point = np.asarray(fit.forecast(steps=horizon), dtype=np.float64)
            # Approximate 95% prediction interval via residual std deviation.
            # statsmodels' ExponentialSmoothing doesn't expose conf_int on
            # the deterministic forecast path; the residual-stddev approximation
            # widens with horizon step, which matches analyst expectation
            # (further-out forecasts carry more uncertainty).
            resid_std = float(pd.Series(fit.resid).std(ddof=1)) if fit.resid is not None else 0.0
            z = 1.96  # 95% confidence
            steps = np.arange(1, horizon + 1, dtype=np.float64)
            widen = z * resid_std * np.sqrt(steps)
            return pd.DataFrame({
                "cik": cik,
                "forecast_year": np.asarray(forecast_years, dtype=np.int32),
                "forecast_value": point,
                "lower_ci_95": point - widen,
                "upper_ci_95": point + widen,
                "model_name": "holt_winters_additive",
                "model_aic": float(fit.aic),
                "historical_obs_count": np.int32(n_obs),
                "latest_historical_year": np.int32(latest_year),
            })
        except Exception as e:
            log.warning("cik=%s Holt-Winters failed (%s) — falling back to ARIMA(1,1,0)", cik, e)

    # ARIMA(1,1,0) fallback — drift walk with one autoregressive lag.
    # Fits even short / flat series; less analyst-credible at horizon but
    # keeps per-company coverage complete.
    if n_obs >= MIN_OBS_ARIMA:
        try:
            arima_fit = ARIMA(series.values, order=(1, 1, 0)).fit()
            forecast_result = arima_fit.get_forecast(steps=horizon)
            # Force ndarray — statsmodels' conf_int return type varies between
            # pd.DataFrame and np.ndarray depending on the model's data index.
            # np.asarray collapses both to a 2D ndarray so positional column
            # slicing is unambiguous.
            point = np.asarray(forecast_result.predicted_mean, dtype=np.float64)
            ci = np.asarray(forecast_result.conf_int(alpha=1 - CONFIDENCE_LEVEL), dtype=np.float64)
            return pd.DataFrame({
                "cik": cik,
                "forecast_year": np.asarray(forecast_years, dtype=np.int32),
                "forecast_value": point,
                "lower_ci_95": ci[:, 0],
                "upper_ci_95": ci[:, 1],
                "model_name": "arima_1_1_0",
                "model_aic": float(arima_fit.aic),
                "historical_obs_count": np.int32(n_obs),
                "latest_historical_year": np.int32(latest_year),
            })
        except Exception as e:
            log.warning("cik=%s ARIMA fallback failed (%s) — skipping", cik, e)
            return pd.DataFrame()

    log.info("cik=%s skipped — only %d observation(s), below MIN_OBS_ARIMA=%d",
             cik, n_obs, MIN_OBS_ARIMA)
    return pd.DataFrame()


def run_forecasts(history_df: pd.DataFrame, horizon: int) -> pd.DataFrame:
    """Iterate per-company, return concatenated forecast surface."""
    frames: list[pd.DataFrame] = []
    n_total = history_df["cik"].nunique()
    for i, (cik, group) in enumerate(history_df.groupby("cik"), start=1):
        series = pd.Series(
            data=group["value_numeric"].values,
            index=group["fiscal_year"].astype(int).values,
        ).sort_index()
        # Drop any duplicate fiscal-year rows defensively (mart dedup should
        # already preclude these — belt-and-braces).
        series = series[~series.index.duplicated(keep="last")]
        fc = forecast_company(cik, series, horizon)
        if not fc.empty:
            frames.append(fc)
        if i % 25 == 0 or i == n_total:
            log.info("Forecast progress — %d / %d companies fit", i, n_total)

    if not frames:
        log.error("Zero successful forecasts across the universe — aborting")
        sys.exit(EXIT_UNEXPECTED)

    result = pd.concat(frames, ignore_index=True)
    # Floor to microsecond — pyarrow's pinned timestamp[us, UTC] target type
    # rejects ns-precision input under safe-cast (truncation would lose
    # precision). Flooring at source keeps the safe cast valid.
    result["load_datetime"] = pd.Timestamp.now(tz="UTC").floor("us")
    result["record_source"] = "script.forecast.py"
    log.info("Forecast surface complete — %d rows across %d companies",
             len(result), result["cik"].nunique())
    return result


def write_parquet_to_s3(forecast_df: pd.DataFrame, s3_client, bucket: str,
                        as_of_date: date, dry_run: bool) -> None:
    """Serialise to a single Parquet file under the partitioned S3 prefix.

    Single-file write per (canonical_concept, as_of_date) partition is
    correct at S&P 100 scale (~300 forecast rows = <100KB). Snappy
    compression matches the project's Iceberg/Parquet convention.
    """
    # Reorder + cast columns to the pinned FORECAST_SCHEMA exactly so the
    # Parquet rowgroup metadata aligns with the dbt sources entry + the
    # external-table DDL. Explicit pandas-side narrowing of int columns
    # to int32 sidesteps pyarrow's strict safe-cast on int64 → int32
    # (defensive — values fit the target dtype trivially).
    forecast_df = forecast_df[[f.name for f in FORECAST_SCHEMA]].copy()
    forecast_df["forecast_year"] = forecast_df["forecast_year"].astype("int32")
    forecast_df["historical_obs_count"] = forecast_df["historical_obs_count"].astype("int32")
    forecast_df["latest_historical_year"] = forecast_df["latest_historical_year"].astype("int32")
    table = pa.Table.from_pandas(forecast_df, schema=FORECAST_SCHEMA, preserve_index=False)

    buf = BytesIO()
    pq.write_table(table, buf, compression="snappy")
    buf.seek(0)
    payload = buf.getvalue()

    key = (
        f"{S3_FORECAST_PREFIX}/"
        f"canonical_concept={FORECAST_CANONICAL}/"
        f"as_of_date={as_of_date.isoformat()}/"
        f"forecast.parquet"
    )

    if dry_run:
        log.info("DRY RUN — would have written %d bytes to s3://%s/%s",
                 len(payload), bucket, key)
        return

    try:
        s3_client.put_object(
            Bucket=bucket,
            Key=key,
            Body=payload,
            ContentType="application/octet-stream",
        )
        log.info("Parquet landed — s3://%s/%s (%d bytes)", bucket, key, len(payload))
    except ClientError as e:
        log.error("S3 put_object failed: %s", e)
        sys.exit(EXIT_S3_PUT)


def parse_args() -> argparse.Namespace:
    """Parse CLI args."""
    p = argparse.ArgumentParser(description="Per-company Holt-Winters revenue forecast")
    p.add_argument("--cik", action="append",
                   help="10-digit zero-padded CIK to forecast for (repeatable; default: all)")
    p.add_argument("--horizon-years", type=int, default=DEFAULT_HORIZON_YEARS,
                   help=f"Forecast horizon in years (default: {DEFAULT_HORIZON_YEARS})")
    p.add_argument("--dry-run", action="store_true",
                   help="Fit + log but skip S3 write")
    return p.parse_args()


def main() -> int:
    """Pipeline orchestrator. Returns exit code."""
    args = parse_args()
    config = load_config()
    bucket = config["S3_BUCKET_NAME"]

    try:
        athena_client, s3_client = build_aws_clients(config)
    except (NoCredentialsError, PartialCredentialsError) as e:
        log.error("AWS credentials invalid: %s", e)
        return EXIT_AUTH
    except EndpointConnectionError as e:
        log.error("AWS endpoint unreachable: %s", e)
        return EXIT_BUCKET

    # Pre-flight — confirm the bucket is reachable under the phil-dbt identity.
    try:
        s3_client.head_bucket(Bucket=bucket)
    except ClientError as e:
        log.error("Bucket inaccessible: %s — %s", bucket, e)
        return EXIT_BUCKET

    log.info("Forecast pipeline starting — canonical=%s, horizon=%d years, dry_run=%s",
             FORECAST_CANONICAL, args.horizon_years, args.dry_run)

    history_df = fetch_historical_revenue(athena_client, s3_client, bucket, args.cik)
    forecast_df = run_forecasts(history_df, args.horizon_years)

    # as_of_date for the forecast partition = today (UTC) — the forecast
    # run captures a point-in-time view of the universe at the run date.
    write_parquet_to_s3(forecast_df, s3_client, bucket,
                        date.today(), args.dry_run)

    log.info("Forecast pipeline complete — exit %d", EXIT_OK)
    return EXIT_OK


sys.exit(main())
