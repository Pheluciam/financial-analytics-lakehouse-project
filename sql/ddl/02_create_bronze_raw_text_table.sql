-- =============================================================================
-- Phase 2 session 2 Bronze raw-text DDL — second view over SEC EDGAR companyfacts
-- =============================================================================
-- Creates a SECOND Athena/Glue Catalog table over the SAME S3 location as
-- financial_analytics_bronze.sec_edgar_companyfacts (see 01_create_bronze_tables.sql)
-- but using a text-based SerDe instead of the openx JSON SerDe. Each JSON
-- file becomes one row with its entire content sitting in a single STRING
-- column called json_text. The first table exposes typed cover-page columns
-- (entityname). This second table exposes the full file body so that
-- downstream dbt intermediate models can call json_extract_* against it
-- to pull specific XBRL concepts (Revenues, NetIncomeLoss, Assets, ...) out
-- of the heterogeneous facts.us-gaap nested structure.
--
-- ARCHITECTURE DECISION — why a second table rather than extending the first?
--
-- (a) The openx JSON SerDe is only documented to handle nested JSON via
--     struct<...> typing (verified against docs.aws.amazon.com 2026-05-27;
--     see DBT_PIPELINE.md section 7). There is no documented "slurp the
--     whole nested object into one STRING column" option.
-- (b) struct<...> typing on the SEC EDGAR facts object exceeds Glue Catalog's
--     131,072-character column type-string limit — NVIDIA's filing blew the
--     cap during the 2026-05-25 Glue Crawler attempt (LEARNINGS.md entry
--     "Glue Crawler fails on heterogeneous JSON via the 128 KB ..."). The
--     struct route is architecturally closed at S&P 100 scale.
-- (c) Modifying the existing Bronze table would breach demo-durability
--     principle 1 (Bronze is the immutable system-of-record snapshot frozen
--     at Phase 1 close, 2026-05-25).
--
-- A SECOND table over the same files: (1) keeps the Phase 1 verified surface
-- entirely intact, (2) uses only documented Athena features, (3) exposes the
-- raw JSON text for downstream json_extract_* processing in the dbt
-- intermediate layer.
--
-- SERDE CHOICE — LazySimpleSerDe via ROW FORMAT DELIMITED.
--
-- FIELDS TERMINATED BY '\001' (octal for SOH, ASCII 0x01). SOH cannot
-- appear unescaped in well-formed JSON: the JSON spec requires control bytes
-- in string values to be \u-escaped. So the literal byte 0x01 will never
-- appear in any minified SEC EDGAR JSON file. With only one declared column
-- (json_text), each line of input goes entirely into that column. SEC EDGAR's
-- companyfacts endpoint returns single-line minified JSON (already verified
-- empirically by Phase 1's openx SerDe, which requires single-line JSON and
-- successfully parsed all 100 files). So each file maps to exactly one row.
--
-- '\001' is also Athena's CTAS default field delimiter — the same value
-- Hive/Athena pick when no delimiter is specified. Idiomatic.
--
-- Partition projection: identical scheme to sec_edgar_companyfacts so both
-- tables expose the same partition surface and dbt models can join cleanly
-- on (cik, extract_date).
--
-- Run order in Athena Console: one statement at a time per the Console's
-- single-statement-per-Run constraint. Production deployments via boto3 /
-- Step Functions can submit both in one batch.
-- =============================================================================

-- Idempotency guard — safe to re-run during schema iteration
DROP TABLE IF EXISTS financial_analytics_bronze.sec_edgar_companyfacts_raw;

-- EXTERNAL: same physical S3 files as sec_edgar_companyfacts, different SerDe
-- + column schema. Dropping this table removes Catalog metadata only; S3
-- files stay intact and the other Bronze table is unaffected.
CREATE EXTERNAL TABLE financial_analytics_bronze.sec_edgar_companyfacts_raw (
    -- Full JSON file content as a single text blob. Each file is a minified
    -- single-line JSON object; LazySimpleSerDe maps it to one row here.
    -- Downstream dbt intermediate models call json_extract_* against this
    -- column to pull out specific XBRL concepts.
    json_text string
)
-- Partition columns derived from the same S3 key=value folder structure
-- as sec_edgar_companyfacts
PARTITIONED BY (
    -- Date the extract ran (yyyy-MM-dd format from extract_sec_edgar.py)
    extract_date string,
    -- 10-digit zero-padded CIK string from extract_sec_edgar.py
    cik string
)
-- LazySimpleSerDe (the default for ROW FORMAT DELIMITED) with SOH (0x01)
-- as the field terminator. SOH cannot appear unescaped in well-formed JSON,
-- guaranteeing each file's entire content stays in the single json_text column.
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\001'
LOCATION 's3://phil-financial-analytics-lakehouse/zone=bronze/'
-- Partition projection: identical scheme to sec_edgar_companyfacts. Both
-- tables share the same partition surface, so dbt models can join on
-- (cik, extract_date) without partition-skew issues.
TBLPROPERTIES (
    'projection.enabled'             = 'true',
    'projection.extract_date.type'   = 'date',
    'projection.extract_date.range'  = '2026-05-24,NOW',
    'projection.extract_date.format' = 'yyyy-MM-dd',
    -- cik values are an enumerated static set — Athena enumerates the
    -- valid partition values from the list below at query time without
    -- needing a WHERE cik = 'X' filter. Switched from type=injected at
    -- Phase 2 session 3 after the type=injected constraint blocked dbt
    -- CTAS materialization. The 100 CIKs match the equivalent enum in
    -- 01_create_bronze_tables.sql; both Bronze tables share the same
    -- partition surface so both lists move in lockstep.
    'projection.cik.type'            = 'enum',
    'projection.cik.values'          = '0000001800,0000002488,0000004962,0000005272,0000012927,0000014272,0000018230,0000019617,0000021344,0000021665,0000027419,0000032604,0000034088,0000036104,0000040533,0000040545,0000050863,0000051143,0000059478,0000060667,0000063908,0000064803,0000066740,0000070858,0000072971,0000077476,0000078003,0000080424,0000092122,0000093410,0000097476,0000097745,0000100885,0000101829,0000104169,0000200406,0000310158,0000313616,0000315189,0000316709,0000318154,0000320187,0000320193,0000354950,0000731766,0000732712,0000732717,0000753308,0000764180,0000773840,0000789019,0000796343,0000804328,0000829224,0000831001,0000858877,0000882095,0000886982,0000895421,0000896878,0000909832,0000927628,0000936468,0001018724,0001035267,0001045810,0001048911,0001053507,0001063761,0001065280,0001067983,0001075531,0001090727,0001099219,0001103982,0001108524,0001141391,0001163165,0001166691,0001283699,0001318605,0001321655,0001326160,0001326801,0001341439,0001373715,0001390777,0001403161,0001413329,0001467373,0001467858,0001543151,0001551152,0001613103,0001633917,0001652044,0001707925,0001730168,0001744489,0002012383',
    'storage.location.template'      = 's3://phil-financial-analytics-lakehouse/zone=bronze/extract_date=${extract_date}/cik=${cik}/'
);
