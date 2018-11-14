CREATE TABLE IF NOT EXISTS `group` (
	`name` VARCHAR(32) NOT NULL PRIMARY KEY,
	`perm_view_map` tinyint(1) unsigned NOT NULL,
	`perm_view_map_raid` tinyint(1) unsigned NOT NULL,
	`perm_view_map_pokemon` tinyint(1) unsigned NOT NULL,
	`perm_view_stats` tinyint(1) unsigned NOT NULL,
	`perm_admin_setting` tinyint(1) unsigned NOT NULL,
	`perm_admin_user` tinyint(1) unsigned NOT NULL,
	`perm_admin_group` tinyint(1) unsigned NOT NULL
);
CREATE TABLE IF NOT EXISTS `user` (
	`username` VARCHAR(32) NOT NULL PRIMARY KEY,
	`email` VARCHAR(128) NOT NULL UNIQUE KEY,
	`password` VARCHAR(72) NOT NULL,
	`discord_id` BIGINT UNSIGNED DEFAULT NULL,
	`email_verified` tinyint(1) unsigned DEFAULT FALSE,
	`group_name` VARCHAR(32) NOT NULL DEFAULT "default",
     CONSTRAINT `fk_group_name` FOREIGN KEY (`group_name`) REFERENCES `group`(`name`)
);
INSERT INTO `group` (name, perm_view_map, perm_view_map_raid, perm_view_map_pokemon, perm_view_stats, perm_admin_setting, perm_admin_user, perm_admin_group)
VALUES ("root", 1, 1, 1, 1, 1, 1, 1);
INSERT INTO `group` (name, perm_view_map, perm_view_map_raid, perm_view_map_pokemon, perm_view_stats, perm_admin_setting, perm_admin_user, perm_admin_group)
VALUES ("default", 1, 1, 1, 1, 0, 0, 0);
INSERT INTO `group` (name, perm_view_map, perm_view_map_raid, perm_view_map_pokemon, perm_view_stats, perm_admin_setting, perm_admin_user, perm_admin_group)
VALUES ("no_user", 1, 1, 1, 1, 0, 0, 0);
