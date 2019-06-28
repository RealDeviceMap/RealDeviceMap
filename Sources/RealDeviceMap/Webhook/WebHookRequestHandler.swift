//
//  ApiRequestHandler.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//

import Foundation
import PerfectLib
import PerfectHTTP
import PerfectMustache
import PerfectSession
import PerfectThread
import Foundation
import SwiftProtobuf
import POGOProtos
import Turf
import S2Geometry

class WebHookRequestHandler {
    
    static var enableClearing = false
    
    private static var levelCacheLock = Threading.Lock()
    private static var levelCache = [String: Int]()
    
    private static var emptyCellsLock = Threading.Lock()
    private static var emptyCells = [UInt64: Int]()
        
    static func handle(request: HTTPRequest, response: HTTPResponse, type: WebHookServer.Action) {
        
        switch type {
        case .controler:
            controlerHandler(request: request, response: response)
        case .raw:
            rawHandler(request: request, response: response)
        }
        
    }
    
    static func rawHandler(request: HTTPRequest, response: HTTPResponse) {
        
        let json: [String: Any]
        do {
            guard let jsonOpt = try (request.postBodyString ?? "").jsonDecode() as? [String : Any] else {
                response.respondWithError(status: .badRequest)
                return
            }
            json = jsonOpt
        } catch {
            response.respondWithError(status: .badRequest)
            return
        }
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[WebHookRequestHandler] Failed to connect to database.")
            response.respondWithError(status: .internalServerError)
            return
        }
        
        let trainerLevel = json["trainerlvl"] as? Int ?? (json["trainerLevel"] as? String)?.toInt() ?? 0
        if let username = json["username"] as? String, trainerLevel > 0 {
            levelCacheLock.lock()
            let oldLevel = levelCache[username]
            levelCacheLock.unlock()
            if oldLevel != trainerLevel {
                do {
                    try Account.setLevel(mysql: mysql, username: username, level: trainerLevel)
                    levelCacheLock.lock()
                    levelCache[username] = trainerLevel
                    levelCacheLock.unlock()
                } catch {}
            }
        }
        
        guard let contents = json["contents"] as? [[String: Any]] ?? json["protos"] as? [[String: Any]] ?? json["gmo"] as? [[String: Any]] else {
            response.respondWithError(status: .badRequest)
            return
        }
    
        let latTarget = json["lat_target"] as? Double
        let lonTarget = json["lon_target"] as? Double
        let pokemonEncounterId = json["pokemon_encounter_id"] as? String
        let pokemonEncounterIdForEncounter = json["pokemon_encounter_id_for_encounter"] as? String
        let targetMaxDistance = json["target_max_distnace"] as? Double ?? 250
        
        var wildPokemons = [(cell: UInt64, data: POGOProtos_Map_Pokemon_WildPokemon, timestampMs: UInt64)]()
        var nearbyPokemons = [(cell: UInt64, data: POGOProtos_Map_Pokemon_NearbyPokemon)]()
        var forts = [(cell: UInt64, data: POGOProtos_Map_Fort_FortData)]()
        var fortDetails = [POGOProtos_Networking_Responses_FortDetailsResponse]()
        var gymInfos = [POGOProtos_Networking_Responses_GymGetInfoResponse]()
        var quests = [POGOProtos_Data_Quests_Quest]()
        var encounters = [POGOProtos_Networking_Responses_EncounterResponse]()
        var cells = [UInt64]()
        
        var isEmtpyGMO = true
        var isInvalidGMO = true
        var containsGMO = false

        for rawData in contents {
            
            let data: Data
            let method: Int
            if let gmo = rawData["GetMapObjects"] as? String {
                data = Data(base64Encoded: gmo) ?? Data()
                method = 106
            } else if let er = rawData["EncounterResponse"] as? String {
                data = Data(base64Encoded: er) ?? Data()
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
            } else if let dataString = rawData["data"] as? String ?? rawData["payload"] as? String {
                data = Data(base64Encoded: dataString) ?? Data()
                method = rawData["method"] as? Int ?? rawData["type"] as? Int ?? 106
            } else {
                continue
            }
            
            if method == 101 {
                if let fsr = try? POGOProtos_Networking_Responses_FortSearchResponse(serializedData: data) {
                    if fsr.hasChallengeQuest && fsr.challengeQuest.hasQuest {
                        let quest = fsr.challengeQuest.quest
                        quests.append(quest)
                    }
                } else {
                    Log.info(message: "[WebHookRequestHandler] Malformed FortSearchResponse")
                }
            } else if method == 102 && trainerLevel >= 30 {
                if let er = try? POGOProtos_Networking_Responses_EncounterResponse(serializedData: data) {
                    encounters.append(er)
                } else {
                    Log.info(message: "[WebHookRequestHandler] Malformed EncounterResponse")
                }
            } else if method == 104 {
                if let fdr = try? POGOProtos_Networking_Responses_FortDetailsResponse(serializedData: data) {
                    fortDetails.append(fdr)
                } else {
                    Log.info(message: "[WebHookRequestHandler] Malformed FortDetailsResponse")
                }
            } else if method == 156 {
                if let ggi = try? POGOProtos_Networking_Responses_GymGetInfoResponse(serializedData: data) {
                    gymInfos.append(ggi)
                } else {
                    Log.info(message: "[WebHookRequestHandler] Malformed GymGetInfoResponse")
                }
            } else if method == 106 {
                containsGMO = true
                if let gmo = try? POGOProtos_Networking_Responses_GetMapObjectsResponse(serializedData: data) {
                    isInvalidGMO = false
                    
                    var newWildPokemons = [(cell: UInt64, data: POGOProtos_Map_Pokemon_WildPokemon, timestampMs: UInt64)]()
                    var newNearbyPokemons = [(cell: UInt64, data: POGOProtos_Map_Pokemon_NearbyPokemon)]()
                    var newForts = [(cell: UInt64, data: POGOProtos_Map_Fort_FortData)]()
                    var newCells = [UInt64]()
                    
                    for mapCell in gmo.mapCells {
                        let timestampMs = UInt64(mapCell.currentTimestampMs)
                        for wildPokemon in mapCell.wildPokemons {
                            newWildPokemons.append((cell: mapCell.s2CellID, data: wildPokemon, timestampMs: timestampMs))
                        }
                        for nearbyPokemon in mapCell.nearbyPokemons {
                            newNearbyPokemons.append((cell: mapCell.s2CellID, data: nearbyPokemon))
                        }
                        for fort in mapCell.forts {
                            newForts.append((cell: mapCell.s2CellID, data: fort))
                        }
                        newCells.append(mapCell.s2CellID)
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
                                Log.debug(message: "[WebHookRequestHandler] Cell \(cell) was empty 3 times in a row. Asuming empty.")
                                cells.append(cell)
                            }
                        }
                        
                        Log.info(message: "[WebHookRequestHandler] GMO is empty.")
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
                    }
                } else {
                    Log.info(message: "[WebHookRequestHandler] Malformed GetMapObjectsResponse")
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
                if !inArea {
                    let coord = CLLocationCoordinate2D(latitude: fort.data.latitude, longitude: fort.data.longitude)
                    if coord.distance(to: targetCoord!) <= targetMaxDistance {
                        inArea = true
                    }
                } else {
                    break
                }
            }
        }
        if targetCoord != nil || pokemonEncounterId != nil {
            for pokemon in wildPokemons {
                if targetCoord != nil {
                    if !inArea {
                        let coord = CLLocationCoordinate2D(latitude: pokemon.data.latitude, longitude: pokemon.data.longitude)
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
                            pokemonCoords = CLLocationCoordinate2D(latitude: pokemon.data.latitude, longitude: pokemon.data.longitude)
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
        
        var data = ["nearby": nearbyPokemons.count, "wild": wildPokemons.count, "forts": forts.count, "quests": quests.count, "encounters": encounters.count, "level": trainerLevel as Any, "only_empty_gmos": containsGMO && isEmtpyGMO, "only_invalid_gmos": containsGMO && isInvalidGMO, "contains_gmos": containsGMO]

        if pokemonEncounterIdForEncounter != nil {
            //If the UIC sets pokemon_encounter_id_for_encounter,
            //only return encounters != 0 if we actually encounter that target.
            //"Guaranteed scan"
            data["encounters"] = 0;
            for encounter in encounters {
                if (encounter.wildPokemon.encounterID.description == pokemonEncounterIdForEncounter){
                    //We actually encountered the target.
                    data["encounters"] = 1;
                }
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
           let uuid = json["uuid"] as? String,
           let controller = InstanceController.global.getInstanceController(deviceUUID: uuid) as? IVInstanceController {
           
            var scatterPokemon = [[String: Any]]()
            
            for pokemon in wildPokemons {
                //Don't return the main query in the scattershot list
                if pokemon.data.encounterID.description == pokemonEncounterId {
                    continue
                }
                
                let pokemonId = UInt16(pokemon.data.pokemonData.pokemonID.rawValue)
                do {
                    let oldPokemon = try Pokemon.getWithId(mysql: mysql, id: pokemon.data.encounterID.description)
                    if (oldPokemon != nil && oldPokemon!.atkIv != nil) {
                        //Skip going to mons already with IVs.
                        continue
                    }
                } catch {}
                
                let coords = CLLocationCoordinate2D(latitude: pokemon.data
                    .latitude, longitude: pokemon.data.longitude)
                let distance = pokemonCoords!.distance(to: coords)
                
                // Only Encounter pokemon within 35m of initial pokemon scann
                if distance <= 35 && controller.scatterPokemon.contains(pokemonId) {
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
            
            let startWildPokemon = Date()
            for wildPokemon in wildPokemons {
                let pokemon = Pokemon(mysql: mysql, wildPokemon: wildPokemon.data, cellId: wildPokemon.cell, timestampMs: wildPokemon.timestampMs)
                try? pokemon.save(mysql: mysql)
            }
            Log.debug(message: "[WebHookRequestHandler] Pokemon Count: \(wildPokemons.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(startWildPokemon)))s")
            
            let startPokemon = Date()
            for nearbyPokemon in nearbyPokemons {
                let pokemon = try? Pokemon(mysql: mysql, nearbyPokemon: nearbyPokemon.data, cellId: nearbyPokemon.cell)
                try? pokemon?.save(mysql: mysql)
            }
            Log.debug(message: "[WebHookRequestHandler] NearbyPokemon Count: \(nearbyPokemons.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(startPokemon)))s")

            let startForts = Date()
            for fort in forts {
                if fort.data.type == .gym {
                    let gym = Gym(fortData: fort.data, cellId: fort.cell)
                    try? gym.save(mysql: mysql)
                    if gymIdsPerCell[fort.cell] == nil {
                        gymIdsPerCell[fort.cell] = [String]()
                    }
                    gymIdsPerCell[fort.cell]!.append(fort.data.id)
                } else if fort.data.type == .checkpoint {
                    let pokestop = Pokestop(fortData: fort.data, cellId: fort.cell)
                    try? pokestop.save(mysql: mysql)
                    if stopsIdsPerCell[fort.cell] == nil {
                        stopsIdsPerCell[fort.cell] = [String]()
                    }
                    stopsIdsPerCell[fort.cell]!.append(fort.data.id)
                }
            }
            Log.debug(message: "[WebHookRequestHandler] Forts Count: \(forts.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(startForts)))s")
            
            if !fortDetails.isEmpty {
                let start = Date()
                for fort in fortDetails {
                    if fort.type == .gym {
                        let gym: Gym?
                        do {
                            gym = try Gym.getWithId(mysql: mysql, id: fort.fortID)
                        } catch {
                            gym = nil
                        }
                        if gym != nil {
                            gym!.addDetails(fortData: fort)
                            try? gym!.save(mysql: mysql)
                        }
                    } else if fort.type == .checkpoint {
                        let pokestop: Pokestop?
                        do {
                            pokestop = try Pokestop.getWithId(mysql: mysql, id: fort.fortID)
                        } catch {
                            pokestop = nil
                        }
                        if pokestop != nil {
                            pokestop!.addDetails(fortData: fort)
                            try? pokestop!.save(mysql: mysql)
                        }
                    }
                }
                Log.debug(message: "[WebHookRequestHandler] Forts Detail Count: \(fortDetails.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(start)))s")
            }
            
            if !gymInfos.isEmpty {
                let start = Date()
                for gymInfo in gymInfos {
                    let gym: Gym?
                    do {
                        gym = try Gym.getWithId(mysql: mysql, id: gymInfo.gymStatusAndDefenders.pokemonFortProto.id)
                    } catch {
                        gym = nil
                    }
                    if gym != nil {
                        gym!.addDetails(gymInfo: gymInfo)
                        try? gym!.save(mysql: mysql)
                    }
                }
                Log.debug(message: "[WebHookRequestHandler] Forts Detail Count: \(fortDetails.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(start)))s")
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
                Log.debug(message: "[WebHookRequestHandler] Quest Count: \(quests.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(start)))s")
            }
            
            if !encounters.isEmpty {
                let start = Date()
                for encounter in encounters {
                    let pokemon: Pokemon?
                    do {
                        pokemon = try Pokemon.getWithId(mysql: mysql, id: encounter.wildPokemon.encounterID.description)
                    } catch {
                        pokemon = nil
                    }
                    if pokemon != nil {
                        pokemon!.addEncounter(encounterData: encounter)
                        try? pokemon!.save(mysql: mysql, updateIV: true)
                    } else {
                        let centerCoord = CLLocationCoordinate2D(latitude: encounter.wildPokemon.latitude, longitude: encounter.wildPokemon.longitude)
                        let center = S2LatLng(coord: centerCoord)
                        let centerNormalizedPoint = center.normalized.point
                        let circle = S2Cap(axis: centerNormalizedPoint, height: 0.0)
                        let coverer = S2RegionCoverer()
                        coverer.maxCells = 1
                        coverer.maxLevel = 15
                        coverer.minLevel = 15
                        let cellIDs = coverer.getCovering(region: circle)
                        if let cellID = cellIDs.first {
                            let newPokemon = Pokemon(
                                wildPokemon: encounter.wildPokemon,
                                cellId: cellID.uid,
                                timestampMs: UInt64(Date().timeIntervalSince1970 * 1000))
                            newPokemon.addEncounter(encounterData: encounter)
                            try? newPokemon.save(mysql: mysql, updateIV: true)
                        }
                    }
                }
                Log.debug(message: "[WebHookRequestHandler] Encounter Count: \(encounters.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(start)))s")
            }
            
            if enableClearing {
                for gymId in gymIdsPerCell {
                    if let cleared = try? Gym.clearOld(mysql: mysql, ids: gymId.value, cellId: gymId.key), cleared != 0 {
                        Log.info(message: "[WebHookRequestHandler] Cleared \(cleared) old Gyms.")
                    }
                }
                for stopId in stopsIdsPerCell {
                    if let cleared = try? Pokestop.clearOld(mysql: mysql, ids: stopId.value, cellId: stopId.key), cleared != 0 {
                        Log.info(message: "[WebHookRequestHandler] Cleared \(cleared) old Pokestops.")
                    }
                }
            }
            
            Threading.destroyQueue(queue)
        }
        
    }

    static func controlerHandler(request: HTTPRequest, response: HTTPResponse) {
        
        let jsonO: [String: Any]?
        let typeO: String?
        let uuidO: String?
        do {
            jsonO = try request.postBodyString?.jsonDecode() as? [String: Any]
            typeO = jsonO?["type"] as? String
            uuidO = jsonO?["uuid"] as? String
        } catch {
            response.respondWithError(status: .badRequest)
            return
        }
        
        guard let type = typeO, let uuid = uuidO else {
            response.respondWithError(status: .badRequest)
            return
        }
                
        let username = jsonO?["username"] as? String
        let minLevel = jsonO?["min_level"] as? Int ?? 0
        let maxLevel = jsonO?["max_level"] as? Int ?? 29

        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[WebHookRequestHandler] Failed to connect to database.")
            response.respondWithError(status: .internalServerError)
            return
        }
        
        if type == "init" {
            do {
                let device = try Device.getById(mysql: mysql, id: uuid)
                let firstWarningTimestamp: UInt32?
                if device == nil || device!.accountUsername == nil {
                    firstWarningTimestamp = nil
                } else {
                    let account = try Account.getWithUsername(mysql: mysql, username: device!.accountUsername!)
                    if account != nil {
                        firstWarningTimestamp = account!.firstWarningTimestamp
                    } else {
                        firstWarningTimestamp = nil
                    }
                }
                
                if device == nil {
                    let newDevice = Device(uuid: uuid, instanceName: nil, lastHost: nil, lastSeen: 0, accountUsername: nil)
                    try newDevice.create(mysql: mysql)
                    try response.respondWithData(data: ["assigned": false, "first_warning_timestamp": firstWarningTimestamp as Any])
                } else {
                    if device!.instanceName == nil {
                        try response.respondWithData(data: ["assigned": false, "first_warning_timestamp": firstWarningTimestamp as Any])
                    } else {
                        try response.respondWithData(data: ["assigned": true, "first_warning_timestamp": firstWarningTimestamp as Any])
                    }
                }
            } catch {
                response.respondWithError(status: .internalServerError)
            }
        } else if type == "heartbeat" {
            let now = Int(Date().timeIntervalSince1970)
            let host: String
            if let remoteAddress = request.connection.remoteAddress {
                host = remoteAddress.host + ":" + remoteAddress.port.description
            } else {
                host = "?"
            }
            do {
                try Device.touch(mysql: mysql, uuid: uuid, host: host, seen: now)
                response.respondWithOk()
            } catch {
                response.respondWithError(status: .internalServerError)
            }
        } else if type == "get_job" {
            let controller = InstanceController.global.getInstanceController(deviceUUID: uuid)
            if controller != nil {
                do {
                    try response.respondWithData(data: controller!.getTask(uuid: uuid, username: username))
                } catch {
                    response.respondWithError(status: .internalServerError)
                }
            } else {
                response.respondWithError(status: .notFound)
            }
        } else if type == "get_account" {
            
            do {
                guard
                    let device = try Device.getById(mysql: mysql, id: uuid),
                    let account = try Account.getNewAccount(mysql: mysql, minLevel: minLevel, maxLevel: maxLevel)
                    else {
                        response.respondWithError(status: .notFound)
                        return
                }
                if device.accountUsername != nil {
                    do {
                        let oldAccount = try Account.getWithUsername(mysql: mysql, username: device.accountUsername!)
                        if oldAccount != nil && oldAccount!.firstWarningTimestamp == nil && oldAccount!.failed == nil && oldAccount!.failedTimestamp == nil {
                            try response.respondWithData(data: ["username": oldAccount!.username, "password": oldAccount!.password, "first_warning_timestamp": oldAccount!.firstWarningTimestamp as Any, "level": oldAccount!.level])
                            return
                        }
                    } catch { }
                }
                
                device.accountUsername = account.username
                try device.save(mysql: mysql, oldUUID: device.uuid)
                try response.respondWithData(data: ["username": account.username, "password": account.password, "first_warning_timestamp": account.firstWarningTimestamp as Any])
            
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
                    let device = try Device.getById(mysql: mysql, id: uuid),
                    let username = device.accountUsername,
                    let account = try Account.getWithUsername(mysql: mysql, username: username)
                else {
                    response.respondWithError(status: .internalServerError)
                    return
                }
                if account.failedTimestamp == nil || account.failed == nil {
                    account.failedTimestamp = UInt32(Date().timeIntervalSince1970)
                    account.failed = "banned"
                    try account.save(mysql: mysql, update: true)
                }
                response.respondWithOk()
            } catch {
                response.respondWithError(status: .internalServerError)
            }
        } else if type == "account_warning" {
            do {
                guard
                    let device = try Device.getById(mysql: mysql, id: uuid),
                    let username = device.accountUsername,
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
            Log.debug(message: "[WebHookRequestHandler] Unhandled Request: \(type)")
            response.respondWithError(status: .badRequest)
        }
        
    }
    
}
