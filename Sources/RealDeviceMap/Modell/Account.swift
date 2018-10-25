//
//  Account.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 15.10.18.
//

import Foundation
import PerfectLib
import PerfectMySQL

class Account {
    
    var username: String
    var password: String
    var isHighLevel: Bool
    var firstWarningTimestamp: UInt32?
    var failedTimestamp: UInt32?
    var failed: String?
    
    init(username: String, password: String, isHighLevel: Bool, firstWarningTimestamp: UInt32?, failedTimestamp: UInt32?, failed: String?) {
        self.username = username
        self.password = password
        self.isHighLevel = isHighLevel
        self.firstWarningTimestamp = firstWarningTimestamp
        self.failedTimestamp = failedTimestamp
        self.failed = failed
    }
    
    public func save(update: Bool) throws {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let oldAccount: Account?
        do {
            oldAccount = try Account.getWithUsername(username: username)
        } catch {
            oldAccount = nil
        }
        let mysqlStmt = MySQLStmt(mysql)
        
        if oldAccount == nil {
            
            let sql = """
                INSERT INTO account (username, password, is_high_level, first_warning_timestamp, failed_timestamp, failed)
                VALUES (?, ?, ?, ?, ?, ?)
            """
            _ = mysqlStmt.prepare(statement: sql)
            
            mysqlStmt.bindParam(username)
        } else if update {
            let sql = """
                UPDATE account
                SET password = ?, is_high_level = ?, first_warning_timestamp = ?, failed_timestamp = ?, failed = ?
                WHERE username = ?
            """
            _ = mysqlStmt.prepare(statement: sql)
        } else {
            return
        }
        
        mysqlStmt.bindParam(password)
        mysqlStmt.bindParam(isHighLevel)
        mysqlStmt.bindParam(firstWarningTimestamp)
        mysqlStmt.bindParam(failedTimestamp)
        mysqlStmt.bindParam(failed)

        if oldAccount != nil {
            mysqlStmt.bindParam(username)
        }
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[ACCOUNT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
    
    public static func getNewAccount(highLevel: Bool) throws -> Account? {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT username, password, is_high_level, first_warning_timestamp, failed_timestamp, failed
            FROM account
            LEFT JOIN device ON username = account_username
            WHERE first_warning_timestamp is NULL AND failed_timestamp is NULL and device.uuid IS NULL AND is_high_level = ? AND failed IS NULL
            ORDER BY RAND()
            LIMIT 1
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(highLevel)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[ACCOUNT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }
        
        let result = results.next()!
        
        let username = result[0] as! String
        let password = result[1] as! String
        let isHighLevel = (result[2] as? UInt8)!.toBool()
        let firstWarningTimestamp = result[3] as? UInt32
        let failedTimestamp = result[4] as? UInt32
        let failed = result[5] as? String
        
        return Account(username: username, password: password, isHighLevel: isHighLevel, firstWarningTimestamp: firstWarningTimestamp, failedTimestamp: failedTimestamp, failed: failed)
    }
    
    public static func getWithUsername(username: String) throws -> Account? {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT username, password, is_high_level, first_warning_timestamp, failed_timestamp, failed
            FROM account
            WHERE username = ?
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(username)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[ACCOUNT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }
        
        let result = results.next()!
        
        let username = result[0] as! String
        let password = result[1] as! String
        let isHighLevel = (result[2] as? UInt8)!.toBool()
        let firstWarningTimestamp = result[3] as? UInt32
        let failedTimestamp = result[4] as? UInt32
        let failed = result[5] as? String
        
        return Account(username: username, password: password, isHighLevel: isHighLevel, firstWarningTimestamp: firstWarningTimestamp, failedTimestamp: failedTimestamp, failed: failed)
    }
    
    public static func getNewCount() throws -> Int64 {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT COUNT(*)
            FROM account
            LEFT JOIN device ON username = account_username
            WHERE first_warning_timestamp is NULL AND failed_timestamp is NULL and device.uuid IS NULL AND failed IS NULL
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[ACCOUNT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        let result = results.next()!
        let count = result[0] as! Int64
        
        return count
    }
    
    public static func getInUseCount() throws -> Int64 {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT COUNT(*)
            FROM account
            LEFT JOIN device ON username = account_username
            WHERE device.uuid IS NOT NULL
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[ACCOUNT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        let result = results.next()!
        let count = result[0] as! Int64
        
        return count
    }

    public static func getWarnedCount() throws -> Int64 {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT COUNT(*)
            FROM account
            WHERE failed IS NULL AND first_warning_timestamp IS NOT NULL
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[ACCOUNT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        let result = results.next()!
        let count = result[0] as! Int64
        
        return count
    }
    
    public static func getFailedCount() throws -> Int64 {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT COUNT(*)
            FROM account
            WHERE failed IS NOT NULL
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[ACCOUNT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        let result = results.next()!
        let count = result[0] as! Int64
        
        return count
    }
    
}
