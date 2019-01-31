ALTER TABLE pokemon
ADD COLUMN expire_timestamp_verified tinyint(1) unsigned NOT NULL;
ALTER TABLE spawnpoint
ADD COLUMN despawn_sec smallint(6) unsigned DEFAULT NULL;
