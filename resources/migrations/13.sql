ALTER TABLE instance
MODIFY `type` enum('circle_pokemon','circle_raid','auto_quest') NOT NULL;
ALTER TABLE instance
MODIFY `data` LONGTEXT NOT NULL;

ALTER TABLE account
ADD COLUMN `level` tinyint(3) unsigned NOT NULL DEFAULT 0;
UPDATE account
SET level = 30 
WHERE is_high_level = true;
ALTER TABLE account
DROP COLUMN `is_high_level`;
ALTER TABLE account
ADD COLUMN `last_encounter_lat` double(18,14) DEFAULT NULL;
ALTER TABLE account
ADD COLUMN `last_encounter_lon` double(18,14) DEFAULT NULL;
ALTER TABLE account
ADD COLUMN `last_encounter_time` int(11) unsigned DEFAULT NULL;
ALTER TABLE pokestop
ADD COLUMN `quest_type` int(11) unsigned DEFAULT NULL;
ALTER TABLE pokestop
ADD COLUMN `quest_timestamp` int(11) unsigned DEFAULT NULL;
ALTER TABLE pokestop
ADD COLUMN `quest_target` smallint(6) unsigned DEFAULT NULL;
ALTER TABLE pokestop
ADD COLUMN `quest_conditions` JSON DEFAULT NULL;
ALTER TABLE pokestop
ADD COLUMN `quest_rewards` JSON DEFAULT NULL;
ALTER TABLE pokestop
ADD COLUMN `quest_pokemon_id` smallint(6) unsigned  GENERATED ALWAYS AS (JSON_EXTRACT(JSON_EXTRACT(quest_rewards, '$[*].info.pokemon_id'), '$[0]') );
ALTER TABLE pokestop
ADD INDEX `ix_quest_quest_pokemon_id` (quest_pokemon_id);
ALTER TABLE pokestop
ADD COLUMN `quest_reward_type` smallint(6) unsigned GENERATED ALWAYS AS (JSON_EXTRACT(JSON_EXTRACT(quest_rewards, '$[*].type'), '$[0]') );
ALTER TABLE pokestop
ADD INDEX `ix_quest_reward_type` (quest_reward_type);
ALTER TABLE pokestop
ADD INDEX `ix_quest_type` (quest_type);
