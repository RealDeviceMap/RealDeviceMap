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

    private static let cooldownDataArray = [
        0.1: 0, 0.3: 0.16, 1: 1, 2: 2, 4: 3, 5: 4, 8: 5, 10: 7, 15: 9, 20: 12, 25: 15, 30: 17, 35: 18, 45: 20,
        50: 20, 60: 21, 70: 23, 80: 24, 90: 25, 100: 26, 125: 29, 150: 32, 175: 34, 201: 37,
        250: 41, 300: 46, 328: 48, 350: 50, 400: 54, 450: 58,
        500: 62, 550: 66, 600: 70, 650: 74, 700: 77, 751: 82, 802: 84, 839: 88, 897: 90, 900: 91, 948: 95,
        1007: 98, 1020: 102, 1100: 104, 1180: 109, 1200: 111, 1221: 113, 1300: 117, 1344: 119,
        Double(Int.max): 120
    ].sorted { (lhs, rhs) -> Bool in
        lhs.key < rhs.key
    }

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

        if lastLon == nil || lastLon == nil {
            return nil
        } else {
            return Coord(lat: lastLat!, lon: lastLon!)
        }

    }

    // swiftlint:disable:next function_body_length
    public static func encounter(mysql: MySQL?=nil, account: Account?, deviceUUID: String,
                                 location: Coord) throws -> Int {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[Cooldown] Failed to connect to database.")
            throw DBController.DBError()
        }

        let lastLat: Double?
        let lastLon: Double?
        var lastTime: UInt32?
        if let account = account {
            lastLat = account.lastEncounterLat
            lastLon = account.lastEncounterLon
            lastTime = account.lastEncounterTime
        } else {
            lastLat = Double(try DBController.global.getValueForKey(key: "AIC_\(deviceUUID)_last_lat") ?? "")
            lastLon = Double(try DBController.global.getValueForKey(key: "AIC_\(deviceUUID)_last_lon") ?? "")
            lastTime = UInt32(try DBController.global.getValueForKey(key: "AIC_\(deviceUUID)_last_time") ?? "")
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
            if lastTime! > now {
                lastTime = now
            }
            let encounterTimeT = lastTime! + encounterCooldown(distM: distance)
            if encounterTimeT < now {
                encounterTime = now
            } else {
                encounterTime = encounterTimeT
            }
            if encounterTime - now >= 7200 {
                encounterTime = now + 7200
            }
            let delayT = Int(Date(timeIntervalSince1970: Double(encounterTime)).timeIntervalSinceNow)
            if delayT < 0 {
                delay = 0
            } else {
                delay = delayT + 1
            }
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
                value: location.lat.description
            )
            try DBController.global.setValueForKey(
                key: "AIC_\(deviceUUID)_last_lon",
                value: location.lon.description
            )
            try DBController.global.setValueForKey(
                key: "AIC_\(deviceUUID)_last_time",
                value: encounterTime.description
            )
        }

        return delay
    }

    private static func encounterCooldown(distM: Double) -> UInt32 {
         let dist = distM / 1000
         for data in cooldownDataArray where data.key >= dist {
             return UInt32(data.value * 60)
         }
         return 0
     }

}
