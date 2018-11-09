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
    private var scannedPokemon = [(Date, Pokemon)]()
    private var scannedPokemonLock = Threading.Lock()
    private var checkScannedThreadingQueue: ThreadQueue?
    private var statsLock = Threading.Lock()
    private var startDate: Date?
    private var count: UInt64 = 0
    
    init(name: String, multiPolygon: MultiPolygon, pokemonList: [UInt16], minLevel: UInt8, maxLevel: UInt8) {
        self.name = name
        self.minLevel = minLevel
        self.maxLevel = maxLevel
        self.multiPolygon = multiPolygon
        self.pokemonList = pokemonList
        
        checkScannedThreadingQueue = Threading.getQueue(name:  "\(name)-check-scanned", type: .serial)
        checkScannedThreadingQueue!.dispatch {
            
            while true {
                
                self.scannedPokemonLock.lock()
                if self.scannedPokemon.isEmpty {
                    self.scannedPokemonLock.unlock()
                    Threading.sleep(seconds: 5)
                } else {
                    let first = self.scannedPokemon.removeFirst()
                    self.scannedPokemonLock.unlock()
                    let timeSince = Date().timeIntervalSince(first.0)
                    if timeSince < 120 {
                        Threading.sleep(seconds: 120 - timeSince)
                    }
                    var success = false
                    var pokemonReal: Pokemon?
                    while !success {
                        do {
                            pokemonReal = try Pokemon.getWithId(id: first.1.id)
                            success = true
                        } catch {}
                    }
                    if let pokemonReal = pokemonReal {
                        if pokemonReal.atkIv == nil {
                            Log.debug(message: "[IVInstanceController] Checked Pokemon doesn't have IV")
                            self.addPokemon(pokemon: pokemonReal)
                        } else {
                            Log.debug(message: "[IVInstanceController] Checked Pokemon has IV")
                            self.statsLock.lock()
                            if self.startDate == nil {
                                self.startDate = Date()
                            }
                            if self.count == UInt64.max {
                                self.count = 0
                                self.startDate = Date()
                            } else {
                                self.count += 1
                            }
                            self.statsLock.unlock()
                        }
                    }
                    
                }
                
            }
            
        }
    }
    
    deinit {
        stop()
    }
    
    func getTask(uuid: String, username: String?) -> [String : Any] {
        pokemonLock.lock()
        if pokemonQueue.isEmpty {
            pokemonLock.unlock()
            return [String: Any]()
        }
        let pokemon = pokemonQueue.removeFirst()
        pokemonLock.unlock()
        
        if UInt32(Date().timeIntervalSince1970) - pokemon.firstSeenTimestamp >= 600 {
            return getTask(uuid: uuid, username: username)
        }
        
        scannedPokemonLock.lock()
        scannedPokemon.append((Date(), pokemon))
        scannedPokemonLock.unlock()
        
        return ["action": "scan_iv", "lat": pokemon.lat, "lon": pokemon.lon, "id": pokemon.id, "is_spawnpoint": pokemon.spawnId != nil, "min_level": minLevel, "max_level": maxLevel]
    }
    
    func getStatus() -> String {
        
        let ivh: String
        self.statsLock.lock()
        if self.startDate != nil {
            ivh = "\(Int(Double(self.count) / Date().timeIntervalSince(self.startDate!) * 3600))"
        } else {
            ivh = "-"
        }
        self.statsLock.unlock()
        return "<a href=\"/dashboard/instance/ivqueue/\(name.encodeUrl() ?? "")\">Queue</a>: \(pokemonQueue.count), IV/h: \(ivh)"
    }
    
    func reload() {}
    
    func stop() {
        if checkScannedThreadingQueue != nil {
            Threading.destroyQueue(checkScannedThreadingQueue!)
        }
    }
    
    func getQueue() -> [Pokemon] {
        pokemonLock.lock()
        let pokemon = self.pokemonQueue
        pokemonLock.unlock()
        return pokemon
    }
    
    func addPokemon(pokemon: Pokemon) {
        if pokemonList.contains(pokemon.pokemonId) && multiPolygon.contains(CLLocationCoordinate2D(latitude: pokemon.lat, longitude: pokemon.lon)) {
            pokemonLock.lock()
            
            if pokemonQueue.contains(pokemon) {
                pokemonLock.unlock()
                return
            }
            
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
