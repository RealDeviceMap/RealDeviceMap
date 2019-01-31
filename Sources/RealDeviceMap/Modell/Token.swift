//
//  Token.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 29.12.18.
//

import Foundation
import PerfectLib
import TurnstileCrypto
import PerfectMySQL

class Token {
    
    enum TokenType: String {
        case confirmEmail = "confirm_email"
        case resetPassword = "reset_password"
    }
    
    var token: String
    var type: TokenType
    var expireTimestamp: UInt32
    var username: String
    
    init(token: String, type: TokenType, expireTimestamp: UInt32, username: String) {
        self.token = token
        self.type = type
        self.expireTimestamp = expireTimestamp
        self.username = username
    }
    
    public static func create(mysql: MySQL?=nil, type: TokenType, username: String, validSeconds: UInt32) throws -> Token {
        let tokenString = URandom().secureToken + URandom().secureToken
        let expireTimestamp = UInt32(Date().timeIntervalSince1970) + validSeconds
        
        let token = Token(token: tokenString, type: type, expireTimestamp: expireTimestamp, username: username)
        try token.save(mysql: mysql)
        return token
    }
    
    public func save(mysql: MySQL?=nil, update: Bool = false) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[TOKEN] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        var sql = """
            INSERT INTO token (token, type, username, expire_timestamp)
            VALUES (?, ?, ?, ?)
        """
        if update {
            sql += """
            ON DUPLICATE KEY UPDATE
            token=VALUES(token),
            type=VALUES(type),
            username=VALUES(username),
            expire_timestamp=VALUES(expire_timestamp)
            """
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(token)
        mysqlStmt.bindParam(type.rawValue)
        mysqlStmt.bindParam(username)
        mysqlStmt.bindParam(expireTimestamp)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[TOKEN] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
    
    public static func get(mysql: MySQL?=nil, token: String) throws -> Token? {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[TOKEN] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT token, type, username, expire_timestamp
            FROM token
            WHERE token = ? AND expire_timestamp >= UNIX_TIMESTAMP()
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(token)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[TOKEN] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }
        
        let result = results.next()!
        
        let token = result[0] as! String
        let type = TokenType(rawValue: result[1] as! String)!
        let username = result[2] as! String
        let expireTimestamp = result[3] as! UInt32
        
        return Token(token: token, type: type, expireTimestamp: expireTimestamp, username: username)
    }
    
    public static func delete(mysql: MySQL?=nil, token: String, type: TokenType) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[TOKEN] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            DELETE
            FROM token
            WHERE token = ? AND type = ?
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(token)
        mysqlStmt.bindParam(type.rawValue)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[TOKEN] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }

    public static func delete(mysql: MySQL?=nil, username: String, type: TokenType) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[TOKEN] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            DELETE
            FROM token
            WHERE username = ? AND type = ?
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(username)
        mysqlStmt.bindParam(type.rawValue)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[TOKEN] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }

    public static func validate(mysql: MySQL?=nil, token: String, username: String, type: TokenType) throws -> Bool {
        guard let token = try Token.get(mysql: mysql, token: token), token.username == username, token.type == type else {
            return false
        }
        return true
    }
    
}
