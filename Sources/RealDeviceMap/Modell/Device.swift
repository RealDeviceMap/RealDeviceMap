//
//  Device.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 29.09.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast

import Foundation
import PerfectLib
import PerfectMySQL

class Device: JSONConvertibleObject, Hashable {

    override func getJSONValues() -> [String: Any] {
        return [
            "uuid": uuid as Any,
            "instance_name": instanceName as Any,
            "last_host": lastHost as Any,
            "last_seen": lastSeen as Any,
            "account_username": accountUsername as Any,
            "last_lat": lastLat as Any,
            "last_lon": lastLon as Any
        ]
    }

    public var hashValue: Int {
        return uuid.hashValue
    }

    var uuid: String
    var instanceName: String?
    var lastHost: String?
    var lastSeen: UInt32
    var accountUsername: String?
    var lastLat: Double?
    var lastLon: Double?
    var deviceGroup: String?

    init(uuid: String, instanceName: String?, lastHost: String?, lastSeen: UInt32, accountUsername: String?,
         lastLat: Double?, lastLon: Double?, deviceGroup: String?) {
        self.uuid = uuid
        self.instanceName = instanceName
        self.lastHost = lastHost
        self.lastSeen = lastSeen
        self.accountUsername = accountUsername
        self.lastLat = lastLat
        self.lastLon = lastLon
        self.deviceGroup = deviceGroup
    }

    public static func touch(mysql: MySQL?=nil, uuid: String, host: String) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DEVICE] Failed to connect to database.")
            throw DBController.DBError()
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
                UPDATE device
                SET last_host = ?
                WHERE uuid = ?
            """
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(host)
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
                SET uuid = ?, instance_name = ?, last_host = ?, last_seen = ?, account_username = ?,
                    last_lat = ?, last_lon = ?, device_group = ?
                WHERE uuid = ?
            """
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(uuid)
        mysqlStmt.bindParam(instanceName)
        mysqlStmt.bindParam(lastHost)
        mysqlStmt.bindParam(lastSeen)
        mysqlStmt.bindParam(accountUsername)
        mysqlStmt.bindParam(lastLat)
        mysqlStmt.bindParam(lastLon)
        mysqlStmt.bindParam(deviceGroup)
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
            INSERT INTO device (uuid, instance_name, last_host, last_seen, account_username, last_lat,
                                last_lon, device_group)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """

        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(uuid)
        mysqlStmt.bindParam(instanceName)
        mysqlStmt.bindParam(lastHost)
        mysqlStmt.bindParam(lastSeen)
        mysqlStmt.bindParam(accountUsername)
        mysqlStmt.bindParam(lastLat)
        mysqlStmt.bindParam(lastLon)
        mysqlStmt.bindParam(deviceGroup)

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
            SELECT uuid, instance_name, last_host, last_seen, account_username, last_lat, last_lon, device_group
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
            let lastLat = result[5] as? Double
            let lastLon = result[6] as? Double
            let deviceGroup = result[7] as? String

            devices.append(Device(uuid: uuid, instanceName: instanceName, lastHost: lastHost, lastSeen: lastSeen,
                                  accountUsername: accountUsername, lastLat: lastLat, lastLon: lastLon,
                                  deviceGroup: deviceGroup))
        }
        return devices

    }

    public static func getById(mysql: MySQL?=nil, id: String) throws -> Device? {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DEVICE] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
            SELECT instance_name, last_host, last_seen, account_username, last_lat, last_lon, device_group
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
        let lastLat = result[4] as? Double
        let lastLon = result[5] as? Double
        let deviceGroup = result[6] as? String

        return Device(uuid: id, instanceName: instanceName, lastHost: lastHost, lastSeen: lastSeen,
                      accountUsername: accountUsername, lastLat: lastLat, lastLon: lastLon, deviceGroup: deviceGroup)
    }

    public static func setLastLocation(mysql: MySQL?=nil, uuid: String, lat: Double, lon: Double) throws {
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DEVICE] Failed to connect to database.")
            throw DBController.DBError()
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
                UPDATE device
                SET last_lat = ?, last_lon = ?, last_seen = UNIX_TIMESTAMP()
                WHERE uuid = ?
            """
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(lat)
        mysqlStmt.bindParam(lon)
        mysqlStmt.bindParam(uuid)

        guard mysqlStmt.execute() else {
            Log.error(message: "[DEVICE] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }

    public func clearGroup(mysql: MySQL?=nil) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DEVICE] Failed to connect to database.")
            throw DBController.DBError()
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            UPDATE device SET device_group = NULL
            WHERE uuid = ?
        """

        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(uuid)

        guard mysqlStmt.execute() else {
            Log.error(message: "[DEVICE] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }

    static func == (lhs: Device, rhs: Device) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}
