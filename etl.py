"""
etl.py — Reads JSON files from data/ and batch-inserts them into
the gacha_game PostgreSQL database using psycopg2.extras.execute_values
for high-throughput ingestion.

Run order:  seed.py -> generator.py -> etl.py
"""
import json
import os
import time

from dotenv import load_dotenv
import psycopg2
from psycopg2.extras import execute_values

load_dotenv()


def get_connection():
    return psycopg2.connect(
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD", ""),
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", 5432),
    )


def load_json(path):
    with open(path, "r") as f:
        return json.load(f)


def clear_tables(cur):
    """Truncate data tables and reset ID sequences (preserves catalog + banners)."""
    cur.execute("""
        TRUNCATE players, pull_history, pity_counter, cash_transactions,
                 inventory, subscription
        RESTART IDENTITY CASCADE
    """)
    print("Truncated + reset sequences: players, pull_history, pity_counter, "
          "cash_transactions, inventory, subscription")


def insert_players(cur, players):
    """Batch-insert players using execute_values."""
    sql = """
        INSERT INTO players
            (username, email, created_at, last_login,
             free_currency, paid_currency, player_lvl)
        VALUES %s
    """
    rows = [
        (p["username"], p["email"], p["created_at"], p["last_login"],
         p["free_currency"], p["paid_currency"], p["player_lvl"])
        for p in players
    ]
    execute_values(cur, sql, rows, page_size=500)
    print(f"Inserted {len(rows)} players")


def insert_pulls(cur, pulls, item_map):
    """Batch-insert pull_history. Resolves item_name -> item_id.

    NOTE: We use execute_values for speed, but this means the
    pity_counter trigger fires per-row in bulk. For 120K rows
    this takes ~30-60 seconds depending on hardware.
    """
    sql = """
    
        INSERT INTO pull_history
            (player_id, banner_id, item_id, pull_time, pity_at_pull)
        VALUES %s
    """
    rows = [
        (p["player_id"], p["banner_id"], item_map[p["item_name"]],
         p["pull_time"], p["pity_at_pull"])
        for p in pulls
    ]

    # Insert in batches of 5000 with progress reporting
    batch_size = 5000
    total = len(rows)
    for i in range(0, total, batch_size):
        batch = rows[i:i + batch_size]
        execute_values(cur, sql, batch, page_size=1000)
        done = min(i + batch_size, total)
        pct = done / total * 100
        print(f"  Pulls: {done:,}/{total:,} ({pct:.0f}%)", flush=True)

    print(f"Inserted {total:,} pull events")


def insert_transactions(cur, transactions):
    """Batch-insert cash transactions."""
    sql = """
        INSERT INTO cash_transactions
            (player_id, amount_local, regional_code, amount_usd,
             paid_currency_granted, status, transaction_time)
        VALUES %s
    """
    rows = [
        (t["player_id"], t["amount_local"], t["regional_code"],
         t["amount_usd"], t["paid_currency_granted"], t["status"],
         t["transaction_time"])
        for t in transactions
    ]
    execute_values(cur, sql, rows, page_size=500)
    print(f"Inserted {len(rows):,} transactions")


def main():
    # 1. Load JSON data
    print("Loading JSON files...")
    players = load_json("data/raw_players.json")
    pulls = load_json("data/raw_pulls.json")
    transactions = load_json("data/raw_transactions.json")
    print(f"  Players: {len(players):,}  Pulls: {len(pulls):,}  "
          f"Transactions: {len(transactions):,}")

    conn = get_connection()
    try:
        with conn:
            with conn.cursor() as cur:
                # 2. Build item_name -> item_id lookup from catalog
                cur.execute("SELECT name, item_id FROM characters_and_weapons")
                item_map = dict(cur.fetchall())
                print(f"Item map: {len(item_map)} catalog items loaded")

                # 3. Clear existing data (keeps catalog + banners)
                clear_tables(cur)

                # 4. Insert in dependency order
                t0 = time.time()

                insert_players(cur, players)
                insert_transactions(cur, transactions)

                print("Inserting pulls (triggers pity_counter updates)...")
                insert_pulls(cur, pulls, item_map)

                elapsed = time.time() - t0
                print(f"\nAll data loaded in {elapsed:.1f}s")

                # 5. Quick sanity checks
                print("\n--- Sanity Checks ---")
                for table in ["players", "pull_history", "cash_transactions",
                              "pity_counter"]:
                    cur.execute(f"SELECT COUNT(*) FROM {table}")
                    print(f"  {table}: {cur.fetchone()[0]:,} rows")

                # Distribution check
                cur.execute("""
                    SELECT cw.rarity, COUNT(*)
                    FROM pull_history ph
                    JOIN characters_and_weapons cw ON ph.item_id = cw.item_id
                    GROUP BY cw.rarity
                    ORDER BY cw.rarity
                """)
                print("\n--- Pull Rarity Distribution ---")
                total_pulls = 0
                counts = {}
                for rarity, count in cur.fetchall():
                    counts[rarity] = count
                    total_pulls += count
                for rarity in sorted(counts):
                    pct = counts[rarity] / total_pulls * 100
                    print(f"  {rarity}-star: {counts[rarity]:>7,} ({pct:.2f}%)")

    finally:
        conn.close()

    print("\nETL complete.")


if __name__ == "__main__":
    main()
