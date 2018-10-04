ALTER TABLE gym
ADD COLUMN `raid_pokemon_move_1` smallint(6) unsigned DEFAULT NULL;
ALTER TABLE gym
ADD COLUMN `raid_pokemon_move_2` smallint(6) unsigned DEFAULT NULL;
ALTER TABLE gym
ADD COLUMN `raid_pokemon_form` smallint(3) unsigned DEFAULT NULL;
ALTER TABLE gym
ADD COLUMN `raid_pokemon_cp` smallint(6) unsigned DEFAULT NULL;
ALTER TABLE pokemon MODIFY `move_1` smallint(6) unsigned DEFAULT NULL;
ALTER TABLE pokemon MODIFY `move_2` smallint(6) unsigned DEFAULT NULL;
