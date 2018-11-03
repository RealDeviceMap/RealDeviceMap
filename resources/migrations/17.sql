CREATE TABLE IF NOT EXISTS `quest_stats` (
  `date` DATE NOT NULL,
  `reward_type` smallint(6) unsigned NOT NULL DEFAULT 0,
  `pokemon_id` smallint(6) unsigned NOT NULL DEFAULT 0,
  `item_id` smallint(6) unsigned NOT NULL DEFAULT 0,
  `count` int NOT NULL,
  PRIMARY KEY (`date`, `reward_type`, `pokemon_id`, `item_id`)
);

DROP TRIGGER  IF EXISTS pokestop_updated;
DROP TRIGGER  IF EXISTS pokestop_inserted;

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
END;

DROP TRIGGER  IF EXISTS gym_updated;
DROP TRIGGER  IF EXISTS gym_inserted;

CREATE TRIGGER gym_updated
BEFORE UPDATE ON gym
FOR EACH ROW BEGIN
  IF ((OLD.raid_pokemon_id IS NULL OR OLD.raid_pokemon_id = 0) AND (NEW.raid_pokemon_id IS NOT NULL AND NEW.raid_pokemon_id != 0)) THEN
    INSERT INTO raid_stats (pokemon_id, level, count, date)
    VALUES
      (NEW.raid_pokemon_id, NEW.raid_level, 1, DATE(FROM_UNIXTIME(NEW.raid_end_timestamp)))
    ON DUPLICATE KEY UPDATE
      count = count + 1&semi
  END IF&semi
END;

CREATE TRIGGER gym_inserted
AFTER INSERT ON gym
FOR EACH ROW BEGIN
  IF (NEW.raid_pokemon_id IS NOT NULL AND NEW.raid_pokemon_id != 0) THEN
    INSERT INTO raid_stats (pokemon_id, level, count, date)
    VALUES
      (NEW.raid_pokemon_id, NEW.raid_level, 1, DATE(FROM_UNIXTIME(NEW.raid_end_timestamp)))
    ON DUPLICATE KEY UPDATE
      count = count + 1&semi
  END IF&semi
END;
