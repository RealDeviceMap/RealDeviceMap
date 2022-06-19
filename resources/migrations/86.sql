DROP TRIGGER IF EXISTS pokestop_updated;
CREATE TRIGGER pokestop_updated
    BEFORE UPDATE ON pokestop
    FOR EACH ROW BEGIN
    IF ((OLD.quest_type IS NULL OR OLD.quest_type = 0) AND (NEW.quest_type IS NOT NULL AND NEW.quest_type != 0)) THEN
    INSERT INTO quest_stats (reward_type, pokemon_id, item_id, count, date)
    VALUES (NEW.quest_reward_type, IFNULL(NEW.quest_pokemon_id, 0), IFNULL(NEW.quest_item_id, 0), 1, DATE(FROM_UNIXTIME(NEW.quest_timestamp)))
    ON DUPLICATE KEY UPDATE count = count + 1&semi
    END IF&semi

    IF ((OLD.alternative_quest_type IS NULL OR OLD.alternative_quest_type = 0) AND NEW.alternative_quest_type IS NOT NULL AND NEW.alternative_quest_type != 0) THEN
    INSERT INTO quest_stats (reward_type, pokemon_id, item_id, count, date)
    VALUES (NEW.alternative_quest_reward_type, IFNULL(NEW.alternative_quest_pokemon_id, 0), IFNULL(NEW.alternative_quest_item_id, 0), 1, DATE(FROM_UNIXTIME(NEW.alternative_quest_timestamp)))
    ON DUPLICATE KEY UPDATE count = count + 1&semi
    END IF&semi
END;
