ALTER TABLE pokemon
ADD COLUMN `changed` int(11) unsigned NOT NULL DEFAULT 0;
UPDATE pokemon
SET changed = first_seen_timestamp;
