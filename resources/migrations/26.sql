CREATE TABLE IF NOT EXISTS `s2cell` (
`id` bigint unsigned NOT NULL,
`level` tinyint unsigned DEFAULT NULL,
`center_lat` double(18,14) NOT NULL DEFAULT 0,
`center_lon` double(18,14) NOT NULL DEFAULT 0,
`updated` int(11) unsigned NOT NULL,
PRIMARY KEY (`id`)
);

INSERT IGNORE INTO s2cell (id, level, updated)
SELECT cell_id, 15, MAX(updated) FROM pokemon WHERE cell_id IS NOT NULL AND cell_id != 0 GROUP BY cell_id;
INSERT IGNORE INTO s2cell (id, level, updated)
SELECT cell_id, 15, MAX(updated) FROM gym WHERE cell_id IS NOT NULL AND cell_id != 0 GROUP BY cell_id;
INSERT IGNORE INTO s2cell (id, level, updated)
SELECT cell_id, 15, MAX(updated) FROM pokestop WHERE cell_id IS NOT NULL AND cell_id != 0 GROUP BY cell_id;

ALTER TABLE pokemon
DROP KEY `ix_pokemon_cell_id`;
ALTER TABLE gym
DROP KEY `ix_gym_cell_id`;
ALTER TABLE pokestop
DROP KEY `ix_pokestop_cell_id`;

ALTER TABLE `pokemon`
ADD CONSTRAINT `fk_pokemon_cell_id` FOREIGN KEY (`cell_id`) REFERENCES `s2cell`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `gym`
ADD CONSTRAINT `fk_gym_cell_id` FOREIGN KEY (`cell_id`) REFERENCES `s2cell`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `pokestop`
ADD CONSTRAINT `fk_pokestop_cell_id` FOREIGN KEY (`cell_id`) REFERENCES `s2cell`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `group`
ADD COLUMN `perm_view_map_cell` tinyint(1) unsigned NOT NULL;
UPDATE `group`
SET `perm_view_map_cell` = `perm_view_map_pokemon`;
