//
//  PublicWebServer.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 18.09.18.
//

import Foundation
import PerfectHTTP
import PerfectHTTPServer
import PerfectSession
import PerfectSessionMySQL

public class WebHookServer {

    public enum Action {
        case controler
        case raw
    }

    private init() {}

    public static var server: HTTPServer.Server {

        let environment = ProcessInfo.processInfo.environment
        let address = environment["WEBHOOK_SERVER_ADDRESS"] ?? "0.0.0.0"
        let port = Int(environment["WEBHOOK_SERVER_PORT"] ?? "") ?? 9001

        let routes = Routes(WebHookRoutes.routes)

        return HTTPServer.Server(name: "WebHook Server", address: address, port: port, routes: routes)
    }

}
