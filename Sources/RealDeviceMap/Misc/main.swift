//
//  main.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//

import Foundation
import PerfectLib
import PerfectThread
import PerfectHTTPServer
import TurnstileCrypto

func shell(_ args: String...) -> Int32 {
    let task = Process()
    task.launchPath = "/usr/bin/env"
    task.arguments = args
    task.launch()
    task.waitUntilExit()
    return task.terminationStatus
}

func combineImages(image1: String, image2: String, output: String) {
    _ = shell("/usr/local/bin/convert", image1, "-background", "none", "-resize", "96x96", "-gravity", "north", "-extent", "96x160", "tmp1.png")
    _ = shell("/usr/local/bin/convert", image2, "-background", "none", "-resize", "96x96", "-gravity", "south", "-extent", "96x160", "tmp2.png")
    _ = shell("/usr/local/bin/convert", "tmp1.png", "tmp2.png", "-gravity", "center", "-compose", "over", "-composite", output)
    _ = shell("rm", "-f", "tmp1.png")
    _ = shell("rm", "-f", "tmp2.png")
}

// Init DBController
_ = DBController.global


// Init Instance Contoller
do {
    try InstanceController.setup()
} catch {
    let message = "[MAIN] Failed to setup InstanceController"
    Log.error(message: message)
    fatalError(message)
}


// Load Settings
WebReqeustHandler.startLat = try! DBController.global.getValueForKey(key: "MAP_START_LAT")!.toDouble()!
WebReqeustHandler.startLon = try! DBController.global.getValueForKey(key: "MAP_START_LON")!.toDouble()!
WebReqeustHandler.startZoom = try! DBController.global.getValueForKey(key: "MAP_START_ZOOM")!.toInt()!
WebReqeustHandler.maxPokemonId = try! DBController.global.getValueForKey(key: "MAP_MAX_POKEMON_ID")!.toInt()!
WebReqeustHandler.title = try! DBController.global.getValueForKey(key: "TITLE") ?? "RealDeviceMap"

// Check if is setup
let isSetup: String?
do {
    isSetup = try DBController.global.getValueForKey(key: "IS_SETUP")
} catch {
    let message = "Failed to get setup status."
    Log.critical(message: "[Main] " + message)
    fatalError(message)
}

if isSetup != nil && isSetup == "true" {
    WebReqeustHandler.isSetup = true
} else {
    WebReqeustHandler.isSetup = false
    WebReqeustHandler.accessToken = URandom().secureToken
    Log.info(message: "[Main] Use this access-token to create the admin user: \(WebReqeustHandler.accessToken!)")
}

// Create Raid images
let raidDir = Dir("resources/webroot/static/img/raid/")
let gymDir = Dir("resources/webroot/static/img/gym/")
let eggDir = Dir("resources/webroot/static/img/egg/")
let unkownEggDir = Dir("resources/webroot/static/img/unkown_egg/")
let pokemonDir = Dir("resources/webroot/static/img/pokemon/")
if !raidDir.exists {
    try! raidDir.create()
}
let doneLock = File(raidDir.path + "done.lock")
if !doneLock.exists && raidDir.exists && gymDir.exists && eggDir.exists && unkownEggDir.exists && pokemonDir.exists {
    
    let thread = Threading.getQueue(type: .serial)
    thread.dispatch {
        
        Log.info(message: "[Main] Creating raid images...")
        
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
                    Log.debug(message: "[Main] Creating image for gym \(gymId) and egg \(eggLevel)")
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
                    Log.debug(message: "[Main] Creating image for gym \(gymId) and unkown egg \(eggLevel)")
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
                    Log.debug(message: "[Main] Creating image for gym \(gymId) and pokemon \(pokemonId)")
                    combineImages(image1: pokemonFile.path, image2: gymFile.path, output: newFile.path)
                }
            }
        }
        
        Log.info(message: "[Main] Raid images created.")
        try! doneLock.open(.readWrite)
        try! doneLock.write(string: "done")
        Threading.destroyQueue(thread)
    }
}

do {
    try HTTPServer.launch(
        [
            WebServer.server,
            WebHookServer.server
        ]
    )
} catch {
    let message = "Failed to launch Servers: \(error)"
    Log.critical(message: message)
    fatalError(message)
}
