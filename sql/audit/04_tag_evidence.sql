-- sql/audit/04_tag_evidence.sql
--
-- Phase 5 audit 3 of 10 — tag-evidence per canonical.
--
-- For each of the 9 canonicals, find the missing CIKs (mart_financial_health
-- column IS NULL at FY2024 latest) and query their companyfacts JSON to
-- identify which us-gaap tags they DO file. Output is the seed-expansion
-- target list — evidence-driven, not speculation.
--
-- 9 sub-queries (A3.1 through A3.9), one per canonical. Each follows the
-- same pattern as the liabilities + cash probes already run:
--   1. Identify missing CIKs at FY2024.
--   2. Probe their JSON for canonical-plausible us-gaap tag names.
--   3. Report YES/no presence per CIK × candidate tag.
--
-- Execution: Athena Console, signed in as phil-admin. One per Run.

-- ============================================================
-- A3.1 — Tag evidence: revenue
-- 4 missing at FY2024 (per A2.1). Likely Risk 55 Financials pattern.
-- Candidate tags: sector-specific revenue lines used by banks /
-- insurers / asset managers.
-- ============================================================
WITH latest AS (
    SELECT MAX(as_of_date) AS latest_as_of FROM financial_analytics_silver.mart_financial_health
),
missing_revenue AS (
    SELECT s.cik, s.ticker, s.entity_name, s.gics_sector
    FROM financial_analytics_silver.sp100_company_sector s
    LEFT JOIN financial_analytics_silver.mart_financial_health m
        ON s.cik = m.cik
        AND m.as_of_date = (SELECT latest_as_of FROM latest)
        AND m.fiscal_year = 2024
    WHERE m.revenue IS NULL
)
SELECT
    mr.ticker,
    mr.entity_name,
    mr.gics_sector,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].InterestAndDividendIncomeOperating')                IS NOT NULL THEN 'YES' ELSE 'no' END AS has_InterestDividendOp,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].RevenuesNetOfInterestExpense')                     IS NOT NULL THEN 'YES' ELSE 'no' END AS has_RevNetOfInt,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].InterestIncomeOperating')                          IS NOT NULL THEN 'YES' ELSE 'no' END AS has_InterestIncOp,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].NoninterestIncome')                                IS NOT NULL THEN 'YES' ELSE 'no' END AS has_NoninterestInc,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].PremiumsEarnedNet')                                IS NOT NULL THEN 'YES' ELSE 'no' END AS has_PremiumsEarned,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].FinancialServicesRevenue')                         IS NOT NULL THEN 'YES' ELSE 'no' END AS has_FinSvcRev,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].InvestmentBankingRevenue')                         IS NOT NULL THEN 'YES' ELSE 'no' END AS has_IBRev
FROM missing_revenue mr
INNER JOIN financial_analytics_silver.stg_sec_edgar__companyfacts_raw b ON mr.cik = b.cik
ORDER BY mr.gics_sector, mr.entity_name;


-- ============================================================
-- A3.2 — Tag evidence: net_income
-- 9 missing at FY2024.
-- Candidate tags: NetIncomeLossAvailableToCommonStockholdersBasic,
-- ProfitLoss, NetIncomeLossAttributableToReportingEntity.
-- ============================================================
WITH latest AS (
    SELECT MAX(as_of_date) AS latest_as_of FROM financial_analytics_silver.mart_financial_health
),
missing_net_income AS (
    SELECT s.cik, s.ticker, s.entity_name, s.gics_sector
    FROM financial_analytics_silver.sp100_company_sector s
    LEFT JOIN financial_analytics_silver.mart_financial_health m
        ON s.cik = m.cik
        AND m.as_of_date = (SELECT latest_as_of FROM latest)
        AND m.fiscal_year = 2024
    WHERE m.net_income IS NULL
)
SELECT
    mn.ticker,
    mn.entity_name,
    mn.gics_sector,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].NetIncomeLoss')                                                 IS NOT NULL THEN 'YES' ELSE 'no' END AS has_NetIncomeLoss,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].NetIncomeLossAvailableToCommonStockholdersBasic')               IS NOT NULL THEN 'YES' ELSE 'no' END AS has_NetIncLossCommonBasic,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].ProfitLoss')                                                    IS NOT NULL THEN 'YES' ELSE 'no' END AS has_ProfitLoss,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].NetIncomeLossAttributableToReportingEntity')                    IS NOT NULL THEN 'YES' ELSE 'no' END AS has_NetIncReportingEntity,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].IncomeLossFromContinuingOperations')                            IS NOT NULL THEN 'YES' ELSE 'no' END AS has_IncLossContOps,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].NetIncomeLossIncludingPortionAttributableToNoncontrollingInterest') IS NOT NULL THEN 'YES' ELSE 'no' END AS has_NetIncIncludingNCI
FROM missing_net_income mn
INNER JOIN financial_analytics_silver.stg_sec_edgar__companyfacts_raw b ON mn.cik = b.cik
ORDER BY mn.gics_sector, mn.entity_name;


-- ============================================================
-- A3.3 — Tag evidence: gross_profit
-- 76 missing at FY2024. Most likely structural defended-NULL (banks,
-- REITs, energy, services don't have COGS). Candidate fallback:
-- derivation = revenue - CostOfRevenue (if both present).
-- ============================================================
WITH latest AS (
    SELECT MAX(as_of_date) AS latest_as_of FROM financial_analytics_silver.mart_financial_health
),
missing_gross_profit AS (
    SELECT s.cik, s.ticker, s.entity_name, s.gics_sector
    FROM financial_analytics_silver.sp100_company_sector s
    LEFT JOIN financial_analytics_silver.mart_financial_health m
        ON s.cik = m.cik
        AND m.as_of_date = (SELECT latest_as_of FROM latest)
        AND m.fiscal_year = 2024
    WHERE m.gross_profit IS NULL
)
SELECT
    mg.gics_sector,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].GrossProfit')                                IS NOT NULL THEN 1 ELSE 0 END AS has_GrossProfit,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].CostOfRevenue')                              IS NOT NULL THEN 1 ELSE 0 END AS has_CostOfRevenue,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].CostOfGoodsAndServicesSold')                 IS NOT NULL THEN 1 ELSE 0 END AS has_CostGoodsSvc,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].CostOfGoodsSold')                            IS NOT NULL THEN 1 ELSE 0 END AS has_CostGoodsSold,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].CostOfServices')                             IS NOT NULL THEN 1 ELSE 0 END AS has_CostOfServices,
    COUNT(*) AS company_count
FROM missing_gross_profit mg
INNER JOIN financial_analytics_silver.stg_sec_edgar__companyfacts_raw b ON mg.cik = b.cik
GROUP BY
    mg.gics_sector,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].GrossProfit')                                IS NOT NULL THEN 1 ELSE 0 END,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].CostOfRevenue')                              IS NOT NULL THEN 1 ELSE 0 END,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].CostOfGoodsAndServicesSold')                 IS NOT NULL THEN 1 ELSE 0 END,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].CostOfGoodsSold')                            IS NOT NULL THEN 1 ELSE 0 END,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].CostOfServices')                             IS NOT NULL THEN 1 ELSE 0 END
ORDER BY mg.gics_sector;


-- ============================================================
-- A3.4 — Tag evidence: operating_income
-- 30 missing at FY2024. Mostly Financials structural — banks don't
-- have OperatingIncomeLoss conceptually. Candidate proxies for banks:
-- IncomeLossFromContinuingOperationsBeforeIncomeTaxesExtraordinaryItemsNoncontrollingInterest,
-- IncomeLossFromContinuingOperationsBeforeIncomeTaxesMinorityInterestAndIncomeLossFromEquityMethodInvestments.
-- ============================================================
WITH latest AS (
    SELECT MAX(as_of_date) AS latest_as_of FROM financial_analytics_silver.mart_financial_health
),
missing_oi AS (
    SELECT s.cik, s.ticker, s.entity_name, s.gics_sector
    FROM financial_analytics_silver.sp100_company_sector s
    LEFT JOIN financial_analytics_silver.mart_financial_health m
        ON s.cik = m.cik
        AND m.as_of_date = (SELECT latest_as_of FROM latest)
        AND m.fiscal_year = 2024
    WHERE m.operating_income IS NULL
)
SELECT
    mo.ticker,
    mo.entity_name,
    mo.gics_sector,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].OperatingIncomeLoss')                                                                         IS NOT NULL THEN 'YES' ELSE 'no' END AS has_OperatingIncome,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].IncomeLossFromContinuingOperationsBeforeIncomeTaxesExtraordinaryItemsNoncontrollingInterest') IS NOT NULL THEN 'YES' ELSE 'no' END AS has_IncBeforeTax,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].IncomeLossFromContinuingOperationsBeforeIncomeTaxesMinorityInterestAndIncomeLossFromEquityMethodInvestments') IS NOT NULL THEN 'YES' ELSE 'no' END AS has_IncBeforeTaxMinority,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].OperatingIncomeLossPerShare')                                                                 IS NOT NULL THEN 'YES' ELSE 'no' END AS has_OpIncPerShare
FROM missing_oi mo
INNER JOIN financial_analytics_silver.stg_sec_edgar__companyfacts_raw b ON mo.cik = b.cik
ORDER BY mo.gics_sector, mo.entity_name;


-- ============================================================
-- A3.5 — Tag evidence: assets (1 missing at FY2024)
-- ============================================================
WITH latest AS (
    SELECT MAX(as_of_date) AS latest_as_of FROM financial_analytics_silver.mart_financial_health
),
missing_assets AS (
    SELECT s.cik, s.ticker, s.entity_name, s.gics_sector
    FROM financial_analytics_silver.sp100_company_sector s
    LEFT JOIN financial_analytics_silver.mart_financial_health m
        ON s.cik = m.cik
        AND m.as_of_date = (SELECT latest_as_of FROM latest)
        AND m.fiscal_year = 2024
    WHERE m.assets IS NULL
)
SELECT
    ma.ticker,
    ma.entity_name,
    ma.gics_sector,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].Assets')                              IS NOT NULL THEN 'YES' ELSE 'no' END AS has_Assets,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].AssetsCurrent')                       IS NOT NULL THEN 'YES' ELSE 'no' END AS has_AssetsCurrent,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].LiabilitiesAndStockholdersEquity')    IS NOT NULL THEN 'YES' ELSE 'no' END AS has_LiabAndSE
FROM missing_assets ma
INNER JOIN financial_analytics_silver.stg_sec_edgar__companyfacts_raw b ON ma.cik = b.cik
ORDER BY ma.gics_sector, ma.entity_name;


-- ============================================================
-- A3.6 — Tag evidence: liabilities (ALREADY RUN earlier session)
-- Result: 29 of 33 file LiabilitiesAndStockholdersEquity but not bare
-- Liabilities. Fix = derivation Liabilities = LiabAndSE − StockholdersEquity.
-- 4 outliers (T, TMUS, DHR, SPGI) file Liabilities but are still missing
-- in mart → upstream pipeline-bug investigation needed (Audit 4 territory).
-- ============================================================


-- ============================================================
-- A3.7 — Tag evidence: stockholders_equity (12 missing at FY2024)
-- ============================================================
WITH latest AS (
    SELECT MAX(as_of_date) AS latest_as_of FROM financial_analytics_silver.mart_financial_health
),
missing_se AS (
    SELECT s.cik, s.ticker, s.entity_name, s.gics_sector
    FROM financial_analytics_silver.sp100_company_sector s
    LEFT JOIN financial_analytics_silver.mart_financial_health m
        ON s.cik = m.cik
        AND m.as_of_date = (SELECT latest_as_of FROM latest)
        AND m.fiscal_year = 2024
    WHERE m.stockholders_equity IS NULL
)
SELECT
    ms.ticker,
    ms.entity_name,
    ms.gics_sector,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].StockholdersEquity')                                                                IS NOT NULL THEN 'YES' ELSE 'no' END AS has_StockholdersEquity,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].StockholdersEquityIncludingPortionAttributableToNoncontrollingInterest')            IS NOT NULL THEN 'YES' ELSE 'no' END AS has_SEIncludingNCI,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].MinorityInterest')                                                                  IS NOT NULL THEN 'YES' ELSE 'no' END AS has_MinorityInterest,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].PartnersCapital')                                                                   IS NOT NULL THEN 'YES' ELSE 'no' END AS has_PartnersCapital
FROM missing_se ms
INNER JOIN financial_analytics_silver.stg_sec_edgar__companyfacts_raw b ON ms.cik = b.cik
ORDER BY ms.gics_sector, ms.entity_name;


-- ============================================================
-- A3.8 — Tag evidence: cash_and_equivalents (ALREADY RUN earlier)
-- Result: 20 of 23 file CashAndCashEquivalentsAtCarryingValue historically
-- only, switched to CashCashEquivalentsRestrictedCashAndRestrictedCashEquivalents
-- post-2018 ASU 2016-18. 3 banks (COF, PNC, WFC) genuinely don't file
-- the bare tag — need alias. Fix = add Restricted... tag to seed.
-- ============================================================


-- ============================================================
-- A3.9 — Tag evidence: operating_cash_flow (3 missing at FY2024)
-- ============================================================
WITH latest AS (
    SELECT MAX(as_of_date) AS latest_as_of FROM financial_analytics_silver.mart_financial_health
),
missing_ocf AS (
    SELECT s.cik, s.ticker, s.entity_name, s.gics_sector
    FROM financial_analytics_silver.sp100_company_sector s
    LEFT JOIN financial_analytics_silver.mart_financial_health m
        ON s.cik = m.cik
        AND m.as_of_date = (SELECT latest_as_of FROM latest)
        AND m.fiscal_year = 2024
    WHERE m.operating_cash_flow IS NULL
)
SELECT
    mo.ticker,
    mo.entity_name,
    mo.gics_sector,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].NetCashProvidedByUsedInOperatingActivities')                            IS NOT NULL THEN 'YES' ELSE 'no' END AS has_NetCashOpAct,
    CASE WHEN json_extract(b.json_text, '$.facts["us-gaap"].NetCashProvidedByUsedInOperatingActivitiesContinuingOperations')        IS NOT NULL THEN 'YES' ELSE 'no' END AS has_NetCashOpActContOps
FROM missing_ocf mo
INNER JOIN financial_analytics_silver.stg_sec_edgar__companyfacts_raw b ON mo.cik = b.cik
ORDER BY mo.gics_sector, mo.entity_name;
