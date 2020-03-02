CREATE TABLE IF NOT EXISTS `instance` (
    `name` VARCHAR(30) NOT NULL PRIMARY KEY,
    `type` ENUM('circle_pokemon', 'circle_raid') NOT NULL,
    `data` text NOT NULL
);
CREATE TABLE IF NOT EXISTS `device` (
    `uuid` VARCHAR(40) NOT NULL PRIMARY KEY,
    `instance_name` VARCHAR(30) DEFAULT NULL,
    `last_host` VARCHAR(30) DEFAULT NULL,
    `last_seen` int(11) unsigned NOT NULL DEFAULT 0,
    CONSTRAINT `fk_instance_name` FOREIGN KEY (`instance_name`) REFERENCES `instance` (`name`) ON DELETE SET NULL ON UPDATE CASCADE
);
