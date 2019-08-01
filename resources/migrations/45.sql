ALTER TABLE `device`
ADD COLUMN `last_lat` double DEFAULT 0.0;

ALTER TABLE `device`
ADD COLUMN `last_lon` double DEFAULT 0.0;

ALTER TABLE `group`
ADD COLUMN `perm_view_map_device` tinyint(1) unsigned NOT NULL;

UPDATE `group`
SET `perm_view_map_device` = `perm_admin`;
