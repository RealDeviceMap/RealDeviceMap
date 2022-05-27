//
// Created by Fabio S. on 21.05.22.
//
//  swiftlint:disable superfluous_disable_command file_length force_cast

import Foundation
import PerfectLib

public class ConfigLoader {

    public static let global = ConfigLoader()

    private let localConfig: Config
    private let defaultConfig: Config
    private let environmentMap: [String: String]

    private static let environmentConstants = [
        "DB_DATABASE", "DB_HOST", "DB_PORT", "DB_USERNAME", "DB_PASSWORD", "DB_ROOT_USERNAME", "DB_ROOT_PASSWORD",
        "WEB_SERVER_ADDRESS", "WEB_SERVER_PORT", "WEBHOOK_SERVER_ADDRESS", "WEBHOOK_SERVER_PORT",
        "WEBHOOK_ENDPOINT_TIMEOUT", "WEBHOOK_ENDPOINT_CONNECT_TIMEOUT", "MEMORY_CACHE_CLEAR_INTERVAL",
        "MEMORY_CACHE_KEEP_TIME", "RAW_THREAD_LIMIT", "LOG_LEVEL", "LOGINLIMIT_COUNT", "LOGINLIMIT_INTERVALL",
        "PVP_DEFAULT_RANK", "PVP_LITTLE_FILTER", "PVP_GREAT_FILTER", "PVP_ULTRA_FILTER", "PVP_LEVEL_CAPS",
        "USE_RW_FOR_QUEST", "USE_RW_FOR_RAID", "NO_GENERATE_IMAGES", "NO_PVP", "NO_IV_WEATHER_CLEARING",
        "NO_CELL_POKEMON", "SAVE_SPAWNPOINT_LASTSEEN", "NO_MEMORY_CACHE", "NO_BACKUP", "NO_REQUIRE_ACCOUNT"
    ]

    private init() {
        localConfig = Config(with: "resources/config/local")
        defaultConfig = Config(with: "resources/config/default")
        environmentMap = ConfigLoader.environmentConstants.reduce(into: [String: String]()) {
            let value = ProcessInfo.processInfo.environment[$1]
            if value != nil {
                $0[$1] = value!
            }
        }
        Log.info(message: "[ConfigLoader] Loaded config settings")
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func getConfig<T>(type: ConfigType) -> T {
        let value = environmentMap[type.rawValue]
        if value != nil || type == .loginLimit {
            return getEnvironmentValue(type: type, value: value ?? "")
        }
        switch type {
        case .logLevel: return localConfig.logger.logLevel.value()
            ?? defaultConfig.logger.logLevel.value()!
        case .rawDebugEnabled: return localConfig.logger.rawDebug.enabled.value()
            ?? defaultConfig.logger.rawDebug.enabled.value()!
        case .rawDebugTypes: return localConfig.logger.rawDebug.types.value()
            ?? defaultConfig.logger.rawDebug.types.value()!
        case .serverHost: return localConfig.server.host.value()
            ?? defaultConfig.server.host.value()!
        case .serverPort: return localConfig.server.port.value()
            ?? defaultConfig.server.port.value()!
        case .webhookServerHost: return localConfig.webhookServer.host.value()
            ?? defaultConfig.webhookServer.host.value()!
        case .webhookServerPort: return localConfig.webhookServer.port.value()
            ?? defaultConfig.webhookServer.port.value()!
        case .dbHost: return localConfig.database.host.value()
            ?? defaultConfig.database.host.value()!
        case .dbPort: return localConfig.database.port.value()
            ?? defaultConfig.database.port.value()!
        case .dbDatabase: return localConfig.database.database.value()
            ?? defaultConfig.database.database.value()!
        case .dbUser: return localConfig.database.user.value()
            ?? defaultConfig.database.user.value()!
        case .dbPassword: return localConfig.database.password.value()
            ?? defaultConfig.database.password.value()!
        case .dbRootUser: return localConfig.database.rootUser.value()
            ?? defaultConfig.database.rootUser.value()!
        case .dbRootPassword: return localConfig.database.rootPassword.value()
            ?? defaultConfig.database.rootPassword.value()!
        case .dbBackup: return localConfig.database.backup.value()
            ?? defaultConfig.database.backup.value()!
        case .rawThreadLimit: return localConfig.application.rawThreadLimit.value()
            ?? defaultConfig.application.rawThreadLimit.value()!
        case .accRequiredInDB: return localConfig.application.account.requireInDB.value()
            ?? defaultConfig.application.account.requireInDB.value()!
        case .accUseRwForQuest: return localConfig.application.account.useRwForQuest.value()
            ?? defaultConfig.application.account.useRwForQuest.value()!
        case .accUseRwForRaid: return localConfig.application.account.useRwForRaid.value()
            ?? defaultConfig.application.account.useRwForRaid.value()!
        case .loginLimit: return localConfig.application.loginLimit.enabled.value()
            ?? defaultConfig.application.loginLimit.enabled.value()!
        case .loginLimitCount: return localConfig.application.loginLimit.count.value()
            ?? defaultConfig.application.loginLimit.count.value()!
        case .loginLimitInterval: return localConfig.application.loginLimit.interval.value()
            ?? defaultConfig.application.loginLimit.interval.value()!
        case .generateImages: return localConfig.application.map.generateImages.value()
            ?? defaultConfig.application.map.generateImages.value()!
        case .ivWeatherClearing: return localConfig.application.map.ivWeatherClearing.value()
            ?? defaultConfig.application.map.ivWeatherClearing.value()!
        case .saveCellPokemon: return localConfig.application.map.saveCellPokemon.value()
            ?? defaultConfig.application.map.saveCellPokemon.value()!
        case .saveSpawnPointLastSeen: return localConfig.application.map.saveSpawnPointLastSeen.value()
            ?? defaultConfig.application.map.saveSpawnPointLastSeen.value()!
        case .memoryCacheEnabled: return localConfig.application.memoryCache.enabled.value()
            ?? defaultConfig.application.memoryCache.enabled.value()!
        case .memoryCacheClearInterval: return localConfig.application.memoryCache.clearInterval.value()
            ?? defaultConfig.application.memoryCache.clearInterval.value()!
        case .memoryCacheKeepTime: return localConfig.application.memoryCache.keepTime.value()
            ?? defaultConfig.application.memoryCache.keepTime.value()!
        case .pvpEnabled: return localConfig.application.pvp.enabled.value()
            ?? defaultConfig.application.pvp.enabled.value()!
        case .pvpLevelCaps: return localConfig.application.pvp.levelCaps.value()
            ?? defaultConfig.application.pvp.levelCaps.value()!
        case .pvpDefaultRank: return localConfig.application.pvp.defaultRank.value()
            ?? defaultConfig.application.pvp.defaultRank.value()!
        case .pvpFilterLittleMinCP: return localConfig.application.pvp.filterLittleMinCP.value()
            ?? defaultConfig.application.pvp.filterLittleMinCP.value()!
        case .pvpFilterGreatMinCP: return localConfig.application.pvp.filterGreatMinCP.value()
            ?? defaultConfig.application.pvp.filterGreatMinCP.value()!
        case .pvpFilterUltraMinCP: return localConfig.application.pvp.filterUltraMinCP.value()
            ?? defaultConfig.application.pvp.filterUltraMinCP.value()!
        case .webhookTimeout: return localConfig.application.webhook.endpointTimeout.value()
            ?? defaultConfig.application.webhook.endpointTimeout.value()!
        case .webhookConnectTimeout: return localConfig.application.webhook.endpointConnectTimeout.value()
            ?? defaultConfig.application.webhook.endpointConnectTimeout.value()!
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func getEnvironmentValue<T>(type: ConfigType, value: String) -> T {
        switch type {
        case .logLevel: return value.lowercased() as! T
        case .rawDebugEnabled: return false as! T
        case .rawDebugTypes: return [] as! T
        case .serverHost: return value as! T
        case .serverPort: return castValue(value: value)
        case .webhookServerHost: return value as! T
        case .webhookServerPort: return castValue(value: value)
        case .dbHost: return value as! T
        case .dbPort: return castValue(value: value)
        case .dbDatabase: return value as! T
        case .dbUser: return value as! T
        case .dbPassword: return value as! T
        case .dbRootUser: return value as! T
        case .dbRootPassword: return value as! T
        case .dbBackup: return false as! T // NO_BACKUP
        case .rawThreadLimit: return castValue(value: value)
        case .accRequiredInDB: return false as! T // NO_REQUIRE_ACCOUNT
        case .accUseRwForQuest: return false as! T // USE_RW_FOR_QUEST
        case .accUseRwForRaid: return false as! T // USE_RW_FOR_RAID
        case .loginLimit: return (environmentMap[ConfigType.loginLimitCount.rawValue] != nil ? true : false) as! T
        case .loginLimitCount: return castValue(value: value)
        case .loginLimitInterval: return castValue(value: value)
        case .generateImages: return false as! T // NO_GENERATE_IMAGES
        case .ivWeatherClearing: return false as! T // NO_IV_WEATHER_CLEARING
        case .saveCellPokemon: return false as! T // NO_CELL_POKEMON
        case .saveSpawnPointLastSeen: return true as! T // SAVE_SPAWNPOINT_LASTSEEN
        case .memoryCacheEnabled: return false as! T
        case .memoryCacheClearInterval: return castValue(value: value)
        case .memoryCacheKeepTime: return castValue(value: value)
        case .pvpEnabled: return false as! T // NO_PVP
        case .pvpLevelCaps: return value.components(separatedBy: ",").map({ Int($0)! }) as! T
        case .pvpDefaultRank: return value as! T
        case .pvpFilterLittleMinCP: return castValue(value: value)
        case .pvpFilterGreatMinCP: return castValue(value: value)
        case .pvpFilterUltraMinCP: return castValue(value: value)
        case .webhookTimeout: return castValue(value: value)
        case .webhookConnectTimeout: return castValue(value: value)
        }
    }

    private func castValue<T>(value: String) -> T {
        if T.self == UInt32.self {
            return UInt32(value.trimmingCharacters(in: .whitespaces)) as! T
        } else if T.self == Int.self {
            return Int(value.trimmingCharacters(in: .whitespaces)) as! T
        } else if T.self == Double.self {
            return Double(value.trimmingCharacters(in: .whitespaces)) as! T
        } else if T.self == Bool.self {
            return Bool(value.trimmingCharacters(in: .whitespaces)) as! T
        } else {
            fatalError()
        }
    }

    enum ConfigType: String {
        case logLevel = "LOG_LEVEL"
        case rawDebugEnabled = "RAW_DEBUG" // not used in env
        case rawDebugTypes = "RAW_TYPES" // not used in env
        case serverHost = "WEB_SERVER_ADDRESS"
        case serverPort = "WEB_SERVER_PORT"
        case webhookServerHost = "WEBHOOK_SERVER_ADDRESS"
        case webhookServerPort = "WEBHOOK_SERVER_PORT"
        case dbHost = "DB_HOST"
        case dbPort = "DB_PORT"
        case dbDatabase = "DB_DATABASE"
        case dbUser = "DB_USERNAME"
        case dbPassword = "DB_PASSWORD"
        case dbRootUser = "DB_ROOT_USERNAME"
        case dbRootPassword = "DB_ROOT_PASSWORD"
        case dbBackup = "NO_BACKUP"
        case rawThreadLimit = "RAW_THREAD_LIMIT"
        case accRequiredInDB = "NO_REQUIRE_ACCOUNT"
        case accUseRwForQuest = "USE_RW_FOR_QUEST"
        case accUseRwForRaid = "USE_RW_FOR_RAID"
        case loginLimit = "LOGIN_LIMIT" // not used in env
        case loginLimitCount = "LOGINLIMIT_COUNT"
        case loginLimitInterval = "LOGINLIMIT_INTERVALL"
        case generateImages = "NO_GENERATE_IMAGES"
        case ivWeatherClearing = "NO_IV_WEATHER_CLEARING"
        case saveCellPokemon = "NO_CELL_POKEMON"
        case saveSpawnPointLastSeen = "SAVE_SPAWNPOINT_LASTSEEN"
        case memoryCacheEnabled = "NO_MEMORY_CACHE"
        case memoryCacheClearInterval = "MEMORY_CACHE_CLEAR_INTERVAL"
        case memoryCacheKeepTime = "MEMORY_CACHE_KEEP_TIME"
        case pvpEnabled = "NO_PVP"
        case pvpLevelCaps = "PVP_LEVEL_CAPS"
        case pvpDefaultRank = "PVP_DEFAULT_RANK"
        case pvpFilterLittleMinCP = "PVP_LITTLE_FILTER"
        case pvpFilterGreatMinCP = "PVP_GREAT_FILTER"
        case pvpFilterUltraMinCP = "PVP_ULTRA_FILTER"
        case webhookTimeout = "WEBHOOK_ENDPOINT_TIMEOUT"
        case webhookConnectTimeout = "WEBHOOK_ENDPOINT_CONNECT_TIMEOUT"
    }

}
