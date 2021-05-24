//
//  Group.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 24.09.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast

import Foundation
import PerfectLib
import PerfectMySQL
import PerfectThread

struct Group {

    enum Perm: UInt32 {
        case viewMap = 0
        case viewMapRaid = 1
        case viewMapPokemon = 2
        case viewStats = 3
        case admin = 4
        // case adminUser = 5
        case viewMapGym = 6
        case viewMapPokestop = 7
        case viewMapSpawnpoint = 8
        case viewMapQuest = 9
        case viewMapIV = 10
        case viewMapCell = 11
        case viewMapWeather = 12
        case viewMapLure = 13
        case viewMapInvasion = 14
        case viewMapDevice = 15
        case viewMapSubmissionCells = 16
        case viewMapEventPokemon = 17

        static var all: [Perm] = [
            .viewMap, .viewMapRaid, .viewMapPokemon, .viewStats, .admin, .viewMapGym, .viewMapPokestop,
            .viewMapSpawnpoint, .viewMapQuest, .viewMapIV, .viewMapCell, .viewMapWeather, .viewMapLure,
            .viewMapInvasion, .viewMapDevice, .viewMapSubmissionCells, .viewMapEventPokemon
        ]

        static func permsToNumber(perms: [Perm]) -> UInt32 {
            var number: UInt32 = 0
            for perm in perms {
                number += UInt32(pow(2, Double(perm.rawValue)))
            }

            return number
        }

        static func numberToPerms(number: UInt32) -> [Perm] {
            let numberString = String(String(number, radix: 2).reversed())
            var perms = [Perm]()

            for perm in all where numberString.count > perm.rawValue && numberString[Int(perm.rawValue)] == "1" {
                perms.append(perm)
            }

            return perms
        }
    }

    var name: String
    var perms: [Perm]

    private static var cacheLock = Threading.Lock()
    private static var cachedGroups = [String: Group]()

    public static func getFromCache(groupName: String) -> Group? {
        cacheLock.lock()
        let group = cachedGroups[groupName]
        cacheLock.unlock()
        return group
    }

    private static func storeInCache(group: Group) {
        cacheLock.lock()
        cachedGroups[group.name] = group
        cacheLock.unlock()
    }

    private static func renameInCache(newName: String, oldName: String) {
        cacheLock.lock()
        if var group = cachedGroups[oldName] {
            cachedGroups[oldName] = nil
            group.name = newName
            cachedGroups[newName] = group
        }
        DiscordController.global.updateGroupName(oldName: oldName, newName: newName)
        cacheLock.unlock()
    }

    private static func removeInCache(name: String) {
        cacheLock.lock()
        cachedGroups[name] = nil
        cacheLock.unlock()
    }

    public static func setup() throws {
        let all = try getAll()
        cachedGroups = [String: Group]()
        for group in all {
            cachedGroups[group.name] = group
        }
    }

    public static func getWithName(mysql: MySQL?=nil, name: String) throws -> Group? {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[GROUP] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
            SELECT perm_view_map, perm_view_map_raid, perm_view_map_pokemon, perm_view_stats, perm_admin,
                   perm_view_map_gym, perm_view_map_pokestop, perm_view_map_spawnpoint, perm_view_map_quest,
                   perm_view_map_iv, perm_view_map_cell, perm_view_map_weather, perm_view_map_lure,
                   perm_view_map_invasion, perm_view_map_device, perm_view_map_submission_cell,
                   perm_view_map_event_pokemon
            FROM `group`
            WHERE name = ?
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)

        guard mysqlStmt.execute() else {
            Log.error(message: "[GROUP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }

        let result = results.next()!

        let permViewMap = (result[0] as? UInt8)!.toBool()
        let permViewMapRaid = (result[1] as? UInt8)!.toBool()
        let permViewMapPokemon = (result[2] as? UInt8)!.toBool()
        let permViewStats = (result[3] as? UInt8)!.toBool()
        let permAdmin = (result[4] as? UInt8)!.toBool()
        let permViewMapGym = (result[5] as? UInt8)!.toBool()
        let permViewMapPokestop = (result[6] as? UInt8)!.toBool()
        let permViewMapSpawnpoint = (result[7] as? UInt8)!.toBool()
        let permViewMapQuest = (result[8] as? UInt8)!.toBool()
        let permViewMapIV = (result[9] as? UInt8)!.toBool()
        let permViewMapCell = (result[10] as? UInt8)!.toBool()
        let permViewMapWeather = (result[11] as? UInt8)!.toBool()
        let permViewMapLure = (result[12] as? UInt8)!.toBool()
        let permViewMapInvasion = (result[13] as? UInt8)!.toBool()
        let permViewMapDevice = (result[14] as? UInt8)!.toBool()
        let permViewMapSubmissionCells = (result[15] as? UInt8)!.toBool()
        let permViewMapEventPokemon = (result[16] as? UInt8)!.toBool()

        var perms = [Perm]()
        if permViewMap {
            perms.append(.viewMap)
        }
        if permViewMapRaid {
            perms.append(.viewMapRaid)
        }
        if permViewMapPokemon {
            perms.append(.viewMapPokemon)
        }
        if permViewStats {
            perms.append(.viewStats)
        }
        if permAdmin {
            perms.append(.admin)
        }
        if permViewMapGym {
            perms.append(.viewMapGym)
        }
        if permViewMapPokestop {
            perms.append(.viewMapPokestop)
        }
        if permViewMapSpawnpoint {
            perms.append(.viewMapSpawnpoint)
        }
        if permViewMapQuest {
            perms.append(.viewMapQuest)
        }
        if permViewMapIV {
            perms.append(.viewMapIV)
        }
        if permViewMapCell {
            perms.append(.viewMapCell)
        }
        if permViewMapWeather {
            perms.append(.viewMapWeather)
        }
        if permViewMapLure {
            perms.append(.viewMapLure)
        }
        if permViewMapInvasion {
            perms.append(.viewMapInvasion)
        }
        if permViewMapDevice {
            perms.append(.viewMapDevice)
        }
        if permViewMapSubmissionCells {
            perms.append(.viewMapSubmissionCells)
        }
        if permViewMapEventPokemon {
            perms.append(.viewMapEventPokemon)
        }

        return Group(name: name, perms: perms)

    }

    public static func getAll(mysql: MySQL?=nil) throws -> [Group] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[GROUP] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
            SELECT name, perm_view_map, perm_view_map_raid, perm_view_map_pokemon, perm_view_stats, perm_admin,
                   perm_view_map_gym, perm_view_map_pokestop, perm_view_map_spawnpoint, perm_view_map_quest,
                   perm_view_map_iv, perm_view_map_cell, perm_view_map_weather, perm_view_map_lure,
                   perm_view_map_invasion, perm_view_map_device, perm_view_map_submission_cell,
                   perm_view_map_event_pokemon
            FROM `group`
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        guard mysqlStmt.execute() else {
            Log.error(message: "[GROUP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var groups = [Group]()
        while let result = results.next() {
            let name = result[0] as! String
            let permViewMap = (result[1] as? UInt8)!.toBool()
            let permViewMapRaid = (result[2] as? UInt8)!.toBool()
            let permViewMapPokemon = (result[3] as? UInt8)!.toBool()
            let permViewStats = (result[4] as? UInt8)!.toBool()
            let permAdmin = (result[5] as? UInt8)!.toBool()
            let permViewMapGym = (result[6] as? UInt8)!.toBool()
            let permViewMapPokestop = (result[7] as? UInt8)!.toBool()
            let permViewMapSpawnpoint = (result[8] as? UInt8)!.toBool()
            let permViewMapQuest = (result[9] as? UInt8)!.toBool()
            let permViewMapIV = (result[10] as? UInt8)!.toBool()
            let permViewMapCell = (result[11] as? UInt8)!.toBool()
            let permViewMapWeather = (result[12] as? UInt8)!.toBool()
            let permViewMapLure = (result[13] as? UInt8)!.toBool()
            let permViewMapInvasion = (result[14] as? UInt8)!.toBool()
            let permViewMapDevice = (result[15] as? UInt8)!.toBool()
            let permViewMapSubmissionCells = (result[16] as? UInt8)!.toBool()
            let permViewMapEventPokemon = (result[17] as? UInt8)!.toBool()

            var perms = [Perm]()
            if permViewMap {
                perms.append(.viewMap)
            }
            if permViewMapRaid {
                perms.append(.viewMapRaid)
            }
            if permViewMapPokemon {
                perms.append(.viewMapPokemon)
            }
            if permViewStats {
                perms.append(.viewStats)
            }
            if permAdmin {
                perms.append(.admin)
            }
            if permViewMapGym {
                perms.append(.viewMapGym)
            }
            if permViewMapPokestop {
                perms.append(.viewMapPokestop)
            }
            if permViewMapSpawnpoint {
                perms.append(.viewMapSpawnpoint)
            }
            if permViewMapQuest {
                perms.append(.viewMapQuest)
            }
            if permViewMapIV {
                perms.append(.viewMapIV)
            }
            if permViewMapCell {
                perms.append(.viewMapCell)
            }
            if permViewMapWeather {
                perms.append(.viewMapWeather)
            }
            if permViewMapLure {
                perms.append(.viewMapLure)
            }
            if permViewMapInvasion {
                perms.append(.viewMapInvasion)
            }
            if permViewMapDevice {
                perms.append(.viewMapDevice)
            }
            if permViewMapSubmissionCells {
                perms.append(.viewMapSubmissionCells)
            }
            if permViewMapEventPokemon {
                perms.append(.viewMapEventPokemon)
            }

            groups.append(Group(name: name, perms: perms))
        }

        return groups
    }

    public func rename(mysql: MySQL?=nil, oldName: String) throws {
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[GROUP] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
        UPDATE `group`
        SET name = ?
        WHERE name = ?
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)
        mysqlStmt.bindParam(oldName)

        guard mysqlStmt.execute() else {
            Log.error(message: "[GROUP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        Group.renameInCache(newName: name, oldName: oldName)
    }

    public func delete(mysql: MySQL?=nil) throws {
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[GROUP] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
        DELETE FROM `group`
        WHERE name = ?
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)

        guard mysqlStmt.execute() else {
            Log.error(message: "[GROUP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        Group.removeInCache(name: name)
    }

    public func save(mysql: MySQL?=nil, update: Bool!=true) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[GROUP] Failed to connect to database.")
            throw DBController.DBError()
        }

        var sql = """
        INSERT INTO `group` (
            name, perm_view_map, perm_view_map_raid, perm_view_map_pokemon, perm_view_stats, perm_admin,
            perm_view_map_gym, perm_view_map_pokestop, perm_view_map_spawnpoint, perm_view_map_quest, perm_view_map_iv,
            perm_view_map_cell, perm_view_map_weather, perm_view_map_lure, perm_view_map_invasion, perm_view_map_device,
            perm_view_map_submission_cell, perm_view_map_event_pokemon
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        if update {
            sql += """
                ON DUPLICATE KEY UPDATE
                perm_view_map=VALUES(perm_view_map),
                perm_view_map_raid=VALUES(perm_view_map_raid),
                perm_view_map_pokemon=VALUES(perm_view_map_pokemon),
                perm_view_stats=VALUES(perm_view_stats),
                perm_admin=VALUES(perm_admin),
                perm_view_map_gym=VALUES(perm_view_map_gym),
                perm_view_map_pokestop=VALUES(perm_view_map_pokestop),
                perm_view_map_spawnpoint=VALUES(perm_view_map_spawnpoint),
                perm_view_map_quest=VALUES(perm_view_map_quest),
                perm_view_map_iv=VALUES(perm_view_map_iv),
                perm_view_map_cell=VALUES(perm_view_map_cell),
                perm_view_map_weather=VALUES(perm_view_map_weather),
                perm_view_map_lure=VALUES(perm_view_map_lure),
                perm_view_map_invasion=VALUES(perm_view_map_invasion),
                perm_view_map_device=VALUES(perm_view_map_device),
                perm_view_map_submission_cell=VALUES(perm_view_map_submission_cell),
                perm_view_map_event_pokemon=VALUES(perm_view_map_event_pokemon)
            """
        }

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)

        mysqlStmt.bindParam(perms.contains(.viewMap))
        mysqlStmt.bindParam(perms.contains(.viewMapRaid))
        mysqlStmt.bindParam(perms.contains(.viewMapPokemon))
        mysqlStmt.bindParam(perms.contains(.viewStats))
        mysqlStmt.bindParam(perms.contains(.admin))
        mysqlStmt.bindParam(perms.contains(.viewMapGym))
        mysqlStmt.bindParam(perms.contains(.viewMapPokestop))
        mysqlStmt.bindParam(perms.contains(.viewMapSpawnpoint))
        mysqlStmt.bindParam(perms.contains(.viewMapQuest))
        mysqlStmt.bindParam(perms.contains(.viewMapIV))
        mysqlStmt.bindParam(perms.contains(.viewMapCell))
        mysqlStmt.bindParam(perms.contains(.viewMapWeather))
        mysqlStmt.bindParam(perms.contains(.viewMapLure))
        mysqlStmt.bindParam(perms.contains(.viewMapInvasion))
        mysqlStmt.bindParam(perms.contains(.viewMapDevice))
        mysqlStmt.bindParam(perms.contains(.viewMapSubmissionCells))
        mysqlStmt.bindParam(perms.contains(.viewMapEventPokemon))

        guard mysqlStmt.execute() else {
            Log.error(message: "[GROUP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        Group.storeInCache(group: self)

    }

}
