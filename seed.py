"""
seed.py — Inserts master catalog (characters_and_weapons) and banners
into the gacha_game database. Safe to re-run (uses ON CONFLICT DO NOTHING).
"""
import os
from dotenv import load_dotenv
import psycopg2

load_dotenv()


def get_connection():
    return psycopg2.connect(
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD", ""),
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", 5432),
    )


# Master Catalog
CATALOG_ITEMS = [
    # 5-Star Featured Character
    ("Raiden Shogun", "character", 5),

    # 5-Star Standard Characters
    ("Diluc", "character", 5),
    ("Jean", "character", 5),
    ("Qiqi", "character", 5),
    ("Mona", "character", 5),
    ("Keqing", "character", 5),

    # 5-Star Weapons
    ("Engulfing Lightning", "weapon", 5),
    ("Wolf's Gravestone", "weapon", 5),
    ("Skyward Harp", "weapon", 5),

    # 4-Star Characters
    ("Bennett", "character", 4),
    ("Xiangling", "character", 4),
    ("Xingqiu", "character", 4),
    ("Fischl", "character", 4),
    ("Sucrose", "character", 4),

    # 4-Star Weapons
    ("Favonius Sword", "weapon", 4),
    ("The Widsith", "weapon", 4),
    ("Rust", "weapon", 4),
    ("Dragon's Bane", "weapon", 4),

    # 3-Star Weapons (Common pull fodder)
    ("Cool Steel", "weapon", 3),
    ("Harbinger of Dawn", "weapon", 3),
    ("Slingshot", "weapon", 3),
    ("Sharpshooter's Oath", "weapon", 3),
    ("Thrilling Tales of Dragon Slayers", "weapon", 3),
    ("Black Tassel", "weapon", 3),
    ("Debate Club", "weapon", 3),
    ("Bloodtainted Greatsword", "weapon", 3),
]

# (name, banner_type, pull_cost, start_date, end_date, featured_item_name)
BANNERS = [
    ("Reign of Serenity", "character", 160,
     "2024-01-01 00:00:00+00", "2025-12-31 23:59:59+00", "Raiden Shogun"),
    ("Epitome Invocation", "weapon", 160,
     "2024-01-01 00:00:00+00", "2025-12-31 23:59:59+00", "Engulfing Lightning"),
    ("Wanderlust Invocation", "standard", 160,
     "2024-01-01 00:00:00+00", None, None),
]


def seed():
    conn = get_connection()
    try:
        with conn:
            with conn.cursor() as cur:
                # 1. Insert catalog items
                catalog_sql = """
                    INSERT INTO characters_and_weapons (name, item_type, rarity)
                    VALUES (%s, %s, %s)
                    ON CONFLICT (name) DO NOTHING
                """
                cur.executemany(catalog_sql, CATALOG_ITEMS)
                print(f"Catalog: {cur.rowcount} new items inserted "
                      f"({len(CATALOG_ITEMS)} total in list)")

                # 2. Build name -> item_id lookup
                cur.execute("SELECT name, item_id FROM characters_and_weapons")
                item_map = dict(cur.fetchall())
                print(f"Item map built: {len(item_map)} items")

                # 3. Insert banners
                banner_sql = """
                    INSERT INTO banner
                        (name, banner_type, pull_cost, start_date, end_date, featured_item_id)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    ON CONFLICT DO NOTHING
                """
                for name, btype, cost, start, end, feat_name in BANNERS:
                    featured_id = item_map.get(feat_name)  # None -> NULL
                    cur.execute(banner_sql, (name, btype, cost, start, end, featured_id))

                print(f"Banners: inserted up to {len(BANNERS)} banners")

                # 4. Verify
                cur.execute("SELECT banner_id, name, banner_type, featured_item_id FROM banner ORDER BY banner_id")
                print("\n--- Live Banners ---")
                for row in cur.fetchall():
                    print(f"  {row}")

                cur.execute("SELECT COUNT(*) FROM characters_and_weapons")
                print(f"\nTotal catalog items: {cur.fetchone()[0]}")

    finally:
        conn.close()

    print("\nSeed complete.")


if __name__ == "__main__":
    seed()
