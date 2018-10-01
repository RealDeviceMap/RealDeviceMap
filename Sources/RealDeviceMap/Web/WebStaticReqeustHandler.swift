//
//  StaticWebRouteHandler.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//

import PerfectLib
import PerfectHTTP

class WebStaticReqeustHandler {
    
    private init() {}
    
    static func handle(request: HTTPRequest, _ response: HTTPResponse) {
        let documentRoot = Dir.workingDir.path + "/resources/webroot"
        let staticFileHandler = StaticFileHandler(documentRoot: documentRoot)
        staticFileHandler.handleRequest(request: request, response: response)
        response.completed()
    }
    
}
