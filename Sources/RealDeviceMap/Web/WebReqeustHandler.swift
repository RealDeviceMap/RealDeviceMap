//
//  PrivateWebReqeustHandler.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//

import Foundation
import PerfectLib
import PerfectHTTP
import PerfectMustache
import PerfectSessionMySQL

class WebReqeustHandler {
    
    class CompletedEarly: Error {}
    
    static var isSetup = false
    static var accessToken: String?
    
    static var startLat: Double = 0
    static var startLon: Double = 0
    static var startZoom: Int = 14
    static var maxPokemonId: Int = 493
    static var title: String = "RealDeviceMap"
    static var avilableFormsJson: String = ""
    static var avilableItemJson: String = ""
    static var enableRegister: Bool = true
    static var tileservers = [String: [String: String]]()
    static var cities = [String: [String: Any]]()
    
    private static let sessionDriver = MySQLSessions()
            
    static func handle(request: HTTPRequest, response: HTTPResponse, page: WebServer.Page, requiredPerms: [Group.Perm], requiredPermsCount:Int = -1) {
        
        let localizer = Localizer.global
        
        let documentRoot = "\(projectroot)/resources/webroot"
        var data = MustacheEvaluationContext.MapType()
        data["csrf"] = request.session?.data["csrf"]
        data["timestamp"] = UInt32(Date().timeIntervalSince1970)
        data["locale"] = Localizer.locale
        data["locale_last_modified"] = localizer.lastModified
        data["enable_register"] = enableRegister
        
        // Localize Navbar
        let navLoc = ["nav_dashboard", "nav_stats", "nav_logout", "nav_register", "nav_login"]
        for loc in navLoc {
            data[loc] = localizer.get(value: loc)
        }
        
        let tmp = getPerms(request: request)
        let perms = tmp.perms
        let username = tmp.username
        
        if username != nil && username != "" {
            data["username"] = username
            data["is_logged_in"] = true
        }
        
        var requiredPermsCountReal: Int
        if requiredPermsCount == -1 {
            requiredPermsCountReal = requiredPerms.count
        } else {
            requiredPermsCountReal = requiredPermsCount
        }
        var requiredPermsFound = 0
        for perm in requiredPerms {
            if perms.contains(perm) {
                requiredPermsFound += 1
            }
        }
        if requiredPermsCountReal > requiredPermsFound {
            if username != nil && username != "" {
                response.setBody(string: "Unauthorized.")
                sessionDriver.save(session: request.session!)
                response.completed(status: .unauthorized)
                return
            } else {
                response.setBody(string: "Unauthorized. Log in first.")
                response.redirect(path: "/login")
                sessionDriver.save(session: request.session!)
                response.completed(status: .found)
                return
            }
        }
        
        if perms.contains(.viewStats) {
            data["show_stats"] = true
        }
 
        if perms.contains(.adminUser) || perms.contains(.adminSetting) {
            data["show_dashboard"] = true
        }
        
        if (!isSetup && page != .setup) {
            response.setBody(string: "Setup required.")
            response.redirect(path: "/setup")
            sessionDriver.save(session: request.session!)
            response.completed(status: .found)
            return
        }
        if (isSetup && page == .setup) {
            response.setBody(string: "Setup already completed.")
            response.redirect(path: "/")
            sessionDriver.save(session: request.session!)
            response.completed(status: .movedPermanently)
            return
        }
        
        data["title"] = title
        switch page {
        case .home:
            data["page_is_home"] = true
            data["page"] = "Home"
            data["hide_gyms"] = !perms.contains(.viewMapGym)
            data["hide_pokestops"] = !perms.contains(.viewMapPokestop)
            data["hide_raids"] = !perms.contains(.viewMapRaid)
            data["hide_pokemon"] = !perms.contains(.viewMapPokemon)
            data["hide_spawnpoints"] = !perms.contains(.viewMapSpawnpoint)
            data["hide_quests"] = !perms.contains(.viewMapQuest)
            data["hide_cells"] = !perms.contains(.viewMapCell)
            var zoom = request.urlVariables["zoom"]?.toInt()
            var lat = request.urlVariables["lat"]?.toDouble()
            var lon = request.urlVariables["lon"]?.toDouble()
            var city = request.urlVariables["city"]
            if city == nil, let tmpCity = request.urlVariables["lat"], tmpCity.toDouble() == nil { // City but in wrong route
                city = tmpCity
                if let tmpZoom = request.urlVariables["lon"]?.toInt() {
                    zoom = tmpZoom
                }
                
            }
            
            if city != nil {
                guard let citySetting = cities[city!.lowercased()] else {
                    response.setBody(string: "The city \(city!) was not found.")
                    sessionDriver.save(session: request.session!)
                    response.completed(status: .notFound)
                    return
                }
                lat = citySetting["lat"] as? Double
                lon = citySetting["lon"] as? Double
                if zoom == nil {
                    zoom = citySetting["zoom"] as? Int
                }
            }
            
            data["lat"] = lat ?? self.startLat
            data["lon"] = lon ?? self.startLon
            data["zoom"] = zoom ?? self.startZoom

            // Localize
            let homeLoc = ["filter_title", "filter_gyms", "filter_raids", "filter_pokestops", "filter_spawnpoints", "filter_pokemon", "filter_filter", "filter_cancel", "filter_close", "filter_hide", "filter_show", "filter_reset", "filter_disable_all", "filter_pokemon_filter", "filter_save", "filter_image", "filter_size_properties", "filter_quests", "filter_name", "filter_quest_filter", "filter_cells", "filter_select_mapstyle", "filter_mapstyle"]
            for loc in homeLoc {
                data[loc] = localizer.get(value: loc)
            }
            
        case .dashboard:
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard"
            data["show_setting"] = perms.contains(.adminSetting)
            data["show_user"] = perms.contains(.adminUser)
        case .dashboardSettings:
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Settings"
            if request.method == .post {
                do {
                    data = try updateSettings(data: data, request: request, response: response)
                } catch {
                    return
                }
            }
            data["start_lat"] = startLat
            data["start_lon"] = startLon
            data["start_zoom"] = startZoom
            data["max_pokemon_id"] = maxPokemonId
            data["locale_new"] = Localizer.locale
            data["enable_register_new"] = enableRegister
            data["enable_clearing"] = WebHookRequestHandler.enableClearing
            data["webhook_urls"] = WebHookController.global.webhookURLStrings.joined(separator: ";")
            data["webhook_delay"] = WebHookController.global.webhookSendDelay
            data["pokemon_time_new"] = Pokemon.defaultTimeUnseen
            data["pokemon_time_old"] = Pokemon.defaultTimeReseen
            var tileserverString = ""
            
            let tileserversSorted = tileservers.sorted { (rhs, lhs) -> Bool in
                return rhs.key == "Default" || rhs.key < lhs.key
            }
            
            for tileserver in tileserversSorted {
                tileserverString += "\(tileserver.key);\(tileserver.value["url"] ?? "");\(tileserver.value["attribution"] ?? "")\n"
            }
            data["tileservers"] = tileserverString
            
            var citiesString = ""
            for city in self.cities {
                if let lat = city.value["lat"] as? Double, let lon = city.value["lon"] as? Double {
                    let zoom = city.value["zoom"] as? Int
                    citiesString += "\(city.key);\(lat);\(lon)"
                    if zoom != nil {
                        citiesString += ";\(zoom!)"
                    }
                    citiesString += "\n"
                }
            }
            data["cities"] = citiesString
            
        case .dashboardDevices:
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Devices"
        case .dashboardDeviceAssign:
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Assign Device"
            let deviceUUID = (request.urlVariables["device_uuid"] ?? "").decodeUrl()!

            data["device_uuid"] = deviceUUID
            if request.method == .post {
                do {
                    data = try assignDevicePost(data: data, request: request, response: response, deviceUUID: deviceUUID)
                } catch {
                    return
                }
            } else {
                do {
                    data = try assignDeviceGet(data: data, request: request, response: response, deviceUUID: deviceUUID)
                } catch {
                    return
                }
            }
        case .dashboardInstances:
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Instances"
        case .dashboardInstanceAdd:
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Add Instance"
            if request.method == .post {
                do {
                    data = try addEditInstance(data: data, request: request, response: response)
                } catch {
                    return
                }
            } else {
                data["min_level"] = 0
                data["max_level"] = 29
                data["timezone_offset"] = 0
                data["nothing_selected"] = true
            }
        case .dashboardInstanceIVQueue:
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - IV Queue"
            let instanceName = request.urlVariables["instance_name"] ?? ""
            data["instance_name_url"] = instanceName
            data["instance_name"] = instanceName.decodeUrl() ?? ""
        case .dashboardAssignments:
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Assignments"
        case .dashboardAssignmentAdd:
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Add Assignment"
            if request.method == .get {
                do {
                    data = try editAssignmentsGet(data: data, request: request, response: response)
                } catch {
                    return
                }
            } else {
                do {
                    data = try editAssignmentsPost(data: data, request: request, response: response)
                } catch {
                    return
                }
            }
        case .dashboardAssignmentDelete:
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Delete Assignment"
            
            let uuid = (request.urlVariables["uuid"] ?? "").decodeUrl()!
            let tmp = uuid.replacingOccurrences(of: "\\\\-", with: "&tmp")
            
            let split = tmp.components(separatedBy: "\\-")
            if split.count == 3 {
                let instanceName = split[0].replacingOccurrences(of: "&tmp", with: "\\\\-").unscaped()
                let deviceUUID = split[1].replacingOccurrences(of: "&tmp", with: "\\\\-").unscaped()
                let time = UInt32(split[2]) ?? 0
                let assignment = Assignment(instanceName: instanceName, deviceUUID: deviceUUID, time: time)
                do {
                    try assignment.delete()
                } catch {
                    response.setBody(string: "Internal Server Error")
                    sessionDriver.save(session: request.session!)
                    response.completed(status: .internalServerError)
                }
                AssignmentController.global.deleteAssignment(assignment: assignment)
                response.redirect(path: "/dashboard/assignments")
                sessionDriver.save(session: request.session!)
                response.completed(status: .seeOther)
                
            } else {
                response.setBody(string: "Bad Request")
                sessionDriver.save(session: request.session!)
                response.completed(status: .badRequest)
            }
            
        case .dashboardAccounts:
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Accounts"
            data["new_accounts_count"] = (try? Account.getNewCount()) ?? "?"
            data["in_use_accounts_count"] = (try? Account.getInUseCount()) ?? "?"
            data["warned_accounts_count"] = (try? Account.getWarnedCount()) ?? "?"
            data["failed_accounts_count"] = (try? Account.getFailedCount()) ?? "?"
            data["cooldown_accounts_count"] = (try? Account.getCooldownCount()) ?? "?"
            data["spin_limit_accounts_count"] = (try? Account.getSpinLimitCount()) ?? "?"
        case .dashboardAccountsAdd:
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Add Accounts"
            if request.method == .post {
                do {
                    data = try addAccounts(data: data, request: request, response: response)
                } catch {
                    return
                }
            } else {
                data["level"] = 0
            }
        case .dashboardInstanceEdit:
            let instanceName = (request.urlVariables["instance_name"] ?? "").decodeUrl()!
            data["page_is_dashboard"] = true
            data["old_name"] = instanceName
            data["page"] = "Dashboard - Edit Instance"
            
            if request.param(name: "delete") == "true" {
                do {
                    try Instance.delete(name: instanceName)
                    InstanceController.global.removeInstance(instanceName: instanceName)
                    response.redirect(path: "/dashboard/instances")
                    sessionDriver.save(session: request.session!)
                    response.completed(status: .seeOther)
                    return
                } catch {
                    response.setBody(string: "Internal Server Error")
                    sessionDriver.save(session: request.session!)
                    response.completed(status: .internalServerError)
                    return
                }
                
            } else if request.method == .post {
                do {
                    data = try addEditInstance(data: data, request: request, response: response, instanceName: instanceName)
                } catch {
                    return
                }
            } else {
                do {
                    data = try editInstanceGet(data: data, request: request, response: response, instanceName: instanceName)
                } catch {
                    return
                }
            }
        case .dashboardClearQuests:
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Clear All Quests"
            if request.method == .post {
                do {
                    try Pokestop.clearQuests()
                    InstanceController.global.reloadAllInstances()
                    response.redirect(path: "/dashboard")
                    sessionDriver.save(session: request.session!)
                    response.completed(status: .found)
                    return
                } catch {
                    data["show_error"] = true
                    data["error"] = "Failed to clear Quests. Please try agai later."
                }
            }
        case .register:
            
            if !enableRegister {
                response.redirect(path: "/")
                sessionDriver.save(session: request.session!)
                response.completed(status: .found)
                return
            }
            
            data["page_is_register"] = true
            data["page"] = "Register"
            
            // Localize
            let homeLoc = ["register_username", "register_email", "register_password", "register_retype_password", "register_register"]
            for loc in homeLoc {
                data[loc] = localizer.get(value: loc)
            }
            data["register_title"] = localizer.get(value: "register_title", replace: ["name" : title])
            
            if request.method == .post {
                do {
                    data = try register(data: data, request: request, response: response, useAccessToken: false)
                } catch {
                    return
                }
            }
        case .login:
            data["page_is_login"] = true
            data["page"] = "Login"
            
            // Localize
            let homeLoc = ["login_username_email", "login_password", "login_login"]
            for loc in homeLoc {
                data[loc] = localizer.get(value: loc)
            }
            data["login_title"] = localizer.get(value: "login_title", replace: ["name" : title])
            
            if request.method == .post {
                do {
                    data = try login(data: data, request: request, response: response)
                } catch {
                    return
                }
            }
        case .logout:
            data["page"] = "Logout"
            do {
                try logout(data: data, request: request, response: response)
            } catch {
                return
            }
        case .setup:
            data["page"] = "Setup"
            if request.method == .post {
                do {
                    data = try register(data: data, request: request, response: response, useAccessToken: true)
                } catch {
                    return
                }
            }
        case .homeJs:
            data["start_lat"] = request.param(name: "lat")?.toDouble() ?? startLat
            data["start_lon"] = request.param(name: "lon")?.toDouble() ?? startLon
            data["start_zoom"] = request.param(name: "zoom")?.toUInt8() ?? startZoom
            data["max_pokemon_id"] = maxPokemonId
            data["avilable_forms_json"] = avilableFormsJson.replacingOccurrences(of: "\\\"", with: "\\\\\"")
            data["avilable_items_json"] = avilableItemJson.replacingOccurrences(of: "\\\"", with: "\\\\\"")
            data["avilable_tileservers_json"] = (tileservers.jsonEncodeForceTry() ?? "").replacingOccurrences(of: "\\\"", with: "\\\\\"")
        default:
            break
        }
        
        if page == .homeJs {
            response.setHeader(.contentType, value: "application/javascript")
        } else if page == .homeCss {
            response.setHeader(.contentType, value: "text/css")
        } else {
            response.setHeader(.contentType, value: "text/html")
        }
        mustacheRequest(
            request: request,
            response: response,
            handler: WebPageHandler(page: page, data: data),
            templatePath: documentRoot + "/" + page.rawValue
        )
        if (page != .homeJs && page != .homeCss) {
            sessionDriver.save(session: request.session!)
        }
        response.completed()
    }
    
    static func logout(data: MustacheEvaluationContext.MapType, request: HTTPRequest, response: HTTPResponse) throws {
        request.session?.userid = ""
        request.session?.data["perms"] = nil
        let redirect = request.param(name: "redirect") ?? "/"
        response.redirect(path: redirect)
        sessionDriver.save(session: request.session!)
        response.completed(status: .found)
        throw CompletedEarly()
    }
    
    static func register(data: MustacheEvaluationContext.MapType, request: HTTPRequest, response: HTTPResponse, useAccessToken: Bool) throws -> MustacheEvaluationContext.MapType {
        
        var data = data
        
        let username = request.param(name: "username")
        let password = request.param(name: "password")
        let passwordRetype = request.param(name: "password-retype")
        let email = request.param(name: "email")
        let accessToken = request.param(name: "access-token")
        
        var noError = true
        
        if password != passwordRetype {
            data["is_password_retype_error"] = true
            data["password_retype_error"] = "The passwords do not match."
            data["is_password_error"] = true
            data["password_error"] = "The passwords do not match."
            noError = false
        }
        if useAccessToken && accessToken != self.accessToken {
            data["is_access_token_error"] = true
            data["access_token_error"] = "Wrong access token."
            noError = false
        }
        if username == nil || username == "" {
            data["is_username_error"] = true
            data["username_error"] = "Username can not be empty."
            noError = false
        }
        if email == nil || email == "" {
            data["is_email_error"] = true
            data["email_error"] = "Email can not be empty."
            noError = false
        }
        
        if noError {
            var user: User?
            do {
                let groupName: String
                if useAccessToken {
                    groupName = "root"
                } else {
                    groupName = "default"
                }
                user = try User.register(username: username!, email: email!, password: password!, groupName: groupName)
            } catch {
                let localizer = Localizer.global
                if error is DBController.DBError {
                    data["is_undefined_error"] = true
                    data["undefined_error"] = localizer.get(value: "register_error_undefined")
                } else {
                    let registerError = error as! User.RegisterError
                    switch registerError.type {
                    case .usernameInvalid:
                        data["is_username_error"] = true
                        data["username_error"] = localizer.get(value: "register_error_username_invalid")
                    case .usernameTaken:
                        data["is_username_error"] = true
                        data["username_error"] = localizer.get(value: "register_error_username_taken")
                    case .emailInvalid:
                        data["is_email_error"] = true
                        data["email_error"] = localizer.get(value: "register_error_email_invalid")
                    case .emailTaken:
                        data["is_email_error"] = true
                        data["email_error"] = localizer.get(value: "register_error_email_taken")
                    case .passwordInvalid:
                        data["is_password_error"] = true
                        data["password_error"] = localizer.get(value: "register_error_password_invalid")
                    case .undefined:
                        data["is_undefined_error"] = true
                        data["undefined_error"] = localizer.get(value: "register_error_undefined")
                    }
                }
            }
            
            if user != nil {
                request.session?.userid = user!.username
                if user!.group != nil {
                    request.session?.data["perms"] = Group.Perm.permsToNumber(perms: user!.group!.perms)
                }
                if useAccessToken {
                    try DBController.global.setValueForKey(key: "IS_SETUP", value: "true")
                    WebReqeustHandler.isSetup = true
                    WebReqeustHandler.accessToken = nil
                    response.redirect(path: "/")
                    sessionDriver.save(session: request.session!)
                    response.completed(status: .seeOther)
                    throw CompletedEarly()
                } else {
                    let redirect = request.param(name: "redirect") ?? "/"
                    response.redirect(path: redirect)
                    sessionDriver.save(session: request.session!)
                    response.completed(status: .seeOther)
                    throw CompletedEarly()
                }
            }
        }
        
        data["username"] = username
        data["password"] = password
        data["password-retype"] = passwordRetype
        data["email"] = email
        if useAccessToken {
            data["access-token"] = accessToken
        }
        
        return data
    }
    
    static func login(data: MustacheEvaluationContext.MapType, request: HTTPRequest, response: HTTPResponse) throws -> MustacheEvaluationContext.MapType {
        
        var data = data
        
        let usernameEmail = request.param(name: "username-email") ?? ""
        let password = request.param(name: "password") ?? ""
        
        var user: User?
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
            let localizer = Localizer.global
            if error is DBController.DBError {
                data["is_error"] = true
                data["error"] = localizer.get(value: "login_error_undefined")
            } else {
                let registerError = error as! User.LoginError
                switch registerError.type {
                case .usernamePasswordInvalid:
                    data["is_error"] = true
                    data["error"] = localizer.get(value: "login_error_invalid")
                case .undefined:
                    data["is_error"] = true
                    data["error"] = localizer.get(value: "login_error_undefined")
                case .limited:
                    data["is_error"] = true
                    data["error"] = localizer.get(value: "login_error_limited")
                }
            }
        }
        
        if user != nil {
            request.session?.userid = user!.username
            if user!.group != nil {
                request.session?.data["perms"] = Group.Perm.permsToNumber(perms: user!.group!.perms)
            }
            let redirect = request.param(name: "redirect") ?? "/"
            response.redirect(path: redirect)
            sessionDriver.save(session: request.session!)
            response.completed(status: .seeOther)
            throw CompletedEarly()
        }
        
        data["username-email"] = usernameEmail
        data["password"] = password
        
        return data
    }
 
    static func updateSettings(data: MustacheEvaluationContext.MapType, request: HTTPRequest, response: HTTPResponse) throws -> MustacheEvaluationContext.MapType {
        
        var data = data
        guard
            let startLat = request.param(name: "start_lat")?.toDouble(),
            let startLon = request.param(name: "start_lon")?.toDouble(),
            let startZoom = request.param(name: "start_zoom")?.toInt(),
            let title = request.param(name: "title"),
            let defaultTimeUnseen = request.param(name: "pokemon_time_new")?.toUInt32(),
            let defaultTimeReseen = request.param(name: "pokemon_time_old")?.toUInt32(),
            let maxPokemonId = request.param(name: "max_pokemon_id")?.toInt(),
            let locale = request.param(name: "locale_new")?.lowercased(),
            let tileserversString = request.param(name: "tileservers")?.replacingOccurrences(of: "<br>", with: "").replacingOccurrences(of: "\r\n", with: "\n", options: .regularExpression),
            let cities = request.param(name: "cities")?.replacingOccurrences(of: "<br>", with: "").replacingOccurrences(of: "\r\n", with: "\n", options: .regularExpression)
            else {
            data["show_error"] = true
            return data
        }
        
        let webhookDelay = request.param(name: "webhook_delay")?.toDouble() ?? 5.0
        let webhookUrlsString = request.param(name: "webhook_urls") ?? ""
        let webhookUrls = webhookUrlsString.components(separatedBy: ";")
        let enableRegister = request.param(name: "enable_register_new") != nil
        let enableClearing = request.param(name: "enable_clearing") != nil
        
        var tileservers = [String: [String: String]]()
        for tileserverString in tileserversString.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n") {
            let split = tileserverString.components(separatedBy: ";")
            if split.count == 3 {
                tileservers[split[0]] = ["url": split[1], "attribution": split[2]]
            } else {
                data["show_error"] = true
                return data
            }
        }
        
        var citySettings = [String: [String: Any]]()
        for cityString in cities.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n") {
            let split = cityString.components(separatedBy: ";")
            // Mayrhofen;10;10;15
            
            let name: String
            let lat: Double?
            let lon: Double?
            let zoom: Int?
            if split.count == 3 {
                name = split[0].lowercased()
                lat = split[1].toDouble()
                lon = split[2].toDouble()
                zoom = nil
            } else if split.count == 4 {
                name = split[0].lowercased()
                lat = split[1].toDouble()
                lon = split[2].toDouble()
                zoom = split[3].toInt()
            } else {
                data["show_error"] = true
                return data
            }
            guard let latReal = lat, let lonReal = lon else {
                data["show_error"] = true
                return data
            }
            citySettings[name] = [
                "lat": latReal,
                "lon": lonReal,
                "zoom": zoom as Any
            ]
        }
        
        do {
            try DBController.global.setValueForKey(key: "MAP_START_LAT", value: startLat.description)
            try DBController.global.setValueForKey(key: "MAP_START_LON", value: startLon.description)
            try DBController.global.setValueForKey(key: "MAP_START_ZOOM", value: startZoom.description)
            try DBController.global.setValueForKey(key: "TITLE", value: title)
            try DBController.global.setValueForKey(key: "WEBHOOK_DELAY", value: webhookDelay.description)
            try DBController.global.setValueForKey(key: "WEBHOOK_URLS", value: webhookUrlsString)
            try DBController.global.setValueForKey(key: "POKEMON_TIME_UNSEEN", value: defaultTimeUnseen.description)
            try DBController.global.setValueForKey(key: "POKEMON_TIME_RESEEN", value: defaultTimeReseen.description)
            try DBController.global.setValueForKey(key: "MAP_MAX_POKEMON_ID", value: maxPokemonId.description)
            try DBController.global.setValueForKey(key: "LOCALE", value: locale)
            try DBController.global.setValueForKey(key: "ENABLE_REGISTER", value: enableRegister.description)
            try DBController.global.setValueForKey(key: "ENABLE_CLEARING", value: enableClearing.description)
            try DBController.global.setValueForKey(key: "TILESERVERS", value: tileservers.jsonEncodeForceTry() ?? "")
            try DBController.global.setValueForKey(key: "CITIES", value: citySettings.jsonEncodeForceTry() ?? "")
        } catch {
            data["show_error"] = true
            return data
        }
        
        WebReqeustHandler.startLat = startLat
        WebReqeustHandler.startLon = startLon
        WebReqeustHandler.startZoom = startZoom
        WebReqeustHandler.title = title
        WebReqeustHandler.maxPokemonId = maxPokemonId
        WebReqeustHandler.enableRegister = enableRegister
        WebReqeustHandler.tileservers = tileservers
        WebReqeustHandler.cities = citySettings
        WebHookController.global.webhookSendDelay = webhookDelay
        WebHookController.global.webhookURLStrings = webhookUrls
        WebHookRequestHandler.enableClearing = enableClearing
        Pokemon.defaultTimeUnseen = defaultTimeUnseen
        Pokemon.defaultTimeReseen = defaultTimeReseen
        Localizer.locale = locale
        
        data["title"] = title
        data["show_success"] = true
        
        return data
    }
    
    static func addEditInstance(data: MustacheEvaluationContext.MapType, request: HTTPRequest, response: HTTPResponse, instanceName: String? = nil) throws -> MustacheEvaluationContext.MapType {
        
        var data = data
        guard
            let name = request.param(name: "name"),
            let area = request.param(name: "area")?.replacingOccurrences(of: "<br>", with: "").replacingOccurrences(of: "\r\n", with: "\n", options: .regularExpression),
            let minLevel = request.param(name: "min_level")?.toUInt8(),
            let maxLevel = request.param(name: "max_level")?.toUInt8()
        else {
            data["show_error"] = true
            data["error"] = "Invalid Request."
            return data
        }
        
        let timezoneOffset = Int(request.param(name: "timezone_offset") ?? "0" ) ?? 0
        let pokemonIDsText = request.param(name: "pokemon_ids")?.replacingOccurrences(of: "<br>", with: ",").replacingOccurrences(of: "\r\n", with: ",", options: .regularExpression)
        
        var pokemonIDs = [UInt16]()
        let pokemonIDsSplit = pokemonIDsText?.components(separatedBy: ",")
        if pokemonIDsSplit != nil {
            for pokemonIDText in pokemonIDsSplit! {
                let pokemonID = pokemonIDText.trimmingCharacters(in: .whitespaces).toUInt16()
                if pokemonID != nil {
                    pokemonIDs.append(pokemonID!)
                }
            }
        }
        
        let type = Instance.InstanceType.fromString(request.param(name: "type") ?? "")
        
        data["name"] = name
        data["area"] = area
        data["pokemon_ids"] = pokemonIDsText
        data["min_level"] = minLevel
        data["max_level"] = maxLevel
        data["timezone_offset"] = timezoneOffset
        
        if type == nil {
            data["nothing_selected"] = true
        } else if type! == .circlePokemon {
            data["circle_pokemon_selected"] = true
        } else if type! == .circleRaid {
            data["circle_raid_selected"] = true
        } else if type! == .circleSmartRaid {
            data["circle_smart_raid_selected"] = true
        } else if type! == .autoQuest {
            data["auto_quest_selected"] = true
        } else if type! == .pokemonIV {
            data["pokemon_iv_selected"] = true
        }
        
        if type == .pokemonIV && pokemonIDs.isEmpty {
            data["show_error"] = true
            data["error"] = "Failed to parse Pokemon IDs."
            return data
        }
        
        if minLevel > maxLevel || minLevel < 0 || minLevel > 40 || maxLevel < 0 || maxLevel > 40 {
            data["show_error"] = true
            data["error"] = "Invalid Levels"
            return data
        }
        
        var newCoords: [Any]
        
        if type != nil && type! == .circlePokemon || type! == .circleRaid || type! == .circleSmartRaid {
            var coords = [Coord]()
            let areaRows = area.components(separatedBy: "\n")
            for areaRow in areaRows {
                let rowSplit = areaRow.components(separatedBy: ",")
                if rowSplit.count == 2 {
                    let lat = rowSplit[0].trimmingCharacters(in: .whitespaces).toDouble()
                    let lon = rowSplit[1].trimmingCharacters(in: .whitespaces).toDouble()
                    if lat != nil && lon != nil {
                        coords.append(Coord(lat: lat!, lon: lon!))
                    }
                }
            }
            
            if coords.count == 0 {
                data["show_error"] = true
                data["error"] = "Failed to parse coords."
                return data
            }
            
            newCoords = coords
            
        } else if type != nil && type! == .autoQuest || type! == .pokemonIV {
            var coordArray = [[Coord]]()
            let areaRows = area.components(separatedBy: "\n")
            var currentIndex = 0
            for areaRow in areaRows {
                let rowSplit = areaRow.components(separatedBy: ",")
                if rowSplit.count == 2 {
                    let lat = rowSplit[0].trimmingCharacters(in: .whitespaces).toDouble()
                    let lon = rowSplit[1].trimmingCharacters(in: .whitespaces).toDouble()
                    if lat != nil && lon != nil {
                        while coordArray.count != currentIndex + 1{
                            coordArray.append([Coord]())
                        }
                        coordArray[currentIndex].append(Coord(lat: lat!, lon: lon!))
                    }
                } else if areaRow.contains(string: "[") && areaRow.contains(string: "]") &&
                    coordArray.count > currentIndex && coordArray[currentIndex].count != 0 {
                    currentIndex += 1
                }
            }
            
            if coordArray.count == 0 {
                data["show_error"] = true
                data["error"] = "Failed to parse coords."
                return data
            }
            
            newCoords = coordArray
        } else {
            data["show_error"] = true
            data["error"] = "Invalid Request."
            return data
        }
        
        if instanceName != nil {
            let oldInstance: Instance?
            do {
                oldInstance = try Instance.getByName(name: instanceName!)
            } catch {
                data["show_error"] = true
                data["error"] = "Failed to update instance. Is the name unique?"
                return data
            }
            if oldInstance == nil {
                response.setBody(string: "Instance Not Found")
                sessionDriver.save(session: request.session!)
                response.completed(status: .notFound)
                throw CompletedEarly()
            } else {
                oldInstance!.name = name
                oldInstance!.type = type!
                oldInstance!.data["area"] = newCoords
                oldInstance!.data["timezone_offset"] = timezoneOffset
                oldInstance!.data["min_level"] = minLevel
                oldInstance!.data["max_level"] = maxLevel

                if type == .pokemonIV {
                    oldInstance!.data["pokemon_ids"] = pokemonIDs
                }
                do {
                    try oldInstance!.update(oldName: instanceName!)
                } catch {
                    data["show_error"] = true
                    data["error"] = "Failed to update instance. Is the name unique?"
                    return data
                }
                InstanceController.global.reloadInstance(newInstance: oldInstance!, oldInstanceName: instanceName!)
                response.redirect(path: "/dashboard/instances")
                sessionDriver.save(session: request.session!)
                response.completed(status: .seeOther)
                throw CompletedEarly()
            }
        } else {
            var instanceData: [String : Any] = ["area" : newCoords, "timezone_offset": timezoneOffset, "min_level": minLevel, "max_level": maxLevel]
            if type == .pokemonIV {
                instanceData["pokemon_ids"] = pokemonIDs
            }
            let instance = Instance(name: name, type: type!, data: instanceData)
            do {
                try instance.create()
                InstanceController.global.addInstance(instance: instance)
            } catch {
                data["show_error"] = true
                data["error"] = "Failed to create instance. Is the name unique?"
                return data
            }
        }
        
        response.redirect(path: "/dashboard/instances")
        sessionDriver.save(session: request.session!)
        response.completed(status: .seeOther)
        throw CompletedEarly()
    }
    
    static func editInstanceGet(data: MustacheEvaluationContext.MapType, request: HTTPRequest, response: HTTPResponse, instanceName: String) throws -> MustacheEvaluationContext.MapType {
        
        var data = data
        
        let oldInstance: Instance?
        do {
            oldInstance = try Instance.getByName(name: instanceName)
        } catch {
            response.setBody(string: "Internal Server Error")
            sessionDriver.save(session: request.session!)
            response.completed(status: .internalServerError)
            throw CompletedEarly()
        }
        if oldInstance == nil {
            response.setBody(string: "Instance Not Found")
            sessionDriver.save(session: request.session!)
            response.completed(status: .notFound)
            throw CompletedEarly()
        } else {
            var areaString = ""
            let areaType1 = oldInstance!.data["area"] as? [[String: Double]]
            let areaType2 = oldInstance!.data["area"] as? [[[String: Double]]]
            if areaType1 != nil {
                for coordLine in areaType1! {
                    let lat = coordLine["lat"]
                    let lon = coordLine["lon"]
                    areaString += "\(lat!),\(lon!)\n"
                }
            } else if areaType2 != nil {
                var index = 1
                for geofence in areaType2! {
                    areaString += "[Geofence \(index)]\n"
                    index += 1
                    for coordLine in geofence {
                        let lat = coordLine["lat"]
                        let lon = coordLine["lon"]
                        areaString += "\(lat!),\(lon!)\n"
                    }
                }
            }
            
            data["name"] = oldInstance!.name
            data["area"] = areaString
            data["min_level"] = (oldInstance!.data["min_level"] as? Int)?.toInt8() ?? 0
            data["max_level"] = (oldInstance!.data["max_level"] as? Int)?.toInt8() ?? 29
            data["timezone_offset"] = oldInstance!.data["timezone_offset"] as? Int ?? 0
            let pokemonIDs = oldInstance!.data["pokemon_ids"] as? [Int]
            if pokemonIDs != nil {
                var text = ""
                for id in pokemonIDs! {
                    text.append("\(id)\n")
                }
                data["pokemon_ids"] = text
            }
            
            switch oldInstance!.type {
            case .circlePokemon:
                data["circle_pokemon_selected"] = true
            case .circleRaid:
                data["circle_raid_selected"] = true
            case .circleSmartRaid:
                data["circle_smart_raid_selected"] = true
            case .autoQuest:
                data["auto_quest_selected"] = true
            case .pokemonIV:
                data["pokemon_iv_selected"] = true
            }
            
            return data
        }
    }
    
    static func assignDevicePost(data: MustacheEvaluationContext.MapType, request: HTTPRequest, response: HTTPResponse, deviceUUID: String) throws -> MustacheEvaluationContext.MapType {

        var data = data
        guard let instanceName = request.param(name: "instance") else {
                data["show_error"] = true
                data["error"] = "Invalid Request."
                return data
        }
        
        let device: Device?
        let instances: [Instance]
        do {
            device = try Device.getById(id: deviceUUID)
            instances = try Instance.getAll()
        } catch {
            data["show_error"] = true
            data["error"] = "Failed to assign Device."
            return data
        }
        if device == nil {
            response.setBody(string: "Device Not Found")
            sessionDriver.save(session: request.session!)
            response.completed(status: .notFound)
            throw CompletedEarly()
        }
        var instancesData = [[String: Any]]()
        for instance in instances {
            instancesData.append(["name": instance.name, "selected": instance.name == instanceName])
        }
        data["instances"] = instancesData

        do {
            device!.instanceName = instanceName
            try device!.save(oldUUID: device!.uuid)
            InstanceController.global.reloadDevice(newDevice: device!, oldDeviceUUID: deviceUUID)
        } catch {
            data["show_error"] = true
            data["error"] = "Failed to assign Device."
            return data
        }
        response.redirect(path: "/dashboard/devices")
        sessionDriver.save(session: request.session!)
        response.completed(status: .seeOther)
        throw CompletedEarly()
        
    }

    static func assignDeviceGet(data: MustacheEvaluationContext.MapType, request: HTTPRequest, response: HTTPResponse, deviceUUID: String) throws -> MustacheEvaluationContext.MapType {
        
        var data = data
        let instances: [Instance]
        let device: Device?
        do {
            device = try Device.getById(id: deviceUUID)
            instances = try Instance.getAll()
        } catch {
            response.setBody(string: "Internal Server Error")
            sessionDriver.save(session: request.session!)
            response.completed(status: .internalServerError)
            throw CompletedEarly()
        }
        if device == nil {
            response.setBody(string: "Device Not Found")
            sessionDriver.save(session: request.session!)
            response.completed(status: .notFound)
            throw CompletedEarly()
        }
        
        var instancesData = [[String: Any]]()
        for instance in instances {
            instancesData.append(["name": instance.name, "selected": instance.name == device!.instanceName])
        }
        data["instances"] = instancesData
        return data
        
    }
    
    static func editAssignmentsGet(data: MustacheEvaluationContext.MapType, request: HTTPRequest, response: HTTPResponse) throws -> MustacheEvaluationContext.MapType {
        
        var data = data
        let instances: [Instance]
        let devices: [Device]
        do {
            devices = try Device.getAll()
            instances = try Instance.getAll()
        } catch {
            response.setBody(string: "Internal Server Error")
            sessionDriver.save(session: request.session!)
            response.completed(status: .internalServerError)
            throw CompletedEarly()
        }
        
        var instancesData = [[String: Any]]()
        for instance in instances {
            instancesData.append(["name": instance.name, "selected": false])
        }
        data["instances"] = instancesData
        var devicesData = [[String: Any]]()
        for device in devices {
            devicesData.append(["uuid": device.uuid, "selected": false])
        }
        data["devices"] = devicesData
        return data
        
    }
    
    static func editAssignmentsPost(data: MustacheEvaluationContext.MapType, request: HTTPRequest, response: HTTPResponse) throws -> MustacheEvaluationContext.MapType {
        
        let selectedDevice = request.param(name: "device")
        let selectedInstance = request.param(name: "instance")
        let time = request.param(name: "time")
        
        var data = data
        let instances: [Instance]
        let devices: [Device]
        do {
            devices = try Device.getAll()
            instances = try Instance.getAll()
        } catch {
            response.setBody(string: "Internal Server Error")
            sessionDriver.save(session: request.session!)
            response.completed(status: .internalServerError)
            throw CompletedEarly()
        }
        
        var instancesData = [[String: Any]]()
        for instance in instances {
            instancesData.append(["name": instance.name, "selected": instance.name == selectedInstance])
        }
        data["instances"] = instancesData
        var devicesData = [[String: Any]]()
        for device in devices {
            devicesData.append(["uuid": device.uuid, "selected": device.uuid == selectedDevice])
        }
        data["devices"] = devicesData
        data["time"] = time
        
        let timeInt: UInt32
        if time == nil || time == "" {
            timeInt = 0
        } else {
            let split = time!.components(separatedBy: ":")
            if split.count == 3, let hours = split[0].toInt(), let minutes = split[1].toInt(), let seconds = split[2].toInt() {
                let timeIntNew = UInt32(hours * 3600 + minutes * 60 + seconds)
                if timeIntNew == 0 {
                    timeInt = 1
                } else {
                    timeInt = timeIntNew
                }
            } else {
                data["show_error"] = true
                data["error"] = "Invalid Time."
                return data
            }
        }
        
        if selectedDevice == nil || selectedInstance == nil {
            data["show_error"] = true
            data["error"] = "Invalid Request."
            return data
        }
        do {
            let assignment = Assignment(instanceName: selectedInstance!, deviceUUID: selectedDevice!, time: timeInt)
            try assignment.create()
            AssignmentController.global.addAssignment(assignment: assignment)
        } catch {
            data["show_error"] = true
            data["error"] = "Failed to assign Device."
            return data
        }
        
        response.redirect(path: "/dashboard/assignments")
        sessionDriver.save(session: request.session!)
        response.completed(status: .seeOther)
        throw CompletedEarly()
        
    }
    
    static func addAccounts(data: MustacheEvaluationContext.MapType, request: HTTPRequest, response: HTTPResponse) throws -> MustacheEvaluationContext.MapType {
        
        var data = data
        
        guard
            let level = request.param(name: "level")?.toUInt8(),
            let accounts = request.param(name: "accounts")?.replacingOccurrences(of: "<br>", with: "").replacingOccurrences(of: "\r\n", with: "\n", options: .regularExpression).replacingOccurrences(of: ";", with: ",").replacingOccurrences(of: ":", with: ",")
            else {
                data["show_error"] = true
                data["error"] = "Invalid Request."
                return data
        }
        
        data["accounts"] = accounts
        data["level"] = level
        
        var accs = [Account]()
        let accountsRows = accounts.components(separatedBy: "\n")
        for accountsRow in accountsRows {
            let rowSplit = accountsRow.components(separatedBy: ",")
            if rowSplit.count == 2 {
                let username = rowSplit[0]
                let password = rowSplit[1]
                accs.append(Account(username: username, password: password, level: level, firstWarningTimestamp: nil, failedTimestamp: nil, failed: nil, lastEncounterLat: nil, lastEncounterLon: nil, lastEncounterTime: nil, spins: 0))
            }
        }
        
        if accs.count == 0 {
            data["show_error"] = true
            data["error"] = "Failed to parse accounts."
            return data
        } else {
            do {
                for acc in accs {
                    try acc.save(update: false)
                }
            } catch {
                data["show_error"] = true
                data["error"] = "Failed to save accounts."
                return data
            }
            response.redirect(path: "/dashboard/accounts")
            sessionDriver.save(session: request.session!)
            response.completed(status: .seeOther)
            throw CompletedEarly()
        }
    }
    
    static func getPerms(request: HTTPRequest) -> (perms: [Group.Perm], username: String?) {
        var username = request.session?.userid
        var perms = [Group.Perm]()
        let sessionPerms = (request.session?.data["perms"] as? Int)?.toUInt32()
        if sessionPerms == nil {
            if username != nil && username != "" {
                let user: User?
                do {
                    user = try User.get(username: username!)
                } catch {
                    user = nil
                }
                if user == nil {
                    request.session?.userid = ""
                    username = ""
                    perms = []
                } else {
                    let userPerms = user!.group?.perms
                    perms = userPerms ?? []
                    request.session?.data["perms"] = Group.Perm.permsToNumber(perms: userPerms ?? [])
                }
            }
            if username == nil || username == "" {
                let group: Group?
                do {
                    group = try Group.getWithName(name: "no_user")
                } catch {
                    group = nil
                }
                if group == nil {
                    perms = [Group.Perm]()
                } else {
                    let userPerms = group!.perms
                    perms = userPerms
                    request.session?.data["perms"] = Group.Perm.permsToNumber(perms: userPerms)
                }
            }
        } else {
            perms = Group.Perm.numberToPerms(number: sessionPerms!)
        }
        return (perms, username)
    }
}
