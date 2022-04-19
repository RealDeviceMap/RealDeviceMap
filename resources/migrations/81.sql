CREATE TABLE IF NOT EXISTS `incident` (
    `id` varchar(35) NOT NULL,
    `pokestop_id` varchar(35) NOT NULL,
    `start` int(11) unsigned NOT NULL,
    `expiration` int(11) unsigned NOT NULL,
    `display_type` smallint(5) unsigned NOT NULL,
    `style` smallint(5) unsigned NOT NULL,
    `character` smallint(5) unsigned NOT NULL,
    `updated` int(11) unsigned NOT NULL,
    PRIMARY KEY (`id`),
    KEY `ix_pokestop` (`pokestop_id`, `expiration`),
    CONSTRAINT `fk_incident_pokestop_id` FOREIGN KEY (`pokestop_id`) REFERENCES `pokestop` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
);

DROP TRIGGER IF EXISTS pokestop_updated;
DROP TRIGGER IF EXISTS pokestop_inserted;

CREATE TRIGGER pokestop_updated
    BEFORE UPDATE ON pokestop
    FOR EACH ROW BEGIN
    IF ((OLD.quest_type IS NULL OR OLD.quest_type = 0) AND (NEW.quest_type IS NOT NULL AND NEW.quest_type != 0)) THEN
    INSERT INTO quest_stats (reward_type, pokemon_id, item_id, count, date)
    VALUES (NEW.quest_reward_type, IFNULL(NEW.quest_pokemon_id, 0), IFNULL(NEW.quest_item_id, 0), 1, DATE(FROM_UNIXTIME(NEW.quest_timestamp)))
    ON DUPLICATE KEY UPDATE count = count + 1&semi
    END IF&semi

    IF ((OLD.alternative_quest_type IS NULL OR OLD.alternative_quest_type = 0) AND NEW.alternative_quest_type IS NOT NULL AND NEW.quest_type != 0) THEN
    INSERT INTO quest_stats (reward_type, pokemon_id, item_id, count, date)
    VALUES (NEW.alternative_quest_reward_type, IFNULL(NEW.alternative_quest_pokemon_id, 0), IFNULL(NEW.alternative_quest_item_id, 0), 1, DATE(FROM_UNIXTIME(NEW.alternative_quest_timestamp)))
    ON DUPLICATE KEY UPDATE count = count + 1&semi
    END IF&semi
END;

CREATE TRIGGER pokestop_inserted
    AFTER INSERT ON pokestop
    FOR EACH ROW BEGIN
    IF (NEW.quest_type IS NOT NULL AND NEW.quest_type != 0) THEN
    INSERT INTO quest_stats (reward_type, pokemon_id, item_id, count, date)
    VALUES (NEW.quest_reward_type, IFNULL(NEW.quest_pokemon_id, 0), IFNULL(NEW.quest_item_id, 0), 1, DATE(FROM_UNIXTIME(NEW.quest_timestamp)))
    ON DUPLICATE KEY UPDATE count = count + 1&semi
    END IF&semi

    IF (NEW.alternative_quest_type IS NOT NULL AND NEW.alternative_quest_type != 0) THEN
    INSERT INTO quest_stats (reward_type, pokemon_id, item_id, count, date)
    VALUES (NEW.alternative_quest_reward_type, IFNULL(NEW.alternative_quest_pokemon_id, 0), IFNULL(NEW.alternative_quest_item_id, 0), 1, DATE(FROM_UNIXTIME(NEW.alternative_quest_timestamp)))
    ON DUPLICATE KEY UPDATE count = count + 1&semi
    END IF&semi
END;

CREATE TRIGGER invasion_inserted
    AFTER INSERT ON incident
    FOR EACH ROW BEGIN
    INSERT INTO invasion_stats (grunt_type, count, date)
    VALUES (NEW.character, 1, DATE(FROM_UNIXTIME(NEW.expiration)))
    ON DUPLICATE KEY UPDATE count = count + 1&semi
END;

CREATE TRIGGER invasion_updated
    BEFORE UPDATE ON incident
    FOR EACH ROW BEGIN
    IF (NEW.`character` != OLD.`character`) THEN
    INSERT INTO invasion_stats (grunt_type, count, date)
    VALUES (NEW.character, 1, DATE(FROM_UNIXTIME(NEW.expiration)))
    ON DUPLICATE KEY UPDATE count = count + 1&semi
    END IF&semi
END;

ALTER TABLE pokestop
DROP COLUMN pokestop_display,
DROP COLUMN incident_expire_timestamp,
DROP COLUMN grunt_type;
