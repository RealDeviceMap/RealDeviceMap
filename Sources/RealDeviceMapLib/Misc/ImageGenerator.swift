//
//  ImageGenerator.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 29.10.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast

import Foundation
import PerfectLib
import PerfectThread

public class ImageGenerator {

    private static let magickEnv = ["MAGICK_THREAD_LIMIT": "1"]

    private init() {}

    //  swiftlint:disable force_try
    static func generate() {
        let raidDir = Dir("\(projectroot)/resources/webroot/static/img/raid/")
        let gymDir = Dir("\(projectroot)/resources/webroot/static/img/gym/")
        let eggDir = Dir("\(projectroot)/resources/webroot/static/img/egg/")
        var unkownEggDir = Dir("\(projectroot)/resources/webroot/static/img/unkown_egg/")
        if !unkownEggDir.exists {
            unkownEggDir = Dir("\(projectroot)/resources/webroot/static/img/unknown_egg/")
        }
        let pokestopDir = Dir("\(projectroot)/resources/webroot/static/img/pokestop/")
        let pokemonDir = Dir("\(projectroot)/resources/webroot/static/img/pokemon/")
        let wildPokemonDir = Dir("\(projectroot)/resources/webroot/static/img/wild_pokemon/")
        let pokemonLeagueDir = Dir("\(projectroot)/resources/webroot/static/img/pokemon_league/")
        let itemDir = Dir("\(projectroot)/resources/webroot/static/img/item/")
        let questDir = Dir("\(projectroot)/resources/webroot/static/img/quest/")
        let gruntDir = Dir("\(projectroot)/resources/webroot/static/img/grunt/")
        let invasionDir = Dir("\(projectroot)/resources/webroot/static/img/invasion/")
        let questInvasionDir = Dir("\(projectroot)/resources/webroot/static/img/quest_invasion/")

        let firstFile = File("\(projectroot)/resources/webroot/static/img/misc/first.png")
        let secondFile = File("\(projectroot)/resources/webroot/static/img/misc/second.png")
        let thirdFile = File("\(projectroot)/resources/webroot/static/img/misc/third.png")

        let grassFile = File("\(projectroot)/resources/webroot/static/img/misc/grass.png")

        if !raidDir.exists {
            try! raidDir.create()
        }
        Shell([
            "/usr/local/bin/convert",
            "(", baseImage, "-resize", "96x96", ")",
            "-gravity", "center"
            ] + markerAgs + [
            image
        ]).run(environment: magickEnv)
    }

    internal static func buildRaidImage(baseImage: String, raidImage: String, image: String) {
        Shell([
            "/usr/local/bin/convert",
            "(", raidImage, "-resize", "96x96", "-gravity", "north", "-extent", "96x160", "-background", "none", ")",
            "(", baseImage, "-resize", "96x96", "-gravity", "south", "-extent", "96x160", "-background", "none", ")",
            "-gravity", "center",
            "-compose", "over",
            "-composite",
            image
        ]).run(environment: magickEnv)
    }

}
