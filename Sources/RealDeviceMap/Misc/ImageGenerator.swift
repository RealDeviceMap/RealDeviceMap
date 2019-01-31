//
//  ImageGenerator.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 29.10.18.
//

import Foundation
import PerfectLib
import PerfectThread

class ImageGenerator {
    
    private init() {}
    
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
        let itemDir = Dir("\(projectroot)/resources/webroot/static/img/item/")
        let questDir = Dir("\(projectroot)/resources/webroot/static/img/quest/")
        if !raidDir.exists {
            try! raidDir.create()
        }
        if !questDir.exists {
            try! questDir.create()
        }
        
        let thread = Threading.getQueue(type: .serial)
        thread.dispatch {
            
            if raidDir.exists && gymDir.exists && eggDir.exists && unkownEggDir.exists && pokemonDir.exists {
                
                Log.info(message: "[ImageGenerator] Creating Raid Images...")
                
                try! gymDir.forEachEntry { (gymFilename) in
                    if !gymFilename.contains(".png") {
                        return
                    }
                    let gymFile = File(gymDir.path + gymFilename)
                    let gymId = gymFilename.replacingOccurrences(of: ".png", with: "")
                    
                    try! eggDir.forEachEntry { (eggFilename) in
                        if !eggFilename.contains(".png") {
                            return
                        }
                        let eggFile = File(eggDir.path + eggFilename)
                        let eggLevel = eggFilename.replacingOccurrences(of: ".png", with: "")
                        let newFile = File(raidDir.path + gymId + "_e" + eggLevel + ".png")
                        if !newFile.exists {
                            Log.debug(message: "[ImageGenerator] Creating image for gym \(gymId) and egg \(eggLevel)")
                            combineImages(image1: eggFile.path, image2: gymFile.path, output: newFile.path)
                        }
                    }
                    try! unkownEggDir.forEachEntry { (unkownEggFilename) in
                        if !unkownEggFilename.contains(".png") {
                            return
                        }
                        let unkownEggFile = File(unkownEggDir.path + unkownEggFilename)
                        let eggLevel = unkownEggFilename.replacingOccurrences(of: ".png", with: "")
                        let newFile = File(raidDir.path + gymId + "_ue" + eggLevel + ".png")
                        if !newFile.exists {
                            Log.debug(message: "[ImageGenerator] Creating image for gym \(gymId) and unkown egg \(eggLevel)")
                            combineImages(image1: unkownEggFile.path, image2: gymFile.path, output: newFile.path)
                        }
                    }
                    try! pokemonDir.forEachEntry { (pokemonFilename) in
                        if !pokemonFilename.contains(".png") {
                            return
                        }
                        let pokemonFile = File(pokemonDir.path + pokemonFilename)
                        let pokemonId = pokemonFilename.replacingOccurrences(of: ".png", with: "")
                        let newFile = File(raidDir.path + gymId + "_" + pokemonId + ".png")
                        if !newFile.exists {
                            Log.debug(message: "[ImageGenerator] Creating image for gym \(gymId) and pokemon \(pokemonId)")
                            combineImages(image1: pokemonFile.path, image2: gymFile.path, output: newFile.path)
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
                
                try! pokestopDir.forEachEntry { (pokestopFilename) in
                    if !pokestopFilename.contains(".png") {
                        return
                    }
                    let pokestopFile = File(pokestopDir.path + pokestopFilename)
                    let pokestopId = pokestopFilename.replacingOccurrences(of: ".png", with: "")
                    
                    try! itemDir.forEachEntry { (itemFilename) in
                        if !itemFilename.contains(".png") {
                            return
                        }
                        let itemFile = File(itemDir.path + itemFilename)
                        let itemId = itemFilename.replacingOccurrences(of: ".png", with: "")
                        let newFile = File(questDir.path + pokestopId + "_i" + itemId + ".png")
                        if !newFile.exists {
                            Log.debug(message: "[ImageGenerator] Creating quest for stop \(pokestopId) and item \(itemId)")
                            combineImages(image1: itemFile.path, image2: pokestopFile.path, output: newFile.path)
                        }
                    }
                    
                    try! pokemonDir.forEachEntry { (pokemonFilename) in
                        if !pokemonFilename.contains(".png") {
                            return
                        }
                        let pokemonFile = File(pokemonDir.path + pokemonFilename)
                        let pokemonId = pokemonFilename.replacingOccurrences(of: ".png", with: "")
                        let newFile = File(questDir.path + pokestopId + "_p" + pokemonId + ".png")
                        if !newFile.exists {
                            Log.debug(message: "[ImageGenerator] Creating quest for stop \(pokestopId) and pokemon \(pokemonId)")
                            combineImages(image1: pokemonFile.path, image2: pokestopFile.path, output: newFile.path)
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
            
            Threading.destroyQueue(thread)

            
        }
    }
    
    private static func combineImages(image1: String, image2: String, output: String) {
        _ = Shell("/usr/local/bin/convert", image1, "-background", "none", "-resize", "96x96", "-gravity", "north", "-extent", "96x160", "tmp1.png").run()
        _ = Shell("/usr/local/bin/convert", image2, "-background", "none", "-resize", "96x96", "-gravity", "south", "-extent", "96x160", "tmp2.png").run()
        _ = Shell("/usr/local/bin/convert", "tmp1.png", "tmp2.png", "-gravity", "center", "-compose", "over", "-composite", output).run()
        _ = Shell("rm", "-f", "tmp1.png").run()
        _ = Shell("rm", "-f", "tmp2.png").run()
    }
    
}
