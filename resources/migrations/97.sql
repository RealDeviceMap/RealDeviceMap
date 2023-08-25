# drop foreign key constraint
alter table assignment
    drop foreign key assignment_fk_instance_name,
    drop foreign key assignment_fk_source_instance_name;
alter table device
    drop foreign key fk_instance_name;

ALTER TABLE `device`
	MODIFY COLUMN `instance_name` VARCHAR(255) NULL;
SET FOREIGN_KEY_CHECKS=1;

# add dropped foreign key constraint
ALTER TABLE assignment
    ADD CONSTRAINT `assignment_fk_instance_name` FOREIGN KEY (`instance_name`) REFERENCES `instance` (`name`) ON DELETE CASCADE ON UPDATE CASCADE,
    ADD CONSTRAINT `assignment_fk_source_instance_name` FOREIGN KEY (`source_instance_name`) REFERENCES `instance` (`name`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE device
    ADD CONSTRAINT `fk_instance_name` FOREIGN KEY (`instance_name`) REFERENCES `instance` (`name`) ON DELETE SET NULL ON UPDATE CASCADE;
