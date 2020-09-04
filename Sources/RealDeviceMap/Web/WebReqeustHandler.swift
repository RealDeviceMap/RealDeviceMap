//
//  PrivateWebReqeustHandler.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity

import Foundation
import PerfectLib
import PerfectHTTP
import PerfectMustache
import PerfectSession
import PerfectSessionMySQL
import PerfectThread
import PerfectCURL

class WebReqeustHandler {

    class CompletedEarly: Error {}

    static var isSetup = false
    static var accessToken: String?

    static var startLat: Double = 0
    static var startLon: Double = 0
    static var startZoom: Int = 14
    static var minZoom: Int = 10
    static var maxZoom: Int = 18
    static var maxPokemonId: Int = 649
    static var title: String = "RealDeviceMap"
    static var avilableFormsJson: String = "[]"
    static var avilableItemJson: String = "[]"
    static var enableRegister: Bool = true
    static var tileservers = [String: [String: String]]()
    static var cities = [String: [String: Any]]()
    static var buttonsLeft = [[String: String]]()
    static var buttonsRight = [[String: String]]()
    static var googleAnalyticsId: String?
    static var googleAdSenseId: String?
    static var statsUrl: String?

    static var oauthDiscordRedirectURL: String?
    static var oauthDiscordClientID: String?
    static var oauthDiscordClientSecret: String?

    private static let sessionDriver = MySQLSessions()

    static func handle(request: HTTPRequest, response: HTTPResponse, page: WebServer.Page, requiredPerms: [Group.Perm],
                       requiredPermsCount: Int = -1, requiresLogin: Bool=false) {

        response.setHeader(.accessControlAllowHeaders, value: "*")
        response.setHeader(.accessControlAllowMethods, value: "GET")
        if let host = request.header(.host) {
            response.setHeader(.accessControlAllowOrigin, value: "http://\(host), https://\(host)")
        }

        let localizer = Localizer.global

        let documentRoot = "\(projectroot)/resources/webroot"
        var data = MustacheEvaluationContext.MapType()
        data["csrf"] = request.session?.data["csrf"]
        data["uri"] = request.uri
        data["timestamp"] = UInt32(Date().timeIntervalSince1970)
        data["locale"] = Localizer.locale
        data["locale_last_modified"] = localizer.lastModified
        data["enable_register"] = enableRegister
        data["has_mailer"] = MailController.global.isSetup
        data["title"] = title
        data["google_analytics_id"] = WebReqeustHandler.googleAnalyticsId
        data["google_adsense_id"] = WebReqeustHandler.googleAdSenseId
        data["buttons_left"] = buttonsLeft
        data["buttons_right"] = buttonsRight

        // Localize Navbar
        let navLoc = ["nav_dashboard", "nav_areas", "nav_stats", "nav_logout", "nav_register", "nav_login"]
        for loc in navLoc {
            data[loc] = localizer.get(value: loc)
        }

        let tmp = getPerms(request: request)
        let perms = tmp.perms
        let username = tmp.username

        if username != nil && username != "" {
            data["username"] = username
            data["is_logged_in"] = true
        } else if requiresLogin {
            response.setBody(string: "Unauthorized. Log in first.")
            response.redirect(path: "/login?redirect=\(request.uri)")
            sessionDriver.save(session: request.session!)
            response.completed(status: .found)
            return
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
                data["page"] = localizer.get(value: "title_unauthorized")
                data["unauthorized_title"] = localizer.get(value: "unauthorized_title")

                do {
                    if let user = try User.get(username: username!) {
                        if user.discordId == nil && WebReqeustHandler.oauthDiscordClientSecret != nil &&
                           WebReqeustHandler.oauthDiscordRedirectURL != nil &&
                           WebReqeustHandler.oauthDiscordClientID != nil {
                            data["discord_info"] = localizer.get(
                                value: "unauthorized_discord",
                                replace: ["href": "/oauth/discord?link=true"]
                            )
                        }
                        if !user.emailVerified && MailController.global.isSetup {
                            data["verifymail_info"] = localizer.get(
                                value: "unauthorized_verifymail",
                                replace: ["href": "/confirmemail"]
                            )
                        }
                    }
                } catch {}

                let path = documentRoot + "/" + WebServer.Page.unauthorized.rawValue
                let context = MustacheEvaluationContext(templatePath: path, map: data)
                let contents: String
                do {
                    contents = try context.formulateResponse(withCollector: .init())
                } catch {
                    response.setBody(string: "Internal Server Error")
                    response.completed(status: .internalServerError)
                    return
                }
                response.setBody(string: contents)
                response.completed(status: .unauthorized)
                return
            } else {
                response.setBody(string: "Unauthorized. Log in first.")
                response.redirect(path: "/login?redirect=\(request.uri)")
                sessionDriver.save(session: request.session!)
                response.completed(status: .found)
                return
            }
        }

        if perms.contains(.viewStats) {
            //data["show_stats"] = true
            data["stats_url"] = WebReqeustHandler.statsUrl
        }

        if perms.contains(.admin) {
            data["show_dashboard"] = true
        }

        if !isSetup && page != .setup {
            response.setBody(string: "Setup required.")
            response.redirect(path: "/setup")
            sessionDriver.save(session: request.session!)
            response.completed(status: .found)
            return
        }
        if isSetup && page == .setup {
            response.setBody(string: "Setup already completed.")
            response.redirect(path: "/")
            sessionDriver.save(session: request.session!)
            response.completed(status: .movedPermanently)
            return
        }

        switch page {
        case .home:
            data["page_is_home"] = true
            data["hide_gyms"] = !perms.contains(.viewMapGym)
            data["hide_pokestops"] = !perms.contains(.viewMapPokestop)
            data["hide_raids"] = !perms.contains(.viewMapRaid)
            data["hide_pokemon"] = !perms.contains(.viewMapPokemon)
            data["hide_spawnpoints"] = !perms.contains(.viewMapSpawnpoint)
            data["hide_quests"] = !perms.contains(.viewMapQuest)
            //data["hide_lures"] = !perms.contains(.viewMapLure)
            //data["hide_invasions"] = !perms.contains(.viewMapInvasion)
            data["hide_cells"] = !perms.contains(.viewMapCell)
            data["hide_submission_cells"] = !perms.contains(.viewMapSubmissionCells)
            data["hide_weathers"] = !perms.contains(.viewMapWeather)
            data["hide_devices"] = !perms.contains(.viewMapDevice)
            var zoom = request.urlVariables["zoom"]?.toInt()
            var lat = request.urlVariables["lat"]?.toDouble()
            var lon = request.urlVariables["lon"]?.toDouble()
            var city = request.urlVariables["city"]
            let id = request.urlVariables["id"]

            // City but in wrong route
            if city == nil, let tmpCity = request.urlVariables["lat"], tmpCity.toDouble() == nil {
                city = tmpCity
                if let tmpZoom = request.urlVariables["lon"]?.toInt() {
                    zoom = tmpZoom
                }

            }

            if city != nil {
                guard let citySetting = cities[city!.lowercased()] else {
                    response.setBody(string: "The city \"\(city!)\" was not found.")
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

            if (zoom ?? startZoom) > maxZoom {
                zoom = maxZoom
            } else if (zoom ?? startZoom) < minZoom {
                zoom = minZoom
            }

            if let id = id {
                let isEvent = (request.urlVariables["is_event"]?.toBool() ?? false)
                              && perms.contains(.viewMapEventPokemon)
                do {
                    if request.pathComponents[1] == "@pokemon" {
                        if let pokemon = try Pokemon.getWithId(id: id, isEvent: isEvent) {
                            data["start_pokemon"] = try pokemon.jsonEncodedString()
                            lat = pokemon.lat
                            lon = pokemon.lon
                            if zoom == nil {
                                zoom = 18
                            }
                        } else {
                            response.setBody(string: "The Pokemon \"\(id)\" was not found.")
                            sessionDriver.save(session: request.session!)
                            response.completed(status: .notFound)
                            return
                        }
                    }
                    if request.pathComponents[1] == "@pokestop" {
                        if let pokestop = try Pokestop.getWithId(id: id) {
                            if !perms.contains(.viewMapLure) {
                                pokestop.lureId = nil
                                pokestop.lureExpireTimestamp = nil
                            }
                            if !perms.contains(.viewMapInvasion) {
                                pokestop.pokestopDisplay = nil
                                pokestop.incidentExpireTimestamp = nil
                                pokestop.gruntType = nil
                            }
                            if !perms.contains(.viewMapQuest) {
                                pokestop.questType = nil
                                pokestop.questTimestamp = nil
                                pokestop.questTarget = nil
                                pokestop.questConditions = nil
                                pokestop.questRewards = nil
                                pokestop.questTemplate = nil
                            }
                            data["start_pokestop"] = try pokestop.jsonEncodedString()
                            lat = pokestop.lat
                            lon = pokestop.lon
                            if zoom == nil {
                                zoom = 18
                            }
                        } else {
                            response.setBody(string: "The Pokestop \"\(id)\" was not found.")
                            sessionDriver.save(session: request.session!)
                            response.completed(status: .notFound)
                            return
                        }
                    }
                    if request.pathComponents[1] == "@gym" {
                        if let gym = try Gym.getWithId(id: id) {
                            if !perms.contains(.viewMapRaid) {
                                gym.raidEndTimestamp = nil
                                gym.raidSpawnTimestamp = nil
                                gym.raidBattleTimestamp = nil
                                gym.raidPokemonId = nil
                            }
                            data["start_gym"] = try gym.jsonEncodedString()
                            lat = gym.lat
                            lon = gym.lon
                            if zoom == nil {
                                zoom = 18
                            }
                        } else {
                            response.setBody(string: "The Gym \"\(id)\" was not found.")
                            sessionDriver.save(session: request.session!)
                            response.completed(status: .notFound)
                            return
                        }
                    }
                } catch {
                    response.setBody(string: "Something went wrong while searching for this pokemon/pokestop/gym.")
                    sessionDriver.save(session: request.session!)
                    response.completed(status: .internalServerError)
                    return
                }
            }

            data["lat"] = lat ?? self.startLat
            data["lon"] = lon ?? self.startLon
            data["zoom"] = zoom ?? self.startZoom
            data["min_zoom"] = self.minZoom
            data["max_zoom"] = self.maxZoom
            data["show_areas"] = perms.contains(.viewMap) && !self.cities.isEmpty
            data["page_is_areas"] = perms.contains(.viewMap)
            var areas = [Any]()
            for area in self.cities.sorted(by: { $0.key < $1.key }) {
                let name = area.key.prefix(1).uppercased() + area.key.lowercased().dropFirst()
                areas.append(["area": name])
            }
            data["areas"] = areas

            // Localize
            let homeLoc = ["filter_title", "filter_gyms", "filter_raids", "filter_pokestops", "filter_spawnpoints",
                           "filter_pokemon", "filter_filter", "filter_cancel", "filter_close", "filter_hide",
                           "filter_show", "filter_reset", "filter_disable_all", "filter_pokemon_filter",
                           "filter_save", "filter_image", "filter_size_properties", "filter_quests", "filter_name",
                           "filter_quest_filter", "filter_raid_filter", "filter_gym_filter",
                           "filter_pokestop_filter", "filter_spawnpoint_filter", "filter_cells",
                           "filter_weathers", "filter_devices", "filter_select_mapstyle", "filter_mapstyle",
                           "filter_export", "filter_import", "filter_submission_cells"]
            for loc in homeLoc {
                data[loc] = localizer.get(value: loc)
            }
        case .confirmemail:
            data["page_is_profile"] = true
            data["page"] = localizer.get(value: "title_confirmmail")

            // Localize
            let locs = ["confirmmail_title", "confirmmail_request"]
            for loc in locs {
                data[loc] = localizer.get(value: loc)
            }

            do {
                if MailController.global.isSetup, let user = try User.get(username: username ?? "") {
                    if user.emailVerified {
                        data["is_error"] = true
                        data["error"] = localizer.get(value: "confirmmail_error_verified")
                    } else {
                        if request.method == .post {
                            try Token.delete(username: username ?? "", type: .confirmEmail)
                            try user.sendConfirmEmail()
                            data["is_success"] = true
                            data["success"] = localizer.get(value: "confirmmail_success_new")
                        }
                    }
                } else {
                    data["is_error"] = true
                    data["error"] = localizer.get(value: "confirmmail_error_undefined")
                }
            } catch {
                data["is_error"] = true
                data["error"] = localizer.get(value: "confirmmail_error_undefined")
            }
        case .confirmemailToken:
            data["page_is_profile"] = true
            data["page"] = localizer.get(value: "title_confirmmail")

            let token = ((request.urlVariables["token"] ?? "").decodeUrl() ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

            // Localize
            let locs = ["confirmmail_title"]
            for loc in locs {
                data[loc] = localizer.get(value: loc)
            }

            let host = request.host
            if !LoginLimiter.global.tokenAllowed(host: host) {
                data["is_error"] = true
                data["error"] = localizer.get(value: "confirmmail_error_limited")
            } else {
                LoginLimiter.global.tokenTry(host: host)
                do {
                    if MailController.global.isSetup, let user = try User.get(username: username ?? "") {
                        if user.emailVerified {
                            data["is_error"] = true
                            data["error"] = localizer.get(value: "confirmmail_error_verified")
                        } else {
                            let valid = try Token.validate(token: token, username: username ?? "", type: .confirmEmail)
                            if valid {
                                try user.verifyEmail()
                                try Token.delete(username: username ?? "", type: .confirmEmail)
                                data["is_success"] = true
                                data["success"] = localizer.get(value: "confirmmail_success")
                            } else {
                                data["is_error"] = true
                                data["error"] = localizer.get(
                                    value: "confirmmail_error_invalid",
                                    replace: ["href": "/confirmemail"]
                                )
                            }
                        }
                    } else {
                        data["is_error"] = true
                        data["error"] = localizer.get(value: "confirmmail_error_undefined")
                    }
                } catch {
                    data["is_error"] = true
                    data["error"] = localizer.get(value: "confirmmail_error_undefined")
                }
            }
        case .resetpassword:
            data["page_is_login"] = true
            data["page"] = localizer.get(value: "title_resetpassword")

            // Localize
            let locs = ["resetpassword_title", "resetpassword_username_email", "resetpassword_request"]
            for loc in locs {
                data[loc] = localizer.get(value: loc)
            }

            if request.method == .post {

                let usernameEmail = request.param(name: "username-email") ?? ""
                data["username-email"] = usernameEmail

                do {
                    if MailController.global.isSetup, let user = try User.get(usernameEmail: usernameEmail) {
                        try Token.delete(username: user.username, type: .resetPassword)
                        let thread = Threading.getQueue(name: Foundation.UUID().uuidString, type: .serial)
                        thread.dispatch { // Dispatch this so all requests take the same time
                            try? user.sendResetMail()
                            Threading.destroyQueue(thread)
                        }
                        data["is_success"] = true
                        data["success"] = localizer.get(value: "resetmail_success_new")
                    } else {
                        data["is_success"] = true
                        data["success"] = localizer.get(value: "resetmail_success_new")
                    }
                } catch {
                    data["is_error"] = true
                    data["error"] = localizer.get(value: "resetmail_error_undefined")
                }

            }
        case .resetpasswordToken:
            data["page_is_login"] = true
            data["page"] = localizer.get(value: "title_resetpassword")

            // Localize
            let locs = ["resetpassword_title", "resetpassword_password", "resetpassword_retype_password",
                        "resetpassword_change"]
            for loc in locs {
                data[loc] = localizer.get(value: loc)
            }

            let host = request.host
            if !LoginLimiter.global.tokenAllowed(host: host) {
                data["is_error"] = true
                data["error"] = localizer.get(value: "resetpassword_error_limited")
            } else if !MailController.global.isSetup {
                data["is_error"] = true
                data["error"] = localizer.get(value: "resetpassword_error_undefined")
            } else {
                LoginLimiter.global.tokenTry(host: host)

                let token = ((request.urlVariables["token"] ?? "").decodeUrl() ?? "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)

                let username: String?
                do {
                    if let tokenDb = try Token.get(token: token), tokenDb.type == .resetPassword {
                        username = tokenDb.username
                    } else {
                        username = nil
                        data["is_error"] = true
                        data["error"] = localizer.get(
                            value: "resetpassword_error_invalid",
                            replace: ["href": "/resetpassword"]
                        )
                    }
                } catch {
                    username = nil
                    data["is_error"] = true
                    data["error"] = localizer.get(value: "resetpassword_error_undefined")
                }

                if let username = username {

                    data["valid"] = true
                    data["username"] = username

                    let password = request.param(name: "password")?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let passwordRetype = request.param(name: "password-retype")?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    data["password"] = password
                    data["password-retype"] = passwordRetype

                    if password != "" {
                        if password != passwordRetype {
                            data["is_password_retype_error"] = true
                            data["password_retype_error"] = localizer.get(value: "register_error_password_retype")
                            data["is_password_error"] = true
                            data["password_error"] = localizer.get(value: "register_error_password_retype")
                        }

                        let user: User?
                        do {
                            user = try User.get(username: username)
                        } catch {
                            user = nil
                        }
                        if user == nil {
                            data["is_error"] = true
                            data["error"] = localizer.get(value: "resetpassword_error_undefined")
                        } else {
                            do {
                                try user!.setPassword(password: password)
                                try Token.delete(username: username, type: .resetPassword)
                                data["is_success"] = true
                                data["success"] = localizer.get(
                                    value: "resetpassword_success",
                                    replace: ["href": "/login"]
                                )
                            } catch {
                                let isUndefined: Bool
                                if let registerError = error as? User.RegisterError {
                                    if registerError.type == .passwordInvalid {
                                        data["is_password_error"] = true
                                        data["password_error"] = localizer.get(value: "register_error_password_invalid")
                                        isUndefined = false
                                    } else {
                                        isUndefined = true
                                    }
                                } else {
                                    isUndefined = true
                                }

                                if isUndefined {
                                    data["is_error"] = true
                                    data["error"] = localizer.get(value: "resetpassword_error_undefined")
                                }
                            }
                        }
                    }
                }

            }

        case .dashboard:
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard"
            data["version"] = VersionManager.global.version.replacingOccurrences(of: "Version ", with: "")
            data["version_commit"] = VersionManager.global.commit
            data["version_url"] = VersionManager.global.url
        case .dashboardSettings:
            data["locale"] = "en"
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
            data["min_zoom"] = minZoom
            data["max_zoom"] = maxZoom
            data["max_pokemon_id"] = maxPokemonId
            data["locale_new"] = Localizer.locale
            data["enable_register_new"] = enableRegister
            data["enable_clearing"] = WebHookRequestHandler.enableClearing
            data["webhook_urls"] = WebHookController.global.webhookURLStrings.joined(separator: ";")
            data["webhook_delay"] = WebHookController.global.webhookSendDelay
            data["pokemon_time_new"] = Pokemon.defaultTimeUnseen
            data["pokemon_time_old"] = Pokemon.defaultTimeReseen
            data["pokestop_lure_time"] = Pokestop.lureTime
            data["ex_raid_boss_id"] = Gym.exRaidBossId ?? 0
            data["ex_raid_boss_form"] = Gym.exRaidBossForm ?? 0
            data["google_analytics_id"] = WebReqeustHandler.googleAnalyticsId
            data["google_adsense_id"] = WebReqeustHandler.googleAdSenseId
            data["mailer_base_uri"] = MailController.baseURI
            data["mailer_name"] = MailController.fromName
            data["mailer_email"] = MailController.fromAddress
            data["mailer_url"] = MailController.clientURL
            data["mailer_username"] = MailController.clientUsername
            data["mailer_password"] = MailController.clientPassword
            data["mailer_footer_html"] = MailController.footerHtml
            data["discord_guild_ids"] = DiscordController.global.guilds.map({ (i) -> String in
                    return i.description
                }).joined(separator: ";")
            data["discord_token"] = DiscordController.global.token
            data["discord_redirect_url"] = WebReqeustHandler.oauthDiscordRedirectURL
            data["discord_client_id"] = WebReqeustHandler.oauthDiscordClientID
            data["discord_client_secret"] = WebReqeustHandler.oauthDiscordClientSecret
            data["stats_url"] = WebReqeustHandler.statsUrl
            data["deviceapi_host_whitelist"] = WebHookRequestHandler.hostWhitelist?.joined(separator: ";")
            data["deviceapi_host_whitelist_uses_proxy"] = WebHookRequestHandler.hostWhitelistUsesProxy
            data["deviceapi_secret"] = WebHookRequestHandler.loginSecret
            data["ditto_disguises"] = WebHookRequestHandler.dittoDisguises?
                                      .map({ $0.description }).joined(separator: ",")

            var tileserverString = ""

            let tileserversSorted = tileservers.sorted { (rhs, lhs) -> Bool in
                return rhs.key == "Default" || rhs.key < lhs.key
            }

            for tileserver in tileserversSorted {
                tileserverString += "\(tileserver.key);\(tileserver.value["url"] ?? "");" +
                                    "\(tileserver.value["attribution"] ?? "")\n"
            }
            data["tileservers"] = tileserverString
            data["buttons_left_formatted"] = buttonsLeft.map({ (button) -> String in
                return (button["name"] ?? "?") + ";" + (button["url"] ?? "?")
            }).joined(separator: "\n")
            data["buttons_right_formatted"] = buttonsRight.map({ (button) -> String in
                return (button["name"] ?? "?") + ";" + (button["url"] ?? "?")
            }).joined(separator: "\n")

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
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Devices"
        case .dashboardDeviceAssign:
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Assign Device"
            let deviceUUID = (request.urlVariables["device_uuid"] ?? "").decodeUrl()!

            data["device_uuid"] = deviceUUID
            if request.method == .post {
                do {
                    data = try assignDevicePost(data: data, request: request, response: response,
                                                deviceUUID: deviceUUID)
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
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Instances"
        case .dashboardInstanceAdd:
            data["locale"] = "en"
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
                data["iv_queue_limit"] = 100
                data["spin_limit"] = 1000
                data["delay_logout"] = 900
                data["radius"] = 10000
                data["store_data"] = false
                data["nothing_selected"] = true
                data["account_group"] = nil
                data["is_event"] = false
            }
        case .dashboardInstanceIVQueue:
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - IV Queue"
            let instanceName = request.urlVariables["instance_name"] ?? ""
            data["instance_name_url"] = instanceName
            data["instance_name"] = instanceName.decodeUrl() ?? ""
        case .dashboardDeviceGroups:
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Device Groups"
        case .dashboardDeviceGroupAdd:
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Add Device Group"
            if request.method == .post {
                do {
                    data = try addDeviceGroupPost(data: data, request: request, response: response)
                } catch {
                    return
                }
            } else {
                do {
                    data["nothing_selected"] = true
                    data = try addDeviceGroupGet(data: data, request: request, response: response)
                } catch {
                    return
                }
            }
        case .dashboardDeviceGroupEdit:
            data["locale"] = "en"
            let deviceGroupName = (request.urlVariables["name"] ?? "").decodeUrl()!
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Edit Device Group"
            data["old_name"] = deviceGroupName

            if request.param(name: "delete") == "true" {
                do {
                    try DeviceGroup.delete(name: deviceGroupName)
                    response.redirect(path: "/dashboard/devicegroups")
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
                    data = try editDeviceGroupPost(data: data, request: request, response: response,
                                                   deviceGroupName: deviceGroupName)
                } catch {
                    return
                }
            } else {
                do {
                    data = try editDeviceGroupGet(data: data, request: request, response: response,
                                                  deviceGroupName: deviceGroupName)
                } catch {
                    return
                }
            }
        case .dashboardDeviceGroupDelete:
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Delete Device Group"

            let nameT = request.urlVariables["name"]
            if let name = nameT {
                do {
                    try DeviceGroup.delete(name: name)
                } catch {
                    response.setBody(string: "Internal Server Error")
                    sessionDriver.save(session: request.session!)
                    response.completed(status: .internalServerError)
                    return
                }
                response.redirect(path: "/dashboard/devicegroups")
                sessionDriver.save(session: request.session!)
                response.completed(status: .seeOther)
            } else {
                response.setBody(string: "Bad Request")
                sessionDriver.save(session: request.session!)
                response.completed(status: .badRequest)
            }
        case .dashboardDeviceGroupAssign:
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Assign Device Group"
            let name = request.urlVariables["name"] ?? ""
            data["name"] = name

            if request.method == .post {
                do {
                    data = try assignDeviceGroupPost(data: data, request: request, response: response,
                                                name: name)
                } catch {
                    return
                }
            } else {
                do {
                    data = try assignDeviceGroupGet(data: data, request: request, response: response, name: name)
                } catch {
                    return
                }
            }
        case .dashboardAssignments:
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Assignments"
        case .dashboardAssignmentAdd:
            data["locale"] = "en"
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
        case .dashboardAssignmentEdit:
            data["locale"] = "en"
            let uuid = (request.urlVariables["uuid"] ?? "").decodeUrl()!
            let tmp = uuid.replacingOccurrences(of: "\\\\-", with: "&tmp")
            data["page_is_dashboard"] = true
            data["old_name"] = uuid
            data["page"] = "Dashboard - Edit Assignment"
            if request.method == .get {
                do {
                    data = try editAssignmentGet(data: data, request: request, response: response, instanceUUID: tmp)
                } catch {
                    return
                }
            } else {
                do {
                    data = try editAssignmentPost(data: data, request: request, response: response)
                } catch {
                    return
                }
            }
        case .dashboardAssignmentStart:
            data["locale"] = "en"
            let uuid = request.urlVariables["uuid"] ?? ""
            if let id = UInt32(uuid) {
                let assignmentT: Assignment?
                do {
                    assignmentT = try Assignment.getByUUID(id: id)
                } catch {
                    response.setBody(string: "Internal Server Error")
                    sessionDriver.save(session: request.session!)
                    response.completed(status: .internalServerError)
                    return
                }
                guard let assignment = assignmentT else {
                    response.setBody(string: "Assignment Not Found")
                    sessionDriver.save(session: request.session!)
                    response.completed(status: .notFound)
                    return
                }
                do {
                    try AssignmentController.global.triggerAssignment(assignment: assignment, force: true)
                } catch {
                    response.setBody(string: "Failed to trigger assignment")
                    sessionDriver.save(session: request.session!)
                    response.completed(status: .internalServerError)
                    return
                }
                response.redirect(path: "/dashboard/assignments")
                sessionDriver.save(session: request.session!)
                response.completed(status: .seeOther)
            } else {
                response.setBody(string: "Bad Request")
                sessionDriver.save(session: request.session!)
                response.completed(status: .badRequest)
            }
        case .dashboardAssignmentDelete:
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Delete Assignment"

            let uuid = request.urlVariables["uuid"] ?? ""
            if let id = UInt32(uuid) {
                do {
                    try Assignment.delete(id: id)
                } catch {
                    response.setBody(string: "Internal Server Error")
                    sessionDriver.save(session: request.session!)
                    response.completed(status: .internalServerError)
                    return
                }
                AssignmentController.global.deleteAssignment(id: id)
                response.redirect(path: "/dashboard/assignments")
                sessionDriver.save(session: request.session!)
                response.completed(status: .seeOther)
            } else {
                response.setBody(string: "Bad Request")
                sessionDriver.save(session: request.session!)
                response.completed(status: .badRequest)
            }
        case .dashboardAssignmentsDeleteAll:
            data["locale"] = "en"
            data["page_is_dashboard"] = true

            do {
                try Assignment.deleteAll()
            } catch {
                response.setBody(string: "Internal Server Error")
                sessionDriver.save(session: request.session!)
                response.completed(status: .internalServerError)
                return
            }
            response.redirect(path: "/dashboard/assignments")
            sessionDriver.save(session: request.session!)
            response.completed(status: .seeOther)
        case .dashboardAccounts:
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Accounts"
            data["new_accounts_count"] = (try? Account.getNewCount().withCommas()) ?? "?"
            data["in_use_accounts_count"] = (try? Account.getInUseCount().withCommas()) ?? "?"
            data["warned_accounts_count"] = (try? Account.getWarnedCount().withCommas()) ?? "?"
            data["failed_accounts_count"] = (try? Account.getFailedCount().withCommas()) ?? "?"
            data["cooldown_accounts_count"] = (try? Account.getCooldownCount().withCommas()) ?? "?"
            data["spin_limit_accounts_count"] = (try? Account.getSpinLimitCount().withCommas()) ?? "?"
            data["iv_accounts_count"] = (try? Account.getLevelCount(level: 30).withCommas()) ?? "?"
            data["stats"] = (try? Account.getStats()) ?? ""
            data["ban_stats"] = (try? Account.getWarningBannedStats()) ?? ""
        case .dashboardAccountsAdd:
            data["locale"] = "en"
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
            data["locale"] = "en"
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
            } else if request.param(name: "clear_quests") == "true" {
                do {
                    let instance = try Instance.getByName(name: instanceName)!
                    if instance.type == .autoQuest {
                        try Pokestop.clearQuests(instance: instance)
                    }
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
                    data = try addEditInstance(data: data, request: request, response: response,
                                               instanceName: instanceName)
                } catch {
                    return
                }
            } else {
                do {
                    data = try editInstanceGet(data: data, request: request, response: response,
                                               instanceName: instanceName)
                } catch {
                    return
                }
            }
        case .dashboardUsers:
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Users"
        case .dashboardUserEdit:
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Edit User"
            let editUsername = (request.urlVariables["username"] ?? "").decodeUrl()!
            data["edit_username"] = editUsername

            let userTmp: User?
            do {
                userTmp = try User.get(username: editUsername)
            } catch {
                userTmp = nil
            }

            guard
                let groups = try? Group.getAll(),
                let user = userTmp
            else {
                response.setBody(string: "Internal Server Error")
                sessionDriver.save(session: request.session!)
                response.completed(status: .internalServerError)
                return
            }
            if request.method == .post {
                let groupName = request.param(name: "group")

                var groupsData = [[String: Any]]()
                for group in groups where  group.name != "no_user" {
                    groupsData.append([
                        "name": group.name,
                        "selected": group.name == groupName ?? ""
                    ])
                }
                data["groups"] = groupsData

                if request.param(name: "delete")?.toBool() ?? false == true {
                    do {
                        try user.delete()
                        response.redirect(path: "/dashboard/users")
                        sessionDriver.save(session: request.session!)
                        response.completed(status: .seeOther)
                    } catch {
                        data["show_error"] = true
                        data["error"] = "Failed to delete user. Try again later."
                    }
                } else {
                    if groupName == nil || groupName! == "no_user" || !groups.map({ (group) -> String in
                        return group.name
                    }).contains(groupName!) {
                        data["show_error"] = true
                        data["error"] = "Failed to update user. Invalid group."
                    } else {
                        do {
                            try user.setGroup(groupName: groupName!)
                            response.redirect(path: "/dashboard/users")
                            sessionDriver.save(session: request.session!)
                            response.completed(status: .seeOther)
                        } catch {
                            data["show_error"] = true
                            data["error"] = "Failed to update user. Try again later."
                        }
                    }
                }
            } else {
                var groupsData = [[String: Any]]()
                for group in groups where group.name != "no_user" {
                    groupsData.append([
                        "name": group.name,
                        "selected": group.name == user.groupName
                    ])
                }
                data["groups"] = groupsData
            }
        case .dashboardGroups:
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Groups"
        case .dashboardGroupEdit:
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Edit Group"
            let groupName = (request.urlVariables["group_name"])?.decodeUrl() ?? ""
            data["name_old"] = groupName
            if groupName == "root" {
                response.redirect(path: "/dashboard/groups")
                sessionDriver.save(session: request.session!)
                response.completed(status: .found)
                return
            }
            let nameRequired: Bool
            if groupName != "no_user" && groupName != "default" && groupName != "default_verified" {
                nameRequired = true
            } else {
                nameRequired = false
            }
            data["show_edit_name"] = nameRequired
            data["show_delete"] = nameRequired

            if request.method == .post {
                do {
                    data = try addEditGroup(data: data, request: request, response: response, groupName: groupName,
                                            nameRequired: nameRequired)
                } catch {
                    return
                }
            } else {
                do {
                    data = try editGroupGet(data: data, request: request, response: response, groupName: groupName)
                } catch {
                    return
                }
            }
        case .dashboardGroupAdd:
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Add Group"
            if request.method == .post {
                do {
                    data = try addEditGroup(data: data, request: request, response: response, groupName: nil,
                                            nameRequired: true)
                } catch {
                    return
                }
            }
        case .dashboardDiscordRules:
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Discord Rules"
        case .dashboardDiscordRuleAdd:
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Add Discord Rule"

            guard let groups = try? Group.getAll() else {
                response.setBody(string: "Internal Server Error")
                sessionDriver.save(session: request.session!)
                response.completed(status: .internalServerError)
                return
            }

            var guilds = [[String: Any]]()
            for guild in DiscordController.global.getAllGuilds() {
                var guildJson = [String: Any]()
                guildJson["id"] = guild.key.description
                guildJson["name"] = guild.value.name

                var roles = [[String: Any]]()
                for role in guild.value.roles {
                    roles.append([
                        "id": role.key.description,
                        "name": role.value
                    ])
                }
                roles.sort { (lhs, rhs) -> Bool in
                    return rhs["name"] as? String ?? "" > lhs["name"] as? String ?? ""
                }
                guildJson["roles"] = roles
                guilds.append(guildJson)
            }
            guilds.sort { (lhs, rhs) -> Bool in
                return rhs["name"] as? String ?? "" > lhs["name"] as? String ?? ""
            }
            data["guilds"] = guilds.jsonEncodeForceTry()?.replacingOccurrences(of: "\\\"", with: "\\\\\"")
                            .replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\"", with: "\\\"")

            var groupsArray = [[String: Any]]()
            for group in groups {
                groupsArray.append(["name": group.name, "selected": group.name == "default"])
            }
            data["groups"] = groupsArray

            if request.method == .post {
                do {
                    data = try addEditDiscordRule(data: data, request: request, response: response, groups: groups)
                } catch {
                    return
                }
            }

        case .dashboardDiscordRuleEdit:
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Edit Discord Rule"

            let priority = (request.urlVariables["discordrule_priority"] ?? "").toInt32()
            data["priority_old"] = priority

            if request.param(name: "delete") == "true" {
                do {
                    try DiscordRule.delete(priority: priority ?? 0)
                    response.redirect(path: "/dashboard/discordrules")
                    sessionDriver.save(session: request.session!)
                    response.completed(status: .seeOther)
                    return
                } catch {
                    response.setBody(string: "Internal Server Error")
                    sessionDriver.save(session: request.session!)
                    response.completed(status: .internalServerError)
                    return
                }
            } else {

                let discordRule: DiscordRule
                let groups: [Group]
                do {
                    if let priority = priority,
                        let discordRule2 = try DiscordRule.get(priority: priority) {
                        discordRule = discordRule2
                    } else {
                        response.setBody(string: "DiscordRule Not Found")
                        sessionDriver.save(session: request.session!)
                        response.completed(status: .notFound)
                        return
                    }
                    groups = try Group.getAll()
                } catch {
                    response.setBody(string: "Internal Server Error")
                    sessionDriver.save(session: request.session!)
                    response.completed(status: .internalServerError)
                    return
                }

                var guilds = [[String: Any]]()
                for guild in DiscordController.global.getAllGuilds() {
                    var guildJson = [String: Any]()
                    guildJson["id"] = guild.key.description
                    guildJson["name"] = guild.value.name

                    var roles = [[String: Any]]()
                    for role in guild.value.roles {
                        roles.append([
                            "id": role.key.description,
                            "name": role.value
                            ])
                    }
                    roles.sort { (lhs, rhs) -> Bool in
                        return rhs["name"] as? String ?? "" > lhs["name"] as? String ?? ""
                    }
                    guildJson["roles"] = roles
                    guilds.append(guildJson)
                }
                guilds.sort { (lhs, rhs) -> Bool in
                    return rhs["name"] as? String ?? "" > lhs["name"] as? String ?? ""
                }
                data["guilds"] = guilds.jsonEncodeForceTry()?.replacingOccurrences(of: "\\\"", with: "\\\\\"")
                                .replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\"", with: "\\\"")

                if request.method == .get {

                    var groupsArray = [[String: Any]]()
                    for group in groups {
                        groupsArray.append(["name": group.name, "selected": group.name == discordRule.groupName])
                    }
                    data["groups"] = groupsArray

                    data["selected_guild"] = discordRule.serverId
                    data["selected_role"] = discordRule.roleId
                    data["priority"] = discordRule.priority
                } else {
                    do {
                        data = try addEditDiscordRule(data: data, request: request, response: response,
                                                      oldPriority: priority, discordRule: discordRule, groups: groups)
                    } catch {
                        return
                    }
                }
            }

        case .dashboardUtilities:
            data["locale"] = "en"
            data["page_is_dashboard"] = true
            data["page"] = "Dashboard - Utilities"

            let convertiblePokestopsCount = try? Pokestop.getConvertiblePokestopsCount()
            let stalePokestopsCount = try? Pokestop.getStalePokestopsCount()
            data["convertible_pokestops"] = convertiblePokestopsCount
            data["stale_pokestops"] = stalePokestopsCount
            data["show_clear_memcache"] = ProcessInfo.processInfo.environment["NO_MEMORY_CACHE"] == nil

            if request.method == .post {
                let action = request.param(name: "action")
                switch action {
                case "clear_quests":
                    do {
                        try Pokestop.clearQuests()
                        InstanceController.global.reloadAllInstances()
                        data["show_success"] = true
                        data["success"] = "Quests cleared!"
                    } catch {
                        data["show_error"] = true
                        data["error"] = "Failed to clear quests."
                    }
                case "clear_memcache":
                    Pokemon.cache?.clear()
                    Pokestop.cache?.clear()
                    Gym.cache?.clear()
                    SpawnPoint.cache?.clear()
                    Weather.cache?.clear()
                    data["show_success"] = true
                    data["success"] = "In-Memory Cache cleared!"
                case "truncate_pokemon":
                    do {
                        try Pokemon.truncate()
                        data["show_success"] = true
                        data["success"] = "Pokemon table truncated!"
                    } catch {
                        data["show_error"] = true
                        data["error"] = "Failed to truncate Pokemon table."
                    }
                case "convert_pokestops":
                    do {
                        let result = try Gym.convertPokestopsToGyms()
                        let deleteResult = try Pokestop.deleteConvertedPokestops()
                        data["show_success"] = true
                        data["success"] = "\(result) Pokestops converted to " +
                                          "gyms and \(deleteResult) Pokestops deleted!"
                    } catch {
                        data["show_error"] = true
                        data["error"] = "Failed to update converted pokestops to gyms."
                    }
                case "delete_stale_pokestops":
                    do {
                        let result = try Pokestop.deleteStalePokestops()
                        data["show_success"] = true
                        data["success"] = "\(result) Stale Pokestops deleted!"
                    } catch {
                        data["show_error"] = true
                        data["error"] = "Failed to delete stale Pokestops."
                    }
                default:
                    break
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
            data["page"] = localizer.get(value: "title_register")

            // Localize
            let homeLoc = ["register_username", "register_email", "register_password", "register_retype_password",
                           "register_register", "register_login_info"]
            for loc in homeLoc {
                data[loc] = localizer.get(value: loc)
            }
            data["register_title"] = localizer.get(value: "register_title", replace: ["name": title])

            if request.method == .post {
                do {
                    data = try register(data: data, request: request, response: response, useAccessToken: false)
                } catch {
                    return
                }
            }
        case .login:
            data["page_is_login"] = true
            data["page"] = localizer.get(value: "title_login")

            // Localize
            let homeLoc = ["login_username_email", "login_password", "login_login", "login_password_info",
                           "login_register_info", "login_discord"]
            for loc in homeLoc {
                data[loc] = localizer.get(value: loc)
            }
            data["login_title"] = localizer.get(value: "login_title", replace: ["name": title])
            data["redirect"] = request.param(name: "redirect") ?? "/"
            data["has_discord_oauth"] = WebReqeustHandler.oauthDiscordClientSecret != nil &&
                                        WebReqeustHandler.oauthDiscordRedirectURL != nil &&
                                        WebReqeustHandler.oauthDiscordClientID != nil
            let error = request.param(name: "error")
            if error != nil {
                if error == "discord_undefined" {
                    data["error"] = localizer.get(value: "login_discord_undefined")
                } else if error == "discord_not_linked" {
                    data["error"] = localizer.get(value: "login_discord_not_linked")
                }
            }

            if request.method == .post {
                do {
                    data = try login(data: data, request: request, response: response)
                } catch {
                    return
                }
            }
        case .oauthDiscord:
            do {
                data = try oauthDiscord(data: data, request: request, response: response)
            } catch {
                return
            }
        case .logout:
            data["page"] = localizer.get(value: "title_logout")
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
        case .profile:
            data["page_is_profile"] = true
            data["page"] = localizer.get(value: "title_profile")

            data["has_discord_oauth"] = WebReqeustHandler.oauthDiscordClientSecret != nil &&
                                        WebReqeustHandler.oauthDiscordRedirectURL != nil &&
                                        WebReqeustHandler.oauthDiscordClientID != nil

            if let success = request.param(name: "success") {
                if success == "discord_linked" {
                    data["success"] = localizer.get(value: "profile_discord_linked_success")
                }
            }

            // Localize
            let homeLoc = ["profile_username", "profile_email", "profile_password", "profile_retype_password",
                           "profile_update", "profile_update_heading", "profile_unverified_header",
                           "profile_unverified_text", "profile_update_password_heading",
                           "profile_old_password", "profile_password_info", "profile_discord_link",
                           "profile_discord_linked"]
            for loc in homeLoc {
                data[loc] = localizer.get(value: loc)
            }
            data["profile_title"] = localizer.get(value: "profile_title", replace: ["name": title])

            let user: User?
            do {
                user = try User.get(username: username ?? "")
            } catch {
                user = nil
            }
            if user == nil {
                response.setBody(string: "Internal Server Error")
                sessionDriver.save(session: request.session!)
                response.completed(status: .internalServerError)
                return
            }

            data["discord_oauth_set"] = user?.discordId != nil

            if MailController.global.isSetup {
                data["mail_verified"] = user!.emailVerified
            } else {
                data["mail_verified"] = false
            }
            data["username_new"] = user!.username
            data["email"] = user!.email

            if request.method == .post {
                do {
                    data = try updateProfile(data: data, request: request, response: response, user: user!)
                } catch {
                    return
                }
            }
        case .homeJs:
            data["start_lat"] = request.param(name: "lat")?.toDouble() ?? startLat
            data["start_lon"] = request.param(name: "lon")?.toDouble() ?? startLon
            data["start_zoom"] = request.param(name: "zoom")?.toUInt8() ?? startZoom
            data["min_zoom"] = request.param(name: "min_zoom")?.toUInt8() ?? minZoom
            data["max_zoom"] = request.param(name: "max_zoom")?.toUInt8() ?? maxZoom
            data["max_pokemon_id"] = maxPokemonId
            data["start_pokemon"] = request.param(name: "start_pokemon")
            data["start_pokestop"] = request.param(name: "start_pokestop")
            data["start_gym"] = request.param(name: "start_gym")
            data["perm_admin"] = perms.contains(.admin)
            data["avilable_forms_json"] = avilableFormsJson.replacingOccurrences(of: "\\\"", with: "\\\\\"")
                                          .replacingOccurrences(of: "'", with: "\\'")
                                          .replacingOccurrences(of: "\"", with: "\\\"")
            data["avilable_items_json"] = avilableItemJson.replacingOccurrences(of: "\\\"", with: "\\\\\"")
                                          .replacingOccurrences(of: "'", with: "\\'")
                                          .replacingOccurrences(of: "\"", with: "\\\"")
            data["avilable_tileservers_json"] = (tileservers.jsonEncodeForceTry() ?? "")
                                                .replacingOccurrences(of: "\\\"", with: "\\\\\"")
                                                .replacingOccurrences(of: "'", with: "\\'")
                                                .replacingOccurrences(of: "\"", with: "\\\"")
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
        let path = documentRoot + "/" + page.rawValue
        let context = MustacheEvaluationContext(templatePath: path, map: data)
        let contents: String
        do {
            contents = try context.formulateResponse(withCollector: .init())
        } catch {
            response.setBody(string: "Internal Server Error")
            response.completed(status: .internalServerError)
            return
        }
        response.setBody(string: contents)
        if page != .homeJs && page != .homeCss {
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

    static func register(data: MustacheEvaluationContext.MapType, request: HTTPRequest,
                         response: HTTPResponse, useAccessToken: Bool) throws -> MustacheEvaluationContext.MapType {

        var data = data

        let username = request.param(name: "username")
        let password = request.param(name: "password")
        let passwordRetype = request.param(name: "password-retype")
        let email = request.param(name: "email")
        let accessToken = request.param(name: "access-token")

        var noError = true

        let localizer = Localizer.global
        if password != passwordRetype {
            data["is_password_retype_error"] = true
            data["password_retype_error"] = localizer.get(value: "register_error_password_retype")
            data["is_password_error"] = true
            data["password_error"] = localizer.get(value: "register_error_password_retype")
            noError = false
        }
        if useAccessToken && accessToken != self.accessToken {
            data["is_access_token_error"] = true
            data["access_token_error"] = "Wrong access token."
            noError = false
        }
        if username == nil || username == "" {
            data["is_username_error"] = true
            data["username_error"] = localizer.get(value: "register_error_username_empty")
            noError = false
        }
        if email == nil || email == "" {
            data["is_email_error"] = true
            data["email_error"] = localizer.get(value: "register_error_email_empty")
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
                if error is DBController.DBError {
                    data["is_undefined_error"] = true
                    data["undefined_error"] = localizer.get(value: "register_error_undefined")
                } else if let registerError = error as? User.RegisterError {
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
                } else {
                    data["is_undefined_error"] = true
                    data["undefined_error"] = localizer.get(value: "register_error_undefined")
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

    static func login(data: MustacheEvaluationContext.MapType, request: HTTPRequest,
                      response: HTTPResponse) throws -> MustacheEvaluationContext.MapType {

        var data = data

        let usernameEmail = request.param(name: "username-email") ?? ""
        let password = request.param(name: "password") ?? ""

        var user: User?
        do {
            let host = request.host
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
            } else if let registerError = error as? User.LoginError {
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
            } else {
                data["is_error"] = true
                data["error"] = localizer.get(value: "login_error_limited")
            }
        }

        if user != nil {
            request.session?.userid = user!.username
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

    static func updateSettings(data: MustacheEvaluationContext.MapType, request: HTTPRequest,
                               response: HTTPResponse) throws -> MustacheEvaluationContext.MapType {

        var data = data
        guard
            let startLat = request.param(name: "start_lat")?.toDouble(),
            let startLon = request.param(name: "start_lon")?.toDouble(),
            let startZoom = request.param(name: "start_zoom")?.toInt(),
            let minZoom = request.param(name: "min_zoom")?.toInt(),
            let maxZoom = request.param(name: "max_zoom")?.toInt(),
            let title = request.param(name: "title"),
            let defaultTimeUnseen = request.param(name: "pokemon_time_new")?.toUInt32(),
            let defaultTimeReseen = request.param(name: "pokemon_time_old")?.toUInt32(),
            let maxPokemonId = request.param(name: "max_pokemon_id")?.toInt(),
            let locale = request.param(name: "locale_new")?.lowercased(),
            let tileserversString = request.param(name: "tileservers")?.replacingOccurrences(of: "<br>", with: "")
                                    .replacingOccurrences(of: "\r\n", with: "\n", options: .regularExpression),
            let exRaidBossId = request.param(name: "ex_raid_boss_id")?.toUInt16(),
            let exRaidBossForm = request.param(name: "ex_raid_boss_form")?.toUInt16(),
            let pokestopLureTime = request.param(name: "pokestop_lure_time")?.toUInt32(),
            let cities = request.param(name: "cities")?.replacingOccurrences(of: "<br>", with: "")
                         .replacingOccurrences(of: "\r\n", with: "\n", options: .regularExpression)
            else {
            data["show_error"] = true
            return data
        }

        let googleAnalyticsId = request.param(name: "google_analytics_id")
        let googleAdSenseId = request.param(name: "google_adsense_id")

        let webhookDelay = request.param(name: "webhook_delay")?.toDouble() ?? 5.0
        let webhookUrlsString = request.param(name: "webhook_urls") ?? ""
        let webhookUrls = webhookUrlsString.components(separatedBy: ";")
        let enableRegister = request.param(name: "enable_register_new") != nil
        let enableClearing = request.param(name: "enable_clearing") != nil

        let mailerBaseURI = request.param(name: "mailer_base_uri")
        let mailerName = request.param(name: "mailer_name")
        let mailerEmail = request.param(name: "mailer_email")
        let mailerURL = request.param(name: "mailer_url")
        let mailerUsername = request.param(name: "mailer_username")
        let mailerPassword = request.param(name: "mailer_password")
        let mailerFooterHTML = request.param(name: "mailer_footer_html")
        let discordGuilds = request.param(name: "discord_guild_ids")?
                            .components(separatedBy: ";").map({ (value) -> UInt64 in
            return value.toUInt64() ?? 0
        }) ?? [UInt64]()
        let discordToken = request.param(name: "discord_token")
        let oauthDiscordRedirectURL = request.param(name: "discord_redirect_url")
        let oauthDiscordClientID = request.param(name: "discord_client_id")
        let oauthDiscordClientSecret = request.param(name: "discord_client_secret")
        let statsUrl = request.param(name: "stats_url")
        let deviceAPIhostWhitelist = request.param(name: "deviceapi_host_whitelist")?
                                     .emptyToNil()?.components(separatedBy: ";")
        let deviceAPIhostWhitelistUsesProxy = request.param(name: "deviceapi_host_whitelist_uses_proxy") != nil
        let deviceAPIloginSecret = request.param(name: "deviceapi_secret")?.emptyToNil()
        let dittoDisguises = request.param(name: "ditto_disguises")?.components(separatedBy: ",")
            .map({ (value) -> UInt16 in
            return value.toUInt16() ?? 0
        }) ?? [UInt16]()

        let buttonsLeftString = request.param(name: "buttons_left_formatted")?
            .replacingOccurrences(of: "<br>", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let buttonsLeft: [[String: String]]
        if buttonsLeftString == nil || buttonsLeftString!.isEmpty {
            buttonsLeft = []
        } else {
            buttonsLeft = buttonsLeftString!
                .components(separatedBy: "\n")
                .map({ (string) -> [String: String] in
                    let components = string.components(separatedBy: ";")
                    return [
                        "name": components[0],
                        "url": components.last ?? "?"
                    ]
                })
        }

        let buttonsRightString = request.param(name: "buttons_right_formatted")?
            .replacingOccurrences(of: "<br>", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let buttonsRight: [[String: String]]
        if buttonsRightString == nil || buttonsRightString!.isEmpty {
            buttonsRight = []
        } else {
            buttonsRight = buttonsRightString!
                .components(separatedBy: "\n")
                .map({ (string) -> [String: String] in
                    let components = string.components(separatedBy: ";")
                    return [
                        "name": components[0],
                        "url": components.last ?? "?"
                    ]
                })
        }

        var tileservers = [String: [String: String]]()
        for tileserverString in tileserversString.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n") {
            let split = tileserverString.components(separatedBy: ";")
            if split.count == 3 {
                tileservers[split[0]] = ["url": split[1], "attribution": split[2]]
            } else {
                data["show_error"] = true
                return data
            }
        }

        var citySettings = [String: [String: Any]]()
        if cities != "" {
            for cityString in cities.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n") {
                let split = cityString.components(separatedBy: ";")
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
        }

        do {
            try DBController.global.setValueForKey(key: "MAP_START_LAT", value: startLat.description)
            try DBController.global.setValueForKey(key: "MAP_START_LON", value: startLon.description)
            try DBController.global.setValueForKey(key: "MAP_START_ZOOM", value: startZoom.description)
            try DBController.global.setValueForKey(key: "MAP_MIN_ZOOM", value: minZoom.description)
            try DBController.global.setValueForKey(key: "MAP_MAX_ZOOM", value: maxZoom.description)
            try DBController.global.setValueForKey(key: "TITLE", value: title)
            try DBController.global.setValueForKey(key: "WEBHOOK_DELAY", value: webhookDelay.description)
            try DBController.global.setValueForKey(key: "WEBHOOK_URLS", value: webhookUrlsString)
            try DBController.global.setValueForKey(key: "POKEMON_TIME_UNSEEN", value: defaultTimeUnseen.description)
            try DBController.global.setValueForKey(key: "POKEMON_TIME_RESEEN", value: defaultTimeReseen.description)
            try DBController.global.setValueForKey(key: "POKESTOP_LURE_TIME", value: pokestopLureTime.description)
            try DBController.global.setValueForKey(key: "GYM_EX_BOSS_ID", value: exRaidBossId.description)
            try DBController.global.setValueForKey(key: "GYM_EX_BOSS_FORM", value: exRaidBossForm.description)
            try DBController.global.setValueForKey(key: "MAP_MAX_POKEMON_ID", value: maxPokemonId.description)
            try DBController.global.setValueForKey(key: "LOCALE", value: locale)
            try DBController.global.setValueForKey(key: "ENABLE_REGISTER", value: enableRegister.description)
            try DBController.global.setValueForKey(key: "ENABLE_CLEARING", value: enableClearing.description)
            try DBController.global.setValueForKey(key: "TILESERVERS", value: tileservers.jsonEncodeForceTry() ?? "")
            try DBController.global.setValueForKey(key: "BUTTONS_LEFT", value: buttonsLeft.jsonEncodeForceTry() ?? "")
            try DBController.global.setValueForKey(key: "BUTTONS_RIGHT", value: buttonsRight.jsonEncodeForceTry() ?? "")
            try DBController.global.setValueForKey(key: "GOOGLE_ANALYTICS_ID", value: googleAnalyticsId ?? "")
            try DBController.global.setValueForKey(key: "GOOGLE_ADSENSE_ID", value: googleAdSenseId ?? "")
            try DBController.global.setValueForKey(key: "MAILER_URL", value: mailerURL ?? "")
            try DBController.global.setValueForKey(key: "MAILER_USERNAME", value: mailerUsername ?? "")
            try DBController.global.setValueForKey(key: "MAILER_PASSWORD", value: mailerPassword ?? "")
            try DBController.global.setValueForKey(key: "MAILER_EMAIL", value: mailerEmail ?? "")
            try DBController.global.setValueForKey(key: "MAILER_NAME", value: mailerName ?? "")
            try DBController.global.setValueForKey(key: "MAILER_FOOTER_HTML", value: mailerFooterHTML ?? "")
            try DBController.global.setValueForKey(key: "MAILER_BASE_URI", value: mailerBaseURI ?? "")
            try DBController.global.setValueForKey(key: "DISCORD_GUILD_IDS", value: discordGuilds.map({ (i) -> String in
                return i.description
            }).joined(separator: ";"))
            try DBController.global.setValueForKey(key: "DISCORD_TOKEN", value: discordToken ?? "")
            try DBController.global.setValueForKey(key: "DISCORD_REDIRECT_URL", value: oauthDiscordRedirectURL ?? "")
            try DBController.global.setValueForKey(key: "DISCORD_CLIENT_ID", value: oauthDiscordClientID ?? "")
            try DBController.global.setValueForKey(key: "DISCORD_CLIENT_SECRET", value: oauthDiscordClientSecret ?? "")
            try DBController.global.setValueForKey(key: "CITIES", value: citySettings.jsonEncodeForceTry() ?? "")
            try DBController.global.setValueForKey(key: "STATS_URL", value: statsUrl ?? "")
            try DBController.global.setValueForKey(key: "DEVICEAPI_HOST_WHITELIST",
                                                   value: deviceAPIhostWhitelist?.joined(separator: ";") ?? "")
            try DBController.global.setValueForKey(key: "DEVICEAPI_HOST_WHITELIST_USES_PROXY",
                                                   value: deviceAPIhostWhitelistUsesProxy.description)
            try DBController.global.setValueForKey(key: "DEVICEAPI_SECRET", value: deviceAPIloginSecret ?? "")
            try DBController.global.setValueForKey(key: "DITTO_DISGUISES", value: dittoDisguises.map({ (i) -> String in
                return i.description
            }).joined(separator: ","))
        } catch {
            data["show_error"] = true
            return data
        }

        WebReqeustHandler.startLat = startLat
        WebReqeustHandler.startLon = startLon
        WebReqeustHandler.startZoom = startZoom
        WebReqeustHandler.minZoom = minZoom
        WebReqeustHandler.maxZoom = maxZoom
        WebReqeustHandler.title = title
        WebReqeustHandler.maxPokemonId = maxPokemonId
        WebReqeustHandler.enableRegister = enableRegister
        WebReqeustHandler.tileservers = tileservers
        WebReqeustHandler.cities = citySettings
        WebReqeustHandler.googleAnalyticsId = googleAnalyticsId ?? ""
        WebReqeustHandler.googleAdSenseId = googleAdSenseId ?? ""
        WebReqeustHandler.buttonsRight = buttonsRight
        WebReqeustHandler.buttonsLeft = buttonsLeft
        WebHookController.global.webhookSendDelay = webhookDelay
        WebHookController.global.webhookURLStrings = webhookUrls
        WebHookRequestHandler.enableClearing = enableClearing
        Pokemon.defaultTimeUnseen = defaultTimeUnseen
        Pokemon.defaultTimeReseen = defaultTimeReseen
        Pokestop.lureTime = pokestopLureTime
        Gym.exRaidBossId = exRaidBossId
        Gym.exRaidBossForm = exRaidBossForm
        MailController.baseURI = mailerBaseURI ?? ""
        MailController.footerHtml = mailerFooterHTML ?? ""
        MailController.clientPassword = mailerPassword
        MailController.clientUsername = mailerUsername
        MailController.clientURL = mailerURL
        MailController.fromAddress = mailerEmail
        MailController.fromName = mailerName
        DiscordController.global.guilds = discordGuilds
        DiscordController.global.token = discordToken
        Localizer.locale = locale
        WebReqeustHandler.oauthDiscordClientSecret = oauthDiscordClientSecret
        WebReqeustHandler.oauthDiscordRedirectURL = oauthDiscordRedirectURL
        WebReqeustHandler.oauthDiscordClientID = oauthDiscordClientID
        WebReqeustHandler.statsUrl = statsUrl
        WebHookRequestHandler.hostWhitelist = deviceAPIhostWhitelist
        WebHookRequestHandler.hostWhitelistUsesProxy = deviceAPIhostWhitelistUsesProxy
        WebHookRequestHandler.loginSecret = deviceAPIloginSecret
        WebHookRequestHandler.dittoDisguises = dittoDisguises

        data["title"] = title
        data["show_success"] = true
        data["buttons_left"] = buttonsLeft
        data["buttons_right"] = buttonsRight

        return data
    }

    static func addEditInstance(data: MustacheEvaluationContext.MapType, request: HTTPRequest, response: HTTPResponse,
                                instanceName: String? = nil) throws -> MustacheEvaluationContext.MapType {

        var data = data
        guard
            let name = request.param(name: "name"),
            let area = request.param(name: "area")?.replacingOccurrences(of: "<br>", with: "")
                       .replacingOccurrences(of: "\r\n", with: "\n", options: .regularExpression),
            let minLevel = request.param(name: "min_level")?.toUInt8(),
            let maxLevel = request.param(name: "max_level")?.toUInt8()
        else {
            data["show_error"] = true
            data["error"] = "Invalid Request."
            return data
        }

        let timezoneOffset = Int(request.param(name: "timezone_offset") ?? "0" ) ?? 0
        let pokemonIDsText = request.param(name: "pokemon_ids")?.replacingOccurrences(of: "<br>", with: ",")
                             .replacingOccurrences(of: "\r\n", with: ",", options: .regularExpression)
        let scatterPokemonIDsText = request.param(name: "scatter_pokemon_ids")?
                                    .replacingOccurrences(of: "<br>", with: ",")
                                    .replacingOccurrences(of: "\r\n", with: ",", options: .regularExpression)

        var pokemonIDs = [UInt16]()
        if pokemonIDsText?.trimmingCharacters(in: .whitespacesAndNewlines) == "*" {
            pokemonIDs = Array(1...999)
        } else {
            let pokemonIDsSplit = pokemonIDsText?.components(separatedBy: ",")
            if pokemonIDsSplit != nil {
                for pokemonIDText in pokemonIDsSplit! {
                    let pokemonID = pokemonIDText.trimmingCharacters(in: .whitespaces).toUInt16()
                    if pokemonID != nil {
                        pokemonIDs.append(pokemonID!)
                    }
                }
            }
        }

        var scatterPokemonIDs = [UInt16]()
        if scatterPokemonIDsText?.trimmingCharacters(in: .whitespacesAndNewlines) == "*" {
            scatterPokemonIDs = Array(1...999)
        } else {
            let scatterPokemonIDsSplit = scatterPokemonIDsText?.components(separatedBy: ",")
            if scatterPokemonIDsSplit != nil {
                for pokemonIDText in scatterPokemonIDsSplit! {
                    let pokemonID = pokemonIDText.trimmingCharacters(in: .whitespaces).toUInt16()
                    if pokemonID != nil {
                        scatterPokemonIDs.append(pokemonID!)
                    }
                }
            }
        }

        let type = Instance.InstanceType.fromString(request.param(name: "type") ?? "")
        let ivQueueLimit = Int(request.param(name: "iv_queue_limit") ?? "" ) ?? 100
        let spinLimit = Int(request.param(name: "spin_limit") ?? "" ) ?? 1000
        let delayLogout = Int(request.param(name: "delay_logout") ?? "" ) ?? 900
        let radius = UInt64(request.param(name: "radius") ?? "" ) ?? 10000
        let storeData = request.param(name: "store_data") == "true"
        let accountGroup = request.param(name: "account_group")?.emptyToNil()
        let isEvent = request.param(name: "is_event") == "true"

        data["name"] = name
        data["area"] = area
        data["pokemon_ids"] = pokemonIDsText
        data["scatter_pokemon_ids"] = scatterPokemonIDs
        data["min_level"] = minLevel
        data["max_level"] = maxLevel
        data["timezone_offset"] = timezoneOffset
        data["iv_queue_limit"] = ivQueueLimit
        data["spin_limit"] = spinLimit
        data["delay_logout"] = delayLogout
        data["radius"] = radius
        data["store_data"] = storeData
        data["account_group"] = accountGroup
        data["is_event"] = isEvent

        if type == nil {
            data["nothing_selected"] = true
        } else {
            switch type! {
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
            case .leveling:
                data["leveling_selected"] = true
            }
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

        var newCoords: Any

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
        } else if type != nil && type! == .autoQuest || type! == .pokemonIV || type! == .leveling {
            var coordArray = [[Coord]]()
            let areaRows = area.components(separatedBy: "\n")
            var currentIndex = 0
            for areaRow in areaRows {
                let rowSplit = areaRow.components(separatedBy: ",")
                if rowSplit.count == 2 {
                    let lat = rowSplit[0].trimmingCharacters(in: .whitespaces).toDouble()
                    let lon = rowSplit[1].trimmingCharacters(in: .whitespaces).toDouble()
                    if lat != nil && lon != nil {
                        while coordArray.count != currentIndex + 1 {
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
                data["error"] = "Failed to parse coords (no coordinates in list)."
                return data
            }
            if type! == .leveling && (coordArray.count > 1 || coordArray[0].count > 1) {
                data["show_error"] = true
                data["error"] = "Failed to parse coords (only one coordinate (=start) needed for leveling instances)."
                return data
            }
            if type! == .leveling {
                newCoords = coordArray[0][0]
            } else {
                newCoords = coordArray
            }
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
                oldInstance!.data["account_group"] = accountGroup
                oldInstance!.data["is_event"] = isEvent

                if type == .pokemonIV {
                    oldInstance!.data["pokemon_ids"] = pokemonIDs
                    oldInstance!.data["iv_queue_limit"] = ivQueueLimit
                    oldInstance!.data["scatter_pokemon_ids"] = scatterPokemonIDs
                } else if type == .autoQuest {
                    oldInstance!.data["spin_limit"] = spinLimit
                    oldInstance!.data["delay_logout"] = delayLogout
                } else if type == .leveling {
                    oldInstance!.data["radius"] = radius
                    oldInstance!.data["store_data"] = storeData
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
            var instanceData: [String: Any] = [
                "area": newCoords,
                "timezone_offset": timezoneOffset,
                "min_level": minLevel,
                "max_level": maxLevel,
                "account_group": accountGroup as Any,
                "is_event": isEvent
            ]
            if type == .pokemonIV {
                instanceData["pokemon_ids"] = pokemonIDs
                instanceData["iv_queue_limit"] = ivQueueLimit
                instanceData["scatter_pokemon_ids"] = scatterPokemonIDs
                instanceData["scatter_pokemon_ids"] = scatterPokemonIDs
            } else if type == .autoQuest {
                instanceData["spin_limit"] = spinLimit
                instanceData["delay_logout"] = delayLogout
            } else if type == .leveling {
                instanceData["radius"] = radius
                instanceData["store_data"] = storeData
            }
            let instance = Instance(name: name, type: type!, data: instanceData, count: 0)
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

    static func editInstanceGet(data: MustacheEvaluationContext.MapType, request: HTTPRequest, response: HTTPResponse,
                                instanceName: String) throws -> MustacheEvaluationContext.MapType {

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
            let areaType3 = oldInstance!.data["area"] as? [String: Double]
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
            } else if areaType3 != nil {
                let lat = areaType3!["lat"]
                let lon = areaType3!["lon"]
                areaString += "\(lat!),\(lon!)\n"
            }

            data["name"] = oldInstance!.name
            data["area"] = areaString
            data["min_level"] = (oldInstance!.data["min_level"] as? Int)?.toInt8() ?? 0
            data["max_level"] = (oldInstance!.data["max_level"] as? Int)?.toInt8() ?? 29
            data["timezone_offset"] = oldInstance!.data["timezone_offset"] as? Int ?? 0
            data["iv_queue_limit"] = oldInstance!.data["iv_queue_limit"] as? Int ?? 100
            data["spin_limit"] = oldInstance!.data["spin_limit"] as? Int ?? 1000
            data["delay_logout"] = oldInstance!.data["delay_logout"] as? Int ?? 900
            data["radius"] = (oldInstance!.data["radius"] as? Int)?.toUInt64() ?? 100000
            data["store_data"] = oldInstance!.data["store_data"] as? Bool ?? false
            data["account_group"] = (oldInstance!.data["account_group"] as? String)?.emptyToNil()
            data["is_event"] = oldInstance!.data["is_event"] as? Bool ?? false

            let pokemonIDs = oldInstance!.data["pokemon_ids"] as? [Int]
            if pokemonIDs != nil {
                var text = ""
                for id in pokemonIDs! {
                    text.append("\(id)\n")
                }
                data["pokemon_ids"] = text
            }

            let scatterPokemonIDs = oldInstance!.data["scatter_pokemon_ids"] as? [Int]
            if scatterPokemonIDs != nil {
                var text = ""
                for id in scatterPokemonIDs! {
                    text.append("\(id)\n")
                }
                data["scatter_pokemon_ids"] = text
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
            case .leveling:
                data["leveling_selected"] = true
            }
            return data
        }
    }

    static func addDeviceGroupGet(data: MustacheEvaluationContext.MapType, request: HTTPRequest,
                                  response: HTTPResponse) throws -> MustacheEvaluationContext.MapType {

        var data = data
        let instances: [Instance]
        let devices: [Device]

        do {
            instances = try Instance.getAll(getData: false)
            devices = try Device.getAll()
        } catch {
            response.setBody(string: "Internal Server Errror")
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
            devicesData.append(["name": device.uuid, "selected": false])
        }
        data["devices"] = devicesData

        return data
    }

    static func addDeviceGroupPost(data: MustacheEvaluationContext.MapType, request: HTTPRequest,
                                   response: HTTPResponse) throws -> MustacheEvaluationContext.MapType {

        var data = data
        guard let groupName = request.param(name: "name") else {
            data["show_error"] = true
            data["error"] = "Invalid Request."
            return data
        }
        let deviceUUIDs = request.params(named: "devices")

        let deviceGroup = DeviceGroup(name: groupName, deviceUUIDs: deviceUUIDs)
        do {
            try deviceGroup.create()
        } catch {
            data["show_error"] = true
            data["error"] = "Failed to create device group. Does this device group already exist?"
            return data
        }

        response.redirect(path: "/dashboard/devicegroups")
        sessionDriver.save(session: request.session!)
        response.completed(status: .seeOther)
        throw CompletedEarly()

    }

    static func editDeviceGroupGet(data: MustacheEvaluationContext.MapType,
                                   request: HTTPRequest,
                                   response: HTTPResponse,
                                   deviceGroupName: String) throws -> MustacheEvaluationContext.MapType {

        var data = data

        let oldDeviceGroup: DeviceGroup?
        do {
            oldDeviceGroup = try DeviceGroup.getByName(name: deviceGroupName)
        } catch {
            response.setBody(string: "Internal Server Error")
            sessionDriver.save(session: request.session!)
            response.completed(status: .internalServerError)
            throw CompletedEarly()
        }
        if oldDeviceGroup == nil {
            response.setBody(string: "Device Group Not Found")
            sessionDriver.save(session: request.session!)
            response.completed(status: .notFound)
            throw CompletedEarly()
        } else {
            data["old_name"] = oldDeviceGroup!.name
            data["name"] = oldDeviceGroup!.name

            let devices: [Device]

            do {
                devices = try Device.getAll()
            } catch {
                response.setBody(string: "Internal Server Errror")
                sessionDriver.save(session: request.session!)
                response.completed(status: .internalServerError)
                throw CompletedEarly()
            }

            var devicesData = [[String: Any]]()
            for device in devices {
                devicesData.append(["name": device.uuid, "selected": oldDeviceGroup!.deviceUUIDs.contains(device.uuid)])
            }
            data["devices"] = devicesData

            return data
        }
    }

    static func editDeviceGroupPost(data: MustacheEvaluationContext.MapType,
                                    request: HTTPRequest,
                                    response: HTTPResponse,
                                    deviceGroupName: String? = nil) throws -> MustacheEvaluationContext.MapType {

        var data = data
        guard
            let name = request.param(name: "name")
            else {
                data["show_error"] = true
                data["error"] = "Invalid Request."
                return data
        }

        let deviceUUIDs = request.params(named: "devices")

        data["name"] = name
        if deviceGroupName != nil {
            let oldDeviceGroup: DeviceGroup?
            do {
                oldDeviceGroup = try DeviceGroup.getByName(name: deviceGroupName!)
            } catch {
                data["show_error"] = true
                data["error"] = "Failed to update device group. Is the name unique?"
                return data
            }
            if oldDeviceGroup == nil {
                response.setBody(string: "Device Group Not Found")
                sessionDriver.save(session: request.session!)
                response.completed(status: .notFound)
                throw CompletedEarly()
            } else {
                oldDeviceGroup!.name = name
                oldDeviceGroup!.deviceUUIDs = deviceUUIDs

                do {
                    try oldDeviceGroup!.update(oldName: deviceGroupName!)
                } catch {
                    data["show_error"] = true
                    data["error"] = "Failed to update device group. Is the name unique?"
                    return data
                }
                response.redirect(path: "/dashboard/devicegroups")
                sessionDriver.save(session: request.session!)
                response.completed(status: .seeOther)
                throw CompletedEarly()
            }
        } else {
            let deviceGroup = DeviceGroup(name: name, deviceUUIDs: deviceUUIDs)
            do {
                try deviceGroup.create()
            } catch {
                data["show_error"] = true
                data["error"] = "Failed to create device group. Is the name unique?"
                return data
            }
        }

        response.redirect(path: "/dashboard/devicegroups")
        sessionDriver.save(session: request.session!)
        response.completed(status: .seeOther)
        throw CompletedEarly()
    }

    static func assignDevicePost(data: MustacheEvaluationContext.MapType, request: HTTPRequest, response: HTTPResponse,
                                 deviceUUID: String) throws -> MustacheEvaluationContext.MapType {

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
            instances = try Instance.getAll(getData: false)
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

    static func assignDeviceGet(data: MustacheEvaluationContext.MapType, request: HTTPRequest, response: HTTPResponse,
                                deviceUUID: String) throws -> MustacheEvaluationContext.MapType {

        var data = data
        let instances: [Instance]
        let device: Device?
        do {
            device = try Device.getById(id: deviceUUID)
            instances = try Instance.getAll(getData: false)
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

    static func editAssignmentsGet(data: MustacheEvaluationContext.MapType, request: HTTPRequest,
                                   response: HTTPResponse) throws -> MustacheEvaluationContext.MapType {

        var data = data
        let instances: [Instance]
        let devices: [Device]
        let groups: [DeviceGroup]
        do {
            devices = try Device.getAll()
            groups = try DeviceGroup.getAll()
            instances = try Instance.getAll(getData: false)
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
        var groupsData = [[String: Any]]()
        for group in groups {
            groupsData.append(["uuid": group.name, "selected": false])
        }
        data["groups"] = groupsData
        return data

    }

    static func editAssignmentsPost(data: MustacheEvaluationContext.MapType, request: HTTPRequest,
                                    response: HTTPResponse) throws -> MustacheEvaluationContext.MapType {

        let selectedDeviceOrGroup = request.param(name: "device")
        let selectedDevice: String?
        if selectedDeviceOrGroup != nil && selectedDeviceOrGroup!.starts(with: "device:") {
            selectedDevice = String(selectedDeviceOrGroup!.dropFirst(7))
        } else {
            selectedDevice = nil
        }
        let selectedGroup: String?
        if selectedDeviceOrGroup != nil && selectedDeviceOrGroup!.starts(with: "group:") {
            selectedGroup = String(selectedDeviceOrGroup!.dropFirst(6))
        } else {
            selectedGroup = nil
        }

        let selectedInstance = request.param(name: "instance")
        let selectedSourceInstance = request.param(name: "source_instance")?.emptyToNil()
        let time = request.param(name: "time")
        let date = request.param(name: "date")
        let onComplete = request.param(name: "oncomplete")
        let enabled = request.param(name: "enabled")

        var data = data
        let instances: [Instance]
        let devices: [Device]
        let groups: [DeviceGroup]
        do {
            devices = try Device.getAll()
            groups = try DeviceGroup.getAll()
            instances = try Instance.getAll(getData: false)
        } catch {
            response.setBody(string: "Internal Server Error")
            sessionDriver.save(session: request.session!)
            response.completed(status: .internalServerError)
            throw CompletedEarly()
        }

        var instancesData = [[String: Any]]()
        for instance in instances {
            instancesData.append([
                "name": instance.name,
                "selected": instance.name == selectedInstance,
                "selected_source": instance.name == selectedSourceInstance
            ])        }
        data["instances"] = instancesData
        var devicesData = [[String: Any]]()
        for device in devices {
            devicesData.append(["uuid": device.uuid, "selected": device.uuid == selectedDeviceOrGroup])
        }
        data["devices"] = devicesData
        var groupsData = [[String: Any]]()
        for group in groups {
            groupsData.append(["uuid": group.name, "selected": false])
        }
        data["groups"] = groupsData
        data["time"] = time
        data["date"] = date

        let timeInt: UInt32
        if time == nil || time == "" {
            timeInt = 0
        } else {
            var split = time!.components(separatedBy: ":")
            if split.count == 2 {
                split.append("00")
            }
            if split.count == 3, let hours = split[0].toInt(), let minutes = split[1].toInt(),
               let seconds = split[2].toInt() {
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
        let realDate: Date?
        if date != nil, let realDateT = date!.toDate() {
            realDate = realDateT
        } else if date == nil || date?.trimmingCharacters(in: .whitespacesAndNewlines) == "" {
            realDate = nil
        } else {
            data["show_error"] = true
            data["error"] = "Invalid Date."
            return data
        }

        if ((selectedDevice == nil || selectedDevice == "") && (selectedGroup == nil || selectedGroup == "")) ||
            selectedInstance == nil || selectedInstance == "" {
            data["show_error"] = true
            data["error"] = "Invalid Request."
            return data
        }
        do {
            let assignmentEnabled = enabled == "on"
            let assignment = Assignment(
                id: nil,
                instanceName: selectedInstance!,
                sourceInstanceName: selectedSourceInstance,
                deviceUUID: selectedDevice,
                deviceGroupName: selectedGroup,
                time: timeInt,
                date: realDate,
                enabled: assignmentEnabled
            )
            try assignment.create()
            AssignmentController.global.addAssignment(assignment: assignment)
        } catch {
            data["show_error"] = true
            data["error"] = "Failed to assign Device."
            return data
        }

        if onComplete == "on" && timeInt != 0 {
            do {
                let onCompleteAssignment = Assignment(
                    id: nil,
                    instanceName: selectedInstance!,
                    sourceInstanceName: selectedSourceInstance,
                    deviceUUID: selectedDevice,
                    deviceGroupName: selectedGroup,
                    time: 0,
                    date: date?.toDate(),
                    enabled: true
                )
                try onCompleteAssignment.create()
                AssignmentController.global.addAssignment(assignment: onCompleteAssignment)
            } catch {
                data["show_error"] = true
                data["error"] = "Failed to assign Device."
                return data
            }
        }

        response.redirect(path: "/dashboard/assignments")
        sessionDriver.save(session: request.session!)
        response.completed(status: .seeOther)
        throw CompletedEarly()

    }

    static func editAssignmentGet(data: MustacheEvaluationContext.MapType,
                                  request: HTTPRequest,
                                  response: HTTPResponse,
                                  instanceUUID: String) throws -> MustacheEvaluationContext.MapType {

        let selectedUUID = (request.urlVariables["uuid"] ?? "").decodeUrl()!
        if let id = UInt32(selectedUUID) {
            var data = data
            let instances: [Instance]
            let devices: [Device]
            let groups: [DeviceGroup]
            let assignmentT: Assignment?
            do {
                devices = try Device.getAll()
                groups = try DeviceGroup.getAll()
                instances = try Instance.getAll(getData: false)
                assignmentT = try Assignment.getByUUID(id: id)
            } catch {
                response.setBody(string: "Internal Server Error")
                sessionDriver.save(session: request.session!)
                response.completed(status: .internalServerError)
                throw CompletedEarly()
            }

            guard let assignment = assignmentT else {
                response.setBody(string: "Assignment not found")
                sessionDriver.save(session: request.session!)
                response.completed(status: .notFound)
                throw CompletedEarly()
            }

            var instancesData = [[String: Any]]()
            for instance in instances {
                instancesData.append([
                    "name": instance.name,
                    "selected": instance.name == assignment.instanceName,
                    "selected_source": instance.name == assignment.sourceInstanceName
                ])
            }
            data["instances"] = instancesData
            var devicesData = [[String: Any]]()
            for device in devices {
                devicesData.append(["uuid": device.uuid, "selected": device.uuid == assignment.deviceUUID])
            }
            data["devices"] = devicesData
            var groupsData = [[String: Any]]()
            for group in groups {
                groupsData.append(["uuid": group.name, "selected": group.name == assignment.deviceGroupName])
            }
            data["groups"] = groupsData

            let formattedTime: String
            if assignment.time == 0 {
                formattedTime = ""
            } else {
                let times = assignment.time.secondsToHoursMinutesSeconds()
                formattedTime = "\(String(format: "%02d", times.hours)):\(String(format: "%02d", times.minutes))" +
                                ":\(String(format: "%02d", times.seconds))"
            }
            data["time"] = formattedTime
            data["date"] = assignment.date?.toString()
            data["enabled"] = assignment.enabled ? "checked" : ""

            return data
        } else {
            response.setBody(string: "Bad Request")
            sessionDriver.save(session: request.session!)
            response.completed(status: .badRequest)
        }

        throw CompletedEarly()
    }

    static func editAssignmentPost(data: MustacheEvaluationContext.MapType, request: HTTPRequest,
                                   response: HTTPResponse) throws -> MustacheEvaluationContext.MapType {
        let selectedDeviceOrGroup = request.param(name: "device")
        let selectedDevice: String?
        if selectedDeviceOrGroup != nil && selectedDeviceOrGroup!.starts(with: "device:") {
            selectedDevice = String(selectedDeviceOrGroup!.dropFirst(7))
        } else {
            selectedDevice = nil
        }
        let selectedGroup: String?
        if selectedDeviceOrGroup != nil && selectedDeviceOrGroup!.starts(with: "group:") {
            selectedGroup = String(selectedDeviceOrGroup!.dropFirst(6))
        } else {
            selectedGroup = nil
        }

        let selectedInstance = request.param(name: "instance")
        let selectedSourceInstance = request.param(name: "source_instance")?.emptyToNil()
        let time = request.param(name: "time")
        let date = request.param(name: "date")
        let enabled = request.param(name: "enabled")

        var data = data

        let timeInt: UInt32
        if time == nil || time == "" {
            timeInt = 0
        } else {
            var split = time!.components(separatedBy: ":")
            if split.count == 2 {
                split.append("00")
            }
            if split.count == 3, let hours = split[0].toInt(), let minutes = split[1].toInt(),
               let seconds = split[2].toInt() {
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

        if ((selectedDevice == nil || selectedDevice == "") && (selectedGroup == nil || selectedGroup == "")) ||
            selectedInstance == nil {
            data["show_error"] = true
            data["error"] = "Invalid Request."
            return data
        }

        let selectedUUID = data["old_name"] as? String ?? ""
        if let id = UInt32(selectedUUID) {
            let oldAssignmentT: Assignment?
            do {
                oldAssignmentT = try Assignment.getByUUID(id: id)
            } catch {
                response.setBody(string: "Internal Server Error")
                sessionDriver.save(session: request.session!)
                response.completed(status: .internalServerError)
                throw CompletedEarly()
            }
            guard let oldAssignment = oldAssignmentT else {
                response.setBody(string: "Assignment not found")
                sessionDriver.save(session: request.session!)
                response.completed(status: .notFound)
                throw CompletedEarly()
            }

            do {
                let assignmentEnabled = enabled == "on"
                let newAssignment = Assignment(
                    id: id,
                    instanceName: selectedInstance!,
                    sourceInstanceName: selectedSourceInstance,
                    deviceUUID: selectedDevice,
                    deviceGroupName: selectedGroup,
                    time: timeInt,
                    date: date?.toDate(),
                    enabled: assignmentEnabled
                )
                try newAssignment.save(oldId: id)
                AssignmentController.global.editAssignment(oldAssignment: oldAssignment, newAssignment: newAssignment)
            } catch {
                data["show_error"] = true
                data["error"] = "Failed to assign Device."
                return data
            }
        } else {
            response.setBody(string: "Bad Request")
            sessionDriver.save(session: request.session!)
            response.completed(status: .badRequest)
        }

        response.redirect(path: "/dashboard/assignments")
        sessionDriver.save(session: request.session!)
        response.completed(status: .seeOther)
        throw CompletedEarly()
    }

    static func addAccounts(data: MustacheEvaluationContext.MapType, request: HTTPRequest,
                            response: HTTPResponse) throws -> MustacheEvaluationContext.MapType {

        var data = data

        guard
            let level = request.param(name: "level")?.toUInt8(),
            let accounts = request.param(name: "accounts")?.replacingOccurrences(of: "<br>", with: "")
                           .replacingOccurrences(of: "\r\n", with: "\n", options: .regularExpression)
                           .replacingOccurrences(of: ";", with: ",").replacingOccurrences(of: ":", with: ",")
            else {
                data["show_error"] = true
                data["error"] = "Invalid Request."
                return data
        }
        let group = request.param(name: "group")?.trimmingCharacters(in: .whitespacesAndNewlines)

        data["accounts"] = accounts
        data["level"] = level
        data["group"] = group

        var accs = [Account]()
        let accountsRows = accounts.components(separatedBy: "\n")
        for accountsRow in accountsRows {
            let rowSplit = accountsRow.components(separatedBy: ",")
            if rowSplit.count == 2 {
                let username = rowSplit[0].trimmingCharacters(in: .whitespaces)
                let password = rowSplit[1].trimmingCharacters(in: .whitespaces)
                accs.append(Account(username: username, password: password, level: level, firstWarningTimestamp: nil,
                                    failedTimestamp: nil, failed: nil, lastEncounterLat: nil, lastEncounterLon: nil,
                                    lastEncounterTime: nil, spins: 0, creationTimestamp: nil, warn: nil,
                                    warnExpireTimestamp: nil, warnMessageAcknowledged: nil,
                                    suspendedMessageAcknowledged: nil, wasSuspended: nil, banned: nil,
                                    lastUsedTimestamp: nil, group: group))
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

    static func updateProfile(data: MustacheEvaluationContext.MapType, request: HTTPRequest,
                              response: HTTPResponse, user: User) throws -> MustacheEvaluationContext.MapType {

        var data = data

        let section = request.param(name: "section")

        let localizer = Localizer.global

        if section == "profile" {

            let username = request.param(name: "username")
            let email = request.param(name: "email")

            data["username_new"] = username
            data["email"] = email

            if username == nil || email == nil {
                data["is_undefined_error_profile"] = true
                data["undefined_error_profile"] = localizer.get(value: "register_error_undefined")
            } else {
                if username != user.username {
                    do {
                        try user.setUsername(username: username!)
                        request.session!.userid = username!
                        data["username"] = username
                        sessionDriver.save(session: request.session!)
                        data["success"] = localizer.get(value: "profile_update_profile_success")
                    } catch {
                        let isUndefined: Bool
                        if let registerError = error as? User.RegisterError {
                            if registerError.type == .usernameInvalid {
                                data["is_username_error"] = true
                                data["username_error"] = localizer.get(value: "register_error_username_invalid")
                                isUndefined = false
                            } else if registerError.type == .usernameTaken {
                                data["is_username_error"] = true
                                data["username_error"] = localizer.get(value: "register_error_username_taken")
                                isUndefined = false
                            } else {
                                isUndefined = true
                            }
                        } else {
                            isUndefined = true
                        }

                        if isUndefined {
                            data["is_undefined_error"] = true
                            data["undefined_error"] = localizer.get(value: "register_error_undefined")
                        }
                    }
                }

                if email != user.email {
                    do {
                        try user.setEmail(email: email!)
                        data["mail_verified"] = false
                        data["success"] = localizer.get(value: "profile_update_profile_success")
                    } catch {
                        let isUndefined: Bool
                        if let registerError = error as? User.RegisterError {
                            if registerError.type == .emailInvalid {
                                data["is_email_error"] = true
                                data["email_error"] = localizer.get(value: "register_error_email_invalid")
                                isUndefined = false
                            } else if registerError.type == .emailTaken {
                                data["is_email_error"] = true
                                data["email_error"] = localizer.get(value: "register_error_email_taken")
                                isUndefined = false
                            } else {
                                isUndefined = true
                            }
                        } else {
                            isUndefined = true
                        }

                        if isUndefined {
                            data["is_undefined_error"] = true
                            data["undefined_error"] = localizer.get(value: "register_error_undefined")
                        }
                    }
                }
            }
        }

        if section == "password" {

            let oldPassword = request.param(name: "old_password")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let password = request.param(name: "password")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let passwordRetype = request.param(name: "password-retype")?
                                 .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            data["old_password"] = oldPassword
            data["password"] = password
            data["password-retype"] = passwordRetype

            if password == "" {
                data["is_undefined_error_profile"] = true
                data["undefined_error_profile"] = localizer.get(value: "register_error_undefined")
            } else {
                if password != passwordRetype {
                    data["is_password_retype_error"] = true
                    data["password_retype_error"] = localizer.get(value: "register_error_password_retype")
                    data["is_password_error"] = true
                    data["password_error"] =  localizer.get(value: "register_error_password_retype")
                } else {
                    do {
                        if try user.verifyPassword(password: oldPassword) {
                            try user.setPassword(password: password)
                            data["success"] = localizer.get(value: "profile_update_password_success")
                        } else {
                            data["is_password_retype_error"] = true
                            data["password_retype_error"] = localizer.get(value: "register_error_password_retype")
                        }
                    } catch {
                        let isUndefined: Bool
                        if let registerError = error as? User.RegisterError {
                            if registerError.type == .passwordInvalid {
                                data["is_password_error"] = true
                                data["password_error"] = localizer.get(value: "register_error_password_invalid")
                                isUndefined = false
                            } else {
                                isUndefined = true
                            }
                        } else {
                            isUndefined = true
                        }

                        if isUndefined {
                            data["is_undefined_error"] = true
                            data["undefined_error"] = localizer.get(value: "register_error_undefined")
                        }
                    }
                }
            }
        }

        return data
    }

    static func addEditGroup(data: MustacheEvaluationContext.MapType, request: HTTPRequest, response: HTTPResponse,
                             groupName: String? = nil, nameRequired: Bool) throws -> MustacheEvaluationContext.MapType {

        var data = data

        let delete = request.param(name: "delete") == "true"

        let name = request.param(name: "name") ?? ""
        if !delete && name == "" && nameRequired {
            data["show_error"] = true
            data["error"] = "Invalid Request."
            return data
        }

        let permAdmin = request.param(name: "perm_admin") != nil
        let permViewMap = request.param(name: "perm_view_map") != nil
        let permViewMapGym = request.param(name: "perm_view_map_gym") != nil
        let permViewMapRaid = request.param(name: "perm_view_map_raid") != nil
        let permViewMapPokestop = request.param(name: "perm_view_map_pokestop") != nil
        let permViewMapQuest = request.param(name: "perm_view_map_quest") != nil
        let permViewMapLure = request.param(name: "perm_view_map_lure") != nil
        let permViewMapInvasion = request.param(name: "perm_view_map_invasion") != nil
        let permViewMapPokemon = request.param(name: "perm_view_map_pokemon") != nil
        let permViewMapEventPokemon = request.param(name: "perm_view_map_event_pokemon") != nil
        let permViewMapIV = request.param(name: "perm_view_map_iv") != nil
        let permViewMapSpawnpoint = request.param(name: "perm_view_map_spawnpoint") != nil
        let permViewMapCell = request.param(name: "perm_view_map_cell") != nil
        let permViewMapWeather = request.param(name: "perm_view_map_weather") != nil
        let permViewMapDevice = request.param(name: "perm_view_map_device") != nil
        let permViewStats = request.param(name: "perm_view_stats") != nil
        let permViewMapSubmissionCells = request.param(name: "perm_view_map_submission_cell") != nil

        data["name"] = name
        data["perm_admin"] = permAdmin
        data["perm_view_map"] = permViewMap
        data["perm_view_map_gym"] = permViewMapGym
        data["perm_view_map_raid"] = permViewMapRaid
        data["perm_view_map_pokestop"] = permViewMapPokestop
        data["perm_view_map_quest"] = permViewMapQuest
        data["perm_view_map_lure"] = permViewMapLure
        data["perm_view_map_invasion"] = permViewMapInvasion
        data["perm_view_map_event_pokemon"] = permViewMapEventPokemon
        data["perm_view_map_pokemon"] = permViewMapPokemon
        data["perm_view_map_iv"] = permViewMapIV
        data["perm_view_map_spawnpoint"] = permViewMapSpawnpoint
        data["perm_view_map_cell"] = permViewMapCell
        data["perm_view_map_weather"] = permViewMapWeather
        data["perm_view_map_device"] = permViewMapDevice
        data["perm_view_map_submission_cell"] = permViewMapSubmissionCells
        data["perm_view_stats"] = permViewStats

        var perms = [Group.Perm]()
        if permViewMap {
            perms.append(.viewMap)
        }
        if permViewMapRaid {
            perms.append(.viewMapRaid)
        }
        if permViewMapPokemon {
            perms.append(.viewMapPokemon)
        }
        if permViewStats {
            perms.append(.viewStats)
        }
        if permAdmin {
            perms.append(.admin)
        }
        if permViewMapGym {
            perms.append(.viewMapGym)
        }
        if permViewMapPokestop {
            perms.append(.viewMapPokestop)
        }
        if permViewMapSpawnpoint {
            perms.append(.viewMapSpawnpoint)
        }
        if permViewMapQuest {
            perms.append(.viewMapQuest)
        }
        if permViewMapLure {
            perms.append(.viewMapLure)
        }
        if permViewMapInvasion {
            perms.append(.viewMapInvasion)
        }
        if permViewMapIV {
            perms.append(.viewMapIV)
        }
        if permViewMapCell {
            perms.append(.viewMapCell)
        }
        if permViewMapWeather {
            perms.append(.viewMapWeather)
        }
        if permViewMapDevice {
            perms.append(.viewMapDevice)
        }
        if permViewMapSubmissionCells {
            perms.append(.viewMapSubmissionCells)
        }

        if groupName == nil { // New Group
            let group = Group(name: name, perms: perms)
            do {
                try group.save(update: false)
            } catch {
                data["show_error"] = true
                data["error"] = "Failed to create group. Try again later."
                return data
            }
        } else { // Update Group
            do {
                guard var group = try Group.getWithName(name: groupName!) else {
                    response.setBody(string: "Group Not Found")
                    sessionDriver.save(session: request.session!)
                    response.completed(status: .notFound)
                    throw CompletedEarly()
                }

                if delete {
                    try group.delete()
                } else {
                    if name != "" {
                        group.name = name
                        try group.rename(oldName: groupName!)
                    }
                    group.perms = perms
                    try group.save()
                }
            } catch {
                data["show_error"] = true
                data["error"] = "Failed to update group. Try again later."
                return data
            }
        }

        response.redirect(path: "/dashboard/groups")
        sessionDriver.save(session: request.session!)
        response.completed(status: .seeOther)
        throw CompletedEarly()
    }

    static func editGroupGet(data: MustacheEvaluationContext.MapType, request: HTTPRequest, response: HTTPResponse,
                             groupName: String) throws -> MustacheEvaluationContext.MapType {

        var data = data

        guard let group = try Group.getWithName(name: groupName) else {
            response.setBody(string: "Group Not Found")
            sessionDriver.save(session: request.session!)
            response.completed(status: .notFound)
            throw CompletedEarly()
        }

        let perms = group.perms

        data["name"] = group.name
        data["perm_admin"] = perms.contains(.admin)
        data["perm_view_map"] = perms.contains(.viewMap)
        data["perm_view_map_gym"] = perms.contains(.viewMapGym)
        data["perm_view_map_raid"] = perms.contains(.viewMapRaid)
        data["perm_view_map_pokestop"] = perms.contains(.viewMapPokestop)
        data["perm_view_map_quest"] = perms.contains(.viewMapQuest)
        data["perm_view_map_lure"] = perms.contains(.viewMapLure)
        data["perm_view_map_invasion"] = perms.contains(.viewMapInvasion)
        data["perm_view_map_pokemon"] = perms.contains(.viewMapPokemon)
        data["perm_view_map_event_pokemon"] = perms.contains(.viewMapEventPokemon)
        data["perm_view_map_iv"] = perms.contains(.viewMapIV)
        data["perm_view_map_spawnpoint"] = perms.contains(.viewMapSpawnpoint)
        data["perm_view_map_cell"] = perms.contains(.viewMapCell)
        data["perm_view_map_weather"] = perms.contains(.viewMapWeather)
        data["perm_view_map_device"] = perms.contains(.viewMapDevice)
        data["perm_view_map_submission_cell"] = perms.contains(.viewMapSubmissionCells)
        data["perm_view_stats"] = perms.contains(.viewStats)

        return data
    }

    static func addEditDiscordRule(data: MustacheEvaluationContext.MapType, request: HTTPRequest,
                                   response: HTTPResponse, oldPriority: Int32?=nil, discordRule: DiscordRule?=nil,
                                   groups: [Group]) throws -> MustacheEvaluationContext.MapType {

        var data = data
        guard
            let priority = request.param(name: "priority")?.toInt32(),
            let guild = request.param(name: "guild")?.toUInt64(),
            let role = request.param(name: "role")?.toUInt64(),
            let group = request.param(name: "group")
            else {
                data["show_error"] = true
                data["error"] = "Invalid Request."
                return data
        }

        var groupsArray = [[String: Any]]()
        for group2 in groups {
            groupsArray.append(["name": group2.name, "selected": group2.name == group])
        }
        data["groups"] = groupsArray

        data["selected_guild"] = guild
        data["selected_role"] = role
        data["priority"] = priority

        let newDiscordRule = DiscordRule(priority: priority, serverId: guild, roleId: role, groupName: group)
        if discordRule != nil && oldPriority != nil {
            do {
                try newDiscordRule.update(oldPriority: oldPriority!)
            } catch {
                data["show_error"] = true
                data["error"] = "Failed to update discord rule. Does this priority already exist?"
                return data
            }
        } else {
            do {
                try newDiscordRule.create()
            } catch {
                data["show_error"] = true
                data["error"] = "Failed to create discord rule. Does this priority already exist?"
                return data
            }
        }

        response.redirect(path: "/dashboard/discordrules")
        sessionDriver.save(session: request.session!)
        response.completed(status: .seeOther)
        throw CompletedEarly()

    }

    static func oauthDiscord(data: MustacheEvaluationContext.MapType, request: HTTPRequest,
                             response: HTTPResponse) throws -> MustacheEvaluationContext.MapType {
        var data = data
        if oauthDiscordClientID == nil || oauthDiscordRedirectURL == nil || oauthDiscordClientSecret == nil {
            response.redirect(path: "/")
            sessionDriver.save(session: request.session!)
            response.completed(status: .seeOther)
            throw CompletedEarly()
        }

        if let error = request.param(name: "error") {
            if error == "access_denied" {
                response.redirect(path: "/login")
            } else {
                response.redirect(path: "/login?error=discord_undefined")
            }
            sessionDriver.save(session: request.session!)
            response.completed(status: .seeOther)
            throw CompletedEarly()
        }

        if let code = request.param(name: "code") {

            let redirect: String
            let usernameNew: String?
            let isLogin: Bool
            let isLink: Bool

            if let state = request.param(name: "state") {
                let split = state.components(separatedBy: ";")
                let oldSession = MySQLSessions().resume(token: split[0])
                request.session?.userid = oldSession.userid
                usernameNew = oldSession.userid
                if split.count >= 2 {
                    redirect = split[1]
                } else {
                    redirect = "/"
                }

                if split.count >= 3 {
                    isLogin = split[2] == "true"
                } else {
                    isLogin = false
                }

                if split.count >= 4 {
                    isLink = split[3] == "true"
                } else {
                    isLink = false
                }
            } else {
                response.redirect(path: "/oauth/discord?login=true")
                sessionDriver.save(session: request.session!)
                response.completed(status: .seeOther)
                throw CompletedEarly()
            }

            let curl = CURLRequest("https://discordapp.com/api/oauth2/token",
                                   options: [
                                    .addHeader(.userAgent, "RealDeviceMap"),
                                    .addHeader(.accept, "application/json"),
                                    .postField(CURLRequest.POSTField(name: "client_id", value: oauthDiscordClientID!)),
                                    .postField(CURLRequest.POSTField(
                                        name: "client_secret",
                                        value: oauthDiscordClientSecret!
                                    )),
                                    .postField(CURLRequest.POSTField(name: "grant_type", value: "authorization_code")),
                                    .postField(CURLRequest.POSTField(name: "code", value: code)),
                                    .postField(CURLRequest.POSTField(
                                        name: "redirect_uri",
                                        value: oauthDiscordRedirectURL!
                                    )),
                                    .postField(CURLRequest.POSTField(name: "scope", value: "identify"))
                ]
            )
            let bodyJSON: [String: Any]?
            do {
                bodyJSON = try curl.perform().bodyJSON
            } catch {
                response.redirect(path: "/oauth/discord?login=\(isLogin)&link=\(isLink)")
                sessionDriver.save(session: request.session!)
                response.completed(status: .seeOther)
                throw CompletedEarly()

            }
            guard let accessToken =  bodyJSON?["access_token"] as? String else {
                response.redirect(path: "/oauth/discord?login=\(isLogin)&link=\(isLink)")
                sessionDriver.save(session: request.session!)
                response.completed(status: .seeOther)
                throw CompletedEarly()
            }

            let curlUser = CURLRequest("https://discordapp.com/api/users/@me",
                                       options: [
                                        .addHeader(.userAgent, "RealDeviceMap"),
                                        .addHeader(.accept, "application/json"),
                                        .addHeader(.authorization, "Bearer \(accessToken)")
                ])
            let bodyJSONUser: [String: Any]?
            do {
                bodyJSONUser = try curlUser.perform().bodyJSON
            } catch {
                response.redirect(path: "/oauth/discord?login=\(isLogin)&link=\(isLink)")
                sessionDriver.save(session: request.session!)
                response.completed(status: .seeOther)
                throw CompletedEarly()
            }

            guard let idString = bodyJSONUser?["id"] as? String, let id = UInt64(idString) else {
                response.redirect(path: "/oauth/discord?login=\(isLogin)&link=\(isLink)")
                sessionDriver.save(session: request.session!)
                response.completed(status: .seeOther)
                throw CompletedEarly()
            }

            let user: User?
            do {
                user = try User.get(username: usernameNew ?? "")
            } catch {
                user = nil
            }
            if user == nil && isLogin {
                do {
                    let user = try User.get(discordId: id)
                    if user != nil {
                        request.session?.userid = user!.username
                    } else {
                        response.redirect(path: "/login?error=discord_not_linked")
                        sessionDriver.save(session: request.session!)
                        response.completed(status: .seeOther)
                        throw CompletedEarly()
                    }
                } catch {
                    response.redirect(path: "/oauth/discord?login=\(isLogin)&link=\(isLink)")
                    sessionDriver.save(session: request.session!)
                    response.completed(status: .seeOther)
                    throw CompletedEarly()
                }
            } else if isLink {
                do {
                    try user!.setDiscordId(id: id)
                } catch {
                    response.redirect(path: "/oauth/discord?login=\(isLogin)&link=\(isLink)")
                    sessionDriver.save(session: request.session!)
                    response.completed(status: .seeOther)
                    throw CompletedEarly()
                }
            } else {
                response.redirect(path: "/oauth/discord?login=\(isLogin)&link=\(isLink)")
                sessionDriver.save(session: request.session!)
                response.completed(status: .seeOther)
                throw CompletedEarly()
            }

            data["url"] = redirect
        } else {
            let isLogin = request.param(name: "login") == "true"
            let isLink = request.param(name: "link") == "true"

            let token = request.session?.token ?? ""
            let redirect = request.param(name: "redirect") ?? "/"
            let url = "https://discordapp.com/api/oauth2/authorize?client_id=\(oauthDiscordClientID!)&redirect_uri=" +
                      "\(oauthDiscordRedirectURL!.stringByEncodingURL)&response_type=code&scope=identify&state=" +
                      "\(token);\(redirect);\(isLogin);\(isLink)"
            response.redirect(path: url)
            sessionDriver.save(session: request.session!)
            response.completed(status: .seeOther)
            throw CompletedEarly()
        }
        return data
    }

    static func getPerms(request: HTTPRequest, fromCache: Bool=false) -> (perms: [Group.Perm], username: String?) {

        var username = request.session?.userid
        var perms = [Group.Perm]()

        if username == nil || username == "" {
            let group = Group.getFromCache(groupName: "no_user")
            perms = group?.perms ?? []
        } else {
            if fromCache, let groupName = User.getGroupNameFromCache(username: username!) {
                let group = Group.getFromCache(groupName: groupName)
                perms = group?.perms ?? []
            } else {
                let user: User?
                do {
                    user = try User.get(username: username!)
                } catch {
                    user = nil
                }
                if user != nil {
                    let group = Group.getFromCache(groupName: user!.groupName)
                    perms = group?.perms ?? []
                } else {
                    request.session?.userid = ""
                    username = ""
                    perms = []
                }
            }
        }
        return (perms, username)
    }

    static func assignDeviceGroupPost(
        data: MustacheEvaluationContext.MapType, request: HTTPRequest, response: HTTPResponse, name: String
    ) throws -> MustacheEvaluationContext.MapType {

        var data = data
        guard let instanceName = request.param(name: "instance") else {
                data["show_error"] = true
                data["error"] = "Invalid Request."
                return data
        }

        let group: DeviceGroup?
        let instances: [Instance]
        let devices: [Device]?
        do {
            group = try DeviceGroup.getByName(name: name)
            devices = try Device.getAllInGroup(deviceGroupName: name)
            instances = try Instance.getAll(getData: false)
        } catch {
            data["show_error"] = true
            data["error"] = "Failed to assign Device."
            return data
        }
        if group == nil || devices == nil {
            response.setBody(string: "Device Group Not Found")
            sessionDriver.save(session: request.session!)
            response.completed(status: .notFound)
            throw CompletedEarly()
        }
        var instancesData = [[String: Any]]()
        for instance in instances {
            instancesData.append(["name": instance.name])
        }
        data["instances"] = instancesData

        do {
            for device in devices! {
                device.instanceName = instanceName
                try device.save(oldUUID: device.uuid)
                InstanceController.global.reloadDevice(newDevice: device, oldDeviceUUID: device.uuid)
            }
        } catch {
            data["show_error"] = true
            data["error"] = "Failed to assign Devices."
            return data
        }
        response.redirect(path: "/dashboard/devicegroups")
        sessionDriver.save(session: request.session!)
        response.completed(status: .seeOther)
        throw CompletedEarly()

    }

    static func assignDeviceGroupGet(
        data: MustacheEvaluationContext.MapType, request: HTTPRequest, response: HTTPResponse, name: String
    ) throws -> MustacheEvaluationContext.MapType {

        var data = data
        let instances: [Instance]
        let group: DeviceGroup?
        do {
            group = try DeviceGroup.getByName(name: name)
            instances = try Instance.getAll(getData: false)
        } catch {
            response.setBody(string: "Internal Server Error")
            sessionDriver.save(session: request.session!)
            response.completed(status: .internalServerError)
            throw CompletedEarly()
        }
        if group == nil {
            response.setBody(string: "Device Group Not Found")
            sessionDriver.save(session: request.session!)
            response.completed(status: .notFound)
            throw CompletedEarly()
        }

        var instancesData = [[String: Any]]()
        for instance in instances {
            instancesData.append(["name": instance.name])
        }
        data["instances"] = instancesData
        return data

    }

}

struct Area {
    let city: String
}
