//
//  DeviceGroup.swift
//  RealDeviceMap
//
//  Created by versx on 5/19/19.
//

import Foundation
import PerfectLib
import PerfectMySQL

class DeviceGroup: Hashable {
    
    public var hashValue: Int {
        return name.hashValue
    }
    
    var name: String
    var instanceName: String
    var devices: [Device]
    var count: UInt64
    
    init(name: String, instanceName: String, devices: [Device]) {
        self.name = name
        self.instanceName = instanceName
        self.devices = devices
        self.count = UInt64(devices.count)
    }
    
    public func create(mysql: MySQL?=nil) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DEVICEGROUP] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            INSERT INTO device_group (name, instance_name)
            VALUES (?, ?)
        """
        
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)
        mysqlStmt.bindParam(instanceName)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[DEVICEGROUP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
    
    public static func delete(mysql: MySQL?=nil, name: String) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DEVICEGROUP] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            DELETE FROM device_group
            WHERE name = ?
        """
        
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[DEVICEGROUP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        
        let devices = try getDevicesByGroup(name: name)!
        for device in devices {
            try device.clearGroup()
        }
    }
    
    public func update(mysql: MySQL?=nil, oldName: String) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DEVICEGROUP] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            UPDATE device_group
            SET name = ?, instance_name = ?
            WHERE name = ?
        """
        
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)
        mysqlStmt.bindParam(instanceName)
        mysqlStmt.bindParam(oldName)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[DEVICEGROUP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }

    public static func getAll(mysql: MySQL?=nil) throws -> [DeviceGroup] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DEVICEGROUP] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT name, instance_name
            FROM device_group AS devgroup
            LEFT JOIN (
                SELECT device_group
                FROM device
                GROUP BY device_group
            ) AS dev ON (dev.device_group = devgroup.name)
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[DEVICEGROUP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var deviceGroups = [DeviceGroup]()
        while let result = results.next() {
            let name = result[0] as! String
            let instanceName = result[1] as! String
            let devices = try! getDevicesByGroup(name: name)!
            deviceGroups.append(DeviceGroup(name: name, instanceName: instanceName, devices: devices))
        }
        return deviceGroups
        
    }
    
    public static func getDevicesByGroup(mysql: MySQL?=nil, name: String) throws -> [Device]? {
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DEVICEGROUP] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT uuid, instance_name, last_host, last_seen, account_username, last_lat, last_lon, device_group
            FROM device
            WHERE device_group = ?
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)
        
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
            let lastLat = result[5] as? Double
            let lastLon = result[6] as? Double
            let deviceGroup = result[7] as? String
            
            devices.append(Device(uuid: uuid, instanceName: instanceName, lastHost: lastHost, lastSeen: lastSeen, accountUsername: accountUsername, lastLat: lastLat, lastLon: lastLon, deviceGroup: deviceGroup))
        }
        return devices
    }
    
    public static func getByName(mysql: MySQL?=nil, name: String) throws -> DeviceGroup? {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DEVICEGROUP] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT instance_name
            FROM device_group
            WHERE name = ?
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[DEVICEGROUP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }
        
        let result = results.next()!
        let instanceName = result[0] as! String
        let devices = try! getDevicesByGroup(name: name)!
        return DeviceGroup(name: name, instanceName: instanceName, devices: devices)
        
    }
    
    static func == (lhs: DeviceGroup, rhs: DeviceGroup) -> Bool {
        return lhs.name == rhs.name
    }
    
}

