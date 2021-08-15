ALTER TABLE pokestop
    ADD COLUMN `alternative_quest_type` int(11) unsigned DEFAULT NULL,
    ADD COLUMN `alternative_quest_timestamp` int(11) unsigned DEFAULT NULL,
    ADD COLUMN `alternative_quest_target` smallint(6) unsigned DEFAULT NULL,
    ADD COLUMN `alternative_quest_conditions` text DEFAULT NULL,
    ADD COLUMN `alternative_quest_rewards` text DEFAULT NULL,
    ADD COLUMN `alternative_quest_template` varchar(100) DEFAULT NULL,
    ADD COLUMN `alternative_quest_pokemon_id` smallint(6) unsigned  GENERATED ALWAYS AS (JSON_EXTRACT(JSON_EXTRACT(alternative_quest_rewards, '$[*].info.pokemon_id'), '$[0]') ),
    ADD INDEX `ix_alternative_quest_alternative_quest_pokemon_id` (alternative_quest_pokemon_id),
    ADD COLUMN `alternative_quest_reward_type` smallint(6) unsigned GENERATED ALWAYS AS (JSON_EXTRACT(JSON_EXTRACT(alternative_quest_rewards, '$[*].type'), '$[0]') ),
    ADD INDEX `ix_alternative_quest_reward_type` (alternative_quest_reward_type);

DROP TRIGGER IF EXISTS pokestop_updated;
DROP TRIGGER IF EXISTS pokestop_inserted;

CREATE TRIGGER pokestop_updated
BEFORE UPDATE ON pokestop
FOR EACH ROW BEGIN
  IF ((OLD.quest_type IS NULL OR OLD.quest_type = 0) AND (NEW.quest_type IS NOT NULL AND NEW.quest_type != 0)) THEN
    INSERT INTO quest_stats (reward_type, pokemon_id, item_id, count, date)
    VALUES
      (NEW.quest_reward_type, IFNULL(NEW.quest_pokemon_id, 0), IFNULL(NEW.quest_item_id, 0), 1, DATE(FROM_UNIXTIME(NEW.quest_timestamp)))
    ON DUPLICATE KEY UPDATE
      count = count + 1&semi
  END IF&semi

  IF ((OLD.grunt_type IS NULL OR OLD.grunt_type = 0) AND (NEW.grunt_type IS NOT NULL AND NEW.grunt_type != 0)) THEN
    INSERT INTO invasion_stats (grunt_type, count, date)
    VALUES
      (NEW.grunt_type, 1, DATE(FROM_UNIXTIME(NEW.incident_expire_timestamp)))
    ON DUPLICATE KEY UPDATE
      count = count + 1&semi
  END IF&semi
END;

CREATE TRIGGER pokestop_inserted
AFTER INSERT ON pokestop
FOR EACH ROW BEGIN
  IF (NEW.quest_type IS NOT NULL AND NEW.quest_type != 0) THEN
    INSERT INTO quest_stats (reward_type, pokemon_id, item_id, count, date)
    VALUES
      (NEW.quest_reward_type, IFNULL(NEW.quest_pokemon_id, 0), IFNULL(NEW.quest_item_id, 0), 1, DATE(FROM_UNIXTIME(NEW.quest_timestamp)))
    ON DUPLICATE KEY UPDATE
      count = count + 1&semi
  END IF&semi

  IF (NEW.alternative_quest_type IS NOT NULL AND NEW.alternative_quest_type != 0) THEN
    INSERT INTO quest_stats (reward_type, pokemon_id, item_id, count, date)
    VALUES
      (NEW.alternative_quest_reward_type, IFNULL(NEW.alternative_quest_pokemon_id, 0), IFNULL(NEW.alternative_quest_item_id, 0), 1, DATE(FROM_UNIXTIME(NEW.alternative_quest_timestamp)))
    ON DUPLICATE KEY UPDATE
      count = count + 1&semi
  END IF&semi

  IF (NEW.grunt_type IS NOT NULL AND NEW.grunt_type != 0) THEN
    INSERT INTO invasion_stats (grunt_type, count, date)
    VALUES
      (NEW.grunt_type, 1, DATE(FROM_UNIXTIME(NEW.incident_expire_timestamp)))
    ON DUPLICATE KEY UPDATE
      count = count + 1&semi
  END IF&semi
END;
