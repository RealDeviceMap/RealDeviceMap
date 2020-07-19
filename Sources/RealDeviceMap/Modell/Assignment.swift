//
//  Assignment.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 02.11.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast

import Foundation
import PerfectLib
import PerfectMySQL

class Assignment: Equatable {

    var id: UInt32?
    var instanceName: String
    var sourceInstanceName: String?
    var deviceUUID: String?
    var deviceGroupName: String?
    var time: UInt32
    var date: Date?
    var enabled: Bool

    init(id: UInt32?, instanceName: String, sourceInstanceName: String?, deviceUUID: String?, deviceGroupName: String?,
         time: UInt32, date: Date?, enabled: Bool) {
        self.id = id
        self.instanceName = instanceName
        self.sourceInstanceName = sourceInstanceName
        self.deviceUUID = deviceUUID
        self.deviceGroupName = deviceGroupName
        self.time = time
        self.date = date
        self.enabled = enabled
    }

    public func save(mysql: MySQL?=nil, oldId: UInt32) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[Assignment] Failed to connect to database.")
            throw DBController.DBError()
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
                UPDATE assignment
                SET id = ?, device_uuid = ?, device_group_name = ?, instance_name = ?,
                    source_instance_name = ?, time = ?, date = ?, enabled = ?
                WHERE id = ?
            """
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(id ?? oldId)
        mysqlStmt.bindParam(deviceUUID)
        mysqlStmt.bindParam(deviceGroupName)
        mysqlStmt.bindParam(instanceName)
        mysqlStmt.bindParam(sourceInstanceName)
        mysqlStmt.bindParam(time)
        mysqlStmt.bindParam(date?.toString())
        mysqlStmt.bindParam(enabled)
        mysqlStmt.bindParam(oldId)

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
            INSERT INTO assignment (device_uuid, device_group_name, instance_name,
                                    source_instance_name, time, date, enabled)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """

        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(deviceUUID)
        mysqlStmt.bindParam(deviceGroupName)
        mysqlStmt.bindParam(instanceName)
        mysqlStmt.bindParam(sourceInstanceName)
        mysqlStmt.bindParam(time)
        mysqlStmt.bindParam(date?.toString())
        mysqlStmt.bindParam(enabled)

        guard mysqlStmt.execute() else {
            Log.error(message: "[Assignment] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }

    public static func delete(mysql: MySQL?=nil, id: UInt32) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[Assignment] Failed to connect to database.")
            throw DBController.DBError()
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            DELETE FROM assignment
            WHERE id = ?
        """

        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(id)

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
            SELECT id, device_uuid, device_group_name, instance_name, source_instance_name, time, date, enabled
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
            let id = result[0] as! UInt32
            let deviceUUID = result[1] as? String
            let deviceGroupName = result[2] as? String
            let instanceName = result[3] as! String
            let sourceTnstanceName = result[4] as? String
            let time = result[5] as! UInt32
            let date = (result[6] as? String)?.toDate()
            let enabledInt = result[7] as? UInt8
            let enabled = enabledInt?.toBool() ?? true

            assignments.append(Assignment(
                id: id,
                instanceName: instanceName,
                sourceInstanceName: sourceTnstanceName,
                deviceUUID: deviceUUID,
                deviceGroupName: deviceGroupName,
                time: time,
                date: date,
                enabled: enabled
            ))
        }
        return assignments

    }

    public static func getByUUID(mysql: MySQL?=nil, id: UInt32) throws -> Assignment? {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[Assignment] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
            SELECT id, device_uuid, device_group_name, instance_name, source_instance_name, time, date, enabled
            FROM assignment
            WHERE id = ?
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(id)

        guard mysqlStmt.execute() else {
            Log.error(message: "[Assignment] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }

        let result = results.next()!
        let id = result[0] as! UInt32
        let deviceUUID = result[1] as? String
        let deviceGroupName = result[2] as? String
        let instanceName = result[3] as! String
        let sourceTnstanceName = result[4] as? String
        let time = result[5] as! UInt32
        let date = (result[6] as? String)?.toDate()
        let enabledInt = result[7] as? UInt8
        let enabled = enabledInt?.toBool() ?? true

        return Assignment(
            id: id,
            instanceName: instanceName,
            sourceInstanceName: sourceTnstanceName,
            deviceUUID: deviceUUID,
            deviceGroupName: deviceGroupName,
            time: time,
            date: date,
            enabled: enabled
        )
    }

    static func == (lhs: Assignment, rhs: Assignment) -> Bool {
        return lhs.id == rhs.id
    }

}
