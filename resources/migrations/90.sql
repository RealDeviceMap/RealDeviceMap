CREATE TABLE `pokemon_history` (
   `id` varchar(25) NOT NULL,
   `location` point NOT NULL,
   `expire_timestamp` int unsigned DEFAULT NULL,
   `pokemon_id` smallint unsigned NOT NULL,
   `cp` smallint unsigned DEFAULT NULL,
   `atk_iv` tinyint unsigned DEFAULT NULL,
   `def_iv` tinyint unsigned DEFAULT NULL,
   `sta_iv` tinyint unsigned DEFAULT NULL,
   `form` smallint unsigned DEFAULT NULL,
   `level` tinyint unsigned DEFAULT NULL,
   `weather` tinyint unsigned DEFAULT NULL,
   `costume` tinyint unsigned DEFAULT NULL,
   `iv` float(5,2) unsigned GENERATED ALWAYS AS (((((`atk_iv` + `def_iv`) + `sta_iv`) * 100) / 45)) VIRTUAL,
   `cell_id` bigint unsigned DEFAULT NULL,
   `expire_timestamp_verified` tinyint unsigned NOT NULL,
   `display_pokemon_id` smallint unsigned DEFAULT NULL,
   `seen_type` enum('wild','encounter','nearby_stop','nearby_cell', 'lure_wild', 'lure_encounter') DEFAULT NULL,
   `shiny` tinyint(1) DEFAULT '0',
   `seen_wild` int unsigned DEFAULT NULL,
   `seen_stop` int unsigned DEFAULT NULL,
   `seen_cell` int unsigned DEFAULT NULL,
   `seen_lure` int unsigned DEFAULT NULL,
   `first_encounter` int unsigned DEFAULT NULL,
   `stats_reset` int unsigned DEFAULT NULL,
   `last_encounter` int unsigned DEFAULT NULL,
   `lure_encounter` int unsigned DEFAULT NULL,
   PRIMARY KEY (`id`),
   KEY `expire_timestamp` (`expire_timestamp`)
);

ALTER TABLE `pokemon_history` ADD SPATIAL INDEX `location` (`location`);
ALTER TABLE `pokemon_history` ADD INDEX `first_encounter` (`first_encounter`);
ALTER TABLE `pokemon_history` ADD INDEX `seen_wild` (`seen_wild`);

CREATE TABLE `pokemon_timing` (
  `id` varchar(25) NOT NULL,
  `seen_wild` int unsigned DEFAULT NULL,
  `seen_stop` int unsigned DEFAULT NULL,
  `seen_cell` int unsigned DEFAULT NULL,
  `seen_lure` int unsigned DEFAULT NULL,
  `first_encounter` int unsigned DEFAULT NULL,
  `stats_reset` int unsigned DEFAULT NULL,
  `last_encounter` int unsigned DEFAULT NULL,
  `lure_encounter` int unsigned DEFAULT NULL,
  PRIMARY KEY (`id`)
);

ALTER TABLE `pokestop`
    ADD COLUMN description text AFTER `name`;

ALTER TABLE `gym`
    ADD COLUMN description text AFTER `name`;


create procedure createStatsAndArchive()
begin
    drop temporary table if exists old&semi
    create temporary table old engine = memory
    as (select id from pokemon where expire_timestamp < UNIX_TIMESTAMP() and expire_timestamp_verified = 1 UNION ALL select id from pokemon where expire_timestamp < (UNIX_TIMESTAMP()-2400) and expire_timestamp_verified = 0)&semi

    insert into pokemon_history (id, location, pokemon_id, cp, atk_iv, def_iv, sta_iv, form, level, weather,
                                 costume, cell_id, expire_timestamp, expire_timestamp_verified, display_pokemon_id,
                                 seen_type, shiny, seen_wild, seen_stop, seen_cell, seen_lure,
                                 first_encounter, stats_reset, last_encounter, lure_encounter)
    select pokemon.id, POINT(lat,lon) as location, pokemon_id, cp, atk_iv, def_iv, sta_iv, form, level, weather,
           costume, cell_id, expire_timestamp, expire_timestamp_verified, display_pokemon_id,
           seen_type, shiny, seen_wild, seen_stop, seen_cell, seen_lure,
           first_encounter, stats_reset, last_encounter, lure_encounter
    from pokemon
             join old on old.id = pokemon.id
             left join pokemon_timing on pokemon.id = pokemon_timing.id
    on duplicate key update location=POINT(pokemon.lat,pokemon.lon), pokemon_id=pokemon.pokemon_id, cp=pokemon.cp, atk_iv=pokemon.atk_iv, def_iv=pokemon.def_iv,
                            sta_iv=pokemon.sta_iv, form=pokemon.form, level=pokemon.level, weather=pokemon.weather, costume=pokemon.costume, cell_id=pokemon.cell_id,
                            expire_timestamp=pokemon.expire_timestamp, expire_timestamp_verified=pokemon.expire_timestamp_verified,
                            display_pokemon_id= pokemon.display_pokemon_id, seen_type= pokemon.seen_type, shiny=pokemon.shiny, seen_wild=pokemon_timing.seen_wild,
                            seen_stop=pokemon_timing.seen_stop, seen_cell=pokemon_timing.seen_cell, seen_lure=pokemon_timing.seen_lure, first_encounter=pokemon_timing.first_encounter,
                            stats_reset=pokemon_timing.stats_reset, last_encounter=pokemon_timing.last_encounter, lure_encounter=pokemon_timing.lure_encounter&semi

    delete pokemon from pokemon
                            join old on pokemon.id = old.id&semi

    delete pokemon_timing from pokemon_timing
                                   join old on pokemon_timing.id = old.id&semi

    drop temporary table old&semi
end;