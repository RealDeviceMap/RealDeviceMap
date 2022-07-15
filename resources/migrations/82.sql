CREATE TABLE IF NOT EXISTS `gymdefender` (
    `id` bigint unsigned NOT NULL DEFAULT '0',
    `fortID` varchar(100) DEFAULT NULL,
    `pokemonid` smallint unsigned NOT NULL,
    `cp` smallint unsigned DEFAULT NULL,
    `atk_iv` tinyint unsigned DEFAULT NULL,
    `def_iv` tinyint unsigned DEFAULT NULL,
    `sta_iv` tinyint unsigned DEFAULT NULL,
    `updated` int unsigned NOT NULL,
    PRIMARY KEY (`id`)