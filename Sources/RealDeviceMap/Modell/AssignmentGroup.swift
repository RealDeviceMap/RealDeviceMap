//
//  AssignmentGroup.swift
//  RealDeviceMap
//
//  Created by petap0w on 3/25/21.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast

import Foundation
import PerfectLib
import PerfectMySQL

class AssignmentGroup: Hashable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    var name: String
    var assignmentIDs: [UInt32]

    init(name: String, assignmentIDs: [UInt32]) {
        self.name = name
        self.assignmentIDs = assignmentIDs
    }

    public func create(mysql: MySQL?=nil) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[ASSIGNMENTGROUP] Failed to connect to database.")
            throw DBController.DBError()
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            INSERT INTO assignment_group (name)
            VALUES (?)
        """
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)

        guard mysqlStmt.execute() else {
            Log.error(message: "[ASSIGNMENTGROUP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        try createLinkings(mysql: mysql)
    }

    private func createLinkings(mysql: MySQL) throws {
        if assignmentIDs.isEmpty {
            return
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            INSERT INTO assignment_group_assignment (assignment_group_name, assignment_id)
            VALUES \(String(String.init(repeating: "(?, ?),", count: assignmentIDs.count).dropLast()))
        """
        _ = mysqlStmt.prepare(statement: sql)
        for assignmentID in assignmentIDs {
            mysqlStmt.bindParam(name)
            mysqlStmt.bindParam(assignmentID)
        }

        guard mysqlStmt.execute() else {
           Log.error(message: "[ASSIGNMENTGROUP] Failed to execute query. (\(mysqlStmt.errorMessage())")
           throw DBController.DBError()
        }
    }

    public static func delete(mysql: MySQL?=nil, name: String) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[ASSIGNMENTGROUP] Failed to connect to database.")
            throw DBController.DBError()
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            DELETE FROM assignment_group
            WHERE name = ?
        """

        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)

        guard mysqlStmt.execute() else {
            Log.error(message: "[ASSIGNMENTGROUP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

    }

    public func update(mysql: MySQL?=nil, oldName: String) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[ASSIGNMENTGROUP] Failed to connect to database.")
            throw DBController.DBError()
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            UPDATE assignment_group
            SET name = ?
            WHERE name = ?
        """

        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)
        mysqlStmt.bindParam(oldName)

        guard mysqlStmt.execute() else {
            Log.error(message: "[ASSIGNMENTGROUP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        try deleteLinkings(mysql: mysql)
        try createLinkings(mysql: mysql)
    }

    private func deleteLinkings(mysql: MySQL) throws {
        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            DELETE FROM assignment_group_assignment
            WHERE assignment_group_name = ?
        """
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)

        guard mysqlStmt.execute() else {
           Log.error(message: "[ASSIGNMENTGROUP] Failed to execute query. (\(mysqlStmt.errorMessage())")
           throw DBController.DBError()
        }
    }

    public static func getAll(mysql: MySQL?=nil) throws -> [AssignmentGroup] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[ASSIGNMENTGROUP] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
            SELECT ag.name, IF(COUNT(aga.assignment_id) > 0,JSON_ARRAYAGG(aga.assignment_id), '[]') as assignment_ids
            FROM assignment_group ag
            LEFT JOIN assignment_group_assignment aga on ag.name = aga.assignment_group_name
            GROUP by ag.name
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        guard mysqlStmt.execute() else {
            Log.error(message: "[ASSIGNMENTGROUP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var assignmentGroups = [AssignmentGroup]()
        while let result = results.next() {
            let name = result[0] as! String
            let assignmentIDs = ((result[1] as? String)?.jsonDecodeForceTry() as! [Int]).map { UInt32($0) }
            assignmentGroups.append(AssignmentGroup(name: name, assignmentIDs: assignmentIDs))
        }
        return assignmentGroups

    }

    public static func getByName(mysql: MySQL?=nil, name: String) throws -> AssignmentGroup? {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[ASSIGNMENTGROUP] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
            SELECT ag.name, IF(COUNT(aga.assignment_id) > 0,JSON_ARRAYAGG(aga.assignment_id), '[]') as assignment_ids
            FROM assignment_group ag
            LEFT JOIN assignment_group_assignment aga on ag.name = aga.assignment_group_name
            WHERE ag.name = ?
            GROUP by ag.name
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)

        guard mysqlStmt.execute() else {
            Log.error(message: "[ASSIGNMENTGROUP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }

        let result = results.next()!
        let name = result[0] as! String
        let assignmentIDs = ((result[1] as? String)?.jsonDecodeForceTry() as! [Int]).map { UInt32($0) }

        return AssignmentGroup(name: name, assignmentIDs: assignmentIDs)

    }

    static func == (lhs: AssignmentGroup, rhs: AssignmentGroup) -> Bool {
        return lhs.name == rhs.name
    }

}
