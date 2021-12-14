ALTER TABLE pokestop
    ADD COLUMN `location_points` smallint(6) unsigned DEFAULT NULL AFTER `ar_scan_eligible`,
    ADD COLUMN `power_up_end_timestamp` int(11) unsigned DEFAULT NULL AFTER `ar_scan_eligible`,
    ADD COLUMN `partner_id` varchar(35) DEFAULT NULL AFTER `sponsor_id`;
ALTER TABLE gym
    ADD COLUMN `location_points` smallint(6) unsigned DEFAULT NULL AFTER `ar_scan_eligible`,
    ADD COLUMN `power_up_end_timestamp` int(11) unsigned DEFAULT NULL AFTER `ar_scan_eligible`,
    ADD COLUMN `partner_id` varchar(35) DEFAULT NULL AFTER `sponsor_id`;

