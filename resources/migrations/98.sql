ALTER TABLE account
    ADD COLUMN `disabled` tinyint(1) unsigned DEFAULT 0 AFTER `last_used_timestamp`,
    ADD COLUMN `last_disabled` int unsigned DEFAULT NULL AFTER `disabled`;

UPDATE account
    SET failed = NULL, failed_timestamp = NULL, disabled = 1, last_disabled = UNIX_TIMESTAMP()
    WHERE failed = 'unknown';
