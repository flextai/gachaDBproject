CREATE OR REPLACE FUNCTION update_pity_counter() RETURNS TRIGGER AS $$
    DECLARE
        v_rarity smallint := 0;
        v_banner_type varchar(10);
        v_featured_item_id int;
    BEGIN
        SELECT rarity INTO v_rarity
        FROM characters_and_weapons
        where item_id=NEW.item_id;
        SELECT banner_type, featured_item_id INTO v_banner_type,v_featured_item_id
        FROM banner
        where banner_id=NEW.banner_id;
        IF v_rarity = 5 THEN
            IF v_banner_type = 'character' THEN
                IF v_featured_item_id = NEW.item_id THEN
                    insert into pity_counter(player_id, banner_type,pity,guaranteed)
                    VALUES (NEW.player_id,v_banner_type,0,false)
                    on conflict (player_id,banner_type)
                    DO UPDATE SET
                        pity = 0,
                        guaranteed = false;
                ELSE
                    insert into pity_counter(player_id, banner_type,pity,guaranteed)
                    VALUES (NEW.player_id,v_banner_type,0,true)
                    on conflict (player_id,banner_type)
                    DO UPDATE SET
                        pity = 0,
                        guaranteed = true;
                end if;
            ELSE
                insert into pity_counter(player_id, banner_type,pity)
                    VALUES (NEW.player_id,v_banner_type,0)
                    on conflict (player_id,banner_type)
                    DO UPDATE SET
                        pity = 0,
                        guaranteed = false;
            end if;
        ELSE
            insert into pity_counter(player_id, banner_type,pity)
            VALUES (NEW.player_id,v_banner_type,1)
            on conflict (player_id,banner_type)
            DO UPDATE SET
                pity = pity_counter.pity+1;
        END if;
        return NEW;
    END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE TRIGGER trigger_update_pity
    AFTER INSERT ON pull_history
    FOR EACH ROW
    EXECUTE FUNCTION update_pity_counter();

CREATE OR REPLACE PROCEDURE claim_monthly_pass(p_player_id BIGINT) LANGUAGE plpgsql AS $$
    DECLARE
        v_end_date timestamptz := current_timestamp;
        v_last_claimed_at timestamptz := current_timestamp;
        v_daily_reward smallint := 90;
    BEGIN
        SELECT end_date,last_claimed_at, daily_reward
        INTO v_end_date, v_last_claimed_at, v_daily_reward
        FROM subscription
        WHERE player_id=p_player_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'No active subscription found';
        end if;
        IF v_end_date>CURRENT_TIMESTAMP THEN
            IF current_timestamp-v_last_claimed_at >= '24 hours' OR v_last_claimed_at is NULL THEN
                UPDATE subscription SET
                    last_claimed_at=current_timestamp
                WHERE player_id=p_player_id;
                UPDATE players SET
                    free_currency = free_currency+90
                WHERE player_id=p_player_id;
            ELSE
                RAISE EXCEPTION 'Already claimed within the 24 hour window';
            end if;
        ELSE
            RAISE EXCEPTION 'Pass has expired.';
        end if;
    END;
$$;
