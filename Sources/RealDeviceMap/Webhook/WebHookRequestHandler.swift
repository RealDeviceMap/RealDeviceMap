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

class WebHookRequestHandler {
    
    static var levelCacheLock = Threading.Lock()
    static var levelCache = [String: Int]()
        
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
        
        let trainerLevel: Int
        if let username = json["username"] as? String, let level = json["trainerlvl"] as? Int ?? (json["trainerLevel"] as? String)?.toInt() {
            trainerLevel = level
            levelCacheLock.lock()
            let oldLevel = levelCache[username]
            levelCacheLock.unlock()
            if oldLevel != level {
                do {
                    try Account.setLevel(mysql: mysql, username: username, level: level)
                    levelCacheLock.lock()
                    levelCache[username] = level
                    levelCacheLock.unlock()
                } catch {}
            }
        } else {
            trainerLevel = 0
        }
        
        guard let contents = json["contents"] as? [[String: Any]] ?? json["protos"] as? [[String: Any]] ?? json["gmo"] as? [[String: Any]] else {
            response.respondWithError(status: .badRequest)
            return
        }
    
        let latTarget = json["lat_target"] as? Double
        let lonTarget = json["lon_target"] as? Double
        let pokemonEncounterId = json["pokemon_encounter_id"] as? String
        let targetMaxDistance = json["target_max_distnace"] as? Double ?? 250
        
        var wildPokemons = [POGOProtos_Map_Pokemon_WildPokemon]()
        var nearbyPokemons = [POGOProtos_Map_Pokemon_NearbyPokemon]()
        var forts = [POGOProtos_Map_Fort_FortData]()
        var fortDetails = [POGOProtos_Networking_Responses_FortDetailsResponse]()
        var quests = [POGOProtos_Data_Quests_Quest]()
        var encounters = [POGOProtos_Networking_Responses_EncounterResponse]()

        for rawData in contents {
            
            let data: Data
            let method: Int
            if let gmo = rawData["GetMapObjects"] as? String {
                data = Data(base64Encoded: gmo) ?? Data()
                method = 106
            } else if trainerLevel >= 30, let er = rawData["EncounterResponse"] as? String {
                data = Data(base64Encoded: er) ?? Data()
                method = 102
            } else if let fdr = rawData["FortDetailsResponse"] as? String {
                data = Data(base64Encoded: fdr) ?? Data()
                method = 104
            } else if let fsr = rawData["FortSearchResponse"] as? String {
                data = Data(base64Encoded: fsr) ?? Data()
                method = 101
            } else if let dataString = rawData["data"] as? String {
                data = Data(base64Encoded: dataString) ?? Data()
                method = rawData["method"] as? Int ?? 106
            } else {
                continue
            }
            
            if method == 101 {
                if let fsr = try? POGOProtos_Networking_Responses_FortSearchResponse(serializedData: data) {
                    if fsr.hasChallengeQuest && fsr.challengeQuest.hasQuest {
                        let quest = fsr.challengeQuest.quest
                        quests.append(quest)
                    }
                }
            } else if method == 102 {
                if let er = try? POGOProtos_Networking_Responses_EncounterResponse(serializedData: data) {
                    encounters.append(er)
                }
            } else if method == 104 {
                if let fdr = try? POGOProtos_Networking_Responses_FortDetailsResponse(serializedData: data) {
                    fortDetails.append(fdr)
                }
            } else if method == 106 {
                if let gmo = try? POGOProtos_Networking_Responses_GetMapObjectsResponse(serializedData: data) {
                    for mapCell in gmo.mapCells {
                        wildPokemons += mapCell.wildPokemons
                        nearbyPokemons += mapCell.nearbyPokemons
                        forts += mapCell.forts
                    }
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
                    let coord = CLLocationCoordinate2D(latitude: fort.latitude, longitude: fort.longitude)
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
                        let coord = CLLocationCoordinate2D(latitude: pokemon.latitude, longitude: pokemon.longitude)
                        if coord.distance(to: targetCoord!) <= targetMaxDistance {
                            inArea = true
                        }
                    } else if pokemonEncounterId == nil || pokemonCoords != nil {
                        break
                    }
                }
                if pokemonEncounterId != nil {
                    if pokemonCoords == nil {
                        if pokemon.encounterID.description == pokemonEncounterId {
                            pokemonCoords = CLLocationCoordinate2D(latitude: pokemon.latitude, longitude: pokemon.longitude)
                        }
                    } else if targetCoord == nil || inArea {
                        break
                    }
                }
            }
        }
        
        var data = ["nearby": nearbyPokemons.count, "wild": wildPokemons.count, "forts": forts.count, "quests": quests.count, "encounters": encounters.count, "level": trainerLevel as Any]
        
        if targetCoord != nil {
            data["in_area"] = inArea
        }
        if pokemonCoords != nil {
            data["pokemon_lat"] = pokemonCoords!.latitude
            data["pokemon_lon"] = pokemonCoords!.longitude
            data["pokemon_encounter_id"] = pokemonEncounterId!
        }
        
        do {
            try response.respondWithData(data: data)
        } catch {
            response.respondWithError(status: .internalServerError)
        }
        
        let queue = Threading.getQueue(name: Foundation.UUID().uuidString, type: .serial)
        queue.dispatch {
            
            let startWildPokemon = Date()
            for wildPokemon in wildPokemons {
                let pokemon = Pokemon(wildPokemon: wildPokemon)
                try? pokemon.save(mysql: mysql)
            }
            Log.info(message: "[WebHookRequestHandler] Pokemon Count: \(wildPokemons.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(startWildPokemon)))s")
            
            let startPokemon = Date()
            for nearbyPokemon in nearbyPokemons {
                let pokemon = try? Pokemon(mysql: mysql, nearbyPokemon: nearbyPokemon)
                try? pokemon?.save(mysql: mysql)
            }
            Log.info(message: "[WebHookRequestHandler] NearbyPokemon Count: \(nearbyPokemons.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(startPokemon)))s")

            let startForts = Date()
            for fort in forts {
                if fort.type == .gym {
                    let gym = Gym(fortData: fort)
                    try? gym.save(mysql: mysql)
                } else if fort.type == .checkpoint {
                    let pokestop = Pokestop(fortData: fort)
                    try? pokestop.save(mysql: mysql)
                }
            }
            Log.info(message: "[WebHookRequestHandler] Forts Count: \(forts.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(startForts)))s")
            
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
                Log.info(message: "[WebHookRequestHandler] Forts Detail Count: \(fortDetails.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(start)))s")
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
                        try? pokestop!.save(mysql: mysql)
                    }
                }
                Log.info(message: "[WebHookRequestHandler] Quest Count: \(quests.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(start)))s")
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
                        try? pokemon!.save(mysql: mysql)
                    }
                }
                Log.info(message: "[WebHookRequestHandler] Encounter Count: \(encounters.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(start)))s")
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
                try! response.respondWithData(data: controller!.getTask(uuid: uuid, username: username))
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
            Log.info(message: "[WebHookRequestHandler] Unhandled Request: \(type)")
            response.respondWithError(status: .badRequest)
        }
        
    }
    
}
