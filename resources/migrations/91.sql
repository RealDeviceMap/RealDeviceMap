ALTER TABLE `pokestop`
    DROP COLUMN `quest_reward_type`,
    DROP COLUMN `quest_item_id` ,
    DROP COLUMN `quest_reward_amount`,
    DROP COLUMN `quest_pokemon_id`,
    DROP COLUMN `alternative_quest_pokemon_id`,
    DROP COLUMN `alternative_quest_reward_type`,
    DROP COLUMN `alternative_quest_item_id`,
    DROP COLUMN `alternative_quest_reward_amount`;

ALTER TABLE `pokestop`
    ADD COLUMN `quest_reward_type` smallint unsigned GENERATED ALWAYS AS (JSON_EXTRACT(JSON_EXTRACT(`quest_rewards`, '$[*].type'), '$[0]')) STORED AFTER `quest_rewards`,
    ADD COLUMN `quest_reward_amount` smallint unsigned GENERATED ALWAYS AS (JSON_EXTRACT(JSON_EXTRACT(`quest_rewards`, '$[*].info.amount'), '$[0]')) STORED AFTER `quest_reward_type`,
    ADD COLUMN `quest_item_id` smallint unsigned GENERATED ALWAYS AS (JSON_EXTRACT(JSON_EXTRACT(`quest_rewards`, '$[*].info.item_id'), '$[0]')) STORED AFTER `quest_reward_amount`,
    ADD COLUMN `quest_pokemon_id` smallint unsigned GENERATED ALWAYS AS (JSON_EXTRACT(JSON_EXTRACT(`quest_rewards`, '$[*].info.pokemon_id'), '$[0]')) STORED AFTER `quest_item_id`,
    ADD COLUMN `alternative_quest_reward_type` smallint unsigned GENERATED ALWAYS AS (JSON_EXTRACT(JSON_EXTRACT(`alternative_quest_rewards`, '$[*].type'), '$[0]')) STORED AFTER `alternative_quest_rewards`,
    ADD COLUMN `alternative_quest_reward_amount` smallint unsigned GENERATED ALWAYS AS (JSON_EXTRACT(JSON_EXTRACT(`alternative_quest_rewards`, '$[*].info.amount'), '$[0]')) STORED AFTER `alternative_quest_reward_type`,
    ADD COLUMN `alternative_quest_item_id` smallint unsigned GENERATED ALWAYS AS (JSON_EXTRACT(JSON_EXTRACT(`alternative_quest_rewards`, '$[*].info.item_id'), '$[0]')) STORED AFTER `alternative_quest_reward_amount`,
    ADD COLUMN `alternative_quest_pokemon_id` smallint unsigned GENERATED ALWAYS AS (JSON_EXTRACT(JSON_EXTRACT(`alternative_quest_rewards`, '$[*].info.pokemon_id'), '$[0]')) STORED AFTER `alternative_quest_item_id`;

ALTER TABLE `pokestop`
    ADD INDEX `ix_quest_reward_type` (quest_reward_type),
    ADD INDEX `ix_quest_alternative_quest_pokemon_id` (quest_pokemon_id),
    ADD INDEX `ix_quest_item_id` (quest_item_id),
    ADD INDEX `ix_alternative_quest_reward_type` (alternative_quest_reward_type),
    ADD INDEX `ix_alternative_quest_alternative_quest_pokemon_id` (alternative_quest_pokemon_id),
    ADD INDEX `ix_alternative_quest_item_id` (alternative_quest_item_id);
