CREATE EVENT IF NOT EXISTS `clear_pokemon_history` ON SCHEDULE EVERY 3 DAY
DO DELETE FROM pokemon_history WHERE expire_timestamp <= UNIX_TIMESTAMP() - 1209600;
