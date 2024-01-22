alter table pokemon
    modify seen_type enum ('wild', 'encounter', 'nearby_stop', 'nearby_cell', 'lure_wild', 'lure_encounter') null;

