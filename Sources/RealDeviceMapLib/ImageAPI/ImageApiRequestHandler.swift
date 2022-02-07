//
//  ApiRequestHandler.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 05.09.21.
//  Updated by Fabio on 06.02.21.
//
//  swiftlint:disable superfluous_disable_command file_length type_body_length

import Foundation
import PerfectLib
import PerfectHTTP
import PerfectThread
import POGOProtos

class ImageApiRequestHandler {

    internal static var defaultIconSet: String?
    internal static let gymPathCacheLock = Threading.Lock()
    internal static var gymPathCache = [Gym: File]()
    internal static let invasionPathCacheLock = Threading.Lock()
    internal static var invasionPathCache = [Invasion: File]()
    internal static let miscPathCacheLock = Threading.Lock()
    internal static var miscPathCache = [Misc: File]()
    internal static let pokemonPathCacheLock = Threading.Lock()
    internal static var pokemonPathCache = [Pokemon: File]()
    internal static let pokestopPathCacheLock = Threading.Lock()
    internal static var pokestopPathCache = [Pokestop: File]()
    internal static let raidPathCacheLock = Threading.Lock()
    internal static var raidPathCache = [Raid: File]()
    internal static let rewardPathCacheLock = Threading.Lock()
    internal static var rewardPathCache = [Reward: File]()
    internal static let typePathCacheLock = Threading.Lock()
    internal static var typePathCache = [Type: File]()
    internal static let weatherPathCacheLock = Threading.Lock()
    internal static var weatherPathCache = [Weather: File]()

    // MARK: handle request
    public static func handleGym(request: HTTPRequest, response: HTTPResponse) {
        guard let style = request.param(name: "style") ?? defaultIconSet,
              let id = request.param(name: "id")?.toInt() else {
            return response.respondWithError(status: .badRequest)
        }

        let level = request.param(name: "level")?.toInt()
        let battle = request.param(name: "battle")?.toBool() ?? false
        let ex = request.param(name: "ex")?.toBool() ?? false

        let raidLevel = request.param(name: "raid_level")?.toInt()
        let raidEx = request.param(name: "raid_ex")?.toBool() ?? false
        let raidHatched = request.param(name: "raid_hatched")?.toBool() ?? false
        let raid = raidLevel != nil ? Raid(style: style, level: raidLevel!, hatched: raidHatched, ex: raidEx) : nil

        let raidPokemonId = request.param(name: "raid_pokemon_id")?.toInt()
        let raidPokemonEvolution = request.param(name: "raid_pokemon_evolution")?.toInt()
        let raidPokemonForm = request.param(name: "raid_pokemon_form")?.toInt()
        let raidPokemonCostume = request.param(name: "raid_pokemon_costume")?.toInt()
        let raidPokemonGender = request.param(name: "raid_pokemon_gender")?.toInt()
        let raidPokemon = raidPokemonId != nil ? Pokemon(
            style: style, id: raidPokemonId!, evolution: raidPokemonEvolution,
            form: raidPokemonForm, costume: raidPokemonCostume, gender: raidPokemonGender
        ) : nil

        let gym = Gym(
            style: style, id: id, level: level, battle: battle, ex: ex, raid: raid, raidPokemon: raidPokemon
        )
        let file = findGymImage(gym: gym)
        sendFile(response: response, file: file)
    }

    public static func handleInvasion(request: HTTPRequest, response: HTTPResponse) {
        guard let style = request.param(name: "style") ?? defaultIconSet,
              let id = request.param(name: "id")?.toInt() else {
            return response.respondWithError(status: .badRequest)
        }
        let invasion = Invasion(style: style, id: id)
        let file = findInvasionImage(invasion: invasion)
        sendFile(response: response, file: file)
    }

    public static func handleMisc(request: HTTPRequest, response: HTTPResponse) {
        guard let style = request.param(name: "style") ?? defaultIconSet,
              let id = request.param(name: "id") else {
            return response.respondWithError(status: .badRequest)
        }
        let misc = Misc(style: style, id: id)
        let file = findMiscImage(misc: misc)
        sendFile(response: response, file: file)
    }

    public static func handlePokemon(request: HTTPRequest, response: HTTPResponse) {
        guard let style = request.param(name: "style") ?? defaultIconSet,
              let id = request.param(name: "id")?.toInt() else {
            return response.respondWithError(status: .badRequest)
        }

        let evolution = request.param(name: "evolution")?.toInt()
        let form = request.param(name: "form")?.toInt()
        let costume = request.param(name: "costume")?.toInt()
        let gender = request.param(name: "gender")?.toInt()
        let spawnType = Pokemon.SpawnType(rawValue: request.param(name: "spawn_type") ?? "")
        let ranking = Pokemon.Ranking(rawValue: request.param(name: "ranking") ?? "")

        let pokemon = Pokemon(
            style: style, id: id, evolution: evolution, form: form, costume: costume, gender: gender,
                spawnType: spawnType, ranking: ranking
        )
        let file = findPokemonImage(pokemon: pokemon)
        sendFile(response: response, file: file)
    }

    public static func handlePokestop(request: HTTPRequest, response: HTTPResponse) {
        guard let style = request.param(name: "style") ?? defaultIconSet,
              let id = request.param(name: "id")?.toInt() else {
            return response.respondWithError(status: .badRequest)
        }
        let invasionType = request.param(name: "invasion")?.toInt()
        let questRewardType = request.param(name: "quest_reward_type")?.toInt()
        let questItemId = request.param(name: "quest_item_id")?.toInt()
        let questRewardAmount = request.param(name: "quest_reward_amount")?.toInt()
        let questPokemonId = request.param(name: "quest_pokemon_id")?.toInt()
        let questFormId = request.param(name: "quest_form_id")?.toInt()
        let questGenderId = request.param(name: "quest_gender_id")?.toInt()
        let questCostumeId = request.param(name: "quest_costume_id")?.toInt()

        var pokemon: Pokemon?
        if questPokemonId != nil {
            pokemon = Pokemon(style: style, id: questPokemonId!, evolution: nil, form: questFormId,
                costume: questCostumeId, gender: questGenderId, spawnType: nil, ranking: nil)
        }

        var invasion: Invasion?
        var invasionActive = false
        if invasionType != nil {
            invasion = Invasion(style: style, id: invasionType!)
            invasionActive = true
        }

        var reward: Reward?
        // var questActive = false
        if questRewardType != nil {
            reward = Reward(style: style, id: questItemId ?? questPokemonId ?? 0, amount: questRewardAmount,
                type: POGOProtos.QuestRewardProto.TypeEnum(rawValue: questRewardType!)!)
            // questActive = true // separate icon with different color
        }
        let pokestop = Pokestop(style: style, id: id, invasionActive: invasionActive, questActive: false,
            invasion: invasion, reward: reward, pokemon: pokemon)

        let file = findPokestopImage(pokestop: pokestop)
        sendFile(response: response, file: file)
    }

    public static func handleRaidEgg(request: HTTPRequest, response: HTTPResponse) {
        guard let style = request.param(name: "style") ?? defaultIconSet,
              let id = request.param(name: "id")?.toInt() else {
            return response.respondWithError(status: .badRequest)
        }

        let ex = request.param(name: "ex")?.toBool() ?? false
        let hatched = request.param(name: "hatched")?.toBool() ?? false

        let raid = Raid(style: style, level: id, hatched: hatched, ex: ex)
        let file = findRaidImage(raid: raid)
        sendFile(response: response, file: file)
    }

    public static func handleReward(request: HTTPRequest, response: HTTPResponse) {
        guard let style = request.param(name: "style") ?? defaultIconSet,
              let id = request.param(name: "id")?.toInt() else {
            return response.respondWithError(status: .badRequest)
        }

        let type = request.param(name: "type")?.toInt()
        let rewardType = POGOProtos.QuestRewardProto.TypeEnum(rawValue: type!)!
        let reward = Reward(style: style, id: id, amount: nil, type: rewardType)
        let file = findRewardImage(reward: reward)
        sendFile(response: response, file: file)
    }

    public static func handleType(request: HTTPRequest, response: HTTPResponse) {
        guard let style = request.param(name: "style") ?? defaultIconSet,
              let id = request.param(name: "id")?.toInt() else {
            return response.respondWithError(status: .badRequest)
        }

        let type = Type(style: style, id: id)
        let file = findTypeImage(type: type)
        sendFile(response: response, file: file)
    }

    public static func handleWeather(request: HTTPRequest, response: HTTPResponse) {
        guard let style = request.param(name: "style") ?? defaultIconSet,
              let id = request.param(name: "id")?.toInt() else {
            return response.respondWithError(status: .badRequest)
        }
        let weather = Weather(style: style, id: id)
        let file = findWeatherImage(weather: weather)
        sendFile(response: response, file: file)
    }

    // MARK: find Images
    private static func findGymImage(gym: Gym) -> File? {
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

    private static func findInvasionImage(invasion: Invasion) -> File? {
        let existingFile = invasionPathCacheLock.doWithLock { invasionPathCache[invasion] }
        if existingFile != nil { return existingFile }

        let baseFile = getFirstPath(style: invasion.style, folder: "invasion", id: "\(invasion.id)", postfixes: [])

        invasionPathCacheLock.doWithLock { invasionPathCache[invasion] = baseFile }
        return baseFile
    }

    private static func findMiscImage(misc: Misc) -> File? {
        let existingFile = miscPathCacheLock.doWithLock { miscPathCache[misc] }
        if existingFile != nil { return existingFile }

        let baseFile = getFirstPath(style: misc.style, folder: "misc", id: misc.id, postfixes: [])

        miscPathCacheLock.doWithLock { miscPathCache[misc] = baseFile }
        return baseFile
    }

    private static func findPokemonImage(pokemon: Pokemon) -> File? {
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

    private static func findPokestopImage(pokestop: Pokestop) -> File? {
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

    private static func findRaidImage(raid: Raid) -> File? {
        let existingFile = raidPathCacheLock.doWithLock { raidPathCache[raid] }
        if existingFile != nil { return existingFile }

        var postfixes: [String] = []
        if raid.hatched { postfixes.append("h") }
        if raid.ex { postfixes.append("ex") }

        let baseFile = getFirstPath(style: raid.style, folder: "raid/egg", id: "\(raid.level)", postfixes: postfixes)

        raidPathCacheLock.doWithLock { raidPathCache[raid] = baseFile }
        return baseFile
    }

    private static func findRewardImage(reward: Reward, pokemon: Pokemon? = nil) -> File? {
        let existingFile = rewardPathCacheLock.doWithLock { rewardPathCache[reward] }
        if existingFile != nil { return existingFile }

        var postfixes: [String] = []
        if reward.amount != nil { postfixes.append("a") }
        let baseFile: File?
        if reward.type == POGOProtos.QuestRewardProto.TypeEnum.pokemonEncounter && pokemon != nil {
            baseFile = findPokemonImage(pokemon: pokemon!)
        } else if reward.type == POGOProtos.QuestRewardProto.TypeEnum.candy {
            baseFile = getFirstPath(style: reward.style, folder: "reward/candy",
                id: "\(reward.id)", postfixes: postfixes)
        } else if reward.type == POGOProtos.QuestRewardProto.TypeEnum.xlCandy {
            baseFile = getFirstPath(style: reward.style, folder: "reward/xl_candy",
                id: "\(reward.id)", postfixes: postfixes)
        } else if reward.type == POGOProtos.QuestRewardProto.TypeEnum.megaResource {
            baseFile = getFirstPath(style: reward.style, folder: "reward/mega_resource",
                id: "\(reward.id)", postfixes: postfixes)
        } else if reward.type == POGOProtos.QuestRewardProto.TypeEnum.item {
            baseFile = getFirstPath(style: reward.style, folder: "reward/item",
                id: "\(reward.id)", postfixes: postfixes)
        } else if reward.type == POGOProtos.QuestRewardProto.TypeEnum.stardust {
            baseFile = getFirstPath(style: reward.style, folder: "reward/stardust",
                id: "\(reward.amount ?? reward.id)", postfixes: [])
        } else {
            baseFile = getFirstPath(style: reward.style, folder: "reward/\(reward.type)",
                id: "\(reward.id)", postfixes: postfixes)
        }

        rewardPathCacheLock.doWithLock { rewardPathCache[reward] = baseFile }
        return baseFile
    }

    private static func findTypeImage(type: Type) -> File? {
        let existingFile = typePathCacheLock.doWithLock { typePathCache[type] }
        if existingFile != nil { return existingFile }

        let baseFile = getFirstPath(style: type.style, folder: "type", id: "\(type.id)", postfixes: [])

        typePathCacheLock.doWithLock { typePathCache[type] = baseFile }
        return baseFile
    }

    private static func findWeatherImage(weather: Weather) -> File? {
        let existingFile = weatherPathCacheLock.doWithLock { weatherPathCache[weather] }
        if existingFile != nil { return existingFile }

        let baseFile = getFirstPath(style: weather.style, folder: "weather", id: "\(weather.id)", postfixes: [])

        weatherPathCacheLock.doWithLock { weatherPathCache[weather] = baseFile }
        return baseFile
    }

    // MARK: Building Images with ImageGenerator
    private static func buildGymImage(gym: Gym, baseFile: File) -> File? {
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

    private static func buildPokemonImage(pokemon: Pokemon, baseFile: File) -> File? {
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

    private static func buildPokestopImage(pokestop: Pokestop, baseFile: File) -> File? {
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
    private static func getFirstPath(style: String, folder: String, id: String, postfixes: [String]) -> File? {
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
        return possiblePaths.first {$0.exists}
    }

    private static func sendFile(response: HTTPResponse, file: File?) {
        if let file = file {
            do {
                try file.open(.read)
                response.setHeader(.cacheControl, value: "max-age=604800, must-revalidate")
                response.addHeader(.acceptRanges, value: "bytes")
                response.addHeader(.contentType, value: MimeType.forExtension(file.path.filePathExtension))
                response.addHeader(.contentLength, value: "\(file.size)")
                response.addHeader(.eTag, value: file.eTag)
                response.appendBody(bytes: try file.readSomeBytes(count: file.size))
                response.completed()
                file.close()
            } catch {
                Log.error(message: "[ImageApiRequestHandler] Failed to send file: \(error.localizedDescription)")
                response.respondWithError(status: .internalServerError)
            }

        } else {
            response.respondWithError(status: .notFound)
        }
    }

}

extension ImageApiRequestHandler {

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
            (reward != nil ? "_r\(reward!.type.rawValue)_\(reward!.uicon)" : "")
        }
    }

    struct Reward: Hashable {
        // Standard
        var style: String
        var id: Int
        var amount: Int?

        // Generated
        var type: POGOProtos.QuestRewardProto.TypeEnum
        var isStandard: Bool = true

        var uicon: String {
            switch type {
            case .pokemonEncounter:
                return "\(id)"
            case .megaResource, .xlCandy, .candy, .item:
                return "\(id)" + (amount != nil ? "_a\(amount!)" : "")
            case .stardust:
                return amount != nil ? "\(amount!)" : "0"
            default: return ""
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

    struct `Type`: Hashable {
        // Standard
        var style: String
        var id: Int
        var isStandard: Bool = true

        var uicon: String { "\(id)" }
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
}
