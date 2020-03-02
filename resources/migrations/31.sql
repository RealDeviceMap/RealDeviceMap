CREATE TABLE IF NOT EXISTS `token` (
    `token` VARCHAR(50) NOT NULL PRIMARY KEY,
    `type` ENUM('confirm_email', 'reset_password') NOT NULL,
    `username` varchar(32) NOT NULL,
    `expire_timestamp` int(11) unsigned NOT NULL,
    INDEX `fk_tokem_username` (`username`),
    FOREIGN KEY (`username`) REFERENCES `user` (`username`) ON DELETE CASCADE ON UPDATE CASCADE,
    KEY ix_expire_timestamp (expire_timestamp)
);
