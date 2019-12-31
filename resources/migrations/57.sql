ALTER TABLE `account`
ADD COLUMN `creationTimestampMs` int(11) unsigned DEFAULT NULL;
ALTER TABLE `account`
ADD COLUMN `warn` tinyint(1) unsigned DEFAULT NULL;
ALTER TABLE `account`
ADD COLUMN `warnExpireMs` int(11) unsigned DEFAULT NULL;
ALTER TABLE `account`
ADD COLUMN `warnMessageAcknowledged` tinyint(1) unsigned DEFAULT NULL;
ALTER TABLE `account`
ADD COLUMN `suspendedMessageAcknowledged` tinyint(1) unsigned DEFAULT NULL;
ALTER TABLE `account`
ADD COLUMN `wasSuspended` tinyint(1) unsigned DEFAULT NULL;
ALTER TABLE `account`
ADD COLUMN `banned` tinyint(1) unsigned DEFAULT NULL;