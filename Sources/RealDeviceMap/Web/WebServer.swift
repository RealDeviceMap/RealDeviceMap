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
        case register = "register.mustache"
        case logout = "logout.mustache"
        case dashboard = "dashboard.mustache"
        case dashboardSettings = "dashboard_settings.mustache"
        case dashboardDevices = "dashboard_devices.mustache"
        case dashboardDeviceAssign = "dashboard_device_assign.mustache"
        case dashboardInstances = "dashboard_instances.mustache"
        case dashboardInstanceAdd = "dashboard_instance_add.mustache"
        case dashboardInstanceEdit = "dashboard_instance_edit.mustache"
        case dashboardInstanceIVQueue = "dashboard_instance_ivqueue.mustache"
        case dashboardAccounts = "dashboard_accounts.mustache"
        case dashboardAccountsAdd = "dashboard_accounts_add.mustache"
        case dashboardClearQuests = "dashboard_clearquests.mustach"
        case dashboardAssignments = "dashboard_assignments.mustache"
        case dashboardAssignmentAdd = "dashboard_assignment_add.mustache"
        case dashboardAssignmentDelete = "dashboard_assignment_delete.mustache"
    }
    
    public enum APIPage {
        case getData
    }
    
    private init() {}
    
    public static var server: HTTPServer.Server {
        
        let enviroment = ProcessInfo.processInfo.environment
        let address = enviroment["WEB_SERVER_ADDRESS"] ?? "0.0.0.0"
        let port = Int(enviroment["WEB_SERVER_PORT"] ?? "") ?? 9000
        
        SessionConfig.name = "SESSION-TOKEN"
        SessionConfig.idle = 2592000
        
        //SessionConfig.cookieDomain = "/"
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
        
        return HTTPServer.Server(name: "Web Server", address: address, port: port, routes: routes, requestFilters: [sessionDriver.requestFilter], responseFilters: [sessionDriver.responseFilter])
    }

}
