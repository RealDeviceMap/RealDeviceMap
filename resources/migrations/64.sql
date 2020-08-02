ALTER TABLE assignment
DROP FOREIGN KEY `assignment_fk_device_uuid`,
ADD COLUMN id INT UNSIGNED AUTO_INCREMENT NOT NULL,
DROP PRIMARY KEY,
ADD PRIMARY KEY (id),
MODIFY COLUMN device_uuid VARCHAR(40) NULL;

ALTER TABLE assignment
ADD CONSTRAINT `assignment_fk_device_uuid` FOREIGN KEY (`device_uuid`) REFERENCES `device`(`uuid`) ON DELETE CASCADE ON UPDATE CASCADE,
ADD COLUMN device_group_name VARCHAR(30) NULL,
ADD CONSTRAINT `assignment_fk_source_device_group_name` FOREIGN KEY (`device_group_name`) REFERENCES `device_group`(`name`) ON DELETE CASCADE ON UPDATE CASCADE,
ADD COLUMN source_instance_name varchar(30) DEFAULT NULL,
ADD CONSTRAINT `assignment_fk_source_instance_name` FOREIGN KEY (`source_instance_name`) REFERENCES `instance`(`name`) ON DELETE CASCADE ON UPDATE CASCADE,
ADD COLUMN date DATE DEFAULT NULL,
ADD UNIQUE KEY assignment_unique (`device_uuid`,`device_group_name`,`instance_name`,`time`,`date`);

ALTER TABLE device
DROP COLUMN device_group;

ALTER TABLE device_group
DROP COLUMN instance_name;

CREATE TABLE device_group_device (
    device_group_name VARCHAR(30) NOT NULL,
    device_uuid VARCHAR(40) NOT NULL,
    PRIMARY KEY (device_group_name, device_uuid),
    CONSTRAINT `device_group_device_fk_device_group_name` FOREIGN KEY (`device_group_name`) REFERENCES `device_group`(`name`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `device_group_device_fk_device_uuid` FOREIGN KEY (`device_uuid`) REFERENCES `device`(`uuid`) ON DELETE CASCADE ON UPDATE CASCADE
)
