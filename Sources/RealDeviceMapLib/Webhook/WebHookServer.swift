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

        let address: String = ConfigLoader.global.getConfig(type: .webhookServerHost)
        let port: Int = ConfigLoader.global.getConfig(type: .webhookServerPort)

        let routes = Routes(WebHookRoutes.routes)

        return HTTPServer.Server(name: "WebHook Server", address: address, port: port, routes: routes)
    }

}
