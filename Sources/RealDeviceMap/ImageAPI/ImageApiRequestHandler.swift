//
//  ApiRequestHandler.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
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
        if let baseFile = baseFile, !pokemon.isStandard {
            file = buildPokemonImage(pokemon: pokemon, baseFile: baseFile)
        } else {
            file = baseFile
        }

        pokemonPathCacheLock.doWithLock { pokemonPathCache[pokemon] = file }
        return file
    }

    private static func buildPokemonImage(pokemon: Pokemon, baseFile: File) -> File? {
        let baseGeneratedPath = Dir("\(projectroot)/resources/webroot/static/img/\(pokemon.style)/generated")
        if !baseGeneratedPath.exists {
            try? baseGeneratedPath.create()
        }
        let file = File("\(baseGeneratedPath.path)\(pokemon.hash).png")
        print(file.path)
        if file.exists { return file }

        let basePath = "\(projectroot)/resources/webroot/static/img/\(pokemon.style)/misc"
        let spawnTypeFile = pokemon.spawnType != nil ? File("\(basePath)/spawn_type/\(pokemon.spawnType!.rawValue).png") : nil
        let rankingFile = pokemon.ranking != nil ? File("\(basePath)/ranking/\(pokemon.ranking!.rawValue).png") : nil

        ImageGenerator.buildPokemonImage(
            baseImage: baseFile.path,
            image: file.path,
            spawnTypeImage: spawnTypeFile != nil && spawnTypeFile!.exists ? spawnTypeFile!.path : nil,
            rankingImage: rankingFile != nil && rankingFile!.exists ? rankingFile!.path : nil
        )
        return file
    }

    private static func getFirstPath(style: String, folder: String, id: String, postfixes: [String]) -> File? {
        let basePath = "\(projectroot)/resources/webroot/static/img/\(style)/\(folder)/\(id)"

        var combinations: [[String]] = []
        let bitValues = (0...postfixes.count).map{ i in Int(pow(2, Double(i))) }

        for i in 0..<bitValues.last! {
            var combination: [String] = []
            for (j, postfix) in postfixes.enumerated() where i & bitValues[j] != 0 {
                combination.append(postfix)
            }
            combinations.append(combination)
        }

        combinations.sort{ lhs, rhs in
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
        return possiblePaths.first{$0.exists}
    }

    private static func sendFile(response: HTTPResponse, file: File?) {
        if let file = file {
            do {
                try file.open(.read)
                response.setHeader(.cacheControl, value: "max-age=604800, must-revalidate")
                response.addHeader(.acceptRanges, value: "bytes")
                response.addHeader(.contentType, value:  MimeType.forExtension(file.path.filePathExtension))
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
            return "\(id)_e\(evolution ?? 0)_f\(form ?? 0)_c\(costume ?? 0)_g\(gender ?? 0)_st\(spawnType?.rawValue ?? "0")_r\(ranking?.rawValue ?? "0")"
        }
    }

}
