ALTER TABLE `group`
ADD COLUMN `perm_view_map_lure` tinyint(1) unsigned NOT NULL;

ALTER TABLE `group`
ADD COLUMN `perm_view_map_invasion` tinyint(1) unsigned NOT NULL;

UPDATE `group`
SET `perm_view_map_lure` = `perm_view_map_pokestop`;

UPDATE `group`
SET `perm_view_map_invasion` = `perm_view_map_pokestop`;
