//
//  PublicWebRoutes.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//

import PerfectLib
import PerfectHTTP

class WebRoutes {

    private init() {}

    public static var routes: [Route] {
        let routes = [
            Route(method: .get, uri: "/", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .home, requiredPerms: [.viewMap])
            }),
            Route(method: .get, uri: "/favicon.ico", handler: { (_, response) in
                response.redirect(path: "/static/favicons/favicon.ico")
                response.completed()
            }),
            Route(method: .get, uri: "/@/{lat}/{lon}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .home, requiredPerms: [.viewMap])
            }),
            Route(method: .get, uri: "/@/{lat}/{lon}/{zoom}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .home, requiredPerms: [.viewMap])
            }),
            Route(method: .get, uri: "/@/{city}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .home, requiredPerms: [.viewMap])
            }),
            Route(method: .get, uri: "/@/{city}/{zoom}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .home, requiredPerms: [.viewMap])
            }),
            Route(method: .get, uri: "/@pokemon/{id}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .home,
                                         requiredPerms: [.viewMap, .viewMapPokemon])
            }),
            Route(method: .get, uri: "/@pokemon/{id}/{is_event}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .home,
                                         requiredPerms: [.viewMap, .viewMapPokemon])
            }),
            Route(method: .get, uri: "/@pokemon/{id}/{is_event}/{zoom}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .home,
                                         requiredPerms: [.viewMap, .viewMapPokemon])
            }),
            Route(method: .get, uri: "/@pokestop/{id}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .home,
                                         requiredPerms: [.viewMap, .viewMapPokestop])
            }),
            Route(method: .get, uri: "/@pokestop/{id}/{zoom}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .home,
                                         requiredPerms: [.viewMap, .viewMapPokestop])
            }),
            Route(method: .get, uri: "/@gym/{id}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .home,
                                         requiredPerms: [.viewMap, .viewMapGym])
            }),
            Route(method: .get, uri: "/@gym/{id}/{zoom}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .home,
                                         requiredPerms: [.viewMap, .viewMapGym])
            }),
            Route(method: .get, uri: "/index.js", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .homeJs, requiredPerms: [.viewMap])
            }),
            Route(method: .get, uri: "/index.css", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .homeCss,
                                         requiredPerms: [.viewMap])
            }),
            Route(methods: [.get, .post], uri: "/setup", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .setup, requiredPerms: [])
            }),
            Route(methods: [.get, .post], uri: "/login", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .login, requiredPerms: [])
            }),
            Route(methods: [.get, .post], uri: "/oauth/discord", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .oauthDiscord, requiredPerms: [])
            }),
            Route(methods: [.get, .post], uri: "/register", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .register, requiredPerms: [])
            }),
            Route(methods: [.get, .post], uri: "/logout", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .logout, requiredPerms: [])
            }),
            Route(methods: [.get, .post], uri: "/profile", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .profile,
                                         requiredPerms: [], requiresLogin: true)
            }),
            Route(methods: [.get, .post], uri: "/confirmemail", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .confirmemail,
                                         requiredPerms: [], requiresLogin: true)
            }),
            Route(method: .get, uri: "/confirmemail/{token}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .confirmemailToken,
                                         requiredPerms: [], requiresLogin: true)
            }),
            Route(methods: [.get, .post], uri: "/resetpassword", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .resetpassword,
                                         requiredPerms: [], requiresLogin: false)
            }),
            Route(methods: [.get, .post], uri: "/resetpassword/{token}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .resetpasswordToken,
                                         requiredPerms: [], requiresLogin: false)
            }),
            Route(method: .get, uri: "/dashboard", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboard,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/settings", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardSettings,
                                         requiredPerms: [.admin])
            }),
            Route(method: .get, uri: "/dashboard/devices", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardDevices,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/device/assign/{device_uuid}",
                  handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardDeviceAssign,
                                         requiredPerms: [.admin])
            }),
            Route(method: .get, uri: "/dashboard/instances", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardInstances,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/instance/add", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardInstanceAdd,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/instance/edit/{instance_name}",
                  handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardInstanceEdit,
                                         requiredPerms: [.admin])
            }),
            Route(method: .get, uri: "/dashboard/devicegroups", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardDeviceGroups,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/devicegroup/add", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardDeviceGroupAdd,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/devicegroup/edit/{name}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardDeviceGroupEdit,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/devicegroup/delete/{name}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardDeviceGroupDelete,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/devicegroup/assign/{name}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardDeviceGroupAssign,
                                         requiredPerms: [.admin])
            }),
            Route(method: .get, uri: "/dashboard/instance/ivqueue/{instance_name}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardInstanceIVQueue,
                                         requiredPerms: [.admin])
            }),
            Route(method: .get, uri: "/dashboard/accounts", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardAccounts,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/accounts/add", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardAccountsAdd,
                                         requiredPerms: [.admin])
            }),
            Route(method: .get, uri: "/dashboard/assignments", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardAssignments,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/assignment/add", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardAssignmentAdd,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/assignment/edit/{uuid}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardAssignmentEdit,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get], uri: "/dashboard/assignment/start/{uuid}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardAssignmentStart,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/assignment/delete/{uuid}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardAssignmentDelete,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/assignment/delete_all", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardAssignmentsDeleteAll,
                                         requiredPerms: [.admin])
            }),
            Route(method: .get, uri: "/dashboard/assignmentgroups", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardAssignmentGroups,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/assignmentgroup/add", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardAssignmentGroupAdd,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/assignmentgroup/edit/{name}",
                  handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardAssignmentGroupEdit,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/assignmentgroup/delete/{name}",
                  handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardAssignmentGroupDelete,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/assignmentgroup/start/{name}",
                  handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardAssignmentGroupStart,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/assignmentgroup/request/{name}",
                  handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardAssignmentGroupReQuest,
                                         requiredPerms: [.admin])
            }),
            Route(method: .get, uri: "/dashboard/users", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardUsers,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/user/edit/{username}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardUserEdit,
                                         requiredPerms: [.admin])
            }),
            Route(method: .get, uri: "/dashboard/groups", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardGroups,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/group/edit/{group_name}", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardGroupEdit,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/group/add", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardGroupAdd,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/utilities", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardUtilities,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/discordrules", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardDiscordRules,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/discordrule/add", handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardDiscordRuleAdd,
                                         requiredPerms: [.admin])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/discordrule/edit/{discordrule_priority}",
                  handler: { (request, response) in
                WebRequestHandler.handle(request: request, response: response, page: .dashboardDiscordRuleEdit,
                                         requiredPerms: [.admin])
            }),
            Route(method: .get, uri: "/static/**", handler: WebStaticRequestHandler.handle)
        ]

        return routes
    }

}
