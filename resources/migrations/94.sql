SET FOREIGN_KEY_CHECKS=0;
ALTER TABLE `instance`
	CHANGE COLUMN `name` `name` VARCHAR(255) NOT NULL FIRST;
ALTER TABLE `assignment`
	CHANGE COLUMN `instance_name` `instance_name` VARCHAR(255) NOT NULL AFTER `device_uuid`,
	CHANGE COLUMN `source_instance_name` `source_instance_name` VARCHAR(255) NULL DEFAULT NULL AFTER `device_group_name`;
SET FOREIGN_KEY_CHECKS=1;
