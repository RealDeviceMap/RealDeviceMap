//
//  StaticWebRouteHandler.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//

import PerfectLib
import PerfectHTTP

class WebStaticRequestHandler {

    private static let staticFileHandler = StaticFileHandler(documentRoot: "\(projectroot)/resources/webroot")

    private init() {}

    static func handle(request: HTTPRequest, _ response: HTTPResponse) {
        if request.path.hasSuffix(".png") || request.path.hasSuffix(".jpg") {
            response.setHeader(.cacheControl, value: "max-age=604800, must-revalidate")
        }
        staticFileHandler.handleRequest(request: request, response: response)
        response.completed()
    }

}
