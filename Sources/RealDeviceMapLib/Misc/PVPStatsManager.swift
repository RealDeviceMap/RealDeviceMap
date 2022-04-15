//
//  PVPStatsManager.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 23.05.20.
//
//  swiftlint:disable function_body_length function_parameter_count file_length type_body_length

import Foundation
import PerfectLib
import PerfectCURL
import PerfectThread
import POGOProtos

public class PVPStatsManager {

    public static let global = PVPStatsManager()
    internal static var defaultPVPRank: RankType = .dense
    internal static var lvlCaps: [Int] = [50]
    internal static var leagueFilter: [Int: Int] = [ 500: 450, 1500: 1400, 2500: 2350 ]

    private var stats = [PokemonWithFormAndGender: Stats]()
    private let rankingLittleLock = Threading.Lock()
    private var rankingLittle = [PokemonWithFormAndGender: ResponsesOrEvent]()
    private let rankingGreatLock = Threading.Lock()
    private var rankingGreat = [PokemonWithFormAndGender: ResponsesOrEvent]()
    private let rankingUltraLock = Threading.Lock()
    private var rankingUltra = [PokemonWithFormAndGender: ResponsesOrEvent]()
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
            "https://raw.githubusercontent.com/PokeMiners/" +
            "game_masters/master/latest/latest.json",
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
        let request = CURLRequest("https://raw.githubusercontent.com/PokeMiners/" +
                                  "game_masters/master/latest/latest.json")
        guard let result = try? request.perform() else {
            Log.error(message: "[PVPStatsManager] Failed to load game master file")
            return
        }
        eTag = result.get(.eTag)
        Log.debug(message: "[PVPStatsManager] Parsing game master file")
        let bodyJSON = try? JSONSerialization.jsonObject(with: Data(result.bodyBytes))
        guard let templates = bodyJSON as? [[String: Any]] else {
            Log.error(message: "[PVPStatsManager] Failed to parse game master file")
            return
        }
        var stats = [PokemonWithFormAndGender: Stats]()
        templates.forEach { (template) in
            guard let data = template["data"] as? [String: Any] else { return }
            guard let templateId = data["templateId"] as? String else { return }
            if templateId.starts(with: "V"), templateId.contains(string: "_POKEMON_"),
                let pokemonInfo = data["pokemonSettings"] as? [String: Any],
                let pokemonName = pokemonInfo["pokemonId"] as? String,
                let statsInfo = pokemonInfo["stats"] as? [String: Any],
                let pokedexHeightM = pokemonInfo["pokedexHeightM"] as? Double,
                let pokedexWeightKg = pokemonInfo["pokedexWeightKg"] as? Double,
                let baseStamina = statsInfo["baseStamina"] as? Int,
                let baseAttack = statsInfo["baseAttack"] as? Int,
                let baseDefense = statsInfo["baseDefense"] as? Int {
                guard let pokemon = pokemonFrom(name: pokemonName) else {
                    Log.warning(message: "[PVPStatsManager] Failed to get pokemon for: \(pokemonName)")
                    return
                }
                let formName = pokemonInfo["form"] as? String
                let form: PokemonDisplayProto.Form?
                if let formName = formName {
                    guard let formT = formFrom(name: formName) else {
                        Log.warning(message: "[PVPStatsManager] Failed to get form for: \(formName)")
                        return
                    }
                    form = formT
                } else {
                    form = nil
                }
                var evolutions = [PokemonWithFormAndGender]()
                let evolutionsInfo = pokemonInfo["evolutionBranch"] as? [[String: Any]] ?? []
                for info in evolutionsInfo {
                    if let pokemonName = info["evolution"] as? String, let pokemon = pokemonFrom(name: pokemonName) {
                        let formName = info["form"] as? String
                        let genderName = info["genderRequirement"] as? String
                        let form = formName == nil ? nil : formFrom(name: formName!)
                        let gender = genderName == nil ? nil : genderFrom(name: genderName!)
                        evolutions.append(.init(pokemon: pokemon, form: form, gender: gender))
                    }
                }
                let stat = Stats(baseAttack: baseAttack, baseDefense: baseDefense,
                                  baseStamina: baseStamina, evolutions: evolutions,
                                  baseHeight: pokedexHeightM, baseWeight: pokedexWeightKg)
                stats[.init(pokemon: pokemon, form: form)] = stat
            }
        }
        rankingLittleLock.lock()
        rankingGreatLock.lock()
        rankingUltraLock.lock()
        self.stats = stats
        self.rankingLittle = [:]
        self.rankingGreat = [:]
        self.rankingUltra = [:]
        rankingLittleLock.unlock()
        rankingGreatLock.unlock()
        rankingUltraLock.unlock()
        Log.debug(message: "[PVPStatsManager] Done parsing game master file")
    }

    internal func getPVPStats(pokemon: HoloPokemonId, form: PokemonDisplayProto.Form?,
                              iv: IV, level: Double, league: League) -> [Response] {
        guard let stats = getTopPVP(pokemon: pokemon, form: form, league: league) else {
            return [Response]()
        }

        var rankings = [Response]()
        var lastRank: Response?
        for lvlCap in PVPStatsManager.lvlCaps {
            var competitionIndex: Int = 0
            var denseIndex: Int = 0
            var ordinalIndex: Int = 0
            var foundMatch: Bool = false
            var rank: Response?
            let filteredStats = stats.filter({ $0.cap == lvlCap })
            statLoop: for stat in filteredStats {
                competitionIndex = ordinalIndex
                for ivlevel in stat.ivs {
                    if ivlevel.iv == iv && ivlevel.level >= level {
                        foundMatch = true
                        rank = stat
                        break statLoop
                    }
                    ordinalIndex += 1
                }
                denseIndex += 1
            }
            if foundMatch == false {
                continue
            }

            // debug print BEGIN

            if pokemon.rawValue == 25 && league == .ultra && iv.attack == 15 && iv.defense == 15 && iv.stamina == 14 {
                Log.info(message: "[TMP] pikachu stats \(iv): \n\(filteredStats)\n")
            }
            if pokemon.rawValue == 133 && (league == .great || league == .ultra) && iv.attack == 0 && iv.defense == 15 &&
                   (iv.stamina == 15 || iv.stamina == 14) {
                Log.info(message: "[TMP] umbreon stats \(iv): \n\(filteredStats)\n")
            }
            if pokemon.rawValue == 661 && league == .ultra && iv.attack == 15 && iv.defense == 15 && iv.stamina == 15 {
                Log.info(message: "[TMP] fletchling stats \(iv): \n\(filteredStats)\n")
            }
            if pokemon.rawValue == 32 && league == .little && iv.attack == 0 && iv.defense == 15 &&
                   (iv.stamina == 11 || iv.stamina == 12) {
                Log.info(message: "[TMP] nidoran male stats \(iv): \n\(filteredStats)\n")
            }

            // debug print END

            let max = Double(filteredStats[0].competitionRank)
            let value = Double(rank!.competitionRank)
            let ivs: [Response.IVWithCP]
            if let currentIV = rank!.ivs.first(where: { $0.iv == iv }) {
                ivs = [currentIV]
            } else {
                ivs = []
            }

            if lastRank != nil, let lastStat = lastRank!.ivs.first, let stat = ivs.first,
               lastStat.level == stat.level && lastRank!.competitionRank == competitionIndex + 1 &&
               lastStat.iv.attack == stat.iv.attack && lastStat.iv.defense == stat.iv.defense &&
               lastStat.iv.stamina == stat.iv.stamina {
                if let index = rankings.firstIndex(where: { $0.competitionRank == lastRank!.competitionRank }) {
                    lastRank!.capped = true
                    rankings[index] = lastRank!
                }
            } else {
                lastRank = Response(competitionRank: competitionIndex + 1,
                    denseRank: denseIndex + 1,
                    ordinalRank: ordinalIndex + 1,
                    percentage: value/max,
                    cap: rank!.cap,
                    capped: false,
                    ivs: ivs)
                rankings.append(lastRank!)
            }
        }
        return rankings
    }

    internal func getPVPAllLeagues(pokemon: HoloPokemonId, form: PokemonDisplayProto.Form?,
                                   gender: PokemonDisplayProto.Gender?, costume: PokemonDisplayProto.Costume, iv: IV,
                                   level: Double) -> [String: Any]? {
        var pvp: [String: Any] = [:]
        League.allCases.forEach({ (league)  in
            let stats = getPVPStatsWithEvolutions(pokemon: pokemon, form: form, gender: gender,
                costume: costume, iv: iv, level: level, league: league)
                    .map({ (ranking) -> [String: Any] in
                        let rank: Any
                        switch PVPStatsManager.defaultPVPRank {
                        case .dense: rank = ranking.response.denseRank as Any
                        case .competition: rank = ranking.response.competitionRank as Any
                        case .ordinal: rank = ranking.response.ordinalRank as Any
                        }
                        var json = [
                            "pokemon": ranking.pokemon.pokemon.rawValue,
                            "form": ranking.pokemon.form?.rawValue ?? 0,
                            "gender": ranking.pokemon.gender?.rawValue ?? 0,
                            "rank": rank,
                            "percentage": ranking.response.percentage as Any,
                            "cp": ranking.response.ivs.first?.cp as Any,
                            "level": ranking.response.ivs.first?.level as Any,
                            "competition_rank": ranking.response.competitionRank as Any,
                            "dense_rank": ranking.response.denseRank as Any,
                            "ordinal_rank": ranking.response.ordinalRank as Any,
                            "cap": ranking.response.cap as Any
                        ]
                        if ranking.response.capped {
                            json["capped"] = true
                        }
                        return json
                    })
            if !stats.isEmpty {
                // only add stats if not empty to prevent empty list in JSON result
                pvp[league.toString()] = stats
            }
        })
        return (pvp.isEmpty ? nil : pvp)
    }

    internal func getPVPStatsWithEvolutions(pokemon: HoloPokemonId, form: PokemonDisplayProto.Form?,
                                            gender: PokemonDisplayProto.Gender?,
                                            costume: PokemonDisplayProto.Costume, iv: IV, level: Double, league: League)
                                            -> [(pokemon: PokemonWithFormAndGender, response: Response)] {
        let rankings = getPVPStats(pokemon: pokemon, form: form, iv: iv, level: level, league: league)
        var result = [(pokemon: PokemonWithFormAndGender, response: Response)]()
        for current in rankings {
            result.append((
                pokemon: PokemonWithFormAndGender(pokemon: pokemon, form: form, gender: gender),
                response: current
            ))
        }
        guard !String(describing: costume).lowercased().contains(string: "noevolve"),
              let stat = stats[.init(pokemon: pokemon, form: form)],
              !stat.evolutions.isEmpty else {
            return result
        }
        for evolution in stat.evolutions {
            if evolution.gender == nil || evolution.gender == gender {
                let pvpStats = getPVPStatsWithEvolutions(
                        pokemon: evolution.pokemon, form: evolution.form,
                        gender: gender, costume: costume, iv: iv, level: level, league: league
                )
                result += pvpStats
            }
        }
        return result
    }

    // swiftlint:disable:next cyclomatic_complexity
    internal func getTopPVP(pokemon: HoloPokemonId, form: PokemonDisplayProto.Form?,
                            league: League) -> [Response]? {
        let info = PokemonWithFormAndGender(pokemon: pokemon, form: form)
        let cached: ResponsesOrEvent?
        switch league {
        case .little:
            cached = rankingLittleLock.doWithLock { rankingLittle[info] }
        case .great:
            cached = rankingGreatLock.doWithLock { rankingGreat[info] }
        case .ultra:
            cached = rankingUltraLock.doWithLock { rankingUltra[info] }
        }

        if cached == nil {
            switch league {
            case .little:
                rankingLittleLock.lock()
            case .great:
                rankingGreatLock.lock()
            case .ultra:
                rankingUltraLock.lock()
            }
            guard let stats = stats[info] else {
                switch league {
                case .little:
                    rankingLittleLock.unlock()
                case .great:
                    rankingGreatLock.unlock()
                case .ultra:
                    rankingUltraLock.unlock()
                }
                return nil
            }
            let event = Threading.Event()
            switch league {
            case .little:
                rankingLittle[info] = .event(event: event)
                rankingLittleLock.unlock()
            case .great:
                rankingGreat[info] = .event(event: event)
                rankingGreatLock.unlock()
            case .ultra:
                rankingUltra[info] = .event(event: event)
                rankingUltraLock.unlock()
            }
            let values = calculateAllRanks(stats: stats, cpCap: league.rawValue)
            switch league {
            case .little:
                rankingLittleLock.doWithLock { rankingLittle[info] = .responses(responses: values) }
            case .great:
                rankingGreatLock.doWithLock { rankingGreat[info] = .responses(responses: values) }
            case .ultra:
                rankingUltraLock.doWithLock { rankingUltra[info] = .responses(responses: values) }
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

    func calculateAllRanks(stats: Stats, cpCap: Int) -> [Response] {
        var ranking = [Response]()
        for lvlCap in PVPStatsManager.lvlCaps {
            if calculateCP(stats: stats, iv: IV.hundo, level: Double(lvlCap)) <= PVPStatsManager.leagueFilter[cpCap]! {
                continue
            }
            ranking += calculatePvPStat(stats: stats, cpCap: cpCap, lvlCap: lvlCap)
                    .sorted { (lhs, rhs) -> Bool in
                        lhs.key >= rhs.key }
                    .map { (value) -> Response in
                        value.value }
        }
        return ranking
    }

    private func calculatePvPStat(stats: Stats, cpCap: Int, lvlCap: Int) -> [Int: Response] {
        var ranking = [Int: Response]()
        for iv in IV.all {
            var lowest = 1.0, highest = Double(lvlCap)
            var bestCP: Int = 0
            while lowest < highest {
                let mid = ceil(lowest + highest) / 2
                let cp = calculateCP(stats: stats, iv: iv, level: mid)
                if cp <= cpCap {
                    lowest = mid
                    bestCP = cp
                } else {
                    highest = mid - 0.5
                }
            }
            if lowest != 0 {
                let value = calculateStatProduct(stats: stats, iv: iv, level: lowest)
                if ranking[value] == nil {
                    ranking[value] = Response(
                        competitionRank: value,
                        denseRank: value,
                        ordinalRank: value,
                        percentage: 0.0,
                        cap: lvlCap,
                        capped: false,
                        ivs: []
                    )
                }
                let index = ranking[value]!.ivs.firstIndex(where: { bestCP >= $0.cp })
                if index != nil {
                    ranking[value]!.ivs.insert(.init(iv: iv, level: lowest, cp: bestCP), at: index!)
                } else {
                    ranking[value]!.ivs.append(.init(iv: iv, level: lowest, cp: bestCP))
                }
            }
        }
        return ranking
    }

    internal func getStats(pokemon: HoloPokemonId, form: PokemonDisplayProto.Form?) -> Stats? {
        stats[PokemonWithFormAndGender(pokemon: pokemon, form: form)]
    }

    private func calculateStatProduct(stats: Stats, iv: IV, level: Double) -> Int {
        let multiplier = (PVPStatsManager.cpMultiplier[level] ?? 0)
        var hp = floor(Double(iv.stamina + stats.baseStamina) * multiplier)
        if hp < 10 { hp = 10 }
        let attack = Double(iv.attack + stats.baseAttack) * multiplier
        let defense = Double(iv.defense + stats.baseDefense) * multiplier
        return Int(round(attack * defense * hp))
    }

    private func calculateCP(stats: Stats, iv: IV, level: Double) -> Int {
        let attack = Double(stats.baseAttack + iv.attack)
        let defense = pow(Double(stats.baseDefense + iv.defense), 0.5)
        let stamina =  pow(Double(stats.baseStamina + iv.stamina), 0.5)
        let multiplier = pow((PVPStatsManager.cpMultiplier[level] ?? 0), 2)
        return max(Int(floor(attack * defense * stamina * multiplier / 10)), 10)
    }

    private func formFrom(name: String) -> PokemonDisplayProto.Form? {
        PokemonDisplayProto.Form.allCases.first { (form) -> Bool in
            String(describing: form).lowercased() == name.replacingOccurrences(of: "_", with: "").lowercased()
        }
    }

    private func pokemonFrom(name: String) -> HoloPokemonId? {
        HoloPokemonId.allCases.first { (pokemon) -> Bool in
            String(describing: pokemon).lowercased() == name.replacingOccurrences(of: "_", with: "").lowercased()
        }
    }

    private func genderFrom(name: String) -> PokemonDisplayProto.Gender? {
        PokemonDisplayProto.Gender.allCases.first { (gender) -> Bool in
            String(describing: gender).lowercased() == name.replacingOccurrences(of: "_", with: "").lowercased()
        }
    }

}

extension PVPStatsManager {

    struct PokemonWithFormAndGender: Hashable {
        var pokemon: HoloPokemonId
        var form: PokemonDisplayProto.Form?
        var gender: PokemonDisplayProto.Gender?
    }

    struct Stats {
        var baseAttack: Int
        var baseDefense: Int
        var baseStamina: Int
        var evolutions: [PokemonWithFormAndGender]
        var baseHeight: Double
        var baseWeight: Double
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

        static var hundo: IV {
            IV(attack: 15, defense: 15, stamina: 15)
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
        var competitionRank: Int
        var denseRank: Int
        var ordinalRank: Int
        var percentage: Double
        var cap: Int
        var capped: Bool
        var ivs: [IVWithCP]
    }

    enum League: Int, CaseIterable {
        case little = 500
        case great = 1500
        case ultra = 2500

        func toString() -> String {
            switch self {
            case .little: return "little"
            case .great: return "great"
            case .ultra: return "ultra"
            }
        }
    }

    enum RankType: String {
        case dense
        case ordinal
        case competition
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
        40: 0.790300011634827,
        40.5: 0.792803950958808,
        41: 0.795300006866455,
        41.5: 0.797803921486970,
        42: 0.800300002098084,
        42.5: 0.802803892322847,
        43: 0.805299997329712,
        43.5: 0.807803863460723,
        44: 0.810299992561340,
        44.5: 0.812803834895027,
        45: 0.815299987792969,
        45.5: 0.817803806620319,
        46: 0.820299983024597,
        46.5: 0.822803778631297,
        47: 0.825299978256226,
        47.5: 0.827803750922783,
        48: 0.830299973487854,
        48.5: 0.832803753381377,
        49: 0.835300028324127,
        49.5: 0.837803755931570,
        50: 0.840300023555756,
        50.5: 0.842803729034748,
        51: 0.845300018787384,
        51.5: 0.847803702398935,
        52: 0.850300014019012,
        52.5: 0.852803676019539,
        53: 0.855300009250641,
        53.5: 0.857803649892077,
        54: 0.860300004482269,
        54.5: 0.862803624012169,
        55: 0.865299999713897
    ]
}
