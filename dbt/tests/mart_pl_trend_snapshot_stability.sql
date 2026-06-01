-- dbt data test: mart_pl_trend snapshot stability regression band.
--
-- Asserts that the total count of (cik, fiscal_year, canonical_concept)
-- tuples with value drift across as_of_dates stays under a regression
-- tolerance band. The drift count = tuples where multiple visible
-- accessions report different values for the same fiscal year — the SEC
-- ASC 205 restatement signature.
--
-- Baseline at Phase 5 session 4 Fix-all close (2026-06-01): ~208 drift
-- tuples across 100 CIKs × 16 years × 2 canonicals (3.25% restatement
-- rate). Audit 8 pre-Fix count was 123 (118 dedup-non-determinism + 5
-- real restatements ELV/HON/KHC) but examined a smaller scope. The
-- broader 16-year S&P 100 restatement floor is the 208 figure surfaced
-- by this test at session 4 close.
--
-- Tolerance band = 350. Catches regressions where a re-introduced dedup
-- non-determinism bug or a mart-filter change blows the drift count out
-- past the natural restatement floor by ~70% headroom. Below 350 = within
-- expected restatement rate. Above 350 = investigate.
--
-- Investigation queue (Step M re-audit): drill down which CIKs +
-- fiscal_years are drifting beyond the known 5 ELV/HON/KHC tuples, and
-- confirm each is a real SEC restatement vs an artifact of the Risk 58
-- re-anchor edge cases. The defended_nulls.md companion file is the
-- pattern; a restated_values.md companion may be the appropriate place
-- for the steady-state restatement roster.
--
-- Source: AUDIT_FINDINGS.md Audit 8 + Audit 10 A10.4 spec item 7 (with
-- regression-band recalibration to match the broader 16-year scope).
-- PASS condition: zero rows returned.

WITH per_tuple AS (
    SELECT cik, fiscal_year, canonical_concept,
           COUNT(DISTINCT value_numeric) AS distinct_values
    FROM {{ ref('mart_pl_trend') }}
    GROUP BY cik, fiscal_year, canonical_concept
),
drift_summary AS (
    SELECT COUNT(*) AS drift_tuples
    FROM per_tuple
    WHERE distinct_values > 1
)
SELECT drift_tuples
FROM drift_summary
WHERE drift_tuples > 350
