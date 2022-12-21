ALTER TABLE pokemon
    CHANGE `size` `height` double(18, 14) null,
    ADD `size` tinyint unsigned after height;

