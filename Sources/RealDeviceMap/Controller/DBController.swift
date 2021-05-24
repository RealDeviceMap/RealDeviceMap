//
//  DBController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity

import Foundation
import PerfectLib
import PerfectMySQL
import PerfectCRUD
import PerfectSessionMySQL
import PerfectThread

class DBController {

    class DBError: Error {}

    public private(set) static var global = DBController()

    private var multiStatement = false
    private var asRoot = false

    public var mysql: MySQL? {
        let mysql = MySQL()
        mysql.setOption(.MYSQL_SET_CHARSET_NAME, "utf8mb4")
        let connected: Bool
        if asRoot {
            connected = mysql.connect(host: host, user: rootUsername, password: rootPassword, db: database, port: port)
        } else {
            connected = mysql.connect(host: host, user: username, password: password, db: database, port: port)
        }
        if connected {
            if multiStatement {
                mysql.setServerOption(.MYSQL_OPTION_MULTI_STATEMENTS_ON)
            } else {
                mysql.setServerOption(.MYSQL_OPTION_MULTI_STATEMENTS_OFF)
            }
            return mysql
        } else {
            Log.error(message: "[DBController] Failed to connect to Database: (\(mysql.errorMessage())")
            return nil
        }
    }

    private let database: String
    private let host: String
    private let port: UInt32
    private let username: String
    private let password: String?
    private let rootUsername: String
    private let rootPassword: String?

    private var newestDBVersion: Int {
        let fileManager = FileManager.default
        let migrationsRoot = "\(projectroot)/resources/migrations/"
        var current = 0

        while fileManager.fileExists(atPath: migrationsRoot + "\(current + 1).sql") {
            current += 1
        }

        return current
    }

    public func getValueForKey(key: String, mysql: MySQL?=nil) throws -> String? {

        guard let mysql = mysql ?? self.mysql else {
            Log.error(message: "[DBController] Failed to connect to database.")
            throw DBError()
        }

        let sql = """
            SELECT `value`
            FROM metadata
            WHERE `key` = ?
            LIMIT 1;
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(key)

        guard mysqlStmt.execute() else {
            Log.error(message: "[DBController] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 1 {
            return results.next()![0] as? String
        } else {
            return nil
        }

    }

    public func setValueForKey(key: String, value: String, mysql: MySQL?=nil) throws {

        guard let mysql = mysql ?? self.mysql else {
            Log.error(message: "[DBController] Failed to connect to database.")
            throw DBError()
        }

        let sql = """
            INSERT INTO metadata (`key`, `value`)
            VALUES(?, ?)
            ON DUPLICATE KEY UPDATE
            value=VALUES(value)
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(key)
        mysqlStmt.bindParam(value)

        guard mysqlStmt.execute() else {
            Log.error(message: "[DBController] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBError()
        }
    }

    private init() {

        Log.info(message: "[DBController] Initializing database")

        let enviroment = ProcessInfo.processInfo.environment
        database = enviroment["DB_DATABASE"] ?? "rdmdb"
        host = enviroment["DB_HOST"] ?? "127.0.0.1"
        port = UInt32(enviroment["DB_PORT"] ?? "") ?? 3306
        username = enviroment["DB_USERNAME"] ?? "rdmuser"
        password = enviroment["DB_PASSWORD"]
        rootUsername = enviroment["DB_ROOT_USERNAME"] ?? "root"
        rootPassword = enviroment["DB_ROOT_PASSWORD"]

        MySQLSessionConnector.host = host
        MySQLSessionConnector.port = Int(port)
        MySQLSessionConnector.username = username
        MySQLSessionConnector.password = password ?? ""
        MySQLSessionConnector.database = database
        MySQLSessionConnector.table = "web_session"

        setup()

        Log.info(message: "[DBController] Done")
    }

    private func setup() {

        asRoot = true
        multiStatement = true

        var count = 1
        var done = false
        var mysql: MySQL!
        while !done {
            guard let mysqlTemp = self.mysql else {
                let message = "Failed to connect to database (as \(self.rootUsername)) while initializing. " +
                              "Try: \(count)"
                Log.warning(message: "[DBController] " + message)
                count += 1
                Threading.sleep(seconds: 2.5)
                continue
            }
            done = true
            asRoot = false
            guard self.mysql != nil else {
                let message = "Failed to connect to database (as \(self.username)) while initializing."
                Log.critical(message: "[DBController] " + message)
                Log.info(message: "[DBController] Threading.sleeping indefinitely")
                Threading.sleep(seconds: Double(UInt32.max))
                fatalError(message)
            }
            asRoot = true
            mysql = mysqlTemp
        }

        var version = 0

        let versionSQL = "SELECT @@VERSION_COMMENT"
        guard mysql.query(statement: versionSQL),
            let versionResults = mysql.storeResults(),
            let versionResult = versionResults.next()?[0] else {
            let message = "Failed to get db type: (\(mysql.errorMessage())"
            Log.critical(message: "[DBController] " + message)
            Log.info(message: "[DBController] Threading.sleeping indefinitely")
            Threading.sleep(seconds: Double(UInt32.max))
            fatalError(message)
        }
        if versionResult.lowercased().contains(string: "mariadb") {
            let stDistancephereSQL = """
                CREATE FUNCTION IF NOT EXISTS `ST_Distance_Sphere`(`pt1` POINT, `pt2` POINT) RETURNS
                decimal(10,2)
                NO SQL
                DETERMINISTIC
                BEGIN
                return 6371000 * 2 * ASIN(SQRT(
                    POWER(SIN((ST_Y(pt2) - ST_Y(pt1)) * pi()/180 / 2),
                    2) + COS(ST_Y(pt1) * pi()/180 ) * COS(ST_Y(pt2) *
                    pi()/180) * POWER(SIN((ST_X(pt2) - ST_X(pt1)) *
                    pi()/180 / 2), 2) ));
                END
            """
            guard mysql.query(statement: stDistancephereSQL) else {
                let message = "Failed to create ST_Distance_Sphere function: (\(mysql.errorMessage())"
                Log.critical(message: "[DBController] " + message)
                Log.info(message: "[DBController] Threading.sleeping indefinitely")
                Threading.sleep(seconds: Double(UInt32.max))
                fatalError(message)
            }
        }

        let createMetadataTableSQL = """
            CREATE TABLE IF NOT EXISTS metadata (
                `key` VARCHAR(50) PRIMARY KEY NOT NULL,
                `value` VARCHAR(50) DEFAULT NULL
            );
        """

        guard mysql.query(statement: createMetadataTableSQL) else {
            let message = "Failed to create metadata table: (\(mysql.errorMessage())"
            Log.critical(message: "[DBController] " + message)
            Log.info(message: "[DBController] Threading.sleeping indefinitely")
            Threading.sleep(seconds: Double(UInt32.max))
            fatalError(message)
        }

        let getDBVersionSQL = """
            SELECT `value`
            FROM metadata
            WHERE `key` = "DB_VERSION"
            LIMIT 1;
        """

        guard mysql.query(statement: getDBVersionSQL) else {
            let message = "Failed to get current database version: (\(mysql.errorMessage())"
            Log.critical(message: "[DBController] " + message)
            Log.info(message: "[DBController] Threading.sleeping indefinitely")
            Threading.sleep(seconds: Double(UInt32.max))
            fatalError(message)
        }

        let getDBVersionResult = mysql.storeResults()
        if getDBVersionResult != nil {
            let element = getDBVersionResult!.next()
            if element != nil {
                version = Int(String(element![0]!))!
            }
        }

        migrate(mysql: mysql, fromVersion: version, toVersion: newestDBVersion)
        multiStatement = false
        asRoot = false

    }

    private func migrate(mysql: MySQL, fromVersion: Int, toVersion: Int) {
        if fromVersion < toVersion {
            Log.info(message: "[DBController] Migrating database to version \(fromVersion + 1)")

            let uuidString = Foundation.UUID().uuidString
            let backupsDir = Dir("\(projectroot)/backups")
            let backupFileSchema = File(backupsDir.path + uuidString + ".schema.sql")
            let backupFileTrigger = File(backupsDir.path + uuidString + ".trigger.sql")
            let backupFileData = File(backupsDir.path + uuidString + ".data.sql")

            if ProcessInfo.processInfo.environment["NO_BACKUP"] == nil {

                let allTables = [
                    "account": true,
                    "assignment": true,
                    "device": true,
                    "device_group": true,
                    "discord_rule": true,
                    "group": true,
                    "gym": true,
                    "instance": true,
                    "metadata": true,
                    "pokemon": true,
                    "pokemon_stats": false,
                    "pokemon_shiny_stats": false,
                    "pokestop": true,
                    "quest_stats": false,
                    "raid_stats": false,
                    "invasion_stats": false,
                    "s2cell": true,
                    "spawnpoint": true,
                    "token": true,
                    "user": true,
                    "weather": true,
                    "web_session": true
                ]

                var tablesShema = ""
                var tablesData = ""

                let allTablesSQL = """
                    SHOW TABLES
                """

                let mysqlStmtTables = MySQLStmt(mysql)
                _ = mysqlStmtTables.prepare(statement: allTablesSQL)

                guard mysqlStmtTables.execute() else {
                    let message = "Failed to execute query. (\(mysqlStmtTables.errorMessage())"
                    Log.critical(message: "[DBController] " + message)
                    Log.info(message: "[DBController] Threading.sleeping indefinitely")
                    Threading.sleep(seconds: Double(UInt32.max))
                    fatalError(message)
                }
                let results = mysqlStmtTables.results()
                while let result = results.next() {
                    if let name = result[0] as? String {
                        if let withData = allTables[name] {
                            tablesShema += " \(name)"
                            if withData {
                                tablesData += " \(name)"
                            }
                        }
                    }
                }

                Log.info(message: "[DBController] Creating backup \(uuidString)")
                #if os(macOS)
                let mysqldumpCommand = "/usr/local/opt/mysql@5.7/bin/mysqldump"
                #else
                let mysqldumpCommand = "/usr/bin/mysqldump"
                #endif

                // Schema
                //  swiftlint:disable:next line_length
                let commandSchema = Shell("bash", "-c", mysqldumpCommand + " --set-gtid-purged=OFF --skip-triggers --add-drop-table --skip-routines --no-data \(self.database) \(tablesShema) -h \(self.host) -P \(self.port) -u \(self.rootUsername) -p\(self.rootPassword?.stringByReplacing(string: "\"", withString: "\\\"") ?? "") > \(backupFileSchema.path)")
                let resultSchema = commandSchema.runError()
                if resultSchema == nil ||
                   resultSchema!.stringByReplacing(
                    string: "mysqldump: [Warning] Using a password on the command line interface can be insecure.",
                    withString: ""
                   ).trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                    let message = "Failed to create Command Backup: \(resultSchema as Any)"
                    Log.critical(message: "[DBController] " + message)
                    Log.info(message: "[DBController] Threading.sleeping indefinitely")
                    Threading.sleep(seconds: Double(UInt32.max))
                    fatalError(message)
                }

                // Trigger
                //  swiftlint:disable:next line_length
                let commandTrigger = Shell("bash", "-c", mysqldumpCommand + " --set-gtid-purged=OFF --triggers --no-create-info --no-data --skip-routines \(self.database) \(tablesShema)  -h \(self.host) -P \(self.port) -u \(self.rootUsername) -p\(self.rootPassword?.stringByReplacing(string: "\"", withString: "\\\"") ?? "") > \(backupFileTrigger.path)")
                let resultTrigger = commandTrigger.runError()
                if resultTrigger == nil ||
                   resultTrigger!.stringByReplacing(
                    string: "mysqldump: [Warning] Using a password on the command line interface can be insecure.",
                    withString: ""
                   ).trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                    let message = "Failed to create Command Backup \(resultTrigger as Any)"
                    Log.critical(message: "[DBController] " + message)
                    Log.info(message: "[DBController] Threading.sleeping indefinitely")
                    Threading.sleep(seconds: Double(UInt32.max))
                    fatalError(message)
                }

                // Data
                //  swiftlint:disable:next line_length
                let commandData = Shell("bash", "-c", mysqldumpCommand + " --set-gtid-purged=OFF --skip-triggers --skip-routines --no-create-info --skip-routines \(self.database) \(tablesData)  -h \(self.host) -P \(self.port) -u \(self.rootUsername) -p\(self.rootPassword?.stringByReplacing(string: "\"", withString: "\\\"") ?? "") > \(backupFileData.path)")
                let resultData = commandData.runError()
                if resultData == nil ||
                   resultData!.stringByReplacing(
                    string: "mysqldump: [Warning] Using a password on the command line interface can be insecure.",
                    withString: ""
                   ).trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                    let message = "Failed to create Data Backup \(resultData as Any)"
                    Log.critical(message: "[DBController] " + message)
                    Log.info(message: "[DBController] Threading.sleeping indefinitely")
                    Threading.sleep(seconds: Double(UInt32.max))
                    fatalError(message)
                }

            }

            Log.info(message: "[DBController] Migrating...")

            var migrateSQL: String
            let sqlFile = File("\(projectroot)/resources/migrations/\(fromVersion + 1).sql")
            do {
                try sqlFile.open(.read)
                try migrateSQL = sqlFile.readString()
                sqlFile.close()
            } catch {
                sqlFile.close()
                let message = "Migration Failed: (\(mysql.errorMessage()))"
                Log.critical(message: "[DBController] " + message)
                Log.info(message: "[DBController] Threading.sleeping indefinitely")
                Threading.sleep(seconds: Double(UInt32.max))
                fatalError(message)
            }

            for sql in migrateSQL.split(separator: ";") {
                let sql = sql.replacingOccurrences(of: "&semi", with: ";")
                          .trimmingCharacters(in: .whitespacesAndNewlines)
                if sql != "" {
                    guard mysql.query(statement: sql) else {
                        let message = "Migration Failed: (\(mysql.errorMessage()))"
                        Log.critical(message: "[DBController] " + message)
                        Log.info(message: "[DBController] Threading.sleeping indefinitely")
                        Threading.sleep(seconds: Double(UInt32.max))
                        fatalError(message)
                    }
                }
            }

            while mysql.moreResults() {
                _ = mysql.nextResult()
            }

            let updateVersionSQL = """
                INSERT INTO metadata (`key`, `value`)
                VALUES("DB_VERSION", \(fromVersion + 1))
                ON DUPLICATE KEY UPDATE `value` = \(fromVersion + 1);
            """

            guard mysql.query(statement: updateVersionSQL) else {
                let message = "Migration Failed: (\(mysql.errorMessage()))"
                Log.critical(message: "[DBController] " + message)
                Log.info(message: "[DBController] Threading.sleeping indefinitely")
                Threading.sleep(seconds: Double(UInt32.max))
                fatalError(message)
            }

            Log.info(message: "[DBController] Migration successful")
            migrate(mysql: mysql, fromVersion: fromVersion + 1, toVersion: toVersion)
        }
    }

}
