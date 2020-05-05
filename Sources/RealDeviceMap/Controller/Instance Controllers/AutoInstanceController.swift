//
//  AutoInstanceController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 23.10.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity

import Foundation
import PerfectLib
import PerfectThread
import PerfectMySQL
import Turf
import S2Geometry

class AutoInstanceController: InstanceControllerProto {

    enum AutoType {
        case quest
    }

    public private(set) var name: String
    public private(set) var minLevel: UInt8
    public private(set) var maxLevel: UInt8
    public weak var delegate: InstanceControllerDelegate?

    private var multiPolygon: MultiPolygon
    private var type: AutoType
    private var stopsLock = Threading.Lock()
    private var allStops: [Pokestop]?
    private var todayStops: [Pokestop]?
    private var todayStopsTries: [Pokestop: UInt8]?
    private var questClearerQueue: ThreadQueue?
    private var timezoneOffset: Int
    private var shouldExit = false
    private var bootstrappLock = Threading.Lock()
    private var bootstrappCellIDs = [S2CellId]()
    private var bootstrappTotalCount = 0
    private var spinLimit: Int
    public var delayLogout: Int

    init(name: String, multiPolygon: MultiPolygon, type: AutoType, timezoneOffset: Int,
         minLevel: UInt8, maxLevel: UInt8, spinLimit: Int, delayLogout: Int) {
        self.name = name
        self.minLevel = minLevel
        self.maxLevel = maxLevel
        self.type = type
        self.multiPolygon = multiPolygon
        self.timezoneOffset = timezoneOffset
        self.spinLimit = spinLimit
        self.delayLogout = delayLogout
        update()

        bootstrap()
        if type == .quest {
            questClearerQueue = Threading.getQueue(name: "\(name)-quest-clearer", type: .serial)
            questClearerQueue!.dispatch {

                while !self.shouldExit {

                    let date = Date()
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm:ss"
                    formatter.timeZone = TimeZone(secondsFromGMT: timezoneOffset) ?? Localizer.global.timeZone
                    let formattedDate = formatter.string(from: date)

                    let split = formattedDate.components(separatedBy: ":")
                    let hour = Int(split[0])!
                    let minute = Int(split[1])!
                    let second = Int(split[2])!

                    let timeLeft = (23 - hour) * 3600 + (59 - minute) * 60 + (60 - second)
                    let atTDate = date.addingTimeInterval(TimeInterval(timeLeft))
                    Log.debug(message:
                        "[AutoInstanceController] [\(name)] Clearing Quests in \(timeLeft)s at " +
                        "\(formatter.string(from: atTDate)) (Currently: \(formatter.string(from: date)))"
                    )

                    if timeLeft > 0 {
                        Threading.sleep(seconds: Double(timeLeft))
                        if self.shouldExit {
                            return
                        }

                        self.stopsLock.lock()
                        if self.allStops == nil {
                            Log.debug(message: "[AutoInstanceController] [\(name)] Tried clearing quests but no stops.")
                            self.stopsLock.unlock()
                            continue
                        }

                        Log.debug(message: "[AutoInstanceController] [\(name)] Getting stop ids")
                        let ids = self.allStops!.map({ (stop) -> String in
                            return stop.id
                        })
                        var done = false
                        Log.debug(message: "[AutoInstanceController] [\(name)] Clearing Quests for ids: \(ids).")
                        while !done {
                            do {
                                try Pokestop.clearQuests(ids: ids)
                                done = true
                            } catch {
                                Threading.sleep(seconds: 5.0)
                                if self.shouldExit {
                                    self.stopsLock.unlock()
                                    return
                                }
                            }
                        }
                        self.stopsLock.unlock()
                        self.update()
                    }
                }

            }
        }

    }

    private func bootstrap() {
        Log.debug(message: "[AutoInstanceController] [\(name)] Checking Bootstrap Status...")
        let start = Date()
        var totalCount = 0
        var missingCellIDs = [S2CellId]()
        for polygon in multiPolygon.polygons {
            let cellIDs = polygon.getS2CellIDs(minLevel: 15, maxLevel: 15, maxCells: Int.max)
            totalCount += cellIDs.count
            let ids = cellIDs.map({ (id) -> UInt64 in
                return id.uid
            })
            var done = false
            var cells = [Cell]()
            while !done {
                do {
                    cells = try Cell.getInIDs(ids: ids)
                    done = true
                } catch {
                    Threading.sleep(seconds: 1)
                }
            }
            for cellID in cellIDs {
                if !cells.contains(where: { (cell) -> Bool in
                    return cell.id == cellID.uid
                }) {
                    missingCellIDs.append(cellID)
                }
            }
        }
        Log.debug(message:
            "[AutoInstanceController] [\(name)] Bootstrap Status: \(totalCount - missingCellIDs.count)/\(totalCount) " +
            "after \(Date().timeIntervalSince(start).rounded(toStringWithDecimals: 2))s"
        )
        bootstrappLock.lock()
        bootstrappCellIDs = missingCellIDs
        bootstrappTotalCount = totalCount
        bootstrappLock.unlock()

    }

    deinit {
        stop()
    }

    private func update() {
        switch type {
        case .quest:
            stopsLock.lock()
            self.allStops = [Pokestop]()
            for polygon in multiPolygon.polygons {

                if let bounds = BoundingBox(from: polygon.outerRing.coordinates),
                    let stops = try? Pokestop.getAll(
                        minLat: bounds.southEast.latitude, maxLat: bounds.northWest.latitude,
                        minLon: bounds.northWest.longitude, maxLon: bounds.southEast.longitude,
                        updated: 0, questsOnly: false, showQuests: true, showLures: true, showInvasions: true) {

                    for stop in stops {
                        let coord = CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon)
                        if polygon.contains(coord, ignoreBoundary: false) {
                            self.allStops!.append(stop)
                        }
                    }
                }

            }
            self.todayStops = [Pokestop]()
            self.todayStopsTries = [Pokestop: UInt8]()
            for stop in self.allStops! {
                if stop.questType == nil && stop.enabled == true {
                    self.todayStops!.append(stop)
                }
            }
            stopsLock.unlock()

        }
    }

    func getTask(mysql: MySQL, uuid: String, username: String?) -> [String: Any] {

        switch type {
        case .quest:

            bootstrappLock.lock()
            if !bootstrappCellIDs.isEmpty {

                if let target = bootstrappCellIDs.popLast() {
                    bootstrappLock.unlock()

                    let cell = S2Cell(cellId: target)
                    let center = S2LatLng(point: cell.center)
                    let coord = center.coord
                    let cellIDs = center.getLoadedS2CellIds()

                    bootstrappLock.lock()
                    for cellID in cellIDs {
                        if let index = bootstrappCellIDs.index(of: cellID) {
                            bootstrappCellIDs.remove(at: index)
                        }
                    }
                    if bootstrappCellIDs.isEmpty {
                        bootstrappLock.unlock()
                        bootstrap()
                        bootstrappLock.lock()
                        if bootstrappCellIDs.isEmpty {
                            bootstrappLock.unlock()
                            update()
                        } else {
                            bootstrappLock.unlock()
                        }
                    } else {
                        bootstrappLock.unlock()
                    }

                    return ["action": "scan_raid", "lat": coord.latitude, "lon": coord.longitude,
                            "min_level": minLevel, "max_level": maxLevel]
                } else {
                    bootstrappLock.unlock()
                    return [String: Any]()
                }

            } else {
                bootstrappLock.unlock()

                stopsLock.lock()
                if todayStops == nil {
                    todayStops = [Pokestop]()
                    todayStopsTries = [Pokestop: UInt8]()
                }
                if allStops == nil {
                    allStops = [Pokestop]()
                }
                if allStops!.isEmpty {
                    stopsLock.unlock()
                    return [String: Any]()
                }
                if todayStops!.isEmpty {
                    let ids = self.allStops!.map({ (stop) -> String in
                        return stop.id
                    })
                    var newStops: [Pokestop]!
                    var done = false
                    while !done {
                        do {
                            newStops = try Pokestop.getIn(mysql: mysql, ids: ids)
                            done = true
                        } catch {
                            Threading.sleep(seconds: 1.0)
                        }
                    }

                    for stop in newStops {
                        let count = todayStopsTries![stop] ?? 0
                        if stop.questType == nil && stop.enabled == true && count <= 5 {
                            todayStops!.append(stop)
                        }
                    }
                    if todayStops!.isEmpty {
                        stopsLock.unlock()
                        delegate?.instanceControllerDone(name: name)
                        return [String: Any]()
                    }
                }
                stopsLock.unlock()

                var account: Account?

                do {
                    if username != nil, let accountT = try Account.getWithUsername(mysql: mysql, username: username!) {
                        account = accountT
                    }
                } catch {
                    Log.error(message: "[InstanceControllerProto] Failed to connect get account.")
                    return [String: Any]()
                }

                if username != nil && account != nil {
                    if account!.spins >= spinLimit ||
                       account!.failed == "GPR_RED_WARNING" ||
                       account!.failed == "GPR_BANNED" {
                        return ["action": "switch_account", "min_level": minLevel, "max_level": maxLevel]
                    } else {
                        try? Account.spin(mysql: mysql, username: username!)
                    }
                }

                let pokestop: Pokestop

                let lastCoord: Coord?
                do {
                    lastCoord = try Cooldown.lastLocation(account: account, deviceUUID: uuid)
                } catch {
                    Log.error(message: "[InstanceControllerProto] Failed to get last location.")
                    return [String: Any]()
                }

                if lastCoord != nil {

                    var closest: Pokestop?
                    var closestDistance: Double = 10000000000000000
                    stopsLock.lock()
                    let todayStopsC = todayStops
                    stopsLock.unlock()
                    if todayStopsC!.isEmpty {
                        return [String: Any]()
                    }

                    for stop in todayStopsC! {
                        let coord = Coord(lat: stop.lat, lon: stop.lon)
                        let dist = lastCoord!.distance(to: coord)
                        if dist < closestDistance {
                            closest = stop
                            closestDistance = dist
                        }
                    }

                    if closest == nil {
                         return [String: Any]()
                    }

                    pokestop = closest!
                    stopsLock.lock()
                    if let index = todayStops!.index(of: pokestop) {
                        todayStops!.remove(at: index)
                    }
                    stopsLock.unlock()
                } else {
                    stopsLock.lock()
                    if let stop = todayStops!.first {
                        pokestop = stop
                        _ = todayStops!.removeFirst()
                    } else {
                        stopsLock.unlock()
                        return [String: Any]()
                    }
                    stopsLock.unlock()
                }

                stopsLock.lock()
                if todayStopsTries![pokestop] == nil {
                    todayStopsTries![pokestop] = 1
                } else {
                    todayStopsTries![pokestop]! += 1
                }
                stopsLock.unlock()

                let delay: Int
                let encounterTime: UInt32
                do {
                    let result = try Cooldown.cooldown(
                        account: account,
                        deviceUUID: uuid,
                        location: Coord(lat: pokestop.lat, lon: pokestop.lon)
                    )
                    delay = result.delay
                    encounterTime = result.encounterTime
                } catch {
                    Log.error(message: "[InstanceControllerProto] Failed to calculate cooldown.")
                    return [String: Any]()
                }

                if delay >= delayLogout {
                    return ["action": "switch_account", "min_level": minLevel, "max_level": maxLevel]
                }

                do {
                    try Cooldown.encounter(
                        mysql: mysql,
                        account: account,
                        deviceUUID: uuid,
                        location: Coord(lat: pokestop.lat, lon: pokestop.lon),
                        encounterTime: encounterTime
                  )
                } catch {
                    Log.error(message: "[InstanceControllerProto] Failed to store cooldown.")
                    return [String: Any]()
                }

                stopsLock.lock()
                if todayStops!.isEmpty {
                    let ids = self.allStops!.map({ (stop) -> String in
                        return stop.id
                    })
                    stopsLock.unlock()
                    var newStops: [Pokestop]!
                    var done = false
                    while !done {
                        do {
                            newStops = try Pokestop.getIn(mysql: mysql, ids: ids)
                            done = true
                        } catch {
                            Threading.sleep(seconds: 1.0)
                        }
                    }

                    stopsLock.lock()
                    for stop in newStops {
                        if stop.questType == nil && stop.enabled == true {
                            todayStops!.append(stop)
                        }
                    }
                    if todayStops!.isEmpty {
                        Log.info(message: "[AutoInstanceController] [\(name)] Instance done")
                        delegate?.instanceControllerDone(name: name)
                    }
                    stopsLock.unlock()
                } else {
                    stopsLock.unlock()
                }

                return ["action": "scan_quest", "deploy_egg": false, "lat": pokestop.lat, "lon": pokestop.lon,
                        "delay": delay, "min_level": minLevel, "max_level": maxLevel]
            }
        }

    }

    func getStatus(mysql: MySQL, formatted: Bool) -> JSONConvertible? {
        switch type {
        case .quest:
            bootstrappLock.lock()
            if !bootstrappCellIDs.isEmpty {
                let totalCount = bootstrappTotalCount
                let count = totalCount - bootstrappCellIDs.count
                bootstrappLock.unlock()

                let percentage: Double
                if totalCount > 0 {
                    percentage = Double(count) / Double(totalCount) * 100
                } else {
                    percentage = 100
                }
                if formatted {
                    return "Bootstrapping \(count)/\(totalCount) (\(percentage.rounded(toStringWithDecimals: 1))%)"
                } else {
                    return [
                        "bootstrapping": [
                            "current_count": count,
                            "total_count": totalCount
                        ]
                    ]
                }
            } else {
                bootstrappLock.unlock()
                stopsLock.lock()
                var currentCountDb = 0
                let ids = self.allStops!.map({ (stop) -> String in
                    return stop.id
                })
                stopsLock.unlock()

                if let stops = try? Pokestop.getIn(mysql: mysql, ids: ids) {
                    for stop in stops where stop.questType != nil {
                        currentCountDb += 1
                    }
                }

                stopsLock.lock()
                let maxCount = self.allStops?.count ?? 0
                let currentCount = maxCount - (self.todayStops?.count ?? 0)
                stopsLock.unlock()

                let percentage: Double
                if maxCount > 0 {
                    percentage = Double(currentCount) / Double(maxCount) * 100
                } else {
                    percentage = 100
                }
                let percentageReal: Double
                if maxCount > 0 {
                    percentageReal = Double(currentCountDb) / Double(maxCount) * 100
                } else {
                    percentageReal = 100
                }
                if formatted {
                    return "Done: \(currentCountDb)|\(currentCount)/\(maxCount) " +
                        "(\(percentageReal.rounded(toStringWithDecimals: 1))|" +
                        "\(percentage.rounded(toStringWithDecimals: 1))%)"
                } else {
                    return [
                        "quests": [
                            "current_count_db": currentCountDb,
                            "current_count_internal": currentCount,
                            "total_count": maxCount
                        ]
                    ]
                }
            }
        }
    }

    func reload() {
        update()
    }

    func stop() {
        self.shouldExit = true
        if questClearerQueue != nil {
            Threading.destroyQueue(questClearerQueue!)
        }
    }
}
