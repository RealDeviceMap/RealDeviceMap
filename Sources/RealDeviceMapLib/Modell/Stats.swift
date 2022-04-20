//
//  Stats.swift
//  RealDeviceMap
//
//  Created by versx on 12/22/19.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast

import Foundation
import PerfectLib
import PerfectMySQL

class Stats: JSONConvertibleObject {

    override func getJSONValues() -> [String: Any] {
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
            "pokemon_total": pokemonStats?[0] ?? 0,
            "pokemon_active": pokemonStats?[1] ?? 0,
            "pokemon_iv_total": pokemonStats?[2] ?? 0,
            "pokemon_iv_active": pokemonStats?[3] ?? 0,
            "pokemon_active_100iv": pokemonStats?[4] ?? 0,
            "pokemon_active_90iv": pokemonStats?[5] ?? 0,
            "pokemon_active_0iv": pokemonStats?[6] ?? 0,
            "pokemon_total_shiny": pokemonStats?[7] ?? 0,
            "pokemon_active_shiny": pokemonStats?[8] ?? 0,
            "pokestops_total": pokestopStats?[0] ?? 0,
            "pokestops_lures_normal": pokestopStats?[1] ?? 0,
            "pokestops_lures_glacial": pokestopStats?[2] ?? 0,
            "pokestops_lures_mossy": pokestopStats?[3] ?? 0,
            "pokestops_lures_magnetic": pokestopStats?[4] ?? 0,
            "pokestops_lures_rainy": pokestopStats?[5] ?? 0,
            "pokestops_invasions": pokestopStats?[6] ?? 0,
            "pokestops_quests": pokestopStats?[7] ?? 0,
            "gyms_total": gymStats?[0] ?? 0,
            "gyms_neutral": gymStats?[1] ?? 0,
            "gyms_mystic": gymStats?[2] ?? 0,
            "gyms_valor": gymStats?[3] ?? 0,
            "gyms_instinct": gymStats?[4] ?? 0,
            "gyms_raids": gymStats?[5] ?? 0,
            "pokemon_stats": pokemonIVStats as Any,
            "raid_stats": raidStats as Any,
            "egg_stats": eggStats as Any,
            "quest_item_stats": questItemStats as Any,
            "quest_pokemon_stats": questPokemonStats as Any,
            "invasion_stats": invasionStats as Any,
            "spawnpoints_total": spawnpointStats?[0] ?? 0,
            "spawnpoints_found": spawnpointStats?[1] ?? 0,
            "spawnpoints_missing": spawnpointStats?[2] ?? 0
        ]
    }

    public static func getTopPokemonStats(mysql: MySQL? = nil, mode: String, limit: Int? = 10) throws -> [Any] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql: String
        switch mode {
        case "lifetime":
            sql = """
                  SELECT iv.pokemon_id, SUM(iv.count) as count, SUM(shiny.count) as shiny
                  FROM pokemon_iv_stats iv
                    LEFT JOIN pokemon_shiny_stats shiny
                    ON iv.date = shiny.date AND iv.pokemon_id = shiny.pokemon_id
                  GROUP BY iv.pokemon_id
                  ORDER BY count DESC
                  LIMIT \(limit ?? 10)
                  """
        case "month":
            sql = """
                  SELECT iv.pokemon_id, SUM(iv.count) as count, SUM(shiny.count) as shiny
                  FROM pokemon_iv_stats iv
                      JOIN pokemon_shiny_stats shiny
                      ON iv.date = shiny.date AND iv.pokemon_id = shiny.pokemon_id
                  WHERE iv.date > FROM_UNIXTIME(UNIX_TIMESTAMP(NOW() - INTERVAL 30 DAY), '%Y-%m-%d')
                  GROUP BY iv.pokemon_id
                  ORDER BY count DESC
                  LIMIT \(limit ?? 10)
                  """
        case "today":
            sql = """
                  SELECT iv.pokemon_id, SUM(iv.count) as count, SUM(shiny.count) as shiny
                  FROM pokemon_iv_stats iv
                    LEFT JOIN pokemon_shiny_stats shiny
                    ON iv.date = shiny.date AND iv.pokemon_id = shiny.pokemon_id
                  WHERE iv.date = FROM_UNIXTIME(UNIX_TIMESTAMP(), '%Y-%m-%d')
                  GROUP BY iv.pokemon_id
                  ORDER BY count DESC
                  LIMIT \(limit ?? 10)
                  """
        case "iv":
            sql = """
                  SELECT pokemon_id, SUM(count) as count
                  FROM pokemon_hundo_stats
                  WHERE date = FROM_UNIXTIME(UNIX_TIMESTAMP(), '%Y-%m-%d')
                  GROUP BY pokemon_id
                  ORDER BY count DESC
                  LIMIT \(limit ?? 10)
                  """
        default:
            return [Any]()
        }

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
            let count = Int(result[1] as? String ?? "0") ?? 0
            let shiny = mode == "iv" ? nil : Int(result[2] as? String ?? "0") ?? 0
            let name = Localizer.global.get(value: "poke_\(pokemonId)")
            var shinyRate = 0
            if shiny != nil && shiny! > 0 {
                shinyRate = count / shiny!
            }
            let shinyResult: String
            if shinyRate > 0 {
                shinyResult = "1/\(shinyRate) | "
            } else {
                shinyResult = "-/- | "
            }
            stats.append([
                "pokemon_id": pokemonId,
                "name": name,
                "shiny": shiny?.withCommas() ?? "",
                "shinyRate": shinyResult,
                "count": count.withCommas()
            ])
        }
        return stats
    }

    public static func getAllPokemonStats(mysql: MySQL? = nil) throws -> [Any] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
                  SELECT date, SUM(count) as count
                  FROM `pokemon_stats`
                  GROUP BY date
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

            let date = result[0] as! String
            let count = Int(result[1] as? String ?? "0") ?? 0

            stats.append([
                "date": date,
                "count": count.withCommas()
            ])

        }
        return stats
    }

    public static func getAllRaidStats(mysql: MySQL? = nil) throws -> [Any] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
                  SELECT date, SUM(count) as count
                  FROM `raid_stats`
                  GROUP BY date
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

            let date = result[0] as! String
            let count = Int(result[1] as? String ?? "0") ?? 0

            stats.append([
                "date": date,
                "count": count.withCommas()
            ])

        }
        return stats
    }

    public static func getAllQuestStats(mysql: MySQL? = nil) throws -> [Any] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
                  SELECT date, SUM(count) as count
                  FROM `quest_stats`
                  GROUP BY date
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

            let date = result[0] as! String
            let count = Int(result[1] as? String ?? "0") ?? 0

            stats.append([
                "date": date,
                "count": count.withCommas()
            ])

        }
        return stats
    }

    public static func getAllInvasionStats(mysql: MySQL? = nil) throws -> [Any] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
                  SELECT date, SUM(count) as count
                  FROM `invasion_stats`
                  GROUP BY date
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

            let date = result[0] as! String
            let count = Int(result[1] as? String ?? "0") ?? 0

            stats.append([
                "date": date,
                "count": count.withCommas()
            ])

        }
        return stats
    }

    public static func getPokemonIVStats(mysql: MySQL? = nil, date: String? = nil) throws -> [Any] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }

        let when = date == nil ? "FROM_UNIXTIME(UNIX_TIMESTAMP(), '%Y-%m-%d')" : "?"
        let sql = """
                  SELECT x.date, x.pokemon_id, shiny.count as shiny, iv.count
                  FROM pokemon_stats x
                    LEFT JOIN pokemon_shiny_stats shiny
                    ON x.date = shiny.date AND x.pokemon_id = shiny.pokemon_id
                    LEFT JOIN pokemon_iv_stats iv
                    ON x.date = iv.date AND x.pokemon_id = iv.pokemon_id
                  WHERE x.date = \(when)
                  """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        if date != nil {
            mysqlStmt.bindParam(date)
        }

        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var stats = [Any]()
        while let result = results.next() {

            let date = result[0] as! String
            let pokemonId = result[1] as! UInt16
            let shiny = result[2] as? Int32 ?? 0
            let count = result[3] as? Int32 ?? 0
            let name = Localizer.global.get(value: "poke_\(pokemonId)")

            stats.append([
                "date": date,
                "pokemon_id": pokemonId,
                "name": name,
                "shiny": shiny.withCommas(),
                "count": count.withCommas()
            ])

        }
        return stats

    }

    public static func getPokemonStats(mysql: MySQL? = nil) throws -> [Int64] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }

        // Thanks Flo
        let sql = """
                  SELECT * FROM (
                      SELECT SUM(count) AS total
                      FROM pokemon_stats
                  ) AS A
                  JOIN (
                      SELECT SUM(count) AS iv_total
                      FROM pokemon_iv_stats
                  ) AS B
                  JOIN (
                      SELECT SUM(count) AS total_shiny
                      FROM pokemon_shiny_stats
                  ) AS C
                  JOIN (
                      SELECT COUNT(id) AS active, COUNT(iv) AS iv_active, SUM(iv = 100) AS active_100iv,
                             SUM(iv >= 90 AND iv < 100) AS active_90iv, SUM(iv = 0) AS active_0iv,
                             SUM(shiny = 1) AS active_shiny
                      FROM pokemon
                      WHERE expire_timestamp >= UNIX_TIMESTAMP()
                  ) AS D
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

            let total = Int64(result[0] as? String ?? "0") ?? 0
            let ivTotal = Int64(result[1] as? String ?? "0") ?? 0
            let totalShiny = Int64(result[2] as? String ?? "0") ?? 0
            let active = result[3] as? Int64 ?? 0
            let ivActive = result[4] as? Int64 ?? 0
            let active100iv = Int64(result[5] as? String ?? "0") ?? 0
            let active90iv = Int64(result[6] as? String ?? "0") ?? 0
            let active0iv = Int64(result[7] as? String ?? "0") ?? 0
            let activeShiny = Int64(result[8] as? String ?? "0") ?? 0

            stats.append(total)
            stats.append(active)
            stats.append(ivTotal)
            stats.append(ivActive)
            stats.append(active100iv)
            stats.append(active90iv)
            stats.append(active0iv)
            stats.append(totalShiny)
            stats.append(activeShiny)

        }
        return stats

    }

    public static func getRaidStats(mysql: MySQL? = nil, date: String? = nil) throws -> [Any] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }

        let when = date == nil ? "FROM_UNIXTIME(UNIX_TIMESTAMP(), '%Y-%m-%d')" : "?"
        let sql = """
                  SELECT pokemon_id, count, level
                  FROM raid_stats
                  WHERE date = \(when)
                  """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        if date != nil {
            mysqlStmt.bindParam(date)
        }

        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var stats = [Any]()
        while let result = results.next() {

            let pokemonId = result[0] as! UInt16
            let count = result[1] as! Int32
            let level = result[2] as! UInt16
            let name = Localizer.global.get(value: "poke_\(pokemonId)")

            stats.append([
                "pokemon_id": pokemonId,
                "name": name,
                "level": level,
                "count": count.withCommas()
            ])

        }
        return stats

    }

    public static func getRaidEggStats(mysql: MySQL? = nil, date: String? = nil) throws -> [Any] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }

        let when = date == nil ? "FROM_UNIXTIME(UNIX_TIMESTAMP(), '%Y-%m-%d')" : "?"
        let sql = """
                  SELECT level, SUM(count) as count
                  FROM raid_stats
                  WHERE date = \(when)
                  GROUP BY level
                  """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        if date != nil {
            mysqlStmt.bindParam(date)
        }

        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var stats = [Any]()
        while let result = results.next() {

            let level = result[0] as! UInt16
            let count = Int64(result[1] as? String ?? "0") ?? 0

            stats.append([
                "level": level,
                "count": count.withCommas()
            ])

        }
        return stats

    }

    public static func getPokestopStats(mysql: MySQL? = nil) throws -> [Int64] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
                  SELECT
                      COUNT(DISTINCT id) AS total,
                      SUM(lure_expire_timestamp > UNIX_TIMESTAMP() AND lure_id=501) AS normal_lures,
                      SUM(lure_expire_timestamp > UNIX_TIMESTAMP() AND lure_id=502) AS glacial_lures,
                      SUM(lure_expire_timestamp > UNIX_TIMESTAMP() AND lure_id=503) AS mossy_lures,
                      SUM(lure_expire_timestamp > UNIX_TIMESTAMP() AND lure_id=504) AS magnetic_lures,
                      SUM(lure_expire_timestamp > UNIX_TIMESTAMP() AND lure_id=505) AS rainy_lures,
                      SUM(invasions) AS invasions,
                      (COUNT(alternative_quest_reward_type) + COUNT(quest_reward_type)) quests
                  FROM (
                      SELECT pokestop.id, lure_expire_timestamp, lure_id,
                        alternative_quest_reward_type, quest_reward_type, count(incident.id) as invasions
                      FROM pokestop
                      LEFT JOIN incident on pokestop.id = incident.pokestop_id
                        and incident.expiration >= UNIX_TIMESTAMP()
                      GROUP BY pokestop.id
                  ) as calculation;
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
            let rainyLures = Int64(result[5] as! String)!
            let invasions = Int64(result[6] as! String)!
            let quests = result[7] as! Int64

            stats.append(total)
            stats.append(normalLures)
            stats.append(glacialLures)
            stats.append(mossyLures)
            stats.append(magneticLures)
            stats.append(rainyLures)
            stats.append(invasions)
            stats.append(quests)

        }
        return stats

    }

    public static func getQuestItemStats(mysql: MySQL? = nil, date: String? = nil) throws -> [Any] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }

        let when = date == nil ? "FROM_UNIXTIME(UNIX_TIMESTAMP(), '%Y-%m-%d')" : "?"
        let sql = """
                  SELECT reward_type, item_id, SUM(count) AS count
                  FROM quest_stats
                  WHERE date = \(when) AND reward_type != 7
                  GROUP BY reward_type, item_id
                  """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        if date != nil {
            mysqlStmt.bindParam(date)
        }

        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var stats = [Any]()
        while let result = results.next() {

            let rewardType = result[0] as! UInt16
            let itemId = result[1] as! UInt16
            let count = Int64(result[2] as? String ?? "0") ?? 0
            let name = itemId == 0
                ? Localizer.global.get(value: "quest_reward_\(rewardType)")
                : Localizer.global.get(value: "item_\(itemId)")

            stats.append([
                "reward_type": rewardType,
                "item_id": itemId,
                "name": name,
                "count": count.withCommas()
            ])

        }
        return stats

    }

    public static func getQuestPokemonStats(mysql: MySQL? = nil, date: String? = nil) throws -> [Any] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }

        let when = date == nil ? "FROM_UNIXTIME(UNIX_TIMESTAMP(), '%Y-%m-%d')" : "?"
        let sql = """
                  SELECT pokemon_id, SUM(count) AS count
                  FROM quest_stats
                  WHERE date = \(when)
                  GROUP BY pokemon_id
                  """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        if date != nil {
            mysqlStmt.bindParam(date)
        }

        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var stats = [Any]()
        while let result = results.next() {

            let pokemonId = result[0] as! UInt16
            let count = Int64(result[1] as? String ?? "0") ?? 0
            let name = Localizer.global.get(value: "poke_\(pokemonId)")

            stats.append([
                "pokemon_id": pokemonId,
                "name": name,
                "count": count.withCommas()
            ])

        }
        return stats

    }

    public static func getInvasionStats(mysql: MySQL? = nil, date: String? = nil) throws -> [Any] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }

        let when = date == nil ? "FROM_UNIXTIME(UNIX_TIMESTAMP(), '%Y-%m-%d')" : "?"
        let sql = """
                  SELECT date, grunt_type, count
                  FROM invasion_stats
                  WHERE date = \(when)
                  """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        if date != nil {
            mysqlStmt.bindParam(date)
        }

        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var stats = [Any]()
        while let result = results.next() {

            let date = result[0] as! String
            let gruntType = result[1] as! UInt16
            let count = result[2] as! Int32
            let name = Localizer.global.get(value: "grunt_\(gruntType)")

            stats.append([
                "date": date,
                "grunt_type": gruntType,
                "name": name,
                "count": count.withCommas()
            ])

        }
        return stats

    }

    public static func getSpawnpointStats(mysql: MySQL? = nil) throws -> [Int64] {

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

    public static func getGymStats(mysql: MySQL? = nil) throws -> [Int64] {

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

    public static func getNewPokestops(mysql: MySQL? = nil, hours: Int? = 24) throws -> [Any] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
                  SELECT id, lat, lon, name, url, first_seen_timestamp
                  FROM `pokestop`
                  WHERE first_seen_timestamp > UNIX_TIMESTAMP(NOW() - INTERVAL ? HOUR)
                  """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        mysqlStmt.bindParam(hours ?? 24)

        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var stats = [Any]()
        while let result = results.next() {

            let id = result[0] as! String
            let lat = result[1] as! Double
            let lon = result[2] as! Double
            let name = result[3] as? String
            let url = result[4] as? String
            let firstSeen = result[5] as? UInt32

            stats.append([
                "id": id,
                "lat": lat,
                "lon": lon,
                "name": name ?? "Unknown Name",
                "url": url ?? "",
                "first_seen": firstSeen ?? 0
            ])

        }
        return stats

    }

    public static func getNewGyms(mysql: MySQL? = nil, hours: Int? = 24) throws -> [Any] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
                  SELECT id, lat, lon, name, url, first_seen_timestamp
                  FROM `gym`
                  WHERE first_seen_timestamp > UNIX_TIMESTAMP(NOW() - INTERVAL ? HOUR)
                  """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        mysqlStmt.bindParam(hours ?? 24)

        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var stats = [Any]()
        while let result = results.next() {

            let id = result[0] as! String
            let lat = result[1] as! Double
            let lon = result[2] as! Double
            let name = result[3] as? String
            let url = result[4] as? String
            let firstSeen = result[5] as? UInt32

            stats.append([
                "id": id,
                "lat": lat,
                "lon": lon,
                "name": name ?? "Unknown Name",
                "url": url ?? "",
                "first_seen": firstSeen ?? 0
            ])

        }
        return stats

    }

    public static func getCommDayStats(mysql: MySQL? = nil, pokemonId: UInt16, start: String, end: String)
    throws -> [String: Any] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
                  SELECT
                    COUNT(id) AS total,
                    SUM(iv > 0) AS with_iv,
                    SUM(iv IS NULL) AS without_iv,
                    SUM(iv = 0) AS iv_0,
                    SUM(iv >= 1 AND iv < 10) AS iv_1_9,
                    SUM(iv >= 10 AND iv < 20) AS iv_10_19,
                    SUM(iv >= 20 AND iv < 30) AS iv_20_29,
                    SUM(iv >= 30 AND iv < 40) AS iv_30_39,
                    SUM(iv >= 40 AND iv < 50) AS iv_40_49,
                    SUM(iv >= 50 AND iv < 60) AS iv_50_59,
                    SUM(iv >= 60 AND iv < 70) AS iv_60_69,
                    SUM(iv >= 70 AND iv < 80) AS iv_70_79,
                    SUM(iv >= 80 AND iv < 90) AS iv_80_89,
                    SUM(iv >= 90 AND iv < 100) AS iv_90_99,
                    SUM(iv = 100) AS iv_100,
                    SUM(gender = 1) AS male,
                    SUM(gender = 2) AS female,
                    SUM(gender = 3) AS genderless,
                    SUM(level >= 1 AND level <= 9) AS level_1_9,
                    SUM(level >= 10 AND level <= 19) AS level_10_19,
                    SUM(level >= 20 AND level <= 29) AS level_20_29,
                    SUM(level >= 30 AND level <= 35) AS level_30_35
                  FROM
                    pokemon
                  WHERE
                    pokemon_id = ?
                    AND first_seen_timestamp >= ?
                    AND first_seen_timestamp <= ?
                  """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        mysqlStmt.bindParam(pokemonId)
        mysqlStmt.bindParam(start)
        mysqlStmt.bindParam(end)

        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var stats = [String: Any]()
        while let result = results.next() {

            stats["total"] = result[0] as? Int64 ?? 0
            stats["with_iv"] = Int64(result[1] as? String ?? "0") ?? 0
            stats["without_iv"] = Int64(result[2] as? String ?? "0") ?? 0

            stats["iv_0"] = Int64(result[3] as? String ?? "0") ?? 0
            stats["iv_1_9"] = Int64(result[4] as? String ?? "0") ?? 0
            stats["iv_10_19"] = Int64(result[5] as? String ?? "0") ?? 0
            stats["iv_20_29"] = Int64(result[6] as? String ?? "0") ?? 0
            stats["iv_30_39"] = Int64(result[7] as? String ?? "0") ?? 0
            stats["iv_40_49"] = Int64(result[8] as? String ?? "0") ?? 0
            stats["iv_50_59"] = Int64(result[9] as? String ?? "0") ?? 0
            stats["iv_60_69"] = Int64(result[10] as? String ?? "0") ?? 0
            stats["iv_70_79"] = Int64(result[11] as? String ?? "0") ?? 0
            stats["iv_80_89"] = Int64(result[12] as? String ?? "0") ?? 0
            stats["iv_90_99"] = Int64(result[13] as? String ?? "0") ?? 0
            stats["iv_100"] = Int64(result[14] as? String ?? "0") ?? 0

            stats["male"] = Int64(result[15] as? String ?? "0") ?? 0
            stats["female"] = Int64(result[16] as? String ?? "0") ?? 0
            stats["genderless"] = Int64(result[17] as? String ?? "0") ?? 0

            stats["level_1_9"] = Int64(result[18] as? String ?? "0") ?? 0
            stats["level_10_19"] = Int64(result[19] as? String ?? "0") ?? 0
            stats["level_20_29"] = Int64(result[20] as? String ?? "0") ?? 0
            stats["level_30_35"] = Int64(result[21] as? String ?? "0") ?? 0

        }
        return stats

    }

}
