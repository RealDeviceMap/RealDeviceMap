INSERT INTO `group` (name, perm_view_map, perm_view_map_raid, perm_view_map_pokemon, perm_view_stats, perm_admin, perm_view_map_gym, perm_view_map_pokestop, perm_view_map_spawnpoint, perm_view_map_quest, perm_view_map_iv, perm_view_map_cell)
SELECT "default_verified", perm_view_map, perm_view_map_raid, perm_view_map_pokemon, perm_view_stats, perm_admin, perm_view_map_gym, perm_view_map_pokestop, perm_view_map_spawnpoint, perm_view_map_quest, perm_view_map_iv, perm_view_map_cell
FROM `group`
WHERE name = "default";
ALTER TABLE `user`
DROP FOREIGN KEY `fk_group_name`;
ALTER TABLE `user`
ADD CONSTRAINT `fk_group_name` FOREIGN KEY (`group_name`) REFERENCES `group` (`name`)  ON UPDATE CASCADE;
CREATE TRIGGER `group_deleted` before delete on `group`
FOR EACH ROW
UPDATE `user` SET `group_name` = "default" WHERE `group_name` = OLD.`name`;
