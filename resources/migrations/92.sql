ALTER TABLE `instance`
	CHANGE COLUMN `type` `type` ENUM('circle_pokemon','circle_smart_pokemon','circle_raid','circle_smart_raid','auto_quest','pokemon_iv','leveling','jumpy_pokemon','findy_pokemon') NOT NULL COLLATE 'utf8mb4_general_ci' AFTER `name`;
