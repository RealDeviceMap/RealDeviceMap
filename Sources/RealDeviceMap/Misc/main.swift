//
//  main.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//
//  swiftlint:disable force_try

import Foundation
import PerfectLib
import PerfectThread
import PerfectHTTPServer
import TurnstileCrypto
import POGOProtos

#if DEBUG
let projectroot = ProcessInfo.processInfo.environment["PROJECT_DIR"] ?? Dir.workingDir.path
#else
let projectroot = Dir.workingDir.path
#endif

// Starting Startup Webserver
Log.debug(message: "[MAIN] Starting Startup Webserver")
var startupServer: HTTPServer.Server? = WebServer.startupServer
var startupServerContext: HTTPServer.LaunchContext? = try! HTTPServer.launch(wait: false, startupServer!)[0]

// Check if /backups exists
let backups = Dir("\(projectroot)/backups")
#if DEBUG
try? backups.create()
#endif
if !backups.exists {
    let message = "[MAIN] Backups directory doesn't exist! Make sure to persist the backups folder before continuing."
    Log.critical(message: message)
    fatalError(message)
}

// Init DBController
Log.debug(message: "[MAIN] Starting Database Controller")
_ = DBController.global

// Load Groups
Log.debug(message: "[MAIN] Loading groups")
do {
    try Group.setup()
} catch {
    let message = "[MAIN] Failed to load groups (\(error.localizedDescription))"
    Log.critical(message: message)
    fatalError(message)
}

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
WebReqeustHandler.minZoom = try! DBController.global.getValueForKey(key: "MAP_MIN_ZOOM")?.toInt() ?? 10
WebReqeustHandler.maxZoom = try! DBController.global.getValueForKey(key: "MAP_MAX_ZOOM")?.toInt() ?? 18
WebReqeustHandler.maxPokemonId = try! DBController.global.getValueForKey(key: "MAP_MAX_POKEMON_ID")!.toInt()!
WebReqeustHandler.title = try! DBController.global.getValueForKey(key: "TITLE") ?? "RealDeviceMap"
WebReqeustHandler.enableRegister = try! DBController.global.getValueForKey(key: "ENABLE_REGISTER")?.toBool() ?? true
WebReqeustHandler.cities = try! DBController.global.getValueForKey(key: "CITIES")?
    .jsonDecodeForceTry() as? [String: [String: Any]] ?? [String: [String: Any]]()
WebReqeustHandler.googleAnalyticsId = try! DBController.global.getValueForKey(key: "GOOGLE_ANALYTICS_ID") ?? ""
WebReqeustHandler.googleAdSenseId = try! DBController.global.getValueForKey(key: "GOOGLE_ADSENSE_ID") ?? ""
WebReqeustHandler.oauthDiscordRedirectURL = try! DBController.global.getValueForKey(key: "DISCORD_REDIRECT_URL")?
    .emptyToNil()
WebReqeustHandler.oauthDiscordClientID = try! DBController.global.getValueForKey(key: "DISCORD_CLIENT_ID")?.emptyToNil()
WebReqeustHandler.oauthDiscordClientSecret = try! DBController.global.getValueForKey(key: "DISCORD_CLIENT_SECRET")?
    .emptyToNil()
WebReqeustHandler.statsUrl = try! DBController.global.getValueForKey(key: "STATS_URL") ?? ""
WebHookRequestHandler.hostWhitelist = try! DBController.global.getValueForKey(key: "DEVICEAPI_HOST_WHITELIST")?
    .emptyToNil()?.components(separatedBy: ";")
WebHookRequestHandler.hostWhitelistUsesProxy = try! DBController.global.getValueForKey(
    key: "DEVICEAPI_HOST_WHITELIST_USES_PROXY"
)?.toBool() ?? false
WebHookRequestHandler.loginSecret = try! DBController.global.getValueForKey(key: "DEVICEAPI_SECRET")?.emptyToNil()
WebHookRequestHandler.dittoDisguises = try! DBController.global.getValueForKey(key: "DITTO_DISGUISES")?
    .components(separatedBy: ",").map({ (string) -> UInt16 in
    return string.toUInt16() ?? 0
}) ?? [13, 46, 48, 163, 165, 167, 187, 223, 273, 293, 300, 316, 322, 399] //Default ditto disguises
WebReqeustHandler.buttonsLeft = try! DBController.global.getValueForKey(key: "BUTTONS_LEFT")?
    .jsonDecode() as? [[String: String]] ?? []
WebReqeustHandler.buttonsRight = try! DBController.global.getValueForKey(key: "BUTTONS_RIGHT")?
    .jsonDecode() as? [[String: String]] ?? []

if let tileserversOld = try! DBController.global.getValueForKey(key: "TILESERVERS")?
    .jsonDecodeForceTry() as? [String: String] {
    var tileservers = [String: [String: String]]()
    for tileserver in tileserversOld {
        tileservers[tileserver.key] = [
            "url": tileserver.value,
            "attribution": "Map data &copy; <a href=\"https://www.openstreetmap.org/\">OpenStreetMap</a> contributors"
        ]
    }
    WebReqeustHandler.tileservers = tileservers
} else {
    WebReqeustHandler.tileservers = try! DBController.global.getValueForKey(key: "TILESERVERS")?
        .jsonDecodeForceTry() as? [String: [String: String]] ?? [
            "Default": [
                "url": "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                "attribution": "Map data &copy; <a href=\"https://www.openstreetmap.org/\">" +
                               "OpenStreetMap</a> contributors"
            ]
        ]
}

Localizer.locale = try! DBController.global.getValueForKey(key: "LOCALE")?.lowercased() ?? "en"

Pokemon.defaultTimeUnseen = try! DBController.global.getValueForKey(key: "POKEMON_TIME_UNSEEN")?.toUInt32() ?? 1200
Pokemon.defaultTimeReseen = try! DBController.global.getValueForKey(key: "POKEMON_TIME_RESEEN")?.toUInt32() ?? 600

Pokestop.lureTime = try! DBController.global.getValueForKey(key: "POKESTOP_LURE_TIME")?.toUInt32() ?? 1800

Gym.exRaidBossId = try! DBController.global.getValueForKey(key: "GYM_EX_BOSS_ID")?.toUInt16()
Gym.exRaidBossForm = try! DBController.global.getValueForKey(key: "GYM_EX_BOSS_FORM")?.toUInt16()

WebHookRequestHandler.enableClearing = try! DBController.global.getValueForKey(key: "ENABLE_CLEARING")?
    .toBool() ?? false

DiscordController.global.guilds = try! DBController.global.getValueForKey(key: "DISCORD_GUILD_IDS")?
    .components(separatedBy: ";").map({ (string) -> UInt64 in
    return string.toUInt64() ?? 0
}) ?? [UInt64]()
DiscordController.global.token = try! DBController.global.getValueForKey(key: "DISCORD_TOKEN") ?? ""

MailController.clientURL = try! DBController.global.getValueForKey(key: "MAILER_URL")
MailController.clientUsername = try! DBController.global.getValueForKey(key: "MAILER_USERNAME")
MailController.clientPassword = try! DBController.global.getValueForKey(key: "MAILER_PASSWORD")
MailController.fromAddress = try! DBController.global.getValueForKey(key: "MAILER_EMAIL")
MailController.fromName = try! DBController.global.getValueForKey(key: "MAILER_NAME")
MailController.footerHtml = try! DBController.global.getValueForKey(key: "MAILER_FOOTER_HTML") ?? ""
MailController.baseURI = try! DBController.global.getValueForKey(key: "MAILER_BASE_URI") ?? ""

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
do {
    try Dir("\(projectroot)/resources/webroot/static/img/pokemon").forEachEntry { (file) in
        let split = file.replacingOccurrences(of: ".png", with: "").components(separatedBy: "-")
        if split.count == 2, let pokemonID = Int(split[0]), let formID = Int(split[1]) {
            avilableForms.append("\(pokemonID)-\(formID)")
        }
    }
    WebReqeustHandler.avilableFormsJson = try avilableForms.jsonEncodedString()
} catch {
    Log.error(message: "Failed to load forms. Frontend will only display default forms. Error: \(error)")
}

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

// Start MailController
Log.debug(message: "[MAIL] Starting Mail Controller")
try! MailController.global.setup()

// Start DiscordController
Log.debug(message: "[MAIL] Starting Discord Controller")
try! DiscordController.global.setup()

// Create Raid images
Log.debug(message: "[MAIN] Starting Images Generator")
ImageGenerator.generate()

// Stopping Startup Webserver
Log.debug(message: "[MAIN] Stopping Startup Webserver")
startupServerContext!.terminate()
startupServer = nil
startupServerContext = nil

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
