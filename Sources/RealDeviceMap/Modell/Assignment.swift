//
//  File.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 02.11.18.
//

import Foundation
import PerfectLib
import PerfectMySQL

class Assignment: Equatable {
    
    var instanceName: String
    var deviceUUID: String
    var time: UInt32
    
    init(instanceName: String, deviceUUID: String, time: UInt32) {
        self.instanceName = instanceName
        self.deviceUUID = deviceUUID
        self.time = time
    }
    
    public func save(mysql: MySQL?=nil, oldInstanceName: String, oldDeviceUUID: String, oldTime: UInt32?) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[Assignment] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
                UPDATE assignment
                SET device_uuid = ?, instance_name = ?, time = ?
                WHERE device_uuid = ? AND instance_name = ? AND time = ?
            """
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(deviceUUID)
        mysqlStmt.bindParam(instanceName)
        mysqlStmt.bindParam(time)
        mysqlStmt.bindParam(oldDeviceUUID)
        mysqlStmt.bindParam(oldInstanceName)
        mysqlStmt.bindParam(oldTime)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[Assignment] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
    
    public func create(mysql: MySQL?=nil) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[Assignment] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            INSERT INTO assignment (device_uuid, instance_name, time)
            VALUES (?, ?, ?)
        """
        
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(deviceUUID)
        mysqlStmt.bindParam(instanceName)
        mysqlStmt.bindParam(time)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[Assignment] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }

    public func delete(mysql: MySQL?=nil) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[Assignment] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            DELETE FROM assignment
            WHERE device_uuid = ? AND instance_name = ? AND time = ?
        """
        
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(deviceUUID)
        mysqlStmt.bindParam(instanceName)
        mysqlStmt.bindParam(time)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[Assignment] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }

    public static func deleteAll(mysql: MySQL?=nil) throws {
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[Assignment] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            DELETE FROM assignment
        """
        
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[Assignment] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
    
    public static func getAll(mysql: MySQL?=nil) throws -> [Assignment] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[Assignment] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT device_uuid, instance_name, time
            FROM assignment
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[Assignment] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var assignments = [Assignment]()
        while let result = results.next() {
            let deviceUUID = result[0] as! String
            let instanceName = result[1] as! String
            let time = result[2] as! UInt32
            
            assignments.append(Assignment(instanceName: instanceName, deviceUUID: deviceUUID, time: time))
        }
        return assignments
        
    }
    
    public static func getByUUID(mysql: MySQL?=nil, instanceName: String, deviceUUID: String, time: UInt32) throws -> Assignment? {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[Assignment] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT device_uuid, instance_name, time
            FROM assignment
            WHERE device_uuid = ? AND instance_name = ? AND time = ?
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(deviceUUID)
        mysqlStmt.bindParam(instanceName)
        mysqlStmt.bindParam(time)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[Assignment] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }
        
        let result = results.next()!
        let deviceUUID = result[0] as! String
        let instanceName = result[1] as! String
        let assignmentTime = result[2] as! UInt32
        return Assignment(instanceName: instanceName, deviceUUID: deviceUUID, time: assignmentTime)
        
    }
    
    static func == (lhs: Assignment, rhs: Assignment) -> Bool {
        return lhs.instanceName == rhs.instanceName && lhs.deviceUUID == rhs.deviceUUID && lhs.time == rhs.time
    }
    
}
