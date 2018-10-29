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
    
    static func handle(request: HTTPRequest, response: HTTPResponse, type: WebHookServer.Action) {
        
        switch type {
        case .json:
            jsonHandler(request: request, response: response)
        case .controler:
            controlerHandler(request: request, response: response)
        case .raw:
            rawHandler(request: request, response: response)
        }
        
    }
    
    static func jsonHandler(request: HTTPRequest, response: HTTPResponse) {
        
        let json: [String: Any]
        do {
            json = try (request.postBodyString ?? "").jsonDecode() as! [String : Any]
        } catch {
            response.respondWithError(status: .badRequest)
            return
        }
        
        let latTarget = json["lat_target"] as? Double ?? 0.0
        let lonTarget = json["lon_target"] as? Double ?? 0.0
        let targetMaxDistance = json["target_max_distnace"] as? Double ?? 250
        let targetCoord = CLLocationCoordinate2D(latitude: latTarget, longitude: lonTarget)
        var inArea = false
        
        var gyms = [Gym]()
        if let gymsData = json["gyms"] as? [[String: Any]] {
            for gymData in gymsData {
                guard let gym = try? Gym(json: gymData) else {
                    //Log.warning(message: "[WebHookRequestHandler] Failed to Parse Gym")
                    continue
                }
                if !inArea {
                    let coord = CLLocationCoordinate2D(latitude: gym.lat, longitude: gym.lon)
                    if coord.distance(to: targetCoord) <= targetMaxDistance {
                        inArea = true
                    }
                }
                gyms.append(gym)
            }
        }
        var pokestops = [Pokestop]()
        if let pokestopsData = json["pokestops"] as? [[String: Any]] {
            for pokestopData in pokestopsData {
                guard let pokestop = try? Pokestop(json: pokestopData) else {
                    //Log.warning(message: "[WebHookRequestHandler] Failed to Parse Pokestop")
                    continue
                }
                if !inArea {
                    let coord = CLLocationCoordinate2D(latitude: pokestop.lat, longitude: pokestop.lon)
                    if coord.distance(to: targetCoord) <= targetMaxDistance {
                        inArea = true
                    }
                }
                pokestops.append(pokestop)
            }
        }
        var wildPokemons = [Pokemon]()
        if let pokemonsData = json["pokemon"] as? [[String: Any]] {
            for pokemonData in pokemonsData {
                guard let pokemon = try? Pokemon(json: pokemonData) else {
                    //Log.warning(message: "[WebHookRequestHandler] Failed to Parse Pokemon")
                    continue
                }
                if !inArea {
                    let coord = CLLocationCoordinate2D(latitude: pokemon.lat, longitude: pokemon.lon)
                    if coord.distance(to: targetCoord) <= targetMaxDistance {
                        inArea = true
                    }
                }
                wildPokemons.append(pokemon)
            }
        }
        
        do {
            try response.respondWithData(data: ["nearby": (json["nearby_pokemon"] as? [[String: Any]] ?? [[String: Any]]()).count, "wild": wildPokemons.count, "forts": pokestops.count + gyms.count, "in_area": inArea])
        } catch {
            response.respondWithError(status: .internalServerError)
        }
        
        let queue = Threading.getQueue(name: Foundation.UUID().uuidString, type: .serial)
        queue.dispatch {
            
            var nearbyPokemons = [Pokemon]()
            if let nearbyPokemonsData = json["nearby_pokemon"] as? [[String: Any]] {
                for pokemonData in nearbyPokemonsData {
                    guard let pokemon = try? Pokemon(json: pokemonData) else {
                        //Log.warning(message: "[WebHookRequestHandler] Failed to Parse Nearby Pokemon")
                        continue
                    }
                    nearbyPokemons.append(pokemon)
                }
            }
        
            let startWildPokemon = Date()
            for wildPokemon in wildPokemons {
                try? wildPokemon.save()
            }
            Log.info(message: "[WebHookRequestHandler] Pokemon Count: \(wildPokemons.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(startWildPokemon)))s")
            
            let startPokemon = Date()
            for nearbyPokemon in nearbyPokemons {
                try? nearbyPokemon.save()
            }
            Log.info(message: "[WebHookRequestHandler] NearbyPokemon Count: \(nearbyPokemons.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(startPokemon)))s")
            
            let startGym = Date()
            for gym in gyms {
                try? gym.save()
            }
            Log.info(message: "[WebHookRequestHandler] Gym Count: \(gyms.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(startGym)))s")
            
            let startPokestop = Date()
            for pokestop in pokestops {
                try? pokestop.save()
            }
            Log.info(message: "[WebHookRequestHandler] Pokestop Count: \(nearbyPokemons.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(startPokestop)))s")
            
            Threading.destroyQueue(queue)
        }
        
    }
    
    static func rawHandler(request: HTTPRequest, response: HTTPResponse) {
        
        let json: [String: Any]
        do {
            json = try (request.postBodyString ?? "").jsonDecode() as! [String : Any]
        } catch {
            response.respondWithError(status: .badRequest)
            return
        }
        
        let contents = json["contents"] as! [[String: Any]]
        
        let latTarget = json["lat_target"] as? Double ?? 0.0
        let lonTarget = json["lon_target"] as? Double ?? 0.0
        let targetMaxDistance = json["target_max_distnace"] as? Double ?? 250
        let targetCoord = CLLocationCoordinate2D(latitude: latTarget, longitude: lonTarget)
        var inArea = false
        
        var wildPokemons = [POGOProtos_Map_Pokemon_WildPokemon]()
        var nearbyPokemons = [POGOProtos_Map_Pokemon_NearbyPokemon]()
        var forts = [POGOProtos_Map_Fort_FortData]()
        var fortDetails = [POGOProtos_Networking_Responses_FortDetailsResponse]()
        var quests = [POGOProtos_Data_Quests_Quest]()

        for rawData in contents {
            let data = Data(base64Encoded: rawData["data"] as! String)!
            
            let method = rawData["method"] as? Int ?? 106
            
            if method == 101 {
                if let fsr = try? POGOProtos_Networking_Responses_FortSearchResponse(serializedData: data) {
                    if fsr.hasChallengeQuest && fsr.challengeQuest.hasQuest {
                        let quest = fsr.challengeQuest.quest
                        quests.append(quest)
                    }
                }
            /*} else if method == 102 {
                if let er = try? POGOProtos_Networking_Responses_EncounterResponse(serializedData: data) {
                    print(er)
                }*/
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
        
        for fort in forts {
            if !inArea {
                let coord = CLLocationCoordinate2D(latitude: fort.latitude, longitude: fort.longitude)
                if coord.distance(to: targetCoord) <= targetMaxDistance {
                    inArea = true
                }
            } else {
                break
            }
        }
        for pokemon in wildPokemons {
            if !inArea {
                let coord = CLLocationCoordinate2D(latitude: pokemon.latitude, longitude: pokemon.longitude)
                if coord.distance(to: targetCoord) <= targetMaxDistance {
                    inArea = true
                }
            } else {
                break
            }
        }
        
        do {
            try response.respondWithData(data: ["nearby": nearbyPokemons.count, "wild": wildPokemons.count, "forts": forts.count, "in_area": inArea])
        } catch {
            response.respondWithError(status: .internalServerError)
        }
        
        let queue = Threading.getQueue(name: Foundation.UUID().uuidString, type: .serial)
        queue.dispatch {
            
            let startWildPokemon = Date()
            for wildPokemon in wildPokemons {
                let pokemon = Pokemon(wildPokemon: wildPokemon)
                try? pokemon.save()
            }
            Log.info(message: "[WebHookRequestHandler] Pokemon Count: \(wildPokemons.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(startWildPokemon)))s")
            
            let startPokemon = Date()
            for nearbyPokemon in nearbyPokemons {
                let pokemon = try? Pokemon(nearbyPokemon: nearbyPokemon)
                try? pokemon?.save()
            }
            Log.info(message: "[WebHookRequestHandler] NearbyPokemon Count: \(nearbyPokemons.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(startPokemon)))s")

            let startForts = Date()
            for fort in forts {
                if fort.type == .gym {
                    let gym = Gym(fortData: fort)
                    try? gym.save()
                } else if fort.type == .checkpoint {
                    let pokestop = Pokestop(fortData: fort)
                    try? pokestop.save()
                }
            }
            Log.info(message: "[WebHookRequestHandler] Forts Count: \(forts.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(startForts)))s")
            
            if !fortDetails.isEmpty {
                let start = Date()
                for fort in fortDetails {
                    if fort.type == .gym {
                        let gym: Gym?
                        do {
                            gym = try Gym.getWithId(id: fort.fortID)
                        } catch {
                            gym = nil
                        }
                        if gym != nil {
                            gym!.addDetails(fortData: fort)
                            try? gym!.save()
                        }
                    } else if fort.type == .checkpoint {
                        let pokestop: Pokestop?
                        do {
                            pokestop = try Pokestop.getWithId(id: fort.fortID)
                        } catch {
                            pokestop = nil
                        }
                        if pokestop != nil {
                            pokestop!.addDetails(fortData: fort)
                            try? pokestop!.save()
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
                        pokestop = try Pokestop.getWithId(id: quest.fortID)
                    } catch {
                        pokestop = nil
                    }
                    if pokestop != nil {
                        pokestop!.addQuest(questData: quest)
                        try? pokestop!.save()
                    }
                }
                Log.info(message: "[WebHookRequestHandler] Quest Count: \(quests.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(start)))s")
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
        
        if type == "init" {
            do {
                let device = try Device.getById(id: uuid)
                let firstWarningTimestamp: UInt32?
                if device == nil || device!.accountUsername == nil {
                    firstWarningTimestamp = nil
                } else {
                    let account = try Account.getWithUsername(username: device!.accountUsername!)
                    if account != nil {
                        firstWarningTimestamp = account!.firstWarningTimestamp
                    } else {
                        firstWarningTimestamp = nil
                    }
                }
                
                if device == nil {
                    let newDevice = Device(uuid: uuid, instanceName: nil, lastHost: nil, lastSeen: 0, accountUsername: nil)
                    try newDevice.create()
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
                try Device.touch(uuid: uuid, host: host, seen: now)
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
                    let device = try Device.getById(id: uuid),
                    let account = try Account.getNewAccount(minLevel: 0, maxLevel: 29)
                    else {
                        response.respondWithError(status: .notFound)
                        return
                }
                if device.accountUsername != nil {
                    do {
                        let oldAccount = try Account.getWithUsername(username: device.accountUsername!)
                        if oldAccount != nil && oldAccount!.firstWarningTimestamp == nil && oldAccount!.failed == nil && oldAccount!.failedTimestamp == nil {
                            try response.respondWithData(data: ["username": oldAccount!.username, "password": oldAccount!.password, "first_warning_timestamp": oldAccount!.firstWarningTimestamp as Any])
                            return
                        }
                    } catch { }
                }
                
                device.accountUsername = account.username
                try device.save(oldUUID: device.uuid)
                try response.respondWithData(data: ["username": account.username, "password": account.password, "first_warning_timestamp": account.firstWarningTimestamp as Any])
            
            } catch {
                response.respondWithError(status: .internalServerError)
            }
        } else if type == "tutorial_done" {
            do {
                guard
                    let device = try Device.getById(id: uuid),
                    let username = device.accountUsername,
                    let account = try Account.getWithUsername(username: username)
                    else {
                        response.respondWithError(status: .internalServerError)
                        return
                }
                if account.level == 0 {
                    account.level = 1
                    try account.save(update: true)
                }
                response.respondWithOk()
            } catch {
                response.respondWithError(status: .internalServerError)
            }
        } else if type == "account_banned" {
            do {
                guard
                    let device = try Device.getById(id: uuid),
                    let username = device.accountUsername,
                    let account = try Account.getWithUsername(username: username)
                else {
                    response.respondWithError(status: .internalServerError)
                    return
                }
                if account.failedTimestamp == nil || account.failed == nil {
                    account.failedTimestamp = UInt32(Date().timeIntervalSince1970)
                    account.failed = "banned"
                    try account.save(update: true)
                }
                response.respondWithOk()
            } catch {
                response.respondWithError(status: .internalServerError)
            }
        } else if type == "account_warning" {
            do {
                guard
                    let device = try Device.getById(id: uuid),
                    let username = device.accountUsername,
                    let account = try Account.getWithUsername(username: username)
                    else {
                        response.respondWithError(status: .notFound)
                        return
                }
                if account.firstWarningTimestamp == nil {
                    account.firstWarningTimestamp = UInt32(Date().timeIntervalSince1970)
                    try account.save(update: true)
                }
                response.respondWithOk()
            } catch {
                response.respondWithError(status: .internalServerError)
            }
        } else if type == "account_invalid_credentials" {
            do {
                guard
                    let device = try Device.getById(id: uuid),
                    let username = device.accountUsername,
                    let account = try Account.getWithUsername(username: username)
                    else {
                        response.respondWithError(status: .notFound)
                        return
                }
                if account.failedTimestamp == nil || account.failed == nil {
                    account.failedTimestamp = UInt32(Date().timeIntervalSince1970)
                    account.failed = "invalid_credentials"
                    try account.save(update: true)
                }
                response.respondWithOk()
            } catch {
                response.respondWithError(status: .internalServerError)
            }
        } else if type == "logged_out" {
            do {
                guard
                    let device = try Device.getById(id: uuid)
                else {
                    response.respondWithError(status: .notFound)
                    return
                }
                device.accountUsername = nil
                try device.save(oldUUID: device.uuid)
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
