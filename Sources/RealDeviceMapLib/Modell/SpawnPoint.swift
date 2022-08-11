//
//  SpawnPoint.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 06.10.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast

import Foundation
import PerfectLib
import PerfectMySQL
import POGOProtos

public class SpawnPoint: JSONConvertibleObject {

    class ParsingError: Error {}

    public override func getJSONValues() -> [String: Any] {
        return [
            "id": id.toHexString()!,
            "lat": lat,
            "lon": lon,
            "updated": updated ?? 1,
            "last_seen": lastSeen ?? 0,
            "despawn_second": despawnSecond as Any
        ]
    }

    var id: UInt64
    var lat: Double
    var lon: Double
    var updated: UInt32?
    var lastSeen: UInt32?
    var despawnSecond: UInt16?

    public static var cache: MemoryCache<SpawnPoint>?

    init(id: UInt64, lat: Double, lon: Double, despawnSecond: UInt16?) {
        self.id = id
        self.lat = lat
        self.lon = lon
        self.despawnSecond = despawnSecond
    }

    init(id: UInt64, lat: Double, lon: Double, updated: UInt32?, lastSeen: UInt32?, despawnSecond: UInt16?) {
        self.id = id
        self.lat = lat
        self.lon = lon
        self.updated = updated
        self.lastSeen = lastSeen
        self.despawnSecond = despawnSecond
    }

    public func save(mysql: MySQL?=nil, update: Bool=false, timestampAccurate: Bool=true) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[SPAWNPOINT] Failed to connect to database.")
            throw DBController.DBError()
        }

        let oldSpawnpoint: SpawnPoint?
        do {
            oldSpawnpoint = try SpawnPoint.getWithId(mysql: mysql, id: id)
        } catch {
            oldSpawnpoint = nil
        }
        let mysqlStmt = MySQLStmt(mysql)

        if !update && oldSpawnpoint != nil {
            return
        }

        let now = UInt32(Date().timeIntervalSince1970)
        updated = now
        lastSeen = now

        if oldSpawnpoint != nil {

            if self.despawnSecond == nil && oldSpawnpoint!.despawnSecond != nil {
                self.despawnSecond = oldSpawnpoint!.despawnSecond
            }

            if !SpawnPoint.hasChanges(old: oldSpawnpoint!, new: self) {
                return
            }

            // better to have inaccurate timestamp than none -> only update if the time differs more than 30 seconds,
            // use old despawn seconds if available then, otherwise keep new despawn seconds
            if !timestampAccurate, let oldDespawnSecond = oldSpawnpoint!.despawnSecond,
               let newDespawnSecond = self.despawnSecond {
                if abs(Int(oldDespawnSecond) - Int(newDespawnSecond)) < 30 {
                    self.despawnSecond = oldDespawnSecond
                }
            }

        }

        var sql = """
            INSERT INTO spawnpoint (id, lat, lon, updated, last_seen, despawn_sec)
            VALUES (?, ?, ?, ?, ?, ?)
        """
        if update {
            sql += """
            ON DUPLICATE KEY UPDATE
            lat=VALUES(lat),
            lon=VALUES(lon),
            updated=VALUES(updated),
            last_seen=VALUES(last_seen),
            despawn_sec=VALUES(despawn_sec)
            """
        }

        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(id)
        mysqlStmt.bindParam(lat)
        mysqlStmt.bindParam(lon)
        mysqlStmt.bindParam(updated)
        mysqlStmt.bindParam(lastSeen)
        mysqlStmt.bindParam(despawnSecond)

        guard mysqlStmt.execute() else {
            Log.error(message: "[SPAWNPOINT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        SpawnPoint.cache?.set(id: id.toString(), value: self)

    }

    private static func hasChanges(old: SpawnPoint, new: SpawnPoint) -> Bool {
        return old.lat != new.lat ||
               old.lon != new.lon ||
               old.despawnSecond != new.despawnSecond
    }

    public func setLastSeen(mysql: MySQL?=nil) throws {

        let now = UInt32(Date().timeIntervalSince1970)

        if self.lastSeen! + 900 > now {
            return
        }
        self.lastSeen = now

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[SPAWNPOINT] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
            UPDATE IGNORE spawnpoint
            SET last_seen = ?
            WHERE id = ?
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(now)
        mysqlStmt.bindParam(id)

        guard mysqlStmt.execute() else {
            Log.error(message: "[SPAWNPOINT] Failed to execute query 'setLastSeen'. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        SpawnPoint.cache?.set(id: id.toString(), value: self)

    }

    public static func getAll(mysql: MySQL?=nil, minLat: Double, maxLat: Double,
                              minLon: Double, maxLon: Double, updated: UInt32,
                              spawnpointFilterExclude: [String]?=nil) throws -> [SpawnPoint] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[SPAWNPOINT] Failed to connect to database.")
            throw DBController.DBError()
        }

        var excludeWithoutTimer = false
        var excludeWithTimer = false
        if spawnpointFilterExclude != nil {
            for filter in spawnpointFilterExclude! {
                if filter.contains(string: "no-timer") {
                    excludeWithoutTimer = true
                } else if filter.contains(string: "with-timer") {
                    excludeWithTimer = true
                }
            }
        }

        let excludeTimerSQL: String
        if !excludeWithoutTimer && !excludeWithTimer {
            excludeTimerSQL = ""
        } else if !excludeWithoutTimer && excludeWithTimer {
            excludeTimerSQL = "AND (despawn_sec IS NULL)"
        } else if excludeWithoutTimer && !excludeWithTimer {
            excludeTimerSQL = "AND (despawn_sec IS NOT NULL)"
        } else {
            excludeTimerSQL = "AND (despawn_sec IS NULL AND despawn_sec IS NOT NULL)"
        }

        let sql = """
            SELECT id, lat, lon, updated, last_seen, despawn_sec
            FROM spawnpoint
            WHERE lat >= ? AND lat <= ? AND lon >= ? AND lon <= ? AND updated > ? \(excludeTimerSQL)
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(minLat)
        mysqlStmt.bindParam(maxLat)
        mysqlStmt.bindParam(minLon)
        mysqlStmt.bindParam(maxLon)
        mysqlStmt.bindParam(updated)

        guard mysqlStmt.execute() else {
            Log.error(message: "[SPAWNPOINT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var spawnpoints = [SpawnPoint]()
        while let result = results.next() {

            let id = result[0] as! UInt64
            let lat = result[1] as! Double
            let lon = result[2] as! Double
            let updated = result[3] as! UInt32
            let lastSeen = result[4] as! UInt32
            let despawnSecond = result[5] as? UInt16

            spawnpoints.append(
                SpawnPoint(
                    id: id,
                    lat: lat,
                    lon: lon,
                    updated: updated,
                    lastSeen: lastSeen,
                    despawnSecond: despawnSecond
                )
            )

        }
        return spawnpoints

    }

    public static func getWithId(mysql: MySQL?=nil, id: UInt64) throws -> SpawnPoint? {

        if let cached = cache?.get(id: id.toString()) {
            return cached
        }

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[SPAWNPOINT] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
            SELECT id, lat, lon, updated, last_seen, despawn_sec
            FROM spawnpoint
            WHERE id = ?
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(id)

        guard mysqlStmt.execute() else {
            Log.error(message: "[SPAWNPOINT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }

        let result = results.next()!

        let id = result[0] as! UInt64
        let lat = result[1] as! Double
        let lon = result[2] as! Double
        let updated = result[3] as! UInt32
        let lastSeen = result[4] as! UInt32
        let despawnSecond = result[5] as? UInt16

        let spawnpoint = SpawnPoint(
            id: id,
            lat: lat,
            lon: lon,
            updated: updated,
            lastSeen: lastSeen,
            despawnSecond: despawnSecond
        )
        cache?.set(id: spawnpoint.id.toString(), value: spawnpoint)
        return spawnpoint

    }

}
