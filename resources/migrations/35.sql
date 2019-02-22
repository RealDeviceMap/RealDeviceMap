CREATE TABLE IF NOT EXISTS `discord_rule` (
	`priority` int(11) NOT NULL PRIMARY KEY,
    `server_id` bigint(20) unsigned NOT NULL,
	`role_id` bigint(20) unsigned DEFAULT NULL,
    `group_name` varchar(32) NOT NULL,
    FOREIGN KEY (`group_name`) REFERENCES `group` (`name`) ON DELETE CASCADE ON UPDATE CASCADE
);
