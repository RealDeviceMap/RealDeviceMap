//
//  ImageAPIRoutes.swift
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
            Route(method: .get, uri: "/image-api/device", handler: { (request, response) in
                ImageApiRequestHandler.handleDevice(request: request, response: response)
            }),
            Route(method: .get, uri: "/image-api/gym", handler: { (request, response) in
                ImageApiRequestHandler.handleGym(request: request, response: response)
            }),
            Route(method: .get, uri: "/image-api/invasion", handler: { (request, response) in
                ImageApiRequestHandler.handleInvasion(request: request, response: response)
            }),
            Route(method: .get, uri: "/image-api/misc", handler: { (request, response) in
                ImageApiRequestHandler.handleMisc(request: request, response: response)
            }),
            Route(method: .get, uri: "/image-api/pokemon", handler: { (request, response) in
                ImageApiRequestHandler.handlePokemon(request: request, response: response)
            }),
            Route(method: .get, uri: "/image-api/pokestop", handler: { (request, response) in
                ImageApiRequestHandler.handlePokestop(request: request, response: response)
            }),
            Route(method: .get, uri: "/image-api/raid-egg", handler: { (request, response) in
                ImageApiRequestHandler.handleRaidEgg(request: request, response: response)
            }),
            Route(method: .get, uri: "/image-api/reward", handler: { (request, response) in
                ImageApiRequestHandler.handleReward(request: request, response: response)
            }),
            Route(method: .get, uri: "/image-api/spawnpoint", handler: { (request, response) in
                ImageApiRequestHandler.handleSpawnpoint(request: request, response: response)
            }),
            Route(method: .get, uri: "/image-api/team", handler: { (request, response) in
                ImageApiRequestHandler.handleTeam(request: request, response: response)
            }),
            Route(method: .get, uri: "/image-api/type", handler: { (request, response) in
                ImageApiRequestHandler.handleType(request: request, response: response)
            }),
            Route(method: .get, uri: "/image-api/weather", handler: { (request, response) in
                ImageApiRequestHandler.handleWeather(request: request, response: response)
            })
        ]

        return routes
    }

}
