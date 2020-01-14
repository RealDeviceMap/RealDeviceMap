ALTER TABLE `account`
ADD COLUMN `creation_timestamp` int(11) unsigned DEFAULT NULL;
ALTER TABLE `account`
ADD COLUMN `warn` tinyint(1) unsigned DEFAULT NULL;
ALTER TABLE `account`
ADD COLUMN `warn_expire_timestamp` int(11) unsigned DEFAULT NULL;
ALTER TABLE `account`
ADD COLUMN `warn_message_acknowledged` tinyint(1) unsigned DEFAULT NULL;
ALTER TABLE `account`
ADD COLUMN `suspended_message_acknowledged` tinyint(1) unsigned DEFAULT NULL;
ALTER TABLE `account`
ADD COLUMN `was_suspended` tinyint(1) unsigned DEFAULT NULL;
ALTER TABLE `account`
ADD COLUMN `banned` tinyint(1) unsigned DEFAULT NULL;
