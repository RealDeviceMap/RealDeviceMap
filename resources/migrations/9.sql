SET FOREIGN_KEY_CHECKS=0;
DROP TABLE spawnpoint;
SET FOREIGN_KEY_CHECKS=1;
CREATE TABLE `spawnpoint` (
	`id` bigint(15) unsigned NOT NULL,
    `lat` double(18,14) NOT NULL,
    `lon` double(18,14) NOT NULL,
    `updated` int(11) UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`)
);
INSERT INTO  `spawnpoint` (id, lat, lon, updated)
SELECT spawn_id, MAX(lat), MAX(lon), unix_timestamp()
FROM pokemon
GROUP by spawn_id
HAVING spawn_id IS NOT NULL;
ALTER TABLE `pokemon`
ADD CONSTRAINT `fk_spawn_id` FOREIGN KEY (`spawn_id`) REFERENCES `spawnpoint`(`id`)  ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE `group`
ADD COLUMN `perm_view_map_spawnpoint` tinyint(1) unsigned NOT NULL;
UPDATE `group`
SET perm_view_map_spawnpoint = 1
WHERE name = "root";
UPDATE `group`
SET perm_view_map_spawnpoint = 1
WHERE name = "default";
UPDATE `group`
SET perm_view_map_spawnpoint = 1
WHERE name = "no_user";