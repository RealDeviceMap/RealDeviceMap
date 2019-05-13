//
//  ApiRequestHandler.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//

import Foundation
import PerfectLib
import PerfectHTTP
import PerfectMustache
import PerfectSessionMySQL
import POGOProtos
import S2Geometry

class ApiRequestHandler {
    
    private static var sessionDriver = MySQLSessions()
    
    public static func handle(request: HTTPRequest, response: HTTPResponse, route: WebServer.APIPage) {
        
        switch route {
        case .getData:
            handleGetData(request: request, response: response)
        }
    }
    
    private static func handleGetData(request: HTTPRequest, response: HTTPResponse) {
        
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
        let pokemonFilterExclude = request.param(name: "pokemon_filter_exclude")?.jsonDecodeForceTry() as? [Int]
        let pokemonFilterIV = request.param(name: "pokemon_filter_iv")?.jsonDecodeForceTry() as? [String: String]
        let raidFilterExclude = request.param(name: "raid_filter_exclude")?.jsonDecodeForceTry() as? [String]
        let gymFilterExclude = request.param(name: "gym_filter_exclude")?.jsonDecodeForceTry() as? [String]
        let pokestopFilterExclude = request.param(name: "pokestop_filter_exclude")?.jsonDecodeForceTry() as? [String]
        let showSpawnpoints =  request.param(name: "show_spawnpoints")?.toBool() ?? false
        let showCells = request.param(name: "show_cells")?.toBool() ?? false
        let showDevices =  request.param(name: "show_devices")?.toBool() ?? false
        let showInstances =  request.param(name: "show_instances")?.toBool() ?? false
        let showUsers =  request.param(name: "show_users")?.toBool() ?? false
        let showGroups =  request.param(name: "show_groups")?.toBool() ?? false
        let showPokemonFilter = request.param(name: "show_pokemon_filter")?.toBool() ?? false
        let showQuestFilter = request.param(name: "show_quest_filter")?.toBool() ?? false
        let showRaidFilter = request.param(name: "show_raid_filter")?.toBool() ?? false
        let showGymFilter = request.param(name: "show_gym_filter")?.toBool() ?? false
        let showPokestopFilter = request.param(name: "show_pokestop_filter")?.toBool() ?? false
        let formatted =  request.param(name: "formatted")?.toBool() ?? false
        let lastUpdate = request.param(name: "last_update")?.toUInt32() ?? 0
        let showAssignments = request.param(name: "show_assignments")?.toBool() ?? false
        let showIVQueue = request.param(name: "show_ivqueue")?.toBool() ?? false
        let showDiscordRules = request.param(name: "show_discordrules")?.toBool() ?? false
        
        if (showGyms || showRaids || showPokestops || showPokemon || showSpawnpoints || showCells) &&
            (minLat == nil || maxLat == nil || minLon == nil || maxLon == nil) {
            response.respondWithError(status: .badRequest)
            return
        }
        
        let tmp = WebReqeustHandler.getPerms(request: request, fromCache: true)
        let perms = tmp.perms
        let username = tmp.username
        
        if username == nil || username == "", let authorization = request.header(.authorization) {
            let base64String = authorization.replacingOccurrences(of: "Basic ", with: "")
            if let data = Data(base64Encoded: base64String),  let string = String(data: data, encoding: .utf8) {
                let split = string.components(separatedBy: ":")
                if split.count == 2 {
                    if let usernameEmail = split[0].stringByDecodingURL, let password = split[1].stringByDecodingURL {
                        let user: User
                        do {
                            let host: String
                            let ff = request.header(.xForwardedFor) ?? ""
                            if ff.isEmpty {
                                host = request.remoteAddress.host
                            } else {
                                host = ff
                            }
                            if usernameEmail.contains("@") {
                                user = try User.login(email: usernameEmail, password: password, host: host)
                            } else {
                                user = try User.login(username: usernameEmail, password: password, host: host)
                            }
                        } catch {
                            if error is DBController.DBError {
                                response.respondWithError(status: .internalServerError)
                                return
                            } else {
                                let registerError = error as! User.LoginError
                                switch registerError.type {
                                case .limited:
                                    fallthrough
                                case .usernamePasswordInvalid:
                                    response.respondWithError(status: .unauthorized)
                                    return
                                case .undefined:
                                    response.respondWithError(status: .internalServerError)
                                    return
                                }
                            }
                        }
                        
                        request.session?.userid = user.username
                        if user.group != nil {
                            request.session?.data["perms"] = Group.Perm.permsToNumber(perms: user.group!.perms)
                        }
                        sessionDriver.save(session: request.session!)
                        handleGetData(request: request, response: response)
                        return
                    }
                }
            
            }
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
            data["gyms"] = try? Gym.getAll(mysql: mysql, minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!, updated: lastUpdate, raidsOnly: !showGyms, showRaids: permShowRaid, raidFilterExclude: raidFilterExclude, gymFilterExclude: gymFilterExclude)
        }
        let permShowStops = perms.contains(.viewMapPokestop)
        let permShowQuests =  perms.contains(.viewMapQuest)
        if isPost && (permViewMap && (showPokestops && permShowStops || showQuests && permShowQuests)) {
            data["pokestops"] = try? Pokestop.getAll(mysql: mysql, minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!, updated: lastUpdate, questsOnly: !showPokestops, showQuests: permShowQuests, questFilterExclude: questFilterExclude, pokestopFilterExclude: pokestopFilterExclude)
        }
        let permShowIV = perms.contains(.viewMapIV)
        if isPost && permViewMap && showPokemon && perms.contains(.viewMapPokemon){
            data["pokemon"] = try? Pokemon.getAll(mysql: mysql, minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!, showIV: permShowIV, updated: lastUpdate, pokemonFilterExclude: pokemonFilterExclude, pokemonFilterIV: pokemonFilterIV)
        }
        if isPost && permViewMap && showSpawnpoints && perms.contains(.viewMapSpawnpoint){
            data["spawnpoints"] = try? SpawnPoint.getAll(mysql: mysql, minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!, updated: lastUpdate)
        }
        if isPost && showCells && perms.contains(.viewMapCell) {
            data["cells"] = try? Cell.getAll(mysql: mysql, minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!, updated: lastUpdate)
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
            let generalTypeString = Localizer.global.get(value: "filter_general")

            let globalIV = Localizer.global.get(value: "filter_global_iv")
            let configureString = Localizer.global.get(value: "filter_configure")
            let andString = Localizer.global.get(value: "filter_and")
            let orString = Localizer.global.get(value: "filter_or")

            var pokemonData = [[String: Any]]()
            
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
                            <label class="btn btn-sm btn-off select-button-new" data-id="\(id)" data-type="pokemon-iv" data-info="off">
                                <input type="radio" name="options" id="hide" autocomplete="off">\(offString)
                            </label>
                            <label class="btn btn-sm btn-on select-button-new" data-id="\(id)" data-type="pokemon-iv" data-info="on">
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
                    
                    let size = "<button class=\"btn btn-sm btn-primary configure-button-new\" data-id=\"\(id)\" data-type=\"pokemon-iv\" data-info=\"global-iv\">\(configureString)</button>"
                    
                    pokemonData.append([
                        "id": [
                            "formatted": andOrString,
                            "sort": i
                        ],
                        "name": globalIV,
                        "image": "-",
                        "filter": filter,
                        "size": size,
                        "type": generalTypeString
                    ])
                    
                }
            }
            
            for i in 1...WebReqeustHandler.maxPokemonId {
                
                let ivLabel: String
                if permShowIV {
                    ivLabel = """
                        <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="pokemon" data-info="iv">
                        <input type="radio" name="options" id="iv" autocomplete="off">\(ivString)
                        </label>
                    """
                } else {
                    ivLabel = ""
                }
                let filter = """
                    <div class="btn-group btn-group-toggle" data-toggle="buttons">
                        <label class="btn btn-sm btn-off select-button-new" data-id="\(i)" data-type="pokemon" data-info="hide">
                            <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
                        </label>
                        <label class="btn btn-sm btn-on select-button-new" data-id="\(i)" data-type="pokemon" data-info="show">
                            <input type="radio" name="options" id="show" autocomplete="off">\(showString)
                        </label>
                        \(ivLabel)
                    </div>
                """
                
                
                let size = """
                    <div class="btn-group btn-group-toggle" data-toggle="buttons">
                        <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="pokemon" data-info="small">
                            <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
                        </label>
                        <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="pokemon" data-info="normal">
                            <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
                        </label>
                        <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="pokemon" data-info="large">
                            <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
                        </label>
                        <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="pokemon" data-info="huge">
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
                    "image": "<img class=\"lazy_load\" data-src=\"/static/img/pokemon/\(i).png\" style=\"height:50px; width:50px;\">",
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
            for i in 1...3 {
                
                let itemName: String
                switch i {
                case 1:
                    itemName = Localizer.global.get(value: "filter_stardust")
                case 2:
                    itemName = Localizer.global.get(value: "filter_xp")
                default:
                    itemName = Localizer.global.get(value: "filter_candy")
                }
                
                let filter = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-off select-button-new" data-id="\(i)" data-type="quest-misc" data-info="hide">
                <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
                </label>
                <label class="btn btn-sm btn-on select-button-new" data-id="\(i)" data-type="quest-misc" data-info="show">
                <input type="radio" name="options" id="show" autocomplete="off">\(showString)
                </label>
                </div>
                """
                
                let size = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="quest-misc" data-info="small">
                <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="quest-misc" data-info="normal">
                <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="quest-misc" data-info="large">
                <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="quest-misc" data-info="huge">
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
                    "image": "<img class=\"lazy_load\" data-src=\"/static/img/item/\(-i).png\" style=\"height:50px; width:50px;\">",
                    "filter": filter,
                    "size": size,
                    "type": miscTypeString
                ])
            }
            
            // Items
            var itemI = 1
            for item in POGOProtos_Inventory_Item_ItemId.allAvilable {
                
                let filter = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-off select-button-new" data-id="\(item.rawValue)" data-type="quest-item" data-info="hide">
                <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
                </label>
                <label class="btn btn-sm btn-on select-button-new" data-id="\(item.rawValue)" data-type="quest-item" data-info="show">
                <input type="radio" name="options" id="show" autocomplete="off">\(showString)
                </label>
                </div>
                """
                
                let size = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-size select-button-new" data-id="\(item.rawValue)" data-type="quest-item" data-info="small">
                <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(item.rawValue)" data-type="quest-item" data-info="normal">
                <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(item.rawValue)" data-type="quest-item" data-info="large">
                <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(item.rawValue)" data-type="quest-item" data-info="huge">
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
                    "image": "<img class=\"lazy_load\" data-src=\"/static/img/item/\(item.rawValue).png\" style=\"height:50px; width:50px;\">",
                    "filter": filter,
                    "size": size,
                    "type": itemsTypeString
                ])
                itemI += 1
            }
            
            // Pokemon
            for i in 1...WebReqeustHandler.maxPokemonId {
                
                let filter = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-off select-button-new" data-id="\(i)" data-type="quest-pokemon" data-info="hide">
                <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
                </label>
                <label class="btn btn-sm btn-on select-button-new" data-id="\(i)" data-type="quest-pokemon" data-info="show">
                <input type="radio" name="options" id="show" autocomplete="off">\(showString)
                </label>
                </div>
                """
                
                let size = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="quest-pokemon" data-info="small">
                <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="quest-pokemon" data-info="normal">
                <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="quest-pokemon" data-info="large">
                <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="quest-pokemon" data-info="huge">
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
                    "image": "<img class=\"lazy_load\" data-src=\"/static/img/pokemon/\(i).png\" style=\"height:50px; width:50px;\">",
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
            
            let raidOptionsString = Localizer.global.get(value: "filter_raid_options")
            //let pokemonTypeString = Localizer.global.get(value: "filter_pokemon")
            
            var raidData = [[String: Any]]()
            //Level
            for i in 1...5 {
                
                let raidLevel: String
                raidLevel = Localizer.global.get(value: "filter_raid_level_\(i)")
                
                let filter = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-off select-button-new" data-id="\(i)" data-type="raid-level" data-info="hide">
                <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
                </label>
                <label class="btn btn-sm btn-on select-button-new" data-id="\(i)" data-type="raid-level" data-info="show">
                <input type="radio" name="options" id="show" autocomplete="off">\(showString)
                </label>
                </div>
                """
                
                let size = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="raid-level" data-info="small">
                <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="raid-level" data-info="normal">
                <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="raid-level" data-info="large">
                <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="raid-level" data-info="huge">
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
                    "image": "<img class=\"lazy_load\" data-src=\"/static/img/egg/\(i).png\" style=\"height:50px; width:50px;\">",
                    "filter": filter,
                    "size": size,
                    "type": raidOptionsString
                ])
            }
            
            let filter = """
            <div class="btn-group btn-group-toggle" data-toggle="buttons">
            <label class="btn btn-sm btn-off select-button-new" data-id="hatched" data-type="raid-hatched" data-info="hide">
            <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
            </label>
            <label class="btn btn-sm btn-on select-button-new" data-id="hatched" data-type="raid-hatched" data-info="show">
            <input type="radio" name="options" id="show" autocomplete="off">\(showString)
            </label>
            </div>
            """
            
            let size = """
            <div class="btn-group btn-group-toggle" data-toggle="buttons">
            <label class="btn btn-sm btn-size select-button-new" data-id="hatched" data-type="raid-hatched" data-info="small">
            <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="hatched" data-type="raid-hatched" data-info="normal">
            <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="hatched" data-type="raid-hatched" data-info="large">
            <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="hatched" data-type="raid-hatched" data-info="huge">
            <input type="radio" name="options" id="show" autocomplete="off">\(hugeString)
            </label>
            </div>
            """
            
            let id = 6;
            raidData.append([
                "id": [
                    "formatted": String(format: "%03d", id),
                    "sort": id+200
                ],
                "name": /*Localizer.global.get(value: "poke_\(i)")*/ "Raid Boss" , //TODO: Localize
                "image": "<img class=\"lazy_load\" data-src=\"/static/img/pokemon/150.png\" style=\"height:50px; width:50px;\">", //TODO: Set actual icon
                "filter": filter,
                "size": size,
                "type": raidOptionsString
            ])
            
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
            //Team
            for i in 0...3 {
                
                let gymTeam: String
                gymTeam = Localizer.global.get(value: "filter_gym_team_\(i)")
                
                let filter = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-off select-button-new" data-id="\(i)" data-type="gym-team" data-info="hide">
                <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
                </label>
                <label class="btn btn-sm btn-on select-button-new" data-id="\(i)" data-type="gym-team" data-info="show">
                <input type="radio" name="options" id="show" autocomplete="off">\(showString)
                </label>
                </div>
                """
                
                let size = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="gym-team" data-info="small">
                <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="gym-team" data-info="normal">
                <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="gym-team" data-info="large">
                <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="gym-team" data-info="huge">
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
                    "image": "<img class=\"lazy_load\" data-src=\"/static/img/gym/\(i)_\(i).png\" style=\"height:50px; width:50px;\">",
                    "filter": filter,
                    "size": size,
                    "type": gymTeamString
                ])
            }
            
            // Ex Raids
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
                    "formatted": String(format: "%03d", 5), //Need a better way to display, new section?
                    "sort": 5
                ],
                "name": Localizer.global.get(value: "filter_raid_ex") ,
                "image": "<img class=\"lazy_load\" data-src=\"/static/img/item/1403.png\" style=\"height:50px; width:50px;\">",
                "filter": exFilter,
                "size": exSize,
                "type": gymOptionsString
            ])
            
            //Available slots
            for i in 0...6 {
                let availableSlots: String
                availableSlots = Localizer.global.get(value: "filter_gym_available_slots_\(i)")
                
                let filter = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-off select-button-new" data-id="\(i)" data-type="gym-slots" data-info="hide">
                <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
                </label>
                <label class="btn btn-sm btn-on select-button-new" data-id="\(i)" data-type="gym-slots" data-info="show">
                <input type="radio" name="options" id="show" autocomplete="off">\(showString)
                </label>
                </div>
                """
                
                let size = """
                <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="gym-slots" data-info="small" disabled>
                <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="gym-slots" data-info="normal" disabled>
                <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="gym-slots" data-info="large" disabled>
                <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
                </label>
                <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="gym-slots" data-info="huge" disabled>
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
                    "image": "<img class=\"lazy_load\" data-src=\"/static/img/gym/\(i == 6 ? 0 : team)_\(6 - i).png\" style=\"height:50px; width:50px;\">",
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
            
            let pokestopLured: String
            pokestopLured = Localizer.global.get(value: "filter_pokestop_lured")
                
            let filter = """
            <div class="btn-group btn-group-toggle" data-toggle="buttons">
            <label class="btn btn-sm btn-off select-button-new" data-id="lured" data-type="pokestop-lured" data-info="hide">
            <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
            </label>
            <label class="btn btn-sm btn-on select-button-new" data-id="lured" data-type="pokestop-lured" data-info="show">
            <input type="radio" name="options" id="show" autocomplete="off">\(showString)
            </label>
            </div>
            """
                
            let size = """
            <div class="btn-group btn-group-toggle" data-toggle="buttons">
            <label class="btn btn-sm btn-size select-button-new" data-id="lured" data-type="pokestop-lured" data-info="small">
            <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="lured" data-type="pokestop-lured" data-info="normal">
            <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="lured" data-type="pokestop-lured" data-info="large">
            <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
            </label>
            <label class="btn btn-sm btn-size select-button-new" data-id="lured" data-type="pokestop-lured" data-info="huge">
            <input type="radio" name="options" id="show" autocomplete="off">\(hugeString)
            </label>
            </div>
            """
                
            pokestopData.append([
                "id": [
                    "formatted": String(format: "%03d", 0),
                    "sort": 0
                ],
                "name": pokestopLured,
                "image": "<img class=\"lazy_load\" data-src=\"/static/img/pokestop/1.png\" style=\"height:50px; width:50px;\">",
                "filter": filter,
                "size": size,
                "type": pokestopOptionsString
                ])
        
            data["pokestop_filters"] = pokestopData
        }
        
        if showDevices && perms.contains(.admin) {
            
            let devices = try? Device.getAll(mysql: mysql)
            var jsonArray = [[String: Any]]()
            
            if devices != nil {
                for device in devices! {
                    var deviceData = [String: Any]()
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
                        deviceData["buttons"] = "<a href=\"/dashboard/device/assign/\(device.uuid.encodeUrl()!)\" role=\"button\" class=\"btn btn-primary\">Assign Instance</a>"
                    } else {
                        deviceData["last_seen"] = device.lastSeen as Any
                    }
                    jsonArray.append(deviceData)
                }
            }
            data["devices"] = jsonArray
            
        }
        
        if showInstances && perms.contains(.admin) {
            
            let instances = try? Instance.getAll(mysql: mysql)
            
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
                    case .autoQuest:
                        instanceData["type"] = "Auto Quest"
                    case .pokemonIV:
                        instanceData["type"] = "Pokemon IV"
                    }
                    
                    if formatted {
                        let status = InstanceController.global.getInstanceStatus(instance: instance, formatted: true)
                        if status is String {
                            instanceData["status"] = status as! String
                        } else {
                            instanceData["status"] = "?"
                        }
                    } else {
                        instanceData["status"] = InstanceController.global.getInstanceStatus(instance: instance, formatted: false) as Any
                    }
                    
                    if formatted {
                        instanceData["buttons"] = "<a href=\"/dashboard/instance/edit/\(instance.name.encodeUrl()!)\" role=\"button\" class=\"btn btn-primary\">Edit Instance</a>"
                    }
                    jsonArray.append(instanceData)
                }
            }
            data["instances"] = jsonArray
            
        }
        
        if showAssignments && perms.contains(.admin) {
            
            let assignments = try? Assignment.getAll(mysql: mysql)
            
            var jsonArray = [[String: Any]]()
            
            if assignments != nil {
                for assignment in assignments! {
                    var assignmentData = [String: Any]()
                    
                    assignmentData["instance_name"] = assignment.instanceName
                    assignmentData["device_uuid"] = assignment.deviceUUID

                    if formatted {
                        let formattedTime: String
                        if assignment.time == 0 {
                            formattedTime = "On Complete"
                        } else {
                            let times = assignment.time.secondsToHoursMinutesSeconds()
                            formattedTime = "\(String(format: "%02d", times.hours)):\(String(format: "%02d", times.minutes)):\(String(format: "%02d", times.seconds))"
                        }
                        assignmentData["time"] = ["timestamp": assignment.time as Any, "formatted": formattedTime]
                       
                        let instanceUUID = "\(assignment.instanceName.escaped())\\-\(assignment.deviceUUID.escaped())\\-\(assignment.time)"
                        assignmentData["buttons"] = "<a href=\"/dashboard/assignment/delete/\(instanceUUID.encodeUrl()!)\" role=\"button\" class=\"btn btn-danger\">Delete</a>"                    } else {
                        assignmentData["time"] = assignment.time as Any
                    }
                    
                    jsonArray.append(assignmentData)
                }
            }
            data["assignments"] = jsonArray
            
        }
        
        if showIVQueue && perms.contains(.admin), let instance = instance {
           
            let queue = InstanceController.global.getIVQueue(name: instance.decodeUrl() ?? "")
            
            var jsonArray = [[String: Any]]()
            var i = 1
            for pokemon in queue {
                
                
                var json: [String: Any] = [
                    "id": i,
                    "pokemon_id": String(format: "%03d", pokemon.pokemonId),
                    "pokemon_name": Localizer.global.get(value: "poke_\(pokemon.pokemonId)") ,
                    "pokemon_spawn_id": pokemon.id,
                    "location": "\(pokemon.lat), \(pokemon.lon)"
                ]
                if formatted {
                    json["pokemon_image"] = "<img src=\"/static/img/pokemon/\(pokemon.pokemonId).png\" style=\"height:50px; width:50px;\">"
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
                        userData["buttons"] = "<a href=\"/dashboard/user/edit/\(user.username.encodeUrl()!)\" role=\"button\" class=\"btn btn-primary\">Edit User</a>"
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
                            groupData["buttons"] = "<a href=\"/dashboard/group/edit/\(group.name.encodeUrl()!)\" role=\"button\" class=\"btn btn-primary\">Edit Group</a>"
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
                                permName = "Cell"
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
                    discordRuleData["buttons"] = "<a href=\"/dashboard/discordrule/edit/\(discordRule.priority)\" role=\"button\" class=\"btn btn-primary\">Edit Discord Rule</a>"
                } else {
                    discordRuleData["server_id"] = discordRule.serverId
                    discordRuleData["role_id"] = discordRule.roleId
                }
                jsonArray.append(discordRuleData)
            }
            data["discordrules"] = jsonArray
        }
        
        data["timestamp"] = Int(Date().timeIntervalSince1970)

        do {
            try response.respondWithData(data: data)
        } catch {
            response.respondWithError(status: .internalServerError)
            return
        }
    }
    
}
