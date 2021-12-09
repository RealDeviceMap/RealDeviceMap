CREATE TABLE IF NOT EXISTS `webhook` (
    `name` varchar(30) UNIQUE NOT NULL,
    `url` varchar(256) UNIQUE NOT NULL,
    `delay` double DEFAULT 5.0,
    `types` longtext,
    `data` longtext,
    `enabled` tinyint unsigned DEFAULT 1
    );

SET @urls = (SELECT `value` FROM `metadata` WHERE `key` = 'WEBHOOK_URLS');

INSERT IGNORE INTO `webhook` (
    `name`,
    `url`,
    `delay`,
    `types`,
    `data`,
    `enabled`
)
SELECT
    CONCAT('webhook_',
           wh.id
        ) AS `name`,
    `url` AS `url`,
    (
        SELECT
            `value`
        FROM
            `metadata`
        WHERE
                `key`= 'WEBHOOK_DELAY'
    ) AS `delay`,
    '["pokemon", "raid", "egg", "pokestop", "lure", "invasion", "quest", "gym", "weather", "account"]' AS `types`,
    '{}' AS `data`,
    1 AS `enabled`
FROM (
         select distinct n.num as id, json_unquote(
             json_extract(CONCAT('["', REPLACE((SELECT `value` FROM `metadata` WHERE `key` = 'WEBHOOK_URLS'),
                 ';', '", "'), '"]'), concat('$[', n.num, ']'))) url
         from metadata m
                inner join (select 0 num union all select 1 union all select 2) n
                on n.num < json_length(
                    CONCAT('["', REPLACE((SELECT `value` FROM `metadata` WHERE `key` = 'WEBHOOK_URLS'),
                        ';', '", "'), '"]'))
     ) as wh