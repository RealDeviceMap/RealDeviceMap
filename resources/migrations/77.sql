alter table pokestop
    modify column `quest_pokemon_id` smallint unsigned GENERATED ALWAYS AS (JSON_EXTRACT(JSON_EXTRACT(quest_rewards, '$[*].info.pokemon_id'), '$[0]'));

alter table pokestop
    add column `quest_reward_amount` smallint unsigned GENERATED ALWAYS AS (JSON_EXTRACT(JSON_EXTRACT(quest_rewards, '$[*].info.amount'), '$[0]')) AFTER `quest_item_id`,
    add column `alternative_quest_reward_amount` smallint unsigned GENERATED ALWAYS AS (JSON_EXTRACT(JSON_EXTRACT(alternative_quest_rewards, '$[*].info.amount'), '$[0]')) AFTER `alternative_quest_item_id`;

