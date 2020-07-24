//
//  Cell.swift
//  RealDeviceMap
//
//  Created by versx on 15.09.19.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable type_body_length function_body_length cyclomatic_complexity force_cast file_length

import Foundation
import PerfectLib
import PerfectMySQL
import POGOProtos
import S2Geometry

class Weather: JSONConvertibleObject, WebHookEvent {

    override func getJSONValues() -> [String: Any] {

        let s2cell = S2Cell(cellId: S2CellId(id: id))
        var polygon =  [[Double]]()
        for i in 0...3 {
            let coord = S2LatLng(point: s2cell.getVertex(i)).coord
            polygon.append([
                coord.latitude,
                coord.longitude
                ])
        }

        return [
            "id": id,
            "level": level,
            "latitude": latitude,
            "longitude": longitude,
            "polygon": polygon,
            "gameplay_condition": gameplayCondition,
            "wind_direction": windDirection,
            "cloud_level": cloudLevel,
            "rain_level": rainLevel,
            "wind_level": windLevel,
            "snow_level": snowLevel,
            "fog_level": fogLevel,
            "special_effect_level": sELevel,
            "severity": severity as Any,
            "warn_weather": warnWeather as Any,
            "updated": updated ?? 1
        ]
    }

    func getWebhookValues(type: String) -> [String: Any] {

        let s2cell = S2Cell(cellId: S2CellId(id: id))
        var polygon = [[Double]]()
        for i in 0...3 {
            let coord = S2LatLng(point: s2cell.getVertex(i)).coord
            polygon.append([
                coord.latitude,
                coord.longitude
                ])
        }

        let message: [String: Any] = [
            "s2_cell_id": id,
            "latitude": latitude,
            "longitude": longitude,
            "polygon": polygon,
            "gameplay_condition": gameplayCondition as Any,
            "wind_direction": windDirection as Any,
            "cloud_level": cloudLevel as Any,
            "rain_level": rainLevel as Any,
            "wind_level": windLevel as Any,
            "snow_level": snowLevel as Any,
            "fog_level": fogLevel as Any,
            "special_effect_level": sELevel as Any,
            "severity": severity as Any,
            "warn_weather": warnWeather as Any,
            "updated": updated ?? 1
        ]
        return [
            "type": "weather",
            "message": message
        ]
    }

    var id: Int64
    var level: UInt8
    var latitude: Double
    var longitude: Double
    var gameplayCondition: UInt8
    var windDirection: Int32
    var cloudLevel: UInt8
    var rainLevel: UInt8
    var windLevel: UInt8
    var snowLevel: UInt8
    var fogLevel: UInt8
    var sELevel: UInt8
    var severity: UInt8? = 0
    var warnWeather: Bool? = false
    var updated: UInt32?

    init(id: Int64, level: UInt8, latitude: Double, longitude: Double, gameplayCondition: UInt8, windDirection: Int32,
         cloudLevel: UInt8, rainLevel: UInt8, windLevel: UInt8, snowLevel: UInt8, fogLevel: UInt8, sELevel: UInt8,
         severity: UInt8?, warnWeather: Bool?, updated: UInt32?) {
        self.id = id
        self.level = level
        self.latitude = latitude
        self.longitude = longitude
        self.gameplayCondition = gameplayCondition
        self.windDirection = windDirection
        self.cloudLevel = cloudLevel
        self.rainLevel = rainLevel
        self.windLevel = windLevel
        self.snowLevel = snowLevel
        self.fogLevel = fogLevel
        self.sELevel = sELevel
        self.severity = severity
        self.warnWeather = warnWeather
        self.updated = updated
    }

    init(mysql: MySQL?=nil, id: Int64, level: UInt8, latitude: Double, longitude: Double,
         conditions: POGOProtos_Map_Weather_ClientWeather, updated: UInt32?) {
        self.id = id
        self.level = level
        self.latitude = latitude
        self.longitude = longitude
        self.gameplayCondition = conditions.gameplayWeather.gameplayCondition.rawValue.toUInt8()
        self.windDirection = conditions.displayWeather.windDirection
        self.cloudLevel = conditions.displayWeather.cloudLevel.rawValue.toUInt8()
        self.rainLevel = conditions.displayWeather.rainLevel.rawValue.toUInt8()
        self.windLevel = conditions.displayWeather.windLevel.rawValue.toUInt8()
        self.snowLevel = conditions.displayWeather.snowLevel.rawValue.toUInt8()
        self.fogLevel = conditions.displayWeather.fogLevel.rawValue.toUInt8()
        self.sELevel = conditions.displayWeather.specialEffectLevel.rawValue.toUInt8()
        for severityConditions in conditions.alerts {
            severity = severityConditions.severity.rawValue.toUInt8()
            warnWeather = severityConditions.warnWeather
        }
        self.updated = updated
    }

    public func save(mysql: MySQL?=nil) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[WEATHER] Failed to connect to database.")
            throw DBController.DBError()
        }

        let oldWeather: Weather?
        do {
            oldWeather = try Weather.getWithId(mysql: mysql, id: id)
        } catch {
            oldWeather = nil
        }

        let sql: String

        if let oldWeather = oldWeather {
            guard Weather.shouldUpdate(old: oldWeather, new: self) else {
                return
            }
            sql = """
            UPDATE `weather`
            SET level = ?, latitude = ?, longitude = ?, gameplay_condition = ?, wind_direction = ?, cloud_level = ?,
                rain_level = ?, wind_level = ?, snow_level = ?, fog_level = ?, special_effect_level = ?, severity = ?,
                warn_weather = ?, updated = UNIX_TIMESTAMP()
            WHERE id = ?
            """
        } else {
            sql = """
            INSERT INTO `weather` (
                id, level, latitude, longitude, gameplay_condition, wind_direction, cloud_level, rain_level, wind_level,
                snow_level, fog_level, special_effect_level, severity, warn_weather, updated
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, UNIX_TIMESTAMP())
            """
        }

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        if oldWeather == nil {
            mysqlStmt.bindParam(id)
        }
        mysqlStmt.bindParam(level)
        mysqlStmt.bindParam(latitude)
        mysqlStmt.bindParam(longitude)
        mysqlStmt.bindParam(gameplayCondition)
        mysqlStmt.bindParam(windDirection)
        mysqlStmt.bindParam(cloudLevel)
        mysqlStmt.bindParam(rainLevel)
        mysqlStmt.bindParam(windLevel)
        mysqlStmt.bindParam(snowLevel)
        mysqlStmt.bindParam(fogLevel)
        mysqlStmt.bindParam(sELevel)
        mysqlStmt.bindParam(severity)
        mysqlStmt.bindParam(warnWeather)
        if oldWeather != nil {
            mysqlStmt.bindParam(id)
        }

        guard mysqlStmt.execute() else {
            if mysqlStmt.errorCode() == 1062 {
                Log.debug(message: "[WEATHER] Duplicated key. Skipping...")
            } else {
                Log.error(message: "[WEATHER] Failed to execute query. (\(mysqlStmt.errorMessage()))")
            }
            throw DBController.DBError()
        }

        if oldWeather == nil {
            WebHookController.global.addWeatherEvent(weather: self)
        } else if oldWeather!.gameplayCondition != self.gameplayCondition ||
                  oldWeather!.warnWeather != self.warnWeather {
            WebHookController.global.addWeatherEvent(weather: self)
        }
    }

    public static func getWithId(mysql: MySQL?=nil, id: Int64) throws -> Weather? {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[WEATHER] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
        SELECT id, level, latitude, longitude, gameplay_condition, wind_direction, cloud_level,
               rain_level, wind_level, snow_level, fog_level, special_effect_level, severity, warn_weather, updated
        FROM weather
        WHERE id = ?
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(id)

        guard mysqlStmt.execute() else {
            Log.error(message: "[WEATHER] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }
        let result = results.next()!

        let id = result[0] as! Int64
        let level = result[1] as! UInt8
        let latitude = result[2] as! Double
        let longitude = result[3] as! Double
        let gameplayCondition = result[4] as! UInt8
        let windDirection = result[5] as! Int32
        let cloudLevel = result[6] as! UInt8
        let rainLevel = result[7] as! UInt8
        let windLevel = result[8] as! UInt8
        let snowLevel = result[9] as! UInt8
        let fogLevel = result[10] as! UInt8
        let sELevel = result[11] as! UInt8
        let severity = result[12] as! UInt8
        let warnWeather = (result[13] as? UInt8)!.toBool()
        let updated = result[14] as! UInt32

        return Weather(
            id: id, level: level, latitude: latitude, longitude: longitude, gameplayCondition: gameplayCondition,
            windDirection: windDirection, cloudLevel: cloudLevel, rainLevel: rainLevel, windLevel: windLevel,
            snowLevel: snowLevel, fogLevel: fogLevel, sELevel: sELevel, severity: severity,
            warnWeather: warnWeather, updated: updated
        )
    }

    public static func getAll(mysql: MySQL?=nil, minLat: Double, maxLat: Double, minLon: Double,
                              maxLon: Double, updated: UInt32) throws -> [Weather] {

        let minLatReal = minLat - 0.1
        let maxLatReal = maxLat + 0.1
        let minLonReal = minLon - 0.1
        let maxLonReal = maxLon + 0.1

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[WEATHER] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
        SELECT id, level, latitude, longitude, gameplay_condition, wind_direction, cloud_level,
               rain_level, wind_level, snow_level, fog_level, special_effect_level, severity, warn_weather, updated
        FROM weather
        WHERE latitude >= ? AND latitude <= ? AND longitude >= ? AND longitude <= ? AND updated > ?
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(minLatReal)
        mysqlStmt.bindParam(maxLatReal)
        mysqlStmt.bindParam(minLonReal)
        mysqlStmt.bindParam(maxLonReal)
        mysqlStmt.bindParam(updated)

        guard mysqlStmt.execute() else {
            Log.error(message: "[WEATHER] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var weather = [Weather]()
        while let result = results.next() {

            let id = result[0] as! Int64
            let level = result[1] as! UInt8
            let latitude = result[2] as! Double
            let longitude = result[3] as! Double
            let gameplayCondition = result[4] as! UInt8
            let windDirection = result[5] as! Int32
            let cloudLevel = result[6] as! UInt8
            let rainLevel = result[7] as! UInt8
            let windLevel = result[8] as! UInt8
            let snowLevel = result[9] as! UInt8
            let fogLevel = result[10] as! UInt8
            let sELevel = result[11] as! UInt8
            let severity = result[12] as! UInt8
            let warnWeather = (result[13] as? UInt8)!.toBool()
            let updated = result[14] as! UInt32

            weather.append(Weather(
                id: id, level: level, latitude: latitude, longitude: longitude, gameplayCondition: gameplayCondition,
                windDirection: windDirection, cloudLevel: cloudLevel, rainLevel: rainLevel, windLevel: windLevel,
                snowLevel: snowLevel, fogLevel: fogLevel, sELevel: sELevel, severity: severity,
                warnWeather: warnWeather, updated: updated
            ))
        }
        return weather

    }

    public static func getInIDs(mysql: MySQL?=nil, ids: [Int64]) throws -> [Weather] {

        if ids.count > 10000 {
            var result = [Weather]()
            for i in 0..<(Int(ceil(Double(ids.count)/10000.0))) {
                let start = 10000 * i
                let end = min(10000 * (i+1) - 1, ids.count - 1)
                let splice = Array(ids[start...end])
                if let spliceResult = try? getInIDs(mysql: mysql, ids: splice) {
                    result += spliceResult
                }
            }
            return result
        }

        if ids.count == 0 {
            return [Weather]()
        }

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[WEATHER] Failed to connect to database.")
            throw DBController.DBError()
        }

        var inSQL = "("
        for _ in 1..<ids.count {
            inSQL += "?, "
        }
        inSQL += "?)"

        let sql = """
        SELECT id, level, latitude, longitude, gameplay_condition, wind_direction, cloud_level, rain_level,
               wind_level, snow_level, fog_level, special_effect_level, severity, warn_weather, updated
        FROM weather
        WHERE id IN \(inSQL)
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        for id in ids {
            mysqlStmt.bindParam(id)
        }

        guard mysqlStmt.execute() else {
            Log.error(message: "[WEATHER] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var weather = [Weather]()
        while let result = results.next() {

            let id = result[0] as! Int64
            let level = result[1] as! UInt8
            let latitude = result[2] as! Double
            let longitude = result[3] as! Double
            let gameplayCondition = result[4] as! UInt8
            let windDirection = result[5] as! Int32
            let cloudLevel = result[6] as! UInt8
            let rainLevel = result[7] as! UInt8
            let windLevel = result[8] as! UInt8
            let snowLevel = result[9] as! UInt8
            let fogLevel = result[10] as! UInt8
            let sELevel = result[11] as! UInt8
            let severity = result[12] as! UInt8
            let warnWeather = (result[13] as? UInt8)!.toBool()
            let updated = result[14] as! UInt32

            weather.append(Weather(
                id: id, level: level, latitude: latitude, longitude: longitude, gameplayCondition: gameplayCondition,
                windDirection: windDirection, cloudLevel: cloudLevel, rainLevel: rainLevel, windLevel: windLevel,
                snowLevel: snowLevel, fogLevel: fogLevel, sELevel: sELevel, severity: severity,
                warnWeather: warnWeather, updated: updated
            ))
        }
        return weather

    }

    public static func shouldUpdate(old: Weather, new: Weather) -> Bool {
        return
            new.id != old.id ||
            new.level != old.level ||
            new.gameplayCondition != old.gameplayCondition ||
            new.windDirection != old.windDirection ||
            new.cloudLevel != old.cloudLevel ||
            new.rainLevel != old.rainLevel ||
            new.windLevel != old.windLevel ||
            new.snowLevel != old.snowLevel ||
            new.fogLevel != old.fogLevel ||
            new.sELevel != old.sELevel ||
            new.severity != old.severity ||
            new.warnWeather != old.warnWeather ||
            fabs(new.latitude - old.latitude) >= 0.000001 ||
            fabs(new.longitude - old.longitude) >= 0.000001
    }

}
