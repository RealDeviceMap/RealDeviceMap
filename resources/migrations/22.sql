ALTER TABLE pokemon
DROP KEY `ix_expire_timestamp`;
ALTER TABLE pokemon
ADD KEY `ix_changed` (`changed`);
ALTER TABLE pokemon
ADD KEY `ix_level` (`level`);

ALTER TABLE gym
ADD KEY `ix_raid_pokemon_id` (`raid_pokemon_id`);

ALTER TABLE pokestop
DROP KEY ix_quest_quest_pokemon_id;
ALTER TABLE pokestop
DROP KEY ix_quest_reward_type;
ALTER TABLE pokestop
DROP KEY ix_quest_item_id;

ALTER TABLE pokestop
ADD KEY `ix_quest_pokemon_id` (`quest_pokemon_id`);
ALTER TABLE pokestop
ADD KEY `ix_quest_reward_type` (`quest_reward_type`);
ALTER TABLE pokestop
ADD KEY `ix_quest_item_id` (`quest_item_id`);
