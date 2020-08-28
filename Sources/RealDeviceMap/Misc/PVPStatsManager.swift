//
//  PVPStatsManager.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 23.05.20.
//
//  swiftlint:disable function_body_length function_parameter_count file_length type_body_length

import Foundation
import PerfectLib
import PerfectCURL
import PerfectThread
import POGOProtos

internal class PVPStatsManager {

    internal static let global = PVPStatsManager()

    private var stats = [PokemonWithForm: Stats]()
    private let rankingGreatLock = Threading.Lock()
    private var rankingGreat = [PokemonWithForm: ResponsesOrEvent]()
    private let rankingUltraLock = Threading.Lock()
    private var rankingUltra = [PokemonWithForm: ResponsesOrEvent]()
    private var eTag: String?
    private let updaterThread: ThreadQueue

    private init() {
        updaterThread = Threading.getQueue(name: "PVPMasterfileUpdater", type: .serial)
        updaterThread.dispatch {
            while true {
                Threading.sleep(seconds: 900)
                self.loadMasterFileIfNeeded()
            }
        }
        loadMasterFile()
    }

    private func loadMasterFileIfNeeded() {
        let request = CURLRequest(
            "https://raw.githubusercontent.com/pokemongo-dev-contrib/" +
            "pokemongo-game-master/master/versions/latest/GAME_MASTER.json",
            .httpMethod(.head)
        )
        guard let result = try? request.perform() else {
           Log.error(message: "[PVPStatsManager] Failed to load game master file")
           return
        }
        let newETag = result.get(.eTag)
        if newETag != eTag {
            Log.info(message: "[PVPStatsManager] Game master file changed")
            loadMasterFile()
        }
    }

    private func loadMasterFile() {
        Log.debug(message: "[PVPStatsManager] Loading game master file")
        let request = CURLRequest("https://raw.githubusercontent.com/pokemongo-dev-contrib/" +
                                  "pokemongo-game-master/master/versions/1595879989869/GAME_MASTER.json")
        guard let result = try? request.perform() else {
            Log.error(message: "[PVPStatsManager] Failed to load game master file")
            return
        }
        eTag = result.get(.eTag)
        Log.debug(message: "[PVPStatsManager] Parsing game master file")
        guard let templates = result.bodyJSON["itemTemplate"] as? [[String: Any]] else {
            Log.error(message: "[PVPStatsManager] Failed to parse game master file")
            return
        }
        var stats = [PokemonWithForm: Stats]()
        templates.forEach { (template) in
            guard let id = template["templateId"] as? String else { return }
            if id.starts(with: "V"), id.contains(string: "_POKEMON_"),
                let pokemonInfo = template["pokemon"] as? [String: Any],
                let pokemonName = pokemonInfo["uniqueId"] as? String,
                let statsInfo = pokemonInfo["stats"] as? [String: Any],
                let baseStamina = statsInfo["baseStamina"] as? Int,
                let baseAttack = statsInfo["baseAttack"] as? Int,
                let baseDefense = statsInfo["baseDefense"] as? Int {
                guard let pokemon = pokemonFrom(name: pokemonName) else {
                    Log.warning(message: "[PVPStatsManager] Failed to get pokemon for: \(pokemonName)")
                    return
                }
                let formName = pokemonInfo["form"] as? String
                let form: POGOProtos_Enums_Form?
                if let formName = formName {
                    guard let formT = formFrom(name: formName) else {
                        Log.warning(message: "[PVPStatsManager] Failed to get form for: \(formName)")
                        return
                    }
                    form = formT
                } else {
                    form = nil
                }
                var evolutions = [PokemonWithForm]()
                let evolutionsInfo = pokemonInfo["evolutionBranch"] as? [[String: Any]] ?? []
                for info in evolutionsInfo {
                    if let pokemonName = info["evolution"] as? String, let pokemon = pokemonFrom(name: pokemonName) {
                        let formName = info["form"] as? String
                        let form = formName == nil ? nil : formFrom(name: formName!)
                        evolutions.append(.init(pokemon: pokemon, form: form))
                    }
                }
                let stat = Stats(baseAttack: baseAttack, baseDefense: baseDefense,
                                  baseStamina: baseStamina, evolutions: evolutions)
                stats[.init(pokemon: pokemon, form: form)] = stat
            }
        }
        rankingGreatLock.lock()
        rankingUltraLock.lock()
        self.stats = stats
        self.rankingGreat = [:]
        self.rankingUltra = [:]
        rankingGreatLock.unlock()
        rankingUltraLock.unlock()
        Log.debug(message: "[PVPStatsManager] Done parsing game master file")
    }

    internal func getPVPStats(pokemon: POGOProtos_Enums_PokemonId, form: POGOProtos_Enums_Form?, iv: IV, level: Double,
                              league: League) -> Response? {
        guard let stats = getTopPVP(pokemon: pokemon, form: form, league: league) else {
            return nil
        }
        guard let index = stats.firstIndex(where: { value in
            for ivlevel in value.ivs where ivlevel.iv == iv && ivlevel.level >= level {
                return true
            }
            return false
        }) else {
            return nil
        }
        let max = Double(stats[0].rank)
        let result = stats[index]
        let value = Double(result.rank)
        let ivs: [Response.IVWithCP]
        if let currentIV = result.ivs.first(where: { return $0.iv == iv }) {
            ivs = [currentIV]
        } else {
            ivs = []
        }
        return .init(rank: index + 1, percentage: value/max, ivs: ivs)
    }

    internal func getPVPStatsWithEvolutions(pokemon: POGOProtos_Enums_PokemonId, form: POGOProtos_Enums_Form?,
                                            costume: POGOProtos_Enums_Costume, iv: IV, level: Double, league: League)
                                            -> [(pokemon: PokemonWithForm, response: Response?)] {
        let current = getPVPStats(pokemon: pokemon, form: form, iv: iv, level: level, league: league)
        let pokemonWithForm = PokemonWithForm(pokemon: pokemon, form: form)
        var result = [(pokemon: pokemonWithForm, response: current)]
        guard !String(describing: costume).lowercased().contains(string: "noevolve"),
              let stat = stats[pokemonWithForm],
              !stat.evolutions.isEmpty else {
            return result
        }
        for evolution in stat.evolutions {
            let pvpStats = getPVPStatsWithEvolutions(pokemon: evolution.pokemon, form: evolution.form,
                                                     costume: costume, iv: iv, level: level, league: league)
            result += pvpStats
        }
        return result
    }

    // swiftlint:disable:next cyclomatic_complexity
    internal func getTopPVP(pokemon: POGOProtos_Enums_PokemonId, form: POGOProtos_Enums_Form?,
                            league: League) -> [Response]? {
        let info = PokemonWithForm(pokemon: pokemon, form: form)
        let cached: ResponsesOrEvent?
        switch league {
        case .great:
            rankingGreatLock.lock()
            cached = rankingGreat[info]
            rankingGreatLock.unlock()
        case .ultra:
            rankingUltraLock.lock()
            cached = rankingUltra[info]
            rankingUltraLock.unlock()
        }

        if cached == nil {
            switch league {
            case .great:
                rankingGreatLock.lock()
            case .ultra:
                rankingUltraLock.lock()
            }
            guard let stats = stats[info] else {
                return nil
            }
            let event = Threading.Event()
            switch league {
            case .great:
                rankingGreat[info] = .event(event: event)
                rankingGreatLock.unlock()
            case .ultra:
                rankingUltra[info] = .event(event: event)
                rankingUltraLock.unlock()
            }
            let values = getPVPValuesOrdered(stats: stats, cap: league.rawValue)
            switch league {
            case .great:
                rankingGreatLock.lock()
                rankingGreat[info] = .responses(responses: values)
                rankingGreatLock.unlock()
            case .ultra:
                rankingUltraLock.lock()
                rankingUltra[info] = .responses(responses: values)
                rankingUltraLock.unlock()
            }
            event.lock()
            event.broadcast()
            event.unlock()
            return values
        }
        switch cached! {
        case .responses(let responses):
            return responses
        case .event(let event):
            event.lock()
            _ = event.wait(seconds: 10)
            event.unlock()
            return getTopPVP(pokemon: pokemon, form: form, league: league)
        }
    }

    private func getPVPValuesOrdered(stats: Stats, cap: Int?) -> [Response] {
        var ranking = [Int: Response]()
        for iv in IV.all {
            var maxLevel: Double = 0
            var maxCP: Int = 0
            for level in stride(from: 0.0, through: 40.0, by: 0.5).reversed() {
                let cp = (cap == nil ? 0 : getCPValue(iv: iv, level: level, stats: stats))
                if cp <= (cap ?? 0) {
                    maxLevel = level
                    maxCP = cp
                    break
                }
            }
            if maxLevel != 0 {
                let value = getPVPValue(iv: iv, level: maxLevel, stats: stats)
                if ranking[value] == nil {
                    ranking[value] = Response(rank: value, percentage: 0.0, ivs: [])
                }
                ranking[value]!.ivs.append(.init(iv: iv, level: maxLevel, cp: maxCP))
            }
        }
        return ranking.sorted { (lhs, rhs) -> Bool in
            return lhs.key >= rhs.key
        }.map { (value) -> Response in
            return value.value
        }
    }

    private func getPVPValue(iv: IV, level: Double, stats: Stats) -> Int {
        let mutliplier = (PVPStatsManager.cpMultiplier[level] ?? 0)
        let attack = Double(iv.attack + stats.baseAttack) * mutliplier
        let defense = Double(iv.defense + stats.baseDefense) * mutliplier
        let stamina = Double(iv.stamina + stats.baseStamina) * mutliplier
        return Int(round(attack * defense * floor(stamina)))
    }

    private func getCPValue(iv: IV, level: Double, stats: Stats) -> Int {
        let attack = Double(stats.baseAttack + iv.attack)
        let defense = pow(Double(stats.baseDefense + iv.defense), 0.5)
        let stamina =  pow(Double(stats.baseStamina + iv.stamina), 0.5)
        let multiplier = pow((PVPStatsManager.cpMultiplier[level] ?? 0), 2)
        return max(Int(floor(attack * defense * stamina * multiplier / 10)), 10)
    }

    private func formFrom(name: String) -> POGOProtos_Enums_Form? {
        return POGOProtos_Enums_Form.allCases.first { (form) -> Bool in
            return String(describing: form).lowercased() == name.replacingOccurrences(of: "_", with: "").lowercased()
        }
    }

    private func pokemonFrom(name: String) -> POGOProtos_Enums_PokemonId? {
        return POGOProtos_Enums_PokemonId.allCases.first { (pokemon) -> Bool in
            return String(describing: pokemon).lowercased() == name.replacingOccurrences(of: "_", with: "").lowercased()
        }
    }

}

extension PVPStatsManager {

    struct PokemonWithForm: Hashable {
        var pokemon: POGOProtos_Enums_PokemonId
        var form: POGOProtos_Enums_Form?
    }

    struct Stats {
        var baseAttack: Int
        var baseDefense: Int
        var baseStamina: Int
        var evolutions: [PokemonWithForm]
    }

    struct IV: Equatable {
        var attack: Int
        var defense: Int
        var stamina: Int

        static var all: [IV] {
            var all = [IV]()
            for attack in 0...15 {
                for defense in 0...15 {
                    for stamina in 0...15 {
                        all.append(IV(
                            attack: attack,
                            defense: defense,
                            stamina: stamina
                        ))
                    }
                }
            }
            return all
        }
    }

    enum ResponsesOrEvent {
        case responses(responses: [Response])
        case event(event: Threading.Event)
    }

    struct Response {
        struct IVWithCP {
            var iv: IV
            var level: Double
            var cp: Int
        }
        var rank: Int
        var percentage: Double
        var ivs: [IVWithCP]
    }

    enum League: Int {
        case great = 1500
        case ultra = 2500
    }

    private static let cpMultiplier = [
        1: 0.09399999678134918,
        1.5: 0.13513743132352830,
        2: 0.16639786958694458,
        2.5: 0.19265091419219970,
        3: 0.21573247015476227,
        3.5: 0.23657265305519104,
        4: 0.25572004914283750,
        4.5: 0.27353037893772125,
        5: 0.29024988412857056,
        5.5: 0.30605737864971160,
        6: 0.32108759880065920,
        6.5: 0.33544503152370453,
        7: 0.34921267628669740,
        7.5: 0.36245773732662200,
        8: 0.37523558735847473,
        8.5: 0.38759241108516856,
        9: 0.39956727623939514,
        9.5: 0.41119354951725060,
        10: 0.4225000143051148,
        10.5: 0.4329264134104144,
        11: 0.4431075453758240,
        11.5: 0.4530599538719858,
        12: 0.4627983868122100,
        12.5: 0.4723360780626535,
        13: 0.4816849529743195,
        13.5: 0.4908558102324605,
        14: 0.4998584389686584,
        14.5: 0.5087017565965652,
        15: 0.5173939466476440,
        15.5: 0.5259425118565559,
        16: 0.5343543291091919,
        16.5: 0.5426357612013817,
        17: 0.5507926940917969,
        17.5: 0.5588305993005633,
        18: 0.5667545199394226,
        18.5: 0.5745691470801830,
        19: 0.5822789072990417,
        19.5: 0.5898879119195044,
        20: 0.5974000096321106,
        20.5: 0.6048236563801765,
        21: 0.6121572852134705,
        21.5: 0.6194041110575199,
        22: 0.6265671253204346,
        22.5: 0.6336491815745830,
        23: 0.6406529545783997,
        23.5: 0.6475809663534164,
        24: 0.6544356346130370,
        24.5: 0.6612192690372467,
        25: 0.6679340004920960,
        25.5: 0.6745819002389908,
        26: 0.6811649203300476,
        26.5: 0.6876849085092545,
        27: 0.6941436529159546,
        27.5: 0.7005428969860077,
        28: 0.7068842053413391,
        28.5: 0.7131690979003906,
        29: 0.7193990945816040,
        29.5: 0.7255756109952927,
        30: 0.7317000031471252,
        30.5: 0.7347410172224045,
        31: 0.7377694845199585,
        31.5: 0.7407855764031410,
        32: 0.7437894344329834,
        32.5: 0.7467812150716782,
        33: 0.7497610449790955,
        33.5: 0.7527291029691696,
        34: 0.7556855082511902,
        34.5: 0.7586303651332855,
        35: 0.7615638375282288,
        35.5: 0.7644860669970512,
        36: 0.7673971652984619,
        36.5: 0.7702972739934921,
        37: 0.7731865048408508,
        37.5: 0.7760649472475052,
        38: 0.7789327502250671,
        38.5: 0.78179006,
        39: 0.78463697,
        39.5: 0.78747358,
        40: 0.79030001
    ]
}
