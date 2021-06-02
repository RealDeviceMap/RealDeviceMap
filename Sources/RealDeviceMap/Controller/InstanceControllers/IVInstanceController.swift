//
//  IVInstanceController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 06.11.18.
//

import Foundation
import PerfectLib
import PerfectThread
import PerfectMySQL
import Turf

class IVInstanceController: InstanceControllerProto {

    public private(set) var name: String
    public private(set) var minLevel: UInt8
    public private(set) var maxLevel: UInt8
    public private(set) var accountGroup: String?
    public private(set) var isEvent: Bool
    public private(set) var scatterPokemon: [UInt16]

    public weak var delegate: InstanceControllerDelegate?

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
    private var shouldExit = false
    private var ivQueueLimit = 100

    // swiftlint:disable:next function_body_length
    init(name: String, multiPolygon: MultiPolygon, pokemonList: [UInt16], minLevel: UInt8,
         maxLevel: UInt8, ivQueueLimit: Int, scatterPokemon: [UInt16], accountGroup: String?,
         isEvent: Bool) {
        self.name = name
        self.minLevel = minLevel
        self.maxLevel = maxLevel
        self.accountGroup = accountGroup
        self.isEvent = isEvent
        self.multiPolygon = multiPolygon
        self.pokemonList = pokemonList
        self.ivQueueLimit = ivQueueLimit
        self.scatterPokemon = scatterPokemon

        checkScannedThreadingQueue = Threading.getQueue(name: "\(name)-check-scanned", type: .serial)
        checkScannedThreadingQueue!.dispatch {

            while !self.shouldExit {

                self.scannedPokemonLock.lock()
                if self.scannedPokemon.isEmpty {
                    self.scannedPokemonLock.unlock()
                    Threading.sleep(seconds: 5.0)
                    if self.shouldExit {
                        return
                    }
                } else {
                    let first = self.scannedPokemon.removeFirst()
                    self.scannedPokemonLock.unlock()
                    let timeSince = Date().timeIntervalSince(first.0)
                    if timeSince < 120 {
                        Threading.sleep(seconds: 120 - timeSince)
                        if self.shouldExit {
                            return
                        }
                    }
                    var success = false
                    var pokemonReal: Pokemon?
                    while !success {
                        do {
                            pokemonReal = try Pokemon.getWithId(id: first.1.id, isEvent: first.1.isEvent)
                            success = true
                        } catch {
                            Threading.sleep(seconds: 1.0)
                            if self.shouldExit {
                                return
                            }
                        }
                    }
                    if let pokemonReal = pokemonReal {
                        if pokemonReal.atkIv == nil {
                            Log.debug(message: "[IVInstanceController] [\(name)] Checked Pokemon doesn't have IV")
                            self.gotPokemon(pokemon: pokemonReal)
                        } else {
                            Log.debug(message: "[IVInstanceController] [\(name)] Checked Pokemon has IV")
                        }
                    }

                }

            }

        }
    }

    deinit {
        stop()
    }

    func getTask(mysql: MySQL, uuid: String, username: String?, account: Account?) -> [String: Any] {

        pokemonLock.lock()
        if pokemonQueue.isEmpty {
            pokemonLock.unlock()
            return [String: Any]()
        }
        let pokemon = pokemonQueue.removeFirst()
        pokemonLock.unlock()

        if UInt32(Date().timeIntervalSince1970) - (pokemon.firstSeenTimestamp ?? 1) >= 600 {
            return getTask(mysql: mysql, uuid: uuid, username: username, account: account)
        }

        scannedPokemonLock.lock()
        scannedPokemon.append((Date(), pokemon))
        scannedPokemonLock.unlock()

        return ["action": "scan_iv", "lat": pokemon.lat, "lon": pokemon.lon, "id": pokemon.id,
                "is_spawnpoint": pokemon.spawnId != nil, "min_level": minLevel, "max_level": maxLevel]
    }

    func getStatus(mysql: MySQL, formatted: Bool) -> JSONConvertible? {

        let ivh: Int?
        self.statsLock.lock()
        if self.startDate != nil {
            ivh = Int(Double(self.count) / Date().timeIntervalSince(self.startDate!) * 3600)
        } else {
            ivh = nil
        }
        self.statsLock.unlock()
        if formatted {
            let ivhString: String
            if ivh == nil {
                ivhString = "-"
            } else {
                ivhString = "\(ivh!)"
            }
            return "<a href=\"/dashboard/instance/ivqueue/\(name.encodeUrl() ?? "")\">Queue" +
                   "</a>: \(pokemonQueue.count), IV/h: \(ivhString)"
        } else {
            return ["iv_per_hour": ivh]
        }
    }

    func reload() {}

    func stop() {
        self.shouldExit = true
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

    func gotPokemon(pokemon: Pokemon) {
        if (pokemon.pokestopId != nil || pokemon.spawnId != nil) &&
           pokemon.isEvent == isEvent &&
           pokemonList.contains(pokemon.pokemonId) &&
           multiPolygon.contains(CLLocationCoordinate2D(latitude: pokemon.lat, longitude: pokemon.lon)) {
            pokemonLock.lock()

            if pokemonQueue.contains(pokemon) {
                pokemonLock.unlock()
                return
            }

            let index = lastIndexOf(pokemonId: pokemon.pokemonId)

            if pokemonQueue.count >= ivQueueLimit && index == nil {
                Log.debug(message: "[IVInstanceController] [\(name)] Queue is full!")
            } else if pokemonQueue.count >= ivQueueLimit {
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

    func gotIV(pokemon: Pokemon) {

        if multiPolygon.contains(CLLocationCoordinate2D(latitude: pokemon.lat, longitude: pokemon.lon)) {

            pokemonLock.lock()
            if let index = pokemonQueue.firstIndex(of: pokemon) {
                pokemonQueue.remove(at: index)
            }
            // Re-Scan 100% none event Pokemon
            if isEvent && !pokemon.isEvent && (
                pokemon.atkIv == 15 || pokemon.atkIv == 0 || pokemon.atkIv == 1
               ) && pokemon.defIv == 15 && pokemon.staIv == 15 {
                pokemon.isEvent = true
                pokemonQueue.insert(pokemon, at: 0)
            }
            pokemonLock.unlock()

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

    private func lastIndexOf(pokemonId: UInt16) -> Int? {

        guard let targetPriority = pokemonList.firstIndex(of: pokemonId) else {
            return nil
        }

        var i = 0
        for pokemon in pokemonQueue {
            if let priority = pokemonList.firstIndex(of: pokemon.pokemonId), targetPriority < priority {
                return i
            }
            i += 1
        }

        return nil

    }

    func getAccount(mysql: MySQL, uuid: String) throws -> Account? {
        return try Account.getNewAccount(
            mysql: mysql,
            minLevel: minLevel,
            maxLevel: maxLevel,
            ignoringWarning: false,
            spins: nil,
            noCooldown: false,
            device: uuid,
            group: accountGroup
        )
    }

    func accountValid(account: Account) -> Bool {
        return
            account.level >= minLevel &&
            account.level <= maxLevel &&
            account.isValid(group: accountGroup)
    }

}
