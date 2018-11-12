ALTER TABLE pokemon
ADD KEY `ix_pokemon_cell_id` (`cell_id`);
ALTER TABLE gym
ADD KEY `ix_gym_cell_id` (`cell_id`);
ALTER TABLE pokestop
ADD KEY `ix_pokestop_cell_id` (`cell_id`);
