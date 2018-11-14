//
//  Pokemon.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//

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
    
    class ParsingError: Error {}
    
    override func getJSONValues() -> [String : Any] {
        return [
            "id": id,
            "pokemon_id": pokemonId,
            "lat": lat,
            "lon": lon,
            "spawn_id": spawnId as Any,
            "expire_timestamp": expireTimestamp as Any,
            "expire_timestamp_true": false, // FIXME: - Temp solution
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
            "pokestop_id": pokestopId as Any,
            "costume": costume as Any,
            "updated": updated ?? 1
        ]
    }
    
    func getWebhookValues(type: String) -> [String : Any] {
        let message: [String: Any] = [
            "spawnpoint_id": spawnId?.toHexString() ?? "None",
            "pokestop_id": pokestopId ?? "None",
            "encounter_id": id,
            "pokemon_id": pokemonId,
            "latitude": lat,
            "longitude": lon,
            "disappear_time": expireTimestamp ?? 0,
            "first_seen": firstSeenTimestamp ?? 1,
            "verified": false,
            "last_modified_time": updated ?? 1,
            "gender": gender ?? 0,
            "cp": cp ?? 0,
            "form": form ?? 0,
            "costume": costume ?? 0,
            "individual_attack": atkIv ?? 0,
            "individual_defense": defIv ?? 0,
            "individual_stamina": staIv ?? 0,
            "level": level ?? 0,
            "move_1": move1 ?? 0,
            "move_2": move2 ?? 0,
            "weight": weight ?? 0,
            "height": size ?? 0,
            "weather": weather ?? 0
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
    var form: UInt8?
    var costume: UInt8?
    var cp: UInt16?
    var level: UInt8?
    var weight: Double?
    var size: Double?
    var weather: UInt8?
    var pokestopId: String?
    var firstSeenTimestamp: UInt32?
    var updated: UInt32?
    var changed: UInt32?
    var cellId: UInt64?
    
    init(id: String, pokemonId: UInt16, lat: Double, lon: Double, spawnId: UInt64?, expireTimestamp: UInt32?, atkIv: UInt8?, defIv: UInt8?, staIv: UInt8?, move1: UInt16?, move2: UInt16?, gender: UInt8?, form: UInt8?, cp: UInt16?, level: UInt8?, weight: Double?, costume: UInt8?, size: Double?, weather: UInt8?, pokestopId: String?, firstSeenTimestamp: UInt32?, updated: UInt32?, changed: UInt32?, cellId: UInt64?) {
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
        self.pokestopId = pokestopId
        self.updated = updated
        self.firstSeenTimestamp = firstSeenTimestamp
        self.changed = changed
        self.cellId = cellId
    }
        
    init(wildPokemon: POGOProtos_Map_Pokemon_WildPokemon, cellId: UInt64) {
        
        let id = wildPokemon.encounterID.description
        let pokemonId = wildPokemon.pokemonData.pokemonID.rawValue.toUInt16()
        let lat = wildPokemon.latitude
        let lon = wildPokemon.longitude
        let spawnId = UInt64(wildPokemon.spawnPointID, radix: 16)
        let gender = wildPokemon.pokemonData.pokemonDisplay.gender.rawValue.toUInt8()
        let form = wildPokemon.pokemonData.pokemonDisplay.form.rawValue.toUInt8()
        let costume = wildPokemon.pokemonData.pokemonDisplay.costume.rawValue.toUInt8()
        let weather = wildPokemon.pokemonData.pokemonDisplay.weatherBoostedCondition.rawValue.toUInt8()
        
        self.id = id
        self.lat = lat
        self.lon = lon
        self.pokemonId = pokemonId
        self.spawnId = spawnId
        self.weather = weather
        self.costume = costume
        self.gender = gender
        self.form = form
        
        self.cellId = cellId
        
    }
    
    init(mysql: MySQL?=nil, nearbyPokemon: POGOProtos_Map_Pokemon_NearbyPokemon, cellId: UInt64) throws {
        
        let id = nearbyPokemon.encounterID.description
        let pokemonId = nearbyPokemon.pokemonID.rawValue.toUInt16()
        let pokestopId = nearbyPokemon.fortID
        let gender = nearbyPokemon.pokemonDisplay.gender.rawValue.toUInt8()
        let form = nearbyPokemon.pokemonDisplay.form.rawValue.toUInt8()
        let costume = nearbyPokemon.pokemonDisplay.costume.rawValue.toUInt8()
        let weather = nearbyPokemon.pokemonDisplay.weatherBoostedCondition.rawValue.toUInt8()
        
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
        self.weather = weather
        self.costume = costume
        self.gender = gender
        self.form = form
        
        self.cellId = cellId

    }
    
    public func addEncounter(encounterData: POGOProtos_Networking_Responses_EncounterResponse) {
        
        self.cp = UInt16(encounterData.wildPokemon.pokemonData.cp)
        self.move1 = UInt16(encounterData.wildPokemon.pokemonData.move1.rawValue)
        self.move2 = UInt16(encounterData.wildPokemon.pokemonData.move2.rawValue)
        self.size = Double(encounterData.wildPokemon.pokemonData.heightM)
        self.weight = Double(encounterData.wildPokemon.pokemonData.weightKg)
        self.atkIv = UInt8(encounterData.wildPokemon.pokemonData.individualAttack)
        self.defIv = UInt8(encounterData.wildPokemon.pokemonData.individualDefense)
        self.staIv = UInt8(encounterData.wildPokemon.pokemonData.individualStamina)
        self.costume = UInt8(encounterData.wildPokemon.pokemonData.pokemonDisplay.costume.rawValue)
        self.form = UInt8(encounterData.wildPokemon.pokemonData.pokemonDisplay.form.rawValue)
        self.gender = UInt8(encounterData.wildPokemon.pokemonData.pokemonDisplay.gender.rawValue)
        let cpMultiplier = encounterData.wildPokemon.pokemonData.cpMultiplier
        let level: UInt8
        if cpMultiplier < 0.734 {
            level = UInt8(round(58.35178527 * cpMultiplier * cpMultiplier - 2.838007664 * cpMultiplier + 0.8539209906))
        } else {
            level = UInt8(round(171.0112688 * cpMultiplier - 95.20425243))
        }
        self.level = level
        
        self.updated = UInt32(Date().timeIntervalSince1970)
        self.changed = self.updated
        
    }

    public func save(mysql: MySQL?=nil) throws {
        
        var bindFirstSeen: Bool
        var bindChangedTimestamp: Bool
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKEMON] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        if self.spawnId != nil {
            let spawnPoint = SpawnPoint(id: spawnId!, lat: lat, lon: lon, updated: updated)
            try? spawnPoint.save(mysql: mysql)
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
            
            WebHookController.global.addPokemonEvent(pokemon: self)
            InstanceController.global.gotPokemon(pokemon: self)
            let sql = """
                INSERT INTO pokemon (id, pokemon_id, lat, lon, spawn_id, expire_timestamp, atk_iv, def_iv, sta_iv, move_1, move_2, gender, form, cp, level, weather, costume, weight, size, pokestop_id, updated, first_seen_timestamp, changed, cell_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), ?)
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
            if oldPokemon!.atkIv == nil && self.atkIv != nil {
                WebHookController.global.addPokemonEvent(pokemon: self)
                bindChangedTimestamp = false
                changedSQL = "UNIX_TIMESTAMP()"
            } else {
                bindChangedTimestamp = true
                self.changed = oldPokemon!.changed
                changedSQL = "?"
            }
            
            if oldPokemon!.atkIv != nil && self.atkIv == nil {
                self.atkIv = oldPokemon!.atkIv
                self.defIv = oldPokemon!.defIv
                self.staIv = oldPokemon!.staIv
                self.cp = oldPokemon!.cp
                self.weight = oldPokemon!.weight
                self.size = oldPokemon!.size
                self.move1 = oldPokemon!.move1
                self.move2 = oldPokemon!.move2
                self.level = oldPokemon!.level
            }
            
            let sql = """
                UPDATE pokemon
                SET pokemon_id = ?, lat = ?, lon = ?, spawn_id = ?, expire_timestamp = ?, atk_iv = ?, def_iv = ?, sta_iv = ?, move_1 = ?, move_2 = ?, gender = ?, form = ?, cp = ?, level = ?, weather = ?, costume = ?, weight = ?, size = ?, pokestop_id = ?, updated = UNIX_TIMESTAMP(), first_seen_timestamp = ?, changed = \(changedSQL), cell_id = ?
                WHERE id = ?
            """
            _ = mysqlStmt.prepare(statement: sql)
        }
        
        mysqlStmt.bindParam(pokemonId)
        mysqlStmt.bindParam(lat)
        mysqlStmt.bindParam(lon)
        mysqlStmt.bindParam(spawnId)
        mysqlStmt.bindParam(expireTimestamp)
        mysqlStmt.bindParam(atkIv)
        mysqlStmt.bindParam(defIv)
        mysqlStmt.bindParam(staIv)
        mysqlStmt.bindParam(move1)
        mysqlStmt.bindParam(move2)
        mysqlStmt.bindParam(gender)
        mysqlStmt.bindParam(form)
        mysqlStmt.bindParam(cp)
        mysqlStmt.bindParam(level)
        mysqlStmt.bindParam(weather)
        mysqlStmt.bindParam(costume)
        mysqlStmt.bindParam(weight)
        mysqlStmt.bindParam(size)
        mysqlStmt.bindParam(pokestopId)
        if bindFirstSeen {
            mysqlStmt.bindParam(firstSeenTimestamp)
        }
        if bindChangedTimestamp {
            mysqlStmt.bindParam(changed)
        }
        mysqlStmt.bindParam(cellId)
        
        if oldPokemon != nil {
            mysqlStmt.bindParam(id)
        }
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[POKEMON] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
    
    public static func getAll(mysql: MySQL?=nil, minLat: Double, maxLat: Double, minLon: Double, maxLon: Double, showIV: Bool, updated: UInt32, pokemonFilterExclude: [Int]?=nil, pokemonFilterIV: [String: String]?=nil) throws -> [Pokemon] {
        
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
                } else {
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
                sqlAdd = " AND \(orPart) AND \(andPart)"
            } else if orPart != "" {
                sqlAdd = " AND \(orPart)"
            } else if andPart != "" {
                sqlAdd = " AND \(andPart)"
            } else if sqlExclude != "" {
                sqlAdd = " AND \(sqlExclude)"
            } else {
                sqlAdd = ""
            }
            
        }
        
        let sql = """
            SELECT id, pokemon_id, lat, lon, spawn_id, expire_timestamp, atk_iv, def_iv, sta_iv, move_1, move_2, gender, form, cp, level, weather, costume, weight, size, pokestop_id, updated, first_seen_timestamp, changed, cell_id
            FROM pokemon
            WHERE expire_timestamp >= UNIX_TIMESTAMP() AND lat >= ? AND lat <= ? AND lon >= ? AND lon <= ? AND updated > ? \(sqlAdd)
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
            }
            
            let gender = result[11] as? UInt8
            let form = result[12] as? UInt8
            let weather = result[15] as? UInt8
            let costume = result[16] as? UInt8
            let pokestopId = result[19] as? String
            let updated = result[20] as! UInt32
            let firstSeenTimestamp = result[21] as! UInt32
            let changed = result[22] as! UInt32
            let cellId = result[23] as? UInt64
            
            pokemons.append(Pokemon(id: id, pokemonId: pokemonId, lat: lat, lon: lon, spawnId: spawnId, expireTimestamp: expireTimestamp, atkIv: atkIv, defIv: defIv, staIv: staIv, move1: move1, move2: move2, gender: gender, form: form, cp: cp, level: level, weight: weight, costume: costume, size: size, weather: weather, pokestopId: pokestopId, firstSeenTimestamp: firstSeenTimestamp, updated: updated, changed: changed, cellId: cellId))
            
        }
        return pokemons
        
    }
    
    public static func getWithId(mysql: MySQL?=nil, id: String) throws -> Pokemon? {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKEMON] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT id, pokemon_id, lat, lon, spawn_id, expire_timestamp, atk_iv, def_iv, sta_iv, move_1, move_2, gender, form, cp, level, weather, costume, weight, size, pokestop_id, updated, first_seen_timestamp, changed, cell_id
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
        let form = result[12] as? UInt8
        let cp = result[13] as? UInt16
        let level = result[14] as? UInt8
        let weather = result[15] as? UInt8
        let costume = result[16] as? UInt8
        let weight = result[17] as? Double
        let size = result[18] as? Double
        let pokestopId = result[19] as? String
        let updated = result[20] as! UInt32
        let firstSeenTimestamp = result[21] as! UInt32
        let changed = result[22] as! UInt32
        let cellId = result[23] as? UInt64
        
        return Pokemon(id: id, pokemonId: pokemonId, lat: lat, lon: lon, spawnId: spawnId, expireTimestamp: expireTimestamp, atkIv: atkIv, defIv: defIv, staIv: staIv, move1: move1, move2: move2, gender: gender, form: form, cp: cp, level: level, weight: weight, costume: costume, size: size, weather: weather, pokestopId: pokestopId, firstSeenTimestamp: firstSeenTimestamp, updated: updated, changed: changed, cellId: cellId)
        
    }
    
    static func == (lhs: Pokemon, rhs: Pokemon) -> Bool {
        return lhs.id == rhs.id
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
