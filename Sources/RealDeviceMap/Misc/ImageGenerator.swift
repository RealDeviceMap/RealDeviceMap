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
        if !questDir.exists {
            try! questDir.create()
        }
        if !invasionDir.exists {
            try! invasionDir.create()
        }
        if !questInvasionDir.exists {
            try! questInvasionDir.create()
        }
        if !pokemonLeagueDir.exists {
            try! pokemonLeagueDir.create()
        }
        if !wildPokemonDir.exists {
            try! wildPokemonDir.create()
        }

        let thread = Threading.getQueue(type: .serial)

        let composeMethod: String
        if ProcessInfo.processInfo.environment["IMAGEGEN_OVER"] == nil {
            composeMethod = "over"
        } else {
            composeMethod = "dst-over"
        }
        thread.dispatch {

            if pokemonDir.exists && firstFile.exists && secondFile.exists && thirdFile.exists {
                Log.info(message: "[ImageGenerator] Creating Pokemon League Images...")
                try! FileManager.default.contentsOfDirectory(atPath: pokemonDir.path).forEach { (pokemonFilename) in
                    if !pokemonFilename.contains(".png") {
                        Log.debug(message: "[ImageGenerator] \(pokemonFilename) is not png! Skipping...")
                        return
                    }
                    let pokemonFile = File(pokemonDir.path + pokemonFilename)
                    let pokemonId = pokemonFilename.replacingOccurrences(of: ".png", with: "")
                    let newFileFirst = File(pokemonLeagueDir.path + pokemonId + "_1.png")
                    if !newFileFirst.exists {
                        Log.debug(message: "[ImageGenerator] Creating #1 Pokemon League Images \(pokemonId)")
                        combineImagesLeague(image1: pokemonFile.path, image2: firstFile.path, output: newFileFirst.path)
                    }
                    let newFileSecond = File(pokemonLeagueDir.path + pokemonId + "_2.png")
                    if !newFileSecond.exists {
                        Log.debug(message: "[ImageGenerator] Creating #2 Pokemon League Images \(pokemonId)")
                        combineImagesLeague(image1: pokemonFile.path, image2: secondFile.path,
                                            output: newFileSecond.path)
                    }
                    let newFileThird = File(pokemonLeagueDir.path + pokemonId + "_3.png")
                    if !newFileThird.exists {
                        Log.debug(message: "[ImageGenerator] Creating #3 Pokemon League Images \(pokemonId)")
                        combineImagesLeague(image1: pokemonFile.path, image2: thirdFile.path, output: newFileThird.path)
                    }
                }
                Log.info(message: "[ImageGenerator] Pokemon League Images created.")
            } else {
                Log.warning(message: "[ImageGenerator] Not generating  Pokemon League Images (missing Dirs)")
                if !pokemonDir.exists {
                    Log.info(message: "[ImageGenerator] Missing dir \(pokemonDir.path)")
                }
                if !firstFile.exists {
                    Log.info(message: "[ImageGenerator] Missing file \(firstFile.path)")
                }
                if !secondFile.exists {
                    Log.info(message: "[ImageGenerator] Missing file \(secondFile.path)")
                }
                if !thirdFile.exists {
                    Log.info(message: "[ImageGenerator] Missing file \(thirdFile.path)")
                }
            }

            if pokemonDir.exists && grassFile.exists {
                Log.info(message: "[ImageGenerator] Creating Wild Pokemon Images...")
                try! FileManager.default.contentsOfDirectory(atPath: pokemonDir.path).forEach { (pokemonFilename) in
                    if !pokemonFilename.contains(".png") {
                        Log.debug(message: "[ImageGenerator] \(pokemonFilename) is not png! Skipping...")
                        return
                    }
                    let pokemonFile = File(pokemonDir.path + pokemonFilename)
                    let pokemonId = pokemonFilename.replacingOccurrences(of: ".png", with: "")
                    let newFileWild = File(wildPokemonDir.path + pokemonId + ".png")
                    if !newFileWild.exists {
                        Log.debug(message: "[ImageGenerator] Creating Wild Pokemon Image \(pokemonId)")
                        combineImagesLeague(image1: pokemonFile.path, image2: grassFile.path, output: newFileWild.path)
                    }
                }
                Log.info(message: "[ImageGenerator] Wild Pokemon Images created.")
            } else {
                Log.warning(message: "[ImageGenerator] Not generating Wild Pokemon Images (missing Dirs)")
                if !pokemonDir.exists {
                    Log.info(message: "[ImageGenerator] Missing dir \(pokemonDir.path)")
                }
                if !grassFile.exists {
                    Log.info(message: "[ImageGenerator] Missing file \(grassFile.path)")
                }
            }

            if raidDir.exists && gymDir.exists && eggDir.exists && unkownEggDir.exists && pokemonDir.exists {

                Log.info(message: "[ImageGenerator] Creating Raid Images...")

                try! FileManager.default.contentsOfDirectory(atPath: gymDir.path).forEach { (gymFilename) in
                    if !gymFilename.contains(".png") {
                        Log.debug(message: "[ImageGenerator] \(gymFilename) is not png! Skipping...")
                        return
                    }
                    let gymFile = File(gymDir.path + gymFilename)
                    let gymId = gymFilename.replacingOccurrences(of: ".png", with: "")

                    try! FileManager.default.contentsOfDirectory(atPath: eggDir.path).forEach { (eggFilename) in
                        if !eggFilename.contains(".png") {
                            Log.debug(message: "[ImageGenerator] \(eggFilename) is not png! Skipping...")
                            return
                        }
                        let eggFile = File(eggDir.path + eggFilename)
                        let eggLevel = eggFilename.replacingOccurrences(of: ".png", with: "")
                        let newFile = File(raidDir.path + gymId + "_e" + eggLevel + ".png")
                        if !newFile.exists {
                            Log.debug(message: "[ImageGenerator] Creating image for gym \(gymId) and egg \(eggLevel)")
                            combineImages(image1: eggFile.path, image2: gymFile.path,
                                          method: composeMethod, output: newFile.path)
                        }
                    }
                    try! FileManager.default.contentsOfDirectory(atPath: unkownEggDir.path)
                                            .forEach { (unkownEggFilename) in
                        if !unkownEggFilename.contains(".png") {
                            Log.debug(message: "[ImageGenerator] \(unkownEggFilename) is not png! Skipping...")
                            return
                        }
                        let unkownEggFile = File(unkownEggDir.path + unkownEggFilename)
                        let eggLevel = unkownEggFilename.replacingOccurrences(of: ".png", with: "")
                        let newFile = File(raidDir.path + gymId + "_ue" + eggLevel + ".png")
                        if !newFile.exists {
                            Log.debug(
                                message: "[ImageGenerator] Creating image for gym \(gymId) and unkown egg \(eggLevel)"
                            )
                            combineImages(image1: unkownEggFile.path, image2: gymFile.path,
                                          method: composeMethod, output: newFile.path)
                        }
                    }
                    try! FileManager.default.contentsOfDirectory(atPath: pokemonDir.path).forEach { (pokemonFilename) in
                        if !pokemonFilename.contains(".png") {
                            Log.debug(message: "[ImageGenerator] \(pokemonFilename) is not png! Skipping...")
                            return
                        }
                        let pokemonFile = File(pokemonDir.path + pokemonFilename)
                        let pokemonId = pokemonFilename.replacingOccurrences(of: ".png", with: "")
                        let newFile = File(raidDir.path + gymId + "_" + pokemonId + ".png")
                        if !newFile.exists {
                            Log.debug(
                                message: "[ImageGenerator] Creating image for gym \(gymId) and pokemon \(pokemonId)"
                            )
                            combineImages(image1: pokemonFile.path, image2: gymFile.path,
                                          method: composeMethod, output: newFile.path)
                        }
                    }
                }

                Log.info(message: "[ImageGenerator] Raid images created.")
            } else {
                Log.warning(message: "[ImageGenerator] Not generating Quest Images (missing Dirs)")
                if !raidDir.exists {
                    Log.info(message: "[ImageGenerator] Missing dir \(raidDir.path)")
                }
                if !gymDir.exists {
                    Log.info(message: "[ImageGenerator] Missing dir \(gymDir.path)")
                }
                if !eggDir.exists {
                    Log.info(message: "[ImageGenerator] Missing dir \(eggDir.path)")
                }
                if !unkownEggDir.exists {
                    Log.info(message: "[ImageGenerator] Missing dir \(unkownEggDir.path)")
                }
                if !pokemonDir.exists {
                    Log.info(message: "[ImageGenerator] Missing dir \(pokemonDir.path)")
                }
            }
            if questDir.exists && itemDir.exists && pokestopDir.exists && pokemonDir.exists {

                Log.info(message: "[ImageGenerator] Creating Quest Images...")

                try! FileManager.default.contentsOfDirectory(atPath: pokestopDir.path).forEach { (pokestopFilename) in
                    if !pokestopFilename.contains(".png") {
                        Log.debug(message: "[ImageGenerator] \(pokestopFilename) is not png! Skipping...")
                        return
                    }
                    let pokestopFile = File(pokestopDir.path + pokestopFilename)
                    let pokestopId = pokestopFilename.replacingOccurrences(of: ".png", with: "")

                    try! FileManager.default.contentsOfDirectory(atPath: itemDir.path).forEach { (itemFilename) in
                        if !itemFilename.contains(".png") {
                            Log.debug(message: "[ImageGenerator] \(itemFilename) is not png! Skipping...")
                            return
                        }
                        let itemFile = File(itemDir.path + itemFilename)
                        let itemId = itemFilename.replacingOccurrences(of: ".png", with: "")
                        let newFile = File(questDir.path + pokestopId + "_i" + itemId + ".png")
                        if !newFile.exists {
                            Log.debug(
                                message: "[ImageGenerator] Creating quest for stop \(pokestopId) and item \(itemId)"
                            )
                            combineImages(image1: itemFile.path, image2: pokestopFile.path,
                                          method: composeMethod, output: newFile.path)
                        }
                    }

                    try! FileManager.default.contentsOfDirectory(atPath: pokemonDir.path).forEach { (pokemonFilename) in
                        if !pokemonFilename.contains(".png") {
                            Log.debug(message: "[ImageGenerator] \(pokemonFilename) is not png! Skipping...")
                            return
                        }
                        let pokemonFile = File(pokemonDir.path + pokemonFilename)
                        let pokemonId = pokemonFilename.replacingOccurrences(of: ".png", with: "")
                        let newFile = File(questDir.path + pokestopId + "_p" + pokemonId + ".png")
                        if !newFile.exists {
                            Log.debug(
                                message: "[ImageGenerator] Creating quest for stop \(pokestopId) " +
                                         "and pokemon \(pokemonId)"
                            )
                            combineImages(image1: pokemonFile.path, image2: pokestopFile.path,
                                          method: composeMethod, output: newFile.path)
                        }
                    }
                }

                Log.info(message: "[ImageGenerator] Quest images created.")
            } else {
                Log.warning(message: "[ImageGenerator] Not generating Quest Images (missing Dirs)")
                if !questDir.exists {
                    Log.info(message: "[ImageGenerator] Missing dir \(questDir.path)")
                }
                if !itemDir.exists {
                    Log.info(message: "[ImageGenerator] Missing dir \(itemDir.path)")
                }
                if !pokestopDir.exists {
                    Log.info(message: "[ImageGenerator] Missing dir \(pokestopDir.path)")
                }
                if !pokemonDir.exists {
                    Log.info(message: "[ImageGenerator] Missing dir \(pokemonDir.path)")
                }
            }

            if gruntDir.exists, pokestopDir.exists {
                Log.info(message: "[ImageGenerator] Creating Invasion Images...")
                try! FileManager.default.contentsOfDirectory(atPath: pokestopDir.path).forEach { (pokestopFilename) in
                    if !pokestopFilename.contains(".png") {
                        Log.debug(message: "[ImageGenerator] \(pokestopFilename) is not png! Skipping...")
                        return
                    } else if !pokestopFilename.hasPrefix("i") {
                        return
                    }
                    let pokestopFile = File(pokestopDir.path + pokestopFilename)
                    let pokestopId = pokestopFilename.replacingOccurrences(of: ".png", with: "")

                    try! FileManager.default.contentsOfDirectory(atPath: gruntDir.path).forEach { (gruntFilename) in
                        if !gruntFilename.contains(".png") {
                            Log.debug(message: "[ImageGenerator] \(gruntFilename) is not png! Skipping...")
                            return
                        }
                        let gruntFile = File(gruntDir.path + gruntFilename)
                        let gruntId = gruntFilename.replacingOccurrences(of: ".png", with: "")
                        let newFile = File(invasionDir.path + pokestopId + "_" + gruntId + ".png")
                        if !newFile.exists {
                            Log.debug(
                                message: "[ImageGenerator] Creating invasion for stop \(pokestopId) " +
                                         "and grunt \(gruntId)"
                            )
                            combineImagesGrunt(image1: pokestopFile.path, image2: gruntFile.path, output: newFile.path)
                        }
                    }
                }
                Log.info(message: "[ImageGenerator] Invasion images created.")
            } else {
                Log.warning(message: "[ImageGenerator] Not generating Invasion Images (missing Dirs)")
                if !gruntDir.exists {
                    Log.info(message: "[ImageGenerator] Missing dir \(gruntDir.path)")
                }
                if !pokestopDir.exists {
                    Log.info(message: "[ImageGenerator] Missing dir \(pokestopDir.path)")
                }
            }

            if gruntDir.exists, questDir.exists {
                Log.info(message: "[ImageGenerator] Creating Quest Invasion Images...")
                try! FileManager.default.contentsOfDirectory(atPath: questDir.path).forEach { (questFilename) in
                    if !questFilename.contains(".png") {
                        Log.debug(message: "[ImageGenerator] \(questFilename) is not png! Skipping...")
                        return
                    } else if !questFilename.hasPrefix("i") {
                        return
                    }
                    let questFile = File(questDir.path + questFilename)
                    let questId = questFilename.replacingOccurrences(of: ".png", with: "")

                    try! FileManager.default.contentsOfDirectory(atPath: gruntDir.path).forEach { (gruntFilename) in
                        if !gruntFilename.contains(".png") {
                            Log.debug(message: "[ImageGenerator] \(gruntFilename) is not png! Skipping...")
                            return
                        }
                        let gruntFile = File(gruntDir.path + gruntFilename)
                        let gruntId = gruntFilename.replacingOccurrences(of: ".png", with: "")
                        let newFile = File(questInvasionDir.path + questId + "_" + gruntId + ".png")
                        if !newFile.exists {
                            Log.debug(
                                message: "[ImageGenerator] Creating invasion for quest \(questId) and grunt \(gruntId)"
                            )
                            combineImagesGruntQuest(image1: questFile.path, image2: gruntFile.path,
                                                    output: newFile.path)
                        }
                    }
                }
                Log.info(message: "[ImageGenerator] Quest Invasion images created.")
            } else {
                Log.warning(message: "[ImageGenerator] Not generating Quest Invasion Images (missing Dirs)")
                if !gruntDir.exists {
                    Log.info(message: "[ImageGenerator] Missing dir \(gruntDir.path)")
                }
                if !questDir.exists {
                    Log.info(message: "[ImageGenerator] Missing dir \(questDir.path)")
                }
            }

            Log.info(message: "[ImageGenerator] Done")
            Threading.destroyQueue(thread)

        }
    }
    //  swiftlint:enable force_try

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
