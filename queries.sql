-- ============================================================
-- queries.sql — Day 4: Analytical Queries
-- Demonstrates: JOINs, GROUP BY, window functions (SUM OVER,
-- ROW_NUMBER, LAG, DENSE_RANK), CTEs, CASE WHEN, FILTER
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- Q1: Top 10 biggest spenders (total USD spent)
-- ─────────────────────────────────────────────────────────────
SELECT
    p.player_id,
    p.username,
    SUM(ct.amount_usd)   AS total_usd_spent,
    COUNT(ct.transaction_id) AS num_transactions
FROM cash_transactions ct
JOIN players p ON ct.player_id = p.player_id
WHERE ct.status = 'success'
GROUP BY p.player_id, p.username
ORDER BY total_usd_spent DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────
-- Q2: Cumulative (running) spend per player over time
--     Uses SUM() as a window function
-- ─────────────────────────────────────────────────────────────
SELECT
    player_id,
    transaction_time,
    amount_usd,
    SUM(amount_usd) OVER (
        PARTITION BY player_id
        ORDER BY transaction_time
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total_usd
FROM cash_transactions
WHERE status = 'success'
ORDER BY player_id, transaction_time
LIMIT 50;

-- ─────────────────────────────────────────────────────────────
-- Q3: Most recent pull per player
--     Uses ROW_NUMBER() window function
-- ─────────────────────────────────────────────────────────────
SELECT player_id, banner_id, item_name, rarity, pull_time
FROM (
    SELECT
        ph.player_id,
        ph.banner_id,
        cw.name       AS item_name,
        cw.rarity,
        ph.pull_time,
        ROW_NUMBER() OVER (
            PARTITION BY ph.player_id
            ORDER BY ph.pull_time DESC
        ) AS rn
    FROM pull_history ph
    JOIN characters_and_weapons cw ON ph.item_id = cw.item_id
) sub
WHERE rn = 1
ORDER BY player_id
LIMIT 20;

-- ─────────────────────────────────────────────────────────────
-- Q4: Revenue breakdown by currency
-- ─────────────────────────────────────────────────────────────
SELECT
    regional_code,
    COUNT(*)                         AS num_transactions,
    SUM(amount_local)                AS total_local,
    SUM(amount_usd)                  AS total_usd,
    ROUND(AVG(amount_usd), 2)       AS avg_usd_per_txn
FROM cash_transactions
WHERE status = 'success'
GROUP BY regional_code
ORDER BY total_usd DESC;

-- ─────────────────────────────────────────────────────────────
-- Q5: 5-star pull rate per banner (using FILTER)
-- ─────────────────────────────────────────────────────────────
SELECT
    b.banner_id,
    b.name                                           AS banner_name,
    COUNT(ph.pull_id)                                AS total_pulls,
    COUNT(ph.pull_id) FILTER (WHERE cw.rarity = 5)   AS five_star_pulls,
    COUNT(ph.pull_id) FILTER (WHERE cw.rarity = 4)   AS four_star_pulls,
    ROUND(
        100.0 * COUNT(ph.pull_id) FILTER (WHERE cw.rarity = 5)
             / NULLIF(COUNT(ph.pull_id), 0), 3
    )                                                AS five_star_rate_pct
FROM pull_history ph
JOIN characters_and_weapons cw ON ph.item_id = cw.item_id
JOIN banner b ON ph.banner_id = b.banner_id
GROUP BY b.banner_id, b.name
ORDER BY b.banner_id;

-- ─────────────────────────────────────────────────────────────
-- Q6: Whale classification using CTE
--     Whale: >$200 spent, Dolphin: $50-200, F2P: <$50
-- ─────────────────────────────────────────────────────────────
WITH player_spending AS (
    SELECT
        player_id,
        COALESCE(SUM(amount_usd) FILTER (WHERE status = 'success'), 0) AS total_spent
    FROM cash_transactions
    GROUP BY player_id
)
SELECT
    CASE
        WHEN ps.total_spent > 200 THEN 'Whale'
        WHEN ps.total_spent >= 50  THEN 'Dolphin'
        ELSE 'F2P / Minnow'
    END                   AS spending_tier,
    COUNT(*)              AS player_count,
    ROUND(AVG(ps.total_spent), 2) AS avg_spent
FROM players p
LEFT JOIN player_spending ps ON p.player_id = ps.player_id
GROUP BY spending_tier
ORDER BY avg_spent DESC;

-- ─────────────────────────────────────────────────────────────
-- Q7: Time between consecutive pulls per player (LAG window fn)
-- ─────────────────────────────────────────────────────────────
SELECT
    player_id,
    pull_time,
    prev_pull_time,
    pull_time - prev_pull_time AS time_between_pulls
FROM (
    SELECT
        player_id,
        pull_time,
        LAG(pull_time) OVER (
            PARTITION BY player_id
            ORDER BY pull_time
        ) AS prev_pull_time
    FROM pull_history
) sub
WHERE prev_pull_time IS NOT NULL
ORDER BY player_id, pull_time
LIMIT 30;

-- ─────────────────────────────────────────────────────────────
-- Q8: Rank players by total pulls (DENSE_RANK)
-- ─────────────────────────────────────────────────────────────
SELECT
    p.player_id,
    p.username,
    COUNT(ph.pull_id) AS total_pulls,
    DENSE_RANK() OVER (ORDER BY COUNT(ph.pull_id) DESC) AS pull_rank
FROM players p
JOIN pull_history ph ON p.player_id = ph.player_id
GROUP BY p.player_id, p.username
ORDER BY pull_rank
LIMIT 15;

-- ─────────────────────────────────────────────────────────────
-- Q9: Monthly revenue trend (date_trunc + aggregation)
-- ─────────────────────────────────────────────────────────────
SELECT
    DATE_TRUNC('month', transaction_time) AS month,
    COUNT(*)                              AS num_transactions,
    SUM(amount_usd)                       AS monthly_revenue,
    SUM(SUM(amount_usd)) OVER (ORDER BY DATE_TRUNC('month', transaction_time))
                                          AS cumulative_revenue
FROM cash_transactions
WHERE status = 'success'
GROUP BY DATE_TRUNC('month', transaction_time)
ORDER BY month;

-- ─────────────────────────────────────────────────────────────
-- Q10: Pity counter analysis — avg pity across banner types
-- ─────────────────────────────────────────────────────────────
SELECT
    banner_type,
    COUNT(*)                    AS num_players,
    ROUND(AVG(pity), 1)        AS avg_pity,
    MAX(pity)                   AS max_pity,
    COUNT(*) FILTER (WHERE guaranteed = true) AS guaranteed_next_count
FROM pity_counter
GROUP BY banner_type
ORDER BY banner_type;
