ALTER TABLE gym CHANGE `availble_slots` `available_slots` smallint(6) unsigned DEFAULT NULL;
ALTER TABLE gym ADD COLUMN `availble_slots` smallint(6) unsigned GENERATED ALWAYS AS (`available_slots`) AFTER `available_slots`;
