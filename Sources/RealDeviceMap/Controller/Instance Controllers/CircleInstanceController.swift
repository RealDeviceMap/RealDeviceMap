//
//  CircleInstanceController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 30.09.18.
//

import Foundation
import PerfectLib
import PerfectThread

class CircleInstanceController: InstanceControllerProto {

    enum CircleType {
        case pokemon
        case raid
    }

    public private(set) var name: String
    public private(set) var minLevel: UInt8
    public private(set) var maxLevel: UInt8
    public weak var delegate: InstanceControllerDelegate?

    private let type: CircleType
    private let coords: [Coord]
    private var lastIndex: Int = 0
    private var lock = Threading.Lock()
    private var lastLastCompletedTime: Date?
    private var lastCompletedTime: Date?

    init(name: String, coords: [Coord], type: CircleType, minLevel: UInt8, maxLevel: UInt8) {
        self.name = name
        self.minLevel = minLevel
        self.maxLevel = maxLevel
        self.coords = coords
        self.type = type
        self.lastCompletedTime = Date()
    }

    func getTask(uuid: String, username: String?) -> [String: Any] {

		guard let mysql = DBController.global.mysql else {
			Log.error(message: "[InstanceControllerProto] Failed to connect to database.")
			return [String: Any]()
		}

		do {
			if username != nil {
				let account = try Account.getWithUsername(mysql: mysql, username: username!)
				if account != nil {
					if account!.failed == "GPR_RED_WARNING" || account!.failed == "GPR_BANNED" {
						return ["action": "switch_account", "min_level": minLevel, "max_level": maxLevel]
					}
				}
			}
		} catch { }

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

    func getStatus(formatted: Bool) -> JSONConvertible? {

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

}
