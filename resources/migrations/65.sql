ALTER TABLE account
ADD COLUMN `group` VARCHAR(50) DEFAULT NULL;
ALTER TABLE pokemon
ADD COLUMN `is_event` TINYINT(1) UNSIGNED NOT NULL DEFAULT FALSE,
DROP PRIMARY KEY,
ADD PRIMARY KEY (id, is_event);
ALTER TABLE `group`
ADD COLUMN `perm_view_map_event_pokemon` tinyint(1) unsigned NOT NULL;
UPDATE `group`
SET `perm_view_map_event_pokemon` = `perm_view_map_pokemon`;
