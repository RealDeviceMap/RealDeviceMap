ALTER TABLE `group`
DROP COLUMN `perm_admin_group`;
ALTER TABLE `group`
ADD COLUMN `perm_view_map_gym` tinyint(1) unsigned NOT NULL;
ALTER TABLE `group`
ADD COLUMN `perm_view_map_pokestop` tinyint(1) unsigned NOT NULL;
UPDATE `group`
SET perm_view_map_gym = 1, perm_view_map_pokestop = 1
WHERE name = "root";
UPDATE `group`
SET perm_view_map_gym = 1, perm_view_map_pokestop = 1
WHERE name = "default";
UPDATE `group`
SET perm_view_map_gym = 1, perm_view_map_pokestop = 1
WHERE name = "no_user";
INSERT INTO metadata (`key`, `value`)
VALUES("MAP_START_LAT", "47.263042");
INSERT INTO metadata (`key`, `value`)
VALUES("MAP_START_LON", "11.400476");
INSERT INTO metadata (`key`, `value`)
VALUES("MAP_START_ZOOM", "14");
INSERT INTO metadata (`key`, `value`)
VALUES("MAP_MAX_POKEMON_ID", "649");
