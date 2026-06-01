# audit/anchor_truth.md — External anchor values for Audit 6

> Phase 5 audit 6 of 10 — external anchor checks vs published 10-Ks.
>
> This file pins manually-verified FY2024 anchor values from published
> 10-K filings + investor-relations press releases for the 6 anchor CIKs
> selected in AUDITS_4_TO_10_SCOPE.md A6.1-A6.6. Each value carries a
> source URL so a future re-audit can re-verify.
>
> Anchor values are external truth — independent of our warehouse — and
> are what `sql/audit/07_external_anchors.sql` queries the mart against.
> Mart values matching anchor values (within definitional tolerance) =
> mart validated. Mismatches > tolerance = real bug to root-cause.
>
> Last verified: 2026-06-01.

---

## A6.1 — Apple Inc. (AAPL, cik=0000320193)

Fiscal year ended **September 28, 2024** (53-week year).

| Metric | Anchor value | Source |
|---|---|---|
| Revenue (Total net sales) | $391,035M | Apple FY2024 10-K |
| Net income | $93,736M | Apple FY2024 10-K |
| Total assets | $337,411M | Apple FY2024 10-K balance sheet |
| Cash and equivalents (bare) | $32,695M | Apple FY2024 10-K (cash on balance sheet, excludes marketable securities) |

Sources:
- [Apple Inc. FY2024 10-K (SEC EDGAR)](https://www.sec.gov/Archives/edgar/data/0000320193/000032019324000123/aapl-20240928.htm)
- [Charted: How Apple Makes its $391B in Revenue (Visual Capitalist)](https://www.visualcapitalist.com/charted-how-apple-makes-its-391b-in-revenue/)

---

## A6.2 — Microsoft Corp (MSFT, cik=0000789019)

Fiscal year ended **June 30, 2024**.

| Metric | Anchor value | Source |
|---|---|---|
| Revenue | $245,122M | Microsoft FY2024 10-K |
| Net income | $88,136M | Microsoft FY2024 10-K |
| Total assets | $512,200M | Microsoft FY2024 10-K balance sheet |
| Cash and equivalents (bare) | $18,315M | Microsoft FY2024 10-K |

Source:
- [Microsoft Corp FY2024 10-K (SEC EDGAR)](https://www.sec.gov/Archives/edgar/data/0000789019/000095017024087843/msft-20240630.htm)

---

## A6.3 — JPMorgan Chase (JPM, cik=0000019617)

Fiscal year ended **December 31, 2024**.

Banks have non-standard revenue concept — Total net revenue includes
net interest income + non-interest revenue, not "Sales".

| Metric | Anchor value | Source |
|---|---|---|
| Total net revenue | $177,556M | JPM FY2024 10-K |
| Net income | $58,471M | JPM FY2024 press release / 10-K |

Sources:
- [JPMorgan Chase FY2024 10-K (SEC EDGAR)](https://www.sec.gov/Archives/edgar/data/0000019617/000001961725000270/jpm-20241231.htm)
- [JPM FY2024 record full-year results press release](https://www.sec.gov/Archives/edgar/data/19617/000001961725000040/a4q24erfexhibit991narrative.htm)

---

## A6.4 — Berkshire Hathaway (BRK.B, cik=0001067983)

Fiscal year ended **December 31, 2024**.

| Metric | Anchor value | Source |
|---|---|---|
| Revenue | $371,433M | BRK FY2024 10-K |
| Net income | $89,000M (approx) | BRK FY2024 10-K |
| Total assets | $1,153,881M | BRK FY2024 10-K balance sheet |

Source:
- [Berkshire Hathaway FY2024 10-K (SEC EDGAR)](https://www.sec.gov/Archives/edgar/data/0001067983/000095017025025210/brka-20241231.htm)
- [Berkshire Hathaway 2024 Annual Report](https://www.berkshirehathaway.com/2024ar/2024ar.pdf)

---

## A6.5 — Walmart Inc (WMT, cik=0000104169)

Fiscal year ended **January 31, 2024**.

WMT's fiscal-year-end is Jan 31 — the "FY2024 10-K" period ends in Jan
2024, NOT Dec 2024. Mart's fiscal_year=2024 row for WMT should anchor
on period_end_date=2024-01-31 per Audit 4's proposed period-end re-anchor.

| Metric | Anchor value | Source |
|---|---|---|
| Total revenue | $648,125M | WMT FY2024 10-K |
| Net sales (subset of revenue) | $642,637M | WMT FY2024 10-K |
| Net income (consolidated, attributable to WMT) | $15,511M | WMT FY2024 10-K |

Source:
- [Walmart Inc FY2024 10-K (SEC EDGAR)](https://www.sec.gov/Archives/edgar/data/0000104169/000010416924000056/wmt-20240131.htm)

---

## A6.6 — Exxon Mobil Corp (XOM, cik=0000034088)

Fiscal year ended **December 31, 2024**.

XOM reports two revenue lines on the income statement. The XBRL
Revenues tag captures the broader "Total revenues and other income"
which includes equity-affiliate income + other operating income, not
just "Sales and other operating revenue."

| Metric | Anchor value | Source | Notes |
|---|---|---|---|
| Sales and other operating revenue | $339,247M | XOM FY2024 10-K | Subset of total revenue |
| Total revenues and other income | ~$349,600M (derived) | XOM FY2024 10-K | Sales + equity-affiliate income (~$8B) + other income (~$2B) |
| Net income (attributable to XOM) | $33,680M | XOM FY2024 10-K | |

Sources:
- [ExxonMobil FY2024 10-K (SEC EDGAR)](https://www.sec.gov/Archives/edgar/data/0000034088/000003408825000010/xom-20241231.htm)
- [ExxonMobil 2024 Results press release](https://corporate.exxonmobil.com/news/news-releases/2025/0131_exxonmobil-announces-2024-results)

---

## A6.7 — S&P 100 aggregate revenue FY2024

External published consolidated S&P 100 FY2024 revenue: not directly
published by S&P Dow Jones Indices in a public summary that web search
surfaced. Aggregate is internal-only verification — sum the mart's
revenue column at FY2024 latest snapshot across 107 seed CIKs, validate
against rough analyst-published indicators ($9-10T expected range based
on per-company averages — top 10 CIKs alone sum to ~$4.0T).

Methodology — use the per-company anchors above + supplementary press
releases to bound the expected total. Hard external aggregate
publication source TBD.

---

## A6.8 — Sector subtotals

Spot-check sectors where aggregate-published numbers are checkable:
- Information Technology (top names: AAPL, MSFT, NVDA, GOOGL, META, ORCL, IBM, CRM, ADBE) — ~$1.3T+ expected
- Financials (top names: BRK.B, JPM, BAC, C, WFC, GS) — ~$1.0T+ expected
- Energy (XOM, CVX, COP, SLB) — ~$0.6T+ expected

Sector subtotals are loose validation — used to confirm warehouse
ordering of magnitudes matches sector reality, not exact match.

---

## Mart anchor tolerance

- Revenue: ±0.1% match on bare us-gaap tag. Discrepancies > 1% require
  per-CIK probe of which raw tag the mart picked vs published headline.
- Net income: ±0.1% match. Some companies file NetIncomeLoss vs
  NetIncomeLossAttributableToParent — bank these as expected definitional
  differences when material.
- Assets: ±0.1% match. Single-tag canonical, should be exact.
- Cash and equivalents: ±0.1% on bare tag where bare-cash filer; full
  match on Restricted variant where Restricted-only filer (per Audit 5
  collapse-rule recommendation).

---

*Authored AI-assisted (Claude by Anthropic) per the standing
AI-assistance disclosure convention. Anchor values verified by web
search of SEC EDGAR + corporate IR sites 2026-06-01.*
