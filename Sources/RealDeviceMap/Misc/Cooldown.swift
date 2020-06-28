//
//  Cooldown.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 29.01.20.
//

import Foundation
import PerfectMySQL
import PerfectLib

class Cooldown {

    private init() {}

    public static func lastLocation(account: Account?, deviceUUID: String) throws -> Coord? {

        let lastLat: Double?
        let lastLon: Double?
        if let account = account {
            lastLat = account.lastEncounterLat
            lastLon = account.lastEncounterLon
        } else {
            lastLat = Double(try DBController.global.getValueForKey(key: "AIC_\(deviceUUID)_last_lat") ?? "")
            lastLon = Double(try DBController.global.getValueForKey(key: "AIC_\(deviceUUID)_last_lon") ?? "")
        }

        if lastLat == nil || lastLon == nil {
            return nil
        } else {
            return Coord(lat: lastLat!, lon: lastLon!)
        }

    }

    public static func encounter(mysql: MySQL?=nil, account: Account?, deviceUUID: String,
                                 location: Coord, encounterTime: UInt32) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[Cooldown] Failed to connect to database.")
            throw DBController.DBError()
        }
        if let account = account {
           try Account.didEncounter(
               mysql: mysql,
               username: account.username,
               lon: location.lon,
               lat: location.lat,
               time: encounterTime
           )
        } else {
           try DBController.global.setValueForKey(
               key: "AIC_\(deviceUUID)_last_lat",
               value: location.lat.description,
               mysql: mysql
           )
           try DBController.global.setValueForKey(
               key: "AIC_\(deviceUUID)_last_lon",
               value: location.lon.description,
               mysql: mysql
           )
           try DBController.global.setValueForKey(
               key: "AIC_\(deviceUUID)_last_time",
               value: encounterTime.description,
               mysql: mysql
           )
       }
    }

    public static func cooldown(mysql: MySQL?=nil, account: Account?, deviceUUID: String,
                                location: Coord) throws -> (delay: Int, encounterTime: UInt32) {
        let lastLat: Double?
        let lastLon: Double?
        let lastTime: UInt32?
        if let account = account {
            lastLat = account.lastEncounterLat
            lastLon = account.lastEncounterLon
            lastTime = account.lastEncounterTime
        } else {
            lastLat = Double(try DBController.global.getValueForKey(key: "AIC_\(deviceUUID)_last_lat",
                                                                    mysql: mysql) ?? "")
            lastLon = Double(try DBController.global.getValueForKey(key: "AIC_\(deviceUUID)_last_lon",
                                                                    mysql: mysql) ?? "")
            lastTime = UInt32(try DBController.global.getValueForKey(key: "AIC_\(deviceUUID)_last_time",
                                                                    mysql: mysql) ?? "")
        }

        let delay: Int
        var encounterTime: UInt32
        let now = UInt32(Date().timeIntervalSince1970)

        if lastLat == nil || lastLon == nil || lastTime == nil {
            delay = 0
            encounterTime = now
        } else {
            let lastCoord = Coord(lat: lastLat!, lon: lastLon!)
            let distance = lastCoord.distance(to: location)
            let encounterTimeT = lastTime! + encounterCooldown(distM: distance)
            if encounterTimeT < now {
                encounterTime = now
            } else {
                encounterTime = encounterTimeT
            }
            if encounterTime - now >= 7200 {
                encounterTime = now + 7200
            }
            delay = Int(encounterTime - now)
        }
        return (delay: delay, encounterTime: encounterTime)
    }

    private static func encounterCooldown(distM: Double) -> UInt32 {
        return UInt32(distM / 9.8)
    }

}
