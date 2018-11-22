ALTER TABLE pokemon
ADD KEY ix_expire_timestamp (expire_timestamp);
ALTER TABLE spawnpoint
ADD KEY `ix_coords` (`lat`,`lon`);
ALTER TABLE spawnpoint
ADD KEY `ix_updated` (`updated`);
