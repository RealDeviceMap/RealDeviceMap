ALTER TABLE instance
MODIFY `type` enum('circle_pokemon','circle_raid','auto_quest') NOT NULL;
ALTER TABLE instance
MODIFY `data` longtext NOT NULL;