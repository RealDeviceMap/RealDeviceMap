ALTER TABLE pokestop
DROP INDEX `ix_quest_pokemon_id`,
DROP COLUMN `quest_pokemon_id`,
ADD COLUMN `quest_pokemon_id` smallint(6) unsigned  GENERATED ALWAYS AS (
    IF(
        JSON_EXTRACT(JSON_EXTRACT(quest_rewards, '$[*].type'), '$[0]') = 7,
        JSON_EXTRACT(JSON_EXTRACT(quest_rewards, '$[*].info.pokemon_id'), '$[0]'),
        NULL
    )
),
ADD INDEX `ix_quest_pokemon_id` (quest_pokemon_id);
