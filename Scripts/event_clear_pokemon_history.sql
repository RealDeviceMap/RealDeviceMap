CREATE EVENT IF NOT EXISTS `clear_pokemon_history` ON SCHEDULE EVERY 1 DAY
DO CALL clear_pokemon_history();

DROP PROCEDURE IF EXISTS clear_pokemon_history;

DELIMITER $$

CREATE PROCEDURE clear_pokemon_history()

BEGIN
    REPEAT
        DO SLEEP(1); ## Optional, to minimise contention
        DELETE FROM pokemon_history
        WHERE expire_timestamp <= UNIX_TIMESTAMP() - 604800 # older than 7 days
        ORDER BY id
        LIMIT 10000; ## 1000 - would be more conservative
    UNTIL ROW_COUNT() = 0 END REPEAT;
END$$

DELIMITER ;

CALL clear_pokemon_history();
