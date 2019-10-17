CREATE TABLE IF NOT EXISTS `pokemon_shiny_stats` (
  `date` DATE NOT NULL,
  `pokemon_id` smallint(6) unsigned NOT NULL,
  `count` int NOT NULL,
  PRIMARY KEY (`date`, `pokemon_id`)
);

INSERT INTO pokemon_shiny_stats (date, pokemon_id, count)
SELECT DATE(FROM_UNIXTIME(expire_timestamp)) as date, pokemon_id, COUNT(*) as count
FROM pokemon
WHERE shiny = true
GROUP BY pokemon_id, date;

DROP TRIGGER IF EXISTS pokemon_inserted;

CREATE TRIGGER pokemon_inserted
BEFORE INSERT ON pokemon
FOR EACH ROW BEGIN
  INSERT INTO pokemon_stats (pokemon_id, count, date)
  VALUES
    (NEW.pokemon_id, 1, DATE(FROM_UNIXTIME(NEW.expire_timestamp)))
  ON DUPLICATE KEY UPDATE
    count = count + 1&semi
  IF (NEW.shiny = 1) THEN BEGIN
      INSERT INTO pokemon_shiny_stats (pokemon_id, count, date)
      VALUES
        (NEW.pokemon_id, 1, DATE(FROM_UNIXTIME(NEW.expire_timestamp)))
      ON DUPLICATE KEY UPDATE
        count = count + 1&semi
      END&semi
  END IF&semi
END;

DROP TRIGGER IF EXISTS pokemon_updated;

CREATE TRIGGER pokemon_updated
BEFORE UPDATE ON pokemon
FOR EACH ROW BEGIN
  IF (NEW.shiny = 1 AND (OLD.shiny = 0 OR OLD.shiny IS NULL)) THEN BEGIN
      INSERT INTO pokemon_shiny_stats (pokemon_id, count, date)
      VALUES
        (NEW.pokemon_id, 1, DATE(FROM_UNIXTIME(NEW.expire_timestamp)))
      ON DUPLICATE KEY UPDATE
        count = count + 1&semi
      END&semi
  END IF&semi
END;

