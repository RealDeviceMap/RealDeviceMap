ALTER TABLE `group`
ADD COLUMN `perm_view_map_iv` tinyint(1) unsigned NOT NULL;
UPDATE `group`
SET `perm_view_map_iv` = `perm_view_map_pokemon`;
ALTER TABLE pokestop
ADD KEY `ix_quest_item_id` (`quest_item_id`);
ALTER TABLE pokemon
ADD COLUMN `iv` FLOAT(5,2) unsigned GENERATED ALWAYS AS ( (atk_iv + def_iv + sta_iv ) * 100 / 45 );
ALTER TABLE pokemon
ADD KEY `ix_iv` (`iv`);
