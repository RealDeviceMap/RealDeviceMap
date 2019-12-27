DROP TABLE IF EXISTS `invasion_stats`;
CREATE TABLE IF NOT EXISTS `invasion_stats` (
  `date` DATE NOT NULL,
  `grunt_type` smallint(5) unsigned NOT NULL DEFAULT 0,
  `count` int NOT NULL,
  PRIMARY KEY (`date`, `grunt_type`)
);

INSERT INTO invasion_stats (date, grunt_type, count)
SELECT DATE(FROM_UNIXTIME(incident_expire_timestamp)) as date, grunt_type, COUNT(*) as count
FROM pokestop
WHERE grunt_type IS NOT NULL AND grunt_type != 0
GROUP BY grunt_type, date;

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
  
  IF (NEW.grunt_type IS NOT NULL AND NEW.grunt_type != 0) THEN
    INSERT INTO invasion_stats (grunt_type, count, date)
    VALUES
      (NEW.grunt_type, 1, DATE(FROM_UNIXTIME(NEW.incident_expire_timestamp)))
    ON DUPLICATE KEY UPDATE
      count = count + 1&semi
  END IF&semi
END;
