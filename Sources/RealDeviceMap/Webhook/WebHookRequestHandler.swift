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
                Log.info(message: "[WebHookRequestHandler] NearbyPokemn Count: \(nearbyPokemons.count) parsed in \(String(format: "%.3f", Date().timeIntervalSince(start)))s")
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
        
        let gmos = json["gmo"] as! [[String: Any]]
        
        var wildPokemonsCount = 0
        var nearbyPokemonsCount = 0
        var fortsCount = 0
        
        var wildPokemons = [POGOProtos_Map_Pokemon_WildPokemon]()
        var nearbyPokemons = [POGOProtos_Map_Pokemon_NearbyPokemon]()
        var forts = [POGOProtos_Map_Fort_FortData]()
        
        for gmoData in gmos {
            let data = Data(base64Encoded: gmoData["data"] as! String)!
            
            if let gmo = try? POGOProtos_Networking_Responses_GetMapObjectsResponse(serializedData: data) {
                for mapCell in gmo.mapCells {
                    wildPokemons += mapCell.wildPokemons
                    nearbyPokemons += mapCell.nearbyPokemons
                    forts += mapCell.forts
                    wildPokemonsCount += mapCell.wildPokemons.count
                    nearbyPokemonsCount += mapCell.nearbyPokemons.count
                    fortsCount += mapCell.forts.count
                }
            }
            
        }

        do {
            try response.respondWithData(data: ["nearby": nearbyPokemonsCount, "wild": wildPokemonsCount, "forts": fortsCount])
        } catch {
            response.respondWithError(status: .internalServerError)
        }
        
        let queue = Threading.getQueue(name: Foundation.UUID().uuidString, type: .serial)
        queue.dispatch {
            
            for wildPokemon in wildPokemons {
                let pokemon = Pokemon(wildPokemon: wildPokemon)
                try? pokemon.save()
            }
            for nearbyPokemon in nearbyPokemons {
                let pokemon = try? Pokemon(nearbyPokemon: nearbyPokemon)
                try? pokemon?.save()
            }
            for fort in forts {
                if fort.type == .gym {
                    let gym = Gym(fortData: fort)
                    try? gym.save()
                } else if fort.type == .checkpoint {
                    let pokestop = Pokestop(fortData: fort)
                    try? pokestop.save()
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
        
        if type == "init" {
            do {
                let device = try Device.getById(id: uuid)
                if device == nil {
                    let newDevice = Device(uuid: uuid, instanceName: nil, lastHost: nil, lastSeen: 0)
                    try newDevice.create()
                    try response.respondWithData(data: ["asigned": false])
                } else {
                    if device!.instanceName == nil {
                        try response.respondWithData(data: ["asigned": false])
                    } else {
                        try response.respondWithData(data: ["asigned": true])
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
        } else {
            response.respondWithError(status: .badRequest)
        }
        
    }
    
}
