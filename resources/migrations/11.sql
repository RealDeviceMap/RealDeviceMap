ALTER TABLE gym 
MODIFY `raid_pokemon_form` tinyint(3) unsigned DEFAULT NULL;
ALTER TABLE gym 
ADD COLUMN `raid_is_exclusive` tinyint(1) unsigned DEFAULT NULL;