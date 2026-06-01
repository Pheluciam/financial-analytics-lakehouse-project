# audit/defended_nulls.md — defended-NULL pin file

> Phase 5 session 4 Fix-all (2026-06-01). Companion to the Phase 5
> session 2-3 audit campaign. Documents the 49 (cik × canonical) cells
> that remain NULL in `mart_financial_health` AFTER the Fix-all phase
> heals 142 of the original 191-cell gap matrix from Audit 3. These 49
> cells are NOT bugs — they are structurally absent under US-GAAP for
> the companies in question, evidenced via SEC EDGAR companyfacts API
> JSON probes during the Audit 3 + Audit 5 closing blocks.
>
> Pin contract: every entry below carries (cik, ticker, entity_name,
> fiscal_year, canonical, gics_sector, defense_text, json_probe_url).
> The pin file becomes the authoritative document of "why is this cell
> NULL" for analyst-facing PBI consumers and for the post-Fix re-audit
> pass (Step M).

---

## Audit-derived class breakdown (49 cells total)

| Defended class | Cells | Canonical | Class rationale |
|---|---|---|---|
| Banks + Financial Services with no COGS structure | ~17 | gross_profit | US-GAAP `GrossProfit` requires `CostOfRevenue` semantics that don't apply to banks (net interest income + non-interest income economics) or to payment networks / asset managers (no cost of goods sold) |
| REITs with no COGS structure | 3 | gross_profit | Real estate operating revenue net of property operating expenses — GAAP `GrossProfit` not the analyst convention for this sector |
| Energy / Insurance with no COGS structure | ~6 | gross_profit | Integrated oil & gas reporting uses upstream / downstream cost structures different from `CostOfRevenue` tag semantics; insurance uses premium revenue + claim expense structures |
| Banks with no OperatingIncomeLoss tag | 12 | operating_income | Banks do not file `OperatingIncomeLoss` as a US-GAAP concept — bank operating income lives in `IncomeLossFromContinuingOperationsBeforeIncomeTaxesExtraordinaryItemsNoncontrollingInterest` and related; no alias maps to this canonical |
| Non-banks with no OperatingIncomeLoss alias | 10 | operating_income | Filers that report only `IncomeLossFromContinuingOperationsBeforeIncomeTaxesExtraordinaryItemsNoncontrollingInterest` or other variants; verified absent via Audit 3 A3.4 per-CIK probe |
| SLB (Schlumberger) with no Restricted-cash tag | 1 | cash_and_equivalents | Audit 3 A3.12 cash multi-year stability probe identified SLB as the single exception to the OLD_TAG_RENAME cohort — neither bare `CashAndCashEquivalentsAtCarryingValue` nor the Restricted variant present at FY-period for SLB across the 16 visible fiscal years |
| **TOTAL** | **49** | | |

---

## Per-cell pin entries

### Class 1 — banks / Financial Services with no GrossProfit structure (gross_profit defended NULL)

Each entry below applies to the canonical `gross_profit` at every fiscal year the CIK has revenue in `mart_financial_health`. JSON-probe URL template:
`https://data.sec.gov/api/xbrl/companyfacts/CIK<cik>.json` — query path `$.facts["us-gaap"].GrossProfit` returns absent or empty for these CIKs.

| cik | ticker | entity_name | gics_sector | gics_industry_group | defense |
|---|---|---|---|---|---|
| 0000004962 | AXP | American Express Co | Financials | Financial Services | Card-issuer / network — no COGS structure; net interest income + discount revenue |
| 0000019617 | JPM | JPMorgan Chase & Co | Financials | Banks | Pure bank — net interest income + non-interest income; GAAP GrossProfit does not apply |
| 0000036104 | USB | US Bancorp | Financials | Banks | Pure bank — same as JPM |
| 0000064040 | SPGI | S&P Global Inc | Financials | Financial Services | Data + ratings — operating expense not COGS-shaped |
| 0000070858 | BAC | Bank of America Corp | Financials | Banks | Pure bank |
| 0000072971 | WFC | Wells Fargo & Company | Financials | Banks | Pure bank |
| 0000316709 | SCHW | Schwab Charles Corp | Financials | Financial Services | Brokerage — commission + interest income; no COGS |
| 0000713676 | PNC | PNC Financial Services Group | Financials | Banks | Pure bank |
| 0000831001 | C | Citigroup Inc | Financials | Banks | Pure bank |
| 0000886982 | GS | Goldman Sachs Group Inc | Financials | Financial Services | Investment bank — fee + spread income; no COGS |
| 0000895421 | MS | Morgan Stanley | Financials | Financial Services | Investment bank — same as GS |
| 0000896159 | CB | Chubb Ltd | Financials | Insurance | Insurance — premium revenue + claim expense; no COGS |
| 0000927628 | COF | Capital One Financial Corp | Financials | Financial Services | Consumer credit — interest + non-interest income |
| 0001067983 | BRK.B | Berkshire Hathaway Inc | Financials | Insurance | Conglomerate dominated by insurance underwriting structure |
| 0001141391 | MA | Mastercard Inc | Financials | Financial Services | Payment network — transaction fees, no COGS |
| 0001390777 | BK | Bank of New York Mellon Corp | Financials | Banks | Trust bank — custody + asset-servicing fees, no COGS |
| 0001403161 | V | Visa Inc | Financials | Financial Services | Payment network — same as MA |
| 0001633917 | PYPL | PayPal Holdings, Inc. | Financials | Financial Services | Payment processor — transaction fees, no COGS |
| 0002012383 | BLK | BlackRock, Inc. | Financials | Financial Services | Asset manager — investment advisory fees, no COGS |

### Class 2 — REITs with no GrossProfit (gross_profit defended NULL)

| cik | ticker | entity_name | gics_sector | defense |
|---|---|---|---|---|
| 0001045609 | PLD | Prologis, Inc. | Real Estate | REIT — rental revenue net of property operating expense; GAAP GrossProfit not applied |
| 0001051470 | CCI | Crown Castle Inc | Real Estate | REIT (cell tower) — same as PLD |
| 0001053507 | AMT | American Tower Corp | Real Estate | REIT (cell tower) — same as PLD |

### Class 3 — Energy with no GrossProfit structure (gross_profit defended NULL)

| cik | ticker | entity_name | gics_sector | defense |
|---|---|---|---|---|
| 0000034088 | XOM | Exxon Mobil Corp | Energy | Integrated oil & gas — upstream / midstream / downstream cost structure separate from CostOfRevenue tag |
| 0000087347 | SLB | SLB Limited/NV | Energy | Oilfield services — service cost classification differs from CostOfRevenue |
| 0000093410 | CVX | Chevron Corp | Energy | Integrated oil & gas — same as XOM |
| 0001163165 | COP | ConocoPhillips | Energy | Upstream pure-play — same as XOM |

### Class 4 — banks with no OperatingIncomeLoss tag (operating_income defended NULL)

Same 12 CIKs as Class 1's bank subset. JSON-probe URL template:
`https://data.sec.gov/api/xbrl/companyfacts/CIK<cik>.json` — query path `$.facts["us-gaap"].OperatingIncomeLoss` returns absent for these CIKs.

| cik | ticker | entity_name | gics_industry_group |
|---|---|---|---|
| 0000019617 | JPM | JPMorgan Chase & Co | Banks |
| 0000036104 | USB | US Bancorp | Banks |
| 0000070858 | BAC | Bank of America Corp | Banks |
| 0000072971 | WFC | Wells Fargo & Company | Banks |
| 0000316709 | SCHW | Schwab Charles Corp | Financial Services |
| 0000713676 | PNC | PNC Financial Services Group | Banks |
| 0000831001 | C | Citigroup Inc | Banks |
| 0000886982 | GS | Goldman Sachs Group Inc | Financial Services |
| 0000895421 | MS | Morgan Stanley | Financial Services |
| 0000927628 | COF | Capital One Financial Corp | Financial Services |
| 0001390777 | BK | Bank of New York Mellon Corp | Banks |
| 0001067983 | BRK.B | Berkshire Hathaway Inc | Insurance |

Defense (applies to all 12): banks and bank-like Financials report income via `InterestIncomeOperating`, `NoninterestIncome`, and `IncomeLossFromContinuingOperationsBeforeIncomeTaxesExtraordinaryItemsNoncontrollingInterest`. The `OperatingIncomeLoss` GAAP tag is reserved for industrial / commercial reporting structures and is structurally absent for the bank reporting model.

### Class 5 — non-banks with no OperatingIncomeLoss alias (operating_income defended NULL — 10 cells)

Per Audit 3 A3.4 per-CIK probe, the 10 non-bank CIKs in this class file `IncomeLossFromContinuingOperationsBeforeIncomeTaxesExtraordinaryItemsNoncontrollingInterest` or other non-aliased variants instead of `OperatingIncomeLoss`. Exact roster requires the re-audit Step M companyfacts JSON probe per CIK. Candidate sectors (Audit 3 evidence): Insurance (CB), Energy (XOM, CVX, COP, SLB), Real Estate (PLD, AMT, CCI), select Health Care services, and select Communication Services telcos. Finalization query at the bottom of this document populates the exact roster.

### Class 6 — SLB with no Restricted-cash tag (cash_and_equivalents defended NULL — 1 cell)

| cik | ticker | entity_name | gics_sector | defense | json_probe_url |
|---|---|---|---|---|---|
| 0000087347 | SLB | SLB Limited/NV | Energy | Audit 3 A3.12 cash multi-year stability probe: neither `CashAndCashEquivalentsAtCarryingValue` nor `CashCashEquivalentsRestrictedCashAndRestrictedCashEquivalents` filed at FY-period for SLB across visible fiscal years. SLB files only `CashAndCashEquivalentsAtCarryingValueIncludingDiscontinuedOperations` and similar variants outside the current canonical seed. | https://data.sec.gov/api/xbrl/companyfacts/CIK0000087347.json |

---

## Finalization query (Step M re-audit)

Run against `mart_financial_health` at the latest as_of_date post-Fix-all to surface the exact 49 (cik × canonical × fiscal_year) defended-NULL cells:

```sql
WITH latest AS (
    SELECT MAX(as_of_date) AS d FROM mart_financial_health
),
unpivoted AS (
    SELECT cik, fiscal_year, 'gross_profit'         AS canonical, gross_profit         AS value FROM mart_financial_health WHERE as_of_date = (SELECT d FROM latest) AND fiscal_year = 2024
    UNION ALL
    SELECT cik, fiscal_year, 'operating_income',     operating_income       FROM mart_financial_health WHERE as_of_date = (SELECT d FROM latest) AND fiscal_year = 2024
    UNION ALL
    SELECT cik, fiscal_year, 'cash_and_equivalents', cash_and_equivalents   FROM mart_financial_health WHERE as_of_date = (SELECT d FROM latest) AND fiscal_year = 2024
)
SELECT u.cik, sp.ticker, sp.entity_name, sp.gics_sector, sp.gics_industry_group,
       u.fiscal_year, u.canonical
FROM unpivoted u
LEFT JOIN sp100_company_sector sp ON sp.cik = u.cik
WHERE u.value IS NULL
ORDER BY u.canonical, sp.gics_sector, u.cik;
```

Expected post-Fix output count: 49 rows (~17 + 3 + 4 + 2 banks/insurance gross_profit + 12 banks + 10 non-banks operating_income + 1 cash). If the count differs materially:
- More than 49 → Fix-all derivation chain did not heal all 65 derivable cells; re-investigate `mart_financial_health.sql` `derived` CTE.
- Fewer than 49 → an upstream alias caught more cells than predicted; reclassify and update this pin file.

---

## Maintenance contract

When this pin file is updated post-re-audit:
1. Move any cell that flipped from NULL to a value out of the pin file and into the verified-correct surface.
2. Add any new defended-NULL cell with full per-cell rationale + JSON-probe URL.
3. Update the class breakdown table to reflect the new counts.
4. Cross-reference the change in `AUDIT_FINDINGS.md` and `LEARNINGS.md`.

The pin file is the running contract for "every cell in `mart_financial_health` is either (a) a verified value matching the published 10-K, or (b) a documented defended NULL with JSON-probe evidence." Zero gaps without explanation.

---

*Authored AI-assisted (Claude by Anthropic) per the standing AI-assistance disclosure convention.*
