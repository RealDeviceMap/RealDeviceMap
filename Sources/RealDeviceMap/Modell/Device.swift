//
//  Device.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 29.09.18.
//

import Foundation
import PerfectLib
import PerfectMySQL

class Device {
    
    var uuid: String
    var instanceName: String?
    var lastHost: String?
    var lastSeen: UInt32
    var accountUsername: String?

    init(uuid: String, instanceName: String?, lastHost: String?, lastSeen: UInt32, accountUsername: String?) {
        self.uuid = uuid
        self.instanceName = instanceName
        self.lastHost = lastHost
        self.lastSeen = lastSeen
        self.accountUsername = accountUsername
    }
    
    public static func touch(mysql: MySQL?=nil, uuid: String, host: String, seen: Int) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DEVICE] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
                UPDATE device
                SET last_host = ?, last_seen = ?
                WHERE uuid = ?
            """
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(host)
        mysqlStmt.bindParam(seen)
        mysqlStmt.bindParam(uuid)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[DEVICE] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
    
    public func save(mysql: MySQL?=nil, oldUUID: String) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DEVICE] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
                UPDATE device
                SET uuid = ?, instance_name = ?, last_host = ?, last_seen = ?, account_username = ?
                WHERE uuid = ?
            """
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(uuid)
        mysqlStmt.bindParam(instanceName)
        mysqlStmt.bindParam(lastHost)
        mysqlStmt.bindParam(lastSeen)
        mysqlStmt.bindParam(accountUsername)
        mysqlStmt.bindParam(oldUUID)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[DEVICE] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
    
    public func create(mysql: MySQL?=nil) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DEVICE] Failed to connect to database.")
            throw DBController.DBError()
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            INSERT INTO device (uuid, instance_name, last_host, last_seen, account_username)
            VALUES (?, ?, ?, ?, ?)
        """
        
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(uuid)
        mysqlStmt.bindParam(instanceName)
        mysqlStmt.bindParam(lastHost)
        mysqlStmt.bindParam(lastSeen)
        mysqlStmt.bindParam(accountUsername)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[DEVICE] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
    
    public static func getAll(mysql: MySQL?=nil) throws -> [Device] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DEVICE] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT uuid, instance_name, last_host, last_seen, account_username
            FROM device
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[DEVICE] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var devices = [Device]()
        while let result = results.next() {
            let uuid = result[0] as! String
            let instanceName = result[1] as? String
            let lastHost = result[2] as? String
            let lastSeen = result[3] as! UInt32
            let accountUsername = result[4] as? String
            
            devices.append(Device(uuid: uuid, instanceName: instanceName, lastHost: lastHost, lastSeen: lastSeen, accountUsername: accountUsername))
        }
        return devices
        
    }
    
    public static func getById(mysql: MySQL?=nil, id: String) throws -> Device? {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DEVICE] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT instance_name, last_host, last_seen, account_username
            FROM device
            WHERE uuid = ?
            LIMIT 1
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(id)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[DEVICE] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }
        
        let result = results.next()!
        let instanceName = result[0] as? String
        let lastHost = result[1] as? String
        let lastSeen = result[2] as! UInt32
        let accountUsername = result[3] as? String
        
        return Device(uuid: id, instanceName: instanceName, lastHost: lastHost, lastSeen: lastSeen, accountUsername: accountUsername)
    }
    
    
}
