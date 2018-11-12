ALTER TABLE pokemon
ADD COLUMN `cell_id` bigint unsigned DEFAULT NULL;
ALTER TABLE gym
ADD COLUMN `cell_id` bigint unsigned DEFAULT NULL;
ALTER TABLE pokestop
ADD COLUMN `cell_id` bigint unsigned DEFAULT NULL;
