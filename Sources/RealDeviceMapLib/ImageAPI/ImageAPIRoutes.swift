//
//  APIRoutes.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 05.09.21.
//

import PerfectLib
import PerfectHTTP

class ImageAPIRoutes {

    private init() {}

    public static var routes: [Route] {
        let routes = [
            Route(method: .get, uri: "/image-api/pokemon", handler: { (request, response) in
                ImageApiRequestHandler.handlePokemon(request: request, response: response)
            }),
            Route(method: .get, uri: "/image-api/gym", handler: { (request, response) in
                ImageApiRequestHandler.handleGym(request: request, response: response)
            }),
            Route(method: .get, uri: "/image-api/pokestop", handler: { (request, response) in
                ImageApiRequestHandler.handlePokestop(request: request, response: response)
            })
        ]

        return routes
    }

}
