//
//  ApiRequestHandler.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 18.09.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity

import Foundation
import PerfectLib
import PerfectHTTP
import PerfectMustache
import PerfectSession
import PerfectThread
import SwiftProtobuf
import POGOProtos
import Turf
import S2Geometry

public class WebHookRequestHandler {

    public static var enableClearing = false
    public static var hostWhitelist: [String]?
    public static var hostWhitelistUsesProxy: Bool = false
    public static var loginSecret: String?
    public static var dittoDisguises: [UInt16]?

    private static var limiter = LoginLimiter()

    private static let levelCacheLock = Threading.Lock()
    private static var levelCache = [String: Int]()

    private static let emptyCellsLock = Threading.Lock()
    private static var emptyCells = [UInt64: Int]()

    static let threadLimitMax = UInt32(exactly: ConfigLoader.global.getConfig(type: .rawThreadLimit) as Int)!
    private static let threadLimitLock = Threading.Lock()
    private static var threadLimitCount: UInt32 = 0
    private static var threadLimitTotalCount: UInt64 = 0
    private static var threadLimitIgnoredCount: UInt64 = 0

    private static let loginLimitEnabled: Bool = ConfigLoader.global.getConfig(type: .loginLimit)
    private static let loginLimit = UInt32(exactly: ConfigLoader.global.getConfig(type: .loginLimitCount) as Int)!
    private static let loginLimitIntervall = UInt32(exactly:
        ConfigLoader.global.getConfig(type: .loginLimitInterval) as Int)!
    private static let loginLimitLock = Threading.Lock()
    private static var loginLimitTime = [String: UInt32]()
    private static var loginLimitCount = [String: UInt32]()

    private static let rawDebugEnabled: Bool = ConfigLoader.global.getConfig(type: .rawDebugEnabled)
    private static let rawDebugTypes: [String] = ConfigLoader.global.getConfig(type: .rawDebugTypes)

    private static let encounterLock = Threading.Lock()
    private static var encounterCount = [String: Int]()
    private static let maxEncounter: Int = ConfigLoader.global.getConfig(type: .accMaxEncounters)

    private static let questArTargetMap = TimedMap<String, Bool>(length: 100)
    private static let questArActualMap = TimedMap<String, Bool>(length: 100)
    private static let allowARQuests: Bool = ConfigLoader.global.getConfig(type: .allowARQuests)

    // swiftlint:disable:next large_tuple
    internal static func getThreadLimits() -> (current: UInt32, total: UInt64, ignored: UInt64) {
        threadLimitLock.lock()
        let current = threadLimitCount
        let total = threadLimitTotalCount
        let ignored = threadLimitIgnoredCount
        threadLimitLock.unlock()
        return (current: current, total: total, ignored: ignored)
    }

    static func handle(request: HTTPRequest, response: HTTPResponse, type: WebHookServer.Action) {

        let host = request.host

        let isMadData = request.header(.origin) != nil

        if let hostWhitelist = hostWhitelist {
            guard hostWhitelist.contains(host) else {
                return response.respondWithError(status: .unauthorized)
            }
        }

        if let loginSecret = loginSecret {
            guard WebHookRequestHandler.limiter.allowed(host: host) else {
                return response.respondWithError(status: .unauthorized)
            }

            var loginSecretHeader = request.header(.authorization)

            if isMadData {
                if let madAuth = Data(base64Encoded: loginSecretHeader?.components(separatedBy: " ").last ?? ""),
                    let madString = String(data: madAuth, encoding: .utf8),
                    let madSecret = madString.components(separatedBy: ":").last {
                        loginSecretHeader = "Bearer \(madSecret)"
                } else {
                    return response.respondWithError(status: .badRequest)
                }
            }
            guard loginSecretHeader == "Bearer \(loginSecret)" else {
                WebHookRequestHandler.limiter.failed(host: host)
                return response.respondWithError(status: .unauthorized)
            }
        }
        response.addHeader(.custom(name: "X-Server"), value: "RealDeviceMap/\(VersionManager.global.version)")
        switch type {
        case .controler:
            controlerHandler(request: request, response: response, host: host)
        case .raw:
            rawHandler(request: request, response: response, host: host)
        }

    }

    static func rawHandler(request: HTTPRequest, response: HTTPResponse, host: String) {

        let json: [String: Any]
        let isMadData = request.header(.origin) != nil
        if isMadData, let madRaw = request.postBodyString?.jsonDecodeForceTry() as? [[String: Any]] {
            json = ["contents": madRaw,
                    "uuid": request.header(.origin)!,
                    "username": "PogoDroid"]
        } else if let rdmRaw = request.postBodyString?.jsonDecodeForceTry() as? [String: Any] {
            json = rdmRaw
        } else {
            response.respondWithError(status: .badRequest)
            return
        }

        let uuid = json["uuid"] as? String
        let timestamp = json["timestamp"] as? UInt64 ?? Date().timestampMs

        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Failed to connect to database.")
            response.respondWithError(status: .internalServerError)
            return
        }

        let trainerLevel = json["trainerlvl"] as? Int ?? (json["trainerLevel"] as? String)?.toInt() ?? 0
        var trainerXP = json["trainerexp"] as? Int ?? 0
        let username = json["username"] as? String
        let hasArQuestReqGlobal = json["have_ar"] as? Bool

        let controller = uuid != nil ? InstanceController.global.getInstanceController(deviceUUID: uuid!) : nil
        let isEvent = controller?.isEvent ?? false
        if username != nil && trainerLevel > 0 {
            levelCacheLock.lock()
            let oldLevel = levelCache[username!]
            levelCacheLock.unlock()
            if oldLevel != trainerLevel {
                do {
                    try Account.setLevel(mysql: mysql, username: username!, level: trainerLevel)
                    Log.debug(message: "[WebHookRequestHandler] Account \(username!) on \(uuid ?? "") " +
                        "from \(String(describing: oldLevel)) to \(trainerLevel) with \(trainerXP) XP")
                    levelCacheLock.lock()
                    levelCache[username!] = trainerLevel
                    levelCacheLock.unlock()
                } catch {}
            }
        }

        // only process MapPokemon when LureEncounter are enabled
        let processMapPokemon = InstanceController.sendTaskForLureEncounter

        guard let contents = json["contents"] as? [[String: Any]] ??
                             json["protos"] as? [[String: Any]] ??
                             json["gmo"] as? [[String: Any]] else {
            response.respondWithError(status: .badRequest)
            return
        }

        let latTarget = json["lat_target"] as? Double
        let lonTarget = json["lon_target"] as? Double
        if uuid != nil && latTarget != nil && lonTarget != nil {
            try? Device.setLastLocation(mysql: mysql, uuid: uuid!, lat: latTarget!, lon: lonTarget!, host: host)
        }

        let pokemonEncounterId = json["pokemon_encounter_id"] as? String
        let pokemonEncounterIdForEncounter = json["pokemon_encounter_id_for_encounter"] as? String
        let targetMaxDistance = json["target_max_distnace"] as? Double ?? 250

        var wildPokemons = [(cell: UInt64, data: WildPokemonProto, timestampMs: UInt64)]()
        var nearbyPokemons = [(cell: UInt64, data: NearbyPokemonProto)]()
        var mapPokemons = [(cell: UInt64, pokeData: MapPokemonProto)]()
        var clientWeathers =  [(cell: Int64, data: ClientWeatherProto)]()
        var forts = [(cell: UInt64, data: PokemonFortProto)]()
        var fortDetails = [FortDetailsOutProto]()
        var gymInfos = [GymGetInfoOutProto]()
        var quests = [(clientQuest: ClientQuestProto, hasAr: Bool)]()
        var fortSearch = [FortSearchOutProto]()
        var encounters = [EncounterOutProto]()
        var diskEncounters = [DiskEncounterOutProto]()
        var playerdatas = [GetPlayerOutProto]()
        var cells = [UInt64]()

        var isEmtpyGMO = true
        var isInvalidGMO = true
        var containsGMO = false

        for rawData in contents {

            let hasArQuestReq = rawData["have_ar"] as? Bool
            let data: Data
            let method: Int
            if let prr = rawData["GetPlayerResponse"] as? String {
                data = Data(base64Encoded: prr) ?? Data()
                method = 2
            } else if let gmo = rawData["GetMapObjects"] as? String {
                data = Data(base64Encoded: gmo) ?? Data()
                method = 106
            } else if let enr = rawData["EncounterResponse"] as? String {
                data = Data(base64Encoded: enr) ?? Data()
                method = 102
            } else if let denr = rawData["DiskEncounterResponse"] as? String {
                data = Data(base64Encoded: denr) ?? Data()
                method = 145
            } else if let fdr = rawData["FortDetailsResponse"] as? String {
                data = Data(base64Encoded: fdr) ?? Data()
                method = 104
            } else if let fsr = rawData["FortSearchResponse"] as? String {
                data = Data(base64Encoded: fsr) ?? Data()
                method = 101
            } else if let ggi = rawData["GymGetInfoResponse"] as? String {
                data = Data(base64Encoded: ggi) ?? Data()
                method = 156
            } else if let inv = rawData["GetHoloholoInventoryOutProto"] as? String {
                data = Data(base64Encoded: inv) ?? Data()
                method = 4
            } else if let dataString = rawData["data"] as? String {
                data = Data(base64Encoded: dataString) ?? Data()
                method = rawData["method"] as? Int ?? 106
            } else if let madString = rawData["payload"] as? String {
                data = Data(base64Encoded: madString) ?? Data()
                method = rawData["type"] as? Int ?? 106
            } else {
                continue
            }

            if method == 2 {
                if let gpr = try? GetPlayerOutProto(serializedData: data) {
                    playerdatas.append(gpr)
                } else {
                    Log.warning(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Malformed GetPlayerResponse")
                }
            } else if method == 4 {
                if let inv = try? GetHoloholoInventoryOutProto(serializedData: data) {
                    if inv.inventoryDelta.inventoryItem.count > 0 {
                        for item in inv.inventoryDelta.inventoryItem {
                            if item.inventoryItemData.playerStats.experience > 0 {
                                trainerXP = Int(item.inventoryItemData.playerStats.experience)
                            }
                            if uuid != nil && item.inventoryItemData.quests.quest.count > 0 {
                                for quest in item.inventoryItemData.quests.quest {
                                    if quest.questContext == .challengeQuest &&
                                       quest.questType == .questGeotargetedArScan {
                                        questArActualMap.setValue(key: uuid!, value: true, time: timestamp)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Log.warning(message:
                        "[WebHookRequestHandler] [\(uuid ?? "?")] Malformed GetHoloholoInventoryOutProto"
                    )
                }
            } else if method == 101 {
                if let fsr = try? FortSearchOutProto(serializedData: data) {
                    if fsr.result != FortSearchOutProto.Result.success {
                        Log.debug(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Ignored non-success " +
                            "FortSearchResponse: \(fsr.result)")
                        continue
                    }
                    if fsr.hasChallengeQuest && fsr.challengeQuest.hasQuest {
                        let hasAr = hasArQuestReqGlobal ??
                            hasArQuestReq ??
                            getArQuestMode(device: uuid, timestamp: timestamp)
                        let challengeQuest = fsr.challengeQuest
                        // Ignore AR quests so they get rescanned if they were the first quest a scanner would hold onto
                        if challengeQuest.quest.questType != .questGeotargetedArScan || allowARQuests {
                            if challengeQuest.quest.questType == .questGeotargetedArScan && uuid != nil {
                                questArActualMap.setValue(key: uuid!, value: true, time: timestamp)
                            }
                            quests.append((clientQuest: challengeQuest, hasAr: hasAr))
                        } else {
                            Log.warning(message:
                            "[WebHookRequestHandler] Quest blocked because it is has the " +
                            "\(String(describing: challengeQuest.quest.questType)) type.")
                            Log.info(message:
                            "[WebHookRequestHandler] Quest info: \(String(describing: challengeQuest.quest))")
                        }
                    }
                    fortSearch.append(fsr)
                } else {
                    Log.warning(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Malformed FortSearchResponse")
                }
            } else if method == 102 && trainerLevel >= 30 || method == 102 && isMadData == true {
                if let enr = try? EncounterOutProto(serializedData: data) {
                    if enr.status != EncounterOutProto.Status.encounterSuccess {
                        Log.debug(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Ignored non-success " +
                            "EncounterOutProto: \(enr.status)")
                        continue
                    }
                    encounters.append(enr)
                } else {
                    Log.warning(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Malformed EncounterResponse")
                }
            } else if method == 145 && trainerLevel >= 30 || method == 145 && isMadData == true {
                if processMapPokemon, let denr = try? DiskEncounterOutProto(serializedData: data) {
                    if denr.result != DiskEncounterOutProto.Result.success {
                        Log.debug(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Ignored non-success " +
                            "DiskEncounterOutProto: \(denr.result)")
                        continue
                    }
                    diskEncounters.append(denr)
                } else {
                    Log.warning(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Malformed DiskEncounterResponse")
                }
            } else if method == 104 {
                if let fdr = try? FortDetailsOutProto(serializedData: data) {
                    fortDetails.append(fdr)
                } else {
                    Log.warning(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Malformed FortDetailsResponse")
                }
            } else if method == 156 {
                if let ggi = try? GymGetInfoOutProto(serializedData: data) {
                    if ggi.result != GymGetInfoOutProto.Result.success {
                        Log.debug(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Ignored non-success " +
                            "GymGetInfoResponse: \(ggi.result)")
                        continue
                    }
                    gymInfos.append(ggi)
                } else {
                    Log.warning(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Malformed GymGetInfoResponse")
                }
            } else if method == 106 {
                containsGMO = true
                if let gmo = try? GetMapObjectsOutProto(serializedData: data) {
                    if gmo.status != GetMapObjectsOutProto.Status.success {
                        Log.debug(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Ignored non-success " +
                            "GMO: \(gmo.status)")
                        continue
                    }
                    isInvalidGMO = false

                    var newWildPokemons = [(cell: UInt64, data: WildPokemonProto,
                                            timestampMs: UInt64)]()
                    var newNearbyPokemons = [(cell: UInt64, data: NearbyPokemonProto)]()
                    var newMapPokemons = [(cell: UInt64, pokeData: MapPokemonProto)]()

                    var newClientWeathers = [(cell: Int64, data: ClientWeatherProto)]()
                    var newForts = [(cell: UInt64, data: PokemonFortProto)]()
                    var newCells = [UInt64]()

                    for mapCell in gmo.mapCell {
                        let timestampMs = UInt64(mapCell.asOfTimeMs)
                        for wildPokemon in mapCell.wildPokemon {
                            newWildPokemons.append((cell: mapCell.s2CellID, data: wildPokemon,
                                            timestampMs: timestampMs))
                        }
                        for nearbyPokemon in mapCell.nearbyPokemon {
                            newNearbyPokemons.append((cell: mapCell.s2CellID, data: nearbyPokemon))
                        }
                        for fort in mapCell.fort {
                            newForts.append((cell: mapCell.s2CellID, data: fort))
                            if processMapPokemon && fort.hasActivePokemon {
                                newMapPokemons.append((cell: mapCell.s2CellID, pokeData: fort.activePokemon))
                            }
                        }
                        newCells.append(mapCell.s2CellID)
                    }

                    for wmapCell in gmo.clientWeather {
                        newClientWeathers.append((cell: wmapCell.s2CellID, data: wmapCell))
                    }

                    if newWildPokemons.isEmpty && newNearbyPokemons.isEmpty && newForts.isEmpty {
                        for cell in newCells {
                            emptyCellsLock.lock()
                            let count = emptyCells[cell]
                            if count == nil {
                                emptyCells[cell] = 1
                            } else {
                                emptyCells[cell] = count! + 1
                            }
                            emptyCellsLock.unlock()
                            if count == 3 {
                                Log.warning(
                                    message: "[WebHookRequestHandler] [\(uuid ?? "?")] Cell \(cell) was " +
                                             "empty 3 times in a row. Assuming empty."
                                )
                                cells.append(cell)
                            }
                        }

                        Log.debug(message: "[WebHookRequestHandler] [\(uuid ?? "?")] GMO is empty.")
                    } else {
                        for cell in newCells {
                            emptyCellsLock.lock()
                            emptyCells[cell] = 0
                            emptyCellsLock.unlock()
                        }
                        isEmtpyGMO = false
                        wildPokemons += newWildPokemons
                        nearbyPokemons += newNearbyPokemons
                        mapPokemons += newMapPokemons
                        forts += newForts
                        cells += newCells
                        clientWeathers += newClientWeathers
                    }
                } else {
                    Log.warning(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Malformed GetMapObjectsResponse")
                }
            }
        }

        if rawDebugEnabled {
            if rawDebugTypes.contains("GetPlayerResponse") && !playerdatas.isEmpty {
                Log.debug(message: "[WebhookRequestHandler] [\(uuid ?? "?")] playerdatas: \(playerdatas)")
            }
            if rawDebugTypes.contains("GetMapObjects_wildMons") && !wildPokemons.isEmpty {
                Log.debug(message: "[WebhookRequestHandler] [\(uuid ?? "?")] wildPokemons: \(wildPokemons)")
            }
            if rawDebugTypes.contains("GetMapObjects_nearbyMons") && !nearbyPokemons.isEmpty {
                Log.debug(message: "[WebhookRequestHandler] [\(uuid ?? "?")] nearbyPokemons: \(nearbyPokemons)")
            }
            if rawDebugTypes.contains("GetMapObjects_mapMons") && !mapPokemons.isEmpty {
                Log.debug(message: "[WebhookRequestHandler] [\(uuid ?? "?")] mapPokemons: \(mapPokemons)")
            }
            if rawDebugTypes.contains("GetMapObjects_forts") && !forts.isEmpty {
                Log.debug(message: "[WebhookRequestHandler] [\(uuid ?? "?")] forts: \(forts)")
            }
            if rawDebugTypes.contains("GetMapObjects_cells") && !cells.isEmpty {
                Log.debug(message: "[WebhookRequestHandler] [\(uuid ?? "?")] cells: \(cells)")
            }
            if rawDebugTypes.contains("GetMapObjects_clientWeathers") && !clientWeathers.isEmpty {
                Log.debug(message: "[WebhookRequestHandler] [\(uuid ?? "?")] clientWeathers: \(clientWeathers)")
            }
            if rawDebugTypes.contains("EncounterResponse") && !encounters.isEmpty {
                Log.debug(message: "[WebhookRequestHandler] [\(uuid ?? "?")] encounters: \(encounters)")
            }
            if rawDebugTypes.contains("DiskEncounterResponse") && !diskEncounters.isEmpty {
                Log.debug(message: "[WebhookRequestHandler] [\(uuid ?? "?")] diskEncounters: \(diskEncounters)")
            }
            if rawDebugTypes.contains("FortDetailsResponse") && !fortDetails.isEmpty {
                Log.debug(message: "[WebhookRequestHandler] [\(uuid ?? "?")] fortDetails: \(fortDetails)")
            }
            if rawDebugTypes.contains("FortSearchResponse") && !fortSearch.isEmpty {
                Log.debug(message: "[WebhookRequestHandler] [\(uuid ?? "?")] fortSearch: \(fortSearch)")
            }
            if rawDebugTypes.contains("GymGetInfoResponse") && !gymInfos.isEmpty {
                Log.debug(message: "[WebhookRequestHandler] [\(uuid ?? "?")] gymInfos: \(gymInfos)")
            }
        }

        if username != nil && trainerXP > 0 && trainerLevel > 0 {
            InstanceController.global.gotPlayerInfo(username: username!, level: trainerLevel, xp: trainerXP)
        }

        let targetCoord: LocationCoordinate2D?
        var inArea = false
        if latTarget != nil && lonTarget != nil {
            targetCoord = LocationCoordinate2D(latitude: latTarget!, longitude: lonTarget!)
        } else {
            targetCoord = nil
        }

        var pokemonCoords: LocationCoordinate2D?

        if targetCoord != nil {
            for fort in forts {
                InstanceController.global.gotFortData(fortData: fort.data, username: username)
                if !inArea {
                    let coord = LocationCoordinate2D(latitude: fort.data.latitude, longitude: fort.data.longitude)
                    if coord.distance(to: targetCoord!) <= targetMaxDistance {
                        inArea = true
                    }
                }
            }
        }
        if targetCoord != nil || pokemonEncounterId != nil {
            for pokemon in wildPokemons {
                if targetCoord != nil {
                    if !inArea {
                        let coord = LocationCoordinate2D(latitude: pokemon.data.latitude,
                                                           longitude: pokemon.data.longitude)
                        if coord.distance(to: targetCoord!) <= targetMaxDistance {
                            inArea = true
                        }
                    } else if pokemonCoords != nil && inArea {
                        break
                    }
                }
                if pokemonEncounterId != nil {
                    if pokemonCoords == nil {
                        if pokemon.data.encounterID.description == pokemonEncounterId {
                            pokemonCoords = LocationCoordinate2D(latitude: pokemon.data.latitude,
                                                                   longitude: pokemon.data.longitude)
                        }
                    } else if pokemonCoords != nil && inArea {
                        break
                    }
                }
            }
        }
        if targetCoord != nil && !inArea {
            for cell in cells {
                if !inArea {
                    let cell = S2Cell(cellId: S2CellId(uid: cell))
                    let coord = S2LatLng(point: cell.center).coord
                    if coord.distance(to: targetCoord!) <= max(targetMaxDistance, 100) {
                        inArea = true
                    }
                } else {
                    break
                }
            }
        }

        var data = ["nearby": nearbyPokemons.count, "wild": wildPokemons.count, "map": mapPokemons.count,
                    "forts": forts.count, "quests": quests.count, "encounters": encounters.count,
                    "disk_encounters": diskEncounters.count, "level": trainerLevel as Any,
                    "only_empty_gmos": containsGMO && isEmtpyGMO, "fort_search": fortSearch.count,
                    "only_invalid_gmos": containsGMO && isInvalidGMO, "contains_gmos": containsGMO
        ]

        if pokemonEncounterIdForEncounter != nil {
            // If the UIC sets pokemon_encounter_id_for_encounter,
            // only return encounters != 0 if we actually encounter that target.
            // "Guaranteed scan"
            data["encounters"] = 0
            for encounter in encounters where
                encounter.pokemon.encounterID.description == pokemonEncounterIdForEncounter {
                // We actually encountered the target.
                data["encounters"] = 1
            }
        }

        if latTarget != nil && lonTarget != nil {
            data["in_area"] = inArea
            data["lat_target"] = latTarget!
            data["lon_target"] = lonTarget!
        }
        if pokemonCoords != nil && pokemonEncounterId != nil {
            data["pokemon_lat"] = pokemonCoords!.latitude
            data["pokemon_lon"] = pokemonCoords!.longitude
            data["pokemon_encounter_id"] = pokemonEncounterId!
        }

        do {
            try response.respondWithData(data: data)
        } catch {
            response.respondWithError(status: .internalServerError)
        }

        if username != nil && maxEncounter > 0 {
            encounterLock.doWithLock {
                var countValue: Int = (encounterCount[username!] ?? 0) + encounters.count
                if countValue < maxEncounter {
                    encounterCount[username!] = countValue
                    Log.debug(message: "[WebHookRequestHandler] [\(uuid)] [\(username!)] #Encounter: \(countValue)")
                } else {
                    try? Account.setDisabled(mysql: mysql, username: username!)
                    encounterCount[username!] = 0
                    Log.debug(message: "[WebHookRequestHandler] [\(uuid)] [\(username!)] Account disabled.")
                }
            }
        }

        let queue = Threading.getQueue(name: Foundation.UUID().uuidString, type: .serial)
        queue.dispatch {

            defer {
                Threading.destroyQueue(queue)
            }

            if !playerdatas.isEmpty && username != nil {
                let start = Date()
                for playerdata in playerdatas {
                    let account: Account?
                    do {
                        account = try Account.getWithUsername(mysql: mysql, username: username!)
                    } catch {
                        account = nil
                    }
                    if account != nil {
                        account!.updateFromResponseInfo(accountData: playerdata)
                        try? account!.save(mysql: mysql, update: true)
                    }
                }
                Log.debug(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Player Detail parsed in " +
                                   "\(String(format: "%.3f", Date().timeIntervalSince(start)))s")
            }

            guard InstanceController.global.shouldStoreData(deviceUUID: uuid ?? "") else {
                Log.debug(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Ignoring data for \(uuid ?? "?")")
                return
            }

            threadLimitLock.lock()
            if threadLimitCount >= threadLimitMax {
                threadLimitIgnoredCount += 1
                threadLimitTotalCount += 1
                threadLimitLock.unlock()
                Log.warning(
                    message: "[WebHookRequestHandler] [\(uuid ?? "?")] Reached thread limit of \(threadLimitMax) " +
                              "for /raw. Ignoring request."
                )
                return
            }
            let limitCount = threadLimitCount + 1
            threadLimitCount = limitCount
            threadLimitTotalCount += 1
            threadLimitLock.unlock()
            let percentage = Float(limitCount) / Float(threadLimitMax)
            let message = "[WebHookRequestHandler] [\(uuid ?? "?")] Processing /raw request. " +
                          "Currently processing: \(limitCount) (\(Int(percentage*100))%)"
            if percentage >= 0.9 {
                Log.info(message: message)
            } else {
                Log.debug(message: message)
            }

            defer {
                threadLimitLock.lock()
                threadLimitCount -= 1
                threadLimitLock.unlock()
            }

            var gymIdsPerCell = [UInt64: [String]]()
            var stopsIdsPerCell = [UInt64: [String]]()

            for cellId in cells {
                let s2cell = S2Cell(cellId: S2CellId(uid: cellId))
                let lat = s2cell.capBound.rectBound.center.lat.degrees
                let lon = s2cell.capBound.rectBound.center.lng.degrees
                let level = s2cell.level
                let cell = Cell(id: cellId, level: UInt8(level), centerLat: lat, centerLon: lon, updated: nil)
                try? cell.save(mysql: mysql)

                if gymIdsPerCell[cellId] == nil {
                    gymIdsPerCell[cellId] = [String]()
                }
                if stopsIdsPerCell[cellId] == nil {
                    stopsIdsPerCell[cellId] = [String]()
                }

            }

            let startclientWeathers = Date()
            for conditions in clientWeathers {
                let ws2cell = S2Cell(cellId: S2CellId(id: conditions.cell))
                let wlat = ws2cell.capBound.rectBound.center.lat.degrees
                let wlon = ws2cell.capBound.rectBound.center.lng.degrees
                let wlevel = ws2cell.level
                let weather = Weather(mysql: mysql, id: ws2cell.cellId.id, level: UInt8(wlevel),
                                      latitude: wlat, longitude: wlon, conditions: conditions.data, updated: nil)
                try? weather.save(mysql: mysql)
            }
            if !clientWeathers.isEmpty {
                Log.debug(
                    message: "[WebHookRequestHandler] [\(uuid ?? "?")] Weather Detail Count: \(clientWeathers.count) " +
                             "parsed in \(String(format: "%.3f", Date().timeIntervalSince(startclientWeathers)))s"
                )
            }

            let startWildPokemon = Date()
            for wildPokemon in wildPokemons {
                let id = wildPokemon.data.encounterID.description
                let pokemon = (try? Pokemon.getWithId(mysql: mysql, id: id, copy: true, isEvent: isEvent)) ?? Pokemon()
                pokemon.updateFromWild(mysql: mysql, wildPokemon: wildPokemon.data, cellId: wildPokemon.cell,
                    timestampMs: wildPokemon.timestampMs, username: username, isEvent: isEvent)
                try? pokemon.save(mysql: mysql)
            }
            if !wildPokemons.isEmpty {
                Log.debug(
                    message: "[WebHookRequestHandler] [\(uuid ?? "?")] Pokemon Count: \(wildPokemons.count) parsed " +
                             "in \(String(format: "%.3f", Date().timeIntervalSince(startWildPokemon)))s"
                )
            }

            let startPokemon = Date()
            for nearbyPokemon in nearbyPokemons {
                let id = nearbyPokemon.data.encounterID.description
                let pokemon = (try? Pokemon.getWithId(mysql: mysql, id: id, copy: true, isEvent: isEvent)) ?? Pokemon()
                do {
                    try pokemon.updateFromNearby(mysql: mysql, nearbyPokemon: nearbyPokemon.data,
                        cellId: nearbyPokemon.cell, username: username, isEvent: isEvent)
                } catch {
                    continue
                }
                try? pokemon.save(mysql: mysql)
            }
            if !nearbyPokemons.isEmpty {
                Log.debug(
                    message: "[WebHookRequestHandler] [\(uuid ?? "?")] NearbyPokemon Count: \(nearbyPokemons.count) " +
                             "parsed in \(String(format: "%.3f", Date().timeIntervalSince(startPokemon)))s"
                )
            }

            let startMapPokemon = Date()
            for mapPokemon in mapPokemons {
                let id = mapPokemon.pokeData.encounterID.description
                let pokemon = (try? Pokemon.getWithId(mysql: mysql, id: id, copy: true, isEvent: isEvent)) ?? Pokemon()
                do {
                    try pokemon.updateFromMap(mysql: mysql, mapPokemon: mapPokemon.pokeData, cellId: mapPokemon.cell,
                        username: username, isEvent: isEvent)
                } catch {
                    continue
                }
                // Check if we have a pending disk encounter cache.
                let displayId = mapPokemon.pokeData.pokemonDisplay.displayID
                let displayIdCacheKey = UInt64(bitPattern: displayId).toString()
                if let cachedEncounter = Pokemon.diskEncounterCache?.get(id: displayIdCacheKey) {
                    pokemon.updateFromDiskEncounterProto(mysql: mysql, diskEncounterData: cachedEncounter,
                        username: username)
                    Log.debug(message: "[WebHookRequestHandler] Found DiskEncounter in Cache: \(displayIdCacheKey)")
                }
                try? pokemon.save(mysql: mysql)
            }
            if !mapPokemons.isEmpty {
                Log.debug(
                    message: "[WebHookRequestHandler] [\(uuid ?? "?")] MapPokemon Count: \(mapPokemons.count) " +
                        "parsed in \(String(format: "%.3f", Date().timeIntervalSince(startMapPokemon)))s"
                )
            }

            let startForts = Date()
            for fort in forts {
                if fort.data.fortType == .gym {
                    let id = fort.data.fortID
                    let gym = (try? Gym.getWithId(mysql: mysql, id: id, copy: true, withDeleted: true))
                        ?? Gym()
                    gym.updateFromFort(fortData: fort.data, cellId: fort.cell)
                    try? gym.save(mysql: mysql)
                    if gymIdsPerCell[fort.cell] == nil {
                        gymIdsPerCell[fort.cell] = [String]()
                    }
                    gymIdsPerCell[fort.cell]!.append(fort.data.fortID)
                } else if fort.data.fortType == .checkpoint {
                    let id = fort.data.fortID
                    let pokestop = (try? Pokestop.getWithId(mysql: mysql, id: id, copy: true, withDeleted: true))
                        ?? Pokestop()
                    pokestop.updateFromFort(fortData: fort.data, cellId: fort.cell)
                    try? pokestop.save(mysql: mysql)
                    pokestop.incidents.forEach({ incident in try? incident.save(mysql: mysql) })
                    if stopsIdsPerCell[fort.cell] == nil {
                        stopsIdsPerCell[fort.cell] = [String]()
                    }
                    stopsIdsPerCell[fort.cell]!.append(fort.data.fortID)
                }
            }
            if !forts.isEmpty {
                Log.debug(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Forts Count: \(forts.count) parsed in " +
                                   "\(String(format: "%.3f", Date().timeIntervalSince(startForts)))s")
            }

            if !fortDetails.isEmpty {
                let start = Date()
                for fort in fortDetails {
                    if fort.fortType == .gym {
                        let gym: Gym?
                        do {
                            gym = try Gym.getWithId(mysql: mysql, id: fort.id, copy: true)
                        } catch {
                            gym = nil
                        }
                        if gym != nil {
                            gym!.updateFromFortDetails(fortData: fort)
                            try? gym!.save(mysql: mysql)
                        }
                    } else if fort.fortType == .checkpoint {
                        let pokestop: Pokestop?
                        do {
                            pokestop = try Pokestop.getWithId(mysql: mysql, id: fort.id, copy: true)
                        } catch {
                            pokestop = nil
                        }
                        if pokestop != nil {
                            pokestop!.updateFromFortDetails(fortData: fort)
                            try? pokestop!.save(mysql: mysql)
                        }
                    }
                }
                Log.debug(
                    message: "[WebHookRequestHandler] [\(uuid ?? "?")] Forts Detail Count: \(fortDetails.count) " +
                             "parsed in \(String(format: "%.3f", Date().timeIntervalSince(start)))s"
                )
            }

            if !gymInfos.isEmpty {
                let start = Date()
                for gymInfo in gymInfos {
                    let gym: Gym?
                    do {
                        gym = try Gym.getWithId(mysql: mysql, id: gymInfo.gymStatusAndDefenders.pokemonFortProto.fortID,
                            copy: true)
                    } catch {
                        gym = nil
                    }
                    if gym != nil {
                        gym!.updateFromGymInfo(gymInfo: gymInfo)
                        try? gym!.save(mysql: mysql)
                    }
                }
                Log.debug(
                    message: "[WebHookRequestHandler] [\(uuid ?? "?")] Gyms Info Count: \(gymInfos.count) " +
                             "parsed in \(String(format: "%.3f", Date().timeIntervalSince(start)))s"
                )
            }

            if !quests.isEmpty {
                let start = Date()
                for (clientQuest, hasAr) in quests {
                    let pokestop: Pokestop?
                    do {
                        pokestop = try Pokestop.getWithId(mysql: mysql, id: clientQuest.quest.fortID, copy: true)
                    } catch {
                        pokestop = nil
                    }
                    if pokestop != nil {
                        pokestop!.updatePokestopFromQuestProto(questData: clientQuest, hasARQuest: hasAr)
                        try? pokestop!.save(mysql: mysql)
                    }
                }
                Log.debug(
                    message: "[WebHookRequestHandler] [\(uuid ?? "?")] Quest Count: \(quests.count) " +
                             "parsed in \(String(format: "%.3f", Date().timeIntervalSince(start)))s"
                )
            }

            if !encounters.isEmpty {
                let start = Date()
                for encounter in encounters {
                    let id = encounter.pokemon.encounterID.description
                    let pokemon = (try? Pokemon.getWithId(mysql: mysql, id: id, copy: true, isEvent: isEvent))
                        ?? Pokemon()
                    pokemon.updateFromEncounterProto(mysql: mysql, encounterData: encounter,
                        username: username, isEvent: isEvent)
                    try? pokemon.save(mysql: mysql)

                }
                Log.debug(
                    message: "[WebHookRequestHandler] [\(uuid ?? "?")] Encounter Count: \(encounters.count) " +
                             "parsed in \(String(format: "%.3f", Date().timeIntervalSince(start)))s"
                )
            }

            if !diskEncounters.isEmpty {
                let start = Date()
                for diskEncounter in diskEncounters {
                    let displayId = diskEncounter.pokemon.pokemonDisplay.displayID
                    let cacheKey = UInt64(bitPattern: displayId).toString()
                    let pokemon: Pokemon?
                    do {
                        pokemon = try Pokemon.getWithId(mysql: mysql, id: cacheKey, copy: true, isEvent: isEvent)
                    } catch {
                        pokemon = nil
                    }
                    if pokemon != nil {
                        pokemon!.updateFromDiskEncounterProto(mysql: mysql, diskEncounterData: diskEncounter,
                            username: username)
                        try? pokemon!.save(mysql: mysql)
                    } else {
                        // No pokemon found, write in cache and process later
                        Pokemon.diskEncounterCache?.set(id: cacheKey, value: diskEncounter)
                        Log.debug(message: "[WebHookRequestHandler] Write DiskEncounter in cache: \(cacheKey)")
                    }
                }
                Log.debug(
                    message: "[WebHookRequestHandler] [\(uuid ?? "?")] Disk Encounter Count: \(diskEncounters.count) " +
                        "parsed in \(String(format: "%.3f", Date().timeIntervalSince(start)))s"
                )
            }

            if enableClearing {
                for (cellId, gymIds) in gymIdsPerCell {
                    let cachedCell = Cell.cache?.get(id: cellId.toString())
                    if cachedCell?.gymCount != gymIds.count {
                        Log.debug(message: "[WebHookRequestHandler] Clearing old gyms in \(cellId): " +
                            "\(cachedCell?.gymCount ?? 0) != \(gymIds.count)")
                        if let cleared = try? Gym.clearOld(mysql: mysql, ids: gymIds, cellId: cellId),
                           cleared != 0 {
                            Log.info(message: "[WebHookRequestHandler] [\(uuid ?? "?")] " +
                                "Cleared \(cleared) old Gyms.")
                        }
                    }
                    cachedCell?.gymCount = gymIds.count
                }
                for (cellId, stopIds) in stopsIdsPerCell {
                    let cachedCell = Cell.cache?.get(id: cellId.toString())
                    if cachedCell?.stopCount != stopIds.count {
                        if let cleared = try? Pokestop.clearOld(mysql: mysql, ids: stopIds, cellId: cellId),
                           cleared != 0 {
                            Log.info(message: "[WebHookRequestHandler] [\(uuid ?? "?")] " +
                                "Cleared \(cleared) old Pokestops.")
                        }
                    }
                    cachedCell?.stopCount = stopIds.count
                }
            }
        }
    }

    static func controlerHandler(request: HTTPRequest, response: HTTPResponse, host: String) {

        let jsonO = request.postBodyString?.jsonDecodeForceTry() as? [String: Any]
        let typeO = jsonO?["type"] as? String
        let uuidO = jsonO?["uuid"] as? String

        guard let type = typeO, let uuid = uuidO else {
            response.respondWithError(status: .badRequest)
            return
        }

        let username = (jsonO?["username"] as? String)?.emptyToNil()
        let timestamp = jsonO?["timestamp"] as? UInt64 ?? Date().timestampMs

        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[WebHookRequestHandler] [\(uuid)] Failed to connect to database.")
            response.respondWithError(status: .internalServerError)
            return
        }

        Log.debug(message: "[WebHookRequestHandler] [\(uuid)] Got control request: \(type)")
        if type == "init" {
            do {
                let device = try Device.getById(mysql: mysql, id: uuid)
                let assigned: Bool
                if device == nil {
                    let newDevice = Device(uuid: uuid, instanceName: nil, lastHost: nil, lastSeen: 0,
                                           accountUsername: nil, lastLat: 0.0, lastLon: 0.0)
                    try newDevice.create(mysql: mysql)
                    assigned = false
                } else {
                    if device!.instanceName == nil {
                        assigned = false
                    } else {
                        assigned = true
                    }
                }
                try response.respondWithData(
                    data: [
                        "assigned": assigned,
                        "version": VersionManager.global.version,
                        "commit": VersionManager.global.commit,
                        "provider": "RealDeviceMap"
                    ]
                )
            } catch {
                response.respondWithError(status: .internalServerError)
            }
        } else if type == "heartbeat" {
            do {
                try Device.touch(mysql: mysql, uuid: uuid, host: host)
                response.respondWithOk()
            } catch {
                response.respondWithError(status: .internalServerError)
            }
        } else if type == "get_job" {
            let controller = InstanceController.global.getInstanceController(deviceUUID: uuid)
            if controller != nil {
                do {
                    let account: Account?
                    if let username = username {
                        account = try Account.getWithUsername(mysql: mysql, username: username)
                    } else {
                        account = nil
                    }
                    if let account = account {
                        guard controller!.accountValid(account: account) else {
                            Log.info(
                                message: "[WebHookRequestHandler] [\(uuid)] Account \(account.username) not valid " +
                                         "for Instance \(controller!.name). Switching Account."
                            )
                            try response.respondWithData(data: [
                                "action": "switch_account",
                                "min_level": controller!.minLevel,
                                "max_level": controller!.maxLevel
                            ])
                            return
                        }
                    } else if let username = username, account == nil {
                        Log.error(
                            message: "[WebHookRequestHandler] [\(uuid)] Account \(username) not found in database. " +
                                     "Switching Account."
                        )
                        try response.respondWithData(data: [
                            "action": "switch_account",
                            "min_level": controller!.minLevel,
                            "max_level": controller!.maxLevel
                        ])
                        return
                    }
                    let task = controller!.getTask(
                        mysql: mysql, uuid: uuid, username: username,
                        account: account, timestamp: timestamp
                    )
                    Log.info(
                        message: "[WebHookRequestHandler] [\(uuid)] Sending task: \(task["action"] as? String ?? "?")" +
                        " at \((task["lat"] as? Double)?.description ?? "?")," +
                        "\((task["lon"] as? Double)?.description ?? "?")"
                    )
                    try response.respondWithData(data: task)
                } catch {
                    response.respondWithError(status: .internalServerError)
                }
            } else {
                response.respondWithError(status: .notFound)
            }
        } else if type == "get_account" {
            do {
                guard let device = try Device.getById(mysql: mysql, id: uuid) else {
                    response.respondWithError(status: .notFound)
                    return
                }
                var account: Account?
                if device.accountUsername != nil,
                   let oldAccount = try Account.getWithUsername(mysql: mysql, username: device.accountUsername!) {
                    if InstanceController.global.accountValid(deviceUUID: uuid, account: oldAccount) {
                        account = oldAccount
                    } else {
                        Log.debug(
                            message: "[WebHookRequestHandler] [\(uuid)] Previously Assigned Account " +
                                     "\(oldAccount.username) not valid for Instance " +
                                     "\(device.instanceName ?? "None"). Getting new Account."
                        )
                    }
                }
                if account == nil {
                    guard let newAccount = try InstanceController.global.getAccount(mysql: mysql, deviceUUID: uuid)
                    else {
                        Log.error(message: "[WebHookRequestHandler] [\(uuid)] Failed to get account for \(uuid)")
                        response.respondWithError(status: .notFound)
                        return
                    }
                    account = newAccount
                }

                if username != account!.username, loginLimitEnabled {
                    let currentTime = UInt32(Date().timeIntervalSince1970) / loginLimitIntervall
                    let left = loginLimitIntervall - UInt32(Date().timeIntervalSince1970) % loginLimitIntervall
                    self.loginLimitLock.lock()
                    let currentCount: UInt32
                    if self.loginLimitTime[host] != currentTime {
                        self.loginLimitTime[host] = currentTime
                        currentCount = 0
                    } else {
                        currentCount = self.loginLimitCount[host] ?? 0
                    }
                    guard currentCount < loginLimit else {
                        self.loginLimitLock.unlock()
                        Log.info(
                            message: "[WebHookRequestHandler] [\(uuid)] Login Limit for \(host): " +
                                     "exceeded (\(left)s left)"
                        )
                        response.addHeader(.retryAfter, value: "\(left)")
                        response.respondWithError(status: .custom(code: 429, message: "Login Limit exceeded"))
                        return
                    }
                    self.loginLimitCount[host] = currentCount + 1
                    self.loginLimitLock.unlock()
                    Log.debug(
                        message: "[WebHookRequestHandler] [\(uuid)] Login Limit for \(host): " +
                                 "\(currentCount + 1)/\(loginLimit) (\(left)s left)"
                    )
                }
                if username != account!.username {
                    Log.debug(message: "[WebHookRequestHandler] [\(uuid)] New account: \(account!.username)")
                }

                device.accountUsername = account!.username
                try device.save(mysql: mysql, oldUUID: device.uuid)
                try response.respondWithData(data: [
                    "username": account!.username,
                    "password": account!.password
                ])
            } catch {
                response.respondWithError(status: .internalServerError)
            }
        } else if type == "tutorial_done" {
            do {
                guard
                    let device = try Device.getById(mysql: mysql, id: uuid),
                    let username = device.accountUsername,
                    let account = try Account.getWithUsername(mysql: mysql, username: username)
                    else {
                        response.respondWithError(status: .internalServerError)
                        return
                }
                if account.level == 0 {
                    account.level = 1
                    try account.save(mysql: mysql, update: true)
                }
                response.respondWithOk()
            } catch {
                response.respondWithError(status: .internalServerError)
            }
        } else if type == "account_banned" {
            do {
                guard
                    let username = username,
                    let account = try Account.getWithUsername(mysql: mysql, username: username)
                else {
                    response.respondWithError(status: .internalServerError)
                    return
                }
                account.failedTimestamp = UInt32(Date().timeIntervalSince1970)
                account.failed = "banned"
                Log.warning(message: "[WebHookRequestHandler] [\(uuid)] Account banned: \(username)")
                try account.save(mysql: mysql, update: true)
                response.respondWithOk()
            } catch {
                response.respondWithError(status: .internalServerError)
            }
        } else if type == "account_suspended" {
            do {
                guard
                    let username = username,
                    let account = try Account.getWithUsername(mysql: mysql, username: username)
                else {
                    response.respondWithError(status: .internalServerError)
                    return
                }
                account.failedTimestamp = UInt32(Date().timeIntervalSince1970)
                account.failed = "suspended"
                Log.warning(message: "[WebHookRequestHandler] [\(uuid)] Account suspended: \(username)")
                try account.save(mysql: mysql, update: true)
                response.respondWithOk()
            } catch {
                response.respondWithError(status: .internalServerError)
            }
        } else if type == "account_warning" {
            do {
                guard
                    let username = username,
                    let account = try Account.getWithUsername(mysql: mysql, username: username)
                    else {
                        response.respondWithError(status: .notFound)
                        return
                }
                let now = UInt32(Date().timeIntervalSince1970)
                if account.firstWarningTimestamp == nil {
                    account.firstWarningTimestamp = now
                }
                if account.warnExpireTimestamp == nil {
                    account.warnExpireTimestamp = now + Account.warnedPeriod
                }
                account.failedTimestamp = now
                account.failed = "GPR_RED_WARNING"
                Log.warning(message: "[WebHookRequestHandler] [\(uuid)] Account warning: \(username)")
                try account.save(mysql: mysql, update: true)
                response.respondWithOk()
            } catch {
                response.respondWithError(status: .internalServerError)
            }
        } else if type == "account_invalid_credentials" {
            do {
                guard
                    let device = try Device.getById(mysql: mysql, id: uuid),
                    let username = device.accountUsername,
                    let account = try Account.getWithUsername(mysql: mysql, username: username)
                    else {
                        response.respondWithError(status: .notFound)
                        return
                }
                if account.failedTimestamp == nil || account.failed == nil {
                    account.failedTimestamp = UInt32(Date().timeIntervalSince1970)
                    account.failed = "invalid_credentials"
                    try account.save(mysql: mysql, update: true)
                } else {
                    Log.warning(message: "[WebHookRequestHandler] [\(uuid)] Account \(account.username) already " +
                        "failed: \(account.failed ?? "?"). Won't set invalid_credentials.")
                }
                response.respondWithOk()
            } catch {
                response.respondWithError(status: .internalServerError)
            }
        } else if type == "account_unknown_error" {
            // accounts are stuck in e.g. blue maintenance screen, make them invalid for at least one day
            do {
                guard
                    let device = try Device.getById(mysql: mysql, id: uuid),
                    let username = device.accountUsername,
                    let account = try Account.getWithUsername(mysql: mysql, username: username)
                else {
                    response.respondWithError(status: .notFound)
                    return
                }

                Log.warning(message: "[WebHookRequestHandler] [\(uuid)] Account stuck in blue screen: \(username)")
                try Account.setDisabled(mysql: mysql, username: username)
                response.respondWithOk()
            } catch {
                response.respondWithError(status: .internalServerError)
            }
        } else if type == "logged_out" {
            do {
                guard
                    let device = try Device.getById(mysql: mysql, id: uuid)
                else {
                    response.respondWithError(status: .notFound)
                    return
                }
                device.accountUsername = nil
                try device.save(mysql: mysql, oldUUID: device.uuid)
                response.respondWithOk()
            } catch {
                response.respondWithError(status: .internalServerError)
            }
        } else {
            Log.warning(message: "[WebHookRequestHandler] [\(uuid)] Unhandled Request: \(type)")
            response.respondWithError(status: .badRequest)
        }

    }

    static func setArQuestTarget(device: String, timestamp: UInt64, isAr: Bool) {
        questArTargetMap.setValue(key: device, value: isAr, time: timestamp)
        if isAr {
            // ar mode is sent to client -> client will clear ar quest
            questArActualMap.setValue(key: device, value: false, time: timestamp)
        }
    }

    static func getArQuestMode(device: String?, timestamp: UInt64) -> Bool {
        if device == nil {
            return true
        }
        let targetMode = questArTargetMap.getValueAt(key: device!, time: timestamp)
        let actualMode = questArActualMap.getValueAt(key: device!, time: timestamp) ?? false
        if targetMode == nil {
            return true
        } else if targetMode! {
            return false
        } else {
            return actualMode
        }
    }

    static func getLoginLimitConfig() -> String {
        return "\(loginLimitEnabled) - \(loginLimit)/\(loginLimitIntervall)"
    }
}
