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
import PerfectCURL

class WebHookController {

    private init() {}

    public private(set) static var global = WebHookController()

    public var webhookURLStrings = [String]()
    public var webhookSendDelay = 5.0

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

    public func addInvasionEvent(pokestop: Pokestop) {
        if !self.webhookURLStrings.isEmpty {
            invasionEventLock.lock()
            invasionEvents[pokestop.id] = pokestop
            invasionEventLock.unlock()
        }
    }

    public func addQuestEvent(pokestop: Pokestop) {
        if !self.webhookURLStrings.isEmpty {
            questEventLock.lock()
            questEvents[pokestop.id] = pokestop
            questEventLock.unlock()
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

    public func addWeatherEvent(weather: Weather) {
        if !self.webhookURLStrings.isEmpty {
            weatherEventLock.lock()
            weatherEvents[weather.id] = weather
            weatherEventLock.unlock()
        }
    }

    public func addAccountEvent(account: Account) {
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
                        for pokemonEvent in self.pokemonEvents {
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
                            events.append(lureEvent.value.getWebhookValues(type: "lure"))
                        }
                        self.lureEvents = [String: Pokestop]()
                        self.lureEventLock.unlock()

                        self.invasionEventLock.lock()
                        for invasionEvent in self.invasionEvents {
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
                            events.append(gymEvent.value.getWebhookValues(type: "gym"))
                        }
                        self.gymEvents = [String: Gym]()
                        self.gymEventLock.unlock()

                        self.gymInfoEventLock.lock()
                        for gymInfoEvent in self.gymInfoEvents {
                            events.append(gymInfoEvent.value.getWebhookValues(type: "gym-info"))
                        }
                        self.gymInfoEvents = [String: Gym]()
                        self.gymInfoEventLock.unlock()

                        self.raidEventLock.lock()
                        for raidEvent in self.raidEvents {
                            events.append(raidEvent.value.getWebhookValues(type: "raid"))
                        }
                        self.raidEvents = [String: Gym]()
                        self.raidEventLock.unlock()

                        self.eggEventLock.lock()
                        for eggEvent in self.eggEvents {
                            events.append(eggEvent.value.getWebhookValues(type: "egg"))
                        }
                        self.eggEvents = [String: Gym]()
                        self.eggEventLock.unlock()

                        self.weatherEventLock.lock()
                        for weatherEvent in self.weatherEvents {
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
                            for url in self.webhookURLStrings {
                                self.sendEvents(events: events, url: url)
                            }
                        }

                    }

                    Threading.sleep(seconds: self.webhookSendDelay)
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

        let request = CURLRequest(
            url,
            .httpMethod(.post),
            .postData(byteArray),
            .addHeader(.contentType, "application/json"),
            .addHeader(.accept, "application/json"),
            .addHeader(.cacheControl, "no-cache"),
            .addHeader(.userAgent, "RealDeviceMap \(VersionManager.global.version)")
        )
        request.perform { (_) in }
    }

}
