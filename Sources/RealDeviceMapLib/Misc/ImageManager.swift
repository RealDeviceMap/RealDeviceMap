//
//  ApiRequestHandler.swift
//  RealDeviceMapLib
//
//  Created by Fabio on 21.02.22.
//
//  swiftlint:disable superfluous_disable_command file_length type_body_length

import Foundation
import PerfectLib
import PerfectHTTP
import PerfectThread
import POGOProtos

class ImageManager {

    public static let global = ImageManager()
    public static var noImageGeneration = false
    public static var styles: [String] = [ImageApiRequestHandler.defaultIconSet]

    internal var uiconIndex: [String : [String: Any]] = [:]
    private var lastModified: [String: Int] = [String: Int]()
    private let updaterThread: ThreadQueue

    internal let gymPathCacheLock = Threading.Lock()
    internal var gymPathCache = [Gym: File]()
    internal let invasionPathCacheLock = Threading.Lock()
    internal var invasionPathCache = [Invasion: File]()
    internal let miscPathCacheLock = Threading.Lock()
    internal var miscPathCache = [Misc: File]()
    internal let pokemonPathCacheLock = Threading.Lock()
    internal var pokemonPathCache = [Pokemon: File]()
    internal let pokestopPathCacheLock = Threading.Lock()
    internal var pokestopPathCache = [Pokestop: File]()
    internal let raidPathCacheLock = Threading.Lock()
    internal var raidPathCache = [Raid: File]()
    internal let rewardPathCacheLock = Threading.Lock()
    internal var rewardPathCache = [Reward: File]()
    internal let teamPathCacheLock = Threading.Lock()
    internal var teamPathCache = [Team: File]()
    internal let typePathCacheLock = Threading.Lock()
    internal var typePathCache = [PokemonType: File]()
    internal let weatherPathCacheLock = Threading.Lock()
    internal var weatherPathCache = [Weather: File]()

    private init() {
        updaterThread = Threading.getQueue(name: "ImageJsonUpdater", type: .serial)
        if ImageManager.noImageGeneration {
            return
        }
        updaterThread.dispatch {
            while true {
                Threading.sleep(seconds: 900)
                self.loadImageJsonFileIfNeeded()
            }
        }
        for style in ImageManager.styles {
            loadImageJsonFile(style: style)
        }
    }

    private func loadImageJsonFileIfNeeded() {
        for style in ImageManager.styles {
            let file = File("\(Dir.projectroot)/resources/webroot/static/img/" +
                "\(style)/index.json")
            let lastModified = lastModified[style]
            if lastModified != file.modificationTime {
                Log.info(message: "[ImageApiRequestHandler] Image Json file changed")
                loadImageJsonFile(style: style)
            }
        }
    }

    private func loadImageJsonFile(style: String) {
        let file = File("\(Dir.projectroot)/resources/webroot/static/img/" +
            "\(style)/index.json")
        lastModified[style] = file.modificationTime

        do {
            try file.open()
            let contents = try file.readString()
            file.close()
            guard let json = try contents.jsonDecode() as? [String: Any] else {
                Log.error(message: "[ImageApiRequestHandler] Failed to decode image json file")
                return
            }
            uiconIndex[style] = json
            print("[TMP] UICON INDEX: \n\(json)")
        } catch {
            Log.critical(message: "[ImageApiRequestHandler] Failed to read image json file")
            fatalError()
        }
    }

    // MARK: find Images
    func findGymImage(gym: Gym) -> File? {
        let existingFile = gymPathCacheLock.doWithLock { gymPathCache[gym] }
        if existingFile != nil { return existingFile }

        var postfixes: [String] = []
        if let level = gym.level { postfixes.append("t\(level)") }
        if gym.battle { postfixes.append("b") }
        if gym.ex { postfixes.append("ex") }

        let baseFile = getFirstPath(style: gym.style, folder: "gym", id: "\(gym.id)", postfixes: postfixes)
        let file: File?
        if let baseFile = baseFile {
            file = buildGymImage(gym: gym, baseFile: baseFile)
        } else {
            file = nil
        }

        gymPathCacheLock.doWithLock { gymPathCache[gym] = file }
        return file
    }

    func findInvasionImage(invasion: Invasion) -> File? {
        let existingFile = invasionPathCacheLock.doWithLock { invasionPathCache[invasion] }
        if existingFile != nil { return existingFile }

        let baseFile = getFirstPath(style: invasion.style, folder: "invasion", id: "\(invasion.id)", postfixes: [])

        invasionPathCacheLock.doWithLock { invasionPathCache[invasion] = baseFile }
        return baseFile
    }

    func findMiscImage(misc: Misc) -> File? {
        let existingFile = miscPathCacheLock.doWithLock { miscPathCache[misc] }
        if existingFile != nil { return existingFile }

        let baseFile = getFirstPath(style: misc.style, folder: "misc", id: misc.id, postfixes: [])

        miscPathCacheLock.doWithLock { miscPathCache[misc] = baseFile }
        return baseFile
    }

    func findPokemonImage(pokemon: Pokemon) -> File? {
        let existingFile = pokemonPathCacheLock.doWithLock { pokemonPathCache[pokemon] }
        if existingFile != nil { return existingFile }

        var postfixes: [String] = []
        if let evolution = pokemon.evolution { postfixes.append("e\(evolution)") }
        if let form = pokemon.form { postfixes.append("f\(form)") }
        if let costume = pokemon.costume { postfixes.append("c\(costume)") }
        if let gender = pokemon.gender { postfixes.append("g\(gender)") }

        let baseFile = getFirstPath(style: pokemon.style, folder: "pokemon", id: "\(pokemon.id)", postfixes: postfixes)
        let file: File?
        if let baseFile = baseFile {
            file = buildPokemonImage(pokemon: pokemon, baseFile: baseFile)
        } else {
            file = nil
        }

        pokemonPathCacheLock.doWithLock { pokemonPathCache[pokemon] = file }
        return file
    }

    func findPokestopImage(pokestop: Pokestop) -> File? {
        let existingFile = pokestopPathCacheLock.doWithLock { pokestopPathCache[pokestop] }
        if existingFile != nil { return existingFile }

        var postfixes: [String] = []
        if pokestop.invasionActive { postfixes.append("i") }
        if pokestop.questActive { postfixes.append("q") }
        if pokestop.arEligible { postfixes.append("ar") }

        let baseFile = getFirstPath(style: pokestop.style, folder: "pokestop",
            id: "\(pokestop.id)", postfixes: postfixes)
        var file: File?
        if let baseFile = baseFile {
            file = buildPokestopImage(pokestop: pokestop, baseFile: baseFile)
        } else {
            file = nil
        }

        pokestopPathCacheLock.doWithLock { pokestopPathCache[pokestop] = file }
        return file
    }

    func findRaidImage(raid: Raid) -> File? {
        let existingFile = raidPathCacheLock.doWithLock { raidPathCache[raid] }
        if existingFile != nil { return existingFile }

        var postfixes: [String] = []
        if raid.hatched { postfixes.append("h") }
        if raid.ex { postfixes.append("ex") }

        let baseFile = getFirstPath(style: raid.style, folder: "raid/egg", id: "\(raid.level)", postfixes: postfixes)

        raidPathCacheLock.doWithLock { raidPathCache[raid] = baseFile }
        return baseFile
    }

    func findRewardImage(reward: Reward, pokemon: Pokemon? = nil) -> File? {
        let existingFile = rewardPathCacheLock.doWithLock { rewardPathCache[reward] }
        if existingFile != nil { return existingFile }

        var postfixes: [String] = []
        if reward.amount != nil { postfixes.append("a") }
        let baseFile: File?
        if reward.type == POGOProtos.QuestRewardProto.TypeEnum.pokemonEncounter && pokemon != nil {
            baseFile = findPokemonImage(pokemon: pokemon!)
        } else if reward.type == POGOProtos.QuestRewardProto.TypeEnum.candy {
            baseFile = getFirstPath(style: reward.style, folder: "reward/candy",
                id: reward.id, postfixes: postfixes)
        } else if reward.type == POGOProtos.QuestRewardProto.TypeEnum.xlCandy {
            baseFile = getFirstPath(style: reward.style, folder: "reward/xl_candy",
                id: reward.id, postfixes: postfixes)
        } else if reward.type == POGOProtos.QuestRewardProto.TypeEnum.megaResource {
            baseFile = getFirstPath(style: reward.style, folder: "reward/mega_resource",
                id: reward.id, postfixes: postfixes)
        } else if reward.type == POGOProtos.QuestRewardProto.TypeEnum.item {
            baseFile = getFirstPath(style: reward.style, folder: "reward/item",
                id: reward.id, postfixes: postfixes)
        } else if reward.type == POGOProtos.QuestRewardProto.TypeEnum.stardust {
            baseFile = getFirstPath(style: reward.style, folder: "reward/stardust",
                id: (reward.amount != nil ? "\(reward.amount!)" : reward.id), postfixes: [])
        } else if reward.type == POGOProtos.QuestRewardProto.TypeEnum.unset {
            baseFile = getFirstPath(style: reward.style, folder: "reward",
                id: reward.id, postfixes: postfixes)
        } else {
            baseFile = getFirstPath(style: reward.style, folder: "reward/\(reward.type)",
                id: reward.id, postfixes: postfixes)
        }

        rewardPathCacheLock.doWithLock { rewardPathCache[reward] = baseFile }
        return baseFile
    }

    func findTeamImage(team: Team) -> File? {
        let existingFile = teamPathCacheLock.doWithLock { teamPathCache[team] }
        if existingFile != nil { return existingFile }

        let baseFile = getFirstPath(style: team.style, folder: "team", id: "\(team.id)", postfixes: [])

        teamPathCacheLock.doWithLock { teamPathCache[team] = baseFile }
        return baseFile
    }

    func findTypeImage(type: PokemonType) -> File? {
        let existingFile = typePathCacheLock.doWithLock { typePathCache[type] }
        if existingFile != nil { return existingFile }

        let baseFile = getFirstPath(style: type.style, folder: "type", id: "\(type.id)", postfixes: [])

        typePathCacheLock.doWithLock { typePathCache[type] = baseFile }
        return baseFile
    }

    func findWeatherImage(weather: Weather) -> File? {
        let existingFile = weatherPathCacheLock.doWithLock { weatherPathCache[weather] }
        if existingFile != nil { return existingFile }

        let baseFile = getFirstPath(style: weather.style, folder: "weather", id: "\(weather.id)", postfixes: [])

        weatherPathCacheLock.doWithLock { weatherPathCache[weather] = baseFile }
        return baseFile
    }

    // MARK: Building Images with ImageGenerator
    private func buildGymImage(gym: Gym, baseFile: File) -> File? {
        let baseGeneratedPath = Dir("\(Dir.projectroot)/resources/webroot/static/img/\(gym.style)/generated")
        if !baseGeneratedPath.exists {
            try? baseGeneratedPath.create()
        }
        let gymPath = Dir("\(baseGeneratedPath.path)gym")
        if !gymPath.exists {
            try? gymPath.create()
        }
        let file = File("\(gymPath.path)\(gym.hash).png")
        if file.exists { return file }

        let raidImage = gym.raid != nil ? findRaidImage(raid: gym.raid!) : nil
        let raidPokemonImage = gym.raidPokemon != nil ? findPokemonImage(pokemon: gym.raidPokemon!) : nil

        guard let usedRaidImage = raidPokemonImage ?? raidImage else {
            return baseFile
        }

        ImageGenerator.buildRaidImage(baseImage: baseFile.path, image: file.path, raidImage: usedRaidImage.path)
        return file
    }

    private func buildPokemonImage(pokemon: Pokemon, baseFile: File) -> File? {
        let baseGeneratedPath = Dir("\(Dir.projectroot)/resources/webroot/static/img/\(pokemon.style)/generated/")
        if !baseGeneratedPath.exists {
            try? baseGeneratedPath.create()
        }
        let pokemonPath = Dir("\(baseGeneratedPath.path)pokemon")
        if !pokemonPath.exists {
            try? pokemonPath.create()
        }
        let file = File("\(pokemonPath.path)\(pokemon.hash).png")
        if file.exists { return file }

        let basePath = "\(Dir.projectroot)/resources/webroot/static/img/\(pokemon.style)"
        let spawnTypeFile = pokemon.spawnType != nil ?
            File("\(basePath)/misc/\(pokemon.spawnType!.getImageValue()).png") :
            nil
        let rankingFile = pokemon.ranking != nil ?
            File("\(basePath)/misc/\(pokemon.ranking!.getImageValue()).png") :
            nil

        ImageGenerator.buildPokemonImage(
            baseImage: baseFile.path,
            image: file.path,
            spawnTypeImage: spawnTypeFile != nil && spawnTypeFile!.exists ? spawnTypeFile!.path : nil,
            rankingImage: rankingFile != nil && rankingFile!.exists ? rankingFile!.path : nil
        )
        return file
    }

    private func buildPokestopImage(pokestop: Pokestop, baseFile: File) -> File? {
        let baseGeneratedPath = Dir("\(Dir.projectroot)/resources/webroot/static/img/\(pokestop.style)/generated")
        if !baseGeneratedPath.exists {
            try? baseGeneratedPath.create()
        }
        let pokestopPath = Dir("\(baseGeneratedPath.path)pokestop")
        if !pokestopPath.exists {
            try? pokestopPath.create()
        }
        let file = File("\(pokestopPath.path)\(pokestop.hash).png")
        if file.exists { return file }

        let invasionImage = pokestop.invasion != nil ? findInvasionImage(invasion: pokestop.invasion!) : nil
        let rewardImage = pokestop.reward != nil
            ? findRewardImage(reward: pokestop.reward!, pokemon: pokestop.pokemon)
            : nil

        if invasionImage == nil && rewardImage == nil {
            return baseFile
        }
        ImageGenerator.buildPokestopImage(baseImage: baseFile.path,
            image: file.path,
            invasionImage: invasionImage != nil && invasionImage!.exists ? invasionImage!.path : nil,
            rewardImage: rewardImage != nil && rewardImage!.exists ? rewardImage!.path : nil
        )
        return file
    }

    // MARK: Utils
    private func getFirstPath(style: String, folder: String, id: String, postfixes: [String]) -> File? {
        let basePath = "\(Dir.projectroot)/resources/webroot/static/img/\(style)/\(folder)/\(id)"

        var combinations: [[String]] = []
        let bitValues = (0...postfixes.count).map { i in Int(pow(2, Double(i))) }

        for i in 0..<bitValues.last! {
            var combination: [String] = []
            for (j, postfix) in postfixes.enumerated() where i & bitValues[j] != 0 {
                combination.append(postfix)
            }
            combinations.append(combination)
        }

        combinations.sort { lhs, rhs in
            var index = 0
            while lhs.count > index || rhs.count > index {
                let lhsFirstPrio = lhs.count > index ? postfixes.firstIndex(of: lhs[index])! : Int.max
                let rhsFirstPrio = rhs.count > index ? postfixes.firstIndex(of: rhs[index])! : Int.max
                if lhsFirstPrio != rhsFirstPrio {
                    return lhsFirstPrio <= rhsFirstPrio
                } else {
                    index += 1
                }
            }
            return false
        }

        var possiblePaths: [File] = []
        for combination in combinations {
            if combination.isEmpty {
                possiblePaths.append(File("\(basePath).png"))
            } else {
                possiblePaths.append(File("\(basePath)_\(combination.joined(separator: "_")).png"))
            }
        }
        // TODO check JSON instead of File structure
        return possiblePaths.first {$0.exists}
    }

}

extension ImageManager {
    struct Pokemon: Hashable {
        enum SpawnType: String {
            case cell

            func getImageValue() -> String {
                switch self {
                case .cell: return "grass"
                }
            }
        }
        enum Ranking: String {
            case first = "1", second = "2", third = "3"

            func getImageValue() -> String {
                switch self {
                case .first: return "first"
                case .second: return "second"
                case .third: return "third"
                }
            }
        }

        // Standard
        var style: String
        var id: Int
        var evolution: Int?
        var form: Int?
        var costume: Int?
        var gender: Int?

        // Generated
        var spawnType: SpawnType?
        var ranking: Ranking?
        var isStandard: Bool {
            spawnType == nil && ranking == nil
        }

        var uicon: String { "\(id)" +
            (evolution != nil ? "_e\(evolution!)" : "") +
            (form != nil ? "_f\(form!)" : "") +
            (costume != nil ? "_c\(costume!)" : "") +
            (gender != nil ? "_g\(gender!)" : "")
        }
        var hash: String { uicon +
            (spawnType != nil ? "_st-\(spawnType!.rawValue)" : "") +
            (ranking != nil ? "_r\(ranking!.rawValue)" : "")
        }
    }

    struct Gym: Hashable {
        // Standard
        var style: String
        var id: Int
        var level: Int?
        var battle: Bool = false
        var ex: Bool = false
        var arEligible: Bool = false

        // Generated
        var raid: Raid?
        var raidPokemon: Pokemon?
        var isStandard: Bool {
            return raid == nil && raidPokemon == nil
        }

        var uicon: String { "\(id)" +
            (level != nil ? "_t\(level!)" : "") +
            "\(battle ? "_b" : "")" +
            "\(ex ? "_ex": "")" +
            "\(arEligible ? "_ar": "")"
        }
        var hash: String { uicon +
            "\(raid != nil && raidPokemon == nil ? "_r\(raid!.uicon)" : "")" +
            "\(raidPokemon != nil ? "_p\(raidPokemon!.uicon)" : "")"
        }

    }

    struct Raid: Hashable {
        // Standard
        var style: String
        var level: Int
        var hatched: Bool = false
        var ex: Bool = false
        var isStandard: Bool = true

        var uicon: String {
            "\(level)\(hatched ? "_h" : "")\(ex ? "_ex": "")"
        }
        var hash: String { uicon }
    }

    struct Pokestop: Hashable {
        // Standard
        var style: String
        var id: Int // Not lured is ID 0
        var arEligible: Bool = false
        var sponsor: Bool = false
        var invasionActive: Bool = false
        var questActive: Bool = false

        // Generated
        var invasion: Invasion?
        var reward: Reward?
        var pokemon: Pokemon?
        var isStandard: Bool {
            return invasion == nil && reward == nil && pokemon == nil
        }
        var uicon: String {
            "\(id)\(invasionActive ? "_i" : "")\(questActive ? "_q": "")\(arEligible ? "_ar": "")"
        }
        var hash: String { uicon +
            (invasion != nil ? "_in\(invasion!.uicon)": "") +
            (reward != nil ? "_r\(reward!.type.rawValue)_\(reward!.uicon)" : "") +
            (pokemon != nil ? "_p\(pokemon!.uicon)" : "")
        }
    }

    struct Reward: Hashable {
        // Standard
        var style: String
        var id: String
        var amount: Int?

        // Generated
        var type: POGOProtos.QuestRewardProto.TypeEnum
        var isStandard: Bool = true

        var uicon: String {
            switch type {
            case .pokemonEncounter:
                return id // special case including all postfixes e.g. 592_f2330
            case .megaResource, .xlCandy, .candy, .item:
                return id + (amount != nil ? "_a\(amount!)" : "")
            case .stardust:
                return amount != nil ? "\(amount!)" : "0"
            default: return "0"
            }
        }
        var hash: String { uicon }
    }

    struct Invasion: Hashable {
        // Standard
        var style: String
        var id: Int
        var isStandard: Bool = true

        var uicon: String { "\(id)" }
        var hash: String { uicon }
    }

    struct Weather: Hashable {
        // Standard
        var style: String
        var id: Int
        var level: Int?
        var day: Bool = true
        var night: Bool = false
        var isStandard: Bool = true

        var uicon: String {
            "\(id)" + (level != nil ? "_l\(level!)" : "") + "\(day ? "_d" : "")\(night ? "_n" : "")"
        }
        var hash: String { uicon }
    }

    struct Misc: Hashable {
        // Standard
        var style: String
        var id: String // not only numbers
        var isStandard: Bool = true

        var uicon: String { "\(id)" }
        var hash: String { uicon }
    }

    struct Team: Hashable {
        // Standard
        var style: String
        var id: Int
        var isStandard: Bool = true

        var uicon: String { "\(id)" }
        var hash: String { uicon }
    }

    struct PokemonType: Hashable {
        // Standard
        var style: String
        var id: Int
        var isStandard: Bool = true

        var uicon: String { "\(id)" }
        var hash: String { uicon }
    }
}
