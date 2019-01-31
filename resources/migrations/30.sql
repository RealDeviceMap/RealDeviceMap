ALTER TABLE `group`
DROP COLUMN `perm_admin_user`;
ALTER TABLE `group`
CHANGE `perm_admin_setting` `perm_admin` tinyint(1) unsigned NOT NULL;
