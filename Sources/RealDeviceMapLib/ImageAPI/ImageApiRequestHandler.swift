//
//  ApiRequestHandler.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 05.09.21.
//  Updated by Fabio on 06.02.21.
//

import Foundation
import PerfectLib
import PerfectHTTP
import PerfectThread
import POGOProtos

class ImageApiRequestHandler {

    internal static var defaultIconSet: String = "Shuffle"

    public static func handleGym(request: HTTPRequest, response: HTTPResponse) {
        let style = request.param(name: "style") ?? ImageApiRequestHandler.defaultIconSet
        guard let id = request.param(name: "id")?.toInt() else {
            return response.respondWithError(status: .badRequest)
        }

        let level = request.param(name: "level")?.toInt()
        let battle = request.param(name: "battle")?.toBool() ?? false
        let ex = request.param(name: "ex")?.toBool() ?? false

        let raidLevel = request.param(name: "raid_level")?.toInt()
        let raidEx = request.param(name: "raid_ex")?.toBool() ?? false
        let raidHatched = request.param(name: "raid_hatched")?.toBool() ?? false
        let raid = raidLevel != nil ?
            ImageManager.Raid(style: style, level: raidLevel!, hatched: raidHatched, ex: raidEx) : nil

        let raidPokemonId = request.param(name: "raid_pokemon_id")?.toInt()
        let raidPokemonEvolution = request.param(name: "raid_pokemon_evolution")?.toInt()
        let raidPokemonForm = request.param(name: "raid_pokemon_form")?.toInt()
        let raidPokemonCostume = request.param(name: "raid_pokemon_costume")?.toInt()
        let raidPokemonGender = request.param(name: "raid_pokemon_gender")?.toInt()
        let raidPokemon = raidPokemonId != nil ? ImageManager.Pokemon(
            style: style, id: raidPokemonId!, evolution: raidPokemonEvolution,
            form: raidPokemonForm, costume: raidPokemonCostume, gender: raidPokemonGender, spawnType: nil, ranking: nil
        ) : nil

        let gym = ImageManager.Gym(
            style: style, id: id, level: level, battle: battle, ex: ex, raid: raid, raidPokemon: raidPokemon
        )
        let file = ImageManager.global.findGymImage(gym: gym)
        sendFile(response: response, file: file)
    }

    public static func handleInvasion(request: HTTPRequest, response: HTTPResponse) {
        let style = request.param(name: "style") ?? ImageApiRequestHandler.defaultIconSet
        guard let id = request.param(name: "id")?.toInt() else {
            return response.respondWithError(status: .badRequest)
        }
        let invasion = ImageManager.Invasion(style: style, id: id)
        let file = ImageManager.global.findInvasionImage(invasion: invasion)
        sendFile(response: response, file: file)
    }

    public static func handleMisc(request: HTTPRequest, response: HTTPResponse) {
        let style = request.param(name: "style") ?? ImageApiRequestHandler.defaultIconSet
        guard let id = request.param(name: "id") else {
            return response.respondWithError(status: .badRequest)
        }
        let misc = ImageManager.Misc(style: style, id: id)
        let file = ImageManager.global.findMiscImage(misc: misc)
        sendFile(response: response, file: file)
    }

    public static func handlePokemon(request: HTTPRequest, response: HTTPResponse) {
        let style = request.param(name: "style") ?? ImageApiRequestHandler.defaultIconSet
        guard let id = request.param(name: "id")?.toInt() else {
            return response.respondWithError(status: .badRequest)
        }

        let evolution = request.param(name: "evolution")?.toInt()
        let form = request.param(name: "form")?.toInt()
        let costume = request.param(name: "costume")?.toInt()
        let gender = request.param(name: "gender")?.toInt()
        let spawnType = ImageManager.Pokemon.SpawnType(rawValue: request.param(name: "spawn_type") ?? "")
        let ranking = ImageManager.Pokemon.Ranking(rawValue: request.param(name: "ranking") ?? "")

        let pokemon = ImageManager.Pokemon(
            style: style, id: id, evolution: evolution, form: form, costume: costume, gender: gender,
                spawnType: spawnType, ranking: ranking
        )
        let file = ImageManager.global.findPokemonImage(pokemon: pokemon)
        sendFile(response: response, file: file)
    }

    public static func handlePokestop(request: HTTPRequest, response: HTTPResponse) {
        let style = request.param(name: "style") ?? ImageApiRequestHandler.defaultIconSet
        guard let id = request.param(name: "id")?.toInt() else {
            return response.respondWithError(status: .badRequest)
        }
        let invasionActive = request.param(name: "invasion")?.toBool() ?? false
        let gruntType = request.param(name: "grunt_type")?.toInt()
        let questRewardType = request.param(name: "quest_reward_type")?.toInt()
        let questItemId = request.param(name: "quest_item_id")
        let questRewardAmount = request.param(name: "quest_reward_amount")?.toInt()
        let questPokemonId = request.param(name: "quest_pokemon_id")?.toInt()
        let questFormId = request.param(name: "quest_form_id")?.toInt()
        let questGenderId = request.param(name: "quest_gender_id")?.toInt()
        let questCostumeId = request.param(name: "quest_costume_id")?.toInt()

        var invasion: ImageManager.Invasion?
        if gruntType != nil {
            invasion = ImageManager.Invasion(style: style, id: gruntType!)
        }

        var reward: ImageManager.Reward?
        var pokemon: ImageManager.Pokemon?
        // var questActive = false
        if questRewardType != nil {
            if questPokemonId != nil {
                pokemon = ImageManager.Pokemon(style: style, id: questPokemonId!, evolution: nil, form: questFormId,
                    costume: questCostumeId, gender: questGenderId, spawnType: nil, ranking: nil)
                reward = ImageManager.Reward(style: style, id: pokemon!.uicon, amount: questRewardAmount,
                    type: POGOProtos.QuestRewardProto.TypeEnum(rawValue: questRewardType!)!)
            } else {

                reward = ImageManager.Reward(style: style, id: (questItemId != nil ? questItemId! : "0"),
                    amount: questRewardAmount,
                    type: POGOProtos.QuestRewardProto.TypeEnum(rawValue: questRewardType!)!)
            }

            // questActive = true // separate icon with different color
        }

        let pokestop = ImageManager.Pokestop(style: style, id: id, invasionActive: invasionActive, questActive: false,
            invasion: invasion, reward: reward, pokemon: pokemon)

        let file = ImageManager.global.findPokestopImage(pokestop: pokestop)
        sendFile(response: response, file: file)
    }

    public static func handleRaidEgg(request: HTTPRequest, response: HTTPResponse) {
        let style = request.param(name: "style") ?? ImageApiRequestHandler.defaultIconSet
        guard let id = request.param(name: "id")?.toInt() else {
            return response.respondWithError(status: .badRequest)
        }

        let ex = request.param(name: "ex")?.toBool() ?? false
        let hatched = request.param(name: "hatched")?.toBool() ?? false

        let raid = ImageManager.Raid(style: style, level: id, hatched: hatched, ex: ex)
        let file = ImageManager.global.findRaidImage(raid: raid)
        sendFile(response: response, file: file)
    }

    public static func handleReward(request: HTTPRequest, response: HTTPResponse) {
        let style = request.param(name: "style") ?? ImageApiRequestHandler.defaultIconSet
        guard let id = request.param(name: "id") else {
            return response.respondWithError(status: .badRequest)
        }

        let type = request.param(name: "type")?.toInt() ?? 0
        let rewardType = POGOProtos.QuestRewardProto.TypeEnum(rawValue: type)
            ?? POGOProtos.QuestRewardProto.TypeEnum.unset

        let reward = ImageManager.Reward(style: style, id: id, amount: nil, type: rewardType)
        let file = ImageManager.global.findRewardImage(reward: reward)
        sendFile(response: response, file: file)
    }

    public static func handleTeam(request: HTTPRequest, response: HTTPResponse) {
        let style = request.param(name: "style") ?? ImageApiRequestHandler.defaultIconSet
        guard let id = request.param(name: "id")?.toInt() else {
            return response.respondWithError(status: .badRequest)
        }

        let team = ImageManager.Team(style: style, id: id)
        let file = ImageManager.global.findTeamImage(team: team)
        sendFile(response: response, file: file)
    }

    public static func handleType(request: HTTPRequest, response: HTTPResponse) {
        let style = request.param(name: "style") ?? ImageApiRequestHandler.defaultIconSet
        guard let id = request.param(name: "id")?.toInt() else {
            return response.respondWithError(status: .badRequest)
        }

        let type = ImageManager.PokemonType(style: style, id: id)
        let file = ImageManager.global.findTypeImage(type: type)
        sendFile(response: response, file: file)
    }

    public static func handleWeather(request: HTTPRequest, response: HTTPResponse) {
        let style = request.param(name: "style") ?? ImageApiRequestHandler.defaultIconSet
        guard let id = request.param(name: "id")?.toInt() else {
            return response.respondWithError(status: .badRequest)
        }
        let weather = ImageManager.Weather(style: style, id: id)
        let file = ImageManager.global.findWeatherImage(weather: weather)
        sendFile(response: response, file: file)
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
