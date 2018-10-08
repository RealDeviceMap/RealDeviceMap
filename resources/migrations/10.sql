DROP TABLE IF EXISTS `pokemon_stats`;
DROP TABLE IF EXISTS `raid_stats`;
DROP TRIGGER IF EXISTS `pokemon_inserted`;
DROP TRIGGER IF EXISTS `gym_updated`;
DROP TRIGGER IF EXISTS `gym_inserted`;

CREATE TABLE `pokemon_stats` (
  `date` DATE NOT NULL,
  `pokemon_id` smallint(6) unsigned NOT NULL,
  `count` int NOT NULL,
  PRIMARY KEY (`date`, `pokemon_id`)
);

DELETE
FROM pokemon
WHERE expire_timestamp IS NULL;

INSERT INTO pokemon_stats (date, pokemon_id, count)
SELECT DATE(FROM_UNIXTIME(expire_timestamp)) as date, pokemon_id, COUNT(*) as count
FROM pokemon
GROUP BY pokemon_id, date;

CREATE TRIGGER pokemon_inserted 
AFTER INSERT ON pokemon
FOR EACH ROW
  INSERT INTO pokemon_stats (pokemon_id, count, date)
  VALUES
    (NEW.pokemon_id, 1, DATE(FROM_UNIXTIME(NEW.expire_timestamp)))
  ON DUPLICATE KEY UPDATE
    count = count + 1;

CREATE TABLE `raid_stats` (
  `date` DATE NOT NULL,
  `pokemon_id` smallint(6) unsigned NOT NULL,
  `count` int NOT NULL,
  PRIMARY KEY (`date`, `pokemon_id`)
);

CREATE TRIGGER gym_updated
BEFORE UPDATE ON gym
FOR EACH ROW BEGIN
  IF ((OLD.raid_pokemon_id IS NULL OR OLD.raid_pokemon_id = 0) AND (NEW.raid_pokemon_id IS NOT NULL AND NEW.raid_pokemon_id != 0)) THEN
    INSERT INTO raid_stats (pokemon_id, count, date)
    VALUES
      (NEW.raid_pokemon_id, 1, DATE(FROM_UNIXTIME(NEW.raid_end_timestamp)))
    ON DUPLICATE KEY UPDATE
      count = count + 1;
  END IF;
END;

CREATE TRIGGER gym_inserted
BEFORE INSERT ON gym
FOR EACH ROW BEGIN
  IF (NEW.raid_pokemon_id IS NOT NULL AND NEW.raid_pokemon_id != 0) THEN
    INSERT INTO raid_stats (pokemon_id, count, date)
    VALUES
      (NEW.raid_pokemon_id, 1, DATE(FROM_UNIXTIME(NEW.raid_end_timestamp)))
    ON DUPLICATE KEY UPDATE
      count = count + 1;
  END IF;
END;
