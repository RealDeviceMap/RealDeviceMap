ALTER TABLE s2cell
ADD KEY `ix_coords` (`center_lat`,`center_lon`);
ALTER TABLE s2cell
ADD KEY `ix_updated` (`updated`);
