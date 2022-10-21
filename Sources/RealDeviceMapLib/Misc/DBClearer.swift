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
        let statsEnabled: Bool = ConfigLoader.global.getConfig(type: .statsEnabled)
        if statsEnabled {
            Log.info(message: "[DBClearer] Create pokemon history for stats")
        } else {
            Log.info(message: "[DBClearer] Pokemon config: " +
                "keep \(keepTime)s, batches of \(batchSize) every \(interval)s")
        }
        Threading.getQueue(name: "DatabaseArchiver", type: .serial).dispatch {
            while true {
                Threading.sleep(seconds: interval)
                guard let mysql = DBController.global.mysql else {
                    Log.error(message: "[DBClearer] [DatabaseArchiver] Failed to connect to database.")
                    continue
                }
                let start = Date()
                let affectedRows: UInt
                if statsEnabled {
                    affectedRows = createStatsAndArchive(mysql: mysql)
                } else {
                    affectedRows = clearPokemon(mysql: mysql, keepTime: keepTime, batchSize: batchSize)
                }
                Log.debug(message: "[DBClearer] [DatabaseArchiver] Archive of pokemon table took " +
                    "\(String(format: "%.3f", Date().timeIntervalSince(start)))s (\(affectedRows) rows)")
            }
        }
    }

    static func startIncidentExpiry() {
        let interval = (ConfigLoader.global.getConfig(type: .dbClearerIncidentInterval) as Int).toDouble()
        let keepTime = (ConfigLoader.global.getConfig(type: .dbClearerIncidentKeepTime) as Int).toDouble()
        let batchSize = (ConfigLoader.global.getConfig(type: .dbClearerIncidentBatchSize) as Int).toUInt()
        Log.info(message: "[DBClearer] Incident config: keep \(keepTime)s, batches of \(batchSize) every \(interval)s")
        Threading.getQueue(name: "IncidentExpiry", type: .serial).dispatch {
            while true {
                Threading.sleep(seconds: interval)
                guard let mysql = DBController.global.mysql else {
                    Log.error(message: "[DBClearer] [IncidentExpiry] Failed to connect to database.")
                    continue
                }
                let start = Date()
                let affectedRows = clearIncident(mysql: mysql, keepTime: keepTime, batchSize: batchSize)
                Log.debug(message: "[DBClearer] [IncidentExpiry] Cleanup of incident table took " +
                    "\(String(format: "%.3f", Date().timeIntervalSince(start)))s (\(affectedRows) rows)")
            }
        }
    }

    private static func clearPokemon(mysql: MySQL, keepTime: Double, batchSize: UInt) -> UInt {
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
        return totalRows
    }

    private static func createStatsAndArchive(mysql: MySQL) -> UInt {
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: "CALL createStatsAndArchive();")
        guard mysqlStmt.execute() else {
            Log.error(message: "[DBClearer] Failed to execute query 'createStatsAndArchive'. " +
                mysqlStmt.errorMessage())
            return 0
        }
        return mysqlStmt.affectedRows()
    }

    private static func clearIncident(mysql: MySQL, keepTime: Double, batchSize: UInt) -> UInt {
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
        return totalRows
    }
}
