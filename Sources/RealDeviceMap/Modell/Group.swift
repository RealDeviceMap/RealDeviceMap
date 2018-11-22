//
//  Group.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 24.09.18.
//

import Foundation
import PerfectLib
import PerfectMySQL

struct Group {
    
    enum Perm: UInt32 {
        case viewMap = 0
        case viewMapRaid = 1
        case viewMapPokemon = 2
        case viewStats = 3
        case adminSetting = 4
        case adminUser = 5
        case viewMapGym = 6
        case viewMapPokestop = 7
        case viewMapSpawnpoint = 8
        case viewMapQuest = 9
        case viewMapIV = 10
        case viewMapCell = 11
        
        static var all: [Perm] = [.viewMap, .viewMapRaid, .viewMapPokemon, .viewStats, .adminSetting, .adminUser, .viewMapGym, .viewMapPokestop, .viewMapSpawnpoint, .viewMapQuest, .viewMapIV, .viewMapCell]
        
        
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
            
            for perm in all {
                if numberString.count > perm.rawValue {
                    if numberString[Int(perm.rawValue)] == "1" {
                        perms.append(perm)
                    }
                }
            }
            
            return perms
        }
    }
    
    var name: String
    var perms: [Perm]
    
    public static func getWithName(mysql: MySQL?=nil, name: String) throws -> Group? {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[GROUP] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT perm_view_map, perm_view_map_raid, perm_view_map_pokemon, perm_view_stats, perm_admin_setting, perm_admin_user, perm_view_map_gym, perm_view_map_pokestop, perm_view_map_spawnpoint, perm_view_map_quest, perm_view_map_iv, perm_view_map_cell
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
        let permAdminSetting = (result[4] as? UInt8)!.toBool()
        let permAdminUser = (result[5] as? UInt8)!.toBool()
        let permViewMapGym = (result[6] as? UInt8)!.toBool()
        let permViewMapPokestop = (result[7] as? UInt8)!.toBool()
        let permViewMapSpawnpoint = (result[8] as? UInt8)!.toBool()
        let permViewMapQuest = (result[9] as? UInt8)!.toBool()
        let permViewMapIV = (result[10] as? UInt8)!.toBool()
        let permViewMapCell = (result[11] as? UInt8)!.toBool()
        
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
        if permAdminSetting {
            perms.append(.adminSetting)
        }
        if permAdminUser {
            perms.append(.adminUser)
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
        
        return Group(name: name, perms: perms)
        
    }
    
    public func save(mysql: MySQL?=nil, update: Bool!=true) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[GROUP] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        var sql = """
        INSERT INTO `group` (name, perm_view_map, perm_view_map_raid, perm_view_map_pokemon, perm_view_stats, perm_admin_setting, perm_admin_user, perm_view_map_gym, perm_view_map_pokestop, perm_view_map_spawnpoint, perm_view_map_quest, perm_view_map_iv, perm_view_map_cell)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        if update {
            sql += """
                ON DUPLICATE KEY UPDATE
                perm_view_map=VALUES(perm_view_map),
                perm_view_map_raid=VALUES(perm_view_map_raid),
                perm_view_map_pokemon=VALUES(perm_view_map_pokemon),
                perm_view_stats=VALUES(perm_view_stats),
                perm_admin_setting=VALUES(perm_admin_setting),
                perm_admin_user=VALUES(perm_admin_user),
                perm_view_map_gym=VALUES(perm_view_map_gym),
                perm_view_map_pokestop=VALUES(perm_view_map_pokestop),
                perm_view_map_spawnpoint=VALUES(perm_view_map_spawnpoint)
                perm_view_map_quest=VALUES(perm_view_map_quest)
                perm_view_map_iv=VALUES(perm_view_map_iv)
                perm_view_map_cell=VALUES(perm_view_map_cell)
            """
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)
        
        mysqlStmt.bindParam(perms.contains(.viewMap))
        mysqlStmt.bindParam(perms.contains(.viewMapRaid))
        mysqlStmt.bindParam(perms.contains(.viewMapPokemon))
        mysqlStmt.bindParam(perms.contains(.viewStats))
        mysqlStmt.bindParam(perms.contains(.adminSetting))
        mysqlStmt.bindParam(perms.contains(.adminUser))
        mysqlStmt.bindParam(perms.contains(.viewMapGym))
        mysqlStmt.bindParam(perms.contains(.viewMapPokestop))
        mysqlStmt.bindParam(perms.contains(.viewMapSpawnpoint))
        mysqlStmt.bindParam(perms.contains(.viewMapQuest))
        mysqlStmt.bindParam(perms.contains(.viewMapIV))
        mysqlStmt.bindParam(perms.contains(.viewMapCell))
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[GROUP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        
    }
    
}
