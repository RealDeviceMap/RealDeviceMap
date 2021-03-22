//
//  Instance.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 29.09.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast

import Foundation
import PerfectLib
import PerfectMySQL

class Instance: Hashable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    enum InstanceType: String {
        case circlePokemon = "circle_pokemon"
        case circleSmartPokemon = "circle_smart_pokemon"
        case circleRaid = "circle_raid"
        case circleSmartRaid = "circle_smart_raid"
        case autoQuest = "auto_quest"
        case pokemonIV = "pokemon_iv"
        case leveling = "leveling"

        static func fromString(_ value: String) -> InstanceType? {
            if value.lowercased() == "circle_pokemon" || value.lowercased() == "circlepokemon" {
                return .circlePokemon
            } else if value.lowercased() == "circle_smart_pokemon" || value.lowercased() == "circlesmartpokemon" {
                return .circleSmartPokemon
            } else if value.lowercased() == "circle_raid" || value.lowercased() == "circleraid" {
                return .circleRaid
            } else if value.lowercased() == "circle_smart_raid" || value.lowercased() == "circlesmartraid" {
                return .circleSmartRaid
            } else if value.lowercased() == "auto_quest" || value.lowercased() == "autoquest" {
                return .autoQuest
            } else if value.lowercased() == "pokemon_iv" || value.lowercased() == "pokemoniv" {
                return .pokemonIV
            } else if value.lowercased() == "leveling" {
                return .leveling
            } else {
                return nil
            }
        }
    }

    var name: String
    var type: InstanceType
    var data: [String: Any]
    var count: Int64

    init(name: String, type: InstanceType, data: [String: Any], count: Int64) {
        self.name = name
        self.type = type
        self.data = data
        self.count = count
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
        mysqlStmt.bindParam(try data.jsonEncodedString())

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
        mysqlStmt.bindParam(try data.jsonEncodedString())
        mysqlStmt.bindParam(name)
        mysqlStmt.bindParam(type.rawValue)
        mysqlStmt.bindParam(oldName)

        guard mysqlStmt.execute() else {
            Log.error(message: "[INSTANCE] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }

    public static func getAll(mysql: MySQL?=nil, getData: Bool=true) throws -> [Instance] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[INSTANCE] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
            SELECT name, type, count \(getData ? ", data" : "")
            FROM instance AS inst
            LEFT JOIN (
              SELECT COUNT(instance_name) AS count, instance_name
              FROM device
              GROUP BY instance_name
            ) devices ON (inst.name = devices.instance_name)
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
            let count = result[2] as! Int64? ?? 0
            let data: [String: Any]
            if getData {
                data = (result[3] as! String).jsonDecodeForceTry() as? [String: Any] ?? [:]
            } else {
                data = [:]
            }
            instances.append(Instance(name: name, type: type, data: data, count: count))
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
            let data = (result[1] as! String).jsonDecodeForceTry() as? [String: Any] ?? [:]
        return Instance(name: name, type: type, data: data, count: 0)

    }

    static func == (lhs: Instance, rhs: Instance) -> Bool {
        return lhs.name == rhs.name
    }

}
