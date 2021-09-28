//
//  ImageGenerator.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 29.10.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast

import Foundation
import PerfectLib
import PerfectThread

class ImageGenerator {

    private static let magickEnv = ["MAGICK_THREAD_LIMIT": "1"]

    private init() {}

    internal static func buildPokemonImage(
        baseImage: String, image: String, spawnTypeImage: String?, rankingImage: String?
    ) {
        var markerAgs = [String]()
        if let spawnTypeImage = spawnTypeImage {
            markerAgs += [
                "(", spawnTypeImage, "-resize", "48x48", ")",
                "-gravity", "Center",
                "-geometry", "-24+24",
                "-composite"
            ]
        }
        if let rankingImage = rankingImage {
            markerAgs += [
                "(", rankingImage, "-resize", "48x48", ")",
                "-gravity", "Center",
                "-geometry", "+24+24",
                "-composite"
            ]
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
