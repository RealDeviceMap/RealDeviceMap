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
        let showDevices =  request.param(name: "show_devices")?.toBool() ?? false
        let showInstances =  request.param(name: "show_instances")?.toBool() ?? false
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
            data["pokemon"] = try? Pokemon.getAll(minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!, updated: lastUpdate)
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
                        deviceData["buttons"] = "<a href=\"/dashboard/device/asign/\(device.uuid.stringByEncodingURL.replacingOccurrences(of: "/", with: "%2F"))\" role=\"button\" class=\"btn btn-primary\">Asign Instance</a>"
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
