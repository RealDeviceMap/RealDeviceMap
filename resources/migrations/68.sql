ALTER TABLE instance
MODIFY `type` enum('circle_pokemon','circle_smart_pokemon','circle_raid','circle_smart_raid','auto_quest','pokemon_iv','leveling') NOT NULL;

CREATE TABLE IF NOT EXISTS `assignment_group` (
  `name` varchar(30) UNIQUE NOT NULL,
  PRIMARY KEY (`name`)
);

CREATE TABLE IF NOT EXISTS `assignment_group_assignment` (
    `assignment_group_name` VARCHAR(30) NOT NULL,
    `assignment_id` int unsigned NOT NULL,
    PRIMARY KEY (`assignment_group_name`, `assignment_id`),
    CONSTRAINT `assignment_group_assignment_fk_assignment_group_name` FOREIGN KEY (`assignment_group_name`) REFERENCES `assignment_group`(`name`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `assignment_group_assignment_fk_assignment_id` FOREIGN KEY (`assignment_id`) REFERENCES `assignment`(`id`) ON DELETE CASCADE ON UPDATE CASCADE
);
