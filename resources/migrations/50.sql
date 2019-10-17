CREATE TABLE IF NOT EXISTS `weather` (
  `id` bigint(30) NOT NULL,
  `level` tinyint(2) unsigned DEFAULT NULL,
  `latitude` double(18,14) NOT NULL DEFAULT '0.00000000000000',
  `longitude` double(18,14) NOT NULL DEFAULT '0.00000000000000',
  `gameplay_condition` tinyint(3) unsigned DEFAULT NULL,
  `wind_direction` mediumint(8) DEFAULT NULL,
  `cloud_level` tinyint(3) unsigned DEFAULT NULL,
  `rain_level` tinyint(3) unsigned DEFAULT NULL,
  `wind_level` tinyint(3) unsigned DEFAULT NULL,
  `snow_level` tinyint(3) unsigned DEFAULT NULL,
  `fog_level` tinyint(3) unsigned DEFAULT NULL,
  `special_effect_level` tinyint(3) unsigned DEFAULT NULL,
  `severity` tinyint(3) unsigned DEFAULT NULL,
  `warn_weather` tinyint(3) unsigned DEFAULT NULL,
  `updated` int(11) unsigned NOT NULL,
  PRIMARY KEY (`id`)
);
ALTER TABLE `group`
ADD COLUMN `perm_view_map_weather` tinyint(1) unsigned NOT NULL;
UPDATE `group`
SET `perm_view_map_weather` = `perm_view_map`;
