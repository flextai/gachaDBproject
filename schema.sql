CREATE TABLE IF NOT EXISTS players(
    player_id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(500) NOT NULL UNIQUE check ( email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' ),
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login timestamptz,
    free_currency INT NOT NULL DEFAULT 0 CHECK ( free_currency>=0 ),
    paid_currency INT NOT NULL DEFAULT 0 CHECK ( paid_currency>=0 ),
    player_lvl INT NOT NULL DEFAULT 1 CHECK ( player_lvl>=1 )
);
CREATE TABLE IF NOT EXISTS characters_and_weapons(
    item_id SERIAL PRIMARY KEY,
    name varchar(50) NOT NULL UNIQUE,
    item_type varchar(10) NOT NULL CHECK ( item_type in ('character','weapon') ),
    rarity smallint NOT NULL CHECK ( rarity in (3,4,5) )
);
CREATE TABLE IF NOT EXISTS inventory(
    inventory_id bigserial primary key,
    player_id bigint not null references players(player_id),
    item_id int not null references characters_and_weapons(item_id),
    quantity int not null default 1 check ( quantity>0 ),
    acquired_at timestamptz not null default current_timestamp,
    unique (player_id,item_id)
);
CREATE TABLE IF NOT EXISTS banner(
    banner_id serial primary key,
    name varchar(100) not null,
    start_date timestamptz not null,
    end_date timestamptz check ( end_date>start_date ),
    pull_cost bigint not null default 1 check ( pull_cost>0 ),
    banner_type varchar(10) not null check ( banner_type in ('character','weapon','standard') ),
    featured_item_id int references characters_and_weapons(item_id)
);
CREATE TABLE IF NOT EXISTS pull_history(
    pull_id bigserial primary key,
    player_id bigint not null references players(player_id),
    banner_id int not null references banner(banner_id),
    item_id int not null references characters_and_weapons(item_id),
    pull_time timestamptz not null default current_timestamp,
    pity_at_pull int not null default 0
);
CREATE TABLE IF NOT EXISTS cash_transactions(
    transaction_id bigserial primary key,
    player_id bigint not null references players(player_id),
    amount_local numeric(10,2) not null check ( amount_local > 0 ),
    regional_code varchar(3) not null check ( regional_code in ( 'USD', 'INR', 'JPY', 'EUR') ),
    amount_usd numeric(10,2) not null check ( amount_usd > 0 ),
    paid_currency_granted int not null default 0 check ( paid_currency_granted >= 0 ),
    status varchar(10) not null check ( status in ('success','failed','refunded') ),
    transaction_time timestamptz not null default current_timestamp
);
CREATE TABLE IF NOT EXISTS subscription(
    subscription_id bigserial primary key,
    player_id bigint not null references players(player_id),
    purchased_at timestamptz not null default current_timestamp,
    start_date timestamptz not null default current_timestamp,
    end_date timestamptz not null check ( end_date>start_date ),
    daily_reward int not null default 90,
    last_claimed_at timestamptz,
    unique (player_id)
);
CREATE TABLE IF NOT EXISTS pity_counter(
    player_id bigint not null references players(player_id) on delete cascade ,
    banner_type varchar(10) not null check ( banner_type in('character','weapon','standard') ),
    pity int not null default 0 check ( pity>=0 ),
    guaranteed bool not null default false,
    primary key (player_id,banner_type)
);