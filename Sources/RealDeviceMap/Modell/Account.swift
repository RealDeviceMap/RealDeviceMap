//
//  Account.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 15.10.18.
//

import Foundation
import PerfectLib
import PerfectMySQL
import POGOProtos

class Account: WebHookEvent {

    func getWebhookValues(type: String) -> [String : Any] {

        let message: [String: Any] = [
            "username": username,
            "level": level,
            "first_warning_timestamp": firstWarningTimestamp ?? 0,
            "failed_timestamp": failedTimestamp ?? 0,
            "failed": failed ?? "None",
            "last_encounter_time": lastEncounterTime ?? 0,
            "spins": spins as Any,
            "creation_timestamp_ms": creationTimestampMs ?? 0,
            "warn": warn ?? 0,
            "warn_expire_ms": warnExpireMs ?? 0,
            "warn_message_acknowledged": warnMessageAcknowledged ?? 0,
            "suspended_message_acknowledged": suspendedMessageAcknowledged ?? 0,
            "was_suspended": wasSuspended ?? 0,
            "banned": banned ?? 0
        ]
        return [
            "type": "account",
            "message": message
        ]
    }
	
    var username: String
    var password: String
    var level: UInt8
    var firstWarningTimestamp: UInt32?
    var failedTimestamp: UInt32?
    var failed: String?
    var lastEncounterLat: Double?
    var lastEncounterLon: Double?
    var lastEncounterTime: UInt32?
    var spins: UInt16
    var creationTimestampMs: UInt64?
    var warn: Bool?
    var warnExpireMs: UInt64?
    var warnMessageAcknowledged: Bool?
    var suspendedMessageAcknowledged: Bool?
    var wasSuspended: Bool?	
    var banned: Bool?

    init(username: String, password: String, level: UInt8, firstWarningTimestamp: UInt32?, failedTimestamp: UInt32?, failed: String?, lastEncounterLat: Double?, lastEncounterLon: Double?, lastEncounterTime: UInt32?, spins: UInt16, creationTimestampMs: UInt64?, warn: Bool?, warnExpireMs: UInt64?, warnMessageAcknowledged: Bool?, suspendedMessageAcknowledged: Bool?, wasSuspended: Bool?, banned: Bool?) {
        self.username = username
        self.password = password
        self.level = level
        if firstWarningTimestamp != 0 {
            self.firstWarningTimestamp = firstWarningTimestamp
        }
        if failedTimestamp != 0 {
            self.failedTimestamp = failedTimestamp
        }
        self.failed = failed
        self.lastEncounterLat = lastEncounterLat
        self.lastEncounterLon = lastEncounterLon
        if lastEncounterTime != 0 {
            self.lastEncounterTime = lastEncounterTime
        }
        self.spins = spins
        self.creationTimestampMs = creationTimestampMs
        self.warn = warn
        self.warnExpireMs = warnExpireMs
        self.warnMessageAcknowledged = warnMessageAcknowledged
        self.suspendedMessageAcknowledged = suspendedMessageAcknowledged
        self.wasSuspended = wasSuspended
        self.banned = banned
    }

    public func responseInfo(accountData: POGOProtos_Networking_Responses_GetPlayerResponse) {

        self.creationTimestampMs = UInt64(accountData.playerData.creationTimestampMs) / 1000
        self.warn = accountData.warn
        self.warnExpireMs = UInt64(accountData.warnExpireMs) / 1000
        self.warnMessageAcknowledged = accountData.warnMessageAcknowledged
        self.suspendedMessageAcknowledged = accountData.suspendedMessageAcknowledged
        self.wasSuspended = accountData.wasSuspended
        self.banned = accountData.banned

        if accountData.warn == true {
            self.failed = "GPR_RED_WARNING"
			if self.firstWarningTimestamp == nil {
                self.firstWarningTimestamp = UInt32(Date().timeIntervalSince1970)
                self.failedTimestamp = UInt32(Date().timeIntervalSince1970)
			}
            Log.debug(message: "[ACCOUNT] AccountName: \(self.username) - UserName: \(accountData.playerData.username) - Red Warning: \(accountData.warn)")
        }
        if accountData.banned == true {
            self.failed = "GPR_BANNED"
			if self.firstWarningTimestamp == nil {
                self.firstWarningTimestamp = UInt32(Date().timeIntervalSince1970)
                self.failedTimestamp = UInt32(Date().timeIntervalSince1970)
			}
            Log.debug(message: "[ACCOUNT] AccountName: \(self.username) - UserName: \(accountData.playerData.username) - Banned: \(accountData.banned)")
        }		

    }
	
    public func save(mysql: MySQL?=nil, update: Bool) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }

        let oldAccount: Account?
        do {
            oldAccount = try Account.getWithUsername(mysql: mysql, username: username)
        } catch {
            oldAccount = nil
        }
        let mysqlStmt = MySQLStmt(mysql)

        if oldAccount == nil {

            let sql = """
                INSERT INTO account (username, password, level, first_warning_timestamp, failed_timestamp, failed, last_encounter_lat, last_encounter_lon, last_encounter_time, spins, creation_timestamp_ms, warn, warn_expire_ms, warn_message_acknowledged, suspended_message_acknowledged, was_suspended, banned)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            _ = mysqlStmt.prepare(statement: sql)

            mysqlStmt.bindParam(username)
        } else if update {

            if lastEncounterLat == nil && oldAccount!.lastEncounterLat != nil {
                self.lastEncounterLat = oldAccount!.lastEncounterLat!
            }
            if lastEncounterLon == nil && oldAccount!.lastEncounterLon != nil {
                self.lastEncounterLon = oldAccount!.lastEncounterLon!
            }
            if lastEncounterTime == nil && oldAccount!.lastEncounterTime != nil {
                self.lastEncounterTime = oldAccount!.lastEncounterTime!
            }
            if failed == nil && oldAccount!.failed != nil {
                self.failed = oldAccount!.failed!
            }
            if firstWarningTimestamp == nil && oldAccount!.firstWarningTimestamp != nil {
                self.firstWarningTimestamp = oldAccount!.firstWarningTimestamp!
            }
            if failedTimestamp == nil && oldAccount!.failedTimestamp != nil {
                self.failedTimestamp = oldAccount!.failedTimestamp!
            }
            if spins < oldAccount!.spins {
                self.spins = oldAccount!.spins
            }
            if creationTimestampMs == nil && oldAccount!.creationTimestampMs != nil {
                self.creationTimestampMs = oldAccount!.creationTimestampMs!
            }
            if warn == nil && oldAccount!.warn != nil {
                self.warn = oldAccount!.warn!
            }
            if warnExpireMs == nil && oldAccount!.warnExpireMs != nil {
                self.warnExpireMs = oldAccount!.warnExpireMs!
            }
            if warnMessageAcknowledged == nil && oldAccount!.warnMessageAcknowledged != nil {
                self.warnMessageAcknowledged = oldAccount!.warnMessageAcknowledged!
            }
            if suspendedMessageAcknowledged == nil && oldAccount!.suspendedMessageAcknowledged != nil {
                self.suspendedMessageAcknowledged = oldAccount!.suspendedMessageAcknowledged!
            }
            if wasSuspended == nil && oldAccount!.wasSuspended != nil {
                self.wasSuspended = oldAccount!.wasSuspended!
            }
            if banned == nil && oldAccount!.banned != nil {
                self.banned = oldAccount!.banned!
            }
            WebHookController.global.addAccountEvent(account: self)
			
            let sql = """
                UPDATE account
                SET password = ?, level = ?, first_warning_timestamp = ?, failed_timestamp = ?, failed = ?, last_encounter_lat = ?, last_encounter_lon = ?, last_encounter_time = ?, spins = ?, creation_timestamp_ms = ?, warn = ?, warn_expire_ms = ?, warn_message_acknowledged = ?, suspended_message_acknowledged = ?, was_suspended = ?, banned = ?
                WHERE username = ?
            """
            _ = mysqlStmt.prepare(statement: sql)
        } else {
            return
        }

        mysqlStmt.bindParam(password)
        mysqlStmt.bindParam(level)
        mysqlStmt.bindParam(firstWarningTimestamp)
        mysqlStmt.bindParam(failedTimestamp)
        mysqlStmt.bindParam(failed)
        mysqlStmt.bindParam(lastEncounterLat)
        mysqlStmt.bindParam(lastEncounterLon)
        mysqlStmt.bindParam(lastEncounterTime)
        mysqlStmt.bindParam(spins)
        mysqlStmt.bindParam(creationTimestampMs)
        mysqlStmt.bindParam(warn)
        mysqlStmt.bindParam(warnExpireMs)
        mysqlStmt.bindParam(warnMessageAcknowledged)
        mysqlStmt.bindParam(suspendedMessageAcknowledged)
        mysqlStmt.bindParam(wasSuspended)
        mysqlStmt.bindParam(banned)

        if oldAccount != nil {
            mysqlStmt.bindParam(username)
        }

        guard mysqlStmt.execute() else {
            Log.error(message: "[ACCOUNT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }

    public static func setLevel(mysql: MySQL?=nil, username: String, level: Int) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
                UPDATE account
                SET level = ?
                WHERE username = ?
            """
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(level)
        mysqlStmt.bindParam(username)

        guard mysqlStmt.execute() else {
            Log.error(message: "[ACCOUNT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
	
    public static func didEncounter(mysql: MySQL?=nil, username: String, lon: Double, lat: Double, time: UInt32) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
                UPDATE account
                SET last_encounter_lat = ?, last_encounter_lon = ?, last_encounter_time = ?
                WHERE username = ?
            """
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(lat)
        mysqlStmt.bindParam(lon)
        mysqlStmt.bindParam(time)
        mysqlStmt.bindParam(username)

        guard mysqlStmt.execute() else {
            Log.error(message: "[ACCOUNT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }

    public static func spin(mysql: MySQL?=nil, username: String) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
                UPDATE account
                SET spins = spins + 1
                WHERE username = ?
            """
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(username)

        guard mysqlStmt.execute() else {
            Log.error(message: "[ACCOUNT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }

    public static func clearSpins(mysql: MySQL?=nil) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }

        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
                UPDATE account
                SET spins = 0
            """
        _ = mysqlStmt.prepare(statement: sql)

        guard mysqlStmt.execute() else {
            Log.error(message: "[ACCOUNT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }

    public static func getNewAccount(mysql: MySQL?=nil, minLevel: Int, maxLevel: Int) throws -> Account? {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
            SELECT username, password, level, first_warning_timestamp, failed_timestamp, failed, last_encounter_lat, last_encounter_lon, last_encounter_time, spins, creation_timestamp_ms, warn, warn_expire_ms, warn_message_acknowledged, suspended_Mmessage_acknowledged, was_suspended, banned
            FROM account
            LEFT JOIN device ON username = account_username
            WHERE first_warning_timestamp is NULL AND failed_timestamp is NULL and device.uuid IS NULL AND level >= ? AND level <= ? AND failed IS NULL AND (last_encounter_time IS NULL OR UNIX_TIMESTAMP() -  CAST(last_encounter_time AS SIGNED INTEGER) >= 7200 AND spins < 400)
            ORDER BY level DESC, RAND()
            LIMIT 1
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(minLevel)
        mysqlStmt.bindParam(maxLevel)

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
        let level = result[2] as! UInt8
        let firstWarningTimestamp = result[3] as? UInt32
        let failedTimestamp = result[4] as? UInt32
        let failed = result[5] as? String
        let lastEncounterLat = result[6] as? Double
        let lastEncounterLon = result[7] as? Double
        let lastEncounterTime = result[8] as? UInt32
        let spins = result[9] as! UInt16
		let creationTimestampMs = result[10] as? UInt64
		let warn = result[11] as? Bool
		let warnExpireMs = result[12] as? UInt64
		let warnMessageAcknowledged = result[13] as? Bool
		let suspendedMessageAcknowledged = result[14] as? Bool
		let wasSuspended = result[15] as? Bool
		let banned = result[16] as? Bool

        return Account(username: username, password: password, level: level, firstWarningTimestamp: firstWarningTimestamp, failedTimestamp: failedTimestamp, failed: failed, lastEncounterLat: lastEncounterLat, lastEncounterLon: lastEncounterLon, lastEncounterTime: lastEncounterTime, spins: spins, creationTimestampMs: creationTimestampMs, warn: warn, warnExpireMs: warnExpireMs, warnMessageAcknowledged: warnMessageAcknowledged, suspendedMessageAcknowledged: suspendedMessageAcknowledged, wasSuspended: wasSuspended, banned: banned)
    }

    public static func getWithUsername(mysql: MySQL?=nil, username: String) throws -> Account? {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
            SELECT username, password, level, first_warning_timestamp, failed_timestamp, failed, last_encounter_lat, last_encounter_lon, last_encounter_time, spins, creation_timestamp_ms, warn, warn_expire_ms, warn_message_acknowledged, suspended_message_acknowledged, was_suspended, banned
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
        let level = result[2] as! UInt8
        let firstWarningTimestamp = result[3] as? UInt32
        let failedTimestamp = result[4] as? UInt32
        let failed = result[5] as? String
        let lastEncounterLat = result[6] as? Double
        let lastEncounterLon = result[7] as? Double
        let lastEncounterTime = result[8] as? UInt32
        let spins = result[9] as! UInt16
        let creationTimestampMs = result[10] as? UInt64
        let warn = result[11] as? Bool
        let warnExpireMs = result[12] as? UInt64
        let warnMessageAcknowledged = result[13] as? Bool
        let suspendedMessageAcknowledged = result[14] as? Bool
        let wasSuspended = result[15] as? Bool
        let banned = result[16] as? Bool

        return Account(username: username, password: password, level: level, firstWarningTimestamp: firstWarningTimestamp, failedTimestamp: failedTimestamp, failed: failed, lastEncounterLat: lastEncounterLat, lastEncounterLon: lastEncounterLon, lastEncounterTime: lastEncounterTime, spins: spins, creationTimestampMs: creationTimestampMs, warn: warn, warnExpireMs: warnExpireMs, warnMessageAcknowledged: warnMessageAcknowledged, suspendedMessageAcknowledged: suspendedMessageAcknowledged, wasSuspended: wasSuspended, banned: banned)
    }

    public static func getNewCount(mysql: MySQL?=nil) throws -> Int64 {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
            SELECT COUNT(*)
            FROM account
            LEFT JOIN device ON username = account_username
            WHERE first_warning_timestamp is NULL AND failed_timestamp is NULL and device.uuid IS NULL AND failed IS NULL AND (last_encounter_time IS NULL OR UNIX_TIMESTAMP() - CAST(last_encounter_time AS SIGNED INTEGER) >= 7200 AND spins < 400)
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

    public static func getCooldownCount(mysql: MySQL?=nil) throws -> Int64 {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
            SELECT COUNT(*)
            FROM account
            WHERE last_encounter_time IS NOT NULL AND UNIX_TIMESTAMP() - CAST(last_encounter_time AS SIGNED INTEGER) < 7200
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

    public static func getSpinLimitCount(mysql: MySQL?=nil) throws -> Int64 {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
            SELECT COUNT(*)
            FROM account
            WHERE spins >= 500
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

    public static func getLevelCount(mysql: MySQL?=nil, level: Int) throws -> Int64 {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
            SELECT COUNT(*)
            FROM account
            WHERE level >= ?
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(level)

        guard mysqlStmt.execute() else {
            Log.error(message: "[ACCOUNT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        let result = results.next()!
        let count = result[0] as! Int64

        return count
    }

    public static func getInUseCount(mysql: MySQL?=nil) throws -> Int64 {

        guard let mysql = mysql ?? DBController.global.mysql else {
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

    public static func getWarnedCount(mysql: MySQL?=nil) throws -> Int64 {

        guard let mysql = mysql ?? DBController.global.mysql else {
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

    public static func getFailedCount(mysql: MySQL?=nil) throws -> Int64 {

        guard let mysql = mysql ?? DBController.global.mysql else {
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
