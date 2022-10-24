//
// Created by fabio on 13.09.22.
//

import Foundation
import PerfectLib
import PerfectMySQL
import PerfectThread

public class DBClearer {

    static func startDatabaseArchiver() {
        let interval = (ConfigLoader.global.getConfig(type: .dbClearerPokemonInterval) as Int).toDouble()
        let keepTime = (ConfigLoader.global.getConfig(type: .dbClearerPokemonKeepTime) as Int).toDouble()
        let batchSize = (ConfigLoader.global.getConfig(type: .dbClearerPokemonBatchSize) as Int).toUInt()
        let statsEnabled = false // MARK: add config type
        let message = statsEnabled ? "Created Stats and Archive in" : "Cleared in"

        Threading.getQueue(name: "DatabaseArchiver", type: .serial).dispatch {
            while true {
                Threading.sleep(seconds: interval)
                guard let mysql = DBController.global.mysql else {
                    Log.error(message: "[DBClearer] [DatabaseArchiver] Failed to connect to database.")
                    continue
                }
                let start = Date()
                if statsEnabled {
                    let mysqlStmt = MySQLStmt(mysql)
                    _ = mysqlStmt.prepare(statement: "CALL createStatsAndArchive();")
                } else {
                    clearPokemon(mysql: mysql, keepTime: keepTime, batchSize: batchSize)
                }
                Log.debug(message: "[DBClearer] [DatabaseArchiver] \(message) " +
                    "\(String(format: "%.3f", Date().timeIntervalSince(start)))s")
            }
        }
    }

    static func startIncidentExpiry() {
        let interval = (ConfigLoader.global.getConfig(type: .dbClearerIncidentInterval) as Int).toDouble()
        let keepTime = (ConfigLoader.global.getConfig(type: .dbClearerIncidentKeepTime) as Int).toDouble()
        let batchSize = (ConfigLoader.global.getConfig(type: .dbClearerIncidentBatchSize) as Int).toUInt()

        Threading.getQueue(name: "IncidentExpiry", type: .serial).dispatch {
            while true {
                Threading.sleep(seconds: interval)
                guard let mysql = DBController.global.mysql else {
                    Log.error(message: "[DBClearer] [IncidentExpiry] Failed to connect to database.")
                    continue
                }
                let start = Date()
                clearIncident(mysql: mysql, keepTime: keepTime, batchSize: batchSize)
                Log.debug(message: "[DBClearer] [IncidentExpiry] Cleared in " +
                    "\(String(format: "%.3f", Date().timeIntervalSince(start)))s")
            }
        }
    }

    private static func clearPokemon(mysql: MySQL, keepTime: Double, batchSize: UInt) {
        var affectedRows: UInt = 0
        var totalRows: UInt = 0
        let sql = """
                  DELETE FROM pokemon
                  WHERE expire_timestamp <= UNIX_TIMESTAMP() - ?
                  LIMIT ?;
                  """

        repeat {
            let mysqlStmt = MySQLStmt(mysql)
            _ = mysqlStmt.prepare(statement: sql)
            mysqlStmt.bindParam(keepTime)
            mysqlStmt.bindParam(batchSize)

            guard mysqlStmt.execute() else {
                Log.error(message: "[DBClearer] Failed to execute query 'DELETE LIMIT pokemon'. " +
                    mysqlStmt.errorMessage())
                break
            }
            affectedRows = mysqlStmt.affectedRows()
            totalRows &+= affectedRows
            // wait between batches
            Threading.sleep(seconds: 0.2)
        } while affectedRows == batchSize
        Log.info(message: "[DBClearer] Cleared \(totalRows) in DB table 'pokemon'")
    }

    private static func clearIncident(mysql: MySQL, keepTime: Double, batchSize: UInt) {
        var affectedRows: UInt = 0
        var totalRows: UInt = 0
        let sql = """
                  DELETE FROM incident
                  WHERE expiration <= UNIX_TIMESTAMP() - ?
                  LIMIT ?;
                  """

        repeat {
            let mysqlStmt = MySQLStmt(mysql)
            _ = mysqlStmt.prepare(statement: sql)
            mysqlStmt.bindParam(keepTime)
            mysqlStmt.bindParam(batchSize)

            guard mysqlStmt.execute() else {
                Log.error(message: "[DBClearer] Failed to execute query 'DELETE LIMIT incident'. " +
                    mysqlStmt.errorMessage())
                break
            }
            affectedRows = mysqlStmt.affectedRows()
            totalRows &+= affectedRows
            // wait between batches
            Threading.sleep(seconds: 0.2)
        } while affectedRows == batchSize
        Log.info(message: "[DBClearer] Cleared \(totalRows) in DB table 'incident'")
    }
}
