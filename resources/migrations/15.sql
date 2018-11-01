ALTER TABLE pokemon
DROP FOREIGN KEY `fk_pokestop_id`;
ALTER TABLE pokemon
ADD CONSTRAINT `fk_pokestop_id` FOREIGN KEY (`pokestop_id`) REFERENCES `pokestop` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE account
ADD COLUMN `spins` smallint(6) unsigned NOT NULL DEFAULT 0;
ALTER TABLE pokestop
ADD COLUMN `quest_item_id` smallint(6) unsigned  GENERATED ALWAYS AS (JSON_EXTRACT(JSON_EXTRACT(quest_rewards, '$[*].info.item_id'), '$[0]') );