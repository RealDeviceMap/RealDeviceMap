DROP PROCEDURE IF EXISTS clear_pokemon_history;

DELIMITER $$

CREATE PROCEDURE clear_pokemon_history()

BEGIN
    REPEAT
        DO SLEEP(1); ## Optional, to minimise contention
        DELETE FROM pokemon_history
        WHERE expire_timestamp <= UNIX_TIMESTAMP() - 604800 # older than 7 days
        ORDER BY id
        LIMIT 1000; ## 10000 - would be less conservative
    UNTIL ROW_COUNT() < 1000 END REPEAT;
END$$

DELIMITER ;

CALL clear_pokemon_history();

CREATE EVENT IF NOT EXISTS `clear_pokemon_history` ON SCHEDULE EVERY 5 MINUTE
DO CALL clear_pokemon_history();
