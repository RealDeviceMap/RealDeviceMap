//
//  APIRoutes.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.08.18.
//

import PerfectLib
import PerfectHTTP

class ImageAPIRoutes {

    private init() {}

    public static var routes: [Route] {
        let routes = [
            Route(method: .get, uri: "/image-api/pokemon", handler: { (request, response) in
                ImageApiRequestHandler.handlePokemon(request: request, response: response)
            })
        ]

        return routes
    }

}
