-- =============================================================================
-- Phase 1 Bronze layer DDL — SEC EDGAR companyfacts
-- =============================================================================
-- Creates the Athena/Glue Catalog table over zone=bronze/ in S3.
--
-- Architecture decision: manual DDL, NOT Glue Crawler. The Crawler was
-- attempted first (2026-05-25, see EXTRACT_PIPELINE.md section 9) and failed
-- with a ValidationException at 49 seconds — the SEC EDGAR companyfacts JSON
-- has heterogeneous schemas (each company reports a different XBRL concept
-- set under facts.us-gaap and facts.dei), and the inferred per-CIK struct
-- definitions exceeded Glue Catalog's 131,072-character column type-string
-- limit on NVIDIA's filing. Manual DDL with the deeply-nested 'facts' object
-- intentionally excluded sidesteps the issue: Bronze stays raw and unopinionated
-- (per demo-durability principle 1) and Phase 2 Silver dbt-athena models will
-- parse the JSON via json_extract_* functions on the raw S3 files.
--
-- Partition projection (TBLPROPERTIES) lets Athena infer partitions from S3
-- key paths at query time — no MSCK REPAIR or ALTER TABLE ADD PARTITION
-- needed when new extract_date partitions land.
--
-- Run order in Athena Console: one statement at a time per the Console's
-- single-statement-per-Run constraint. Production deployments via boto3 /
-- Step Functions can submit both in one batch.
-- =============================================================================

-- Idempotency guard — safe to re-run during schema iteration
DROP TABLE IF EXISTS financial_analytics_bronze.sec_edgar_companyfacts;

-- EXTERNAL: data lives on S3, Athena does not manage its lifecycle.
-- Dropping this table removes Catalog metadata only; S3 files stay intact.
CREATE EXTERNAL TABLE financial_analytics_bronze.sec_edgar_companyfacts (
    -- entityName from JSON. Hive lowercases column names by default;
    -- the mapping.entityname property below preserves the camelCase
    -- reference to the JSON field.
    entityname string
)
-- Partition columns derived from S3 key=value folder structure
PARTITIONED BY (
    -- Date the extract ran (yyyy-MM-dd format from extract_sec_edgar.py)
    extract_date string,
    -- 10-digit zero-padded CIK string from extract_sec_edgar.py partition naming
    cik string
)
-- openx is Athena's canonical JSON SerDe — permissive struct handling
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
WITH SERDEPROPERTIES (
    -- Maps Hive's lowercased "entityname" to JSON's actual "entityName"
    'mapping.entityname' = 'entityName',
    -- Fail loudly on bad JSON rather than silently skip malformed files
    'ignore.malformed.json' = 'false'
)
LOCATION 's3://phil-financial-analytics-lakehouse/zone=bronze/'
-- Partition projection: Athena infers partition values from S3 key paths at
-- query time. No MSCK REPAIR needed when new partitions land.
TBLPROPERTIES (
    'projection.enabled'             = 'true',
    -- extract_date is a date range — projection enumerates one virtual
    -- partition per day from initial extract through 'NOW'
    'projection.extract_date.type'   = 'date',
    'projection.extract_date.range'  = '2026-05-24,NOW',
    'projection.extract_date.format' = 'yyyy-MM-dd',
    -- cik values are an enumerated static set — Athena enumerates the
    -- valid partition values from the list below at query time without
    -- needing a WHERE cik = 'X' filter. Switched from type=injected
    -- (Phase 1 session 3 default) to type=enum at Phase 2 session 3 after
    -- the type=injected constraint blocked dbt CTAS materialization (full
    -- scans without static cik filters fail under injected mode). The
    -- 100 CIKs below are the iShares OEF NPORT-P S&P 100 roster as of
    -- 2025-12-31 (per scripts/extract_sec_edgar.py source-of-record).
    -- S&P 100 turnover requires updating this list AND the equivalent
    -- in 02_create_bronze_raw_text_table.sql, then DROP+CREATE both
    -- Glue Catalog tables. AWS Athena partition-projection-supported-types
    -- docs recommend enum for "a few dozen" values — 100 is on the higher
    -- end but within practical bounds for our query patterns.
    'projection.cik.type'            = 'enum',
    'projection.cik.values'          = '0000001800,0000002488,0000004962,0000005272,0000006281,0000008670,0000012927,0000014272,0000018230,0000019617,0000021344,0000021665,0000027419,0000032604,0000034088,0000036104,0000037996,0000040533,0000040545,0000050863,0000051143,0000059478,0000060667,0000063908,0000064040,0000064803,0000066740,0000070858,0000072971,0000077476,0000078003,0000080424,0000087347,0000092122,0000093410,0000097476,0000097745,0000100885,0000101829,0000104169,0000109198,0000200406,0000310158,0000310764,0000313616,0000315189,0000316709,0000318154,0000320187,0000320193,0000354950,0000713676,0000731766,0000732712,0000732717,0000753308,0000764180,0000773840,0000789019,0000796343,0000804328,0000829224,0000831001,0000858877,0000882095,0000886982,0000895421,0000896159,0000896878,0000898173,0000909832,0000927628,0000936468,0001018724,0001035267,0001045609,0001045810,0001048911,0001051470,0001053507,0001063761,0001065280,0001067983,0001075531,0001090727,0001091667,0001099219,0001103982,0001108524,0001141391,0001156039,0001163165,0001166691,0001283699,0001318605,0001321655,0001326160,0001326801,0001341439,0001373715,0001390777,0001403161,0001413329,0001467373,0001467858,0001543151,0001551152,0001613103,0001633917,0001637459,0001652044,0001707925,0001730168,0001744489,0002012383',
    -- Template for reconstructing the S3 path from partition values
    'storage.location.template'      = 's3://phil-financial-analytics-lakehouse/zone=bronze/extract_date=${extract_date}/cik=${cik}/'
);
