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

class WebHookServer {

    public enum Action {
        case controler
        case raw
    }

    private init() {}

    public static var server: HTTPServer.Server {

        let enviroment = ProcessInfo.processInfo.environment
        let address = enviroment["WEBHOOK_SERVER_ADDRESS"] ?? "0.0.0.0"
        let port = Int(enviroment["WEBHOOK_SERVER_PORT"] ?? "") ?? 9001

        let routes = Routes(WebHookRoutes.routes)

        return HTTPServer.Server(name: "WebHook Server", address: address, port: port, routes: routes)
    }

}
