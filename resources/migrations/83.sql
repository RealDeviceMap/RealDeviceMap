ALTER TABLE pokemon
    ADD seen_type enum('wild', 'encounter', 'nearby_stop', 'nearby_cell') AFTER display_pokemon_id;
