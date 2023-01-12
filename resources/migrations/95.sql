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

# add new column and migrate data
ALTER TABLE instance
    ADD COLUMN area mediumtext GENERATED ALWAYS AS (json_extract(data, "$.area")) STORED,
    ADD COLUMN area_new mediumtext;
UPDATE instance
SET area_new = area;
ALTER TABLE instance
    DROP COLUMN area,
    RENAME COLUMN area_new TO area,
    MODIFY data text not null;
UPDATE instance
SET data = JSON_REMOVE(data, "$.area");