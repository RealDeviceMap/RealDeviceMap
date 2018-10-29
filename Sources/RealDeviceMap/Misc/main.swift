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
import POGOProtos

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

// Start WebHookController
WebHookController.global.start()

// Load Forms
var avilableForms = [String]()
for formString in POGOProtos_Enums_Form.allFormsInString {
    let file = File("resources/webroot/static/img/pokemon/\(formString).png")
    if file.exists {
        avilableForms.append(formString)
    }
}
WebReqeustHandler.avilableFormsJson = try! avilableForms.jsonEncodedString()

// Load timezone
if let result = Shell("date", "+%z").run()?.replacingOccurrences(of: "\n", with: "") {
    let sign = result.substring(toIndex: 1)
    if let hours = Int(result.substring(toIndex: 3).substring(fromIndex: 1)),
       let mins = Int(result.substring(toIndex: 5).substring(fromIndex: 3)) {
        let offset: Int
        if sign == "-" {
            offset = -hours * 3600 + mins * 60
        } else {
            offset = hours * 3600 + mins * 60
        }
        if let timeZone = TimeZone(secondsFromGMT: offset) {
            Localizer.global.timeZone = timeZone
        }
    }
}

// Load Settings
WebReqeustHandler.startLat = try! DBController.global.getValueForKey(key: "MAP_START_LAT")!.toDouble()!
WebReqeustHandler.startLon = try! DBController.global.getValueForKey(key: "MAP_START_LON")!.toDouble()!
WebReqeustHandler.startZoom = try! DBController.global.getValueForKey(key: "MAP_START_ZOOM")!.toInt()!
WebReqeustHandler.maxPokemonId = try! DBController.global.getValueForKey(key: "MAP_MAX_POKEMON_ID")!.toInt()!
WebReqeustHandler.title = try! DBController.global.getValueForKey(key: "TITLE") ?? "RealDeviceMap"
Localizer.locale = try! DBController.global.getValueForKey(key: "LOCALE")?.lowercased() ?? "en"

Pokemon.defaultTimeUnseen = try! DBController.global.getValueForKey(key: "POKEMON_TIME_UNSEEN")?.toUInt32() ?? 1200
Pokemon.defaultTimeReseen = try! DBController.global.getValueForKey(key: "POKEMON_TIME_RESEEN")?.toUInt32() ?? 600

let webhookDelayString = try! DBController.global.getValueForKey(key: "WEBHOOK_DELAY") ?? "5.0"
let webhookUrlStrings = try! DBController.global.getValueForKey(key: "WEBHOOK_URLS") ?? ""
if let webhookDelay = Double(webhookDelayString) {
    WebHookController.global.webhookSendDelay = webhookDelay
}
WebHookController.global.webhookURLStrings = webhookUrlStrings.components(separatedBy: ";")

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
ImageGenerator.generate()

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
