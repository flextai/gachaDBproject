-- ============================================================
-- views.sql — Day 6: Reporting Views
-- Reusable views that encapsulate common analytical patterns.
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- V1: Player Dashboard Summary
--     One row per player with aggregated stats.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_player_summary AS
SELECT
    p.player_id,
    p.username,
    p.email,
    p.player_lvl,
    p.free_currency,
    p.paid_currency,
    p.created_at                                        AS join_date,
    COALESCE(pull_stats.total_pulls, 0)                 AS total_pulls,
    COALESCE(pull_stats.five_star_pulls, 0)             AS five_star_pulls,
    COALESCE(spend_stats.total_usd_spent, 0)            AS total_usd_spent,
    COALESCE(spend_stats.num_purchases, 0)              AS num_purchases,
    CASE
        WHEN COALESCE(spend_stats.total_usd_spent, 0) > 200 THEN 'Whale'
        WHEN COALESCE(spend_stats.total_usd_spent, 0) >= 50  THEN 'Dolphin'
        ELSE 'F2P'
    END                                                 AS spending_tier
FROM players p
LEFT JOIN (
    SELECT
        ph.player_id,
        COUNT(*)                                     AS total_pulls,
        COUNT(*) FILTER (WHERE cw.rarity = 5)        AS five_star_pulls
    FROM pull_history ph
    JOIN characters_and_weapons cw ON ph.item_id = cw.item_id
    GROUP BY ph.player_id
) pull_stats ON p.player_id = pull_stats.player_id
LEFT JOIN (
    SELECT
        player_id,
        SUM(amount_usd)  AS total_usd_spent,
        COUNT(*)         AS num_purchases
    FROM cash_transactions
    WHERE status = 'success'
    GROUP BY player_id
) spend_stats ON p.player_id = spend_stats.player_id;


-- ─────────────────────────────────────────────────────────────
-- V2: Banner Performance Report
--     Per-banner pull counts and rarity distribution.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_banner_performance AS
SELECT
    b.banner_id,
    b.name                                                 AS banner_name,
    b.banner_type,
    cw_feat.name                                           AS featured_item,
    COUNT(ph.pull_id)                                      AS total_pulls,
    COUNT(DISTINCT ph.player_id)                           AS unique_pullers,
    COUNT(ph.pull_id) FILTER (WHERE cw.rarity = 5)         AS five_star_count,
    COUNT(ph.pull_id) FILTER (WHERE cw.rarity = 4)         AS four_star_count,
    COUNT(ph.pull_id) FILTER (WHERE cw.rarity = 3)         AS three_star_count,
    ROUND(
        100.0 * COUNT(ph.pull_id) FILTER (WHERE cw.rarity = 5)
             / NULLIF(COUNT(ph.pull_id), 0), 3
    )                                                      AS five_star_rate_pct
FROM banner b
LEFT JOIN pull_history ph ON b.banner_id = ph.banner_id
LEFT JOIN characters_and_weapons cw ON ph.item_id = cw.item_id
LEFT JOIN characters_and_weapons cw_feat ON b.featured_item_id = cw_feat.item_id
GROUP BY b.banner_id, b.name, b.banner_type, cw_feat.name;


-- ─────────────────────────────────────────────────────────────
-- V3: Monthly Revenue Dashboard
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_monthly_revenue AS
SELECT
    DATE_TRUNC('month', transaction_time)::date   AS month,
    COUNT(*)                                      AS total_transactions,
    COUNT(*) FILTER (WHERE status = 'success')    AS successful,
    COUNT(*) FILTER (WHERE status = 'failed')     AS failed,
    COUNT(*) FILTER (WHERE status = 'refunded')   AS refunded,
    SUM(amount_usd) FILTER (WHERE status = 'success')
                                                  AS revenue_usd,
    SUM(SUM(amount_usd) FILTER (WHERE status = 'success'))
        OVER (ORDER BY DATE_TRUNC('month', transaction_time))
                                                  AS cumulative_revenue
FROM cash_transactions
GROUP BY DATE_TRUNC('month', transaction_time)
ORDER BY month;


-- ─────────────────────────────────────────────────────────────
-- V4: Pity Tracker Overview
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_pity_overview AS
SELECT
    pc.player_id,
    p.username,
    pc.banner_type,
    pc.pity,
    pc.guaranteed,
    CASE
        WHEN pc.banner_type IN ('character', 'weapon') THEN 90 - pc.pity
        ELSE 90 - pc.pity
    END AS pulls_until_hard_pity
FROM pity_counter pc
JOIN players p ON pc.player_id = p.player_id;


-- ─────────────────────────────────────────────────────────────
-- V5: Item Popularity Ranking
--     Which items are pulled the most?
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_item_popularity AS
SELECT
    cw.item_id,
    cw.name,
    cw.item_type,
    cw.rarity,
    COUNT(ph.pull_id)       AS times_pulled,
    DENSE_RANK() OVER (
        PARTITION BY cw.rarity
        ORDER BY COUNT(ph.pull_id) DESC
    )                       AS rank_within_rarity
FROM characters_and_weapons cw
LEFT JOIN pull_history ph ON cw.item_id = ph.item_id
GROUP BY cw.item_id, cw.name, cw.item_type, cw.rarity
ORDER BY cw.rarity DESC, times_pulled DESC;
