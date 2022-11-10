ALTER TABLE pokemon_history
    ADD COLUMN lat double(18, 14) not null AFTER location,
    ADD COLUMN lon double(18, 14) not null AFTER lat,
    ADD COLUMN pokestop_id varchar(35) null AFTER id,
    ADD COLUMN spawn_id bigint unsigned null AFTER pokestop_id,
    ADD COLUMN first_seen_timestamp int unsigned not null AFTER shiny;

DROP PROCEDURE IF EXISTS createStatsAndArchive;
CREATE PROCEDURE createStatsAndArchive()
begin
    drop temporary table if exists old&semi
    create temporary table old engine = memory
    as (select id from pokemon where expire_timestamp < UNIX_TIMESTAMP() and expire_timestamp_verified = 1 UNION ALL select id from pokemon where expire_timestamp < (UNIX_TIMESTAMP()-2400) and expire_timestamp_verified = 0)&semi

    insert into pokemon_history (id, pokestop_id, spawn_id, location, lat, lon, pokemon_id, cp, atk_iv, def_iv, sta_iv, form, level, weather,
                                 costume, cell_id, expire_timestamp, expire_timestamp_verified, display_pokemon_id,
                                 seen_type, shiny, first_seen_timestamp, seen_wild, seen_stop, seen_cell, seen_lure,
                                 first_encounter, stats_reset, last_encounter, lure_encounter)
    select pokemon.id, pokestop_id, spawn_id, POINT(lat,lon) as location, lat, lon, pokemon_id, cp, atk_iv, def_iv, sta_iv, form, level, weather,
           costume, cell_id, expire_timestamp, expire_timestamp_verified, display_pokemon_id,
           seen_type, shiny, first_seen_timestamp, seen_wild, seen_stop, seen_cell, seen_lure,
           first_encounter, stats_reset, last_encounter, lure_encounter
    from pokemon
             join old on old.id = pokemon.id
             left join pokemon_timing on pokemon.id = pokemon_timing.id
    on duplicate key update pokestop_id=pokemon.pokestop_id, spawn_id=pokemon.spawn_id, location=POINT(pokemon.lat,pokemon.lon), lat=pokemon.lat, lon=pokemon.lon,
                            pokemon_id=pokemon.pokemon_id, cp=pokemon.cp, atk_iv=pokemon.atk_iv, def_iv=pokemon.def_iv,
                            sta_iv=pokemon.sta_iv, form=pokemon.form, level=pokemon.level, weather=pokemon.weather, costume=pokemon.costume, cell_id=pokemon.cell_id,
                            expire_timestamp=pokemon.expire_timestamp, expire_timestamp_verified=pokemon.expire_timestamp_verified,
                            display_pokemon_id= pokemon.display_pokemon_id, seen_type= pokemon.seen_type, shiny=pokemon.shiny, first_seen_timestamp=pokemon.first_seen_timestamp, seen_wild=pokemon_timing.seen_wild,
                            seen_stop=pokemon_timing.seen_stop, seen_cell=pokemon_timing.seen_cell, seen_lure=pokemon_timing.seen_lure, first_encounter=pokemon_timing.first_encounter,
                            stats_reset=pokemon_timing.stats_reset, last_encounter=pokemon_timing.last_encounter, lure_encounter=pokemon_timing.lure_encounter&semi

    delete pokemon from pokemon
                            join old on pokemon.id = old.id&semi

    delete pokemon_timing from pokemon_timing
                                   join old on pokemon_timing.id = old.id&semi

    drop temporary table old&semi
end;
