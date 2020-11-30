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
    }

    func getTask(mysql: MySQL, uuid: String, username: String?, account: Account?) -> [String: Any] {

        lock.lock()
        let currentIndex = self.lastIndex
        if lastIndex + 1 == coords.count {
            lastLastCompletedTime = lastCompletedTime
            lastCompletedTime = Date()
            lastIndex = 0
        } else {
            lastIndex += 1
        }
        lock.unlock()

        let currentCoord = coords[currentIndex]

        if type == .pokemon {
            return ["action": "scan_pokemon", "lat": currentCoord.lat, "lon": currentCoord.lon,
                    "min_level": minLevel, "max_level": maxLevel]
        } else {
            return ["action": "scan_raid", "lat": currentCoord.lat, "lon": currentCoord.lon,
                    "min_level": minLevel, "max_level": maxLevel]
        }

    }

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
        case .pokemon:
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
                ignoringWarning: true,
                spins: nil,
                noCooldown: false,
                device: uuid,
                group: accountGroup
            )
        }
    }

    func accountValid(account: Account) -> Bool {
        switch type {
        case .pokemon:
            return
                account.level >= minLevel &&
                account.level <= maxLevel &&
                account.isValid(group: accountGroup)
        case .raid:
            return
                account.level >= minLevel &&
                account.level <= maxLevel &&
                account.isValid(ignoringWarning: true, group: accountGroup)
        }
    }

}
