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


// Check if /backups exists
let backups = Dir("backups")
if !backups.exists {
    let message = "[MAIN] Backups directory doesn't exist! Make sure to persist the backups folder before continuing."
    Log.critical(message: message)
    fatalError(message)
}

// Init DBController
Log.debug(message: "[MAIN] Starting Database Controller")
_ = DBController.global

// Load timezone
Log.debug(message: "[MAIN] Loading Timezone")
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
Log.debug(message: "[MAIN] Loading Settings")
WebReqeustHandler.startLat = try! DBController.global.getValueForKey(key: "MAP_START_LAT")!.toDouble()!
WebReqeustHandler.startLon = try! DBController.global.getValueForKey(key: "MAP_START_LON")!.toDouble()!
WebReqeustHandler.startZoom = try! DBController.global.getValueForKey(key: "MAP_START_ZOOM")!.toInt()!
WebReqeustHandler.maxPokemonId = try! DBController.global.getValueForKey(key: "MAP_MAX_POKEMON_ID")!.toInt()!
WebReqeustHandler.title = try! DBController.global.getValueForKey(key: "TITLE") ?? "RealDeviceMap"
WebReqeustHandler.enableRegister = try! DBController.global.getValueForKey(key: "ENABLE_REGISTER")?.toBool() ?? true
WebReqeustHandler.tileservers = try! DBController.global.getValueForKey(key: "TILESERVERS")?.jsonDecodeForceTry() as? [String: String] ?? ["Default": "https://tile.openstreetmap.org/{z}/{x}/{y}.png"]


Localizer.locale = try! DBController.global.getValueForKey(key: "LOCALE")?.lowercased() ?? "en"

Pokemon.defaultTimeUnseen = try! DBController.global.getValueForKey(key: "POKEMON_TIME_UNSEEN")?.toUInt32() ?? 1200
Pokemon.defaultTimeReseen = try! DBController.global.getValueForKey(key: "POKEMON_TIME_RESEEN")?.toUInt32() ?? 600

WebHookRequestHandler.enableClearing = try! DBController.global.getValueForKey(key: "ENABLE_CLEARING")?.toBool() ?? false

let webhookDelayString = try! DBController.global.getValueForKey(key: "WEBHOOK_DELAY") ?? "5.0"
let webhookUrlStrings = try! DBController.global.getValueForKey(key: "WEBHOOK_URLS") ?? ""
if let webhookDelay = Double(webhookDelayString) {
    WebHookController.global.webhookSendDelay = webhookDelay
}

// Init Instance Contoller
do {
    Log.debug(message: "[MAIN] Starting Instance Controller")
    try InstanceController.setup()
} catch {
    let message = "[MAIN] Failed to setup InstanceController"
    Log.critical(message: message)
    fatalError(message)
}

// Start WebHookController
Log.debug(message: "[MAIN] Starting Webhook Controller")
WebHookController.global.start()

// Load Forms
Log.debug(message: "[MAIN] Loading Avilable Forms")
var avilableForms = [String]()
for formString in POGOProtos_Enums_Form.allFormsInString {
    let file = File("resources/webroot/static/img/pokemon/\(formString).png")
    if file.exists {
        avilableForms.append(formString)
    }
}
WebReqeustHandler.avilableFormsJson = try! avilableForms.jsonEncodedString()

Log.debug(message: "[MAIN] Loading Avilable Items")
var aviableItems = [-3, -2, -1]
for itemId in POGOProtos_Inventory_Item_ItemId.allAvilable {
    aviableItems.append(itemId.rawValue)
}
WebReqeustHandler.avilableItemJson = try! aviableItems.jsonEncodedString()

Log.debug(message: "[MAIN] Starting Webhook")
WebHookController.global.webhookURLStrings = webhookUrlStrings.components(separatedBy: ";")

Log.debug(message: "[MAIN] Starting Account Controller")
AccountController.global.setup()

Log.debug(message: "[MAIN] Starting Assignement Controller")
do {
    try AssignmentController.global.setup()
} catch {
    let message = "[MAIN] Failed to start Assignement Controller"
    Log.critical(message: message)
    fatalError(message)
}

// Check if is setup
Log.debug(message: "[MAIN] Checking if setup is completed")
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
    Log.debug(message: "[Main] Use this access-token to create the admin user: \(WebReqeustHandler.accessToken!)")
}

// Create Raid images
Log.debug(message: "[MAIN] Starting Images Generator")
ImageGenerator.generate()

Log.debug(message: "[MAIN] Starting Webserves")
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
