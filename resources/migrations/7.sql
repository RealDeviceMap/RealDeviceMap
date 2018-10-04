ALTER TABLE gym
ADD COLUMN `ex_raid_eligible` tinyint(1) unsigned DEFAULT NULL;
ALTER TABLE gym
ADD COLUMN `in_battle` tinyint(1) unsigned DEFAULT NULL;