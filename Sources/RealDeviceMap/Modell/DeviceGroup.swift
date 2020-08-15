//
//  DeviceGroup.swift
//  RealDeviceMap
//
//  Created by versx on 5/19/19.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast

import Foundation
import PerfectLib
import PerfectMySQL

class DeviceGroup: Hashable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    var name: String
    var deviceUUIDs: [String]

    init(name: String, deviceUUIDs: [String]) {
        self.name = name
        self.deviceUUIDs = deviceUUIDs
    }

    public func create(mysql: MySQL?=nil) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DEVICEGROUP] Failed to connect to database.")
            throw DBController.DBError()
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            INSERT INTO device_group (name)
            VALUES (?)
        """
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)

        guard mysqlStmt.execute() else {
            Log.error(message: "[DEVICEGROUP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        try createLinkings(mysql: mysql)
    }

    private func createLinkings(mysql: MySQL) throws {
        if deviceUUIDs.isEmpty {
            return
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            INSERT INTO device_group_device (device_group_name, device_uuid)
            VALUES \(String(String.init(repeating: "(?, ?),", count: deviceUUIDs.count).dropLast()))
        """
        _ = mysqlStmt.prepare(statement: sql)
        for deviceUUID in deviceUUIDs {
            mysqlStmt.bindParam(name)
            mysqlStmt.bindParam(deviceUUID)
        }

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

    }

    public func update(mysql: MySQL?=nil, oldName: String) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DEVICEGROUP] Failed to connect to database.")
            throw DBController.DBError()
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            UPDATE device_group
            SET name = ?
            WHERE name = ?
        """

        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)
        mysqlStmt.bindParam(oldName)

        guard mysqlStmt.execute() else {
            Log.error(message: "[DEVICEGROUP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        try deleteLinkings(mysql: mysql)
        try createLinkings(mysql: mysql)
    }

    private func deleteLinkings(mysql: MySQL) throws {
        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            DELETE FROM device_group_device
            WHERE device_group_name = ?
        """
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)

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
            SELECT dg.name, IF(COUNT(dgd.device_uuid) > 0,JSON_ARRAYAGG(dgd.device_uuid), '[]') as device_uuids
            FROM device_group dg
            LEFT JOIN device_group_device dgd on dg.name = dgd.device_group_name
            GROUP by dg.name
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
            let deviceUUIDs = (result[1] as? String)?.jsonDecodeForceTry() as? [String] ?? []
            deviceGroups.append(DeviceGroup(name: name, deviceUUIDs: deviceUUIDs))
        }
        return deviceGroups

    }

    public static func getByName(mysql: MySQL?=nil, name: String) throws -> DeviceGroup? {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[DEVICEGROUP] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
            SELECT dg.name, IF(COUNT(dgd.device_uuid) > 0,JSON_ARRAYAGG(dgd.device_uuid), '[]') as device_uuids
            FROM device_group dg
            LEFT JOIN device_group_device dgd on dg.name = dgd.device_group_name
            WHERE dg.name = ?
            GROUP by dg.name
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
        let name = result[0] as! String
        let deviceUUIDs = (result[1] as? String)?.jsonDecodeForceTry() as? [String] ?? []

        return DeviceGroup(name: name, deviceUUIDs: deviceUUIDs)

    }

    static func == (lhs: DeviceGroup, rhs: DeviceGroup) -> Bool {
        return lhs.name == rhs.name
    }

}
