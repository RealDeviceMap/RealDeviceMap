//
//  WebHookController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 03.10.18.
//

import Foundation
import PerfectLib
import PerfectThread
import cURL
import PerfectCURL

class WebHookController {
    
    private init() {}
    
    public private(set) static var global = WebHookController()
    
    public var webhookURLStrings = [String]()
    public var webhookSendDelay = 5.0
    
    private var pokemonEventLock = NSLock()
    private var pokemonEvents = [String: Pokemon]()
    private var pokestopEventLock = NSLock()
    private var pokestopEvents = [String: Pokestop]()
    private var lureEventLock = NSLock()
    private var lureEvents = [String: Pokestop]()
    private var gymEventLock = NSLock()
    private var gymEvents = [String: Gym]()
    private var gymInfoEventLock = NSLock()
    private var gymInfoEvents = [String: Gym]()
    private var eggEventLock = NSLock()
    private var eggEvents = [String: Gym]()
    private var raidEventLock = NSLock()
    private var raidEvents = [String: Gym]()
    
    private var queue: ThreadQueue?
    
    public func addPokemonEvent(pokemon: Pokemon) {
        if !self.webhookURLStrings.isEmpty {
            pokemonEventLock.lock()
            pokemonEvents[pokemon.id] = pokemon
            pokemonEventLock.unlock()
        }
    }
    
    public func addPokestopEvent(pokestop: Pokestop) {
        if !self.webhookURLStrings.isEmpty {
            pokestopEventLock.lock()
            pokestopEvents[pokestop.id] = pokestop
            pokestopEventLock.unlock()
        }
    }
    
    public func addLureEvent(pokestop: Pokestop) {
        if !self.webhookURLStrings.isEmpty {
            lureEventLock.lock()
            lureEvents[pokestop.id] = pokestop
            lureEventLock.unlock()
        }
    }
    
    public func addGymEvent(gym: Gym) {
        if !self.webhookURLStrings.isEmpty {
            gymEventLock.lock()
            gymEvents[gym.id] = gym
            gymEventLock.unlock()
        }
    }
    
    public func addGymInfoEvent(gym: Gym) {
        if !self.webhookURLStrings.isEmpty {
            gymInfoEventLock.lock()
            gymInfoEvents[gym.id] = gym
            gymInfoEventLock.unlock()
        }
    }
    
    public func addEggEvent(gym: Gym) {
        if !self.webhookURLStrings.isEmpty {
            eggEventLock.lock()
            eggEvents[gym.id] = gym
            eggEventLock.unlock()
        }
    }
    
    public func addRaidEvent(gym: Gym) {
        if !self.webhookURLStrings.isEmpty {
            raidEventLock.lock()
            raidEvents[gym.id] = gym
            raidEventLock.unlock()
        }
    }
    
    public func start() {
        
        if queue == nil {
            queue = Threading.getQueue(name: "WebHookControllerQueue", type: .serial)
            queue!.dispatch {
                
                while true {
                    if !self.webhookURLStrings.isEmpty {
                        var events = [[String: Any]]()
                        
                        self.pokemonEventLock.lock()
                        for pokemonEvent in self.pokemonEvents {
                            events.append(["type": "pokemon", "message": pokemonEvent.value.getWebhookValues()])
                        }
                        self.pokemonEvents = [String: Pokemon]()
                        self.pokemonEventLock.unlock()
                        
                        self.pokestopEventLock.lock()
                        for pokestopEvent in self.pokestopEvents {
                            events.append(["type": "pokestop", "message": pokestopEvent.value.getWebhookValues()])
                        }
                        self.pokestopEvents = [String: Pokestop]()
                        self.pokestopEventLock.unlock()
                        
                        self.lureEventLock.lock()
                        for lureEvent in self.lureEvents {
                            events.append(["type": "lure", "message": lureEvent.value.getWebhookValues()])
                        }
                        self.lureEvents = [String: Pokestop]()
                        self.lureEventLock.unlock()
                        
                        self.gymEventLock.lock()
                        for gymEvent in self.gymEvents {
                            events.append(["type": "gym", "message": gymEvent.value.getWebhookValues()])
                        }
                        self.gymEvents = [String: Gym]()
                        self.gymEventLock.unlock()
                        
                        self.gymInfoEventLock.lock()
                        for gymInfoEvent in self.gymInfoEvents {
                            events.append(["type": "gym-info", "message": gymInfoEvent.value.getWebhookValues()])
                        }
                        self.gymInfoEvents = [String: Gym]()
                        self.gymInfoEventLock.unlock()
                        
                        self.raidEventLock.lock()
                        for raidEvent in self.raidEvents {
                            events.append(["type": "raid", "message": raidEvent.value.getWebhookValues()])
                        }
                        self.raidEvents = [String: Gym]()
                        self.raidEventLock.unlock()
                        
                        self.eggEventLock.lock()
                        for eggEvent in self.eggEvents {
                            events.append(["type": "egg", "message": eggEvent.value.getWebhookValues()])
                        }
                        self.eggEvents = [String: Gym]()
                        self.eggEventLock.unlock()
                        
                        
                        if !events.isEmpty {
                            for url in self.webhookURLStrings {
                                self.sendEvents(events: events, url: url)
                            }
                        }
                        
                    }
                    
                    usleep(UInt32(self.webhookSendDelay * 1000000))
                }
            }
        }
        
    }
    
    private func sendEvents(events: [[String: Any]], url: String) {
        
        let body = try! events.jsonEncodedString()
        let byteArray = [UInt8](body.utf8)

        let curlObject = CURL(url: url)
        
        curlObject.setOption(CURLOPT_HTTPHEADER, s: "Accept: application/json")
        curlObject.setOption(CURLOPT_HTTPHEADER, s: "Cache-Control: no-cache")
        curlObject.setOption(CURLOPT_USERAGENT, s: "RealDeviceMap")
        curlObject.setOption(CURLOPT_POST, int: 1)
        curlObject.setOption(CURLOPT_POSTFIELDSIZE, int: byteArray.count)
        curlObject.setOption(CURLOPT_COPYPOSTFIELDS, v: UnsafeMutablePointer(mutating: byteArray))
        curlObject.setOption(CURLOPT_HTTPHEADER, s: "Content-Type: application/json")
    
        curlObject.perform { (_, _, _) in }
        
    }
    
}
