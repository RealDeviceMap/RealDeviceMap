//
//  Pokestop.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 18.09.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast

import Foundation
import PerfectLib
import PerfectMySQL
import POGOProtos

public class Pokestop: JSONConvertibleObject, WebHookEvent, Hashable {

    public static var lureTime: UInt32 = 1800

    class ParsingError: Error {}

    public override func getJSONValues() -> [String: Any] {
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
            "quest_title": questTitle as Any,
            "quest_conditions": questConditions as Any,
            "quest_rewards": questRewards as Any,
            "quest_timestamp": questTimestamp as Any,
            "alternative_quest_type": alternativeQuestType as Any,
            "alternative_quest_target": alternativeQuestTarget as Any,
            "alternative_quest_template": alternativeQuestTemplate as Any,
            "alternative_quest_title": alternativeQuestTitle as Any,
            "alternative_quest_conditions": alternativeQuestConditions as Any,
            "alternative_quest_rewards": alternativeQuestRewards as Any,
            "alternative_quest_timestamp": alternativeQuestTimestamp as Any,
            "lure_id": lureId as Any,
            "ar_scan_eligible": arScanEligible as Any,
            "sponsor_id": sponsorId as Any,
            "partner_id": partnerId as Any,
            "power_up_level": powerUpLevel as Any,
            "power_up_points": powerUpPoints as Any,
            "power_up_end_timestamp": powerUpEndTimestamp as Any,
            "incidents": incidents.map({ incident in incident.getJSONValues() }) as Any,
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
                "title": questTitle!,
                "conditions": questConditions!,
                "rewards": questRewards!,
                "updated": questTimestamp!,
                "pokestop_name": name ?? "Unknown",
                "ar_scan_eligible": arScanEligible ?? 0,
                "pokestop_url": url ?? "",
                "with_ar": true
            ]
            return [
                "type": "quest",
                "message": message
            ]
        } else if type == "alternative_quest" {
            let message: [String: Any] = [
                "pokestop_id": id,
                "latitude": lat,
                "longitude": lon,
                "type": alternativeQuestType!,
                "target": alternativeQuestTarget!,
                "template": alternativeQuestTemplate!,
                "title": alternativeQuestTitle!,
                "conditions": alternativeQuestConditions!,
                "rewards": alternativeQuestRewards!,
                "updated": alternativeQuestTimestamp!,
                "pokestop_name": name ?? "Unknown",
                "ar_scan_eligible": arScanEligible ?? 0,
                "pokestop_url": url ?? "",
                "with_ar": false
            ]
            return [
                "type": "quest",
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
                "ar_scan_eligible": arScanEligible ?? 0,
                "power_up_level": powerUpLevel ?? 0,
                "power_up_points": powerUpPoints ?? 0,
                "power_up_end_timestamp": powerUpEndTimestamp ?? 0,
                "updated": updated ?? 1
            ]
            return [
                "type": "pokestop",
                "message": message
            ]
        }
    }

    public func hash(into hasher: inout Hasher) {
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
    var partnerId: String?
    var updated: UInt32?
    var arScanEligible: Bool?
    var powerUpPoints: UInt32?
    var powerUpLevel: UInt16?
    var powerUpEndTimestamp: UInt32?
    var questType: UInt32?
    var questTemplate: String?
    var questTitle: String?
    var questTarget: UInt16?
    var questTimestamp: UInt32?
    var questConditions: [[String: Any]]?
    var questRewards: [[String: Any]]?
    var alternativeQuestType: UInt32?
    var alternativeQuestTemplate: String?
    var alternativeQuestTitle: String?
    var alternativeQuestTarget: UInt16?
    var alternativeQuestTimestamp: UInt32?
    var alternativeQuestConditions: [[String: Any]]?
    var alternativeQuestRewards: [[String: Any]]?
    var cellId: UInt64?
    var lureId: Int16?
    var incidents: [Incident]

    var hasChanges = false
    var hasQuestChanges = false
    var hasAlternativeQuestChanges = false

    public static var cache: MemoryCache<Pokestop>?

    init(id: String, lat: Double, lon: Double, name: String?, url: String?, enabled: Bool?,
         lureExpireTimestamp: UInt32?, lastModifiedTimestamp: UInt32?, updated: UInt32?, questType: UInt32?,
         questTarget: UInt16?, questTimestamp: UInt32?, questConditions: [[String: Any]]?,
         questRewards: [[String: Any]]?, questTemplate: String?, questTitle: String?, cellId: UInt64?, lureId: Int16?,
         sponsorId: UInt16?, partnerId: String?, arScanEligible: Bool?, powerUpPoints: UInt32?, powerUpLevel: UInt16?,
         powerUpEndTimestamp: UInt32?, alternativeQuestType: UInt32?, alternativeQuestTarget: UInt16?,
         alternativeQuestTimestamp: UInt32?, alternativeQuestConditions: [[String: Any]]?,
         alternativeQuestRewards: [[String: Any]]?, alternativeQuestTemplate: String?, alternativeQuestTitle: String?,
         incidents: [Incident]) {
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
        self.questTitle = questTitle
        self.alternativeQuestType = alternativeQuestType
        self.alternativeQuestTarget = alternativeQuestTarget
        self.alternativeQuestTimestamp = alternativeQuestTimestamp
        self.alternativeQuestConditions = alternativeQuestConditions
        self.alternativeQuestRewards = alternativeQuestRewards
        self.alternativeQuestTemplate = alternativeQuestTemplate
        self.alternativeQuestTitle = alternativeQuestTitle
        self.cellId = cellId
        self.lureId = lureId
        self.sponsorId = sponsorId
        self.partnerId = partnerId
        self.arScanEligible = arScanEligible
        self.powerUpPoints = powerUpPoints
        self.powerUpLevel = powerUpLevel
        self.powerUpEndTimestamp = powerUpEndTimestamp
        self.incidents = incidents
    }

    init(fortData: PokemonFortProto, cellId: UInt64) {

        self.id = fortData.fortID
        self.lat = fortData.latitude
        self.lon = fortData.longitude
        self.partnerId = fortData.partnerID != "" ? fortData.partnerID : nil
        if fortData.sponsor != .unset {
            self.sponsorId = UInt16(fortData.sponsor.rawValue)
        }
        self.enabled = fortData.enabled
        self.arScanEligible = fortData.isArScanEligible
        let now = UInt32(Date().timeIntervalSince1970)
        let powerUpLevelExpirationMs = UInt32(fortData.powerUpLevelExpirationMs / 1000)
        self.powerUpPoints = UInt32(fortData.powerUpProgressPoints)
        if fortData.powerUpProgressPoints < 50 {
            self.powerUpLevel = 0
        } else if fortData.powerUpProgressPoints < 100 && powerUpLevelExpirationMs > now {
            self.powerUpLevel = 1
            self.powerUpEndTimestamp = powerUpLevelExpirationMs
        } else if fortData.powerUpProgressPoints < 150 && powerUpLevelExpirationMs > now {
            self.powerUpLevel = 2
            self.powerUpEndTimestamp = powerUpLevelExpirationMs
        } else if powerUpLevelExpirationMs > now {
            self.powerUpLevel = 3
            self.powerUpEndTimestamp = powerUpLevelExpirationMs
        } else {
            self.powerUpLevel = 0
        }

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
        self.cellId = cellId
        var incidents = fortData.pokestopDisplays
        if incidents.isEmpty && fortData.hasPokestopDisplay {
            incidents = [fortData.pokestopDisplay]
        }
        self.incidents = incidents.map({ pokestopDisplay in
            Incident(now: now, pokestopId: fortData.fortID, pokestopDisplay: pokestopDisplay) })
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

    public func addQuest(title: String, questData: QuestProto, hasARQuest: Bool) {

        let questType = questData.questType.rawValue.toUInt32()
        let questTarget = UInt16(questData.goal.target)
        let questTemplate = questData.templateID.lowercased()
        let questTitle = title
        self.hasChanges = true

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
            case .withItemType:
                let info = conditionData.withItemType
                infoData["item_type_ids"] = info.itemType.map({ (type) -> Int in
                    return type.rawValue
                })
            case .withRaidElapsedTime:
                let info = conditionData.withElapsedTime
                infoData["time"] = Int(info.elapsedTimeMs / 1000)
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
            case .withFriendLevel: break
            case .withSticker: break
            case .withPokemonCp: break
            case .withRaidLocation: break
            case .withFriendsRaid: break
            case .withPokemonCostume: break
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
            case .incident: break
            case .playerAttribute: break
            case .unset: break
            case .UNRECOGNIZED: break
            }

            reward["info"] = infoData
            rewards.append(reward)
        }

        let questConditions = conditions
        let questRewards = rewards
        let questTimestamp = UInt32(Date().timeIntervalSince1970)

         if !hasARQuest {
             self.alternativeQuestType = questType
             self.alternativeQuestTarget = questTarget
             self.alternativeQuestTemplate = questTemplate
             self.alternativeQuestTitle = questTitle
             self.alternativeQuestConditions = questConditions
             self.alternativeQuestRewards = questRewards
             self.alternativeQuestTimestamp = questTimestamp
             self.hasAlternativeQuestChanges = true
         } else {
             self.questType = questType
             self.questTarget = questTarget
             self.questTemplate = questTemplate
             self.questTitle = questTitle
             self.questConditions = questConditions
             self.questRewards = questRewards
             self.questTimestamp = questTimestamp
             self.hasQuestChanges = true
         }

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

        let now = UInt32(Date().timeIntervalSince1970)

        if oldPokestop == nil {
            let sql = """
                INSERT INTO pokestop (
                    id, lat, lon, name, url, enabled, lure_expire_timestamp, last_modified_timestamp, quest_type,
                    quest_timestamp, quest_target, quest_conditions, quest_rewards, quest_template, quest_title,
                    alternative_quest_type, alternative_quest_timestamp, alternative_quest_target,
                    alternative_quest_conditions, alternative_quest_rewards, alternative_quest_template,
                    alternative_quest_title, cell_id, lure_id, sponsor_id, partner_id, ar_scan_eligible,
                    power_up_points, power_up_level, power_up_end_timestamp, updated, first_seen_timestamp)
                VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
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
                self.questTitle = oldPokestop!.questTitle
            }
            if updateQuest && oldPokestop!.alternativeQuestType != nil && self.alternativeQuestType == nil {
                self.alternativeQuestType = oldPokestop!.alternativeQuestType
                self.alternativeQuestTarget = oldPokestop!.alternativeQuestTarget
                self.alternativeQuestConditions = oldPokestop!.alternativeQuestConditions
                self.alternativeQuestRewards = oldPokestop!.alternativeQuestRewards
                self.alternativeQuestTimestamp = oldPokestop!.alternativeQuestTimestamp
                self.alternativeQuestTemplate = oldPokestop!.alternativeQuestTemplate
                self.alternativeQuestTitle = oldPokestop!.alternativeQuestTitle
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
            if updateQuest && questTimestamp ?? 0 > oldPokestop!.questTimestamp ?? 0 {
                WebHookController.global.addQuestEvent(pokestop: self)
            }
            if updateQuest && alternativeQuestTimestamp ?? 0 > oldPokestop!.alternativeQuestTimestamp ?? 0 {
                WebHookController.global.addAlternativeQuestEvent(pokestop: self)
            }

            var questSQL = ""
            if updateQuest && questTimestamp ?? 0 > 0 {
                questSQL += "quest_type = ?, quest_timestamp = ?, quest_target = ?, quest_conditions = ?, " +
                            "quest_rewards = ?, quest_template = ?, quest_title = ?,"
            }
            if updateQuest && alternativeQuestTimestamp ?? 0 > 0 {
                questSQL += "alternative_quest_type = ?, alternative_quest_timestamp = ?, " +
                            "alternative_quest_target = ?, alternative_quest_conditions = ?, " +
                            "alternative_quest_rewards = ?, alternative_quest_template = ?," +
                            "alternative_quest_title = ?,"
            }

            let nameSQL = name != nil ? "name = ?, " : ""
            let sql = """
                UPDATE pokestop
                SET lat = ?, lon = ?, \(nameSQL) url = ?, enabled = ?, lure_expire_timestamp = ?,
                    last_modified_timestamp = ?, updated = UNIX_TIMESTAMP(), \(questSQL) cell_id = ?,
                    lure_id = ?, deleted = false, sponsor_id = ?, partner_id = ?, ar_scan_eligible = ?,
                    power_up_points = ?, power_up_level = ?, power_up_end_timestamp = ?
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
        if (updateQuest && questTimestamp ?? 0 > 0) || oldPokestop == nil {
            mysqlStmt.bindParam(questType)
            mysqlStmt.bindParam(questTimestamp)
            mysqlStmt.bindParam(questTarget)
            mysqlStmt.bindParam(questConditions.jsonEncodeForceTry())
            mysqlStmt.bindParam(questRewards.jsonEncodeForceTry())
            mysqlStmt.bindParam(questTemplate)
            mysqlStmt.bindParam(questTitle)
        }
        if (updateQuest && alternativeQuestTimestamp ?? 0 > 0) || oldPokestop == nil {
            mysqlStmt.bindParam(alternativeQuestType)
            mysqlStmt.bindParam(alternativeQuestTimestamp)
            mysqlStmt.bindParam(alternativeQuestTarget)
            mysqlStmt.bindParam(alternativeQuestConditions.jsonEncodeForceTry())
            mysqlStmt.bindParam(alternativeQuestRewards.jsonEncodeForceTry())
            mysqlStmt.bindParam(alternativeQuestTemplate)
            mysqlStmt.bindParam(alternativeQuestTitle)
        }
        mysqlStmt.bindParam(cellId)
        mysqlStmt.bindParam(lureId ?? 0)
        mysqlStmt.bindParam(sponsorId)
        mysqlStmt.bindParam(partnerId)
        mysqlStmt.bindParam(arScanEligible)
        mysqlStmt.bindParam(powerUpPoints)
        mysqlStmt.bindParam(powerUpLevel)
        mysqlStmt.bindParam(powerUpEndTimestamp)

        if oldPokestop != nil {
            mysqlStmt.bindParam(id)
        }

        guard mysqlStmt.execute() else {
            if mysqlStmt.errorCode() == 1062 {
                Log.debug(message: "[POKESTOP] Duplicated key. Skipping...")
            } else {
                Log.error(message: "[POKESTOP] Failed to execute query 'save'. (\(mysqlStmt.errorMessage()))")
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
            if alternativeQuestTimestamp ?? 0 > 0 {
                WebHookController.global.addAlternativeQuestEvent(pokestop: self)
            }
        } else {
            if oldPokestop!.lureExpireTimestamp ?? 0 < self.lureExpireTimestamp ?? 0 {
                WebHookController.global.addLureEvent(pokestop: self)
            }
            if updateQuest && (hasQuestChanges || questTimestamp ?? 0 > oldPokestop!.questTimestamp ?? 0) {
                hasQuestChanges = false
                WebHookController.global.addQuestEvent(pokestop: self)
            }
            if updateQuest && (hasAlternativeQuestChanges ||
                alternativeQuestTimestamp ?? 0 > oldPokestop!.alternativeQuestTimestamp ?? 0
            ) {
                hasAlternativeQuestChanges = false
                WebHookController.global.addAlternativeQuestEvent(pokestop: self)
            }
        }
    }

    //  swiftlint:disable:next function_parameter_count
    public static func getAll(
        mysql: MySQL?=nil, minLat: Double, maxLat: Double, minLon: Double, maxLon: Double, updated: UInt32,
        showPokestops: Bool, showQuests: Bool, showLures: Bool, showInvasions: Bool, questFilterExclude: [String]?=nil,
        pokestopFilterExclude: [String]?=nil, pokestopShowOnlyAr: Bool=false, pokestopShowOnlySponsored: Bool=false,
        invasionFilterExclude: [Int]?=nil, showAlternativeQuests: Bool=false
    ) throws -> [Pokestop] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKESTOP] Failed to connect to database.")
            throw DBController.DBError()
        }

        var excludedTypes = [Int]()
        var excludedPokemon = [Int]()
        var excludedItems = [Int]()
        var excludedLures = [Int]()
        var excludedInvasions = [Int]()
        var excludedPowerUpLevels = [Int]()
        var excludeNormal = Bool()

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

        if showInvasions && invasionFilterExclude != nil {
            for filter in invasionFilterExclude! {
                excludedInvasions.append(filter)
            }
        }

        if pokestopFilterExclude != nil {
            for filter in pokestopFilterExclude! {
                if filter.contains(string: "normal") {
                    excludeNormal = true
                } else if showLures && filter.contains(string: "l") {
                    if let id = filter.stringByReplacing(string: "l", withString: "").toInt() {
                        excludedLures.append(id)
                    }
                } else if filter.contains(string: "p") {
                    if let id = filter.stringByReplacing(string: "p", withString: "").toInt() {
                        excludedPowerUpLevels.append(id)
                    }
                }
            }
        }

        let excludeQuestTypeSQL: String
        let excludeQuestPokemonSQL: String
        let excludeQuestItemSQL: String
        let excludeLureSQL: String
        var excludePokestopSQL: String
        var onlyArSQL: String
        var onlySponsoredSQL: String
        var excludeInvasionSQL: String
        let excludePowerUpLevelsSQL: String

        if showInvasions {
            if excludedInvasions.isEmpty {
                excludeInvasionSQL = ""
            } else {
                excludeInvasionSQL = "AND `character` NOT IN ("
                for _ in 1..<excludedInvasions.count {
                    excludeInvasionSQL += "?, "
                }
                excludeInvasionSQL += "?)"
            }
        } else {
            excludeInvasionSQL = ""
        }

        let questRewardTypeSql = showAlternativeQuests ? "alternative_quest_reward_type" : "quest_reward_type"
        let questPokemonIdSql = showAlternativeQuests ? "alternative_quest_pokemon_id" : "quest_pokemon_id"
        let questItemIdSql = showAlternativeQuests ? "alternative_quest_item_id" : "quest_item_id"

        if showQuests {
            if excludedTypes.isEmpty {
                excludeQuestTypeSQL = ""
            } else {
                var sqlExcludeCreate = "AND (\(questRewardTypeSql) IS NULL OR \(questRewardTypeSql) NOT IN ("
                for _ in 1..<excludedTypes.count {
                    sqlExcludeCreate += "?, "
                }
                sqlExcludeCreate += "?)) "
                excludeQuestTypeSQL = sqlExcludeCreate
            }

            if excludedPokemon.isEmpty {
                excludeQuestPokemonSQL = ""
            } else {
                var sqlExcludeCreate = "AND (\(questPokemonIdSql) IS NULL OR \(questPokemonIdSql) NOT IN ("
                for _ in 1..<excludedPokemon.count {
                    sqlExcludeCreate += "?, "
                }
                sqlExcludeCreate += "?)"
                if !excludedTypes.contains(3) { // candy reward type = 4
                    sqlExcludeCreate += " OR \(questRewardTypeSql) = 4"
                }
                if !excludedTypes.contains(6) { // mega energy reward type = 12
                    sqlExcludeCreate += " OR \(questRewardTypeSql) = 12"
                }
                excludeQuestPokemonSQL = sqlExcludeCreate+") "
            }

            if excludedItems.isEmpty {
                excludeQuestItemSQL = ""
            } else {
                var sqlExcludeCreate = "AND (\(questItemIdSql) IS NULL OR \(questItemIdSql) NOT IN ("
                for _ in 1..<excludedItems.count {
                    sqlExcludeCreate += "?, "
                }
                sqlExcludeCreate += "?)) "
                excludeQuestItemSQL = sqlExcludeCreate
            }
        } else {
            excludeQuestTypeSQL = ""
            excludeQuestPokemonSQL = ""
            excludeQuestItemSQL = ""
        }

        if excludeNormal || !excludedLures.isEmpty {
            if excludedLures.isEmpty {
                excludeLureSQL = ""
            } else {
                var sqlExcludeCreate = "AND lure_id NOT IN ("
                for _ in 1..<excludedLures.count {
                    sqlExcludeCreate += "?, "
                }
                sqlExcludeCreate += "?)"
                excludeLureSQL = sqlExcludeCreate
            }

            let hasLureSQL = "(lure_expire_timestamp IS NOT NULL AND lure_expire_timestamp >= " +
                             "UNIX_TIMESTAMP() \(excludeLureSQL))"
            let hasNoLureSQL = "(lure_expire_timestamp IS NULL OR lure_expire_timestamp < " +
                               "UNIX_TIMESTAMP())"
            excludePokestopSQL = "AND ("
            if excludeNormal {
                excludePokestopSQL += "(\(hasLureSQL))"
            } else {
                excludePokestopSQL += "(\(hasNoLureSQL) OR \(hasLureSQL))"
            }
            excludePokestopSQL += ") "
        } else if showPokestops {
            excludePokestopSQL = "AND TRUE "
        } else {
            excludePokestopSQL = ""
        }

        if pokestopShowOnlyAr && showPokestops {
            onlyArSQL = "AND ar_scan_eligible = TRUE "
        } else {
            onlyArSQL = ""
        }

        if pokestopShowOnlySponsored && showPokestops {
            onlySponsoredSQL = "AND partner_id is not null "
        } else {
            onlySponsoredSQL = ""
        }

        if excludedPowerUpLevels.isEmpty {
            excludePowerUpLevelsSQL = ""
        } else {
            var sqlExcludeCreate = "AND power_up_level NOT IN ("
            for _ in 1..<excludedPowerUpLevels.count {
                sqlExcludeCreate += "?, "
            }
            sqlExcludeCreate += "?) "
            excludePowerUpLevelsSQL = sqlExcludeCreate
        }

        let onlyQuestsSQL = showQuests ? "AND \(questRewardTypeSql) IS NOT NULL " : ""
        let joinIncidentSQL = showInvasions ?
                "LEFT JOIN incident on pokestop.id = incident.pokestop_id and expiration >= UNIX_TIMESTAMP()" :
                ""

        let sqlOrParts: [String] = [
            "\(excludePokestopSQL) \(excludePowerUpLevelsSQL) \(onlyArSQL) \(onlySponsoredSQL)",
            "\(onlyQuestsSQL) \(excludeQuestTypeSQL) \(excludeQuestPokemonSQL) \(excludeQuestItemSQL)",
            "\(excludeInvasionSQL)"
        ]
            .filter({ $0.trimmingCharacters(in: .whitespacesAndNewlines) != "" })
            .map({ "(TRUE \($0))" })

        let selectIncidentProps = showInvasions ?
            ", incident.id, pokestop_id, start, expiration, display_type, style, `character`, incident.updated" :
            ""

        let sql = """
            SELECT pokestop.id, lat, lon, name, url, enabled, lure_expire_timestamp, last_modified_timestamp,
                   pokestop.updated, quest_type, quest_timestamp, quest_target, CAST(quest_conditions AS CHAR),
                   CAST(quest_rewards AS CHAR), quest_template, quest_title,
                   alternative_quest_type, alternative_quest_timestamp, alternative_quest_target,
                   CAST(alternative_quest_conditions AS CHAR), CAST(alternative_quest_rewards AS CHAR),
                   alternative_quest_template, alternative_quest_title, cell_id, lure_id, sponsor_id, partner_id,
                   ar_scan_eligible, power_up_points, power_up_level, power_up_end_timestamp \(selectIncidentProps)
            FROM pokestop \(joinIncidentSQL)
            WHERE lat >= ? AND lat <= ? AND lon >= ? AND lon <= ? AND pokestop.updated > ? AND
                  deleted = false \(sqlOrParts.count > 0 ? "AND (\(sqlOrParts.joined(separator: "\nOR\n")))" : "")
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(minLat)
        mysqlStmt.bindParam(maxLat)
        mysqlStmt.bindParam(minLon)
        mysqlStmt.bindParam(maxLon)
        mysqlStmt.bindParam(updated)

        for id in excludedPowerUpLevels {
            mysqlStmt.bindParam(id)
        }
        for id in excludedTypes {
            mysqlStmt.bindParam(id)
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
        for id in excludedInvasions {
            mysqlStmt.bindParam(id)
        }
        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query 'getAll'. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        return extractResults(results: results, showLures: showLures, showInvasions: showInvasions,
            showQuests: showQuests)

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

        let joinIncidentSQL = "LEFT JOIN incident on pokestop.id = incident.pokestop_id and " +
            "expiration >= UNIX_TIMESTAMP()"
        let selectIncidentSql = ", incident.id, pokestop_id, start, expiration, display_type, style, `character`, " +
            "incident.updated"

        let sql = """
            SELECT pokestop.id, lat, lon, name, url, enabled, lure_expire_timestamp, last_modified_timestamp,
                   pokestop.updated, quest_type, quest_timestamp, quest_target, CAST(quest_conditions AS CHAR),
                   CAST(quest_rewards AS CHAR), quest_template, quest_title,
                   alternative_quest_type, alternative_quest_timestamp, alternative_quest_target,
                   CAST(alternative_quest_conditions AS CHAR), CAST(alternative_quest_rewards AS CHAR),
                   alternative_quest_template, alternative_quest_title, cell_id, lure_id, sponsor_id, partner_id,
                   ar_scan_eligible, power_up_points, power_up_level, power_up_end_timestamp \(selectIncidentSql)
            FROM pokestop \(joinIncidentSQL)
            WHERE pokestop.id IN \(inSQL) AND deleted = false
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        for id in ids {
            mysqlStmt.bindParam(id)
        }

        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query 'getIn'. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        return extractResults(results: results)
    }

    internal static func questCountIn(
        mysql: MySQL?=nil, ids: [String], mode: AutoInstanceController.QuestMode
    ) throws -> Int64 {
        if ids.count > 10000 {
            var result: Int64 = 0
            for i in 0..<(Int(ceil(Double(ids.count)/10000.0))) {
                let start = 10000 * i
                let end = min(10000 * (i+1) - 1, ids.count - 1)
                let splice = Array(ids[start...end])
                if let spliceResult = try? questCountIn(mysql: mysql, ids: splice, mode: mode) {
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

        let conditionSQL: String
        let sumSQL: String
        switch mode {
        case .normal:
            conditionSQL = "quest_reward_type IS NOT NULL"
            sumSQL = "COUNT(*)"
        case .alternative:
            conditionSQL = "alternative_quest_reward_type IS NOT NULL"
            sumSQL = "COUNT(*)"
        case .both:
            conditionSQL = "quest_reward_type IS NOT NULL OR alternative_quest_reward_type IS NOT NULL"
            sumSQL = "CAST(SUM(IF(quest_reward_type IS NOT NULL AND " +
                     "alternative_quest_reward_type IS NOT NULL, 2, 1)) AS SIGNED)"
        }

        let sql = """
            SELECT \(sumSQL)
            FROM pokestop
            WHERE id IN \(inSQL) AND deleted = false AND (\(conditionSQL))
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        for id in ids {
            mysqlStmt.bindParam(id)
        }
        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query 'questCountIn'. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        let result = results.next()
        let count = result?[0] as? Int64 ?? 0

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

        let joinIncidentSQL = "LEFT JOIN incident on pokestop.id = incident.pokestop_id and " +
            "expiration >= UNIX_TIMESTAMP()"
        let selectIncidentSql = ", incident.id, pokestop_id, start, expiration, display_type, style, `character`, " +
            "incident.updated"

        let sql = """
            SELECT pokestop.id, lat, lon, name, url, enabled, lure_expire_timestamp, last_modified_timestamp,
                   pokestop.updated, quest_type, quest_timestamp, quest_target, CAST(quest_conditions AS CHAR),
                   CAST(quest_rewards AS CHAR), quest_template, quest_title,
                   alternative_quest_type, alternative_quest_timestamp, alternative_quest_target,
                   CAST(alternative_quest_conditions AS CHAR), CAST(alternative_quest_rewards AS CHAR),
                   alternative_quest_template, alternative_quest_title, cell_id, lure_id, sponsor_id, partner_id,
                   ar_scan_eligible, power_up_points, power_up_level, power_up_end_timestamp \(selectIncidentSql)
            FROM pokestop \(joinIncidentSQL)
            WHERE pokestop.id = ? \(withDeletedSQL)
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(id)

        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query 'getWithId'. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }

        let pokestop = extractResults(results: results).first!
        cache?.set(id: pokestop.id, value: pokestop)
        return pokestop
    }

    private static func extractResults(results: MySQLStmt.Results, showLures: Bool = true, showInvasions: Bool = true,
                                       showQuests: Bool = true) -> [Pokestop] {
        var pokestops = [String: Pokestop]()
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
            let questTitle: String?
            let alternativeQuestType: UInt32?
            let alternativeQuestTimestamp: UInt32?
            let alternativeQuestTarget: UInt16?
            let alternativeQuestConditions: [[String: Any]]?
            let alternativeQuestRewards: [[String: Any]]?
            let alternativeQuestTemplate: String?
            let alternativeQuestTitle: String?

            if showQuests {
                questType = result[9] as? UInt32
                questTimestamp = result[10] as? UInt32
                questTarget = result[11] as? UInt16
                questConditions = (result[12] as? String)?.jsonDecodeForceTry() as? [[String: Any]]
                questRewards = (result[13] as? String)?.jsonDecodeForceTry() as? [[String: Any]]
                questTemplate = result[14] as? String
                questTitle = result[15] as? String
                alternativeQuestType = result[16] as? UInt32
                alternativeQuestTimestamp = result[17] as? UInt32
                alternativeQuestTarget = result[18] as? UInt16
                alternativeQuestConditions = (result[19] as? String)?.jsonDecodeForceTry() as? [[String: Any]]
                alternativeQuestRewards = (result[20] as? String)?.jsonDecodeForceTry() as? [[String: Any]]
                alternativeQuestTemplate = result[21] as? String
                alternativeQuestTitle = result[22] as? String
            } else {
                questType = nil
                questTimestamp = nil
                questTarget = nil
                questConditions = nil
                questRewards = nil
                questTemplate = nil
                questTitle = nil
                alternativeQuestType = nil
                alternativeQuestTimestamp = nil
                alternativeQuestTarget = nil
                alternativeQuestConditions = nil
                alternativeQuestRewards = nil
                alternativeQuestTemplate = nil
                alternativeQuestTitle = nil
            }
            let cellId = result[23] as? UInt64
            let lureId: Int16?
            if showLures {
                lureId = result[24] as? Int16
            } else {
                lureId = nil
            }
            let sponsorId = result[25] as? UInt16
            let partnerId = result[26] as? String
            let arScanEligible = (result[27] as? UInt8)?.toBool()
            let powerUpPoints = result[28] as? UInt32
            let powerUpLevel = result[29] as? UInt16
            let powerUpEndTimestamp = result[30] as? UInt32

            let incident: Incident?
            if showInvasions {
                let incidentId = result[31] as? String
                if incidentId != nil {
                    let pokestopId = result[32] as! String
                    let start = result[33] as! UInt32
                    let expiration = result[34] as! UInt32
                    let displayType = result[35] as! UInt16
                    let style = result[36] as! UInt16
                    let character = result[37] as! UInt16
                    let incidentUpdated = result[38] as! UInt32
                    incident = Incident(id: incidentId!, pokestopId: pokestopId, start: start, expiration: expiration,
                        displayType: displayType, style: style, character: character, updated: incidentUpdated)
                } else {
                    incident = nil
                }
            } else {
                incident = nil
            }
            // duplicate rows because of JOIN with incident table possible
            if pokestops[id] != nil {
                if incident != nil {
                    pokestops[id]!.incidents.append(incident!)
                }
            } else {
                let incidents = incident != nil ? [incident!] : [Incident]()
                pokestops.merge([id: Pokestop(
                    id: id, lat: lat, lon: lon, name: name, url: url, enabled: enabled,
                    lureExpireTimestamp: lureExpireTimestamp, lastModifiedTimestamp: lastModifiedTimestamp,
                    updated: updated, questType: questType, questTarget: questTarget, questTimestamp: questTimestamp,
                    questConditions: questConditions, questRewards: questRewards, questTemplate: questTemplate,
                    questTitle: questTitle, cellId: cellId, lureId: lureId, sponsorId: sponsorId, partnerId: partnerId,
                    arScanEligible: arScanEligible, powerUpPoints: powerUpPoints, powerUpLevel: powerUpLevel,
                    powerUpEndTimestamp: powerUpEndTimestamp,
                    alternativeQuestType: alternativeQuestType, alternativeQuestTarget: alternativeQuestTarget,
                    alternativeQuestTimestamp: alternativeQuestTimestamp,
                    alternativeQuestConditions: alternativeQuestConditions,
                    alternativeQuestRewards: alternativeQuestRewards,
                    alternativeQuestTemplate: alternativeQuestTemplate,
                    alternativeQuestTitle: alternativeQuestTitle, incidents: incidents
                )]) { (current, _) in current }
            }
        }
        return Array(pokestops.values)
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
                quest_conditions = NULL, quest_rewards = NULL, quest_template = NULL, quest_title = NULL,
                alternative_quest_type = NULL, alternative_quest_timestamp = NULL, alternative_quest_target = NULL,
                alternative_quest_conditions = NULL, alternative_quest_rewards = NULL,
                alternative_quest_template = NULL, alternative_quest_title = NULL
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
            Log.error(message: "[POKESTOP] Failed to execute query 'clearQuests'. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        Pokestop.cache?.clear()

    }

    internal static func clearQuests(mysql: MySQL?=nil, instance: Instance) throws {
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
                quest_conditions = NULL, quest_rewards = NULL, quest_template = NULL, quest_title = NULL,
                alternative_quest_type = NULL, alternative_quest_timestamp = NULL, alternative_quest_target = NULL,
                alternative_quest_conditions = NULL, alternative_quest_rewards = NULL,
                alternative_quest_template = NULL, alternative_quest_title = NULL
            WHERE (quest_type IS NOT NULL OR alternative_quest_type IS NOT NULL) AND ST_CONTAINS(
                ST_GEOMFROMTEXT('POLYGON((\(coords)))'),
                POINT(pokestop.lat, pokestop.lon)
            )
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        guard mysqlStmt.execute() else {
            Log.error(message: "[INSTANCE] Failed to execute query 'clearQuests'. (\(mysqlStmt.errorMessage()))")
            throw DBController.DBError()
        }

        Pokestop.cache?.clear()

        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return
        }
    }

    internal static func clearQuests(mysql: MySQL?=nil, area: [Coord]) throws {
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
                quest_conditions = NULL, quest_rewards = NULL, quest_template = NULL, quest_title = NULL,
                alternative_quest_type = NULL, alternative_quest_timestamp = NULL, alternative_quest_target = NULL,
                alternative_quest_conditions = NULL, alternative_quest_rewards = NULL,
                alternative_quest_template = NULL, alternative_quest_title = NULL
            WHERE ST_CONTAINS(
                ST_GEOMFROMTEXT('POLYGON((\(coords)))'),
                POINT(pokestop.lat, pokestop.lon)
            ) AND (quest_type IS NOT NULL OR alternative_quest_type IS NOT NULL)
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        guard mysqlStmt.execute() else {
            Log.error(message: "[INSTANCE] Failed to execute query 'clearQuests'. (\(mysqlStmt.errorMessage()))")
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
            Log.error(message: "[POKESTOP] Failed to execute query 'clearOld'. (\(mysqlStmt.errorMessage())")
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
        WHERE id IN (SELECT id FROM `gym` WHERE deleted = 0)
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query 'convertibleCount'. (\(mysqlStmt.errorMessage())")
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
            Log.error(message: "[POKESTOP] Failed to execute query 'staleCount'. (\(mysqlStmt.errorMessage())")
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
        WHERE id IN (SELECT id FROM `gym` WHERE deleted = 0)
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query 'deleteConverted'. (\(mysqlStmt.errorMessage())")
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
            Log.error(message: "[POKESTOP] Failed to execute query 'deleteStale'. (\(mysqlStmt.errorMessage())")
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
            new.incidents.count != old.incidents.count ||
            new.name != old.name ||
            new.url != old.url ||
            new.arScanEligible != old.arScanEligible ||
            new.powerUpPoints != old.powerUpPoints ||
            new.powerUpEndTimestamp != old.powerUpEndTimestamp ||
            new.questTemplate != old.questTemplate ||
            new.alternativeQuestTemplate != old.alternativeQuestTemplate ||
            new.enabled != old.enabled ||
            new.sponsorId != old.sponsorId ||
            new.partnerId != old.partnerId ||
            fabs(new.lat - old.lat) >= 0.000001 ||
            fabs(new.lon - old.lon) >= 0.000001
    }

    public static func == (lhs: Pokestop, rhs: Pokestop) -> Bool {
        return lhs.id == rhs.id
    }

}
