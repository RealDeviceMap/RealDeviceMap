ALTER TABLE account
    ADD COLUMN `disabled` tinyint(1) unsigned DEFAULT 0 AFTER `last_used_timestamp`,
    ADD COLUMN `last_disabled` int unsigned DEFAULT NULL;