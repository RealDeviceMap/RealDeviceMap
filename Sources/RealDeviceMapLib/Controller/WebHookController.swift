//
//  WebHookController.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 03.10.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast

import Foundation
import PerfectLib
import PerfectThread
import PerfectCURL
import Turf

public class WebHookController {

    private init() {
        let environment = ProcessInfo.processInfo.environment
        timeout = environment["WEBHOOK_ENDPOINT_TIMEOUT"]?.toInt() ?? 30
        connectTimeout = environment["WEBHOOK_ENDPOINT_CONNECT_TIMEOUT"]?.toInt() ?? 30
    }

    public private(set) static var global = WebHookController()

    public var webhooks = [Webhook]()

    private let timeout: Int
    private let connectTimeout: Int

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
    private var alternativeQuestEventsLock = Threading.Lock()
    private var alternativeQuestEvents = [String: Pokestop]()
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

    private var types = [WebhookType]()
    private var queue: ThreadQueue?

    public func addPokemonEvent(pokemon: Pokemon) {
        if !self.webhooks.isEmpty && self.types.contains(.pokemon) {
            pokemonEventLock.lock()
            pokemonEvents[pokemon.id] = pokemon
            pokemonEventLock.unlock()
        }
    }

    public func addPokestopEvent(pokestop: Pokestop) {
        if !self.webhooks.isEmpty && self.types.contains(.pokestop) {
            pokestopEventLock.lock()
            pokestopEvents[pokestop.id] = pokestop
            pokestopEventLock.unlock()
        }
    }

    public func addLureEvent(pokestop: Pokestop) {
        if !self.webhooks.isEmpty && self.types.contains(.lure) {
            lureEventLock.lock()
            lureEvents[pokestop.id] = pokestop
            lureEventLock.unlock()
        }
    }

    public func addInvasionEvent(pokestop: Pokestop) {
        if !self.webhooks.isEmpty && self.types.contains(.invasion) {
            invasionEventLock.lock()
            invasionEvents[pokestop.id] = pokestop
            invasionEventLock.unlock()
        }
    }

    public func addQuestEvent(pokestop: Pokestop) {
        if !self.webhooks.isEmpty && self.types.contains(.quest) {
            questEventLock.lock()
            questEvents[pokestop.id] = pokestop
            questEventLock.unlock()
        }
    }

    public func addAlternativeQuestEvent(pokestop: Pokestop) {
        if !self.webhooks.isEmpty && self.types.contains(.quest) {
            alternativeQuestEventsLock.lock()
            alternativeQuestEvents[pokestop.id] = pokestop
            alternativeQuestEventsLock.unlock()
        }
    }

    public func addGymEvent(gym: Gym) {
        if !self.webhooks.isEmpty && self.types.contains(.gym) {
            gymEventLock.lock()
            gymEvents[gym.id] = gym
            gymEventLock.unlock()
        }
    }

    public func addGymInfoEvent(gym: Gym) {
        if !self.webhooks.isEmpty && self.types.contains(.gym) {
            gymInfoEventLock.lock()
            gymInfoEvents[gym.id] = gym
            gymInfoEventLock.unlock()
        }
    }

    public func addEggEvent(gym: Gym) {
        if !self.webhooks.isEmpty && self.types.contains(.egg) {
            eggEventLock.lock()
            eggEvents[gym.id] = gym
            eggEventLock.unlock()
        }
    }

    public func addRaidEvent(gym: Gym) {
        if !self.webhooks.isEmpty && self.types.contains(.raid) {
            raidEventLock.lock()
            raidEvents[gym.id] = gym
            raidEventLock.unlock()
        }
    }

    public func addWeatherEvent(weather: Weather) {
        if !self.webhooks.isEmpty && self.types.contains(.weather) {
            weatherEventLock.lock()
            weatherEvents[weather.id] = weather
            weatherEventLock.unlock()
        }
    }

    public func addAccountEvent(account: Account) {
        if !self.webhooks.isEmpty && self.types.contains(.account) {
            accountEventLock.lock()
            accountEvents[account.username] = account
            accountEventLock.unlock()
        }
    }

    public func reload() {
        do {
            webhooks = try Webhook.getAll()
            types = Array(Set(webhooks.flatMap({ webhook in webhook.types })))
        } catch {
            Log.error(message: "[WebHookController] Failed to reload webhooks from DB")
        }
    }

    public func start() {

        do {
            webhooks = try Webhook.getAll()
            types = Array(Set(webhooks.flatMap({ webhook in webhook.types })))
        } catch {
            Log.error(message: "[WebHookController] Failed to load webhooks from DB")
            return
        }
        Log.debug(message: "[WebHookController] loaded \(webhooks.count) webhooks")
        Log.debug(message: "[WebHookController] loaded \(types.count) types")
        if queue == nil {
            queue = Threading.getQueue(name: "WebHookControllerQueue", type: .serial)
            queue!.dispatch {

                while true {
                    if !self.webhooks.isEmpty {
                        let countEnabled = self.webhooks.filter({ webhook in webhook.enabled == true }).count
                        if countEnabled == 0 {
                            Threading.sleep(seconds: 30.0)
                            continue
                        }

                        var pokemonEvents = [String: Pokemon]()
                        var pokestopEvents = [String: Pokestop]()
                        var lureEvents = [String: Pokestop]()
                        var invasionEvents = [String: Pokestop]()
                        var questEvents = [String: Pokestop]()
                        var alternativeQuestEvents = [String: Pokestop]()
                        var gymEvents = [String: Gym]()
                        var gymInfoEvents = [String: Gym]()
                        var eggEvents = [String: Gym]()
                        var raidEvents = [String: Gym]()
                        var weatherEvents = [Int64: Weather]()
                        var accountEvents = [String: Account]()

                        self.pokemonEventLock.lock()
                        pokemonEvents = self.pokemonEvents
                        self.pokemonEvents = [String: Pokemon]()
                        self.pokemonEventLock.unlock()

                        self.pokestopEventLock.lock()
                        pokestopEvents = self.pokestopEvents
                        self.pokestopEvents = [String: Pokestop]()
                        self.pokestopEventLock.unlock()

                        self.lureEventLock.lock()
                        lureEvents = self.lureEvents
                        self.lureEvents = [String: Pokestop]()
                        self.lureEventLock.unlock()

                        self.invasionEventLock.lock()
                        invasionEvents = self.invasionEvents
                        self.invasionEvents = [String: Pokestop]()
                        self.invasionEventLock.unlock()

                        self.questEventLock.lock()
                        questEvents = self.questEvents
                        self.questEvents = [String: Pokestop]()
                        self.questEventLock.unlock()

                        self.alternativeQuestEventsLock.lock()
                        alternativeQuestEvents = self.alternativeQuestEvents
                        self.alternativeQuestEvents = [String: Pokestop]()
                        self.alternativeQuestEventsLock.unlock()

                        self.gymEventLock.lock()
                        gymEvents = self.gymEvents
                        self.gymEvents = [String: Gym]()
                        self.gymEventLock.unlock()

                        self.gymInfoEventLock.lock()
                        gymInfoEvents = self.gymInfoEvents
                        self.gymInfoEvents = [String: Gym]()
                        self.gymInfoEventLock.unlock()

                        self.raidEventLock.lock()
                        raidEvents = self.raidEvents
                        self.raidEvents = [String: Gym]()
                        self.raidEventLock.unlock()

                        self.eggEventLock.lock()
                        eggEvents = self.eggEvents
                        self.eggEvents = [String: Gym]()
                        self.eggEventLock.unlock()

                        self.weatherEventLock.lock()
                        weatherEvents = self.weatherEvents
                        self.weatherEvents = [Int64: Weather]()
                        self.weatherEventLock.unlock()

                        self.accountEventLock.lock()
                        accountEvents = self.accountEvents
                        self.accountEvents = [String: Account]()
                        self.accountEventLock.unlock()

                        let minDelay = self.webhooks.map({ $0.delay }).min()
                        for webhook in self.webhooks {
                            if !webhook.enabled {
                                continue
                            }
                            let area = self.createAreaArray(webhookArea: webhook.data["area"])
                            let polygon = self.createMultiPolygon(areaArray: area)
                            var events = [[String: Any]]()

                            if webhook.types.contains(.pokemon) {
                                let pokemonIDs = webhook.data["pokemon_ids"] as? [Int] ?? [Int]()
                                for (_, pokemon) in pokemonEvents {
                                    if area.isEmpty ||
                                           self.inPolygon(lat: pokemon.lat, lon: pokemon.lon, multiPolygon: polygon) {
                                        if pokemonIDs.contains(Int(pokemon.pokemonId)) {
                                            continue
                                        }
                                        events.append(pokemon.getWebhookValues(type: WebhookType.pokemon.rawValue))
                                    }
                                }
                            }

                            if webhook.types.contains(.pokestop) {
                                for (_, pokestop) in pokestopEvents {
                                    if area.isEmpty ||
                                           self.inPolygon(lat: pokestop.lat, lon: pokestop.lon,
                                               multiPolygon: polygon) {
                                        events.append(pokestop.getWebhookValues(
                                            type: WebhookType.pokestop.rawValue
                                        ))
                                    }
                                }
                            }

                            if webhook.types.contains(.lure) {
                                let lureIDs = webhook.data["lure_ids"] as? [Int] ?? [Int]()
                                for (_, lure) in lureEvents {
                                    if area.isEmpty ||
                                           self.inPolygon(lat: lure.lat, lon: lure.lon, multiPolygon: polygon) {
                                        if lureIDs.contains(Int(lure.lureId ?? 0)) {
                                            continue
                                        }
                                        events.append(lure.getWebhookValues(type: WebhookType.lure.rawValue))
                                    }
                                }
                            }

                            if webhook.types.contains(.invasion) {
                                let invasionIDs = webhook.data["invasion_ids"] as? [Int] ?? [Int]()
                                for (_, invasion) in invasionEvents {
                                    if area.isEmpty ||
                                           self.inPolygon(lat: invasion.lat, lon: invasion.lon,
                                               multiPolygon: polygon) {
                                        if invasionIDs.contains(Int(invasion.gruntType ?? 0)) {
                                            continue
                                        }
                                        events.append(invasion.getWebhookValues(type: WebhookType.invasion.rawValue))
                                    }
                                }
                            }

                            if webhook.types.contains(.quest) {
                                let questIDs = webhook.data["quest_ids"] as? [Int] ?? [Int]()
                                for (_, quest) in questEvents {
                                    if area.isEmpty ||
                                           self.inPolygon(lat: quest.lat, lon: quest.lon, multiPolygon: polygon) {
                                        if questIDs.contains(Int(quest.questType ?? 0)) {
                                            continue
                                        }
                                        events.append(quest.getWebhookValues(type: WebhookType.quest.rawValue))
                                    }
                                }
                                for (_, quest) in alternativeQuestEvents {
                                    if area.isEmpty ||
                                           self.inPolygon(lat: quest.lat, lon: quest.lon, multiPolygon: polygon) {
                                        if questIDs.contains(Int(quest.questType ?? 0)) {
                                            continue
                                        }
                                        events.append(quest.getWebhookValues(type: "alternative_quest"))
                                    }
                                }
                            }

                            if webhook.types.contains(.gym) {
                                let gymIDs = webhook.data["gym_ids"] as? [Int] ?? [Int]()
                                for (_, gym) in gymEvents {
                                    if area.isEmpty ||
                                           self.inPolygon(lat: gym.lat, lon: gym.lon, multiPolygon: polygon) {
                                        if gym.teamId ?? 0 > 0 && gymIDs.contains(Int(gym.teamId ?? 0)) {
                                            continue
                                        }
                                        events.append(gym.getWebhookValues(type: WebhookType.gym.rawValue))
                                    }
                                }
                                for (_, gymInfo) in gymInfoEvents {
                                    if area.isEmpty ||
                                           self.inPolygon(lat: gymInfo.lat, lon: gymInfo.lon, multiPolygon: polygon) {
                                        if gymIDs.contains(Int(gymInfo.teamId ?? 0)) {
                                            continue
                                        }
                                        events.append(gymInfo.getWebhookValues(type: "gym-info"))
                                    }
                                }
                            }

                            if webhook.types.contains(.raid) {
                                let raidIDs = webhook.data["raid_ids"] as? [Int] ?? [Int]()
                                for (_, raid) in raidEvents {
                                    if area.isEmpty ||
                                           self.inPolygon(lat: raid.lat, lon: raid.lon, multiPolygon: polygon) {
                                        if raidIDs.contains(Int(raid.raidPokemonId ?? 0)) {
                                            continue
                                        }
                                        events.append(raid.getWebhookValues(type: WebhookType.raid.rawValue))
                                    }
                                }
                            }

                            if webhook.types.contains(.egg) {
                                let eggIDs = webhook.data["egg_ids"] as? [Int] ?? [Int]()
                                for (_, egg) in eggEvents {
                                    if area.isEmpty ||
                                           self.inPolygon(lat: egg.lat, lon: egg.lon, multiPolygon: polygon) {
                                        if eggIDs.contains(Int(egg.raidLevel ?? 0)) {
                                            continue
                                        }
                                        events.append(egg.getWebhookValues(type: WebhookType.egg.rawValue))
                                    }
                                }
                            }

                            if webhook.types.contains(.weather) {
                                let weatherIDs = webhook.data["weather_ids"] as? [Int] ?? [Int]()
                                for (_, weather) in weatherEvents {
                                    if area.isEmpty ||
                                           self.inPolygon(lat: weather.latitude, lon: weather.longitude,
                                               multiPolygon: polygon) {
                                        if weather.gameplayCondition > 0 && weatherIDs.contains(
                                                   Int(weather.gameplayCondition)) {
                                            continue
                                        }
                                        events.append(weather.getWebhookValues(type: WebhookType.weather.rawValue))
                                    }
                                }
                            }

                            if webhook.types.contains(.account) {
                                for (_, account) in accountEvents {
                                    events.append(account.getWebhookValues(type: WebhookType.account.rawValue))
                                }
                            }

                            if !events.isEmpty {
                                self.sendEvents(events: events, url: webhook.url)
                            }
                        }
                        Threading.sleep(seconds: minDelay != nil ? minDelay! : 5.0)
                    }
                }
            }
        }
    }

    private func sendEvents(events: [[String: Any]], url: String) {
        Log.debug(message: "[WebHookController] Sending \(events.count) events to" +
            "\(webhooks.count) endpoints")
        guard let body = try? events.jsonEncodedString() else {
            Log.error(message: "[WebHookController] Failed to parse events into json string")
            return
        }
        let byteArray = [UInt8](body.utf8)
        let request = CURLRequest(
            url,
            .httpMethod(.post),
            .postData(byteArray),
            .addHeader(.contentType, "application/json"),
            .addHeader(.accept, "application/json"),
            .addHeader(.cacheControl, "no-cache"),
            .addHeader(.userAgent, "RealDeviceMap \(VersionManager.global.version)"),
            .timeout(timeout),
            .connectTimeout(connectTimeout)
        )
        request.perform { (_) in }

    }

    private func createAreaArray(webhookArea: Any?) -> [[Coord]] {
        var areaArray = [[Coord]]()
        if webhookArea as? [[Coord]] != nil {
            areaArray = webhookArea as? [[Coord]] ?? [[Coord]]()
        } else {
            let areas = webhookArea as? [[[String: Double]]] ?? [[[String: Double]]]()
            var i = 0
            for coords in areas {
                for coord in coords {
                    while areaArray.count != i + 1 {
                        areaArray.append([Coord]())
                    }
                    areaArray[i].append(Coord(lat: coord["lat"]!, lon: coord["lon"]!))
                }
                i += 1
            }
        }
        return areaArray
    }

    private func createMultiPolygon(areaArray: [[Coord]]) -> MultiPolygon {
        var geofences = [[[CLLocationCoordinate2D]]]()
        for coord in areaArray {
            var geofence = [CLLocationCoordinate2D]()
            for crd in coord {
                geofence.append(CLLocationCoordinate2D.init(latitude: crd.lat, longitude: crd.lon))
            }
            geofences.append([geofence])
        }
        return MultiPolygon.init(geofences)
    }

    private func inPolygon(lat: Double, lon: Double, multiPolygon: MultiPolygon) -> Bool {
        for polygon in multiPolygon.polygons {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            if polygon.contains(coord, ignoreBoundary: false) {
                return true
            }
        }
        return false
    }
}
