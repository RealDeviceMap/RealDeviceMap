ALTER TABLE pokemon MODIFY id varchar(25) NOT NULL;
UPDATE pokemon p1
INNER JOIN pokemon p2 ON p1.id = p2.id
SET p1.spawn_id = CONV(p1.spawn_id,16,10);
ALTER TABLE pokemon MODIFY spawn_id bigint(15) unsigned DEFAULT NULL;
ALTER TABLE pokemon ADD COLUMN `first_seen_timestamp` int(11) unsigned NOT NULL;
