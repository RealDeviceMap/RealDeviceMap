ALTER TABLE `raid_stats`
ADD COLUMN `level` smallint(3) unsigned DEFAULT NULL;

DROP TABLE IF EXISTS `assignment`;
CREATE TABLE `assignment` (
    `device_uuid` varchar(40) NOT NULL,
    `instance_name` varchar(30) NOT NULL,
    `time` mediumint(6) unsigned NOT NULL,
    PRIMARY KEY (`device_uuid`, `instance_name`, `time`),
    CONSTRAINT `assignment_fk_device_uuid` FOREIGN KEY (`device_uuid`) REFERENCES `device` (`uuid`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `assignment_fk_instance_name` FOREIGN KEY (`instance_name`) REFERENCES `instance` (`name`) ON DELETE CASCADE ON UPDATE CASCADE
);
