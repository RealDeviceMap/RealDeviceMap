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
        let showGyms = request.param(name: "show_gyms")?.toBool() ?? false
        let showRaids = request.param(name: "show_raids")?.toBool() ?? false
        let showPokestops = request.param(name: "show_pokestops")?.toBool() ?? false
        let showPokemon = request.param(name: "show_pokemon")?.toBool() ?? false
        let pokemonFilterExclude = (try? (request.param(name: "pokemon_filter_exclude") ?? "")?.jsonDecode() as? [Int]) ?? nil
        let showSpawnpoints =  request.param(name: "show_spawnpoints")?.toBool() ?? false
        let showDevices =  request.param(name: "show_devices")?.toBool() ?? false
        let showInstances =  request.param(name: "show_instances")?.toBool() ?? false
        let showPokemonFilter = request.param(name: "show_pokemon_filter")?.toBool() ?? false
        let formatted =  request.param(name: "formatted")?.toBool() ?? false
        let lastUpdate = request.param(name: "last_update")?.toUInt32() ?? 0
        
        if (showGyms || showRaids || showPokestops || showPokemon) &&
            (minLat == nil || maxLat == nil || minLon == nil || maxLon == nil) {
            response.respondWithError(status: .badRequest)
            return
        }
        
        var perms = [Group.Perm]()
        let sessionPerms = (request.session?.data["perms"] as? Int)?.toUInt32()
        if sessionPerms == nil {
            response.respondWithError(status: .unauthorized)
            return
        } else {
            perms = Group.Perm.numberToPerms(number: sessionPerms!)
        }
        
        let permViewMap = perms.contains(.viewMap)
        
        var data = [String: Any]()
        let permShowRaid = perms.contains(.viewMapRaid)
        let permShowGym =  perms.contains(.viewMapGym)
        if (permViewMap && (showGyms && permShowGym || showRaids && permShowGym)) {
            data["gyms"] = try? Gym.getAll(minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!, updated: lastUpdate, raidsOnly: !showGyms, showRaids: permShowRaid)
        }
        if permViewMap && showPokestops && perms.contains(.viewMapPokestop){
            data["pokestops"] = try? Pokestop.getAll(minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!, updated: lastUpdate)
        }
        if permViewMap && showPokemon && perms.contains(.viewMapPokemon){
            data["pokemon"] = try? Pokemon.getAll(minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!, updated: lastUpdate, pokemonFilterExclude: pokemonFilterExclude)
        }
        if permViewMap && showSpawnpoints && perms.contains(.viewMapSpawnpoint){
            data["spawnpoints"] = try? SpawnPoint.getAll(minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!, updated: lastUpdate)
        }
        if permViewMap && showPokemonFilter {
            var pokemonData = [[String: Any]]()
            for i in 1...WebReqeustHandler.maxPokemonId {
                
                let filter = """
                    <div class="btn-group btn-group-toggle" data-toggle="buttons">
                        <label class="btn btn-sm btn-off select-button-new" data-id="\(i)" data-type="pokemon" data-info="hide">
                            <input type="radio" name="options" id="hide" autocomplete="off">Hide
                        </label>
                        <label class="btn btn-sm btn-on select-button-new" data-id="\(i)" data-type="pokemon" data-info="show">
                            <input type="radio" name="options" id="show" autocomplete="off">Show
                        </label>
                    </div>
                """
                
                let size = """
                    <div class="btn-group btn-group-toggle" data-toggle="buttons">
                        <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="pokemon" data-info="small">
                            <input type="radio" name="options" id="hide" autocomplete="off">Small
                        </label>
                        <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="pokemon" data-info="normal">
                            <input type="radio" name="options" id="show" autocomplete="off">Normal
                        </label>
                        <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="pokemon" data-info="large">
                            <input type="radio" name="options" id="show" autocomplete="off">Large
                        </label>
                        <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="pokemon" data-info="huge">
                            <input type="radio" name="options" id="show" autocomplete="off">Huge
                        </label>
                    </div>
                """
                
                pokemonData.append([
                    "pokemon_id": String(format: "%03d", i),
                    "pokemon_name": Localizer.global.get(value: "poke_\(i)") ?? "?",
                    "image": "<img class=\"lazy_load\" data-src=\"/static/img/pokemon/\(i).png\" style=\"height:31px; width:31px;\">",
                    "filter": filter,
                    "size": size
                ])
            }
            data["pokemon_filters"] = pokemonData
        }

        
        if showDevices && perms.contains(.adminSetting) {
            
            let devices = try? Device.getAll()
            var jsonArray = [[String: Any]]()
            
            if devices != nil {
                for device in devices! {
                    var deviceData = [String: Any]()
                    deviceData["uuid"] = device.uuid
                    deviceData["host"] = device.lastHost ?? ""
                    deviceData["instance"] = device.instanceName ?? ""
                    
                    if formatted {
                        let formattedDate: String
                        if device.lastSeen == 0 {
                            formattedDate = ""
                        } else {
                            let date = Date(timeIntervalSince1970: TimeInterval(device.lastSeen))
                            let formatter = DateFormatter()
                            formatter.dateFormat = "HH:mm:ss dd.MM.yyy"
                            formattedDate = formatter.string(from: date)
                        }
                        deviceData["last_seen"] = ["timestamp": device.lastSeen, "formatted": formattedDate]
                        deviceData["buttons"] = "<a href=\"/dashboard/device/assign/\(device.uuid.stringByEncodingURL.replacingOccurrences(of: "/", with: "%2F"))\" role=\"button\" class=\"btn btn-primary\">Assign Instance</a>"
                    } else {
                        deviceData["last_seen"] = device.lastSeen
                    }
                    jsonArray.append(deviceData)
                }
            }
            data["devices"] = jsonArray
            
        }
        
        if showInstances && perms.contains(.adminSetting) {
            
            let instances = try? Instance.getAll()
            var jsonArray = [[String: Any]]()
            
            if instances != nil {
                for instance in instances! {
                    var instanceData = [String: Any]()
                    instanceData["name"] = instance.name
                    switch instance.type {
                    case .circleRaid:
                        instanceData["type"] = "Circle Raid"
                    case .circlePokemon:
                        instanceData["type"] = "Circle Pokemon"
                    }
                    
                    if formatted {
                        instanceData["buttons"] = "<a href=\"/dashboard/instance/edit/\(instance.name.stringByEncodingURL.replacingOccurrences(of: "/", with: "%2F"))\" role=\"button\" class=\"btn btn-primary\">Edit Instance</a>"
                    }
                    jsonArray.append(instanceData)
                }
            }
            data["instances"] = jsonArray
            
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
