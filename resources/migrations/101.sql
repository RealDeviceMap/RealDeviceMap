ALTER TABLE `spawnpoint`
	ADD COLUMN `first_seen_timestamp` INT(11) UNSIGNED NULL DEFAULT UNIX_TIMESTAMP() AFTER `despawn_sec`,
	ADD COLUMN `spawn_info` INT(11) UNSIGNED NULL DEFAULT 0 AFTER `first_seen_timestamp`,
	ADD INDEX `first_seen_timestamp` (`first_seen_timestamp`),
	ADD INDEX `spawn_info` (`spawn_info`);
	
UPDATE spawnpoint SET first_seen_timestamp = null;
UPDATE spawnpoint SET spawn_info = 0;