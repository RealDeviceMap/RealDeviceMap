//
//  SpawnPoint.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 06.10.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast

import Foundation
import PerfectLib
import PerfectMySQL
import POGOProtos

class SpawnPoint: JSONConvertibleObject {

    class ParsingError: Error {}

    override func getJSONValues() -> [String: Any] {
        return [
            "id": id.toHexString()!,
            "lat": lat,
            "lon": lon,
            "updated": updated ?? 1,
            "despawn_second": despawnSecond as Any
        ]
    }

    var id: UInt64
    var lat: Double
    var lon: Double
    var updated: UInt32?
    var despawnSecond: UInt16?

    static var cache: MemoryCache<SpawnPoint>?

    init(id: UInt64, lat: Double, lon: Double, updated: UInt32?, despawnSecond: UInt16?) {
        self.id = id
        self.lat = lat
        self.lon = lon
        self.updated = updated
        self.despawnSecond = despawnSecond
    }

    public func save(mysql: MySQL?=nil, update: Bool=false) throws {

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

        updated = UInt32(Date().timeIntervalSince1970)

        if !update && oldSpawnpoint != nil {
            return
        }

        let now = UInt32(Date().timeIntervalSince1970)
        if oldSpawnpoint != nil {

            if self.despawnSecond == nil && oldSpawnpoint!.despawnSecond != nil {
                self.despawnSecond = oldSpawnpoint!.despawnSecond
            }

            if  self.lat == oldSpawnpoint!.lat &&
                self.lon == oldSpawnpoint!.lon &&
                self.despawnSecond == oldSpawnpoint!.despawnSecond {
                return
            }

        }

        var sql = """
            INSERT INTO spawnpoint (id, lat, lon, updated, despawn_sec)
            VALUES (?, ?, ?, UNIX_TIMESTAMP(), ?)
        """
        if update {
            sql += """
            ON DUPLICATE KEY UPDATE
            lat=VALUES(lat),
            lon=VALUES(lon),
            updated=VALUES(updated),
            despawn_sec=VALUES(despawn_sec)
            """
        }

        self.updated = now

        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(id)
        mysqlStmt.bindParam(lat)
        mysqlStmt.bindParam(lon)
        mysqlStmt.bindParam(despawnSecond)

        guard mysqlStmt.execute() else {
            Log.error(message: "[SPAWNPOINT] Failed to execute query. (\(mysqlStmt.errorMessage())")
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
            SELECT id, lat, lon, updated, despawn_sec
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
            let despawnSecond = result[4] as? UInt16

            spawnpoints.append(SpawnPoint(id: id, lat: lat, lon: lon, updated: updated, despawnSecond: despawnSecond))

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
            SELECT id, lat, lon, updated, despawn_sec
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
        let despawnSecond = result[4] as? UInt16

        let spawnpoint = SpawnPoint(id: id, lat: lat, lon: lon, updated: updated, despawnSecond: despawnSecond)
        cache?.set(id: spawnpoint.id.toString(), value: spawnpoint)
        return spawnpoint

    }

}
