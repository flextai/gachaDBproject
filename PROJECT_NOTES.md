# Gacha Game Economy Engine — Project Notes

Class project. Solo (originally split with a friend who was going to handle the BigQuery/Looker migration — that part may now be dropped or handled separately).

**Working style preference:** I want to actually learn this, not just have code generated for me. Explain reasoning, walk through design decisions, let me write the first draft where possible — don't just hand over finished code unprompted.

## Deadline
**1 week**, starting today. (Originally scoped for 3 weeks — compressed.)

## Full project scope (6 steps)

1. **Relational Schema Design & DDL** — CREATE TABLE scripts for: Players, Characters_And_Weapons, Player_Inventory, Banners, Pull_History, Cash_Transactions, Active_Subscriptions. Enforce PKs, FKs, cascade behaviors, CHECK constraints (e.g. rarity IN (3,4,5)), UNIQUE constraints (e.g. email).
2. **Triggers & Stored Procedures (PL/pgSQL)** — AFTER INSERT trigger on Pull_History that increments a pity counter, resets to 0 on a 5-star pull. Stored procedure `Claim_Monthly_Pass` that checks Active_Subscriptions, validates 24h since last claim, issues currency atomically.
3. **Python ETL Pipeline** — Faker + psycopg2 to generate messy mock game-server JSON logs (players, pulls, transactions), transform (clean timestamps, dedupe, derived fields), batch-load via `execute_values` or `COPY`.
4. **Indexing & Query Profiling** — Write analytical queries (last 50 pulls on a banner, top spenders), run EXPLAIN ANALYZE, identify seq scans, add B-tree/composite indexes, document before/after timings.
5. **Analytical SQL Views** — CTEs + window functions (ROW_NUMBER, DENSE_RANK, LAG, SUM() OVER): pity trend analysis, player segmentation (F2P/Dolphin/Whale by cumulative spend), monthly pass retention/churn.
6. **Cloud Migration** — Export normalized tables to Parquet/CSV → GCS → BigQuery → Looker Studio dashboard. **Cut from the 1-week plan** — CV polish, not grade-critical, revisit later if time allows.

## Compressed 1-week plan
- **Day 1:** Full DDL, all 7 tables
- **Day 2:** Pity trigger + Claim_Monthly_Pass procedure (budget the most time here — PL/pgSQL debugging is the usual time-sink)
- **Day 3–4:** Python ETL, reduced scale (~1,000–2,000 players instead of 10,000 — still yields tens of thousands of pull rows)
- **Day 5:** Indexing — pick 2–3 queries, EXPLAIN ANALYZE before/after
- **Day 6:** 2 of the 3 analytical views (pity trend + segmentation prioritized; retention/churn is the one to cut if squeezed)
- **Step 6:** dropped for now

## Environment setup (done)
- **IDE:** PyCharm Professional (JetBrains student license)
- **Python:** 3.12.10 (avoided 3.14 — too new, risk of missing prebuilt wheels for psycopg2 etc; avoided system 3.9/3.10)
- **PostgreSQL:** native via Homebrew, **not Docker** — `postgresql@16`, started with `brew services start postgresql@16`
- **Database:** `gacha_game`, created with `createdb gacha_game`
- **Project location:** `~/PycharmProjects/gachaDBproject`
- **Connection confirmed working** via psycopg2 (`SELECT version()` returned Postgres 16.15 successfully)

## requirements.txt (installed, then pinned via `pip freeze`)
```
psycopg2-binary
Faker
SQLAlchemy
python-dotenv
pandas
```

## Files/config in place
- `main.py` — currently has a working `db_connection.py`-style connection using `.env` + psycopg2, tested with a `SELECT version()` call
- `.env` (project root, gitignored) — `DB_NAME`, `DB_USER`, `DB_PASSWORD` (blank, no password set locally), `DB_HOST=localhost`, `DB_PORT=5432`
- `.gitignore` (project root — separate from the one auto-generated inside `.venv/`) — should include: `.venv/`, `.env`, `__pycache__/`, `*.pyc`, `.idea/`

## Concepts covered so far
- psycopg2 `conn`/`cursor`/`commit()`/`rollback()` lifecycle, why atomicity matters for this project specifically (ties directly into Step 2's trigger/procedure requirement)
- Always use `%s` parameterized queries, never string-built SQL (SQL injection)
- Prefer `with conn: / with conn.cursor():` context-manager pattern for auto commit/rollback

## Where I left off
About to start **Step 1: Players table** — field list and constraints not yet decided. Next table after that: Characters_And_Weapons.
