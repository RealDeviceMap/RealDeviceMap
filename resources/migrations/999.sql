ALTER TABLE `spawnpoint`
	ADD COLUMN `created` INT(11) UNSIGNED NULL DEFAULT UNIX_TIMESTAMP() AFTER `despawn_sec`,
	ADD COLUMN `spawn_info` INT(11) UNSIGNED NULL DEFAULT '0' AFTER `created`,
	ADD INDEX `created` (`created`),
	ADD INDEX `spawn_info` (`spawn_info`);
UPDATE spawnpoint SET created=0;