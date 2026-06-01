-- dbt/models/marts/mart_growth_forecast.sql
--
-- Gold-layer Growth & Forecast mart — FOURTH mart in the project, shipped
-- at Phase 4 session 4. Per-company annual revenue trajectory carrying
-- BOTH the historical observed values (from mart_pl_trend) AND the
-- forward-looking 3-year forecast surface (from scripts/forecast.py via
-- the forecast_surface external table). Consumed downstream by Power BI
-- Desktop via the Amazon Athena ODBC v2 driver + Windows System DSN
-- "FinancialAnalyticsAthena" (Risk 39 prerequisite shipped at Phase 4
-- session 1 kickoff).
--
-- THE FORECAST MART. Phase 4's fourth and final non-aggregation mart —
-- the "where is the business going" lens. Different shape from the prior
-- 3 marts: this mart is a UNION over two sources rather than a single
-- equi-join chain over BV + RV. The historical leg reuses mart_pl_trend's
-- revenue rows directly (already canonical-collapsed, Risk 42 deduped,
-- Risk 48 period-filtered, Risk 45/47 tag-preferred — every upstream data
-- quality decision is already baked in). The forecast leg reads from the
-- forecast_surface external table that scripts/forecast.py writes to S3
-- via the Option A forecast architecture (Phase 4 session 4 kickoff
-- direction-check, 2026-05-30).
--
-- FORECAST ARCHITECTURE OVERVIEW. statsmodels runs in Python, not SQL.
-- scripts/forecast.py (boto3 Athena → pandas → statsmodels.tsa →
-- pyarrow → S3 Parquet) is the compute layer. The forecast_surface
-- external table (sql/ddl/03_create_forecast_external_table.sql) +
-- this mart are the consumption layer. Per-company Holt-Winters
-- Exponential Smoothing with additive trend is the primary model;
-- ARIMA(1,1,0) drift-walk is the fallback for companies with fewer than
-- 4 fiscal-year observations OR where the Holt-Winters fit raised.
-- Companies with fewer than 2 observations are skipped at the script
-- level (no row emitted for them in either leg of this mart's forecast
-- side — historical rows still appear from mart_pl_trend).
--
-- Grain. Composite (cik, canonical_concept, fiscal_year, as_of_date,
-- row_kind). row_kind is the discriminator between the historical and
-- forecast legs ('historical' vs 'forecast') — analyst-facing column
-- that PBI consumers filter / colour by. fiscal_year column unifies the
-- historical_year (from mart_pl_trend) and forecast_year (from
-- forecast_surface) under one column name so PBI's time-axis grouping
-- works without a derived column. as_of_date is RETAINED on the historical
-- leg from mart_pl_trend; the forecast leg projects the script's
-- as_of_date partition (the forecast run date) into the same column,
-- matching the grain shape of the prior 3 marts.
--
-- Canonical concept filter. Implicit — both legs ship rows where
-- canonical_concept = 'revenue' for Phase 4 session 4. Forward-compatible
-- expansion to net_income / operating_income forecasts is purely a
-- script + external-table partition extension; this mart's SQL doesn't
-- need to change.
--
-- Annual filter. Historical leg inherits mart_pl_trend's fiscal_period = 'FY'
-- filter. Forecast leg is annual by construction (statsmodels fits per
-- fiscal year).
--
-- Forecast-specific columns. forecast_value, lower_ci_95, upper_ci_95,
-- model_name, model_aic are NULL on the historical leg and populated on
-- the forecast leg. value_numeric is populated on the historical leg
-- (the analyst-observed value) and NULL on the forecast leg (where the
-- forecast_value column carries the analogous signal). PBI consumers can
-- COALESCE(value_numeric, forecast_value) for a single trend line, or
-- filter on row_kind for separate historical/forecast visualisations
-- with the CI band rendered as a shaded area on the forecast leg only.
--
-- Surrogate PK. mart_growth_forecast_hk = SHA-256 over the 5-column
-- composite grain (cik || '||' || canonical_concept || '||' || fiscal_year
-- || '||' || as_of_date || '||' || row_kind), matching the hash-chain
-- convention of the prior 3 marts.
--
-- Entity descriptor. Historical leg carries entity_name from mart_pl_trend
-- directly. Forecast leg LEFT JOINs sat_company_metadata via hub_company
-- on cik to attach entity_name to the forecast rows — separate single-
-- equi-join (forecast_surface has no entity_name column to avoid coupling
-- the Python writer to the silver-layer naming convention).
--
-- Materialization. Plain Iceberg table per marts layer defaults in
-- dbt_project.yml — full rebuild per dbt run. Risk 2 Iceberg-merge bug
-- class structurally avoided.
--
-- Verification surface. sql/verify/16_phase4_marts_growth_forecast_verification.sql
-- runs PASS/FAIL CTEs against this mart matching the 13-15 pattern.
--
-- Walkthrough: GOLD_MARTS_PIPELINE.md section 10 + DBT_PIPELINE.md section 9.6.

WITH historical AS (
    -- Historical leg — reuse mart_pl_trend's already-cleaned revenue rows
    -- directly. No re-derivation of the BV + RV equi-join chain — that
    -- chain has already run in mart_pl_trend and applied every Risk
    -- 42/45/47/48 fix. mart_pl_trend's grain (cik, as_of_date, fiscal_year,
    -- canonical_concept) carries one row per analyst-facing fiscal-year
    -- snapshot; we filter to canonical_concept = 'revenue' to match the
    -- forecast leg's scope. row_kind = 'historical' is the discriminator
    -- column.
    SELECT
        m.cik,
        m.entity_name,
        m.as_of_date,
        m.fiscal_year,
        m.canonical_concept,
        m.value_numeric,
        CAST(NULL AS DOUBLE) AS forecast_value,
        CAST(NULL AS DOUBLE) AS lower_ci_95,
        CAST(NULL AS DOUBLE) AS upper_ci_95,
        CAST(NULL AS VARCHAR) AS model_name,
        CAST(NULL AS DOUBLE) AS model_aic,
        CAST(NULL AS INTEGER) AS historical_obs_count,
        CAST(NULL AS INTEGER) AS latest_historical_year,
        'historical' AS row_kind
    FROM {{ ref('mart_pl_trend') }} m
    WHERE m.canonical_concept = 'revenue'
),

forecast_raw AS (
    -- Forecast leg — read from the forecast_surface external table that
    -- scripts/forecast.py writes to S3. Filter to canonical_concept =
    -- 'revenue' (the only value present today; the filter is forward-
    -- compatible). Latest as_of_date partition only — each forecast run
    -- writes a new partition, but the mart represents the most-recent
    -- forecast view per analyst convention. Earlier runs remain on S3 for
    -- audit + reproducibility.
    SELECT
        f.cik,
        CAST(f.as_of_date AS DATE) AS as_of_date,
        f.forecast_year,
        f.canonical_concept,
        f.forecast_value,
        f.lower_ci_95,
        f.upper_ci_95,
        f.model_name,
        f.model_aic,
        f.historical_obs_count,
        f.latest_historical_year
    FROM {{ source('forecast', 'forecast_surface') }} f
    WHERE f.canonical_concept = 'revenue'
      AND f.as_of_date = (
          SELECT MAX(as_of_date)
          FROM {{ source('forecast', 'forecast_surface') }}
          WHERE canonical_concept = 'revenue'
      )
),

forecast_enriched AS (
    -- Attach entity_name to forecast rows via hub_company → sat_company_metadata.
    -- LEFT JOIN through hub_company by cik (10-digit zero-padded both sides);
    -- INNER JOIN to sat_company_metadata is safe given the 1:1 hub→sat
    -- relationship in current data. forecast_surface has no entity_name
    -- column by design — the Python writer doesn't need to couple to the
    -- silver-layer naming convention.
    SELECT
        f.cik,
        scm.entity_name,
        f.as_of_date,
        f.forecast_year AS fiscal_year,
        f.canonical_concept,
        CAST(NULL AS DECIMAL(28, 2)) AS value_numeric,
        f.forecast_value,
        f.lower_ci_95,
        f.upper_ci_95,
        f.model_name,
        f.model_aic,
        f.historical_obs_count,
        f.latest_historical_year,
        'forecast' AS row_kind
    FROM forecast_raw f
    INNER JOIN {{ ref('hub_company') }} hc
        ON hc.cik = f.cik
    INNER JOIN {{ ref('sat_company_metadata') }} scm
        ON scm.hub_company_hk = hc.hub_company_hk
),

unioned AS (
    -- UNION ALL preserves both legs in the same mart row stream.
    -- No deduplication needed — historical rows carry row_kind='historical'
    -- and forecast rows carry row_kind='forecast', and the composite grain
    -- (cik, canonical_concept, fiscal_year, as_of_date, row_kind) is
    -- collision-free by construction (forecast_year > latest historical
    -- fiscal_year per company).
    SELECT * FROM historical
    UNION ALL
    SELECT * FROM forecast_enriched
),

hashed AS (
    -- Compute mart surrogate PK + final shape + lineage. SHA-256 chain
    -- matches the prior 3 marts (Risk 4 + Risk 6). 5-component composite
    -- over the grain.
    SELECT
        to_hex(sha256(to_utf8(
            CAST(cik AS varchar) || '||' ||
            CAST(canonical_concept AS varchar) || '||' ||
            CAST(fiscal_year AS varchar) || '||' ||
            CAST(as_of_date AS varchar) || '||' ||
            CAST(row_kind AS varchar)
        ))) AS mart_growth_forecast_hk,
        cik,
        entity_name,
        as_of_date,
        fiscal_year,
        canonical_concept,
        row_kind,
        value_numeric,
        forecast_value,
        lower_ci_95,
        upper_ci_95,
        model_name,
        model_aic,
        historical_obs_count,
        latest_historical_year,
        CAST(current_timestamp AT TIME ZONE 'UTC' AS timestamp(6)) AS load_datetime,
        'mart.mart_growth_forecast' AS record_source
    FROM unioned
)

SELECT * FROM hashed
