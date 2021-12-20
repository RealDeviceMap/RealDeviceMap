ALTER TABLE pokestop
    ADD COLUMN `power_up_end_timestamp` int(11) unsigned DEFAULT NULL AFTER `ar_scan_eligible`,
    ADD COLUMN `power_up_points` int(6) unsigned DEFAULT NULL AFTER `ar_scan_eligible`,
    ADD COLUMN `power_up_level` smallint(4) unsigned DEFAULT NULL AFTER `ar_scan_eligible`,
    ADD COLUMN `partner_id` varchar(35) DEFAULT NULL AFTER `sponsor_id`;
ALTER TABLE gym
    ADD COLUMN `power_up_end_timestamp` int(11) unsigned DEFAULT NULL AFTER `ar_scan_eligible`,
    ADD COLUMN `power_up_points` int(6) unsigned DEFAULT NULL AFTER `ar_scan_eligible`,
    ADD COLUMN `power_up_level` smallint(4) unsigned DEFAULT NULL AFTER `ar_scan_eligible`,
    ADD COLUMN `partner_id` varchar(35) DEFAULT NULL AFTER `sponsor_id`;
ALTER TABLE gym
    MODIFY `total_cp` int unsigned null;

