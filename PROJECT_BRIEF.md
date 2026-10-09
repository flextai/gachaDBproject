# Gacha Game Economy Engine — Project Brief

Building an enterprise-grade database requires moving through the same lifecycle software engineers use in production: designing the blueprint, enforcing data integrity at the database layer, simulating production scale, optimizing performance, and finally migrating to an analytical warehouse.

---

### Step 1: Relational Schema Design & DDL Construction

* **What you build:** Write the pure SQL Data Definition Language (`CREATE TABLE` scripts) defining primary keys, foreign keys, cascade behaviors, and field constraints for all tables (`Players`, `Characters_And_Weapons`, `Player_Inventory`, `Banners`, `Pull_History`, `Cash_Transactions`, and `Active_Subscriptions`).
* **The Engineering Rationale:** Schema design is your contract with the data. If you don't enforce constraints like `CHECK (rarity IN (3, 4, 5))` or `UNIQUE(email)` here, bad data enters the database. Fixing corrupt data downstream in a pipeline is exponentially more painful than blocking it at the database layer.

### Step 2: Business Logic via Triggers & Stored Procedures

* **What you build:** Write PL/pgSQL database functions:
  1. An `AFTER INSERT` trigger on `Pull_History` that increments the player's pity counter, or resets it to zero if a 5-star character is pulled.
  2. A stored procedure (`Claim_Monthly_Pass`) that checks `Active_Subscriptions`, validates whether 24 hours have passed since the last claim, and issues currency in a single atomic transaction.
* **The Engineering Rationale:** Application servers can crash mid-operation. Handling pity counters and transaction rewards directly inside PostgreSQL guarantees **ACID atomicity** — a player can never pull a character without their pity counter updating, even if the application calling the database disconnects.

### Step 3: High-Volume Python ETL Pipeline (Your ADP Showcase)

* **What you build:** A Python script using `Faker` and `psycopg2` (or `SQLAlchemy`) that acts as an ETL ingestion engine:
  * **Extract/Generate:** Simulates messy game-server event logs (JSON files) representing 10,000 players, hundreds of thousands of gacha pulls, and transaction logs.
  * **Transform:** Validates schemas, cleans timestamps, deduplicates records, and calculates derived fields.
  * **Load:** Uses batch insertion methods (`execute_values` or `COPY`) to insert this high volume of data into PostgreSQL in seconds rather than row-by-row.
* **The Engineering Rationale:** Real enterprise systems process millions of rows. Writing an ingestion pipeline that handles batches and catches malformed records proves you know how to build reliable data pipelines, not just run toy scripts.

### Step 4: Indexing & Query Profiling (`EXPLAIN ANALYZE`)

* **What you build:** Write heavy analytical queries (e.g., retrieving a player's last 50 pulls on a specific banner or finding top spenders). Run `EXPLAIN ANALYZE` to inspect PostgreSQL's query execution plans, identify costly sequential table scans, and build targeted B-tree and composite indexes to speed them up.
* **The Engineering Rationale:** Anyone can write a query that works on 50 rows. Knowing how to read an execution plan, spot high-cost operations, and slash query execution times from 800ms to 4ms using proper indexing is what distinguishes junior engineers from solid backend practitioners.

### Step 5: Advanced Analytical SQL Views

* **What you build:** Write SQL views using Common Table Expressions (CTEs) and Window Functions (`ROW_NUMBER()`, `DENSE_RANK()`, `LAG()`, `SUM() OVER (...)`):
  * **Pity Trend Analysis:** Average number of pulls before hitting a 5-star.
  * **Player Segmentation:** Classifying players into tiers (F2P, Dolphin, Whale) based on cumulative cash transaction volume.
  * **Monthly Pass Retention:** Tracking churn rates of players whose 30-day passes expired without renewal.
* **The Engineering Rationale:** This satisfies the highest tier of academic grading rubrics by showing you have mastered analytical SQL constructs beyond simple `JOIN` and `GROUP BY` statements.

### Step 6: The Cloud Migration to BigQuery & BI (The CV Showcase)

* **What you build:** With the grade secured, export the normalized tables to Parquet or CSV format and upload them to Google Cloud Storage (GCS). Your friend configures BigQuery to ingest the files, builds an analytical data model (star schema), and connects Looker Studio to build an executive dashboard.
* **The Engineering Rationale:** On your resume, this transforms a standard database project into a full **On-Premise/Relational to Cloud Data Warehouse Migration**. It proves you know how to hand off structured relational data into an OLAP ecosystem ready for business intelligence.

---

*Note: see `PROJECT_NOTES.md` in this same folder for the compressed 1-week timeline, environment setup already completed, and where things were left off.*
