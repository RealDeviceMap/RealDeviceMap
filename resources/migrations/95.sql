# drop foreign key constraints to modify instance schema
alter table assignment
    drop foreign key assignment_fk_instance_name,
    drop foreign key assignment_fk_source_instance_name;
alter table device
    drop foreign key fk_instance_name;

# add id as primary key, name only as unique key
alter table instance
    drop primary key;
ALTER TABLE instance
    ADD COLUMN `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY FIRST,
    ADD UNIQUE (name);

# add dropped foreign key constraint again
ALTER TABLE assignment
    ADD CONSTRAINT `assignment_fk_instance_name` FOREIGN KEY (`instance_name`) REFERENCES `instance` (`name`) ON DELETE CASCADE ON UPDATE CASCADE,
    ADD CONSTRAINT `assignment_fk_source_instance_name` FOREIGN KEY (`source_instance_name`) REFERENCES `instance` (`name`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE device
    ADD CONSTRAINT `fk_instance_name` FOREIGN KEY (`instance_name`) REFERENCES `instance` (`name`) ON DELETE SET NULL ON UPDATE CASCADE;
