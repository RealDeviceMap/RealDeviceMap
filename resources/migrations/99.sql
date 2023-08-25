# drop constraints again
alter table assignment
    drop foreign key assignment_fk_source_device_group_name;
alter table assignment_group_assignment
    drop foreign key assignment_group_assignment_fk_assignment_group_name;
alter table device_group_device
    drop foreign key device_group_device_fk_device_group_name;

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

# add dropped constraints again
alter table device_group_device
    add constraint device_group_device_fk_device_group_name
        foreign key (device_group_name) references device_group (name)
            on update cascade on delete cascade;
alter table assignment_group_assignment
    add constraint assignment_group_assignment_fk_assignment_group_name
        foreign key (assignment_group_name) references assignment_group (name)
            on update cascade on delete cascade;
alter table assignment
    add constraint assignment_fk_source_device_group_name
        foreign key (device_group_name) references device_group (name)
            on update cascade on delete cascade;

