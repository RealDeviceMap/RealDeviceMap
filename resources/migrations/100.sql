ALTER TABLE gym
ADD COLUMN `raid_pokemon_alignment` tinyint(3) unsigned DEFAULT NULL;

ALTER TABLE account
    DROP COLUMN `disabled`;
