//
//  CircleInstanceController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 30.09.18.
//

import Foundation
import PerfectLib
import PerfectThread
import PerfectMySQL

class CircleInstanceController: InstanceControllerProto {

    enum CircleType {
        case pokemon
        case smartPokemon
        case raid
    }

    public private(set) var name: String
    public private(set) var minLevel: UInt8
    public private(set) var maxLevel: UInt8
    public private(set) var accountGroup: String?
    public private(set) var isEvent: Bool
    public weak var delegate: InstanceControllerDelegate?

    private let type: CircleType
    private let coords: [Coord]
    private var lastIndex: Int = 0
    private var lock = Threading.Lock()
    private var lastLastCompletedTime: Date?
    private var lastCompletedTime: Date?
    private var currentUuidIndexes: [String: Int]
    private var currentUuidSeenTime: [String: Date]
    public let useRwForRaid =
        ProcessInfo.processInfo.environment["USE_RW_FOR_RAID"] != nil

    init(name: String, coords: [Coord], type: CircleType, minLevel: UInt8, maxLevel: UInt8,
         accountGroup: String?, isEvent: Bool) {
        self.name = name
        self.minLevel = minLevel
        self.maxLevel = maxLevel
        self.accountGroup = accountGroup
        self.isEvent = isEvent
        self.coords = coords
        self.type = type
        self.lastCompletedTime = Date()
        self.currentUuidIndexes = [:]
        self.currentUuidSeenTime = [:]
    }

    func routeDistance(xcoord: Int, ycoord: Int) -> Int {
        if xcoord < ycoord {
            return ycoord - xcoord
        }
        return ycoord + (coords.count - xcoord)
    }

    func checkSpacingDevices(uuid: String) -> [String: Int] {
        let deadDeviceCutoffTime = Date().addingTimeInterval(-60)
        var liveDevices = [String]()

        // Check if all registered devices are still online and clean list
        for (currentUuid, _) in currentUuidIndexes.sorted(by: { return $0.1 < $1.1 }) {
            let lastSeen = currentUuidSeenTime[currentUuid]
            if lastSeen != nil {
                if lastSeen! < deadDeviceCutoffTime {
                    currentUuidIndexes[currentUuid] = nil
                    currentUuidSeenTime[currentUuid] = nil
                } else {
                    liveDevices.append(currentUuid)
                }
            }
        }

        let nbliveDevices = liveDevices.count
        var distanceToNext = coords.count

        for i in 0..<nbliveDevices {
            if uuid != liveDevices[i] {
                continue
            }
            if i < nbliveDevices - 1 {
                let nextDevice = liveDevices[i+1]
                distanceToNext = routeDistance(xcoord: currentUuidIndexes[uuid]!,
                                               ycoord: currentUuidIndexes[nextDevice]!)
            } else {
                let nextDevice = liveDevices[0]
                distanceToNext = routeDistance(xcoord: currentUuidIndexes[uuid]!,
                                               ycoord: currentUuidIndexes[nextDevice]!)
            }
        }
        return ["numliveDevices": nbliveDevices, "distanceToNext": distanceToNext]
    }

    // swiftlint:disable function_body_length
    func getTask(mysql: MySQL, uuid: String, username: String?, account: Account?) -> [String: Any] {
        var currentIndex = 0
        var currentUuidIndex = 0
        var currentCoord = coords[currentIndex]
        if type == .smartPokemon {
            lock.lock()
            currentUuidIndex = currentUuidIndexes[uuid] ?? Int.random(in: 0..<coords.count)
            currentUuidIndexes[uuid] = currentUuidIndex
            currentUuidSeenTime[uuid] = Date()
            var shouldAdvance = true
            var jumpDistance = 0

            if currentUuidIndexes.count > 1 && Int.random(in: 0...100) < 15 {
                let live = checkSpacingDevices(uuid: uuid)
                let dist = 10 * live["distanceToNext"]! * live["numliveDevices"]! + 5
                if dist < 10 * coords.count {
                    shouldAdvance = false
                }
                if dist > 12 * coords.count {
                    jumpDistance = live["distanceToNext"]! - coords.count / live["numliveDevices"]! - 1
                }
            }
            if currentUuidIndex == 0 {
                shouldAdvance = true
            }
            if shouldAdvance {
                currentUuidIndex += jumpDistance + 1
                if currentUuidIndex >= coords.count - 1 {
                    currentUuidIndex -= coords.count - 1
                    lastLastCompletedTime = lastCompletedTime
                    lastCompletedTime = Date()
                }
            } else {
                currentUuidIndex -= 1
                if currentUuidIndex < 0 {
                    currentUuidIndex = coords.count - 1
                }
            }
            lock.unlock()
            currentUuidIndexes[uuid] = currentUuidIndex
            currentCoord = coords[currentUuidIndex]
            return ["action": "scan_pokemon", "lat": currentCoord.lat, "lon": currentCoord.lon,
                    "min_level": minLevel, "max_level": maxLevel]
        } else {
            lock.lock()
            currentIndex = self.lastIndex
            if lastIndex + 1 == coords.count {
                lastLastCompletedTime = lastCompletedTime
                lastCompletedTime = Date()
                lastIndex = 0
            } else {
                lastIndex += 1
            }
            lock.unlock()
            currentCoord = coords[currentIndex]
            if type == .pokemon {
                return ["action": "scan_pokemon", "lat": currentCoord.lat, "lon": currentCoord.lon,
                        "min_level": minLevel, "max_level": maxLevel]
            } else {
                return ["action": "scan_raid", "lat": currentCoord.lat, "lon": currentCoord.lon,
                        "min_level": minLevel, "max_level": maxLevel]
            }
        }
    }
    // swiftlint:enable function_body_length

    func getStatus(mysql: MySQL, formatted: Bool) -> JSONConvertible? {
        if let lastLast = lastLastCompletedTime, let last = lastCompletedTime {
            let time = Int(last.timeIntervalSince(lastLast))
            if formatted {
                return "Round Time: \(time)s"
            } else {
                return ["round_time": time]
            }
        } else {
            if formatted {
                return "-"
            } else {
                return nil
            }
        }
    }

    func reload() {
        lock.lock()
        lastIndex = 0
        lock.unlock()
    }

    func stop() {}

    func getAccount(mysql: MySQL, uuid: String) throws -> Account? {
        switch type {
        case .pokemon, .smartPokemon:
            return try Account.getNewAccount(
                mysql: mysql,
                minLevel: minLevel,
                maxLevel: maxLevel,
                ignoringWarning: false,
                spins: nil,
                noCooldown: false,
                device: uuid,
                group: accountGroup
            )
        case .raid:
            return try Account.getNewAccount(
                mysql: mysql,
                minLevel: minLevel,
                maxLevel: maxLevel,
                ignoringWarning: useRwForRaid,
                spins: nil,
                noCooldown: false,
                device: uuid,
                group: accountGroup
            )
        }
    }

    func accountValid(account: Account) -> Bool {
        switch type {
        case .pokemon, .smartPokemon:
            return account.level >= minLevel &&
                account.level <= maxLevel &&
                account.isValid(group: accountGroup)
        case .raid:
            return account.level >= minLevel &&
                account.level <= maxLevel &&
                account.isValid(ignoringWarning: useRwForRaid, group: accountGroup)
        }
    }

}
