//
//  IVInstanceController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 06.11.18.
//

import Foundation
import PerfectLib
import PerfectThread
import Turf

class IVInstanceController: InstanceControllerProto {
    
    public private(set) var name: String
    public private(set) var minLevel: UInt8
    public private(set) var maxLevel: UInt8
    public var delegate: InstanceControllerDelegate?

    private var multiPolygon: MultiPolygon
    private var pokemonList: [UInt16]
    private var pokemonQueue = [Pokemon]()
    private var pokemonLock = Threading.Lock()
    
    init(name: String, multiPolygon: MultiPolygon, pokemonList: [UInt16], minLevel: UInt8, maxLevel: UInt8) {
        self.name = name
        self.minLevel = minLevel
        self.maxLevel = maxLevel
        self.multiPolygon = multiPolygon
        self.pokemonList = pokemonList
    }
    func getTask(uuid: String, username: String?) -> [String : Any] {
        pokemonLock.lock()
        if pokemonQueue.isEmpty {
            pokemonLock.unlock()
            return [String: Any]()
        }
        let pokemon = pokemonQueue.removeFirst()
        pokemonLock.unlock()
        return ["action": "scan_iv", "lat": pokemon.lat, "lon": pokemon.lon, "id": pokemon.id, "is_spawnpoint": pokemon.spawnId != nil, "min_level": minLevel, "max_level": maxLevel]
    }
    
    func getStatus() -> String {
        return "Queue: \(pokemonQueue.count)"
    }
    
    func reload() {}
    
    func stop() {}
    
    func addPokemon(pokemon: Pokemon) {
        if pokemonList.contains(pokemon.pokemonId) && multiPolygon.contains(CLLocationCoordinate2D(latitude: pokemon.lat, longitude: pokemon.lon)) {
            pokemonLock.lock()
            
            let index = lastIndexOf(pokemonId: pokemon.pokemonId)
            
            if pokemonQueue.count >= 100 && index == nil {
                Log.warning(message: "[IVInstanceController] Queue is full!")
            } else if pokemonQueue.count >= 100 {
                pokemonQueue.insert(pokemon, at: index!)
                _ = pokemonQueue.popLast()
            } else if index != nil {
                pokemonQueue.insert(pokemon, at: index!)
            } else {
                pokemonQueue.append(pokemon)
            }
            pokemonLock.unlock()
        }
        
    }
    
    private func lastIndexOf(pokemonId: UInt16) -> Int? {
        
        let targetPriority = pokemonList.index(of: pokemonId)!
        
        var i = 0
        for pokemon in pokemonQueue {
            let priority = pokemonList.index(of: pokemon.pokemonId)!
            if targetPriority < priority {
                return i
            }
            i += 1
        }
        
        return nil
        
    }
    
}
