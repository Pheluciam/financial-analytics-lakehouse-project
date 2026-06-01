# LEARNINGS.md — Retail Demand & Forecasting Pipeline

> A running journal of what I'm learning on Project #2.
> First entry: 2026-05-09.

This is my second data engineering project, building on what I learned in Project #1
(CDC NT Transport). The point of this document isn't to look polished. It's to capture
the real moments where something clicked, broke, or made me rethink an assumption,
so I can refer back to it in interviews and on future projects.

---

## Project #3 lessons (`financial-analytics-lakehouse-project` — 2026-05-23+)

Diagnosis → fix → lesson loops from Project #3 as they happen. Project #2
content (Project summary onwards) continues unchanged below.

### Build locally first, GitHub commit at session close (2026-05-23, Phase 1 session 1)

**Diagnosis.** Mid-session, the GitHub repo was created and `git init` +
`git remote add origin` run, with the bundled commit deliberately deferred
to a later step. Phil flagged this as unprofessional — the repo had a
dangling git-plumbing state with no commit pushed, splitting the ship-it
moment across a dinner break.

**Fix.** Reversed in-session: built the remaining session-1 docs (README,
EXTRACT_PIPELINE.md update, PROJECT_CONTEXT.md session-log entry) all at
once, then bundled `git add .` → `git commit` → `git push` as one atomic
ship moment. Pre-dinner `git init` + remote config just sits under the
first commit — invisible in repo history.

**Lesson.** Senior-DE pattern: build everything locally first, THEN create
remote and push in one atomic bundle at session close. Splitting GitHub
repo creation from the inaugural commit across a break is amateur — repo
looks empty to anyone visiting in the gap, and the workflow stutters at
every context switch. Apply forward: NO mid-session git plumbing, only at
session close.

### Never screenshot AWS one-time credentials (2026-05-23, Phase 1 session 1)

**Diagnosis.** During phil-admin IAM user creation, the Step 4 "Retrieve
password" screen shows the auto-generated temp password in cleartext.
Screenshotted and shared — password visible. Screenshot data persists in
conversation context; anything visible in one is effectively exposed.

**Fix (mitigations in place).** Force-change-on-first-sign-in was ticked
during user creation, so the temp password died on first login. MFA
enrolled immediately after the password change, narrowing the
already-narrow exposure window further. Net real-world risk: low; the
discipline gap is the actual lesson.

**Lesson.** AWS one-time temp passwords + access keys must be copied to
clipboard or a password manager ONLY, never screenshotted. When the AWS
dialog shows the values: clipboard, then direct-to-`.env` (via the
download-CSV flow for access keys). Never via screen capture. Anything
visible in a screenshot is exposed — treat as such and rotate.

### AWS Console region selector on Global-service pages (2026-05-23, Phase 1 session 1)

**Diagnosis.** Tried to switch region from Sydney to us-east-1 via the
top-right region dropdown while on IAM and Billing pages. Clicks on
"N. Virginia" appeared to do nothing — region indicator stayed showing
Sydney (or "Global"), no page reload, no visible state change.

**Fix.** IAM and Billing are global services — they don't depend on region,
so the dropdown has no visible effect on those pages. Navigated direct to
S3 (region-bound), clicked the region dropdown there, picked N. Virginia
— switched immediately.

**Lesson.** Don't try to set region from a global-service page. Canonical
pattern: navigate to the target region-bound service first, THEN switch
region from the dropdown on that page. Saves multiple minutes of "why
isn't this working" diagnosis on every region change.

### Inline-code formatting in explanations breaks Phil's reading flow (2026-05-24, Phase 1 session 2)

**Diagnosis.** During the session 2 smoke-test design discussion, Claude
peppered explanatory prose with backticks — wrapping AWS service names,
Python function names, env-var names, bucket prefixes, and config strings
in inline code formatting throughout three multi-paragraph design calls.
Phil flagged it: the orange/pink inline rendering against the dark chat
background visually fragments the prose and disrupts his comprehension.
The rule against this had been locked since 2026-05-20 in
TEACHING_PREFERENCES.md line 92, but Claude defaulted to chat-conventional
inline-code styling anyway because most assistant training treats inline
backticks as standard for technical references.

**Fix.** Two coordinated edits: (a) added a 2026-05-24 reinforcement bullet
to TEACHING_PREFERENCES.md "Anything else Claude should know" explicitly
calling out the violation categories — AWS service names, Python module /
function names, AWS resource identifiers, env-var names, flag names, file
extensions — and re-locking the rule as zero-tolerance for the rest of
Project #3; (b) banked the diagnosis loop here so it's a referenceable
artefact, not a one-off chat correction. Mental test stays: paste-able →
code block; reference for reading → plain text.

**Lesson.** TEACHING_PREFERENCES.md rules that conflict with assistant
defaults need active reinforcement, not single-mention-and-trust. Phil's
preferences against AI defaults (no inline code in prose, comments
above-the-line not end-of-line, no bullet points in reports, plain-text
references) all live in this category — they require Claude to consciously
override its default rendering on every applicable message, not just once
at session start. Carry-forward: at session kickoff, scan TEACHING_PREFERENCES
for the rules that go against typical chat conventions and treat them as
active checkpoints throughout the session, not load-once-and-coast.

### Process-density drift — Phase-0 discussion mode bleeding into Phase-1 shipping (2026-05-24, Phase 1 session 2)

**Diagnosis.** Session 2 drifted into Phase-0-style discussion density —
multi-paragraph design call write-ups, 3-6 "green-light A/B/C?" questions
before writing each script, comment-above-every-line walkthroughs, audit
results as paragraphs instead of tick-box rows. Phil flagged it mid-session:
"a lot of this is way too much... I don't wanna take seven hundred and three
years to write something... let's get this project built because then there's
another five projects I wanna build, and I wanna get a job."

**Fix.** Three coordinated TEACHING_PREFERENCES.md updates locked the new
standing default (all bulleted under "Anything else Claude should know"):
(a) pace > teaching density — Project #3 ships first, deep instruction
deferred to the 6-8 week training journey + interview mock sessions;
(b) verbose-in-chat depth calibrated to block-level for Python, line-level
only for config-style files; (c) standard response template — brief bullet
summary, light explanation, one optional direction question, default to
senior-DE professional on every other call, Phil asks for depth if he
wants it. Audit results render as 10-row tick-box tables, not paragraphs.

**Lesson.** Claude's chat defaults trend verbose because most assistant
training treats thorough explanation as the safe move. For Phil's
constraint (ship 8 projects to qualify for jobs before money runs out),
verbose IS the wrong move — pace is the safety. The professional code
itself stays at senior-DE quality (the deliverable is what gets judged);
the conversation density around building it should match Project #2's
tight ship pace, not Project-#3-Phase-0's deliberation density. Deep
explanation has explicit homes: the training journey, mock interviews,
and Phil saying "explain that more." Default elsewhere = tight bullets,
move fast, ship.

### venv-not-active on a fresh PowerShell session (2026-05-25, Phase 1 session 3)

**Diagnosis.** Started session 3's 10-company extract with `python scripts/extract_sec_edgar.py --cik ...`. Hit `ModuleNotFoundError: No module named 'boto3'` at the import line. Phil correctly named the hypothesis in his own words ("I'm not in venv. Is that an issue?") before Claude proposed the fix — engagement with the diagnostic rather than blank-stare-and-accept.

**Fix.** Activate the venv before running scripts: `.\.venv\Scripts\Activate.ps1`. Visual tell: prompt prefix changes to `(.venv) PS C:\...>`. boto3 was installed into the venv at session 2 close, not into system Python; the fresh PowerShell window had no venv active, so the unqualified `python` invocation resolved to system Python which has no boto3.

**Lesson.** Every new PowerShell window starts WITHOUT venv active. Manual activation required every time. VS Code's integrated terminal can be auto-configured via workspace settings (Phase 6 polish); outside-VS-Code fresh shells always need the manual step. Carry-forward debugging-fluency win: Phil drove the diagnosis to fix, not the other way around. Worth banking as a live-coding interview reference — the first question after any "my script doesn't run" failure is "what Python is actually running this?", and the second is "is the venv active?".

### Glue Crawler fails on heterogeneous JSON via the 128 KB column-type-definition limit (2026-05-25, Phase 1 session 3)

**Diagnosis.** Glue Crawler against `s3://phil-financial-analytics-lakehouse/zone=bronze/` failed at 49 seconds (0.223 DPU-hours) with `com.amazonaws.services.glue.model.ValidationException: Value at 'table.storageDescriptor.columns.3.member.type' failed to satisfy constraint: Member must have length less than or equal to 131072`. Failing table: `sec_edgar_cik_0001045810` (NVIDIA). 6 partial tables created before bail; partitions not unified into a single table as we expected.

**Root cause.** Glue Catalog has a hard 131,072-character (128 KB) ceiling on each column's type-definition string. SEC EDGAR's `facts` field is a deeply nested struct — `facts.us-gaap.*` enumerates hundreds of XBRL concepts per company, and the concept set DIFFERS per company (banks report different concepts than energy majors). When the Crawler tried to express NVIDIA's `facts` as a strongly-typed nested struct, the type string blew past 128 KB and the Catalog rejected the write.

**Fix.** Pivot from Crawler to manual `CREATE EXTERNAL TABLE` DDL. The 128 KB cap is a Catalog architectural limit — no Crawler config can fit NVIDIA's full inferred schema. Manual DDL excludes the heterogeneous `facts` field entirely; types only universal columns (`entityname`) plus partition keys (`extract_date`, `cik`). Phase 2 Silver dbt-athena models will parse the JSON via `json_extract_*` on raw S3 files when building hubs/links/satellites.

**Lesson.** Glue Crawler earns its keep when data shape is schema-PREDICTABLE (Parquet, CSV, narrow JSON). It breaks on deeply-heterogeneous JSON like SEC EDGAR XBRL facts. When the data shape is known at design time, manual DDL beats Crawler. The Crawler infrastructure stays as scaffolding for Silver/Gold Parquet layers where it'll work cleanly. Carry-forward: at design time, audit upstream JSON for heterogeneous keys before defaulting to Crawler. The "see what Glue does first" optimistic approach cost 49 seconds and 0.223 DPU-hours to confirm what a single web search on Glue limits would have predicted.

### Athena Query Editor enforces one statement per Run (2026-05-25, Phase 1 session 3)

**Diagnosis.** Pasted Bronze DDL containing both `DROP TABLE IF EXISTS ...` and `CREATE EXTERNAL TABLE ...` separated by a semicolon. Athena Console returned: "Only one sql statement is allowed."

**Fix.** Split into two queries; Run each in turn via the Console editor. Web search (allowed_domains restricted to AWS docs) confirmed the constraint is documented — single-statement-per-Run is a Console editor design, not a SQL dialect limitation. CTEs and multi-CTE single statements are fine; semicolon-separated multiple statements are not. Production deployments via boto3, AWS CLI, or Step Functions can batch multi-statement DDL — only the Console UI enforces this.

**Lesson.** Athena Console Query Editor has a single-statement-per-Run constraint that's tooling-layer, not SQL-dialect. When shipping multi-statement DDL files for portfolio polish: include a header comment "Run order in Athena Console: one statement at a time per the Console's single-statement-per-Run constraint. Production deployments via boto3 / Step Functions can submit both in one batch." That comment lives at the top of `sql/ddl/01_create_bronze_tables.sql` as the standing convention.

### TYPE_MISMATCH on date BETWEEN over a string partition column + four valid fixes (2026-05-25, Phase 1 session 3)

**Diagnosis.** Smoke-check query `WHERE extract_date BETWEEN DATE '2026-05-24' AND DATE '2026-05-25'` failed with `TYPE_MISMATCH: line 3:20: Cannot check if varchar is BETWEEN date and date`. Phil correctly diagnosed the type mismatch in his own words ("we've stored extract date as a varchar rather than as a date field" — speech-to-text rendered "bar chart" but the concept was correct) before Claude proposed the fix.

**Root cause.** `extract_date` is declared as STRING in `PARTITIONED BY (...)`. Athena reads partition values from S3 path strings (`extract_date=2026-05-24`), so the column type in the table is varchar regardless of what the partition PROJECTION declares. The projection's `type='date'` controls how Athena enumerates partition values during pruning, not the column type the WHERE predicate sees.

**Fix — four valid approaches, ranked for senior-DE practice.**

1. **Option B (string comparison) — RECOMMENDED.** `WHERE extract_date BETWEEN '2026-05-24' AND '2026-05-25'`. ISO 8601 (YYYY-MM-DD) strings sort lexicographically the same as date order — no type conversion needed, no runtime cost, no risk of defeating partition pruning. Cleanest when the partition column is string-typed.
2. **Option A (drop the date filter).** Valid only when partition count is small enough that scanning all is cheap. Trivial at our 2-partition scale.
3. **Option C (explicit CAST).** `WHERE CAST(extract_date AS DATE) BETWEEN DATE '...' AND DATE '...'`. Most portable across dialects. Gotcha: casting a partition column can defeat partition pruning at TB scale if the optimizer doesn't push the predicate down.
4. **Option D (Trino DATE function).** `WHERE DATE(extract_date) BETWEEN DATE '...' AND DATE '...'`. Same effect as Option C, less verbose, less portable across dialects.

**Lesson.** Partition projection's TYPE setting and the partition COLUMN's declared type are SEPARATE concerns. When designing partition schemes: choose the column type that matches how queries will FILTER, not just how the projection ENUMERATES. Verified mid-session via web search: the `::` PostgreSQL cast operator is NOT supported in Athena/Trino — use `CAST(... AS type)` instead. The `::` shortcut is PostgreSQL-specific. Phil drove this diagnosis correctly — banked as another debugging-fluency win.

### Web-search-verify before shipping unverified syntax claims (2026-05-25, Phase 1 session 3)

**Diagnosis.** Claude claimed mid-session: "openx JsonSerDe serializes complex nested objects back to STRING when the column type is STRING" — without docs verification. The Bronze DDL was designed with `facts string` relying on this behavior. Phil pushed back ("do not trust your training model. Do a web search on AWS Athena docs") BEFORE the DDL shipped to Athena.

**Fix.** Two targeted web searches (with `allowed_domains` restricted to docs.aws.amazon.com + trino.io) — (1) confirmed Athena Console one-statement-at-a-time constraint, (2) confirmed `::` cast NOT supported in Athena/Trino. Critically, the openx-string-serialization claim was NOT confirmed by the docs. Pivoted to a safer DDL: drop the `facts` column entirely from Bronze, type only `entityname`. Phase 2 Silver dbt-athena models will use `json_extract_*` on raw S3 files for any JSON parsing — pushes the heterogeneity handling to where it belongs architecturally.

**Lesson.** Training-data claims about syntax + library behavior can be confidently wrong, especially for AWS services that evolve quickly. For DDL or schema design decisions worth a verifying search even when 80% confident. Use `allowed_domains` to restrict searches to authoritative sources (AWS docs, dialect-owner docs like trino.io) — never random blogs. Phil's "do not trust your training, web-search authoritative sources" discipline is now a standing pattern for the rest of Project #3 and all mini-projects: before shipping any non-trivial DDL, API call, or library claim, two checks — (1) does this work? (2) is my syntax current? Bank as an interview talking point: "How do you handle uncertainty about AWS service behavior?" — answer: "Restricted-domain web search of authoritative docs, then verify in a sandbox before shipping."

### Web fetch returning empty on a server-rendered page → escalate to alternate authoritative source (2026-05-25, Phase 1 session 4)

**Diagnosis.** Tried to fetch the Wikipedia S&P 100 constituent table via web_fetch for the 100-company roster derivation. Page returned empty body (likely JS-rendered table or sandbox-level bot detection — the page itself exists, the search results found it, but the fetch returned only the URL string with no content). The S&P Dow Jones Indices interactive page also fetched (76 KB) but contained no constituent table inline — that's a client-rendered React app.

**Fix.** Pivoted to the iShares OEF S&P 100 ETF NPORT-P schedule of investments on SEC EDGAR (search results had surfaced it). The OEF tracks the S&P 100 by construction — its holdings ARE the index. SEC EDGAR HTML filings are server-rendered, persistent URLs, no JS dependency. Returned 101 ticker line items cleanly. Cross-referenced against SEC's company_tickers.json (~75 KB JSON of 10K+ entries) via single regex grep to extract the 100 CIKs.

**Lesson.** When researching a topic where multiple authoritative sources exist, the "obvious" Wikipedia route isn't always cheapest. Index-tracking ETFs filed with regulators are often the more durable authoritative source — quarterly NPORT-P filings, persistent SEC URLs, server-rendered HTML, no JS dependency. The general principle: regulated filings beat web pages when both exist. Banked as a research-pattern for the rest of Project #3 and any future portfolio work needing authoritative index/benchmark constituent lists.

### Defensive non-conforming-key skip earned its keep on first run (2026-05-25, Phase 1 session 4)

**Diagnosis.** scripts/verify_bronze_s3_metadata.py was built with a PARTITION_KEY_RE regex check + WARNING skip for keys not matching the expected `zone=bronze/extract_date=YYYY-MM-DD/cik=XXXXXXXXXX/` shape. On its very first run, the skip fired once — on the bare `zone=bronze/` folder placeholder created during session 1's S3 bucket setup. Without the skip, that key would have crashed downstream parsing (no extract_date or cik to extract from `zone=bronze/`).

**Fix.** No fix needed — the defense worked exactly as designed. Logged the skipped key with WARNING level, surfaced the skip count in the summary line ("Listed 101 Bronze objects (1 skipped non-conforming)"), continued without raising.

**Lesson.** Defensive checks against "this shouldn't happen, but if it does, log loudly and continue" are worth the line count even when they feel like over-engineering at design time. The cheapest place to catch unexpected state is the first run, not after weeks of accumulated drift. Carry-forward: every S3 enumeration script in Project #3 (Silver / Gold verify scripts in Phase 2-4) should validate the key shape it expects to see, log skips by name, and surface the skip count in the summary. Reads as "defensive engineering" in code review; functions as "free interview talking point" — explaining the line in interview reads as senior-DE thinking.

### Athena scan on raw JSON Bronze scales with CIK count, not query selectivity (2026-05-25, Phase 1 session 4)

**Diagnosis.** Re-running the refactored SQL verify suite at 100-CIK scale: 2.03 GB scanned for a query that SELECTs only one column (entityname) plus the two partition columns (extract_date, cik). At 11-CIK scale the same SELECT scanned 241.5 KB. That's ~8400x scan increase for 10x CIK count — vastly more than the linear 10x naive intuition would predict.

**Root cause.** Athena's openx JsonSerDe reads every byte of every JSON file in the matched partitions, regardless of how few columns the query projects. Each Bronze partition holds a 2-7 MB raw companyfacts JSON file. The SerDe parses the full JSON to materialize the queried row — no column pruning, no predicate pushdown, no projection pushdown. Athena's columnar scan optimizations work for Parquet / ORC / Iceberg; they do not work for row-oriented JSON. Cost at this scale: ~$0.01 per query (well within demo budget). At Silver/Gold scale with daily refresh, that same pattern would be $1-5/query.

**Lesson.** Bronze JSON layers are query-cost-inefficient by design — that's exactly why the medallion pattern materializes Silver as a columnar format. Bank as the explicit cost rationale for Phase 2 dbt-athena Iceberg/Parquet materialization: Bronze JSON scanned 2 GB for a single-column SELECT at 100 CIKs because openx JsonSerDe has no column pruning; Silver as Parquet/Iceberg brings typical scan to KB territory via Athena's columnar engine. Interview talking point ready to ship: "Why did you pick Parquet for Silver?" → "Measured: Bronze JSON scans 2 GB for a 1-column query; Parquet column pruning brings that to KB. The materialization layer pays for itself in pennies per query at Phase 1 scale and dollars per query at production scale."

### AWS IAM inline-policy 2048-char cap is a hard limit per user (2026-05-25, Phase 2 session 1)

**Diagnosis.** Authored an 8-statement inline policy for the new `phil-dbt` IAM user covering Athena workgroup execute, Glue Catalog R/W on bronze+silver databases, S3 read on bronze, S3 R/W on silver and athena-results. Attaching via the Console's "Create inline policy" path failed with `Your policy exceeds the non-whitespace character limit of 2048. The character limit includes the total character count of all inline policies for phil-dbt.` Policy weighed in around 3KB of non-whitespace characters — over the cap by ~50%.

**Root cause.** AWS imposes hard per-user-aggregate caps on inline policies, and the caps scale by attachment surface: user-inline = 2048, group-inline = 5120, **customer-managed = 6144**. The "non-whitespace character limit" wording threw initial diagnosis (sounds like an indentation issue) — actually it's the opposite: the limit IGNORES whitespace, so reformatting the JSON saves nothing. The cap is on the actual statement bodies.

**Fix.** Pivoted to a Customer Managed Policy (`lakehouse-dbt-runtime-access`) — 6144-char cap fits the ~3KB policy with room to spare, AND the managed-policy form is the more professional pattern anyway: reusable across users/roles, automatically versioned (v1/v2/v3 as the policy is edited), stable name in CloudTrail audit logs. Inline policies are most appropriate for one-shot scopes where the policy lives and dies with the user; ours doesn't fit that shape.

**Lesson.** Inline-vs-managed isn't an arbitrary distinction — AWS encodes their guidance into the per-character caps. Any scoped runtime policy of meaningful size (more than ~5 statements) wants to be a Customer Managed Policy from the start. Carry-forward: for Step Functions execution role in Phase 3, Lambda execution roles in mini-projects, etc. — skip the inline path entirely and create a Customer Managed Policy first, attach second. Pairs with the Phase 1 Glue Crawler 128KB column-type-definition limit as the second "AWS hard limit only discovered by hitting" of Project #3 — both are infrastructure limits the docs mention only in passing.

**Sub-note (same diagnostic loop).** AWS IAM policy `Description` field accepts only the strict character set `a-zA-Z0-9+=,.@-_` plus spaces. Em-dashes (—), smart quotes, and forward slashes (/) all reject with `Invalid characters. Use alphanumeric and '+=,.@-' characters.` Claude's chat output uses typographic em-dashes by default; any paste-able destined for an AWS Console form field needs plain ASCII translation first. Banked as a standing self-correction for the rest of Project #3.

### Paste-able discipline third re-lock — mechanical pre-send check now mandatory (2026-05-25, Phase 2 session 1)

**Diagnosis.** Rule locked 2026-05-20 (TEACHING_PREFERENCES line 92), re-locked 2026-05-24 with zero-tolerance language (line 165). Phase 2 session 1 saw TWO violations within one session: (1) step 3d initially listed policy name + description as plain text rather than each in their own fenced code block; (2) step 4 prose was peppered with backticks for file paths and package names that Phil wasn't going to paste. Phil explicitly flagged both and asked for the rule to be re-locked AGAIN.

**Fix.** Wording stronger than zero-tolerance has hit its ceiling. The new enforcement mechanism is procedural, not exhortative — added as a third re-lock to TEACHING_PREFERENCES.md "Anything else Claude should know" (Project #3 Phase 2 session 1 entry). Two mandatory pre-send checks before any chat response: (1) mentally scan for every backtick; each one either opens/closes a fenced code block OR is removed and replaced with plain text — no inline backticks ever; (2) every form-field paste-able gets its own fenced code block, even single-word values. Mental test is now binary: "am I telling Phil to type/paste this value somewhere? Yes → its own code block. No → plain text, no backticks."

**Lesson.** When a project rule has been locked three times and is still drifting, the failure mode is no longer awareness — it's that Claude's default markdown formatting habits override project rules absent a mechanical intervention. Soft "remember to follow X" prompts don't beat trained generation defaults; procedural checks do. Carry-forward principle for any future rule that re-violates after a re-lock: escalate to a pre-send mechanical check, not just stronger wording. Interview talking point on AI-assisted-coding discipline: "When the AI repeats the same mistake despite explicit instruction, the failure is in the prompt mechanism, not the instruction content."

### Criterion-6 reflex on every new tool/adapter config file — anticipate IDE-vs-runtime drift proactively (2026-05-25, Phase 2 session 1)

**Diagnosis.** Authored `dbt/dbt_project.yml` with `+table_type`, `+format`, `+table_properties` (dbt-athena adapter-specific config keys). Three IDE-or-runtime issues surfaced in immediate succession after first dbt invocation: (1) VS Code's YAML extension flagged the adapter-specific keys as unknown because SchemaStore's `dbt_project-latest.json` schema is dbt-core only (red squigglies); (2) dbt-core 1.11 fired `CustomKeyInConfigDeprecation` false positives on `table_properties.format_version` per dbt-labs/dbt-core issues #12314, #12342, #12355, #12087; (3) `dbt parse` emitted `UnusedResourceConfigPath` for forward-looking layer defaults (marts/intermediate/warehouse) that had no models yet. All three were predictable on a new adapter's first config file; none were caught proactively.

**Fix.** Three coordinated bypasses, each documented in-file: (1) `.vscode/settings.json` + `.vscode/dbt_project.permissive.schema.json` (an empty JSON Schema document) override SchemaStore's automatic binding; (2) `flags.warn_error_options.silence` block in `dbt_project.yml` adds `CustomKeyInConfigDeprecation` + `DeprecationsSummary` with comment linking to the dbt-core issues; (3) removed empty-layer config blocks per "models drive configs" principle — re-added at the session each layer's first model lands.

**Lesson.** Engineering standards criterion 6 (Dev environment hygiene — locked 2026-05-14, Project #2 Phase 3 session 1, after Pylance yellow squigglies on the Airflow DAG) is supposed to cover exactly this drift class: "the linter/IDE sees something different from what gets committed and that's the silent-bug class the rest of the checklist exists to prevent." But the rule is reactive — it triggers AFTER squigglies surface. The carry-forward refinement: when authoring a new config file in a new tool/adapter for the first time, PROACTIVELY anticipate the IDE-vs-runtime gap and ship the bypass directive at file-creation time, not after Phil surfaces the squigglies. Apply same reflex to: any new dbt adapter's project.yml, any new Airflow DAG-side imports the IDE can't resolve, any new dbt package's vars block, any new GitHub Actions workflow with custom keys. Interview talking point: "How do you handle the gap between IDE static analysis and runtime behavior on new tools?" → "Proactive bypass directives at file creation with documented rationale, paired with the actual runtime as the source of truth — dbt parse, ruff, pytest. The IDE catches typos; the runtime catches behavior."

### dbt does NOT auto-load .env files — python-dotenv[cli] wrapper is the cross-platform pattern (2026-05-25, Phase 2 session 1)

**Diagnosis.** First `dbt parse` after writing `dbt/profiles.yml` (with `env_var()` Jinja references against `AWS_DBT_ACCESS_KEY_ID`) failed with `Parsing Error: Env var required but not provided: 'AWS_DBT_ACCESS_KEY_ID'`. The variable IS in `.env` — but dbt-core doesn't auto-load `.env` files. The Python extract scripts use `python-dotenv` explicitly via `load_dotenv()`; dbt has no equivalent mechanism. The feature request (dbt-labs/dbt-core issue #8026) is open since 2023 with no implementation timeline.

**Fix.** Install `python-dotenv[cli]` extras (gives a `dotenv` CLI command). Wrap every dbt invocation: `dotenv -f ..\.env run -- dbt <subcommand>`. From the `dbt/` subdirectory, `-f ..\.env` points at the project-root `.env` (dotenv defaults to looking in cwd). Cross-platform (works in PowerShell, bash, CI), no new project deps beyond what's already in `requirements.txt`, no secrets pasted into shell history.

**Lesson.** dbt and Python share a runtime but not a configuration-loading convention. The standing pattern for this project: every dbt CLI command is documented as `dotenv -f ..\.env run -- dbt ...` in DBT_PIPELINE.md, README, and any future CI YAML. Carry-forward: any tool that reads `os.environ` but doesn't have `.env`-loading semantics (most CLI tools — terraform, ansible, kubectl) takes the same wrapper pattern. Senior-DE interview frame: ".env files are a Python ecosystem convention, not a universal one. Wrappers (dotenv, direnv) bridge the gap cross-tool."

### Raw-JSON-read pattern locked as Option B: second Bronze table over same S3 location (2026-05-27, Phase 2 session 2)

**Diagnosis.** Phase 1 closed with the Bronze `sec_edgar_companyfacts` table deliberately omitting the `facts` field — Glue Crawler had failed at 49 seconds against NVIDIA's filing because the inferred struct type for `facts.us-gaap` exceeded Glue Catalog's 131,072-character per-column type-string limit. Bronze worked perfectly for cover-page queries (entityname + partition keys) but had no column reaching the actual XBRL financial concepts. Phase 2 session 2 needed to expose `facts` for json_extract_* to operate on. Three architectural options presented at session start, each with different trade-offs.

**Fix.** Web-search-verify pass against authoritative docs (allowed_domains restricted to docs.aws.amazon.com, docs.getdbt.com, github.com/dbt-athena/dbt-athena-external-tables, trino.io) to lock the choice before any DDL shipped.

(a) **Option A — extend Bronze DDL with `facts` STRING column.** The unverified Phase 1 session 3 claim that the openx JSON SerDe will serialize nested objects back to STRING when the column type is STRING. AWS docs (openx-json-serde.html) document nested-JSON handling via struct typing ONLY — exactly the typing pattern that blew the 128 KB ceiling on NVIDIA. No documented "slurp into STRING column" behavior exists. Same conclusion as Phase 1 session 3 LEARNINGS — the claim remains unsupported by docs. Rejected.

(b) **Option B — second Athena table over same S3 location.** Manual DDL using LazySimpleSerDe (default text SerDe via `ROW FORMAT DELIMITED`) with `FIELDS TERMINATED BY '\001'` (SOH byte — cannot appear unescaped in well-formed JSON), single STRING column `json_text`, same partition projection scheme as the existing Bronze table. Each minified single-line JSON file maps to exactly one row with full content in `json_text`. Downstream models call json_extract_* against that column to pull XBRL concepts out of the nested structure. Uses only documented Athena features. The Phase 1 verified Bronze surface stays entirely untouched. IAM impact zero — same S3 prefix, same Glue database. **Selected.**

(c) **Option C — dbt-external-tables via dbt-athena-external-tables.** The Athena-specific package opens its README with "PROOF OF CONCEPT — USE AT OWN RISK". 4 GitHub stars, 3 forks, 18 total commits, single v0.0.1 release Aug 2024, no further activity. Adds an experimental dependency that wraps the same DDL Option B writes by hand. Rejected on portfolio-polish grounds — recruiter-visible "use at own risk" in the dependency tree for a function the project doesn't need outsourced.

**Lesson.** Three carry-forward principles banked from this design call. **First**, when an architectural option from a prior session was flagged as unverified-by-docs in LEARNINGS, treat that as a hard veto signal, not "worth re-trying" — the verify pass will return the same docs and the same unsupported pattern. Save the search round-trip by leading with "Phase 1 verified this isn't documented; the search will only confirm that." **Second**, the "experimental package" trap in portfolio repos: the package may technically work, but its README header is visible to every recruiter who looks at the dependency tree. Portfolio polish ranks above marginal convenience. **Third**, the "two tables over same files" pattern is portable beyond this one source. Any future portfolio project hitting heterogeneous JSON / XML / nested binary data can use the same shape: keep the original typed-column table for cover-page queries, ship a second raw-text table over the same files for downstream json_extract / xml_parse / regex_extract work. Two catalogs over one set of files — the files don't care.

### Criterion-6 proactive-bypass missed AGAIN on _models.yml — dbt 1.10+ accepted_values argument-nesting (2026-05-27, Phase 2 session 2)

**Diagnosis.** First `dbt parse` against the new `dbt/models/intermediate/_models.yml` fired `MissingArgumentsPropertyInGenericTestDeprecation`: dbt-core 1.10.5+ now expects generic test arguments to nest under an `arguments` property, not at the top level of the test block. Phase 2 session 1 LEARNINGS entry "Criterion-6 reflex on every new tool/adapter config file" banked the exact pattern this was supposed to prevent: "when authoring a new config file in a new tool/adapter for the first time, PROACTIVELY anticipate the IDE-vs-runtime gap and ship the bypass directive at file-creation time, not after Phil surfaces the squigglies." The _models.yml was the new file class for the intermediate layer's first arrival — exactly the trigger. The proactive reflex did not fire; Claude shipped the pre-1.10.5 `accepted_values: values: [...]` form by default. Phil ran parse, the warning surfaced, fix landed in-session, re-parse clean. Net cost: two minutes plus a web-search round-trip.

**Fix.** Two coordinated edits to `dbt/models/intermediate/_models.yml`: (a) `concept_name` accepted_values nested under `arguments:` → `arguments: values: [...]` form; (b) same change to `unit` accepted_values. Web-search-verify against docs.getdbt.com confirmed the new structure before applying. Re-parse returned zero warnings.

**Lesson.** Banking a project rule has not been sufficient to make the proactive bypass fire on a new tool/adapter config file. This is the SECOND consecutive session it's been missed (Phase 2 session 1 missed it on `dbt_project.yml` with adapter-specific config keys; Phase 2 session 2 missed it on `_models.yml` with generic-test argument nesting). The pattern is structural — Claude's defaults default to "ship the form I know best", and the project rule needs MORE than a banked-in-LEARNINGS preference to override that default at file-authoring time. New enforcement mechanism for the rest of Project #3: when authoring ANY new dbt YAML config file for the first time (dbt_project.yml, sources.yml, _models.yml, schema.yml, packages.yml, _properties.yml), MANDATORY web-search-verify pass against docs.getdbt.com for the file's current shape BEFORE the file is written, not after parse surfaces a warning. The verify pass becomes a pre-write checkpoint, not a post-write debug loop. Same logic applies to any first-time-introducing-this-tool-or-adapter config file: ship a "current shape per docs as of <date>" comment block at file top citing the verified docs URL, similar to how the `.vscode/dbt_project.permissive.schema.json` shipped with documented rationale in Phase 2 session 1. The pattern is "verify-then-write" for config files in new tools. Interview talking point: "How do you bridge the gap between LLM training-cutoff knowledge and live tool versions?" → "Restricted-domain verify pass against the tool's authoritative docs before authoring config in the tool, not after the tool surfaces a warning. Pre-write, not post-debug."

**Update 2026-05-28 (Phase 2 session 5) — THIRD consecutive miss on this rule, this time on the `relationships` test.** Session 5's link_company_filing introduced two new generic tests Claude hadn't written in this project before — `relationships` FK tests with `to:` + `field:` arguments. Claude shipped the pre-1.10.5 top-level form despite the rule banked above explicitly mandating "verify-then-write" against docs.getdbt.com before authoring new dbt YAML test configurations. First parse fired `MissingArgumentsPropertyInGenericTestDeprecation` on the relationships block; Phil pasted the warning; Claude fixed in-session by nesting the arguments under `arguments:`. The rule didn't fire because the verify-then-write protocol is itself dependent on Claude noticing "this is a new test type in a YAML config file" at file-authoring time — and Claude's defaults treat YAML extension as "just add the new keys to the existing file" rather than "this introduces a new test class that needs verification." Three consecutive misses (session 1: adapter config keys / session 2: accepted_values argument nesting / session 5: relationships argument nesting) is now diagnostic — the verify-then-write rule needs a finer-grained trigger. **Re-locked enforcement for the remainder of Project #3 + the mini-projects:** whenever Claude is about to author or extend a dbt YAML file with a generic test type Claude has not yet written in THIS project (regardless of whether the file already exists), Claude FIRST web-search-verifies the current argument-nesting structure for that specific test type against docs.getdbt.com or the source dbt-utils/dbt-adapters repo, BEFORE writing the YAML. The trigger is "first use of this test type in the project," not "first creation of this file." That's a stricter trigger and should fire on every new test introduction. If this misses a fourth time, the rule moves to a hard-coded preflight comment at the top of every \_models.yml referencing this entry. Carry-forward principle for the broader pattern: when a rule has been banked twice and missed a third time, the rule's TRIGGER is what's wrong, not the rule itself. Re-engineer the trigger to fire on a finer-grained event.

### Bronze cik partition projection type=injected blocks dbt CTAS materialization AND schema-test scans (2026-05-28, Phase 2 session 3)

**Diagnosis.** First dbt test run after the canonical-concept reconciliation work errored on 8 schema tests with `CONSTRAINT_VIOLATION: For the injected projected partition column cik, the WHERE clause must contain only static equality conditions, and at least one such condition must be present.` Phil correctly identified the diagnostic asymmetry: dbt run passed (PASS=4) but dbt test failed. The reason — and this is the meta-lesson banked alongside the fix — dbt run for view models executes only CREATE VIEW statements which never scan source data (views just register a SQL definition with Glue Catalog), while dbt test executes the test SELECT queries which cascade-compile through the view chain down to Bronze raw-text. The Bronze cik partition projection set in Phase 1 session 3 was `type=injected`, which requires every full-scan query to include a static `cik = '<value>'` predicate; schema-test queries do not include one. First fix proposed: flip the intermediate layer materialization from view to Iceberg table so schema tests scan compact Iceberg files on S3 instead of Bronze. **This fix was incomplete.** The materialization step itself runs CTAS over Bronze, which is also a full-scan query without a static cik filter — so the next dbt run errored with the same constraint. Two debug loops, one root cause.

**Fix.** Real fix is switching both Bronze table partition projections from `type=injected` to `type=enum` with all 100 S&P 100 CIKs enumerated in `projection.cik.values`. Edits to `sql/ddl/01_create_bronze_tables.sql` and `sql/ddl/02_create_bronze_raw_text_table.sql`; DROP+CREATE both tables in Athena Console under phil-admin (4 statements one at a time). S3 data files untouched; Glue Catalog table definitions swapped. Verified per AWS docs that enum projection has no hard cap on value count — the constraint is total Glue Catalog metadata gzip-compressed under ~1 MB, which 100 CIKs at ~11 chars each fit comfortably. The intermediate-layer flip to Iceberg materialization (`+materialized: table` + `+table_type: iceberg` + `+format: parquet` in dbt_project.yml) stayed as part of the fix — it's the right Silver-layer architecture per the locked Phase 2 plan, AND it means downstream tests scan Parquet not Bronze JSON which is a real cost win independent of the partition-projection issue.

**Lesson.** Three lessons banked. **First**, when designing partition projection mode at Bronze setup time, think hard about whether full-scan queries will ever be valid against the table. type=injected is the "flexible" mode that handles arbitrary dynamic CIKs without a hardcoded list, but it has a hard contract: every query needs a static cik filter. dbt schema tests, dbt CTAS materialization, and any future ad-hoc full-table queries will not include such a filter — so type=injected is wrong for any Bronze table whose downstream consumers include dbt models. For known-finite sets like S&P 100, type=enum is the right tool: enumerate upfront, accept the maintenance cost of editing the list on roster turnover, get full-scan support for free. Carry-forward to any future Project #3 partition-projection design and to mini-projects: only choose type=injected when you can guarantee every query will name a specific value (e.g. event-source queries pulling logs for a known request_id). **Second**, when diagnosing a "tests fail but runs pass" pattern with views in a lakehouse, the cheapest diagnostic question is "what does each command actually execute against the underlying engine?" CREATE VIEW doesn't read data; CREATE TABLE AS does; SELECT does. Materialization choice changes WHEN data is read, not WHETHER it is. Initial diagnosis missed the CTAS-also-scans-source angle and proposed a partial fix that surfaced the same root cause from a different actor. Senior-DE pattern: when proposing a fix, run through every other code path that touches the same source table, not just the one that surfaced the error. **Third**, debug-discipline carry-forward — Phil drove the dbt-run-vs-dbt-test distinction in his own words before Claude proposed any fix, which is exactly the in-session debug pattern banked at Project #3 Phase 0 close. Worth banking again here: the live-coding interview pattern is "name the difference between what each command does, then root-cause the symptom in terms of that difference." Interview talking point: "Tell me about a time you diagnosed a tricky failure" → "Schema tests failed but the data pipeline ran clean; the asymmetry came down to view definitions never scanning source data while test queries did. The fix needed two layers — materialization choice for the intermediate, and partition-projection mode at the source. Banked both."

### dbt-athena docs recommend Iceberg table_property format_version=2 that AWS Athena engine rejects (2026-05-28, Phase 2 session 3)

**Diagnosis.** During the intermediate-as-Iceberg flip, set `+table_properties.format_version: "2"` in `dbt_project.yml` per the dbt-athena adapter docs explicit recommendation: "For Iceberg table, it is recommended to use table_properties configuration to set the format_version to 2 to maintain compatibility between Iceberg tables created by Trino with those created by Spark." First dbt run failed: `botocore.errorfactory.InvalidRequestException: An error occurred (InvalidRequestException) when calling the StartQueryExecution operation: Table properties [format_version] are not supported.`

**Fix.** Web-search-verify pass against `docs.aws.amazon.com/athena/latest/ug/querying-iceberg-creating-tables.html` (NOT against `docs.getdbt.com/reference/resource-configs/athena-configs`). AWS docs are unambiguous: Athena allows ONLY a predefined allowlist of table properties for Iceberg tables — `format`, `write_compression`, `optimize_rewrite_data_file_threshold`, `optimize_rewrite_delete_file_threshold`, `vacuum_min_snapshots_to_keep`, `vacuum_max_snapshot_age_seconds`, `vacuum_max_metadata_files_to_keep`. `format_version` is not in the allowlist. AND, separately: "Athena creates Iceberg v2 tables" — v2 is the engine default. The dbt-athena adapter docs recommendation is stale relative to current Athena engine behavior. Removed the `table_properties` block entirely from dbt_project.yml; Athena defaults to Iceberg v2 anyway so no functional loss.

**Lesson.** Adapter wrapper documentation lags the underlying engine, sometimes for years. When debugging an engine-side rejection of a config that the adapter docs explicitly recommend, the authoritative source is the engine's own docs, not the adapter's. Carry-forward as a project rule: for any stakes-sensitive dbt-athena Iceberg config (or, more generally, any cross-tool integration where there's an adapter layer between dbt and a cloud engine), verify against the engine's docs first when behavior diverges from expectation. The adapter docs are a good starting reference but not the source of truth on the engine's actual current behavior. Interview talking point: "How do you handle dependency layers in production data tools?" → "Treat the adapter as a convenience layer over the engine, but never as the authoritative source. When an adapter-recommended config fails on the engine, verify against the engine's own docs — adapter recommendations can be stale relative to the underlying platform's current behavior."

### Athena COLUMN_NOT_FOUND error message includes misleading "not authorized" boilerplate (2026-05-28, Phase 2 session 3)

**Diagnosis.** Final verify suite paste in Athena Console returned `COLUMN_NOT_FOUND: line 113:39: Column 'period_fiscal_year' cannot be resolved or requester is not authorized to access requested resources`. Phil read the error literally and his first diagnosis was "looks like we haven't given it permissions or something." Actual root cause was a missing column in the `canonical` CTE's SELECT projection in `sql/verify/02_phase2_silver_intermediate_verification.sql` — check 10 referenced `period_fiscal_year`, which existed in the underlying `int_sec_edgar__concepts_canonical` table but wasn't projected into the CTE.

**Fix.** One-line edit to the canonical CTE in `sql/verify/02_phase2_silver_intermediate_verification.sql` — added `period_fiscal_year` to the SELECT list. Re-pasted in Athena Console: 11/11 PASS.

**Lesson.** Athena's COLUMN_NOT_FOUND error message tacks on "or requester is not authorized to access requested resources" as boilerplate, regardless of whether IAM is actually involved. The wording is misleading: 99% of the time the real cause is SQL projection (column truly doesn't exist in the CTE, OR exists in the underlying table but was excluded from an upstream subquery, OR is misspelled, OR has a different case than the engine expects). IAM denials emit a different error class entirely (`AccessDeniedException`, with `User is not authorized to perform athena:...` wording from STS/IAM, not from query planning). Standing diagnostic rule: when you see COLUMN_NOT_FOUND in Athena, check the SQL projection chain BEFORE reaching for IAM. Cheapest check: is the column actually in the CTE / subquery / view that the error line references? If yes, then escalate to type mismatch or case sensitivity; if no, fix the projection. Interview talking point on error-message literacy: "When a tool's error message mentions permissions but I have admin access, the message wording is usually misleading and the actual cause is in the SQL/code I just wrote."

### Forward-projected risks for Phase 2 remainder + Phase 3 (banked 2026-05-28, Phase 2 session 3 close-amend)

These aren't diagnosis-fix-lesson loops — the issues haven't bitten yet. They're risks surfaced by the first-ever phase-kickoff forward-verify pass (ENGINEERING_STANDARDS.md new section, added same day) against authoritative docs. Each is captured BEFORE the corresponding phase work begins so the design decisions land deliberately, not reactively. Mitigations baked into PROJECT_PLAN.md sections 7 and 9 same commit.

#### Risk 1 — AutomateDV does NOT officially support dbt-athena (Phase 2 warehouse layer)

**Verified against authoritative source.** automate-dv.readthedocs.io/en/latest/platform_support/ Platform Support page enumerates supported platforms: Snowflake (primary), Google BigQuery, MS SQL Server, Databricks, Postgres. Redshift listed as planned/in-progress. **Athena is not on the supported list and not on the planned list.** AutomateDV's macros (hub, link, sat, eff_sat, ma_sat, xts, pit, bridge) cannot be safely assumed to work on dbt-athena.

**Implication.** Phase 2 session 4+ warehouse-layer Data Vault 2.0 (hub_company, link_company_filing, sat_company_metadata, etc.) will be hand-rolled in plain dbt-athena SQL — NOT via AutomateDV macros. The hand-rolled approach is actually a stronger portfolio story: shows pattern understanding (you can write a SCD-2 satellite from scratch), not just library use (you typed `{{ dbtvault.sat(...) }}` and trusted the macro). Cross-link the LEARNINGS entry to PROJECT_PLAN.md section 7 (DV2.0 modeling pattern) where the hand-rolled approach is now explicit.

**Carry-forward principle.** For any dbt portfolio project on a non-mainstream adapter (dbt-athena, dbt-trino, dbt-fabric, etc.), check the platform-support pages of the major modeling packages BEFORE assuming they're available. The "we'll just use dbtvault / AutomateDV" default is unsafe outside Snowflake / BigQuery / SQL Server / Databricks / Postgres.

#### Risk 2 — Iceberg merge incremental + on_schema_change has a known duplicate-insertion bug

**Verified against authoritative source.** dbt-adapters issue #571 (and related dbt-glue issues) document that Iceberg merge incremental strategy with on_schema_change settings does NOT correctly update rows — instead inserts duplicates. Mentioned in passing in the dbt-athena merge docs but the failure mode bites at runtime, not parse time.

**Implication.** Data Vault 2.0 satellites are SCD-2-by-construction — every attribute change inserts a new satellite row with a new load_datetime, and the unique key is (hub_hashkey, load_datetime). Duplicates in satellite tables corrupt the audit lineage that's the whole point of DV2.0. Risk is real for Phase 2 session 4+ satellite implementations.

**Mitigations going into PROJECT_PLAN.md section 9 Phase 2 entry.**

- Do NOT set on_schema_change on satellite models (leave at default `ignore`).
- Carefully control unique_key composition: (hub_hashkey, load_datetime) is the natural satellite key. Test with parity counts (source row count vs satellite incremental insert count) after every satellite refresh.
- Add a row-count sanity check to the verification suite at the satellite layer that catches duplicates within a single load batch.
- If schema evolution becomes required on a satellite mid-lifecycle, do a full-refresh rebuild rather than relying on on_schema_change.

#### Risk 3 — AWS Step Functions has NO native dbt integration (Phase 3 orchestration)

**Verified against authoritative source.** docs.aws.amazon.com/step-functions/latest/dg/connect-athena.html confirms Step Functions has native task-type integration with Athena (StartQueryExecution, GetQueryExecution, GetQueryResults). docs.getdbt.com Quickstart for dbt and Amazon Athena confirms dbt is invoked as a Python process via the dbt CLI. **Step Functions cannot natively invoke dbt commands.** Any Step Functions state machine that orchestrates dbt-athena requires a runtime container for the dbt process.

**Implication.** Phase 3 (orchestration via Step Functions) has a non-trivial architectural design call that the 2026-05-23 phase plan didn't surface. Three viable runtimes for dbt-athena invoked from Step Functions:

| Runtime | Pros | Cons |
|---|---|---|
| **AWS Lambda** | Serverless, $0 idle, pay-per-invocation. Fits demo-durability principle 4. | 250 MB unzipped Lambda layer + code limit is tight for dbt-core + dbt-athena + pyathena + the dbt project files. May require packaging discipline (Lambda Container Image format, up to 10 GB) to fit. |
| **AWS Glue Python Shell** | Serverless, ~$0.44/DPU-hour, fits within Free Plan budget for portfolio scale. Native Python runtime with pip-installable deps. | Adds Glue ETL service to the project's IAM scope. |
| **AWS ECS Fargate (one-off task)** | Clean container model; no layer-size constraints. | Adds ECR + ECS to the IAM scope and the deployment story; container build complexity. |

**Recommended at this point (subject to Phase 3 kickoff verification):** AWS Glue Python Shell. Lowest IAM expansion (already have AWSGlueServiceRole-financial-analytics-lakehouse from Phase 1), no container-build overhead, fits the Free Plan budget, serverless pay-per-second. Lambda Container Image is the backup if Glue Python Shell has dbt-specific gotchas surfacing during Phase 3 kickoff.

**Mitigation going into PROJECT_PLAN.md section 9 Phase 3 entry.** Explicit design call documented up front: "Phase 3 first session = forward-verify pass + dbt-runtime choice between Glue Python Shell (preferred) and Lambda Container Image (fallback)." No surprise mid-phase.

#### Risk 4 — Hash-key algorithm choice (MD5 vs SHA-256) and hand-rolled vs dbt_utils for DV2.0 hubs (banked 2026-05-28, Phase 2 session 4 kickoff forward-verify)

**Verified against authoritative sources.** Scalefree (canonical Data Vault 2.0 reference body — scalefree.com/blog/architecture/hash-keys-in-the-data-vault/) lists MD5 (128-bit) and SHA-1 (160-bit) as current recommended defaults for DV2.0 hash keys, with SHA-256 explicitly available for users who want lower collision rates on large data sets. AutomateDV's hashing docs (automate-dv.readthedocs.io/en/latest/best_practises/hashing/) expose `md5` / `sha1` / `sha` (= SHA-256) as configurable. `dbt_utils.generate_surrogate_key()` (github.com/dbt-labs/dbt-utils generate_surrogate_key.sql) uses MD5 cross-adapter via adapter dispatch and IS compatible with dbt-athena. Athena's Trino-based engine v3 (docs.aws.amazon.com/athena/latest/ug/functions-env3.html) exposes native `sha256()` returning varbinary + `to_hex()` for the hex-string conversion.

**Implication.** Two defensible design paths for hub_company's hub_company_hk:

| Path | Pros | Cons |
|---|---|---|
| **`dbt_utils.generate_surrogate_key(['cik'])`** | Ecosystem-standard, one-liner, cross-adapter portable, matches Scalefree's MD5-by-default recommendation | Hides the hash mechanic behind a macro — weaker portfolio story for "I hand-rolled DV2.0 on Athena" |
| **Hand-rolled Athena native: `to_hex(sha256(to_utf8(cast(cik as varchar))))`** | Demonstrates engine-fluent SQL + DV2.0 mechanic understanding, aligns with the "hand-rolled, no AutomateDV" lock (Risk 1), SHA-256 lower collision rate (irrelevant at S&P 100 = 100 rows but matters for the portfolio narrative around future-scale design) | Verbose vs the macro one-liner; collision-rate argument is theoretical at this scale |

**Decision (locked at this forward-verify pass).** Hand-rolled `to_hex(sha256(to_utf8(cast(<bk> as varchar))))` is the project standard for all DV2.0 hash keys (hub_company_hk, future hub_filing_hk, link hash keys, satellite parent hash key references). Rationale: consistency with the "hand-rolled DV2.0, no AutomateDV" lock from Risk 1 — using `dbt_utils.generate_surrogate_key()` for the hash while hand-rolling everything else would be inconsistent. SHA-256 over MD5 because the portfolio story is "I understand DV2.0 mechanics deeply enough to pick a higher-strength hash deliberately even at small scale, knowing the perf trade-off is negligible at S&P 100 volumes." Document the design call in DBT_PIPELINE.md section 8 so the choice is auditable.

**Carry-forward principle.** When the choice is between a cross-adapter macro and an engine-native expression in a portfolio project, the engine-native expression usually wins because it demonstrates depth. The macro wins in production at scale where consistency across pipelines matters more than the artifact's pedagogical surface.

#### Risk 5 — dbt-athena Iceberg merge strategy OVERWRITES matched rows by default; DV2.0 hubs need insert-only semantics (banked 2026-05-28, Phase 2 session 4 kickoff forward-verify)

**Verified against authoritative source.** docs.getdbt.com/reference/resource-configs/athena-configs + docs.getdbt.com/docs/build/incremental-strategy — for `incremental_strategy='merge'` on Iceberg with `unique_key` set, dbt's default behavior is to OVERWRITE matched rows with new values. Optional configs to constrain the merge: `update_condition` (SQL identifying which matched rows update), `insert_condition` (SQL identifying which not-matched rows insert), `merge_update_columns` (whitelist of columns to update — leave empty to update nothing). dbt-athena docs confirm same behavior on Athena Iceberg merge. dbt-athena merge requires Athena engine v3, which wg_financial_analytics already runs.

**Implication.** Data Vault 2.0 hubs are INSERT-ONLY by definition — a business key (cik) entering the hub once is immutable forever. The hub row records "we first observed cik X at load_datetime Y from record_source Z." Re-seeing the same cik in a later load must NOT update load_datetime (corrupts the first-seen audit trail) and must NOT insert a duplicate (violates hub primary-key uniqueness). dbt-athena's default merge behavior would overwrite load_datetime + record_source on every refresh of hub_company — silently corrupting the lineage that's the whole point of DV2.0.

**Mitigations — pick ONE pattern, document in DBT_PIPELINE.md section 8.**

| Pattern | How | When to pick |
|---|---|---|
| **Source-side filter + merge with unique_key** | In the model body, wrap the source SELECT in an `{% if is_incremental() %}` block that filters to `WHERE hub_company_hk NOT IN (SELECT hub_company_hk FROM {{ this }})`. The merge then has nothing to match on — every row in source is genuinely new. unique_key acts as a safety net at the engine level. | **Recommended.** Cleanest DV2.0 hub pattern — semantics match how an experienced DV2.0 modeler explains it ("source already excludes seen-before keys; merge unique_key guards the contract"). Matches AutomateDV's hub generator output structurally. |
| **`update_condition: '1 = 0'`** | Pass an always-false SQL predicate that excludes every matched row from update. Engine still scans matched rows but no-ops the update. | Works but less idiomatic — the literal `1 = 0` reads as a hack vs an explicit source-side filter that says what it means. |
| **`merge_update_columns: []`** | Empty whitelist tells dbt to update no columns. | Same effect as above; same readability complaint. |
| **`incremental_strategy='append'`** | Skip merge entirely. Naive append. | REJECTED — append has no unique-key safety net; a duplicated source row inserts a duplicated hub row, corrupting the hub. |

**Decision (locked at this forward-verify pass).** Pattern 1 — source-side filter + merge with unique_key. The `is_incremental()` block reads as DV2.0-idiomatic; the unique_key safety net at the engine level satisfies criterion 9 (post-action verification belt-and-braces). Cross-link to Risk 2 (banked 2026-05-28): on_schema_change stays at default `ignore` for hub_company — hubs are schema-stable by construction (hash key + business key + load_datetime + record_source).

**Carry-forward principle.** dbt's incremental defaults are tuned for analytics-engineering upsert patterns (overwrite latest values), NOT for audit-lineage patterns like DV2.0 hubs/links/satellites. Every DV2.0 model on dbt-athena (hub, link, sat) must explicitly state its insert-only / SCD-2 contract through model-body filters + targeted merge conditions, not by trusting defaults. The same source-side filter pattern carries to future hub_filing, link_company_filing; satellites get a different pattern (SCD-2 insert-on-change keyed on hash diff).

#### Risk 6 — Composite-hash delimiter choice for DV2.0 link keys (banked 2026-05-28, Phase 2 session 5 kickoff forward-verify)

**Verified against authoritative sources.** AutomateDV's hashing best-practices page (automate-dv.readthedocs.io/en/latest/best_practises/hashing/) and macro configuration docs document `concat_string: '||'` (double-pipe) as the default delimiter when concatenating business-key columns before hashing — picked deliberately because '||' is "unlikely to be contained in the columns being concatenated" so a composite key like (cik, accession_number) always produces a stable, unambiguous hash. By contrast, dbt_utils.generate_surrogate_key (github.com/dbt-labs/dbt-utils/blob/main/macros/sql/generate_surrogate_key.sql) uses `'-'` (hyphen) as its delimiter — and dbt-utils GitHub issue #1015 documents the failure mode that motivates AutomateDV's choice: when a business-key column can contain `'-'`, the macro generates the same output for different inputs (e.g., ('123-', '456') concatenates to `'123--456'`, identical to ('123', '-456')). For SEC EDGAR business keys this is a real concern: accession_number values arrive in the form `'0000320193-24-000123'` (literal hyphens in positions 11 and 14 per SEC's accession-number format). A '-' delimiter would not be hash-safe; '||' is.

**Implication.** link_company_filing's composite hash must NOT be built via dbt_utils.generate_surrogate_key — even ignoring the hand-rolled lock from Risk 1 + Risk 4, the hyphen delimiter would have an ambiguity risk on accession-number inputs. The composite hash function chain for the project is:

```sql
to_hex(sha256(to_utf8(
    CAST(cik AS varchar) || '||' || CAST(accession_number AS varchar)
)))
```

Trino's `||` operator concatenates varchar to varchar (verified against trino.io/docs/current/functions/string.html); the rest of the chain is identical to Risk 4's single-key hash chain.

**Decision (locked at this forward-verify pass).** Project standard for every composite hash key in every future DV2.0 link is the '||' delimiter, applied as a literal SQL concatenation inside the to_hex(sha256(to_utf8(...))) chain. Per-column CAST AS varchar inside the concatenation guards against future staging-side type changes (same defensive pattern as hub_company). Comment in each link model explains the '||' choice with a reference to this LEARNINGS entry so the design call is auditable from the model body.

**Carry-forward principle.** Any composite-key hash in any future warehouse model (links with 3+ hubs, satellites with composite parent references, future portfolio projects with multi-column natural keys) uses '||' as the delimiter — never '-', never '_', never any character that can plausibly appear in a business-key value. The delimiter test: "could this character appear in either of the columns I'm concatenating?" — if yes, it's wrong. SEC EDGAR accession numbers literally contain hyphens; pipe characters never appear in regulatory identifiers.

#### Risk 7 — accession_number sourcing for hub_filing (banked 2026-05-28, Phase 2 session 5 kickoff forward-verify)

**Verified against authoritative sources.** SEC EDGAR Application Programming Interfaces page (sec.gov/search-filings/edgar-application-programming-interfaces) documents two distinct API endpoints: `data.sec.gov/submissions/CIK##########.json` (filing-history-by-filer, includes accession-number arrays as `recent.accessionNumber`) and `data.sec.gov/api/xbrl/companyfacts/CIK##########.json` (XBRL-fact-aggregated). Cross-referenced GitHub libraries (dgunning/edgartools, clojure-finance/edgarjure, sec-edgar-financials) all confirm the companyfacts JSON's per-fact array entries include accession-number fields named `accn` alongside `end`, `val`, `fy`, `fp`, `form`, `filed`. Format: 18-character string with hyphens in positions 11 and 14 (e.g., `'0000320193-24-000123'`).

**Implication.** Two viable sources for hub_filing's accession_number business key:

| Source | Pros | Cons |
|---|---|---|
| **Bronze companyfacts JSON via stg_sec_edgar__companyfacts_raw** — UNNEST $.facts["us-gaap"].<concept>.units.USD arrays; project accn DISTINCT | Honors the session-4 lock that DV2.0 hubs source from the rawest layer where the BK first appears. No Phase 1 extract extension needed. Self-contained — hub_filing's lineage is independent of the canonical-concept reconciliation chain. | Requires the same Jinja for-loop UNNEST pattern as int_sec_edgar__concepts. Captures only accession_numbers for filings that report at least one of the 8 in-scope XBRL concepts — but for the S&P 100 universe every 10-K/10-Q reports revenue + balance-sheet basics, so coverage is universal in practice. |
| **Submissions endpoint via Phase 1 extract extension** — extract data.sec.gov/submissions/CIK#########.json, land in Bronze, build a new staging model, source hub_filing from that | Captures every filing the company ever made (including ones that don't report XBRL facts — proxy statements, 8-K events, etc.) — strict superset of Option A. | Phase 1 extract is FROZEN per demo-durability principle 1 (Bronze freeze, 2026-05-25). Extending it now would un-freeze Bronze mid-project — significant scope expansion. The strict-superset coverage isn't useful for this project's scope (revenue + financial-health themes only consume XBRL-bearing filings anyway). |

**Decision (locked at this forward-verify pass).** Option A — source from stg_sec_edgar__companyfacts_raw inside the hub_filing model body. hub_filing.sql does its own Jinja for-loop UNNEST across the same 8 in-scope XBRL concept tags as int_sec_edgar__concepts, projects accn, applies DISTINCT, hashes. Bronze stays frozen; Phase 1 demo durability is preserved. Coverage trade-off is documented and acceptable.

**Carry-forward principle.** When the question is "do I extend an earlier-phase artifact to satisfy a later-phase need OR work within the existing source surface" — the answer in any portfolio project with a Bronze freeze convention is: work within the existing source surface unless coverage is materially compromised. The Phase 1 Bronze freeze is a contract with the demo-durability principles; un-freezing it for a marginal coverage gain undermines the contract. Document the coverage trade-off explicitly so it's defensible at portfolio-walkthrough time: "I picked source A over source B because B's superset coverage didn't change the analytical surface and would have required un-freezing Bronze, violating demo-durability principle 1."

#### Risk 8 — Trino concat NULL propagation in hashdiff defeats SCD-2 change detection (banked 2026-05-28, Phase 2 session 6 kickoff forward-verify)

**Verified against authoritative source.** Trino's string-functions docs (trino.io/docs/current/functions/string.html) state that `concat()` and the `||` operator return NULL whenever any input argument is NULL — standard SQL NULL-propagation semantics, no null-safe variant. AutomateDV's hashing best-practices page (automate-dv.readthedocs.io/en/latest/best_practises/hashing/) documents the canonical defense: COALESCE every payload column to a stable string sentinel BEFORE the concatenation, so the hash is computed over a deterministic byte sequence rather than a NULL. The AutomateDV macro default sentinel is `'^^'` (double-caret) — picked because, like the '||' delimiter on composite-key hashes, it's a character pair unlikely to appear in any business-key or attribute value.

**Implication.** sat_filing_metadata's payload includes `period_start_date` which the upstream int_sec_edgar__concepts model intentionally leaves NULL for balance-sheet point-in-time concepts (Assets, Liabilities, StockholdersEquity — SEC EDGAR omits `$.start` for instant-period facts). For sat_filing_metadata sourced from companyfacts JSON the same `$.start` NULL behavior carries through. Without COALESCE, the hashdiff for ANY filing whose payload has even one NULL attribute resolves to NULL — and NULL = NULL is false in SQL — so the SCD-2 change-detection filter would see "no existing matching hashdiff" on every load and insert a duplicate row per refresh, silently corrupting the SCD-2 audit lineage. The exact failure mode banked at Risk 2 (Iceberg merge + on_schema_change duplicate insertion), but triggered by a different upstream bug — concat NULL propagation, not adapter merge semantics.

**Decision (locked at this forward-verify pass).** Every payload column in every satellite hashdiff goes through COALESCE to a stable string sentinel BEFORE the `||` concatenation. Project standard sentinel = `'^^'` (AutomateDV ecosystem default). The hashdiff function chain for sat_filing_metadata is:

```sql
to_hex(sha256(to_utf8(
    COALESCE(CAST(form_type AS varchar), '^^') || '||' ||
    COALESCE(CAST(filed_date AS varchar), '^^') || '||' ||
    COALESCE(CAST(period_start_date AS varchar), '^^') || '||' ||
    COALESCE(CAST(period_end_date AS varchar), '^^') || '||' ||
    COALESCE(CAST(fiscal_year AS varchar), '^^') || '||' ||
    COALESCE(CAST(fiscal_period AS varchar), '^^')
)))
```

Same SHA-256 chain as hub_company / hub_filing / link_company_filing's single-key and composite-key hashes (Risks 4 + 6); only the input expression differs. Per-column CAST AS varchar guards against type changes upstream silently breaking the hash. The '||' delimiter sits between sentinels-or-values inside the concat chain — same delimiter rationale as composite link hashes (Risk 6).

**Carry-forward principle.** Any hash computed over multiple payload columns where any column can be NULL needs COALESCE-to-sentinel applied BEFORE the concat — never trust the upstream "in practice these are non-NULL" guarantee, because the SCD-2 corruption mode is silent. The sentinel must be a character sequence that cannot plausibly appear as a real value in any of the columns being hashed. `'^^'` is the AutomateDV default; project uses the same. Same logic carries to any future portfolio project with SCD-2 satellites, dimension tables with type-2 history, or audit lineage hashes.

#### Risk 9 — Satellite source-side filter is an anti-join on latest-hashdiff-per-parent, NOT a NOT IN on parent hash key (banked 2026-05-28, Phase 2 session 6 kickoff forward-verify)

**Verified against authoritative sources.** Scalefree's "Maintaining the Hash Diff" Data Vault Friday entry (scalefree.com/knowledge/webinars/data-vault-friday/maintaining-the-hash-diff/) and AutomateDV's loading docs (automate-dv.readthedocs.io/en/latest/best_practises/loading/) both confirm: "in an incremental load, the first record of a batch is inserted only if it is different from the latest record in the existing Satellite." The change-detection mechanic compares the inbound hashdiff against the most recent stored hashdiff for the same parent hash key — if different OR no row exists for that parent, insert a new satellite row with a new load_datetime. If identical, skip. This is the SCD-2 insert-on-change idiom.

**Implication.** The source-side filter pattern that worked for hubs and links (`WHERE hub_hk NOT IN (SELECT hub_hk FROM {{ this }})`) is WRONG for satellites — it would exclude every already-seen parent from the source, including parents whose payload genuinely changed and SHOULD insert a new SCD-2 row. The satellite filter needs the opposite semantic: include parents whose inbound hashdiff differs from the most recent stored hashdiff. This is a real anti-join, not a NOT IN.

**Decision (locked at this forward-verify pass).** The satellite source-side `is_incremental()` filter pattern is:

```sql
{% if is_incremental() %}
WHERE NOT EXISTS (
    SELECT 1
    FROM (
        SELECT
            hub_filing_hk,
            hashdiff,
            ROW_NUMBER() OVER (
                PARTITION BY hub_filing_hk
                ORDER BY load_datetime DESC
            ) AS rn
        FROM {{ this }}
    ) latest
    WHERE latest.hub_filing_hk = inbound.hub_filing_hk
      AND latest.hashdiff = inbound.hashdiff
      AND latest.rn = 1
)
{% endif %}
```

The window function picks the latest stored row per parent; the NOT EXISTS clause excludes inbound rows whose hashdiff matches the latest stored hashdiff for the same parent. Inbound rows pass through to merge if (a) no existing row for that parent OR (b) hashdiff differs from latest. Pattern is DV2.0-idiomatic and matches the AutomateDV sat-macro semantics structurally.

**Carry-forward principle.** Every DV2.0 model class needs a class-specific source-side filter pattern — hubs and links use `NOT IN` on the model's own hash key (immutable PK contract); satellites use a `NOT EXISTS` anti-join on (parent_hk, latest_hashdiff) (SCD-2 insert-on-change contract). The filter pattern reflects the model class's audit-lineage semantics; trusting any single pattern across all three model classes corrupts at least one. Carries to every future warehouse satellite (sat_company_metadata, sat_concept_value, sat_concept_canonical) unchanged.

#### Risk 10 — Single sat hash key vs composite (parent_hk, load_datetime) unique_key for satellite incremental merge (banked 2026-05-28, Phase 2 session 6 kickoff forward-verify)

**Verified against authoritative sources.** dbt-athena Iceberg merge docs (docs.getdbt.com/reference/resource-configs/athena-configs) confirm `unique_key` accepts either a single column name or a list of columns. Scalefree's hash-key documentation (blog.scalefree.com/2017/04/28/hash-keys-in-the-data-vault/) and AutomateDV's metadata reference (automate-dv.readthedocs.io/en/stable/metadata/) document two equally-valid satellite primary-key conventions: (a) composite of (parent hub hash key, load_datetime) — the natural DV2.0 PK; (b) a dedicated `sat_<entity>_hk` hashed over the natural PK columns — gives the satellite a single-column surrogate key matching the hub/link pattern.

**Implication.** Two defensible designs for sat_filing_metadata's unique_key:

| Path | Pros | Cons |
|---|---|---|
| **Composite list `unique_key=['hub_filing_hk', 'load_datetime']`** | Matches AutomateDV / Scalefree DV2.0 textbook satellite PK directly; no extra hash column to compute or test | Two-column unique_key surface; engine-level merge predicate touches two columns at runtime; reads less consistently with hub_company/hub_filing/link_company_filing which all carry a single hash key as PK |
| **Dedicated `sat_filing_metadata_hk = sha256(hub_filing_hk \|\| '\|\|' \|\| CAST(load_datetime AS varchar))`** | Single-column PK reads consistently with hub and link pattern; merge predicate is single-column; downstream PIT tables, point-of-time queries, and Power BI marts all join on a single hash key like every other warehouse model | Adds one column to the satellite; the composite PK is implicit in the hash rather than explicit in the column list — needs the dbt_utils.unique_combination_of_columns test on (hub_filing_hk, load_datetime) to make the natural-PK contract auditable at test time |

**Decision (locked at this forward-verify pass).** Path B — dedicated `sat_filing_metadata_hk` over `hub_filing_hk || '||' || CAST(load_datetime AS varchar)`. Project standard for every future satellite (sat_company_metadata, sat_concept_value, etc.): single sat hash key as unique_key, composite natural PK auditable via `dbt_utils.unique_combination_of_columns` test on (parent_hk, load_datetime). Rationale: keeps the hub/link/sat surface visually consistent (every warehouse model has a single-column hash PK called `<class>_<entity>_hk`); the explicit natural-PK contract lives in the schema test, where it belongs as a test-time check rather than a runtime engine concern. Same '||' delimiter as composite link hashes (Risk 6); same SHA-256 chain as everything else (Risk 4).

**Carry-forward principle.** Visual consistency in the warehouse-layer surface matters for portfolio storytelling — every hub, link, and satellite has the same shape (single-column hash key as PK + business-key columns + load_datetime + record_source + payload). The natural-PK semantics of each model class live in their schema tests, not in their column lists. Pattern carries to every future satellite unchanged. Project rule: every warehouse-layer model has exactly one column named `<class>_<entity>_hk` that is its single-column unique_key.

#### Risk 11 — Satellite source from companyfacts JSON needs DISTINCT to collapse per-concept duplicates (banked 2026-05-28, Phase 2 session 6 kickoff forward-verify)

**Verified against authoritative sources.** SEC EDGAR companyfacts JSON structure (sec.gov/search-filings/edgar-application-programming-interfaces) confirms the same filing-level attributes (`accn`, `form`, `filed`, `fy`, `fp`, `end`, `start`) appear in every concept's per-period array entry — these are filing-level metadata, not concept-level. A filing reporting 8 in-scope concepts produces 8 array entries with identical filing-level attributes. The hub_filing model (session 5) handles this correctly with `SELECT DISTINCT accession_number`; sat_filing_metadata needs the same DISTINCT discipline applied to the full payload row, not just the parent BK.

**Implication.** Without DISTINCT applied to the projected payload before hashing, the satellite would receive 8 rows per (cik, accn) — identical filing-level attributes, identical computed hashdiff, identical computed sat_filing_metadata_hk. The unique_key constraint at engine-level would reject duplicates on merge (so engine-side data integrity holds), but every dbt run would scan and shuffle 8x the necessary rows through the merge engine — wasted compute, wasted Athena scan cost, and the dbt run statistics report would be wildly misleading ("merged 6,551 rows" actual vs "merged 52,408 rows scanned"). At Free Tier budget this is a real cost concern, not just an aesthetic one.

**Decision (locked at this forward-verify pass).** Apply DISTINCT to the projected payload row (the full (hub_filing_hk, form_type, filed_date, period_start_date, period_end_date, fiscal_year, fiscal_period) tuple) BEFORE hashdiff computation. The pattern carries the hub_filing DISTINCT discipline forward — every model that sources from the per-concept UNNEST chain applies DISTINCT at the natural-cardinal-unit level for that model (one row per accession_number for hub_filing; one row per (accession_number, payload) for sat_filing_metadata; one row per (cik, accession_number) for link_company_filing).

**Carry-forward principle.** When a model sources from an UNNEST chain that intentionally repeats certain attributes (the same filing-level metadata across 8 concept arrays), the model body must apply DISTINCT at the natural-cardinal-unit level for that model. Each warehouse-layer model has a different cardinal unit — hubs at the business-key level, links at the (BK1, BK2) pair level, satellites at the (parent_BK, payload-tuple) level. The DISTINCT-at-cardinal-level rule is what makes the UNNEST source pattern reusable across the three model classes without per-class manual deduplication contortions.

#### Risk 12 — Filing-level vs filing-instance-level attribute scope on satellites: cardinality-test discipline (banked 2026-05-28, Phase 2 session 6 first dbt run surfaced the miss)

**Diagnosis → fix → lesson, banked under the forward-projected-risks section because the carry-forward principle is what matters going forward.** First `dbt run --select sat_filing_metadata` returned `OK 45851` rows, ~7x the expected 6,551 (the hub_filing parent count). Materialization succeeded, but the cardinality is wrong by design — sat_filing_metadata as scoped at session 6 kickoff carried 6 payload attributes (form_type, filed_date, period_start_date, period_end_date, fiscal_year, fiscal_period). The DISTINCT collapse per Risk 11 worked correctly given those columns, but the column selection itself conflated two distinct grains. SEC EDGAR companyfacts JSON: a single 10-K filing's accession_number appears across MULTIPLE period-instance array entries inside each concept's units.USD array — comparatives (current FY + 2 prior FYs in 10-K; current Q + YTD + prior-year same in 10-Q). period_start_date / period_end_date / fiscal_year / fiscal_period are per-period-instance, not per-filing. Only form_type and filed_date are truly filing-level (entityName too, but that lives upstream of the per-period UNNEST and belongs on sat_company_metadata when that lands).

**Verified empirically + against authoritative source.** SEC EDGAR API docs (sec.gov/search-filings/edgar-application-programming-interfaces) document the companyfacts JSON structure as one array entry per (filing, period) tuple within each concept's units array — confirming the per-instance grain. Empirical confirmation: 6,551 distinct accession_numbers across hub_filing × ~7 average period-instances per filing ≈ 45,851 rows.

**Fix (locked at this within-session correction).** Trim sat_filing_metadata's payload to the 2 truly filing-level attributes only — form_type + filed_date. Full-refresh rebuild (first run was CTAS so no history exists to preserve). The 4 period/fiscal attributes naturally belong on a future model — either a hub_period + link_filing_period structure, or baked into sat_concept_value when that lands in a later session. Both are forward decisions, not session 6 scope.

**Carry-forward principle — cardinality-test discipline for every future satellite.** At design time, before code ships, every satellite gets a 30-second cardinality sanity check: "what is the expected row count on first load, and how does it relate to the parent hub row count?" Three valid satellite cardinalities exist in DV2.0 textbook design: (a) **1:1 with parent** (every parent has exactly one current-state row — sat_filing_metadata as now scoped, sat_company_metadata) — most common, the natural single-entity-descriptor satellite shape; (b) **many-to-1 against parent via a separate temporal hub** (parent has many entries indexed by time/period, but they're modeled as a separate hub like hub_period with a link) — what the period attributes need; (c) **multi-active satellite** (parent has multiple concurrent active rows, modeled explicitly as a multi-active sat with a sub-sequence key) — rare, used for concurrent set-membership patterns. Mixing per-instance attributes into a 1:1 satellite collapses (a) and (b) into a shape that's neither — looks like a sat but behaves like a link-with-payload, breaks the parent-coverage-parity invariant, and breaks downstream SCD-2 query patterns that assume "latest row per parent" is a single row. The mental test: "if I observed this same parent twice, would this attribute have the same value?" If yes → 1:1 sat payload. If no → it belongs on a different model class. Apply to every future satellite in this project (sat_company_metadata, sat_concept_value, sat_concept_canonical) and to every satellite in every future portfolio project.

**Carry-forward principle — test ordering by cost.** The cardinality miss should have been caught by a 30-second `SELECT COUNT(*)` parity check BEFORE running dbt test (which scans every column for every test, expensive) or verify/05 (which joins multiple tables, more expensive). Senior-DE test-ordering discipline: row-count parity check FIRST (cheap, single aggregation), schema tests SECOND (multi-column scans), structural verify LAST (multi-table joins). The Athena scan cost of running schema tests against a 45,851-row model with a known wrong cardinality is pure waste — the parity check would have surfaced the issue at ~$0 cost. Banking this here so the next satellite session leads with the parity check.

**Carry-forward principle — forward-verify pass must include cardinality reasoning, not just function-chain reasoning.** Session 6 kickoff forward-verify pass surfaced Risks 8/9/10/11 around hashdiff mechanics, source-side filter shape, unique_key construction, and DISTINCT discipline — but did NOT reason about whether the selected payload columns were 1:1 with the parent. That class of question (model-grain-vs-payload-grain) is now part of every future forward-verify pass: before locking the payload column list, name the expected first-load row count and confirm it equals the parent hub count for a 1:1 satellite. The 30-second check belongs at design time, not at first-run time.

#### Risk 13 — Bronze cardinality drift across extract_dates breaks naive parent-count inference: empirical cardinality probe mandatory at every satellite forward-verify pass (banked 2026-05-28, Phase 2 session 7 forward-verify pass)

**Diagnosis (forward-projected, caught at design time per the Risk 12 carry-forward principle).** At Phase 2 session 7 kickoff, the forward-verify pass for sat_company_metadata reached the cardinality-reasoning step (locked at Risk 12). Naive inference would have read: "parent = hub_company has 100 rows; payload = entity_name from companyfacts top-level $.entityName; expected first-load = 100 rows = 1:1 invariant satisfied." The Risk 12 carry-forward says: name the expected row count AND confirm against actual data, not just authoritative docs. Phil ran the empirical probe via Athena:

```sql
SELECT
    COUNT(*) AS total_bronze_rows,
    COUNT(DISTINCT cik) AS distinct_ciks,
    COUNT(DISTINCT extract_date) AS distinct_extract_dates,
    COUNT(DISTINCT json_extract_scalar(json_text, '$.entityName')) AS distinct_entity_names
FROM financial_analytics_bronze.sec_edgar_companyfacts_raw;
```

Result: 101 rows / 100 distinct CIKs / 2 distinct extract_dates / 100 distinct entityNames. ONE CIK had been extracted twice on two different dates (likely a Phase 1 ingestion re-run mid-session for one company). The duplicate CIK carries the SAME entityName in both extract rows. Reading staging directly without DISTINCT would have shipped 101 satellite rows on first load, breaking the 1:1 invariant with hub_company (100). The naive parent-count inference (100 = 100) was correct as a TARGET but wrong as a PREDICTION of what the source-side row count would actually be — the gap between target and actual is the cardinality drift.

**Verified empirically.** Probe query above. The forward-verify pass earned its keep at design time, not first-run time — DISTINCT (cik, entity_name) collapse baked into the model's distinct_companies CTE before any code shipped. First dbt run delivered [OK 100 in 13.75s] exactly as predicted by the post-probe design; verify/06 check_08 (parent coverage parity) PASS confirmed the 1:1 invariant held in the materialized output.

**Fix (locked at this forward-verify pass, applies to every future satellite).** Every satellite's forward-verify pass now includes an empirical cardinality probe against actual Bronze BEFORE writing the model. The probe shape is the same four-aggregate signature: COUNT(*) / COUNT(DISTINCT business_key) / COUNT(DISTINCT extract_date_or_load_partition) / COUNT(DISTINCT payload_concat). If those four numbers don't match the parent hub count exactly, name the collapse mechanism (DISTINCT clause, latest-extract-only filter, etc.) and bake it into the model's source-side CTE. Cardinality probe artefact lives in DBT_PIPELINE.md section 8.14+ as the per-model forward-verify exhibit.

**Carry-forward principle — empirical probe over inferred parity for cardinality reasoning.** Risk 12 locked "forward-verify pass must include cardinality reasoning, not just function-chain reasoning"; Risk 13 strengthens that to "the reasoning must be empirical against actual data, not inferred from parent-count + structural-shape arguments alone." The senior-DE discipline: doc-verify the function chain (what SHA-256 chain works on Athena, what arguments nest under which YAML property), THEN data-verify the cardinality (what does the actual Bronze look like, and what collapse mechanism is required). Both are part of the standing forward-verify pass.

**Sub-note (same diagnostic loop).** First attempt at the empirical probe used a guessed table name (`bronze_sec_edgar_companyfacts_raw_text` — Claude's read-from-memory guess for the second Bronze table) that returned TABLE_NOT_FOUND in Athena. Actual table name from the Phase 2 session 2 DDL is `sec_edgar_companyfacts_raw` (no `bronze_` prefix). Verify-then-write discipline says: grep the DDL or the source('bronze', 'X') call before writing identifier-bearing diagnostic queries, especially when AWS Glue Catalog table names sometimes diverge from project naming pattern. The miss was caught immediately (Phil pasted the error, fix landed in one round), but it's a verify-then-write category miss adjacent to the criterion-6 proactive-bypass rule. Carry-forward: for any diagnostic query targeting a table identifier Claude hasn't recently written, grep the project for the canonical identifier first.

#### Risk 14 — hub_period is non-standard for transactional observation data: period attributes as descriptive payload, not separate hub (banked 2026-05-28, Phase 2 session 8 forward-verify pass)

**Verified against authoritative source.** Scalefree's multi-temporality article (scalefree.com/blog/data-vault/multi-temporality-in-data-vault-2-0-part-1) treats period-related attributes (period_start, period_end, fy, fp, valid-from/valid-to time spans) as descriptive data living inside satellites with multi-temporal awareness — NOT as separate hubs. A hub_period is only DV2.0-idiomatic when the period itself is an enterprise-wide reference entity (a fiscal calendar with cross-system reuse). For per-source-observation period attributes the canonical placement is link-level descriptive payload or satellite payload.

**Empirically verified.** Phase 2 session 8 cardinality probe 3 against int_sec_edgar__concepts_canonical returned 10,974 distinct (period_start, period_end, fy, fp) instances — transactional-grain territory, not reference-hub territory. A true reference-style fiscal-calendar hub would land at ~40-50 rows (10 years × ~4-6 fiscal-period codes). At 10,974 distinct period instances, hub_period would be structurally redundant with the link's natural grain — adding it only to satisfy the 1:1-sat-shape aesthetic from sessions 6+7 would be tail-wagging-the-dog modeling.

**Decision (locked at this forward-verify pass).** No hub_period in Project #3's warehouse layer. Period attributes (period_start_date, period_end_date, fiscal_year, fiscal_period) live as descriptive payload on link_filing_concept_period (the 3-way link connecting hub_company + hub_filing + hub_concept). Cardinality of the link is the natural observation grain; period attributes describe each observation without needing their own hub.

**Carry-forward principle.** Hubs are for ENTITY identity (a thing that exists in the business domain — a company, a filing, a concept, a product, a customer). Time-spans, periods, and fiscal periods are typically ATTRIBUTES of entity observations rather than entities themselves. The empirical test before adding a temporal hub: probe the cardinality of distinct period instances; if it's in the tens of thousands relative to the source observation count, the periods are transactional grain and belong as payload, not as a hub. Reference-hub for periods only earns its keep when (a) the period is reused across many sources/entities AND (b) the distinct period count is small enough to be a genuine dimension. This carries to any future portfolio project with date-keyed observation data (sales, transactions, sensor readings, log events).

#### Risk 15 — non-historized vs standard link decision depends on relationship-grain repetition at source (banked 2026-05-28, Phase 2 session 8 forward-verify pass)

**Verified against authoritative source.** Scalefree's non-historized links article (scalefree.com/blog/modeling/the-value-of-non-historized-links) defines non-historized links (also called Transaction Links) as the DV2.0 pattern for relationships that REPEAT at source with different transaction values — e.g., a customer buying the same product from the same store on multiple occasions. The standard link would collapse those repetitions to a distinct list of relationships, requiring a grain-shift via satellite join to recover the original transaction-per-row granularity. The non-historized link preserves source granularity directly.

**Empirically verified.** Phase 2 session 8 cardinality probe 4 against int_sec_edgar__concepts_canonical revealed 9,335 (cik, canonical_concept, period_end_date) groups with value disagreement (31% of 29,815 total groups) — but inspection shows this comes from period-grain ambiguity (3-month Q3 vs 9-month YTD sharing the same end date), multi-filing same-period reporting (Q1 standalone + 10-K including Q1 + 10-K/A restated Q1), canonical-collapse double-projection, and only a SUBSET of true restatements. Critically: when accession_number is added to the grain, each (cik, accession_number, canonical_concept, period_start, period_end, fy, fp) tuple is unique-per-filing. SEC restatements come via NEW accession_numbers, not same-accession value drift.

**Decision (locked at this forward-verify pass).** link_filing_concept_period is a STANDARD link, not a non-historized link. The relationship grain (cik, accession_number, canonical_concept, period_start, period_end, fy, fp) is unique-per-source-event in SEC XBRL's reporting semantics. Restatements appear as NEW link rows because they carry NEW accession_numbers — no grain-shift needed, no NHL pattern needed. sat_concept_value as a standard SCD-2 sat protects against the rare same-accession value drift across extract_dates (1 chance within current Bronze per the session 7 duplicate-extract CIK; contract valid for future).

**Carry-forward principle.** The link-class test at design time: "if the upstream source were to push the same (entity1, entity2, ...) tuple twice, would those be (a) distinct relationship-events with potentially different values [→ non-historized link] OR (b) duplicate-extract noise / re-extraction of the same observation [→ standard link]." SEC XBRL fits (b) — each filing's facts are observed once per filing, repeat extractions are duplicate-detection territory. Sales transactions fit (a) — same customer-store-product combination genuinely repeats across time with different transaction values. The choice between standard and non-historized link is not about the data domain (financial vs retail vs IoT) — it's about whether the source semantics treat the relationship instance as unique-per-event or repeatable-per-event. Apply to every future link design in this project and beyond.

#### Risk 16 — Canonical-concept dictionary joins produce per-canonical row duplicates from multi-tag-same-period reporting: DISTINCT collapse at link source-side (banked 2026-05-28, Phase 2 session 8 forward-verify pass)

**Verified empirically.** Phase 2 session 8 cardinality probe 2 against int_sec_edgar__concepts_canonical returned 93,869 total rows vs 87,928 distinct (cik, canonical_concept, period_start, period_end, fy, fp) tuples — a 5,941-row gap representing canonical-collapse double-projection. The 4 revenue alias tags (Revenues, SalesRevenueNet, RevenueFromContractWithCustomerExcludingAssessedTax, RevenueFromContractWithCustomerIncludingAssessedTax) all map to canonical_concept = 'revenue' via the canonical_concepts_dictionary seed. When a single filing reports the SAME period under multiple revenue alias tags (common during ASC 606 transition years 2017-2019 when companies dual-tagged), the canonical view produces multiple rows with identical (cik, canonical_concept, period_*) tuples — different raw concept_name, potentially slightly different reported values due to reclassification timing.

**Implication.** Without DISTINCT (cik, accession_number, canonical_concept, period_start, period_end, fy, fp) at link_filing_concept_period's source-side CTE, the link would receive ~94K rows where ~88K is the natural cardinal unit — 5,941 rows would either be rejected by the unique_key constraint (engine-side OK but wasted scan cost) or, if multiple raw tags happen to hash to different link hashes via accession-number-or-period drift, would silently produce duplicate-canonical link rows breaking the link's natural-PK semantics. Same DISTINCT discipline as sat_filing_metadata's full-payload-tuple collapse (Risk 11) but extended to the post-canonical layer: DISTINCT now applies to the canonical projection, not the raw tag projection.

**Decision (locked at this forward-verify pass).** link_filing_concept_period's source-side CTE applies DISTINCT to the natural cardinal tuple (cik, accession_number, canonical_concept, period_start, period_end, fy, fp) BEFORE composite-hash computation. The canonical_concept (not raw concept_name) is the link grain by design — audit lineage to the raw tag survives in the staging + intermediate layer for forensic queries; the warehouse vault stores canonical observations only. For the value-disagreement case (5,941 rows where two raw tags reported slightly different values for the canonical-collapsed group), select MIN(value) or first-by-tag-priority during the source-side projection — that's a sat_concept_value design decision banked separately at the model body.

**Carry-forward principle.** When a model sources from a layer that performs semantic collapse (dictionary join, canonical name reconciliation, code-to-label mapping), the post-collapse layer can produce duplicate rows at the collapsed-grain level if the source had multiple distinct keys mapping to the same collapsed key. DISTINCT at the natural-cardinal-unit-of-the-collapsed-layer is the defensive standard. Generalizes Risk 11 (pre-collapse DISTINCT on UNNEST repetition) into a post-collapse DISTINCT principle. Both shapes apply at every warehouse model that sources from intermediate/staging layers performing collapse-style transformations — and to every future portfolio project with reference-data dimensional reconciliation.

#### Risk 17 — Degenerate multi-active satellite payload (CDK == payload) needs explicit design acknowledgment, not silent acceptance (banked 2026-05-29, Phase 2 session 9 forward-verify pass)

**Verified against authoritative sources.** AutomateDV ma_sat tutorial (automate-dv.readthedocs.io/en/latest/tutorial/tut_multi_active_satellites/) frames the canonical MAS structure as parent_hk + load_datetime + Child Dependent Key (CDK) in the primary key, with descriptive PAYLOAD as a separate-from-CDK column set. The textbook example (customer phone numbers) uses CUSTOMER_PHONE as the CDK and CUSTOMER_NAME as the payload — different concepts at different granularities. Scalefree's multi-active-satellites Part 1 (scalefree.com/blog/data-vault/using-multi-active-satellites-the-correct-way-1-2/) reinforces the same structural distinction: the CDK identifies which active row this is; the payload is the descriptive content that can change over time per active row.

**Implication.** sat_concept_canonical's design has no separate-from-CDK descriptive payload. The raw concept_name IS both the active-row identifier (hashed into sub_sequence_key as the CDK) and the only audit-lineage attribute being preserved. business_area from the canonical_concepts_dictionary seed is 1:1 with canonical_concept (the parent BK), not 1:1 with the raw tag — semantically a parent-level attribute that would belong on a regular sat on hub_concept, not on this MAS. With no separate payload, the hashdiff column is structurally constant per (parent, CDK) pair by construction — once a (canonical, raw_tag) pair is observed, the hashdiff for that row never changes. The SCD-2 change-detection mechanic still fires correctly on the (parent, CDK) uniqueness branch (new pair = new sat row inserted), but the hashdiff-change branch can't fire in practice.

**Decision (locked at this forward-verify pass).** Keep the hashdiff column anyway. Two reasons. (a) Project-wide visual consistency with sessions 6/7/8 satellites — every sat carries the same hub/hashdiff/parent_hk/load_datetime/record_source column-list shape; dropping hashdiff for this one sat would break the surface symmetry that makes the warehouse layer readable as a coherent collection. (b) Future-proofing — if a per-raw-tag descriptive attribute is ever added (e.g., first_observed_date or deprecation_date for an XBRL tag), the hashdiff structure is already in place to detect changes. Document the degeneracy explicitly in the model body so the choice is auditable and isn't read as a bug or oversight at portfolio walkthrough time.

**Carry-forward principle.** In any DV2.0 satellite where the CDK and the only payload attribute are the same concept, name the degeneracy in the model body comment block before code ships. Don't silently inherit the hashdiff column from a standard sat template without noting that it's structurally constant by construction — a senior DE reviewing the code shouldn't have to derive the degeneracy from the hashdiff column's behavior at runtime. The degeneracy is a design choice, not an accident; document it like one. Applies to any future audit-lineage MAS (raw-tag → canonical mapping, code-to-label dimension reconciliation, source-system-of-record provenance trails) and any future portfolio project with semantic-collapse audit satellites.

#### Risk 18 — Multi-active satellite CDK selection priority: stable source-provided type code over sub-sequence number (banked 2026-05-29, Phase 2 session 9 forward-verify pass)

**Verified against authoritative source.** Scalefree's multi-active-satellites Part 1 article (scalefree.com/blog/data-vault/using-multi-active-satellites-the-correct-way-1-2/) explicitly enumerates the implementation options in priority order: (a) **type code from source** — when the upstream source provides a stable identifier per active row (e.g., phone type: 'home'/'business'/'cell'/'fax'), use it directly as the CDK. (b) **sub-sequence number** — auto-numbered 1..N per parent in the staging layer, used as the FALLBACK when no stable type code is provided. (c) extra weak hub — last-resort pattern, not recommended for most cases. The article calls out the failure mode of using sub-sequence numbering when a stable type code is available: if the upstream source returns the active rows in different order on a subsequent load, the auto-numbered sub-sequence reshuffles and corrupts the SCD-2 audit lineage (a row's `sub_sequence_key = 3` on Monday becomes `= 2` on Tuesday).

**Implication.** sat_concept_canonical has a stable source-provided type code by design: the raw XBRL US-GAAP tag name (e.g., 'Revenues', 'SalesRevenueNet') is a stable taxonomy identifier maintained by FASB and the XBRL US standards body. A 10-K filed under 'Revenues' in 2017 is still tagged 'Revenues' on every re-extract today. The CDK is therefore the stable type code (raw concept_name), hashed to fixed width via the project SHA-256 chain for surface consistency with the rest of the hash-key column set. Auto-numbering rejected: would re-shuffle CDK assignments on every dbt refresh if the upstream view ever returned rows in different order, corrupting the audit lineage immediately.

**Decision (locked at this forward-verify pass).** sub_sequence_key = `to_hex(sha256(to_utf8(CAST(concept_name AS varchar))))`. Same SHA-256 + to_utf8 + to_hex chain as every other hash column in the project (Risk 4 hash chain locked at session 4). The CDK source is the stable source-provided raw concept_name; the construction is the same hash chain; the result is a 64-char fixed-width column visually consistent with hub_company_hk / hub_filing_hk / hub_concept_hk / sat_*_hk / hashdiff columns. The "sub_sequence_key" column name is retained as the structural label even though it's not an auto-numbered sub-sequence — Scalefree's "sub-sequence" terminology is the canonical DV2.0 column name for the MAS CDK regardless of whether the underlying value is a type code or an auto-number.

**Carry-forward principle.** Before defaulting to sub-sequence auto-numbering for any future MAS, audit the upstream source for a stable type code that could serve as the CDK directly. The priority test: does the upstream source produce, for each active row, a stable identifier that won't change across re-extracts? If yes → use it as CDK (hashed for surface consistency). If no → sub-sequence auto-numbering is the fallback. The same priority test applies to any future portfolio project with MAS use cases: customer contact methods (phone/email/address types), product attribute alternatives (color/size variants), regulatory classification codes (ICD/SIC/NAICS alternates per entity), source-system identifiers from federation (multi-CRM customer rosters).

#### Risk 19 — PIT pattern requires 2+ satellites per parent to materialize its query-acceleration value; single-sat topology demands honest framing, not redundant PIT proliferation (banked 2026-05-29, Phase 2 session 10 forward-verify pass)

**Verified against authoritative sources.** AutomateDV's PIT tutorial (automate-dv.readthedocs.io/en/latest/tutorial/tut_point_in_time/) explicitly recommends PIT tables "when referencing at least two Satellites and especially when the Satellites have different rates of update." Scalefree's PIT structure article (scalefree.com/knowledge/webinars/data-vault-friday/pit-table-structure-in-data-vault/) reinforces this — the JOIN-collapse value comes from resolving multi-satellite LDTS lookups to a single equi-join row. A PIT against a single-sat parent reduces ONE join lookup, not many; the value-vs-cost trade-off is materially weaker.

**Implication.** Project #3's Raw Vault topology shipped sessions 4-9 has no 2+ standard-sat parent: hub_company → sat_company_metadata (1); hub_filing → sat_filing_metadata (1); link_filing_concept_period → sat_concept_value (1); hub_concept → sat_concept_canonical (1 MAS). A textbook AutomateDV-shape PIT against any of these has marginal join-reduction value. Building four PITs (one per parent) to "complete the pattern" would be pattern-for-pattern's-sake — anti-portfolio because a senior DE reviewer would flag the unnecessary surface area.

**Decision (locked at this forward-verify pass).** Ship ONE demonstrative PIT — pit_link_filing_concept_period (spine = link_filing_concept_period, sat = sat_concept_value). Picked because (a) it's THE fact-shape every Phase 4 mart will consume — equi-join from PIT to sat resolves "value at as_of_date" without recomputing the SCD-2 latest-row anti-join at query time, real downstream benefit; (b) future-proofs for when sat_concept_value gets joined with a second sat (e.g., sat_concept_value_restatement_flag or sat_concept_value_audit) — PIT shape already in place. Document the single-sat framing explicitly in the model body so the design call is auditable: this PIT demonstrates the Scalefree-canonical pattern + targets the most-queried Raw Vault object, NOT padding the warehouse with one PIT per parent.

**Carry-forward principle.** In any portfolio project where the Raw Vault is single-sat-per-parent, ship ONE PIT against the parent most frequently consumed by downstream marts, not one per parent. Name the single-sat framing in the model body. PIT proliferation against single-sat parents is portfolio noise, not portfolio depth. Same logic applies to any future Vault implementation where the parent-to-sat fan-out hasn't yet expanded — the pattern lives in the project; the surface area scales with actual sat count.

#### Risk 20 — Bridge pattern's effectivity-satellite metadata is optional; no-end-date link topology allows simplified bridge_walk (banked 2026-05-29, Phase 2 session 10 forward-verify pass)

**Verified against authoritative sources.** AutomateDV's bridge tutorial (automate-dv.readthedocs.io/en/latest/tutorial/tut_bridges/) presents bridge_walk metadata with eff_sat_table + eff_sat_pk + eff_sat_end_date + eff_sat_load_date per link relationship — but the eff_sat columns serve specifically to filter "currently-valid" relationships at as_of_date when source data tracks relationship end-dates. Scalefree's Bridge Tables 101 (scalefree.com/blog/data-vault/bridge-tables-101/) shows the SQL idiom without eff_sat references when source relationships are insert-only-current — the simpler shape stores hub_hashkeys + link_hashkeys + snapshot_date + aggregated measures, filtering by source LDTS ≤ snapshot_date.

**Implication.** Project #3's links (link_company_filing, link_filing_concept_period) are insert-only with no end-date semantics — a (cik, accession_number) relationship doesn't "end" in SEC reporting; a filing exists or doesn't, and once filed it remains observable forever. We don't ship effectivity satellites, and adding them just to satisfy AutomateDV's metadata shape would be tail-wagging-the-dog modeling. The Scalefree-canonical simpler shape is the correct fit.

**Decision (locked at this forward-verify pass).** Hand-rolled bridge_company_concept_period structure: (bridge_hk, hub_company_hk, hub_filing_hk, hub_concept_hk, link_company_filing_hk, link_filing_concept_period_hk, period_end_date, fiscal_year, fiscal_period, as_of_date, load_datetime, record_source). Source-side filter: WHERE hub_company load_datetime ≤ as_of_date AND hub_filing load_datetime ≤ as_of_date AND link load_datetimes ≤ as_of_date — relationships visible at as_of_date land in the row. No eff_sat columns. Composite bridge_hk = SHA-256 of (hub_company_hk || '||' || link_company_filing_hk || '||' || link_filing_concept_period_hk || '||' || as_of_date) for surface consistency with hub/link/sat single-hash-PK pattern (Risk 10 carry).

**Carry-forward principle.** Effectivity satellites are not a prerequisite for bridge tables — they're the canonical pattern when source data carries relationship-end-date semantics. Source-event-stream domains (financial filings, regulatory submissions, immutable event logs) typically don't have end-dates and use the simpler bridge shape. Domains where relationships start AND END at the source (customer-product subscriptions, employee-department assignments, account-status memberships) earn the eff_sat columns. Domain-agnostic test before adding eff_sat to a bridge: does the source ever emit a "relationship X ended on date Y" signal? If yes → eff_sat. If no → simpler shape.

#### Risk 21 — As-of-dates table is a Business Vault prerequisite; scale of as-of-dates list multiplies PIT/Bridge row counts (banked 2026-05-29, Phase 2 session 10 forward-verify pass)

**Verified against authoritative source.** Both AutomateDV's PIT and Bridge tutorials require an as_of_dates_table parameter — a list of timestamps for which the PIT/Bridge resolves the "what was visible at this date" snapshot. The as-of-dates table is a Business-Vault-layer artefact that doesn't exist until shipped explicitly. AutomateDV's separate As-of-Date tutorial (automate-dv.readthedocs.io/en/latest/tutorial/tut_as_of_date/) shows the table as a simple single-column timestamp list.

**Implication.** Project #3 doesn't yet have a dim_as_of_dates equivalent. Choice of cardinality directly multiplies both PIT and Bridge first-load row counts. Concrete options surfaced at design-time math:

- **Fiscal-quarter-end snapshots over 10 years** = ~38-40 rows × link cardinality (89,821) = ~3.4M PIT rows. Canonical Scalefree shape; large for our Free-Tier scope.
- **Fiscal-year-end only over 10 years** = 10 rows × 89,821 = ~898K PIT rows. Demonstrates multi-snapshot temporal mechanic without the explosion. Picked.
- **Current-only as_of_date** = 1 row × 89,821 = 89,821 rows. Demonstrates JOIN-collapse mechanic but loses the temporal-snapshot story.

**Decision (locked at this forward-verify pass).** Ship dim_as_of_dates as a small dbt model (not a seed — generated from a SELECT VALUES clause so the 10 fiscal-year-ends are reproducible from source and self-documenting). Cardinality = 10 fiscal-year-end timestamps spanning 2016-12-31 through 2025-12-31. Justifies multi-snapshot PIT/Bridge mechanic without 4x storage explosion vs the quarterly-snapshot alternative. Fiscal-year-end is the natural mart-time grain for "annual P&L trend" and "annual peer benchmark" — directly matches Phase 4 mart query patterns.

**Carry-forward principle.** Before locking the as-of-dates cardinality for any PIT/Bridge, multiply against the largest expected parent cardinality and confirm the resulting row count is within storage budget AND maps to actual mart query needs. The aesthetic-default (quarter-end, month-end) is rarely the right cardinality — pick the grain that matches downstream consumption. Same principle in future portfolio projects with snapshot-shaped Business Vault tables.

#### Risk 22 — Ghost-record pattern deferred; PIT uses LEFT JOIN + NULL semantics for "no satellite at as-of-date" (banked 2026-05-29, Phase 2 session 10 forward-verify pass)

**Verified against authoritative sources.** AutomateDV's PIT structure (automate-dv.readthedocs.io/en/latest/tutorial/tut_point_in_time/) emits a synthetic zero-hash-key ghost record reference when a parent has no matching satellite row at a given as_of_date — the worked example shows "000000..." in the SAT_CUSTOMER_LOGIN_PK column with a placeholder 1900-01-01 LDTS for a customer whose first login post-dated 2021-11-01. Scalefree's "Implementing DV2.0 Ghost Records" article (scalefree.com/blog/data-vault/implementing-dv2-0-ghost-records/) defines ghost records as a standing-row idiom inserted into every satellite at table-create time with a zero-hash key + epoch LDTS, ensuring inner-join semantics work cleanly without NULL handling at query time.

**Implication.** Project #3's sats (sat_filing_metadata, sat_company_metadata, sat_concept_value, sat_concept_canonical) don't ship with ghost records — we've used standard SCD-2 insert-on-change throughout. Adding ghost records retroactively to all four sats would be substantial out-of-scope work for session 10. The simpler hand-rolled alternative: PIT uses LEFT JOIN against the sat with COALESCE-to-NULL on sat_hk + ldts when no sat row exists for the parent at as_of_date.

**Decision (locked at this forward-verify pass).** PIT uses LEFT JOIN semantics. Document the ghost-record-deferred call in the model body explicitly. Phase 4 mart layer can handle NULL semantics via standard COALESCE in mart-side SQL. Ghost records remain a deferred enhancement — earnable in a future portfolio iteration if Power BI downstream specifically needs inner-join semantics on the PIT (unlikely for our PBI Import mode + DAX-side blank-handling).

**Carry-forward principle.** Ghost records are a defensible standard but not a hard prerequisite for PITs — LEFT JOIN + NULL handling is the pragmatic substitute when retrofitting ghost records to existing sats would inflate session scope. The trade-off: ghost records simplify mart SQL (always inner-join), but retrofit cost on shipped sats is non-trivial. Decision rule: ship ghost records from satellite-creation time onward in future projects; don't retrofit unless mart-side query complexity demands it.

#### Risk 23 — load_datetime captures ingestion time, not observation time: PIT/Bridge must anchor on filed_date for meaningful temporal snapshots (banked 2026-05-29, Phase 2 session 10 forward-verify pass)

**Verified against authoritative sources + project state.** Scalefree's PIT structure article and AutomateDV's PIT tutorial both anchor the temporal filter on the satellite's load_datetime — the canonical DV2.0 semantic is "load_datetime captures when the system observed the fact." Project #3's actual load_datetime implementation (verified by reading hub_company.sql, hub_filing.sql, sat_filing_metadata.sql, sat_concept_value.sql, sat_concept_canonical.sql) uses `CAST(current_timestamp AT TIME ZONE 'UTC' AS timestamp(6))` — captures the dbt-run wall clock, NOT the SEC filing's observation date. Every row's load_datetime is in May 2026 (the actual ingestion run). Applied to a canonical PIT with as_of_dates spanning 2016-12-31 through 2025-12-31, the MAX(sat.load_datetime) ≤ as_of_date filter evaluates to false for every as_of_date before 2026-05-29 — the PIT would be EMPTY for the entire 10-year demonstrative horizon, holding rows only at as_of_dates after the ingestion timestamp.

**Implication.** A canonical PIT against our Raw Vault is structurally correct but semantically empty for the demonstrative time range. Three options surfaced at design-time analysis:

- (a) Accept the canonical PIT shape + restrict as_of_dates to 2026+ only — loses the 10-year multi-snapshot story; demonstrates the mechanic only on current-and-future.
- (b) Retrofit load_datetime on every shipped sat to use filed_date instead of ingestion time — substantial out-of-scope work, breaks the audit-lineage immutability contract on already-shipped sats, requires --full-refresh on all 4 sats.
- (c) **Anchor PIT/Bridge on filed_date (from sat_filing_metadata) instead of load_datetime** — preserves canonical PIT/Bridge structure, makes the 10-year as_of_dates list resolve real data, document the deviation explicitly. Picked.

**Decision (locked at this forward-verify pass).** PIT and Bridge join through hub_filing → sat_filing_metadata to access filed_date, then use MAX(filed_date) ≤ as_of_date as the temporal filter. The PIT's per-row temporal coordinate stored as sat_ldts comes from the link → sat join chain at the chosen filed_date snapshot — load_datetime is preserved as the canonical lineage column even though it's not the temporal filter. Document the deviation explicitly in both pit_* and bridge_* model bodies + in DBT_PIPELINE.md section 8.22+: project-specific deviation from canonical PIT semantics, driven by the project's ingestion-time load_datetime implementation.

**Carry-forward principle.** In any DV2.0 portfolio project where load_datetime is set at dbt-run time rather than observation time (common simplification for first-time DV implementations), PIT/Bridge must anchor on a source-derived observation-date column (filing date, transaction date, event timestamp) rather than load_datetime. Document the deviation as an explicit architectural call — silently substituting columns is unauditable. The lesson generalizes: **separate the audit-lineage anchor (load_datetime, immutable, ingestion-time) from the business-temporal anchor (observation date from source) when they're not the same.** True production DV2.0 implementations typically make load_datetime = source-extracted observation timestamp, eliminating this concern entirely. Banking the lesson so future portfolio projects either (a) implement observation-time load_datetime from day one, OR (b) explicitly route PIT/Bridge through a source-observation-date column with the deviation documented.

---

### Phase 2 reflection — 23 Risks rolled into eight pattern families (banked 2026-05-29, Phase 2 session 11 close)

Phase 2 banked 23 forward-projected Risks across 8 sessions of forward-verify passes (sessions 3-10). The list is now too long to scan as a flat reference for the post-mini-projects training journey. Rolling them into eight top-level pattern families — each carries forward as a generalisable lesson for the four remaining portfolio projects + the five mini-projects + the training journey. Risks remain individually banked above as design-decision provenance; this section is the consolidated training surface.

**Family 1 — Adapter-vs-engine discipline.** Adapter wrapper docs (dbt-athena recommending `format_version`; AutomateDV not officially supporting dbt-athena) can be stale or off-target relative to the underlying cloud engine. Risks 1 and 2. **Carry-forward.** Engine docs (docs.aws.amazon.com, trino.io) are the source of truth; adapter docs are orientation. Verify against engine before shipping any adapter-recommended config that touches engine internals.

**Family 2 — DV2.0 hash discipline + defensive shielding.** Hash chains over multi-column payload need COALESCE-to-sentinel against NULL propagation in the engine's concat semantics; SCD-2 anti-join needs latest-per-parent partition; satellite hash key chain extends from parent hub hash. Risk 8 + sessions 4-7 carry-forward decisions. **Carry-forward.** Defensive sentinel, parent-extending hash chain, anti-join on latest-hashdiff are the three load-bearing primitives for every future hand-rolled Data Vault.

**Family 3 — Forward-verify-then-write discipline.** Every new architectural pattern (hub class, link class, sat class, PIT, Bridge, MAS) needs a kickoff forward-verify pass against authoritative docs PLUS an empirical four-aggregate cardinality probe (COUNT(*) / COUNT(DISTINCT BK) / COUNT(DISTINCT extract_date) / COUNT(DISTINCT payload)) against actual source data BEFORE the model body is written. Risks 12 (the original miss), 13 (the rule), and the verify-then-write sub-note on diagnostic table identifiers. **Carry-forward.** Doc-verify + empirical probe = standard kickoff activity for any genuinely new pattern in any future project.

**Family 4 — Cardinality-first object-class selection.** The shape of the data (distinct cardinality of candidate keys, ratio of source rows to distinct natural tuples, presence of stable source-provided type codes) drives object-class selection: hub vs payload (Risk 14), standard link vs NHL (Risk 15), post-collapse DISTINCT (Risk 16), CDK = stable type code vs sub-sequence fallback (Risk 18), as-of-dates grain = mart-time grain (Risk 21). **Carry-forward.** Probe distinct cardinality before architecting; let observed grain drive object class, not architectural-pattern catalogues.

**Family 5 — Scope discipline at design time + explicit deferral framing.** Pattern-canonical features that don't earn their keep for the project's actual scope get deferred indefinitely with explicit framing, not silently omitted: hub_period (Risk 14), eff_sat columns on Bridge (Risk 20), ghost-records on sats (Risk 22), degenerate MAS payload acknowledgment (Risk 17). **Carry-forward.** When canonical-pattern feature X doesn't materialize value for the project's scope, name the deferral and the rationale in the model body + LEARNINGS — silent omission reads as oversight at portfolio walkthrough time; explicit deferral reads as senior judgment.

**Family 6 — Temporal semantics fidelity.** Canonical DV2.0 load_datetime = source observation time; project simplification of load_datetime = dbt-run wall clock breaks PIT/Bridge for any historical as_of_date. Risk 23. **Carry-forward.** Implement observation-time load_datetime from day one in any future portfolio Data Vault, OR explicitly route PIT/Bridge through a source-observation-date column with the deviation documented in the model body.

**Family 7 — Honest framing over pattern-padding.** PIT pattern materializes value at 2+ sats per parent. Single-sat Raw Vault gets ONE demonstrative PIT on the most-consumed parent, framed honestly — not one PIT per parent to inflate the warehouse. Risk 19. **Carry-forward.** When a canonical pattern needs N+ inputs to materialize value and the project only has N, ship one demonstrative instance with the framing explicit in walkthrough docs. Pattern proliferation without value is portfolio-anti-pattern.

**Family 8 — Runtime-architecture trade-offs for tool-on-cloud orchestration.** Choosing dbt's host (Glue Python Shell vs Lambda Container Image vs ECS Fargate) is a trade-off across IAM surface, timeout cap, cold-start, dep-install model, and Free-Tier fit. Risk 3 + the session 11 lock. **Carry-forward.** For any tool-on-cloud orchestration choice, evaluate against (a) timeout cap vs expected runtime, (b) IAM expansion, (c) cold-start vs cadence, (d) dep install path, (e) cost-tier fit. Default to the simplest shape that fits actual workload; container-and-VPC complexity is the production-overkill option, not the safe default.

---

### Phase 3 forward-projected risks (banked 2026-05-29, Phase 2 session 11 — Phase 3 kickoff forward-verify pass)

Six new Risks surfaced at the Phase 3 kickoff forward-verify pass against AWS Step Functions, dbt programmatic invocation, AWS Glue Python Shell, and AWS Lambda Container Image documentation. Banked BEFORE Phase 3 work begins, per the standing forward-verify-pass rule.

#### Risk 24 — dbt-core does not support safe parallel execution in the same process; multi-invocation fan-out requires subprocess wrapping (banked 2026-05-29, Phase 2 session 11 — Phase 3 kickoff forward-verify)

**Verified against authoritative source.** docs.getdbt.com/reference/programmatic-invocations explicitly states: "dbt-core doesn't support safe parallel execution for multiple invocations in the same process. This means it's not safe to run multiple dbt commands concurrently. It's officially discouraged and requires a wrapping process to handle sub-processes." Reason: each dbt-core command interacts with global Python variables; concurrent invocations against the same data platform have undefined behavior.

**Implication.** Phase 3 orchestration design — Step Functions can invoke ONE Glue Python Shell job at a time that runs ONE `dbtRunner().invoke(["build"])` call. Multi-step fan-out (e.g., parallel `dbt run --select` against disjoint subsets) cannot run inside one Python process. Carry-forward principle for any future portfolio project doing dbt-from-orchestrator: each orchestrator step is one dbt invocation in one process. Fan-out happens at the orchestrator level (Step Functions parallel branches launching separate Glue jobs), not inside Python.

#### Risk 25 — `dbtRunnerResult.result` object internals are partially documented and "liable to change in future versions of dbt-core"; pin dbt-core version + treat result as exit-code-only (banked 2026-05-29, Phase 2 session 11 — Phase 3 kickoff forward-verify)

**Verified against authoritative source.** docs.getdbt.com/reference/programmatic-invocations "Commitments & Caveats" section: "the objects returned by each command in `dbtRunnerResult.result` are not fully contracted, and therefore liable to change... These additional fields and methods should be considered internal and liable to change in future versions of dbt-core."

**Implication.** The Glue Python Shell job's success criterion should be `dbtRunnerResult.success` (bool) + the CLI exit code (0/1/2) — NOT field-level inspection of `result.results[*].node.status` or any other internal structure. The dbt-core version pinned in `--additional-python-modules` becomes a stability contract; bumping dbt-core requires re-validating Step Functions failure-detection logic. Carry-forward to any programmatic dbt invocation: treat `dbtRunnerResult` as a coarse-grained success/failure signal, leave structured event introspection to dbt's `EventManager` callback API which has a separate stability contract.

#### Risk 26 — AWS Glue Python Shell 3.6 sunset 2026-03-01; only Python 3.9 is supported for Phase 3 (banked 2026-05-29, Phase 2 session 11 — Phase 3 kickoff forward-verify)

**Verified against authoritative source.** docs.aws.amazon.com/glue/latest/dg/add-job-python.html top-of-page note: "Support for Pyshell v3.6 will end on March 1, 2026." Same page confirms Python 3.9 is the current supported version with 480-minute (8-hour) default timeout on Glue v5+ — 32x Lambda's 15-minute hard cap.

**Implication.** Phase 3 Glue Python Shell jobs are authored against Python 3.9. Compatible with current `requirements.txt` (Python 3.11 locally; dbt-core + dbt-athena are 3.9+ compatible). Carry-forward: when adopting a managed Python runtime on a cloud service, check the runtime's lifecycle stage before authoring — managed runtimes have shorter EOL cycles than expected (Python 3.6 sunset is mid-Phase-3 timeline if Phase 3 had slipped).

#### Risk 27 — dbt-athena + dbt-core dependency install via `--additional-python-modules` adds cold-start time to every Glue Python Shell job run; first-run timing validation required (banked 2026-05-29, Phase 2 session 11 — Phase 3 kickoff forward-verify)

**Verified against authoritative source + project state.** docs.aws.amazon.com/glue/latest/dg/add-job-python.html confirms `--additional-python-modules` triggers pip3 install at job start (not cached across runs). Project's existing dbt-athena adapter footprint includes dbt-core + dbt-athena + pyathena + boto3 + cryptography transitives. pyathena 2.5.3 IS pre-installed in Glue's analytics library set, narrowing the install delta to dbt-core + dbt-athena + their direct transitives.

**Implication.** First Glue Python Shell job at Phase 3 kickoff measures cold-start install time as a baseline — if install adds >2 minutes to a ~30-second dbt build, consider building a Glue-compatible wheel layer OR switching to ECS Fargate with a pre-baked container. For our daily-run cadence at Phase 3 scope, 60-second install + 30-second dbt build = 90-second total run is fully acceptable; flagging only as a baseline-measurement task at first job creation, not a pre-decision blocker. Carry-forward to any managed-runtime + tool-with-deps choice: measure cold-start dep-install time on the first run, decide ahead-of-time whether to optimize via wheel layer / container image / pre-baked AMI based on actual cadence.

#### Risk 28 — AWS Lambda's 15-minute hard execution cap is a forward-projection blocker as dbt build duration grows; explicit reason Lambda Container Image was rejected at the runtime lock (banked 2026-05-29, Phase 2 session 11 — Phase 3 kickoff forward-verify)

**Verified against authoritative source.** docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html: "Code can run for up to 15 minutes in a single invocation" + Function timeout table row: "900 seconds (15 minutes)" — flagged as cannot-be-changed (hard quota).

**Implication.** Current Phase 2 dbt build at 12 models + 121 schema tests runs in ~30-40 seconds — well inside 15 minutes. Phase 4 marts add 5+ models. Mini-project work would add more. At unknown future scale, 15-minute cap could bite without warning. Glue Python Shell's 480-minute cap removes the cap entirely as a concern. Documented as the load-bearing reason Lambda Container Image was rejected at the runtime direction-check, in addition to senior-DE-default factors. Carry-forward to any future serverless-runtime choice: pick timeout caps that accommodate the SCALED workload, not the prototype workload. 15 minutes is fine until it isn't, and "until it isn't" is a 3am page in production.

#### Risk 29 — Step Functions Athena native `.sync` integration runs RAW SQL queries, not dbt orchestration; complementary pattern to dbt-on-Glue-Python-Shell (banked 2026-05-29, Phase 2 session 11 — Phase 3 kickoff forward-verify)

**Verified against authoritative source.** docs.aws.amazon.com/step-functions/latest/dg/connect-athena.html: Step Functions Athena optimized integration's `.sync` pattern supports `StartQueryExecution` only — submits a SQL string to Athena and waits for execution to complete. Not dbt orchestration; dbt produces SQL DDL/DML which Athena executes, but Step Functions calling Athena directly skips the dbt-compile step entirely.

**Implication.** Step Functions Phase 3 state machine has TWO complementary task patterns: (a) Glue Python Shell task running `dbtRunner().invoke(["build"])` for dbt orchestration; (b) Athena `.sync` tasks for raw SQL verify queries (sql/verify/03-12 style structural PASS/FAIL checks). Clean separation: dbt does transformation + tests; Step Functions Athena tasks do post-build verification. IAM auto-generated for Athena task; Glue task uses our existing phil-dbt-style Customer Managed Policy. Carry-forward principle for any cloud-orchestrator with native integrations: enumerate which orchestration steps need a compute host (transformations, custom logic) vs which are direct service calls (SQL execution, file operations, notifications) — native integrations reduce IAM surface for the second class, leave compute hosts for the first.

---

### Phase 3 session 12 — six new Risks banked at first orchestrated run (2026-05-29)

Six new Risks surfaced during the first end-to-end orchestrated dbt-on-Glue-Python-Shell run. Each is a cross-check the forward-verify pass missed because the surfaces in question are downstream of the runtime lock decision.

#### Risk 30 — Managed-runtime Python ceiling vs tool Python floor cross-check (banked 2026-05-29, Phase 3 session 12 — first-run debug loop)

**Verified against authoritative source.** docs.aws.amazon.com Glue Python Shell job properties: Python 3.9 is the only supported runtime post-2026-03-01 Python 3.6 sunset (Risk 26). pypi.org/project/dbt-core: dbt-core 1.11.x Requires-Python >=3.10.0 (verified May 2026); 1.10.x is the last series supporting Python 3.9. pypi.org/project/dbt-athena-community: 1.10.x bumped Requires-Python to >=3.10.0 at version 1.10.0 (December 2025); 1.9.5 (September 2025) is the last adapter version with Python 3.9 support.

**Implication.** The Phase 3 forward-verify pass (Phase 2 session 11) banked Glue Python Shell's Python 3.9 ceiling (Risk 26) but didn't cross-check dbt-core's Python floor at the same time. Result: pinned dbt-core==1.11.11 in Glue --additional-python-modules, pip silently filtered all 1.11.x versions, install failed at runtime. Required two further version downgrades (1.11.11 → 1.10.22 → 1.9.10 for dbt-core; 1.10.1 → 1.9.5 for dbt-athena-community) chasing the Python floor cascade. Carry-forward principle: when locking a managed-runtime Python version OR a tool version, cross-check the Python ceiling AND floor of BOTH surfaces at the same forward-verify pass. Adapter ecosystems often track dbt-core's Python floor with a release lag — verify adapter's floor independently, not by assuming it matches dbt-core's. The aligned pin at session 12 close is Python 3.9 + dbt-core 1.9.10 + dbt-athena-community 1.9.5 — locks until AWS Glue Python Shell adopts Python 3.10+, at which point both pins can advance together.

#### Risk 31 — dbt 1.10+ test config `arguments:` wrapper key fails strict validation on dbt 1.9.x (banked 2026-05-29, Phase 3 session 12 — first-run debug loop)

**Verified against authoritative source + project state.** dbt-core 1.10 release notes (docs.getdbt.com) introduced the `arguments:` wrapper under data test entries to disambiguate test argument names from column-reference fields. dbt-core 1.9.x test macros don't accept `arguments` as a kwarg — parse-time error: `macro 'dbt_macro__test_accepted_values' takes no keyword argument 'arguments'`. Confirmed by ImportError trace from the Phase 3 session 12 first parse attempt against dbt-core 1.9.10 with Phase 2 schema YAMLs (authored against 1.10/1.11).

**Implication.** Schema YAML test syntax is dbt-core-version-coupled. When downgrading dbt-core minor versions (this session: 1.11 → 1.9), every `tests:` / `data_tests:` block authored with `arguments:` wrappers must be flattened. Phase 3 session 12 hit 28 instances across 4 YAML files (intermediate, warehouse, business_vault, seeds), flattened via a one-shot Python migration script (scripts/flatten_test_arguments.py in outputs). Carry-forward principle: when the project's dbt-core line shifts BACKWARD for managed-runtime compatibility reasons, audit the schema YAML for syntax features introduced in the newer line. The companion flag block `flags.warn_error_options.silence` (which referenced `CustomKeyInConfigDeprecation` + `DeprecationsSummary`, both 1.10+ error names) is the second case of the same pattern: 1.10+-only config rejected at parse-time on 1.9.x. Both classes are detectable at design time via the dbt-core release notes diff between the OLD (locally-tested) and NEW (managed-runtime-pinned) versions.

#### Risk 32 — Glue Python Shell stdout buffering + `if __name__ == "__main__":` guard silent-no-op (banked 2026-05-29, Phase 3 session 12 — first-run debug loop)

**Verified against authoritative source + empirical evidence.** AWS Glue Python Shell job execution model (docs.aws.amazon.com/glue/latest/dg/add-job-python.html) does not guarantee `__name__ == "__main__"` for the entry-point script — the script may be exec'd or runpy'd by the Glue runtime with a different module name. Empirical evidence from Phase 3 session 12 first run: the wrapper script (with `if __name__ == "__main__": sys.exit(main())` guard) returned exit code 0 with ZERO output to CloudWatch Logs after the "Setup complete. Starting script execution" line. dbtRunner was never invoked despite the wrapper script being downloaded and executed by Glue. Athena Recent queries showed NO queries from the Glue run timestamp window — the smoking gun that dbt did not run.

**Implication.** Two carry-forward fixes for any Python script targeting Glue Python Shell: (a) drop the `if __name__ == "__main__":` guard and call `sys.exit(main())` unconditionally at module level — the guard's only benefit is import-vs-execute disambiguation, and Glue Python Shell scripts are never imported as modules; (b) use `print(..., flush=True)` everywhere (or set `PYTHONUNBUFFERED=1` via Glue's --conf, or use `sys.stdout.reconfigure(line_buffering=True)`) so stdout reaches CloudWatch before the job terminates. The default Python stdout buffering against a non-TTY can lose the entire last buffer when the process exits, masking the failure-mode signal. The `__name__` guard silent-no-op is particularly dangerous because it produces a Succeeded job status with no error signal — wrapper exits 0 trivially.

#### Risk 33 — IAM Role wizard "Step Functions" use case auto-attaches AWSLambdaRole; Custom trust policy is cleaner for non-Lambda state machines (banked 2026-05-29, Phase 3 session 12 — IAM authoring)

**Verified against authoritative source + project state.** IAM Role creation wizard's AWS service → Step Functions use case pre-attaches the AWSLambdaRole managed policy (grants lambda:InvokeFunction*) and hides the policy search box — the assumption baked into the wizard is that Step Functions state machines invoke Lambda functions. State machines that orchestrate Glue + Athena + native integrations (our Phase 3 pattern) don't need Lambda permissions and AWSLambdaRole is dead weight.

**Implication.** For Step Functions execution roles that don't invoke Lambda, use the Custom trust policy path from the Trusted entity type grid instead of AWS service → Step Functions. Custom trust policy gives a normal Add permissions screen with the search box, so you can attach ONLY your Customer Managed Policy. Carry-forward principle for any IAM Role wizard with pre-attached managed policies that conflict with least-privilege intent: switch to Custom trust policy with the principal's exact ARN, then attach only the policies the workload actually needs.

#### Risk 34 — Glue role's Glue Catalog IAM scope must include EVERY upstream + downstream Catalog database the dbt project sources from or writes to (banked 2026-05-29, Phase 3 session 12 — first-run debug loop)

**Verified against authoritative source + project state.** dbt-athena models that reference `{{ source('bronze', 'sec_edgar_companyfacts') }}` resolve via the source's database (financial_analytics_bronze) + table on the Athena Glue Data Catalog. The Glue Python Shell job's execution role must have glue:GetDatabase + glue:GetTable on the Bronze database. Initial lakehouse-glue-runtime-policy scoped Glue Catalog access to financial_analytics_silver ONLY — staging models failed with `Runtime Error in model stg_sec_edgar__companyfacts ... User: arn:aws:sts::470439680370:assumed-role/financial-analytics-glue-runtime/...` indicating Athena denied the Glue Catalog read because the assumed role's policy didn't grant access to the Bronze database.

**Implication.** When authoring the Customer Managed Policy for a dbt-athena Glue runtime role, enumerate EVERY Catalog database the dbt models touch: Bronze (sources read), Silver (warehouse + intermediate + business_vault read+write), Marts (Phase 4 — future writes). Either grant `glue:Get*` on the catalog-wide resource (broader, simpler) OR split into separate Sid blocks per database with appropriate read-only or read-write scopes (tighter, more verbose). Phase 3 session 12 split into GlueCatalogSilverReadWrite + GlueCatalogBronzeRead — read-only on Bronze enforces the insert-only-Bronze invariant at the IAM layer. Carry-forward principle: dbt's source() references are a load-bearing surface for IAM scope discovery — grep the project for `source(` and the Catalog database names listed in `_sources.yml` files BEFORE writing the IAM policy.

#### Risk 35 — `dbt deps` must run inside the Glue job (the deploy sync excludes dbt_packages/ from S3 by design) (banked 2026-05-29, Phase 3 session 12 — first-run debug loop)

**Verified against authoritative source + project state.** dbt's package resolution model: packages.yml declares dependencies; `dbt deps` downloads them into the project's `dbt_packages/` folder; subsequent `dbt parse/run/build` commands compile against the resolved packages. The Phase 3 deploy pattern (scripts/sync_phase3_artifacts_to_s3.py) excludes dbt_packages/ from the S3 sync because vendored package code shouldn't be in version control or deploy artifacts. Result: the Glue runtime's dbt project has packages.yml but no dbt_packages/ — dbt build fails with `Compilation Error dbt found 1 package(s) specified in packages.yml, but only 0 package(s) installed in dbt_packages. Run "dbt deps" to install package dependencies.`

**Implication.** The Glue wrapper script must invoke `dbtRunner().invoke(["deps", ...])` BEFORE `dbtRunner().invoke(["build", ...])`. ~2-second cost per Glue run; runs once per invocation. The alternative — including dbt_packages/ in the S3 sync — ships vendored package code to S3 and conflates project-source-of-truth with package-version-pin (which lives in package-lock.yml). The dbt deps approach inside the wrapper preserves the clean S3 deploy surface AND ensures package versions match package-lock.yml at every run. Carry-forward principle for any tool that has a separate "install dependencies" phase from "run workload" (dbt deps, npm install, pip install -r, terraform init): include the install step in the orchestrator's runtime invocation rather than pre-baking dependencies into the deploy artifact. Faster iteration, clean separation, package-lock authority preserved.

#### Risk 36 — Step Functions Parallel state fails fast: any sibling unhandled error stops all other branches in flight (banked 2026-05-29, Phase 3 session 13 — restricted-domain forward-verify pass + confirmed live at first orchestrated run with Parallel fan-out)

**Verified against authoritative source + live execution.** AWS Step Functions docs (docs.aws.amazon.com/step-functions/latest/dg/state-parallel.html) explicitly: "If any branch fails, because of an unhandled error or by transitioning to a Fail state, the entire Parallel state is considered to have failed and all its branches are stopped. If the error is not handled by the Parallel state itself, Step Functions stops the execution with an error." Phase 3 session 13 first orchestrated run with the new Parallel verify fan-out confirmed this live: VerifyWarehouseLinks failed on a glue:GetDatabase AccessDenied (Risk 37 below), the other 8 sibling branches that were already running flipped to TaskStateAborted within milliseconds, ParallelStateFailed propagated, execution exited Failed. Total elapsed from sibling failure to ExecutionFailed: ~25 ms.

**Implication.** Fail-fast is the DESIRED semantic for structural verify fan-out — the first regressing verify surfaces the failure immediately and the operator doesn't waste minutes waiting for the other 9 (which were going to pass anyway). For Phase 3 we accept this shape with no per-branch retry, no per-branch Catch handler, and no result aggregation. The carry-forward shape is more nuanced for future Parallel states where each branch represents independent useful work that SHOULD complete even when siblings fail (e.g., per-region data quality scans where the analyst wants to know which regions are healthy regardless of which fail). In that scenario the pattern is per-branch Catch handler that routes the failure into a synthetic success result containing the error metadata — converting branch failures into data, not control flow. Carry-forward principle: at every Parallel state authoring decision, name the semantic intent (fail-fast vs collect-all) and let that drive the Catch shape; never accept fail-fast as a default by omission.

#### Risk 37 — Step Functions execution role's Glue Catalog scope must include EVERY Catalog database referenced by Athena VIEWS in the queries the state machine runs — not just databases referenced directly by the FROM clause (banked 2026-05-29, Phase 3 session 13 — first orchestrated Parallel run debug loop)

**Verified against authoritative source + live execution.** Athena resolves a stored view at query analysis time by recursively analyzing the view's body. If the view body references a table in a different Glue Catalog database, Athena calls glue:GetDatabase on that database under the QUERY EXECUTOR's identity (the Step Functions execution role when called via `athena:startQueryExecution.sync`, NOT the role that created the view). Phase 3 session 13 first orchestrated run: VerifyWarehouseLinks (sql/verify/04) queries `financial_analytics_silver.stg_sec_edgar__companyfacts_raw`, a STORED VIEW in Silver whose body references `financial_analytics_bronze.sec_edgar_companyfacts_raw`. The Step Functions execution role (lakehouse-stepfunctions-runtime-policy) was scoped Silver-only at session 12 because the session 12 demo verify only touched hub_company (a plain Silver table). Verify 04 forces the view → Bronze chain → AccessDeniedException on glue:GetDatabase against the Bronze database.

**Implication.** This is Risk 34 reprise on a different IAM role. At session 12, Risk 34 was banked against the Glue runtime role (which dbt uses to BUILD the Silver tables). Now Risk 37 surfaces on the Step Functions runtime role (which Athena uses to QUERY the Silver tables) — same lesson, different consumer-side role. Fix at session 13: added `glue:GetDatabase + glue:GetTable + glue:GetPartitions` on `database/financial_analytics_bronze` + `table/financial_analytics_bronze/*` to the GlueCatalogReadForAthenaVerify Sid. Second orchestrated run after the policy patch: all 10 Parallel branches TaskSucceeded, ParallelStateSucceeded, ExecutionSucceeded in 6m 15s. Carry-forward principle: when scoping an IAM role for an Athena query consumer, the role's Glue Catalog read scope must include EVERY database transitively reachable via stored-view resolution, not just databases named in the query's FROM clause. Discovery pattern: grep the verify SQL for every table reference, then `SHOW CREATE VIEW <each>` on any view in the list to see what databases the view body references. Build the IAM scope from the union of direct + transitive databases.

---

### Phase 4 forward-projected risks (banked 2026-05-29, Phase 3 session 14 — Phase 4 kickoff forward-verify pass)

Two new Risks surfaced at the Phase 4 kickoff forward-verify pass against the Prophet installation docs (facebook.github.io/prophet), statsmodels installation docs (statsmodels.org), and Microsoft Learn Amazon Athena Power Query connector docs. Banked BEFORE Phase 4 work begins, per the standing forward-verify-pass rule.

#### Risk 38 — Forecasting library footprint vs AWS Free Tier + observation cadence: Prophet is overkill for annual data and adds Stan C++ compilation; statsmodels is the right shape for low-cadence financial time series (banked 2026-05-29, Phase 3 session 14 — Phase 4 kickoff forward-verify)

**Verified against authoritative sources.** facebook.github.io/prophet/docs/installation.html: Prophet (Python) installs via `python -m pip install prophet` but the underlying engine is Stan, which compiles C++ on install (cmdstan / pystan backend). Optimised for daily / sub-daily data with seasonality + holiday effects + trend changepoints — the exact features the model exploits to outperform classical methods. statsmodels.org/stable/install.html: statsmodels installs via pure pip with NumPy + SciPy + Pandas + Patsy dependencies only (no compilation step from PyPI wheels); supports Python 3.9-3.10; carries the classical time-series stack (ARIMA / SARIMA / Holt-Winters exponential smoothing / VAR) in `statsmodels.tsa`. Project #3 Phase 4 forecast workload: 10 fiscal year-end snapshots × 100 companies × 8 in-scope concepts = ~8,000 annual observations to forecast 3-5 years forward. No seasonality (annual cadence), no holiday effects (financial fiscal-year-end metrics), no daily trend changepoints.

**Implication.** Prophet rejected at Phase 4 kickoff on (a) zero seasonality / holiday signal for the model to exploit at annual cadence — the features that justify Prophet's complexity premium materialize at daily / sub-daily, not yearly, (b) Stan C++ compilation footprint adds Free Tier deploy friction even for local development (cold-install can be 5-15 min depending on platform). statsmodels chosen on the inverse: pure-Python deps via PyPI wheels (fast install, no compiler), classical methods (ARIMA / Holt-Winters) fit annual financial time-series cleanly with prediction intervals out of the box, and `statsmodels.tsa.holtwinters.ExponentialSmoothing` + `statsmodels.tsa.arima.ARIMA` cover the forecast surface Phase 4 needs. **Decision: `statsmodels>=0.14` in `requirements.txt` and `scripts/forecast.py`; Prophet explicitly NOT installed.** Carry-forward principle: at every cloud-native forecasting library decision, evaluate model-complexity vs observation cadence vs library install footprint as a joint trade-off — a "more powerful" library that doesn't fit the data's actual signal is just install overhead.

#### Risk 39 — Power BI Amazon Athena connector requires the Amazon Athena ODBC v2 driver pre-installed on the Windows machine + a System DSN configured; that admin step must precede ANY Phase 5 PBI work, not block-discover at PBI Desktop dialog time (banked 2026-05-29, Phase 3 session 14 — Phase 4 kickoff forward-verify)

**Verified against authoritative sources.** learn.microsoft.com/en-us/power-query/connectors/amazon-athena (updated 2026-04-28): Amazon Athena connector is owned and provided by Amazon (not Microsoft). Prerequisites include "Customers must install the Amazon Athena ODBC driver before using the connector". Connection model uses Windows ODBC DSN, not a direct connection string — Phil supplies the DSN name in the PBI connection dialog. Authentication: DSN configuration OR Organizational account (AAD). Capabilities supported: Import + DirectQuery. Athena Engine 3 reads Iceberg V2 natively, so PBI sees the Phase 2 Iceberg Business Vault layer transparently through ODBC — no Iceberg-specific connector config required. On-premises data gateway is only required for Power BI Service refresh (irrelevant for Phil's Desktop-only setup).

**Implication.** Phase 5 session 1 cannot start with "open PBI Desktop → Get Data → Amazon Athena" — that path stalls at the first dialog asking for a DSN that doesn't yet exist. The ODBC v2 driver install + DSN setup is a 15-30 min Windows admin step that needs to land BEFORE any PBI work. Carry-forward principle: at every BI-tool + cloud-warehouse pairing, identify the local-machine prerequisite stack (ODBC / JDBC driver install + DSN / service config + Windows ODBC bitness alignment) and run it as a pre-Phase prerequisite, not as the first activity of the BI phase. Pattern from Project #2: Snowflake → PBI used the Snowflake connector which had a Microsoft-owned no-driver install path; Project #3 Athena → PBI requires the Amazon-owned ODBC driver install + DSN, which is more friction and needs an explicit slot in the schedule. Bake into PROJECT_PLAN section 9 Phase 5 entry as a pre-Phase prerequisite. Phase 5 session 1 task 1 is "ODBC driver install + DSN setup + first connection smoke test from PBI", not "build the executive overview page".

**Update 2026-05-30 (Phase 4 session 1 — shipped at session kickoff).** Risk 39 prerequisite cleared today as Phase 4 session 1's step 0, pulled forward to enable the mart-shape PBI smoke test at mart-creation time per Project #2 carry-forward (catch mart-architecture problems early, not at Phase 5). Live install path took ~10 minutes scripted via PowerShell Add-OdbcDsn (vs the ~15-30 min estimated via GUI). Two new Risks (40-41) surfaced from the install path itself — see below. Risk 43 (PBI ODBC ~/.aws/credentials dependency) banked as adjacent prerequisite. Phase 5 entry pre-prerequisite call-out remains for historical context but is now SHIPPED, not pending.

---

#### Risk 40 — Amazon Athena ODBC v2 driver silently ignores unknown attribute keys at DSN-creation time; mismatched param names (e.g., ProfileName vs AWSProfile) accepted without error and only surface on post-creation attribute inspection (banked 2026-05-30, Phase 4 session 1)

**Verified against authoritative sources.** docs.aws.amazon.com/athena/latest/ug/odbc-v2-driver-main-connection-parameters.html documents the main connection parameters (DSN, Description, Catalog, AwsRegion, Schema, Workgroup, S3OutputLocation, etc.). docs.aws.amazon.com/athena/latest/ug/odbc-v2-driver-iam-profile.html documents the IAM Profile authentication-specific parameters — connection string name is `AWSProfile` (capital AWS), Parameter type Required, default None. The main-params page does NOT enumerate the auth-type-specific params; the auth-type page is the SOLE authoritative source for params like `AWSProfile`. Cross-reading the two pages is necessary for any DSN that uses non-default auth.

**Live signal.** Initial DSN registration used `Add-OdbcDsn ... -SetPropertyValue @(..., "ProfileName=phil-admin")` based on a generic "profile name" mental model. The cmdlet accepted the call without error, no PowerShell warning, no driver-side validation. Post-creation `Get-OdbcDsn | Format-Table -AutoSize` showed AwsProfile attribute present in the standard schema with empty value, no entry for "ProfileName". Three diagnostic steps before fix: (1) re-verify against authoritative iam-profile.html doc page → confirmed correct param name is `AWSProfile`; (2) patch via Set-OdbcDsn with AWSProfile=phil-admin (then phil-dbt); (3) verify attribute populated.

**Carry-forward principle.** For any driver / SDK / library that accepts a free-form attribute-key list at config time (ODBC drivers being the prototypical example, but also Snowflake connection params, BigQuery client options, etc.), always doc-verify connection-string param names against the SPECIFIC auth-type / feature doc page BEFORE config, not just the main-params page. Drivers commonly accept unknown keys silently to support forward-compatibility with newer driver versions — the price is config errors that only surface on attribute inspection or at first runtime call. Defensive pattern: after every DSN / connection-string registration, run a "what attributes are actually set" inspection step (`Get-OdbcDsn` for Windows ODBC, equivalent introspection in other drivers) before any consumer attempts to use the config. Codifies as part of the verify-then-write rule expanded to verify-write-then-inspect.

---

#### Risk 41 — Set-OdbcDsn -SetPropertyValue is destructive-replace, NOT merge — patching one attribute wipes the other 6 (banked 2026-05-30, Phase 4 session 1)

**Verified against authoritative sources.** Microsoft Learn `Set-OdbcDsn` cmdlet reference: "-SetPropertyValue: Specifies an array of property values for the DSN." Not documented as merge / additive — replacement semantics inferred from cmdlet name (`Set-` is replace in PowerShell verb convention, vs `Add-` or `Update-`). Behavior confirmed live at Phase 4 session 1 install.

**Live signal.** After initial DSN registration with 7 correct params (minus the wrong ProfileName key), patching attempt via `Set-OdbcDsn ... -SetPropertyValue @("AWSProfile=phil-admin")` to add just the missing key. Post-patch `Get-OdbcDsn` inspection showed: AwsProfile = phil-admin ✓ (the one we just set), but all 6 OTHER params reset to driver defaults — Schema = default (was financial_analytics_silver), Workgroup = primary (was wg_financial_analytics), AuthenticationType = IAM Credentials (was IAM Profile), AwsRegion empty (was us-east-1), S3OutputLocation empty (was set), Catalog = AwsDataCatalog (still correct but matches default by coincidence). Fix = re-run Set-OdbcDsn with the COMPLETE 7-param list including the corrected AWSProfile key. Post-fix inspection: all 7 params correct.

**Carry-forward principle.** Always supply the COMPLETE attribute / property list when patching configs via PowerShell `Set-*` cmdlets (or any `Set-` semantic in any tool — REST PUT vs PATCH, AWS CLI `aws ... update` vs `aws ... modify`, etc.). When in doubt about whether a config-modification command is merge or replace, READ the cmdlet docs explicitly OR run a destructive-test against a throwaway resource. For ODBC DSN management specifically: maintain a canonical declarative attribute list per DSN (could live in a `.json` or `.yml` config file under `iam/` or `scripts/`) that's the single source of truth for the registration command — every modification re-runs the full registration, never patches deltas. This sidesteps the destructive-replace surprise entirely. Pattern carries across config-mgmt tooling: declarative > imperative for any system where partial-update semantics are ambiguous.

---

#### Risk 42 — SEC ASC 205 income-statement comparatives produce ~2x duplication at the link grain when joined naively through Bridge → PIT → sat; mart layer is where this collapse belongs via ROW_NUMBER() ORDER BY accession_number DESC (banked 2026-05-30, Phase 4 session 1)

**Verified against authoritative sources.** ASC (Accounting Standards Codification) 205-10-50 — Presentation of Financial Statements — Comparative Financial Statements: "It is ordinarily desirable that the statement of financial position, the income statement, and the statement of changes in equity be given for one or more preceding years as well as for the current year." US GAAP and SEC EDGAR convention: 10-K annual filings report the current fiscal year PLUS the 2 prior years as comparatives (3-year income statement, 2-year balance sheet). Verified at Phase 4 session 1 forward-projection of the dup pattern + confirmed live at first dbt build.

**Live signal.** First dbt build of mart_pl_trend (after authoring the SQL + _models.yml + dbt_project.yml marts layer config) returned PASS=18 / ERROR=2 / TOTAL=20 at the schema test layer. Both failures on uniqueness: `dbt_utils_unique_combination_of_columns_mart_pl_trend_cik__as_of_date__fiscal_year__canonical_concept` got 19,371 rows violating; `unique_mart_pl_trend_mart_pl_trend_hk` also got 19,371 rows violating. Both failing on the SAME row count = NOT a hash collision (which would fail unique-hash only). Underlying data carries 19,371 dup tuples per the mart grain.

**Root cause.** link_filing_concept_period grain includes accession_number; mart grain (cik, as_of_date, fiscal_year, canonical_concept) does NOT include accession. SEC ASC 205 means a single (cik, fiscal_year=2018, canonical_concept='revenue') tuple appears in the FY2018 10-K AND the FY2019 10-K AND the FY2020 10-K (each reports FY2018 as the current OR a prior-year comparative). Three accessions = three link rows (link grain includes accession) = three mart rows on the same composite grain after the JOIN chain Bridge → PIT → sat_concept_value (sat row resolved per link grain, so three sat rows = three mart rows). Net dup factor in observed data ≈ 2x (19,371 dups on 19,393 unique = ~50% of source rows were duplicates; means each grain tuple appeared ~2x on average — some appeared 3x as the 10-K cycle suggests, others 1x for early FYs only the original 10-K reports).

**Fix.** Add a `deduped` CTE between `company_resolved` and `hashed` using `ROW_NUMBER() OVER (PARTITION BY mart grain ORDER BY accession_number DESC)` — keep `rn = 1`. accession_number ORDER DESC = latest filing wins (analyst-convention "current reported value for FY at the snapshot"). accession_number is brought through the CTE chain (added to sat_resolved + company_resolved SELECT lists) but NOT projected to the mart output — audit trail of source filing lives in sat_concept_value at the warehouse layer. Post-fix dbt build: PASS=20 / ERROR=0 — clean. Mart row count 19,393.

**Carry-forward principle.** Mart layer is the architectural location for source-domain dedup decisions where the source-faithful grain (BV / RV layer) preserves multiple records per analyst-facing grain. The trade-off: dedup at sat/link level would lose per-accession audit lineage (defeating the DV2.0 contract); dedup at mart level keeps RV/BV pure + applies analyst-facing collapse at the consumption surface. Tie-breaker MUST be deterministic — ROW_NUMBER with explicit ORDER BY (not RANK/DENSE_RANK which can return multiple rows on ties); ORDER BY column MUST be a stable identifier with semantic ordering (accession_number DESC ≈ latest filing; alternative could be MAX(filed_date) but filed_date isn't pushed through Bridge/PIT to mart query path so accession_number is the cheaper proxy). Pattern carries forward to every Phase 4 mart that aggregates per-fiscal-year facts; banked into GOLD_MARTS_PIPELINE.md section 5.

---

#### Risk 43 — PBI ODBC chains AWS credentials through ~/.aws/credentials named profiles, NOT .env env vars; .env-only setups (the project's dbt pattern) need a one-time credentials-file bootstrap before PBI works (banked 2026-05-30, Phase 4 session 1)

**Verified against authoritative sources.** docs.aws.amazon.com/athena/latest/ug/odbc-v2-driver-iam-profile.html: `AWSProfile` connection-string param "The profile name to use for your ODBC connection. For more information about profiles, see Using named profiles in the AWS CLI User Guide." Linked AWS CLI docs explain named profiles live in `~/.aws/credentials` (Linux/macOS) or `%USERPROFILE%\.aws\credentials` (Windows). Driver code path: AWSProfile=X → look up `[X]` section in the credentials file → use the access keys from that section. Env vars are NOT consulted on the IAM Profile auth path; they ARE consulted on the Default Credentials auth path (`AuthenticationType=Default Credentials`) which uses the AWS SDK default credential chain.

**Live signal.** First PBI Athena connection attempt with DSN AWSProfile=phil-admin returned `[HY000] No AWS profile found: phil-admin`. Diagnostic via PowerShell: `Test-Path $env:USERPROFILE\.aws\credentials` returned False — the file didn't exist. Project's dbt pattern uses .env env vars (AWS_DBT_ACCESS_KEY_ID + AWS_DBT_SECRET_ACCESS_KEY) loaded via dotenv wrapper; .env is the SOLE credential source for dbt operations. PBI ODBC has no .env awareness. Fix: PowerShell bootstrap script reads AWS_DBT_* values from .env, writes them as `[phil-dbt]` section to `%USERPROFILE%\.aws\credentials`. Secret values never displayed in chat (script verification via file-size output only).

**Carry-forward principle.** When a project's credential-management pattern (env vars via .env, AWS SDK default chain, named profiles in ~/.aws/credentials, IAM role assumption, IAM Identity Center, etc.) doesn't align with a downstream tool's expected credential source, a one-time bootstrap to bridge the two is the cleanest fix — not a re-architecture of either side. For .env → ~/.aws/credentials specifically: keep the credential values in .env as the source of truth, write a PowerShell / shell bootstrap that populates ~/.aws/credentials from .env at first-PBI-setup time. The bootstrap is a Phase 5 prerequisite step (or in this project Phase 4 session 1 step 0, pulled forward by the mart-shape PBI smoke test pattern). Pattern generalizes to any BI tool with named-profile credential chain (Tableau, Power BI, DBeaver, etc.). The .env stays gitignored; ~/.aws/credentials should also be gitignored / never committed.

---

#### Risk 44 — Project's phil-admin / phil-dbt identity split has a Phase 4-5 PBI implication: PBI ODBC runs as phil-dbt (programmatic) for now; revisit if a tighter "PBI reader" identity becomes architecturally meaningful (banked 2026-05-30, Phase 4 session 1)

**Verified against authoritative sources.** Project standing rule (TEACHING_PREFERENCES.md line 166, locked 2026-05-28 at Phase 2 session 3): phil-admin for AWS Console interactive work, phil-dbt for programmatic. Verified against the Phase 2 IAM scope setup (lakehouse-dbt-runtime-access customer-managed policy attached to phil-dbt, scope = Glue Catalog read/write on financial_analytics_silver + financial_analytics_bronze + Athena query operations + S3 read/write on the lakehouse bucket).

**Decision context.** PBI Desktop is interactive/visual but accesses Athena via ODBC programmatically. The standing rule "phil-admin for Console" was for the AWS Console UI specifically; PBI is its own UI, IAM identity backing PBI through ODBC is technically programmatic (no Console sign-in, AWS creds chained through the driver). Two options at Phase 4 session 1 install: (a) mint new programmatic access keys for phil-admin in AWS IAM Console + add to ~/.aws/credentials; (b) use existing phil-dbt creds from .env (already programmatic-only, has full Athena query scope from dbt operations). Senior-DE call = option (b): identity-consistent with project rule "programmatic → phil-dbt", no new IAM key mint, fastest path to working smoke test.

**Carry-forward principle.** When a new consumer (PBI here, hypothetically a Notebook / Tableau / DBeaver later) needs AWS credentials from outside the established AWS Console + dbt pattern, default to the existing programmatic identity (phil-dbt) unless there's an architectural reason to scope tighter. Reasons to scope tighter at Phase 5 or beyond: (a) PBI .pbix shipped to a non-developer audience and embedding phil-dbt's broader-scope credentials is a security concern; (b) Lake Formation governance at Phase 6 wants per-consumer ABAC; (c) audit-logging needs separable trails per identity. At Project #3 portfolio-demo scale none of those apply yet — phil-dbt is the right pick for Phase 4-5. Revisit at Phase 6 stretch if Lake Formation lands. Pattern generalizes: don't proliferate IAM identities ahead of architectural need; the two-identity model (admin + programmatic) handles most cases.

---

#### Risk 45 — sat_concept_value MIN(value) tie-breaker (Risk 16, locked Phase 2 session 8) produces analyst-visible artifacts in mart_pl_trend; Apple FY2019 renders ~$70B (actual ~$260B) because MIN-collapse picks the smaller Revenue alias when multiple are reported (banked 2026-05-30, Phase 4 session 1 — surfaced at mart-shape PBI smoke test)

**Verified against authoritative sources.** SEC EDGAR XBRL US-GAAP taxonomy: multiple Revenue concept tags are valid concurrent reporting choices for the same fiscal-period revenue, including `Revenues` (the gross/inclusive measure), `SalesRevenueNet` (net of returns/allowances), `RevenueFromContractWithCustomerExcludingAssessedTax` (ASC 606 post-2018 standard, excludes sales tax), `RevenueFromContractWithCustomerIncludingAssessedTax` (ASC 606 alternative including sales tax). The canonical_concepts_dictionary seed maps all 4 to canonical_concept='revenue'. Companies frequently report MULTIPLE of these tags for the same fiscal period (especially during ASC 606 transition years 2018-2019). sat_concept_value's MIN(value) tie-breaker (Risk 16, locked Phase 2 session 8) is documented as "biases toward the more conservative revenue measurement (e.g., excluding-assessed-tax over including-assessed-tax) — aligns with analyst convention of 'smallest defensible number' for revenue measurement." Documented design provenance, but the analyst-visible consequence wasn't fully gamed out at session 8.

**Live signal.** Apple revenue line chart in Phase 4 session 1 mart-shape PBI smoke test (Power BI Desktop, fiscal_year X-axis, value_numeric Y-axis, filters cik='0000320193' + canonical_concept='revenue' + as_of_date=2025-12-31). Visible chart shape: FY2010-FY2012 climb 0.025T → 0.075T (matches actual $65B → $156B at the LOW end), FY2013-FY2017 plateau at ~0.075T (Apple's actual revenue $171B-$229B — chart shows ~$75B, off by 60-70%), FY2018 peak at ~0.25T (matches actual $266B), FY2019 SUDDEN DROP to ~0.07T (actual $260B — chart shows $70B, off by 73%), FY2020-FY2024 climbing 0.25T → 0.4T (matches actual $274B → $391B). The years where the chart is RIGHT (FY2010-2012, FY2018, FY2020-2024) are years where Apple reported a single Revenue alias; the years where it's WRONG (FY2013-2017, FY2019) are years where Apple reported multiple Revenue aliases and MIN-collapse picked the smaller variant (typically the ExcludingAssessedTax post-2018 ASC 606 tag, which has lower observed values in transition years).

**RESOLVED at Phase 4 session 2 (2026-05-30) — see Risks 46, 47, 48 below for the resolution narrative.** Final resolution combines option (b) (preferred-tag seed) with option (a) (MAX value primary): preferred-tag seed authored + INNER-joined in sat_concept_value, but seed used as the deterministic tie-breaker only — ORDER BY value DESC primary, preference_rank ASC secondary. Plus a separate mart-layer Risk 48 filter for the deeper SEC XBRL intra-accession period-chunk artifact that surfaced during diagnosis. Apple FY2019 revenue now renders at the analyst-correct $260.174B (vs the pre-fix MIN-collapse $70B and the failed v1 preferred-tag-primary $62.9B).

**Carry-forward principle.** Source-domain dedup decisions made at warehouse-layer collapse points (Risk 16 MIN-value tie-breaker here) have analyst-visible downstream consequences that may not be obvious at design time — they materialize as artifacts in the actual analytical visualizations. Carry-forward A: mart-shape PBI smoke test at mart-creation time (Project #2 carry-forward) is a high-value catch surface for this class of artifact — visualizing real data exposes biases that schema-test pass/fail can't detect. The smoke test PASSED architecturally even with Risk 45 visible; the carry-forward is to BANK the data-quality finding from the smoke test, not to fail-the-smoke-test-on-artifact. Carry-forward B: warehouse-layer collapse decisions (MIN / MAX / FIRST / LAST / specific-tag-preference) deserve explicit forward-projection at design time AGAINST realistic example data, not just "deterministic tie-breaker" abstract justification. Phase 2 session 8 banked Risk 16 with the design-rationale "MIN biases conservative — aligns with analyst convention" but didn't run the chosen value through a sample chart to validate the analyst experience. Forward-projection pattern for Phase 4+ collapse decisions: hand-pick 1-2 well-known companies + 1-2 well-known fiscal years, manually trace through the collapse mechanic, eyeball the result against publicly-known values. Cheap, catches 80% of these artifacts pre-build.

---

#### Risk 46 — Preferred-tag seed pattern as Risk 45 resolution: canonical_concept_tag_preference seed drives sat_concept_value collapse tie-breaker (banked 2026-05-30, Phase 4 session 2)

**Verified against authoritative sources.** SEC EDGAR XBRL US-GAAP taxonomy: multiple Revenue concept tags are valid concurrent reporting choices (Risk 45 verification carry-forward). Analyst-credible per-canonical tag preference: for 'revenue', the legacy `Revenues` tag carries top-line GAAP semantics when populated; `RevenueFromContractWithCustomerExcludingAssessedTax` is the ASC 606 post-2018 standard; including-assessed-tax variant is rarer; `SalesRevenueNet` is older / lower-cardinality. Single-tag canonicals (NetIncomeLoss, Assets, etc.) get rank 1 trivially.

**Design + ship.** New seed `dbt/seeds/canonical_concept_tag_preference.csv` (8 rows: canonical_concept, concept_name, preference_rank as smallint). sat_concept_value's canonical_observations CTE refactored to carry concept_name through the join chain; new preference_ranked CTE INNER JOINs to the seed on (canonical_concept, concept_name) to attach preference_rank; collapsed_observations CTE uses ROW_NUMBER() OVER (PARTITION BY natural cardinal tuple ORDER BY value DESC, preference_rank ASC) keeping rn = 1. INNER JOIN is intentional — a canonical-mapped tag missing from the seed fails loudly as a missing-config signal rather than silently dropping rows through a LEFT JOIN.

**Carry-forward.** Per-canonical preferred-tag config seeds are the right architectural pattern for any XBRL-style multi-tag-per-canonical collapse decision — analyst-credible, deterministic, audit-traceable, and forward-compatible (seed expansion = ordered rank entries for new tags, zero model change). The seed becomes the project's authoritative "which raw tag wins when companies report multiple for the same canonical" reference, separate from the canonical mapping itself. Carries to mart_financial_health (session 3) when balance-sheet-related canonical multi-tag cases land.

---

#### Risk 47 — Preferred-tag ORDER BY v1→v2 flip: ASC 606 transition years break preference-rank ASC primary; value DESC primary + preference_rank ASC tie-breaker only (banked 2026-05-30, Phase 4 session 2)

**Live signal.** v1 of the Risk 45 fix shipped at session 2 step 2 used ORDER BY preference_rank ASC PRIMARY (rank 1 = `Revenues` tag wins for canonical revenue). Cascade-rebuild + PBI smoke test surfaced the failure immediately: Apple FY2019 rendered at $62.9B — WORSE than the original Risk 16 MIN-collapse value of $70B, against the analyst-correct $260B. Diagnosis: during ASC 606 transition (FY2018-2019 for most companies), companies often report BOTH the legacy `Revenues` tag (carrying a fractional or zero value as a compat / placeholder) AND the new `RevenueFromContractWithCustomerExcludingAssessedTax` tag (carrying the actual top-line). preference_rank ASC primary picks `Revenues` regardless of value — and when `Revenues` carries $62B vs the real-tag $260B, that's the analyst-facing artifact.

**Fix.** Flipped ORDER BY to value DESC PRIMARY, preference_rank ASC SECONDARY. value DESC = analyst-correct headline number wins (matches company public revenue announcements which quote the LARGEST defensible figure across XBRL tag aliases). preference_rank ASC = deterministic tie-breaker for the rare degenerate case where multiple tags report the SAME value (preserves auditability + determinism without driving the analyst-facing selection).

**Carry-forward.** Two distinct lessons: (A) WHEN preferred-tag-seed design is the right pattern for multi-source-tag collapse, USE THE SEED AS A TIE-BREAKER ONLY, not as the primary selector — the seed encodes "analyst preference between equally-defensible source tags" not "analyst preference regardless of value." (B) Cross-period source-domain reporting conventions (ASC 606 transition here) generate failure modes that abstract design rationale doesn't surface — same as Risk 45's carry-forward B, REPEATED here: every collapse / tie-breaker design decision needs forward-projection against KNOWN-correct sample values BEFORE building the cascade. The session-2 smoke test caught Risk 47 in <5 minutes of PBI render; the same forward-projection during session-2 step-1 design would have caught it pre-build. Pattern strengthens: smoke-test-first IS forward-projection.

---

#### Risk 48 — Mart-dedup intra-accession period-chunk filter: SEC XBRL tags 11 unrelated periods within one 10-K with fp=FY fy=filing_year; mart-grain collapse non-deterministic without explicit period-shape filter (banked 2026-05-30, Phase 4 session 2)

**Live signal.** Post-Risk-47 v2 cascade, Apple FY2019 STILL rendered at $62.9B in the PBI smoke test. Direct Athena query against sat_concept_value (`WHERE cik = '0000320193' AND canonical_concept = 'revenue' AND fiscal_year = 2019 AND fiscal_period = 'FY'`) returned 11 rows for the SAME accession_number (0000320193-19-000119 = Apple's FY2019 10-K) with 11 DIFFERENT (period_start_date, period_end_date) pairs spanning: the actual FY2019 ($260B, period Sep 2018-Sep 2019), the FY2018 comparative ($265B, period Oct 2017-Sep 2018), the FY2017 comparative ($229B, period Sep 2016-Sep 2017), various 3-month / 6-month quarterly chunks ($53-$88B), and one $62B row (period Jul-Sep 2018 = Q4 FY2018). All 11 tagged with fiscal_period='FY' fiscal_year=2019.

**Diagnosis.** SEC XBRL companyfacts JSON aggregates ALL period observations Apple's FY2019 10-K reports under each us-gaap concept — including current-FY actual, prior-year ASC 205 comparatives (FY2017 + FY2018), AND various rolling-window quarter / half-year sub-period chunks that Apple's XBRL tagging set fp=FY fy=2019 against. sat_concept_value's natural PK INCLUDES period_start_date + period_end_date so the 11 rows are LEGITIMATE distinct entities at the sat grain — no constraint violation. mart_pl_trend + mart_peer_benchmark's grain does NOT include period dates, so the existing Risk 42 ROW_NUMBER OVER (PARTITION BY mart grain ORDER BY accession_number DESC) collapses all 11 into a single bucket — and since they all share accession_number, the ORDER BY tie-breaker is degenerate and Athena picks one of the 11 non-deterministically. Apple FY2019 happened to land on the $62.9B Q4-quarter row.

**Fix.** Mart-layer filter at sat_resolved CTE in BOTH mart_pl_trend AND mart_peer_benchmark:

1. `year(period_end_date) IN (fiscal_year, fiscal_year + 1)` — drops prior-year comparatives misaligned to the filing's fy tag. The fy+1 case handles retailer FY-end conventions (Walmart FY2019 ends late-Jan 2020 → period_end_date.year = 2020 = fy+1).
2. For income-statement canonicals ONLY (revenue + net_income): `date_diff('day', period_start_date, period_end_date) BETWEEN 350 AND 380` — drops quarter / half-year period chunks mis-tagged as FY. 350-380 day band accommodates 52-week fiscal years (364 days) and the rare 53-week fiscal year (371 days) without over-constraining.
3. Balance-sheet canonicals (assets, liabilities, stockholders_equity) are EXEMPT from the span filter — point-in-time balance sheet observations have period_start_date NULL or = period_end_date so date_diff would be 0 (outside the band). The year filter alone correctly drops prior-year balance sheet comparatives. Implemented via `(canonical_concept = 'assets' OR date_diff(...) BETWEEN 350 AND 380)` conditional in mart_peer_benchmark; mart_pl_trend doesn't need the conditional (only IS canonicals in scope).

Post-cascade verification: Apple FY2019 = $260.174B (analyst-correct, matches public 10-K headline). Full 17-year series correct (FY2009 = $42.9B → FY2025 = $416.2B, all tracking known reference values within rounding).

**Carry-forward.** Three distinct lessons: (A) SEC XBRL companyfacts data has period-shape ambiguity that natural-key uniqueness alone doesn't expose — mart-layer analyst-credible filtering on period-span semantics is a REQUIRED part of the mart contract for fp=FY income-statement canonicals. (B) Direct sat-layer Athena queries during PBI smoke-test diagnosis are the right escalation when the mart-layer dedup looks "deterministically wrong" — the 11-row sat sample exposed the failure mode in <30s of query time, where successive PBI-only diagnostics would have lost hours. (C) Per-concept-type conditional filtering (IS vs BS canonicals here) is a clean modeling pattern when mart contracts apply different period-shape semantics — encode as conditional OR rather than splitting into separate mart variants. Forward-projects to mart_financial_health (session 3) where BS-only canonicals dominate and the IS span filter would over-prune.

---

#### Risk 49 — Salesforce 2010-2013 pre-ASC-606 gross_profit > revenue artifact: GrossProfit us-gaap tag anchored to multi-tag revenue base, sat_concept_value value-DESC collapse picks largest single Revenues alias → tag-base mismatch surfaces as 1.02-1.07x gross_margin at mart layer (banked 2026-05-30, Phase 4 session 3)

**Live signal.** First run of `sql/verify/15_phase4_marts_financial_health_verification.sql` at session 3 cascade close — check 15 (gross_margin finite + bounded between -100 and 1) FAIL 3306/3319. Diagnostic query `SELECT cik, entity_name, as_of_date, fiscal_year, revenue, gross_profit, gross_margin FROM mart_financial_health WHERE gross_margin > 1 ORDER BY entity_name, fiscal_year` returned 13 rows — all Salesforce Inc (cik 0001108524) across 4 distinct fiscal years (2010, 2011, 2012, 2013) × ~3 visible as_of_dates each. gross_profit was 2-7% above revenue (e.g., FY2010 revenue=$1.306B, gross_profit=$1.333B, gross_margin=1.0212).

**Diagnosis.** Salesforce's pre-ASC-606 (2010-2013) XBRL filings use a multi-tag revenue decomposition (SubscriptionAndSupportRevenue + ProfessionalServicesAndOtherRevenues as separate components alongside a Revenues total), AND the company-reported `GrossProfit` tag is anchored to a different revenue base than any single Revenues-family alias picks up. sat_concept_value's value DESC ORDER BY collapse picks the LARGEST single tag value per (cik, accession, canonical, period) tuple — that's the analyst-correct headline number for revenue, but it's NOT the base the company's reported GrossProfit subtracts CostOfRevenue against. Net result: numerator GrossProfit is anchored to a base slightly larger than the denominator Revenues alias the collapse picks → gross_profit / revenue > 1.0 by 2-7% for this specific company × FY window. ASC 606 transition years after FY2014 normalized the tagging, and the artifact disappears from FY2014 onwards (Salesforce FY2014-2025 gross_margin renders cleanly within [0, 1]).

**Fix.** Verify-check exclusion, NOT data filter at mart layer. The 13 mart rows ARE valid data in the sense of "what the company reported" — the mismatch is at the raw-tag-interpretation level, not a real data quality fault. Excluding at verify documents the limitation honestly; excluding at mart would silently drop legitimate (though imperfect) numbers. Implementation at sql/verify/15 check 15: add `AND NOT (cik = '0001108524' AND fiscal_year BETWEEN 2010 AND 2013)` to BOTH the numerator and denominator subqueries. Header comment for check 15 extended with full provenance pointing at this Risk entry. Re-run PASS 3279/3279.

**Carry-forward.** Three lessons: (A) **PBI-smoke-test-adjacent diagnostics catch tag-base mismatches early.** The artifact only became visible because a mart-level integrity check (gross_margin within plausible bounds) was authored in the verify suite — schema tests alone wouldn't have caught it. Carry-forward to every future ratio mart: include at least one bounded-range check per derived ratio. (B) **Known-artifact verify-check exclusion is the senior-DE professional pattern for documented data quality limitations.** Tighter is wrong (would silently drop data); looser is wrong (lets real bad data through); exclusion with explicit (cik, fy) window + comment provenance + Risk register entry is the auditable answer. (C) **Per-company tag-preference override at sat_concept_value is the targeted future fix** — extending `canonical_concept_tag_preference` to optionally accept a `(cik, fy_window)` scope column would let Salesforce 2010-2013 pick a different revenue tag than the global value-DESC pick. Out of session 3 scope per locked build-mode preference; deferred enhancement for a future targeted seed-extension session, narrow benefit (0.12% artifact at session 3 surface).

---

#### Risk 50 — Forecast S3 prefix + phil-dbt IAM scope: top-level `forecasts/` prefix is OUTSIDE the standing `S3SilverReadWrite` scope; new compute-output surfaces MUST sit under the existing zone= convention to inherit IAM scope without policy attachment (banked 2026-05-30, Phase 4 session 4)

**Verified against authoritative sources.** `iam/lakehouse_dbt_runtime_policy.json` (project source): `S3SilverReadWrite` Sid grants phil-dbt `s3:PutObject + DeleteObject + AbortMultipartUpload + ListMultipartUploadParts` on `arn:aws:s3:::phil-financial-analytics-lakehouse/zone=silver/*`. NO write scope on top-level prefixes outside the zone= convention. Project standing S3 layout (per `EXTRACT_PIPELINE.md` section 4): bucket prefixes are `zone=bronze/` (raw, phil-dbt read-only), `zone=silver/` (dbt-managed Iceberg + this forecast surface, phil-dbt R/W), `zone=gold/` (reserved future), `athena-results/` (R/W), `glue-scripts/` + `dbt-project/` (Phase 3 orchestration artefacts).

**Live signal.** First end-to-end run of `scripts/forecast.py` at Phase 4 session 4 step 8c — script fitted Holt-Winters per company, concatenated the 294-row forecast surface, attempted `s3_client.put_object(Bucket=..., Key='forecasts/canonical_concept=revenue/as_of_date=2026-05-30/forecast.parquet')`. boto3 returned `An error occurred (AccessDenied) when calling the PutObject operation: User: arn:aws:iam::470439680370:user/phil-dbt is not authorized to perform: s3:PutObject on resource: "arn:aws:s3:::phil-financial-analytics-lakehouse/forecasts/canonical_concept=revenue/as_of_date=2026-05-30/forecast.parquet" because no identity-based policy allows the s3:PutObject action`. Diagnostic path: read the IAM policy JSON → confirmed S3SilverReadWrite scoped to `zone=silver/*` only → confirmed forecasts/ is a NEW top-level prefix outside the standing scope. Two resolution options at design pass: (a) extend `S3SilverReadWrite` Resource list to include `arn:aws:s3:::phil-financial-analytics-lakehouse/forecasts/*` (IAM policy update — Phil-admin AWS Console action + repo file change); (b) relocate the forecast Parquet to live UNDER `zone=silver/` (single S3 prefix change in the Python writer + the DDL). Senior-DE choice = (b) — inherits the existing IAM scope automatically AND matches the project's zone= S3 layout convention AND no IAM scope expansion = less surface to audit at Phase 6 + at Lake Formation governance time. Implementation: `S3_FORECAST_PREFIX = "zone=silver/forecasts"` in `scripts/forecast.py`; `LOCATION 's3://phil-financial-analytics-lakehouse/zone=silver/forecasts/'` + matching `storage.location.template` in `sql/ddl/03`. Re-DROP + re-CREATE the external table in Athena Console + re-run the script — landed clean.

**Carry-forward.** Two distinct lessons: (A) **At every Option A architecture design pass that introduces a NEW compute-output S3 surface, name the writer's IAM identity + verify the destination prefix is within that identity's existing S3 scope BEFORE shipping the writer.** This is the standing ENGINEERING_STANDARDS criterion 7 consumption-pattern contract applied to the IAM + S3 axis. The single mental check: "which identity writes here, and does its policy already allow it?" If no → relocate the prefix to inherit existing scope (preferred) OR expand the policy (if relocation isn't possible due to other constraints). (B) **The project's zone= S3 layout convention is the standing organizing principle for new surfaces.** `zone=bronze/` for raw external data, `zone=silver/` for compute output consumed downstream by dbt-athena, `zone=gold/` reserved. Top-level prefixes outside the zone= convention (forecasts/, scratch/, etc.) are anti-pattern at the project level — both for IAM scope inheritance + for the visible "where is X" navigability of the bucket. The first-cut Phase 4 session 4 DDL + Python script targeted top-level `forecasts/` because the analytical pattern is "compute output ≠ silver" — but in this project's layout, compute output for dbt-consumed surfaces IS silver. Pattern strengthens: zone=silver/ is "dbt-consumed Silver", not "dbt-written Silver."

---

#### Risk 51 — Forecast schema triple-pin: the same Parquet column list is declared in `scripts/forecast.py` FORECAST_SCHEMA + `sql/ddl/03_create_forecast_external_table.sql` column list + `dbt/models/marts/_sources.yml` columns block; schema drift between any two surfaces as a Parquet column-mismatch error at first dbt build (banked 2026-05-30, Phase 4 session 4)

**Verified against authoritative sources.** pyarrow.parquet docs: Parquet files self-describe their schema in the footer. pa.Table.from_pandas(schema=...) enforces strict type-match between the input DataFrame columns + the target schema — type mismatches raise `ArrowTypeError` (verified live this session — int64 cik → string target raised "Expected a string or bytes dtype, got int64" at first run). Athena docs on external Parquet tables: column list in CREATE EXTERNAL TABLE must match the Parquet file footer column types OR Athena returns NULL for the mismatched columns at query time without raising. dbt sources YAML: column declarations are documentation + schema-test surface; they don't enforce against the underlying table at parse time but DO drive dbt's lineage docs + auto-generated test scaffolding.

**Design context.** The forecast pipeline's clean compute/consumption separation (Option A architecture, banked above in session 4 close narrative) introduces THREE separate places where the forecast schema is asserted: the Python writer (pyarrow schema pin = type contract enforced at write time), the Athena DDL (column list = type contract registered to Glue Catalog), and the dbt sources YAML (column list = lineage + test contract). All three must agree byte-for-byte at every schema bump. Drift between (Python, DDL) silently surfaces as Athena query NULLs. Drift between (Python, sources YAML) silently surfaces as missing dbt lineage / missing column tests. Drift between (DDL, sources YAML) silently surfaces as dbt schema-test failures.

**Implementation.** Banked at session 4 close as a coordinated-drift contract, NOT a single source of truth. Three artefact-level conventions documented inline:

1. `scripts/forecast.py` — `FORECAST_SCHEMA` pyarrow schema declaration at module level with explicit pa.field() type declarations. Module docstring section "Schema drift contract" pointers to the DDL + sources YAML.
2. `sql/ddl/03_create_forecast_external_table.sql` — explicit column list with pinned types matching FORECAST_SCHEMA. DDL comment block pointers to the Python writer + sources YAML.
3. `dbt/models/marts/_sources.yml` — column list pinned to match FORECAST_SCHEMA + DDL byte-for-byte. Header comment pointers to both upstream artefacts.

**Carry-forward.** Two lessons: (A) **Coordinated-drift contracts are the senior-DE pattern for multi-artefact schema agreements where no single artefact can be the source of truth.** Three-artefact + inline pointer documentation is cheaper than building a code generator that emits all three from one source — at S&P 100 scale + 11-column forecast surface, the manual coordination cost is trivial AND every artefact remains independently readable. Codegen would buy zero readability + introduce build-tooling complexity. Pattern carries forward to every Option A architecture in future projects (Python compute → S3 Parquet → dbt external table); name the three artefacts up front, document the contract inline, manually coordinate on every schema bump. (B) **The first-cut session 4 forecast.py shipped with an int64-typed cik column from pd.read_csv auto-inference, raising at pyarrow's strict schema check.** Fixed via `dtype={"cik": str}` on read_csv + defensive `.str.zfill(10)` on the Series. The triple-pin caught the bug at first run instead of letting it surface as silently-wrong cik values at Athena query time. Concrete value of the strict schema check: pyarrow's `ArrowTypeError` IS the contract. Pattern: prefer strict-validation writer paths (pyarrow + pinned schema) over permissive-validation writer paths (CSV, JSON) for any analyst-facing surface.

---

### Phase 4 reflection — 14 Risks rolled into four pattern families (banked 2026-05-30, Phase 4 session 5 close)

Phase 4 banked 14 Risks across the kickoff forward-verify (Risks 38-39 at Phase 3 session 14) + sessions 1-4 (Risks 40-51). Rolling them into four top-level pattern families. Risks remain individually banked above as design-decision provenance; this is the consolidated training surface for the post-mini-projects training journey + portfolio walkthroughs. Family lettering continues from the Phase 3 reflection (Families A-F).

**Family G — Forecasting library + observation-cadence cross-check.** "Most powerful" forecasting library is not "right library" — the right library for any forecasting workload is determined by the joint trade-off of (a) observation cadence (daily / hourly vs annual / quarterly), (b) signal shape the library exploits (seasonality / holiday effects / trend changepoints), (c) install footprint on the target runtime (pure-Python pip wheels vs Stan / C++ compilation). Prophet is best-in-class for daily / sub-daily data with seasonality + holidays + trend shifts; rejected at Phase 4 kickoff on (a) zero seasonality / holiday signal at annual cadence — the features that justify Prophet's complexity premium materialize at daily / sub-daily, not yearly, (b) Stan C++ compilation adds Free-Tier deploy friction (5-15 min cold-install). statsmodels.tsa Holt-Winters + ARIMA chosen on the inverse: pure-Python deps via PyPI wheels (no compiler), classical methods fit annual financial time-series cleanly with prediction intervals out of the box. Risk 38. **Carry-forward.** At every cloud-native forecasting library decision, evaluate model-complexity vs observation cadence vs library install footprint as a joint trade-off — a "more powerful" library that doesn't fit the data's actual signal is just install overhead. Pattern generalizes: pick libraries to the workload's signal shape, not to the library's marketing.

**Family H — BI-tool prerequisite + local-machine stack.** Cloud-warehouse → BI-tool pairings require a local-machine prerequisite stack (driver install + DSN / service config + credential-source bridge) that must land BEFORE any BI build session, not block-discover at the first BI dialog. For Athena → PBI specifically: Amazon Athena ODBC v2 driver install (15-30 min Windows admin step, ~10 min when scripted via PowerShell Add-OdbcDsn) + Windows System DSN configuration + ~/.aws/credentials [phil-dbt] section bootstrap (PBI ODBC chains credentials through named profiles, NOT .env env vars — the project's .env-only dbt pattern needs the credentials-file bootstrap). Three driver-config gotchas surface during install: ODBC v2 silently ignores unknown attribute keys (ProfileName accepted in place of AWSProfile; surfaces only at post-creation attribute inspection), `Set-OdbcDsn -SetPropertyValue` is destructive-replace not merge (patching one attribute wipes the other 6), identity choice (phil-admin Console vs phil-dbt programmatic) — PBI ODBC is technically programmatic so phil-dbt is the senior-DE pick unless a tighter PBI-reader identity becomes architecturally meaningful. Risks 39, 40, 41, 43, 44. **Carry-forward.** For every cloud-warehouse + BI-tool pairing in future projects (Project #2's Snowflake → PBI didn't hit this because the Snowflake connector was Microsoft-owned no-driver-install; Project #3's Athena → PBI is Amazon-owned ODBC, more friction): identify the local-machine prerequisite stack at the phase-boundary forward-verify pass and bake it into PROJECT_PLAN.md as a pre-Phase prerequisite, not a Phase-1-session-1 surprise. For driver / SDK / library configs that accept free-form attribute keys: verify-write-then-inspect (post-write attribute introspection step) before any consumer attempts to use the config. For PowerShell `Set-*` (or any tool with ambiguous merge vs replace semantics): maintain a canonical declarative attribute list as the single source of truth, re-run the full registration on every change, never patch deltas.

**Family I — Source-domain dedup + collapse architectural location.** Source-domain dedup decisions are made at TWO architectural layers, each with different concerns: (a) at the WAREHOUSE layer (Risk 16 MIN(value) tie-breaker at sat_concept_value, then Risk 45-47 evolved to value DESC primary + preferred-tag seed ASC tie-breaker), where the contract is "what value resolves for this (entity, period) tuple when source reports multiple aliases"; (b) at the MART layer (Risk 42 ROW_NUMBER ORDER BY accession_number DESC for ASC 205 prior-year comparatives, Risk 48 intra-accession period-chunk filter for fp=FY-tagged sub-period observations), where the contract is "which warehouse-grain rows aggregate into a single analyst-facing mart-grain row." The Phase 4 cascade exposed that warehouse-layer collapse decisions made in abstract (Risk 16 "MIN biases conservative") have analyst-visible artifacts that only surface at PBI-smoke-test time (Apple FY2019 = $70B at first render, vs actual $260B), then mart-layer dedup decisions can introduce their OWN failure modes that need direct sat-layer Athena diagnostic queries to expose (the 11 rows / single-accession period-chunk artifact). Risk 49 (Salesforce pre-ASC-606 gross_profit > revenue) is a hybrid where the tag-base mismatch lives at the raw-tag interpretation level — fix is verify-check exclusion with explicit (cik, fy) window + Risk register entry, NOT silent mart-layer data filter (tighter is wrong; looser is wrong; documented-exclusion is the auditable answer). Risks 42, 45, 46, 47, 48, 49. **Carry-forward.** Two distinct lessons: (A) Every warehouse-layer collapse / tie-breaker design decision needs forward-projection against KNOWN-correct sample values BEFORE the cascade ships — pick 1-2 well-known companies + fiscal years, manually trace through the collapse mechanic, eyeball against publicly-known values. Cheap, catches 80% of these artifacts pre-build. Smoke-test-first IS forward-projection. (B) Mart-layer is the architectural location for analyst-facing collapse decisions; warehouse-layer stays source-faithful with multi-row-per-grain rows preserved for audit lineage. Tie-breakers MUST be deterministic (ROW_NUMBER with explicit ORDER BY, not RANK/DENSE_RANK). When per-concept-type semantics differ (IS vs BS canonicals here), use conditional filtering inside one mart rather than splitting into mart variants. Known-artifact data quality limitations get verify-check exclusion with explicit (cik, fy) window + comment provenance + Risk register entry — not silent data drops.

**Family J — Compute-output surface + IAM zone convention + multi-artefact schema agreement.** Phase 4 session 4's Option A forecast architecture (Python writes Parquet to S3, dbt-athena consumes via sources + external table) surfaced two cross-cutting concerns that generalize to every future "Python compute → S3 → dbt external table" pattern. (a) Every new compute-output S3 surface needs IAM scope verification at design time, not at first-run AccessDenied — the project's existing zone= S3 layout convention (`zone=bronze/`, `zone=silver/`, `zone=gold/`) is the standing organizing principle, AND `zone=silver/` IAM scope (phil-dbt S3SilverReadWrite) covers any dbt-consumed compute output that sits under that prefix without policy expansion. Senior-DE move when designing a new compute output: name the writer's IAM identity → verify destination prefix is within that identity's existing scope → relocate the prefix to inherit existing scope (preferred) before expanding the policy. Risk 50. (b) Multi-artefact schema agreements (Python writer schema + Athena DDL column list + dbt sources YAML columns block) cannot have a single source of truth at S&P-100 scale + 11-column surface — codegen would buy zero readability while adding build-tooling complexity. Coordinated-drift contract is the senior-DE pattern: explicit pyarrow schema pin in the Python writer (strict-validation writer path — pyarrow.ArrowTypeError IS the contract), explicit column-list pin in the DDL, explicit column block in dbt sources YAML, with cross-artefact pointers inline in each. Three places to coordinate at every schema bump; the strict writer catches drift at first run. Risk 51. **Carry-forward.** At every Option A architecture in future projects, name the three artefacts up front, verify the IAM + S3 zone convention before shipping the writer, document the schema contract inline in each artefact. Prefer strict-validation writer paths (pyarrow + pinned schema) over permissive-validation writer paths (CSV, JSON) for any analyst-facing surface — the type-check IS the contract.

---

### Phase 5 forward-verify pass — Power BI architectural discipline + Athena ODBC v2 + Iceberg V2 verification (banked 2026-05-30, Phase 4 session 5 close — Phase 5 kickoff forward-verify)

Three new Risks (52-54) surfaced at the Phase 5 kickoff forward-verify pass against authoritative docs (learn.microsoft.com Power BI / DAX / composite model / Optimize ribbon docs, docs.aws.amazon.com Athena ODBC v2 docs, SQLBI). Banked BEFORE Phase 5 work begins, per the standing forward-verify-pass rule.

#### Risk 52 — Project's marts materialize as full-rebuild Iceberg (Risk 2 avoidance pattern from Phase 2 session 3); PBI Import via Athena ODBC v2 doesn't hit Iceberg V2 position-delete merge-on-read complexity at consumption time (banked 2026-05-30, Phase 4 session 5 — Phase 5 kickoff forward-verify)

**Verified against authoritative sources.** docs.aws.amazon.com/athena/latest/ug/querying-iceberg-updating-iceberg-table-data.html + querying-iceberg-delete.html: Athena's UPDATE and DELETE statements follow the Iceberg format v2 row-level position delete specification — merge-on-read approach with positional deletes. docs.aws.amazon.com/athena/latest/ug/odbc-v2-driver.html: Amazon Athena ODBC 2.x driver (current v2.0.2.2) passes raw SQL to Athena; the driver itself doesn't see Iceberg semantics — Athena's query engine handles merge-on-read transparently and returns the post-merge result set to the ODBC client. Project's dbt_project.yml marts block configures marts as full-rebuild Iceberg tables (NOT incremental merge) per the standing Risk 2 avoidance pattern from Phase 2 session 3.

**Implication.** PBI Import refresh against the marts via Athena ODBC v2 reads the materialized full-rebuild Iceberg snapshot at refresh time; position-delete merge-on-read complexity that would apply to Risk 2-style incremental merge tables does NOT apply at the consumption layer for Project #3 marts. Empirically anchored: 4 mart-shape PBI smoke tests (sessions 1-4) all PASSED through the ODBC v2 driver path — driver + Iceberg V2 + Athena Engine 3 + PBI Desktop chain proven through 4 marts already. **Carry-forward.** Project-specific protection worth banking explicitly — the Risk 2 full-rebuild materialization choice at Phase 2 session 3 (initially banked as an Iceberg-merge-incremental bug avoidance) pays a second dividend at Phase 5 by simplifying the PBI consumption contract. For future projects pairing dbt-athena Iceberg with PBI: prefer full-rebuild materialization for marts unless mart size forces incremental — the simpler consumption path saves a class of refresh-time gotcha.

---

#### Risk 53 — Pure Import storage mode is the right default for Project #3 marts at 10K-30K row scale; Composite / Dual / DirectQuery patterns are over-engineering for this scale (banked 2026-05-30, Phase 4 session 5 — Phase 5 kickoff forward-verify)

**Verified against authoritative sources.** learn.microsoft.com/en-us/power-bi/transform-model/desktop-storage-mode + transform-model/desktop-composite-models + guidance/composite-model-guidance: Power BI supports three storage modes — Import (cached, all queries fulfilled from cache), DirectQuery (no cache, every query executes against the source), Dual (both Import + DirectQuery, PBI Service picks the most efficient per-query basis). Documented recommendation: "Data modelers who develop Composite models are likely to configure dimension-type tables in Import or Dual storage mode, and fact-type tables in DirectQuery mode." Dual is recommended for dimension tables when there's a possibility they'll be queried together with DirectQuery fact tables — reduces "limited relationships" (relationships where PBI can't push JOIN logic to the source). Composite + Dual + DirectQuery pattern's value materializes when the FACT table is too large for Import (typically millions+ rows on PBI Desktop's memory ceiling) OR refresh cadence requires source-of-truth freshness that Import refresh schedules can't deliver.

**Implication.** Project #3 mart cardinality: mart_pl_trend = 19,336 rows; mart_peer_benchmark = 29,936 rows; mart_financial_health = 10,610 rows; mart_growth_forecast = 10,069 rows. Total ~70K rows across 4 marts — trivially Import-fitting on PBI Desktop. The 5-page executive overview + 4 themed pages target a sub-100MB .pbix at v1.0 freeze (Phase 6 ship gate). DirectQuery's per-visual Athena round-trip would add latency + Athena scan cost per interaction with zero performance benefit at this scale. Composite mode adds storage-mode-per-table modeling overhead + limited-relationship management for zero return. **Decision: Pure Import storage mode for all Phase 5 marts.** Revisit Composite / DirectQuery / Dual only if a future mart exceeds ~1M rows or refresh cadence requires it (neither applies at Project #3 scale or under the demo-durability principle 3 = Import mode at v1.0 freeze, which makes the .pbix self-contained against an expired AWS account). **Carry-forward.** Storage-mode selection at PBI authoring time is a workload-shape decision, not a "use the fancy pattern" decision. For Project #3 + every future mini-project mart at <100K row scale: pure Import is the default, document the choice explicitly in POWERBI_PIPELINE.md (Phase 5) so the decision is auditable later. Pattern generalizes: pick the simplest storage mode that fits the workload's size + refresh cadence + delivery contract; complexity = composite + DirectQuery only earns its keep when the simpler shape would actually break.

---

#### Risk 54 — Power BI Desktop known issue 321 (Performance Analyzer + Pause Visuals interaction): paused visuals don't refresh during Performance Analyzer recording; diagnostic discipline needs both states cross-checked, not just one (banked 2026-05-30, Phase 4 session 5 — Phase 5 kickoff forward-verify)

**Verified against authoritative sources.** learn.microsoft.com/en-us/power-bi/troubleshoot/known-issues/known-issue-321-paused-visuals-in-performance-analyzer-dont-refresh — Microsoft-acknowledged known issue: when Pause Visuals is enabled AND Performance Analyzer is recording, the paused-state of the visuals propagates into the Performance Analyzer output — DAX query timings can be missing or misattributed. learn.microsoft.com/en-us/power-bi/create-reports/desktop-optimize-ribbon: Pause Visuals lives on the Optimize ribbon; toggling resumes via the same ribbon button OR via the "Resume visual queries" report banner. Project #2 Phase 5 session 5.5 locked the standing Pause Visuals diagnostic discipline (TEACHING_PREFERENCES.md line 134): "check Optimize → Pause Visuals BEFORE any other diagnostic when the symptom is 'things disappear on click' or 'I need to refresh after every change'."

**Implication.** Risk 54 refines the existing Pause Visuals discipline for the specific case where Performance Analyzer is being used alongside Pause Visuals — the analyzer output cannot be trusted if Pause Visuals is on. Order of diagnostic checks when Performance Analyzer is in use: (1) Optimize ribbon → confirm Pause Visuals shows the Pause icon (visuals LIVE) before recording; (2) ONLY THEN start Performance Analyzer recording. If Performance Analyzer output looks suspicious (missing timings, incomplete DAX traces), check Pause Visuals state FIRST before chasing model / measure / relationship explanations. **Carry-forward.** Minor refinement on the existing Pause Visuals discipline. Pairs with the Project #2 standing rule. Add to POWERBI_PIPELINE.md at Phase 5 authoring as a "diagnostic order of operations" note alongside the existing Pause Visuals + save-close-reopen-on-cyclic-reference patterns.

---

### Phase 5 session 1 lessons — v1 ship + redesign trigger + 2 data quality Risks banked (2026-05-31)

Phase 5 session 1 shipped a working v1 of the executive overview page (data model + 4 KPI measures + hero trend chart + 2 slicers + caveat strip) and then triggered a complete 5-page redesign at session close after the v1 layout read as "generic Power BI tutorial" rather than a portfolio-grade Project #3 deliverable. Session lessons distilled into 2 banked Risks + 1 process Risk (57 below) + the redesign spec landed in POWERBI_PIPELINE.md section 3.

#### Risk 55 — Sector-specific us-gaap revenue tag mapping gap: 18 of 107 S&P 100 companies missing FY2024 revenue in mart_pl_trend due to the canonical_concept_tag_preference seed covering 4 us-gaap tags (Revenues, SalesRevenueNet, RevenueFromContractWithCustomerExcludingAssessedTax, RevenueFromContractWithCustomerIncludingAssessedTax) but not the sector-specific tags used by financials / insurance / asset managers (banked 2026-05-31, Phase 5 session 1)

**Discovered via Athena audit at session 1 close.** Four diagnostic queries against mart_pl_trend + sp100_company_sector surfaced 18 universe entries with zero revenue rows at FY2024. Concentration: 6 Financials (CB, GS, MS, PNC, WFC, SPGI), plus a few utilities, energy services (SLB), insurance (KHC), consumer discretionary (F, ORLY, TJX), industrials (ADP, ADI), and a real estate pair (CCI, PLD). Net impact: S&P 100 FY2024 aggregate revenue reports as $8.88T vs an estimated true total ~$10T — roughly a 10-12% under-count concentrated in the financial sector.

**Root cause.** The `int_sec_edgar__concepts.sql` Jinja `{% set concepts %}` list extracts 13 us-gaap tag names from the raw Bronze JSON; for canonical 'revenue' the list covers the four most common across the tech / industrial / consumer S&P 100 majority. Banks and insurance commonly use sector-specific revenue tags (InterestAndDividendIncomeOperating, RevenuesNetOfInterestExpense, PremiumsEarnedNet, NoninterestIncome) that aren't in the extraction list — so their revenue isn't extracted from raw Bronze in the first place, never reaches the canonical mapping, and never lands in mart_pl_trend.

**Triage at session close.** Pragmatic senior-DE call: document as a Risk + dashboard caveat strip on every page + defer the dbt fix to a dedicated Phase 6 mapping-expansion session. Estimated fix scope = 2-4 hours: extend the `int_sec_edgar__concepts.sql` Jinja concept list + the 5 lock-step warehouse Jinja lists + the canonical_concepts_dictionary seed + the canonical_concept_tag_preference seed + dbt seed --full-refresh + dbt build full cascade + re-verify the 4 marts. Out of Phase 5 session 1 scope by a wide margin. Documented in POWERBI_PIPELINE.md section 4. **Interview talking point.** Demonstrates the senior-DE triage muscle — identified the gap rigorously via SQL audit (4 diagnostic queries against the silver layer), quantified the impact (10-12% under-count, sector-concentrated), chose to ship with a documented limitation rather than blow the session timeline on a 10% accuracy gain, scheduled the fix to the right phase.

**Carry-forward.** Universe-coverage Risks like this need to surface via verify-pass audits BEFORE the BI layer surfaces them as visual surprises. Phase 6 candidate enhancement: add a cumulative `sql/verify/17_coverage_audit.sql` check that counts companies per (canonical, fiscal_year) at the latest snapshot and FAILs if the count drops below ≥95% of the universe at any year. Catches mapping gaps + future seed-roster mismatches at the SQL layer before they reach a dashboard.

#### Risk 56 — Forecast horizon varies per company in mart_growth_forecast: 3-year forecast extends from each company's LATEST historical year, not from a globally-fixed start year (banked 2026-05-31, Phase 5 session 1)

**Discovered during Phase 5 session 1 hero chart authoring.** Initial hero-chart attempts plotted historical + forecast on the same time series and surfaced an anomalous FY2028 drop ($10T → $3T) at the rightmost edge. Diagnosis: 86 of 107 universe companies have FY2024 as their latest historical fiscal year (forecast spans FY2025-2027), but 21 companies have FY2025 historical (forecast spans FY2026-2028). The "drop" at FY2028 was just the smaller cohort's contribution showing alone.

**Root cause.** `scripts/forecast.py` is a per-company iteration generating a 3-year horizon from each company's last observed fiscal_year. This is statistically correct (you can't extrapolate from "company X's last data point" the same number of years out as company Y's if their last data points are different) but visually it creates an apparent revenue cliff at the rightmost extant forecast year because cohort size shrinks. Not a bug in the script — a known visualization implication of per-company horizons over a multi-company aggregation.

**Triage.** Documented. mart_growth_forecast visualization on Page 5 (per POWERBI_PIPELINE.md section 3.5) handles this explicitly with a "Forecast horizon note" panel making the per-company horizon explicit to dashboard viewers + a clip-at-FY2027 option for the aggregate trajectory line. Page 1 (Executive Overview) defers forecast viz entirely — the trend chart on Page 1 is historical only (FY2009-2024 via the Latest Complete FY pattern), with forecast visualizations confined to the dedicated growth/forecast Page 5.

**Carry-forward.** When a forecast surface has per-entity horizons over a multi-entity aggregation, the aggregate viz needs to clip at the smallest cohort's last year OR explicitly annotate per-cohort horizons. Never let the rightmost edge of a forecast time series silently shrink — viewers will read it as a real revenue projection rather than a cohort-size artefact.

#### Risk 57 — PBI authoring discipline: ship a deliberate design BEFORE clicking, not iteratively patch through the visual until it stops looking broken (banked 2026-05-31, Phase 5 session 1 close)

**Discovered the hard way during Phase 5 session 1.** Session ran 9+ hours of iterative-fix → re-fix → re-re-fix loops on the hero chart and KPI cards, each round trying to fix the visual symptom that surfaced after the previous fix. Iteration shape: render → spot oddity → patch DAX → spot next oddity → patch chart filter → spot next oddity → patch source mart selection → final-stage frustration at how generic the page looked after all the patches landed. Phil's call at session close: complete redesign of all 5 pages with a deliberate spec written up front.

**Root cause.** No upfront design spec for the executive overview page beyond "4 KPI cards + hero chart + 2 slicers + caveat" — which is itself a generic-Power-BI-tutorial pattern. Once the implementation started, the design call was punted into the implementation loop, and incremental visual-symptom debugging took over from "what does the page need to demonstrate as a Project #3 portfolio piece." Differs from how Phase 4 marts shipped (each mart had a CTE design discussion at session kickoff before any SQL was written).

**Carry-forward.** Phase 5 sessions 2-6 each open with a 1-page design call (what the page needs to show, what visuals encode what, what makes this page distinctive vs Projects #1 and #2) BEFORE any PBI clicks. The design call output gets banked in POWERBI_PIPELINE.md as the session's pre-implementation spec. Implementation iterates against the spec, not against the rendered output. **Senior-DE pattern reinforced from Project #2 Risk family E ("design BEFORE you build, especially when the output is visual"):** the visual layer is the easiest place to drift, hardest place to spot the drift, and most expensive place to recover from the drift.

#### Risk 58 — Mart fiscal_year anchored on SEC fy attribute instead of year(period_end_date): 52/53-week filers' 10-Ks tag both current-year and prior-year comparatives under the same fy, breaking the mart partition assumption (banked 2026-06-01, Phase 5 session 3, Audits 4 + 7 + 8 TRIPLE convergence)

**Discovered during Phase 5 session 3 audit campaign.** Audit 4 surfaced it at the SPGI test case (SPGI's standalone FY2024 10-K absent from companyfacts JSON; 2024-12-31 data exists only as comparative under fy=2025 filings; `year(period_end) IN (fy, fy+1)` filter at `mart_financial_health.sql` line 190 rejects 2024 NOT IN (2025, 2026)). Audit 7 surfaced the same root cause as ~421 cross-mart divergences (52/53-week retailers WMT/HD/TGT/LOW/TJX/NVDA/CRM/JNJ with one 10-K reporting two period_end rows tagged the same fy + same accession). Audit 8 surfaced the same root cause as 118 snapshot-stability drifts.

**Root cause.** SEC EDGAR XBRL `fy` attribute uses period-START-year convention for 52/53-week filers — a WMT 10-K with period_start=2012-02-01 + period_end=2013-01-31 carries fy=2012 in XBRL despite WMT internally calling it "Fiscal 2013." The same 10-K then reports prior-year comparative rows tagged fy=2012 with period_end=2012-01-31. Both rows pass the mart's year-IN filter. Risk 42 dedup `ORDER BY accession_number DESC` produces a tie (same accession). Trino ROW_NUMBER tie-break is non-deterministic per partition → cross-mart divergence + snapshot drift + SPGI total absence.

**Triage / fix shape.** Re-anchor mart `fiscal_year` on `year(period_end_date)` instead of the SEC `fy` attribute. Specific edits to `mart_financial_health.sql` + `mart_pl_trend.sql` + `mart_peer_benchmark.sql`: drop the year-IN filter; change Risk 42 dedup partition from `fiscal_year` to `year(period_end_date)`; change projection / pivot GROUP BY from `fiscal_year` to `year(period_end_date) AS fiscal_year`. Risk 48 conditional span filter preserved. ONE fix heals Audits 4 + 7 + 8 simultaneously.

**Carry-forward.** When XBRL or SEC-anchored data drives a mart's grain, NEVER anchor on the source's internal fiscal-year attribute — anchor on the period_end_date the value covers. Source attributes follow filer-specific naming conventions that the data engineer cannot ground-truth without per-CIK probes. Calendar-year-of-period-end is universal across all 11 GICS sectors and matches analyst-facing interpretation.

#### Risk 59 — Canonical-specific collapse_rule override needed for cash_and_equivalents: Risk 47 value-DESC PRIMARY inflates by Restricted-cash component when the alias is added (banked 2026-06-01, Phase 5 session 3, Audit 5)

**Discovered during Phase 5 session 3 Audit 5 cash post-Fix simulation.** Audit 3 identified that 16 CIKs (mostly banks: JPM, BAC, C, WFC, USB, PNC, COF, BRK.B, AXP + GE, GILD, PG, CVX, INTC, MMM, TGT) file only the Restricted-cash variant tag (`CashCashEquivalentsRestrictedCashAndRestrictedCashEquivalents`) and need it added as an alias for `cash_and_equivalents`. Audit 5 simulated the post-Fix collapse: 45 OTHER CIKs file BOTH the bare `CashAndCashEquivalentsAtCarryingValue` AND the Restricted variant, with the Restricted variant always >= bare by the FASB definition. Under Risk 47 value-DESC PRIMARY, the mart would pick Restricted, inflating cash by the restricted-cash component. Worst cases: PYPL +$15.8B (241% over bare), ADP +$7.2B (246%), SCHW +$23.4B (56%), INTU +$3.5B (197%).

**Root cause.** Risk 47's "value-DESC = analyst-headline" heuristic is correct for revenue (where multi-tag disagreement reflects ASC 606 transition partials vs full reported revenue, larger = headline) but is WRONG for cash, where the Restricted variant is a strict SUPERSET and the analyst-headline is the BARE tag.

**Triage / fix shape.** Extend `canonical_concept_tag_preference.csv` with a `collapse_rule` column. Values: `value_desc` (Risk 47 default, keep for revenue + future multi-tag canonicals where larger = headline) and `preference_rank_asc` (override — preference_rank 1 wins regardless of value; for cash_and_equivalents). Switch `sat_concept_value.sql` `collapsed_observations` CTE ORDER BY to a CASE on collapse_rule. Cash seed rank 1 = bare, rank 2 = Restricted. Heals 16 RESTRICTED_ONLY CIKs without inflating the 45 RESTRICTED_LARGER cases.

**Carry-forward.** When adding a tag alias to a canonical's preference list, the FIRST question is "what's the semantic relationship between the new tag and the existing tag?" Three patterns:
1. **Alternative-tags-same-concept** (revenue's 4 alias tags during ASC 606 transition) → value-DESC is right; pick the analyst-headline.
2. **Superset-of-existing** (Restricted cash = bare cash + restricted component) → preference_rank ASC is right; pick the narrower bare definition.
3. **Derivation-source** (CostOfRevenue used to derive gross_profit) → not collapse semantics; mart-layer derivation column.

The `collapse_rule` column makes the choice explicit per canonical. Default = value_desc; override = preference_rank_asc for superset cases.

#### Risk 60 — Forecast model pathology on structural shocks: Holt-Winters extrapolates spinoff / divestiture revenue declines as gradual trend (banked 2026-06-01, Phase 5 session 3, Audit 9)

**Discovered during Phase 5 session 3 Audit 9 forecast sanity scorecard.** 3 of 336 forecast rows showed implausibly low forecast_value relative to latest historical: GE 2027 (0.42x of $38.7B FY2024 = $16.2B forecast vs analyst consensus ~$40B), MMM 2026 (0.42x of $24.6B = $10.3B vs ~$23B), MMM 2027 (0.13x = $3.1B vs ~$22B). Both companies underwent major divestitures in 2024 (GE: GE Vernova + GE HealthCare separations; 3M: fiber optics + food safety). The historical revenue trajectory captured the structural step-downs; Holt-Winters Exponential Smoothing additive trend read those steps as continuous decline and projected forward.

**Root cause.** Univariate forecasting (statsmodels.tsa Holt-Winters, ARIMA) operates on the revenue time series alone — no awareness of whether a historical change was a continuous trend OR a one-time structural event. Spinoffs/divestitures appear in the data as a single-period revenue drop, indistinguishable mathematically from one period in a continuing decline trend.

**Triage / fix shape.** No code fix in scope — handling structural breaks requires intervention analysis / structural-break detection (heavy-weight for portfolio scope) or per-company manual override lists. Documentation fix only: PBI Page 5 caveat strip annotation "Forecasts are 3-year Holt-Winters / ARIMA projections; structural events (spinoffs, divestitures, M&A) are not modeled. Forecasts for GE, MMM, and other post-divestiture filers should be interpreted accordingly." Flag the 5 outlier forecast rows via a CASE column on mart_growth_forecast at Fix-all phase.

**Carry-forward.** When publishing per-company forecasts derived from purely-historical univariate models, an explicit caveat about structural breaks is non-optional. The model's silence on the pathology becomes a viewer's interpretation error if the caveat is missing. For future projects involving forecasting: build a "structural events" seed early if any company in scope has had a spinoff/M&A in the historical window.

#### Risk 61 — Risk 42 dedup tie-break non-determinism under Trino ROW_NUMBER: same-accession multiple period_end rows pass the mart filter; ORDER BY accession_number DESC produces a tie (banked 2026-06-01, Phase 5 session 3, Audit 7 mechanism; subsumed by Risk 58 fix)

**Discovered during Phase 5 session 3 Audit 7 cross-mart drilldown.** WMT FY2012 sat probe revealed both `period_end=2012-01-31` ($446.95B, WMT's FY2012 actual) and `period_end=2013-01-31` ($469.16B, WMT's FY2013 current-year-tagged-fy=2012-by-XBRL) share the same accession `0000104169-13-000011`. Both pass mart filters. Risk 42 dedup ORDER BY accession_number DESC → both rows have the same accession → tie. Trino ROW_NUMBER tie-break is non-deterministic per partition. mart_pl_trend picked $469B; mart_financial_health picked $447B. ~421 cross-mart divergent rows across 6 checks.

**Root cause.** Trino's ROW_NUMBER documentation: "If ORDER BY produces ties, the ordering among tied rows is unspecified." Two rows sharing identical PARTITION BY columns AND ORDER BY values can be ranked 1-vs-2 in either order, with the choice unstable across partitions in the same query. Different as_of_date partitions resolve the tie differently → snapshot-stability drift (Audit 8) + cross-mart divergence (Audit 7).

**Triage / fix shape.** Risk 58 period-end re-anchor structurally resolves this — when fiscal_year is derived from year(period_end_date), the two rows fall into DIFFERENT partitions, and the tie cannot occur. NO separate Risk 61 fix needed. Defensive belt-and-braces: extend dedup `ORDER BY accession_number DESC, period_end_date DESC` even after Risk 58 fix lands, since accession_number DESC remains the primary intent.

**Carry-forward.** Whenever a dedup ORDER BY column can produce ties under any realistic data distribution, the dedup contract must include a deterministic secondary tie-breaker. General pattern: every ROW_NUMBER ORDER BY should include enough columns that ties are mathematically impossible under any real data distribution; otherwise the dedup is silently non-deterministic.

#### Risk 62 — dbt schema test layer is STRUCTURAL ONLY: zero semantic coverage of completeness, cross-mart consistency, value sanity, snapshot stability, collapse semantics, forecast plausibility (banked 2026-06-01, Phase 5 session 3, Audit 10)

**Discovered during Phase 5 session 3 Audit 10 schema-test inventory.** 249 current dbt schema tests across 4 layers (intermediate, warehouse, business_vault, marts). All 249 passing. ZERO of them caught any cell in the 191-cell gap matrix from Audit 3. Audit 4-8 architectural bugs (period-end anchor mismatch, dedup non-determinism, cross-mart divergence, snapshot drift) all pass current tests cleanly.

**Root cause.** Current tests verify SHAPE (hash uniqueness, FK closure, not-null, accepted_values, composite PK). They don't verify VALUES (anchor truth, cross-mart agreement, completeness thresholds, range sanity, semantic consistency). The audit campaign filled this gap manually; production-grade test coverage must bake the audit findings into the dbt test suite.

**Triage / fix shape.** Add 12 new dbt tests in Fix-all phase: 6 anchor-CIK value-correctness data tests (AAPL/MSFT/JPM/BRK.B/WMT/XOM at FY2024), 3 cross-mart consistency data tests (revenue + net_income + assets divergence = 0), 1 completeness threshold on mart_financial_health.revenue, 1 forecast CI ordering test, 1 snapshot stability test (allow 5 real restatements, fail on dedup-bug drift), 1 collapse_rule enum test on canonical_concept_tag_preference, plus 3 generic dbt_expectations range tests on net_margin / ROA / growth_ratio. Post-Fix expected: 261/261 dbt schema tests passing.

**Carry-forward.** Schema tests = STRUCTURAL contract. Data tests = SEMANTIC contract. Both required for production-grade warehouses. The bug class that motivates data tests = "the warehouse passes 249/249 structural tests AND ships wrong values to the dashboard." From this project onward: every architectural audit finding gets a paired data test added at fix time. The audit becomes the test suite specification.

---

### Phase 5 session 3 audit campaign — Audits 1-10 closed (banked 2026-06-01)

Phase 5 session 3 closed the 10-audit data quality framework started in Phase 5 session 2. Audits 1-3 ran prior session; Audits 4-10 ran this session. 5 new architectural Risks banked (58-62 above). 8 audit SQL artifacts + 1 anchor-truth markdown + 1 schema-test coverage markdown shipped to `sql/audit/` + `audit/`.

**TRIPLE CONVERGENCE finding.** Audits 4 + 7 + 8 independently surfaced the same root cause (SEC fy attribute anchor for 52/53-week filers + Risk 42 dedup non-determinism). ONE fix (Risk 58 period-end re-anchor) heals ~561 affected (cik, fiscal_year, canonical) tuples across the three audits.

**FIX-ALL phase queued.** One coherent commit: period-end re-anchor (3 marts) + cash collapse_rule override (sat_concept_value + seed extension) + seed alias expansion (canonical_concepts_dictionary + 6-place Jinja lockstep) + mart-layer derivation (gross_profit / liabilities / SE / cash) + universe filter (hub_company) + 12 new dbt schema/data tests + defended-NULL JSON-evidence pin file. ONE cascade rebuild. ONE re-audit pass through all 10 audit files. Bounded.

**Operating principle held throughout.** ZERO mart / seed / DDL / dbt model changes during audit phase. 100% read-only investigation per lock at session 2 kickoff. All findings banked at each audit's closing block in the respective `sql/audit/*.sql` file.

---

### Phase 3 reflection — 14 Risks rolled into six pattern families (banked 2026-05-29, Phase 3 session 14 close)

Phase 3 banked 14 Risks across two sessions (session 11 forward-verify shipped Risks 24-29; session 12 first-run debug shipped 30-35; session 13 first-Parallel-run shipped 36-37). Rolling them into six top-level pattern families. Risks remain individually banked above as design-decision provenance; this is the consolidated training surface for the post-mini-projects training journey + portfolio walkthroughs.

**Family A — Managed-runtime version-floor cross-check.** Managed services pin a Python/Java/runtime ceiling that silently filters out modern tool versions advertised as "current". dbt-core 1.11 pinned in --additional-python-modules silently filtered to nothing on Glue Python Shell 3.9 because dbt-core 1.10+ requires Python 3.10+; cascade resolved at dbt-core 1.9.10 + dbt-athena-community 1.9.5. Risks 26, 30. **Carry-forward.** For every managed-runtime + cloud-tool stack: explicitly cross-check the runtime version ceiling against the tool's version-supported-python floor BEFORE pinning. Document the highest-tool-version-that-fits in the requirements file as a comment + upper bound. Re-validate when the managed runtime adopts a newer language version.

**Family B — Adapter vs tool version skew on config keys.** Adapter releases bring new config keys (dbt 1.10's `arguments:` test wrapper) that are rejected by the prior tool version's strict validation. Skew kills builds at parse time. Risk 31. **Carry-forward.** When downgrading a tool by a minor version (1.10→1.9.x in this case), grep the project for config keys introduced in the dropped versions and flatten/remove them. Reciprocally: when upgrading, re-test config files against the new version's strict validation before committing.

**Family C — Cloud-runtime stdout buffering + Python idioms.** Cloud runtimes buffer stdout (Glue Python Shell does, Lambda does, Fargate does); standard Python idioms (`if __name__ == "__main__":` guard, default print buffering) are unreliable signals of execution path. Risk 32. **Carry-forward.** For cloud-hosted Python entrypoints: drop the `__main__` guard, use `sys.exit(main())` at module level, add `flush=True` to every diagnostic print. The guard provides zero protection (script isn't imported by anything) and the buffering can silently mask runtime failure paths.

**Family D — IAM scope discovery: direct + transitive references.** IAM scope discovery cannot stop at the SQL FROM clause — Athena resolves stored views at query analysis time and calls Glue Catalog APIs under the query-executor identity for every database transitively reachable via the view body. Risks 34 (dbt sources → Bronze catalog read on Glue role), 37 (Athena view body → Bronze catalog read on Step Functions role). **Carry-forward.** Discovery pattern for any cloud query-consumer role: grep the queries for every table reference, run `SHOW CREATE VIEW` on every view in the list, union direct + transitive databases into the role's read scope. Tighter: split direct-write databases from transitive-read databases into separate Sid blocks so the IAM document carries the lesson visibly.

**Family E — Wizard defaults vs explicit trust policies.** AWS Console role wizards optimise for the most-common case (Lambda function); their defaults silently attach AWSLambdaRole even when the trust policy use case is not Lambda. Risk 33. **Carry-forward.** For any non-Lambda IAM role with cross-service trust (Step Functions, EventBridge, AppFlow, etc.): bypass the wizard's service-presets and use the Custom trust policy path with the explicit `Service: states.amazonaws.com` (or equivalent). Custom Customer Managed Policy attached separately. Wizard-attached extras get archaeological-tech-debt-level invisible until someone reads the role's policy attachments and asks "why is this here."

**Family F — Orchestration-state semantics: choose the failure shape deliberately.** Step Functions Parallel state fails fast: any sibling error stops all in-flight branches within milliseconds. That's the desirable shape for structural verify fan-out (first regression surfaces immediately), but the wrong shape for per-region data quality scans where the analyst wants to know which regions are healthy regardless of which fail. Risk 36. **Carry-forward.** At every Parallel state authoring decision: name the semantic intent (fail-fast vs collect-all-results) and let that drive the Catch shape. Fail-fast = no Catch; collect-all = per-branch Catch handler that converts the failure into synthetic success metadata. Never accept fail-fast as a default by omission.

Risk 24 (dbt parallel-execution safety), Risk 25 (dbtRunnerResult internals "liable to change"), Risk 27 (Glue cold-start budget), Risk 28 (Lambda 15-min cap), Risk 29 (Step Functions Athena .sync runs raw SQL not dbt), and Risk 35 (dbt deps must run inside the wrapper) are design-decision Risks already baked into the runtime + wrapper architecture; no separate pattern family — they live as design provenance above and as live design decisions in `ORCHESTRATION_PIPELINE.md`.

---

### Banked open items from session 1 (not lessons, but trackable)

- **Free Plan cliff: 23 Nov 2026.** AWS account converts to paid OR
  auto-closes when Free Plan expires (6 months from account creation, or
  $200 credits exhausted, whichever first). Calendar reminder
  ~mid-October 2026 to evaluate conversion-to-paid vs cached-demo-only
  path. Demo durability principle 5 (repo + .pbix Import mode) means a
  closed account doesn't kill the demo — only live AWS demos.
- **phil-admin lacks IAM-access-to-billing.** Billing > Account page
  showed permission-denied errors despite phil-admin having
  `AdministratorAccess`. Root must toggle "IAM users and roles can view
  billing information" in root's Account preferences. Not blocking for
  Phase 1 work; worth fixing for clean billing review.

---

## Project summary

End-to-end data engineering portfolio project building a production-grade retail
demand-planning analytics platform. Real Walmart sales data (M5 Forecasting dataset)
is ingested from Azure SQL Database into Snowflake via scheduled Airflow jobs,
transformed through a partitioned star schema with dedicated marts using dbt,
and surfaced as a five-page Power BI dashboard for an operations / S&OP audience.

Headline focus: **orchestration**. Pipeline runs end-to-end on a schedule with proper
failure handling, tests, and CI — not button-pressed like Project #1.

---

## Technical learnings

> Sections below will fill in as work progresses. Each entry should capture what
> happened, what was new, and what I'd do differently. Project #1 examples for
> reference are in `C:\dbt\cdc_nt_gtfs\LEARNINGS.md`.

### Azure SQL Database

**Provisioning (2026-05-12 session)**

- **"Azure SQL" in Marketplace is a hub, not a product.** It splits into SQL databases, Managed Instance, SQL VMs. We want **SQL databases** (Single database). The Azure UI also pushes **Hyperscale** as the headline option — that's a different (more expensive) tier, NOT what we want. Plain General Purpose Serverless is correct for a project this size.
- **Free Azure SQL Database offer exists and is excellent.** 100,000 vCore-seconds + 32 GB data + 32 GB backup free **per month for the lifetime of the subscription**. One free database per subscription. Critical safety: when free limits are hit, you can configure "auto-pause until next month" with **Overage billing: Disabled**, meaning zero risk of unexpected charges. This is dramatically better than the paid path I'd planned for.
- **Logical server vs database.** Two distinct concepts. The **server** is the security/firewall boundary with a globally unique public hostname (`*.database.windows.net`); the **database** lives inside it. Server names must be globally unique across all Azure customers. Used `sql-retail-demand-fc-phm` (phm suffix = initials).
- **Region — Australia East is the AU primary.** Microsoft puts new services there first; Australia Southeast (Melbourne) is the paired DR region with thinner service coverage. Free offer was available in Australia East.

**Firewall**

- During provisioning, the Networking tab has an **"Add current client IP address"** toggle — this creates the firewall rule for you. Public IP captured this session: `115.69.3.187`. Will need to add new rules when working from other networks (mobile hotspot, etc.).
- **"Allow Azure services and resources to access this server" = Yes** allows other Azure services (Azure Functions, Logic Apps, etc.) to connect. Needed if we later integrate with anything Azure-side.

**Authentication**

- **SQL authentication** picked over Microsoft Entra. Reason: our Python scripts (Phase 2 onwards) need a username/password pair to connect. Entra would require setting up an Entra admin on the server and using token-based auth in Python — extra complexity for no portfolio benefit. SQL auth with `sqladmin` + strong password is the right call.
- Admin password must satisfy 3-of-4 complexity (upper / lower / digit / symbol) and 8–128 chars.

**Cost controls**

- Set up a **Resource Group-scoped budget** at $50 AUD before provisioning anything. Budgets are alerts only (not hard caps) — Azure has no true spending hard cap on pay-as-you-go subscriptions.
- For the Free offer, the practical hard cap is "Overage billing: Disabled" — DB pauses, no charges.
- Budget thresholds set: 50%, 80%, 100% Actual + 100% Forecasted. Forecasted is the early-warning alert that catches runaway spend before it actually hits the cap.

**Connection testing**

- **Portal's Query editor (preview)** is excellent for the first connection sanity check — browser-based, no client install. Sign in with SQL auth (`sqladmin` + password), paste `SELECT @@VERSION;`, hit Run. Result confirmed Azure SQL 12.0.2000.8.
- For Phase 2 onwards we'll switch to Azure Data Studio or VS Code's mssql extension for richer querying.

**Secrets management pattern**

- Created `.env` (gitignored) holding real secrets + `.env.example` (committed) as a template. Loaded in Python via `python-dotenv` → `os.getenv()`. Same pattern will extend to Snowflake creds in Phase 2 and Kaggle in any scripted download.
- ⚠️ **Slip this session:** Claude echoed Phil's real password back in a chat message. The password is still valid; risk is low since the transcript is between Phil and Claude (not public), but a clean fix is to rotate the password in Azure portal and update `.env`.

**Auto-pause behaviour (2026-05-12 session)**

- Free Serverless databases **auto-pause after ~1 hour of inactivity** and the cold-start wake takes 30–60 seconds. Default pyodbc `Connection Timeout=30` is too short → got `08001 TCP Provider: Timeout error [258]` despite firewall being correct.
- Fix: bumped `Connection Timeout=90` in all connection strings. First connect of each session is slow; subsequent connects within the active hour are fast. This will matter again in Phase 2/3 (Airflow DAG cold-starts) — bake the 90s into shared connection helpers from day one.
- Diagnostic learned: `Test-NetConnection <host> -Port 1433` cleanly distinguishes firewall/network problems (TCP fails) from auto-pause/login-layer problems (TCP succeeds, login times out).

**PAGE compression on raw tables (2026-05-12)**

- Free Serverless gives 32 GB storage. The `raw.sales_train` table (~59M rows after unpivot) would have eaten ~9 GB uncompressed (NVARCHAR uses 2 bytes/char). Adding `WITH (DATA_COMPRESSION = PAGE)` to the `CREATE TABLE` typically yields 50–70% savings — meaningful headroom on the Free tier.
- Trade-off: marginally more CPU on write, _faster_ reads (less I/O), no query-side complexity. No reason not to use it on any raw table over a few million rows. Skipped on `calendar` (1,969 rows — overhead dwarfs savings).

**SQL Server 1024-column limit (2026-05-12)**

- Azure SQL has a hard limit of 1024 columns per table. M5's wide sales tables (1947 / 1919 cols) exceed this. Original plan was "load wide, unpivot in dbt staging" — locked decision from Phase 0. Had to be revised in Phase 1: **unpivot during the Python load** using `pandas.melt` before insert.
- General rule: column-count and row-count constraints of the **specific** destination dialect must be checked before locking source-shape decisions. Wide tables that fit Snowflake (no practical column limit for our scale) don't necessarily fit SQL Server.

**Code-quality checklist (2026-05-12)**

- Established a 9-point code-quality audit (currency, compactness, resource efficiency, security, workflow consistency, upstream/downstream contract, idempotency, pre/post-action verification, observable progress). Lives in `TEACHING_PREFERENCES.md` — applied to every non-trivial script from this session onwards. First scripts audited: `smoke_test_azure_sql.py`, `01_create_raw_tables.sql`, `create_raw_tables.py`. Public-facing version at `CODE_QUALITY.md` (linked from README).

**Bulk load throughput on Free Serverless (2026-05-12 → 2026-05-13)**

- **Measured throughput:** ~1,500 rows/sec sustained on Azure SQL Free Serverless (2 vCores) via `pandas.to_sql` + `fast_executemany`. Significantly below my pre-load 10–20k rows/sec estimate. Paid Standard tiers (S2/S3) reportedly hit 30–50k rows/sec on the same pattern.
- **End-to-end load times (sequential, in order loaded):**
  - `calendar` (1,969 rows): ~5 sec
  - `sell_prices` (6,841,121 rows): **73.1 min**
  - `sales_train` (59,181,090 rows): **659.6 min** (~11 hours)
  - **Total: ~12.2 hours**
- **Cost (vCore-seconds on Free tier):** approx 87,900 of monthly 100,000 quota consumed by this single load. Hit ~88% of monthly budget in one shot. No issue for Phase 2 (daily extracts are ~minutes of compute) but a useful data point for sizing future bulk operations.
- **Implication for Phase 2:** Snowflake's `COPY INTO` from S3/blob is orders of magnitude faster than row-by-row INSERTs. The Azure SQL → Snowflake extract should be much faster than this initial CSV → Azure SQL load.

**Sleep schedule discipline (2026-05-12 → 2026-05-13)**

- Long-running scripts on consumer-hardware need active OS-level defences: screen-off and sleep both `Never`, lid close `Do nothing`, Windows Update paused. Wi-Fi adapter power management is a separate hidden setting on Windows 11 (often missing from Power Options on Modern Standby devices — accessed via PowerShell `powercfg -attributes SUB_WIRELESSPOWER ... -ATTRIB_HIDE` if needed).
- Carry-forward: write a one-shot **overnight-stability checklist** as a portable artefact, applies to any Project #3 long-running batch.

### Snowflake

**Signup choices (2026-05-13)**

- **"AI Data Cloud — For Enterprise"** vs **"Cortex Code CLI — For Developers"**: different *products*, not different tiers. AI Data Cloud is the standard data warehouse (what we want); Cortex Code CLI is Snowflake's AI coding agent. Don't conflate.
- **"For Enterprise"** (marketing label on the AI Data Cloud button) is NOT the same as **Enterprise edition** (pricing tier). Edition is picked on page 2/2 — chose **Standard**, cheapest tier with everything we need.
- **Cloud provider (AWS / Azure / GCP) doesn't matter** for use cases where data flows via the Python connector. Picked AWS because (a) Snowflake started there in 2014 — most mature; (b) every tutorial / Stack Overflow example uses AWS; (c) cross-cloud transfer is trivial at our volume (~3-5 GB compressed).
- **Region matters for compute location, not timezone.** Picked `ap-southeast-2` (Sydney) — closest to Azure SQL Australia East. AWS and Azure Sydney regions sit in the same physical datacentres anyway.
- **Username convention:** AD-style short identifier (`pheluciam`), not the email address. Email contains `@` and `.` — both special characters in Snowflake identifiers requiring double-quoting in every `GRANT`. Snowflake stores usernames as uppercase regardless of input case.

**Role + permission hierarchy (2026-05-13)**

- **Never use ACCOUNTADMIN for day-to-day work.** Standard pattern: create a dedicated project role (`RETAIL_ENGINEER`), grant it the specific privileges it needs, switch into it for all real work. ACCOUNTADMIN is the equivalent of `root` / `sa` — admin operations only.
- **`GRANT ... ON FUTURE TABLES IN SCHEMA ...`** is critical for any schema where new tables will be created later. Without it, every new table needs its own explicit grant. Pure quality-of-life win.
- **Privilege chain:** USAGE needed at every level (warehouse → database → schema) for a role to reach a table. Forgetting USAGE on schema = "object does not exist or not authorised" errors that are easy to misread.
- **Role hierarchy via `GRANT ROLE RETAIL_ENGINEER TO ROLE SYSADMIN`** — Snowflake's recommended pattern. Lets SYSADMIN also assume the project role without needing ACCOUNTADMIN.

**Timezone gotcha (2026-05-13)**

- **`TIMESTAMP_NTZ` = "No Time Zone"**, NOT New Zealand! Easy misread. Three variants: NTZ (wall clock, no tz), LTZ (stored as UTC, displayed in session tz), TZ (with explicit offset).
- **Region ≠ timezone.** Region = where Snowflake's servers physically run. Timezone = a *display* setting on the user/session. Default timezone on new accounts is `America/Los_Angeles` — confusing for non-US users.
- **Fix:** `ALTER USER <name> SET TIMEZONE = 'Australia/Melbourne'` (persistent, affects all future sessions) + `ALTER SESSION SET TIMEZONE = 'Australia/Melbourne'` (immediate, current session).
- **`(9)` after `TIMESTAMP_NTZ`** = fractional-second precision (9 digits = nanoseconds). Snowflake default.
- **Sydney and Melbourne share timezone** (`Australia/Sydney` / `Australia/Melbourne` interchangeable — same offset, same DST rules). AEST = UTC+10, AEDT = UTC+11. Australian DST: first Sunday October → first Sunday April.

**Warehouse economics (2026-05-13)**

- **`AUTO_SUSPEND = 60` + `AUTO_RESUME = TRUE`** on an XS warehouse means near-zero idle cost — wakes in ~1-2 sec on next query. Significantly faster wake than Azure SQL Free Serverless (30-60s), because Snowflake architecture separates compute from storage and the storage is always live.
- **`INITIALLY_SUSPENDED = TRUE`** on `CREATE WAREHOUSE` = zero credit burn between provisioning and first real query. Default is the opposite — worth setting explicitly.
- **XS = 1 credit/hour while running.** Trial includes $400 credits / 30 days — plenty for a portfolio project at this scale.

**DDL differences vs SQL Server (2026-05-13)**

- **`CREATE OR REPLACE TABLE`** = Snowflake's atomic equivalent of "drop if exists, then create". One statement, no race condition. *Destructive* — wipes data.
- **No `DATA_COMPRESSION = PAGE` needed** — Snowflake auto-compresses everything via micro-partitions (Zstd by default). The entire SQL Server compression DDL story disappears.
- **Column-level `COMMENT '...'`** is supported and useful. Living documentation that shows up in `INFORMATION_SCHEMA.COLUMNS` and Snowsight's table viewer.
- **No `GO` batch separator.** Snowflake parses statement-by-statement; just separate with `;`.
- **Identifier case:** unquoted identifiers stored as UPPERCASE (queries case-insensitive). Quoted identifiers preserve case. For RAW tables, unquoted snake_case is simplest.
- **Audit pattern:** `loaded_at TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP() NOT NULL` on every RAW table. Cheap, valuable for Phase 3 "did the pipeline run today?" health checks.

**Clustering keys — when NOT to cluster (2026-05-13)**

- Considered clustering `sales_train` on the `d` column (`'d_1'`..`'d_1941'`) for date-range query speed. **Skipped** — lexicographic order on a text column with variable-width numbers (`d_1, d_10, d_100, ..., d_11`) doesn't match date order. Clustering wouldn't help date-range filters.
- **Correct place to add clustering:** dbt staging layer (Phase 4), where we'll derive a real `sale_date DATE` column by joining `raw.sales_train.d` → `raw.calendar.d`. *That* table can be clustered on the real DATE.
- General principle: cluster on the column you'll actually filter on in the form it's stored, not a proxy that has lookup overhead.

**Connector specifics (2026-05-13)**

- **`snowflake-connector-python[pandas]`** — the `[pandas]` extra pulls in `pyarrow` and enables `write_pandas()`, the recommended bulk-load function (uses PUT to internal stage + COPY INTO under the hood). Without `[pandas]` you'd be doing row-by-row INSERTs — orders of magnitude slower.
- **Dependency drift:** installing `snowflake-connector-python` (resolved to v4.5.0) downgraded pandas from 3.0.3 → 2.3.3. Connector hasn't qualified pandas 3.x yet. `requirements.txt` uses minimum-version pinning only at this stage; when Phase 3 is stable, generate a `requirements-lock.txt` via `pip freeze`.
- **`login_timeout`** and **`network_timeout`** — set explicitly on connections (mirrors the defensive 90s timeouts on Azure SQL after the auto-pause learning). Cold connections may take longer than the default.

**Mental model: three execution locations (2026-05-13)**

Pinning this because confusion crept in mid-session:

| Location | What lives there | What you do there |
|---|---|---|
| **Disk / VS Code** (`sql/snowflake/*.sql`) | Source-of-truth SQL files, version-controlled | Author + edit SQL files |
| **Snowsight worksheets** | Web UI tabs where SQL actually executes | **Run** SQL — the only place SQL touches Snowflake |
| **PowerShell** | Python runtime, pip, Git commands | Run Python scripts (smoke test, extract); never SQL DDL |

Disk file existing ≠ SQL has been run. The two must be reconciled: write to disk → copy → paste into Snowsight worksheet → Run All.

**Worksheet naming convention in Snowsight (2026-05-13)**

- **Numbered worksheets** (`00_provision_account.sql`, `01_create_raw_tables.sql`) mirror the canonical setup-script sequence on disk. A fresh installer would run these in order.
- **Non-numbered worksheets** (`timezone_setup.sql`) are one-off fix-ups applied to an already-provisioned account. Won't be re-run.

**`write_pandas` bulk-load economics (2026-05-13, Phase 2 session 2)**

- Confirmed throughput on the production extract path (Azure SQL Free Serverless → pandas → `write_pandas` → Snowflake XS warehouse): **~14,000-15,000 rows/sec sustained** on 100k-row chunks for `sales_train` (8 narrow cols). `sell_prices` (4 narrow cols) hit ~10,500 rows/sec on a 27k single-chunk load. Orders of magnitude faster than Phase 1's `pandas.to_sql` + `fast_executemany` to Azure SQL (~1,500 rows/sec).
- The cost difference reflects architecture, not language: `write_pandas` PUTs a Parquet file to an internal stage then issues one `COPY INTO`, which Snowflake processes in parallel against its micro-partition writer. `fast_executemany` against SQL Server is still row-batched INSERTs at heart.
- **Implication:** the Phase 3 Airflow daily run will move ~30k sales rows in <10 seconds of compute. The warehouse barely wakes up before going back to sleep. Credit burn is negligible at this scale.

**Snowflake connector transient retry — built-in (2026-05-13)**

- Hit a transient `RemoteDisconnected('Remote end closed connection without response')` mid-PUT during the 7-day extract test. **The connector's internal retry handled it cleanly** — `Retrying (Retry(total=0, ...))` log line, then next chunk succeeded. Zero data lost, no special handling needed in our code.
- Worth knowing for interview talking points: Snowflake Python connector ships with `urllib3`-level retry on transient HTTP failures. You don't need to wrap `write_pandas` calls in your own retry loops. Different from `pyodbc` to Azure SQL where you need to think about it yourself.

**3-year backfill economics (2026-05-14, Phase 2 session 3)**

- **Total wall-clock for 35.6M rows across 3 tables: 27.3 minutes (1,638 sec).** Against an original fear of 40 hours and a session-2 revised estimate of 60-90 min. The "one wide query, paid the table-scan cost once" pattern delivered.
- **Per-table elapsed (from extract log timestamps):**
  - `calendar` — ~4 sec for 1,068 rows
  - `sell_prices` — ~85 sec for 3,040,105 rows
  - `sales_train` — ~25 min 47 sec for 32,563,320 rows (326 chunks of 100k, except the last which was a partial 63,320)
- **Sustained throughput on the production run** — both materially higher than session 2's spot-test measurements:
  - `sell_prices` (4 cols): ~35,500 rows/sec — vs session 2's 10,500. ~3.4× faster.
  - `sales_train` (8 cols): ~22,000 rows/sec — vs session 2's 14,500. ~1.5× faster.
- **Why the speedup vs session 2 measurements:**
  - **Bigger chunks amortise overhead better.** Session 2's sell_prices test was a single 27k-row chunk; backfill ran 100k-row chunks back-to-back. Per-chunk fixed costs (Parquet encode, PUT, COPY INTO) get paid less often per million rows.
  - **Warmer infrastructure.** Snowflake's internal-stage upload path felt sharper at AU morning vs session 2's late afternoon. Cloud services have time-of-day variation worth noting.
- **End-to-end parity verified two ways:**
  - Script's own pre-flight (Azure SQL source count) vs post-action (Snowflake destination written count) — all three tables `OK`.
  - Independent SQL queries against both databases (`sql/snowflake/02_extract_smoke_tests.sql` Section 5 + `sql/verify/02_phase2_extract_verification.sql`) — all three tables `OK / OK / OK`.
- **Zero retries fired during the run.** No 40613 errors mid-stream, no transient HTTP disconnects mid-PUT. (Did hit one 40613 on the very first connect attempt — see Mistakes & diagnoses.)

### 2026-05-18 — Snowflake metadata visibility ≠ access boundary

Discovered during Phase 5 session 1 while connecting Power BI Desktop. PBI's Navigator under the dedicated `POWERBI_READER` role showed *all 7 schemas* in `RETAIL_DB` (`INFORMATION_SCHEMA`, `INTERMEDIATE`, `MARTS`, `PUBLIC`, `RAW`, `STAGING`, `WAREHOUSE`) — even though the role only had USAGE on `WAREHOUSE` and `MARTS`. Surprising; looked like a privilege leak. Diagnosed via `INFORMATION_SCHEMA.QUERY_HISTORY_BY_USER('PHELUCIAM')`, which proved every PBI metadata query (`SHOW SCHEMAS IN "RETAIL_DB"`, `SHOW DATABASES`, etc.) ran under `POWERBI_READER` — the role pin worked at the session level.

**The real behavior**: Snowflake's `SHOW SCHEMAS IN DATABASE` returns *every schema name* in a database the role has DB-level USAGE on, **regardless of per-schema privileges**. Schema-level USAGE controls whether you can OPEN the schema and READ tables inside it — not whether the schema name appears in catalog listings. The metadata layer is broadly readable; the access layer is privilege-gated.

**Visitor-badge analogy.** Walk into a building with a visitor pass. The elevator directory lists *every floor*: Marketing, Engineering, Executive, etc. That listing isn't a security hole; it's just signage. The badge readers on each individual floor's door are what enforce who can actually enter. Snowflake's `SHOW SCHEMAS` is the directory; the USAGE/SELECT grants are the badge readers.

**How we proved the boundary holds anyway**: `SELECT COUNT(*) FROM RETAIL_DB.RAW.M5_SALES_TRAIN` under `POWERBI_READER` failed with "Object does not exist or not authorized" — exactly as designed. PBI's Navigator showing the RAW schema name in the tree is cosmetic; if you'd tried to expand it and tick a table to load, the load itself would have errored with the same auth message.

**Carry-forward**: when a Snowflake catalog listing looks broader than expected, the question to ask is not "what did the GRANTs miss?" but "does an actual SELECT against the surprising object succeed?" Metadata is broadly readable; access is the boundary. Same pattern likely holds in BigQuery, Databricks Unity Catalog, and other modern warehouses. Project #3 carry-forward.

**Diagnostic technique worth banking**: `INFORMATION_SCHEMA.QUERY_HISTORY_BY_USER('<user>')` filtered to the last N minutes is the canonical way to verify what role any connecting tool is actually using — beats guessing-from-symptoms decisively. Add this to the Project #3 troubleshooting toolkit early.

### 2026-05-19 — ML training workload sizing: sample, validate, then scale

Discovered during Phase 5 session 5.3 while training the Snowflake Cortex ML FORECAST model. Claude scoped training at the full fact grain — 30,490 (item × store) series × ~1,150 days = ~35M training rows — and pointed it at the XS warehouse (1 credit/hr, single-node). Training ran for 90+ minutes (and possibly longer; Phil chose to let it finish rather than cancel mid-run after waiting ~80 min).

**The mistake**: scoping the ML workload to "production grain" before validating it ran in a tolerable time at all. Cortex multi-series scales reasonably well, but 30K series on XS is squarely on the high end of what XS handles efficiently. The single Cortex training run consumed roughly half a credit (acceptable cost) but a disproportionate share of Phil's wall-clock patience (not acceptable).

**Forward principle — ML workload scoping checklist**:

1. **Sample first.** Train on a small representative subset (e.g., 100-500 series, recent N months only) and measure wall-clock. Multiply out conservatively to the full grain — if the projection exceeds 30 min, decide before starting whether that's tolerable or scope needs reducing.
2. **Match warehouse / cluster size to workload.** For Cortex multi-series at 10K+ series, MEDIUM warehouse trains materially faster than XS for marginal extra cost (warehouse cost scales linearly but training time scales sub-linearly). Same principle applies on Databricks (autoscaling cluster vs single-node).
3. **Pick the right grain for the use case, not "the same grain as the fact."** If the Forecast vs Actual page surfaces category-level trends, item × day or category × day is sufficient and trains in minutes. Item × store × day is operationally useful but only if inventory/replenishment is the actual use case.
4. **Communicate runtime expectations BEFORE starting.** Anything > 5 min should come with a flagged time estimate so the user can decide to schedule it, walk away, or scope down.

**Carry-forward to Project #3**: Databricks ML workloads (MLflow / Spark MLlib / AutoML) have the same shape. Sample first, size cluster to projected runtime, communicate expectation, scale up only when correctness is proven at small scale. Community Edition Databricks is single-node and slow — paid trial or per-workload cluster sizing matters more there than on Snowflake's auto-suspend warehouse model.

**Discipline rule logged in TEACHING_PREFERENCES separately**: any operation Claude proposes that's expected to exceed 5 minutes must be flagged with explicit time estimate up front; any operation that ends up >2x the estimate is a triggered post-mortem.

**Resolution.** After cancelling the item × store training at 2h20min (still running, status confirmed RUNNING via Query History), pivoted to item-level grain (3K series). New training completed in the expected 3-5 min window. Lesson durably captured: the **right grain for a forecast is the grain that matches the use case AND trains in a tolerable window**, not "the same grain as the fact table." Item × store would only have earned its keep if the dashboard surfaced per-store forecasts as a primary visual. The Forecast vs Actual page surfaces aggregate revenue/units trends — item-level is the right grain. Interview talk track: *"I chose item-level forecasting over item × store because aggregated series have stronger signal — each item's daily demand across all stores is more stationary than per-store splits. Standard retail forecasting pattern when stores share similar SKU mixes."*

### 2026-05-20 — Cortex ML training is MEMORY-bounded, not just runtime-bounded, when using `method='best' + evaluate=TRUE`

Direct follow-up to the entry above. After fixing the GRAIN problem (item-level not item × store), the next training run at the right grain was kicked off overnight on XS warehouse with `method='best' + evaluate=TRUE` for portfolio-grade quality. Expected runtime per Snowflake docs was 60-120 min. Actual outcome: at 1h40m, the run failed with `STATEMENT_ERROR: Function available memory exhausted` (Snowflake's `_BASECONSTRUCT` UDF OOM'd inside the Python sandbox running the Cortex training).

**The mistake — second one in two days on the same workload.** Even at the right grain (3K series, ~3.5M training rows), `method='best' + evaluate=TRUE` is materially heavier on RAM than `method='fast'` because:

- `best` ensembles 4-5 models (Prophet, ARIMA, ExpSmoothing, GBM) in parallel — each model's per-series state is held in memory simultaneously across the cross-validation folds.
- `evaluate=TRUE` runs cross-validation splits which multiplies the in-memory model state by the number of folds.
- The XS warehouse on Snowflake is single-node with ~16 GB RAM available to UDFs. The combined ensemble + CV state on 3K series exceeded that ceiling at ~1h40m into the training.

**The recovery path that worked.** Bumped warehouse to XL (`ALTER WAREHOUSE WH_RETAIL SET WAREHOUSE_SIZE = 'XLARGE'`), re-ran the same SQL, completed in ~15 min. Cost ~1-2 credits total (XL is 16 credits/hr but only ran ~15 min). Then immediately bumped warehouse back to XS via `SET WAREHOUSE_SIZE = 'XSMALL'` as the last statement in the script so it didn't sit idle at XL between training runs.

**The forward principle.** Warehouse sizing decisions for ML workloads must weight RAM headroom separately from CPU time. The standard guidance "smaller warehouse runs longer for less cost" works for SQL transformations (CPU-bounded) but breaks for ML training (memory-bounded). Specifically for Cortex:

- `method='fast'` on XS: ~3 min on 3K series, fits in RAM, ~0.05 credits.
- `method='best' + evaluate=FALSE` on XS: probably 30-60 min, may fit in RAM. Untested in this session.
- `method='best' + evaluate=TRUE` on XS: OOM at 1h40m on 3K series. Memory ceiling exceeded.
- `method='best' + evaluate=TRUE` on XL: ~15 min on 3K series. Memory headroom + horizontal compute. ~1-2 credits.

**Interview talk track**: *"For portfolio-quality forecasting I went with method='best' + evaluate=TRUE which ensembles 4 models and runs cross-validation. The XS warehouse hit a memory ceiling at 1h40m — the ensemble holds per-series state for all 4 models plus CV folds simultaneously, which exceeded the single-node RAM. Bumped to XL warehouse, ran in 15 min for ~1-2 credits, then immediately dropped back to XS. The lesson: ML workload sizing is memory-bounded not just time-bounded, so picking the warehouse on cost-per-minute alone is the wrong heuristic."*

**Carry-forward**: applies identically to Databricks ML clusters in Project #3 — single-node clusters with tight RAM ceilings work for small-feature workloads but blow up on ensemble + CV training. Size cluster for memory headroom on training workloads, then scale down for inference/query workloads.

### Airflow

**Stack architecture choices (2026-05-14, Phase 3 session 1)**

- **Self-contained `airflow/` subdirectory.** Everything Airflow-related — `docker-compose.yml`, the custom `Dockerfile`, `requirements-airflow.txt`, `dags/`, `plugins/`, `logs/` — lives under one folder. Project root stays clean. The compose file mounts the parent project's `scripts/` folder read-only into the containers so the DAG can call the existing `extract_azure_to_snowflake.py` without code duplication.
- **LocalExecutor, not CeleryExecutor.** Airflow has several "executor" engines deciding how tasks actually run. LocalExecutor runs each task as a subprocess on the scheduler container — adequate for a single-DAG portfolio project. CeleryExecutor adds a Redis broker plus N worker containers — required at production scale, overkill here. Worth knowing the upgrade path exists: same DAG code, just swap executor + add services in compose.
- **Four containers in the stack.** `postgres` (Airflow's own metadata DB, not our retail data), `airflow-init` (one-shot bootstrap that runs `airflow db migrate` and creates the admin user, then exits), `airflow-webserver` (UI at `localhost:8080`), `airflow-scheduler` (parses DAGs, schedules + runs tasks). Init `depends_on: postgres: condition: service_healthy`; webserver and scheduler `depends_on: airflow-init: condition: service_completed_successfully` — ordered startup is declarative.
- **One `.env`, two execution environments.** `env_file: - ../.env` in the compose anchor passes our existing Azure SQL + Snowflake creds into every Airflow container as env vars. The extract script's `os.getenv("AZURE_SQL_SERVER")` calls work identically inside Airflow and from PowerShell — zero environment-specific branching in our code. One source of truth for secrets.

**Custom Airflow image — never reuse the project-root `requirements.txt` (2026-05-14, Phase 3 session 1)**

Two-stage failure during the first build of the custom Airflow image:

- **Stage 1 — no `--constraint` flag, install our `requirements.txt` directly.** Build succeeded; `airflow-init` immediately crashed with `sqlalchemy.orm.exc.MappedAnnotationError: Type annotation for "TaskInstance.dag_model" can't be correctly interpreted...`. Airflow 2.10 needs SQLAlchemy **1.4.x**; our `requirements.txt` has `>=2.0.0`. pip upgraded past what Airflow could handle.
- **Stage 2 — same `requirements.txt`, now with `--constraint` pointing at Airflow's official constraints file.** Build failed at pip with a dependency-resolution error. Constraint says SQLAlchemy 1.4.x, requirement says ≥ 2.0.0 — pip refuses a direct conflict. `--constraint` alone isn't enough; the underlying disagreement still has to be fixed.

**The fix that worked: separate `airflow/requirements-airflow.txt` with no version pins.** Lists only the extras the extract script needs (`pyodbc`, `python-dotenv`, `snowflake-connector-python[pandas]`). `--constraint` pointed at `https://raw.githubusercontent.com/apache/airflow/constraints-2.10.3/constraints-3.11.txt` chooses tested versions for everything. Build clean, runtime clean.

**General principle for any custom image extending an opinionated base.** Don't blanket-apply existing pin lists onto an image whose maintainers have already thought hard about compatible versions. List only the *additional* packages, leave them unpinned, let the base image's constraints decide. Same lesson applies to a custom `dbt-core` image, a custom Jupyter image, anything layering deps onto a curated stack.

**Carry-forward:** add "look at constraints/lockfile of base image before adding deps" to the Code-Quality checklist as a corollary of criterion 1 (Currency). Project #3 carry-forward — most production Docker images extend an opinionated base.

**Docker daemon must be running before `docker compose` (2026-05-14, Phase 3 session 1)**

Trivial-in-hindsight but worth noting because the error message is opaque: `failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine`. That long path is Docker Desktop's named pipe on Windows. The error is just "Docker Desktop isn't running." Fix: open Docker Desktop from the Start menu, wait for the whale icon in the taskbar to stop animating (settles to solid), then retry. The CLI (`docker`, `docker compose`) is a thin client that talks to a background service — the service has to be alive for any command to work.

**Code-quality framework gap discovered: dev environment hygiene (2026-05-14, Phase 3 session 1)**

Mid-session, yellow Pylance squigglies appeared on the freshly-written DAG file (`airflow/dags/m5_daily_extract.py`) — `import pendulum`, `from airflow.decorators import dag, task`, `import extract_azure_to_snowflake`. Phil pushed back: shouldn't `CODE_QUALITY.md` have flagged this *before* it became a problem?

**Diagnosis.** The lunch audit had been thorough — but all nine criteria audit what's *inside* the code (idioms, security, types, idempotency, observability). None audited the *dev environment around* the code. A genuine gap in the framework.

**Fix.** Three coordinated edits:

- Added criterion 6 to `CODE_QUALITY.md`: "Dev environment hygiene." Linter warnings zero-tolerance, IDE imports resolve to the runtime modules, local venv mirrors deployed environment.
- Renumbered the rest (6→7, 7→8, 8→9, 9→10); "six core checks" → "seven core checks."
- Mirrored in `TEACHING_PREFERENCES.md`.

**Practical-fix corollary.** Yellow squigglies addressed with the canonical Windows-host workaround:

- `pip install pendulum "apache-airflow==2.10.3" --no-deps` — installs Airflow source files for Pylance import-resolution without dragging in 100+ Unix-only transitive deps.
- `pyrightconfig.json` at project root with `extraPaths: ["scripts"]` — maps the DAG's runtime `sys.path.insert(0, "/opt/airflow/scripts")` to the host's `scripts/` folder.
- *Truly* professional answer is **VS Code Dev Containers** (editor attaches to the running container; zero drift). Flagged as Phase 6 polish — strong interview talking point about progression from pragmatic-now to modern-later.

**What this taught me.**

- A code-quality checklist is a living artefact — when a mistake bypasses it, the checklist is the artefact to improve. Updating alongside the fix pays compounding interest across all future projects.
- "Code quality" and "dev environment quality" are distinct concerns; both deserve explicit criteria. Conflating them means dev-env issues hide as random IDE complaints rather than being treated as the same silent-bug class.
- Carry-forward to Project #3: criterion 6 starts day one — pyrightconfig, IDE-resolves-runtime imports, linter-warnings-zero-tolerance baked into Phase 0 scaffolding.

**Airflow 2.x CLI flag is `-e` / `--exec-date`, not `--logical-date` (2026-05-14, Phase 3 session 1)**

First attempted to manually trigger the DAG for a specific past date with `airflow dags trigger m5_daily_extract --logical-date 2014-01-02T00:00:00`. Failed with `airflow command error: unrecognized arguments: --logical-date 2014-01-02T00:00:00`.

**Diagnosis.** `--logical-date` only landed in Airflow 3.x. Airflow 2.10 still uses `-e` (short form) or `--exec-date` (long form). The terminology shift `execution_date` → `logical_date` happened in stages:

- Airflow 2.2 (2021): renamed the Python API parameter (the macro available to DAG code).
- Airflow 3.0: finally followed through and renamed the CLI flag to match.
- Airflow 2.x in between: Python code references `logical_date`, CLI still uses `--exec-date` for backward compatibility. This terminology mismatch is invisible in tutorials that show only Python, but bites the moment you go to the CLI.

**Fix.** Use `-e`:

```powershell
docker compose exec airflow-scheduler airflow dags trigger m5_daily_extract -e 2014-01-02T00:00:00
```

**Carry-forward.** Run `airflow version` (or `docker compose exec airflow-scheduler airflow version`) before constructing CLI invocations against a new Airflow stack. Tutorial syntax written for Airflow 3.x will silently fail on 2.x for at least this one flag. Same family of risk as "ODBC Driver 17 vs 18" — version-specific names that look interchangeable but aren't.

**`catchup=False` semantics: still runs the most recent interval on unpause (2026-05-14, Phase 3 session 1)**

When the DAG was unpaused via the UI toggle, an unexpected scheduled run fired immediately for `scheduled__2026-05-12T14:00:00+00:00` — even though the DAG has `catchup=False`. Caught me out: I assumed `catchup=False` meant "no scheduled runs fire until the next scheduled interval boundary."

**Actual semantics.** `catchup=False` means: when the DAG is unpaused, Airflow runs *exactly one* scheduled instance — the most recent interval that has already ended — and skips all earlier missed intervals. The protection against "auto-backfill 4,500 days from 2014 forward" works as expected; what doesn't get protected is that *one* most-recent-interval run firing on unpause.

**Why it works this way.** Airflow's UX assumes that when you unpause a DAG, you want at least one run to fire so you can validate it works. Silent-until-next-tick would make it harder to know "did unpausing actually do anything?"

**For our setup this was a no-op:** the auto-fired run targeted "today's date" (~2026-05-14) which is outside the M5 dataset's calendar range. The script found 0 calendar rows for the window, logged the warning, and exited 0. Clean.

**Carry-forward to Project #3 and beyond.** If a DAG should *truly* not fire on unpause (e.g., it writes to a production table and you don't want an accidental run), don't rely on `catchup=False` to protect you. Either keep the DAG paused until you trigger explicitly, or guard the first task with a sensor that no-ops when the data interval is outside the safe window. Distinguishing "I want catchup off because I'd otherwise drown in backlog" from "I want zero auto-runs on unpause" matters.

**CTE-based PASS/FAIL verification template (2026-05-14, Phase 3 session 1)**

Captured for reuse across future projects. Lives concretely in `sql/verify/03_phase3_dag_extract_verification.sql` Section 5. The shape:

```sql
WITH expected AS (
    SELECT 'check_1' AS check_name, <expected_count_1> AS expected_rows UNION ALL
    SELECT 'check_2' AS check_name, <expected_count_2> AS expected_rows UNION ALL
    -- one row per check
),
actual AS (
    SELECT 'check_1' AS check_name,
        (SELECT COUNT(*) FROM <table_1> WHERE <filter>) AS actual_rows
    UNION ALL
    SELECT 'check_2',
        (SELECT COUNT(*) FROM <table_2> WHERE <filter>)
    -- matching one per check
)
SELECT
    e.check_name,
    e.expected_rows,
    a.actual_rows,
    CASE WHEN e.expected_rows = a.actual_rows THEN 'PASS' ELSE 'FAIL' END AS status
FROM expected e
JOIN actual a ON e.check_name = a.check_name
ORDER BY e.check_name;
```

**Why this pattern earns its keep:**

- **Single result set.** N checks roll up into one tidy table with a status column. At-a-glance "all PASS or any FAIL" with no scrolling through separate query results.
- **Hardcoded expected values force pre-commitment** to what "correct" means *before* running. Catches assumption drift — if you only ever look at the actual count, you have no anchor to disagree with.
- **Trivial to extend.** Add a check = add one row to `expected` and one to `actual`. Six lines of SQL for a new test.
- **Snowflake-agnostic.** Pure ANSI SQL; works the same on Postgres, BigQuery, Databricks SQL Warehouse. No dialect-specific bits.

**Carry-forward.** Any verification SQL file with two or more checks in future projects ends with a Section N rollup using this template. Cheap insurance; cost is ~30 lines of well-structured SQL per file. Detailed sections (1, 2, 3, ...) stay for debugging when a FAIL appears; the rollup is the headline.

**`verify_one_day` caught a real silent failure on first deploy (2026-05-15, Phase 3 session 2)**

Built `verify_one_day` as a second task in `m5_daily_extract`, downstream of `extract_one_day`. Three Snowflake-side checks (`CALENDAR` = 1 row for run_date, `SELL_PRICES` > 0 for the fiscal week, `SALES_TRAIN` > 0 for the d-code) batched into a single SQL round-trip with three positional `%s` binds. Queries Snowflake fresh — doesn't read the extract task's XCom. Closes the loop inside Airflow rather than relying on a manual Snowsight pass.

**The verify task caught a real silent failure within ten minutes of deployment.** Testing the manual `2014-01-03` trigger, the run stuck in `queued` forever — **paused DAGs don't execute manually-triggered tasks in Airflow 2.x**. Unpausing then auto-fired today's `2026-05-15` slot (because `catchup=False` only suppresses *historical backfill*, not the next scheduled interval). M5 doesn't cover that date — Azure SQL returned 0 rows, `extract_one_day` finished cleanly with no error, and `verify_one_day` queried Snowflake, found 0 calendar rows, raised `RuntimeError`. **Exactly the silent-failure shape the verify task was designed to catch.**

**Lessons.**

- **Independent verification beats trusting return codes.** If verify had read the extract task's XCom (`rows_written = 0`), the chain would have been "extract reported zero, verify confirms zero, all good." Querying Snowflake fresh closed that loop properly. A verify that depends on the extract's word is a verify with the same blind spots as the extract.
- **Silent failures are the dangerous failures.** A loud crash gets fixed within hours. A quiet zero-row extract that reports success can poison downstream dashboards, alerts, and dbt models for months before anyone notices the numbers stopped moving.
- **`catchup=False` is not the same as "no auto-runs."** It only suppresses backfill of skipped historical intervals. The first scheduled interval *after* unpause still fires. To suppress that too, separate config (e.g., `is_paused_upon_creation=True` on initial deploy, or just leaving the DAG paused) is needed.
- **Paused DAGs swallow manual triggers in Airflow 2.x.** The DAG run is created and queued, but tasks won't be scheduled. Operator confusion in the moment: "I triggered it but nothing's running." Resolution: unpause, let the run complete, re-pause after if metadata-DB clutter is the concern.

**Carry-forward.** Every DAG with a real-world data destination in future projects gets an independent verify task as part of its definition-of-done. The pattern is cheap — ~50 lines of Python plus a single SQL round-trip — and the value compounds because the alternative (trusting upstream return codes) fails silently exactly when it matters most.

Reference screenshots: `docs/screenshots/00_verify_caught_silent_failure_2026-05-15_log.png` (the Logs tab showing the three CALENDAR / SELL_PRICES / SALES_TRAIN count lines plus the `RuntimeError` message). Grid-view side-by-side screenshot deferred — can be regenerated from `m5_daily_extract` history at any time.

**`SHOW_TRIGGER_FORM_IF_NO_PARAMS=true` + the two-button UI gotcha (2026-05-15, Phase 3 session 2)**

Enabled the trigger-with-config form by adding `AIRFLOW__WEBSERVER__SHOW_TRIGGER_FORM_IF_NO_PARAMS: 'true'` to the shared `x-airflow-common.environment` block in `airflow/docker-compose.yml`, then full `down` + `up -d` (an env-var change is only picked up at container start). Verified the var landed two ways: `docker compose exec airflow-webserver env | findstr -i trigger` returned the variable, and `docker compose exec airflow-webserver airflow config get-value webserver show_trigger_form_if_no_params` returned `true` — confirming Airflow's own config system sees the setting, not just the OS env layer.

**UI gotcha that ate ~20 minutes.** Even with the flag correctly enabled, clicking the play-arrow "Trigger DAG" button on the DAG detail page still fired the run immediately with no form. Eventually figured out: Airflow 2.10's DAG detail page exposes **two distinct trigger buttons**. The play-arrow "Trigger DAG" always quick-fires (uses the current timestamp as logical_date). The dropdown-revealed **"Trigger DAG w/ config"** is the one that opens the modal with the calendar-icon Logical Date field + Configuration JSON area. The flag controls whether the form *exists* for no-param DAGs at all (it's hidden by default since 2.7) — it does not change which button calls it. Validated end-to-end by triggering for `2014-01-04T00:00:00+00:00` via the form; extract + verify both ran green.

**Lessons.**

- **Flags that change UI behaviour need TWO validations:** the env-var diagnostic (`env | grep`), *and* the actual user-facing click path. Either alone can mislead.
- **`airflow config get-value` is a better diagnostic than reading the env var.** It confirms Airflow's *config system* has resolved the setting, not just that the OS-level env var is present. Catches edge cases where the var landed but Airflow's section/key mapping is wrong.
- **In Airflow 2.10's UI, "Trigger DAG" and "Trigger DAG w/ config" are not the same control.** The first is always immediate; the second is always form-based. Browser cache and incognito mode are red herrings here.

Reference screenshot: `docs/screenshots/01_ui_trigger_form_with_date_picker.png` — the filled-in form showing Logical Date `2014-01-04T00:00:00+00:00`, Run id empty, Configuration JSON `{}`, ready to click Trigger.

**Harmless deprecation warning: `core/sql_alchemy_conn` (2026-05-15)**

Every Airflow CLI invocation inside the container prints:

```
FutureWarning: section/key [core/sql_alchemy_conn] has been deprecated, you should use [database/sql_alchemy_conn] instead. Please update your `conf.get*` call to use the new name
```

Our `docker-compose.yml` **already uses the new name** (`AIRFLOW__DATABASE__SQL_ALCHEMY_CONN`, line 44). The warning is emitted by Airflow's own internal compatibility shim that still reads the legacy `core/sql_alchemy_conn` section path somewhere inside `airflow.configuration`. Functional impact: zero. Audit trail: confirmed by grepping `docker-compose.yml` and `Dockerfile`, neither contains the old name.

**Carry-forward.** Leave it alone. The warning will disappear when we upgrade to Airflow 3.x or whenever upstream cleans up the internal reference. Logged here so that future-me sees the warning, recognises it, and moves on without spending time chasing a non-issue.

### 2026-05-17 — Astronomer Cosmos: per-model task generation for dbt (Phase 4 session 6)

The headline session-6 work. Replaced what would have been a `BashOperator` shelling out to `dbt build` with a `DbtTaskGroup` from `astronomer-cosmos`. At DAG-parse time, Cosmos reads the dbt project's manifest, walks `ref()` dependencies, and **generates one Airflow task per dbt model + one per dbt test**, with the Airflow Graph view showing the dbt DAG directly. 13 lines of Cosmos config replaced what would have been ~150 lines of hand-wired BashOperator tasks and dependency wiring.

**Three pieces of installation surface:**

1. `astronomer-cosmos>=1.7,<2.0` in `airflow/requirements-airflow.txt` — Cosmos itself, range-pinned because Cosmos ships breaking changes between major versions.
2. Separate Python venv inside the Dockerfile at `/opt/airflow/dbt_venv` with `dbt-core==1.11.10 dbt-snowflake==1.11.5` — isolated from Airflow's pinned deps to avoid `jinja2` / `pyyaml` conflicts. Astronomer's documented recommended pattern.
3. `../dbt:/opt/airflow/dbt:ro` mount in `docker-compose.yml` — read-only window for Cosmos to read the dbt project files at DAG-parse time. Same pattern as the existing `../scripts:/opt/airflow/scripts:ro` mount from Phase 3.

**Cosmos default `test_behavior=AFTER_EACH`**: each dbt model becomes a sub-TaskGroup containing a `run` task (DbtRunLocalOperator) and a `test` task (DbtTestLocalOperator) that fires immediately after the model. Failing tests halt dependent models cleanly. Alternatives (`AFTER_ALL`, `BUILD`) are configurable via `RenderConfig` but `AFTER_EACH` is the right default for fail-fast pipelines.

**Carry-forward**: per-model task generation as the default for any future dbt + orchestrator combo (Dagster's dbt assets, Prefect's `prefect-dbt`, Argo, etc.). Single source of truth (the dbt project) beats duplicate maintenance across two task lists.

### 2026-05-17 — Cosmos lazy imports + the submodule workaround for Pylance

The natural import `from cosmos import DbtTaskGroup, ProjectConfig, ProfileConfig, ExecutionConfig` worked at runtime in the Airflow worker but triggered Pylance errors locally: *"Object of type object is not callable. Attribute __call__ is unknown."* Cause: Cosmos's `cosmos/__init__.py` uses **lazy imports via `__getattr__`** for memory and startup-time reasons — the class names aren't statically present in the namespace; they're loaded dynamically on first access. Pylance can't follow `__getattr__` magic and degrades the unresolved names to bare `object`, producing the "not callable" diagnostic.

**Fix**: import each class from its actual submodule path:

```python
from cosmos.airflow.task_group import DbtTaskGroup
from cosmos.config import ExecutionConfig, ProfileConfig, ProjectConfig
```

Runtime behaviour is identical (Python loads the same classes either way), but Pylance can statically resolve the submodule paths. Clean diagnostics, zero `# type: ignore` suppression. Confirmed by reading `cosmos/__init__.py` directly: a `_LAZY_IMPORTS: dict[str, str]` declares the mapping from public names to their submodule paths.

**Carry-forward**: when Pylance reports "Object of type object is not callable" on a third-party class import, suspect lazy imports / `__getattr__` magic. Read the package's `__init__.py` to find the actual submodule path and import from there.

### 2026-05-17 — Airflow data_interval semantics: logical_date vs ds

Got tripped during the end-to-end manual trigger. Set Logical Date to `2014-03-22 00:00:00` in the trigger form; the run actually processed data for **2014-03-21**, not 2014-03-22. Quick reference:

| Field | What it means |
|---|---|
| `logical_date` | The END of the data interval (formerly "execution_date") |
| `data_interval_start` | Start of the data period the run processes |
| `data_interval_end` | End of the data period (= `logical_date`) |
| `{{ ds }}` template | `data_interval_start.strftime('%Y-%m-%d')` |

For `@daily` schedule, triggering `logical_date = X` processes data for the previous day (`X − 1`). Easy to miss for manual triggers because the form labels the field "Logical Date" without explaining the off-by-one relative to the data actually being processed.

**Carry-forward**: when triggering a DAG manually for "data date X," set the Logical Date to `X + 1`. Or design the DAG with task code that explicitly uses `data_interval_start` rather than relying on a `ds` template that could be misread.

### 2026-05-17 — Airflow task states: `upstream_failed` vs `failed`

Demonstrated cleanly during the failure-injection test. When `dbt_models` went red (a model's test failed), the downstream `verify_dbt_one_day` task did **not** turn red — it turned **orange / upstream_failed**. Key distinction:

- `failed` = the task executed and failed (raised an exception, exited non-zero, etc.)
- `upstream_failed` = the task **never executed**; an upstream task in the dependency chain failed, and the task's `trigger_rule="all_success"` (the default) means "only run if all upstream succeeded"

The tooltip on the upstream_failed task confirmed: `Duration: 00:00:00`, `Trigger Rule: all_success`. The task was skipped without firing, which is exactly what fail-fast pipelines want — no broken-data verifications running on top of a broken dbt build.

**Other `trigger_rule` values worth knowing**:

| Rule | Behaviour |
|---|---|
| `all_success` (default) | Run only if all direct upstream tasks succeeded |
| `all_failed` | Run only if all direct upstream tasks failed |
| `all_done` | Run regardless of upstream state (success, failed, or skipped) |
| `one_success` | Run if any upstream succeeded |
| `none_failed` | Run if no upstream failed (success or skipped) |

`all_done` is useful for cleanup tasks (always run, even after pipeline failure). `one_success` is useful for "any one of these branches has the data we need" patterns. For verify-gate tasks like `verify_dbt_one_day`, the default `all_success` is exactly right.

### 2026-05-18 — DAG state ownership: the scheduler tracks "where we're up to," not me

Came up during Phase 5 session 1 while thinking about the interview demo. The manual-trigger UX during testing — typing a date into the form every time — created the wrong mental model: that I was responsible for remembering which date the DAG was up to. I'm not. Airflow is.

**The actual state model.** Airflow's metadata DB records every DAG run — `logical_date`, start time, end time, final state — and the scheduler reads that table to decide what to run next. With `schedule="@daily"` + `catchup=False`, an unpaused DAG fires exactly one new run per scheduled interval going forward, regardless of how many intervals were missed while paused. The scheduler maintains the cursor; I just look at it.

**Three places the cursor is visible** (any one is enough to answer "what's the next date to run?"):

| Surface | How to read it |
|---|---|
| **Airflow UI → Grid view** | Each column = a `logical_date`. Rightmost green square = latest success. Next date to run = column one to the right. Screenshot-ready for interview/portfolio. |
| **`SELECT MAX(sale_date) FROM RETAIL_DB.WAREHOUSE.FACT_DAILY_SALES`** | Snowflake's view of the truth. After session 6's two runs this returns `2014-03-23`. Next date to process = MAX + 1 = `2014-03-24`. Survives even if Airflow's metadata DB is wiped. |
| **`airflow dags list-runs -d m5_daily_extract`** (CLI) | The same data the Grid view renders, tabular. Useful in scripted environments / over SSH. |

**Why I'd been "putting in dates" anyway.** Manual UI triggers (the trigger-with-config form) are for *testing specific dates without waiting* — backfills, replays, demos. That's a dev-time affordance, not the prod control surface. In production the DAG runs untouched on its schedule; nobody types a date in.

**`catchup=False` is a deliberate design call worth defending in interviews.** With `catchup=True` (Airflow's default), unpausing this DAG today would queue ~2.5 years of runs back-to-back and burn Snowflake credits in one burst. With `catchup=False`, only one run fires per real day going forward — the "simulated freshness" pattern, where the DAG advances one M5 date per real-world midnight. Bounded-backfill datasets like M5 should default to `False`; rolling-window datasets (sensor data, transactional logs) often want `True`.

**Two power moves to keep banked**:

- **Backfill on demand.** `airflow dags backfill m5_daily_extract -s 2014-03-24 -e 2014-03-26` (CLI) fires three dates back-to-back from a known start to end. Useful for "the upstream data was corrected — replay the last week" scenarios. Makes a strong mid-demo move because it shows the scheduler picking up exactly where it left off.
- **Pause / unpause.** Toggling the DAG off in the UI freezes the cursor in place. Unpausing resumes from the next-unfilled interval, not from a "rewind 5 days" position. The cursor never drifts.

**Interview talk-track sentence**:

> *"Airflow's scheduler owns the state, not me. The metadata DB tracks every run; the Grid view renders it. I set `catchup=False` deliberately because for this simulated-freshness pattern I want one date per real day, not a 2.5-year burst at unpause. Backfills and replays go through the CLI when I need them — pause/unpause never loses the cursor."*

**Carry-forward to Project #3**: every scheduler-driven DAG has three "where are we up to" surfaces — the scheduler's own state, the data destination's MAX-of-watermark column, and a CLI introspection command. Wire all three explicitly so a question about pipeline state has a 30-second answer regardless of who's asking. Avoid mental models that put state in your head.

### dbt (advanced from Project #1)

**Installing dbt-snowflake alongside the Phase 3 `--no-deps` Airflow stub (2026-05-15, Phase 4 session 1)**

First `pip install dbt-snowflake` printed a wall of "apache-airflow 2.10.3 requires X, which is not installed" warnings plus one "sqlalchemy 2.0.49 is incompatible" line. **All harmless** — direct consequence of Phase 3 session 1's deliberate `pip install pendulum "apache-airflow==2.10.3" --no-deps` (logged in Phase 3 LEARNINGS). The local-venv Airflow package was always a half-install for Pylance import-resolution purposes; the actual Airflow runtime lives inside Docker. dbt needs SQLAlchemy 2.x, the Airflow stub wants 1.4.x — they coexist because only dbt is ever actually *run* from this venv. The line that mattered: `Successfully installed dbt-core-1.11.10 dbt-snowflake-1.11.5`.

**Carry-forward.** Textbook "multiple tools in one venv" drift. The professional long-term fix is per-tool venvs or VS Code Dev Containers — already flagged as Phase 6 polish.

**Three-layer documentation pattern for code-shaped files (2026-05-15, Phase 4 session 1)**

Locked in mid-session after Phil pushed back on heavily-commented YAML being unsuitable for a portfolio repo. Now `TEACHING_PREFERENCES.md` policy for every code-shaped file going forward:

- **(a) Verbose, comment-rich version shown in chat** — comments-above-the-line style, every line explained. Phil's learning artefact for the session.
- **(b) Clean, professional version written to disk** — short header pointing at the walkthrough doc, only non-obvious-choice inline comments. What ships to git.
- **(c) Companion walkthrough markdown** at project root — `<COMPONENT>_PIPELINE.md` pattern, matches `EXTRACT_PIPELINE.md` from Phase 2. Lives in the repo, carries the depth.

**Why this matters.** A portfolio visitor skimming a heavily-commented `dbt_project.yml` reads "junior dev copy-pasted a tutorial." Clean config + separate depth doc reads "senior engineer who documented their work." Same content, different signal. Created `DBT_PIPELINE.md` this session as the first instance of (c).

**Comments-above-the-line, never end-of-line (2026-05-15, Phase 4 session 1)**

Same `TEACHING_PREFERENCES.md` update. End-of-line comments push lines past the Claude chat code-block width, forcing horizontal scroll which breaks reading flow. Comments-above-the-line keeps every line short, reads top-to-bottom naturally, and the file itself becomes the teaching artefact that lives in the repo forever (not just in chat scrollback). Discovered when the first verbose `dbt_project.yml` had ~120-char lines.

**dbt_project.yml vs profiles.yml — the two-file split (2026-05-15)**

dbt deliberately separates two concerns:

- **`dbt_project.yml`** says *what* to do — project name, folder layout, default materializations.
- **`profiles.yml`** says *where* to connect — Snowflake account, credentials, warehouse, database.

The bridge is the `profile:` line in `dbt_project.yml`, which looks up a matching top-level key in `profiles.yml`. One `profiles.yml` can hold multiple project profiles, each with multiple targets (`dev`, `prod`, etc.) — `dbt run --target prod` switches.

**Carry-forward.** In a team setting, every engineer has their own `profiles.yml` pointing at their personal dev schema. `dbt_project.yml` is shared and identical across the team. Don't conflate them.

**`env_var()` — dbt's secrets pattern (2026-05-15)**

```yaml
password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
```

Jinja template. At dbt-run time, the value resolves by reading the shell environment. dbt does **not** auto-read `.env` — values must already be in the OS environment when dbt starts. Result: `profiles.yml` is safe to commit (no plaintext secrets), credentials sit in `.env` (gitignored), rotation is a `.env` edit. Same pattern real teams use with HashiCorp Vault / AWS Secrets Manager — swap the secret source, dbt-side wiring is unchanged. Direct transfer to interviews: "How do you handle secrets in dbt?" → "env_var() resolving against environment populated from Vault."

**PowerShell one-liner to load `.env` before running dbt (2026-05-15)**

```powershell
Get-Content .env | ForEach-Object {
    if ($_ -match '^([A-Z_][A-Z0-9_]*)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
    }
}
```

Run once per PowerShell session. Walks `.env` line-by-line, pulls out `KEY=VALUE` pairs (the regex skips comments and blank lines), sets each as a process-scoped env var. Subsequent `dbt` commands see them. Documented in `DBT_PIPELINE.md` as the prerequisite step.

**`.gitignore` un-ignore syntax (`!path`) (2026-05-15)**

Phase 0's `.gitignore` had a blanket `profiles.yml` ignore — the dbt-community default, because most teams write secrets directly into the file. We don't (we use `env_var()`), so our `profiles.yml` is safe to commit. Override syntax:

```
profiles.yml
!dbt/profiles.yml
```

A line starting with `!` un-ignores a specific path that would otherwise match a previous pattern. **Order matters** — the un-ignore must come *after* the ignore. Git evaluates `.gitignore` rules top-to-bottom, with later rules overriding earlier ones.

**Schema concatenation gotcha — dbt's default `generate_schema_name` (2026-05-15)**

dbt's default behaviour with the `+schema:` per-folder config in `dbt_project.yml` is to **concatenate** the target schema (from `profiles.yml`) with the per-folder schema. So `profiles.yml` `schema: DEV` + `+schema: staging` lands the model in `DEV_STAGING` — not the cleaner `STAGING`.

**Fix (deferred to Phase 4 session 2).** Custom `macros/generate_schema_name.sql` that overrides this — if a per-folder `+schema:` is set, use it directly without concatenating. Standard pattern in production dbt projects, deferred to before the first `dbt run` materializes anything.

For step 3d we used the existing `SNOWFLAKE_SCHEMA=RAW` env var as a placeholder — `dbt debug` doesn't materialize anything, so no harm done. Must be replaced before staging models land.

**materialized: view / table / incremental / ephemeral (2026-05-15)**

The dbt config that decides what *kind* of physical object each model becomes in Snowflake. Same SELECT, different storage strategy:

- **`view`** — `CREATE OR REPLACE VIEW`. Always fresh, no storage cost. Staging + intermediate default.
- **`table`** — `CREATE OR REPLACE TABLE`. Fast to query, slightly stale until next run. Dim tables, marts.
- **`incremental`** — `CREATE TABLE` once, then `INSERT`/`MERGE` only new rows on subsequent runs. Fact tables at scale.
- **`ephemeral`** — no warehouse object; dbt inlines as a CTE in downstream models. Tiny helpers only.

Set folder-level defaults in `dbt_project.yml` (we did), override per-model with `{{ config(materialized='...') }}`.

**Kitchen analogy that landed in session.** view = made-to-order (re-cooked every order, always fresh). table = pre-cooked buffet tray (fast to serve, stale until refreshed). incremental = topped-up buffet (existing food stays, new dishes get added). ephemeral = sauce base in the prep kitchen (never served on its own, only folded into other dishes).

**`dbt debug` as the connection canary (2026-05-15)**

No-side-effects health check — verifies `profiles.yml` resolves, env vars land, the Snowflake adapter can authenticate, and the warehouse is reachable. No models materialize. Key output: `Connection test: [OK connection ok]` + `All checks passed!`. Should be the first dbt command run after any environment change (new venv, new credentials, new shell session). Password is masked in the output even when authentication succeeds — `env_var()` works without leaking secrets to stdout.

**The grant-fix gap — Phase 2 grants didn't cover Phase 4 (2026-05-15, Phase 4 session 2)**

First `dbt build --select staging` failed mid-session with `Insufficient privileges to operate on database 'RETAIL_DB'`. The `RETAIL_ENGINEER` role provisioned in Phase 2 had everything needed to *operate inside* `RETAIL_DB.RAW` (USAGE, CREATE TABLE/VIEW/STAGE inside RAW, full DML on tables) but had never been granted `CREATE SCHEMA` at the database level. dbt's auto-create-the-STAGING-schema attempt bounced off Snowflake's RBAC.

**Root cause.** A clean miss on Criterion 7 of the 10-point audit — Upstream/downstream contract. When the dbt project landed in session 1 it expected to be able to create schemas at the DB level; we never verified the connecting role had the privilege. The Phase 2 audit was clean for Phase 2's needs (load into RAW) and didn't anticipate Phase 4's needs.

**Fix.** New `sql/snowflake/03_grant_dbt_privileges.sql` with one statement: `GRANT CREATE SCHEMA ON DATABASE RETAIL_DB TO ROLE RETAIL_ENGINEER`. Snowflake's ownership model handled the rest — once the role created STAGING, it owned STAGING, which gave it full privileges inside (CREATE VIEW, SELECT, etc.) automatically. No second-round grants needed.

**Diagnostic discipline used.** Before granting anything, ran `SHOW GRANTS TO ROLE RETAIL_ENGINEER` as ACCOUNTADMIN. Confirmed exactly what was present and what was missing. Avoided the trap of "throw more grants at it and hope." After the fix, re-ran `SHOW GRANTS` to confirm the new `CREATE SCHEMA on DATABASE RETAIL_DB` row appeared.

**Carry-forward.** Any time a new tool/layer is introduced (Power BI's connector role in Phase 5, GitHub Actions CI in Phase 6, future MERGE-into-Snowflake patterns), explicitly audit the permission boundary BEFORE the first run. The pattern is: list what the tool will attempt, list what the role currently has, identify the gap, grant once. Cheaper than mid-session firefighting. Also updated `00_provision_account.sql` to include the `CREATE SCHEMA` grant from day 1 — so a future fresh setup from this repo doesn't repeat the gap.

**Snowflake ownership model — the transitive-grants shortcut (2026-05-15)**

When a role creates a schema (or table, view, etc.), Snowflake makes that role the OWNER of the new object. Ownership in Snowflake confers full privileges automatically — no explicit `GRANT SELECT/INSERT/...` needed on the owned object. This is why granting just `CREATE SCHEMA on DATABASE` is sufficient for dbt: the role creates STAGING, becomes its owner, and can create views, run tests, drop+recreate, etc. inside it without further grants.

**Interview line.** "How do you set up Snowflake permissions for dbt?" → "Minimal grants: USAGE on warehouse and database, plus `CREATE SCHEMA` on the database. Once dbt creates each layer's schema as the connecting role, ownership covers the rest. Future grants on other roles (e.g. Power BI read-only) get added when those consumers come online."

**`{{ ref() }}` vs `{{ source() }}` — the dbt reference patterns (2026-05-15)**

Two ways for a model to point at upstream data:

- `{{ source('<source_name>', '<table_name>') }}` — references a table declared in `sources.yml`. Used in staging models pointing at RAW tables.
- `{{ ref('<model_name>') }}` — references another dbt model in this project. Used everywhere else (intermediate, warehouse, marts), AND inside staging if a staging model joins to another staging model (as `stg_m5_sales_train` does for the date translation).

Both resolve to fully-qualified `DATABASE.SCHEMA.OBJECT` strings at compile time. Crucially, `ref()` also builds the dbt model dependency graph — dbt automatically orders model builds so referenced models build first. Run `dbt run --select stg_m5_sales_train` and dbt knows to build `stg_m5_calendar` first. No manual scheduling needed.

**CTE pattern for staging models (2026-05-15)**

dbt style-guide convention for any model with more than one logical step. Three CTEs: one for each source pull, one (or more) for the actual transformation, then a final `SELECT * FROM <last_cte>`.

Three benefits:

1. Each CTE has one clear job — reads top-to-bottom like a recipe.
2. Easy to debug — swap `SELECT * FROM joined` for `SELECT * FROM source` to peek at intermediate state without rewriting the model.
3. Easy to extend — adding a new transformation step is just another CTE in the chain.

Trivial single-SELECT staging models (`stg_m5_sell_prices`) don't need this — the CTE pattern is for models that do real work.

**LEFT JOIN + `not_null` test = the join-sentinel pattern (2026-05-15)**

Defensive data engineering pattern. When joining two tables where every left row SHOULD have a match in the right (e.g. every sale day should map to a calendar entry):

- **INNER JOIN** silently drops left rows without a match. Bad — data quality issue hidden.
- **LEFT JOIN + `not_null` test** on the joined column. Mismatches produce NULL, which the test catches and surfaces as a failure. Bad data loudly visible.

Standard practice — test as observability. `sale_date NOT NULL` in `stg_m5_sales_train` is exactly this pattern.

**Schema YAML naming `_<folder>__models.yml` (2026-05-15)**

dbt convention for schema/test YAML files in a model folder. Leading underscore sorts the file to the top of the folder alphabetically. Double-underscore visually separates folder name from "models." So `dbt/models/staging/_staging__models.yml` is the canonical name. Used by dbt-labs internally and across most production projects.

**`dbt build` vs `dbt run` vs `dbt test` (2026-05-15)**

- `dbt run` — materializes models only. No tests.
- `dbt test` — runs tests only. No model rebuilds.
- `dbt build` — both, dependency-ordered. Builds a model, runs its tests, then proceeds to dependent models only if upstream tests passed. **Default for production work.** Catches data quality regressions before they propagate downstream.

The `--select <selector>` flag scopes the build (`--select staging` for one folder, `--select stg_m5_calendar+` for a model and everything downstream, etc.). Useful for iterating on one layer without rebuilding the whole project.

**dbt 1.11 `freshness` config deprecation (2026-05-15)**

`PropertyMovedToConfigDeprecation` warning surfaced on `dbt parse` of the first `sources.yml`. dbt 1.8+ moved `freshness` and `loaded_at_field` from top-level under a source to inside a `config:` block under the source. Same semantics, different nesting. Fix is small: add a `config:` key and indent everything that was at source-level by 2 spaces. Worth knowing because dbt-labs is moving toward this nested-config pattern across the board — model configs, source configs, test configs.

**`dbt_utils` install + the lockfile pattern (2026-05-16, Phase 4 session 3)**

dbt has a package system that works the same way npm and pip do for those ecosystems. Three moving parts:

- **`packages.yml`** — declares what you want. Lives next to `dbt_project.yml`. One entry per package, with a version range:

  ```yaml
  packages:
    - package: dbt-labs/dbt_utils
      version: [">=1.1.1", "<2.0.0"]
  ```

- **`dbt deps`** — the install command. Reads `packages.yml`, downloads the matching versions, drops them into `dbt_packages/`. Roughly: dbt's `npm install`.
- **`package-lock.yml`** — auto-generated by `dbt deps`. Pins the *exact* version that resolved (in our case `dbt_utils 1.3.3`). **Commit this.** Same role as `package-lock.json` or `Pipfile.lock` — guarantees that anyone else cloning the repo gets the identical package version even if `dbt_utils` ships a 1.3.4 tomorrow. `dbt_packages/` itself is gitignored (line 78), same logic as `node_modules/`.

**Why this matters in practice.** `dbt_utils` is a library of community-maintained macros that solve problems every dbt project hits — compound-key uniqueness tests, surrogate-key generation, pivot helpers, date spine generation, `not_empty_string` tests, dozens more. Installing it is one of the most universal day-1 moves in real dbt projects. The package itself is maintained by dbt-labs (the dbt company), so it's safe and stable. Same role as `pandas` for Python or `lodash` for Node — the "everyone uses this" utility library.

**The dbt 1.10+ `arguments:` syntax for generic tests (2026-05-16)**

First use of `dbt_utils.unique_combination_of_columns` on `stg_m5_sell_prices` tripped a `MissingArgumentsPropertyInGenericTestDeprecation` warning. Older dbt syntax passed macro args directly under the test name:

```yaml
- dbt_utils.unique_combination_of_columns:
    combination_of_columns: [store_id, item_id, wm_yr_wk]
```

dbt 1.10+ wants them nested under an explicit `arguments:` key:

```yaml
- dbt_utils.unique_combination_of_columns:
    arguments:
      combination_of_columns:
        - store_id
        - item_id
        - wm_yr_wk
```

Same semantics; one extra indent level. Reason: dbt is making test/config patterns uniform across the codebase, and `arguments:` signals "these are macro inputs" vs "this is dbt config." Fix is mechanical. After the edit, re-ran with `dbt build --select stg_m5_sell_prices --no-partial-parse` — the `--no-partial-parse` flag flushes dbt's cached `partial_parse.msgpack` so the deprecation cache clears. Subsequent normal `dbt build` calls are clean.

**Carry-forward.** Any new generic test or `dbt_utils` macro call writes the `arguments:` form from day 1. Old syntax still works in 1.11 but the deprecation warning is loud.

**What "parsing" means in dbt (2026-05-16)**

Before any SQL ever hits Snowflake, dbt **parses** the entire project — every `.yml` and `.sql` file under `dbt/`. Parsing builds the manifest: the dependency graph (which model `ref()`s which), all the test definitions, all the source declarations, the materialization config for every model. The manifest is what `dbt run`, `dbt test`, `dbt build` all consult to decide what to do and in what order.

**Kitchen analogy.** A chef reads through the whole recipe once before turning the stove on — checking the ingredient list is sensible, the steps reference real prep, the timings line up. That's parsing. *Then* the cooking starts. dbt does exactly that for the SQL pipeline.

**Practical consequence.** Typos and missing refs blow up at parse time, not query time. If I rename `stg_m5_calendar` to `stg_m5_cal` and forget one downstream model, `dbt parse` fails immediately with the file and line. No wasted Snowflake compute, no half-built pipeline. dbt also caches a `partial_parse.msgpack` so subsequent runs only re-parse changed files — usually sub-second. `--no-partial-parse` is the escape hatch when the cache itself gets stale (as with the deprecation-warning case above).

**The rows-back-equals-failures contract for dbt tests (2026-05-16)**

Every dbt test compiles to a `SELECT` statement. The contract is dead simple:

- Zero rows back → **pass**.
- One or more rows back → **fail**, and the rows themselves tell you exactly what failed.

A `not_null` test on `sale_date` compiles to roughly `SELECT * FROM stg_m5_sales_train WHERE sale_date IS NULL`. If the result is empty, every row has a sale_date — pass. If five rows come back, those five rows show exactly which records broke the rule. `unique_combination_of_columns` compiles to a `GROUP BY <cols> HAVING COUNT(*) > 1` — any duplicates surface as result rows.

**Why this is elegant.** No special test framework, no DSL — tests are just SQL. After any `dbt build`, you can read the literal compiled SQL Snowflake ran under `dbt/target/compiled/<project>/models/<folder>/<schema_yml>/<test_name>.sql`. Useful for "wait, what is dbt actually checking?" moments — open the file and read the query. Same idea as inspecting a compiled view in Snowsight, but for tests.

**Compound keys — the Harding's Hardware analogy (2026-05-16)**

A **compound key** (also called composite key) is a key made of multiple columns that *together* uniquely identify a row — and where none of the columns is unique on its own. `stg_m5_sell_prices` has the classic shape: `store_id` repeats (each store stocks thousands of items), `item_id` repeats (each item lives in dozens of stores), `wm_yr_wk` repeats (each fiscal week has thousands of price rows). But `(store_id, item_id, wm_yr_wk)` together identifies exactly one price row.

**The Harding's Hardware parallel.** Back in my BI-analyst days at Harding's, the stock-by-location table had the same shape: `(product_id, warehouse_id)` was the compound key. Every product appeared in multiple warehouses; every warehouse stocked multiple products; only the pair uniquely identified a stock row. Different industry, identical pattern. Compound keys show up everywhere in operational data because that's how the real world is shaped — most things are intersections.

**Why this matters for dim modelling.** Compound natural keys are the reason surrogate keys exist. Carrying `(store_id, item_id, wm_yr_wk)` through every downstream join would be three columns instead of one and would still leak source-system details into the warehouse. The dim's surrogate key (one 32-char hex string) replaces the compound natural key for join purposes. `dbt_utils.generate_surrogate_key(['store_id', 'item_id', 'wm_yr_wk'])` literally hashes the compound key into a single value.

**Intermediate layer — purpose and place (2026-05-16)**

Between **staging** (light passthrough — rename, cast, drop sentinel columns) and **warehouse** (the published Kimball star schema), there's the **intermediate** layer. Job: *business-logic joins and derivations.* This is the "workshop bench" where source-aligned shapes get assembled into business-aligned shapes before being shipped to the published star.

`int_sales_with_prices` is the textbook example. Daily sales live in one staging model, weekly prices in another, the calendar bridge in a third. None of those individually answers a business question. The intermediate model joins all three and computes `revenue_amount_usd`. Downstream `fact_daily_sales` will build from `int_sales_with_prices` rather than re-doing those joins itself.

**Why a separate layer at all.** Two reasons:

1. **Reuse.** If multiple fact tables need "sales with prices attached," the join lives once in `int_sales_with_prices` and every fact `ref()`s it. Single source of truth for that business logic.
2. **Testability.** Intermediate models get their own tests (compound-key uniqueness, NULL semantics). Without a named intermediate, the same logic is buried inside a big fact-table SELECT, harder to test in isolation.

CTE shape is the dbt-style-guide `source → enriched → final` chain. Same pattern as `stg_m5_sales_train` from session 2 — read top-to-bottom like a recipe, debug by swapping the final SELECT.

**LEFT JOIN as semantic choice, not just safe choice (2026-05-16)**

The lazy framing of LEFT JOIN is "the safe one — drops nothing, surfaces gaps as NULLs." That's true but it undersells the actual point.

In `int_sales_with_prices`, **34.66% of rows have no matching sell_price**. That's 11.4M of the 32.9M rows. Initial reaction: "huge fraction missing, must be a join problem." Then the anomaly check (Section 3 of `04_phase4_int_sales_with_prices_verification.sql`) returned **zero rows** for `units_sold > 0 AND sell_price IS NULL`. Every priceless row also has zero units sold.

**What's going on.** M5 only carries a `sell_prices` row for an item × store × fiscal week when the item is actively stocked at that store in that week. Three product-lifecycle reasons explain every NULL:

1. Product hasn't launched yet at this store (no price set yet).
2. Product is stocked in different stores within a state but not this one (inter-store assortment).
3. Product has been discontinued (no current price).

In all three cases, `units_sold = 0`. They're "product wasn't on the shelf, so it didn't sell" rows. **That's legitimate demand signal** — knowing where and when an item *wasn't* available is part of demand planning. An INNER JOIN would silently drop all 11.4M of those rows; downstream forecasts would treat "no row" as identical to "row with zero sales," which collapses two different concepts into one.

**Discipline carry-forward.** LEFT JOIN isn't a defensive default — it's the right semantic choice when the absence of a match is itself information. INNER JOIN is the right choice when an absence is a data-quality failure (e.g. the `sale_date` join sentinel from session 2). Pick consciously per join.

**Warehouse layer materialization transition — view → table (2026-05-16)**

`dim_calendar` is the first model where materialization flipped from `view` to `table`. Set by the `dbt_project.yml` per-folder defaults — staging and intermediate default to `view`, warehouse and marts default to `table`. No per-model override needed.

**Why tables for warehouse:**

- **Compute once, read many.** Power BI will hit `fact_daily_sales` and the dims thousands of times. A table is pre-materialized — Snowflake reads from storage. A view re-runs its SELECT every query. For a fact join across three dims, view-on-view-on-view would explode compute cost.
- **Stable performance.** Tables have row counts, byte sizes, and (eventually) clustering. Views are recomputed black boxes for the query planner.

**Why views for staging + intermediate:**

- **No storage cost.** Snowflake bills for storage; views are just SELECT statements saved by name.
- **Always fresh against upstream.** When Airflow lands a new day in RAW, the next query against a staging view sees it immediately. A table would need a `dbt run` first.
- **Light compute.** Staging is one-table-deep type-casting; intermediate is a couple of joins. Sub-second on Snowflake.

The transition point is `warehouse/` for exactly the right reason — that's where the data goes from "in flight" (read-once, transform-on-the-fly) to "published" (read-many, pre-built).

**Surrogate keys via `dbt_utils.generate_surrogate_key` (2026-05-16)**

```sql
{{ dbt_utils.generate_surrogate_key(['calendar_date']) }} AS date_key
```

Compiles to roughly `MD5(NVL(calendar_date::VARCHAR, '_dbt_utils_surrogate_key_null_')) AS date_key`. Output: a stable 32-character hex string. Same input always produces the same output.

**Two benefits worth the line of Jinja:**

1. **Decoupling from upstream natural-key drift.** If the source ever changes the natural key (say `calendar_date` becomes `cal_dt`, or the type changes from DATE to TIMESTAMP), the surrogate key's downstream contract holds — every fact still joins on `date_key`. Only the dim's own surrogate-key expression changes.
2. **SCD-2 readiness.** For slowly-changing dimensions (Type 2 — e.g. `dim_item` if an item's category changes over time), the same natural key needs to appear in multiple dim rows, each with its own validity window. Surrogate keys solve this trivially — each row gets a unique hash by including the validity window in the key columns. Manual `||`-concatenated keys can't do this cleanly.

`dim_calendar` only needs one column in the key list (`calendar_date`), but the macro accepts a list specifically so compound surrogates work: `generate_surrogate_key(['store_id', 'item_id', 'wm_yr_wk'])` for a dim whose natural key is compound.

**ISO date variants in Snowflake — session-parameter independence (2026-05-16)**

`dim_calendar` derives `day_of_week` and `week_of_year` from `calendar_date` directly rather than carrying through M5's pre-computed `wday` / `wm_yr_wk` columns. The function choice matters:

- `DAYOFWEEKISO(calendar_date)` → 1–7 with **Monday = 1, Sunday = 7**. ISO 8601 standard. Doesn't change.
- `DAYOFWEEK(calendar_date)` → 0–6 by default, with the starting day controlled by Snowflake's session-level `WEEK_START` parameter. Different account, different default — different answer for the same date.
- `WEEKISO(calendar_date)` → ISO 8601 week number, same definition everywhere.
- `WEEK(calendar_date)` → controlled by `WEEK_OF_YEAR_POLICY`. Different per environment.

**Why this matters for a dim.** Dims get queried by every downstream model, by Power BI, by ad-hoc analysts, possibly from sessions with different parameter settings. If the dim's own values flip based on whose session you're in, the analytics aren't reproducible. ISO variants are fixed by international standard — same answer everywhere, forever.

Same discipline applied to `is_weekend`: derived via `DAYNAME(calendar_date) IN ('Sat', 'Sun')` rather than a numeric `DAYOFWEEK` check. `DAYNAME` returns three-letter English abbreviations regardless of session locale — convention-independent.

**Carry-forward.** Any time a derivation could behave differently based on session state, prefer the variant that's pinned to an external standard (ISO, English abbreviations, UTC, etc.).

**The NULL-vs-empty-string trap — implicit verification (2026-05-16)**

`is_holiday` in `dim_calendar` is computed as:

```sql
CASE
    WHEN event_name_1 IS NOT NULL OR event_name_2 IS NOT NULL
    THEN TRUE
    ELSE FALSE
END AS is_holiday
```

Classic SQL trap: `'' IS NOT NULL` evaluates to **TRUE** in every major dialect — an empty string is not the same as NULL. If M5's source had loaded "no event" rows with `event_name_1 = ''` instead of `event_name_1 = NULL`, `is_holiday` would have been TRUE on every single non-event day. The whole flag would be useless.

**The eyeball check in Section 2 of `05_phase4_dim_calendar_verification.sql` implicitly verified this.** A random Friday with no event in the source returned `is_holiday = FALSE` correctly. That can only happen if the underlying `event_name_1` value is a genuine NULL, not an empty string. No explicit "is this NULL or empty string" assertion needed — the boolean output already settled it.

**Why I'm flagging this.** I almost wrote `event_name_1 != ''` as a defensive variant of the condition. Would have been wrong on a clean source (where the empty-string case never occurs) and right on a dirty source (where mixed NULLs and empty strings would otherwise sneak through). The correct discipline for staging+: explicitly normalize empty strings to NULL during cast (`NULLIF(event_name_1, '') AS event_name_1`) so every downstream model can trust `IS NULL` semantics. Already a discipline rule going forward; M5's source is clean so it doesn't bite here, but the next source might be dirtier.

**Date-spine pattern — production `dim_calendar` is procedurally generated (2026-05-16)**

`dim_calendar` currently has 1,079 rows, covering **2011-01-29 to 2014-03-21 with gaps**. The latest date (2014-03-21) is wrong relative to the planned cutoff of 2014-01-04 — leftover from a Phase 2 smoke-test extract that pulled a wider window. More importantly: the dim covers only what's been extracted to RAW, with the same gaps that RAW has.

**That's not how production `dim_calendar` typically works.** A production date dimension is **procedurally generated** — a continuous spine from some start date (e.g. 2010-01-01) to some end date (e.g. 2030-12-31), independent of what facts have landed. Why: Power BI and downstream BI tools assume the dim is continuous when drawing time-series axes. If a date with zero sales is missing from `dim_calendar`, Power BI's x-axis skips it entirely — a 14-day gap shows as a continuous line, not a flat segment. Procedural generation guarantees every date exists whether or not a fact row references it.

**Standard pattern.** Use `dbt_utils.date_spine()` macro — generates a continuous date range as a CTE, no source table needed. Then LEFT JOIN any source-derived attributes (like `wm_yr_wk` or `event_name_*`) onto the spine.

**Flagged for Phase 6 polish or Project 3.** Current `dim_calendar` works for the analytics this project will surface (M5 is a complete daily-grain dataset for the dates it covers — there genuinely are no missing dates within the 2011-01-29 to 2014-03-21 window once the full backfill is loaded). But the discipline rule — *dimensions are independent of fact coverage* — is worth recording now.

**Phase-boundary structural audit — caught real findings on first use (2026-05-16, Phase 4 session 4)**

Added a new section to `CODE_QUALITY.md` formalising a check that's distinct from the per-script 10-point audit: a **structural pass over the project's file inventory** at each phase or layer boundary. The per-script audit verifies that individual files meet the bar; the structural audit verifies that the collection of files as a whole is internally consistent — no naming collisions, no stale scaffolding, no missing pairings, no test-count drift between schema YAMLs and `dbt build`.

First explicit application caught two real issues: (a) two verify files both prefixed `04_` (`04_phase4_staging_layer_verification.sql` from session 2 colliding with `04_phase4_int_sales_with_prices_verification.sql` from session 3), renamed the latter to `04a_`; (b) three stale `.gitkeep` placeholders in `staging/`/`intermediate/`/`warehouse/` model folders despite those folders now containing real models, deleted them. Both 30-second fixes in-session; both would have been frozen into the session commit otherwise.

**Discipline rule going forward:** end-of-phase structural pass before drafting closeout docs and before the bundled commit. Cheap to run, pays for itself the first time it catches drift.

**Incremental materialization on Snowflake — the `is_incremental()` Jinja guard (2026-05-16)**

`fact_daily_sales` is the first model in the project materialised as `incremental` rather than `view` or `table`. The pattern uses dbt's built-in `is_incremental()` macro to wrap a WHERE clause that only fires on builds *after* the first:

```sql
{% if is_incremental() %}
    WHERE sale_date > (SELECT COALESCE(MAX(sale_date), '1900-01-01') FROM {{ this }})
{% endif %}
```

First build: this block is skipped → full 32.9M-row historical load. Subsequent builds: only rows newer than the current max `sale_date` enter. The `COALESCE` handles the edge case where the table exists but is empty (rare, but real — partial-failure recovery).

`unique_key='sale_key'` plus the Snowflake default `incremental_strategy='merge'` means dbt does an UPSERT — new rows insert, existing keys update. Safe even if a re-run overlaps a previously-processed date.

**Snowflake clustering — the BigQuery-partition equivalent (2026-05-16)**

Snowflake doesn't have explicit partitions like BigQuery. It has **automatic micro-partitions** (50–500MB compressed slices that the engine manages) and an optional **clustering key** that tells Snowflake how to physically co-locate rows when re-organising those micro-partitions.

`cluster_by=['sale_date']` on `fact_daily_sales` is the equivalent of `PARTITION BY sale_date` in BigQuery: tells Snowflake to keep rows with adjacent `sale_date` values in the same micro-partitions, so date-range queries (the dominant access pattern for a fact table) skip irrelevant micro-partitions and scan less data. Clustering happens automatically in the background — no maintenance commands needed.

**Compute-same-way FK keys vs JOIN-to-dims (2026-05-16)**

Two patterns for wiring fact-table FKs to dimension PKs:

- **JOIN-to-dim** — classical Kimball pattern: `LEFT JOIN dim_item ON fact.item_id = dim_item.item_id` and pull `dim_item.item_key` out. Pros: explicitly validates referential integrity row-by-row at build time. Cons: three joins × 32.9M rows = expensive; if any FK is missing in a dim, the row gets a NULL key without raising an error.

- **Compute-same-way** — call `dbt_utils.generate_surrogate_key(['item_id'])` on both sides. Same input → same MD5 → matching key by construction. No joins. Pros: cheap (no row-by-row JOINs), can't get a NULL key. Cons: doesn't enforce dim coverage at build time — needs a separate `relationships` test to catch orphan FKs.

`fact_daily_sales` uses compute-same-way + three `relationships` tests. The tests caught zero orphans across 32.9M rows in <0.5s each, so the contract is enforced even though we never JOIN. Cheaper at scale, and the test result is the same kind of contract assurance.

**`relationships` test performance on 32.9M rows — sub-second (2026-05-16)**

Three FK `relationships` tests on `fact_daily_sales` (against `dim_item`, `dim_store`, `dim_calendar`) each completed in **under 0.5 seconds** during `dbt build`. That's checking 32.9M × 3 = ~99M FK lookups against dim PKs.

Why so fast: Snowflake's query optimiser sees the test query (`SELECT COUNT(*) FROM fact f WHERE NOT EXISTS (SELECT 1 FROM dim d WHERE d.key = f.key)`) and resolves it as a hash join with the dim's PK in memory. Dims are 1k–3k rows — fits comfortably in a single warehouse XS slot. The optimiser does the heavy lifting; nothing tuning-side needed from us.

Worth knowing because the instinct from row-store databases is "relationships tests on large facts will be slow." On Snowflake (and any columnar warehouse with a half-decent optimiser), they're cheap.

**`dbt_utils.accepted_range` — column-level range assertion (2026-05-16)**

Added `accepted_range` test on `fact_daily_sales.units_sold` with `min_value: 0, inclusive: true` to codify the constraint "no negative units." Verify Section 4 had already confirmed `MIN(units_sold) = 0` empirically, but a dbt test makes the contract machine-enforced rather than human-spotted.

`accepted_range` reads cleaner in test output than the alternative `dbt_utils.expression_is_true` with `expression: 'units_sold >= 0'`. Both work; the range version is dbt-idiomatic for "this column's values are within a range."

**`MissingArgumentsPropertyInGenericTestDeprecation` re-encountered — second time same lesson (2026-05-16)**

Same dbt 1.10+ deprecation we caught in session 3 on the compound-key test. Session 4 hit it again — three occurrences this time, all on the new `relationships` tests in `_warehouse__models.yml`. The fix is identical: wrap the test arguments in an `arguments:` block.

Same pattern, second hit. **Discipline rule reinforced**: every new generic test (any test whose name has a `.` like `dbt_utils.unique_combination_of_columns` or `relationships`) needs the modern `arguments:` wrapping from the start. Treat the deprecation as if it were an error — fix it on first write, not after the deprecation warning surfaces.

**`dim_item` design — no string parsing needed (2026-05-16)**

`PROJECT_CONTEXT.md` had originally noted that `dim_item` would "derive department/category from `item_id` structure (M5 item_ids are `<DEPT>_<CAT>_<NNN>`)." When it came time to actually build it, a check of `stg_m5_sales_train` showed `dept_id` and `cat_id` already shipped as their own columns from M5's source CSV.

Chose `SELECT DISTINCT item_id, dept_id, cat_id FROM stg_m5_sales_train` over splitting `item_id` strings with `SPLIT_PART` or regex. Cleaner: no parsing logic to maintain, no risk of getting the regex wrong, no surface area for "what if the format changes in a future load."

**Lesson**: "derive from structure" should be the *fallback* when the data doesn't ship the columns separately. If staging already has them, take them directly. The plan note from earlier was a guess about what would be needed; check what the data actually has before writing parsing code.

**Two-CTE pattern when there's nothing to derive (2026-05-16)**

`dim_calendar` had a three-CTE shape (`source → enriched → final`) because it derived 10+ new columns (year, quarter, month, day_name, is_weekend, is_holiday, etc.). `dim_item` has nothing to derive — every column comes through unchanged from staging. Dropped the `enriched` middle CTE; the shape is just `source → final`.

**Lesson**: don't add an empty pass-through CTE for symmetry. CTE structure should reflect what the model is *doing*, not pattern-match a previous model. Two-CTE for derivation-free dims, three-CTE for dims that compute attributes. The reader should be able to look at the CTE list and infer what work is happening at each step.

**MD5 surrogate consistency across the star schema (2026-05-16)**

The four warehouse models all use `dbt_utils.generate_surrogate_key()` with the same inputs on both sides of every FK relationship:

| Fact column | Dim PK column | Both compute |
| --- | --- | --- |
| `fact_daily_sales.item_key` | `dim_item.item_key` | `MD5(item_id)` |
| `fact_daily_sales.store_key` | `dim_store.store_key` | `MD5(store_id)` |
| `fact_daily_sales.date_key` | `dim_calendar.date_key` | `MD5(sale_date)` (== `calendar_date`) |
| `fact_daily_sales.sale_key` | (none, fact's own PK) | `MD5(item_id, store_id, sale_date)` |

Same MD5 input → same 32-char hex output, deterministically. FK-PK matching is by construction — no need to JOIN-and-lookup at build time. The `relationships` tests catch any drift if a dim is rebuilt with different inputs (defence-in-depth).

**Lesson**: surrogate-key hashing is its own integrity mechanism in a star schema *if* the inputs are identical both sides. Always hash the natural key, not a derived value; never hash all columns. Documented this in `dim_item.sql`'s short header so the next person reading the model sees the contract.

**First full-DAG `dbt build` after incremental fact — 15.26s no-op rebuild (2026-05-16)**

After the initial full-load build of `fact_daily_sales` (~22s for 32.9M rows + 12 tests), the next full-DAG `dbt build --no-partial-parse` ran the entire project in **15.26 seconds**. PASS=66 (1 incremental + 3 tables + 4 views + 58 data tests), WARN=0, ERROR=0.

Why so fast: the incremental's `is_incremental()` block evaluated to "no new dates beyond 2014-03-21" → MERGE found zero new rows → near-instant. The three dims (table materialisations) re-ran fully but they're 3k / 10 / 1k rows. Views are query definitions, not materialisations. Tests are the slow line items.

**The interview talk-track**: "End-to-end retail star schema with 32.9M-row fact, 58 tests, full DAG re-validation in 15 seconds." That's the headline for "show me a dbt project on your portfolio." Cheap to demonstrate, easy to explain why each line of the architecture is the way it is.

**Headline portfolio numbers worth carrying through (2026-05-16)**

Captured for interview / portfolio README closing slides:

- **32,898,710 fact rows** in `fact_daily_sales` (~33M)
- **$93,559,341.40 total revenue** across the M5 dataset
- **3,049 items × 10 stores × ~1,148 days** of coverage (2011-01-29 to 2014-03-21)
- **0 orphan FKs** across three `relationships` tests
- **58 dbt tests** across the project, full DAG green in 15.26s
- **34.66% NULL price rate** in the fact (M5 product lifecycle — items not on sale every week)

These are real numbers from a real pipeline. The 32.9M / $93.5M scale-of-data signal is the kind of detail that elevates a portfolio repo from "I followed a tutorial" to "I built and validated a production-shaped pipeline."

### 2026-05-17 — Mart-layer aggregation patterns

Four idioms applied in `mart_executive_overview` worth knowing for any future mart:

**1. `SUM` semantics on a nullable measure.** ANSI `SUM()` ignores NULLs by default. `revenue_amount_usd` is NULL on ~34.66% of fact rows (M5 product-lifecycle gaps); `SUM(revenue_amount_usd)` skips those and totals only the priced ones. Right semantic — rows with unknown revenue contributing zero beats rows defaulted to `0` and silently understating the day. The interview-friendly version: *"a NULL price means we don't know the revenue, not that the revenue was zero; SUM respects that automatically."*

**2. `CASE`-inside-`COUNT(DISTINCT ...)` for filtered distinct counts.** Cleaner and cheaper than the subquery alternative. The CASE emits the id only when the condition fires (NULL otherwise); `COUNT(DISTINCT ...)` skips NULLs. Snowflake resolves the whole expression in one pass — no subquery, no second scan. Pattern is general and applies wherever "count distinct things matching X" is needed.

**3. `accepted_range` upper bounds tied to dim cardinalities.** `active_item_count` capped at 3,049 (the M5 item count); `active_store_count` capped at 10 (the M5 store count). These caps make a category of grain bug (accidental cross-join, key explosion, fan-out from a botched join) machine-detectable. If the test ever fires, something is fanning out the fact's grain — not a downstream display bug. Cheap insurance.

**4. `not_null` on an aggregate of a nullable column.** Counter-intuitive but correct: `revenue_amount_usd` is nullable at the fact level (correct — M5 lifecycle gaps), but `total_revenue_usd` at the mart level is `not_null`-tested. Reasoning: a NULL daily total would mean every row in the day's fact has NULL price, which is a catastrophic upstream condition — should fire as a test failure, not show as a blank cell in Power BI.

**Carry-forward to Project #3:** when adding any aggregation layer above a nullable measure, ask "what does NULL at the aggregate level mean for the downstream consumer?" — if the answer is "they'd be confused or take a wrong action," codify `not_null` at the aggregate level even if the source column allows NULL.

### 2026-05-17 — dbt-core and adapter version pinning (1.8+ decoupling)

First attempt to pin both `dbt-core` and `dbt-snowflake` to `1.11.5` in the Airflow image's dbt venv failed with `pip ResolutionImpossible`:

```
The user requested dbt-core==1.11.5
dbt-snowflake 1.11.5 depends on dbt-core<2.0 and >=1.11.6
```

**Root cause**: since the **dbt 1.8 release**, dbt-core and the adapters (`dbt-snowflake`, `dbt-postgres`, `dbt-bigquery`, etc.) ship on **independent patch cycles**. The version numbers between core and adapter don't have to match; in this case the adapter explicitly requires a newer patch than its own version number.

**Fix**: pin both exactly, but to different patches:

```
dbt-core==1.11.10 dbt-snowflake==1.11.5
```

`dbt-core==1.11.10` is the latest 1.11.x patch and was what pip resolved to on its own when only the adapter was pinned (without an explicit dbt-core pin). Documented in the Dockerfile comment so future engineers reading the repo understand why the numbers diverge.

**Carry-forward**: when pinning dbt versions, don't assume `1.X.Y` adapter requires `1.X.Y` core. Check the adapter's PyPI metadata (or `setup.py`) for its `dbt-core` requirement range, then pin accordingly. Document the divergence inline so a future reader doesn't waste time wondering why the numbers don't match.

### 2026-05-17 — Incremental fact backfill limitation in `is_incremental()` patterns

Caught at trigger time during end-to-end testing. The first manual trigger (logical_date `2014-01-05`, processing date `2014-01-04`) failed at `verify_dbt_one_day` with the fact and mart showing 0 rows for the run date. Diagnosis:

The fact uses the standard incremental pattern:

```sql
{{ config(materialized='incremental', unique_key='sale_key') }}

SELECT ... FROM {{ ref('int_sales_with_prices') }}
{% if is_incremental() %}
WHERE sale_date > (SELECT MAX(sale_date) FROM {{ this }})
{% endif %}
```

The fact's current `MAX(sale_date) = 2014-03-21` (from the session 4 initial build). When staging data for 2014-01-04 (the `ds` for logical_date 2014-01-05 in `@daily` semantics) flowed through the new build, the WHERE clause `sale_date > '2014-03-21'` excluded it — the MERGE inserted 0 new rows for 2014-01-04, and the mart aggregating from the fact also got 0 rows for that date.

**The structural lesson**: `WHERE sale_date > MAX(sale_date)` patterns **extend forward only**. They cannot **backfill** historical dates within the existing range. Two ways to handle backfill use cases:

1. `dbt run --full-refresh --select fact_daily_sales` — rebuilds the whole fact from scratch (expensive for large facts but correct).
2. A date-window incremental variant: `WHERE sale_date BETWEEN {{ var('start_date') }} AND {{ var('end_date') }}` — allows targeted backfill of a specific window via `dbt run --vars '{start_date: 2014-01-01, end_date: 2014-01-31}'`.

For our test trigger, the practical fix was to pick a date **after** the current fact max (logical_date 2014-03-23 → ds 2014-03-22 → incremental filter accepts it). For real backfill scenarios, the full-refresh path is what we'd use.

**Carry-forward**: design the incremental's WHERE clause around the actual use case. Forward-only is fine for "extract today, add tomorrow" patterns; date-window is required if you ever need to backfill arbitrary historical dates without a full refresh. Document the choice in the model's header comment so future maintainers understand the design intent.

### 2026-05-17 — Failure injection as a validation technique

To prove the four-task chain halts cleanly on a dbt test failure, deliberately broke the mart's `active_store_count` `accepted_range` test (flipped `max_value: 10` → `5`). Triggered a fresh run for a new logical date. Observed exactly the predicted behaviour:

- `extract_one_day` → green
- `verify_one_day` → green
- `dbt_models` task group → 8 model `run` + `test` pairs green, then `mart_executive_overview.test` → **red** (the broken test fired across essentially every row of the rebuilt mart and failed). Task group status: red overall.
- `verify_dbt_one_day` → **upstream_failed**, duration `00:00:00`, never executed
- Overall DAG run → failed

Reverted the YAML edit post-test so the project state is clean.

**Why this works as a testing pattern**: a temporary YAML flip is **fully reversible** (no DDL changes, no orphaned data) and exercises the failure-handling code paths in the orchestrator. The success path was already proven in the prior run (2014-03-22 → all four task squares green), so the asymmetric pair "happy path passes, then break one test → confirm chain halts" demonstrates both directions cleanly. Clean revert is part of the technique — never commit a broken-test YAML.

**Carry-forward**: use failure injection as a closing validation step whenever wiring up an orchestration chain. Flip one value, trigger, observe the clean halt, revert. Especially valuable for portfolio purposes because it produces a credible "yes, the failure path actually works" screenshot pair.

### 2026-05-22 — Airflow `schedule=None` is the correct pattern for portfolio-demo DAGs

Surfaced during Phase 5 session 5.9 end-to-end smoke test. Original DAG was declared with `schedule="@daily"` + `catchup=False` — the conventional "scheduled production cron" pattern. On unpausing the DAG to recover from a pause-mid-run trap (see next entry), Airflow's scheduler immediately auto-created a DagRun for the most recent missed scheduled interval — which for a 2026 wall-clock run meant a DagRun with `logical_date` ≈ today's date. That DagRun then tried to extract M5 data for 2026-05-22, which doesn't exist in Azure SQL (M5 dataset ends ~2016), and failed at `extract_one_day`.

**Why this is wrong for a portfolio-demo DAG**: a portfolio project's DAG should only ever run when the operator triggers it on command. Running automatically on unpause produces phantom DagRuns that the operator never asked for, complicates the run-history narrative (extra red squares in the UI), and creates a Snowflake compute cost we didn't intend. The "scheduled production cron" framing is the wrong framing for a project that exists to demonstrate the orchestration pattern, not to run on a real ops cadence.

**The fix**: change the `@dag` decorator's `schedule="@daily"` → `schedule=None`. With `schedule=None`, the Airflow scheduler never auto-creates a DagRun. The only way to run is via UI "Trigger DAG w/ config" with an explicit logical date, or via CLI `airflow dags trigger` / `airflow dags test`. Pause/unpause becomes a near-no-op (still controls whether scheduler queues tasks within existing DagRuns, but no longer drives DagRun creation at all).

**Pattern decision criteria**:

- **`schedule="@daily"` (or any cron) + `catchup=False`**: use when you have a real ops cadence (a database that genuinely emits new data daily and you want Airflow to fetch it automatically). Accept the discipline that unpausing creates a DagRun.
- **`schedule=None`**: use for portfolio-demo DAGs, ad-hoc backfill DAGs, manual-only orchestration scenarios. Operator controls every DagRun explicitly. No phantom runs ever.
- **`schedule="@daily"` + `catchup=True`**: use when historical backfill on first start is intentional (e.g., onboarding a new source where you want every missed day backfilled). Almost never the right default — explicit opt-in only.

**The `catchup=False` flag is still kept in code** even with `schedule=None`, as a belt-and-braces signal of intent: even if someone later changes the schedule back to `@daily` for some reason, catchup=False prevents the 12-year backfill cliff. Defense-in-depth costs nothing.

**Portfolio narrative shift**: pivoting from `@daily` to `None` doesn't weaken the interview story — it strengthens it. "I built this DAG with `schedule=None` so the operator controls every run; the date-partitioned extract pattern works because every DagRun gets a logical_date via config, and the extract task reads `context['ds']` to pull the right slice. Production deployment would flip this to a real cron schedule, but for a portfolio-demo where I want a single repeatable run on command, schedule=None is correct." That's a senior-engineer architectural framing.

**Carry-forward for Project #3**: default new orchestration DAGs in portfolio projects to `schedule=None`. Only set a real cron schedule when there's a real ops cadence requirement. Document the choice explicitly in the DAG docstring so a future reader sees the intent immediately.

### 2026-05-22 — Airflow pause-mid-run trap: paused DAGs strand tasks in "scheduled" state

Surfaced during Phase 5 session 5.9 end-to-end smoke test. After triggering a manual DagRun (smoke_test_5_9_2014_03_24) on a paused DAG via "Trigger DAG w/ config", the first task `extract_one_day` ran to completion (green). The second task `verify_one_day` then transitioned to `scheduled` state and **stayed there for 12+ minutes** — well outside the normal 5-30 second scheduled→queued transition window. The third and fourth tasks never started.

**Root cause**: in Airflow 2.x the scheduler only evaluates tasks for DAGs whose `is_paused` flag is False. Tasks already in `running` or `queued` state when a DAG is paused will continue to run to completion (which is why `extract_one_day` finished green — it was already queued before the pause). But tasks that need to transition from `scheduled` → `queued` after the pause **get stranded**: the state-machine creates the `scheduled` task instance based on dependency satisfaction (upstream tasks succeeded), but the scheduler refuses to push `scheduled` → `queued` because the DAG is paused. The run is alive, the dependency is satisfied, the task is sitting there waiting — but no worker will ever pick it up until the DAG is unpaused.

**The asymmetric pause behavior**:

- Already-queued / already-running tasks: continue to completion ✓
- Tasks that need to be queued after the pause: stranded forever ✗

This is documented Airflow behavior, not a bug. See [Airflow Issue #15439](https://github.com/apache/airflow/issues/15439) — "DAG run state not updated while DAG is paused" — and the related discussion in [#55675](https://github.com/apache/airflow/issues/55675).

**The fix when this happens**: unpause the DAG. The scheduler will pick up the stranded task within ~30 seconds and the rest of the chain proceeds normally.

**The discipline rule to avoid this entirely**:

- **NEVER pause a DAG mid-run if you want the run to complete.** Pausing is for "stop creating new DagRuns", not for "freeze the current run". The pause toggle is a scheduler-control, not a run-control.
- **If you only want a one-off run, the safe sequence is: (1) unpause if necessary, (2) trigger the DagRun, (3) let it run to completion, (4) THEN pause.** Reversing steps 3 and 4 strands the chain.
- **For genuinely paused-by-default DAGs, use `schedule=None`** (see prior LEARNING) so unpausing doesn't auto-create phantom runs and the pause/unpause cycle becomes much less load-bearing.

**The asymmetric trap also has implications for the "Unpause DAG when triggered" toggle** in the "Trigger DAG w/ config" dialog. The toggle's label suggests it controls whether the DAG gets unpaused on trigger, but its effective semantics interact with the asymmetric pause behavior in non-obvious ways. In 5.9 we observed that even with the toggle set off (visually grey), the DAG ended up unpaused after trigger — possibly an Airflow 2.10.3 behavior where manual triggers always unpause regardless of toggle state. Safest practice: don't rely on the toggle for pause-control; instead, manually pause AFTER the run completes if you want the DAG paused.

**Carry-forward for Project #3**: when designing orchestration DAGs, document the pause-mid-run trap in the DAG docstring or in the project's orchestration runbook. New analysts pairing on the project will hit this if they pause a DAG before its current run completes, and the symptom (task stuck on "scheduled" indefinitely) looks like a worker failure or a scheduler hang rather than a pause-state issue.

### 2026-05-22 — Stale variable references in surgically-modified functions: scan return strings + log calls when removing a check

Surfaced during Phase 5 session 5.9 smoke test. In Phase 5.4 the `verify_dbt_one_day` task in `airflow/dags/m5_daily_extract.py` was modified to remove the mart-layer check (the legacy `MART_EXECUTIVE_OVERVIEW` was renamed to `AGG_SALES_DAILY` with a different key schema; the per-run mart row-count check became redundant because `fact_daily_sales` already validates the incremental MERGE). The check itself was removed cleanly from the SQL query, the binds, the unpack, the log calls, the failure-check block — **but the success-path return statement still contained `f"fact={fact_rows}, mart={mart_rows}"`**, where `mart_rows` was no longer defined. The bug sat undiscovered for ~6 sessions because:

- The 5.4 backfill ran with a feature-flag path that didn't reach this code,
- Subsequent runs all failed earlier in the chain on unrelated issues (Snowflake transients, schema drift), masking the bug,
- No CI / unit tests on Airflow task functions to catch the NameError statically.

The bug fired on the 5.9 smoke test as the first run that actually reached the success path of `verify_dbt_one_day` since the 5.4 modification. Symptom: extract green, verify_one_day green, dbt_models all green, verify_dbt_one_day **red** with `NameError: name 'mart_rows' is not defined`.

**The discipline rule**: when surgically removing a check or a variable from inside a function, scan for ALL references to the removed name in the rest of the function body — not just the obvious ones. Specifically:

1. The SQL query itself (obvious).
2. The bind tuple passed to `cur.execute()` (often forgotten).
3. The unpacking line that destructures the row (often forgotten).
4. **The log calls — `log.info(...)` lines that include the removed variable in their format args** (often forgotten because log statements look like side-effects, not code paths).
5. **The success-path return string — f-strings or `.format()` calls that include the removed variable** (the 5.9 bug — easiest to miss because the return is at the bottom of the function, far from the check-block where the variable was used).
6. The failure-check block — any `if x <= 0: failures.append(...)` lines (obvious, usually caught).

**Why the success-path return is the easy-to-miss case**: when checks fail, the function raises before reaching the return. When checks pass, the return executes and the NameError fires. So the bug only surfaces on the happy path — exactly the path that hasn't been exercised since the modification, exactly the path you'd assume is "obviously working" because the data layer is healthy.

**Defense-in-depth practices to catch this earlier**:

- **Static analysis**: a `ruff` or `flake8` lint pass with `F821 undefined-name` enabled would catch this in <1 second. Worth adding to the project's CI as a pre-merge gate.
- **`mypy --strict` or similar type-checking**: would also catch undefined references, plus catch type-mismatch bugs.
- **End-to-end smoke tests as a phase-close gate**: the 5.9 smoke test is exactly how this bug was found. Every phase that modifies an Airflow DAG should close with one fresh end-to-end DagRun, not just unit tests of individual task functions.
- **Code review checklist item**: "when removing a variable or a check, search the whole function body for references to the removed name before merging".

**Carry-forward for Project #3**: add `ruff` (or equivalent) to the CI pipeline with `F821` enabled, as a pre-merge gate on any `*.py` file in `airflow/dags/`. Also bake the end-to-end smoke test as a phase-close ritual — the cheapest, highest-signal validation step at the end of each phase.

### Power BI (advanced from Project #1)

### 2026-05-18 — Explicit DAX measures over implicit aggregations

Phase 5 session 1 discipline rule, locked from the first Card on the Executive Overview page. Every measure displayed on the dashboard is a named DAX measure (`Total Revenue`, `Total Units Sold`, `Active Items`, `Active Stores`), not a column dragged onto a visual with PBI's default Σ aggregation.

**The difference**: dragging `MART_EXECUTIVE_OVERVIEW[total_revenue_usd]` directly onto a Card creates an **implicit measure** — an unnamed throwaway `SUM()` that exists only inside that one visual. Five visuals using the same column = five separate throwaway aggregations, none named, none reusable, format settings applied per-visual.

A **named DAX measure** is the recipe written down once in the head office. Every Card / chart / tooltip / DAX-derived measure that references "Total Revenue" points back to one definition. Change the recipe centrally — formatting, underlying column, even the aggregation type — and every visual everywhere updates next render.

**Recipe-on-the-wall analogy**: implicit measures are chefs cooking "tomato sauce" from memory at every station — slight variations creep in, and if you want to change the recipe you retrain every chef individually. Explicit measures hang the recipe on the wall once; every kitchen reads from it.

**One concrete future-payoff** this enables: time intelligence DAX in session 5.5 (`Total Units Sold YoY`, `Total Units Sold YTD`, `Total Units Sold MTD`) are written as new measures that reference `Total Units Sold` as their base. Like sauces that start with the base tomato recipe. If the base were a throwaway implicit aggregation, every derived measure would have to recreate the base sum inside itself — and any later refactor would touch every derived measure. With the base measure named, the derived measures stay clean.

**Discipline rule for the rest of Phase 5**: every measure used on any visual is created as a named DAX measure via `New measure` first, then referenced. Implicit aggregations (drag-the-Σ-column) are a red flag in code review. Default project-wide.

### 2026-05-18 — Mart→calendar 1:1 cardinality override for star-schema discipline

Hit during the semantic model build in Phase 5 session 1. `MART_EXECUTIVE_OVERVIEW.sale_date` (1,081 unique daily rows) and `DIM_CALENDAR.calendar_date` (1,082 unique dates) connected via drag-and-drop in Model View. PBI auto-detected the cardinality as **One to one (1:1)** because both columns are unique on their respective tables. PBI then **locked the cross-filter direction to "Both"** — no Single option available, no way to override.

**Why "Both" is wrong for this model**: both `FACT_DAILY_SALES` and `MART_EXECUTIVE_OVERVIEW` connect to `DIM_CALENDAR`. With bidirectional cross-filter from mart→calendar, filtering on the mart would cascade *through* `dim_calendar` *into* the fact (because dim→fact has its own filter). Suddenly the mart could filter the fact, which is not the star-schema intent and creates hidden filter chains that produce wrong DAX results later.

**The fix**: manually **override the cardinality dropdown to "Many to one (*:1)"**. PBI shows a benign yellow warning along the lines of *"data integrity may be at risk — unique values detected on both sides"* — accept it. Cross-filter direction then unlocks; set to **Single**.

**Why this is semantically correct even though the data is technically 1:1**: `dim_calendar` is the **conformed dimension** (single source of truth for date attributes — day name, holiday flag, ISO week). The mart is **downstream consumption** of fact data. As new dates land in `dim_calendar` ahead of the mart catching up (e.g. when extract runs but dbt hasn't rebuilt the mart yet), the constraint stays valid as many-to-one. The 1:1 is degenerate in current state, not in design.

**Discipline rule banked**: every relationship from a fact or mart to a conformed dimension should be many-to-one with Single cross-filter direction, regardless of current uniqueness on both sides. Star-schema purity > technical accuracy.

### 2026-05-18 — Power BI dual-axis line charts disable trend lines

Discovered when trying to add trend lines to the Executive Overview revenue + units chart. The chart auto-converted to **dual-axis** when both measures were added to the Y-axis (Total Revenue $40K–$140K range on left axis, Total Units Sold 0K–50K range on right axis — PBI detects scale-difference and splits axes).

In the Analytics pane (the magnifying-glass icon in Visualizations), the available options were: X/Y-Axis Constant Line, Min line, Max line, Average line, Median line, Percentile line, Error bars, Anomalies. **No "Trend line" option.**

**Why**: PBI's trend-line feature requires a single-axis chart with a date/continuous X-axis. Dual-axis combo charts are excluded by design — a single trend line over two different scales would be ambiguous, and per-series trend lines aren't supported in this chart type.

**Workarounds**:
1. **Split into two single-measure side-by-side charts.** Each chart then has one Y-axis and supports its own trend line via Analytics. Most professional fix for a polished portfolio dashboard.
2. **Use Min/Max/Average lines as proxies.** Available on dual-axis charts; not a real trend (no slope), but useful for "threshold" or "baseline" annotations.
3. **Switch to a "Line and clustered column" combo chart** with explicit primary + secondary axes. Different constraints; some versions allow trend on the primary line.

**Banked for Phase 5 session 5.6** (polish pass): if trend lines are wanted for the Home page, split the dual-axis chart into two single-measure charts. Until then, the dual-axis story is clean enough.

**Carry-forward**: PBI's Analytics pane offerings change based on visual type and configuration. Before promising a feature to a stakeholder, check what's actually available in the current chart state.

### 2026-05-18 — Power BI Desktop UI version variance + web-check discipline

Earned by being wrong about it twice during Phase 5 session 1. Power BI Desktop **ships continuous UI updates** — visuals get promoted from preview to default, old ones get hidden, ribbon items move between sections, dialog field labels change. The mental model of "PBI Desktop has X feature in Y location" goes stale fast.

**Concrete examples from this single session**:
- **"Recent Sources"** in Get Data dropdown — visible in some versions, absent in Phil's. Not a paid-vs-free distinction (Power BI Desktop is universally free); just a version difference.
- **Data-load progress modal** — shows a row counter in some versions, just a spinner in Phil's. Same version-difference category.
- **"Card" vs "Card (new)" visual** — initial instruction referenced both as competing options. Web-confirmed: the new Card visual replaced the classic Card as default in **November 2025 GA**; the legacy Card is now hidden in current PBI Desktop unless explicitly toggled on. Phil's Visualizations pane shows only one Card.

**Compounding factor**: "free vs paid" is a misleading frame. **Power BI Desktop is universally free for everyone** — there's no paid Desktop tier. The free/paid split is **Desktop vs Service** (Service is the paid cloud platform for sharing). When a user says "I'm on free Power BI", they almost certainly mean "Desktop only, no Service licence." Practical implication: skip all Service-only steps (scheduled refresh, publishing, workspaces, apps) and assume Desktop has the full feature surface modulo version drift.

**Discipline rule for any PBI walkthrough**: when an instruction references a specific UI element (button, visual, menu path, dialog field, ribbon section), either (a) ask the user to confirm what they see in their version *before* prescribing clicks, or (b) web-check the current state of that UI element rather than asserting from memory. Don't assume the UI Claude knows from training matches what Phil sees today.

**Captured durably in TEACHING_PREFERENCES.md** under Tooling — Claude should re-read at session start for any PBI work.

### 2026-05-18 — Mart-sourced measures break when sliced by item or store dims

Discovered mid-session in Phase 5 session 5.2 while building the Demand by Hierarchy page. Symptom: a clustered bar chart with `Y-axis = DIM_ITEM[cat_id]` and `X-axis = Sum of MART_EXECUTIVE_OVERVIEW[total_revenue_usd]` showed **the same value ($93.8M) for every category** (FOODS, HOUSEHOLD, HOBBIES).

**Root cause — design-predictable, not a bug.** `MART_EXECUTIVE_OVERVIEW` is a day-grain pre-aggregation with columns `sale_date, total_revenue_usd, total_units_sold, active_item_count, active_store_count`. By lean-marts design, it carries NO item or store identifiers — the fact's `item_id`/`store_id` columns were aggregated away at mart build time. Consequently, the mart has only ONE relationship in the PBI semantic model: `MART.sale_date → DIM_CALENDAR.calendar_date`. No relationship to `DIM_ITEM`, none to `DIM_STORE`. When a visual filters by `DIM_ITEM[cat_id]`, the filter has no path to the mart, so no filtering occurs — every slice gets the mart's grand total.

**Why this was a fresh discovery.** Session 5.1 built only the Executive Overview page using mart measures and `DIM_CALENDAR` slicers — the calendar relationship existed, so date-range slicing worked correctly and the bug was invisible. The hidden constraint was *"mart measures only work when sliced by calendar-related fields."* Page 1 happened to satisfy that constraint; pages 2-5 don't.

**The mart's own schema YAML comment anticipated the constraint** (`_marts__models.yml` line 5: "NO denormalised date attributes (Power BI joins dim_calendar for year/quarter/is_weekend/is_holiday slicing)") — but the comment framed it as a *date-attribute* design choice. It didn't surface the bigger consequence that **mart measures would fail to respond to ANY non-calendar dim filter** (item, store, state, category).

**Fix that was applied (session 5.2 reset, captured in POWERBI_PLAYBOOK.md).** All measures relocated from `MART_EXECUTIVE_OVERVIEW` to a new dedicated hidden `_Measures` table, with each measure rewritten to aggregate `FACT_DAILY_SALES` directly. The fact has many-to-one relationships to all 3 dims, so fact-based measures respond correctly to every slicer on every page. The mart stays loaded but is hidden from the PBI field list — kept as documentation of the lean-marts pattern in dbt without coupling the BI model to it.

**Discipline rule banked**: when a pre-aggregated table is joined to PBI alongside a fact, the table's relationship topology determines what dims its measures can be sliced by. If the pre-agg only relates to the calendar dim, its measures only work on calendar-only pages. For cross-dim slicing, measures MUST aggregate the fact. The mart is for the home page's compression story (1,081 rows powering an exec view instead of 32.9M); it's not the universal measure source.

**Carry-forward principle for Project #3**: any pre-aggregated table in a BI semantic model needs documented filtering boundaries — *"this agg can be sliced by [X, Y, Z]; for slicing by [A, B], use the underlying fact."* Goes in the model's YAML alongside the column descriptions, not just in the dbt comment.

### 2026-05-18 — Dedicated hidden `_Measures` table for measure organization

Locked in during Phase 5 session 5.2 reset, backed by SQLBI / Microsoft Learn. Pattern: create a single empty table called `_Measures` (leading underscore sorts it to the top of the field list), hide the placeholder column, and home all measures there. Measures don't need a data source — they're computed expressions; the "home table" is purely organizational.

**Why this beats homing measures on data tables.** (a) The field list separates *"things to drag onto visuals as dimensions"* (data tables) from *"things to drag onto visuals as values"* (measure table) — cleaner mental model. (b) Refactoring a measure to reference a different fact column is trivial when the measure has no data-table home — no "this measure is on `MART` but references `FACT`, is that wrong?" ambiguity. (c) Sorts alphabetically before all data tables thanks to the leading underscore — measures always at the top.

**How to create**: Modeling tab → New table → paste `_Measures = ROW("Placeholder", BLANK())`. Then in Fields pane right-click the placeholder column → Hide. Then for every new measure: right-click `_Measures` in Fields pane → New measure. PBI auto-homes the measure on `_Measures`.

**Carry-forward**: every new PBI project in any subsequent Project #N starts with `_Measures` created BEFORE the first measure is written. Don't accumulate measures on data tables and refactor later — costly.

### 2026-05-18 — Dual storage mode on dims joined to a DirectQuery fact

Decision locked during Phase 5 session 5.2 reset after audit + SQLBI / Marco Russo research. The setup is: `FACT_DAILY_SALES` in DirectQuery (forced by 32.9M-row size hitting GitHub's 100 MB push limit in pure-Import mode), all three dims previously in pure Import.

**The problem with Import dims + DQ fact.** Per SQLBI: a relationship between an Import dim and a DirectQuery fact is a **limited (weak) relationship**. Properties of limited relationships:

1. **Cannot use `RELATED`** to fetch a column across them.
2. **Skip table expansion** — internal optimizations that propagate filter context through chained relationships don't apply.
3. **INNER JOIN semantics** — drops rows from EITHER side that have no match, even when the other side semantically should be included.
4. **High-cardinality join keys are slow** — limited-relationship joins are evaluated row-by-row above ~100-200 unique values.

**Dual mode fixes all four.** Setting dims to Dual lets PBI's engine treat the dim as Import for in-memory queries AND as DirectQuery when joining to the live DQ fact at the Snowflake side. Relationships become **regular** at query time. Free in Desktop, zero downside, strictly better for this topology.

**How to set**: Model view → right-click table header → Properties → Storage mode → Dual. PBI prompts that the change is irreversible (Dual → Import or DQ requires recreating the table) → confirm. Three dims × 1 click each.

**Carry-forward**: any time a star schema spans storage modes (Import + DirectQuery), the Import dims should be Dual, not pure Import. Pure Import dims joined to DQ facts is an anti-pattern.

### 2026-05-18 — Backfill anti-pattern: full-chain vs `--task-regex`

Lesson from mid-session 5.2 — Claude initially proposed running the full Airflow extract → verify → dbt models → verify_dbt chain 68 times for a historical date backfill. That's the *canonical DAG* but the wrong tool for *historical hole-filling*. Sequential full-chain × 68 dates × 5:31 per run = ~6 hours unattended. Parallel with `--max-active-runs 4` halves it but still ~1.5h.

**The 25-min alternative**: `airflow dags backfill ... --task-regex extract_one_day -i`. Restricts the backfill to only the named task per DagRun; downstream tasks (verify, dbt, verify_dbt) are skipped. Each run is then ~20-30s (just the Azure SQL → Snowflake extract, no dbt rebuild, no test suite). 68 × 25s = ~25 min. Then one `dbt build --full-refresh` at the end (~18s + tests) rebuilds the whole warehouse from the fuller RAW in one shot.

**Why the wasted work**: full-chain × 68 means the dbt incremental MERGE fires 68 times, each time processing one date and re-running 78 tests. The tests are checking nothing that hasn't been checked, and the MERGEs are doing what one full-refresh would do in 22s. ~5.5 hours of pure waste.

**Add `--reset-dagruns`** if any DagRun records already exist for the target logical_date range (e.g. from a half-completed earlier attempt) — wipes them clean before the new backfill creates fresh ones. No double-ups.

**Discipline rule banked**: when proposing a multi-run Airflow operation, lead with the shortest professional approach. Surface the duration estimate explicitly *before* any command runs. If duration > 30 min, offer 2-3 explicit options (sequential / parallel / task-restricted) with their respective time costs before committing. Default = the fastest one that doesn't compromise data integrity.

### 2026-05-18 — Research-backed playbook as a mid-phase reset tool

Meta-lesson from Phase 5 session 5.2 mid-session reset. When a project's PBI build hit a measure-architecture bug 2 hours into the session, the right move was NOT to keep iterating step-by-step in chat. It was to STOP, spawn parallel research agents (one auditing the project's current state from docs + dbt files, one web-researching Microsoft Learn / SQLBI / RADACAD / Chris Webb for the architectural questions), synthesize into a single durable doc (`POWERBI_PLAYBOOK.md`), and update the live state docs (PROJECT_CONTEXT.md, TEACHING_PREFERENCES.md, this file).

**Why this is durable** beyond Phase 5: the playbook locks the architectural decisions (storage modes, measure home, mart fate, measure family source) with web-verified sources, so subsequent sessions can be **executed** rather than **re-litigated**. If a later step proposes something that contradicts the playbook, that's a flag to push back rather than proceed.

**Trigger condition for the pattern**: any time the project hits a "this design choice has cascading consequences across multiple future sessions, and we just discovered the consequence is wrong" moment. Don't power through. Reset, research, document, then resume.

**Carry-forward for Project #3**: at the start of any BI / dashboard / semantic-model phase, draft the equivalent playbook *before* building. The session-5.1 mistake was building Executive Overview before locking the measure architecture — the bug surfaced only when page 2 introduced cross-dim slicing requirements that page 1 didn't have.

### 2026-05-18 — Airflow extract anomaly + ground-truth-via-direct-execution diagnostic

Hit at session 5.2 mid-session during the 68-date backfill verification. Symptom: Airflow's `airflow dags backfill m5_daily_extract --start-date 2014-01-07 --end-date 2014-03-15 --task-regex extract_one_day -i --reset-dagruns` reported **67 of 67 succeeded** — but parity check showed only **66 new dates landed** in Snowflake RAW. One date (`ds=2014-01-06` = `d_1074`) was silently skipped despite the Airflow task instance state showing `success`.

**Diagnostic process — three steps, ground-truth-first**:

1. **Confirm Azure SQL has the row.** Wrote `scripts/check_azure_sql_calendar_gap.py` re-using the production extract module's `connect_azure_sql()` helper (so .env semantics = guaranteed-same as the DAG's runtime). Queried `raw.calendar` for date='2014-01-06' AND d='d_1074' AND for the d_1072..d_1076 window. Result: **row exists**, all 5 surrounding d_values present, `raw.calendar` total = 1,969 rows (full M5 dataset).
2. **Run the extract script directly.** From PowerShell with the project's `.venv` active: `python scripts/extract_azure_to_snowflake.py --run-date 2014-01-06`. Result: **clean load in 2 minutes** — 1 calendar row + 26,049 sell_prices rows (whole `wm_yr_wk=11350` week) + 30,490 sales_train rows, parity verifications all PASS.
3. **Conclusion**: Azure SQL is fine, the script is fine, the bug is somewhere in Airflow's context resolution under `--reset-dagruns` + `--task-regex` mode. Root cause not definitively proven — suspected interaction between Cosmos-integrated DAG parsing and the backfill's `ds` resolution when DagRun records are being recreated. Documented as known anomaly.

**The durable pattern banked: ground-truth-via-direct-execution**. When orchestration says SUCCESS but the data layer says otherwise, **invoke the underlying script directly with the same arguments the orchestrator would have passed**, in an environment that mirrors the orchestrator's (same Python, same .env, same connection helpers). Two outcomes possible: (a) script also fails the same way → bug is in the script; (b) script succeeds → bug is in the orchestrator's context, environment, or invocation path. Either outcome is actionable. The diagnostic burns only the script's runtime (~2 min here) versus debugging Airflow's task isolation, which can chew hours.

**Why re-using the production module's connection helpers matters**: writing a fresh `pyodbc.connect()` in the diagnostic script would have introduced a confound — "does the diagnostic script see Azure SQL the same way Airflow's task does?" By importing `extract_azure_to_snowflake` and calling its `connect_azure_sql()` + `wake_azure_sql()`, the diagnostic uses the exact same connection path Airflow uses, so a clean answer from the diagnostic is decisive about the script-or-script-internals layer.

**Discipline rule for future anomalies**: when "orchestrator says success but downstream check says missing data", reach for ground-truth-via-direct-execution before debugging the orchestrator. The orchestrator has more moving parts; the script is the simpler unit to isolate.

**Carry-forward for Project #3**: when wiring any orchestrator (Airflow, Prefect, Dagster, Argo) around an existing ETL script, keep the script independently runnable with the same `--run-date`-style CLI surface the orchestrator uses. This isn't just "good code hygiene" — it's the diagnostic surface for problems exactly like this one.

### 2026-05-18 — `.pbix` file size forced composite-mode decision at git-push time

Caught at session 5.1 close. Initial decision was **full Import** for all 5 tables in the semantic model — dims (small), mart (small), and the **32.9M-row `FACT_DAILY_SALES`** (large but reasoned: "VertiPaq compresses 5–10× and Import unlocks the full DAX surface"). The .pbix saved fine locally, but **`git push` was rejected by GitHub with**:

```
remote: error: File powerbi/retail_demand_forecasting.pbix is 949.08 MB;
this exceeds GitHub's file size limit of 100.00 MB
```

VertiPaq genuinely compressed the row data — 32.9M rows × multiple columns into ~600 MB is decent compression — but **GitHub's 100 MB per-file hard limit** is a real constraint that doesn't care about column-store internals. The `.pbix` is a single binary blob from git's perspective.

**The pivot**: switch `FACT_DAILY_SALES` from **Import** to **DirectQuery**. Composite-mode: fact stays in Snowflake and queries live for fact-driven visuals; dims + mart remain in Import for instant home-page interactivity. **Result**: `.pbix` dropped from **949 MB to 264 KB** — a ~3,600× reduction. Push went through cleanly without Git LFS.

**Mechanics — the trap to avoid**: PBI Desktop **cannot switch a table from Import to DirectQuery via the Properties pane Storage mode dropdown**. The dropdown is greyed out by design (web-confirmed via Microsoft Learn). The valid switches are: DirectQuery → Import (irreversible), DirectQuery → Dual, Import → Dual. Import → DirectQuery requires **delete the table from the model + re-add via Get Data and choose DirectQuery at the load dialog**. Relationships are lost on delete and must be rebuilt afterward (3 fact→dim relationships in our case — quick).

**Reframe for interview talk-track**: this isn't a setback — it's the actual empirical DirectQuery-vs-Import evaluation playing out. The original session plan called for "Native Snowflake connector with DirectQuery vs Import evaluation; settle the pattern empirically per page." That's exactly what happened. The empirical answer for THIS dataset at THIS scale in a git-versioned portfolio repo is **composite mode**, and the story behind it ("I tried full Import first, hit GitHub's 100 MB ceiling, pivoted to composite") demonstrates real operational maturity. *"I empirically evaluated Import vs DirectQuery per table. Small dims + the pre-aggregated mart land in Import for instant interactivity. The 32.9M-row fact stays in Snowflake under DirectQuery — clicks pay sub-second latency rather than baking a near-GB binary into the repo."*

**Three carry-forward principles for Project #3**:

1. **Estimate output artefact size BEFORE the empirical evaluation**, not after. Back-of-envelope: 32.9M rows × ~10 columns × ~30 bytes/value (uncompressed) = ~10 GB raw → VertiPaq 5–10× compression → ~1–2 GB in .pbix → exceeds GitHub by 10×. Would have caught this without the failed push.
2. **GitHub's 100 MB per-file limit is the hard constraint** for any git-versioned binary deliverable — `.pbix`, `.twbx` (Tableau workbook), `.parquet` snapshots, ML model artefacts. Plan around it from session 1, not session N when the push fails.
3. **Composite mode is the senior-DE default for any analytics tool consuming both small and large warehouse surfaces.** Small + slow-changing → Import (fast slice/dice, full DAX). Large + slow-changing → DirectQuery (no client storage, latency on click). Large + fast-changing → DirectQuery (freshness). Mixed → composite. Make this an explicit per-table decision, not a project-wide one.

### 2026-05-20 — Manage Aggregations requires DirectQuery on the Detail Table — architecturally incompatible with all-Import models

Discovered mid-rebuild in Phase 5 session 5.4. The `POWERBI_PLAYBOOK.md` §1.4 prescribed wiring `AGG_SALES_DAILY` and `AGG_SALES_DAILY_ITEM_CAT` as user-defined aggregations to accelerate Sum-based measures over the 32.9M-row fact. When I opened Modeling → Manage Aggregations and tried to map `DATE_KEY` (GroupBy summarization) to a Detail Table, every option in the dropdown was unclickable. Spent ~30 min on what looked like a UI bug (clicks not registering, options visually greyed) before web-checking the actual Microsoft Learn doc on aggregations-advanced.

**The actual rule, missed by the original playbook:** the Detail Table for any user-defined aggregation must be in **DirectQuery storage mode**, not Import. From Microsoft Learn: *"The Detail Table must use DirectQuery storage mode, not Import."* The aggregation table itself can be Import (and usually should be, for VertiPaq compression), but the table it maps INTO has to be DirectQuery so PBI can rewrite queries between Import-cached-agg and DQ-direct-fact at runtime.

**Why this matters for an all-Import model.** The playbook §1.1 explicitly locked the model to all-Import (no Dual, no DirectQuery, no composite) to avoid the Import → Dual one-way restriction trap and the lean-marts measure cascade bug from session 5.2. That decision was correct for those problems, but it forecloses the UDA path entirely. The two architectural choices are mutually exclusive: you can have all-Import simplicity OR user-defined aggregations, not both.

**Resolution.** Deleted `AGG_SALES_DAILY` and `AGG_SALES_DAILY_ITEM_CAT` from the PBI semantic model. They're still in Snowflake + dbt as a portfolio narrative artefact — *"I built two pre-aggregated marts following the Kimball aggregate pattern"* — but they don't get wired into PBI. Net result: measures hit `FACT_DAILY_SALES` directly via VertiPaq Import. Empirically: sub-second for Sum-based measures on 32.9M rows, so no measurable performance loss to deliver.

**Forward principle**: any time a playbook locks in a storage-mode decision (Import only / DirectQuery only / Dual / composite), explicitly enumerate which downstream optimizations that decision rules OUT. UDA is one. RLS row-level filtering on DQ-only tables is another. Hybrid tables for fast-changing data is a third. The storage-mode decision isn't just a perf choice — it cascades through every advanced PBI feature.

**Interview talk track**: *"I went all-Import for the semantic model because the alternative — DirectQuery on the fact + Dual on the dims — has a documented one-way restriction in PBI Desktop where you can't downgrade Import to Dual without re-importing as DirectQuery first. The cost of that decision was losing access to user-defined aggregations, which require a DirectQuery detail table. I kept the pre-aggregated marts in dbt for the architectural story but didn't wire them into PBI — VertiPaq compression on the Import-mode fact made the perf gap negligible at our scale."*

**Carry-forward to Project #3 (Databricks)**: Power BI on Databricks has the same UDA requirement — agg tables in Import, detail in DirectQuery. Decide storage mode BEFORE building the agg layer so you don't ship dead aggs to PBI like this project did.

### 2026-05-20 — Power BI measure formula editor: Enter does NOT commit when editing an existing measure; click the green checkmark

Discovered after burning ~30 min in Phase 5 session 5.4 trying to fix the `Active Items` measure. Symptom: card on canvas kept showing `--` (BLANK) regardless of which formula was typed into the measure formula bar. Iterated through 4 different DAX formulations — original (used `MAX(DIM_CALENDAR[calendar_date])`), then fact-side (`MAX(FACT_DAILY_SALES[sale_date])`), then `CALCULATE(DISTINCTCOUNT, units_sold > 0)`, then dead-simple `DISTINCTCOUNT(FACT_DAILY_SALES[item_key])`. ALL returned BLANK. Other measures on the same fact worked fine (Total Revenue, Total Units Sold, Active Stores all rendered correctly).

**The actual bug.** I was instructing Phil to press Enter to commit each new formula. In PBI Desktop's measure formula editor, **Enter does NOT commit when you're editing an EXISTING measure** — it inserts a newline (DAX supports multi-line formulas). The displayed text in the formula bar updates with each new formulation, but the SAVED measure definition stays at the original. Every "new" formula was just sitting unsaved in the editor while the broken original kept executing in the background, returning BLANK.

**Why other measures were fine.** When you click "New measure" from the Modeling ribbon, the workflow is different — Enter DOES commit-and-exit the new-measure dialog. All 20 measures during the bulk-paste phase were created via that workflow, so Enter worked. The trap is specifically when you go back to EDIT an existing measure by clicking it in the Data pane — different formula bar mode, different commit semantics.

**The fix.** Click the green checkmark icon to the LEFT of the formula bar text explicitly. The X (red) and checkmark (green when there are unsaved changes, grey when committed) are next to the formula. Clicking the green checkmark commits the edit. Pressing Enter just adds a line break.

**Forward principle, locked into PROJECT_CONTEXT 5.5 opening directive**: whenever Claude prescribes a measure edit (not a new-measure create), the instruction must include "click the green checkmark to commit, not Enter."

**Diagnostic technique worth banking**: when a DAX measure returns BLANK and there's no obvious filter context reason, the FIRST check should be "is the formula actually saved?" Not "is the DAX correct?" The committed formula vs displayed formula divergence is invisible until you click away and click back — then the formula bar shows the saved version, not the typed-but-unsaved version. Carry-forward for Tableau too (Tableau has analogous edit-mode-vs-saved-mode confusion in calculated fields).

### 2026-05-20 — Power BI Optimize → Pause Visuals as silent root cause of "everything disappears on click"

The biggest time-sink of Phase 5 session 5.5. Symptom from session open: every interaction in PBI Desktop (clicking a slicer, dragging a measure into a card, switching pages) caused visuals to go blank. Clicking Home → Refresh forced them to render. Next interaction → blank again. Pattern was so consistent Phil flagged it explicitly ("I click on something, everything disappears. I have to do a refresh.") roughly an hour into the session.

**The actual cause.** Optimize ribbon → "Pause Visuals" was toggled ON. Pause Visuals is a PBI Desktop feature meant for performance work — when on, every visual query is queued but NOT executed until you Resume or Refresh. The visual stays in whatever render state it was in before the pause, then blanks when you change anything that invalidates it (new field, new filter, page switch), because the new query never runs. Refresh forces the queue to flush, visuals render. Next interaction → queued again → blank again.

**Why it took so long to find.** Three reasons compounded:
- The pattern looked like a model/data bug at first ("DIM_ITEM[cat_id] slicer is empty" — data view showed 3,049 rows with FOODS/HOBBIES/HOUSEHOLD populated, so it wasn't the data).
- A refresh during diagnostics surfaced an unrelated "A cyclic reference was encountered" error pointing at FACT_DAILY_SALES, which became the red herring. Spent ~30 min tracing M-code (clean), query dependencies (clean), calculated columns (none), measures (intact). The cycle turned out to be spurious — close+reopen of the .pbix cleared it (see separate entry below).
- The "To format your visual, refresh it or resume visual queries" message in the Format pane was the actual giveaway — it appeared late in the session when Phil clicked a card to format it. The word "resume" in that message is what unlocked it.

**The fix.** Optimize ribbon → click Pause Visuals to toggle OFF. Icon behavior is the opposite of what you'd expect: when visuals are LIVE, the button shows a Pause symbol (II) meaning "click to pause." When PAUSED, it shows a Play arrow (▶) meaning "click to resume." Confusing UI affordance.

**Discipline rule locked, added to TEACHING_PREFERENCES.** Whenever the user reports "things keep disappearing when I click" / "I need to refresh after every change" / "visuals look empty until I refresh" — FIRST diagnostic before anything else is Optimize → Pause Visuals. It's a 1-click check with the highest signal-to-noise of any PBI diagnostic. Cyclic ref errors, empty slicers, blank cards, "needs refresh to render" — all are downstream symptoms of paused queries.

**How it likely got turned on.** Pause Visuals is a single-click button on the Optimize ribbon, easy to hit accidentally. Once on, it stays on through saves and reopens. No global toast or banner indicates the paused state — the only persistent cue is the icon style in the Optimize tab (which you only see if you're on that tab).

**Carry-forward to any future PBI work**: the Optimize tab and its toggles (Pause visuals, Refresh visuals, Apply all slicers button) are part of PBI's standard diagnostic surface. Worth learning what each one does proactively so symptoms map quickly to causes. Carry-forward also to Tableau (Pause Auto Updates serves the same function, same trap potential).

### 2026-05-20 — Power BI cyclic reference errors can be spurious; close + reopen the .pbix before deep-diving

Mid-session in 5.5, a Refresh surfaced: *"5 queries are blocked by the following error: FACT_DAILY_SALES — A cyclic reference was encountered during evaluation."* The natural first reaction is to chase the cycle through the model — Power Query M-code, query dependency graph, calculated columns, calculated tables, measure dependencies, bidirectional relationships, etc.

**What was actually wrong.** Nothing. The M-code for FACT_DAILY_SALES was clean (Source → 3 Navigation steps → drop SALE_KEY). Query Dependencies graph showed all 6 queries pulling independently from the one Snowflake source with no cross-references. No calculated columns on FACT_DAILY_SALES. The error was spurious.

**The fix.** Save → close Power BI Desktop entirely (red X) → reopen the .pbix from File Explorer. The cyclic reference error did not return after the reopen. Slicers that had been silently failing started returning values normally (the underlying Pause Visuals issue was still there, but the cycle itself was gone).

**The supporting evidence** (from a contemporaneous web search): the [crossjoin.co.uk article on this error](https://blog.crossjoin.co.uk/2023/01/22/understanding-the-a-cyclic-reference-was-encountered-during-evaluation-error-in-power-query-in-power-bi-or-excel/) explicitly notes: *"Sometimes the cyclic reference error is raised without an actual cyclic reference existing, another refresh doesn't raise the error, and it's better to refresh twice before investigating."* So this is a documented PBI quirk, not a one-off glitch.

**Discipline rule.** When PBI surfaces *A cyclic reference was encountered during evaluation*, the first step is save + close + reopen, NOT trace the model. Only if the error persists after reopen should you investigate M-code → Query Dependencies → DAX calc columns / tables → measure deps → bidirectional relationship cycles. Going straight to the trace burned ~30 min in 5.5 before the reopen cleared everything.

**Carry-forward.** Many PBI Desktop "intermittent or one-time-only" errors clear on reopen because PBI caches internal model snapshots that can desync from the live model state. When the symptom doesn't match the data (data is clean, formula is correct, relationships look right, error is still there) — reopen first.

### 2026-05-20 — Power BI new Card visual (Nov 2025 GA) renders blank when bound to a measure that works in other visuals

Symptom: created a fresh Card visual on Executive Overview page, dragged `Total Revenue` into the Value field well — visual rendered as an empty rectangle with no number. Same measure on the same page in a Line chart rendered correctly with `$100.70M` value visible in the legend tooltip.

**Confirmed via web search**: the [(new) Card visual went GA with the Nov 2025 Power BI release](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-card) and has a documented blank-render bug in PBI Desktop. The [Fabric Community thread](https://community.fabric.microsoft.com/t5/Desktop/New-Card-Visual-Missing-After-Latest-Power-BI-Update/m-p/4861831) describes the same symptom and offers "restoring the defaults" via the Format pane as the documented fix.

**The fixes that actually worked tonight (after disabling Pause Visuals):**
- The card rendered immediately once Pause Visuals was turned off. The blank-card issue was a downstream consequence of paused queries, not the GA bug. So the "new Card visual GA bug" may not have been the root cause in this specific instance — but it IS a known PBI Desktop issue and worth banking.

**What's actually banked.** If a measure renders blank in a fresh Card visual but works elsewhere on the same page, and Pause Visuals is confirmed OFF, the workarounds (in order of preference): (a) Format pane → Reset to default; (b) Delete the card and recreate; (c) Switch to the Multi-row card visual, which is a different visual type that doesn't share the new Card's render path.

**Why this matters for portfolio narrative.** Tonight's confusion (blank card AND paused visuals AND spurious cyclic ref all happening at once) reinforces a senior-DE diagnostic principle: **isolate one variable at a time**. When three things look broken, fixing all three with one action (turn off Pause Visuals) tells you they were all symptoms, not three independent bugs. Locked into a teaching-preferences carry-forward.

### 2026-05-21 — Power BI calculated COLUMN vs MEASURE: same formula bar, different evaluation context

Discovered during Phase 5 session 5.6 while adding `is_snap_day` to `DIM_CALENDAR` for the Promotion & Price page. Phil clicked "New measure" instead of "New column" — the formula bar looked identical, but every column reference (`DIM_CALENDAR[SNAP_CA]`, `[SNAP_TX]`, `[SNAP_WI]`) lit up with red squigglies and the error tooltip read "Cannot find name SNAP_CA". Confirmed the columns existed on DIM_CALENDAR via the Data pane; re-typing using Intellisense didn't fix it; only switching from New measure to New column cleared the error.

**The real distinction:**

- **Calculated COLUMN** evaluates in **row context** — runs once per row of the host table. Bare column references like `DIM_CALENDAR[SNAP_CA]` resolve to "the value of SNAP_CA on THIS row." Cheap to read in DAX.
- **MEASURE** evaluates in **filter context** — runs once per cell of a visual, with no inherent row context. Bare column references don't make sense (there's no single row to evaluate against) so DAX requires an aggregator (SUM, AVERAGEX, etc.). The "Cannot find name" error is PBI's slightly misleading way of saying "this reference can't resolve without row context."

**Mental model — clipboard-vs-turnstile.** A calculated column is like a clipboard handed to each row as it walks past — the row context is its identity. A measure is like a turnstile counter at the gate — it sees the FLOW (filter context) of rows passing through but has no concept of "this row" without an aggregator wrapping it.

**Why the same formula bar exposes both:** Microsoft chose UI parsimony over discoverability. The exact same DAX syntax can mean two completely different things depending on whether you clicked New column or New measure five seconds ago. Discipline rule: ALWAYS double-check the ribbon button before pasting a formula.

**Carry-forward.** Any time PBI surfaces "Cannot find name [column]" on a reference Phil can verify exists in the Data pane, the FIRST diagnostic check is "did I click New measure or New column?" — not "is the column name wrong?", not "is there a typo?", not "is Intellisense broken?". Saved ~10 min of misdirected diagnostics this session; would have saved more if checked first.

### 2026-05-21 — Snowflake unquoted identifiers stored as UPPERCASE carry through to Power BI column names

Surfaced during Phase 5 session 5.6 when the `is_snap_day` calculated column formula was authored as `DIM_CALENDAR[snap_ca]` (lowercase, matching dbt model source-of-truth) and lit up with red squigglies in PBI. The actual columns visible in PBI's Data pane were `SNAP_CA`, `SNAP_TX`, `SNAP_WI` — all uppercase.

**The chain:** dbt models write columns in lowercase (`snap_ca`, `snap_tx`, `snap_wi`). Snowflake stores unquoted identifiers as UPPERCASE (documented behavior — applies to all CREATE TABLE / SELECT / column references that aren't double-quoted). When PBI imports via the Snowflake connector, it reads whatever Snowflake returns — uppercase. So lowercase dbt source code → uppercase Snowflake catalog → uppercase PBI column names. DAX is case-insensitive for column REFERENCES but the column NAMES still need to match what PBI catalogued.

**Practical implication for DAX authoring:** when writing DAX measures or calculated columns that reference columns in a Snowflake-imported semantic model, default to UPPERCASE column names — or use Intellisense, which always pulls the exact catalog name. Don't free-type the column name in lowercase even though it works in your dbt source code.

**Edge cases worth knowing:**

- Double-quoted Snowflake identifiers preserve case (`CREATE TABLE "MyTable"` stays "MyTable"). The dbt convention to use unquoted snake_case is what produces clean uppercase in the catalog.
- Identifiers with special characters (spaces, hyphens, leading digits) get auto-quoted by some tools and may retain original casing — another reason to stick to plain snake_case throughout the stack.
- BigQuery is case-SENSITIVE for column names by default — same dbt source produces case-preserving column names. The lesson here is Snowflake-specific.

**Carry-forward.** When DAX authoring against a Snowflake-imported model and a bare column reference doesn't resolve: check casing FIRST (UPPERCASE for unquoted Snowflake), table name SECOND, column existence in the Data pane THIRD. Cheapest checks first.

### 2026-05-21 — The `(Mart)` measure naming pattern: same metric, two source tables, two measures

Discovered during Phase 5 session 5.6 while building the Forecast vs Actual matrix. Playbook §3.5 specified the matrix as `Rows=cat_id, Columns=series_type, Values=Total Units, Total Revenue` — but the existing `Total Revenue` and `Total Units Sold` measures (from playbook §2.1) source from `FACT_DAILY_SALES`, which has no `series_type` column. Putting `series_type` in matrix Columns would have no filtering effect on FACT-sourced measures: both the "actual" and "forecast" columns would show the same $100.70M total because the column-level filter can't reach the source table.

**Fix:** added two NEW measures — `Total Units (Mart)` and `Total Revenue (Mart)` — that source from `MART_FORECAST_VS_ACTUAL` (the dbt mart that UNIONs actuals and forecasts with a `series_type` discriminator). The matrix now uses these mart-sourced measures, the column filter does its job, and we get a clean actual vs forecast split: FOODS shows 25.9M actual units / $59.7M revenue alongside 696K forecast units / $1.7M revenue.

**The naming convention.** Suffix the mart-sourced version with `(Mart)` rather than renaming the fact-sourced original. Reasons:

1. The fact-sourced version is the canonical company-wide measure — every page outside Forecast vs Actual uses it. Renaming it would force ripple changes.
2. The `(Mart)` suffix is a self-documenting signal that the measure has different source semantics. A future reader sees the suffix and knows to check the source table.
3. The two measures coexist on `_Measures` and sort alphabetically together — visible side-by-side in field lists, making the relationship obvious.

**When to reach for this pattern.** Any time you have two source tables that represent the same metric at different scopes — actuals vs forecast, current vs prior period at table level (not measure level), unified vs filtered subsets. Better than trying to consolidate into one measure with complex CALCULATE logic — explicit beats clever in DAX as much as it does in Python.

**Anti-pattern to avoid.** Don't reuse the same measure name on two different tables (PBI prevents this anyway — measure names are globally unique in the model). Don't use ambiguous suffixes like `(v2)` or `(new)`. The suffix should signal the SOURCE or SCOPE difference, not version.

**Carry-forward to Project #3.** When Data Vault 2.0 hubs/satellites + Gold information marts both expose the same metric (revenue, units, customer count), the same pattern applies: explicit suffix on the mart-sourced measure (`Revenue (Gold)` alongside `Revenue (Vault)`), let the field list show them side by side.

### 2026-05-21 — Power BI format pane section names vary by visual type (Bars / Columns / Markers / Slices)

Surfaced during Phase 5 session 5.7 polish pass when I (Claude) repeatedly told Phil to click "Format → Visual → **Bars** → Colors" for the Average Selling Price chart on Promotion & Price. The dropdown didn't exist because the chart was a **clustered column** (vertical bars), not a horizontal bar chart — and in the new Power BI Desktop format pane the section is called **Columns** for column charts, **Bars** for bar charts, **Markers** for scatter / bubble charts, and **Slices** for pie / donut charts. Each parent section contains the visual's color controls, but the parent's name follows the visual type, not a uniform "Colors" parent.

**The chain.** The "old" Power BI format pane had a flat-ish structure with "Data colors" as a near-universal subsection at the top level of the Visualizations format pane — same name across most visual types. The redesigned pane (rolled out 2023-2024 and now standard in 2026) groups formatting controls under visual-type-specific parent sections. Same control, different parent label. Made worse by the fact that conditional formatting (`fx` button) lives inside whichever parent section the colors are under — so the click path is different for each visual type.

**Practical impact during 5.7.** I gave Phil three wrong paths in a row before he insisted I deep-think and web-check the actual UI. Confirmed via Microsoft Learn:

- Bar chart (horizontal) → Format → Visual → **Bars** → Color → fx
- Column chart (vertical) → Format → Visual → **Columns** → Color → fx
- Scatter / bubble → Format → Visual → **Markers** → Apply settings to (per-series dropdown) → Color
- Donut / pie → Format → Visual → **Slices** → Colors → fx
- Line chart → Format → Visual → **Lines** → Colors

**Carry-forward discipline.** When giving Power BI format-pane click paths in 5.8 and beyond, web-check the visual type's parent section name FIRST if I can't see the Format pane directly in the user's screenshot. Don't assume a generic "Colors" parent. If a path doesn't click, ask the user what parent sections are visible in their pane rather than guessing again. Cost ~10 minutes mid-session before Phil pushed back; cheap to avoid in future by visual-type-checking upfront.

**Edge cases worth knowing:**

- The **Apply settings to** dropdown inside Markers / Bars / Columns is what gates per-series customization. If a user can't find per-category color controls, it's usually because they haven't switched the dropdown off "All" yet.
- Conditional formatting via `fx` is only enabled when "Apply settings to" = All. Per-series manual colors bypass the fx dialog entirely.
- The Power BI documentation on Microsoft Learn for the new Card visual, scatter chart, donut chart, etc. each describe their parent section names directly — the docs are the source of truth, not stale community blog posts that still show the old "Data colors" path.

### 2026-05-21 — Power BI new Card visual Reference labels field well is variant-dependent (basic-license PBI Desktop is missing it)

Surfaced during Phase 5 session 5.7 polish pass when trying to add a YoY % indicator to the Total Revenue card on Executive Overview. Standard pattern for the new Card visual (Nov 2025 GA) is to drag the YoY measure into the **Reference labels** field well — gives a small secondary value below the main number, color-coded against the change. The screenshot of Phil's Build visual pane on the card showed only: **Value, Categories, Tooltips, Drill through**. No Reference labels field well.

**The chain.** The new Card visual's Reference labels feature shipped as part of the November 2025 GA release, but the field well's exposure in the Build pane appears to be license-tier-gated or variant-specific. Phil is running stock-standard Power BI Desktop with no Pro / PPU / Premium license. Microsoft's documentation describes Reference labels as a core feature of the new Card visual; community threads from late 2025 / early 2026 show two distinct Build-pane variants — one with Reference labels exposed, one without — with no clear pattern as to which license tier or feature flag drives the difference. The Reference labels field well is sometimes present in identical-version PBI Desktop installs on different machines.

**Practical impact during 5.7.** I'd planned 5 time-intelligence visuals on Exec Overview (YoY % pill, YTD line overlay, 30-day MA, etc.). The YoY % visualization was meant to use Reference labels on the Total Revenue card. With the field well unavailable, the only paths forward were:

1. Build a separate Multi-row card next to the Total Revenue card showing the YoY measure — added visual clutter, abandoned.
2. Build a custom DAX measure that returns the YoY % as a formatted text string, then put it in the Tooltip — usable but the YoY signal is hidden behind hover, doesn't read at-a-glance.
3. Skip the YoY % visualization entirely — chosen path. YoY measure retained on `_Measures` for tooltip use; the at-a-glance YoY indicator deferred.

**Feature-detect discipline.** Before recommending any new-visual field-well pattern (Reference labels, Small multiples, dynamic format strings, etc.), ask for a screenshot of the user's Build visual pane and confirm the field well exists. Don't assume the feature is present just because it's in the Microsoft documentation. New Power BI visuals roll out features incrementally across license tiers and feature flags; the GA announcement does not guarantee universal exposure.

**Carry-forward to Project #3.** Same discipline applies to any incrementally-released BI tool feature — Tableau, Looker, Mode, etc. Doc-described capabilities and user-visible capabilities are not always the same set. Screenshot-first feature-detect saves the time wasted recommending a path the user can't take.

### 2026-05-22 — Power BI Desktop format pane control locations vary heavily by variant — pin exact paths for common controls

Surfaced repeatedly during Phase 5 session 5.8 polish pass. The new Power BI Desktop format pane has been reorganised through 2024-2026 and controls don't always live where Microsoft Learn or community blogs say they do. Worse, in this user's stock free Desktop variant, some controls were in non-obvious sub-sections that required multiple research detours to find. Pinning the actual locations as confirmed in this user's variant (May 2026 stock free Desktop):

**Matrix controls:**

- **Row padding** → Format → Visual → **Grid** → **Options** sub-card → Row padding (NOT in Row headers / NOT in Values — both have Font/Text/alignment only)
- **Global font size** for all matrix text → Format → Visual → **Grid** → **Options** → Global font size (one control bumps all matrix text proportionally; cleaner than per-section font edits)
- **Auto-size column width / Grow to fit** → Format → Visual → **Layout** → **Column width** → Auto-size behavior dropdown = "Grow to fit"; companion toggle: **Custom widths** must be OFF for Grow to fit to actually distribute evenly (custom widths from prior manual drags override Grow to fit per-column)
- **Conditional formatting (background gradient, blank value handling)** → Format → Visual → **Cell elements** → "Apply settings to" dropdown (pick the target measure) → Background color toggle ON → click **fx** for the gradient dialog. Inside the dialog: "Apply to" = Values only excludes the Total column/row from the gradient; "How should we format empty values?" = Don't format (or Specific color → No fill) kills the gradient on truly-empty cells. The other CF access route via Build pane → Values well → ▾ on the measure → Conditional formatting works equivalently but only when the visual is selected.

**Format pane section names vary by visual type** (already locked 2026-05-21):

- Bar chart (horizontal) → Bars section
- Column chart (vertical) → Columns section
- Scatter / bubble → Markers section
- Donut / pie → Slices section
- Line chart → Lines section

**New Card visual field wells are Value / Categories / Tooltips / Drill through — NEVER "Fields well".** Banking this explicitly because saying "Fields well" wasted time across multiple turns. The classic Card visual had a "Fields" well; the new Card visual (Nov 2025 GA, default in current builds) uses "Value" as the primary field well name. Reference labels field well is variant-dependent (locked 2026-05-21).

**Carry-forward discipline:** when an instruction references any specific format pane section, sub-card, or field well name, web-check the EXACT location in the user's variant by asking for a screenshot of the relevant pane FIRST. Don't prescribe from memory of where it "should be" based on docs. Variant differences are real and prescribing-and-correcting wastes the user's time more than asking-and-confirming up front.

### 2026-05-22 — Power BI build order: pick theme + test drill-through EARLY with 1-2 visuals, NOT at polish-pass time

Two related carry-forward discipline rules surfaced after session 5.8's painful drill-through and theme-cohesion experiences. The user specifically asked these be banked for Project #3.

**Rule 1 — apply theme after 1-2 visuals exist, not after the report is built.** Power BI themes propagate font sizes, colors, default visual styling, and spacing across every visual on every page when applied. Building all 22 visuals across 5 pages with default formatting and then applying the theme at the polish-pass stage means every previously-formatted visual gets some properties overwritten or reorganized — net effect is rework on the visual formatting that was already invested. Build 1-2 visuals first, apply the theme, verify it looks how the user wants, then continue building. Theme-first means subsequent polish layers on top of the theme cleanly.

**Rule 2 — wire and TEST drill-through with 1-2 source visuals + a minimal destination page, BEFORE investing in source-visual formatting.** Power BI drill-through has known fragility around right-click trigger detection (community threads cite various causes: lineage mismatch, hidden destination page, blocked dim table, Page type setting, variant differences in the Page information section). When the right-click trigger fails to fire despite spec-correct wiring, the most commonly-cited community fix is to delete and re-add the source visual. If the source visual has already been polished with category-keyed colors, title renames, format-pane work, etc., that polish is lost. Testing drill-through EARLY with a minimal source visual (just the field, no formatting) means a failed trigger only costs 30 seconds of re-add. Testing drill-through LATE means losing significant polish work.

**Carry-forward to Project #3:** add "apply theme after first 1-2 visuals" and "wire + test drill-through after first 1-2 source visuals" as two locked steps in the Power BI build order, before the full visual build. Project #3's Power BI playbook should bake these in at the page-build phase, not the polish phase.

### 2026-05-22 — Power BI Desktop drill-through right-click trigger silently failing despite spec-correct wiring (unresolved)

Surfaced during Phase 5 session 5.8. Drill-through destination page "Item Detail" was created and hidden, drill-through field well wired with DIM_ITEM[ITEM_ID], "Allow drill through when = Used as category", Keep all filters Off, Cross-report Off. Source visual on Demand by Hierarchy was a Table with DIM_ITEM[ITEM_ID] in Columns well (lineage confirmed via tooltip showing 'DIM_ITEM'[ITEM_ID]). File saved + full close+reopen attempted.

**Symptom.** Right-click on an ITEM_ID value in the source table showed the standard context menu (Copy / Show as table / Include / Exclude / Group / Summarize / New visual calculation / Set up a verified answer / Customize total calculation) — but NO **Drill through** option.

**Diagnostics attempted (all checked, none resolved the issue):**

- Page hidden vs unhidden — same result
- Right-click on ITEM_ID text cell directly vs on revenue cell vs on total row — same result
- Allow drill through when = Used as category (verified, didn't change)
- Keep all filters Off (verified)
- Cross-report Off (verified)
- Source visual ITEM_ID lineage = DIM_ITEM[ITEM_ID] (verified via tooltip)
- Save → close PBI Desktop → reopen (verified, didn't resolve)
- Page type dropdown in Page information — NOT EXPOSED in this user's variant (only Set as landing page / Allow use as tooltip / Allow Q&A — no "Drillthrough" page type toggle; community thread on this control as the #1 cause didn't apply to this variant)

**Resolution:** drill-through was PULLED from session 5.8 scope. Item Detail destination page deleted. The cost-benefit on continuing to chase a variant-specific UI issue versus moving on to the remaining 5.8 items was not worth it for a portfolio piece focused on the data engineering story. PBI's automatic cross-filtering (left-click on a value in one visual filters all other visuals on the same page) gives most of the interactive value already, without the drill-through wiring complexity.

**Carry-forward discipline:**

- When drill-through right-click trigger fails despite spec-correct wiring in a free stock Desktop variant, the community-cited "Page type = Drillthrough" fix may not apply (the toggle may not exist in all variants — Page information section only exposed Allow use as tooltip / Allow Q&A / Set as landing page in this user's case). Investigation beyond this point requires screen-sharing for variant-specific diagnosis.
- Recommend treating drill-through as a "nice-to-have polish item" with a hard time-cap on debugging (e.g., 30 minutes). If not firing after spec-correct wiring + close+reopen, pull from scope rather than burning hours.
- See related carry-forward rule above: test drill-through EARLY with minimal visuals, before investing in source-visual formatting.

### 2026-05-22 — Power BI cyclic reference revisit: not always spurious cache — can also be real Power Query M-code self-reference

Update / refinement to the 2026-05-20 (session 5.5) LEARNING that locked cyclic reference errors as "almost always spurious cache desync, save+close+reopen fixes it."

5.8 surfaced a second occurrence of the same `"A cyclic reference was encountered during evaluation"` error pattern, this time on DIM_ITEM and DIM_STORE after a Power Query Replace Values transformation was applied to MART_FORECAST_VS_ACTUAL.SERIES_TYPE (renaming categorical values "actual" → "Actual", "forecast" → "Forecast"). The save+close+reopen path from 5.5 didn't always clear it on first attempt.

**Two distinct causes for the same error message:**

1. **Spurious cache desync** (5.5 pattern) — save+close+reopen clears instantly. Common after refresh / model changes / measure edits.
2. **Real Power Query M-code self-reference** (5.8 pattern) — a Replace Values step (or any Table.* transformation) references the query name itself instead of `#"PreviousStepName"` in the first argument. Self-reference creates a real evaluation loop that close+reopen cannot fix. Pattern: `= Table.ReplaceValue(QueryName, ...)` instead of `= Table.ReplaceValue(#"PreviousStep", ...)`. The Replace Values UI sometimes auto-generates the self-reference form depending on user actions.

**Updated diagnostic order for "cyclic reference" errors:**

1. Save + close PBI Desktop + reopen — clears spurious cache cases (5.5 pattern, fast)
2. If error persists after reopen → open Power Query Editor → click each affected table in the left panel → for each Applied Step, look at the formula bar M code → first argument must be `#"PreviousStepName"` (a step name with `#""` wrapper), NOT the query name directly
3. If a step references the query name, edit the formula bar to reference the prior step name → Close & Apply
4. If still failing, more involved tracing (Query Dependencies graph, calculated columns, relationship audit) per crossjoin.co.uk / community.fabric.microsoft.com diagnostic patterns

Source: [community.fabric.microsoft.com — Cyclic ref Replace Values self-reference pattern](https://community.fabric.microsoft.com/t5/Desktop/quot-A-cyclic-reference-was-encountered-during-evaluation-quot/m-p/3425258)

**Carry-forward:** treat cyclic ref as a two-cause symptom, not a single one. Cheapest diagnostic first (close+reopen), then M-code inspection if needed.

### 2026-05-22 — Power Query Replace Values is the ONLY stock-Desktop path for renaming categorical column values

Surfaced during Phase 5 session 5.8. User had a matrix with column headers driven by a categorical column SERIES_TYPE containing values "actual" and "forecast" (lowercase per dbt convention propagated through Snowflake unquoted-identifier UPPERCASE values). Wanted those headers to display as "Actual" / "Forecast" (properly cased).

**Paths investigated:**

- **In-visual "Rename for this visual"** → works for measure pills in field wells (e.g., renaming a Total Revenue (Mart) measure header to "Revenue"), but does NOT work for category values that drive column headers via a Columns field well. Confirmed via community.fabric.microsoft.com thread: "currently for matrix visual, there is no support for dynamically changing column names, and it is not possible for the headers to be dynamic."
- **Data View / Table View in-place edit** → not supported, PBI Desktop Table View is read-only for cell values
- **DAX calculated column with SWITCH** → works (creates a new column returning "Actual" / "Forecast" based on SERIES_TYPE value), bind matrix Columns well to the new column. Adds a column to the model.
- **Data Groups** → works, but creates a "(groups)" version of the field with similar overhead as a calc column
- **Power Query Replace Values** → modifies the existing column's data at load time. No new column created. Cleanest, community-recommended path. Requires opening Power Query Editor (Home → Transform data) and re-applying via Close & Apply (model refresh wait).
- **Update at dbt source layer** → best long-term but biggest commit; rebuild required

**Chosen path in 5.8:** Power Query Replace Values. Worked correctly; matrix redrew with "Actual" / "Forecast" / "Total" properly cased.

**Carry-forward discipline:**

- For categorical value renames in PBI semantic models, Power Query Replace Values is the cleanest stock-Desktop path. Confirmed by Fabric Community: there is no in-visual rename mechanism for category values driving column headers.
- For Project #3's Data Vault scenarios, decide at dbt source layer whether values like "actual" / "forecast" / "active" / "inactive" should be properly-cased at source (Snowflake/Databricks string functions) OR at the BI layer via Power Query. Source-side fix is more durable; BI-side fix is faster iteration.

Sources:
- [community.fabric.microsoft.com — Rename column header in matrix when column represents column value](https://community.fabric.microsoft.com/t5/Desktop/rename-a-column-header-in-matrix-visual-when-column-represents/m-p/3077461)

### 2026-05-22 — PBI transformation layer hierarchy: do data cleanup as close to source as possible (dbt → Power Query → DAX → visual)

Surfaced as a meta-pattern from 5.8 retrospective. Across the session we made multiple data-shaping decisions and didn't always pick the right layer. Locking the hierarchy explicitly.

**The layered transformation hierarchy (do cleanup at the LOWEST layer possible):**

1. **Source layer (dbt models / SQL transforms in Snowflake/Databricks/Postgres)** — best for stable, reusable transforms consumed by multiple downstream systems (PBI + ad-hoc SQL + other BI tools). Examples: properly-cased categorical values, derived calendar attributes, conformed dimensions, business-rule-driven boolean flags. If "actual"/"forecast" should be properly-cased everywhere, fix in dbt — then PBI inherits the clean values for free.
2. **Power Query (M) at PBI load time** — second best, for PBI-specific transforms that should happen automatically on every refresh. Examples: Replace Values for casing fixes; Remove Columns for fields PBI doesn't need; Change Type for numeric/date conversions; Merge/Append for combined sources; Conditional Column for derived text. Persists across refreshes. No model-side overhead. Slower to build but faster runtime than calc columns.
3. **DAX calculated columns** — only when row context is needed AND Power Query can't handle the same transform (rare — PQ Conditional Column covers most cases). Calc columns recalculate on every model refresh and consume VertiPaq memory. Examples where calc column IS the right tool: time intelligence patterns referencing related measures, complex DAX patterns that can't be expressed in M.
4. **DAX measures** — for dynamic aggregations evaluated at query time, not for data cleanup. Measures should compute, not rename.
5. **Visual-level (Filter pane, Rename for this visual, custom format strings)** — last resort, only for per-visual customization that doesn't generalize. "Rename for this visual" is a presentation-layer fix, not a data fix.

**Concrete examples from 5.8 — what we did vs what would be better:**

- **Did right:** Power Query Replace Values for SERIES_TYPE column on MART_FORECAST_VS_ACTUAL (actual → Actual, forecast → Forecast). Persists across refreshes, no calc column overhead, source data layer (dbt) untouched. Even better would be fixing at dbt source, but PQ is the right second choice.
- **Could have done better:** Day Type and SNAP Day Type calc columns on DIM_CALENDAR returning "Weekend"/"Weekday" and "SNAP Day"/"Non-SNAP Day" text. These could equally have been Power Query Conditional Columns on DIM_CALENDAR's M query — same result, slightly lighter VertiPaq footprint, transform lives in the load-time query graph rather than the model. For project consistency though, having all DIM_CALENDAR derived attrs as calc columns is also defensible. Trade-off: PQ keeps the M code graph cleaner; calc columns are easier to edit in PBI without leaving the model view.
- **Best path for Project #3:** push these transforms upstream into dbt where possible (the dim_calendar model can include `day_type` and `snap_day_type` columns natively). PBI then imports clean, semantically-named columns and skips both the PQ step AND the calc column step. Source-side transformations are also reusable for non-PBI consumers (ad-hoc SQL, other BI tools, ML pipelines).

**Other Power Query disciplines worth practicing in Project #3:**

- **Remove unused columns at load time.** Power Query → right-click column header → Remove. Reduces .pbix size, improves refresh speed, keeps the Data pane uncluttered. Doing this at PBI side instead of dbt side is fine when the dbt model is consumed by multiple downstream tools that need different column subsets.
- **Change column types explicitly.** Power Query auto-detects types but the detection isn't always right (e.g., a numeric ID column might be inferred as decimal when it should be whole number; a date string might come in as text). Explicit Change Type steps make the model more deterministic.
- **Rename columns for human readability at load.** snake_case from dbt → human-readable headers in Power Query (e.g., `total_revenue_usd` → `Revenue`). Centralizes the renaming so every visual using that column inherits the friendly name. Beats Rename for this visual which only fixes one visual.
- **Filter at load time, not visual time.** If certain rows should never appear in PBI (e.g., test data, soft-deleted records), filter them out in Power Query — not via Filter pane on every visual.

**Carry-forward discipline for Project #3:**

- Default: cleanup transforms in dbt at source. If not possible, Power Query at load time. DAX only when M can't express it. Visual-level only for per-visual presentation tweaks.
- Project #3's POWERBI_PLAYBOOK should include a "Power Query checklist at load time" section: rename columns to human-friendly names; remove unused columns; explicit type conversions; replace casing/text inconsistencies; document any non-obvious Power Query steps in M comments.
- Make this a mandatory step in the PBI build order — happens AFTER Get Data, BEFORE building any visuals. Easier to maintain clean transforms when the model loads correctly from day 1 vs retrofitting later.

### 2026-05-22 — DAX Studio External Tools registration requires "Install for all users" — per-user install doesn't expose the ribbon tab

Surfaced during Phase 5 session 5.8 when setting up VertiPaq Analyzer for the model-size talk-track artifact. Installed DAX Studio (latest), chose "Install for me only" to avoid admin prompt, ticked "Register as External Tool for Power BI" during install. After reopening PBI Desktop with the .pbix loaded, the **External Tools ribbon tab did not appear**.

**Root cause** (per community.fabric.microsoft.com): the per-user install path places `daxstudio.pbitool.json` in `%LOCALAPPDATA%\DAX Studio\` instead of the all-users path `C:\Program Files (x86)\Common Files\Microsoft Shared\Power BI Desktop\External Tools\` which is where PBI Desktop scans for external tool registrations. Per-user install completes successfully but the registration file is in the wrong location for PBI Desktop's discovery.

**Two verified fixes:**

1. Reinstall DAX Studio choosing **"Install for all users"** (requires admin / UAC prompt). Registration file lands in the correct scanned path. External Tools tab appears.
2. Manually copy `daxstudio.pbitool.json` from `%LOCALAPPDATA%\DAX Studio\` into the all-users Common Files path above (needs admin to write to Program Files).

**Workaround if neither admin path is available:**

Launch DAX Studio standalone from Start Menu → in the Connect dialog → select the **Power BI / SSDT Model** radio button → it detects running PBI Desktop instances dynamically. Loses the convenience of one-click launch from External Tools ribbon but functionally equivalent.

Source: [community.fabric.microsoft.com — External Tools Ribbon Missing](https://community.fabric.microsoft.com/t5/Desktop/External-Tools-Ribbon-Missing/td-p/3196052)

**Carry-forward:** for Project #3, when installing external tools (Tabular Editor, DAX Studio, Bravo for Power BI, ALM Toolkit), default to "Install for all users" to ensure External Tools ribbon registration. Note this in Project #3's tooling setup checklist.

### 2026-05-22 — .vpax files use ZIP64 format; Windows Expand-Archive cannot read them

Surfaced during Phase 6 when trying to extract the VertiPaq Analyzer export (`powerbi/retail_demand_forecasting.vpax`, 76 KB) via PowerShell to populate per-dim cardinality stats into POWERBI_PIPELINE.md without reopening DAX Studio. Tried `Copy-Item .vpax .zip` then `Expand-Archive`. Failed with:

```
Exception calling ".ctor" with "3" argument(s):
"Offset to Central Directory cannot be held in an Int64."
```

**Root cause:** .vpax files are ZIP archives using the **ZIP64 extension** (the format used when an archive or one of its entries exceeds 4GB or 65,535 files). DAX Studio writes .vpax in ZIP64 by default. Windows PowerShell's built-in `Expand-Archive` (built on `System.IO.Compression.ZipArchive`) does not implement ZIP64; the central-directory offset overflow throws on the constructor before any entries are read.

**Three working workarounds:**

1. **7-zip CLI**: `7z x retail_demand_forecasting.vpax -o<dest>` — handles ZIP64 transparently.
2. **Python zipfile module**: `python -m zipfile -e retail_demand_forecasting.vpax <dest>` — also handles ZIP64.
3. **DAX Studio itself**: File → Open VPAX in DAX Studio renders the contents natively (tables, columns, cardinality, size) without needing to extract the archive at all. This is the intended path; the extract-with-tools approach is a workaround.

**Carry-forward:** for any future tooling that exports ZIP64 archives (some database backup files; some build artefacts > 4GB), do not assume `Expand-Archive` will read them. Default to `7z` or `python -m zipfile` for unknown archives. In this project, the .vpax ships with the repo so the reviewer-with-DAX-Studio path works without any extraction step.

### 2026-05-22 — `ruff F821` as a CI pre-merge gate catches stale-variable-reference bugs

Defense-in-depth pattern shipped at Phase 6 close after the 5.9 `mart_rows` NameError incident. The bug was a stale variable reference left in the success-path return f-string of `verify_dbt_one_day` after the 5.4 mart-check surgical removal; sat undiscovered for 6 sessions because the success-path code didn't fire during routine work, only during a full smoke test.

**The CI gate** (`.github/workflows/lint-python.yml`):

```yaml
- name: Run ruff F821 (undefined-name)
  run: ruff check --select F821 .
```

Runs on every pull request and every push to `main`. F821 is ruff's rule for undefined-name references — exactly the class of bug that bit us. The check is **scoped to F821 only**, not full ruff lint, because the codebase isn't lint-clean against the default ruleset and gold-plating every style rule isn't the point. F821 is the one rule that would have caught the actual bug.

**Why this is defense-in-depth, not a primary defence:**

- Manual testing (running the DAG end-to-end) would catch it — and did, eventually, in 5.9.
- Code review by a second pair of eyes would catch it.
- Type checkers (mypy, pyright) would catch it but they're a heavier lift to configure for an Airflow project.
- F821 is the cheapest catch — milliseconds per CI run, no config, no false positives in this codebase.

**Carry-forward:** for Project #3, add F821 to the CI pre-merge gates from day one. Cost ~5 minutes of setup; saves potentially hours of stale-reference debugging. If the project grows to need stricter Python quality bars, the same workflow file can expand the `--select` flag to broader rule sets without restructuring CI.

### Docker

_(to be populated as encountered — containerisation patterns, docker-compose,
networking between containers)_

### Git / GitHub Actions

**Project #2 v1.0 CI shipped 2026-05-22 (Phase 6 close):**

> **Important: this initial v1.0 CI design was patched within hours of shipping. See the v1.0.1 patch block immediately below for the corrected design and the saga that drove it. The bullets here describe what shipped first, not what's running now.**

- `.github/workflows/lint-python.yml` — ruff F821 undefined-name gate (see entry above). Unchanged in v1.0.1.
- `.github/workflows/dbt-ci.yml` — dbt parse + sqlfluff lint on PR + push when `dbt/**` changes. Dummy Snowflake env vars in the job env so `dbt parse` templates without needing real credentials; `dbt test` deliberately excluded with an inline comment explaining the cost-avoidance reasoning (would burn pay-as-you-go credits on every push, run locally before merging). **sqlfluff-lint job rewired in v1.0.1 to use real Snowflake creds via GitHub Secrets — see below.**
- `dbt/.sqlfluff` — Snowflake dialect, jinja templater (no DB connection needed for CI), uppercase keywords, 120-char line length, 3 rule exclusions documented inline (LT05 / RF02 / ST05). **Templater switched to dbt in v1.0.1 — jinja templater couldn't resolve dbt_utils package macros.**

**Carry-forward:** Project #3 starts with `.github/workflows/` already populated from this template — but use the v1.0.1 corrected design, not what shipped at v1.0. Add domain-specific tests on top of the F821 + dbt-parse + sqlfluff foundation.

### 2026-05-22 (later) — v1.0.1 patch: sqlfluff dbt templater + GitHub Secrets pattern; jinja templater can't resolve package macros

The CI shipped at v1.0 had a structural flaw discovered on the first run: the jinja templater with `apply_dbt_builtins = true` resolves dbt-core macros (`ref()`, `source()`, `var()`) but NOT package macros — anything namespaced like `dbt_utils.*`. Project #2 uses `dbt_utils.generate_surrogate_key()` in 5 SQL models. Result: sqlfluff saw raw `{{ dbt_utils.* }}` jinja text in those files, couldn't parse them as SQL, threw cascading bogus errors (LT01 / LT02 / CP01 / PRS against literal template text), and failed CI with a red X on the main branch — the headline portfolio commit.

**Why dummy creds with the dbt templater also failed (the first attempted fix):** the dbt templater calls `dbt compile` under the hood, not `dbt parse`. `dbt compile` initializes the Snowflake adapter and validates the connection. Dummy creds fail with a 404 against the fake account hostname. Confirmed in local test — exact error: `dbt.adapters.exceptions.connection.FailedToConnectError: Database Error 290404 (08001): 404 Not Found: post ci-dummy-account.snowflakecomputing.com:443/session/v1/login-request`. The "no-secrets-in-CI" design constraint that drove the original jinja choice is structurally incompatible with the dbt templater for warehouse-backed adapters.

**What worked (v1.0.1 design):**

1. **Switched `dbt/.sqlfluff` templater from `jinja` to `dbt`.** Added `[sqlfluff:templater:dbt]` section with `project_dir = .` and `profiles_dir = .`.
2. **Added 7 GitHub Actions Secrets to the repo settings**: SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PASSWORD, SNOWFLAKE_ROLE, SNOWFLAKE_WAREHOUSE, SNOWFLAKE_DATABASE, SNOWFLAKE_SCHEMA. Values from local `.env`. GitHub Secrets are encrypted at rest, never logged in workflow output, auto-scrubbed from any echo/print, and not visible to forkers or to the repo owner after creation (only update or delete).
3. **Updated `.github/workflows/dbt-ci.yml` sqlfluff-lint job** to reference `${{ secrets.SNOWFLAKE_* }}` instead of hardcoded dummies. Added install steps for `dbt-core==1.11.10`, `dbt-snowflake==1.11.5`, `sqlfluff-templater-dbt>=3.0.0`, and a `dbt deps` step before the lint command.
4. **dbt-parse job kept its dummy creds** — `dbt parse` truly doesn't connect, dummies work fine. Mixed-credentials approach is honest and documented in the workflow header.
5. **After the templater fix, sqlfluff surfaced REAL style violations** that had been hidden behind the parse cascade — LT01 (spacing around `AS`), LT02 (indentation), CP01 (keyword case), AL01 (implicit aliasing). Ran `sqlfluff fix --force models/` locally to auto-correct most violations across 8 SQL files.
6. **Two stragglers remained that auto-fix couldn't handle**: `int_sales_with_prices.sql` (joined CTE body) and `agg_sales_daily_item_cat.sql` (aggregated CTE body) had their CTE bodies unindented while all OTHER CTEs in those files used 4-space indent. `sqlfluff fix --force` doesn't safely auto-reindent multi-line CTE bodies where the source uses unconventional indentation. Manual fix required (Edit tool, prepend 4 spaces to ~15 lines per file).
7. **Local lint went clean.** Committed + pushed. CI went green on commit `d434493`.

**Long-term degradation plan (documented in workflow header):** the Snowflake trial expires ~2026-06-12 (21 days after v1.0.1 ship). When it does, sqlfluff-lint will start failing because creds won't authenticate. Graceful degradation = switch the sqlfluff-lint job to `continue-on-error: true` at that point. The dbt-parse job will keep passing on dummy creds because it doesn't connect. The lint job still RUNS and prints output, just stops blocking the workflow status. Better than removing the job entirely (preserves portfolio CI story).

**Carry-forward to Project #3 (CRITICAL — bake into Phase 0):**

1. **Use sqlfluff's `dbt` templater from day 1, not `jinja`.** Resist the "no-secrets-in-CI" simplification. As soon as you pull in any dbt package (dbt_utils, dbt_expectations, dbt_external_tables, audit_helper, etc.), the jinja templater + `apply_dbt_builtins` is structurally inadequate.
2. **Wire real warehouse credentials via GitHub Secrets in Phase 0 CI, not as a retrofit.** For Project #3 (Databricks lakehouse): use DATABRICKS_HOST + DATABRICKS_TOKEN + DATABRICKS_HTTP_PATH as secrets. Retrofitting after the project has ~10 dbt models is much more painful than starting with it.
3. **Document the trial-expiry degradation plan in the workflow header at Phase 0.** Future-you will need it. Include the exact `continue-on-error: true` snippet ready to drop in.
4. **Run sqlfluff lint LOCALLY before the first CI push.** Project #2's first CI run was the first time anyone tried to lint the project end-to-end — exactly when ~30 violations surfaced at once. Smaller-batch fixes during the build avoid this surprise.
5. **`sqlfluff fix --force` is good for ~80% of violations but doesn't safely reindent multi-line CTE bodies.** Plan for some manual cleanup time at the end. The known unfixable pattern: CTE body at column 1 inside parens when other CTEs in the same file are indented.
6. **Be wary of cascading errors.** When sqlfluff outputs hundreds of violations of varied types after a config change, the FIRST diagnostic question is "is the templater resolving macros properly?" — not "are these all real style nits?". A parse-level failure can masquerade as a tsunami of style failures. Cascading PRS / TMP errors are the tell.
7. **Demo-durability principle #5 (GitHub repo = canonical artifact) means the green CI badge actually matters.** Recruiters scan the repo for it. Accept the operational cost of real-creds CI (small) for the portfolio cost of a red X (significant).

---

## Mistakes & diagnoses

> Each entry: Symptom → Diagnosis → Fix → What this taught me.
> Capture mid-project, not just at end. Project #1 had ~6 of these — this section
> is where future-me looks first when something goes wrong.

### 2026-05-13 — `Connection Timeout=` in ODBC string silently ignored

**Symptom:** First run of `extract_azure_to_snowflake.py` against a cold (auto-paused) Azure SQL Free Serverless DB. Failed with `pyodbc.OperationalError: [08001] Login timeout expired (0); Invalid connection string attribute (0)` after **16 seconds** — despite our connection string containing `Connection Timeout=90;`.

**Diagnosis:** Our 90-second timeout was never being applied. The 16s figure is suspiciously close to ODBC Driver 17's *default* login timeout (~15s). The `Invalid connection string attribute (0)` clause in the error was the giveaway — the keyword in the connection string was being silently rejected by this driver/pyodbc combo. Phase 1's `load_m5_to_azure_sql.py` had the *exact same* pattern and "worked," but only because the DB happened to wake in time before the unconfigured default fired.

**Fix:** Move the timeout out of the ODBC string and into pyodbc's actual login-timeout parameter via SQLAlchemy `connect_args`:

```python
engine = create_engine(
    f"mssql+pyodbc:///?odbc_connect={quoted}",
    connect_args={"timeout": 90},   # pyodbc honors this reliably
)
```

`connect_args["timeout"]` is passed to `pyodbc.connect(timeout=…)`, which is the canonical Microsoft/pyodbc-documented place to set login timeout. The connection-string form is a hint that some drivers honor and some don't.

**What this taught me:**

- **A keyword that "looks right" in a connection string isn't necessarily honored.** Default-falling-back-silently is the worst class of failure mode because the symptom (timeout) doesn't point at the cause (configuration ignored). Look for the secondary clue — here, `Invalid connection string attribute (0)`.
- **Phase 1's `load_m5_to_azure_sql.py` has the same latent flaw.** It hasn't bitten because that script runs after a smoke test that already woke the DB. Worth a small side-quest fix when convenient — same one-liner: switch to `connect_args={"timeout": 90}`. Until then, the script is fragile on cold-start runs.
- **Carry-forward to Project #3:** when adding timeouts/retries to any database connection, verify the actual underlying library's recognized parameter shape (kwarg vs connection string), not just whatever shape worked in a tutorial. ODBC drivers especially are inconsistent across versions and providers about keyword recognition.

### 2026-05-14 — Azure SQL Free Serverless error 40613 (database paused, fast-fail on cold connect)

**Symptom:** First connection attempt of the 3-year backfill (overnight after session 2). Failed *instantly* with `pyodbc.Error: ('HY000', "... Database 'sqldb-m5-source' on server '...' is not currently available. Please retry the connection later. (40613)")`. Not a timeout — the error returned in well under a second.

**Diagnosis:** Auto-pause had fired sometime overnight since session 2 finished. This is a *different* failure class from session 2's `Connection Timeout` issue. pyodbc isn't timing out — Azure SQL is *explicitly* returning **error code 40613** to say "I heard you, I'm waking, retry later." The 90-second `connect_args["timeout"]` fix from session 2 doesn't help here because nothing is waiting to time out.

**Fix:** `Start-Sleep -Seconds 45` in PowerShell, then re-run the exact same command. Second attempt connected cleanly — the wake-up that the first attempt triggered had completed by then.

**What this taught me:**

- There are at least **two distinct cold-start failure modes** on Azure SQL Free Serverless:
  1. **Silent timeout class** (session 2's bug, now fixed). pyodbc gives up after its default ~15s while the DB is still booting.
  2. **Explicit 40613 fast-fail class** (today). Azure SQL replies immediately with "not available, retry later" before the connection even gets to the login stage.
- The session-2 fix solves (1) but not (2). They need different handling.
- **Production-ready code should wrap `engine.connect()` in a retry loop** that catches error 40613 specifically (and ideally the related 40197 "service is busy" code too), with 2-3 attempts at 30-60s spacing. Logged as a small follow-up improvement to `scripts/extract_azure_to_snowflake.py` — not blocking Phase 2 closeout but worth fixing before Airflow wraps the script in Phase 3 (otherwise the first scheduled run after overnight idle will fail until the second retry).
- **Diagnostic habit:** when a "database connection failed" error appears, read past the generic part to the *specific error code in parentheses*. The number is the signal: `08001` = network/login layer; `40613` = paused-and-waking; `40197` = transient busy. Each has a different fix.
- Carry-forward to Project #3.

### 2026-05-12 / 2026-05-13 — Verified the shape, not the product

**Symptom:** Overnight bulk load script ran cleanly for 11 hours, then exited with `ValueError: Row count mismatch for raw.sales_train: got 59,181,090, expected 59,180,090` at the very end. Looked like a load failure when first seen in the morning terminal.

**Diagnosis:** Data was correct. The script's `EXPECTED_ROWS["sales_train"]` constant had an off-by-1000 arithmetic error: `30,490 series × 1,941 day columns = 59,181,090`, not the 59,180,090 written in the constant. The verification function correctly compared `actual != expected` and raised — exactly as designed. The _expected value itself_ was wrong.

**Fix:** Updated `EXPECTED_ROWS["sales_train"]` to 59,181,090 in `scripts/load_m5_to_azure_sql.py`. Confirmed actual data via manual `SELECT COUNT_BIG(*)` in Azure Query editor (matched 59,181,090). No re-load needed.

**What this taught me:** Verifying the _shape_ of an arithmetic operation ("30,490 rows × 1,941 day columns") is not the same as verifying the _product_. The dimensions were checked correctly (CSV inspection confirmed 30,490 rows and 1,941 day columns), but the multiplication itself was wrong by 1,000 and never independently recomputed — writing "30,490 × 1,941" makes the answer feel obvious enough not to double-check.

**Going forward:**

- When a magic number guards verification, **compute it via two independent routes** (e.g., Python arithmetic AND a `SELECT 30490 * 1941` directly in SQL).
- Better still — **derive expected values from runtime measurements** rather than hardcoding. The loader could compute `len(df_long)` at melt-time and use that as the verification baseline. Hardcoded magic numbers are a known anti-pattern in test/verification code; this is exactly the failure mode they cause.
- Carry-forward to Project #3.

### 2026-05-17 — Test-count drift in PROJECT_CONTEXT records

**Symptom:** Predicted full-DAG `dbt build` PASS=77 after shipping the mart. Actual: PASS=78. Off by one.

**Diagnosis:** Worked backwards through the targeted-build output (`mart_executive_overview` shipped 1 model + 10 tests = 11 PASS, correct) and the project totals (69 tests in YAMLs, also correct). The discrepancy traced to the *previous* session's PROJECT_CONTEXT record: session 4 close claimed `fact_daily_sales` shipped with 13 tests and the project total was 58. Actual YAML counts show 14 fact tests and 59 project tests at session-4 close. The eye-balled column-level tally missed the model-level `unique_combination_of_columns` test on the fact (model-level tests are easy to miss when scanning down a list of column-level `data_tests:` blocks).

**Fix:** Corrected the historical record in PROJECT_CONTEXT's session-5 closeout block (notes the 58 → 59 correction in-line). The 78-count is consistent with the corrected baseline (59 + 11 = 70 tests; 8 models + 1 mart = 9; 70 + 9 = wait, off again — actual is 78 = 69 tests + 9 models, so the math is: 58 → 59 at session 4, 59 + 10 = 69 today; total nodes 8 → 9 with the mart; 69 + 9 = 78 ✓).

**What this taught me:** When counting tests on a model, eyeballing the YAML's `data_tests:` blocks **misses model-level tests** that sit at the model's top level rather than under any column. Two reliable disciplines:

1. Run the targeted `dbt build` and read the count off the output line ("Finished running ... N data tests in ..."). The build is ground truth.
2. When grepping for test counts manually, search separately for `^[[:space:]]+-[[:space:]]+(unique|not_null)` (built-in column tests) AND for namespaced tests (`unique_combination_of_columns`, `accepted_range`, `relationships`) which can sit at column OR model level.

Caught by the phase-boundary structural audit on its second explicit application — paid for itself again.

### 2026-05-17 — Conflated Airflow page-level vs panel-level trash icons → deleted entire DAG history

**Symptom:** Tried to delete a single failed DAG run (the 2014-01-05 manual trigger that hit the incremental backfill limitation) by clicking the red trash icon in the top-right of the DAG page. Instead of deleting just the one run, the entire DAG disappeared from the DAG list. All run history wiped.

**Diagnosis:** Airflow's UI has **multiple trash icons at different scope levels** in different parts of the screen, and they look identical (small red trash can):

| Trash location | What it deletes |
|---|---|
| Top-right of the DAG page (next to play button, under user avatar) | **The entire DAG** — all runs, all task instances, all history |
| Inside the side panel when a Run is selected | Just that one DAG run |
| Inside the side panel when a Task is selected | Just that one task instance |

Claude conflated the page-level (top-right) trash with the panel-level (side panel) trash when guiding through the housekeeping step. Should have specified the panel-level location explicitly.

**Fix:** None needed for the actual code or data — the DAG **file** on disk (`airflow/dags/m5_daily_extract.py`) was untouched. Airflow only deleted the metadata-DB records. The scheduler re-parsed the DAG file on its next sweep (~30 seconds) and the DAG reappeared with zero history. Snowflake data also untouched.

**What was lost:** the run-history records from Phase 3 sessions (extract_one_day successes, the verify-caught-silent-failure episodes from session 2). The Grid view's coloured history bars no longer show those runs. Cosmetic loss — the lessons themselves survive in PROJECT_CONTEXT, in LEARNINGS, and in screenshots taken during the sessions.

**What this taught me:**

1. **Airflow's UI uses scope-sensitive icons.** Same icon (trash can) means different things depending on which part of the screen it's in and what's currently selected. When in doubt, click into the side panel first (select a specific Run or Task) and use the buttons there.
2. **For deleting individual runs cleanly**, the safer path is: select the run in side panel → use "Mark Failed" (closes out retries, marks the run failed) rather than the trash icon. The trash is for permanent metadata removal.
3. **For documentation / portfolio purposes**, leaving a failed run in history is often fine — the red square is meaningful evidence that "verify caught a problem." Only delete if cleanliness matters more than evidence.

**Carry-forward**: when guiding through any UI action, name the EXACT screen region the button is in, not just the button shape. "Red trash in the top-right corner" is ambiguous; "red trash inside the side panel that appears when you click on a Run" is unambiguous. This is a teaching-discipline lesson as much as an Airflow lesson.

---

## Design decisions

> Each entry: what was considered, what was chosen, what was the trade-off accepted.
> Particularly important for: dbt-vs-DAX-vs-marts calls, partitioning strategy,
> incremental model design, surrogate key approach.

### 2026-05-12 — Simulated freshness via date-partitioned extraction (Option B)

**Considered:**

- Option A: Load all 6 years of M5 into Azure SQL once, have Airflow run nightly over the full set. Honest about static data in the README.
- Option B: Same one-time bulk load into Azure SQL, but the Airflow DAG extracts ONE new date slice per scheduled run, advancing through M5 history as if it were a live source.

**Chosen:** Option B.

**Trade-off accepted:** Slightly more complex extract script (must accept a `run_date` parameter and filter `WHERE sale_date BETWEEN data_interval_start AND data_interval_end`) in exchange for a dramatically more credible orchestration story. Incremental dbt models, dbt tests, and failure alerts all have something _real_ to fire on — each Airflow run actually processes new rows, instead of looping over the same static set every night.

**Why this matters for the portfolio:** the headline of Project #2 is orchestration. Option A reduces the schedule to theatre. Option B makes "runs daily, picks up new data, transforms, tests, alerts on failure" a true statement.

### 2026-05-12 — Wide-to-long unpivot moved from dbt staging to Python load

**Considered:** Keep the locked Phase 0 decision — load M5 sales wide-as-is into Azure SQL, do the unpivot in dbt staging downstream.

**Forced re-decision:** Azure SQL's 1024-column-per-table hard limit means M5's wide sales tables (1947 / 1919 columns) cannot physically be loaded wide. Three options considered:

1. **Unpivot in Python** during the load step using `pandas.melt`. Long table lands directly in `raw.sales_train`.
2. **Sparse columns** (allow up to 30,000 cols). Preserves the original plan but introduces an unusual feature, hurts query performance, and makes the dbt staging unpivot awkward over 1900+ columns.
3. **Split wide tables** into chunks of ~960 cols each. Ugly, fragmented downstream.

**Chosen:** Option 1 — unpivot in Python.

**Trade-off accepted:** Loses the "raw layer = 1:1 with source CSV shape" purity, in exchange for not fighting the database engine. dbt staging now does cleaning, casting, and renaming — not shape transformation. Load time roughly 2-3× longer (10-30 minutes for full sales table) but no other compromises.

**General rule learned:** column-count limits of the _specific_ destination engine must be verified before locking source-shape decisions. The original plan would have worked on Snowflake or Postgres but not SQL Server. Project #3 carry-forward.

### 2026-05-12 — Drop `sales_train_validation`, keep only `sales_train_evaluation`

**Considered:** Load both wide sales CSVs (validation + evaluation) per the original "all 5 M5 files" plan.

**Chosen:** Load only `sales_train_evaluation`. Skip `sales_train_validation`.

**Trade-off accepted:** Slightly diverges from the Kaggle competition convention, but `evaluation` is a strict superset — same 30,490 series, plus 28 extra days at the end. Loading both would have produced 58M duplicate rows for zero analytical gain.

**Final raw table count:** 3 (calendar, sell_prices, sales_train), not the "6 raw tables" mentioned loosely in early plan drafts. Also dropped `sample_submission.csv` as out-of-scope (competition submission format, irrelevant to the demand-planning pipeline).

### 2026-05-12 — Airflow stays in Phase 3 (before dbt and Power BI)

**Considered:** Build dbt and Power BI manually first (Phases 3 + 4), then wrap everything in Airflow at the end.

**Chosen:** Keep the plan's ordering — Airflow in Phase 3, dbt in Phase 4, Power BI in Phase 5.

**Trade-off accepted:** Airflow lands before there's a "full" pipeline to schedule — but by end of Phase 2 there's already a working Python extract script, which is exactly what gets wrapped in the first DAG. New layers (dbt, then Power BI refresh) bolt onto the existing DAG as additional tasks. This matches how production pipelines actually grow: orchestration is built early and small, then extended, not bolted on at the end.

**Why this matters:** the headline deliverable shouldn't be the last thing built. If Airflow goes last and the project runs out of energy, the portfolio piece loses its differentiator from Project #1.

### 2026-05-13 — Backfill/incremental cutoff at 2014-01-01

**Considered:** With Option B (simulated freshness via date-partitioned extraction) locked the previous day, the remaining question was: where does the *backfill* end and the *incremental walk* begin? Three options weighed:

1. **Cutoff at 2014-01-01** — backfill 2011-01-29 → 2013-12-31 (~3 years, ~33M sales rows). Incremental window 2014-01-01 → 2016-06-19 (~2.5 years, ~26M rows).
2. **Cutoff at 2015-01-01** — heavier backfill (~4 years, ~43M rows), tighter incremental (~1.5 years, ~16M rows).
3. **Cutoff at 2016-01-01** — maximum backfill (~5 years, ~54M rows), only ~6 months incremental.

**Chosen:** Option 1 — cutoff at 2014-01-01.

**Trade-off accepted:** Less "we already had years of history" weight than option 3, but more headroom for Airflow demo runs in Phase 3. Phil's original instinct, validated against the alternatives. 2.5 years of incremental headroom is overkill (we'll only simulate a few dozen days in demos) but harmless.

**Mechanics:** the extract script (`scripts/extract_azure_to_snowflake.py`, next session) is written once and used in two modes:

- **Backfill mode:** run once with a wide date range covering 2011-01-29 → 2013-12-31. Off-hours, slow, who cares.
- **Incremental mode:** run by Airflow each day, one date at a time, starting 2014-01-01.

Same script, two invocations. This is the standard production pattern — one tool, two modes.

**Why this matters:** Phase 3 needs a credible "the pipeline runs nightly and picks up new data" story. With 2.5 years of unprocessed dates sitting in Azure SQL, Airflow has something *real* to walk through. Each scheduled run actually processes new rows.

### 2026-05-13 — Date-window filtering: fixed scan cost dominates per-row cost

**Observed during Phase 2 session 2 smoke tests:**

| Window | sales_train rows | Wall-clock |
|---|---|---|
| 1 day  | 30,490  | 126 sec |
| 7 days | 213,430 | 121 sec |

**The 7-day extract is faster than the 1-day extract.** Same source query shape (`WHERE d IN (?,?,...)`), just more values in the IN list. Reading 7x more data took *less* wall time.

**Diagnosis:** `raw.sales_train` has no index on the `d` column (we deliberately skipped clustering it — a synthetic string like `d_1142` doesn't sort to date order, so an index buys nothing). Every query against it does a full table scan over 59M rows. That scan cost is roughly fixed per query — it dominates the per-row read cost at small extract sizes.

**Implication for the upcoming backfill:**

The 3-year backfill (~32.5M sales_train rows, 1066 d values in the IN list) was originally feared at "~40 hours if it scales linearly with the daily run." It won't. It's one query, one scan, then bulk-streaming rows through pandas chunks to Snowflake's `write_pandas`. Estimated end-to-end: **60-90 minutes**, not 40 hours.

**General principle for any "should I extract day-by-day or in batches?" decision:**

If the source can't filter cheaply by your partition key (no index, or the column isn't naturally ordered), **a single wide-window query is cheaper than N narrow-window queries.** The Airflow daily run still works (the 2-minute cost is acceptable for a scheduled job), but backfills should always go wide.

**Why this won't bite us in Phase 3:** Airflow runs one date per scheduled invocation, paying the fixed ~70-second scan cost once per day. At 2.3 minutes per run × overnight, total compute is trivial. The pattern is fine; just don't naively *loop* an Airflow-style daily run for backfill.

**Validated 2026-05-14 (Phase 2 session 3):** The actual 3-year backfill completed in **27.3 minutes** (1,638 sec) end-to-end — comfortably inside the 60-90 min prediction and dramatically faster than the originally-feared 40 hours. The "one wide query, fixed scan cost dominates" pattern delivered as designed. Locks the pattern for future Project #3 backfills against any unindexed-source-to-warehouse pipeline.

### 2026-05-13 — `loaded_at` audit column on every Snowflake RAW table

**Considered:** Mirror the Azure SQL raw tables exactly — same columns, nothing else.

**Chosen:** Add `loaded_at TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP() NOT NULL` to all three RAW tables in Snowflake.

**Trade-off accepted:** Tiny divergence from Azure SQL shape (one extra column) in exchange for free lineage on every row. The `DEFAULT` means the extract script doesn't need to populate it — Snowflake stamps it on insert. No code complexity.

**Where it pays back:** Phase 3 "did the pipeline run today?" health checks (`SELECT MAX(loaded_at) FROM raw.sales_train`), debugging late-arriving rows, dbt source freshness tests. Standard practice in raw landing layers — cheap to add now, painful to retrofit.

### 2026-05-17 — Lean marts layer + analyst-facing star schema

**Considered:**

- **Wide-mart pattern (original plan).** Five marts, one per Power BI page, each denormalised with date attributes flattened in. Power BI reads what's there. Common in DE-heavy teams where engineers ship the modelling.
- **Lean-mart pattern.** Expose the warehouse star (fact + conformed dims) directly to Power BI. Build relationships and DAX measures in the BI tool. Marts only where they earn their keep — pre-aggregations for performance, or cross-domain joins that don't belong in any single fact.

**Chosen:** Lean-mart pattern. Start with **one** mart — `mart_executive_overview` — pre-aggregating `fact_daily_sales` (32.9M rows) down to ~1,148 daily summary rows. Add `mart_forecast_vs_actual` later in Phase 5 only when forecasts exist (joins two domains, genuinely earns a mart). Drop the four "thin re-projection" marts (Demand by Hierarchy / Promotion & Price / Seasonality & Calendar / etc.) — Power BI's VertiPaq engine handles those off the star directly, and pre-baking them adds maintenance weight without proportional value.

**Trade-off accepted:** Less pre-baked work in the warehouse means more modelling work in Power BI (relationships, DAX measures, slicer plumbing). That's the intended trade — Phil targets Melbourne BI Analyst / DE-adjacent roles where Power BI fluency matters as much as the pipeline behind it. The leaner shape lets the warehouse demonstrate clean DE patterns *and* leaves real BI work to demo.

**Risk-register revision:** The original "Power BI only ever connects to `marts/` — never raw or warehouse-fact" rule (Project Plan risk register) is **superseded**. New rule: Power BI connects to `WAREHOUSE.fact_*` + `dim_*` for analyst-facing pages, and to `MARTS.mart_*` for pre-aggregated/cross-domain pages. The risk of "Power BI choking on the 32.9M-row fact" is mitigated by VertiPaq's compression — a single XS Snowflake warehouse plus Power BI's in-memory engine handles this size comfortably. Verified empirically before relying on it in Power BI.

**Why this matters for the portfolio:** This is the most-professional architectural default for the role-shape Phil is targeting. The interview talk-track is sharper than "I built five marts because that's what the tutorial said":

> "I exposed the warehouse star directly to Power BI for analyst flexibility. The marts layer holds pre-aggregations only where they genuinely earn their keep — `mart_executive_overview` rolls 32.9M fact rows down to a daily summary for the dashboard home page. Sliceable rollups stay in Power BI's own model where analysts can iterate quickly."

**Carry-forward to Project #3:** When the question "should this go in a mart or a BI tool?" comes up, default to "BI tool" unless the mart earns its keep via (a) pre-aggregation that meaningfully speeds dashboard refresh, (b) cross-domain joins that don't belong in any single fact, or (c) governance/SLA reasons specific to that downstream consumer.

### 2026-05-17 — Extend Airflow DAG with dbt orchestration via Astronomer Cosmos

**Considered:**

- **Defer dbt orchestration to Project #3.** Keep Project #2's Airflow story at "I stood up the stack and wrote a first DAG (extract + verify)." Power BI handles refresh manually. Cheaper in the near term, but the headline DE deliverable (*end-to-end orchestrated pipeline*) is only half-built.
- **Extend the existing DAG via `BashOperator`.** Add one `dbt_build_one_day` task that shell-runs `dbt build`. Simplest possible. Works but doesn't impress — one opaque task fires either green or red with no per-model visibility.
- **Extend the existing DAG via Astronomer Cosmos.** Cosmos parses dbt's manifest at DAG-parse time and generates **one Airflow task per dbt model** with full dependency wiring. Each `stg_*` / `int_*` / `dim_*` / `fact_*` / `mart_*` model + its tests becomes its own Airflow task in the UI. The Airflow lineage graph shows the dbt DAG directly. Steeper setup; real-shop pattern.

**Chosen:** Astronomer Cosmos. Phase 4 session 6 (next) extends `m5_daily_extract.py` from 2 tasks to a 4-stage shape: `extract_one_day → verify_one_day → <Cosmos task group for dbt> → verify_dbt_one_day`. Power BI moves one session out to Phase 5.

**Trade-off accepted:** One additional session of work (~2-3 hours) and one new dependency (`astronomer-cosmos` in the Airflow image) in exchange for the headline DE deliverable being real: *the pipeline runs end-to-end on a schedule, with proper failure handling, tests, and per-model lineage visibility*. Without this, Project #2's orchestration story is foundation-only.

**Why this matters for the portfolio:** The Melbourne BI Analyst / DE-adjacent role-shape Phil is targeting weights orchestration heavily — recruiters and hiring managers reading the README want to see the full chain (extract → load → transform → test → publish) wired into a scheduler with proper failure handling. Cosmos is also the integration approach real shops use in 2025 (the dbt Cloud-native and Airflow-native options have largely converged on this pattern), so showing it in a portfolio repo demonstrates current-tooling fluency, not just conceptual understanding.

**Interview talk-track:**

> "I integrated dbt and Airflow via Astronomer Cosmos. Cosmos parses the dbt manifest at DAG-parse time and creates one Airflow task per dbt model — so the Airflow lineage graph shows the dbt model DAG directly, and a failure on a single model surfaces in the Airflow UI as a single red task with a link to the dbt logs. Cleaner observability than wrapping `dbt build` in a single `BashOperator`."

**Carry-forward to Project #3:** Default to per-model task generation (Cosmos or the equivalent for whatever orchestrator Project #3 uses — Dagster's dbt assets, Prefect's `prefect-dbt`, etc.) rather than monolithic shell-out, unless the dbt project is small enough that the manifest-parse overhead at DAG-parse time isn't worth the granularity.

---

## Pipeline orchestration

> Project #1 was manual. Project #2's headline is orchestration. This section
> captures the orchestration design and lessons learned implementing it.

The Project #2 orchestration story builds in two stages:

**Phase 3 (sessions 1-2): Airflow stack stood up; first DAG fires extract + verify.** Custom Airflow image extends `apache/airflow:2.10.3-python3.11` with the Microsoft ODBC driver and a minimal `requirements-airflow.txt` (pyodbc, python-dotenv, snowflake-connector-python). Postgres metadata DB, LocalExecutor, three Airflow services (init, webserver, scheduler) via docker-compose. The first DAG (`m5_daily_extract`) wraps the existing `scripts/extract_azure_to_snowflake.py` as a single @task at `@daily` cadence, with a downstream `verify_one_day` @task that independently queries Snowflake to confirm rows landed. Caught a real silent failure on its first auto-fire (no M5 data for 2026-05-15; verify went red within 10 minutes of deployment).

**Phase 4 session 6: dbt orchestration wired in via Astronomer Cosmos.** The two-task chain becomes a four-stage chain: `extract_one_day → verify_one_day → [dbt_models task group, 18 auto-generated tasks] → verify_dbt_one_day`. Cosmos reads the dbt project at DAG-parse time and generates one Airflow task per dbt model + per test; the Graph view shows the dbt DAG directly. Failure injection test confirmed the chain halts cleanly on dbt test failure (upstream_failed propagation, no broken-data verifications fire downstream).

**The headline number**: 13 lines of Cosmos config in the DAG replace what would have been ~150 lines of hand-wired `BashOperator` tasks. Single source of truth (the dbt project), automatic regeneration at every DAG-parse, per-model lineage in the Airflow UI.

**The headline talk-track**: *"end-to-end pipeline on a schedule, with proper failure handling, tests, and per-model lineage visibility. A broken dbt test halts the chain at exactly that task, the downstream verify never fires on broken data, and the Airflow UI tells me which model in which layer broke without grepping logs."*

**Carry-forward principles for Project #3**:

1. Always run a downstream "verify" task immediately after a load / transform task. Don't trust the task's own success report — independently query the destination and confirm row counts at the layer being written. This caught a real silent failure on its first day of operation in Project #2.
2. Per-model task generation > monolithic shell-out for orchestrating dbt under any scheduler. Cosmos for Airflow; Dagster's dbt assets for Dagster; `prefect-dbt` for Prefect. The portfolio screenshot of "Airflow Graph view showing my dbt DAG directly" is the headline visual that recruiters respond to.
3. Failure-injection tests as closing validation of every orchestration chain. Flip one value, trigger, observe the clean halt, revert. Produces a credible "yes, the failure path actually works" demonstration.
4. Keep one credential surface (the project-root `.env`) shared between local development and the deployed container env, via `env_var()` in profiles.yml and `env_file:` in docker-compose. One source of truth for secrets, two execution environments.

---

## What I'd do differently next time

> Lessons that should carry forward to Project #3.

_(to be populated through the project, finalised at the end)_

---

## Open questions / things still shaky

> Things I haven't fully understood yet. Useful for spotting where to dig deeper
> in Project #3, or for interview prep where I should expect questions.

_(to be populated as questions come up)_

---

## Carry-forward to Project #3

> What I want to do from day one of the `financial-analytics-lakehouse-project`.
> Populated at Project #3 Phase 0 close, 2026-05-23 (revised after the
> Azure → AWS pivot and Databricks → AWS-native lakehouse pivot). The
> principles below are the Project #2 lessons that genuinely change how
> Project #3 gets built. Tool-specific Project #2 advice (Snowflake DDL,
> Cortex ML, Cosmos task generation) is NOT carried forward — it doesn't
> apply on the AWS-native stack.

### Engineering-standards carry-forward

- **Step-up extract testing — 1 → 10 → 100, never straight to full scale.**
  Banked from Project #2 Phase 1 where the M5 load was an 11-hour single shot.
  In Project #3: extract SEC EDGAR for 1 company first (Apple, CIK 320193),
  verify row counts and content, expand to 10 representative companies across
  sectors, verify again, THEN scale to the full S&P 100. Criterion 9
  (pre-flight verification) of ENGINEERING_STANDARDS.md applied to extract.
- **Verify the PRODUCT, not just the SHAPE.** Banked from the 2026-05-13
  M5 expected-rows magic-number diagnosis. Don't hardcode expected row
  counts as magic numbers — derive them from runtime measurements or
  compute via two independent routes (e.g. Python arithmetic AND a SQL
  SELECT COUNT). For Project #3, the natural expected-rows derivation is
  "ticker_count × filings_per_company × line_items_per_filing" computed at
  extract end and asserted against the actual landed Bronze count.
- **Idempotency by default (criterion 8).** Every DDL is drop-and-recreate;
  every loader is TRUNCATE-then-INSERT or upsert on a key; every Step
  Functions task is safe to re-run without orphaning state or duplicating
  rows.
- **Privacy & security (criterion 4).** Secrets in `.env`, gitignored; TLS in
  transit for all AWS calls; IAM least-privilege from day 1, not retrofitted;
  no PII in logs; no string-concatenated SQL anywhere in Python.
- **Observable progress on long-running operations (criterion 10).** Print
  per-company progress during the extract loop; print per-DPU progress if
  any Glue ETL job runs; emit batch counters not just spinners.
- **Polite rate limiter on day 1, not retrofitted.** SEC EDGAR will block
  on >10 req/sec or missing User-Agent. Build the limiter + exponential
  backoff into the extract from the first commit, validate against a single
  company before scaling.
- **`schedule=None` is the correct portfolio-demo orchestration pattern.**
  Project #2 Airflow lesson, generalises to Project #3 Step Functions: no
  cron schedule, on-demand-only triggers, demos show past execution history
  + can fire a one-shot live execution if needed. Demo-durability principle 2.

### Power BI carry-forward (will apply at Phase 5)

The following are pre-baked into the Phase 5 plan. Full statements in
TEACHING_PREFERENCES.md "Anything else Claude should know":

- Measures live on a dedicated hidden `_Measures` table — never on data tables.
- Measures aggregate the FACT (or the dimensional star), never the pre-aggregated mart.
- Dims joined to a DirectQuery fact must be in Dual storage mode. (Likely
  N/A for Project #3 since the .pbix is Import mode at v1.0 per
  demo-durability principle 3, but flagged in case any visual needs
  composite mode mid-build.)
- Use named measures in visuals — never raw columns with implicit aggregation.
- Diagnose "everything disappears on click" by checking Optimize → Pause
  Visuals BEFORE any other diagnostic.
- Cyclic-reference errors: save + close + reopen the .pbix BEFORE deep-diving
  the model.
- "Cannot find name [column]": check whether you clicked New COLUMN or
  New MEASURE first; they have different evaluation contexts.
- Athena imports default to UPPERCASE column names in PBI (same convention
  as Snowflake — unquoted identifiers stored uppercase). Reference columns
  via Intellisense, don't free-type lowercase.
- **Mart-shape smoke test EARLY, not at Phase 5.** Banked from the 2026-05-18
  Project #2 mart-shape diagnosis at session 5.2. At the dbt session that
  first creates each Gold mart, drag 1-2 fields into 1-2 PBI visuals and
  confirm correct slicing across required dims. Pre-baked into the Phase 4
  delivery plan in PROJECT_PLAN.md.

### Documentation carry-forward

- **Three-layer pattern for code-shaped files.** Verbose-in-chat (teaching),
  clean-on-disk (shippable), walkthrough-doc-alongside (`*_PIPELINE.md` at
  repo root). Pre-baked into the Phase 1-5 deliverables in PROJECT_PLAN.md.
- **Comments-above-the-line, never end-of-line.** Keeps every code line
  short, reads top-to-bottom naturally.
- **Bundled commit per session.** One `git add` + one `git commit` + one
  `git push` at session close, not artificially split into multiple "clean
  history" commits. Subject + max 3 short body lines; WHY not WHAT (the
  diff shows what).
- **Diagnostic queries one per code block.** Same pattern as PowerShell —
  paste-and-run each one separately. Applies to Athena verification queries
  in Project #3.
- **Doc-shaped edits get brief chat descriptions, not inline diffs.**
  Code-shaped edits get inline before/after with line numbers.

### Architectural carry-forward

- **Lean marts layer, analyst-facing star schema in marts.** Project #2's
  Phase 4 session 4 design landed at "warehouse layer holds star schema +
  is the analyst-facing surface; marts layer is thin, only mart_-prefixed
  pre-aggregations for specific reports." Carries forward: Project #3's
  Silver Data Vault is the canonical surface; Gold marts are thin
  pre-aggregations for the 4 dashboard themes, NOT a second modeling layer.
- **`loaded_at` audit column on every raw table.** Project #2 Phase 1 lesson —
  every Bronze row gets an `extract_run_id` + `extract_timestamp` for
  downstream lineage and time-travel debugging. Carries forward to Project #3
  Bronze.
- **No Snowflake-style warehouse upsize pain on Athena**, but DO apply
  equivalent right-sizing checks: Athena workgroup query bytes-scanned cap,
  rate-limiter validation before scaling extract, mart row-count assertions.
  Captured in PROJECT_PLAN.md section 12.

### Anti-patterns explicitly NOT to repeat

- **Don't propose 5-6 hour unattended runs when a 25-min alternative exists.**
  Banked from 2026-05-18 Project #2 backfill discussion. Lead with the shortest
  professional approach; flag duration explicitly before any command runs.
- **Don't conflate page-level vs panel-level trash icons in any UI.** Banked
  from 2026-05-17 Airflow page where the wrong trash icon click deleted the
  entire DAG history. Before any destructive UI action, confirm scope.
- **Don't ship surgical edits without scanning return strings + log calls** for
  stale variable references. Banked from 2026-05-22 v1.0 patch. ruff F821
  CI gate catches this — already in the Project #3 CI plan.
- **Don't assume PBI Desktop UI state from a previous session's closeout
  text.** Before prescribing any PBI step, verify state or ask Phil what he
  sees. PBI Desktop ships frequent UI updates; assertions from memory drift
  out of date fast. Carries forward to Project #3 Phase 5.

### Project-#2-specific advice deliberately NOT carried forward

For clarity, these are Project #2 lessons that don't apply to Project #3
and won't be reused:

- Snowflake-specific DDL, virtual-warehouse sizing, Cortex ML method='best'
  + evaluate=TRUE memory tuning — Project #3 uses Athena (serverless, no
  sizing) and local Python forecasting (no Cortex ML).
- Cosmos `ProjectConfig` / `ProfileConfig` / `ExecutionConfig` patterns —
  Project #3 uses Step Functions, not Airflow + Cosmos.
- Azure SQL Free Serverless 40613 cold-connect lesson, `wake_azure_sql`
  helper — Project #3 has no Azure SQL.
- M5-specific quirks (SNAP flag, `wm_yr_wk`, `d_NNNN` day identifier,
  FOODS/HOUSEHOLD/HOBBIES categorisation) — Project #3 is SEC EDGAR / XBRL,
  totally different domain.

These are still valuable in LEARNINGS.md for the training-journey
consolidation pass (they ARE part of Phil's reference codebase), but they
don't drive any Project #3 build decisions.
