ALTER TABLE pokemon
ADD COLUMN `pvp` text DEFAULT NULL AFTER `capture_3`,
DROP COLUMN pvp_rankings_great_league,
DROP COLUMN pvp_rankings_ultra_league;