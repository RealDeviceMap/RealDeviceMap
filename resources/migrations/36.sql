ALTER TABLE `pokestop`
ADD COLUMN deleted tinyint(1) unsigned NOT NULL DEFAULT 0;
ALTER TABLE `pokestop`
ADD INDEX `ix_pokestop_deleted` (deleted);
ALTER TABLE `gym`
ADD COLUMN deleted tinyint(1) unsigned NOT NULL DEFAULT 0;
ALTER TABLE `gym`
ADD INDEX `ix_gym_deleted` (deleted);
