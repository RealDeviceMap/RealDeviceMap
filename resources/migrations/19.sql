ALTER TABLE pokemon
ADD COLUMN `changed` int(11) NOT NULL DEFAULT `first_seen_timestamp`;
