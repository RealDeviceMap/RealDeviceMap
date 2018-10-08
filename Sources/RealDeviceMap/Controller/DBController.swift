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

class DBController {
    
    class DBError: Error {}
    
    public private(set) static var global = DBController()

    private var multiStatement = false
    
    public var mysql: MySQL? {
        let mysql = MySQL()
        mysql.setOption(.MYSQL_SET_CHARSET_NAME, "utf8mb4")
        let connected = mysql.connect(host: host, user: username, password: password, db: database)
        if connected {
            if multiStatement {
                mysql.setServerOption(.MYSQL_OPTION_MULTI_STATEMENTS_ON)
            } else {
                mysql.setServerOption(.MYSQL_OPTION_MULTI_STATEMENTS_OFF)
            }
            return mysql
        } else {
            Log.error(message: "Failed to connect to Database: (\(mysql.errorMessage())")
            return nil
        }
    }
    
    private let database: String
    private let host: String
    private let port: Int
    private let username: String
    private let password: String?
    
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
        port = Int(enviroment["DB_PORT"] ?? "") ?? 3306
        username = enviroment["DB_USERNAME"] ?? "root"
        password = enviroment["DB_PASSWORD"]
        
        MySQLSessionConnector.host = host
        MySQLSessionConnector.port = port
        MySQLSessionConnector.username = username
        MySQLSessionConnector.password = password ?? ""
        MySQLSessionConnector.database = database
        MySQLSessionConnector.table = "web_session"
        
        setup()

        Log.info(message: "[DBController] done")
    }
    
    private func setup() {
        
        multiStatement = true
        guard let mysql = mysql else {
            let message = "Failed to connect to database while initializing."
            Log.critical(message: "[DBController] " + message)
            fatalError(message)
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
    }
    
    private func migrate(mysql: MySQL, fromVersion: Int, toVersion: Int) {
        if fromVersion < toVersion {
            Log.info(message: "[DBController] Migrating database to version \(fromVersion + 1)")
            
            
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
            
            guard mysql.query(statement: migrateSQL) else {
                let message = "Migration Failed: (\(mysql.errorMessage()))"
                Log.critical(message: "[DBController] " + message)
                fatalError(message)
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
            
            clearPerms()
            
            Log.info(message: "[DBController] Migration successful")
            migrate(mysql: mysql, fromVersion: fromVersion + 1, toVersion: toVersion)
        }
    }
 
    private func clearPerms() {
        let sessions = try? getAllSessionData()
        if sessions != nil {
            for session in sessions! {
                var dataJson = try! session.value.jsonDecode() as! [String: Any]
                dataJson["perms"] = nil
                try? setSessionData(token: session.key, data: try! dataJson.jsonEncodedString())
            }
        }
        
    }
    
    private func getAllSessionData() throws -> [String: String] {
        
        guard let mysql = mysql else {
            Log.error(message: "[DBController] Failed to connect to database.")
            throw DBError()
        }
        
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
    
    private func setSessionData(token: String, data: String) throws {
        guard let mysql = mysql else {
            Log.error(message: "[DBController] Failed to connect to database.")
            throw DBError()
        }
        
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
