# Gacha Game Economy Engine

A full-stack database project simulating a gacha game's economy — from schema design and ACID business logic down to ETL data pipelines and analytical reporting, all built on **PostgreSQL 16** and **Python 3.12**.

## Project Structure

```
gachaDBproject/
├── schema.sql          # Day 1: 8-table DDL (players, items, banners, pulls, transactions, pity, inventory, subscriptions)
├── businessLogic.sql   # Day 2: PL/pgSQL trigger (pity counter state machine) + stored procedure (monthly pass claim)
├── seed.py             # Day 3: Master catalog (26 items) + 3 banners seeder
├── generator.py        # Day 3: Faker-based mock data generator (500 players, 120K pulls, 2K transactions)
├── etl.py              # Day 3: Batch ETL pipeline using execute_values (120K rows in ~6s)
├── queries.sql         # Day 4: 10 analytical queries (JOINs, window functions, CTEs, FILTER)
├── indexes.sql         # Day 5: 5 strategic indexes + EXPLAIN ANALYZE results
├── views.sql           # Day 6: 5 reporting views (player summary, banner performance, revenue dashboard)
├── .env                # Database connection config
├── requirements.txt    # Python dependencies
└── data/               # Generated JSON files (raw_players, raw_pulls, raw_transactions)
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Database | PostgreSQL 16 (native, Homebrew) |
| Business Logic | PL/pgSQL (triggers, stored procedures) |
| ETL Pipeline | Python 3.12, psycopg2, Faker |
| Batch Ingestion | `psycopg2.extras.execute_values` |

## Schema (8 Tables)

- **players** — User accounts with email regex validation, dual currency balances
- **characters_and_weapons** — Master item catalog (3/4/5-star rarities)
- **banner** — Time-limited and permanent gacha banners with featured items
- **pull_history** — Every gacha roll event (120K+ rows)
- **inventory** — Player item ownership (quantity tracking)
- **cash_transactions** — Real-money purchases with multi-currency FX conversion
- **subscription** — Monthly pass with daily claim tracking
- **pity_counter** — Per-player, per-banner-type pity progression (composite PK)

### Key Constraints
- Email regex: `^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$`
- Non-negative currency: `CHECK (free_currency >= 0)`
- Rarity enum: `CHECK (rarity IN (3, 4, 5))`
- Date integrity: `CHECK (end_date > start_date)`
- Foreign key cascades on player deletion

## Business Logic (PL/pgSQL)

### 1. Pity Counter Trigger (`AFTER INSERT ON pull_history`)
- Tracks per-player, per-banner-type pity count
- Implements 50/50 guarantee state machine for character banners:
  - Won featured → reset pity, `guaranteed = false`
  - Lost 50/50 (got standard 5★) → reset pity, `guaranteed = true`
  - Non-5★ pull → increment pity counter
- Uses `ON CONFLICT ... DO UPDATE` (UPSERT) for atomic state updates

### 2. Monthly Pass Claim (`claim_monthly_pass` procedure)
- Validates active subscription exists
- Checks pass expiration
- Enforces 24-hour cooldown between claims
- Atomically updates `subscription.last_claimed_at` + `players.free_currency`

## ETL Pipeline

```
seed.py → generator.py → etl.py
```

1. **seed.py** — Inserts 26 catalog items + 3 banners (idempotent with `ON CONFLICT DO NOTHING`)
2. **generator.py** — Generates mock data with realistic distributions:
   - 500 players (Faker emails, level correlated to account age)
   - 120,000 gacha pulls (0.6% 5★, 5.1% 4★, 94.3% 3★)
   - 2,000 cash transactions (4 currencies, 5 top-up tiers, 90/7/3 success/fail/refund split)
3. **etl.py** — Batch ingestion via `execute_values` with progress reporting

## Analytical Queries (10 Queries)

| # | Query | SQL Concepts |
|---|-------|-------------|
| Q1 | Top 10 biggest spenders | `JOIN`, `GROUP BY`, `SUM`, `ORDER BY` |
| Q2 | Running spend per player | `SUM() OVER (PARTITION BY ... ORDER BY)` |
| Q3 | Most recent pull per player | `ROW_NUMBER() OVER (PARTITION BY)` |
| Q4 | Revenue by currency | `GROUP BY`, `SUM`, `ROUND` |
| Q5 | 5★ pull rate per banner | `COUNT() FILTER (WHERE)`, `NULLIF` |
| Q6 | Whale/Dolphin/F2P classification | `CTE`, `CASE WHEN`, `LEFT JOIN` |
| Q7 | Time between consecutive pulls | `LAG()` window function |
| Q8 | Player ranking by total pulls | `DENSE_RANK()` window function |
| Q9 | Monthly revenue trend | `DATE_TRUNC`, cumulative `SUM() OVER` |
| Q10 | Pity counter analysis | `AVG`, `MAX`, `FILTER (WHERE)` |

## Indexes & Optimization

5 strategic indexes targeting the most common query patterns:

- `idx_pull_history_player_time` — Composite (player_id, pull_time DESC) for player-centric queries
- `idx_pull_history_banner` — Banner-level aggregation
- `idx_pull_history_item` — Join acceleration with catalog
- `idx_cash_txn_player_success` — Partial index (status = 'success') for spending queries
- `idx_cash_txn_currency` — Partial index for currency breakdown

EXPLAIN ANALYZE on Q3 shows Index Scan at **12ms** vs estimated **350ms** sequential scan (~30x improvement).

## Reporting Views

| View | Purpose |
|------|---------|
| `v_player_summary` | One-row-per-player dashboard with pulls, spending, tier classification |
| `v_banner_performance` | Per-banner pull counts, unique pullers, rarity distribution |
| `v_monthly_revenue` | Monthly revenue with cumulative total (window function) |
| `v_pity_overview` | Current pity state + pulls until hard pity |
| `v_item_popularity` | Items ranked by pull frequency within each rarity tier |

## Setup & Run

```bash
# Prerequisites: PostgreSQL 16, Python 3.12

# 1. Create database
createdb gacha_game

# 2. Run schema + business logic
psql -d gacha_game -f schema.sql
psql -d gacha_game -f businessLogic.sql

# 3. Install Python dependencies
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 4. Configure .env
cp .env.example .env  # edit DB credentials

# 5. Seed catalog + generate data + ETL
python seed.py
python generator.py
python etl.py

# 6. Create indexes + views
psql -d gacha_game -f indexes.sql
psql -d gacha_game -f views.sql

# 7. Run analytical queries
psql -d gacha_game -f queries.sql
```

## Team

- Nissim Arya (24BEL1009)
- Nishant Singh (24BEL1019)
- Madhav Saraf (24BEL1063)
- Gaurav Mukherjee (24BEL1071)
- Abhijeet Bera (24BEL1073)
