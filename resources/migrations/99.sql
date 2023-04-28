SET FOREIGN_KEY_CHECKS=0;
ALTER TABLE `assignment`
	MODIFY COLUMN `device_group_name` VARCHAR(255) NULL DEFAULT NULL AFTER `id`;
ALTER TABLE `assignment_group`
	MODIFY COLUMN `name` VARCHAR(255);
ALTER TABLE `assignment_group_assignment`
	MODIFY COLUMN `assignment_group_name` VARCHAR(255);
ALTER TABLE `device_group`
	MODIFY COLUMN `name` VARCHAR(255);
ALTER TABLE `device_group_device`
	MODIFY COLUMN `device_group_name` VARCHAR(255);
SET FOREIGN_KEY_CHECKS=1;