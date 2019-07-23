ALTER TABLE `pokestop`
ADD COLUMN `pokestop_display` smallint(5) DEFAULT 0;

ALTER TABLE `pokestop`
ADD COLUMN `incident_expire_timestamp` int(11) unsigned DEFAULT NULL;
