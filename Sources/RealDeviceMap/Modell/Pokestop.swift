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

class Pokestop: JSONConvertibleObject, WebHookEvent, Hashable {

    public static var lureTime: UInt32 = 1800

    class ParsingError: Error {}

    override func getJSONValues() -> [String: Any] {
        return [
            "id": id,
            "lat": lat,
            "lon": lon,
            "name": name as Any,
            "url": url as Any,
            "lure_expire_timestamp": lureExpireTimestamp as Any,
            "last_modified_timestamp": lastModifiedTimestamp as Any,
            "enabled": enabled as Any,
            "quest_type": questType as Any,
            "quest_target": questTarget as Any,
            "quest_template": questTemplate as Any,
            "quest_conditions": questConditions as Any,
            "quest_rewards": questRewards as Any,
            "quest_timestamp": questTimestamp as Any,
            "lure_id": lureId as Any,
            "pokestop_display": pokestopDisplay as Any,
            "incident_expire_timestamp": incidentExpireTimestamp as Any,
            "grunt_type": gruntType as Any,
            "ar_scan_eligible": arScanEligible as Any,
            "updated": updated ?? 1
        ]
    }

    func getWebhookValues(type: String) -> [String: Any] {
        if type == "quest" {
            let message: [String: Any] = [
                "pokestop_id": id,
                "latitude": lat,
                "longitude": lon,
                "type": questType!,
                "target": questTarget!,
                "template": questTemplate!,
                "conditions": questConditions!,
                "rewards": questRewards!,
                "updated": questTimestamp!,
                "pokestop_name": name ?? "Unknown",
                "ar_scan_eligible": arScanEligible ?? 0,
                "pokestop_url": url ?? ""
            ]
            return [
                "type": "quest",
                "message": message
            ]
        } else if type == "invasion" {
            let message: [String: Any] = [
                "pokestop_id": id,
                "latitude": lat,
                "longitude": lon,
                "name": name ?? "Unknown",
                "url": url ?? "",
                "lure_expiration": lureExpireTimestamp ?? 0,
                "last_modified": lastModifiedTimestamp ?? 0,
                "enabled": enabled ?? true,
                "lure_id": lureId ?? 0,
                "pokestop_display": pokestopDisplay ?? 0,
                "incident_expire_timestamp": incidentExpireTimestamp ?? 0,
                "grunt_type": gruntType ?? 0,
                "ar_scan_eligible": arScanEligible ?? 0,
                "updated": updated ?? 1
            ]
            return [
                "type": "invasion",
                "message": message
            ]
        } else {
            let message: [String: Any] = [
                "pokestop_id": id,
                "latitude": lat,
                "longitude": lon,
                "name": name ?? "Unknown",
                "url": url ?? "",
                "lure_expiration": lureExpireTimestamp ?? 0,
                "last_modified": lastModifiedTimestamp ?? 0,
                "enabled": enabled ?? true,
                "lure_id": lureId ?? 0,
                "pokestop_display": pokestopDisplay ?? 0,
                "incident_expire_timestamp": incidentExpireTimestamp ?? 0,
                "ar_scan_eligible": arScanEligible ?? 0,
                "updated": updated ?? 1
            ]
            return [
                "type": "pokestop",
                "message": message
            ]
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var id: String
    var lat: Double
    var lon: Double

    var enabled: Bool?
    var lureExpireTimestamp: UInt32?
    var lastModifiedTimestamp: UInt32?
    var name: String?
    var url: String?
    var sponsorId: UInt16?
    var updated: UInt32?
    var arScanEligible: Bool?
    var questType: UInt32?
    var questTemplate: String?
    var questTarget: UInt16?
    var questTimestamp: UInt32?
    var questConditions: [[String: Any]]?
    var questRewards: [[String: Any]]?
    var cellId: UInt64?
    var lureId: Int16?
    var pokestopDisplay: UInt16?
    var incidentExpireTimestamp: UInt32?
    var gruntType: UInt16?

    var hasChanges = false
    var hasQuestChanges = false

    static var cache: MemoryCache<Pokestop>?

    init(id: String, lat: Double, lon: Double, name: String?, url: String?, enabled: Bool?,
         lureExpireTimestamp: UInt32?, lastModifiedTimestamp: UInt32?, updated: UInt32?, questType: UInt32?,
         questTarget: UInt16?, questTimestamp: UInt32?, questConditions: [[String: Any]]?,
         questRewards: [[String: Any]]?, questTemplate: String?, cellId: UInt64?, lureId: Int16?,
         pokestopDisplay: UInt16?, incidentExpireTimestamp: UInt32?, gruntType: UInt16?, sponsorId: UInt16?,
         arScanEligible: Bool?) {
        self.id = id
        self.lat = lat
        self.lon = lon
        self.name = name
        self.url = url
        self.enabled = enabled
        self.lureExpireTimestamp = lureExpireTimestamp
        self.lastModifiedTimestamp = lastModifiedTimestamp
        self.updated = updated
        self.questType = questType
        self.questTarget = questTarget
        self.questTimestamp = questTimestamp
        self.questConditions = questConditions
        self.questRewards = questRewards
        self.questTemplate = questTemplate
        self.cellId = cellId
        self.lureId = lureId
        self.pokestopDisplay = pokestopDisplay
        self.incidentExpireTimestamp = incidentExpireTimestamp
        self.gruntType = gruntType
        self.sponsorId = sponsorId
        self.arScanEligible = arScanEligible
    }

    init(fortData: PokemonFortProto, cellId: UInt64) {

        self.id = fortData.fortID
        self.lat = fortData.latitude
        self.lon = fortData.longitude
        if fortData.sponsor != .unset {
            self.sponsorId = UInt16(fortData.sponsor.rawValue)
        }
        self.enabled = fortData.enabled
        self.arScanEligible = fortData.isArScanEligible
        let lastModifiedTimestamp = UInt32(fortData.lastModifiedMs / 1000)
        if fortData.activeFortModifier.contains(.troyDisk) ||
            fortData.activeFortModifier.contains(.troyDiskGlacial) ||
            fortData.activeFortModifier.contains(.troyDiskMossy) ||
            fortData.activeFortModifier.contains(.troyDiskMagnetic) ||
            fortData.activeFortModifier.contains(.troyDiskRainy) {
            self.lureExpireTimestamp = lastModifiedTimestamp + Pokestop.lureTime
            self.lureId = Int16(fortData.activeFortModifier[0].rawValue)
        }
        self.lastModifiedTimestamp = lastModifiedTimestamp
        if fortData.imageURL != "" {
            self.url = fortData.imageURL
        }
        if fortData.hasPokestopDisplay {
            self.pokestopDisplay = UInt16(fortData.pokestopDisplay.characterDisplay.style.rawValue)
            self.incidentExpireTimestamp = UInt32(fortData.pokestopDisplay.incidentExpirationMs / 1000)
            self.gruntType = UInt16(fortData.pokestopDisplay.characterDisplay.character.rawValue)
        } else if fortData.pokestopDisplays.count != 0 {
            self.pokestopDisplay = UInt16(fortData.pokestopDisplays[0].characterDisplay.style.rawValue)
            self.incidentExpireTimestamp = UInt32(fortData.pokestopDisplays[0].incidentExpirationMs / 1000)
            self.gruntType = UInt16(fortData.pokestopDisplays[0].characterDisplay.character.rawValue)
        }

        self.cellId = cellId

    }

    public func addDetails(fortData: FortDetailsOutProto) {

        self.id = fortData.id
        self.lat = fortData.latitude
        self.lon = fortData.longitude
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

    public func addQuest(questData: QuestProto) {

        self.questType = questData.questType.rawValue.toUInt32()
        self.questTarget = UInt16(questData.goal.target)
        self.questTemplate = questData.templateID.lowercased()
        self.hasChanges = true
        self.hasQuestChanges = true

        var conditions = [[String: Any]]()
        var rewards = [[String: Any]]()

        for conditionData in questData.goal.condition {
            var condition = [String: Any]()
            var infoData = [String: Any]()
            condition["type"] = conditionData.type.rawValue

            switch conditionData.type {
            case .withBadgeType:
                let info = conditionData.withBadgeType
                infoData["amount"] = info.amount
                infoData["badge_rank"] = info.badgeRank
                var badgeTypesById = [Int]()
                for badge in info.badgeType {
                    badgeTypesById.append(badge.rawValue)
                }
                infoData["badge_types"] = badgeTypesById
            case .withItem:
                let info = conditionData.withItem
                if info.item.rawValue != 0 {
                    infoData["item_id"] = info.item.rawValue
                }
            case .withRaidLevel:
                let info = conditionData.withRaidLevel
                var raidLevelById = [Int]()
                for raidLevel in info.raidLevel {
                    raidLevelById.append(raidLevel.rawValue)
                }
                infoData["raid_levels"] = raidLevelById
            case .withPokemonType:
                let info = conditionData.withPokemonType
                var pokemonTypesById = [Int]()
                for type in info.pokemonType {
                    pokemonTypesById.append(type.rawValue)
                }
                infoData["pokemon_type_ids"] = pokemonTypesById
            case .withPokemonCategory:
                let info = conditionData.withPokemonCategory
                if info.categoryName != "" {
                    infoData["category_name"] = info.categoryName
                }
                var pokemonById = [Int]()
                for pokemon in info.pokemonIds {
                    pokemonById.append(pokemon.rawValue)
                }
                infoData["pokemon_ids"] = pokemonById
            case .withWinRaidStatus: break
            case .withThrowType:
                let info = conditionData.withThrowType
                if info.throwType.rawValue != 0 {
                    infoData["throw_type_id"] = info.throwType.rawValue
                }
                infoData["hit"] = info.hit
            case .withThrowTypeInARow:
                let info = conditionData.withThrowType
                if info.throwType.rawValue != 0 {
                    infoData["throw_type_id"] = info.throwType.rawValue
                }
                infoData["hit"] = info.hit
            case .withLocation:
                let info = conditionData.withLocation
                infoData["cell_ids"] = info.s2CellID
            case .withDistance:
                let info = conditionData.withDistance
                infoData["distance"] = info.distanceKm
            case .withPokemonAlignment:
                let info = conditionData.withPokemonAlignment
                infoData["alignment_ids"] = info.alignment.map({ (alignment) -> Int in
                    return alignment.rawValue
                })
            case .withInvasionCharacter:
                let info = conditionData.withInvasionCharacter
                infoData["character_category_ids"] = info.category.map({ (category) -> Int in
                    return category.rawValue
                })
            case .withNpcCombat:
                let info = conditionData.withNpcCombat
                infoData["win"] = info.requiresWin
                infoData["trainer_ids"] = info.combatNpcTrainerID
            case .withPvpCombat:
                let info = conditionData.withPvpCombat
                infoData["win"] = info.requiresWin
                infoData["template_ids"] = info.combatLeagueTemplateID
            case .withPlayerLevel:
                let info = conditionData.withPlayerLevel
                infoData["level"] = info.level
            case .withBuddy:
                let info = conditionData.withBuddy
                infoData["min_buddy_level"] = info.minBuddyLevel.rawValue
                infoData["must_be_on_map"] = info.mustBeOnMap
            case .withDailyBuddyAffection:
                let info = conditionData.withDailyBuddyAffection
                infoData["min_buddy_affection_earned_today"] = info.minBuddyAffectionEarnedToday
            case .withTempEvoPokemon:
                let info = conditionData.withTempEvoID
                infoData["raid_pokemon_evolutions"] = info.megaForm.map({ (evolution) -> Int in
                    return evolution.rawValue
                })
            case .withWinGymBattleStatus: break
            case .withSuperEffectiveCharge: break
            case .withUniquePokestop: break
            case .withQuestContext: break
            case .withWinBattleStatus: break
            case .withCurveBall: break
            case .withNewFriend: break
            case .withDaysInARow: break
            case .withWeatherBoost: break
            case .withDailyCaptureBonus: break
            case .withDailySpinBonus: break
            case .withUniquePokemon: break
            case .withBuddyInterestingPoi: break
            case .withPokemonLevel: break
            case .withSingleDay: break
            case .withUniquePokemonTeam: break
            case .withMaxCp: break
            case .withLuckyPokemon: break
            case .withLegendaryPokemon: break
            case .withGblRank: break
            case .withCatchesInARow: break
            case .withEncounterType: break
            case .withCombatType: break
            case .withGeotargetedPoi: break
            case .withItemType: break
            case .unset: break
            case .UNRECOGNIZED: break
            }

            if !infoData.isEmpty {
                condition["info"] = infoData
            }
            conditions.append(condition)
        }

        for rewardData in questData.questRewards {
            var reward = [String: Any]()
            var infoData = [String: Any]()
            reward["type"] = rewardData.type.rawValue

            switch rewardData.type {
            case .experience:
                let info = rewardData.exp
                infoData["amount"] = info
            case .item:
                let info = rewardData.item
                infoData["amount"] = info.amount
                infoData["item_id"] = info.item.rawValue
            case .stardust:
                let info = rewardData.stardust
                infoData["amount"] = info
            case .candy:
                let info = rewardData.candy
                infoData["amount"] = info.amount
                infoData["pokemon_id"] = info.pokemonID.rawValue
            case .xlCandy:
                let info = rewardData.xlCandy
                infoData["amount"] = info.amount
                infoData["pokemon_id"] = info.pokemonID.rawValue
            case .pokemonEncounter:
                let info = rewardData.pokemonEncounter
                if info.isHiddenDitto {
                    infoData["pokemon_id"] = 132
                    infoData["pokemon_id_display"] = info.pokemonID.rawValue
                } else {
                    infoData["pokemon_id"] = info.pokemonID.rawValue
                }
                infoData["costume_id"] = info.pokemonDisplay.costume.rawValue
                infoData["form_id"] = info.pokemonDisplay.form.rawValue
                infoData["gender_id"] = info.pokemonDisplay.gender.rawValue
                infoData["shiny"] = info.pokemonDisplay.shiny
            case .pokecoin:
                let info = rewardData.pokecoin
                infoData["amount"] = info
            case .sticker:
                let info = rewardData.sticker
                infoData["amount"] = info.amount
                infoData["sticker_id"] = info.stickerID
            case .megaResource:
                let info = rewardData.megaResource
                infoData["amount"] = info.amount
                infoData["pokemon_id"] = info.pokemonID.rawValue
            case .avatarClothing: break
            case .quest: break
            case .levelCap: break
            case .unset: break
            case .UNRECOGNIZED: break
            }

            reward["info"] = infoData
            rewards.append(reward)
        }

        self.questConditions = conditions
        self.questRewards = rewards
        self.questTimestamp = UInt32(Date().timeIntervalSince1970)
    }

    public func save(mysql: MySQL?=nil, updateQuest: Bool=false) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKESTOP] Failed to connect to database.")
            throw DBController.DBError()
        }

        let oldPokestop: Pokestop?
        do {
            oldPokestop = try Pokestop.getWithId(mysql: mysql, id: id, withDeleted: true)
        } catch {
            oldPokestop = nil
        }
        let mysqlStmt = MySQLStmt(mysql)

        updated = UInt32(Date().timeIntervalSince1970)

        let now = UInt32(Date().timeIntervalSince1970)
        if oldPokestop == nil {
            let sql = """
                INSERT INTO pokestop (
                    id, lat, lon, name, url, enabled, lure_expire_timestamp, last_modified_timestamp, quest_type,
                    quest_timestamp, quest_target, quest_conditions, quest_rewards, quest_template, cell_id, lure_id,
                    pokestop_display, incident_expire_timestamp, grunt_type, sponsor_id, ar_scan_eligible,
                    updated, first_seen_timestamp)
                VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    UNIX_TIMESTAMP(), UNIX_TIMESTAMP())
            """
            self.updated = now
            _ = mysqlStmt.prepare(statement: sql)
            mysqlStmt.bindParam(id)
        } else {
            if oldPokestop!.cellId != nil && self.cellId == nil {
                self.cellId = oldPokestop!.cellId
            }

            if oldPokestop!.name != nil && self.name == nil {
                self.name = oldPokestop!.name
            }
            if oldPokestop!.url != nil && self.url == nil {
                self.url = oldPokestop!.url
            }
            if updateQuest && oldPokestop!.questType != nil && self.questType == nil {
                self.questType = oldPokestop!.questType
                self.questTarget = oldPokestop!.questTarget
                self.questConditions = oldPokestop!.questConditions
                self.questRewards = oldPokestop!.questRewards
                self.questTimestamp = oldPokestop!.questTimestamp
                self.questTemplate = oldPokestop!.questTemplate
            }
            if oldPokestop!.lureId != nil && self.lureId == nil {
                self.lureId = oldPokestop!.lureId
            }

            guard Pokestop.shouldUpdate(old: oldPokestop!, new: self) else {
                return
            }

            if oldPokestop!.lureExpireTimestamp ?? 0 < self.lureExpireTimestamp ?? 0 {
                WebHookController.global.addLureEvent(pokestop: self)
            }
            if oldPokestop!.incidentExpireTimestamp ?? 0 < self.incidentExpireTimestamp ?? 0 {
                WebHookController.global.addInvasionEvent(pokestop: self)
            }
            if updateQuest && questTimestamp ?? 0 > oldPokestop!.questTimestamp ?? 0 {
                WebHookController.global.addQuestEvent(pokestop: self)
            }

            let questSQL: String
            if updateQuest {
                questSQL = "quest_type = ?, quest_timestamp = ?, quest_target = ?, quest_conditions = ?, " +
                           "quest_rewards = ?, quest_template = ?,"
            } else {
                questSQL = ""
            }

            let nameSQL = name != nil ? "name = ?, " : ""
            let sql = """
                UPDATE pokestop
                SET lat = ?, lon = ?, \(nameSQL) url = ?, enabled = ?, lure_expire_timestamp = ?,
                    last_modified_timestamp = ?, updated = UNIX_TIMESTAMP(), \(questSQL) cell_id = ?,
                    lure_id = ?, pokestop_display = ?, incident_expire_timestamp = ?, grunt_type = ?,
                    deleted = false, sponsor_id = ?, ar_scan_eligible = ?
                WHERE id = ?
            """
            self.updated = now
            _ = mysqlStmt.prepare(statement: sql)
        }

        mysqlStmt.bindParam(lat)
        mysqlStmt.bindParam(lon)
        if oldPokestop == nil || name != nil {
            mysqlStmt.bindParam(name)
        }
        mysqlStmt.bindParam(url)
        mysqlStmt.bindParam(enabled)
        mysqlStmt.bindParam(lureExpireTimestamp)
        mysqlStmt.bindParam(lastModifiedTimestamp)
        if updateQuest || oldPokestop == nil {
            mysqlStmt.bindParam(questType)
            mysqlStmt.bindParam(questTimestamp)
            mysqlStmt.bindParam(questTarget)
            mysqlStmt.bindParam(questConditions.jsonEncodeForceTry())
            mysqlStmt.bindParam(questRewards.jsonEncodeForceTry())
            mysqlStmt.bindParam(questTemplate)
        }
        mysqlStmt.bindParam(cellId)
        mysqlStmt.bindParam(lureId ?? 0)
        mysqlStmt.bindParam(pokestopDisplay)
        mysqlStmt.bindParam(incidentExpireTimestamp)
        mysqlStmt.bindParam(gruntType)
        mysqlStmt.bindParam(sponsorId)
        mysqlStmt.bindParam(arScanEligible)

        if oldPokestop != nil {
            mysqlStmt.bindParam(id)
        }

        guard mysqlStmt.execute() else {
            if mysqlStmt.errorCode() == 1062 {
                Log.debug(message: "[POKESTOP] Duplicated key. Skipping...")
            } else {
                Log.error(message: "[POKESTOP] Failed to execute query. (\(mysqlStmt.errorMessage()))")
            }
            throw DBController.DBError()
        }

        Pokestop.cache?.set(id: self.id, value: self)

        if oldPokestop == nil {
            WebHookController.global.addPokestopEvent(pokestop: self)
            if lureExpireTimestamp ?? 0 > 0 {
                WebHookController.global.addLureEvent(pokestop: self)
            }
            if questTimestamp ?? 0 > 0 {
                WebHookController.global.addQuestEvent(pokestop: self)
            }
            if incidentExpireTimestamp ?? 0 > 0 {
                WebHookController.global.addInvasionEvent(pokestop: self)
            }
        } else {
            if oldPokestop!.lureExpireTimestamp ?? 0 < self.lureExpireTimestamp ?? 0 {
                WebHookController.global.addLureEvent(pokestop: self)
            }
            if oldPokestop!.incidentExpireTimestamp ?? 0 < self.incidentExpireTimestamp ?? 0 {
                WebHookController.global.addInvasionEvent(pokestop: self)
            }
            if updateQuest && (hasQuestChanges || questTimestamp ?? 0 > oldPokestop!.questTimestamp ?? 0) {
                hasQuestChanges = false
                WebHookController.global.addQuestEvent(pokestop: self)
            }
        }
    }

    //  swiftlint:disable:next function_parameter_count
    public static func getAll(
        mysql: MySQL?=nil, minLat: Double, maxLat: Double, minLon: Double, maxLon: Double, updated: UInt32,
        questsOnly: Bool, showQuests: Bool, showLures: Bool, showInvasions: Bool, questFilterExclude: [String]?=nil,
        pokestopFilterExclude: [String]?=nil, pokestopShowOnlyAr: Bool=false) throws -> [Pokestop] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKESTOP] Failed to connect to database.")
            throw DBController.DBError()
        }

        var excludedTypes = [Int]()
        var excludedPokemon = [Int]()
        var excludedItems = [Int]()
        var excludedLures = [Int]()
        var excludeNormal = Bool()
        var excludeInvasion = Bool()

        if showQuests && questFilterExclude != nil {
            for filter in questFilterExclude! {
                if filter.contains(string: "p") {
                    if let id = filter.stringByReplacing(string: "p", withString: "").toInt() {
                        excludedPokemon.append(id)
                    }
                } else if filter.contains(string: "i") {
                    if let id = filter.stringByReplacing(string: "i", withString: "").toInt() {
                        if id > 0 {
                            excludedItems.append(id)
                        } else if id < 0 {
                            excludedTypes.append(-id)
                        }
                    }
                }
            }
        }

        if pokestopFilterExclude != nil {
            for filter in pokestopFilterExclude! {
                if filter.contains(string: "normal") {
                    excludeNormal = true
                } else if showLures && filter.contains(string: "l") {
                    if let id = filter.stringByReplacing(string: "l", withString: "").toInt() {
                        excludedLures.append(id + 500)
                    }
                } else if showInvasions && filter.contains(string: "invasion") {
                    excludeInvasion = true
                }
            }
        }

        let excludeTypeSQL: String
        let excludePokemonSQL: String
        let excludeItemSQL: String
        let excludeLureSQL: String
        var excludePokestopSQL: String
        var onlyArSQL: String

        if showQuests {
            if excludedTypes.isEmpty {
                excludeTypeSQL = ""
            } else {
                var sqlExcludeCreate = "AND (quest_reward_type IS NULL OR quest_reward_type NOT IN ("
                for _ in 1..<excludedTypes.count {
                    sqlExcludeCreate += "?, "
                }
                sqlExcludeCreate += "?))"
                excludeTypeSQL = sqlExcludeCreate
            }

            if excludedPokemon.isEmpty {
                excludePokemonSQL = ""
            } else {
                var sqlExcludeCreate = "AND (quest_pokemon_id IS NULL OR quest_pokemon_id NOT IN ("
                for _ in 1..<excludedPokemon.count {
                    sqlExcludeCreate += "?, "
                }
                sqlExcludeCreate += "?))"
                excludePokemonSQL = sqlExcludeCreate
            }

            if excludedItems.isEmpty {
                excludeItemSQL = ""
            } else {
                var sqlExcludeCreate = "AND (quest_item_id IS NULL OR quest_item_id NOT IN ("
                for _ in 1..<excludedItems.count {
                    sqlExcludeCreate += "?, "
                }
                sqlExcludeCreate += "?))"
                excludeItemSQL = sqlExcludeCreate
            }
        } else {
            excludeTypeSQL = ""
            excludePokemonSQL = ""
            excludeItemSQL = ""
        }

        if excludeNormal || !excludedLures.isEmpty || excludeInvasion {
            if excludedLures.isEmpty {
                excludeLureSQL = ""
            } else {
                var sqlExcludeCreate = "AND (lure_id NOT IN ("
                for _ in excludedLures {
                    sqlExcludeCreate += "?, "
                }
                sqlExcludeCreate += "?))"
                excludeLureSQL = sqlExcludeCreate
            }

            let hasLureSQL = "(lure_expire_timestamp IS NOT NULL AND lure_expire_timestamp >= " +
                             "UNIX_TIMESTAMP() \(excludeLureSQL))"
            let hasNoLureSQL = "(lure_expire_timestamp IS NULL OR lure_expire_timestamp < " +
                               "UNIX_TIMESTAMP())"
            let hasInvasionSQL = "(incident_expire_timestamp IS NOT NULL AND incident_expire_timestamp >= " +
                                 "UNIX_TIMESTAMP())"
            let hasNoInvasionSQL = "(incident_expire_timestamp IS NULL OR incident_expire_timestamp < UNIX_TIMESTAMP())"

            excludePokestopSQL = "AND ("
            if excludeNormal && excludeInvasion {
                excludePokestopSQL += "(\(hasLureSQL) AND \(hasNoInvasionSQL))"
            } else if excludeNormal && !excludeInvasion {
                excludePokestopSQL += "(\(hasLureSQL) OR \(hasInvasionSQL))"
            } else if !excludeNormal && excludeInvasion {
                excludePokestopSQL += "((\(hasNoLureSQL) OR \(hasLureSQL)) AND \(hasNoInvasionSQL))"
            } else {
                excludePokestopSQL += "(\(hasNoLureSQL) OR \(hasLureSQL))"
            }
            excludePokestopSQL += ")"
        } else {
            excludePokestopSQL = ""
        }

        if pokestopShowOnlyAr && !questsOnly {
            onlyArSQL = "AND ar_scan_eligible = TRUE"
        } else {
            onlyArSQL = ""
        }

        var sql = """
            SELECT id, lat, lon, name, url, enabled, lure_expire_timestamp, last_modified_timestamp, updated,
                   quest_type, quest_timestamp, quest_target, CAST(quest_conditions AS CHAR),
                   CAST(quest_rewards AS CHAR), quest_template, cell_id, lure_id, pokestop_display,
                   incident_expire_timestamp, grunt_type, sponsor_id, ar_scan_eligible
            FROM pokestop
            WHERE lat >= ? AND lat <= ? AND lon >= ? AND lon <= ? AND updated > ? AND
                  deleted = false \(excludeTypeSQL) \(excludePokemonSQL) \(excludeItemSQL) \(excludePokestopSQL)
                  \(onlyArSQL)
        """
        if questsOnly {
            sql += " AND quest_reward_type IS NOT NULL"
        }

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(minLat)
        mysqlStmt.bindParam(maxLat)
        mysqlStmt.bindParam(minLon)
        mysqlStmt.bindParam(maxLon)
        mysqlStmt.bindParam(updated)
        for id in excludedTypes {
            if id == 1 {
                mysqlStmt.bindParam(3)
            } else if id == 2 {
                mysqlStmt.bindParam(1)
            } else if id == 3 {
                mysqlStmt.bindParam(4)
            } else if id == 4 {
                mysqlStmt.bindParam(8)
            } else if id == 5 {
                mysqlStmt.bindParam(11)
            } else if id == 6 {
                mysqlStmt.bindParam(12)
            } else {
                mysqlStmt.bindParam(id)
            }
        }
        for id in excludedPokemon {
            mysqlStmt.bindParam(id)
        }
        for id in excludedItems {
            mysqlStmt.bindParam(id)
        }
        for id in excludedLures {
            mysqlStmt.bindParam(id)
        }

        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var pokestops = [Pokestop]()
        while let result = results.next() {
            let id = result[0] as! String
            let lat = result[1] as! Double
            let lon = result[2] as! Double
            let name = result[3] as? String
            let url = result[4] as? String
            let enabledInt = result[5] as? UInt8
            let enabled = enabledInt?.toBool()
            let lureExpireTimestamp: UInt32?
            if showLures {
                lureExpireTimestamp = result[6] as? UInt32
            } else {
                lureExpireTimestamp = nil
            }
            let lastModifiedTimestamp = result[7] as? UInt32
            let updated = result[8] as! UInt32

            let questType: UInt32?
            let questTimestamp: UInt32?
            let questTarget: UInt16?
            let questConditions: [[String: Any]]?
            let questRewards: [[String: Any]]?
            let questTemplate: String?

            if showQuests {
                questType = result[9] as? UInt32
                questTimestamp = result[10] as? UInt32
                questTarget = result[11] as? UInt16
                questConditions = (result[12] as? String)?.jsonDecodeForceTry() as? [[String: Any]]
                questRewards = (result[13] as? String)?.jsonDecodeForceTry() as? [[String: Any]]
                questTemplate = result[14] as? String
            } else {
                questType = nil
                questTimestamp = nil
                questTarget = nil
                questConditions = nil
                questRewards = nil
                questTemplate = nil
            }

            let cellId = result[15] as? UInt64
            let lureId: Int16?
            if showLures {
                lureId = result[16] as? Int16
            } else {
                lureId = nil
            }
            let pokestopDisplay: UInt16?
            let incidentExpireTimestamp: UInt32?
            let gruntType: UInt16?
            if showInvasions {
                pokestopDisplay = result[17] as? UInt16
                incidentExpireTimestamp = result[18] as? UInt32
                gruntType = result[19] as? UInt16
            } else {
                pokestopDisplay = nil
                incidentExpireTimestamp = nil
                gruntType = nil
            }
            let sponsorId = result[20] as? UInt16
            let arScanEligible = (result[21] as? UInt8)?.toBool()

            pokestops.append(Pokestop(
                id: id, lat: lat, lon: lon, name: name, url: url, enabled: enabled,
                lureExpireTimestamp: lureExpireTimestamp, lastModifiedTimestamp: lastModifiedTimestamp,
                updated: updated, questType: questType, questTarget: questTarget, questTimestamp: questTimestamp,
                questConditions: questConditions, questRewards: questRewards, questTemplate: questTemplate,
                cellId: cellId, lureId: lureId, pokestopDisplay: pokestopDisplay,
                incidentExpireTimestamp: incidentExpireTimestamp, gruntType: gruntType, sponsorId: sponsorId,
                arScanEligible: arScanEligible
            ))
        }
        return pokestops

    }

    public static func getIn(mysql: MySQL?=nil, ids: [String]) throws -> [Pokestop] {

        if ids.count > 10000 {
            var result = [Pokestop]()
            for i in 0..<(Int(ceil(Double(ids.count)/10000.0))) {
                let start = 10000 * i
                let end = min(10000 * (i+1) - 1, ids.count - 1)
                let splice = Array(ids[start...end])
                if let spliceResult = try? getIn(mysql: mysql, ids: splice) {
                    result += spliceResult
                }
            }
            return result
        }

        if ids.count == 0 {
            return [Pokestop]()
        }

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKESTOP] Failed to connect to database.")
            throw DBController.DBError()
        }

        var inSQL = "("
        for _ in 1..<ids.count {
            inSQL += "?, "
        }
        inSQL += "?)"

        let sql = """
            SELECT id, lat, lon, name, url, enabled, lure_expire_timestamp, last_modified_timestamp, updated,
                   quest_type, quest_timestamp, quest_target, CAST(quest_conditions AS CHAR),
                   CAST(quest_rewards AS CHAR), quest_template, cell_id, lure_id, pokestop_display,
                   incident_expire_timestamp, grunt_type, sponsor_id, ar_scan_eligible
            FROM pokestop
            WHERE id IN \(inSQL) AND deleted = false
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        for id in ids {
            mysqlStmt.bindParam(id)
        }

        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var pokestops = [Pokestop]()
        while let result = results.next() {
            let id = result[0] as! String
            let lat = result[1] as! Double
            let lon = result[2] as! Double
            let name = result[3] as? String
            let url = result[4] as? String
            let enabledInt = result[5] as? UInt8
            let enabled = enabledInt?.toBool()
            let lureExpireTimestamp = result[6] as? UInt32
            let lastModifiedTimestamp = result[7] as? UInt32
            let updated = result[8] as! UInt32
            let questType = result[9] as? UInt32
            let questTimestamp = result[10] as? UInt32
            let questTarget = result[11] as? UInt16
            let questConditions = (result[12] as? String)?.jsonDecodeForceTry() as? [[String: Any]]
            let questRewards = (result[13] as? String)?.jsonDecodeForceTry() as? [[String: Any]]
            let questTemplate = result[14] as? String
            let cellId = result[15] as? UInt64
            let lureId = result[16] as? Int16
            let pokestopDisplay = result[17] as? UInt16
            let incidentExpireTimestamp = result[18] as? UInt32
            let gruntType = result[19] as? UInt16
            let sponsorId = result[20] as? UInt16
            let arScanEligible = (result[21] as? UInt8)?.toBool()

            pokestops.append(Pokestop(
                id: id, lat: lat, lon: lon, name: name, url: url, enabled: enabled,
                lureExpireTimestamp: lureExpireTimestamp, lastModifiedTimestamp: lastModifiedTimestamp,
                updated: updated, questType: questType, questTarget: questTarget, questTimestamp: questTimestamp,
                questConditions: questConditions, questRewards: questRewards, questTemplate: questTemplate,
                cellId: cellId, lureId: lureId, pokestopDisplay: pokestopDisplay,
                incidentExpireTimestamp: incidentExpireTimestamp, gruntType: gruntType, sponsorId: sponsorId,
                arScanEligible: arScanEligible
            ))
        }
        return pokestops

    }

    public static func questCountIn(mysql: MySQL?=nil, ids: [String]) throws -> Int64 {
        if ids.count > 10000 {
            var result: Int64 = 0
            for i in 0..<(Int(ceil(Double(ids.count)/10000.0))) {
                let start = 10000 * i
                let end = min(10000 * (i+1) - 1, ids.count - 1)
                let splice = Array(ids[start...end])
                if let spliceResult = try? questCountIn(mysql: mysql, ids: splice) {
                    result += spliceResult
                }
            }
            return result
        }

        if ids.count == 0 {
            return 0
        }

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKESTOP] Failed to connect to database.")
            throw DBController.DBError()
        }

        var inSQL = "("
        for _ in 1..<ids.count {
            inSQL += "?, "
        }
        inSQL += "?)"

        let sql = """
            SELECT COUNT(*)
            FROM pokestop
            WHERE id IN \(inSQL) AND deleted = false AND quest_reward_type IS NOT NULL
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        for id in ids {
            mysqlStmt.bindParam(id)
        }
        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        let result = results.next()!
        let count = result[0] as! Int64

        return count
    }

    public static func getWithId(mysql: MySQL?=nil, id: String, withDeleted: Bool=false) throws -> Pokestop? {

        if let cached = cache?.get(id: id) {
            return cached
        }

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKESTOP] Failed to connect to database.")
            throw DBController.DBError()
        }

        let withDeletedSQL: String
        if withDeleted {
            withDeletedSQL = ""
        } else {
            withDeletedSQL = "AND deleted = false"
        }
        let sql = """
            SELECT id, lat, lon, name, url, enabled, lure_expire_timestamp, last_modified_timestamp, updated,
                   quest_type, quest_timestamp, quest_target, CAST(quest_conditions AS CHAR),
                   CAST(quest_rewards AS CHAR), quest_template, cell_id, lure_id, pokestop_display,
                   incident_expire_timestamp, grunt_type, sponsor_id, ar_scan_eligible
            FROM pokestop
            WHERE id = ? \(withDeletedSQL)
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(id)

        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query. (\(mysqlStmt.errorMessage())")
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
        let enabledInt = result[5] as? UInt8
        let enabled = enabledInt?.toBool()
        let lureExpireTimestamp = result[6] as? UInt32
        let lastModifiedTimestamp = result[7] as? UInt32
        let updated = result[8] as! UInt32
        let questType = result[9] as? UInt32
        let questTimestamp = result[10] as? UInt32
        let questTarget = result[11] as? UInt16
        let questConditions = (result[12] as? String)?.jsonDecodeForceTry() as? [[String: Any]]
        let questRewards = (result[13] as? String)?.jsonDecodeForceTry() as? [[String: Any]]
        let questTemplate = result[14] as? String
        let cellId = result[15] as? UInt64
        let lureId = result[16] as? Int16
        let pokestopDisplay = result[17] as? UInt16
        let incidentExpireTimestamp = result[18] as? UInt32
        let gruntType = result[19] as? UInt16
        let sponsorId = result[20] as? UInt16
        let arScanEligible = (result[21] as? UInt8)?.toBool()

        let pokestop = Pokestop(
            id: id, lat: lat, lon: lon, name: name, url: url, enabled: enabled,
            lureExpireTimestamp: lureExpireTimestamp, lastModifiedTimestamp: lastModifiedTimestamp,
            updated: updated, questType: questType, questTarget: questTarget, questTimestamp: questTimestamp,
            questConditions: questConditions, questRewards: questRewards, questTemplate: questTemplate,
            cellId: cellId, lureId: lureId, pokestopDisplay: pokestopDisplay,
            incidentExpireTimestamp: incidentExpireTimestamp, gruntType: gruntType, sponsorId: sponsorId,
            arScanEligible: arScanEligible
        )
        cache?.set(id: pokestop.id, value: pokestop)
        return pokestop
    }

    public static func clearQuests(mysql: MySQL?=nil, ids: [String]?=nil) throws {

        if ids?.count == 0 {
            return
        }

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKESTOP] Failed to connect to database.")
            throw DBController.DBError()
        }

        let whereSQL: String

        if ids != nil {
            var inSQL = "("
            for _ in 1..<ids!.count {
                inSQL += "?, "
            }
            inSQL += "?)"
            whereSQL = "WHERE id IN \(inSQL)"
        } else {
            whereSQL = ""
        }

        let sql = """
            UPDATE pokestop
            SET updated = UNIX_TIMESTAMP(), quest_type = NULL, quest_timestamp = NULL, quest_target = NULL,
                quest_conditions = NULL, quest_rewards = NULL, quest_template = NULL
            \(whereSQL)
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        if ids != nil {
            for id in ids! {
                mysqlStmt.bindParam(id)
            }
        }

        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        Pokestop.cache?.clear()

    }

    public static func clearQuests(mysql: MySQL?=nil, instance: Instance) throws {
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[INSTANCE] Failed to connect to database.")
            throw DBController.DBError()
        }

        var areaString = ""
        let areaType1 = instance.data["area"] as? [[String: Double]]
        let areaType2 = instance.data["area"] as? [[[String: Double]]]
        if areaType1 != nil {
            for coordLine in areaType1! {
                let lat = coordLine["lat"]
                let lon = coordLine["lon"]
                areaString += "\(lat!),\(lon!)\n"
            }
        } else if areaType2 != nil {
            for geofence in areaType2! {
                for coordLine in geofence {
                    let lat = coordLine["lat"]
                    let lon = coordLine["lon"]
                    areaString += "\(lat!),\(lon!)\n"
                }
            }
        }

        let coords = Pokestop.flattenCoords(area: areaString)
        let sql = """
            UPDATE pokestop
            SET updated = UNIX_TIMESTAMP(), quest_type = NULL, quest_timestamp = NULL, quest_target = NULL,
                quest_conditions = NULL, quest_rewards = NULL, quest_template = NULL
            WHERE ST_CONTAINS(
                ST_GEOMFROMTEXT('POLYGON((\(coords)))'),
                POINT(pokestop.lat, pokestop.lon)
            ) AND quest_type IS NOT NULL
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        guard mysqlStmt.execute() else {
            Log.error(message: "[INSTANCE] Failed to execute query. (\(mysqlStmt.errorMessage()))")
            throw DBController.DBError()
        }

        Pokestop.cache?.clear()

        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return
        }
    }

    public static func clearQuests(mysql: MySQL?=nil, area: [Coord]) throws {
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[INSTANCE] Failed to connect to database.")
            throw DBController.DBError()
        }

        var areaString = ""
        for coordLine in area {
            areaString += "\(coordLine.lat),\(coordLine.lon)\n"
        }

        let coords = Pokestop.flattenCoords(area: areaString)
        let sql = """
            UPDATE pokestop
            SET updated = UNIX_TIMESTAMP(), quest_type = NULL, quest_timestamp = NULL, quest_target = NULL,
                quest_conditions = NULL, quest_rewards = NULL, quest_template = NULL
            WHERE ST_CONTAINS(
                ST_GEOMFROMTEXT('POLYGON((\(coords)))'),
                POINT(pokestop.lat, pokestop.lon)
            ) AND quest_type IS NOT NULL
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        guard mysqlStmt.execute() else {
            Log.error(message: "[INSTANCE] Failed to execute query. (\(mysqlStmt.errorMessage()))")
            throw DBController.DBError()
        }

        Pokestop.cache?.clear()

        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return
        }
    }

    public static func flattenCoords(area: String) -> String {
        var coords = ""
        var firstCoord = ""
        let areaRows = area.components(separatedBy: "\n")
        for (index, areaRow) in areaRows.enumerated() {
            let rowSplit = areaRow.components(separatedBy: ",")
            if rowSplit.count == 2 {
                let lat = rowSplit[0].trimmingCharacters(in: .whitespaces).toDouble()
                let lon = rowSplit[1].trimmingCharacters(in: .whitespaces).toDouble()
                if lat != nil && lon != nil {
                    let coord = "\(lat!) \(lon!)"
                    if index == 0 {
                        firstCoord = coord
                    }
                    coords += "\(coord),"
                }
            }
        }
        return coords + firstCoord
    }

    public static func clearOld(mysql: MySQL?=nil, ids: [String], cellId: UInt64) throws -> UInt {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKESTOP] Failed to connect to database.")
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
            UPDATE pokestop
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
            Log.error(message: "[POKESTOP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        return mysqlStmt.affectedRows()

    }

    public static func getConvertiblePokestopsCount(mysql: MySQL?=nil) throws -> Int {
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKESTOP] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
        SELECT id
        FROM `pokestop`
        WHERE id IN (SELECT id FROM `gym`)
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        let results = mysqlStmt.results()
        return results.numRows
    }

    public static func getStalePokestopsCount(mysql: MySQL?=nil) throws -> Int {
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKESTOP] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
        SELECT id
        FROM `pokestop`
        WHERE updated < UNIX_TIMESTAMP() - 90000
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        let results = mysqlStmt.results()
        return results.numRows
    }

    public static func deleteConvertedPokestops(mysql: MySQL?=nil) throws -> UInt {
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKESTOP] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
        DELETE FROM `pokestop`
        WHERE id IN (SELECT id FROM `gym`)
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        Pokestop.cache?.clear()

        return mysqlStmt.affectedRows()
    }

    public static func deleteStalePokestops(mysql: MySQL?=nil) throws -> UInt {
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKESTOP] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
        DELETE FROM `pokestop`
        WHERE updated < UNIX_TIMESTAMP() - 90000
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        Pokestop.cache?.clear()

        return mysqlStmt.affectedRows()
    }

    public static func shouldUpdate(old: Pokestop, new: Pokestop) -> Bool {
        if old.hasChanges {
            old.hasChanges = false
            return true
        }
        return
            new.lastModifiedTimestamp != old.lastModifiedTimestamp ||
            new.lureExpireTimestamp != old.lureExpireTimestamp ||
            new.lureId != old.lureId ||
            new.incidentExpireTimestamp != old.incidentExpireTimestamp ||
            new.gruntType != old.gruntType ||
            new.pokestopDisplay != old.pokestopDisplay ||
            new.name != old.name ||
            new.url != old.url ||
            new.arScanEligible != old.arScanEligible ||
            new.questTemplate != old.questTemplate ||
            new.enabled != old.enabled ||
            new.sponsorId != old.sponsorId ||
            fabs(new.lat - old.lat) >= 0.000001 ||
            fabs(new.lon - old.lon) >= 0.000001
    }

    static func == (lhs: Pokestop, rhs: Pokestop) -> Bool {
        return lhs.id == rhs.id
    }

}
