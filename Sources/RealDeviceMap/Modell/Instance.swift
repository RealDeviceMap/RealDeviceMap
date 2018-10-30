//
//  Instance.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 29.09.18.
//

import Foundation
import PerfectLib
import PerfectMySQL

class Instance {
    
    enum InstanceType: String {
        case circlePokemon = "circle_pokemon"
        case circleRaid = "circle_raid"
        case autoQuest = "auto_quest"
        
        static func fromString(_ s: String) -> InstanceType? {
            if s.lowercased() == "circle_pokemon" || s.lowercased() == "circlepokemon" {
                return .circlePokemon
            } else if s.lowercased() == "circle_raid" || s.lowercased() == "circleraid" {
                return .circleRaid
            } else if s.lowercased() == "auto_quest" || s.lowercased() == "autoquest" {
                return .autoQuest
            } else {
                return nil
            }
        }
    }
    
    var name: String
    var type: InstanceType
    var data: [String: Any]

    init(name: String, type: InstanceType, data: [String: Any]) {
        self.name = name
        self.type = type
        self.data = data
    }
    
    public func create(mysql: MySQL?=nil) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[INSTANCE] Failed to connect to database.")
            throw DBController.DBError()
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            INSERT INTO instance (name, type, data)
            VALUES (?, ?, ?)
        """
        
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)
        mysqlStmt.bindParam(type.rawValue)
        mysqlStmt.bindParam(try! data.jsonEncodedString())
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[INSTANCE] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
    
    public static func delete(mysql: MySQL?=nil, name: String) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[INSTANCE] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            DELETE FROM instance
            WHERE name = ?
        """
        
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[INSTANCE] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
    
    public func update(mysql: MySQL?=nil, oldName: String) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[INSTANCE] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            UPDATE instance
            SET data = ?, name = ?, type = ?
            WHERE name = ?
        """
        
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(try! data.jsonEncodedString())
        mysqlStmt.bindParam(name)
        mysqlStmt.bindParam(type.rawValue)
        mysqlStmt.bindParam(oldName)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[INSTANCE] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
    
    public static func getAll(mysql: MySQL?=nil) throws -> [Instance] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[INSTANCE] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT name, type, data
            FROM instance
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[INSTANCE] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var instances = [Instance]()
        while let result = results.next() {
            let name = result[0] as! String
            let type = InstanceType.fromString(result[1] as! String)!
            let data = (try! (result[2] as! String).jsonDecode() as? [String: Any]) ?? [String: Any]()
            instances.append(Instance(name: name, type: type, data: data))
        }
        return instances
        
    }
    
    public static func getByName(mysql: MySQL?=nil, name: String) throws -> Instance? {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[INSTANCE] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT type, data
            FROM instance
            WHERE name = ?
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[INSTANCE] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }
        
        let result = results.next()!
            let type = InstanceType.fromString(result[0] as! String)!
            let data = (try! (result[1] as! String).jsonDecode() as? [String: Any]) ?? [String: Any]()
        return Instance(name: name, type: type, data: data)
    
    }
    
}
