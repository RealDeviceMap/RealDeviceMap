//
//  Gym.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast

import Foundation
import PerfectLib
import PerfectMySQL
import POGOProtos

class Gym: JSONConvertibleObject, WebHookEvent, Hashable {

    public static var exRaidBossId: UInt16?
    public static var exRaidBossForm: UInt16?

    class ParsingError: Error {}

    override func getJSONValues() -> [String: Any] {
        return [
            "id": id,
            "lat": lat,
            "lon": lon,
            "name": name as Any,
            "url": url as Any,
            "guard_pokemon_id": guardPokemonId as Any,
            "enabled": enabled as Any,
            "last_modified_timestamp": lastModifiedTimestamp as Any,
            "team_id": teamId as Any,
            "raid_end_timestamp": raidEndTimestamp as Any,
            "raid_spawn_timestamp": raidSpawnTimestamp as Any,
            "raid_battle_timestamp": raidBattleTimestamp as Any,
            "raid_pokemon_id": raidPokemonId as Any,
            "raid_level": raidLevel as Any,
            "availble_slots": availableSlots as Any,
            "updated": updated ?? 1,
            "ex_raid_eligible": exRaidEligible as Any,
            "in_battle": inBattle as Any,
            "raid_pokemon_form": raidPokemonForm as Any,
            "raid_pokemon_costume": raidPokemonCostume as Any,
            "raid_pokemon_move_1": raidPokemonMove1 as Any,
            "raid_pokemon_move_2": raidPokemonMove2 as Any,
            "raid_pokemon_cp": raidPokemonCp as Any,
            "raid_pokemon_gender": raidPokemonGender as Any,
            "raid_pokemon_evolution": raidPokemonEvolution as Any,
            "raid_is_exclusive": raidIsExclusive as Any,
            "total_cp": totalCp as Any,
            "sponsor_od": sponsorId as Any,
            "ar_scan_eligible": arScanEligible as Any
        ]
    }

    func getWebhookValues(type: String) -> [String: Any] {

        let realType: String
        let message: [String: Any]
        if type == "gym" {
            realType = "gym"
            message = [
                "gym_id": id,
                "gym_name": name ?? "Unknown",
                "latitude": lat,
                "longitude": lon,
                "url": url ?? "",
                "enabled": enabled ?? true,
                "team_id": teamId ?? 0,
                "last_modified": lastModifiedTimestamp ?? 0,
                "guard_pokemon_id": guardPokemonId ?? 0,
                "slots_available": availableSlots ?? 6,
                "raid_active_until": raidEndTimestamp ?? 0,
                "ex_raid_eligible": exRaidEligible ?? 0,
                "sponsor_od": sponsorId ?? 0,
                "ar_scan_eligible": arScanEligible ?? 0
            ]
        } else if type == "gym-info" {
            realType = "gym_details"
            message = [
                "id": id,
                "name": name ?? "Unknown",
                "url": url ?? "",
                "latitude": lat,
                "longitude": lon,
                "team": teamId ?? 0,
                "slots_available": availableSlots ?? 6,
                "ex_raid_eligible": exRaidEligible ?? 0,
                "in_battle": inBattle ?? false,
                "sponsor_od": sponsorId ?? 0,
                "ar_scan_eligible": arScanEligible ?? 0
            ]
        } else if type == "egg" || type == "raid" {
            realType = "raid"
            message = [
                "gym_id": id,
                "gym_name": name ?? "Unknown",
                "gym_url": url ?? "",
                "latitude": lat,
                "longitude": lon,
                "team_id": teamId ?? 0,
                "spawn": raidSpawnTimestamp ?? 0,
                "start": raidBattleTimestamp ?? 0,
                "end": raidEndTimestamp ?? 0,
                "level": raidLevel ?? 0,
                "pokemon_id": raidPokemonId ?? 0,
                "cp": raidPokemonCp ?? 0,
                "gender": raidPokemonGender ?? 0,
                "form": raidPokemonForm ?? 0,
                "evolution": raidPokemonEvolution ?? 0,
                "move_1": raidPokemonMove1 ?? 0,
                "move_2": raidPokemonMove2 ?? 0,
                "ex_raid_eligible": exRaidEligible ?? 0,
                "is_exclusive": raidIsExclusive ?? false,
                "sponsor_od": sponsorId ?? 0,
                "ar_scan_eligible": arScanEligible ?? 0
            ]
        } else {
            realType = "unkown"
            message = [String: Any]()
        }
        return [
            "type": realType,
            "message": message
        ]
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var id: String
    var lat: Double
    var lon: Double

    var name: String?
    var url: String?
    var guardPokemonId: UInt16?
    var enabled: Bool?
    var lastModifiedTimestamp: UInt32?
    var teamId: UInt8?
    var raidEndTimestamp: UInt32?
    var raidSpawnTimestamp: UInt32?
    var raidBattleTimestamp: UInt32?
    var raidPokemonId: UInt16?
    var raidLevel: UInt8?
    var raidPokemonMove1: UInt16?
    var raidPokemonMove2: UInt16?
    var raidPokemonForm: UInt16?
    var raidPokemonCostume: UInt16?
    var raidPokemonCp: UInt32?
    var raidPokemonGender: UInt8?
    var raidPokemonEvolution: UInt8?
    var availableSlots: UInt16?
    var updated: UInt32?
    var exRaidEligible: Bool?
    var inBattle: Bool?
    var raidIsExclusive: Bool?
    var cellId: UInt64?
    var totalCp: UInt32?
    var sponsorId: UInt16?
    var arScanEligible: Bool?

    var hasChanges = false

    static var cache: MemoryCache<Gym>?

    init(id: String, lat: Double, lon: Double, name: String?, url: String?, guardPokemonId: UInt16?, enabled: Bool?,
         lastModifiedTimestamp: UInt32?, teamId: UInt8?, raidEndTimestamp: UInt32?, raidSpawnTimestamp: UInt32?,
         raidBattleTimestamp: UInt32?, raidPokemonId: UInt16?, raidLevel: UInt8?, availableSlots: UInt16?,
         updated: UInt32?, exRaidEligible: Bool?, inBattle: Bool?, raidPokemonMove1: UInt16?, raidPokemonMove2: UInt16?,
         raidPokemonForm: UInt16?, raidPokemonCostume: UInt16?, raidPokemonCp: UInt32?, raidPokemonGender: UInt8?,
         raidPokemonEvolution: UInt8?, raidIsExclusive: Bool?, cellId: UInt64?, totalCp: UInt32?, sponsorId: UInt16?,
         arScanEligible: Bool?) {
        self.id = id
        self.lat = lat
        self.lon = lon
        self.name = name
        self.url = url
        self.guardPokemonId =  guardPokemonId
        self.enabled = enabled
        self.lastModifiedTimestamp = lastModifiedTimestamp
        self.teamId = teamId
        self.raidEndTimestamp = raidEndTimestamp
        self.raidSpawnTimestamp = raidSpawnTimestamp
        self.raidBattleTimestamp = raidBattleTimestamp
        self.raidPokemonId = raidPokemonId
        self.raidLevel = raidLevel
        self.availableSlots = availableSlots
        self.updated = updated
        self.exRaidEligible = exRaidEligible
        self.inBattle = inBattle
        self.raidPokemonMove1 = raidPokemonMove1
        self.raidPokemonMove2 = raidPokemonMove2
        self.raidPokemonForm = raidPokemonForm
        self.raidPokemonCostume = raidPokemonCostume
        self.raidPokemonCp = raidPokemonCp
        self.raidPokemonGender = raidPokemonGender
        self.raidPokemonEvolution = raidPokemonEvolution
        self.raidIsExclusive = raidIsExclusive
        self.cellId = cellId
        self.totalCp = totalCp
        self.sponsorId = sponsorId
        self.arScanEligible = arScanEligible
    }

    init(fortData: PokemonFortProto, cellId: UInt64) {
        self.id = fortData.fortID
        self.lat = fortData.latitude
        self.lon = fortData.longitude
        self.enabled = fortData.enabled
        self.guardPokemonId = fortData.guardPokemonID.rawValue.toUInt16()
        self.teamId = fortData.team.rawValue.toUInt8()
        self.availableSlots = UInt16(fortData.gymDisplay.slotsAvailable)
        self.lastModifiedTimestamp = UInt32(fortData.lastModifiedMs / 1000)
        self.exRaidEligible = fortData.isExRaidEligible
        self.inBattle = fortData.isInBattle
        self.arScanEligible = fortData.isArScanEligible
        if fortData.sponsor != .unset {
            self.sponsorId = UInt16(fortData.sponsor.rawValue)
        }
        if fortData.imageURL != "" {
            self.url = fortData.imageURL
        }
        if fortData.team == .unset {
            self.totalCp = 0
        } else {
            self.totalCp = UInt32(fortData.gymDisplay.totalGymCp)
        }

        if fortData.hasRaidInfo {
            self.raidEndTimestamp = UInt32(fortData.raidInfo.raidEndMs / 1000)
            self.raidSpawnTimestamp = UInt32(fortData.raidInfo.raidSpawnMs / 1000)
            self.raidBattleTimestamp = UInt32(fortData.raidInfo.raidBattleMs / 1000)
            self.raidLevel = UInt8(fortData.raidInfo.raidLevel.rawValue)
            self.raidPokemonId = UInt16(fortData.raidInfo.raidPokemon.pokemonID.rawValue)
            self.raidPokemonMove1 = UInt16(fortData.raidInfo.raidPokemon.move1.rawValue)
            self.raidPokemonMove2 = UInt16(fortData.raidInfo.raidPokemon.move2.rawValue)
            self.raidPokemonForm = UInt16(fortData.raidInfo.raidPokemon.pokemonDisplay.form.rawValue)
            self.raidPokemonCp = UInt32(fortData.raidInfo.raidPokemon.cp)
            self.raidPokemonGender = UInt8(fortData.raidInfo.raidPokemon.pokemonDisplay.gender.rawValue)
            self.raidIsExclusive = fortData.raidInfo.isExclusive
            self.raidPokemonCostume = UInt16(fortData.raidInfo.raidPokemon.pokemonDisplay.costume.rawValue)
            self.raidPokemonEvolution = UInt8(
                fortData.raidInfo.raidPokemon.pokemonDisplay.currentTempEvolution.rawValue
            )
        }

        self.cellId = cellId

    }

    public func addDetails(fortData: FortDetailsOutProto) {
        if !fortData.imageURL.isEmpty {
            let url = fortData.imageURL[0]
            if self.url != url {
                hasChanges = true
            }
            self.url = url
        }
        let name = fortData.name
        if self.name != name {
            hasChanges = true
        }
        self.name = name
    }

    public func addDetails(gymInfo: GymGetInfoOutProto) {
        let name = gymInfo.name
        let url = gymInfo.url
        if self.url != url || self.name != name {
            hasChanges = true
        }
        self.name = name
        self.url = url
    }

    public func save(mysql: MySQL?=nil) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[GYM] Failed to connect to database.")
            throw DBController.DBError()
        }

        let oldGym: Gym?
        do {
            oldGym = try Gym.getWithId(mysql: mysql, id: id, withDeleted: true)
        } catch {
            oldGym = nil
        }
        let mysqlStmt = MySQLStmt(mysql)

        if raidIsExclusive != nil && raidIsExclusive! && Gym.exRaidBossId != nil {
            raidPokemonId = Gym.exRaidBossId!
            raidPokemonForm = Gym.exRaidBossForm ?? 0
        }

        updated = UInt32(Date().timeIntervalSince1970)

        let now = UInt32(Date().timeIntervalSince1970)
        if oldGym == nil {
            let sql = """
                INSERT INTO gym (
                    id, lat, lon, name, url, guarding_pokemon_id, last_modified_timestamp, team_id, raid_end_timestamp,
                    raid_spawn_timestamp, raid_battle_timestamp, raid_pokemon_id, enabled, availble_slots, raid_level,
                    ex_raid_eligible, in_battle, raid_pokemon_move_1, raid_pokemon_move_2, raid_pokemon_form,
                    raid_pokemon_costume, raid_pokemon_cp, raid_pokemon_gender, raid_is_exclusive, cell_id, total_cp,
                    sponsor_id, raid_pokemon_evolution, ar_scan_eligible, updated, first_seen_timestamp)
                VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
                )
            """
            self.updated = now
            _ = mysqlStmt.prepare(statement: sql)
            mysqlStmt.bindParam(id)
        } else {
            if oldGym!.cellId != nil && self.cellId == nil {
                self.cellId = oldGym!.cellId
            }
            if oldGym!.name != nil && self.name == nil {
                self.name = oldGym!.name
            }
            if oldGym!.url != nil && self.url == nil {
                self.url = oldGym!.url
            }
            if oldGym!.raidIsExclusive != nil && self.raidIsExclusive == nil {
                self.raidIsExclusive = oldGym!.raidIsExclusive
            }

            if self.raidEndTimestamp == nil && oldGym!.raidEndTimestamp != nil {
                self.raidEndTimestamp = oldGym!.raidEndTimestamp
            }

            guard Gym.shouldUpdate(old: oldGym!, new: self) else {
                return
            }

            if self.raidSpawnTimestamp != nil && raidSpawnTimestamp != 0 &&
                (
                    oldGym!.raidLevel != self.raidLevel ||
                    oldGym!.raidPokemonId != self.raidPokemonId ||
                    oldGym!.raidSpawnTimestamp != self.raidSpawnTimestamp
                ) {

                let raidBattleTime = Date(timeIntervalSince1970: Double(raidBattleTimestamp ?? 0))
                let raidEndTime = Date(timeIntervalSince1970: Double(raidEndTimestamp ?? 0))
                let now = Date()

                if raidBattleTime > now && self.raidLevel ?? 0 != 0 {
                    WebHookController.global.addEggEvent(gym: self)
                } else if raidEndTime > now && self.raidPokemonId ?? 0 != 0 {
                    WebHookController.global.addRaidEvent(gym: self)
                }

            }
            let nameSQL = name != nil ? "name = ?, " : ""

            let sql = """
                UPDATE gym
                SET lat = ?, lon = ?, \(nameSQL) url = ?, guarding_pokemon_id = ?, last_modified_timestamp = ?,
                    team_id = ?, raid_end_timestamp = ?, raid_spawn_timestamp = ?, raid_battle_timestamp = ?,
                    raid_pokemon_id = ?, enabled = ?, availble_slots = ?, updated = UNIX_TIMESTAMP(), raid_level = ?,
                    ex_raid_eligible = ?, in_battle = ?, raid_pokemon_move_1 = ?, raid_pokemon_move_2 = ?,
                    raid_pokemon_form = ?, raid_pokemon_costume = ?, raid_pokemon_cp = ?, raid_pokemon_gender = ?,
                    raid_is_exclusive = ?, cell_id = ?, deleted = false, total_cp = ?, sponsor_id = ?,
                    raid_pokemon_evolution = ?, ar_scan_eligible = ?
                WHERE id = ?
            """
            self.updated = now
            _ = mysqlStmt.prepare(statement: sql)
        }

        mysqlStmt.bindParam(lat)
        mysqlStmt.bindParam(lon)
        if oldGym == nil || name != nil {
            mysqlStmt.bindParam(name)
        }
        mysqlStmt.bindParam(url)
        mysqlStmt.bindParam(guardPokemonId)
        mysqlStmt.bindParam(lastModifiedTimestamp)
        mysqlStmt.bindParam(teamId)
        mysqlStmt.bindParam(raidEndTimestamp)
        mysqlStmt.bindParam(raidSpawnTimestamp)
        mysqlStmt.bindParam(raidBattleTimestamp)
        mysqlStmt.bindParam(raidPokemonId)
        mysqlStmt.bindParam(enabled)
        mysqlStmt.bindParam(availableSlots)
        mysqlStmt.bindParam(raidLevel)
        mysqlStmt.bindParam(exRaidEligible)
        mysqlStmt.bindParam(inBattle)
        mysqlStmt.bindParam(raidPokemonMove1)
        mysqlStmt.bindParam(raidPokemonMove2)
        mysqlStmt.bindParam(raidPokemonForm)
        mysqlStmt.bindParam(raidPokemonCostume)
        mysqlStmt.bindParam(raidPokemonCp)
        mysqlStmt.bindParam(raidPokemonGender)
        mysqlStmt.bindParam(raidIsExclusive)
        mysqlStmt.bindParam(cellId)
        mysqlStmt.bindParam(totalCp)
        mysqlStmt.bindParam(sponsorId)
        mysqlStmt.bindParam(raidPokemonEvolution)
        mysqlStmt.bindParam(arScanEligible)

        if oldGym != nil {
            mysqlStmt.bindParam(id)
        }

        guard mysqlStmt.execute() else {
            if mysqlStmt.errorCode() == 1062 {
                Log.debug(message: "[GYM] Duplicated key. Skipping...")
            } else {
                Log.error(message: "[GYM] Failed to execute query. (\(mysqlStmt.errorMessage()))")
            }
            throw DBController.DBError()
        }

        Gym.cache?.set(id: id, value: self)

        if oldGym == nil {
            WebHookController.global.addGymEvent(gym: self)
            WebHookController.global.addGymInfoEvent(gym: self)
            let raidBattleTime = Date(timeIntervalSince1970: Double(raidBattleTimestamp ?? 0))
            let raidEndTime = Date(timeIntervalSince1970: Double(raidEndTimestamp ?? 0))
            let now = Date()

            if raidBattleTime > now && self.raidLevel ?? 0 != 0 {
                WebHookController.global.addEggEvent(gym: self)
            } else if raidEndTime > now && self.raidPokemonId ?? 0 != 0 {
                WebHookController.global.addRaidEvent(gym: self)
            }
        } else {
            if self.raidSpawnTimestamp != nil && raidSpawnTimestamp != 0 && (
                    oldGym!.raidLevel != self.raidLevel ||
                    oldGym!.raidPokemonId != self.raidPokemonId ||
                    oldGym!.raidSpawnTimestamp != self.raidSpawnTimestamp) {
                let raidBattleTime = Date(timeIntervalSince1970: Double(raidBattleTimestamp ?? 0))
                let raidEndTime = Date(timeIntervalSince1970: Double(raidEndTimestamp ?? 0))
                let now = Date()

                if raidBattleTime > now && self.raidLevel ?? 0 != 0 {
                    WebHookController.global.addEggEvent(gym: self)
                } else if raidEndTime > now && self.raidPokemonId ?? 0 != 0 {
                    WebHookController.global.addRaidEvent(gym: self)
                }
            }
            if oldGym!.availableSlots != self.availableSlots ||
               oldGym!.teamId != self.teamId ||
               oldGym!.inBattle != self.inBattle {
                WebHookController.global.addGymInfoEvent(gym: self)
            }
        }
    }

    //  swiftlint:disable:next function_parameter_count
    public static func getAll(mysql: MySQL?=nil, minLat: Double, maxLat: Double, minLon: Double, maxLon: Double,
                              updated: UInt32, raidsOnly: Bool, showRaids: Bool, raidFilterExclude: [String]?=nil,
                              gymFilterExclude: [String]?=nil, gymShowOnlyAr: Bool=false) throws -> [Gym] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[GYM] Failed to connect to database.")
            throw DBController.DBError()
        }

        var excludedLevels = [Int]()
        var excludedPokemon = [Int]()
        var excludeAllButEx = false
        var excludedTeams = [Int]()
        var excludedAvailableSlots = [Int]()

        if showRaids && raidFilterExclude != nil {
            for filter in raidFilterExclude! {
                if filter.contains(string: "l") {
                    if let id = filter.stringByReplacing(string: "l", withString: "").toInt() {
                        excludedLevels.append(id)
                    }
                } else if filter.contains(string: "p"),
                       let id = filter.stringByReplacing(string: "p", withString: "").toInt() {
                    excludedPokemon.append(id)
                }
            }
        }

        if gymFilterExclude != nil {
            for filter in gymFilterExclude! {
                if filter.contains(string: "t") {
                    if let id = filter.stringByReplacing(string: "t", withString: "").toInt() {
                        excludedTeams.append(id)
                    }
                } else if filter.contains(string: "s") {
                    if let id = filter.stringByReplacing(string: "s", withString: "").toInt() {
                        excludedAvailableSlots.append(id)
                    }
                } else if filter.contains(string: "ex") {
                    excludeAllButEx = true
                }
            }
        }

        let excludeLevelSQL: String
        let excludePokemonSQL: String
        let excludeAllButExSQL: String
        var onlyArSQL: String
        let excludeTeamSQL: String
        let excludeAvailableSlotsSQL: String

        if showRaids {
            if excludedLevels.isEmpty {
                excludeLevelSQL = ""
            } else {
                var sqlExcludeCreate = "AND (raid_level NOT IN ("
                for _ in 1..<excludedLevels.count {
                    sqlExcludeCreate += "?, "
                }
                sqlExcludeCreate += "?))"
                excludeLevelSQL = sqlExcludeCreate
            }

            if excludedPokemon.isEmpty {
                excludePokemonSQL = ""
            } else {
                var sqlExcludeCreate = "AND (raid_pokemon_id NOT IN ("
                for _ in 1..<excludedPokemon.count {
                    sqlExcludeCreate += "?, "
                }
                sqlExcludeCreate += "?))"
                excludePokemonSQL = sqlExcludeCreate
            }
        } else {
            excludeLevelSQL = ""
            excludePokemonSQL = ""
        }
        if excludedTeams.isEmpty {
            excludeTeamSQL = ""
        } else {
            var sqlExcludeCreate = "AND (team_id NOT IN ("
            for index in excludedTeams.indices {
                if index == excludedTeams.count - 1 {
                    sqlExcludeCreate += "?))"
                } else {
                    sqlExcludeCreate += "?, "
                }
            }
            excludeTeamSQL = sqlExcludeCreate
        }

        if excludedAvailableSlots.isEmpty {
            excludeAvailableSlotsSQL = ""
        } else {
            var sqlExcludeCreate = "AND (availble_slots NOT IN ("
            for _ in excludedAvailableSlots {
                sqlExcludeCreate += "?, "
            }
            sqlExcludeCreate += "?))"
            excludeAvailableSlotsSQL = sqlExcludeCreate
        }

        if excludeAllButEx && !raidsOnly {
            excludeAllButExSQL = "AND ex_raid_eligible = TRUE"
        } else {
            excludeAllButExSQL = ""
        }

        if gymShowOnlyAr && !raidsOnly {
            onlyArSQL = "AND ar_scan_eligible = TRUE"
        } else {
            onlyArSQL = ""
        }

        var sql = """
            SELECT id, lat, lon, name, url, guarding_pokemon_id, last_modified_timestamp, team_id, raid_end_timestamp,
                   raid_spawn_timestamp, raid_battle_timestamp, raid_pokemon_id, enabled, availble_slots, updated,
                   raid_level, ex_raid_eligible, in_battle, raid_pokemon_move_1, raid_pokemon_move_2, raid_pokemon_form,
                   raid_pokemon_costume, raid_pokemon_cp, raid_pokemon_gender, raid_is_exclusive, cell_id, total_cp,
                   sponsor_id, raid_pokemon_evolution, ar_scan_eligible
            FROM gym
            WHERE lat >= ? AND lat <= ? AND lon >= ? AND lon <= ? AND updated > ? AND deleted = false
                  \(excludeLevelSQL) \(excludePokemonSQL) \(excludeTeamSQL) \(excludeAvailableSlotsSQL)
                  \(excludeAllButExSQL) \(onlyArSQL)
        """
        if raidsOnly {
            sql += " AND raid_end_timestamp >= UNIX_TIMESTAMP()"
        }

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(minLat)
        mysqlStmt.bindParam(maxLat)
        mysqlStmt.bindParam(minLon)
        mysqlStmt.bindParam(maxLon)
        mysqlStmt.bindParam(updated)

        for id in excludedLevels {
            mysqlStmt.bindParam(id)
        }
        for id in excludedPokemon {
            mysqlStmt.bindParam(id)
        }
        for id in excludedTeams {
            mysqlStmt.bindParam(id)
        }
        for id in excludedAvailableSlots {
            mysqlStmt.bindParam(id)
        }

        guard mysqlStmt.execute() else {
            Log.error(message: "[GYM] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var gyms = [Gym]()
        while let result = results.next() {
            let id = result[0] as! String
            let lat = result[1] as! Double
            let lon = result[2] as! Double
            let name = result[3] as? String
            let url = result[4] as? String
            let guardPokemonId = result[5] as? UInt16
            let lastModifiedTimestamp = result[6] as? UInt32
            let teamId = result[7] as? UInt8

            let raidEndTimestamp: UInt32?
            let raidSpawnTimestamp: UInt32?
            let raidBattleTimestamp: UInt32?
            let raidPokemonId: UInt16?
            if showRaids {
                raidEndTimestamp = result[8] as? UInt32
                raidSpawnTimestamp = result[9] as? UInt32
                raidBattleTimestamp = result[10] as? UInt32
                raidPokemonId = result[11] as? UInt16
            } else {
                raidEndTimestamp = nil
                raidSpawnTimestamp = nil
                raidBattleTimestamp = nil
                raidPokemonId = nil
            }

            let enabled = (result[12] as? UInt8)?.toBool()
            let availableSlots = result[13] as? UInt16
            let updated = result[14] as! UInt32
            let raidLevel = result[15] as? UInt8
            let exRaidEligible = (result[16] as? UInt8)?.toBool()
            let inBattle = (result[17] as? UInt8)?.toBool()
            let raidPokemonMove1 = result[18] as? UInt16
            let raidPokemonMove2 = result[19] as? UInt16
            let raidPokemonForm = result[20] as? UInt16
            let raidPokemonCostume = result[21] as? UInt16
            let raidPokemonCp = result[22] as? UInt32
            let raidPokemonGender = result[23] as? UInt8
            let raidIsExclusive = (result[24] as? UInt8)?.toBool()
            let cellId = result[25] as? UInt64
            let totalCp = result[26] as? UInt32
            let sponsorId = result[27] as? UInt16
            let raidPokemonEvolution = result[28] as? UInt8
            let arScanEligible = (result[29] as? UInt8)?.toBool()

            gyms.append(Gym(
                id: id, lat: lat, lon: lon, name: name, url: url, guardPokemonId: guardPokemonId, enabled: enabled,
                lastModifiedTimestamp: lastModifiedTimestamp, teamId: teamId, raidEndTimestamp: raidEndTimestamp,
                raidSpawnTimestamp: raidSpawnTimestamp, raidBattleTimestamp: raidBattleTimestamp,
                raidPokemonId: raidPokemonId, raidLevel: raidLevel, availableSlots: availableSlots, updated: updated,
                exRaidEligible: exRaidEligible, inBattle: inBattle, raidPokemonMove1: raidPokemonMove1,
                raidPokemonMove2: raidPokemonMove2, raidPokemonForm: raidPokemonForm,
                raidPokemonCostume: raidPokemonCostume, raidPokemonCp: raidPokemonCp,
                raidPokemonGender: raidPokemonGender, raidPokemonEvolution: raidPokemonEvolution,
                raidIsExclusive: raidIsExclusive, cellId: cellId, totalCp: totalCp, sponsorId: sponsorId,
                arScanEligible: arScanEligible))
        }
        return gyms

    }

    public static func getWithId(mysql: MySQL?=nil, id: String, withDeleted: Bool=false) throws -> Gym? {

        if let cached = cache?.get(id: id) {
            return cached
        }

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[GYM] Failed to connect to database.")
            throw DBController.DBError()
        }

        let withDeletedSQL: String
        if withDeleted {
            withDeletedSQL = ""
        } else {
            withDeletedSQL = "AND deleted = false"
        }
        let sql = """
            SELECT id, lat, lon, name, url, guarding_pokemon_id, last_modified_timestamp, team_id, raid_end_timestamp,
                   raid_spawn_timestamp, raid_battle_timestamp, raid_pokemon_id, enabled, availble_slots, updated,
                   raid_level, ex_raid_eligible, in_battle, raid_pokemon_move_1, raid_pokemon_move_2, raid_pokemon_form,
                   raid_pokemon_costume, raid_pokemon_cp, raid_pokemon_gender, raid_is_exclusive, cell_id, total_cp,
                   sponsor_id, raid_pokemon_evolution, ar_scan_eligible
            FROM gym
            WHERE id = ? \(withDeletedSQL)
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(id)

        guard mysqlStmt.execute() else {
            Log.error(message: "[GYM] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }

        let result = results.next()!
        let id = result[0] as! String
        let lat = result[1] as! Double
        let lon = result[2] as! Double
        let name = result[3] as? String
        let url = result[4] as? String
        let guardPokemonId = result[5] as? UInt16
        let lastModifiedTimestamp = result[6] as? UInt32
        let teamId = result[7] as? UInt8
        let raidEndTimestamp = result[8] as? UInt32
        let raidSpawnTimestamp = result[9] as? UInt32
        let raidBattleTimestamp = result[10] as? UInt32
        let raidPokemonId = result[11] as? UInt16
        let enabled = (result[12] as? UInt8)?.toBool()
        let availableSlots = result[13] as? UInt16
        let updated = result[14] as! UInt32
        let raidLevel = result[15] as? UInt8
        let exRaidEligible = (result[16] as? UInt8)?.toBool()
        let inBattle = (result[17] as? UInt8)?.toBool()
        let raidPokemonMove1 = result[18] as? UInt16
        let raidPokemonMove2 = result[19] as? UInt16
        let raidPokemonForm = result[20] as? UInt16
        let raidPokemonCostume = result[21] as? UInt16
        let raidPokemonCp = result[22] as? UInt32
        let raidPokemonGender = result[23] as? UInt8
        let raidIsExclusive = (result[24] as? UInt8)?.toBool()
        let cellId = result[25] as? UInt64
        let totalCp = result[26] as? UInt32
        let sponsorId = result[27] as? UInt16
        let raidPokemonEvolution = result[28] as? UInt8
        let arScanEligible = (result[29] as? UInt8)?.toBool()

        let gym = Gym(
            id: id, lat: lat, lon: lon, name: name, url: url, guardPokemonId: guardPokemonId, enabled: enabled,
            lastModifiedTimestamp: lastModifiedTimestamp, teamId: teamId, raidEndTimestamp: raidEndTimestamp,
            raidSpawnTimestamp: raidSpawnTimestamp, raidBattleTimestamp: raidBattleTimestamp,
            raidPokemonId: raidPokemonId, raidLevel: raidLevel, availableSlots: availableSlots, updated: updated,
            exRaidEligible: exRaidEligible, inBattle: inBattle, raidPokemonMove1: raidPokemonMove1,
            raidPokemonMove2: raidPokemonMove2, raidPokemonForm: raidPokemonForm,
            raidPokemonCostume: raidPokemonCostume, raidPokemonCp: raidPokemonCp,
            raidPokemonGender: raidPokemonGender, raidPokemonEvolution: raidPokemonEvolution,
            raidIsExclusive: raidIsExclusive, cellId: cellId, totalCp: totalCp, sponsorId: sponsorId,
            arScanEligible: arScanEligible)
        cache?.set(id: gym.id, value: gym)
        return gym
    }

    public static func getWithIDs(mysql: MySQL?=nil, ids: [String]) throws -> [Gym] {

        if ids.count > 10000 {
            var result = [Gym]()
            for i in 0..<(Int(ceil(Double(ids.count)/10000.0))) {
                let start = 10000 * i
                let end = min(10000 * (i+1) - 1, ids.count - 1)
                let splice = Array(ids[start...end])
                if let spliceResult = try? getWithIDs(mysql: mysql, ids: splice) {
                    result += spliceResult
                }
            }
            return result
        }

        if ids.count == 0 {
            return [Gym]()
        }

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[GYM] Failed to connect to database.")
            throw DBController.DBError()
        }

        var inSQL = "("
        for _ in 1..<ids.count {
            inSQL += "?, "
        }
        inSQL += "?)"

        let sql = """
        SELECT id, lat, lon, name, url, guarding_pokemon_id, last_modified_timestamp, team_id,
               raid_end_timestamp, raid_spawn_timestamp, raid_battle_timestamp, raid_pokemon_id, enabled,
               availble_slots, updated, raid_level, ex_raid_eligible, in_battle, raid_pokemon_move_1,
               raid_pokemon_move_2, raid_pokemon_form, raid_pokemon_costume, raid_pokemon_cp, raid_pokemon_gender,
               raid_is_exclusive, cell_id, total_cp, sponsor_id, raid_pokemon_evolution, ar_scan_eligible
        FROM gym
        WHERE id IN \(inSQL) AND deleted = false
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        for id in ids {
            mysqlStmt.bindParam(id)
        }

        guard mysqlStmt.execute() else {
            Log.error(message: "[GYM] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var gyms = [Gym]()
        while let result = results.next() {
            let id = result[0] as! String
            let lat = result[1] as! Double
            let lon = result[2] as! Double
            let name = result[3] as? String
            let url = result[4] as? String
            let guardPokemonId = result[5] as? UInt16
            let lastModifiedTimestamp = result[6] as? UInt32
            let teamId = result[7] as? UInt8
            let raidEndTimestamp = result[8] as? UInt32
            let raidSpawnTimestamp = result[9] as? UInt32
            let raidBattleTimestamp = result[10] as? UInt32
            let raidPokemonId = result[11] as? UInt16
            let enabled = (result[12] as? UInt8)?.toBool()
            let availableSlots = result[13] as? UInt16
            let updated = result[14] as! UInt32
            let raidLevel = result[15] as? UInt8
            let exRaidEligible = (result[16] as? UInt8)?.toBool()
            let inBattle = (result[17] as? UInt8)?.toBool()
            let raidPokemonMove1 = result[18] as? UInt16
            let raidPokemonMove2 = result[19] as? UInt16
            let raidPokemonForm = result[20] as? UInt16
            let raidPokemonCostume = result[21] as? UInt16
            let raidPokemonCp = result[22] as? UInt32
            let raidPokemonGender = result[23] as? UInt8
            let raidIsExclusive = (result[24] as? UInt8)?.toBool()
            let cellId = result[25] as? UInt64
            let totalCp = result[26] as? UInt32
            let sponsorId = result[27] as? UInt16
            let raidPokemonEvolution = result[28] as? UInt8
            let arScanEligible = (result[29] as? UInt8)?.toBool()

            gyms.append(Gym(
                id: id, lat: lat, lon: lon, name: name, url: url, guardPokemonId: guardPokemonId, enabled: enabled,
                lastModifiedTimestamp: lastModifiedTimestamp, teamId: teamId, raidEndTimestamp: raidEndTimestamp,
                raidSpawnTimestamp: raidSpawnTimestamp, raidBattleTimestamp: raidBattleTimestamp,
                raidPokemonId: raidPokemonId, raidLevel: raidLevel, availableSlots: availableSlots, updated: updated,
                exRaidEligible: exRaidEligible, inBattle: inBattle, raidPokemonMove1: raidPokemonMove1,
                raidPokemonMove2: raidPokemonMove2, raidPokemonForm: raidPokemonForm,
                raidPokemonCostume: raidPokemonCostume, raidPokemonCp: raidPokemonCp,
                raidPokemonGender: raidPokemonGender, raidPokemonEvolution: raidPokemonEvolution,
                raidIsExclusive: raidIsExclusive, cellId: cellId, totalCp: totalCp, sponsorId: sponsorId,
                arScanEligible: arScanEligible)
            )
        }
        return gyms
    }

    public static func getWithCellIDs(mysql: MySQL?=nil, cellIDs: [UInt64]) throws -> [Gym] {

        if cellIDs.count > 10000 {
            var result = [Gym]()
            for i in 0..<(Int(ceil(Double(cellIDs.count)/10000.0))) {
                let start = 10000 * i
                let end = min(10000 * (i+1) - 1, cellIDs.count - 1)
                let splice = Array(cellIDs[start...end])
                if let spliceResult = try? getWithCellIDs(mysql: mysql, cellIDs: splice) {
                    result += spliceResult
                }
            }
            return result
        }

        if cellIDs.count == 0 {
            return [Gym]()
        }

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[GYM] Failed to connect to database.")
            throw DBController.DBError()
        }

        var inSQL = "("
        for _ in 1..<cellIDs.count {
            inSQL += "?, "
        }
        inSQL += "?)"

        let sql = """
            SELECT id, lat, lon, name, url, guarding_pokemon_id, last_modified_timestamp, team_id, raid_end_timestamp,
                   raid_spawn_timestamp, raid_battle_timestamp, raid_pokemon_id, enabled, availble_slots, updated,
                   raid_level, ex_raid_eligible, in_battle, raid_pokemon_move_1, raid_pokemon_move_2, raid_pokemon_form,
                   raid_pokemon_costume, raid_pokemon_cp, raid_pokemon_gender, raid_is_exclusive, cell_id, total_cp,
                   sponsor_id, raid_pokemon_evolution, ar_scan_eligible
            FROM gym
            WHERE cell_id IN \(inSQL) AND deleted = false
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        for id in cellIDs {
            mysqlStmt.bindParam(id)
        }

        guard mysqlStmt.execute() else {
            Log.error(message: "[GYM] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var gyms = [Gym]()
        while let result = results.next() {
            let id = result[0] as! String
            let lat = result[1] as! Double
            let lon = result[2] as! Double
            let name = result[3] as? String
            let url = result[4] as? String
            let guardPokemonId = result[5] as? UInt16
            let lastModifiedTimestamp = result[6] as? UInt32
            let teamId = result[7] as? UInt8
            let raidEndTimestamp = result[8] as? UInt32
            let raidSpawnTimestamp = result[9] as? UInt32
            let raidBattleTimestamp = result[10] as? UInt32
            let raidPokemonId = result[11] as? UInt16
            let enabled = (result[12] as? UInt8)?.toBool()
            let availableSlots = result[13] as? UInt16
            let updated = result[14] as! UInt32
            let raidLevel = result[15] as? UInt8
            let exRaidEligible = (result[16] as? UInt8)?.toBool()
            let inBattle = (result[17] as? UInt8)?.toBool()
            let raidPokemonMove1 = result[18] as? UInt16
            let raidPokemonMove2 = result[19] as? UInt16
            let raidPokemonForm = result[20] as? UInt16
            let raidPokemonCostume = result[21] as? UInt16
            let raidPokemonCp = result[22] as? UInt32
            let raidPokemonGender = result[23] as? UInt8
            let raidIsExclusive = (result[24] as? UInt8)?.toBool()
            let cellId = result[25] as? UInt64
            let totalCp = result[26] as? UInt32
            let sponsorId = result[27] as? UInt16
            let raidPokemonEvolution = result[28] as? UInt8
            let arScanEligible = (result[29] as? UInt8)?.toBool()

            gyms.append(Gym(
                id: id, lat: lat, lon: lon, name: name, url: url, guardPokemonId: guardPokemonId, enabled: enabled,
                lastModifiedTimestamp: lastModifiedTimestamp, teamId: teamId, raidEndTimestamp: raidEndTimestamp,
                raidSpawnTimestamp: raidSpawnTimestamp, raidBattleTimestamp: raidBattleTimestamp,
                raidPokemonId: raidPokemonId, raidLevel: raidLevel, availableSlots: availableSlots, updated: updated,
                exRaidEligible: exRaidEligible, inBattle: inBattle, raidPokemonMove1: raidPokemonMove1,
                raidPokemonMove2: raidPokemonMove2, raidPokemonForm: raidPokemonForm,
                raidPokemonCostume: raidPokemonCostume, raidPokemonCp: raidPokemonCp,
                raidPokemonGender: raidPokemonGender, raidPokemonEvolution: raidPokemonEvolution,
                raidIsExclusive: raidIsExclusive, cellId: cellId, totalCp: totalCp, sponsorId: sponsorId,
                arScanEligible: arScanEligible)
            )
        }
        return gyms
    }

    public static func clearOld(mysql: MySQL?=nil, ids: [String], cellId: UInt64) throws -> UInt {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[GYM] Failed to connect to database.")
            throw DBController.DBError()
        }

        let notInSQL: String

        if ids.count != 0 {
            var inSQL = "("
            for _ in 1..<ids.count {
                inSQL += "?, "
            }
            inSQL += "?)"
            notInSQL = "AND id NOT IN \(inSQL)"
        } else {
            notInSQL = ""
        }

        let sql = """
            UPDATE gym
            SET deleted = true
            WHERE cell_id = ? \(notInSQL) AND deleted = false
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(cellId)
        for id in ids {
            mysqlStmt.bindParam(id)
        }

        guard mysqlStmt.execute() else {
            Log.error(message: "[GYM] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        return mysqlStmt.affectedRows()

    }

    public static func convertPokestopsToGyms(mysql: MySQL?=nil) throws -> UInt {
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[GYM] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
        UPDATE `gym` INNER JOIN `pokestop` ON pokestop.id = gym.id
        SET gym.name = pokestop.name, gym.url = pokestop.url
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        guard mysqlStmt.execute() else {
            Log.error(message: "[GYM] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        cache?.clear()

        return mysqlStmt.affectedRows()
    }

    public static func shouldUpdate(old: Gym, new: Gym) -> Bool {
        if old.hasChanges {
            old.hasChanges = false
            return true
        }
        return
            new.lastModifiedTimestamp != old.lastModifiedTimestamp ||
            new.name != old.name ||
            new.url != old.url ||
            new.enabled != old.enabled ||
            new.raidEndTimestamp != old.raidEndTimestamp ||
            new.raidPokemonId != old.raidPokemonId ||
            new.teamId != old.teamId ||
            new.guardPokemonId != old.guardPokemonId ||
            new.availableSlots != old.availableSlots ||
            new.totalCp != old.totalCp ||
            new.exRaidEligible != old.exRaidEligible ||
            new.sponsorId != old.sponsorId ||
            new.arScanEligible != old.arScanEligible ||
            fabs(new.lat - old.lat) >= 0.000001 ||
            fabs(new.lon - old.lon) >= 0.000001
    }

    static func == (lhs: Gym, rhs: Gym) -> Bool {
        return lhs.id == rhs.id
    }

}
