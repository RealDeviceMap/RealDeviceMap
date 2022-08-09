//
//  ImageManager.swift
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
    public static var imageGenerationEnabled: Bool = true

    private let lock = Threading.Lock()
    private var uiconIndex: [String: [String: Any]] = [:]
    private var lastModified: [String: Int] = [String: Int]()
    private let updaterThread: ThreadQueue

    internal static var devicePathCache: MemoryCache<File>?
    internal static var gymPathCache: MemoryCache<File>?
    internal static var invasionPathCache: MemoryCache<File>?
    internal static var miscPathCache: MemoryCache<File>?
    internal static var pokemonPathCache: MemoryCache<File>?
    internal static var pokestopPathCache: MemoryCache<File>?
    internal static var raidPathCache: MemoryCache<File>?
    internal static var rewardPathCache: MemoryCache<File>?
    internal static var spawnpointPathCache: MemoryCache<File>?
    internal static var teamPathCache: MemoryCache<File>?
    internal static var typePathCache: MemoryCache<File>?
    internal static var weatherPathCache: MemoryCache<File>?

    private init() {
        updaterThread = Threading.getQueue(name: "ImageJsonUpdater", type: .serial)
        if !ImageManager.imageGenerationEnabled {
            return
        }
        updaterThread.dispatch {
            while true {
                Threading.sleep(seconds: 900)
                self.loadImageJsonFileIfNeeded()
            }
        }
        let styles = ImageApiRequestHandler.styles
        for (_, folder) in styles {
            loadImageJsonFile(folder: folder)
        }
    }

    private func loadImageJsonFileIfNeeded() {
        let styles = ImageApiRequestHandler.styles
        for (_, folder) in styles {
            let file = File("\(Dir.projectroot)/resources/webroot/static/img/" +
                "\(folder)/index.json")
            let modificationTime = lock.doWithLock { lastModified[folder] }
            if modificationTime != file.modificationTime {
                Log.info(message: "[ImageManager] Image Json file changed")
                loadImageJsonFile(folder: folder)
            }
        }
    }

    private func loadImageJsonFile(folder: String) {
        let file = File("\(Dir.projectroot)/resources/webroot/static/img/" +
            "\(folder)/index.json")
        lock.doWithLock { lastModified[folder] = file.modificationTime }

        do {
            try file.open()
            let contents = try file.readString()
            file.close()
            guard let json = try contents.jsonDecode() as? [String: Any] else {
                Log.error(message: "[ImageManager] Failed to decode image json file")
                return
            }
            lock.doWithLock { uiconIndex[folder] = json }
        } catch {
            Log.critical(message: "[ImageManager] Failed to open/read image json file '\(file.path)'" +
                " - does it exist?")
        }
    }

    // MARK: find Images
    func findDeviceImage(device: Device) -> File? {
        let existingFile = ImageManager.devicePathCache?.get(id: device.cacheHash)
        if existingFile != nil { return existingFile }

        let baseFile = File("\(Dir.projectroot)/resources/webroot/static/img/" +
            "\(device.style)/device/\(device.uicon).png")

        ImageManager.devicePathCache?.set(id: device.cacheHash, value: baseFile)
        return baseFile
    }

    func findGymImage(gym: Gym) -> File? {
        let existingFile = ImageManager.gymPathCache?.get(id: gym.cacheHash)
        if existingFile != nil { return existingFile }

        let baseFile = File("\(Dir.projectroot)/resources/webroot/static/img/" +
            "\(gym.style)/gym/\(gym.uicon).png")

        let file = buildGymImage(gym: gym, baseFile: baseFile)
        ImageManager.gymPathCache?.set(id: gym.cacheHash, value: file)
        return file
    }

    func findInvasionImage(invasion: Invasion) -> File? {
        let existingFile = ImageManager.invasionPathCache?.get(id: invasion.cacheHash)
        if existingFile != nil { return existingFile }

        let baseFile = File("\(Dir.projectroot)/resources/webroot/static/img/" +
            "\(invasion.style)/invasion/\(invasion.uicon).png")

        ImageManager.invasionPathCache?.set(id: invasion.cacheHash, value: baseFile)
        return baseFile
    }

    func findMiscImage(misc: Misc) -> File? {
        let existingFile = ImageManager.miscPathCache?.get(id: misc.cacheHash)
        if existingFile != nil { return existingFile }

        let baseFile = File("\(Dir.projectroot)/resources/webroot/static/img/" +
            "\(misc.style)/misc/\(misc.uicon).png")

        ImageManager.miscPathCache?.set(id: misc.cacheHash, value: baseFile)
        return baseFile
    }

    func findPokemonImage(pokemon: Pokemon) -> File? {
        let existingFile = ImageManager.pokemonPathCache?.get(id: pokemon.cacheHash)
        if existingFile != nil { return existingFile }

        var postfixes: [String] = []
        if let evolution = pokemon.evolution { postfixes.append("e\(evolution)") }
        if let form = pokemon.form { postfixes.append("f\(form)") }
        if let costume = pokemon.costume { postfixes.append("c\(costume)") }
        if let gender = pokemon.gender { postfixes.append("g\(gender)") }

        let baseFile = File("\(Dir.projectroot)/resources/webroot/static/img/" +
            "\(pokemon.style)/pokemon/\(pokemon.uicon).png")

        let file = buildPokemonImage(pokemon: pokemon, baseFile: baseFile)
        ImageManager.pokemonPathCache?.set(id: pokemon.cacheHash, value: file)
        return file
    }

    func findPokestopImage(pokestop: Pokestop) -> File? {
        let existingFile = ImageManager.pokestopPathCache?.get(id: pokestop.cacheHash)
        if existingFile != nil { return existingFile }

        let baseFile = File("\(Dir.projectroot)/resources/webroot/static/img/" +
            "\(pokestop.style)/pokestop/\(pokestop.uicon).png")

        let file = buildPokestopImage(pokestop: pokestop, baseFile: baseFile)
        ImageManager.pokestopPathCache?.set(id: pokestop.cacheHash, value: file)
        return file
    }

    func findRaidImage(raid: Raid) -> File? {
        let existingFile = ImageManager.raidPathCache?.get(id: raid.cacheHash)
        if existingFile != nil { return existingFile }

        let baseFile = File("\(Dir.projectroot)/resources/webroot/static/img/" +
            "\(raid.style)/raid/egg/\(raid.uicon).png")

        ImageManager.raidPathCache?.set(id: raid.cacheHash, value: baseFile)
        return baseFile
    }

    func findRewardImage(reward: Reward, pokemon: Pokemon? = nil) -> File? {
        let existingFile = ImageManager.rewardPathCache?.get(id: reward.cacheHash)
        if existingFile != nil { return existingFile }

        var postfixes: [String] = []
        if reward.amount != nil { postfixes.append("a") }
        let baseFile: File

        if reward.type == POGOProtos.QuestRewardProto.TypeEnum.pokemonEncounter && pokemon != nil {
            baseFile = File("\(Dir.projectroot)/resources/webroot/static/img/" +
                "\(pokemon!.style)/pokemon/\(pokemon!.uicon).png")
        } else if reward.type == POGOProtos.QuestRewardProto.TypeEnum.candy {
            baseFile = File("\(Dir.projectroot)/resources/webroot/static/img/" +
                "\(reward.style)/reward/candy/\(reward.uicon).png")
        } else if reward.type == POGOProtos.QuestRewardProto.TypeEnum.xlCandy {
            baseFile = File("\(Dir.projectroot)/resources/webroot/static/img/" +
                "\(reward.style)/reward/xl_candy/\(reward.uicon).png")
        } else if reward.type == POGOProtos.QuestRewardProto.TypeEnum.megaResource {
            baseFile = File("\(Dir.projectroot)/resources/webroot/static/img/" +
                "\(reward.style)/reward/mega_resource/\(reward.uicon).png")
        } else if reward.type == POGOProtos.QuestRewardProto.TypeEnum.item {
            baseFile = File("\(Dir.projectroot)/resources/webroot/static/img/" +
                "\(reward.style)/reward/item/\(reward.uicon).png")
        } else if reward.type == POGOProtos.QuestRewardProto.TypeEnum.stardust {
            baseFile = File("\(Dir.projectroot)/resources/webroot/static/img/" +
                "\(reward.style)/reward/stardust/\(reward.uicon).png")
        } else if reward.type == POGOProtos.QuestRewardProto.TypeEnum.unset {
            baseFile = File("\(Dir.projectroot)/resources/webroot/static/img/" +
                "\(reward.style)/reward/\(reward.uicon).png")
        } else {
            baseFile = File("\(Dir.projectroot)/resources/webroot/static/img/" +
                "\(reward.style)/reward/\(reward.type)/\(reward.uicon).png")
        }

        ImageManager.rewardPathCache?.set(id: reward.cacheHash, value: baseFile)
        return baseFile
    }

    func findSpawnpointImage(spawnpoint: Spawnpoint) -> File? {
        let existingFile = ImageManager.spawnpointPathCache?.get(id: spawnpoint.cacheHash)
        if existingFile != nil { return existingFile }

        let baseFile = File("\(Dir.projectroot)/resources/webroot/static/img/" +
            "\(spawnpoint.style)/spawnpoint/\(spawnpoint.uicon).png")

        ImageManager.spawnpointPathCache?.set(id: spawnpoint.cacheHash, value: baseFile)
        return baseFile
    }

    func findTeamImage(team: Team) -> File? {
        let existingFile = ImageManager.teamPathCache?.get(id: team.cacheHash)
        if existingFile != nil { return existingFile }

        let baseFile = File("\(Dir.projectroot)/resources/webroot/static/img/" +
            "\(team.style)/team/\(team.uicon).png")

        ImageManager.teamPathCache?.set(id: team.cacheHash, value: baseFile)
        return baseFile
    }

    func findTypeImage(type: PokemonType) -> File? {
        let existingFile = ImageManager.typePathCache?.get(id: type.cacheHash)
        if existingFile != nil { return existingFile }

        let baseFile = File("\(Dir.projectroot)/resources/webroot/static/img/" +
            "\(type.style)/type/\(type.uicon).png")

        ImageManager.typePathCache?.set(id: type.cacheHash, value: baseFile)
        return baseFile
    }

    func findWeatherImage(weather: Weather) -> File? {
        let existingFile = ImageManager.weatherPathCache?.get(id: weather.cacheHash)
        if existingFile != nil { return existingFile }

        let baseFile = File("\(Dir.projectroot)/resources/webroot/static/img/" +
            "\(weather.style)/weather/\(weather.uicon).png")

        ImageManager.weatherPathCache?.set(id: weather.cacheHash, value: baseFile)
        return baseFile
    }

    // MARK: Building Images with ImageGenerator
    private func buildGymImage(gym: Gym, baseFile: File) -> File {
        if (gym.raid == nil && gym.raidPokemon == nil) || !ImageManager.imageGenerationEnabled {
            return baseFile
        }

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

    private func buildPokemonImage(pokemon: Pokemon, baseFile: File) -> File {
        if (pokemon.spawnType == nil && pokemon.ranking == nil) || !ImageManager.imageGenerationEnabled {
            return baseFile
        }

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

    private func buildPokestopImage(pokestop: Pokestop, baseFile: File) -> File {
        if (pokestop.invasion == nil && pokestop.reward == nil) || !ImageManager.imageGenerationEnabled {
            return baseFile
        }

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

        ImageGenerator.buildPokestopImage(baseImage: baseFile.path,
            image: file.path,
            invasionImage: invasionImage != nil && invasionImage!.exists ? invasionImage!.path : nil,
            rewardImage: rewardImage != nil && rewardImage!.exists ? rewardImage!.path : nil
        )
        return file
    }

    // MARK: Utils
    func getFirstNameWithFallback(id: String, index: [String], postfixes: [String]) -> String {
        var combinations: [[String]] = []
        let bitValues = (0...postfixes.count).map { i in
            Int(pow(2, Double(i)))
        }

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

        var possibleNames: [String] = []
        for combination in combinations {
            if combination.isEmpty {
                possibleNames.append("\(id).png")
            } else {
                possibleNames.append("\(id)_\(combination.joined(separator: "_")).png")
            }
        }
        return possibleNames.first {
            index.contains($0)
        }?.deletingFileExtension ?? "0"
    }

    func accessUiconIndexList(style: String, folder: String) -> [String]? {
        lock.doWithLock { uiconIndex[style]?[folder] as? [String] }
    }

    func accessUiconIndexDictionary(style: String, folder: String) -> [String: Any]? {
        lock.doWithLock { uiconIndex[style]?[folder] as? [String: Any] }
    }

    func clearCaches() {
        ImageManager.devicePathCache?.clear()
        ImageManager.gymPathCache?.clear()
        ImageManager.invasionPathCache?.clear()
        ImageManager.miscPathCache?.clear()
        ImageManager.pokemonPathCache?.clear()
        ImageManager.pokestopPathCache?.clear()
        ImageManager.raidPathCache?.clear()
        ImageManager.rewardPathCache?.clear()
        ImageManager.spawnpointPathCache?.clear()
        ImageManager.teamPathCache?.clear()
        ImageManager.typePathCache?.clear()
        ImageManager.weatherPathCache?.clear()
    }
}

extension ImageManager {
    struct Device {
        // Standard
        var style: String
        var id: Int
        var isStandard: Bool = true

        var postfixes: [String] = []
        var uicon: String {
            guard let index = ImageManager.global.accessUiconIndexList(style: style, folder: "device") else {
                return "\(id)"
            }
            return ImageManager.global.getFirstNameWithFallback(id: "\(id)", index: index, postfixes: postfixes)
        }
        var hash: String { uicon }

        var cacheHash: String { style + "_" + hash }
    }

    struct Gym {
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
            raid == nil && raidPokemon == nil
        }
        var postfixes: [String] {
            var build: [String] = []
            if level != nil { build.append("t\(level!)") }
            if battle { build.append("b") }
            if ex { build.append("ex") }
            if arEligible { build.append("ar")}
            return build
        }
        var uicon: String {
            guard let index = ImageManager.global.accessUiconIndexList(style: style, folder: "gym") else {
                return "\(id)"
            }
            return ImageManager.global.getFirstNameWithFallback(id: "\(id)", index: index, postfixes: postfixes)
        }
        var hash: String { uicon +
            "\(raid != nil && raidPokemon == nil ? "_r\(raid!.uicon)" : "")" +
            "\(raidPokemon != nil ? "_p\(raidPokemon!.uicon)" : "")"
        }

        var cacheHash: String { style + "_" + hash }
    }

    struct Invasion {
        // Standard
        var style: String
        var id: Int
        var isStandard: Bool = true

        var postfixes: [String] = []
        var uicon: String {
            guard let index = ImageManager.global.accessUiconIndexList(style: style, folder: "invasion") else {
                return "\(id)"
            }
            return ImageManager.global.getFirstNameWithFallback(id: "\(id)", index: index, postfixes: postfixes)
        }
        var hash: String { uicon }

        var cacheHash: String { style + "_" + hash }
    }

    struct Misc {
        // Standard
        var style: String
        var id: String // not only numbers
        var isStandard: Bool = true

        var postfixes: [String] = []
        var uicon: String {
            guard let index = ImageManager.global.accessUiconIndexList(style: style, folder: "misc") else {
                return "\(id)"
            }
            return ImageManager.global.getFirstNameWithFallback(id: "\(id)", index: index, postfixes: postfixes)
        }
        var hash: String { uicon }

        var cacheHash: String { style + "_" + hash }
    }

    struct Pokemon {
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

        var postfixes: [String] {
            var build: [String] = []
            if let evolution = evolution { build.append("e\(evolution)") }
            if let form = form { build.append("f\(form)") }
            if let costume = costume { build.append("c\(costume)") }
            if let gender = gender { build.append("g\(gender)") }
            return build
        }

        var uicon: String {
            guard let index = ImageManager.global.accessUiconIndexList(style: style, folder: "pokemon") else {
                return "\(id)"
            }
            return ImageManager.global.getFirstNameWithFallback(id: "\(id)", index: index, postfixes: postfixes)
        }
        var hash: String { uicon +
            (spawnType != nil ? "_st-\(spawnType!.rawValue)" : "") +
            (ranking != nil ? "_r\(ranking!.rawValue)" : "")
        }

        var cacheHash: String { style + "_" + hash }
    }

    struct Pokestop {
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
            invasion == nil && reward == nil && pokemon == nil
        }

        var postfixes: [String] {
            var build: [String] = []
            if invasionActive { build.append("i") }
            if questActive { build.append("q") }
            if arEligible { build.append("ar") }
            return build
        }
        var uicon: String {
            guard let index = ImageManager.global.accessUiconIndexList(style: style, folder: "pokestop") else {
                return "\(id)"
            }
            return ImageManager.global.getFirstNameWithFallback(id: "\(id)", index: index, postfixes: postfixes)
        }
        var hash: String { uicon +
            (invasion != nil ? "_in\(invasion!.uicon)": "") +
            (reward != nil ? "_r\(reward!.type.rawValue)_\(reward!.uicon)" : "") +
            (pokemon != nil ? "_p\(pokemon!.uicon)" : "")
        }

        var cacheHash: String { style + "_" + hash }
    }

    struct Raid {
        // Standard
        var style: String
        var level: Int
        var hatched: Bool = false
        var ex: Bool = false
        var isStandard: Bool = true

        var postfixes: [String] {
            var build: [String] = []
            if hatched { build.append("h") }
            if ex { build.append("ex") }
            return build
        }
        var uicon: String {
            guard let raid = ImageManager.global.accessUiconIndexDictionary(style: style, folder: "raid"),
                let index = raid["egg"] as? [String] else {
                return "\(level)"
            }
            return ImageManager.global.getFirstNameWithFallback(id: "\(level)", index: index, postfixes: postfixes)
        }
        var hash: String { uicon }

        var cacheHash: String { style + "_" + hash }
    }

    struct Reward {
        // Standard
        var style: String
        var id: String
        var amount: Int?

        // Generated
        var type: POGOProtos.QuestRewardProto.TypeEnum
        var isStandard: Bool = true

        var postfixes: [String] {
            var build: [String] = []
            if amount != nil { build.append("a\(amount!)") }
            return build
        }
        var uicon: String {
            guard let index = ImageManager.global.accessUiconIndexDictionary(style: style, folder: "reward") else {
                return "\(id)"
            }
            switch type {
            case .pokemonEncounter:
                return id // contains special case including all postfixes e.g. 592_f2330
            case .megaResource:
                return ImageManager.global.getFirstNameWithFallback(id: "\(id)",
                    index: index["mega_resource"] as? [String] ?? [String](), postfixes: postfixes)
            case .xlCandy:
                return ImageManager.global.getFirstNameWithFallback(id: "\(id)",
                    index: index["xl_candy"] as? [String] ?? [String](), postfixes: postfixes)
            case .candy:
                return ImageManager.global.getFirstNameWithFallback(id: "\(id)",
                    index: index["candy"] as? [String] ?? [String](), postfixes: postfixes)
            case .item:
                return ImageManager.global.getFirstNameWithFallback(id: "\(id)",
                    index: index["item"] as? [String] ?? [String](), postfixes: postfixes)
            case .stardust:
                let id = amount != nil ? "\(amount!)" : "0"
                return ImageManager.global.getFirstNameWithFallback(id: id,
                    index: index["stardust"] as? [String] ?? [String](), postfixes: [])
            case .unset:
                return ImageManager.global.getFirstNameWithFallback(id: id,
                    index: index["unset"] as? [String] ?? [String](), postfixes: postfixes)
            default:
                return ImageManager.global.getFirstNameWithFallback(id: id,
                index: index["\(type)"] as? [String] ?? [String](), postfixes: postfixes)
            }
        }
        var hash: String { "\(type.rawValue)_" + uicon }

        var cacheHash: String { style + "_" + hash }
    }

    struct Spawnpoint {
        // Standard
        var style: String
        var id: Int
        var isStandard: Bool = true

        var postfixes: [String] = []
        var uicon: String {
            guard let index = ImageManager.global.accessUiconIndexList(style: style, folder: "spawnpoint") else {
                return "\(id)"
            }
            return ImageManager.global.getFirstNameWithFallback(id: "\(id)", index: index, postfixes: postfixes)
        }
        var hash: String { uicon }

        var cacheHash: String { style + "_" + hash }
    }

    struct Team {
        // Standard
        var style: String
        var id: Int
        var isStandard: Bool = true

        var postfixes: [String] = []
        var uicon: String {
            guard let index = ImageManager.global.accessUiconIndexList(style: style, folder: "team") else {
                return "\(id)"
            }
            return ImageManager.global.getFirstNameWithFallback(id: "\(id)", index: index, postfixes: postfixes)
        }
        var hash: String { uicon }

        var cacheHash: String { style + "_" + hash }
    }

    struct PokemonType {
        // Standard
        var style: String
        var id: Int
        var isStandard: Bool = true

        var postfixes: [String] = []
        var uicon: String {
            guard let index = ImageManager.global.accessUiconIndexList(style: style, folder: "type") else {
                return "\(id)"
            }
            return ImageManager.global.getFirstNameWithFallback(id: "\(id)", index: index, postfixes: postfixes)
        }
        var hash: String { uicon }

        var cacheHash: String { style + "_" + hash }
    }

    struct Weather {
        // Standard
        var style: String
        var id: Int
        var level: Int?
        var day: Bool = true
        var night: Bool = false
        var isStandard: Bool = true

        var postfixes: [String] {
            var build: [String] = []
            if level != nil { build.append("l\(level!)") }
            if day { build.append("d") }
            if night { build.append("n") }
            return build
        }
        var uicon: String {
            guard let index = ImageManager.global.accessUiconIndexList(style: style, folder: "weather") else {
                return "\(id)"
            }
            return ImageManager.global.getFirstNameWithFallback(id: "\(id)", index: index, postfixes: postfixes)
        }
        var hash: String { uicon }

        var cacheHash: String { style + "_" + hash }
    }
}
