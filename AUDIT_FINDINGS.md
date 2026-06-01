# AUDIT_FINDINGS.md — Phase 5 Data Quality Audit

> Phase 5 session 2 (2026-06-01). Comprehensive data quality audit of
> the 4 Gold marts before any Power BI dashboard authoring. Built in
> response to the recognition that dbt schema tests catch structural
> integrity but miss semantic correctness (tag mapping, completeness,
> defended-NULL classification, external-anchor validity).
>
> This document captures findings from Audits 1, 2, 3 (universe,
> completeness, tag-evidence). Audits 4-10 follow in the next session
> per `AUDITS_4_TO_10_SCOPE.md`.

---

## Audit 1 — Universe Integrity

**Goal.** Confirm every layer (seed, Bronze, hub_company, 4 marts) holds
exactly the 107 S&P 100 CIKs with no orphans, no duplicates, no missing.

**File.** `sql/audit/02_universe_integrity.sql` (6 checks A1.1–A1.6).

**Scoreboard.**

| Check | Result | Detail |
|---|---|---|
| A1.1 seed sanity | PASS | 107 distinct CIKs / tickers / entity_names |
| A1.2 Bronze vs seed | FAIL | 0 seed missing, but 8 Bronze orphans propagating downstream |
| A1.3 orphan identification | info | AIG, CVS, GD, LMT, MET, PLTR, SPG, UBER — real S&P 500 boundary companies (not in 2025-12-31 seed snapshot) |
| A1.4 hub_company integrity | PASS | All 107 seed CIKs reach hub; no stale rows |
| A1.5 mart CIK universes | FAIL | All 4 marts carry 115 CIKs (107 seed + 8 orphans); mart_growth_forecast is missing GS (downstream of revenue-tag-mapping fix needed) |
| A1.6 composite PK uniqueness | PASS | No duplicate rows at PK grain in any mart |

**Fixes surfaced (deferred to Fix-all phase):**

1. **Universe filter at hub_company or mart layer** — scope the warehouse
   to the 107 seed CIKs. Drops the 8 orphans cleanly without removing
   data from Bronze.
2. **Financials revenue seed expansion** — restores GS to
   mart_growth_forecast (also fixes 4 missing Financials revenue cells).

---

## Audit 2 — Completeness Across All 4 Marts × All FYs

**Goal.** Coverage heat-map per (mart × canonical × fiscal_year) for
FY2009-2024. Identifies whether gaps are FY2024-only or chronic.

**File.** `sql/audit/03_completeness.sql` (5 checks A2.1–A2.5).

**Scoreboard.**

| Check | Result | Detail |
|---|---|---|
| A2.1 mart_financial_health heat-map | (insights) | Gaps are CHRONIC across all 16 FYs, not FY2024-specific |
| A2.2 mart_pl_trend per-FY | (insights) | Matches A2.1 for shared canonicals |
| A2.3 mart_peer_benchmark per-FY | (insights) | Matches A2.1+A2.2 |
| A2.4 mart_growth_forecast cohorts | (insights) | 4 cohorts (not 2 as documented): FY2025-latest, FY2024-latest, FY2019-latest, FY2014-latest. Stale cohorts likely Risk-55 driven |
| A2.5 cross-mart revenue consistency | PASS (all 16 years) | No drift between marts |

**Key chronic-gap profile (FY2024 baseline, stable across 16 years):**

| Canonical | FY2024 missing | Pattern |
|---|---|---|
| gross_profit | 76 | Banks/REITs/Energy/Utilities no COGS structure |
| liabilities | 33 | LiabilitiesAndStockholdersEquity filed instead of bare Liabilities |
| operating_income | 30 | Banks structural + non-banks file IncBeforeTax only |
| cash_and_equivalents | 23 | Post-2018 ASU 2016-18 tag rename to Restricted variant |
| stockholders_equity | 12 | SEIncludingNCI filed instead of bare SE |
| net_income | 9 | Pipeline filter — bare NetIncomeLoss present in JSON |
| revenue | 4 | Financials sector-specific tags (Risk 55) + SPGI special case |
| operating_cash_flow | 3 | Pipeline filter — bare tag present |
| assets | 1 | SPGI special case |

**Insight that re-shaped fix plan:**

- Risk 55 was originally framed as an FY2024 filing-lag issue. Audit 2
  proved it's a chronic 16-year systemic issue. Every fix improves every
  fiscal year, not just FY2024.
- Marts don't diverge — bugs are upstream at sat/intermediate, not in
  mart-specific filter logic.

---

## Audit 3 — Tag-Evidence Per Canonical

**Goal.** For each missing (CIK × canonical) cell, query the company's
companyfacts JSON to identify which us-gaap tags they DO file. Output
is the seed-expansion target list — evidence-driven, not speculation.

**File.** `sql/audit/04_tag_evidence.sql` (9 sub-queries A3.1–A3.9 plus
A3.10 classification + A3.11 SPGI-pattern + A3.12 multi-year stability).

**Methodology.** For each canonical, JSON-probe the missing CIKs for
the seed-mapped tag + plausible alternates. Then classify each cell as:

- **NEVER_IN_SAT** — sat has zero rows for this (CIK, canonical). Either
  structural defended NULL OR tag-alias missing.
- **OLD_TAG_RENAME** — sat has rows but max period_end_date < FY2024
  reporting window. Company switched to a newer tag.
- **RECENT_PIPELINE_BUG** — sat has rows with period_end_date in FY2024
  window. Bare tag IS filed, mart isn't surfacing it. Audit 4 territory.

### Classification scoreboard (191 cells total)

| Canonical | NEVER_IN_SAT | OLD_TAG_RENAME | RECENT_PIPELINE_BUG | Total |
|---|---|---|---|---|
| assets | 0 | 0 | 1 | 1 |
| cash_and_equivalents | 3 | 17 | 3 | 23 |
| gross_profit | 55 | 19 | 2 | 76 |
| liabilities | 29 | 3 | 1 | 33 |
| net_income | 0 | 2 | 7 | 9 |
| operating_cash_flow | 0 | 0 | 3 | 3 |
| operating_income | 22 | 6 | 2 | 30 |
| revenue | 1 | 2 | 1 | 4 |
| stockholders_equity | 4 | 6 | 2 | 12 |
| **TOTAL** | **114** | **55** | **22** | **191** |

### NEVER_IN_SAT breakdown (114 cells)

- **gross_profit 55**: 26 truly defended NULL (banks/REITs/Energy/services
  no COGS) + 29 derivable from CostOfRevenue / CostOfGoodsAndServicesSold /
  CostOfGoodsSold / CostOfServices tags (mart-layer derivation:
  gross_profit = revenue − cost).
- **liabilities 29**: ALL derivable from
  LiabilitiesAndStockholdersEquity − StockholdersEquity (mart-layer
  derivation). LiabilitiesAndStockholdersEquity has multi-year coverage
  across these CIKs.
- **operating_income 22**: 12 banks (no OI concept) + 10 non-banks (no
  alternate OI tag exists in their JSON — verified via probe). All
  defended NULL.
- **stockholders_equity 4**: T, VZ, PG, CAT — file
  StockholdersEquityIncludingPortionAttributableToNoncontrollingInterest
  + MinorityInterest separately. Derive SE = SEIncludingNCI −
  MinorityInterest.
- **cash 3**: COF, PNC, WFC — file only the Restricted variant. Add
  CashCashEquivalentsRestrictedCashAndRestrictedCashEquivalents alias.
- **revenue 1**: SPGI — total absence in sat (also flagged in A3.11).
  Goes into Audit 4 SPGI-pattern investigation.

### OLD_TAG_RENAME breakdown (55 cells)

- **cash 17**: SBUX, TGT, MDLZ, PG, SLB, AXP, BAC, BRK.B, C, CB, JPM,
  DHR, GILD, MMM, EMR, GE, USB. All switched to
  CashCashEquivalentsRestrictedCashAndRestrictedCashEquivalents (verified
  via A3.12 — 16 of 17 have 5+ year coverage; SLB unique, needs separate
  alias).
- **gross_profit 19**: file GrossProfit historically but stopped.
  Investigation needed for replacement tag (likely a CostOfRevenue
  variant — derivation path covers these too).
- **stockholders_equity 6**: likely SEIncludingNCI switch.
- **operating_income 6**: investigation needed.
- **liabilities 3**: investigation needed.
- **net_income 2**: investigation needed.
- **revenue 2**: investigation needed.

### RECENT_PIPELINE_BUG (22 cells across canonicals)

- net_income 7, operating_income 2, gross_profit 2, cash 3,
  operating_cash_flow 3, stockholders_equity 2, liabilities 1, assets 1,
  revenue 1.
- These CIKs have bare-tag sat rows at FY2024 period dates, but the
  mart filter is dropping them. **Single root-cause investigation in
  Audit 4** likely heals all 22 cells with one fix.

### SPGI canary case (A3.11)

SPGI is the ONLY CIK in the universe with <5 sat rows at (fiscal_year=2024,
fiscal_period='FY'). All 106 other CIKs have 5+ rows. SPGI shows missing
on every canonical at FY2024. Bronze has SPGI; hub has SPGI; sat has
SPGI rows at OTHER fiscal_period codes (Q1/Q2/Q3) but ZERO at FY-period
for FY2024.

This is the canonical test case for the Audit-4 mart-pipeline filter bug.

### Multi-year tag stability (A3.12)

Sample probe on the cash OLD_TAG_RENAME cohort (17 CIKs) confirmed the
CashCashEquivalentsRestrictedCashAndRestrictedCashEquivalents tag is
present at FY-period for 5+ years across 16 of 17 CIKs. The seed alias
expansion fix will heal historical years too, not just FY2024. SLB is the
single exception (no Restricted tag at any year) — needs Energy-sector
investigation OR documented defended NULL.

---

## Strategic implications for Fix-all phase

After fixes complete:

| Fix family | Cells healed | Path |
|---|---|---|
| Audit 4 mart-pipeline bug | 22 | Single root-cause investigation |
| Seed alias expansion | 55 | Per-canonical alias additions to canonical_concept_tag_preference + Jinja concept lists |
| Mart-layer derivation columns | 65 | gross_profit = rev − cost (29); liabilities = LiabAndSE − SE (29); SE = SEIncludingNCI − MI (4); cash via Restricted (3) |
| Universe filter (Audit 1) | (orphans dropped) | Filter at hub_company OR mart layer to 107 seed CIKs |
| **Subtotal fillable** | **142 of 191** | |
| **Documented defended NULL** | **49** | Banks no GP (17), banks no OI (12), non-banks no OI (10), other (10) |

**Coverage target after all fixes:** ~97% (107 reporting / 107 universe,
minus the 49 documented defended-NULL cells which are correctly absent).
The remaining 49 cells will have JSON-evidence pinned in defended-NULL
documentation so they can be defended to management as "company X doesn't
file concept Y under any us-gaap tag — verified" rather than "we don't
know."

---

## Files shipped this session

- `sql/audit/02_universe_integrity.sql` — Audit 1
- `sql/audit/03_completeness.sql` — Audit 2
- `sql/audit/04_tag_evidence.sql` — Audit 3
- `sql/ddl/01_create_bronze_tables.sql` — cik enum extended 100→115
  (Bronze gap closure for the 15 originally-missing seed CIKs)
- `sql/ddl/02_create_bronze_raw_text_table.sql` — same lockstep edit
- `AUDIT_FINDINGS.md` — this file
- `AUDITS_4_TO_10_SCOPE.md` — handoff scope for the next session

---

## Pre-Audit-4 state of the warehouse (snapshot)

- 107 seed CIKs (post-backfill of 15 originally missing).
- 115 in Bronze (107 seed + 8 orphans).
- 115 in hub_company.
- mart_financial_health 191 cells null across 9 canonicals at FY2024
  latest snapshot.
- 22 of 191 expected to heal via Audit-4 mart-pipeline bug fix.
- 55 of 191 via seed alias expansion.
- 65 of 191 via mart-layer derivation.
- 49 of 191 documented defended NULL with JSON evidence.

---

*Authored AI-assisted (Claude by Anthropic) per the standing
AI-assistance disclosure convention.*
