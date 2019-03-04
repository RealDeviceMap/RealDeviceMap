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

class Pokemon: JSONConvertibleObject, WebHookEvent {
    
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
            "first_seen_timestamp": firstSeenTimestamp,
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
            "updated": updated
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
            "first_seen": firstSeenTimestamp,
            "verified": false,
            "last_modified_time": updated,
            "gender": gender ?? 0,
            "cp": cp ?? "",
            "form": form ?? 0,
            "costume": costume ?? 0,
            "individual_attack": atkIv ?? "",
            "individual_defense": defIv ?? "",
            "individual_stamina": staIv ?? "",
            "move_1": move1 ?? "",
            "move_2": move2 ?? "",
            "weight": weight ?? "",
            "height": size ?? "",
            "weather": weather ?? ""
        ]
        return [
            "type": "pokemon",
            "message": message
        ]
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
    var firstSeenTimestamp: UInt32
    var updated: UInt32
    
    init(id: String, pokemonId: UInt16, lat: Double, lon: Double, spawnId: UInt64?, expireTimestamp: UInt32?, atkIv: UInt8?, defIv: UInt8?, staIv: UInt8?, move1: UInt16?, move2: UInt16?, gender: UInt8?, form: UInt8?, cp: UInt16?, level: UInt8?, weight: Double?, costume: UInt8?, size: Double?, weather: UInt8?, pokestopId: String?, firstSeenTimestamp: UInt32, updated: UInt32) {
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
    }
    
    init(json: [String: Any]) throws {
                
        var lat = json["lat"] as? Double
        var lon = json["lon"] as? Double
        let pokestopId = json["fort_id"] as? String
        
        if lat == nil {
            
            let sql = """
                SELECT lat, lon
                FROM pokestop
                WHERE id = ?;
            """
            
            guard let mysql = DBController.global.mysql else {
                Log.error(message: "[POKEMON] Failed to connect to database.")
                throw DBController.DBError()
            }
            
            let mysqlStmt = MySQLStmt(mysql)
            _ = mysqlStmt.prepare(statement: sql)
            
            mysqlStmt.bindParam(pokestopId!)
            
            guard mysqlStmt.execute() else {
                Log.error(message: "[POKEMON] Failed to execute query. (\(mysqlStmt.errorMessage())")
                throw DBController.DBError()
            }
            
            let results = mysqlStmt.results()
            
            if results.numRows == 0 {
                throw ParsingError()
            }
            
            let result = results.next()
            lat = result![0] as? Double
            lon = result![1] as? Double
        }
        
        guard
            let pokemonId = json["pokemon_id"] as? Int,
            let id = json["encounter_id"] as? String ??
                (json["encounter_id"] as? Int)?.toString() ??
                json["id"] as? String ??
                (json["id"] as? Int)?.toString()
            else {
                throw ParsingError()
        }
        
        let spawnIdString  = (json["spawn_id"] as? String)
        let spawnId: UInt64?
        if spawnIdString != nil {
            spawnId = UInt64(spawnIdString!, radix: 16)
        } else {
            spawnId = nil
        }
        
        let weather = json["weather"] as? Int
        let costume = json["costume"] as? Int
        let gender = json["gender"] as? Int
        let form = json["form"] as? Int
        
        self.id = id
        self.lat = lat!
        self.lon = lon!
        self.pokemonId = pokemonId.toUInt16()
        self.spawnId = spawnId
        self.weather = weather?.toUInt8Checked()
        self.costume = costume?.toUInt8Checked()
        self.pokestopId = pokestopId
        self.gender = gender?.toUInt8Checked()
        self.form = form?.toUInt8Checked()
        
        self.firstSeenTimestamp = UInt32(Date().timeIntervalSince1970)
        self.updated = UInt32(Date().timeIntervalSince1970)
    }
    
    init(wildPokemon: POGOProtos_Map_Pokemon_WildPokemon) {
        
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
        
        self.firstSeenTimestamp = UInt32(Date().timeIntervalSince1970)
        self.updated = UInt32(Date().timeIntervalSince1970)
        
    }
    
    init(nearbyPokemon: POGOProtos_Map_Pokemon_NearbyPokemon) throws {
        
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
        
        guard let mysql = DBController.global.mysql else {
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
        
        self.firstSeenTimestamp = UInt32(Date().timeIntervalSince1970)
        self.updated = UInt32(Date().timeIntervalSince1970)

    }

    public func save() throws {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[POKEMON] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        if self.spawnId != nil {
            let spawnPoint = SpawnPoint(id: spawnId!, lat: lat, lon: lon, updated: updated)
            try? spawnPoint.save()
        }
        
        let oldPokemon: Pokemon?
        do {
            oldPokemon = try Pokemon.getWithId(id: id)
        } catch {
            oldPokemon = nil
        }
        let mysqlStmt = MySQLStmt(mysql)
        
        if oldPokemon == nil {
            if self.expireTimestamp == nil {
                self.expireTimestamp = UInt32(Date().timeIntervalSince1970) + Pokemon.defaultTimeUnseen
            }
            
            WebHookController.global.addPokemonEvent(pokemon: self)
            let sql = """
                INSERT INTO pokemon (id, pokemon_id, lat, lon, spawn_id, expire_timestamp, atk_iv, def_iv, sta_iv, move_1, move_2, gender, form, cp, level, weather, costume, weight, size, pokestop_id, updated, first_seen_timestamp)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            _ = mysqlStmt.prepare(statement: sql)
            mysqlStmt.bindParam(id)
        } else {
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
            
            if oldPokemon!.spawnId != nil && self.spawnId == nil {
                self.spawnId = oldPokemon!.spawnId
                self.lat = oldPokemon!.lat
                self.lon = oldPokemon!.lon
            }
            
            if oldPokemon!.pokestopId != nil && self.pokestopId == nil {
                self.pokestopId = oldPokemon!.pokestopId
            }
            
            if oldPokemon!.atkIv != nil && self.atkIv == nil {
                self.atkIv = oldPokemon!.atkIv
                self.defIv = oldPokemon!.defIv
                self.staIv = oldPokemon!.staIv
                self.cp = oldPokemon!.cp
                self.weight = oldPokemon!.weight
                self.size = oldPokemon!.size
            }
            
            if oldPokemon!.atkIv != self.atkIv {
                WebHookController.global.addPokemonEvent(pokemon: self)
            }
            
            // Resend?
            
            let sql = """
                UPDATE pokemon
                SET pokemon_id = ?, lat = ?, lon = ?, spawn_id = ?, expire_timestamp = ?, atk_iv = ?, def_iv = ?, sta_iv = ?, move_1 = ?, move_2 = ?, gender = ?, form = ?, cp = ?, level = ?, weather = ?, costume = ?, weight = ?, size = ?, pokestop_id = ?, updated = ?, first_seen_timestamp = ?
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
        mysqlStmt.bindParam(updated)
        mysqlStmt.bindParam(firstSeenTimestamp)
        
        if oldPokemon != nil {
            mysqlStmt.bindParam(id)
        }
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[POKEMON] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
    
    public static func getAll(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double, updated: UInt32, pokemonFilterExclude: [Int]?=nil) throws -> [Pokemon] {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[POKEMON] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sqlExclude: String
        if pokemonFilterExclude == nil || pokemonFilterExclude!.isEmpty {
            sqlExclude = ""
        } else {
            var sqlExcludeCreate = "AND pokemon_id NOT IN ("
            for _ in 1..<pokemonFilterExclude!.count {
                sqlExcludeCreate += "?, "
            }
            sqlExcludeCreate += "?)"
            sqlExclude = sqlExcludeCreate
        }
        let sql = """
            SELECT id, pokemon_id, lat, lon, spawn_id, expire_timestamp, atk_iv, def_iv, sta_iv, move_1, move_2, gender, form, cp, level, weather, costume, weight, size, pokestop_id, updated, first_seen_timestamp
            FROM pokemon
            WHERE expire_timestamp >= UNIX_TIMESTAMP() AND lat >= ? AND lat <= ? AND lon >= ? AND lon <= ? AND updated > ? \(sqlExclude)
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(minLat)
        mysqlStmt.bindParam(maxLat)
        mysqlStmt.bindParam(minLon)
        mysqlStmt.bindParam(maxLon)
        mysqlStmt.bindParam(updated)
        if pokemonFilterExclude != nil {
            for id in pokemonFilterExclude! {
                mysqlStmt.bindParam(id)
            }
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
            
            pokemons.append(Pokemon(id: id, pokemonId: pokemonId, lat: lat, lon: lon, spawnId: spawnId, expireTimestamp: expireTimestamp, atkIv: atkIv, defIv: defIv, staIv: staIv, move1: move1, move2: move2, gender: gender, form: form, cp: cp, level: level, weight: weight, costume: costume, size: size, weather: weather, pokestopId: pokestopId, firstSeenTimestamp: firstSeenTimestamp, updated: updated))
            
        }
        return pokemons
        
    }
    
    public static func getWithId(id: String) throws -> Pokemon? {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[POKEMON] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT id, pokemon_id, lat, lon, spawn_id, expire_timestamp, atk_iv, def_iv, sta_iv, move_1, move_2, gender, form, cp, level, weather, costume, weight, size, pokestop_id, updated, first_seen_timestamp
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
        
        return Pokemon(id: id, pokemonId: pokemonId, lat: lat, lon: lon, spawnId: spawnId, expireTimestamp: expireTimestamp, atkIv: atkIv, defIv: defIv, staIv: staIv, move1: move1, move2: move2, gender: gender, form: form, cp: cp, level: level, weight: weight, costume: costume, size: size, weather: weather, pokestopId: pokestopId, firstSeenTimestamp: firstSeenTimestamp, updated: updated)
        
    }
    
}
