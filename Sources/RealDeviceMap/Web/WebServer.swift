//
//  PublicWebServer.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//

import Foundation
import PerfectHTTP
import PerfectHTTPServer
import PerfectSession
import PerfectSessionMySQL

class WebServer {

    public enum Page: String {
        case home = "index.mustache"
        case homeJs = "index.js.mustache"
        case homeCss = "index.css.mustache"
        case setup = "setup.mustache"
        case login = "login.mustache"
        case oauthDiscord = "oauth_discord.mustache"
        case register = "register.mustache"
        case logout = "logout.mustache"
        case profile = "profile.mustache"
        case confirmemail = "confirmemail.mustache"
        case confirmemailToken = "confirmemail_token.mustache"
        case resetpassword = "resetpassword.mustache"
        case resetpasswordToken = "resetpassword_token.mustache"
        case dashboard = "dashboard.mustache"
        case dashboardSettings = "dashboard_settings.mustache"
        case dashboardDevices = "dashboard_devices.mustache"
        case dashboardDeviceAssign = "dashboard_device_assign.mustache"
        case dashboardInstances = "dashboard_instances.mustache"
        case dashboardInstanceAdd = "dashboard_instance_add.mustache"
        case dashboardInstanceEdit = "dashboard_instance_edit.mustache"
        case dashboardInstanceIVQueue = "dashboard_instance_ivqueue.mustache"
        case dashboardDeviceGroups = "dashboard_devicegroups.mustache"
        case dashboardDeviceGroupAdd = "dashboard_devicegroup_add.mustache"
        case dashboardDeviceGroupEdit = "dashboard_devicegroup_edit.mustache"
        case dashboardDeviceGroupDelete = "dashboard_devicegroup_delete.mustache"
        case dashboardDeviceGroupAssign = "dashboard_devicegroup_assign.mustache"
        case dashboardAccounts = "dashboard_accounts.mustache"
        case dashboardAccountsAdd = "dashboard_accounts_add.mustache"
        case dashboardAssignments = "dashboard_assignments.mustache"
        case dashboardAssignmentAdd = "dashboard_assignment_add.mustache"
        case dashboardAssignmentEdit = "dashboard_assignment_edit.mustache"
        case dashboardAssignmentStart = "dashboard_assignment_start.mustache"
        case dashboardAssignmentDelete = "dashboard_assignment_delete.mustache"
        case dashboardAssignmentsDeleteAll = "dashboard_assignments_delete_all.mustache"
        case dashboardAssignmentGroups = "dashboard_assignmentgroups.mustache"
        case dashboardAssignmentGroupAdd = "dashboard_assignmentgroup_add.mustache"
        case dashboardAssignmentGroupEdit = "dashboard_assignmentgroup_edit.mustache"
        case dashboardAssignmentGroupDelete = "dashboard_assignmentgroup_delete.mustache"
        case dashboardAssignmentGroupStart = "dashboard_assignmentgroup_start.mustache"
        case dashboardAssignmentGroupReQuest = "dashboard_assignmentgroup_request.mustache"
        case dashboardUsers = "dashboard_users.mustache"
        case dashboardUserEdit = "dashboard_user_edit.mustache"
        case dashboardGroups = "dashboard_groups.mustache"
        case dashboardGroupEdit = "dashboard_group_edit.mustache"
        case dashboardGroupAdd = "dashboard_group_add.mustache"
        case dashboardDiscordRules = "dashboard_discordrules.mustache"
        case dashboardDiscordRuleAdd = "dashboard_discordrule_add.mustache"
        case dashboardDiscordRuleEdit = "dashboard_discordrule_edit.mustache"
        case dashboardUtilities = "dashboard_utilities.mustache"
        case unauthorized = "unauthorized.mustache"
    }

    public enum APIPage {
        case getData
        case setData
    }

    private init() {}

    public static var server: HTTPServer.Server {

        let enviroment = ProcessInfo.processInfo.environment
        let address = enviroment["WEB_SERVER_ADDRESS"] ?? "0.0.0.0"
        let port = Int(enviroment["WEB_SERVER_PORT"] ?? "") ?? 9000

        SessionConfig.name = "SESSION-TOKEN"
        SessionConfig.idle = 604800 // 7 Days

        // SessionConfig.cookieDomain = "/"
        SessionConfig.cookieSecure = false // <- make secure
        SessionConfig.IPAddressLock = false
        SessionConfig.userAgentLock = false
        SessionConfig.CSRF.checkState = true
        SessionConfig.CSRF.checkHeaders = true
        SessionConfig.CSRF.requireToken = true

        SessionConfig.CORS.enabled = true
        SessionConfig.CORS.methods = [.get, .post]
        SessionConfig.CORS.maxAge = 3600

        AuthFilter.authenticationConfig.include("*")

        let sessionDriver = SessionMySQLDriver()

        let routes = Routes(WebRoutes.routes + APIRoutes.routes)

        return HTTPServer.Server(name: "Web Server", address: address, port: port, routes: routes,
                                 requestFilters: [sessionDriver.requestFilter],
                                 responseFilters: [sessionDriver.responseFilter])
    }

    public static var startupServer: HTTPServer.Server {
        let enviroment = ProcessInfo.processInfo.environment
        let address = enviroment["WEB_SERVER_ADDRESS"] ?? "0.0.0.0"
        let port = Int(enviroment["WEB_SERVER_PORT"] ?? "") ?? 9000

        let route = Route(uri: "**") { (_, response) in
            response.setBody(string: """
            <html lang="en">
                <head>
                    <title>RealDeviceMap - Starting...</title>
                    <meta http-equiv="refresh" content="30"/>
                </head>

                <body>
                    <br>
                    <h1 align="center">RealDeviceMap is starting!</h1>
                    <h2 align="center">Please wait...<h2>
                    <h2 align="center">(This page will auto reload in 30 seconds.)</h2>
                </body>
            </html>
            """)
            response.completed()
        }
        return HTTPServer.Server(name: "Temp Web Server", address: address, port: port, routes: Routes([route]))
    }

}
