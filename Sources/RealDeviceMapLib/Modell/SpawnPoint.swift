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

public class SpawnPoint: JSONConvertibleObject {

    class ParsingError: Error {}

    public override func getJSONValues() -> [String: Any] {
        return [
            "id": id.toHexString()!,
            "lat": lat,
            "lon": lon,
            "updated": updated ?? 1,
            "last_seen": lastSeen ?? 0,
            "despawn_second": despawnSecond as Any,
            "spawnInfo": spawnInfo ?? 0,
            "created": created ?? 0
        ]
    }

    var id: UInt64
    var lat: Double
    var lon: Double
    var updated: UInt32?
    var lastSeen: UInt32?
    var despawnSecond: UInt16?
    var spawnInfo: UInt32? //only first 4 bits used to track if spawn 30 or 60min.
    var created: UInt32?

    public static var cache: MemoryCache<SpawnPoint>?

    init(id: UInt64, lat: Double, lon: Double, despawnSecond: UInt16?) {
        self.id = id
        self.lat = lat
        self.lon = lon
        self.despawnSecond = despawnSecond
        self.spawnInfo = 0
        self.created = UInt32(Date().timeIntervalSince1970)
    }

    init(id: UInt64, lat: Double, lon: Double, updated: UInt32?, lastSeen: UInt32?, despawnSecond: UInt16?) {
        self.id = id
        self.lat = lat
        self.lon = lon
        self.updated = updated
        self.lastSeen = lastSeen
        self.despawnSecond = despawnSecond
        self.spawnInfo = 0
        self.created = UInt32(Date().timeIntervalSince1970)
    }

    init(id: UInt64, lat: Double, lon: Double, updated: UInt32?, lastSeen: UInt32?, despawnSecond: UInt16?, spawnInfo: UInt32?, created: UInt32?) {
        self.id = id
        self.lat = lat
        self.lon = lon
        self.updated = updated
        self.lastSeen = lastSeen
        self.despawnSecond = despawnSecond
        self.spawnInfo = spawnInfo
        self.created = created
    }

    public func save(mysql: MySQL?=nil, update: Bool=false, timestampAccurate: Bool=true, minute: UInt64 = UInt64.max) throws {

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
        
        // determine spawn information by what quarter of hours the monster has been seen in
        // 1. if the spawn has been seen in all quarter hours, it is a 60min spawn
        // 2. if the spawn has been seen in 3 or less quarter hours, it is considered a 30min spawn
        // 3. one will want to run the area on laps, as by definition, findy will not likely visit the spawnpoint in enough quarter hours to determine if the spawn is a 60min one.  it will likely be considered a 30min spawn forever if just running jumpy.
        var curMinute:UInt64 = minute
        var quarterHourValue:UInt32 = 0
        if minute == UInt64.max { // if got a default value, just grab the current minute
            (_, curMinute, _) = secondsToHoursMinutesSeconds()
        }

        if (curMinute >= 0) && (curMinute <= 14) {
            quarterHourValue = 1
        } else if (curMinute >= 15) && (curMinute <= 29) {
            quarterHourValue = 2
        } else if (curMinute >= 30) && (curMinute <= 44) {
            quarterHourValue = 4
        } else if (curMinute >= 45) && (curMinute <= 59) {
            quarterHourValue = 8
        }

        let now = UInt32(Date().timeIntervalSince1970)
        updated = now
        lastSeen = now

        if oldSpawnpoint != nil {
            // check if we found tth for spawnpoint
            if oldSpawnpoint!.despawnSecond == nil && self.despawnSecond != nil              
            {
                Log.debug(message: "[Spawnpoint] - TTH found for spawnpoint with id=\(self.id)")
            }

            // check if TTH changed spawnpoint
            if oldSpawnpoint!.despawnSecond != nil && oldSpawnpoint!.despawnSecond != self.despawnSecond               
            {
                Log.debug(message: "[Spawnpoint] - TTH changed for spawnpoint with id=\(self.id)")
            }

            if self.despawnSecond == nil && oldSpawnpoint!.despawnSecond != nil {
                self.despawnSecond = oldSpawnpoint!.despawnSecond
            }

            // see if there is an update to spawn info
            if oldSpawnpoint != nil
            {
                self.spawnInfo = quarterHourValue | oldSpawnpoint!.spawnInfo!
            }

            if !SpawnPoint.hasChanges(old: oldSpawnpoint!, new: self) {
                return
            }

            // better to have inaccurate timestamp than none -> only update if the time differs more than 3 minutes,
            // use old despawn seconds if available then, otherwise keep new despawn seconds
            if !timestampAccurate, let oldDespawnSecond = oldSpawnpoint!.despawnSecond,
               let newDespawnSecond = self.despawnSecond {
                // depending on the other is great than the other
                // we have to subtract from smaller value to get valid result
                let absDifference = abs(Int(oldDespawnSecond) - Int(newDespawnSecond))
                let secondAbsDifference = 3600 - absDifference
                // difference can be either 900 or 2700 - e.g. if you compare despawnSec 800 with 3500
                if absDifference < secondAbsDifference && absDifference < 180 {
                    self.despawnSecond = oldDespawnSecond
                } else if absDifference > secondAbsDifference && secondAbsDifference < 180 {
                    self.despawnSecond = oldDespawnSecond
                }
            }
        }
        else // oldSpawnpoint == nil
        {
            // we have new spawnpoint, so need to set created
            self.created = now
        }

        var sql = """
            INSERT INTO spawnpoint (id, lat, lon, updated, last_seen, despawn_sec, spawn_info)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """
        if update {
            sql += """
            ON DUPLICATE KEY UPDATE
            lat=VALUES(lat),
            lon=VALUES(lon),
            updated=VALUES(updated),
            last_seen=VALUES(last_seen),
            despawn_sec=VALUES(despawn_sec),
            spawn_info=VALUES(spawn_info)
            """
        }

        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(id)
        mysqlStmt.bindParam(lat)
        mysqlStmt.bindParam(lon)
        mysqlStmt.bindParam(updated)
        mysqlStmt.bindParam(lastSeen)
        mysqlStmt.bindParam(despawnSecond)
        mysqlStmt.bindParam(spawnInfo)
        // mysqlStmt.bindParam(created) // we should not update/save, let db handle this as a default value when entry made

        guard mysqlStmt.execute() else {
            Log.error(message: "[SPAWNPOINT] Failed to execute query in save(). (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        SpawnPoint.cache?.set(id: id.toString(), value: self)

    }

    private static func hasChanges(old: SpawnPoint, new: SpawnPoint) -> Bool {
        return old.lat != new.lat ||
               old.lon != new.lon ||
               old.despawnSecond != new.despawnSecond ||
               old.spawnInfo != new.spawnInfo
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
            SELECT id, lat, lon, updated, last_seen, despawn_sec, spawn_info
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
            Log.error(message: "[SPAWNPOINT] Failed to execute query in getAll(). (\(mysqlStmt.errorMessage())")
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
            let spawnInfo = result[6] as! UInt32
            let created = result[7] as! UInt32

            spawnpoints.append(
                SpawnPoint(
                    id: id,
                    lat: lat,
                    lon: lon,
                    updated: updated,
                    lastSeen: lastSeen,
                    despawnSecond: despawnSecond,
                    spawnInfo: spawnInfo,
                    created: created
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
            SELECT id, lat, lon, updated, last_seen, despawn_sec, spawn_info, created
            FROM spawnpoint
            WHERE id = ?
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(id)

        guard mysqlStmt.execute() else {
            Log.error(message: "[SPAWNPOINT] Failed to execute query in getWithId(). (\(mysqlStmt.errorMessage())")
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
        let spawnInfo = result[6] as! UInt32
        let created = result[7] as! UInt32

        let spawnpoint = SpawnPoint(
            id: id,
            lat: lat,
            lon: lon,
            updated: updated,
            lastSeen: lastSeen,
            despawnSecond: despawnSecond,
            spawnInfo: spawnInfo,
            created: created
        )
        cache?.set(id: spawnpoint.id.toString(), value: spawnpoint)
        
        return spawnpoint
    }

    func secondsToHoursMinutesSeconds() -> (hours: UInt64, minutes: UInt64, seconds: UInt64) {
        let now = UInt64(Date().timeIntervalSince1970)
        return (UInt64(now / 3600), UInt64((now % 3600) / 60), UInt64((now % 3600) % 60))
    }
}
