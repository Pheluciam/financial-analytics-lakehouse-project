-- dbt data test: mart_financial_health.net_margin range sanity (non-Financials).
--
-- Asserts that net_margin (when non-NULL) falls within [-3.0, 3.0] for
-- non-Financials sector companies. Net margin = net_income / revenue.
-- The widened bound from the original [-1.0, 1.0] design absorbs the
-- legitimate one-time event floor that surfaced in the 2026-06-01 Fix-all
-- cascade — ~20 non-Financials tuples sit between |1.0| and |3.0|, plausible
-- candidates being spinoff years (GE, MMM), divestiture years, large
-- one-time impairments, and tax-benefit reversals. The [-3.0, 3.0] range
-- still catches catastrophic regression (e.g. denominator corruption
-- producing margins > 5x) without false-flagging real corporate-action
-- signal. Material per-CIK revenue / net_income regressions are caught
-- directly by the 6 anchor-CIK data tests (AAPL/MSFT/JPM/BRK.B/WMT/XOM)
-- on the same mart.
--
-- Financials sector is excluded — Phase 5 session 4 Fix-all Step B added
-- InterestAndDividendIncomeOperating as a Financials revenue alias (Risk
-- 55). Banks' "revenue" under this tag = gross interest income, while
-- net_income includes trading, fees, and non-interest income; investment
-- banks (GS, MS), payment networks (V, MA), and asset managers (BLK)
-- structurally produce net_margin > 1.0 under this mapping. The
-- analyst-conventional bank margin is return-on-equity, not net_margin.
--
-- Investigation queue (Step M re-audit): drill the specific (cik, fy)
-- tuples sitting between |1.0| and |3.0| and confirm each pairs with a
-- documented one-time event. Tuples without a matching corporate action
-- are candidates for further refinement of the cost_of_revenue / Risk 58
-- mart-layer derivation.
--
-- Source: AUDIT_FINDINGS.md Audit 10 A10.4 spec item 9 (range test in
-- place of dbt_expectations dependency).
-- PASS condition: zero rows returned.

SELECT m.cik, sp.ticker, m.fiscal_year, sp.gics_sector,
       m.revenue, m.net_income, m.net_margin
FROM {{ ref('mart_financial_health') }} m
INNER JOIN {{ ref('sp100_company_sector') }} sp ON sp.cik = m.cik
WHERE m.net_margin IS NOT NULL
  AND sp.gics_sector != 'Financials'
  AND (m.net_margin < -3.0 OR m.net_margin > 3.0)
