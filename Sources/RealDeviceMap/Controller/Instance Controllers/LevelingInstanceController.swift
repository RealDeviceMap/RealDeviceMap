//
//  LevelingInstanceController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 29.01.20.
//

import Foundation
import PerfectLib
import PerfectThread
import POGOProtos
import Turf

class LevelingInstanceController: InstanceControllerProto {

    public private(set) var name: String
    public private(set) var minLevel: UInt8
    public private(set) var maxLevel: UInt8
    public weak var delegate: InstanceControllerDelegate?

    private let start: Coord
    private let unspunPokestopsPerUsernameLock = NSLock()
    private var unspunPokestopsPerUsername = [String: [String: POGOProtos_Map_Fort_FortData]]()
    private var lastLocactionUsername = [String: Coord]()

    init(name: String, start: Coord, minLevel: UInt8, maxLevel: UInt8) {
        self.name = name
        self.minLevel = minLevel
        self.maxLevel = maxLevel
        self.start = start
    }

    func getTask(uuid: String, username: String?) -> [String: Any] {

        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[LevelingInstanceController] Failed to connect to database.")
            return [:]
        }

        guard let username = username,
              let accountX = try? Account.getWithUsername(mysql: mysql, username: username),
              let account = accountX else {
            Log.error(message: "[LevelingInstanceController] Failed to get account.")
            return [:]
        }
        if account.failed == "GPR_RED_WARNING" || account.failed == "GPR_BANNED" {
            return ["action": "switch_account", "min_level": minLevel, "max_level": maxLevel]
        }

        unspunPokestopsPerUsernameLock.lock()
        guard let unspunPokestops = unspunPokestopsPerUsername[username]?.values.reversed(),
              let closestPokestop = findClosest(
                unspunPokestops: unspunPokestops, username: username, account: account
              ) else {
            unspunPokestopsPerUsernameLock.unlock()
            return ["action": "spin_pokestop", "lat": start.lat, "lon": start.lon, "delay":
                    0, "min_level": minLevel, "max_level": maxLevel]
        }
        unspunPokestopsPerUsername[username]![closestPokestop.id] = nil
        unspunPokestopsPerUsernameLock.unlock()

        let delay: Int
        do {
            delay = try Cooldown.encounter(
                account: account,
                deviceUUID: uuid,
                location: Coord(lat: closestPokestop.longitude, lon: closestPokestop.latitude)
            )
        } catch {
            Log.error(message: "[LevelingInstanceController] Failed to store cooldown.")
            return [:]
        }

        return [
            "action": "spin_pokestop",
            "lat": closestPokestop.latitude,
            "lon": closestPokestop.longitude,
            "delay": delay,
            "min_level": minLevel,
            "max_level": maxLevel
        ]

    }

    private func findClosest(unspunPokestops: [POGOProtos_Map_Fort_FortData], username: String,
                             account: Account) -> POGOProtos_Map_Fort_FortData? {
        var closest: POGOProtos_Map_Fort_FortData?
        var closestDistance: Double = 10000000000000000

        let current = CLLocationCoordinate2D(
            latitude: account.lastEncounterLat ?? start.lat,
            longitude: account.lastEncounterLon ?? start.lon
        )
        for stop in unspunPokestops {
            let coord = CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
            let dist = current.distance(to: coord)
            if dist < closestDistance {
                closest = stop
                closestDistance = dist
            }
        }
        return closest
    }

    func gotFortData(fortData: POGOProtos_Map_Fort_FortData, username: String?) {
        guard let username = username else {
            return
        }

        if fortData.type == .checkpoint {
            unspunPokestopsPerUsernameLock.lock()
            if unspunPokestopsPerUsername[username] == nil {
                unspunPokestopsPerUsername[username]! = [:]
            }
            if fortData.visited {
                unspunPokestopsPerUsername[username]![fortData.id] = nil
            } else {
                unspunPokestopsPerUsername[username]![fortData.id] = fortData
            }
            unspunPokestopsPerUsernameLock.unlock()
        }
    }

    func getStatus(formatted: Bool) -> JSONConvertible? {
        if formatted {
            return "-"
        } else {
            return nil
        }
    }

    func reload() {

    }

    func stop() {

    }

}
