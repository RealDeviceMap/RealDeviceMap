//
//  APIRoutes.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.08.18.
//

import PerfectLib
import PerfectHTTP

class WebHookRoutes {
    
    private init() {}
    
    public static var routes: [Route] {
        let routes = [
            Route(method: .post, uri: "/raw", handler: { (request, response) in
                WebHookRequestHandler.handle(request: request, response: response, type: .raw)
            }),
            Route(method: .post, uri: "/controler", handler: { (request, response) in
                WebHookRequestHandler.handle(request: request, response: response, type: .controler)
            })
        ]
        return routes
    }
    
}
