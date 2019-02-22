//
//  DiscordRule.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 20.02.19.
//

import Foundation
import PerfectLib
import PerfectMySQL

class DiscordRule: Equatable {

    var priority: Int32
    var serverId: UInt64
    var roleId: UInt64?
    var groupName: String
    
    init(priority: Int32, serverId: UInt64, roleId: UInt64?, groupName: String) {
        self.priority = priority
        self.serverId = serverId
        if roleId == serverId {
            self.roleId = nil
        } else {
            self.roleId = roleId
        }
        self.groupName = groupName
    }
    
    public func create(mysql: MySQL?=nil) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DISCORDRULE] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        
        let sql = """
            INSERT INTO discord_rule (priority, server_id, role_id, group_name)
            VALUES (?, ?, ?, ?)
        """
        
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(priority)
        mysqlStmt.bindParam(serverId)
        mysqlStmt.bindParam(roleId)
        mysqlStmt.bindParam(groupName)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[DISCORDRULE] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        
        DiscordController.global.addDiscordRule(discordRule: self)
        
    }
    
    public func update(oldPriority: Int32, mysql: MySQL?=nil) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DISCORDRULE] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        
        let sql = """
            UPDATE discord_rule
            SET priority = ?, server_id = ?, role_id = ?, group_name = ?
            WHERE priority = ?
        """
        
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(priority)
        mysqlStmt.bindParam(serverId)
        mysqlStmt.bindParam(roleId)
        mysqlStmt.bindParam(groupName)
        mysqlStmt.bindParam(oldPriority)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[DISCORDRULE] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        
        DiscordController.global.updateDiscordRule(oldPriority: oldPriority, discordRule: self)
        
    }
    
    public static func delete(mysql: MySQL?=nil, priority: Int32) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DISCORDRULE] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        
        let sql = """
            DELETE FROM discord_rule
            WHERE priority = ?
        """
        
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(priority)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[DISCORDRULE] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        
        DiscordController.global.deleteDiscordRule(priority: priority)
        
    }

    public static func getAll(mysql: MySQL?=nil) throws -> [DiscordRule] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DISCORDRULE] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT priority, server_id, role_id, group_name
            FROM discord_rule
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[DISCORDRULE] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var discordRules = [DiscordRule]()
        while let result = results.next() {
            
            let priority = result[0] as! Int32
            let serverId = result[1] as! UInt64
            let roleId = result[2] as? UInt64
            let groupName = result[3] as! String

            discordRules.append(DiscordRule(priority: priority, serverId: serverId, roleId: roleId, groupName: groupName))
        }
        return discordRules
        
    }
    
    public static func get(priority: Int32, mysql: MySQL?=nil) throws -> DiscordRule? {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DISCORDRULE] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT priority, server_id, role_id, group_name
            FROM discord_rule
            WHERE priority = ?
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(priority)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[DISCORDRULE] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        if results.numRows == 0 {
            return nil
        } else {
            let result = results.next()!
            let priority = result[0] as! Int32
            let serverId = result[1] as! UInt64
            let roleId = result[2] as? UInt64
            let groupName = result[3] as! String
            
            return DiscordRule(priority: priority, serverId: serverId, roleId: roleId, groupName: groupName)
        }
        
    }

    static func == (lhs: DiscordRule, rhs: DiscordRule) -> Bool {
        return lhs.priority == rhs.priority
    }
    
}
