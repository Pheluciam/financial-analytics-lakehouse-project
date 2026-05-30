-- =============================================================================
-- Phase 4 session 4 — External table over scripts/forecast.py Parquet output
-- =============================================================================
-- Registers the forecast surface that scripts/forecast.py writes to
-- s3://phil-financial-analytics-lakehouse/forecasts/ as an Athena/Glue
-- Catalog external table. dbt-athena consumes this table via the
-- "forecast" source in dbt/models/marts/_sources.yml; mart_growth_forecast
-- is a thin model that UNIONs the historical revenue rows from
-- mart_pl_trend with the forecast rows from this table.
--
-- ARCHITECTURE DECISION — Option A (forecast architecture direction-check,
-- Phase 4 session 4 kickoff, 2026-05-30).
--
-- (a) statsmodels runs in Python, not SQL. The compute layer is Python;
--     the consumption layer is dbt-athena. Cleanest separation = Python
--     writes Parquet directly to S3, dbt-athena consumes it via an
--     external table reference. Option B (Python writes to a Bronze
--     staging table that dbt collapses) adds a Bronze hop that buys
--     nothing — the Python script already produces clean analyst-ready
--     forecast rows. Option C (Python writes the mart directly via
--     Athena CTAS) breaks the dbt lineage / docs / schema-test surface
--     for the mart, which is a regression on the consumption-pattern
--     contract (ENGINEERING_STANDARDS criterion 7).
--
-- (b) Parquet (not Iceberg) for the forecast surface. Iceberg buys
--     time-travel + ACID merge — the forecast layer has neither
--     requirement (full rewrite per forecast run, no SCD-2 history,
--     no incremental merge contract). Plain Parquet with Snappy
--     compression matches the rest of the marts surface format and
--     keeps the script's pyarrow write path simple.
--
-- (c) Schema in financial_analytics_silver (not _bronze). Bronze is the
--     immutable system-of-record snapshot per demo-durability principle 1
--     (PROJECT_PLAN.md section 10) — the forecast surface is compute
--     output, not external raw data. Silver is the consumption-side
--     schema; the forecast table lives alongside the marts it feeds.
--
-- (d) S3 LOCATION sits UNDER zone=silver/ — matches the project's
--     zone= layout convention (zone=bronze/ raw, zone=silver/ dbt-managed
--     + this forecast surface, zone=gold/ reserved) AND inherits the
--     existing phil-dbt S3SilverReadWrite IAM scope so the Python writer
--     does not need a new policy attachment. Banked at Phase 4 session 4
--     after a first-cut design at top-level forecasts/ hit S3 PutObject
--     AccessDenied — phil-dbt's S3 write scope is limited to zone=silver/
--     by the standing lakehouse-dbt-runtime-access policy.
--
-- PARTITION LAYOUT — (canonical_concept, as_of_date) two-level partitioning.
--
-- canonical_concept FIRST so forward-compatible expansion (net_income /
-- operating_income forecasts in a future session) drops cleanly under the
-- same prefix. as_of_date second so partition pruning at the dbt + PBI
-- layer matches the rest of the marts surface (which all carry as_of_date
-- in the grain).
--
-- Partition projection: type=enum on canonical_concept (single value
-- 'revenue' for session 4; future expansion adds entries); type=date on
-- as_of_date (range starts at 2026-05-30 — the first forecast run date).
-- type=enum + type=date avoid the Bronze cik partition projection
-- type=injected pitfall (LEARNINGS Phase 2 session 3 — type=injected
-- requires every WHERE clause to filter on the projected column, which
-- dbt schema tests + dbt CTAS don't do). dbt builds against this table
-- will scan without partition filters and partition projection will still
-- resolve.
--
-- SCHEMA — must match the FORECAST_SCHEMA pin in scripts/forecast.py
-- byte-for-byte. Schema drift between the Python writer and this DDL
-- surfaces as Parquet column-mismatch errors at first dbt build —
-- coordinated changes across all three artefacts (forecast.py +
-- this DDL + dbt/models/marts/_sources.yml) at every schema bump.
-- =============================================================================

-- Idempotency guard — safe to re-run during schema iteration.
DROP TABLE IF EXISTS financial_analytics_silver.forecast_surface;

CREATE EXTERNAL TABLE financial_analytics_silver.forecast_surface (
    -- 10-digit zero-padded SEC Central Index Key.
    cik string,
    -- Forecast fiscal year (latest_historical_year + 1, +2, +3).
    forecast_year int,
    -- Point forecast value in USD (DOUBLE per Python pandas → pyarrow path).
    forecast_value double,
    -- Lower bound of the 95% prediction interval.
    lower_ci_95 double,
    -- Upper bound of the 95% prediction interval.
    upper_ci_95 double,
    -- Name of the model that produced this row — either 'holt_winters_additive'
    -- or 'arima_1_1_0' (fallback for short / non-trended series).
    model_name string,
    -- Akaike Information Criterion of the model fit — lower is better.
    -- Provided as a model-quality columns for PBI consumers to filter on.
    model_aic double,
    -- Number of historical observations the model was fit on (typically 8-11
    -- per company across 10 fiscal year-ends).
    historical_obs_count int,
    -- Latest historical fiscal year — the anchor before forecast_year.
    latest_historical_year int,
    -- UTC timestamp when the Python script wrote this row.
    load_datetime timestamp,
    -- Constant 'script.forecast.py' — provenance trail.
    record_source string
)
PARTITIONED BY (
    -- Canonical concept being forecast — single value 'revenue' for session 4.
    canonical_concept string,
    -- Date the forecast run was executed (and the partition this row landed
    -- under). YYYY-MM-DD string format from date.today().isoformat() in Python.
    as_of_date string
)
STORED AS PARQUET
LOCATION 's3://phil-financial-analytics-lakehouse/zone=silver/forecasts/'
TBLPROPERTIES (
    'projection.enabled'                       = 'true',
    'projection.canonical_concept.type'        = 'enum',
    'projection.canonical_concept.values'      = 'revenue',
    'projection.as_of_date.type'               = 'date',
    'projection.as_of_date.range'              = '2026-05-30,NOW',
    'projection.as_of_date.format'             = 'yyyy-MM-dd',
    'storage.location.template'                = 's3://phil-financial-analytics-lakehouse/zone=silver/forecasts/canonical_concept=${canonical_concept}/as_of_date=${as_of_date}/'
);
