CREATE TABLE IF NOT EXISTS `account` (
  `username` varchar(32) NOT NULL,
  `password` varchar(32) NOT NULL,
  `is_high_level` tinyint(1) unsigned NOT NULL,
  `first_warning_timestamp` int(11) unsigned DEFAULT NULL,
  `failed_timestamp` int(11) unsigned  DEFAULT NULL,
  `failed` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`username`)
);
ALTER TABLE `device`
ADD COLUMN `account_username` varchar(32) DEFAULT NULL;
ALTER TABLE `device`
ADD  CONSTRAINT `fk_account_username` FOREIGN KEY (`account_username`) REFERENCES `account` (`username`) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE `device`
ADD  CONSTRAINT `uk_iaccount_username` UNIQUE KEY (`account_username`);
