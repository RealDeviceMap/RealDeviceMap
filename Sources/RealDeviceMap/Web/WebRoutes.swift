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
                WebReqeustHandler.handle(request: request, response: response, page: .home, requiredPerms: [.viewMap])
            }),
            Route(method: .get, uri: "/index.js", handler: { (request, response) in
                WebReqeustHandler.handle(request: request, response: response, page: .homeJs, requiredPerms: [.viewMap])
            }),
            Route(method: .get, uri: "/index.css", handler: { (request, response) in
                WebReqeustHandler.handle(request: request, response: response, page: .homeCss, requiredPerms: [.viewMap])
            }),
            Route(methods: [.get, .post], uri: "/setup", handler: { (request, response) in
                WebReqeustHandler.handle(request: request, response: response, page: .setup, requiredPerms: [])
            }),
            Route(methods: [.get, .post], uri: "/login", handler: { (request, response) in
                WebReqeustHandler.handle(request: request, response: response, page: .login, requiredPerms: [])
            }),
            Route(methods: [.get, .post], uri: "/register", handler: { (request, response) in
                WebReqeustHandler.handle(request: request, response: response, page: .register, requiredPerms: [])
            }),
            Route(methods: [.get, .post], uri: "/logout", handler: { (request, response) in
                WebReqeustHandler.handle(request: request, response: response, page: .logout, requiredPerms: [])
            }),
            Route(method: .get, uri: "/dashboard", handler: { (request, response) in
                WebReqeustHandler.handle(request: request, response: response, page: .dashboard, requiredPerms: [.adminUser, .adminSetting], requiredPermsCount: 1)
            }),
            Route(methods: [.get, .post], uri: "/dashboard/settings", handler: { (request, response) in
                WebReqeustHandler.handle(request: request, response: response, page: .dashboardSettings, requiredPerms: [.adminSetting])
            }),
            Route(method: .get, uri: "/dashboard/devices", handler: { (request, response) in
                WebReqeustHandler.handle(request: request, response: response, page: .dashboardDevices, requiredPerms: [.adminSetting])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/device/assign/{device_uuid}", handler: { (request, response) in
                WebReqeustHandler.handle(request: request, response: response, page: .dashboardDeviceAssign, requiredPerms: [.adminSetting])
            }),
            Route(method: .get, uri: "/dashboard/instances", handler: { (request, response) in
                WebReqeustHandler.handle(request: request, response: response, page: .dashboardInstances, requiredPerms: [.adminSetting])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/instance/add", handler: { (request, response) in
                WebReqeustHandler.handle(request: request, response: response, page: .dashboardInstanceAdd, requiredPerms: [.adminSetting])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/instance/edit/{instance_name}", handler: { (request, response) in
                WebReqeustHandler.handle(request: request, response: response, page: .dashboardInstanceEdit, requiredPerms: [.adminSetting])
            }),
            Route(method: .get, uri: "/dashboard/instance/ivqueue/{instance_name}", handler: { (request, response) in
                WebReqeustHandler.handle(request: request, response: response, page: .dashboardInstanceIVQueue, requiredPerms: [.adminSetting])
            }),
            Route(method: .get, uri: "/dashboard/accounts", handler: { (request, response) in
                WebReqeustHandler.handle(request: request, response: response, page: .dashboardAccounts, requiredPerms: [.adminSetting])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/accounts/add", handler: { (request, response) in
                WebReqeustHandler.handle(request: request, response: response, page: .dashboardAccountsAdd
                    , requiredPerms: [.adminSetting])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/clearquests", handler: { (request, response) in
                WebReqeustHandler.handle(request: request, response: response, page: .dashboardClearQuests
                    , requiredPerms: [.adminSetting])
            }),
            Route(method: .get, uri: "/dashboard/assignments", handler: { (request, response) in
                WebReqeustHandler.handle(request: request, response: response, page: .dashboardAssignments, requiredPerms: [.adminSetting])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/assignment/add", handler: { (request, response) in
                WebReqeustHandler.handle(request: request, response: response, page: .dashboardAssignmentAdd, requiredPerms: [.adminSetting])
            }),
            Route(methods: [.get, .post], uri: "/dashboard/assignment/delete/{uuid}", handler: { (request, response) in
                WebReqeustHandler.handle(request: request, response: response, page: .dashboardAssignmentDelete, requiredPerms: [.adminSetting])
            }),
            Route(method: .get, uri: "/static/**", handler: WebStaticReqeustHandler.handle)
        ]
        
        return routes
    }
    
}
