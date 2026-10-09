"""
generator.py — Generates mock player data, gacha pull events, and cash
transactions using Faker. Exports to JSON files in data/.

Gacha rates (Genshin-style):
    5-star: 0.6%    4-star: 5.1%    3-star: 94.3%
"""
import json
import os
import random
from datetime import datetime, timedelta, timezone

from faker import Faker

fake = Faker()
random.seed(42)
Faker.seed(42)

# ──────────────────────── CONFIG ────────────────────────
NUM_PLAYERS = 500
NUM_PULLS = 120_000
NUM_TRANSACTIONS = 2_000

BANNER_IDS = [1, 2, 3]   # character, weapon, standard (must match seed.py order)
BANNER_WEIGHTS = [0.50, 0.20, 0.30]  # pull distribution across banners

# These must match the catalog from seed.py
FIVE_STAR_CHARS = ["Raiden Shogun", "Diluc", "Jean", "Qiqi", "Mona", "Keqing"]
FIVE_STAR_WEAPONS = ["Engulfing Lightning", "Wolf's Gravestone", "Skyward Harp"]
FOUR_STAR_CHARS = ["Bennett", "Xiangling", "Xingqiu", "Fischl", "Sucrose"]
FOUR_STAR_WEAPONS = ["Favonius Sword", "The Widsith", "Rust", "Dragon's Bane"]
THREE_STAR_WEAPONS = [
    "Cool Steel", "Harbinger of Dawn", "Slingshot", "Sharpshooter's Oath",
    "Thrilling Tales of Dragon Slayers", "Black Tassel", "Debate Club",
    "Bloodtainted Greatsword",
]

# Exchange rates to USD
FX_RATES = {"USD": 1.0, "INR": 0.012, "JPY": 0.0067, "EUR": 1.08}
# Typical top-up packs (amount_local, currency, paid_currency_granted)
TOP_UP_PACKS = {
    "USD": [(4.99, 300), (14.99, 980), (29.99, 1980), (49.99, 3280), (99.99, 6480)],
    "INR": [(449, 300), (1299, 980), (2599, 1980), (4399, 3280), (8999, 6480)],
    "JPY": [(610, 300), (1840, 980), (3680, 1980), (6100, 3280), (12000, 6480)],
    "EUR": [(5.49, 300), (15.99, 980), (32.99, 1980), (54.99, 3280), (109.99, 6480)],
}

GAME_START = datetime(2024, 1, 1, tzinfo=timezone.utc)
GAME_NOW = datetime(2026, 9, 1, tzinfo=timezone.utc)


# ──────────────────── PLAYER GENERATION ─────────────────
def generate_players():
    """Generate mock player records with Faker."""
    players = []
    used_emails = set()
    for _ in range(NUM_PLAYERS):
        # Faker emails satisfy the regex in schema.sql
        while True:
            email = fake.unique.email()
            if email not in used_emails:
                used_emails.add(email)
                break

        join_date = fake.date_time_between(
            start_date=GAME_START, end_date=GAME_NOW, tzinfo=timezone.utc
        )
        # Newer players have lower levels on average
        days_active = (GAME_NOW - join_date).days
        max_level = min(60, max(1, days_active // 5))
        level = random.randint(1, max_level)

        players.append({
            "username": fake.user_name(),
            "email": email,
            "created_at": join_date.isoformat(),
            "last_login": fake.date_time_between(
                start_date=join_date, end_date=GAME_NOW, tzinfo=timezone.utc
            ).isoformat(),
            "free_currency": random.choice([0, 0, 0, 160, 320, 800, 1600, 4800]),
            "paid_currency": random.choice([0, 0, 0, 0, 300, 980, 1980]),
            "player_lvl": level,
        })
    return players


# ──────────────────── PULL SIMULATION ───────────────────
def roll_rarity():
    """Return 3, 4, or 5 based on gacha probabilities."""
    r = random.random()
    if r < 0.006:
        return 5
    elif r < 0.006 + 0.051:
        return 4
    else:
        return 3


def pick_item(rarity, banner_type):
    """Pick a random item name given rarity and banner type."""
    if rarity == 5:
        if banner_type == "character":
            return random.choice(FIVE_STAR_CHARS)
        elif banner_type == "weapon":
            return random.choice(FIVE_STAR_WEAPONS)
        else:  # standard
            return random.choice(FIVE_STAR_CHARS + FIVE_STAR_WEAPONS)
    elif rarity == 4:
        return random.choice(FOUR_STAR_CHARS + FOUR_STAR_WEAPONS)
    else:
        return random.choice(THREE_STAR_WEAPONS)


def generate_pulls(players):
    """Simulate pull events across all players."""
    pulls = []
    banner_types = {1: "character", 2: "weapon", 3: "standard"}

    for _ in range(NUM_PULLS):
        player_idx = random.randint(0, len(players) - 1)
        player_id = player_idx + 1  # 1-indexed in DB

        banner_id = random.choices(BANNER_IDS, weights=BANNER_WEIGHTS, k=1)[0]
        rarity = roll_rarity()
        item_name = pick_item(rarity, banner_types[banner_id])

        # Pull time: random time after the player joined
        join_date = datetime.fromisoformat(players[player_idx]["created_at"])
        pull_time = fake.date_time_between(
            start_date=join_date, end_date=GAME_NOW, tzinfo=timezone.utc
        )

        pulls.append({
            "player_id": player_id,
            "banner_id": banner_id,
            "item_name": item_name,      # resolved to item_id in etl.py
            "pull_time": pull_time.isoformat(),
            "pity_at_pull": 0,            # will be set by the trigger
        })

    # Sort by pull_time so inserts fire the trigger in chronological order
    pulls.sort(key=lambda x: x["pull_time"])
    return pulls


# ────────────────── TRANSACTION GENERATION ──────────────
def generate_transactions(players):
    """Generate mock cash top-up transactions."""
    transactions = []
    statuses = ["success"] * 90 + ["failed"] * 7 + ["refunded"] * 3  # 90/7/3 split

    for _ in range(NUM_TRANSACTIONS):
        player_idx = random.randint(0, len(players) - 1)
        player_id = player_idx + 1

        currency = random.choice(list(FX_RATES.keys()))
        amount_local, gems = random.choice(TOP_UP_PACKS[currency])
        amount_usd = round(amount_local * FX_RATES[currency], 2)
        status = random.choice(statuses)

        join_date = datetime.fromisoformat(players[player_idx]["created_at"])
        txn_time = fake.date_time_between(
            start_date=join_date, end_date=GAME_NOW, tzinfo=timezone.utc
        )

        transactions.append({
            "player_id": player_id,
            "amount_local": amount_local,
            "regional_code": currency,
            "amount_usd": amount_usd,
            "paid_currency_granted": gems if status == "success" else 0,
            "status": status,
            "transaction_time": txn_time.isoformat(),
        })

    return transactions


# ──────────────────────── MAIN ──────────────────────────
def main():
    os.makedirs("data", exist_ok=True)

    print("Generating players...")
    players = generate_players()
    with open("data/raw_players.json", "w") as f:
        json.dump(players, f, indent=2)
    print(f"  -> {len(players)} players written to data/raw_players.json")

    print("Generating pulls...")
    pulls = generate_pulls(players)
    with open("data/raw_pulls.json", "w") as f:
        json.dump(pulls, f, indent=2)
    print(f"  -> {len(pulls)} pulls written to data/raw_pulls.json")

    print("Generating transactions...")
    transactions = generate_transactions(players)
    with open("data/raw_transactions.json", "w") as f:
        json.dump(transactions, f, indent=2)
    print(f"  -> {len(transactions)} transactions written to data/raw_transactions.json")

    print("\nDone! Run etl.py next to load into PostgreSQL.")


if __name__ == "__main__":
    main()
