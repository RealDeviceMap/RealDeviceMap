//
//  CircleSmartRaidInstanceController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.12.18.
//

import Foundation
import PerfectThread
import PerfectLib
import PerfectMySQL
import Turf
import S2Geometry

class CircleSmartRaidInstanceController: CircleInstanceController {

    private var smartRaidLock = Threading.Lock()
    private var smartRaidGyms = [String: Gym]()
    private var smartRaidGymsInPoint = [Coord: [String]]()
    private var smartRaidPointsUpdated = [Coord: Date]()

    private var raidUpdaterQueue: ThreadQueue?

    private var statsLock = Threading.Lock()
    private var startDate: Date?
    private var count: UInt64 = 0

    private var shouldExit = false

    private static let raidInfoBeforeHatch = 120 // 2 min
    private static let ignoreTimeEgg = 150 // 2.5 min
    private static let ignoreTimeBoss = 60 // 1 min
    private static let noRaidTime = 1800 // 30 min

    init(name: String, coords: [Coord], minLevel: UInt8, maxLevel: UInt8) {
        super.init(name: name, coords: coords, type: .raid, minLevel: minLevel, maxLevel: maxLevel)

        for point in coords {

            let coord = CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon)
            let cellIDs = S2LatLng(coord: coord).getLoadedS2CellIds().map { (cell) -> UInt64 in
                return cell.uid
            }

            var loaded = false
            while !loaded {
                do {
                    let gyms = try Gym.getWithCellIDs(cellIDs: cellIDs)
                    smartRaidGymsInPoint[point] = gyms.map({ (gym) -> String in
                        return gym.id
                    })
                    smartRaidPointsUpdated[point] = Date(timeIntervalSince1970: 0)
                    for gym in gyms where smartRaidGyms[gym.id] == nil {
                        smartRaidGyms[gym.id] = gym
                    }
                    loaded = true
                } catch {
                    Threading.sleep(seconds: 5.0)
                }
            }
        }

        raidUpdaterQueue = Threading.getQueue(name: "\(name)-raid-updater", type: .serial)
        raidUpdaterQueue!.dispatch {
            self.raidUpdaterRun()
        }
    }

    deinit {
        stop()
    }

    private func raidUpdaterRun() {
        while !shouldExit {
            smartRaidLock.lock()

            let gyms = try? Gym.getWithIDs(ids: Array(smartRaidGyms.keys))
            if gyms == nil {
                smartRaidLock.unlock()
                Threading.sleep(seconds: 5.0)
                continue
            }
            for gym in gyms! {
                smartRaidGyms[gym.id] = gym
            }

            smartRaidLock.unlock()
            Threading.sleep(seconds: 30.0)
        }
    }

    override func stop() {
        shouldExit = true
        if raidUpdaterQueue != nil {
            Threading.destroyQueue(raidUpdaterQueue!)
        }
    }

    // swiftlint:disable:next function_body_length
    override func getTask(mysql: MySQL, uuid: String, username: String?, account: Account?) -> [String: Any] {

        // Get gyms without raid and gyms without boss where updated ago > ignoreTime
        var gymsNoRaid = [(Gym, Date, Coord)]()
        var gymsNoBoss = [(Gym, Date, Coord)]()
        let nowTimestamp = Int(Date().timeIntervalSince1970)
        smartRaidLock.lock()
        for gymsInPoint in smartRaidGymsInPoint {
            let updated = smartRaidPointsUpdated[gymsInPoint.key]
            let shouldUpdateEgg = (
                updated == nil ||
                nowTimestamp >= Int(updated!.timeIntervalSince1970) + CircleSmartRaidInstanceController.ignoreTimeEgg
            )
            let shouldUpdateBoss = (
                updated == nil ||
                nowTimestamp >= Int(updated!.timeIntervalSince1970) + CircleSmartRaidInstanceController.ignoreTimeBoss
            )
            for id in gymsInPoint.value {
                guard let gym = smartRaidGyms[id] else {
                    continue
                }
                if shouldUpdateEgg && (gym.raidEndTimestamp == nil ||
                   nowTimestamp >= Int(gym.raidEndTimestamp!) + CircleSmartRaidInstanceController.noRaidTime) {
                    gymsNoRaid.append((gym, updated!, gymsInPoint.key))
                } else if shouldUpdateBoss &&
                          (gym.raidPokemonId == nil || gym.raidPokemonId == 0) &&
                          gym.raidBattleTimestamp != nil &&
                          gym.raidEndTimestamp != nil &&
                          nowTimestamp >= Int(gym.raidBattleTimestamp!) -
                          CircleSmartRaidInstanceController.raidInfoBeforeHatch &&
                          nowTimestamp <= Int(gym.raidEndTimestamp!) {
                    gymsNoBoss.append((gym, updated!, gymsInPoint.key))
                }
            }
        }

        // Get coord to scan
        var coord: Coord?
        if !gymsNoBoss.isEmpty {
            gymsNoBoss.sort { (lhs, rhs) -> Bool in
                lhs.1 < rhs.1
            }
            let first = gymsNoBoss.first!
            smartRaidPointsUpdated[first.2] = Date()
            coord = first.2
        } else if !gymsNoRaid.isEmpty {
            gymsNoRaid.sort { (lhs, rhs) -> Bool in
                lhs.1 < rhs.1
            }
            let first = gymsNoRaid.first!
            smartRaidPointsUpdated[first.2] = Date()
            coord = first.2
        }

        smartRaidLock.unlock()

        if coord == nil {
            return [String: Any]()
        } else {
            self.statsLock.lock()
            if self.startDate == nil {
                self.startDate = Date()
            }
            if self.count == UInt64.max {
                self.count = 0
                self.startDate = Date()
            } else {
                self.count += 1
            }
            self.statsLock.unlock()

            return ["action": "scan_raid", "lat": coord!.lat,
                    "lon": coord!.lon, "min_level": minLevel, "max_level": maxLevel]
        }

    }

    override func getStatus(mysql: MySQL, formatted: Bool) -> JSONConvertible? {

        let scansh: Int?
        self.statsLock.lock()
        if self.startDate != nil {
            scansh = Int(Double(self.count) / Date().timeIntervalSince(self.startDate!) * 3600)
        } else {
            scansh = nil
        }
        self.statsLock.unlock()
        if formatted {
            let scanshString: String
            if scansh == nil {
                scanshString = "-"
            } else {
                scanshString = "\(scansh!)"
            }
            return "Scans/h: \(scanshString)"
        } else {
            return ["scans_per_h": scansh]
        }

    }

    override func getAccount(mysql: MySQL, uuid: String) throws -> Account? {
        return try Account.getNewAccount(
            mysql: mysql,
            minLevel: minLevel,
            maxLevel: maxLevel,
            ignoringWarning: true,
            spins: nil,
            noCooldown: false
        )
    }

    override func accountValid(account: Account) -> Bool {
        return
            account.level >= minLevel &&
            account.level <= maxLevel &&
            account.isValid(ignoringWarning: true)
    }

}
