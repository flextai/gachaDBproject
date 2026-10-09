-- ============================================================
-- indexes.sql — Day 5: Performance Optimization
-- Creates indexes for the most common query patterns,
-- with EXPLAIN ANALYZE results documented in comments.
-- ============================================================

-- ─────────────────── Pull History Indexes ───────────────────

-- Speeds up: player pull history lookups, most-recent-pull queries,
-- time-between-pulls (LAG), and any per-player pull aggregation.
CREATE INDEX IF NOT EXISTS idx_pull_history_player_time
    ON pull_history (player_id, pull_time DESC);

-- Speeds up: 5-star rate per banner, banner performance views.
CREATE INDEX IF NOT EXISTS idx_pull_history_banner
    ON pull_history (banner_id);

-- Speeds up: joins between pull_history and characters_and_weapons.
CREATE INDEX IF NOT EXISTS idx_pull_history_item
    ON pull_history (item_id);


-- ─────────────────── Transaction Indexes ────────────────────

-- Speeds up: top spender queries, per-player spending aggregations,
-- revenue trend queries. Partial index excludes failed/refunded.
CREATE INDEX IF NOT EXISTS idx_cash_txn_player_success
    ON cash_transactions (player_id, transaction_time)
    WHERE status = 'success';

-- Speeds up: revenue-by-currency breakdown.
CREATE INDEX IF NOT EXISTS idx_cash_txn_currency
    ON cash_transactions (regional_code)
    WHERE status = 'success';


-- ─────────────────── Pity Counter Index ─────────────────────

-- Already has a composite PK (player_id, banner_type),
-- which serves as the clustered index. No extra index needed.


-- ─────────────────── Player Indexes ─────────────────────────

-- Email lookups (already has UNIQUE constraint = implicit index).
-- Username is not unique, but rarely queried alone — skip.


-- ============================================================
-- EXPLAIN ANALYZE results (measured on 120K pulls, 2K txns):
-- ============================================================

-- Q3 (most recent pull per player) with idx_pull_history_player_time:
--   Uses Index Scan using idx_pull_history_player_time
--   with Memoize on characters_and_weapons PK (4546 hits, 26 misses).
--   Planning: 1.4ms  Execution: 12.0ms
--   Without index: Seq Scan + Sort would be ~350ms (est. ~30x slower)

-- Q1 (top 10 spenders) with idx_cash_txn_player_success:
--   HashAggregate + Hash Join on 1,796 successful transactions.
--   top-N heapsort (26kB memory) for ORDER BY.
--   Planning: 1.3ms  Execution: 2.4ms
