//
//  AutoInstanceController.swift
//  RealDeviceMapLib
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

    enum QuestMode: String {
        // normal - keep ar in inventory when questing
        // alternative - remove ar quest when questing
        case normal, alternative, both
    }

    struct PokestopWithMode: Hashable {
        var pokestop: Pokestop
        var alternative: Bool
    }

    public private(set) var name: String
    public private(set) var minLevel: UInt8
    public private(set) var maxLevel: UInt8
    public private(set) var accountGroup: String?
    public private(set) var isEvent: Bool
    internal var lock = Threading.Lock() // unused, add functionality in near future
    internal var scanNextCoords: [Coord] = [] // unused, add functionality in near future
    public weak var delegate: InstanceControllerDelegate?

    private var multiPolygon: MultiPolygon
    private var type: AutoType
    private let stopsLock = Threading.Lock()
    private var doneDate: Date?
    private var lastDoneCheck = Date(timeIntervalSinceNow: -3600)
    private var allStops: [PokestopWithMode]?
    private var todayStops: [PokestopWithMode]?
    private var todayStopsTries: [PokestopWithMode: UInt8]?
    private var questClearerQueue: ThreadQueue?
    private var timezoneOffset: Int
    private var shouldExit = false
    private let bootstrappLock = Threading.Lock()
    private var bootstrappCellIDs = [S2CellId]()
    private var bootstrappTotalCount = 0
    private var spinLimit: Int
    private let accountsLock = Threading.Lock()
    private var accounts = [String: String]()
    private var lastMode = [String: Bool]()
    private let questMode: QuestMode
    public var delayLogout: Int
    public let useRwForQuest: Bool = ConfigLoader.global.getConfig(type: .accUseRwForQuest)

    init(name: String, multiPolygon: MultiPolygon, type: AutoType, timezoneOffset: Int,
         minLevel: UInt8, maxLevel: UInt8, spinLimit: Int, delayLogout: Int,
         accountGroup: String?, isEvent: Bool, questMode: QuestMode = .normal) {
        self.name = name
        self.minLevel = minLevel
        self.maxLevel = maxLevel
        self.accountGroup = accountGroup
        self.type = type
        self.multiPolygon = multiPolygon
        self.timezoneOffset = timezoneOffset
        self.spinLimit = spinLimit
        self.delayLogout = delayLogout
        self.isEvent = isEvent
        self.questMode = questMode
        update()

        try? bootstrap()
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

                        Log.debug(message: "[AutoInstanceController] [\(name)] Getting stop ids.")
                        let ids = Array(Set(self.allStops!.map({ (stop) -> String in
                            return stop.pokestop.id
                        })))
                        var done = false
                        Log.info(message: "[AutoInstanceController] [\(name)] Clearing Quests.")
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

    private func bootstrap() throws {
        Log.debug(message: "[AutoInstanceController] [\(name)] Checking Bootstrap Status...")

        let multiPolygonHash = multiPolygon.persistentHash
        let multiPolygonHashKey = "MultiPolygonS215Cells-\(multiPolygonHash ?? "")"
        var cachedCellIDs: [UInt64]?
        do {
            if multiPolygonHash != nil,
               let cachedCellsString = try DBController.global.getValueForKey(key: multiPolygonHashKey) {
                 cachedCellIDs = cachedCellsString.components(separatedBy: ",").map({ (string) -> UInt64 in
                    return string.toUInt64() ?? 0
                })
            }
        } catch {}

        let start = Date()
        var allCells = [S2CellId]()
        var allCellIDs = [UInt64]()
        if let cachedCellIDs = cachedCellIDs {
            Log.debug(message: "[AutoInstanceController] [\(name)] Using Cached Cells...")
            allCellIDs = cachedCellIDs
            allCells = allCellIDs.map({ (uid) -> S2CellId in
                return S2CellId(uid: uid)
            })
        } else {
            Log.debug(message: "[AutoInstanceController] [\(name)] Calculating Cells...")
            for polygon in multiPolygon.polygons {
                let cellIDs = polygon.getS2CellIDs(minLevel: 15, maxLevel: 15, maxCells: Int.max)
                let ids = cellIDs.map({ (id) -> UInt64 in
                    return id.uid
                })
                allCells += cellIDs
                allCellIDs += ids
            }

            if multiPolygonHash != nil {
                let allCellIDsString = allCellIDs.map { (int) -> String in
                    return int.description
                }.joined(separator: ",")
                try? DBController.global.setValueForKey(key: multiPolygonHashKey, value: allCellIDsString)
            }
        }

        var missingCellIDs = [S2CellId]()
        var done = false
        while !done {
            do {
                let cells = try Cell.getInIDs(ids: allCellIDs)
                for cellID in allCells {
                    if !cells.contains(where: { (cell) -> Bool in
                        return cell.id == cellID.uid
                    }) {
                        missingCellIDs.append(cellID)
                    }
                }
                done = true
            } catch {
                Threading.sleep(seconds: 1)
            }
        }
        Log.debug(message:
            "[AutoInstanceController] [\(name)] Bootstrap Status: \(allCells.count - missingCellIDs.count)/" +
            "\(allCells.count) after \(Date().timeIntervalSince(start).rounded(toStringWithDecimals: 2))s"
        )
        bootstrappLock.doWithLock {
            bootstrappCellIDs = missingCellIDs
            bootstrappTotalCount = allCells.count
        }

    }

    deinit {
        stop()
    }

    private func update() {
        switch type {
        case .quest:
            stopsLock.lock()
            self.allStops = []
            for polygon in multiPolygon.polygons {

                if let bounds = BoundingBox(from: polygon.outerRing.coordinates),
                    let stops = try? Pokestop.getAll(
                        minLat: bounds.southWest.latitude, maxLat: bounds.northEast.latitude,
                        minLon: bounds.southWest.longitude, maxLon: bounds.northEast.longitude,
                        updated: 0, showPokestops: true, showQuests: true, showLures: true, showInvasions: false) {

                    for stop in stops {
                        let coord = LocationCoordinate2D(latitude: stop.lat, longitude: stop.lon)
                        if polygon.contains(coord, ignoreBoundary: false) {
                            if self.questMode == .normal || self.questMode == .both {
                                self.allStops!.append(PokestopWithMode(pokestop: stop, alternative: false))
                            }
                            if self.questMode == .alternative || self.questMode == .both {
                                self.allStops!.append(PokestopWithMode(pokestop: stop, alternative: true))
                            }
                        }
                    }
                }

            }
            self.todayStops = []
            self.todayStopsTries = [:]
            self.doneDate = nil
            for stop in self.allStops! {
                if (
                    (!stop.alternative && stop.pokestop.questType == nil) ||
                    (stop.alternative && stop.pokestop.alternativeQuestType == nil)
                ) &&
                stop.pokestop.enabled == true {
                    self.todayStops!.append(stop)
                }
            }
            stopsLock.unlock()
        }
    }

    func getTask(mysql: MySQL, uuid: String, username: String?, account: Account?, timestamp: UInt64) -> [String: Any] {

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
                        if let index = bootstrappCellIDs.firstIndex(of: cellID) {
                            bootstrappCellIDs.remove(at: index)
                        }
                    }
                    if bootstrappCellIDs.isEmpty {
                        bootstrappLock.unlock()
                        try? bootstrap()
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

                guard username != nil || !InstanceController.requireAccountEnabled else {
                    Log.warning(
                        message: "[AutoInstanceController] [\(name)] [\(uuid)] No username specified. Ignoring..."
                    )
                    return [:]
                }

                guard account != nil || !InstanceController.requireAccountEnabled else {
                    Log.warning(
                        message: "[AutoInstanceController] [\(name)] [\(uuid)] No account specified. Ignoring..."
                    )
                    return [:]
                }

                stopsLock.lock()
                if todayStops == nil {
                    todayStops = []
                    todayStopsTries = [:]
                }
                if allStops == nil {
                    allStops = []
                }
                if allStops!.isEmpty {
                    stopsLock.unlock()
                    return [String: Any]()
                }
                if todayStops!.isEmpty {
                    guard Date().timeIntervalSince(lastDoneCheck) >= 600 else {
                        stopsLock.unlock()
                        if doneDate == nil {
                            doneDate = Date()
                        }
                        delegate?.instanceControllerDone(mysql: mysql, name: name)
                        return [:]
                    }
                    lastDoneCheck = Date()
                    let ids = Array(Set(self.allStops!.map({ (stop) -> String in
                        return stop.pokestop.id
                    })))
                    let newStops: [Pokestop]
                    do {
                        newStops = try Pokestop.getIn(mysql: mysql, ids: ids)
                    } catch {
                        Log.error(
                           message: "[AutoInstanceController] [\(name)] [\(uuid)] Failed to get today stops."
                        )
                        return [:]
                    }

                    for stop in newStops {
                        if questMode == .normal || questMode == .both {
                            let pokestopWithMode = PokestopWithMode(pokestop: stop, alternative: false)
                            let count = todayStopsTries![pokestopWithMode] ?? 0
                            if stop.questType == nil && stop.enabled == true && count <= 5 {
                                todayStops!.append(pokestopWithMode)
                            }
                        }
                        if questMode == .alternative || questMode == .both {
                            let pokestopWithMode = PokestopWithMode(pokestop: stop, alternative: true)
                            let count = todayStopsTries![pokestopWithMode] ?? 0
                            if stop.alternativeQuestType == nil && stop.enabled == true && count <= 5 {
                                todayStops!.append(pokestopWithMode)
                            }
                        }
                    }
                    if todayStops!.isEmpty {
                        stopsLock.unlock()
                        if doneDate == nil {
                            doneDate = Date()
                        }
                        delegate?.instanceControllerDone(mysql: mysql, name: name)
                        return [:]
                    }
                }
                stopsLock.unlock()

                let pokestop: PokestopWithMode
                let lastCoord: Coord?
                do {
                    lastCoord = try Cooldown.lastLocation(account: account, deviceUUID: uuid)
                } catch {
                    Log.error(
                        message: "[AutoInstanceController] [\(name)] [\(uuid)] Failed to get last location."
                    )
                    return [String: Any]()
                }

                if lastCoord != nil {

                    var closestOverall: PokestopWithMode?
                    var closestOverallDistance: Double = 10000000000000000

                    var closestNormal: PokestopWithMode?
                    var closestNormalDistance: Double = 10000000000000000

                    var closestAlternative: PokestopWithMode?
                    var closestAlternativeDistance: Double = 10000000000000000

                    stopsLock.lock()
                    let todayStopsC = todayStops
                    stopsLock.unlock()
                    if todayStopsC!.isEmpty {
                        return [String: Any]()
                    }

                    for stop in todayStopsC! {
                        let coord = Coord(lat: stop.pokestop.lat, lon: stop.pokestop.lon)
                        let dist = lastCoord!.distance(to: coord)
                        if dist < closestOverallDistance {
                            closestOverall = stop
                            closestOverallDistance = dist
                        }
                        if !stop.alternative && dist < closestNormalDistance {
                            closestNormal = stop
                            closestNormalDistance = dist
                        }
                        if stop.alternative && dist < closestAlternativeDistance {
                            closestAlternative = stop
                            closestAlternativeDistance = dist
                        }
                    }

                    var closest: PokestopWithMode?
                    let mode = stopsLock.doWithLock { lastMode[username ?? uuid] }
                    if mode == nil {
                        closest = closestOverall
                    } else if mode == false {
                        closest = closestNormal ?? closestOverall
                    } else {
                        closest = closestAlternative ?? closestOverall
                    }

                    if closest == nil {
                        return [:]
                    }
                    if (mode == nil || mode == true) && closest!.alternative == false {
                        Log.debug(message: "[AutoInstanceController] [\(username ?? "?")] switching quest mode from " +
                            "\(mode == true ? "alternative" : "none") to normal")
                        var closestAR: PokestopWithMode?
                        var closestARDistance: Double = 10000000000000000
                        for stop in allStops! where stop.pokestop.arScanEligible == true {
                            let coord = Coord(lat: stop.pokestop.lat, lon: stop.pokestop.lon)
                            let dist = lastCoord!.distance(to: coord)
                            if dist < closestARDistance {
                                closestAR = stop
                                closestARDistance = dist
                            }
                        }
                        if closestAR != nil {
                            closestAR!.alternative = closest!.alternative
                            closest = closestAR
                            Log.debug(message: "[AutoInstanceController] [\(username ?? "?")] scanning " +
                                "AR eligible stop \(closest!.pokestop.id)")
                        } else {
                            Log.debug(message: "[AutoInstanceController] [\(username ?? "?")] " +
                                "no AR eligible stop found to scan")
                        }
                    }

                    pokestop = closest!

                    var nearbyStops = [pokestop]
                    let pokestopCoord = Coord(lat: pokestop.pokestop.lat, lon: pokestop.pokestop.lon)
                    for stop in todayStopsC! {
                        // MARK: Revert back to 40m once reverted ingame
                        if pokestop.alternative == stop.alternative &&
                           pokestopCoord.distance(to: Coord(lat: stop.pokestop.lat, lon: stop.pokestop.lon)) <= 80 {
                            nearbyStops.append(stop)
                        }
                    }
                    stopsLock.lock()
                    for pokestop in nearbyStops {
                        if let index = todayStops!.firstIndex(of: pokestop) {
                            todayStops!.remove(at: index)
                        }
                    }
                    stopsLock.unlock()
                } else {
                    stopsLock.lock()
                    if let stop = todayStops!.first {
                        pokestop = stop
                        _ = todayStops!.removeFirst()
                    } else {
                        stopsLock.unlock()
                        return [:]
                    }
                    stopsLock.unlock()
                }

                let delay: Int
                let encounterTime: UInt32
                do {
                    let result = try Cooldown.cooldown(
                        account: account,
                        deviceUUID: uuid,
                        location: Coord(lat: pokestop.pokestop.lat, lon: pokestop.pokestop.lon)
                    )
                    delay = result.delay
                    encounterTime = result.encounterTime
                } catch {
                    Log.error(message: "[AutoInstanceController] [\(name)] [\(uuid)] Failed to calculate cooldown.")
                    stopsLock.lock()
                    todayStops?.append(pokestop)
                    stopsLock.unlock()
                    return [String: Any]()
                }

                if delay >= delayLogout && account != nil {
                    stopsLock.lock()
                    todayStops?.append(pokestop)
                    stopsLock.unlock()
                    accountsLock.lock()
                    var newUsername: String?
                    do {
                        if accounts[uuid] == nil {
                            accountsLock.unlock()
                            let account = try getAccount(
                                mysql: mysql,
                                uuid: uuid,
                                encounterTarget: Coord(lat: pokestop.pokestop.lat, lon: pokestop.pokestop.lon)
                            )
                            accountsLock.lock()
                            if accounts[uuid] == nil {
                                newUsername = account?.username
                                accounts[uuid] = account?.username
                                Log.debug(
                                    message: "[AutoInstanceController] [\(name)] [\(uuid)] Over Logout Delay. " +
                                             "Switching Account from \(username ?? "?") to \(newUsername ?? "?")"
                                )
                            }
                        } else {
                            newUsername = accounts[uuid]
                        }
                        accountsLock.unlock()
                    } catch {
                        Log.error(
                            message: "[AutoInstanceController] [\(name)] [\(uuid)] Failed to get account in advance."
                        )
                    }
                    return ["action": "switch_account", "min_level": minLevel, "max_level": maxLevel]
                } else if delay >= delayLogout {
                    Log.warning(
                        message: "[AutoInstanceController] [\(name)] [\(uuid)] Ignoring over Logout Delay, " +
                                 "because no account is specified."
                    )
                }

                do {
                    if let username = username {
                        try Account.spin(mysql: mysql, username: username)
                    }
                    try Cooldown.encounter(
                        mysql: mysql,
                        account: account,
                        deviceUUID: uuid,
                        location: Coord(lat: pokestop.pokestop.lat, lon: pokestop.pokestop.lon),
                        encounterTime: encounterTime
                  )
                } catch {
                    Log.error(message: "[AutoInstanceController] [\(name)] [\(uuid)] Failed to store cooldown.")
                    stopsLock.lock()
                    todayStops?.append(pokestop)
                    stopsLock.unlock()
                    return [String: Any]()
                }

                stopsLock.lock()
                if todayStopsTries == nil {
                    todayStopsTries = [:]
                }
                if let tries = todayStopsTries![pokestop] {
                    todayStopsTries![pokestop] = (tries == UInt8.max ? 10 : tries + 1)
                } else {
                    todayStopsTries![pokestop] = 1
                }
                if todayStops!.isEmpty {
                    lastDoneCheck = Date()
                    let ids = Array(Set(self.allStops!.map({ (stop) -> String in
                        return stop.pokestop.id
                    })))
                    stopsLock.unlock()
                    let newStops: [Pokestop]
                    do {
                        newStops = try Pokestop.getIn(mysql: mysql, ids: ids)
                    } catch {
                        Log.error(
                           message: "[AutoInstanceController] [\(name)] [\(uuid)] Failed to get today stops."
                        )
                        return [:]
                    }

                    stopsLock.lock()
                    for stop in newStops {
                        if questMode == .normal || questMode == .both {
                            let pokestopWithMode = PokestopWithMode(pokestop: stop, alternative: false)
                            let count = todayStopsTries![pokestopWithMode] ?? 0
                            if stop.questType == nil && stop.enabled == true && count <= 5 {
                                todayStops!.append(pokestopWithMode)
                            }
                        }
                        if questMode == .alternative || questMode == .both {
                            let pokestopWithMode = PokestopWithMode(pokestop: stop, alternative: true)
                            let count = todayStopsTries![pokestopWithMode] ?? 0
                            if stop.alternativeQuestType == nil && stop.enabled == true && count <= 5 {
                                todayStops!.append(pokestopWithMode)
                            }
                        }
                    }
                    if todayStops!.isEmpty {
                        stopsLock.unlock()
                        Log.info(message: "[AutoInstanceController] [\(name)] [\(uuid)] Instance done")
                        if doneDate == nil {
                            doneDate = Date()
                        }
                        delegate?.instanceControllerDone(mysql: mysql, name: name)
                    } else {
                        stopsLock.unlock()
                    }
                } else {
                    stopsLock.unlock()
                }
                stopsLock.doWithLock { lastMode[username ?? uuid] = pokestop.alternative }
                WebHookRequestHandler.setArQuestTarget(device: uuid, timestamp: timestamp, isAr: pokestop.alternative)
                return ["action": "scan_quest", "deploy_egg": false,
                        "lat": pokestop.pokestop.lat, "lon": pokestop.pokestop.lon,
                        "delay": delay, "min_level": minLevel, "max_level": maxLevel,
                        "quest_type": pokestop.alternative ? "ar" : "normal"]
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
                let ids = Array(Set(self.allStops!.map({ (stop) -> String in
                    return stop.pokestop.id
                })))
                stopsLock.unlock()
                let currentCountDb = (try? Pokestop.questCountIn(mysql: mysql, ids: ids, mode: questMode)) ?? 0
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
                    return "Status: \(currentCountDb)|\(currentCount)/\(maxCount) " +
                        "(\(percentageReal.rounded(toStringWithDecimals: 1))|" +
                        "\(percentage.rounded(toStringWithDecimals: 1))%)" +
                        "\(doneDate != nil ? ", Completed: @\(doneDate!.toString("HH:mm") ?? "")" : "")"
                } else {
                    return [
                        "quests": [
                            "done_since": doneDate?.timeIntervalSince1970 as Any,
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

    func getAccount(mysql: MySQL, uuid: String) throws -> Account? {
        return try getAccount(mysql: mysql, uuid: uuid, encounterTarget: nil)
    }

    func getAccount(mysql: MySQL, uuid: String, encounterTarget: Coord?) throws -> Account? {
        accountsLock.lock()
        if let username = accounts[uuid] {
            accounts[uuid] = nil
            accountsLock.unlock()
            return try Account.getWithUsername(username: username)
        } else {
            accountsLock.unlock()
            return try Account.getNewAccount(
                mysql: mysql,
                minLevel: minLevel,
                maxLevel: maxLevel,
                ignoringWarning: useRwForQuest,
                spins: spinLimit,
                noCooldown: true,
                encounterTarget: encounterTarget,
                device: uuid,
                group: accountGroup
            )
        }
    }

    func accountValid(account: Account) -> Bool {
        return
            account.level >= minLevel &&
            account.level <= maxLevel &&
            account.isValid(ignoringWarning: useRwForQuest, group: accountGroup) &&
            account.hasSpinsLeft(spins: spinLimit)
    }
}
