//
//  Stats.swift
//  RealDeviceMap
//
//  Created by versx on 12/22/19.
//

import Foundation
import PerfectLib
import PerfectMySQL

class Stats: JSONConvertibleObject {
    
    override func getJSONValues() -> [String : Any] {
        //TODO: Faster way to get stats
        let pokemonStats = try? Stats.getPokemonStats()
        let pokemonIVStats = try? Stats.getPokemonIVStats()
        let raidStats = try? Stats.getRaidStats()
        let eggStats = try? Stats.getRaidEggStats()
        let gymStats = try? Stats.getGymStats()
        let pokestopStats = try? Stats.getPokestopStats()
        let questItemStats = try? Stats.getQuestItemStats()
        let questPokemonStats = try? Stats.getQuestPokemonStats()
        let invasionStats = try? Stats.getInvasionStats()
        let spawnpointStats = try? Stats.getSpawnpointStats()
        return [
            "pokemon_total": (pokemonStats?[0] ?? 0),
            "pokemon_active": (pokemonStats?[1] ?? 0),
            "pokemon_iv_total": (pokemonStats?[2] ?? 0),
            "pokemon_iv_active": (pokemonStats?[3] ?? 0),
            "pokestops_total": (pokestopStats?[0] ?? 0),
            "pokestops_lures_normal": (pokestopStats?[1] ?? 0),
            "pokestops_lures_glacial": (pokestopStats?[2] ?? 0),
            "pokestops_lures_mossy": (pokestopStats?[3] ?? 0),
            "pokestops_lures_magnetic": (pokestopStats?[4] ?? 0),
            "pokestops_invasions": (pokestopStats?[5] ?? 0),
            "pokestops_quests": (pokestopStats?[6] ?? 0),
            "gyms_total": (gymStats?[0] ?? 0),
            "gyms_neutral": (gymStats?[1] ?? 0),
            "gyms_mystic": (gymStats?[2] ?? 0),
            "gyms_valor": (gymStats?[3] ?? 0),
            "gyms_instinct": (gymStats?[4] ?? 0),
            "gyms_raids": (gymStats?[5] ?? 0),
            "pokemon_stats": pokemonIVStats as Any,
            "raid_stats": raidStats as Any,
            "egg_stats": eggStats as Any,
            "quest_item_stats": questItemStats as Any,
            "quest_pokemon_stats": questPokemonStats as Any,
            "invasion_stats": invasionStats as Any,
            "spawnpoints_total": (spawnpointStats?[0] ?? 0),
            "spawnpoints_found": (spawnpointStats?[1] ?? 0),
            "spawnpoints_missing": (spawnpointStats?[2] ?? 0),
            "spawnpoints_percent": 0,
            "spawnpoints_min30": (spawnpointStats?[3] ?? 0),
            "spawnpoints_min60": (spawnpointStats?[4] ?? 0)
        ]
    }
    
    public static func getPokemonIVStats(mysql: MySQL?=nil) throws -> [Any] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT iv.date, iv.pokemon_id, shiny.count as shiny, iv.count
        FROM pokemon_iv_stats iv
          LEFT JOIN pokemon_shiny_stats shiny
          ON iv.date = shiny.date AND iv.pokemon_id = shiny.pokemon_id
        WHERE
          iv.date = FROM_UNIXTIME(UNIX_TIMESTAMP(), "%Y-%m-%d") AND
          shiny.date = FROM_UNIXTIME(UNIX_TIMESTAMP(), "%Y-%m-%d")
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Any]()
        while let result = results.next() {
            
            let pokemonId = result[1] as! UInt16
            let shiny = (result[2] as! Int32)
            let count = (result[3] as! Int32)
            let name = Localizer.global.get(value: "poke_\(pokemonId)")
            
            stats.append(["id": pokemonId, "name": name, "shiny": shiny.withCommas(), "count": count.withCommas()])
            
        }
        return stats
        
    }
    
    public static func getPokemonStats(mysql: MySQL?=nil) throws -> [Int64] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT
          COUNT(id) AS total,
          SUM(expire_timestamp >= UNIX_TIMESTAMP()) AS active,
          SUM(iv IS NOT NULL) AS iv_total,
          SUM(iv IS NOT NULL && expire_timestamp >= UNIX_TIMESTAMP()) AS iv_active
        FROM pokemon
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var stats = [Int64]()
        while let result = results.next() {
            
            let total = result[0] as! Int64
            let active = Int64(result[1] as! String) ?? 0
            let ivTotal = Int64(result[2] as! String) ?? 0
            let ivActive = Int64(result[3] as! String) ?? 0
            
            stats.append(total)
            stats.append(active)
            stats.append(ivTotal)
            stats.append(ivActive)
            
        }
        return stats
        
    }
    
    public static func getRaidStats(mysql: MySQL?=nil) throws -> [Any] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT raid_pokemon_id, COUNT(*) AS total
        FROM gym
        WHERE raid_pokemon_id > 0 AND raid_end_timestamp > UNIX_TIMESTAMP()
        GROUP BY raid_pokemon_id
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Any]()
        while let result = results.next() {
            
            let pokemonId = result[0] as! UInt16
            let count = result[1] as! Int64
            let name = Localizer.global.get(value: "poke_\(pokemonId)")
            
            stats.append(["id": pokemonId, "name": name, "count": count.withCommas()])
            
        }
        return stats
        
    }
    
    public static func getRaidEggStats(mysql: MySQL?=nil) throws -> [Any] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT raid_level, COUNT(*) AS total
        FROM gym
        WHERE raid_level > 0 AND raid_end_timestamp > UNIX_TIMESTAMP()
        GROUP BY raid_level
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Any]()
        while let result = results.next() {
            
            let level = result[0] as! UInt8
            let count = result[1] as! Int64
            
            stats.append(["level": level, "count": count.withCommas()])
            
        }
        return stats
        
    }
    
    public static func getPokestopStats(mysql: MySQL?=nil) throws -> [Int64] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT
          COUNT(id) AS total,
          SUM(lure_expire_timestamp > UNIX_TIMESTAMP() AND lure_id=501) AS normal_lures,
          SUM(lure_expire_timestamp > UNIX_TIMESTAMP() AND lure_id=502) AS glacial_lures,
          SUM(lure_expire_timestamp > UNIX_TIMESTAMP() AND lure_id=503) AS mossy_lures,
          SUM(lure_expire_timestamp > UNIX_TIMESTAMP() AND lure_id=504) AS magnetic_lures,
          SUM(incident_expire_timestamp > UNIX_TIMESTAMP()) invasions,
          SUM(quest_reward_type IS NOT NULL) quests
        FROM pokestop
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Int64]()
        while let result = results.next() {
            
            let total = result[0] as! Int64
            let normalLures = Int64(result[1] as! String)!
            let glacialLures = Int64(result[2] as! String)!
            let mossyLures = Int64(result[3] as! String)!
            let magneticLures = Int64(result[4] as! String)!
            let invasions = Int64(result[5] as! String)!
            let quests = Int64(result[6] as! String)!
            
            stats.append(total)
            stats.append(normalLures)
            stats.append(glacialLures)
            stats.append(mossyLures)
            stats.append(magneticLures)
            stats.append(invasions)
            stats.append(quests)
            
        }
        return stats
        
    }
    
    public static func getQuestItemStats(mysql: MySQL?=nil) throws -> [Any] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT quest_item_id, COUNT(*) AS total
        FROM pokestop
        WHERE quest_item_id IS NOT NULL
        GROUP BY quest_item_id
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Any]()
        while let result = results.next() {
            
            let questType = result[0] as! UInt16
            let count = result[1] as! Int64
            let name = Localizer.global.get(value: "item_\(questType)")
            
            stats.append(["type": questType, "name": name, "count": count.withCommas()])
            
        }
        return stats
        
    }

    public static func getQuestPokemonStats(mysql: MySQL?=nil) throws -> [Any] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT quest_pokemon_id, COUNT(*) AS total
        FROM pokestop
        WHERE quest_pokemon_id IS NOT NULL
        GROUP BY quest_pokemon_id
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Any]()
        while let result = results.next() {
            
            let pokemonId = result[0] as! UInt16
            let count = result[1] as! Int64
            let name = Localizer.global.get(value: "poke_\(pokemonId)")
            
            stats.append(["id": pokemonId, "name": name, "count": count.withCommas()])
            
        }
        return stats
        
    }
    
    public static func getInvasionStats(mysql: MySQL?=nil) throws -> [Any] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT grunt_type, COUNT(*) AS total
        FROM pokestop
        WHERE incident_expire_timestamp >= UNIX_TIMESTAMP()
        GROUP BY grunt_type
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Any]()
        while let result = results.next() {
            
            let gruntType = result[0] as! UInt16
            let count = result[1] as! Int64
            let name = Localizer.global.get(value: "grunt_\(gruntType)")
            
            stats.append(["type": gruntType, "name": name, "count": count.withCommas()])
            
        }
        return stats
        
    }
    
    public static func getSpawnpointStats(mysql: MySQL?=nil) throws -> [Int64] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT
          COUNT(id) AS total,
          SUM(despawn_sec IS NOT NULL) AS found,
          SUM(despawn_sec IS NULL) AS missing,
          SUM(despawn_sec <= 1800) AS min30,
          SUM(despawn_sec > 1800) AS min60
        FROM spawnpoint
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Int64]()
        while let result = results.next() {
            
            let total = result[0] as! Int64
            let found = Int64(result[1] as! String) ?? 0
            let missing = Int64(result[2] as! String) ?? 0
            let min30 = Int64(result[3] as! String) ?? 0
            let min60 = Int64(result[4] as! String) ?? 0
            
            stats.append(total)
            stats.append(found)
            stats.append(missing)
            stats.append(min30)
            stats.append(min60)
            
        }
        return stats
        
    }
    
    public static func getGymStats(mysql: MySQL?=nil) throws -> [Int64] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT
          COUNT(id) AS total,
          SUM(team_id=0) AS neutral,
          SUM(team_id=1) AS mystic,
          SUM(team_id=2) AS valor,
          SUM(team_id=3) AS instinct,
          SUM(raid_pokemon_id IS NOT NULL AND raid_end_timestamp > UNIX_TIMESTAMP()) AS raids
        FROM gym
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Int64]()
        while let result = results.next() {
            
            let total = result[0] as! Int64
            let neutral = Int64(result[1] as! String) ?? 0
            let mystic = Int64(result[2] as! String) ?? 0
            let valor = Int64(result[3] as! String) ?? 0
            let instinct = Int64(result[4] as! String) ?? 0
            let raids = Int64(result[5] as! String) ?? 0
            
            stats.append(total)
            stats.append(neutral)
            stats.append(mystic)
            stats.append(valor)
            stats.append(instinct)
            stats.append(raids)
            
        }
        return stats
        
    }
    
}
