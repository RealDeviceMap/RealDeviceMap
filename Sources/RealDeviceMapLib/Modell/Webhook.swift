//
// Created by fabio on 21.10.21.
//
//  swiftlint:disable force_cast

import Foundation
import PerfectMySQL
import PerfectLib

public class Webhook {

    var name: String
    var url: String
    var delay: Double
    var types: [WebhookType]
    var data: [String: Any]
    var enabled: Bool

    public init(name: String, url: String, delay: Double, types: [WebhookType], data: [String: Any], enabled: Bool) {
        self.name = name
        self.url = url
        self.delay = delay
        self.types = types
        self.data = data
        self.enabled = enabled
    }

    func create(mysql: MySQL? = nil) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[WEBHOOK] Failed to connect to database.")
            throw DBController.DBError()
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
                      INSERT INTO webhook (name, url, delay, types, data, enabled)
                      VALUES (?, ?, ?, ?, ?, ?)
                  """

        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)
        mysqlStmt.bindParam(url)
        mysqlStmt.bindParam(delay)
        mysqlStmt.bindParam(try types.map({$0.rawValue}).jsonEncodedString())
        mysqlStmt.bindParam(try data.jsonEncodedString())
        mysqlStmt.bindParam(enabled)

        guard mysqlStmt.execute() else {
            Log.error(message: "[WEBHOOK] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }

    func save(mysql: MySQL? = nil, oldName: String) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[WEBHOOK] Failed to connect to database.")
            throw DBController.DBError()
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
                      UPDATE webhook
                      SET name = ?, url = ?, delay = ?, types = ?, data = ?, enabled = ?
                      WHERE name = ?
                  """

        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)
        mysqlStmt.bindParam(url)
        mysqlStmt.bindParam(delay)
        mysqlStmt.bindParam(try types.map({$0.rawValue}).jsonEncodedString())
        mysqlStmt.bindParam(try data.jsonEncodedString())
        mysqlStmt.bindParam(enabled)
        mysqlStmt.bindParam(oldName)

        guard mysqlStmt.execute() else {
            Log.error(message: "[WEBHOOK] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }

    public static func delete(mysql: MySQL? = nil, name: String) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[WEBHOOK] Failed to connect to database.")
            throw DBController.DBError()
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
                      DELETE FROM webhook
                      WHERE name = ?
                  """

        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)

        guard mysqlStmt.execute() else {
            Log.error(message: "[WEBHOOK] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }

    public static func getAll(mysql: MySQL? = nil, getData: Bool = true) throws -> [Webhook] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[WEBHOOK] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
                      SELECT name, url, delay, types, enabled \(getData ? ", data" : "")
                      FROM webhook
                  """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        guard mysqlStmt.execute() else {
            Log.error(message: "[WEBHOOK] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var webhooks = [Webhook]()
        while let result = results.next() {
            let name = result[0] as! String
            let url = result[1] as! String
            let delay = result[2] as! Double
            let types = ((result[3] as? String)?.jsonDecodeForceTry() as? [String])?
                .compactMap({WebhookType(rawValue: $0) }) ?? [WebhookType]()
            let enabledInt = result[4] as? UInt8
            let enabled = enabledInt?.toBool() ?? false
            let data: [String: Any]
            if getData {
                data = (result[5] as! String).jsonDecodeForceTry() as? [String: Any] ?? [:]
            } else {
                data = [:]
            }
            webhooks.append(Webhook(name: name, url: url, delay: delay, types: types, data: data, enabled: enabled))
        }
        return webhooks

    }

    public static func getByName(mysql: MySQL? = nil, name: String) throws -> Webhook? {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[WEBHOOK] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
                      SELECT url, delay, types, enabled, data
                      FROM webhook
                      WHERE name = ?
                  """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)

        guard mysqlStmt.execute() else {
            Log.error(message: "[WEBHOOK] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }

        let result = results.next()!
        let url = result[0] as! String
        let delay = result[1] as! Double
        let types = ((result[2] as? String)?.jsonDecodeForceTry() as? [String])?
            .compactMap({WebhookType(rawValue: $0) }) ?? [WebhookType]()
        let enabledInt = result[3] as? UInt8
        let enabled = enabledInt?.toBool() ?? false
        let data = (result[4] as! String).jsonDecodeForceTry() as? [String: Any] ?? [:]
        return Webhook(name: name, url: url, delay: delay, types: types, data: data, enabled: enabled)

    }
}

public enum WebhookType: String, CaseIterable {
    case pokemon, raid, egg, pokestop, lure, invasion, quest, gym, weather, account
}
