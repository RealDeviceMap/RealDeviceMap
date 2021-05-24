//
//  ApiRequestHandler.swift
//  RealDeviceMap
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

class WebHookRequestHandler {

    static var enableClearing = false
    static var hostWhitelist: [String]?
    static var hostWhitelistUsesProxy: Bool = false
    static var loginSecret: String?
    static var dittoDisguises: [UInt16]?

    private static var limiter = LoginLimiter()

    private static let levelCacheLock = Threading.Lock()
    private static var levelCache = [String: Int]()

    private static let emptyCellsLock = Threading.Lock()
    private static var emptyCells = [UInt64: Int]()

    static let threadLimitMax = UInt32(ProcessInfo.processInfo.environment["RAW_THREAD_LIMIT"] ?? "") ?? 100
    private static let threadLimitLock = Threading.Lock()
    private static var threadLimitCount: UInt32 = 0
    private static var threadLimitTotalCount: UInt64 = 0
    private static var threadLimitIgnoredCount: UInt64 = 0

    private static let loginLimit = UInt32(ProcessInfo.processInfo.environment["LOGINLIMIT_COUNT"] ?? "")
    private static let loginLimitIntervall = UInt32(
        ProcessInfo.processInfo.environment["LOGINLIMIT_INTERVALL"] ?? ""
    ) ?? 300
    private static let loginLimitLock = Threading.Lock()
    private static var loginLimitTime = [String: UInt32]()
    private static var loginLimitCount = [String: UInt32]()

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

        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Failed to connect to database.")
            response.respondWithError(status: .internalServerError)
            return
        }

        let trainerLevel = json["trainerlvl"] as? Int ?? (json["trainerLevel"] as? String)?.toInt() ?? 0
        let trainerXP = json["trainerexp"] as? Int ?? 0
        let username = json["username"] as? String
        let controller = uuid != nil ? InstanceController.global.getInstanceController(deviceUUID: uuid!) : nil
        let isEvent = controller?.isEvent ?? false
        if username != nil && trainerLevel > 0 {
            levelCacheLock.lock()
            let oldLevel = levelCache[username!]
            levelCacheLock.unlock()
            if oldLevel != trainerLevel {
                do {
                    try Account.setLevel(mysql: mysql, username: username!, level: trainerLevel)
                    levelCacheLock.lock()
                    levelCache[username!] = trainerLevel
                    levelCacheLock.unlock()
                } catch {}
            }
        }

        if username != nil && trainerXP > 0 && trainerLevel > 0 {
            InstanceController.global.gotPlayerInfo(username: username!, level: trainerLevel, xp: trainerXP)
        }

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
        var clientWeathers =  [(cell: Int64, data: ClientWeatherProto)]()
        var forts = [(cell: UInt64, data: PokemonFortProto)]()
        var fortDetails = [FortDetailsOutProto]()
        var gymInfos = [GymGetInfoOutProto]()
        var quests = [QuestProto]()
        var fortSearch = [FortSearchOutProto]()
        var encounters = [EncounterOutProto]()
        var playerdatas = [GetPlayerOutProto]()
        var cells = [UInt64]()

        var isEmtpyGMO = true
        var isInvalidGMO = true
        var containsGMO = false

        for rawData in contents {

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
            } else if let fdr = rawData["FortDetailsResponse"] as? String {
                data = Data(base64Encoded: fdr) ?? Data()
                method = 104
            } else if let fsr = rawData["FortSearchResponse"] as? String {
                data = Data(base64Encoded: fsr) ?? Data()
                method = 101
            } else if let ggi = rawData["GymGetInfoResponse"] as? String {
                data = Data(base64Encoded: ggi) ?? Data()
                method = 156
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
                    Log.info(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Malformed GetPlayerResponse")
                }
            } else if method == 101 {
                if let fsr = try? FortSearchOutProto(serializedData: data) {
                    if fsr.hasChallengeQuest && fsr.challengeQuest.hasQuest {
                        let quest = fsr.challengeQuest.quest
                        quests.append(quest)
                    }
                    fortSearch.append(fsr)
                } else {
                    Log.info(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Malformed FortSearchResponse")
                }
            } else if method == 102 && trainerLevel >= 30 || method == 102 && isMadData == true {
                if let enr = try? EncounterOutProto(serializedData: data) {
                    encounters.append(enr)
                } else {
                    Log.info(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Malformed EncounterResponse")
                }
            } else if method == 104 {
                if let fdr = try? FortDetailsOutProto(serializedData: data) {
                    fortDetails.append(fdr)
                } else {
                    Log.info(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Malformed FortDetailsResponse")
                }
            } else if method == 156 {
                if let ggi = try? GymGetInfoOutProto(serializedData: data) {
                    gymInfos.append(ggi)
                } else {
                    Log.info(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Malformed GymGetInfoResponse")
                }
            } else if method == 106 {
                containsGMO = true
                if let gmo = try? GetMapObjectsOutProto(serializedData: data) {
                    isInvalidGMO = false

                    var newWildPokemons = [(cell: UInt64, data: WildPokemonProto,
                                            timestampMs: UInt64)]()
                    var newNearbyPokemons = [(cell: UInt64, data: NearbyPokemonProto)]()
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
                                Log.debug(
                                    message: "[WebHookRequestHandler] [\(uuid ?? "?")] Cell \(cell) was " +
                                             "empty 3 times in a row. Asuming empty."
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
                        forts += newForts
                        cells += newCells
                        clientWeathers += newClientWeathers
                    }
                } else {
                    Log.info(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Malformed GetMapObjectsResponse")
                }
            }
        }

        let targetCoord: CLLocationCoordinate2D?
        var inArea = false
        if latTarget != nil && lonTarget != nil {
            targetCoord = CLLocationCoordinate2D(latitude: latTarget!, longitude: lonTarget!)
        } else {
            targetCoord = nil
        }

        var pokemonCoords: CLLocationCoordinate2D?

        if targetCoord != nil {
            for fort in forts {
                InstanceController.global.gotFortData(fortData: fort.data, username: username)
                if !inArea {
                    let coord = CLLocationCoordinate2D(latitude: fort.data.latitude, longitude: fort.data.longitude)
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
                        let coord = CLLocationCoordinate2D(latitude: pokemon.data.latitude,
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
                            pokemonCoords = CLLocationCoordinate2D(latitude: pokemon.data.latitude,
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

        var data = ["nearby": nearbyPokemons.count, "wild": wildPokemons.count, "forts": forts.count,
                    "quests": quests.count, "encounters": encounters.count, "level": trainerLevel as Any,
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

        let listScatterPokemon = json["list_scatter_pokemon"] as? Bool ?? false
        if listScatterPokemon,
           pokemonCoords != nil,
           pokemonEncounterId != nil,
           let ivController = controller as? IVInstanceController {

            var scatterPokemon = [[String: Any]]()

            for pokemon in wildPokemons {
                // Don't return the main query in the scattershot list
                if pokemon.data.encounterID.description == pokemonEncounterId {
                    continue
                }

                let pokemonId = UInt16(pokemon.data.pokemon.pokemonID.rawValue)
                do {
                    let oldPokemon = try Pokemon.getWithId(
                        mysql: mysql,
                        id: pokemon.data.encounterID.description,
                        isEvent: isEvent
                    )
                    if oldPokemon != nil && oldPokemon!.atkIv != nil {
                        // Skip going to mons already with IVs.
                        continue
                    }
                } catch {}

                let coords = CLLocationCoordinate2D(latitude: pokemon.data
                    .latitude, longitude: pokemon.data.longitude)
                let distance = pokemonCoords!.distance(to: coords)

                // Only Encounter pokemon within 35m of initial pokemon scann
                if distance <= 35 && ivController.scatterPokemon.contains(pokemonId) {
                    scatterPokemon.append([
                        "lat": pokemon.data.latitude,
                        "lon": pokemon.data.longitude,
                        "id": pokemon.data.encounterID.description
                    ])
                }
            }

            data["scatter_pokemon"] = scatterPokemon
        }

        do {
            try response.respondWithData(data: data)
        } catch {
            response.respondWithError(status: .internalServerError)
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
                        account!.responseInfo(accountData: playerdata)
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
            if percentage >= 0.5 {
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
                try? cell.save(mysql: mysql, update: true)

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
                let pokemon = Pokemon(mysql: mysql, wildPokemon: wildPokemon.data, cellId: wildPokemon.cell,
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
                let pokemon = try? Pokemon(mysql: mysql, nearbyPokemon: nearbyPokemon.data,
                                           cellId: nearbyPokemon.cell, username: username, isEvent: isEvent)
                try? pokemon?.save(mysql: mysql)
            }
            if !nearbyPokemons.isEmpty {
                Log.debug(
                    message: "[WebHookRequestHandler] [\(uuid ?? "?")] NearbyPokemon Count: \(nearbyPokemons.count) " +
                             "parsed in \(String(format: "%.3f", Date().timeIntervalSince(startPokemon)))s"
                )
            }

            let startForts = Date()
            for fort in forts {
                if fort.data.fortType == .gym {
                    let gym = Gym(fortData: fort.data, cellId: fort.cell)
                    try? gym.save(mysql: mysql)
                    if gymIdsPerCell[fort.cell] == nil {
                        gymIdsPerCell[fort.cell] = [String]()
                    }
                    gymIdsPerCell[fort.cell]!.append(fort.data.fortID)
                } else if fort.data.fortType == .checkpoint {
                    let pokestop = Pokestop(fortData: fort.data, cellId: fort.cell)
                    try? pokestop.save(mysql: mysql)
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
                            gym = try Gym.getWithId(mysql: mysql, id: fort.id)
                        } catch {
                            gym = nil
                        }
                        if gym != nil {
                            gym!.addDetails(fortData: fort)
                            try? gym!.save(mysql: mysql)
                        }
                    } else if fort.fortType == .checkpoint {
                        let pokestop: Pokestop?
                        do {
                            pokestop = try Pokestop.getWithId(mysql: mysql, id: fort.id)
                        } catch {
                            pokestop = nil
                        }
                        if pokestop != nil {
                            pokestop!.addDetails(fortData: fort)
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
                        gym = try Gym.getWithId(mysql: mysql, id: gymInfo.gymStatusAndDefenders.pokemonFortProto.fortID)
                    } catch {
                        gym = nil
                    }
                    if gym != nil {
                        gym!.addDetails(gymInfo: gymInfo)
                        try? gym!.save(mysql: mysql)
                    }
                }
                Log.debug(
                    message: "[WebHookRequestHandler] [\(uuid ?? "?")] Forts Detail Count: \(fortDetails.count) " +
                             "parsed in \(String(format: "%.3f", Date().timeIntervalSince(start)))s"
                )
            }

            if !quests.isEmpty {
                let start = Date()
                for quest in quests {
                    let pokestop: Pokestop?
                    do {
                        pokestop = try Pokestop.getWithId(mysql: mysql, id: quest.fortID)
                    } catch {
                        pokestop = nil
                    }
                    if pokestop != nil {
                        pokestop!.addQuest(questData: quest)
                        try? pokestop!.save(mysql: mysql, updateQuest: true)
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
                    let pokemon: Pokemon?
                    do {
                        pokemon = try Pokemon.getWithId(
                            mysql: mysql,
                            id: encounter.pokemon.encounterID.description,
                            isEvent: isEvent
                        )
                    } catch {
                        pokemon = nil
                    }
                    if pokemon != nil {
                        pokemon!.addEncounter(mysql: mysql, encounterData: encounter, username: username)
                        try? pokemon!.save(mysql: mysql, updateIV: true)
                    } else {
                        let centerCoord = CLLocationCoordinate2D(latitude: encounter.pokemon.latitude,
                                                                 longitude: encounter.pokemon.longitude)
                        let cellID = S2CellId(latlng: S2LatLng(coord: centerCoord)).parent(level: 15)
                        let newPokemon = Pokemon(
                            wildPokemon: encounter.pokemon,
                            cellId: cellID.uid,
                            timestampMs: UInt64(Date().timeIntervalSince1970 * 1000),
                            username: username,
                            isEvent: isEvent
                        )
                        newPokemon.addEncounter(mysql: mysql, encounterData: encounter, username: username)
                        try? newPokemon.save(mysql: mysql, updateIV: true)
                    }
                }
                Log.debug(
                    message: "[WebHookRequestHandler] [\(uuid ?? "?")] Encounter Count: \(encounters.count) " +
                             "parsed in \(String(format: "%.3f", Date().timeIntervalSince(start)))s"
                )
            }

            if enableClearing {
                for gymId in gymIdsPerCell {
                    if let cleared = try? Gym.clearOld(mysql: mysql, ids: gymId.value, cellId: gymId.key),
                       cleared != 0 {
                        Log.info(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Cleared \(cleared) old Gyms.")
                    }
                }
                for stopId in stopsIdsPerCell {
                    if let cleared = try? Pokestop.clearOld(mysql: mysql, ids: stopId.value, cellId: stopId.key),
                       cleared != 0 {
                        Log.info(message: "[WebHookRequestHandler] [\(uuid ?? "?")] Cleared \(cleared) old Pokestops.")
                    }
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
                            Log.debug(
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
                    let task = controller!.getTask(mysql: mysql, uuid: uuid, username: username, account: account)
                    Log.debug(
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

                if username != account!.username, let loginLimit = self.loginLimit {
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
                Log.debug(message: "[WebHookRequestHandler] [\(uuid)] Account banned: \(username)")
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
                Log.debug(message: "[WebHookRequestHandler] [\(uuid)] Account suspended: \(username)")
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
                if account.firstWarningTimestamp == nil {
                    account.firstWarningTimestamp = UInt32(Date().timeIntervalSince1970)
                    try account.save(mysql: mysql, update: true)
                }
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
                }
                response.respondWithOk()
            } catch {
                response.respondWithError(status: .internalServerError)
            }
        } else if type == "error_26" {
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
                    account.failed = "error_26"
                    try account.save(mysql: mysql, update: true)
                }
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
            Log.debug(message: "[WebHookRequestHandler] [\(uuid)] Unhandled Request: \(type)")
            response.respondWithError(status: .badRequest)
        }

    }

}
