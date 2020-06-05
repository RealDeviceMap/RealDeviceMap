//
//  Pokemon.swift
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
import Regex

class Pokemon: JSONConvertibleObject, WebHookEvent, Equatable, CustomStringConvertible {

    var description: String {
        return pokemonId.description
    }

    static var defaultTimeUnseen: UInt32 = 1200
    static var defaultTimeReseen: UInt32 = 600
    static var dittoPokemonId: UInt16 = 132
    static var weatherBoostMinLevel: UInt8 = 6
    static var weatherBoostMinIvStat: UInt8 = 4

    class ParsingError: Error {}

    override func getJSONValues() -> [String: Any] {
        return [
            "id": id,
            "pokemon_id": pokemonId,
            "lat": lat,
            "lon": lon,
            "spawn_id": spawnId?.toHexString() as Any,
            "expire_timestamp": expireTimestamp as Any,
            "expire_timestamp_verified": expireTimestampVerified,
            "first_seen_timestamp": firstSeenTimestamp ?? 1,
            "atk_iv": atkIv as Any,
            "def_iv": defIv as Any,
            "sta_iv": staIv as Any,
            "move_1": move1 as Any,
            "move_2": move2 as Any,
            "gender": gender as Any,
            "form": form as Any,
            "cp": cp as Any,
            "level": level as Any,
            "weight": weight as Any,
            "size": size as Any,
            "weather": weather as Any,
            "shiny": shiny as Any,
            //"username": username as Any,
            "pokestop_id": pokestopId as Any,
            "costume": costume as Any,
            "updated": updated ?? 1,
            "capture_1": capture1 as Any,
            "capture_2": capture2 as Any,
            "capture_3": capture3 as Any,
            "display_pokemon_id": displayPokemonId as Any
        ]
    }

    func getWebhookValues(type: String) -> [String: Any] {
        let message: [String: Any] = [
            "spawnpoint_id": spawnId?.toHexString() ?? "None",
            "pokestop_id": pokestopId ?? "None",
            "encounter_id": id,
            "pokemon_id": pokemonId,
            "latitude": lat,
            "longitude": lon,
            "disappear_time": expireTimestamp ?? 0,
            "disappear_time_verified": expireTimestampVerified,
            "first_seen": firstSeenTimestamp ?? 1,
            "last_modified_time": updated ?? 1,
            "gender": gender as Any,
            "cp": cp as Any,
            "form": form as Any,
            "costume": costume as Any,
            "individual_attack": atkIv as Any,
            "individual_defense": defIv as Any,
            "individual_stamina": staIv as Any,
            "pokemon_level": level as Any,
            "move_1": move1 as Any,
            "move_2": move2 as Any,
            "weight": weight as Any,
            "height": size as Any,
            "weather": weather as Any,
            "capture_1": capture1 ?? 0,
            "capture_2": capture2 ?? 0,
            "capture_3": capture3 ?? 0,
            "shiny": shiny as Any,
            "username": username as Any,
            "display_pokemon_id": displayPokemonId as Any
        ]
        return [
            "type": "pokemon",
            "message": message
        ]
    }

    public var hashValue: Int {
        return id.hashValue
    }

    var id: String
    var pokemonId: UInt16
    var lat: Double
    var lon: Double
    var spawnId: UInt64?
    var expireTimestamp: UInt32?
    var atkIv: UInt8?
    var defIv: UInt8?
    var staIv: UInt8?
    var move1: UInt16?
    var move2: UInt16?
    var gender: UInt8?
    var form: UInt16?
    var costume: UInt8?
    var cp: UInt16?
    var level: UInt8?
    var weight: Double?
    var size: Double?
    var weather: UInt8?
    var shiny: Bool?
    var username: String?
    var pokestopId: String?
    var firstSeenTimestamp: UInt32?
    var updated: UInt32?
    var changed: UInt32?
    var cellId: UInt64?
    var expireTimestampVerified: Bool
    var capture1: Double?
    var capture2: Double?
    var capture3: Double?
    var isDitto: Bool = false
    var displayPokemonId: UInt16?

    init(id: String, pokemonId: UInt16, lat: Double, lon: Double, spawnId: UInt64?, expireTimestamp: UInt32?,
         atkIv: UInt8?, defIv: UInt8?, staIv: UInt8?, move1: UInt16?, move2: UInt16?, gender: UInt8?, form: UInt16?,
         cp: UInt16?, level: UInt8?, weight: Double?, costume: UInt8?, size: Double?,
         capture1: Double?, capture2: Double?, capture3: Double?, displayPokemonId: UInt16?,
         weather: UInt8?, shiny: Bool?, username: String?, pokestopId: String?, firstSeenTimestamp: UInt32?,
         updated: UInt32?, changed: UInt32?, cellId: UInt64?, expireTimestampVerified: Bool) {
        self.id = id
        self.pokemonId = pokemonId
        self.lat = lat
        self.lon = lon
        self.spawnId = spawnId
        self.expireTimestamp = expireTimestamp
        self.atkIv = atkIv
        self.defIv = defIv
        self.staIv = staIv
        self.move1 = move1
        self.move2 = move2
        self.gender = gender
        self.form = form
        self.cp = cp
        self.level = level
        self.weight = weight
        self.costume = costume
        self.size = size
        self.weather = weather
        self.shiny = shiny
        self.username = username
        self.pokestopId = pokestopId
        self.updated = updated
        self.firstSeenTimestamp = firstSeenTimestamp
        self.changed = changed
        self.cellId = cellId
        self.expireTimestampVerified = expireTimestampVerified
        self.capture1 = capture1
        self.capture2 = capture2
        self.capture3 = capture3
        self.displayPokemonId = displayPokemonId
    }

    init(mysql: MySQL?=nil, wildPokemon: POGOProtos_Map_Pokemon_WildPokemon, cellId: UInt64,
         timestampMs: UInt64, username: String?) {

        id = wildPokemon.encounterID.description
        pokemonId = wildPokemon.pokemonData.pokemonID.rawValue.toUInt16()
        lat = wildPokemon.latitude
        lon = wildPokemon.longitude
        let spawnId = UInt64(wildPokemon.spawnPointID, radix: 16)
        gender = wildPokemon.pokemonData.pokemonDisplay.gender.rawValue.toUInt8()
        form = wildPokemon.pokemonData.pokemonDisplay.form.rawValue.toUInt16()
        if wildPokemon.pokemonData.hasPokemonDisplay {
            costume = wildPokemon.pokemonData.pokemonDisplay.costume.rawValue.toUInt8()
            weather = wildPokemon.pokemonData.pokemonDisplay.weatherBoostedCondition.rawValue.toUInt8()
            //The wildPokemon and nearbyPokemon GMOs don't contain actual shininess.
            //shiny = wildPokemon.pokemonData.pokemonDisplay.shiny
        }
        self.username = username

        if wildPokemon.timeTillHiddenMs <= 90000 && wildPokemon.timeTillHiddenMs > 0 {
            expireTimestamp = UInt32((timestampMs + UInt64(wildPokemon.timeTillHiddenMs)) / 1000)
            expireTimestampVerified = true
        } else {
            expireTimestampVerified = false
        }

        if !expireTimestampVerified && spawnId != nil {
            let spawnpoint: SpawnPoint?
            do {
                spawnpoint = try SpawnPoint.getWithId(id: spawnId!)
            } catch {
                spawnpoint = nil
            }
            if let spawnpoint = spawnpoint, let despawnSecond = spawnpoint.despawnSecond {
                let date = Date(timeIntervalSince1970: Double(timestampMs) / 1000)

                let formatter = DateFormatter()
                formatter.dateFormat = "mm:ss"
                let formattedDate = formatter.string(from: date)

                let split = formattedDate.components(separatedBy: ":")
                let minute = Int(split[0])!
                let second = Int(split[1])!
                let secondOfHour = second + minute * 60

                let depsawnOffset: Int
                if despawnSecond < secondOfHour {
                    depsawnOffset = 3600 + Int(despawnSecond) - secondOfHour
                } else {
                    depsawnOffset = Int(despawnSecond) - secondOfHour
                }

                self.expireTimestamp = UInt32(Int(date.timeIntervalSince1970) + depsawnOffset)
                self.expireTimestampVerified = true
            }
        }

        self.spawnId = spawnId
        self.cellId = cellId

    }

    init(mysql: MySQL?=nil, nearbyPokemon: POGOProtos_Map_Pokemon_NearbyPokemon, cellId: UInt64,
         username: String?) throws {

        let id = nearbyPokemon.encounterID.description
        let pokemonId = nearbyPokemon.pokemonID.rawValue.toUInt16()
        let pokestopId = nearbyPokemon.fortID
        let gender = nearbyPokemon.pokemonDisplay.gender.rawValue.toUInt8()
        let form = nearbyPokemon.pokemonDisplay.form.rawValue.toUInt16()
        if nearbyPokemon.hasPokemonDisplay {
            costume = nearbyPokemon.pokemonDisplay.costume.rawValue.toUInt8()
            weather = nearbyPokemon.pokemonDisplay.weatherBoostedCondition.rawValue.toUInt8()
            //The wildPokemon and nearbyPokemon GMOs don't contain actual shininess.
            //shiny = wildPokemon.pokemonData.pokemonDisplay.shiny
        }
        self.username = username

        let sql = """
                SELECT lat, lon
                FROM pokestop
                WHERE id = ?;
            """

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKEMON] Failed to connect to database.")
            throw DBController.DBError()
        }

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        mysqlStmt.bindParam(pokestopId)

        guard mysqlStmt.execute() else {
            Log.error(message: "[POKEMON] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        let results = mysqlStmt.results()

        if results.numRows == 0 {
            throw ParsingError()
        }

        let result = results.next()
        let lat = result![0] as! Double
        let lon = result![1] as! Double

        self.id = id
        self.lat = lat
        self.lon = lon
        self.pokemonId = pokemonId
        self.pokestopId = pokestopId
        self.gender = gender
        self.form = form

        self.cellId = cellId
        self.expireTimestampVerified = false

    }

    public func addEncounter(encounterData: POGOProtos_Networking_Responses_EncounterResponse, username: String?) {

        self.pokemonId = UInt16(encounterData.wildPokemon.pokemonData.pokemonID.rawValue)
        self.cp = UInt16(encounterData.wildPokemon.pokemonData.cp)
        self.move1 = UInt16(encounterData.wildPokemon.pokemonData.move1.rawValue)
        self.move2 = UInt16(encounterData.wildPokemon.pokemonData.move2.rawValue)
        self.size = Double(encounterData.wildPokemon.pokemonData.heightM)
        self.weight = Double(encounterData.wildPokemon.pokemonData.weightKg)
        self.atkIv = UInt8(encounterData.wildPokemon.pokemonData.individualAttack)
        self.defIv = UInt8(encounterData.wildPokemon.pokemonData.individualDefense)
        self.staIv = UInt8(encounterData.wildPokemon.pokemonData.individualStamina)
        self.costume = UInt8(encounterData.wildPokemon.pokemonData.pokemonDisplay.costume.rawValue)
        self.shiny = encounterData.wildPokemon.pokemonData.pokemonDisplay.shiny
        self.username = username
        self.form = UInt16(encounterData.wildPokemon.pokemonData.pokemonDisplay.form.rawValue)
        self.gender = UInt8(encounterData.wildPokemon.pokemonData.pokemonDisplay.gender.rawValue)
        if encounterData.hasCaptureProbability {
            self.capture1 = Double(encounterData.captureProbability.captureProbability[0])
            self.capture2 = Double(encounterData.captureProbability.captureProbability[1])
            self.capture3 = Double(encounterData.captureProbability.captureProbability[2])
        }
        let cpMultiplier = encounterData.wildPokemon.pokemonData.cpMultiplier
        let level: UInt8
        if cpMultiplier < 0.734 {
            level = UInt8(round(58.35178527 * cpMultiplier * cpMultiplier - 2.838007664 * cpMultiplier + 0.8539209906))
        } else {
            level = UInt8(round(171.0112688 * cpMultiplier - 95.20425243))
        }
        self.level = level
        self.isDitto = Pokemon.isDittoDisguised(pokemonId: self.pokemonId,
                                                level: self.level ?? 0,
                                                weather: self.weather ?? 0,
                                                atkIv: self.atkIv ?? 0,
                                                defIv: self.defIv ?? 0,
                                                staIv: self.staIv ?? 0
        )
        if self.isDitto {
            Log.debug(message: "[POKEMON] Pokemon \(id) Ditto found, disguised as \(self.pokemonId)")
            self.setDittoAttributes(displayPokemonId: self.pokemonId)
        }

        if self.spawnId == nil {
            let spawnId = UInt64(encounterData.wildPokemon.spawnPointID, radix: 16)
            self.spawnId = spawnId
            self.lat = encounterData.wildPokemon.latitude
            self.lon = encounterData.wildPokemon.longitude

            if !expireTimestampVerified && spawnId != nil {
                let spawnpoint: SpawnPoint?
                do {
                    spawnpoint = try SpawnPoint.getWithId(id: spawnId!)
                } catch {
                    spawnpoint = nil
                }
                if let spawnpoint = spawnpoint, let despawnSecond = spawnpoint.despawnSecond {
                    let date = Date()

                    let formatter = DateFormatter()
                    formatter.dateFormat = "mm:ss"
                    let formattedDate = formatter.string(from: date)

                    let split = formattedDate.components(separatedBy: ":")
                    let minute = Int(split[0])!
                    let second = Int(split[1])!
                    let secondOfHour = second + minute * 60

                    let depsawnOffset: Int
                    if despawnSecond < secondOfHour {
                        depsawnOffset = 3600 + Int(despawnSecond) - secondOfHour
                    } else {
                        depsawnOffset = Int(despawnSecond) - secondOfHour
                    }

                    self.expireTimestamp = UInt32(Int(date.timeIntervalSince1970) + depsawnOffset)
                    self.expireTimestampVerified = true
                }
            }

        }

        self.updated = UInt32(Date().timeIntervalSince1970)
        self.changed = self.updated

    }

    public static func shouldUpdate(old: Pokemon, new: Pokemon) -> Bool {
        return
            new.pokemonId != old.pokemonId ||
            new.spawnId != old.spawnId ||
            new.pokestopId != old.pokestopId ||
            new.weather != old.weather ||
            new.expireTimestampVerified != old.expireTimestampVerified ||
            new.atkIv != old.atkIv ||
            new.defIv != old.defIv ||
            new.staIv != old.staIv ||
            new.cp != old.cp ||
            new.level != old.level ||
            new.move1 != old.move1 ||
            new.move2 != old.move2 ||
            new.gender != old.gender ||
            new.form != old.form ||
            new.costume != old.costume ||
            abs(Int(new.expireTimestamp ?? 0) - Int(old.expireTimestamp ?? 0)) >= 60 ||
            fabs(new.lat - old.lat) >= 0.000001 ||
            fabs(new.lon - old.lon) >= 0.000001
    }

    public func save(mysql: MySQL?=nil, updateIV: Bool=false) throws {

        var bindFirstSeen: Bool
        var bindChangedTimestamp: Bool

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKEMON] Failed to connect to database.")
            throw DBController.DBError()
        }

        updated = UInt32(Date().timeIntervalSince1970)

        let oldPokemon: Pokemon?
        do {
            oldPokemon = try Pokemon.getWithId(mysql: mysql, id: id)
        } catch {
            oldPokemon = nil
        }
        let mysqlStmt = MySQLStmt(mysql)

        if oldPokemon == nil {
            bindFirstSeen = false
            bindChangedTimestamp = false

            if self.expireTimestamp == nil {
                self.expireTimestamp = UInt32(Date().timeIntervalSince1970) + Pokemon.defaultTimeUnseen
            }
            firstSeenTimestamp = updated

            let sql = """
                INSERT INTO pokemon (
                    id, pokemon_id, lat, lon, spawn_id, expire_timestamp, atk_iv, def_iv, sta_iv, move_1, move_2, cp,
                    level, weight, size, capture_1, capture_2, capture_3, shiny, display_pokemon_id, username, gender,
                    form, weather, costume, pokestop_id, updated, first_seen_timestamp, changed, cell_id,
                    expire_timestamp_verified
                )
                VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), ?, ?
                )
            """
            _ = mysqlStmt.prepare(statement: sql)
            mysqlStmt.bindParam(id)
        } else {
            bindFirstSeen = true

            self.firstSeenTimestamp = oldPokemon!.firstSeenTimestamp

            if self.expireTimestamp == nil {
                let now = Date()
                let oldExpireDate = Date(timeIntervalSince1970: Double(oldPokemon!.expireTimestamp ?? 0))
                if Int(oldExpireDate.timeIntervalSince(now)) < Int(Pokemon.defaultTimeReseen) {
                    self.expireTimestamp = UInt32(Date().timeIntervalSince1970) + Pokemon.defaultTimeReseen
                } else {
                    self.expireTimestamp = oldPokemon!.expireTimestamp
                }
            }
            if !expireTimestampVerified && oldPokemon!.expireTimestampVerified {
                self.expireTimestampVerified = oldPokemon!.expireTimestampVerified
                self.expireTimestamp = oldPokemon!.expireTimestamp
            }

            if oldPokemon!.pokemonId != self.pokemonId {
                if oldPokemon!.pokemonId != Pokemon.dittoPokemonId {
                    Log.debug(
                        message: "[POKEMON] Pokemon \(id) changed from \(oldPokemon!.pokemonId) to \(self.pokemonId)"
                    )
                } else if oldPokemon!.displayPokemonId ?? 0 != self.pokemonId {
                    Log.debug(
                        message: "[POKEMON] Pokemon \(id) Ditto diguised as \(oldPokemon!.displayPokemonId ?? 0) " +
                                 "now seen as \(self.pokemonId)"
                    )
                }
            }

            if oldPokemon!.cellId != nil && self.cellId == nil {
                self.cellId = oldPokemon!.cellId
            }

            if oldPokemon!.spawnId != nil && self.spawnId == nil {
                self.spawnId = oldPokemon!.spawnId
                self.lat = oldPokemon!.lat
                self.lon = oldPokemon!.lon
            }

            if oldPokemon!.pokestopId != nil && self.pokestopId == nil {
                self.pokestopId = oldPokemon!.pokestopId
            }

            let changedSQL: String
            if updateIV && oldPokemon!.atkIv == nil && self.atkIv != nil {
                bindChangedTimestamp = false
                changedSQL = "UNIX_TIMESTAMP()"
            } else {
                bindChangedTimestamp = true
                self.changed = oldPokemon!.changed
                changedSQL = "?"
            }

            if updateIV && oldPokemon!.atkIv != nil && self.atkIv == nil {
                if !(
                        (oldPokemon!.weather == nil || oldPokemon!.weather! == 0) && (self.weather ?? 0 > 0) ||
                            (self.weather == nil || self.weather! == 0 ) && (oldPokemon!.weather ?? 0 > 0)
                    ) {
                    self.atkIv = oldPokemon!.atkIv
                    self.defIv = oldPokemon!.defIv
                    self.staIv = oldPokemon!.staIv
                    self.cp = oldPokemon!.cp
                    self.weight = oldPokemon!.weight
                    self.size = oldPokemon!.size
                    self.move1 = oldPokemon!.move1
                    self.move2 = oldPokemon!.move2
                    self.level = oldPokemon!.level
                    self.capture1 = oldPokemon!.capture1
                    self.capture2 = oldPokemon!.capture2
                    self.capture3 = oldPokemon!.capture3
                    self.shiny = oldPokemon!.shiny
                    self.isDitto = Pokemon.isDittoDisguised(pokemon: oldPokemon!)
                    if self.isDitto {
                        Log.debug(message: "[POKEMON] oldPokemon \(id) Ditto found, disguised as \(self.pokemonId)")
                        self.setDittoAttributes(displayPokemonId: self.pokemonId)
                    }
                }
            }

            guard Pokemon.shouldUpdate(old: oldPokemon!, new: self) else {
                return
            }

            let ivSQL: String
            if updateIV {
                ivSQL = "atk_iv = ?, def_iv = ?, sta_iv = ?, move_1 = ?, move_2 = ?, cp = ?, level = ?, " +
                        "weight = ?, size = ?, capture_1 = ?, capture_2 = ?, capture_3 = ?, " +
                        "shiny = ?, display_pokemon_id = ?,"
            } else {
                ivSQL = ""
            }

            if oldPokemon!.pokemonId == Pokemon.dittoPokemonId && self.pokemonId != Pokemon.dittoPokemonId {
                Log.debug(
                    message: "[POKEMON] Pokemon \(id) Ditto changed from \(oldPokemon!.pokemonId) to \(self.pokemonId)"
                )
            }

            let sql = """
                UPDATE pokemon
                SET pokemon_id = ?, lat = ?, lon = ?, spawn_id = ?, expire_timestamp = ?, \(ivSQL) username = ?,
                    gender = ?, form = ?, weather = ?, costume = ?, pokestop_id = ?, updated = UNIX_TIMESTAMP(),
                    first_seen_timestamp = ?, changed = \(changedSQL), cell_id = ?, expire_timestamp_verified = ?
                WHERE id = ?
            """
            _ = mysqlStmt.prepare(statement: sql)
        }

        mysqlStmt.bindParam(pokemonId)
        mysqlStmt.bindParam(lat)
        mysqlStmt.bindParam(lon)
        mysqlStmt.bindParam(spawnId)
        mysqlStmt.bindParam(expireTimestamp)
        if updateIV || oldPokemon == nil {
            mysqlStmt.bindParam(atkIv)
            mysqlStmt.bindParam(defIv)
            mysqlStmt.bindParam(staIv)
            mysqlStmt.bindParam(move1)
            mysqlStmt.bindParam(move2)
            mysqlStmt.bindParam(cp)
            mysqlStmt.bindParam(level)
            mysqlStmt.bindParam(weight)
            mysqlStmt.bindParam(size)
            mysqlStmt.bindParam(capture1)
            mysqlStmt.bindParam(capture2)
            mysqlStmt.bindParam(capture3)
            mysqlStmt.bindParam(shiny)
            mysqlStmt.bindParam(displayPokemonId)
        }
        mysqlStmt.bindParam(username)
        mysqlStmt.bindParam(gender)
        mysqlStmt.bindParam(form)
        mysqlStmt.bindParam(weather)
        mysqlStmt.bindParam(costume)
        mysqlStmt.bindParam(pokestopId)
        if bindFirstSeen {
            mysqlStmt.bindParam(firstSeenTimestamp)
        }
        if bindChangedTimestamp {
            mysqlStmt.bindParam(changed)
        }
        mysqlStmt.bindParam(cellId)
        mysqlStmt.bindParam(expireTimestampVerified)

        if oldPokemon != nil {
            mysqlStmt.bindParam(id)
        }

        if self.spawnId != nil {
            let spawnPoint: SpawnPoint
            if expireTimestampVerified && expireTimestamp != nil {

                let date = Date(timeIntervalSince1970: Double(self.expireTimestamp!))

                let formatter = DateFormatter()
                formatter.dateFormat = "mm:ss"
                let formattedDate = formatter.string(from: date)

                let split = formattedDate.components(separatedBy: ":")
                let minute = Int(split[0])!
                let second = Int(split[1])!
                let secondOfHour = second + minute * 60
                spawnPoint = SpawnPoint(id: spawnId!, lat: lat, lon: lon, updated: updated,
                                        despawnSecond: UInt16(secondOfHour))
            } else {
                spawnPoint = SpawnPoint(id: spawnId!, lat: lat, lon: lon, updated: updated, despawnSecond: nil)
            }
            try? spawnPoint.save(mysql: mysql, update: true)
        }

        guard mysqlStmt.execute() else {
            if mysqlStmt.errorCode() == 1062 {
                Log.debug(message: "[POKEMON] Duplicated key. Skipping...")
            } else {
                Log.error(message: "[POKEMON] Failed to execute query. (\(mysqlStmt.errorMessage()))")
            }
            throw DBController.DBError()
        }

        if oldPokemon == nil {
            WebHookController.global.addPokemonEvent(pokemon: self)
            InstanceController.global.gotPokemon(pokemon: self)
            if self.atkIv != nil {
                InstanceController.global.gotIV(pokemon: self)
            }
        } else if updateIV && oldPokemon!.atkIv == nil && self.atkIv != nil {
            WebHookController.global.addPokemonEvent(pokemon: self)
            InstanceController.global.gotIV(pokemon: self)
        }
    }

    //  swiftlint:disable:next function_parameter_count
    public static func getAll(mysql: MySQL?=nil, minLat: Double, maxLat: Double, minLon: Double, maxLon: Double,
                              showIV: Bool, updated: UInt32, pokemonFilterExclude: [Int]?=nil,
                              pokemonFilterIV: [String: String]?=nil) throws -> [Pokemon] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKEMON] Failed to connect to database.")
            throw DBController.DBError()
        }

        var pokemonFilterExclude = pokemonFilterExclude ?? [Int]()

        if pokemonFilterIV != nil && !pokemonFilterIV!.isEmpty && showIV {
            for ivFilter in pokemonFilterIV! {
                guard let id = Int(ivFilter.key) else {
                    continue
                }
                if !pokemonFilterExclude.contains(id) {
                    pokemonFilterExclude.append(id)
                }
            }

        }

        let sqlExclude: String
        if pokemonFilterExclude.isEmpty {
            sqlExclude = ""
        } else {
            var sqlExcludeCreate = "pokemon_id NOT IN ("
            for _ in 1..<pokemonFilterExclude.count {
                sqlExcludeCreate += "?, "
            }
            sqlExcludeCreate += "?)"
            sqlExclude = sqlExcludeCreate
        }

        let sqlAdd: String
        if (pokemonFilterIV == nil || pokemonFilterIV!.isEmpty || !showIV) && pokemonFilterExclude.isEmpty {
            sqlAdd = ""
        } else if pokemonFilterIV == nil || pokemonFilterIV!.isEmpty || !showIV {
            sqlAdd = " AND \(sqlExclude)"
        } else {
            var orPart = ""
            var andPart = ""
            for filter in pokemonFilterIV! {
                guard let sql = sqlifyIvFilter(filter: filter.value), sql != "" else {
                    continue
                }
                if filter.key == "and" {
                    andPart += "\(sql)"
                } else if !pokemonFilterExclude.isEmpty {
                    if orPart == "" {
                        orPart += "("
                    } else {
                        orPart += " OR "
                    }
                    if filter.key == "or" {
                        orPart += "(\(sql))"
                    } else {
                        let id = Int(filter.key) ?? 0
                        orPart += "( pokemon_id = \(id) AND \(sql))"
                    }
                }
            }
            if sqlExclude != "" {
                if orPart == "" {
                    orPart += "("
                } else {
                    orPart += " OR "
                }
                orPart += "(\(sqlExclude))"
            }
            if orPart != "" {
                orPart += ")"
            }

            if orPart != "" && andPart != "" {
                sqlAdd = " AND (\(orPart) AND \(andPart))"
            } else if orPart != "" {
                sqlAdd = " AND (\(orPart))"
            } else if andPart != "" {
                sqlAdd = " AND (\(andPart))"
            } else if sqlExclude != "" {
                sqlAdd = " AND (\(sqlExclude))"
            } else {
                sqlAdd = ""
            }

        }

        let sql = """
            SELECT id, pokemon_id, lat, lon, spawn_id, expire_timestamp, atk_iv, def_iv, sta_iv, move_1, move_2,
                   gender, form, cp, level, weather, costume, weight, size, capture_1, capture_2, capture_3,
                   display_pokemon_id, pokestop_id, updated, first_seen_timestamp, changed, cell_id,
                   expire_timestamp_verified, shiny, username
            FROM pokemon
            WHERE expire_timestamp >= UNIX_TIMESTAMP() AND lat >= ? AND lat <= ? AND lon >= ? AND
                  lon <= ? AND updated > ? \(sqlAdd)
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(minLat)
        mysqlStmt.bindParam(maxLat)
        mysqlStmt.bindParam(minLon)
        mysqlStmt.bindParam(maxLon)
        mysqlStmt.bindParam(updated)
        for id in pokemonFilterExclude {
            mysqlStmt.bindParam(id)
        }

        guard mysqlStmt.execute() else {
            Log.error(message: "[POKEMON] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var pokemons = [Pokemon]()
        while let result = results.next() {

            let id = result[0] as! String
            let pokemonId = result[1] as! UInt16
            let lat = result[2] as! Double
            let lon = result[3] as! Double
            let spawnId = result[4] as? UInt64
            let expireTimestamp = result[5] as? UInt32

            let atkIv: UInt8?
            let defIv: UInt8?
            let staIv: UInt8?
            let move1: UInt16?
            let move2: UInt16?
            let cp: UInt16?
            let level: UInt8?
            let weight: Double?
            let size: Double?
            let capture1: Double?
            let capture2: Double?
            let capture3: Double?
            let displayPokemonId: UInt16?
            if showIV {
                atkIv = result[6] as? UInt8
                defIv = result[7] as? UInt8
                staIv = result[8] as? UInt8
                move1 = result[9] as? UInt16
                move2 = result[10] as? UInt16
                cp = result[13] as? UInt16
                level = result[14] as? UInt8
                weight = result[17] as? Double
                size = result[18] as? Double
                capture1 = result[19] as? Double
                capture2 = result[20] as? Double
                capture3 = result[21] as? Double
                displayPokemonId = result[22] as? UInt16
            } else {
                atkIv = nil
                defIv = nil
                staIv = nil
                move1 = nil
                move2 = nil
                cp = nil
                level = nil
                weight = nil
                size = nil
                capture1 = nil
                capture2 = nil
                capture3 = nil
                displayPokemonId = nil
            }

            let gender = result[11] as? UInt8
            let form = result[12] as? UInt16
            let weather = result[15] as? UInt8
            let costume = result[16] as? UInt8
            let pokestopId = result[23] as? String
            let updated = result[24] as! UInt32
            let firstSeenTimestamp = result[25] as! UInt32
            let changed = result[26] as! UInt32
            let cellId = result[27] as? UInt64
            let expireTimestampVerified = (result[28] as? UInt8)!.toBool()
            let shiny = (result[29] as? UInt8)?.toBool()
            let username = result[30] as? String

            pokemons.append(Pokemon(
                id: id, pokemonId: pokemonId, lat: lat, lon: lon, spawnId: spawnId, expireTimestamp: expireTimestamp,
                atkIv: atkIv, defIv: defIv, staIv: staIv, move1: move1, move2: move2, gender: gender, form: form,
                cp: cp, level: level, weight: weight, costume: costume, size: size, capture1: capture1,
                capture2: capture2, capture3: capture3, displayPokemonId: displayPokemonId,
                weather: weather, shiny: shiny, username: username, pokestopId: pokestopId,
                firstSeenTimestamp: firstSeenTimestamp, updated: updated, changed: changed, cellId: cellId,
                expireTimestampVerified: expireTimestampVerified
            ))
        }
        return pokemons

    }

    public static func getWithId(mysql: MySQL?=nil, id: String) throws -> Pokemon? {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKEMON] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
            SELECT id, pokemon_id, lat, lon, spawn_id, expire_timestamp, atk_iv, def_iv, sta_iv, move_1, move_2,
                   gender, form, cp, level, weather, costume, weight, size, capture_1, capture_2, capture_3,
                   display_pokemon_id, pokestop_id, updated, first_seen_timestamp, changed, cell_id,
                   expire_timestamp_verified, shiny, username
            FROM pokemon
            WHERE id = ?
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(id)

        guard mysqlStmt.execute() else {
            Log.error(message: "[POKEMON] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }

        let result = results.next()!

        let id = result[0] as! String
        let pokemonId = result[1] as! UInt16
        let lat = result[2] as! Double
        let lon = result[3] as! Double
        let spawnId = result[4] as? UInt64
        let expireTimestamp = result[5] as? UInt32
        let atkIv = result[6] as? UInt8
        let defIv = result[7] as? UInt8
        let staIv = result[8] as? UInt8
        let move1 = result[9] as? UInt16
        let move2 = result[10] as? UInt16
        let gender = result[11] as? UInt8
        let form = result[12] as? UInt16
        let cp = result[13] as? UInt16
        let level = result[14] as? UInt8
        let weather = result[15] as? UInt8
        let costume = result[16] as? UInt8
        let weight = result[17] as? Double
        let size = result[18] as? Double
        let capture1 = result[19] as? Double
        let capture2 = result[20] as? Double
        let capture3 = result[21] as? Double
        let displayPokemonId = result[22] as? UInt16
        let pokestopId = result[23] as? String
        let updated = result[24] as! UInt32
        let firstSeenTimestamp = result[25] as! UInt32
        let changed = result[26] as! UInt32
        let cellId = result[27] as? UInt64
        let expireTimestampVerified = (result[28] as? UInt8)!.toBool()
        let shiny = (result[29] as? UInt8)?.toBool()
        let username = result[30] as? String

        return Pokemon(id: id, pokemonId: pokemonId, lat: lat, lon: lon, spawnId: spawnId,
                       expireTimestamp: expireTimestamp, atkIv: atkIv, defIv: defIv, staIv: staIv, move1: move1,
                       move2: move2, gender: gender, form: form, cp: cp, level: level, weight: weight,
                       costume: costume, size: size, capture1: capture1, capture2: capture2, capture3: capture3,
                       displayPokemonId: displayPokemonId, weather: weather,
                       shiny: shiny, username: username, pokestopId: pokestopId, firstSeenTimestamp: firstSeenTimestamp,
                       updated: updated, changed: changed, cellId: cellId,
                       expireTimestampVerified: expireTimestampVerified
        )
    }

    static func == (lhs: Pokemon, rhs: Pokemon) -> Bool {
        return lhs.id == rhs.id
    }

    private func setDittoAttributes(displayPokemonId: UInt16) {
        let moveTransformFast: UInt16 = 242
        let moveStruggle: UInt16 = 133
        self.displayPokemonId = displayPokemonId
        self.pokemonId = Pokemon.dittoPokemonId
        self.form = 0
        self.move1 = moveTransformFast
        self.move2 = moveStruggle
        self.gender = 3
        self.costume = 0
        self.size = 0
        self.weight = 0
    }

    private static func isDittoDisguised(pokemon: Pokemon) -> Bool {
        return isDittoDisguised(pokemonId: pokemon.pokemonId,
                                level: pokemon.level ?? 0,
                                weather: pokemon.weather ?? 0,
                                atkIv: pokemon.atkIv ?? 0,
                                defIv: pokemon.defIv ?? 0,
                                staIv: pokemon.staIv ?? 0
        )
    }

    //  swiftlint:disable:next function_parameter_count
    private static func isDittoDisguised(pokemonId: UInt16, level: UInt8, weather: UInt8,
                                         atkIv: UInt8, defIv: UInt8, staIv: UInt8) -> Bool {
        let isDisguised = (pokemonId == Pokemon.dittoPokemonId) ||
                          (WebHookRequestHandler.dittoDisguises?.contains(pokemonId) ?? false)
        let isUnderLevelBoosted = level > 0 && level < Pokemon.weatherBoostMinLevel
        let isUnderIvStatBoosted = level > 0 &&
            (atkIv < Pokemon.weatherBoostMinIvStat ||
             defIv < Pokemon.weatherBoostMinIvStat ||
             staIv < Pokemon.weatherBoostMinIvStat)
        let isWeatherBoosted = weather > 0
        return isDisguised && (isUnderLevelBoosted || isUnderIvStatBoosted) && isWeatherBoosted
    }

    public static func truncate(mysql: MySQL?=nil) throws {
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKEMON] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
        TRUNCATE TABLE `pokemon`
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        guard mysqlStmt.execute() else {
            Log.error(message: "[POKEMON] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }

    private static func sqlifyIvFilter(filter: String) -> String? {

        let fullMatch = "^(?!&&|\\|\\|)((\\|\\||&&)?\\(?((A|D|S|L)?[0-9.]+(-(A|D|S|L)?[0-9.]+)?)\\)?)*$"

        if filter !~ fullMatch {
            return nil
        }

        let singleMatch = "(A|D|S|L)?[0-9.]+(-(A|D|S|L)?[0-9.]+)?"

        var sql = singleMatch.r?.replaceAll(in: filter) { match in
            if let firstGroup = match.group(at: 0) {

                var firstGroupNumbers = firstGroup.replacingOccurrences(of: "A", with: "")
                firstGroupNumbers = firstGroupNumbers.replacingOccurrences(of: "D", with: "")
                firstGroupNumbers = firstGroupNumbers.replacingOccurrences(of: "S", with: "")
                firstGroupNumbers = firstGroupNumbers.replacingOccurrences(of: "L", with: "")

                let column: String
                if firstGroup.contains(string: "A") {
                    column = "atk_iv"
                } else if firstGroup.contains(string: "D") {
                    column = "def_iv"
                } else if firstGroup.contains(string: "S") {
                    column = "sta_iv"
                } else if firstGroup.contains(string: "L") {
                    column = "level"
                } else {
                    column = "iv"
                }

                if firstGroupNumbers.contains(string: "-") { // min max
                    let split = firstGroupNumbers.components(separatedBy: "-")
                    guard split.count == 2, let number0 = Float(split[0]), let number1 = Float(split[1]) else {
                        return nil
                    }

                    let min: Float
                    let max: Float
                    if number0 < number1 {
                        min = number0
                        max = number1
                    } else {
                        max = number1
                        min = number0
                    }

                    return "\(column) >= \(min) AND \(column) <= \(max)"
                } else { // fixed
                    guard let number = Float(firstGroupNumbers) else {
                        return nil
                    }
                    return "\(column) = \(number)"
                }

            }
            return nil
        } ?? ""
        if sql == "" {
            return nil
        }

        sql = sql.replacingOccurrences(of: "&&", with: " AND ")
        sql = sql.replacingOccurrences(of: "||", with: " OR ")

        return sql

    }

}
