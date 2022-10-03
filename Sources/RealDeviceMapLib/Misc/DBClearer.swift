//
// Created by fabio on 13.09.22.
//

import Foundation
import PerfectLib
import PerfectMySQL
import PerfectThread

public class DBClearer {

    public static let global = DBClearer()

    internal static var interval: Double = 300
    internal static var keepTime: Double = 3600
    internal static var batchSize: UInt = 250

    private let clearerThread: ThreadQueue

    private init() {
        clearerThread = Threading.getQueue(name: "DBClearer", type: .serial)
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[DBClearer] Failed to connect to database.")
            Threading.destroyQueue(clearerThread)
            return
        }
        clearerThread.dispatch {
            while true {
                Threading.sleep(seconds: DBClearer.interval)
                Log.debug(message: "[DBClearer] Start clearing.")
                let start = Date()
                self.clear(mysql: mysql, table: "pokemon", expireKeyword: "expire_timestamp")
                Threading.sleep(seconds: 1.0)
                self.clear(mysql: mysql, table: "incident", expireKeyword: "expiration")
                Log.debug(message: "[DBClearer] Cleared in \(String(format: "%.3f", Date().timeIntervalSince(start)))s")
            }
        }
    }

    private func clear(mysql: MySQL, table: String, expireKeyword: String) {
        var affectedRows: UInt = 0
        var totalRows: UInt = 0
        let sql = """
                  DELETE FROM \(table)
                  WHERE \(expireKeyword) <= UNIX_TIMESTAMP() - ?
                  LIMIT ?;
                  """

        repeat {
            let mysqlStmt = MySQLStmt(mysql)
            _ = mysqlStmt.prepare(statement: sql)
            mysqlStmt.bindParam(DBClearer.keepTime)
            mysqlStmt.bindParam(DBClearer.batchSize)

            guard mysqlStmt.execute() else {
                Log.error(message: "[DBClearer] Failed to execute query 'DELETE LIMIT'. " +
                    mysqlStmt.errorMessage())
                break
            }
            affectedRows = mysqlStmt.affectedRows()
            totalRows &+= affectedRows
            // wait between batches
            Threading.sleep(seconds: 0.2)
        } while affectedRows == DBClearer.batchSize
        Log.debug(message: "[DBClearer] Cleared \(totalRows) in DB table '\(table)'")
    }
}
