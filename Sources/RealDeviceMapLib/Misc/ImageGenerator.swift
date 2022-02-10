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
                "-gravity", "center",
                "-geometry", "-24+24",
                "-composite"
            ]
        }
        if let rankingImage = rankingImage {
            markerAgs += [
                "(", rankingImage, "-resize", "48x48", ")",
                "-gravity", "center",
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

    internal static func buildRaidImage(
        baseImage: String, image: String, raidImage: String
    ) {
        Shell([
            "/usr/local/bin/convert",
            "(", raidImage, "-background", "none", "-resize", "96x96", "-gravity", "north", "-extent", "96x160", ")",
            "(", baseImage, "-background", "none", "-resize", "96x96", "-gravity", "south", "-extent", "96x160", ")",
            "-gravity", "center",
            "-compose", "over",
            "-composite",
            image
        ]).run(environment: magickEnv)
    }

    internal static func buildPokestopImage(
        baseImage: String, image: String, invasionImage: String?, rewardImage: String?
    ) {
        var markerAgs = [String]()
        let invasionGeometry
        if rewardImage != nil {
            invasionGeometry = [ "-geometry", "+0-19" ]
        } else {
            invasionGeometry = [ "-geometry", "+0+13" ]
        }
        if let invasionImage = invasionImage {
            markerAgs += [
                "(", invasionImage, "-resize", "48x48", ")",
                "-gravity", "center"
                ] + invasionGeometry + [
                "-composite"
            ]
        }
        // if let rewardImage = rewardImage {
        //    markerAgs += [
        //        "(", rewardImage, "-resize", "48x48", ")",
        //        "-gravity", "center",
        //        "-geometry", "+24-24",
        //        "-composite"
        //   ]
        // }
        if rewardImage != nil {
            Shell([
                "/usr/local/bin/convert",
                "(", rewardImage!, "-background", "none", "-resize", "96x96", "-gravity", "north", "-extent", "96x160",
                ")",
                "(", baseImage, "-background", "none", "-resize", "96x96", "-gravity", "south", "-extent", "96x160",
                ")",
                "-gravity", "center",
                "-compose", "over",
                "-composite"
            ] + markerAgs + [
                image
            ]).run(environment: magickEnv)
        } else {
            Shell([
                "/usr/local/bin/convert",
                "(", baseImage, "-resize", "96x96", ")",
                "-gravity", "center"
            ] + markerAgs + [
                image
            ]).run(environment: magickEnv)
        }
    }

}
