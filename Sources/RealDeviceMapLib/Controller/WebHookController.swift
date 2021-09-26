//
//  WebHookController.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 03.10.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity

import Foundation
import PerfectLib
import PerfectThread
import PerfectCURL

public class WebHookController {

    private init() {
        let environment = ProcessInfo.processInfo.environment
        timeout = environment["WEBHOOK_ENDPOINT_TIMEOUT"]?.toInt() ?? 30
        connectTimeout = environment["WEBHOOK_ENDPOINT_CONNECT_TIMEOUT"]?.toInt() ?? 30
    }

    public private(set) static var global = WebHookController()

    public var webhookURLStrings = [String]()
    public var webhookSendDelay = 5.0

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
        print("[TEST] addPokemonEvent \(pokemon.id) (urls: \(webhookURLStrings.count))")
        if !self.webhookURLStrings.isEmpty {
            pokemonEventLock.lock()
            pokemonEvents[pokemon.id] = pokemon
            pokemonEventLock.unlock()
        }
    }

    public func addPokestopEvent(pokestop: Pokestop) {
        print("[TEST] addPokestopEvent \(pokestop.id) (urls: \(webhookURLStrings.count))")
        if !self.webhookURLStrings.isEmpty {
            pokestopEventLock.lock()
            pokestopEvents[pokestop.id] = pokestop
            pokestopEventLock.unlock()
        }
    }

    public func addLureEvent(pokestop: Pokestop) {
        print("[TEST] addLureEvent \(pokestop.id) (urls: \(webhookURLStrings.count))")
        if !self.webhookURLStrings.isEmpty {
            lureEventLock.lock()
            lureEvents[pokestop.id] = pokestop
            lureEventLock.unlock()
        }
    }

    public func addInvasionEvent(pokestop: Pokestop) {
        print("[TEST] addInvasionEvent \(pokestop.id) (urls: \(webhookURLStrings.count))")
        if !self.webhookURLStrings.isEmpty {
            invasionEventLock.lock()
            invasionEvents[pokestop.id] = pokestop
            invasionEventLock.unlock()
        }
    }

    public func addQuestEvent(pokestop: Pokestop) {
        print("[TEST] addQuestEvent \(pokestop.id) (urls: \(webhookURLStrings.count))")
        if !self.webhookURLStrings.isEmpty {
            questEventLock.lock()
            questEvents[pokestop.id] = pokestop
            questEventLock.unlock()
        }
    }

    public func addGymEvent(gym: Gym) {
        print("[TEST] addGymEvent \(gym.id) (urls: \(webhookURLStrings.count))")
        if !self.webhookURLStrings.isEmpty {
            gymEventLock.lock()
            gymEvents[gym.id] = gym
            gymEventLock.unlock()
        }
    }

    public func addGymInfoEvent(gym: Gym) {
        print("[TEST] addGymInfoEvent \(gym.id) (urls: \(webhookURLStrings.count))")
        if !self.webhookURLStrings.isEmpty {
            gymInfoEventLock.lock()
            gymInfoEvents[gym.id] = gym
            gymInfoEventLock.unlock()
        }
    }

    public func addEggEvent(gym: Gym) {
        print("[TEST] addEggEvent \(gym.id) (urls: \(webhookURLStrings.count))")
        if !self.webhookURLStrings.isEmpty {
            eggEventLock.lock()
            eggEvents[gym.id] = gym
            eggEventLock.unlock()
        }
    }

    public func addRaidEvent(gym: Gym) {
        print("[TEST] addRaidEvent \(gym.id) (urls: \(webhookURLStrings.count))")
        if !self.webhookURLStrings.isEmpty {
            raidEventLock.lock()
            raidEvents[gym.id] = gym
            raidEventLock.unlock()
        }
    }

    public func addWeatherEvent(weather: Weather) {
        print("[TEST] addWeatherEvent \(weather.id) (urls: \(webhookURLStrings.count))")
        if !self.webhookURLStrings.isEmpty {
            weatherEventLock.lock()
            weatherEvents[weather.id] = weather
            weatherEventLock.unlock()
        }
    }

    public func addAccountEvent(account: Account) {
        print("[TEST] addAccountEvent \(account.username) (urls: \(webhookURLStrings.count))")
        if !self.webhookURLStrings.isEmpty {
            accountEventLock.lock()
            accountEvents[account.username] = account
            accountEventLock.unlock()
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
                        let pokemonEvents = self.pokemonEvents
                        self.pokemonEvents = [:]
                        self.pokemonEventLock.unlock()
                        print("[TEST] pokemonEvents \(pokemonEvents.count) (urls: \(self.webhookURLStrings.count))")
                        events += pokemonEvents.map({$0.value.getWebhookValues(type: "pokemon")})

                        self.pokestopEventLock.lock()
                        let pokestopEvents = self.pokestopEvents
                        self.pokestopEvents = [:]
                        self.pokestopEventLock.unlock()
                        print("[TEST] pokestopEvents \(pokestopEvents.count) (urls: \(self.webhookURLStrings.count))")
                        events += pokestopEvents.map({$0.value.getWebhookValues(type: "pokestop")})

                        self.lureEventLock.lock()
                        let lureEvents = self.lureEvents
                        self.lureEvents = [:]
                        self.lureEventLock.unlock()
                        print("[TEST] lureEvents \(lureEvents.count) (urls: \(self.webhookURLStrings.count))")
                        events += lureEvents.map({$0.value.getWebhookValues(type: "lure")})

                        self.invasionEventLock.lock()
                        let invasionEvents = self.invasionEvents
                        self.invasionEvents = [String: Pokestop]()
                        self.invasionEventLock.unlock()
                        print("[TEST] invasionEvents \(invasionEvents.count) (urls: \(self.webhookURLStrings.count))")
                        events += invasionEvents.map({$0.value.getWebhookValues(type: "invasion")})

                        self.questEventLock.lock()
                        let questEvents = self.questEvents
                        self.questEvents = [String: Pokestop]()
                        self.questEventLock.unlock()
                        print("[TEST] questEvents \(questEvents.count) (urls: \(self.webhookURLStrings.count))")
                        events += questEvents.map({$0.value.getWebhookValues(type: "quest")})

                        self.gymEventLock.lock()
                        let gymEvents = self.gymEvents
                        self.gymEvents = [String: Gym]()
                        self.gymEventLock.unlock()
                        print("[TEST] gymEvents \(gymEvents.count) (urls: \(self.webhookURLStrings.count))")
                        events += gymEvents.map({$0.value.getWebhookValues(type: "gym")})

                        self.gymInfoEventLock.lock()
                        let gymInfoEvents = self.gymInfoEvents
                        self.gymInfoEvents = [String: Gym]()
                        self.gymInfoEventLock.unlock()
                        print("[TEST] gymInfoEvents \(gymInfoEvents.count) (urls: \(self.webhookURLStrings.count))")
                        events += gymInfoEvents.map({$0.value.getWebhookValues(type: "gym-info")})

                        self.raidEventLock.lock()
                        let raidEvents = self.raidEvents
                        self.raidEvents = [String: Gym]()
                        self.raidEventLock.unlock()
                        print("[TEST] raidEvents \(raidEvents.count) (urls: \(self.webhookURLStrings.count))")
                        events += raidEvents.map({$0.value.getWebhookValues(type: "raid")})

                        self.eggEventLock.lock()
                        let eggEvents = self.eggEvents
                        self.eggEvents = [String: Gym]()
                        self.eggEventLock.unlock()
                        print("[TEST] eggEvents \(eggEvents.count) (urls: \(self.webhookURLStrings.count))")
                        events += eggEvents.map({$0.value.getWebhookValues(type: "egg")})

                        self.weatherEventLock.lock()
                        let weatherEvents = self.weatherEvents
                        self.weatherEvents = [Int64: Weather]()
                        self.weatherEventLock.unlock()
                        print("[TEST] weatherEvents \(weatherEvents.count) (urls: \(self.webhookURLStrings.count))")
                        events += weatherEvents.map({$0.value.getWebhookValues(type: "weather")})

                        self.accountEventLock.lock()
                        let accountEvents = self.accountEvents
                        self.accountEvents = [String: Account]()
                        self.accountEventLock.unlock()
                        print("[TEST] accountEvents \(accountEvents.count) (urls: \(self.webhookURLStrings.count))")
                        events += accountEvents.map({$0.value.getWebhookValues(type: "account")})

                        print("[TEST] events \(events.count) (urls: \(self.webhookURLStrings.count))")
                        if !events.isEmpty {
                            Log.debug(message: "[WebHookController] Sending \(events.count) events to" +
                                               "\(self.self.webhookURLStrings.count) endpoints")
                            guard let body = events.jsonEncodeForceTry() else {
                                Log.error(message: "[WebHookController] Failed to parse events into json string")
                                continue
                            }
                            let byteArray = [UInt8](body.utf8)
                            for url in self.webhookURLStrings {
                                self.sendEvents(data: byteArray, url: url)
                            }
                        }

                    }

                    Threading.sleep(seconds: self.webhookSendDelay)
                }
            }
        }

    }

    private func sendEvents(data: [UInt8], url: String) {
        let request = CURLRequest(
            url,
            .httpMethod(.post),
            .postData(data),
            .addHeader(.contentType, "application/json"),
            .addHeader(.accept, "application/json"),
            .addHeader(.cacheControl, "no-cache"),
            .addHeader(.userAgent, "RealDeviceMapLib \(VersionManager.global.version)"),
            .timeout(timeout),
            .connectTimeout(connectTimeout)
        )
        request.perform { (_) in }
    }

}
