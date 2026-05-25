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
    -- cik values are "injected" — Athena learns valid values from the
    -- WHERE clause at query time; queries against this table MUST filter
    -- on cik or partition pruning fails
    'projection.cik.type'            = 'injected',
    -- Template for reconstructing the S3 path from partition values
    'storage.location.template'      = 's3://phil-financial-analytics-lakehouse/zone=bronze/extract_date=${extract_date}/cik=${cik}/'
);
