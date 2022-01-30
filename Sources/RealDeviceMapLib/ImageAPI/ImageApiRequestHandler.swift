//
//  ApiRequestHandler.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 05.09.21.
//
//  swiftlint:disable superfluous_disable_command file_length type_body_length

import Foundation
import PerfectLib
import PerfectHTTP
import PerfectThread

class ImageApiRequestHandler {

    internal static var defaultIconSet: String?
    internal static let pokemonPathCacheLock = Threading.Lock()
    internal static var pokemonPathCache = [Pokemon: File]()
    internal static let gymPathCacheLock = Threading.Lock()
    internal static var gymPathCache = [Gym: File]()
    internal static let raidPathCacheLock = Threading.Lock()
    internal static var raidPathCache = [Raid: File]()

    // MARK: Pokemon
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
        // TODO: always generate even if only for resizing
        if let baseFile = baseFile, !pokemon.isStandard {
            file = buildPokemonImage(pokemon: pokemon, baseFile: baseFile)
        } else {
            file = baseFile
        }

        pokemonPathCacheLock.doWithLock { pokemonPathCache[pokemon] = file }
        return file
    }

    private static func buildPokemonImage(pokemon: Pokemon, baseFile: File) -> File? {
        let baseGeneratedPath = Dir("\(Dir.projectroot)/resources/webroot/static/img/\(pokemon.style)/generated")
        if !baseGeneratedPath.exists {
            try? baseGeneratedPath.create()
        }
        let file = File("\(baseGeneratedPath.path)\(pokemon.hash).png")
        if file.exists { return file }

        let basePath = "\(Dir.projectroot)/resources/webroot/static/img/\(pokemon.style)"
        let spawnTypeFile = pokemon.spawnType != nil ?
                File("\(basePath)/misc/spawn_type/\(pokemon.spawnType!.rawValue).png") :
                nil
        let rankingFile = pokemon.ranking != nil ?
                File("\(basePath)/misc/ranking/\(pokemon.ranking!.rawValue).png") :
                nil

        ImageGenerator.buildPokemonImage(
            baseImage: baseFile.path,
            image: file.path,
            spawnTypeImage: spawnTypeFile != nil && spawnTypeFile!.exists ? spawnTypeFile!.path : nil,
            rankingImage: rankingFile != nil && rankingFile!.exists ? rankingFile!.path : nil
        )
        return file
    }

    // MARK: Gym
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

    private static func findGymImage(gym: Gym) -> File? {
        let existingFile = gymPathCacheLock.doWithLock { gymPathCache[gym] }
        if existingFile != nil { return existingFile }

        var postfixes: [String] = []
        if let level = gym.level { postfixes.append("t\(level)") }
        if gym.battle { postfixes.append("b") }
        if gym.ex { postfixes.append("ex") }

        let baseFile = getFirstPath(style: gym.style, folder: "gym", id: "\(gym.id)", postfixes: postfixes)
        let file: File?
        // TODO: always generate even if only for resizing
        if let baseFile = baseFile, !gym.isStandard {
            file = buildGymImage(gym: gym, baseFile: baseFile)
        } else {
            file = baseFile
        }

        gymPathCacheLock.doWithLock { gymPathCache[gym] = file }
        return file
    }

    private static func buildGymImage(gym: Gym, baseFile: File) -> File? {
        let baseGeneratedPath = Dir("\(Dir.projectroot)/resources/webroot/static/img/\(gym.style)/generated")
        if !baseGeneratedPath.exists {
            try? baseGeneratedPath.create()
        }
        let file = File("\(baseGeneratedPath.path)\(gym.hash).png")
        if file.exists { return file }

        let raidImage = gym.raid != nil ? findRaidImage(raid: gym.raid!) : nil
        let raidPokemonImage = gym.raidPokemon != nil ? findPokemonImage(pokemon: gym.raidPokemon!) : nil

        guard let usedRaidImage = raidPokemonImage ?? raidImage else {
            return baseFile
        }

        ImageGenerator.buildRaidImage(baseImage: baseFile.path, raidImage: usedRaidImage.path, image: file.path)
        return file
    }

    // MARK: Raid
    private static func findRaidImage(raid: Raid) -> File? {
        let existingFile = raidPathCacheLock.doWithLock { raidPathCache[raid] }
        if existingFile != nil { return existingFile }

        var postfixes: [String] = []
        if raid.hatched { postfixes.append("h") }
        if raid.ex { postfixes.append("ex") }

        let file = getFirstPath(style: raid.style, folder: "raid/egg", id: "\(raid.level)", postfixes: postfixes)

        raidPathCacheLock.doWithLock { raidPathCache[raid] = file }
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
        }
        enum Ranking: String {
            case first = "1", second = "2", third = "3"
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
            return spawnType == nil && ranking == nil
        }

        var hash: String {
            return "\(id)" +
                (evolution != nil ? "_e\(evolution!)" : "") +
                (form != nil ? "_f\(form!)" : "") +
                (costume != nil ? "_c\(costume!)" : "") +
                (gender != nil ? "_g\(gender!)" : "") +
                (spawnType != nil ? "_st\(spawnType!.rawValue)" : "") +
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

        // Generated
        var raid: Raid?
        var raidPokemon: Pokemon?

        var isStandard: Bool {
            return raid == nil && raidPokemon == nil
        }

        var hash: String {
            return "\(id)" +
                (level != nil ? "_t\(level!)" : "") +
                "\(battle ? "_b" : "")" +
                "\(ex ? "_ex": "")" +
                "\(raid != nil && raidPokemon == nil ? "_r(\(raid!.hash)" : ""))" +
                "\(raidPokemon != nil ? "_p(\(raidPokemon!.hash)" : ""))"
        }

    }

    struct Raid: Hashable {

        // Standard
        var style: String
        var level: Int
        var hatched: Bool = false
        var ex: Bool = false

        var isStandard: Bool = true

        var hash: String {
            return "\(level)\(hatched ? "_h" : "")\(ex ? "_ex": "")"
        }

    }

}
