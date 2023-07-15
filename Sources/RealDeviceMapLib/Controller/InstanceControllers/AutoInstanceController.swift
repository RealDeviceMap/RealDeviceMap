//
//  AutoInstanceController.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 23.10.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast large_tuple

import Foundation
import PerfectLib
import PerfectThread
import PerfectMySQL
import Turf
import S2Geometry

class AutoInstanceController: InstanceControllerProto {

    enum AutoType {
        case quest
        case pokemon
        case tth
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
    internal var scanNextCoords: [[Coord]] = [] // unused, add functionality in near future
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
    public let skipBootstrap: Bool = ConfigLoader.global.getConfig(type: .stopAllBootstrapping)
    public let limit = UInt8(exactly: ConfigLoader.global.getConfig(type: .questRetryLimit) as Int)!
    public let spinDistance = Double(ConfigLoader.global.getConfig(type: .spinDistance) as Int)

    var tthRequeryFrequency: Int = ConfigLoader.global.getConfig(type: .tthRequeryFrequency)
    var tthClusteringUsesKoji: Bool = ConfigLoader.global.getConfig(type: .tthClusterUsingKoji)
    var tthClusteringRadius: UInt16 = UInt16(ConfigLoader.global.getConfig(type: .tthClusteringRadius) as Int)
    var tthHopTime: Double = Double(ConfigLoader.global.getConfig(type: .tthHopTime) as String)!
    var tthDeviceTimeout: UInt16 = UInt16(ConfigLoader.global.getConfig(type: .tthDeviceTimeout) as Int)

    var autoUseLastSeenTime: Int = ConfigLoader.global.getConfig(type: .autoPokemonUseLastSeenTime)
    var autoRequeryFrequency: Int = ConfigLoader.global.getConfig(type: .autoPokemonRequeryFrequency)
    var autoMinSpawnTime: UInt16 = UInt16(ConfigLoader.global.getConfig(type: .autoPokemonMinSpawnTime) as Int)
    var autoBufferTime: UInt16 = UInt16(ConfigLoader.global.getConfig(type: .autoPokemonBufferTime) as Int)
    var autoSleepInterval: UInt16 = UInt16(ConfigLoader.global.getConfig(type: .autoPokemonSleepInterval) as Int)

    var defaultLongitude: Double = Double(ConfigLoader.global.getConfig(type: .autoPokemonDefaultLongitude) as String)!
    var defaultLatitude: Double = Double(ConfigLoader.global.getConfig(type: .autoPokemonDefaultLatitude) as String)!

    struct AutoPokemonCoord {
        var id: UInt64
        var coord: Coord
        var spawnSeconds: UInt16
    }

    private var lastCompletedTime: Date?
    private var lastLastCompletedTime: Date?
    var pokemonCoords: [AutoPokemonCoord]
    var tthCoords: [Coord]
    var currentDevicesMaxLocation: Int = 0
    let deviceUuid: String
    var autoPokemonLock = Threading.Lock()
    var autoPokemonDbLock = Threading.Lock()
    var tthLock = Threading.Lock()
    var tthDbLock = Threading.Lock()
    var lastTthCountUnknown: Int = 0
    var tthCluseringTime: Double = 0.0
    var lastTthRawPointsCount: Int = 0
    var currentTthRawPointsCount: Int = 0
    var lastMaxClusterSize: Int = 0
    var firstRun: Bool = true
    var tthClusterVisits: Int = 0
    var pokemonCache: MemoryCache<Int>?
    var tthCache: MemoryCache<Int>?
    var tthDevices: MemoryCache<Int>?
    var autoCountTooFast: Int = 0
    var autoCountTooSlow: Int = 0
    var autoSkippedCount: Int = 0
    var autoFirstPass: Bool = true

    init(name: String, multiPolygon: MultiPolygon, type: AutoType, minLevel: UInt8, maxLevel: UInt8,
         spinLimit: Int = 1000, delayLogout: Int = 900, timezoneOffset: Int = 0, questMode: QuestMode = .normal,
         accountGroup: String?, isEvent: Bool) {
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

        self.pokemonCoords = [AutoPokemonCoord]()
        self.tthCoords = [Coord]()
        self.deviceUuid = UUID().uuidString

        if type == .pokemon {
            // sensibility checks for user values for mode config
            autoRequeryFrequency = clamp(autoRequeryFrequency, minValue: 600, maxValue: 86400)
            autoMinSpawnTime = clamp(autoMinSpawnTime, minValue: 600, maxValue: 1740)
            autoBufferTime = clamp(autoBufferTime, minValue: 10, maxValue: 120)
            autoSleepInterval = clamp(autoSleepInterval, minValue: 1, maxValue: 5)
            defaultLongitude = clamp(defaultLongitude, minValue: -179.99999999, maxValue: 179.99999999)
            defaultLatitude = clamp(defaultLatitude, minValue: -89.99999999, maxValue: 89.99999999)

            if autoUseLastSeenTime == 0 {
                // as set to zero, assume user meant to use all data
                autoUseLastSeenTime = -1
            } else if autoUseLastSeenTime > 0 {
                // user set positive value, no sense to refresh more than every 10min
                // max value of 1wk in seconds
                autoUseLastSeenTime = clamp(autoUseLastSeenTime, minValue: 600, maxValue: 604800)
            } else {
                // negative, so going to use all data, just clamp for future usage
                autoUseLastSeenTime = clamp(autoUseLastSeenTime, minValue: -100, maxValue: -1)
            }

            // setup cache(s) we need for this mode, leave the others as nil
            pokemonCache = MemoryCache(interval: Double(autoRequeryFrequency) / 4,
                                       keepTime: Double(autoRequeryFrequency), extendTtlOnHit: false)

            return
        }
        if type == .tth {
            // sensibility checks for user values for mode config
            tthClusteringRadius = clamp(tthClusteringRadius, minValue: 10, maxValue: 100)
            tthHopTime = clamp(tthHopTime, minValue: 0.0, maxValue: 60.0)
            tthRequeryFrequency = clamp(tthRequeryFrequency, minValue: 60, maxValue: 3600)
            tthDeviceTimeout = clamp(tthDeviceTimeout, minValue: 30, maxValue: 3600)

            // setup cache(s) we need for this mode, leave the others as nil
            tthDevices = MemoryCache(interval: Double(tthDeviceTimeout) / 4,
                                     keepTime: Double(tthDeviceTimeout), extendTtlOnHit: true)
            tthCache = MemoryCache(interval: Double(tthRequeryFrequency) / 4,
                                   keepTime: Double(tthRequeryFrequency), extendTtlOnHit: false)

            // attempt to verify koji url is actually valid
            let koji = Koji()
            if tthClusteringUsesKoji && !koji.hasValidUrl() {
                    tthClusteringUsesKoji = false
                    Log.error(message: "[AutoInstanceController] Init() - " +
                        "Unable to utilize Koji for clustering as it is not a valid URL=\(koji.getUrl())")
            }
            return
        }

        update()

        if !skipBootstrap {
            try? bootstrap()
        } else {
            Log.info(message: "[AutoInstanceController] Skipping instance bootstrapping.")
        }
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
                            Log.warning(message:
                                "[AutoInstanceController] [\(name)] Tried clearing quests but no stops.")
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
        case .pokemon:
            pokemonCache!.set(id: self.name, value: 1)
            try? initAutoPokemonCoords()
        case .tth:
            tthCache!.set(id: self.name, value: 1)
            try? initTthCoords()
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
        case .pokemon:
            let hit = pokemonCache!.get(id: self.name) ?? 0
            if hit == 0 {
                pokemonCache!.set(id: self.name, value: 1)
                try? initAutoPokemonCoords()
            }

            // wait for changes to data after requery of db, as do not want to ask it during update ops
            autoPokemonDbLock.lock()
            // wait for other devices asking for next location in array
            autoPokemonLock.lock()

            // increment location
            let locIndex: Int = currentDevicesMaxLocation

            let (newLocIndex, hasOverRan) = determineNextAutoPokemonLocation(curLocationIndex: locIndex)

            Log.debug(message: "[AutoInstanceController] getTask() - " +
                      "Instance: \(name) - oldLoc=\(locIndex) & newLoc=\(newLocIndex)/\(pokemonCoords.count / 2)")

            var currentCoord = AutoPokemonCoord(id: 1, coord: Coord(lat: defaultLatitude,
                                                                    lon: defaultLongitude), spawnSeconds: 0)

            if hasOverRan {
                // too many devices on instance, going to overrun,
                // send to a prior coord to stall for time
                var randomIdx = newLocIndex - Int.random(in: 0..<50)
                if randomIdx < 0 {
                    randomIdx += pokemonCoords.count / 2
                }

                currentCoord = pokemonCoords[randomIdx]
            } else {
                // normal operation
                if pokemonCoords.indices.contains(newLocIndex) {
                    currentDevicesMaxLocation = newLocIndex
                    currentCoord = pokemonCoords[newLocIndex]
                } else {
                    if pokemonCoords.indices.contains(0) {
                        currentDevicesMaxLocation = 0
                        currentCoord = pokemonCoords[0]
                    } else {
                        currentDevicesMaxLocation = -1
                    }
                }
            }

            // release both the locks
            autoPokemonLock.unlock()
            autoPokemonDbLock.unlock()

            var task: [String: Any] = [
                "action": "scan_pokemon", "lat": currentCoord.coord.lat, "lon": currentCoord.coord.lon,
                "min_level": minLevel, "max_level": maxLevel
            ]

            if InstanceController.sendTaskForLureEncounter { task["lure_encounter"] = true }

            return task
        case .tth:
            // get route like for tth finding, specify fence and use tth = null
            // with each gettask, just increment to next point in list
            // requery the route every ???? min, set with cache above
            // run until data length == 0, then output a message to tell user done
            // since we actually care about laptime, use that variable
            tthDbLock.lock()
            tthLock.lock()

            // update cache for active devices
            tthDevices?.set(id: uuid, value: 1)

            let hit = tthCache!.get(id: self.name) ?? 0
            if hit == 0 && firstRun {
                // not run before, so must get some coords to start
                // don't run as async as we will just grab unclustered coords on first run to get thing moving
                tthCache!.set(id: self.name, value: 1)
                try? initTthCoords()
            } else if hit == 0 {
                tthCache!.set(id: self.name, value: 1)

                // run async.  intent is to fire off the clustering,
                //  but keep running on old coords until we get data back from koji
                DispatchQueue.global(qos: .background).async {
                    try? self.initTthCoords()
                }
            }

            // test for behavior if hoptime is set
            if tthHopTime > 0.0 {
                let possibleHopsInRequeryFrequency =
                    Int( Double((tthDevices?.keyCount())!) * Double(tthRequeryFrequency) / tthHopTime )

                if currentDevicesMaxLocation > possibleHopsInRequeryFrequency {
                    currentDevicesMaxLocation = -1
                }
            }

            // increment location
            let priorLoc: Int = currentDevicesMaxLocation

            var newLoc = priorLoc + 1
            if newLoc >= tthCoords.count || newLoc < 0 {
                newLoc = 0
            }

            Log.debug(message: "[AutoInstanceController] getTask() - " +
                      "oldLoc=\(priorLoc) & newLoc=\(newLoc)/\(tthCoords.count) & " +
                      "rawCount=\(self.currentTthRawPointsCount)")

            currentDevicesMaxLocation = newLoc

            var currentCoord = Coord(lat: defaultLatitude, lon: defaultLongitude)
            if tthCoords.indices.contains(newLoc) {
                currentCoord = tthCoords[newLoc]
            } else {
                if tthCoords.indices.contains(0) {
                    currentDevicesMaxLocation = 0
                    currentCoord = tthCoords[newLoc]
                } else {
                    currentDevicesMaxLocation = -1
                }
            }

            tthLock.unlock()
            tthDbLock.unlock()

            var task: [String: Any] = [
                "action": "scan_pokemon", "lat": currentCoord.lat, "lon": currentCoord.lon,
                "min_level": minLevel, "max_level": maxLevel
            ]

            if InstanceController.sendTaskForLureEncounter { task["lure_encounter"] = true }

            return task
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
                    return [:]
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
                            if stop.questType == nil && stop.enabled == true && count <= limit {
                                todayStops!.append(pokestopWithMode)
                            }
                        }
                        if questMode == .alternative || questMode == .both {
                            let pokestopWithMode = PokestopWithMode(pokestop: stop, alternative: true)
                            let count = todayStopsTries![pokestopWithMode] ?? 0
                            if stop.alternativeQuestType == nil && stop.enabled == true && count <= limit {
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
                    return [:]
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
                        return [:]
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
                        Log.debug(message:
                            "[AutoInstanceController] [\(username ?? "?")] switching quest mode from " +
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
                        if pokestop.alternative == stop.alternative && pokestopCoord.distance(
                                to: Coord(lat: stop.pokestop.lat, lon: stop.pokestop.lon)) <= spinDistance {
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
                    return [:]
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
                                accounts[uuid] = newUsername
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
                        Log.error(message:
                            "[AutoInstanceController] [\(name)] [\(uuid)] Failed to get account in advance.")
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
                    return [:]
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
                WebHookRequestHandler.setArQuestTarget(device: uuid, timestamp: timestamp,
                    isAr: pokestop.alternative)
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
        case .pokemon:
            let cnt = self.pokemonCoords.count/2

            if formatted {
                return """
                    Coord Count: \(cnt)</br>
                    Coord Resets (fast/slow): \(autoCountTooFast)x / \(autoCountTooSlow)x (\(autoSkippedCount)skipped)
                """
            } else {
                return ["coord_count": cnt, "reset_too_fast": autoCountTooFast,
                    "reset_too_slow": autoCountTooSlow, "skipped_count": autoSkippedCount]
            }
        case .tth:
            var changeCluster = tthCoords.count - lastTthCountUnknown
            if changeCluster == tthCoords.count {
                changeCluster = 0
            }

            var changeRaw = currentTthRawPointsCount - lastTthRawPointsCount
            if changeRaw == currentTthRawPointsCount {
                changeRaw = 0
            }

            var avgVisitTime: Double = 0.0
            if tthClusterVisits != 0 {
                avgVisitTime = Double(self.tthRequeryFrequency) / Double(tthClusterVisits)
            }

            let deviceCount = devicesOnInstance()

            if formatted {
                if changeCluster > 0 {
                    if changeRaw > 0 {
                        return """
                            <span title=\"Current count and change in count from last query\">
                            Using Koji: \(tthClusteringUsesKoji)</br>
                            Count (clusters/raw): \(self.tthCoords.count) / \(self.currentTthRawPointsCount)</br>
                            Delta: \(changeCluster) / \(changeRaw)</br>
                            Clustering Date (max cluster size / time): \(self.lastMaxClusterSize) /
                            \(self.tthCluseringTime.rounded(decimals: 2))sec</br>
                            Performance (clusters visited / devices / avg time): \(tthClusterVisits) /
                            \(deviceCount) / \(avgVisitTime.rounded(decimals: 2))sec
                            </span>
                        """
                    } else {
                        return """
                            <span title=\"Current count and change in count from last query\">
                            Using Koji: \(tthClusteringUsesKoji)</br>
                            Count (clusters/raw): \(self.tthCoords.count) / \(self.currentTthRawPointsCount)</br>
                            Delta: \(changeCluster) / \(changeRaw)</br>
                            Clustering Date (max cluster size / time): \(self.lastMaxClusterSize) /
                            \(self.tthCluseringTime.rounded(decimals: 2))sec</br>
                            Performance (clusters visited / devices / avg time): \(tthClusterVisits) /
                            \(deviceCount) / \(avgVisitTime.rounded(decimals: 2))sec
                            </span>
                        """
                    }
                } else {
                    if changeRaw > 0 {
                        return """
                            <span title=\"Current count and change in count from last query\">
                            Using Koji: \(tthClusteringUsesKoji)</br>
                            Count (clusters/raw): \(self.tthCoords.count) / \(self.currentTthRawPointsCount)</br>
                            Delta: \(changeCluster) / \(changeRaw)</br>
                            Clustering Date (max cluster size / time): \(self.lastMaxClusterSize) /
                            \(self.tthCluseringTime.rounded(decimals: 2))sec</br>
                            Performance (clusters visited / devices / avg time): \(tthClusterVisits) /
                            \(deviceCount) / \(avgVisitTime.rounded(decimals: 2))sec
                            </span>
                        """
                    } else {
                        return """
                            <span title=\"Current count and change in count from last query\">
                            Using Koji: \(tthClusteringUsesKoji)</br>
                            Count (clusters/raw): \(self.tthCoords.count) / \(self.currentTthRawPointsCount)</br>
                            Delta: \(changeCluster) / \(changeRaw)</br>
                            Clustering Date (max cluster size / time): \(self.lastMaxClusterSize) /
                            \(self.tthCluseringTime.rounded(decimals: 2))sec</br>
                            Performance (clusters visited / devices / avg time): \(tthClusterVisits) /
                            \(deviceCount) / \(avgVisitTime.rounded(decimals: 2))sec
                            </span>
                        """
                    }
                }
            } else {
                return ["coord_count": self.tthCoords.count, "Delta": changeCluster]
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

    func initAutoPokemonCoords() throws {
        Log.debug(message: "[AutoInstanceController] initAutoPokemonCoords() - Starting")
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[AutoInstanceController] initAutoPokemonCoords() - Failed to connect to database.")
            return
        }

        // reset status variables
        autoCountTooFast = 0
        autoCountTooSlow = 0
        autoSkippedCount = 0
        autoFirstPass = true

        var tmpCoords: [AutoPokemonCoord] = [AutoPokemonCoord]()

        if pokemonCoords.count > 1 {
            tmpCoords.reserveCapacity(pokemonCoords.count)
        }

        // get min and max coords from polygon(s)
        var minLat: Double = 90
        var maxLat: Double = -90
        var minLon: Double = 180
        var maxLon: Double = -180
        for polygon in multiPolygon.polygons {
            let bounds = BoundingBox(from: polygon.outerRing.coordinates)
            minLat = min(minLat, bounds!.southWest.latitude)
            maxLat = max(maxLat, bounds!.northEast.latitude)
            minLon = min(minLon, bounds!.southWest.longitude)
            maxLon = max(maxLon, bounds!.northEast.longitude)
        }

        // assemble the sql
        var sql = "select id, despawn_sec, lat, lon, spawn_info from spawnpoint where "
        sql.append(" (lat>" + String(minLat) + " AND lon >" + String(minLon) + ") ")
        sql.append(" AND ")
        sql.append(" (lat<" + String(maxLat) + " AND lon <" + String(maxLon) + ") ")
        sql.append(" AND despawn_sec is not null")

        if autoUseLastSeenTime > 0 {
            let time = UInt64(Date().timeIntervalSince1970) - UInt64(autoUseLastSeenTime)

            sql.append(" AND last_seen > \(time) ")
        }

        sql.append(" order by despawn_sec")

        Log.debug(message: "\(sql)")

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        guard mysqlStmt.execute() else {
            Log.error(message: "[AutoInstanceController] initAutoPokemonCoords() - Failed to execute query. " +
                "(\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        var count: Int = 0
        let results = mysqlStmt.results()
        while let result = results.next() {
            let id = result[0] as! UInt64
            let despawnSeconds = result[1] as! UInt16
            let lat = result[2] as! Double
            let lon = result[3] as! Double
            let spawnInfo = result[4] as! UInt32

            var spawnSeconds: Int = Int(despawnSeconds)

            // determine if 60 or 30min spawns, will default to 30min spawns
            // first 4 bits of spawnInfo are quarter hours of if mon seen there,
            //   all 4, it is 60.  less than 4, it is 30.
            let testValue: UInt32 = 15
            if spawnInfo & testValue == testValue {
                spawnSeconds -= 3600
            } else {
                spawnSeconds -= 1800
            }

            if spawnSeconds < 0 {
                spawnSeconds += 3600
            }

            if inPolygon(lat: lat, lon: lon, multiPolygon: multiPolygon) {
                tmpCoords.append(
                    AutoPokemonCoord( id: id, coord: Coord(lat: lat, lon: lon),
                        spawnSeconds: UInt16(spawnSeconds))
                )
            }

            count += 1
        }

        Log.debug(message: "[AutoInstanceController] initAutoPokemonCoords() - " +
            "got \(count) spawnpoints in min/max rectangle")
        Log.debug(message: "[AutoInstanceController] initAutoPokemonCoords() - " +
            "got \(tmpCoords.count) spawnpoints in geofence")

        autoPokemonDbLock.lock()

        pokemonCoords.removeAll()
        pokemonCoords.reserveCapacity(2 * tmpCoords.count)

        pokemonCoords = tmpCoords

        // take lazy man's approach, probably not ideal
        // add elements to end, so 3600-7199 sec
        for coord in tmpCoords {
            pokemonCoords.append(
                AutoPokemonCoord(id: coord.id, coord: coord.coord, spawnSeconds: coord.spawnSeconds + 3600 ))
        }

        // set to start, algorithm will iterate to find right spot to start work
        currentDevicesMaxLocation = -1

        // sort the times in array, necessary as added in 60min spawns to v2
        pokemonCoords.sort {
            $0.spawnSeconds < $1.spawnSeconds
        }

        firstRun = false

        if pokemonCoords.count > 0 {
            if defaultLatitude == 0.0 && defaultLongitude == 0.0 {
                defaultLatitude = pokemonCoords[0].coord.lat
                defaultLongitude = pokemonCoords[0].coord.lon
            }
        }

        autoPokemonDbLock.unlock()

        Log.debug(message: "[AutoInstanceController] initAutoPokemonCoords() - Ended")
    }

    func initTthCoords() throws {
        Log.debug(message: "[AutoInstanceController] initTthCoords() - Starting")
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[AutoInstanceController] initTthCoords() - Failed to connect to database.")
            return
        }

        lastTthCountUnknown = tthCoords.count
        lastTthRawPointsCount = currentTthRawPointsCount

        var tmpCoords = [Coord]()

        if tthCoords.count > 1 {
            tmpCoords.reserveCapacity(tthCoords.count)
        }

        // get min and max coords from polygon(s)
        var minLat: Double = 90
        var maxLat: Double = -90
        var minLon: Double = 180
        var maxLon: Double = -180
        for polygon in multiPolygon.polygons {
            let bounds = BoundingBox(from: polygon.outerRing.coordinates)
            minLat = min(minLat, bounds!.southWest.latitude)
            maxLat = max(maxLat, bounds!.northEast.latitude)
            minLon = min(minLon, bounds!.southWest.longitude)
            maxLon = max(maxLon, bounds!.northEast.longitude)
        }

        // assemble the sql
        var sql = "SELECT lat, lon FROM spawnpoint WHERE "
        sql.append("(lat>" + String(minLat) + " AND lon >" + String(minLon) + ")")
        sql.append(" AND ")
        sql.append("(lat<" + String(maxLat) + " AND lon <" + String(maxLon) + ")")
        sql.append(" AND despawn_sec is null")

        // if koji not available, order the data by last seen adding a random amount to make devices bounce around a bit
        // we will keep working over set of found points.  if find one, setup will just expand
        if firstRun && !tthClusteringUsesKoji {
            sql.append(" ORDER BY RAND() ")
        } else if !tthClusteringUsesKoji {
            sql.append(" ORDER BY (last_seen + RAND() * 1000) DESC ")
        }

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        guard mysqlStmt.execute() else {
            Log.error(message:
                "[AutoInstanceController] initTthCoords() - Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        var count: Int = 0
        let results = mysqlStmt.results()
        while let result = results.next() {
            let lat = result[0] as! Double
            let lon = result[1] as! Double

            if inPolygon(lat: lat, lon: lon, multiPolygon: multiPolygon) {
                tmpCoords.append( Coord(lat: lat, lon: lon) )
            }

            count += 1
        }
        currentTthRawPointsCount = tmpCoords.count

        Log.debug(message:
            "[AutoInstanceController] initTthCoords() - got \(count) points in min/max rectangle with null tth")
        Log.debug(message:
            "[AutoInstanceController] initTthCoords() - got \(tmpCoords.count) points in geofence with null tth")

        if tmpCoords.count == 0 {
            Log.debug(message: "[AutoInstanceController] initTthCoords - " +
                      "got ZERO points in min/max rectangle with null tth, you should switch to another mode")
        }

        Log.debug(message: "[AutoInstanceController] initTthCoords() - " +
                  "UsingKoji = \(tthClusteringUsesKoji) &  firstRun=\(firstRun)")

        // lock the data for location array so that we can write to it
        tthDbLock.lock()

        tthCoords.removeAll(keepingCapacity: true)

        // determine if end user is utilizing koji, if so cluster some shit
        // for the first run, we will just do all data without any clusters to get things moving
        if tthClusteringUsesKoji {
            Log.debug(message: "[AutoInstanceController] initTthCoords() - Using Koji for clustering")
            tthCoords = getClusteredCoords(dataPoints: tmpCoords)
        } else {
            Log.debug(message: "[AutoInstanceController] initTthCoords() - not using Koji for clustering")

            // setup and do some poor boy clustering
            var precision: UInt16 = 7

            if tmpCoords.count < 1000 {
                // drop down in precision, likely to be on nearly all clusters being singular points anyways
                precision = 8
            }

            lastMaxClusterSize = Int(precision)

            tthCoords = poorBoyClusteringUsingGeohash(dataPoints: tmpCoords, geohashPrecision: precision)
        }

        tthClusterVisits = currentDevicesMaxLocation
        currentDevicesMaxLocation = -1

        firstRun = false

        tthCache!.set(id: self.name, value: 1)

        if tthCoords.count > 0 {
            if defaultLatitude == 0.0 && defaultLongitude == 0.0 {
                defaultLatitude = tthCoords[0].lat
                defaultLongitude = tthCoords[0].lon
            }
        }

        // done messing with location array, so unlock it
        tthDbLock.unlock()

        Log.debug(message: "[AutoInstanceController] initTthCoords() - Ended")
    }

    func devicesOnInstance() -> UInt16 {
        var cnt = tthDevices?.keyCount() ?? 1
        cnt  = min(1, cnt)  // really shouldn't be capable of happening

        return UInt16(cnt)
    }

    func getClusteredCoords(dataPoints: [Coord]) -> [Coord] {
        Log.debug(message: "[AutoInstanceController] getClusteredCoords() - starting function")

        // get the clusters from koji
        // 1. run with fast=true for first run, so that we can get moving, which causes clusters to be random order
        // 2. on subsequent runs, we will use fast=false, so we get clusters back sorted by largest.
        //      this will cause the workers to start with high spawnpoint count clusters and work
        //      towards smaller ones.
        if let kojiData = getClusteredCoordsFromKoji(dataPoints: dataPoints, radius: tthClusteringRadius,
                                             minPoints: UInt16(1), benchmarkMode: false, fast: firstRun) {
            lastMaxClusterSize = kojiData.stats.bestClusterPointCount
            tthCluseringTime = kojiData.stats.clusterTime

            return kojiData.data!
        } else {
            // something went wrong with koji, fallback to normal
            Log.error(message: "[AutoInstanceController] getClusteredCoords() - " +
                      "Unable to get data from Koji, falling back to geohash clustering")
            tthClusteringUsesKoji = false
            firstRun = true  // reset flag so we know to do a rand() on data to get a shotgun pattern

            lastMaxClusterSize = 0
            tthCluseringTime = 0

            return poorBoyClusteringUsingGeohash(dataPoints: dataPoints, geohashPrecision: 8)
        }
    }

    func getClusteredCoordsFromKoji(dataPoints: [Coord], radius: UInt16, minPoints: UInt16,
                                    benchmarkMode: Bool, fast: Bool) -> Koji.ReturnedDataOfSingleArray? {
        // function to get the data from koji
        // may get nil back from Koji function, don't handle here but pass on to calling funciton
        Log.debug(message: "[AutoInstanceController] clusteredCoords() - " +
                  "started function with radius=\(radius) & minPoints=\(minPoints) " +
                  "& benchmarkMode=\(benchmarkMode) & [Coord].count=\(dataPoints.count)")

        let koji = Koji()
        let returnedData = koji.getClusterTthFromKoji(dataPoints: dataPoints,
                                                radius: Int(tthClusteringRadius), minPoints: Int(minPoints),
                                                benchmarkMode: benchmarkMode, fast: fast,
                                                sortBy: Koji.Sorting.clusterCount.asText(),
                                                returnType: Koji.ReturnType.singleArray.asText(),
                                                onlyUnique: true)!

        return returnedData
    }

    func poorBoyClusteringUsingGeohash(dataPoints: [Coord], geohashPrecision: UInt16 = 8) -> [Coord] {
        let start = Date()

        var geohashSet = Set<String>()

        // loop through points and convert to geohash
        // insert into a swift set, so that there are no duplicates
        for point in dataPoints {
            let hashedCoord = Geohash.encode(latitude: point.lat, longitude: point.lon, length: Int(geohashPrecision))

            geohashSet.insert(hashedCoord)
        }

        // convert back to lat/lon for our use
        var returnPoints = [Coord]()
        for hashedPoint in geohashSet {
            if let (lat, lon) = Geohash.decode(hash: hashedPoint) {
                let latitudeMidpoint = (lat.min + lat.max) / 2
                let longitudeMidpoint = (lon.min + lon.max) / 2
                returnPoints.append( Coord(lat: latitudeMidpoint, lon: longitudeMidpoint) )
            }
        }

        let diff = -1 * start.timeIntervalSinceNow
        tthCluseringTime = diff
        Log.debug(message: "[AutoInstanceController] PoorBoyClustering() - process time = \(diff)")

        return returnPoints
    }

    func secondsFromTopOfHour(seconds: UInt64 ) -> UInt64 {
        var ret: UInt64 = (seconds % 3600)
        ret += (seconds % 3600) % 60

        return ret
    }

    func secondsToHoursMinutesSeconds() -> (hours: UInt64, minutes: UInt64, seconds: UInt64) {
        let now = UInt64(Date().timeIntervalSince1970)
        return (UInt64(now / 3600), UInt64((now % 3600) / 60), UInt64((now % 3600) % 60))
    }

    func offsetsForSpawnTimer(time: UInt16) -> (UInt16, UInt16) {
        let maxTime: UInt16 = time + 1800 - UInt16(autoMinSpawnTime)
        let minTime: UInt16 = time + UInt16(autoBufferTime)

        return (minTime, maxTime)
    }

    func determineNextAutoPokemonLocation(curLocationIndex: Int) -> (Int, Bool) {
        let cntArray = pokemonCoords.count
        let cntCoords = pokemonCoords.count / 2

        var hasOverRan = false

        if cntArray <= 0 {
            pokemonCache!.set(id: self.name, value: 1)
            try? initAutoPokemonCoords()
            return (0, false)
        }

        let (_, min, sec) = secondsToHoursMinutesSeconds()
        var curTime: UInt64 = min*60 + sec
        var originalTime = curTime

        // increment position
        var locIndex = curLocationIndex + 1
        if locIndex > cntCoords {
            Log.debug(message: "[AutoInstanceController] determineNextLocation() - " +
                      "reached end of data, going back to zero")

            lastLastCompletedTime = lastCompletedTime
            lastCompletedTime = Date()

            return (0, hasOverRan)
        } else if locIndex < 0 {
            locIndex = 0
        }

        if !pokemonCoords.indices.contains(locIndex) {
            if pokemonCoords.indices.contains(0) {
                locIndex = 0
            } else {
                // wtf
                Log.debug(message: "[AutoInstanceController] " +
                          "determineNextPokemonLocation - no zero location, wtf...")
            }
        }
        var nextCoord = pokemonCoords[locIndex]

        var spawnSeconds: UInt16 = nextCoord.spawnSeconds

        var (minTime, maxTime) = offsetsForSpawnTimer(time: spawnSeconds)
        if maxTime > 3599 && curTime < minTime {
            curTime += 3600

            if (curTime >= minTime) && (curTime <= maxTime) {
                Log.debug(message: "[AutoInstanceController] determineNextPokemonLocation() z1")
            }
        }

        Log.debug(message:
            "[AutoInstanceController] determineNextPokemonLocation - minTime=\(minTime) & " +
                "curTime=\(curTime) & maxTime=\(maxTime)")

        // are we around the top of the hosue
        if maxTime > 3599 && curTime < minTime {
            curTime += 3600

            if (curTime >= minTime) && (curTime <= maxTime) {
                Log.debug(message: "[AutoInstanceController] determineNextPokemonLocation() z1")
            }
        }

        // do the shit
        if (curTime >= minTime) && (curTime <= maxTime) {
            if Double(curTime) < Double(minTime) + Double(autoSleepInterval) {
                // test if we are getting too close to the mintime
                Log.debug(message:
                    "[AutoInstanceController] determineNextPokemonLocation() a2 - " +
                    "sending worker to random coords as too many devices on instance")

                if !autoFirstPass {
                    autoCountTooFast += 1
                }

                hasOverRan = true
                locIndex -= 1
            } else {
                // normal entry if things are going as designed,
                // good to jump as to next spot
                Log.debug(message: "[AutoInstanceController] determineNextPokemonLocation a1 - " +
                        "curtime between min and max, moving standard 1 forward")
            }
        } else if curTime < minTime && !firstRun {
            // spawn is before legit time to visit, need to find a good one to jump to
            Log.debug(message: "[AutoInstanceController] determineNextPokemonLocation() b1 - " +
                "curTime \(curTime) < minTime \(minTime), iterate")

            if !autoFirstPass {
                autoCountTooFast += 1
            }

            for idx in 0..<cntArray {
                nextCoord = pokemonCoords[idx]
                spawnSeconds = nextCoord.spawnSeconds

                var (mnTime, mxTime) = offsetsForSpawnTimer(time: spawnSeconds)

                if  (originalTime >= mnTime + 10) && (originalTime <= mxTime - 30) {
                    Log.debug(message: "[AutoInstanceController] determineNextPokemonLocation() b2 - " +
                        "mnTime=\(mnTime) & originalTime=\(originalTime) & mxTime=\(mxTime)")

                    locIndex = idx
                    break
                }
                /*
                if  (workingTime >= mnTime + 10) && (workingTime <= mxTime - 30) {
                    Log.debug(message: "[AutoInstanceController] determineNextPokemonLocation() b3 - " +
                        "mnTime=\(mnTime) & workingTime=\(workingTime) & mxTime=\(mxTime)")

                    locIndex = idx
                    break
                }
                */
            }
        } else if curTime < minTime && firstRun {
            Log.debug(message: "[AutoInstanceController] determineNextPokemonLocation() c1 - sleeping 10sec")
            Threading.sleep(seconds: 5)

            locIndex -= 1
        } else if curTime > maxTime {
            // spawn is past time to visit, need to find a good one to jump to
            Log.debug(message: "[AutoInstanceController] determineNextPokemonLocation() d1 - " +
                "curTime=\(curTime) > maxTime=\(maxTime), iterate.  Devices falling behind, consider more devices!")

            let originalIdx = curLocationIndex

            for idx in (0..<cntArray).reversed() {
                nextCoord = pokemonCoords[idx]
                spawnSeconds = nextCoord.spawnSeconds

                var (mnTime, mxTime) = offsetsForSpawnTimer(time: spawnSeconds)

                if (originalTime >= mnTime + 10) && (originalTime <= mxTime - 30) {
                    Log.debug(message: "[AutoInstanceController] determineNextPokemonLocation() d2 -  " +
                        "mnTime=\(mnTime) & originalTime=\(originalTime) & mxTime=\(mxTime). " +
                        "resetting to new working time window")
                    locIndex = idx
                    break
                }
            }

            if !autoFirstPass {
                autoCountTooSlow += 1
                autoSkippedCount += abs(locIndex-originalIdx)
            }
        } else {
            Log.debug(message: "[AutoInstanceController] determineNextPokemonLocation() e1 - " +
                "criteria fail with curTime=\(curTime) & curLocation=\(curLocationIndex)" +
                      "& despawn=\(spawnSeconds)")
            // go back to zero and iterate somewhere useful
            locIndex=0
        }

        if locIndex >= cntCoords-1 {
            lastLastCompletedTime = lastCompletedTime
            lastCompletedTime = Date()
        }

        // sanity checks
        if locIndex > cntCoords { // check if we went past half
            locIndex -= cntCoords
        } else if locIndex < 0 { // we before first point
            locIndex = 0
        }

        autoFirstPass = false

        return (locIndex, hasOverRan)
    }

    private func inPolygon(lat: Double, lon: Double, multiPolygon: MultiPolygon) -> Bool {
        for polygon in multiPolygon.polygons {
            let coord = LocationCoordinate2D(latitude: lat, longitude: lon)

            if polygon.contains(coord, ignoreBoundary: false) {
                return true
            }
        }

        return false
    }
}
