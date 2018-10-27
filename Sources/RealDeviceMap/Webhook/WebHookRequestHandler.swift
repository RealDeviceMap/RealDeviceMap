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
        
        response.respondWithOk()

        let queue = Threading.getQueue(name: Foundation.UUID().uuidString, type: .serial)
        queue.dispatch {
            if let gyms = json["gyms"] as? [[String: Any]] {
                let start = Date()
                for gymData in gyms {
                    guard let gym = try? Gym(json: gymData) else {
                        //Log.warning(message: "[WebHookRequestHandler] Failed to Parse gym")
                        continue
                    }
                    try? gym.save()
                }
                Log.info(message: "[WebHookRequestHandler] Gym Count: \(gyms.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(start)))s")
            }
            if let pokestops = json["pokestops"] as? [[String: Any]] {
                let start = Date()
                for pokestopData in pokestops {
                    guard let pokestop = try? Pokestop(json: pokestopData) else {
                        //Log.warning(message: "[WebHookRequestHandler] Failed to Parse pokestop")
                        continue
                    }
                    try? pokestop.save()
                }
                Log.info(message: "[WebHookRequestHandler] Pokestop Count: \(pokestops.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(start)))s")
            }
            if let nearbyPokemons = json["nearby_pokemon"] as? [[String: Any]] {
                let start = Date()
                for pokemonData in nearbyPokemons {
                    guard let pokemon = try? Pokemon(json: pokemonData) else {
                        //Log.warning(message: "[WebHookRequestHandler] Failed to Parse Nearby Pokemon")
                        continue
                    }
                    try? pokemon.save()
                }
                Log.info(message: "[WebHookRequestHandler] NearbyPokemon Count: \(nearbyPokemons.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(start)))s")
            }
            if let pokemons = json["pokemon"] as? [[String: Any]] {
                let start = Date()
                for pokemonData in pokemons {
                    guard let pokemon = try? Pokemon(json: pokemonData) else {
                        //Log.warning(message: "[WebHookRequestHandler] Failed to Parse Pokemon")
                        continue
                    }
                    try? pokemon.save()
                }
                Log.info(message: "[WebHookRequestHandler] Pokemon Count: \(pokemons.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(start)))s")
            }
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
        
        var wildPokemons = [POGOProtos_Map_Pokemon_WildPokemon]()
        var nearbyPokemons = [POGOProtos_Map_Pokemon_NearbyPokemon]()
        var forts = [POGOProtos_Map_Fort_FortData]()

        for rawData in contents {
            let data = Data(base64Encoded: rawData["data"] as! String)!
            
            let method = rawData["method"] as? Int ?? 106
            print(method)
            
            if method == 106 {
                if let gmo = try? POGOProtos_Networking_Responses_GetMapObjectsResponse(serializedData: data) {
                    for mapCell in gmo.mapCells {
                        wildPokemons += mapCell.wildPokemons
                        nearbyPokemons += mapCell.nearbyPokemons
                        forts += mapCell.forts
                    }
                }
            } else if method == 102 {
                if let er = try? POGOProtos_Networking_Responses_EncounterResponse(serializedData: data) {
                    print(er)
                }
            } else if method == 101 {
                if let fsr = try? POGOProtos_Networking_Responses_FortSearchResponse(serializedData: data) {
                    print(fsr)
                }
            }
            
        }
        
        do {
            try response.respondWithData(data: ["nearby": nearbyPokemons.count, "wild": wildPokemons.count, "forts": forts.count])
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
                try! response.respondWithData(data: controller!.getTask())
            } else {
                response.respondWithError(status: .notFound)
            }
        } else if type == "get_account" {
            do {
                guard
                    let device = try Device.getById(id: uuid),
                    let account = try Account.getNewAccount(highLevel: false)
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
