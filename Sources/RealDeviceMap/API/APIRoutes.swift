//
//  APIRoutes.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.08.18.
//

import PerfectLib
import PerfectHTTP

class APIRoutes {
    
    private init() {}
    
    public static var routes: [Route] {
        let routes = [
            Route(methods: [.get, .post], uri: "/api/get_data", handler: { (request, response) in
                ApiRequestHandler.handle(request: request, response: response, route: .getData)
            })
        ]
        
        return routes
    }
    
}
