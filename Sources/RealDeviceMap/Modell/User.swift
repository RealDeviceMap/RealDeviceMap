//
//  User.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//

import PerfectLib
import TurnstileCrypto
import PerfectMySQL
import Regex

class User {
    
    class RegisterError: Error {
        
        enum ErrorType: String {
            case usernameTaken = "username_taken"
            case usernameInvalid = "username_invalid"
            case emailTaken = "email_taken"
            case emailInvalid = "email_invalid"
            case passwordInvalid = "password_invalid"
            case undefined = "undefined"
        }
        
        public private(set) var type: ErrorType
        init(type: ErrorType) {
            self.type = type
        }
        
    }
    
    class LoginError: Error {
        enum ErrorType: String {
            case usernamePasswordInvalid = "credentials_invalid"
            case limited = "limited"
            case undefined = "undefined"
        }
        
        public private(set) var type: ErrorType
        init(type: ErrorType) {
            self.type = type
        }
        
    }
    
    public private(set) var username: String
    public private(set) var email: String
    public private(set) var passwordHash: String
    public private(set) var emailVerified: Bool
    public private(set) var discordId: UInt64?
    public private(set) var groupName: String
    
    private var groupCache: Group?
    public var group: Group? {
        if groupCache == nil {
            do {
                groupCache = try Group.getWithName(name: groupName)
            } catch {
                return nil
            }
        }
        return groupCache!
    }

    private init(username: String, email: String, passwordHash: String, emailVerified: Bool=false, discordId: UInt64?=nil, groupName: String) {
        self.username = username
        self.email = email
        self.passwordHash = passwordHash
        self.emailVerified = emailVerified
        self.discordId = discordId
        self.groupName = groupName
    }
    
    // MARK: - REGISTER
    
    public static func register(mysql: MySQL?=nil, username: String, email: String, password: String, groupName: String) throws -> User {
        
        guard checkUsernameValid(username: username) else {
            throw RegisterError(type: .usernameInvalid)
        }
        guard checkEmailVaild(email: email) else {
            throw RegisterError(type: .emailInvalid)
        }
        guard checkPasswordValid(password: password) else {
            throw RegisterError(type: .passwordInvalid)
        }

        let usernameTaken: Bool
        do {
            usernameTaken = try checkUsernameTaken(mysql: mysql, username: username)
        } catch {
            throw RegisterError(type: .undefined)
        }
        if usernameTaken {
            throw RegisterError(type: .usernameTaken)
        }
        
        let emailTaken: Bool
        do {
            emailTaken = try checkEmailTaken(mysql: mysql, email: email)
        } catch {
            throw RegisterError(type: .undefined)
        }
        if emailTaken {
            throw RegisterError(type: .emailTaken)
        }
        
        let passwordHash = BCrypt.hash(password: password, salt: BCryptSalt(cost: 7))
        
        let user = User(username: username, email: email, passwordHash: passwordHash, groupName: groupName)
        do {
            try user.save(mysql: mysql)
        } catch {
            throw RegisterError(type: .undefined)
        }
        return user
        
    }
    
    private static func checkUsernameValid(username: String) -> Bool {
        let regex = "^[A-Z0-9a-z_\\- ]{4,25}$"
        
        if username =~ regex {
            if !username.contains(string: "  ") && !username.contains(string: "__") && !username.contains(string: "--") {
                return true
            }
        }
        return false
        
    }
    
    private static func checkEmailVaild(email: String) -> Bool {
        let regex = "^(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])+$"
        return email =~ regex
    }
    
    private static func checkPasswordValid(password: String) -> Bool {
        return password.count >= 8
    }
    
    private static func checkUsernameTaken(mysql: MySQL?=nil, username: String) throws -> Bool {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[USER] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT NULL
            FROM user
            WHERE username = ?
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(username)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[USER] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        
        let results = mysqlStmt.results()
        return results.numRows != 0
    }
    
    private static func checkEmailTaken(mysql: MySQL?=nil, email: String) throws -> Bool {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[USER] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT NULL
            FROM user
            WHERE email = ?
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(email)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[USER] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        
        let results = mysqlStmt.results()
        return results.numRows != 0
    }
    
    // MARK: - LOGIN
    
    public static func login(mysql: MySQL?=nil, username: String, password: String, host: String) throws -> User {
        return try login(mysql: mysql, username: username, email: nil, password: password, host: host)
    }
    
    public static func login(mysql: MySQL?=nil, email: String, password: String, host: String) throws -> User {
        return try login(mysql: mysql, username: nil, email: email, password: password, host: host)
    }
    
    private static func login(mysql: MySQL?=nil, username: String? = nil, email: String? = nil, password: String, host: String) throws -> User {
        
        if !LoginLimiter.global.allowed(host: host) {
            throw LoginError(type: .limited)
        }
        
        let user: User?
        do {
            user = try User.get(mysql: mysql, username: username, email: email)
        } catch {
            throw LoginError(type: .undefined)
        }
        
        if user == nil  {
            LoginLimiter.global.failed(host: host)
            throw LoginError(type: .usernamePasswordInvalid)
        }
        
        if try BCrypt.verify(password: password, matchesHash: user!.passwordHash) {
            return user!
        } else {
            LoginLimiter.global.failed(host: host)
            throw LoginError(type: .usernamePasswordInvalid)
        }
    }
    
    // MARK: - DB
    
    public static func get(mysql: MySQL?=nil, username: String? = nil, email: String? = nil) throws -> User? {
        
        if username == nil && email == nil {
            fatalError("Invalid call to User.get without username or email")
        }
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[USER] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        var sql = """
            SELECT username, email, password, discord_id, email_verified, group_name
            FROM user
        """
        if username != nil {
            sql += " WHERE username = ?"
        } else {
            sql += " WHERE email = ?"
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        if username != nil {
            mysqlStmt.bindParam(username!)
        } else {
            mysqlStmt.bindParam(email!)
        }
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[USER] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        
        let results = mysqlStmt.results()
        
        if results.numRows == 0 {
            return nil
        } else {
            let result = results.next()!
            let username = result[0] as! String
            let email = result[1] as! String
            let passwordHash = result[2] as! String
            let discordId = result[3] as? UInt64
            let emailVerified = (result[4] as? UInt8)?.toBool() ?? false
            let groupName = result[5] as! String

            return User(username: username, email: email, passwordHash: passwordHash, emailVerified: emailVerified, discordId: discordId, groupName: groupName)
        }
    }
    
    private func save(mysql: MySQL?=nil, update: Bool = false) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[USER] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        var sql = """
            INSERT INTO user (username, email, password, discord_id, email_verified, group_name)
            VALUES (?, ?, ?, ?, ?, ?)
        """
        if update {
            sql += """
            ON DUPLICATE KEY UPDATE
            email=VALUES(email),
            password=VALUES(password),
            discord_id=VALUES(discord_id),
            email_verified=VALUES(email_verified)
            group_name=VALUES(group_name)
            """
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(username)
        mysqlStmt.bindParam(email)
        mysqlStmt.bindParam(passwordHash)
        mysqlStmt.bindParam(discordId)
        mysqlStmt.bindParam(emailVerified)
        mysqlStmt.bindParam(groupName)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[USER] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
    
}
