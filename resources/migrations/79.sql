ALTER TABLE
  spawnpoint
ADD
  `last_seen` INT(11) UNSIGNED NOT NULL DEFAULT '0'
AFTER
  `updated`;
