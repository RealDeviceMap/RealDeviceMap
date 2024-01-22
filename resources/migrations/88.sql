ALTER TABLE pokemon
    ADD COLUMN `is_ditto` TINYINT(1) UNSIGNED NOT NULL DEFAULT FALSE after `display_pokemon_id`;
