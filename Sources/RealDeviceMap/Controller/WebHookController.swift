//
//  WebHookController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 03.10.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity

import Foundation
import PerfectLib
import PerfectThread
import cURL
import PerfectCURL
import Turf

class WebHookController {

    private init() {}

    public private(set) static var global = WebHookController()

    public var webhooks = [Webhook]()

    private var pokemonEventLock = Threading.Lock()
    private var pokemonEvents = [String: Pokemon]()
    private var pokestopEventLock = Threading.Lock()
    private var pokestopEvents = [String: Pokestop]()
    private var lureEventLock = Threading.Lock()
    private var lureEvents = [String: Pokestop]()
    private var invasionEventLock = Threading.Lock()
    private var invasionEvents = [String: Pokestop]()
    private var questEventLock = Threading.Lock()
    private var questEvents = [String: Pokestop]()
    private var gymEventLock = Threading.Lock()
    private var gymEvents = [String: Gym]()
    private var gymInfoEventLock = Threading.Lock()
    private var gymInfoEvents = [String: Gym]()
    private var eggEventLock = Threading.Lock()
    private var eggEvents = [String: Gym]()
    private var raidEventLock = Threading.Lock()
    private var raidEvents = [String: Gym]()
    private var weatherEventLock = Threading.Lock()
    private var weatherEvents = [Int64: Weather]()
    private var accountEventLock = Threading.Lock()
    private var accountEvents = [String: Account]()

    private var queue: ThreadQueue?

    public func addPokemonEvent(pokemon: Pokemon) {
        if !self.webhooks.isEmpty {
            pokemonEventLock.lock()
            pokemonEvents[pokemon.id] = pokemon
            pokemonEventLock.unlock()
        }
    }

    public func addPokestopEvent(pokestop: Pokestop) {
        if !self.webhooks.isEmpty {
            pokestopEventLock.lock()
            pokestopEvents[pokestop.id] = pokestop
            pokestopEventLock.unlock()
        }
    }

    public func addLureEvent(pokestop: Pokestop) {
        if !self.webhooks.isEmpty {
            lureEventLock.lock()
            lureEvents[pokestop.id] = pokestop
            lureEventLock.unlock()
        }
    }

    public func addInvasionEvent(pokestop: Pokestop) {
        if !self.webhooks.isEmpty {
            invasionEventLock.lock()
            invasionEvents[pokestop.id] = pokestop
            invasionEventLock.unlock()
        }
    }

    public func addQuestEvent(pokestop: Pokestop) {
        if !self.webhooks.isEmpty {
            questEventLock.lock()
            questEvents[pokestop.id] = pokestop
            questEventLock.unlock()
        }
    }

    public func addGymEvent(gym: Gym) {
        if !self.webhooks.isEmpty {
            gymEventLock.lock()
            gymEvents[gym.id] = gym
            gymEventLock.unlock()
        }
    }

    public func addGymInfoEvent(gym: Gym) {
        if !self.webhooks.isEmpty {
            gymInfoEventLock.lock()
            gymInfoEvents[gym.id] = gym
            gymInfoEventLock.unlock()
        }
    }

    public func addEggEvent(gym: Gym) {
        if !self.webhooks.isEmpty {
            eggEventLock.lock()
            eggEvents[gym.id] = gym
            eggEventLock.unlock()
        }
    }

    public func addRaidEvent(gym: Gym) {
        if !self.webhooks.isEmpty {
            raidEventLock.lock()
            raidEvents[gym.id] = gym
            raidEventLock.unlock()
        }
    }

    public func addWeatherEvent(weather: Weather) {
        if !self.webhooks.isEmpty {
            weatherEventLock.lock()
            weatherEvents[weather.id] = weather
            weatherEventLock.unlock()
        }
    }

    public func addAccountEvent(account: Account) {
        if !self.webhooks.isEmpty {
            accountEventLock.lock()
            accountEvents[account.username] = account
            accountEventLock.unlock()
        }
    }

    public func start() {

        webhooks = try! Webhook.getAll()

        if queue == nil {
            queue = Threading.getQueue(name: "WebHookControllerQueue", type: .serial)
            queue!.dispatch {

                while true {
                    if !self.webhooks.isEmpty {
                        var events = [[String: Any]]()

                        for webhook in self.webhooks {
                            if !webhook.enabled {
                                continue
                            }
                            
                            self.pokemonEventLock.lock()
                            for pokemonEvent in self.pokemonEvents {
                                if webhook.data["area"] == nil || (webhook.data["area"] != nil && self.inPolygon(lat: pokemonEvent.value.lat, lon: pokemonEvent.value.lon, coords: webhook.data["area"] as! [[Coord]])) {
                                    if webhook.types.contains(.pokemon) &&
                                       (webhook.data["pokemon_ids"] as! [UInt16]).contains(pokemonEvent.value.pokemonId) {
                                        continue
                                    }
                                }
                                events.append(pokemonEvent.value.getWebhookValues(type: "pokemon"))
                            }
                            self.pokemonEvents = [String: Pokemon]()
                            self.pokemonEventLock.unlock()

                            self.pokestopEventLock.lock()
                            for pokestopEvent in self.pokestopEvents {
                                events.append(pokestopEvent.value.getWebhookValues(type: "pokestop"))
                            }
                            self.pokestopEvents = [String: Pokestop]()
                            self.pokestopEventLock.unlock()

                            self.lureEventLock.lock()
                            for lureEvent in self.lureEvents {
                                if webhook.data["area"] == nil || (webhook.data["area"] != nil && self.inPolygon(lat: lureEvent.value.lat, lon: lureEvent.value.lon, coords: webhook.data["area"] as! [[Coord]])) {
                                    if webhook.types.contains(.lures) && (webhook.data["lure_ids"] as! [UInt16]).contains(UInt16(lureEvent.value.lureId ?? 0)) {
                                        continue
                                    }
                                }
                                events.append(lureEvent.value.getWebhookValues(type: "lure"))
                            }
                            self.lureEvents = [String: Pokestop]()
                            self.lureEventLock.unlock()

                            self.invasionEventLock.lock()
                            for invasionEvent in self.invasionEvents {
                                if webhook.data["area"] == nil || (webhook.data["area"] != nil && self.inPolygon(lat: invasionEvent.value.lat, lon: invasionEvent.value.lon, coords: webhook.data["area"] as! [[Coord]])) {
                                    if webhook.types.contains(.invasions) && (webhook.data["invasion_ids"] as! [UInt16]).contains(invasionEvent.value.gruntType ?? 0) {
                                        continue
                                    }
                                }
                                events.append(invasionEvent.value.getWebhookValues(type: "invasion"))
                            }
                            self.invasionEvents = [String: Pokestop]()
                            self.invasionEventLock.unlock()

                            self.questEventLock.lock()
                            for questEvent in self.questEvents {
                                events.append(questEvent.value.getWebhookValues(type: "quest"))
                            }
                            self.questEvents = [String: Pokestop]()
                            self.questEventLock.unlock()

                            self.gymEventLock.lock()
                            for gymEvent in self.gymEvents {
                                if webhook.data["area"] == nil || (webhook.data["area"] != nil && self.inPolygon(lat: gymEvent.value.lat, lon: gymEvent.value.lon, coords: webhook.data["area"] as! [[Coord]])) {
                                    if webhook.types.contains(.gyms) && gymEvent.value.teamId ?? 0 > 0 && (webhook.data["gym_ids"] as! [UInt8]).contains(gymEvent.value.teamId ?? 0) {
                                        continue
                                    }
                                }
                                events.append(gymEvent.value.getWebhookValues(type: "gym"))
                            }
                            self.gymEvents = [String: Gym]()
                            self.gymEventLock.unlock()

                            self.gymInfoEventLock.lock()
                            for gymInfoEvent in self.gymInfoEvents {
                                if webhook.data["area"] == nil || (webhook.data["area"] != nil && self.inPolygon(lat: gymInfoEvent.value.lat, lon: gymInfoEvent.value.lon, coords: webhook.data["area"] as! [[Coord]])) {
                                    if webhook.types.contains(.gyms) && gymInfoEvent.value.teamId ?? 0 > 0 && (webhook.data["gym_ids"] as! [UInt8]).contains(gymInfoEvent.value.teamId ?? 0) {
                                        continue
                                    }
                                }
                                events.append(gymInfoEvent.value.getWebhookValues(type: "gym-info"))
                            }
                            self.gymInfoEvents = [String: Gym]()
                            self.gymInfoEventLock.unlock()

                            self.raidEventLock.lock()
                            for raidEvent in self.raidEvents {
                                if webhook.data["area"] == nil || (webhook.data["area"] != nil && self.inPolygon(lat: raidEvent.value.lat, lon: raidEvent.value.lon, coords: webhook.data["area"] as! [[Coord]])) {
                                    if webhook.types.contains(.raids) &&
                                       raidEvent.value.raidPokemonId ?? 0 > 0 &&
                                       (webhook.data["raid_ids"] as! [UInt16]).contains(raidEvent.value.raidPokemonId!) {
                                        continue
                                    }
                                }
                                events.append(raidEvent.value.getWebhookValues(type: "raid"))
                            }
                            self.raidEvents = [String: Gym]()
                            self.raidEventLock.unlock()

                            self.eggEventLock.lock()
                            for eggEvent in self.eggEvents {
                                if webhook.data["area"] == nil || (webhook.data["area"] != nil && self.inPolygon(lat: eggEvent.value.lat, lon: eggEvent.value.lon, coords: webhook.data["area"] as! [[Coord]])) {
                                    if webhook.types.contains(.eggs) && eggEvent.value.raidLevel ?? 0 > 0 && (webhook.data["egg_ids"] as! [UInt8]).contains(eggEvent.value.raidLevel ?? 0) {
                                        continue
                                    }
                                }
                                events.append(eggEvent.value.getWebhookValues(type: "egg"))
                            }
                            self.eggEvents = [String: Gym]()
                            self.eggEventLock.unlock()

                            self.weatherEventLock.lock()
                            for weatherEvent in self.weatherEvents {
                                if webhook.data["area"] == nil || (webhook.data["area"] != nil && self.inPolygon(lat: weatherEvent.value.latitude, lon: weatherEvent.value.longitude, coords: webhook.data["area"] as! [[Coord]])) {
                                    if webhook.types.contains(.weather) && weatherEvent.value.gameplayCondition > 0 && (webhook.data["weather_ids"] as! [UInt8]).contains(weatherEvent.value.gameplayCondition) {
                                        continue
                                    }
                                }
                                events.append(weatherEvent.value.getWebhookValues(type: "weather"))
                            }
                            self.weatherEvents = [Int64: Weather]()
                            self.weatherEventLock.unlock() 

                            self.accountEventLock.lock()
                            for accountEvent in self.accountEvents {
                                events.append(accountEvent.value.getWebhookValues(type: "account"))
                            }
                            self.accountEvents = [String: Account]()
                            self.accountEventLock.unlock()

                            if !events.isEmpty {
                                self.sendEvents(events: events, url: webhook.url)
                            }
                            
                            Threading.sleep(seconds: webhook.delay)
                        }
                    }
                }
            }
        }
    }

    private func sendEvents(events: [[String: Any]], url: String) {

        guard let body = try? events.jsonEncodedString() else {
            Log.error(message: "[WebHookController] Failed to parse events into json string")
            return
        }
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

    private func inPolygon(lat: Double, lon: Double, coords: [[Coord]]) -> Bool {
        var geofences = [[[CLLocationCoordinate2D]]]()
        for coord in coords {
            var geofence = [CLLocationCoordinate2D]()
            for crd in coord {
                geofence.append(CLLocationCoordinate2D.init(latitude: crd.lat, longitude: crd.lon))
            }
            geofences.append([geofence])
        }
        let multiPolygon = MultiPolygon.init(geofences)
        for polygon in multiPolygon.polygons {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            if polygon.contains(coord, ignoreBoundary: false) {
                return true
            }
        }
        return false
    }


}
