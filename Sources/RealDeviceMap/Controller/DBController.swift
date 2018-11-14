//
//  DBController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//

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
        let migrationsRoot = Dir.workingDir.path + "/resources/migrations/"
        var current = 0
        
        while fileManager.fileExists(atPath: migrationsRoot + "\(current + 1).sql") {
            current += 1
        }
        
        return current
    }
    
    public func getValueForKey(key: String) throws -> String? {
        
        guard let mysql = mysql else {
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
    
    public func setValueForKey(key: String, value: String) throws {
        
        guard let mysql = mysql else {
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

        Log.info(message: "[DBController] done")
    }
    
    private func setup() {
        
        asRoot = true
        multiStatement = true
        
        var count = 1
        var done = false
        var mysql: MySQL!
        while !done {
            guard let mysqlTemp = self.mysql else {
                let message = "Failed to connect to database (as \(self.rootUsername)) while initializing. Try: \(count)/10"
                if count == 10 {
                    Log.critical(message: "[DBController] " + message)
                    fatalError(message)
                } else {
                    Log.warning(message: "[DBController] " + message)
                }
                count += 1
                Threading.sleep(seconds: 2.5)
                continue
            }
            done = true
            asRoot = false
            guard self.mysql != nil else {
                let message = "Failed to connect to database (as \(self.username)) while initializing."
                Log.critical(message: "[DBController] " + message)
                fatalError(message)
            }
            asRoot = true
            mysql = mysqlTemp
        }
        
        var version = 0
        
        let createMetadataTableSQL = """
            CREATE TABLE IF NOT EXISTS metadata (
                `key` VARCHAR(50) PRIMARY KEY NOT NULL,
                `value` VARCHAR(50) DEFAULT NULL
            );
        """
        
        guard mysql.query(statement: createMetadataTableSQL) else {
            let message = "Failed to create metadata table: (\(mysql.errorMessage())"
            Log.critical(message: "[DBController] " + message)
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
        
        if version != newestDBVersion {
            try? clearPerms()
        }
    }
    
    private func migrate(mysql: MySQL, fromVersion: Int, toVersion: Int) {
        if fromVersion < toVersion {
            Log.info(message: "[DBController] Migrating database to version \(fromVersion + 1)")
            
            let uuidString = Foundation.UUID().uuidString
            let backupsDir = Dir("backups")
            let backupFile = File(backupsDir.path + "/" + uuidString + ".sql")
            Log.debug(message: "[DBController] Creating backup \(uuidString)")
            #if os(macOS)
            let mysqldumpCommand = "/usr/local/opt/mysql@5.7/bin/mysqldump"
            #else
            let mysqldumpCommand = "/usr/bin/mysqldump"
            #endif
            
            let command = Shell(mysqldumpCommand, "--add-drop-table", self.database, "-h", self.host, "-P", self.port.description, "-u", self.rootUsername, "-p\(self.rootPassword ?? "")")
            var result = command.run()
            if result == nil || result!.trimmingCharacters(in: .whitespacesAndNewlines) == "" {
                let message = "Failed to create Backup"
                Log.critical(message: "[DBController] " + message)
                fatalError(message)
            }
            
            do {
                try backupFile.open(.readWrite)
                try backupFile.write(string: "-- RDM Auto Generated Backup\n")
                try backupFile.write(string: "-- Migration: \(fromVersion) -> \(fromVersion + 1)\n")
                try backupFile.write(string: "-- Date: \(Date())\n")
                try backupFile.write(string: "-- ------------------------------------------------------\n\n")
                try backupFile.write(string: result!)
                backupFile.close()
                result = nil
            } catch {
                let message = "Failed to create Backup)"
                Log.critical(message: "[DBController] " + message)
                fatalError(message)
            }
            
            var migrateSQL: String
            do {
                let sqlFile = File(Dir.workingDir.path + "/resources/migrations/\(fromVersion + 1).sql")
                try sqlFile.open(.read)
                try migrateSQL = sqlFile.readString()
                sqlFile.close()
            } catch {
                let message = "Migration failed: (\(error.localizedDescription))"
                Log.critical(message: "[DBController] " + message)
                fatalError(message)
            }
            
            for sql in migrateSQL.split(separator: ";") {
                let sql = sql.replacingOccurrences(of: "&semi", with: ";").trimmingCharacters(in: .whitespacesAndNewlines)
                if sql != "" {
                    guard mysql.query(statement: sql) else {
                        let message = "Migration Failed: (\(mysql.errorMessage()))"
                        Log.critical(message: "[DBController] " + message)
                        Log.info(message: "[DBController] Rolling back migration. Do not kill RDM!")
                        rollback(backup: backupFile)
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
                fatalError(message)
            }
            
            Log.info(message: "[DBController] Migration successful")
            migrate(mysql: mysql, fromVersion: fromVersion + 1, toVersion: toVersion)
        }
    }
    
    private func rollback(backup: File) {
        let backupSQL: String
        do {
            try backup.open(.read)
            backupSQL = try backup.readString()
        } catch {
            Log.error(message: "[DBController] Failed to read backup! Manual restore required!")
            return
        }

        #if os(macOS)
        let mysqlCommand = "/usr/local/opt/mysql@5.7/bin/mysql"
        #else
        let mysqlCommand = "/usr/bin/mysql"
        #endif

        let command = Shell(mysqlCommand, self.database, "-h", self.host, "-P", self.port.description, "-u", self.rootUsername, "-p\(self.rootPassword ?? "")")
        let inputPipe = Pipe()
        let backupSQLData = backupSQL.data(using: .utf8)!
        inputPipe.fileHandleForWriting.write(backupSQLData)
        inputPipe.fileHandleForWriting.closeFile()
        _ = command.run(inputPipe: inputPipe)

        Log.info(message: "[DBController] Database restored successfully!")
        Log.info(message: "[DBController] Sleeping for 60s before restarting again. (Save to kill now)")
        Threading.sleep(seconds: 60)
    
    }
 
    private func clearPerms() throws {
        
        Log.info(message: "[DBController] Reseting Permissions")
        
        guard let mysql = mysql else {
            Log.error(message: "[DBController] Failed to connect to database.")
            throw DBError()
        }
        
        let sql = """
            UPDATE web_session
            SET data = JSON_REMOVE(data, "$.perms");
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        guard mysqlStmt.execute() else {
            Log.error(message: "[DBController] Fast Reset failed. Using legacy Reset.")
            let sessions = try getAllSessionData(mysql: mysql)
            for session in sessions {
                var dataJson = try session.value.jsonDecode() as! [String: Any]
                dataJson["perms"] = nil
                try setSessionData(token: session.key, data: dataJson.jsonEncodedString(), mysql: mysql)
            }
            return
        }
        
    }
    
    private func getAllSessionData(mysql: MySQL) throws -> [String: String] {
        
        let sql = """
            SELECT token, data
            FROM `web_session`
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[DBController] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBError()
        }
        let results = mysqlStmt.results()
    
        var sessions = [String: String]()
        while let result = results.next() {
            let token = result[0] as! String
            let data = result[1] as! String
            sessions[token] = data
        }
        return sessions
    }
    
    private func setSessionData(token: String, data: String, mysql: MySQL) throws {

        let sql = """
            UPDATE `web_session`
            SET data = ?
            WHERE token = ?
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(data)
        mysqlStmt.bindParam(token)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[DBController] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBError()
        }
    }
    
}
