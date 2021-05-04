//
//  LevelingInstanceController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 29.01.20.
//
//  swiftlint:disable type_body_length function_body_length cyclomatic_complexity

import Foundation
import PerfectLib
import PerfectThread
import PerfectMySQL
import POGOProtos
import Turf

class LevelingInstanceController: InstanceControllerProto {

    public private(set) var name: String
    public private(set) var minLevel: UInt8
    public private(set) var maxLevel: UInt8
    public private(set) var accountGroup: String?
    public private(set) var isEvent: Bool
    public weak var delegate: InstanceControllerDelegate?

    private static let levelXP = [
        0,
        0,
        1000,
        3000,
        6000,
        10000,
        15000,
        21000,
        28000,
        36000,
        45000,
        55000,
        65000,
        75000,
        85000,
        100000,
        120000,
        140000,
        160000,
        185000,
        210000,
        260000,
        335000,
        435000,
        560000,
        710000,
        900000,
        1100000,
        1350000,
        1650000,
        2000000,
        2500000,
        3000000,
        3750000,
        4750000,
        6000000,
        7500000,
        9500000,
        12000000,
        15000000,
        20000000
    ]

    private let start: Coord
    private let storeData: Bool
    private let radius: UInt64
    private let unspunPokestopsPerUsernameLock = NSLock()
    private var unspunPokestopsPerUsername = [String: [String: PokemonFortProto]]()
    private var lastPokestopsPerUsername = [String: [Coord]]()
    private let playerLock = NSLock()
    private var playerLastSeen = [String: Date]()
    private var playerXP = [String: Int]()
    private var playerLevel = [String: Int]()
    private var playerXPPerTime = [String: [(date: Date, xp: Int)]]()
    private var lastLocactionUsername = [String: Coord]()

    init(name: String, start: Coord, minLevel: UInt8, maxLevel: UInt8, storeData: Bool,
         radius: UInt64, accountGroup: String?, isEvent: Bool) {
        self.name = name
        self.minLevel = minLevel
        self.maxLevel = maxLevel
        self.accountGroup = accountGroup
        self.isEvent = isEvent
        self.start = start
        self.storeData = storeData
        self.radius = radius
    }

    func getTask(mysql: MySQL, uuid: String, username: String?, account: Account?) -> [String: Any] {

        guard let username = username else {
            Log.error(message: "[LevelingInstanceController] [\(name)] [\(uuid)] No username specified.")
            return [:]
        }

        guard let account = account else {
            Log.error(message: "[LevelingInstanceController] [\(name)] [\(uuid)] No account specified.")
            return [:]
        }

        if lastPokestopsPerUsername[username] == nil {
            lastPokestopsPerUsername[username] = []
        }
        let destination: Coord
        unspunPokestopsPerUsernameLock.lock()
        if let unspunPokestops = unspunPokestopsPerUsername[username]?.values.reversed(),
            let closestPokestop = findClosest(
                unspunPokestops: unspunPokestops,
                exclude: lastPokestopsPerUsername[username]!,
                username: username,
                account: account
            ) {
            destination = Coord(lat: closestPokestop.latitude, lon: closestPokestop.longitude)
            unspunPokestopsPerUsername[username]![closestPokestop.fortID] = nil
            while lastPokestopsPerUsername[username]!.count > 5 {
                _ = lastPokestopsPerUsername[username]!.remove(at: 0)
            }
            lastPokestopsPerUsername[username]!.append(destination)
        } else {
            destination = start
        }
        unspunPokestopsPerUsernameLock.unlock()

        let delay: Int
        let encounterTime: UInt32
        do {
            let result = try Cooldown.cooldown(
                account: account,
                deviceUUID: uuid,
                location: destination
            )
            delay = result.delay
            encounterTime = result.encounterTime
        } catch {
            Log.error(message: "[LevelingInstanceController] [\(name)] [\(uuid)] Failed to calculate cooldown.")
            return [String: Any]()
        }

        do {
            try Cooldown.encounter(
                mysql: mysql,
                account: account,
                deviceUUID: uuid,
                location: destination,
                encounterTime: encounterTime
          )
        } catch {
            Log.error(message: "[LevelingInstanceController] [\(name)] [\(uuid)] Failed to store cooldown.")
            return [String: Any]()
        }

        playerLock.lock()
        playerLastSeen[username] = Date()
        playerLock.unlock()

        return [
            "action": "spin_pokestop",
            "deploy_egg": true,
            "lat": destination.lat,
            "lon": destination.lon,
            "delay": delay,
            "min_level": minLevel,
            "max_level": maxLevel
        ]

    }

    private func findClosest(unspunPokestops: [PokemonFortProto], exclude: [Coord], username: String,
                             account: Account) -> PokemonFortProto? {
        var closest: PokemonFortProto?
        var closestDistance: Double = 10000000000000000

        let current = Coord(
            lat: account.lastEncounterLat ?? start.lat,
            lon: account.lastEncounterLon ?? start.lon
        )
        unspunLoop: for stop in unspunPokestops {
            let coord = Coord(lat: stop.latitude, lon: stop.longitude)
            for last in exclude {
                // MARK: Revert back to 40m once reverted ingame
                if coord.distance(to: last) <= 80 {
                    continue unspunLoop
                }
            }

            let dist = current.distance(to: coord)
            if dist < closestDistance {
                closest = stop
                closestDistance = dist
            }
        }
        return closest
    }

    func gotFortData(fortData: PokemonFortProto, username: String?) {
        guard let username = username else {
            return
        }

        if fortData.fortType == .checkpoint {
            let coord = Coord(lat: fortData.latitude, lon: fortData.longitude)
            if UInt64(coord.distance(to: start)) <= radius {
                unspunPokestopsPerUsernameLock.lock()
                if unspunPokestopsPerUsername[username] == nil {
                    unspunPokestopsPerUsername[username] = [:]
                }
                if fortData.visited {
                    unspunPokestopsPerUsername[username]![fortData.fortID] = nil
                } else {
                    unspunPokestopsPerUsername[username]![fortData.fortID] = fortData
                }
                unspunPokestopsPerUsernameLock.unlock()
            }
        }
    }

    func gotPlayerInfo(username: String, level: Int, xp: Int) {
        playerLock.lock()
        playerLevel[username] = level
        playerXP[username] = xp
        if playerXPPerTime[username] == nil {
            playerXPPerTime[username] = []
        }
        playerXPPerTime[username]!.append((Date(), xp))
        playerLock.unlock()
    }

    func getStatus(mysql: MySQL, formatted: Bool) -> JSONConvertible? {
        var players = [String]()
        playerLock.lock()
        for player in playerLastSeen {
            if Date().timeIntervalSince(player.value) <= 3600 {
                players.append(player.key)
            }
        }

        var data = [[String: Any]]()
        for player in players {
            let xpTarget = LevelingInstanceController.levelXP[min(max(Int(maxLevel) + 1, 0), 40)]
            let xpStart = LevelingInstanceController.levelXP[min(max(Int(minLevel), 0), 40)]
            let xpCurrent = playerXP[player] ?? 0
            let xpPercentage = Double(xpCurrent - xpStart) / Double(xpTarget - xpStart) * 100
            var startXP = 0
            var startTime = Date()

            for xpPerTime in playerXPPerTime[player] ?? [] {
                if Date().timeIntervalSince(xpPerTime.date) <= 3600 {
                    startXP = xpPerTime.xp
                    startTime = xpPerTime.date
                    break
                } else {
                    _ = playerXPPerTime.popFirst()
                }
            }

            let xpDelta = (playerXPPerTime[player]?.last?.xp ?? startXP) - startXP
            let timeDelta = max(
                1,
                (playerXPPerTime[player]?.last?.date.timeIntervalSince1970 ?? startTime.timeIntervalSince1970) -
                    startTime.timeIntervalSince1970
            )
            let xpPerHour = Int(Double(xpDelta) / timeDelta * 3600)
            let timeLeft = Double(xpTarget - xpCurrent) / Double(xpPerHour)

            data.append([
                "xp_target": xpTarget,
                "xp_start": xpStart,
                "xp_current": xpCurrent,
                "xp_percentage": xpPercentage,
                "level": playerLevel[player] ?? 0,
                "username": player,
                "xp_per_hour": xpPerHour,
                "time_left": timeLeft
            ])
        }

        if formatted {
            var text = ""
            for player in data {
                if text != "" {
                    text += "<br>"
                }
                let username = player["username"] as? String ?? "?"
                let level = player["level"] as? Int ?? 0
                let xpPercentage = (player["xp_percentage"] as? Double ?? 0).rounded(decimals: 1)
                let xpPerHour = (player["xp_per_hour"] as? Int ?? 0).withCommas()
                let timeLeft = player["time_left"] as? Double ?? 0

                let timeLeftHours: Int
                let timeLeftMinutes: Int
                if timeLeft == .infinity || timeLeft == -.infinity || timeLeft.isNaN {
                    timeLeftHours = 999
                    timeLeftMinutes = 0
                } else {
                    timeLeftHours = Int(timeLeft)
                    timeLeftMinutes = Int((timeLeft - Double(timeLeftHours)) * 60)
                }

                if level > maxLevel {
                    text += "\(username): Lvl.\(level) done"
                } else {
                    text += "\(username): Lvl.\(level) \((xpPercentage))% \(xpPerHour)XP/h " +
                            "\(timeLeftHours)h\(timeLeftMinutes)m"
                }
            }
            playerLock.unlock()
            if text == "" {
                text = "-"
            }
            return text
        } else {
            playerLock.unlock()
            return data
        }
    }

    func shouldStoreData() -> Bool {
        return storeData
    }

    func reload() {

    }

    func stop() {

    }

    func getAccount(mysql: MySQL, uuid: String) throws -> Account? {
        return try Account.getNewAccount(
            mysql: mysql,
            minLevel: minLevel,
            maxLevel: maxLevel,
            ignoringWarning: false,
            spins: nil, // 7000
            noCooldown: true,
            device: uuid,
            group: accountGroup
        )
    }

    func accountValid(account: Account) -> Bool {
        return
            account.level >= minLevel &&
            account.level <= maxLevel &&
            account.isValid(group: accountGroup) // && account.hasSpinsLeft(spins: 7000)
    }

}
