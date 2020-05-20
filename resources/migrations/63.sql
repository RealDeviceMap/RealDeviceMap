ALTER TABLE `group`
ADD COLUMN `perm_view_map_nests` tinyint(1) unsigned NOT NULL;

UPDATE `group`
SET `perm_view_map_nests` = `perm_view_map_pokemon`;
