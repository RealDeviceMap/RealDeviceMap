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
        print(baseImage, image, spawnTypeImage, rankingImage)

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

        print(([
            "/usr/local/bin/convert",
            "(", baseImage, "-resize", "96x96", ")",
            "-gravity", "Center"
            ] + markerAgs + [
            image
        ]).joined(separator: " "))
        Shell([
            "/usr/local/bin/convert",
            "(", baseImage, "-resize", "96x96", ")",
            "-gravity", "Center"
            ] + markerAgs + [
            image
        ]).run(environment: magickEnv)

    }

    private static func combineImages(image1: String, image2: String, method: String, output: String) {
        _ = Shell("/usr/local/bin/convert", "-limit", "thread", "1", image1, "-background", "none",
                  "-resize", "96x96", "-gravity", "north", "-extent", "96x160", "tmp1.png").run(environment: magickEnv)
        _ = Shell("/usr/local/bin/convert", "-limit", "thread", "1", image2, "-background", "none",
                  "-resize", "96x96", "-gravity", "south", "-extent", "96x160", "tmp2.png").run(environment: magickEnv)
        _ = Shell("/usr/local/bin/convert", "-limit", "thread", "1", "tmp1.png", "tmp2.png",
                  "-gravity", "center", "-compose", method, "-composite", output).run(environment: magickEnv)
        _ = Shell("rm", "-f", "tmp1.png").run()
        _ = Shell("rm", "-f", "tmp2.png").run()
    }

    private static func combineImagesGrunt(image1: String, image2: String, output: String) {
        _ = Shell("/usr/local/bin/convert", "-limit", "thread", "1", image1, "-background", "none",
                  "-resize", "96x96", "-gravity", "center", "tmp1.png").run(environment: magickEnv)
        _ = Shell("/usr/local/bin/convert", "-limit", "thread", "1", image2, "-background", "none",
                  "-resize", "64x64", "-gravity", "center", "tmp2.png").run(environment: magickEnv)
        _ = Shell("/usr/local/bin/convert", "-limit", "thread", "1", "tmp1.png", "tmp2.png",
                  "-gravity", "center", "-geometry", "+0-19", "-compose", "over", "-composite", output)
            .run(environment: magickEnv)
        _ = Shell("rm", "-f", "tmp1.png").run()
        _ = Shell("rm", "-f", "tmp2.png").run()
    }

    private static func combineImagesGruntQuest(image1: String, image2: String, output: String) {
        _ = Shell("/usr/local/bin/convert", "-limit", "thread", "1", image1, "-background", "none",
                  "-resize", "96x160", "-gravity", "center", "tmp1.png").run(environment: magickEnv)
        _ = Shell("/usr/local/bin/convert", "-limit", "thread", "1", image2, "-background", "none",
                  "-resize", "64x64", "-gravity", "center", "tmp2.png").run(environment: magickEnv)
        _ = Shell("/usr/local/bin/convert", "-limit", "thread", "1", "tmp1.png", "tmp2.png",
                  "-gravity", "center", "-geometry", "+0+13", "-compose", "over", "-composite", output)
            .run(environment: magickEnv)
        _ = Shell("rm", "-f", "tmp1.png").run()
        _ = Shell("rm", "-f", "tmp2.png").run()
    }

    private static func combineImagesLeague(image1: String, image2: String, output: String) {
        _ = Shell("/usr/local/bin/convert", "-limit", "thread", "1", image1, "-background", "none",
                  "-resize", "96x96", "-gravity", "center", "tmp1.png").run(environment: magickEnv)
        _ = Shell("/usr/local/bin/convert", "-limit", "thread", "1", image2, "-background", "none",
                  "-resize", "64x64", "-gravity", "center", "tmp2.png").run(environment: magickEnv)
        _ = Shell("/usr/local/bin/convert", "-limit", "thread", "1", "tmp1.png", "tmp2.png",
                  "-gravity", "SouthWest", "-compose", "over", "-composite", output)
            .run(environment: magickEnv)
        _ = Shell("rm", "-f", "tmp1.png").run()
        _ = Shell("rm", "-f", "tmp2.png").run()
    }

}
