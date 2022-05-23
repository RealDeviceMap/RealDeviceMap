//
//  setup.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 18.09.18.
//
//  swiftlint:disable force_try cyclomatic_complexity function_body_length

import Foundation
import PerfectLib
import PerfectThread
import PerfectHTTPServer
import TurnstileCrypto
import POGOProtos
import Backtrace

public func setupRealDeviceMap() {
    _ = ConfigLoader.global
    let logLevel: String = ConfigLoader.global.getConfig(type: .logLevel)
    Log.even = true
    Log.setThreshold(value: logLevel)

    if ProcessInfo.processInfo.environment["NO_INSTALL_BACKTRACE"] == nil {
        Log.info(message: "[MAIN] Installing Backtrace")
        Backtrace.install()
    }

    Log.info(message: "[MAIN] Getting Version")
    _ = VersionManager.global

    // Starting Startup Webserver
    Log.info(message: "[MAIN] Starting Startup Webserver")
    var startupServer: HTTPServer.Server? = WebServer.startupServer
    var startupServerContext: HTTPServer.LaunchContext? = try! HTTPServer.launch(wait: false, startupServer!)[0]

    // Check if /backups exists
    let backups = Dir("\(Dir.projectroot)/backups")
    #if DEBUG
    try? backups.create()
    #endif
    if !backups.exists {
        let message = "[MAIN] Backups directory doesn't exist! " +
                      "Make sure to persist the backups folder before continuing."
        Log.critical(message: message)
        fatalError(message)
    }

    // Init DBController
    Log.info(message: "[MAIN] Starting Database Controller")
    _ = DBController.global

    // Init MemoryCache
    let memoryCacheEnabled: Bool = ConfigLoader.global.getConfig(type: .memoryCacheEnabled)
    let memoryCacheClearInterval = Double(ConfigLoader.global.getConfig(type: .memoryCacheClearInterval) as Int)
    let memoryCacheKeepTime = Double(ConfigLoader.global.getConfig(type: .memoryCacheKeepTime) as Int)
    if memoryCacheEnabled {
        Log.info(message:
            "[MAIN] Starting Memory Cache with interval \(memoryCacheClearInterval) " +
            "and keep time \(memoryCacheKeepTime)"
        )
        Pokestop.cache = MemoryCache(interval: memoryCacheClearInterval, keepTime: memoryCacheKeepTime)
        Pokemon.cache = MemoryCache(interval: memoryCacheClearInterval, keepTime: memoryCacheKeepTime)
        Gym.cache = MemoryCache(interval: memoryCacheClearInterval, keepTime: memoryCacheKeepTime)
        SpawnPoint.cache = MemoryCache(interval: memoryCacheClearInterval, keepTime: memoryCacheKeepTime)
        Weather.cache = MemoryCache(interval: memoryCacheClearInterval, keepTime: memoryCacheKeepTime)
        Incident.cache = MemoryCache(interval: memoryCacheClearInterval, keepTime: memoryCacheKeepTime)
    } else {
        Log.info(message: "[MAIN] Memory Cache deactivated")
    }

    // Load Groups
    Log.info(message: "[MAIN] Loading Groups")
    do {
        try Group.setup()
    } catch {
        let message = "[MAIN] Failed to load groups (\(error.localizedDescription))"
        Log.critical(message: message)
        fatalError(message)
    }

    // Load locales
    Log.info(message: "[MAIN] Loading Locales")
    Localizer.locale = try! DBController.global.getValueForKey(key: "LOCALE")?.lowercased() ?? "en"

    // Load timezone
    Log.info(message: "[MAIN] Loading Timezone")
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
    Log.info(message: "[MAIN] Loading Settings")
    WebRequestHandler.startLat = try! DBController.global.getValueForKey(key: "MAP_START_LAT")!.toDouble()!
    WebRequestHandler.startLon = try! DBController.global.getValueForKey(key: "MAP_START_LON")!.toDouble()!
    WebRequestHandler.startZoom = try! DBController.global.getValueForKey(key: "MAP_START_ZOOM")!.toInt()!
    WebRequestHandler.minZoom = try! DBController.global.getValueForKey(key: "MAP_MIN_ZOOM")?.toInt() ?? 10
    WebRequestHandler.maxZoom = try! DBController.global.getValueForKey(key: "MAP_MAX_ZOOM")?.toInt() ?? 18
    WebRequestHandler.maxPokemonId = try! DBController.global.getValueForKey(key: "MAP_MAX_POKEMON_ID")!.toInt()!
    WebRequestHandler.title = try! DBController.global.getValueForKey(key: "TITLE") ?? "RealDeviceMap"
    WebRequestHandler.enableRegister = try! DBController.global.getValueForKey(key: "ENABLE_REGISTER")?.toBool() ?? true
    let tmpCities = try! DBController.global.getValueForKey(key: "CITIES")
    WebRequestHandler.cities = tmpCities?
        .jsonDecodeForceTry() as? [String: [String: Any]] ?? [String: [String: Any]]()
    WebRequestHandler.citiesLowerCased = tmpCities?.lowercased()
        .jsonDecodeForceTry() as? [String: [String: Any]] ?? [String: [String: Any]]()
    WebRequestHandler.googleAnalyticsId = try! DBController.global.getValueForKey(key: "GOOGLE_ANALYTICS_ID") ?? ""
    WebRequestHandler.googleAdSenseId = try! DBController.global.getValueForKey(key: "GOOGLE_ADSENSE_ID") ?? ""
    WebRequestHandler.oauthDiscordRedirectURL = try! DBController.global.getValueForKey(key: "DISCORD_REDIRECT_URL")?
        .emptyToNil()
    WebRequestHandler.oauthDiscordClientID = try! DBController.global.getValueForKey(key: "DISCORD_CLIENT_ID")?
        .emptyToNil()
    WebRequestHandler.oauthDiscordClientSecret = try! DBController.global.getValueForKey(key: "DISCORD_CLIENT_SECRET")?
        .emptyToNil()
    WebRequestHandler.statsUrl = try! DBController.global.getValueForKey(key: "STATS_URL") ?? ""
    WebHookRequestHandler.hostWhitelist = try! DBController.global.getValueForKey(key: "DEVICEAPI_HOST_WHITELIST")?
        .emptyToNil()?.components(separatedBy: ";")
    WebHookRequestHandler.hostWhitelistUsesProxy = try! DBController.global.getValueForKey(
        key: "DEVICEAPI_HOST_WHITELIST_USES_PROXY"
    )?.toBool() ?? false
    WebHookRequestHandler.loginSecret = try! DBController.global.getValueForKey(key: "DEVICEAPI_SECRET")?.emptyToNil()
    WebHookRequestHandler.dittoDisguises = try! DBController.global.getValueForKey(key: "DITTO_DISGUISES")?
        .components(separatedBy: ",").map({ (string) -> UInt16 in
        return string.toUInt16() ?? 0
    }) ?? [13, 46, 48, 163, 165, 167, 187, 223, 273, 293, 300, 316, 322, 399] // Default ditto disguises
    WebRequestHandler.buttonsLeft = try! DBController.global.getValueForKey(key: "BUTTONS_LEFT")?
        .jsonDecode() as? [[String: String]] ?? []
    WebRequestHandler.buttonsRight = try! DBController.global.getValueForKey(key: "BUTTONS_RIGHT")?
        .jsonDecode() as? [[String: String]] ?? []

    if let tileserversOld = try! DBController.global.getValueForKey(key: "TILESERVERS")?
        .jsonDecodeForceTry() as? [String: String] {
        var tileservers = [String: [String: String]]()
        for tileserver in tileserversOld {
            tileservers[tileserver.key] = [
                "url": tileserver.value,
                "attribution": "Map data &copy; " +
                               "<a href=\"https://www.openstreetmap.org/\">OpenStreetMap</a> contributors"
            ]
        }
        WebRequestHandler.tileservers = tileservers
    } else {
        WebRequestHandler.tileservers = try! DBController.global.getValueForKey(key: "TILESERVERS")?
            .jsonDecodeForceTry() as? [String: [String: String]] ?? [
                "Default": [
                    "url": "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    "attribution": "Map data &copy; <a href=\"https://www.openstreetmap.org/\">" +
                                   "OpenStreetMap</a> contributors"
                ]
            ]
    }

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

    // Init Instance Controller
    do {
        Log.info(message: "[MAIN] Starting Instance Controller")
        try InstanceController.setup()
    } catch {
        let message = "[MAIN] Failed to setup InstanceController"
        Log.critical(message: message)
        fatalError(message)
    }

    // Start WebHookController
    Log.info(message: "[MAIN] Starting Webhook Controller")
    WebHookController.global.start()

    Log.info(message: "[MAIN] Loading Available Items")
    var availableItems: [Int] = []
    for rewardType in QuestRewardProto.TypeEnum.allAvailable {
        if rewardType != .pokemonEncounter && rewardType != .item {
            availableItems.append(rewardType.rawValue * -1)
        }
    }
    for itemId in Item.allAvailable {
        availableItems.append(itemId.rawValue)
    }
    WebRequestHandler.availableItemJson = try! availableItems.jsonEncodedString()

    Pokemon.pvpEnabled = ConfigLoader.global.getConfig(type: .pvpEnabled)
    Pokemon.weatherIVClearingEnabled = ConfigLoader.global.getConfig(type: .ivWeatherClearing)
    Pokemon.cellPokemonEnabled = ConfigLoader.global.getConfig(type: .saveCellPokemon)
    Pokemon.saveSpawnpointLastSeen = ConfigLoader.global.getConfig(type: .saveSpawnPointLastSeen)
    InstanceController.requireAccountEnabled = ConfigLoader.global.getConfig(type: .accRequiredInDB)

    if Pokemon.pvpEnabled {
        Log.info(message: "[MAIN] Getting PVP Stats")
        let pvpRank: String = ConfigLoader.global.getConfig(type: .pvpDefaultRank)
        PVPStatsManager.defaultPVPRank = PVPStatsManager.RankType(rawValue: pvpRank) ?? .dense
        let pvpLittleFilter: Int = ConfigLoader.global.getConfig(type: .pvpFilterLittleMinCP)
        PVPStatsManager.leagueFilter[500] = pvpLittleFilter
        let pvpGreatFilter: Int = ConfigLoader.global.getConfig(type: .pvpFilterGreatMinCP)
        PVPStatsManager.leagueFilter[1500] = pvpGreatFilter
        let pvpUltraFilter: Int = ConfigLoader.global.getConfig(type: .pvpFilterUltraMinCP)
        PVPStatsManager.leagueFilter[2500] = pvpUltraFilter
        PVPStatsManager.lvlCaps = ConfigLoader.global.getConfig(type: .pvpLevelCaps)
        Log.info(message: "[MAIN] PVP Stats for Level Caps \(String(describing: PVPStatsManager.lvlCaps))")
        Log.info(message: "[MAIN] PVP Stats defaults to rank type \(pvpRank)")
        _ = PVPStatsManager.global
    } else {
        Log.info(message: "[MAIN] PVP Stats deactivated")
    }
    Log.info(message: "[MAIN] Pokemon weather IV clearing enabled: \(Pokemon.weatherIVClearingEnabled)")
    Log.info(message: "[MAIN] Pokemon cell spawns enabled: \(Pokemon.cellPokemonEnabled)")
    Log.info(message: "[MAIN] Pokemon update spanwpoint last seen: \(Pokemon.saveSpawnpointLastSeen)")
    Log.info(message: "[MAIN] InstanceController require account in DB: \(InstanceController.requireAccountEnabled)")

    // Load Icon styles
    Log.info(message: "[MAIN] Load Icon Styles")
    ImageApiRequestHandler.styles = try! DBController.global.getValueForKey(key: "ICON_STYLES")?
            .jsonDecodeForceTry() as? [String: String] ?? ["Default": "default"]

    ImageManager.imageGenerationEnabled = ConfigLoader.global.getConfig(type: .generateImages)

    if memoryCacheEnabled {
        // this will use the same cache values like the pokemon cache
        ImageManager.devicePathCache =
            MemoryCache(interval: memoryCacheClearInterval, keepTime: memoryCacheKeepTime)
        ImageManager.gymPathCache =
            MemoryCache(interval: memoryCacheClearInterval, keepTime: memoryCacheKeepTime)
        ImageManager.invasionPathCache =
            MemoryCache(interval: memoryCacheClearInterval, keepTime: memoryCacheKeepTime)
        ImageManager.miscPathCache =
            MemoryCache(interval: memoryCacheClearInterval, keepTime: memoryCacheKeepTime)
        ImageManager.pokemonPathCache =
            MemoryCache(interval: memoryCacheClearInterval, keepTime: memoryCacheKeepTime)
        ImageManager.pokestopPathCache =
            MemoryCache(interval: memoryCacheClearInterval, keepTime: memoryCacheKeepTime)
        ImageManager.raidPathCache =
            MemoryCache(interval: memoryCacheClearInterval, keepTime: memoryCacheKeepTime)
        ImageManager.rewardPathCache =
            MemoryCache(interval: memoryCacheClearInterval, keepTime: memoryCacheKeepTime)
        ImageManager.spawnpointPathCache =
            MemoryCache(interval: memoryCacheClearInterval, keepTime: memoryCacheKeepTime)
        ImageManager.teamPathCache =
            MemoryCache(interval: memoryCacheClearInterval, keepTime: memoryCacheKeepTime)
        ImageManager.typePathCache =
            MemoryCache(interval: memoryCacheClearInterval, keepTime: memoryCacheKeepTime)
        ImageManager.weatherPathCache =
            MemoryCache(interval: memoryCacheClearInterval, keepTime: memoryCacheKeepTime)
    }
    _ = ImageManager.global

    Log.info(message: "[MAIN] Starting Account Controller")
    AccountController.global.setup()

    Log.info(message: "[MAIN] Starting Assignment Controller")
    do {
        try AssignmentController.global.setup()
    } catch {
        let message = "[MAIN] Failed to start Assignment Controller"
        Log.critical(message: message)
        fatalError(message)
    }

    // Check if is setup
    Log.info(message: "[MAIN] Checking if setup is completed")
    let isSetup: String?
    do {
        isSetup = try DBController.global.getValueForKey(key: "IS_SETUP")
    } catch {
        let message = "Failed to get setup status."
        Log.critical(message: "[Main] " + message)
        fatalError(message)
    }

    if isSetup != nil && isSetup == "true" {
        WebRequestHandler.isSetup = true
    } else {
        WebRequestHandler.isSetup = false
        WebRequestHandler.accessToken = URandom().secureToken
        Log.info(message: "[MAIN] Use this access-token to create the admin user: \(WebRequestHandler.accessToken!)")
    }

    // Start MailController
    Log.info(message: "[MAIN] Starting Mail Controller")
    try! MailController.global.setup()

    // Start DiscordController
    Log.info(message: "[MAIN] Starting Discord Controller")
    try! DiscordController.global.setup()

    // Stopping Startup Webserver
    Log.info(message: "[MAIN] Stopping Startup Webserver")
    startupServerContext!.terminate()
    startupServer = nil
    startupServerContext = nil

    ApiRequestHandler.start = Date()
    Log.info(message: "[MAIN] Setup during startup finished ...")
    Log.info(message: "[MAIN] Starting Webservers")
    do {
        try HTTPServer.launch(
            [
                WebServer.server,
                WebHookServer.server
            ]
        )
    } catch {
        let message = "Failed to launch Servers: \(error.localizedDescription)"
        Log.critical(message: message)
        fatalError(message)
    }
}
