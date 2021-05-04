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
import PerfectMustache
import PerfectSessionMySQL
import POGOProtos
import S2Geometry
import PerfectThread

class ApiRequestHandler {

    private static var sessionDriver = MySQLSessions()

    public static func handle(request: HTTPRequest, response: HTTPResponse, route: WebServer.APIPage) {

        switch route {
        case .getData:
            handleGetData(request: request, response: response)
        case .setData:
            handleSetData(request: request, response: response)
        }
    }

    public internal(set) static var start: Date = Date(timeIntervalSince1970: 0)

    // swiftlint:disable:next cyclomatic_complexity
    private static func getPerms(request: HTTPRequest, response: HTTPResponse) -> [Group.Perm]? {
        let tmp = WebRequestHandler.getPerms(request: request, fromCache: true)
        let perms = tmp.perms
        let username = tmp.username

        if username == nil || username == "", let authorization = request.header(.authorization) {
            let base64String = authorization.replacingOccurrences(of: "Basic ", with: "")
            if let data = Data(base64Encoded: base64String), let string = String(data: data, encoding: .utf8) {
                let split = string.components(separatedBy: ":")
                if split.count == 2 {
                    if let usernameEmail = split[0].stringByDecodingURL, let password = split[1].stringByDecodingURL {
                        let user: User
                        do {
                            let host = request.host
                            if usernameEmail.contains("@") {
                                user = try User.login(email: usernameEmail, password: password, host: host)
                            } else {
                                user = try User.login(username: usernameEmail, password: password, host: host)
                            }
                        } catch {
                            if error is DBController.DBError {
                                response.respondWithError(status: .internalServerError)
                                return nil
                            } else if let error = error as? User.LoginError {
                                switch error.type {
                                case .limited, .usernamePasswordInvalid:
                                    response.respondWithError(status: .unauthorized)
                                    return nil
                                case .undefined:
                                    response.respondWithError(status: .internalServerError)
                                    return nil
                                }
                            } else {
                                response.respondWithError(status: .internalServerError)
                                return nil
                            }
                        }

                        request.session?.userid = user.username
                        if user.group != nil {
                            request.session?.data["perms"] = Group.Perm.permsToNumber(perms: user.group!.perms)
                        }
                        sessionDriver.save(session: request.session!)
                        handleGetData(request: request, response: response)
                        return nil
                    }
                }

            }
        }
        return perms
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private static func handleGetData(request: HTTPRequest, response: HTTPResponse) {

        guard let perms = getPerms(request: request, response: response) else {
            return
        }

        let minLat = request.param(name: "min_lat")?.toDouble()
        let maxLat = request.param(name: "max_lat")?.toDouble()
        let minLon = request.param(name: "min_lon")?.toDouble()
        let maxLon = request.param(name: "max_lon")?.toDouble()
        let instance = request.param(name: "instance")
        let showGyms = request.param(name: "show_gyms")?.toBool() ?? false
        let showRaids = request.param(name: "show_raids")?.toBool() ?? false
        let showPokestops = request.param(name: "show_pokestops")?.toBool() ?? false
        let showQuests = request.param(name: "show_quests")?.toBool() ?? false
        let questFilterExclude = request.param(name: "quest_filter_exclude")?.jsonDecodeForceTry() as? [String]
        let showPokemon = request.param(name: "show_pokemon")?.toBool() ?? false
        let pokemonFilterEventOnly = request.param(name: "pokemon_filter_event_only")?.toBool() ?? false
        let pokemonFilterExclude = request.param(name: "pokemon_filter_exclude")?.jsonDecodeForceTry() as? [Int]
        let pokemonFilterIV = request.param(name: "pokemon_filter_iv")?.jsonDecodeForceTry() as? [String: String]
        let raidFilterExclude = request.param(name: "raid_filter_exclude")?.jsonDecodeForceTry() as? [String]
        let gymFilterExclude = request.param(name: "gym_filter_exclude")?.jsonDecodeForceTry() as? [String]
        let pokestopFilterExclude = request.param(name: "pokestop_filter_exclude")?.jsonDecodeForceTry() as? [String]
        let spawnpointFilterExclude = request.param(name: "spawnpoint_filter_exclude")?
            .jsonDecodeForceTry() as? [String]
        let showSpawnpoints =  request.param(name: "show_spawnpoints")?.toBool() ?? false
        let showCells = request.param(name: "show_cells")?.toBool() ?? false
        let showSubmissionPlacementCells = request.param(name: "show_submission_placement_cells")?.toBool() ?? false
        let showSubmissionTypeCells = request.param(name: "show_submission_type_cells")?.toBool() ?? false
        let showWeathers = request.param(name: "show_weathers")?.toBool() ?? false
        let showDevices =  request.param(name: "show_devices")?.toBool() ?? false
        let showActiveDevices = request.param(name: "show_active_devices")?.toBool() ?? false
        let showInstances =  request.param(name: "show_instances")?.toBool() ?? false
        let showDeviceGroups = request.param(name: "show_devicegroups")?.toBool() ?? false
        let showUsers =  request.param(name: "show_users")?.toBool() ?? false
        let showGroups =  request.param(name: "show_groups")?.toBool() ?? false
        let showPokemonFilter = request.param(name: "show_pokemon_filter")?.toBool() ?? false
        let showQuestFilter = request.param(name: "show_quest_filter")?.toBool() ?? false
        let showRaidFilter = request.param(name: "show_raid_filter")?.toBool() ?? false
        let showGymFilter = request.param(name: "show_gym_filter")?.toBool() ?? false
        let showPokestopFilter = request.param(name: "show_pokestop_filter")?.toBool() ?? false
        let showSpawnpointFilter = request.param(name: "show_spawnpoint_filter")?.toBool() ?? false
        let formatted =  request.param(name: "formatted")?.toBool() ?? false
        let lastUpdate = request.param(name: "last_update")?.toUInt32() ?? 0
        let showAssignments = request.param(name: "show_assignments")?.toBool() ?? false
        let showAssignmentGroups = request.param(name: "show_assignmentgroups")?.toBool() ?? false
        let showIVQueue = request.param(name: "show_ivqueue")?.toBool() ?? false
        let showDiscordRules = request.param(name: "show_discordrules")?.toBool() ?? false
        let showStatus = request.param(name: "show_status")?.toBool() ?? false

        if (showGyms || showRaids || showPokestops || showPokemon || showSpawnpoints ||
            showCells || showSubmissionTypeCells || showSubmissionPlacementCells || showWeathers) &&
            (minLat == nil || maxLat == nil || minLon == nil || maxLon == nil) {
            response.respondWithError(status: .badRequest)
            return
        }

        let permViewMap = perms.contains(.viewMap)

        guard let mysql = DBController.global.mysql else {
            response.respondWithError(status: .internalServerError)
            return
        }

        var data = [String: Any]()
        let isPost = request.method == .post
        let permShowRaid = perms.contains(.viewMapRaid)
        let permShowGym = perms.contains(.viewMapGym)
        if isPost && (permViewMap && (showGyms && permShowGym || showRaids && permShowRaid)) {
            data["gyms"] = try? Gym.getAll(
                mysql: mysql, minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!, updated: lastUpdate,
                raidsOnly: !showGyms, showRaids: permShowRaid, raidFilterExclude: raidFilterExclude,
                gymFilterExclude: gymFilterExclude
            )
        }
        let permShowStops = perms.contains(.viewMapPokestop)
        let permShowQuests =  perms.contains(.viewMapQuest)
        let permShowLures = perms.contains(.viewMapLure)
        let permShowInvasions = perms.contains(.viewMapInvasion)
        if isPost && (permViewMap && (showPokestops && permShowStops || showQuests && permShowQuests)) {
            data["pokestops"] = try? Pokestop.getAll(
                mysql: mysql, minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!, updated: lastUpdate,
                questsOnly: !showPokestops, showQuests: permShowQuests, showLures: permShowLures,
                showInvasions: permShowInvasions, questFilterExclude: questFilterExclude,
                pokestopFilterExclude: pokestopFilterExclude
            )
        }
        let permShowIV = perms.contains(.viewMapIV)
        let permShowEventPokemon = perms.contains(.viewMapEventPokemon)
        if isPost && permViewMap && showPokemon && perms.contains(.viewMapPokemon) {
            data["pokemon"] = try? Pokemon.getAll(
                mysql: mysql, minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!,
                showIV: permShowIV, updated: lastUpdate, pokemonFilterExclude: pokemonFilterExclude,
                pokemonFilterIV: pokemonFilterIV, isEvent: pokemonFilterEventOnly && permShowEventPokemon
            )
        }
        if isPost && permViewMap && showSpawnpoints && perms.contains(.viewMapSpawnpoint) {
            data["spawnpoints"] = try? SpawnPoint.getAll(
                mysql: mysql, minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!,
                updated: lastUpdate, spawnpointFilterExclude: spawnpointFilterExclude
            )
        }
        if isPost && permViewMap && showActiveDevices && perms.contains(.viewMapDevice) {
            data["active_devices"] = try? Device.getAll(
                mysql: mysql
            )
        }
        if isPost && showCells && perms.contains(.viewMapCell) {
            data["cells"] = try? Cell.getAll(
                mysql: mysql, minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!, updated: lastUpdate
            )
        }
        if lastUpdate == 0 && isPost && showSubmissionPlacementCells && perms.contains(.viewMapSubmissionCells) {
            let result = try? SubmissionPlacementCell.getAll(
                mysql: mysql, minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!
            )
            data["submission_placement_cells"] = result?.cells
            data["submission_placement_rings"] = result?.rings
        }
        if lastUpdate == 0 && isPost && showSubmissionTypeCells && perms.contains(.viewMapSubmissionCells) {
            data["submission_type_cells"] = try? SubmissionTypeCell.getAll(
                mysql: mysql, minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!
            )
        }
        if isPost && showWeathers && perms.contains(.viewMapWeather) {
			data["weather"] = try? Weather.getAll(
                mysql: mysql, minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!, updated: lastUpdate
            )
        }
        if permViewMap && showPokemonFilter {

            let hideString = Localizer.global.get(value: "filter_hide")
            let showString = Localizer.global.get(value: "filter_show")
            let onString = Localizer.global.get(value: "filter_on")
            let offString = Localizer.global.get(value: "filter_off")
            let ivString = Localizer.global.get(value: "filter_iv")

            let smallString = Localizer.global.get(value: "filter_small")
            let normalString = Localizer.global.get(value: "filter_normal")
            let largeString = Localizer.global.get(value: "filter_large")
            let hugeString = Localizer.global.get(value: "filter_huge")

            let pokemonTypeString = Localizer.global.get(value: "filter_pokemon")
            let eventsTypeString = Localizer.global.get(value: "filter_event")
            let globalIVTypeString = Localizer.global.get(value: "filter_global_iv")

            let eventOnlyString = Localizer.global.get(value: "filter_event_only")
            let globalIV = Localizer.global.get(value: "filter_global_iv")
            let configureString = Localizer.global.get(value: "filter_configure")
            let andString = Localizer.global.get(value: "filter_and")
            let orString = Localizer.global.get(value: "filter_or")

            var pokemonData = [[String: Any]]()

            if permShowEventPokemon {
                 let filter = """
                    <div class="btn-group btn-group-toggle" data-toggle="buttons">
                        <label class="btn btn-sm btn-off select-button-new" data-id="event_only"
                         data-type="pokemon-iv" data-info="event_only_hide">
                            <input type="radio" name="options" id="hide" autocomplete="off">\(offString)
                        </label>
                        <label class="btn btn-sm btn-on select-button-new" data-id="event_only"
                         data-type="pokemon-iv" data-info="event_only_show">
                            <input type="radio" name="options" id="show" autocomplete="off">\(onString)
                        </label>
                    </div>
                """
                pokemonData.append([
                    "id": [
                        "formatted": "",
                        "sort": -1
                    ],
                    "name": eventOnlyString,
                    "image": "Event",
                    "filter": filter,
                    "size": "",
                    "type": eventsTypeString
                ])
            }

            if permShowIV {
                for i in 0...1 {

                    let id: String
                    if i == 0 {
                        id = "and"
                    } else {
                        id = "or"
                    }

                     let filter = """
                        <div class="btn-group btn-group-toggle" data-toggle="buttons">
                            <label class="btn btn-sm btn-off select-button-new" data-id="\(id)"
                             data-type="pokemon-iv" data-info="off">
                                <input type="radio" name="options" id="hide" autocomplete="off">\(offString)
                            </label>
                            <label class="btn btn-sm btn-on select-button-new" data-id="\(id)"
                             data-type="pokemon-iv" data-info="on">
                                <input type="radio" name="options" id="show" autocomplete="off">\(onString)
                            </label>
                        </div>
                    """

                    let andOrString: String
                    if i == 0 {
                        andOrString = andString
                    } else {
                        andOrString = orString
                    }

                    let size = "<button class=\"btn btn-sm btn-primary configure-button-new\" " +
                        "data-id=\"\(id)\" data-type=\"pokemon-iv\" data-info=\"global-iv\">\(configureString)</button>"

                    pokemonData.append([
                        "id": [
                            "formatted": andOrString,
                            "sort": i
                        ],
                        "name": globalIV,
                        "image": andOrString,
                        "filter": filter,
                        "size": size,
                        "type": globalIVTypeString
                    ])

                }
            }

            for i in 1...WebRequestHandler.maxPokemonId {

                let ivLabel: String
                if permShowIV {
                    ivLabel = """
                        <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                         data-type="pokemon" data-info="iv">
                        <input type="radio" name="options" id="iv" autocomplete="off">\(ivString)
                        </label>
                    """
                } else {
                    ivLabel = ""
                }
                let filter = """
                    <div class="btn-group btn-group-toggle" data-toggle="buttons">
                        <label class="btn btn-sm btn-off select-button-new" data-id="\(i)"
                         data-type="pokemon" data-info="hide">
                            <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
                        </label>
                        <label class="btn btn-sm btn-on select-button-new" data-id="\(i)"
                         data-type="pokemon" data-info="show">
                            <input type="radio" name="options" id="show" autocomplete="off">\(showString)
                        </label>
                        \(ivLabel)
                    </div>
                """

                let size = """
                    <div class="btn-group btn-group-toggle" data-toggle="buttons">
                        <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                         data-type="pokemon" data-info="small">
                            <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
                        </label>
                        <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                         data-type="pokemon" data-info="normal">
                            <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
                        </label>
                        <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                         data-type="pokemon" data-info="large">
                            <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
                        </label>
                        <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                         data-type="pokemon" data-info="huge">
                            <input type="radio" name="options" id="show" autocomplete="off">\(hugeString)
                        </label>
                    </div>
                """

                pokemonData.append([
                    "id": [
                        "formatted": String(format: "%03d", i),
                        "sort": i+1
                    ],
                    "name": Localizer.global.get(value: "poke_\(i)") ,
                    "image": "<img class=\"lazy_load\" data-src=\"/static/img/pokemon/\(i).png\"" +
                             "style=\"height:50px; width:50px;\">",
                    "filter": filter,
                    "size": size,
                    "type": pokemonTypeString
                ])
            }
            data["pokemon_filters"] = pokemonData
        }

        if permViewMap && showQuestFilter {

            let hideString = Localizer.global.get(value: "filter_hide")
            let showString = Localizer.global.get(value: "filter_show")

            let smallString = Localizer.global.get(value: "filter_small")
            let normalString = Localizer.global.get(value: "filter_normal")
            let largeString = Localizer.global.get(value: "filter_large")
            let hugeString = Localizer.global.get(value: "filter_huge")

            let pokemonTypeString = Localizer.global.get(value: "filter_pokemon")
            let miscTypeString = Localizer.global.get(value: "filter_misc")
            let itemsTypeString = Localizer.global.get(value: "filter_items")

            var questData = [[String: Any]]()

            // Misc
            for i in 1...6 {

                let itemName: String
                switch i {
                case 1:
                    itemName = Localizer.global.get(value: "filter_stardust")
                case 2:
                    itemName = Localizer.global.get(value: "filter_xp")
                case 3:
                    itemName = Localizer.global.get(value: "filter_candy")
                case 4:
                    itemName = Localizer.global.get(value: "filter_pokecoin")
                case 5:
                    itemName = Localizer.global.get(value: "filter_sticker")
                default:
                    itemName = Localizer.global.get(value: "filter_mega_energy")
                }

                let filter = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-off select-button-new" data-id="\(i)"
                 data-type="quest-misc" data-info="hide">
                <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
                </label>
                <label class="btn btn-sm btn-on select-button-new" data-id="\(i)"
                 data-type="quest-misc" data-info="show">
                <input type="radio" name="options" id="show" autocomplete="off">\(showString)
                </label>
                </div>
                """

                let size = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="quest-misc" data-info="small">
                <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="quest-misc" data-info="normal">
                <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="quest-misc" data-info="large">
                <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="quest-misc" data-info="huge">
                <input type="radio" name="options" id="show" autocomplete="off">\(hugeString)
                </label>
                </div>
                """

                questData.append([
                    "id": [
                        "formatted": String(format: "%03d", i),
                        "sort": i
                    ],
                    "name": itemName,
                    "image": "<img class=\"lazy_load\" data-src=\"/static/img/item/\(-i).png\" " +
                             "style=\"height:50px; width:50px;\">",
                    "filter": filter,
                    "size": size,
                    "type": miscTypeString
                ])
            }

            // Items
            var itemI = 1
            for item in Item.allAvilable {

                let filter = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-off select-button-new" data-id="\(item.rawValue)"
                 data-type="quest-item" data-info="hide">
                <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
                </label>
                <label class="btn btn-sm btn-on select-button-new" data-id="\(item.rawValue)"
                 data-type="quest-item" data-info="show">
                <input type="radio" name="options" id="show" autocomplete="off">\(showString)
                </label>
                </div>
                """

                let size = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-size select-button-new" data-id="\(item.rawValue)"
                 data-type="quest-item" data-info="small">
                <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(item.rawValue)"
                 data-type="quest-item" data-info="normal">
                <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(item.rawValue)"
                 data-type="quest-item" data-info="large">
                <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(item.rawValue)"
                 data-type="quest-item" data-info="huge">
                <input type="radio" name="options" id="show" autocomplete="off">\(hugeString)
                </label>
                </div>
                """

                questData.append([
                    "id": [
                        "formatted": String(format: "%03d", itemI),
                        "sort": itemI+100
                    ],
                    "name": Localizer.global.get(value: "item_\(item.rawValue)") ,
                    "image": "<img class=\"lazy_load\" data-src=\"/static/img/item/\(item.rawValue).png\" " +
                             "style=\"height:50px; width:50px;\">",
                    "filter": filter,
                    "size": size,
                    "type": itemsTypeString
                ])
                itemI += 1
            }

            // Pokemon
            for i in 1...WebRequestHandler.maxPokemonId {

                let filter = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-off select-button-new" data-id="\(i)"
                 data-type="quest-pokemon" data-info="hide">
                <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
                </label>
                <label class="btn btn-sm btn-on select-button-new" data-id="\(i)"
                 data-type="quest-pokemon" data-info="show">
                <input type="radio" name="options" id="show" autocomplete="off">\(showString)
                </label>
                </div>
                """

                let size = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="quest-pokemon" data-info="small">
                <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="quest-pokemon" data-info="normal">
                <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="quest-pokemon" data-info="large">
                <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="quest-pokemon" data-info="huge">
                <input type="radio" name="options" id="show" autocomplete="off">\(hugeString)
                </label>
                </div>
                """

                questData.append([
                    "id": [
                        "formatted": String(format: "%03d", i),
                        "sort": i+200
                    ],
                    "name": Localizer.global.get(value: "poke_\(i)") ,
                    "image": "<img class=\"lazy_load\" data-src=\"/static/img/pokemon/\(i).png\" " +
                             "style=\"height:50px; width:50px;\">",
                    "filter": filter,
                    "size": size,
                    "type": pokemonTypeString
                    ])
            }
            data["quest_filters"] = questData
        }

        if permViewMap && showRaidFilter {
            let hideString = Localizer.global.get(value: "filter_hide")
            let showString = Localizer.global.get(value: "filter_show")

            let smallString = Localizer.global.get(value: "filter_small")
            let normalString = Localizer.global.get(value: "filter_normal")
            let largeString = Localizer.global.get(value: "filter_large")
            let hugeString = Localizer.global.get(value: "filter_huge")

            let generalString = Localizer.global.get(value: "filter_general")
            let raidLevelsString = Localizer.global.get(value: "filter_raid_levels")
            let pokemonString = Localizer.global.get(value: "filter_pokemon")

            var raidData = [[String: Any]]()

            let raidTimers = Localizer.global.get(value: "filter_raid_timers")

            let filter = """
            <div class="btn-group btn-group-toggle" data-toggle="buttons">
            <label class="btn btn-sm btn-off select-button-new" data-id="timers"
             data-type="raid-timers" data-info="hide">
            <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
            </label>
            <label class="btn btn-sm btn-on select-button-new" data-id="timers"
             data-type="raid-timers" data-info="show">
            <input type="radio" name="options" id="show" autocomplete="off">\(showString)
            </label>
            </div>
            """

            let size = """
            <div class="btn-group btn-group-toggle" data-toggle="buttons">
            <label class="btn btn-sm btn-size select-button-new" data-id="timers"
             data-type="raid-timers" data-info="small" disabled>
            <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="timers"
             data-type="raid-timers" data-info="normal" disabled>
            <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="timers"
             data-type="raid-timers" data-info="large" disabled>
            <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="timers"
             data-type="raid-timers" data-info="huge" disabled>
            <input type="radio" name="options" id="show" autocomplete="off">\(hugeString)
            </label>
            </div>
            """

            raidData.append([
                "id": [
                    "formatted": String(format: "%03d", 0),
                    "sort": 0
                ],
                "name": raidTimers,
                "image": "<img class=\"lazy_load\" data-src=\"/static/img/misc/timer.png\" " +
                         "style=\"height:50px; width:50px;\">",
                "filter": filter,
                "size": size,
                "type": generalString
                ])

            // Level
            for i in 1...6 {

                let raidLevel = Localizer.global.get(value: "filter_raid_level_\(i)")

                let filter = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-off select-button-new" data-id="\(i)"
                 data-type="raid-level" data-info="hide">
                <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
                </label>
                <label class="btn btn-sm btn-on select-button-new" data-id="\(i)"
                 data-type="raid-level" data-info="show">
                <input type="radio" name="options" id="show" autocomplete="off">\(showString)
                </label>
                </div>
                """

                let size = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="raid-level" data-info="small">
                <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="raid-level" data-info="normal">
                <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="raid-level" data-info="large">
                <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="raid-level" data-info="huge">
                <input type="radio" name="options" id="show" autocomplete="off">\(hugeString)
                </label>
                </div>
                """

                raidData.append([
                    "id": [
                        "formatted": String(format: "%03d", i),
                        "sort": i
                    ],
                    "name": raidLevel,
                    "image": "<img class=\"lazy_load\" data-src=\"/static/img/egg/\(i).png\" " +
                             "style=\"height:50px; width:50px;\">",
                    "filter": filter,
                    "size": size,
                    "type": raidLevelsString
                ])
            }

            // Pokemon
            for i in 1...WebRequestHandler.maxPokemonId {

                let filter = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-off select-button-new" data-id="\(i)"
                 data-type="raid-pokemon" data-info="hide">
                <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
                </label>
                <label class="btn btn-sm btn-on select-button-new" data-id="\(i)"
                 data-type="raid-pokemon" data-info="show">
                <input type="radio" name="options" id="show" autocomplete="off">\(showString)
                </label>
                </div>
                """

                let size = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="raid-pokemon" data-info="small">
                <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="raid-pokemon" data-info="normal">
                <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="raid-pokemon" data-info="large">
                <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="raid-pokemon" data-info="huge">
                <input type="radio" name="options" id="show" autocomplete="off">\(hugeString)
                </label>
                </div>
                """
                raidData.append([
                    "id": [
                        "formatted": String(format: "%03d", i),
                        "sort": i+200
                    ],
                    "name": Localizer.global.get(value: "poke_\(i)"),
                    "image": "<img class=\"lazy_load\" data-src=\"/static/img/pokemon/\(i).png\" " +
                             "style=\"height:50px; width:50px;\">",
                    "filter": filter,
                    "size": size,
                    "type": pokemonString
                ])
            }

            data["raid_filters"] = raidData
        }

        if permViewMap && showGymFilter {
            let hideString = Localizer.global.get(value: "filter_hide")
            let showString = Localizer.global.get(value: "filter_show")

            let smallString = Localizer.global.get(value: "filter_small")
            let normalString = Localizer.global.get(value: "filter_normal")
            let largeString = Localizer.global.get(value: "filter_large")
            let hugeString = Localizer.global.get(value: "filter_huge")

            let gymTeamString = Localizer.global.get(value: "filter_gym_team")
            let gymOptionsString = Localizer.global.get(value: "filter_gym_options")
            let availableSlotsString = Localizer.global.get(value: "filter_gym_available_slots")

            var gymData = [[String: Any]]()
            // Team
            for i in 0...3 {

                let gymTeam = Localizer.global.get(value: "filter_gym_team_\(i)")

                let filter = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-off select-button-new" data-id="\(i)"
                 data-type="gym-team" data-info="hide">
                <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
                </label>
                <label class="btn btn-sm btn-on select-button-new" data-id="\(i)"
                 data-type="gym-team" data-info="show">
                <input type="radio" name="options" id="show" autocomplete="off">\(showString)
                </label>
                </div>
                """

                let size = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="gym-team" data-info="small">
                <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="gym-team" data-info="normal">
                <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="gym-team" data-info="large">
                <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="gym-team" data-info="huge">
                <input type="radio" name="options" id="show" autocomplete="off">\(hugeString)
                </label>
                </div>
                """

                gymData.append([
                    "id": [
                        "formatted": String(format: "%03d", i),
                        "sort": i
                    ],
                    "name": gymTeam,
                    "image": "<img class=\"lazy_load\" data-src=\"/static/img/gym/\(i)_\(i).png\" " +
                             "style=\"height:50px; width:50px;\">",
                    "filter": filter,
                    "size": size,
                    "type": gymTeamString
                ])
            }

            // EX raid eligible gyms
            let exFilter = """
            <div class="btn-group btn-group-toggle" data-toggle="buttons">
            <label class="btn btn-sm btn-off select-button-new" data-id="ex" data-type="gym-ex" data-info="hide">
            <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
            </label>
            <label class="btn btn-sm btn-on select-button-new" data-id="ex" data-type="gym-ex" data-info="show">
            <input type="radio" name="options" id="show" autocomplete="off">\(showString)
            </label>
            </div>
            """

            let exSize = """
            <div class="btn-group btn-group-toggle" data-toggle="buttons">
            <label class="btn btn-sm btn-size select-button-new" data-id="ex" data-type="gym-ex" data-info="small">
            <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="ex" data-type="gym-ex" data-info="normal">
            <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="ex" data-type="gym-ex" data-info="large">
            <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="ex" data-type="gym-ex" data-info="huge">
            <input type="radio" name="options" id="show" autocomplete="off">\(hugeString)
            </label>
            </div>
            """

            gymData.append([
                "id": [
                    "formatted": String(format: "%03d", 5), // Need a better way to display, new section?
                    "sort": 5
                ],
                "name": Localizer.global.get(value: "filter_raid_ex") ,
                "image": "<img class=\"lazy_load\" data-src=\"/static/img/item/1403.png\" " +
                         "style=\"height:50px; width:50px;\">",
                "filter": exFilter,
                "size": exSize,
                "type": gymOptionsString
            ])

            // Available slots
            for i in 0...6 {
                let availableSlots = Localizer.global.get(value: "filter_gym_available_slots_\(i)")

                let filter = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-off select-button-new" data-id="\(i)"
                 data-type="gym-slots" data-info="hide">
                <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
                </label>
                <label class="btn btn-sm btn-on select-button-new" data-id="\(i)"
                 data-type="gym-slots" data-info="show">
                <input type="radio" name="options" id="show" autocomplete="off">\(showString)
                </label>
                </div>
                """

                let size = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="gym-slots" data-info="small" disabled>
                <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="gym-slots" data-info="normal" disabled>
                <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="gym-slots" data-info="large" disabled>
                <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="gym-slots" data-info="huge" disabled>
                <input type="radio" name="options" id="show" autocomplete="off">\(hugeString)
                </label>
                </div>
                """

                let team = (UInt16.random % 3) + 1

                gymData.append([
                    "id": [
                        "formatted": String(format: "%03d", i),
                        "sort": i+100
                    ],
                    "name": availableSlots,
                    "image": "<img class=\"lazy_load\" data-src=\"/static/img/gym/\(i == 6 ? 0 : team)_\(6 - i).png\"" +
                             " style=\"height:50px; width:50px;\">",
                    "filter": filter,
                    "size": size,
                    "type": availableSlotsString
                ])
            }

            data["gym_filters"] = gymData
        }

        if permViewMap && showPokestopFilter {
            let hideString = Localizer.global.get(value: "filter_hide")
            let showString = Localizer.global.get(value: "filter_show")

            let smallString = Localizer.global.get(value: "filter_small")
            let normalString = Localizer.global.get(value: "filter_normal")
            let largeString = Localizer.global.get(value: "filter_large")
            let hugeString = Localizer.global.get(value: "filter_huge")

            let pokestopOptionsString = Localizer.global.get(value: "filter_pokestop_options")

            var pokestopData = [[String: Any]]()

            let pokestopNormal = Localizer.global.get(value: "filter_pokestop_normal")
            let pokestopInvasion = Localizer.global.get(value: "filter_pokestop_invasion")

            let filter = """
            <div class="btn-group btn-group-toggle" data-toggle="buttons">
            <label class="btn btn-sm btn-off select-button-new" data-id="normal"
             data-type="pokestop-normal" data-info="hide">
            <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
            </label>
            <label class="btn btn-sm btn-on select-button-new" data-id="normal"
             data-type="pokestop-normal" data-info="show">
            <input type="radio" name="options" id="show" autocomplete="off">\(showString)
            </label>
            </div>
            """

            let size = """
            <div class="btn-group btn-group-toggle" data-toggle="buttons">
            <label class="btn btn-sm btn-size select-button-new" data-id="normal"
             data-type="pokestop-normal" data-info="small">
            <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="normal"
             data-type="pokestop-normal" data-info="normal">
            <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="normal"
             data-type="pokestop-normal" data-info="large">
            <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="normal"
             data-type="pokestop-normal" data-info="huge">
            <input type="radio" name="options" id="show" autocomplete="off">\(hugeString)
            </label>
            </div>
            """

            pokestopData.append([
                "id": [
                    "formatted": String(format: "%03d", 0),
                    "sort": 0
                ],
                "name": pokestopNormal,
                "image": "<img class=\"lazy_load\" data-src=\"/static/img/pokestop/0.png\" " +
                         "style=\"height:50px; width:50px;\">",
                "filter": filter,
                "size": size,
                "type": pokestopOptionsString
            ])

            for i in 1...5 {
                let pokestopLure = Localizer.global.get(value: "filter_pokestop_lure_\(i)")

                let filter = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-off select-button-new" data-id="\(i)"
                 data-type="pokestop-lure" data-info="hide">
                <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
                </label>
                <label class="btn btn-sm btn-on select-button-new" data-id="\(i)"
                 data-type="pokestop-lure" data-info="show">
                <input type="radio" name="options" id="show" autocomplete="off">\(showString)
                </label>
                </div>
                """

                let size = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="pokestop-lure" data-info="small">
                <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="pokestop-lure" data-info="normal">
                <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="pokestop-lure" data-info="large">
                <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)"
                 data-type="pokestop-lure" data-info="huge">
                <input type="radio" name="options" id="show" autocomplete="off">\(hugeString)
                </label>
                </div>
                """

                pokestopData.append([
                    "id": [
                        "formatted": String(format: "%03d", i),
                        "sort": i
                    ],
                    "name": pokestopLure,
                    "image": "<img class=\"lazy_load\" data-src=\"/static/img/pokestop/\(i).png\" " +
                             "style=\"height:50px; width:50px;\">",
                    "filter": filter,
                    "size": size,
                    "type": pokestopOptionsString
                ])
            }

            let trFilter = """
            <div class="btn-group btn-group-toggle" data-toggle="buttons">
            <label class="btn btn-sm btn-off select-button-new" data-id="invasion"
             data-type="pokestop-invasion" data-info="hide">
            <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
            </label>
            <label class="btn btn-sm btn-on select-button-new" data-id="invasion"
             data-type="pokestop-invasion" data-info="show">
            <input type="radio" name="options" id="show" autocomplete="off">\(showString)
            </label>
            </div>
            """

            let trSize = """
            <div class="btn-group btn-group-toggle" data-toggle="buttons">
            <label class="btn btn-sm btn-size select-button-new" data-id="invasion"
             data-type="pokestop-invasion" data-info="small">
            <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="invasion"
             data-type="pokestop-invasion" data-info="normal">
            <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="invasion"
             data-type="pokestop-invasion" data-info="large">
            <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="invasion"
             data-type="pokestop-invasion" data-info="huge">
            <input type="radio" name="options" id="show" autocomplete="off">\(hugeString)
            </label>
            </div>
            """

            pokestopData.append([
                "id": [
                    "formatted": String(format: "%03d", 5),
                    "sort": 5
                ],
                "name": pokestopInvasion,
                "image": "<img class=\"lazy_load\" data-src=\"/static/img/pokestop/i0.png\" " +
                         "style=\"height:50px; width:50px;\">",
                "filter": trFilter,
                "size": trSize,
                "type": pokestopOptionsString
                ])

            data["pokestop_filters"] = pokestopData
        }

        if permViewMap && showSpawnpointFilter {
            let hideString = Localizer.global.get(value: "filter_hide")
            let showString = Localizer.global.get(value: "filter_show")

            let smallString = Localizer.global.get(value: "filter_small")
            let normalString = Localizer.global.get(value: "filter_normal")
            let largeString = Localizer.global.get(value: "filter_large")
            let hugeString = Localizer.global.get(value: "filter_huge")

            let spawnpointOptionsString = Localizer.global.get(value: "filter_spawnpoint_options")
            let spawnpointWithTimerString = Localizer.global.get(value: "filter_spawnpoint_with_timer")
            let spawnpointWithoutTimerString = Localizer.global.get(value: "filter_spawnpoint_without_timer")

            var spawnpointData = [[String: Any]]()

            var filter = """
            <div class="btn-group btn-group-toggle" data-toggle="buttons">
            <label class="btn btn-sm btn-off select-button-new" data-id="no-timer"
             data-type="spawnpoint-timer" data-info="hide">
            <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
            </label>
            <label class="btn btn-sm btn-on select-button-new" data-id="no-timer"
             data-type="spawnpoint-timer" data-info="show">
            <input type="radio" name="options" id="show" autocomplete="off">\(showString)
            </label>
            </div>
            """

            var size = """
            <div class="btn-group btn-group-toggle" data-toggle="buttons">
            <label class="btn btn-sm btn-size select-button-new" data-id="no-timer"
             data-type="spawnpoint-timer" data-info="small">
            <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="no-timer"
             data-type="spawnpoint-timer" data-info="normal">
            <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="no-timer"
             data-type="spawnpoint-timer" data-info="large">
            <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="no-timer"
             data-type="spawnpoint-timer" data-info="huge">
            <input type="radio" name="options" id="show" autocomplete="off">\(hugeString)
            </label>
            </div>
            """

            spawnpointData.append([
                "id": [
                    "formatted": String(format: "%03d", 0),
                    "sort": 0
                ],
                "name": spawnpointWithoutTimerString,
                "image": "<img class=\"lazy_load\" data-src=\"/static/img/spawnpoint/0.png\" " +
                         "style=\"height:50px; width:50px;\">",
                "filter": filter,
                "size": size,
                "type": spawnpointOptionsString
            ])

            filter = """
            <div class="btn-group btn-group-toggle" data-toggle="buttons">
            <label class="btn btn-sm btn-off select-button-new" data-id="with-timer"
             data-type="spawnpoint-timer" data-info="hide">
            <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
            </label>
            <label class="btn btn-sm btn-on select-button-new" data-id="with-timer"
             data-type="spawnpoint-timer" data-info="show">
            <input type="radio" name="options" id="show" autocomplete="off">\(showString)
            </label>
            </div>
            """

            size = """
            <div class="btn-group btn-group-toggle" data-toggle="buttons">
            <label class="btn btn-sm btn-size select-button-new" data-id="with-timer"
             data-type="spawnpoint-timer" data-info="small">
            <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="with-timer"
             data-type="spawnpoint-timer" data-info="normal">
            <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="with-timer"
             data-type="spawnpoint-timer" data-info="large">
            <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="with-timer"
             data-type="spawnpoint-timer" data-info="huge">
            <input type="radio" name="options" id="show" autocomplete="off">\(hugeString)
            </label>
            </div>
            """

            spawnpointData.append([
                "id": [
                    "formatted": String(format: "%03d", 1),
                    "sort": 1
                ],
                "name": spawnpointWithTimerString,
                "image": "<img class=\"lazy_load\" data-src=\"/static/img/spawnpoint/1.png\" " +
                         "style=\"height:50px; width:50px;\">",
                "filter": filter,
                "size": size,
                "type": spawnpointOptionsString
            ])

            data["spawnpoint_filters"] = spawnpointData
        }

        if showDevices && perms.contains(.admin) {

            let devices = try? Device.getAll(mysql: mysql)
            var jsonArray = [[String: Any]]()

            if devices != nil {
                for device in devices! {
                    var deviceData = [String: Any]()
                    // deviceData["chk"] = ""
                    deviceData["uuid"] = device.uuid
                    deviceData["host"] = device.lastHost ?? ""
                    deviceData["instance"] = device.instanceName ?? ""
                    deviceData["username"] = device.accountUsername ?? ""

                    if formatted {
                        let formattedDate: String
                        if device.lastSeen == 0 {
                            formattedDate = ""
                        } else {
                            let date = Date(timeIntervalSince1970: TimeInterval(device.lastSeen))
                            let formatter = DateFormatter()
                            formatter.dateFormat = "HH:mm:ss dd.MM.yyy"
                            formatter.timeZone = Localizer.global.timeZone
                            formattedDate = formatter.string(from: date)
                        }
                        deviceData["last_seen"] = ["timestamp": device.lastSeen, "formatted": formattedDate]
                        deviceData["buttons"] = "<a href=\"/dashboard/device/assign/\(device.uuid.encodeUrl()!)\" " +
                                                "role=\"button\" class=\"btn btn-primary\">Assign Instance</a>"
                    } else {
                        deviceData["last_seen"] = device.lastSeen as Any
                    }
                    jsonArray.append(deviceData)
                }
            }
            data["devices"] = jsonArray

        }

        if showInstances && perms.contains(.admin) {

            let instances = try? Instance.getAll(mysql: mysql, getData: false)
            var jsonArray = [[String: Any]]()

            if instances != nil {
                for instance in instances! {
                    var instanceData = [String: Any]()
                    instanceData["name"] = instance.name
                    instanceData["count"] = instance.count
                    switch instance.type {
                    case .circleRaid:
                        instanceData["type"] = "Circle Raid"
                    case .circleSmartRaid:
                        instanceData["type"] = "Circle Smart Raid"
                    case .circlePokemon:
                        instanceData["type"] = "Circle Pokemon"
                    case .circleSmartPokemon:
                        instanceData["type"] = "Circle Smart Pokemon"
                    case .autoQuest:
                        instanceData["type"] = "Auto Quest"
                    case .pokemonIV:
                        instanceData["type"] = "Pokemon IV"
                    case .leveling:
                        instanceData["type"] = "Leveling"
                    }

                    if formatted {
                        let status = InstanceController.global.getInstanceStatus(
                            mysql: mysql,
                            instance: instance,
                            formatted: true
                        )
                        if let status = status as? String {
                            instanceData["status"] = status
                        } else {
                            instanceData["status"] = "?"
                        }
                        instanceData["buttons"] = "<a href=\"/dashboard/instance/edit/\(instance.name.encodeUrl()!)\"" +
                                                  " role=\"button\" class=\"btn btn-primary\">Edit Instance</a>"
                    } else {
                        instanceData["status"] = InstanceController.global.getInstanceStatus(
                            mysql: mysql,
                            instance: instance,
                            formatted: false
                        ) as Any
                    }
                    jsonArray.append(instanceData)
                }
            }
            data["instances"] = jsonArray
        }

        if showDeviceGroups && perms.contains(.admin) {

            let deviceGroups = try? DeviceGroup.getAll(mysql: mysql)
            let devices = try? Device.getAll(mysql: mysql)

            var jsonArray = [[String: Any]]()

            if deviceGroups != nil {
                for deviceGroup in deviceGroups! {
                    let devicesInGroup = devices?.filter({ deviceGroup.deviceUUIDs.contains($0.uuid) }) ?? []
                    let instances = Array(
                        Set(devicesInGroup.filter({ $0.instanceName != nil }).map({ $0.instanceName! }))
                    ).sorted()

                    var deviceGroupData = [String: Any]()
                    deviceGroupData["name"] = deviceGroup.name

                    if formatted {
                        deviceGroupData["instances"] = instances.joined(separator: ", ")
                        deviceGroupData["devices"] = deviceGroup.deviceUUIDs.joined(separator: ", ")
                        let id = deviceGroup.name.encodeUrl()!
                        deviceGroupData["buttons"] = "<div class=\"btn-group\" role=\"group\"><a " +
                            "href=\"/dashboard/devicegroup/assign/\(id)\" " +
                            "role=\"button\" class=\"btn btn-success\">Assign</a>" +
                            "<a href=\"/dashboard/devicegroup/edit/\(id)\" " +
                            "role=\"button\" class=\"btn btn-primary\">Edit</a>" +
                            "<a href=\"/dashboard/devicegroup/delete/\(id)\" " +
                            "role=\"button\" class=\"btn btn-danger\">Delete</a></div>"
                    } else {
                        deviceGroupData["instances"] = instances
                        deviceGroupData["devices"] = deviceGroup.deviceUUIDs
                    }

                    jsonArray.append(deviceGroupData)
                }
            }

            data["devicegroups"] = jsonArray
        }

        if showAssignments && perms.contains(.admin) {

            let assignments = try? Assignment.getAll(mysql: mysql)

            var jsonArray = [[String: Any]]()

            if assignments != nil {
                for assignment in assignments! {
                    var assignmentData = [String: Any]()

                    assignmentData["source_instance_name"] = assignment.sourceInstanceName ?? ""
                    assignmentData["instance_name"] = assignment.instanceName
                    assignmentData["device_uuid"] = assignment.deviceUUID ?? ""
                    assignmentData["device_group_name"] = assignment.deviceGroupName ?? ""

                    if formatted {
                        let formattedTime: String
                        if assignment.time == 0 {
                            formattedTime = "On Complete"
                        } else {
                            let times = assignment.time.secondsToHoursMinutesSeconds()
                            formattedTime = "\(String(format: "%02d", times.hours)):" +
                                            "\(String(format: "%02d", times.minutes)):" +
                                            "\(String(format: "%02d", times.seconds))"
                        }
                        assignmentData["time"] = ["timestamp": assignment.time as Any, "formatted": formattedTime]

                        let formattedDate: String
                        if assignment.date == nil {
                            formattedDate = ""
                        } else {
                            formattedDate = assignment.date!.toString() ?? "?"
                        }
                        assignmentData["date"] = [
                            "timestamp": assignment.date?.timeIntervalSince1970 ?? 0,
                            "formatted": formattedDate
                        ]

                        assignmentData["buttons"] = "<div class=\"btn-group\" role=\"group\"><a " +
                            "href=\"/dashboard/assignment/start/\(assignment.id!)\" " +
                            "role=\"button\" class=\"btn btn-success\">Start</a>" +
                            "<a href=\"/dashboard/assignment/edit/\(assignment.id!)\" " +
                            "role=\"button\" class=\"btn btn-primary\">Edit</a>" +
                            "<a href=\"/dashboard/assignment/delete/\(assignment.id!)\" " +
                            "role=\"button\" class=\"btn btn-danger\">Delete</a></div>"
                    } else {
                        assignmentData["time"] = assignment.time as Any
                    }
                    assignmentData["enabled"] = assignment.enabled ? "Yes" : "No"

                    jsonArray.append(assignmentData)
                }
            }
            data["assignments"] = jsonArray

        }

        if showAssignmentGroups && perms.contains(.admin) {

            let assignmentGroups = try? AssignmentGroup.getAll(mysql: mysql)
            let assignments = try? Assignment.getAll(mysql: mysql)

            var jsonArray = [[String: Any]]()

            if assignmentGroups != nil {
                for assignmentGroup in assignmentGroups! {
                    let assignmentsInGroup =
                        assignments?.filter({ assignmentGroup.assignmentIDs.contains($0.id!) }) ?? []
                    let assignmentsInGroupDevices = Array(
                        Set(assignmentsInGroup.filter({ $0.deviceUUID != nil || $0.deviceGroupName != nil })
                            .map({ ($0.deviceUUID != nil ? $0.deviceUUID! : "") +
                            ($0.deviceGroupName != nil ? $0.deviceGroupName! : "") + " -> " + $0.instanceName}))
                        ).sorted()

                    var assignmentGroupData = [String: Any]()
                    assignmentGroupData["name"] = assignmentGroup.name

                    if formatted {
                        assignmentGroupData["assignments"] = assignmentsInGroupDevices.joined(separator: ", ")
                        let id = assignmentGroup.name.encodeUrl()!
                        assignmentGroupData["buttons"] = "<div class=\"btn-group\" role=\"group\"><a " +
                            "href=\"/dashboard/assignmentgroup/start/\(id)\" " +
                            "role=\"button\" class=\"btn btn-success\">Start</a>" +
                            "<a href=\"/dashboard/assignmentgroup/request/\(id)\" " +
                            "role=\"button\" class=\"btn btn-warning\" onclick=\"return " +
                            "confirm('Are you sure that you want to clear all quests " +
                            "for this assignment group?')\">ReQuest</a>" +
                            "<a href=\"/dashboard/assignmentgroup/edit/\(id)\" " +
                            "role=\"button\" class=\"btn btn-primary\">Edit</a>" +
                            "<a href=\"/dashboard/assignmentgroup/delete/\(id)\" " +
                            "role=\"button\" class=\"btn btn-danger\" onclick=\"return " +
                            "confirm('Are you sure you want to delete this assignment " +
                            "group? This action is irreversible and cannot be " +
                            "undone without backups.')\">Delete</a></div>"
                    } else {
                        assignmentGroupData["assignments"] = assignments
                    }

                    jsonArray.append(assignmentGroupData)
                }
            }

            data["assignmentgroups"] = jsonArray
        }

        if showIVQueue && perms.contains(.admin), let instance = instance {

            let queue = InstanceController.global.getIVQueue(name: instance.decodeUrl() ?? "")

            var jsonArray = [[String: Any]]()
            var i = 1
            for pokemon in queue {

                var json: [String: Any] = [
                    "id": i,
                    "pokemon_id": String(format: "%03d", pokemon.pokemonId),
                    "pokemon_name": Localizer.global.get(value: "poke_\(pokemon.pokemonId)")
                ]
                if formatted {
                    json["pokemon_image"] =
                        "<img src=\"/static/img/pokemon/\(pokemon.pokemonId).png\" style=\"height:50px; width:50px;\">"
                    json["pokemon_spawn_id"] =
                        "<a target=\"_blank\" href=\"/@pokemon/\(pokemon.id)\">\(pokemon.id)</a>"
                    json["location"] =
                        "<a target=\"_blank\" href=\"https://www.google.com/maps/place/" +
                        "\(pokemon.lat),\(pokemon.lon)\">\(pokemon.lat),\(pokemon.lon)</a>"
                } else {
                    json["pokemon_spawn_id"] = pokemon.id
                    json["location"] = "\(pokemon.lat), \(pokemon.lon)"
                }
                jsonArray.append(json)
                i += 1
            }
            data["ivqueue"] = jsonArray

        }

        if showUsers && perms.contains(.admin) {
            let users = try? User.getAll(mysql: mysql)
            var jsonArray = [[String: Any]]()

            if users != nil {
                for user in users! {
                    var userData = [String: Any]()
                    userData["username"] = user.username
                    userData["group"] = user.groupName

                    if formatted {
                        if user.emailVerified {
                            userData["email"] = "\(user.email) (Verified)"
                        } else {
                            userData["email"] = user.email
                        }
                        userData["buttons"] = "<a href=\"/dashboard/user/edit/\(user.username.encodeUrl()!)\" " +
                                              "role=\"button\" class=\"btn btn-primary\">Edit User</a>"
                    } else {
                        userData["email"] = user.email
                        userData["email_verified"] = user.emailVerified
                    }
                    jsonArray.append(userData)
                }
            }
            data["users"] = jsonArray
        }

        if showGroups && perms.contains(.admin) {
            let groups = try? Group.getAll(mysql: mysql)
            var jsonArray = [[String: Any]]()

            if groups != nil {
                for group in groups! {
                    var groupData = [String: Any]()
                    groupData["name"] = group.name

                    if formatted {
                        if group.name != "root" {
                            groupData["buttons"] = "<a href=\"/dashboard/group/edit/\(group.name.encodeUrl()!)\" " +
                                                   "role=\"button\" class=\"btn btn-primary\">Edit Group</a>"
                        } else {
                            groupData["buttons"] = ""
                        }
                        var permsString = ""
                        for perm in group.perms {
                            var permName: String
                            switch perm {
                            case .viewMap:
                                permName = "Map"
                            case .viewMapRaid:
                                permName = "Raid"
                            case .viewMapPokemon:
                                permName = "Pokemon"
                            case .viewStats:
                                permName = "Stats"
                            case .admin:
                                permName = "Admin"
                            case .viewMapGym:
                                permName = "Gym"
                            case .viewMapPokestop:
                                permName = "Pokestop"
                            case .viewMapSpawnpoint:
                                permName = "Spawnpoint"
                            case .viewMapQuest:
                                permName = "Quest"
                            case .viewMapIV:
                                permName = "IV"
                            case .viewMapCell:
                                permName = "Scann-Cell"
                            case .viewMapWeather:
                                permName = "Weather"
                            case .viewMapLure:
                                permName = "Lure"
                            case .viewMapInvasion:
                                permName = "Invasion"
                            case .viewMapDevice:
                                permName = "Device"
                            case .viewMapSubmissionCells:
                                permName = "Submission-Cell"
                            case .viewMapEventPokemon:
                                permName = "Event Pokemon"
                            }

                            if permsString == "" {
                                permsString += permName
                            } else {
                                permsString += ","+permName
                            }
                        }
                        groupData["perms"] = permsString

                    } else {
                        groupData["perms"] = Group.Perm.permsToNumber(perms: group.perms)
                    }
                    jsonArray.append(groupData)
                }
            }
            data["groups"] = jsonArray
        }

        if showDiscordRules && perms.contains(.admin) {

            var jsonArray = [[String: Any]]()
            let discordRules = DiscordController.global.getDiscordRules()

            for discordRule in discordRules {
                var discordRuleData = [String: Any]()
                discordRuleData["priority"] = discordRule.priority
                discordRuleData["group_name"] = discordRule.groupName
                if formatted {
                    let serverId = discordRule.serverId
                    let roleId = discordRule.roleId
                    let guilds = DiscordController.global.getAllGuilds()

                    discordRuleData["server"] = [
                        "id": serverId,
                        "name": guilds[serverId]?.name ?? serverId.description
                    ]
                    if roleId != nil {
                        let guild = guilds[serverId]
                        let name = guild?.roles[roleId!] ?? roleId!.description

                        discordRuleData["role"] = [
                            "id": roleId as Any,
                            "name": name
                        ]
                    } else {
                        discordRuleData["role"] = [
                            "id": nil,
                            "name": "Any"
                        ]
                    }
                    discordRuleData["buttons"] = "<a href=\"/dashboard/discordrule/edit/\(discordRule.priority)\" " +
                                                 "role=\"button\" class=\"btn btn-primary\">Edit Discord Rule</a>"
                } else {
                    discordRuleData["server_id"] = discordRule.serverId
                    discordRuleData["role_id"] = discordRule.roleId
                }
                jsonArray.append(discordRuleData)
            }
            data["discordrules"] = jsonArray
        }

        if showStatus && perms.contains(.admin) {
            do {
                let passed = UInt32(Date().timeIntervalSince(start)).secondsToDaysHoursMinutesSeconds()
                let devices: [Device] = try Device.getAll(mysql: mysql)
                let offlineDevices = devices.filter {
                    Date().timeIntervalSince(Date(timeIntervalSince1970: Double($0.lastSeen))) >= 15 * 60
                }
                let onlineDevices = devices.filter {
                    Date().timeIntervalSince(Date(timeIntervalSince1970: Double($0.lastSeen))) < 15 * 60
                }
                let activePokemonCounts = try Pokemon.getActiveCounts(mysql: mysql)

                let limits = WebHookRequestHandler.getThreadLimits()
                data["status"] = [
                    "processing": [
                        "current": limits.current,
                        "total": limits.total,
                        "ignored": limits.ignored,
                        "max": WebHookRequestHandler.threadLimitMax
                    ],
                    "uptime": [
                        "date": start.timeIntervalSince1970,
                        "days": passed.days,
                        "hours": passed.hours,
                        "minutes": passed.minutes,
                        "seconds": passed.seconds
                    ],
                    "devices": [
                        "total": devices.count,
                        "offline": offlineDevices.count,
                        "online": onlineDevices.count
                    ],
                    "pokemon": [
                        "active_total": activePokemonCounts.total,
                        "active_iv": activePokemonCounts.iv
                    ]
                ]
            } catch {
                response.respondWithError(status: .internalServerError)
                return
            }
        }

        data["timestamp"] = Int(Date().timeIntervalSince1970)

        do {
            try response.respondWithData(data: data)
        } catch {
            response.respondWithError(status: .internalServerError)
            return
        }
    }

    private static func handleSetData(request: HTTPRequest, response: HTTPResponse) {

        guard let perms = getPerms(request: request, response: response) else {
            return
        }

        let setGymName = request.param(name: "set_gym_name")?.toBool() ?? false
        let gymId = request.param(name: "gym_id")
        let gymName = request.param(name: "gym_name")
        let setPokestopName = request.param(name: "set_pokestop_name")?.toBool() ?? false
        let pokestopId = request.param(name: "pokestop_id")
        let pokestopName = request.param(name: "pokestop_name")

        if setGymName, perms.contains(.admin), let id = gymId, let name = gymName {
            do {
                guard let oldGym = try Gym.getWithId(id: id) else {
                    return response.respondWithError(status: .custom(code: 404, message: "Gym not found"))
                }
                oldGym.name = name
                oldGym.hasChanges = true
                try oldGym.save()
                response.respondWithOk()
            } catch {
                response.respondWithError(status: .internalServerError)
            }
        } else  if setPokestopName, perms.contains(.admin), let id = pokestopId, let name = pokestopName {
           do {
               guard let oldPokestop = try Pokestop.getWithId(id: id) else {
                   return response.respondWithError(status: .custom(code: 404, message: "Pokestop not found"))
               }
               oldPokestop.name = name
               oldPokestop.hasChanges = true
               try oldPokestop.save()
               response.respondWithOk()
           } catch {
               response.respondWithError(status: .internalServerError)
           }
        } else {
            response.respondWithError(status: .badRequest)
        }
    }

}
