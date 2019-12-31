ALTER TABLE `group`
ADD COLUMN `perm_view_map_submission_cell` tinyint(1) unsigned NOT NULL;

UPDATE `group`
SET `perm_view_map_submission_cell` = `perm_view_map_pokestop`;

ALTER TABLE gym
ADD COLUMN `sponsor_id` smallint unsigned DEFAULT NULL;

ALTER TABLE pokestop
ADD COLUMN `sponsor_id` smallint unsigned DEFAULT NULL;
