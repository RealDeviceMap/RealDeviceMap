DROP TRIGGER pokemon_inserted;
CREATE TRIGGER pokemon_inserted
AFTER INSERT ON pokemon
FOR EACH ROW BEGIN
  INSERT INTO pokemon_stats (pokemon_id, count, date)
  VALUES
    (NEW.pokemon_id, 1, DATE(FROM_UNIXTIME(NEW.expire_timestamp)))
  ON DUPLICATE KEY UPDATE
    count = count + 1&semi
END;
