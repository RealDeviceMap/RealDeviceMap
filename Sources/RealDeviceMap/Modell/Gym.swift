//
//  Gym.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//

import Foundation
import PerfectLib
import PerfectMySQL
import POGOProtos

class Gym: JSONConvertibleObject, WebHookEvent {
    
    class ParsingError: Error {}
    
    override func getJSONValues() -> [String : Any] {
        return [
            "id":id,
            "lat":lat,
            "lon":lon,
            "name":name as Any,
            "url":url as Any,
            "guard_pokemon_id": guardPokemonId as Any,
            "enabled": enabled as Any,
            "last_modified_timestamp": lastModifiedTimestamp as Any,
            "team_id": teamId as Any,
            "raid_end_timestamp": raidEndTimestamp as Any,
            "raid_spawn_timestamp": raidSpawnTimestamp as Any,
            "raid_battle_timestamp": raidBattleTimestamp as Any,
            "raid_pokemon_id": raidPokemonId as Any,
            "raid_level": raidLevel as Any,
            "availble_slots": availbleSlots as Any,
            "updated": updated,
            "ex_raid_eligible": exRaidEligible as Any,
            "in_battle": inBattle as Any,
            "raid_pokemon_form": raidPokemonForm as Any,
            "raid_pokemon_move_1": raidPokemonMove1 as Any,
            "raid_pokemon_move_2": raidPokemonMove2 as Any,
            "raid_pokemon_cp": raidPokemonCp as Any
        ]
    }
    
    func getWebhookValues() -> [String : Any] {
        return [
            "gym_id":id,
            "latitude":lat,
            "longitude":lon,
            "name":name as Any,
            "url":url as Any,
            "guard_pokemon_id": guardPokemonId as Any,
            "enabled": enabled as Any,
            "last_modified": lastModifiedTimestamp as Any,
            "team_id": teamId as Any,
            "slots_available": availbleSlots as Any,
            "updated": updated,
            "end": raidEndTimestamp as Any,
            "spawn": raidSpawnTimestamp as Any,
            "start": raidBattleTimestamp as Any,
            "pokemon_id": raidPokemonId as Any,
            "level": raidLevel as Any,
            "ex_raid_eligible": exRaidEligible as Any,
            "in_battle": inBattle as Any,
            "form": raidPokemonForm as Any,
            "move_1": raidPokemonMove1 as Any,
            "move_2": raidPokemonMove2 as Any,
            "cp": raidPokemonCp as Any
        ]
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
    var raidPokemonForm: UInt8?
    var raidPokemonCp: UInt16?
    var availbleSlots: UInt16?
    var updated: UInt32
    var exRaidEligible: Bool?
    var inBattle: Bool?
    
    init(id: String, lat: Double, lon: Double, name: String?, url: String?, guardPokemonId: UInt16?, enabled: Bool?, lastModifiedTimestamp: UInt32?, teamId: UInt8?, raidEndTimestamp: UInt32?, raidSpawnTimestamp: UInt32?, raidBattleTimestamp: UInt32?, raidPokemonId: UInt16?, raidLevel: UInt8?, availbleSlots:UInt16?, updated:UInt32, exRaidEligible: Bool?, inBattle: Bool?, raidPokemonMove1: UInt16?, raidPokemonMove2: UInt16?, raidPokemonForm: UInt8?, raidPokemonCp: UInt16?) {
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
        self.availbleSlots = availbleSlots
        self.updated = updated
        self.exRaidEligible = exRaidEligible
        self.inBattle = inBattle
        self.raidPokemonMove1 = raidPokemonMove1
        self.raidPokemonMove2 = raidPokemonMove2
        self.raidPokemonForm = raidPokemonForm
        self.raidPokemonCp = raidPokemonCp
    }
    
    init(json: [String: Any]) throws {
        
        guard
            let id = json["gym_id"] as? String,
            let lat = json["latitude"] as? Double,
            let lon = json["longitude"] as? Double
        else {
                throw ParsingError()
        }
        
        let enabled = json["enabled"] as? Bool
        let availbleSlots = json["slotsAvailble"] as? Int
        let teamId = json["team"] as? Int
        var raidPokemonId = json["raidPokemon"] as? Int
        let raidLevel = json["raidLevel"] as? Int
        let exRaidEligible = json["isExRaidEligible"] as? Bool
        let inBattle = json["isInBattle"] as? Bool
        
        let raidPokemonMove1 = json["raidPokemonMove1"] as? Int
        let raidPokemonMove2 = json["raidPokemonMove2"] as? Int
        let raidPokemonForm = json["raidPokemonForm"] as? Int
        let raidPokemonCp = json["raidPokemonCp"] as? Int
        
        if raidPokemonId == 0 {
            raidPokemonId = nil
        }
        var guardPokemonId = json["guardingPokemonIdentifier"] as? Int
        if guardPokemonId == 0 {
            guardPokemonId = nil
        }
        
        var lastModifiedTimestamp = json["lastModifiedTimestampMs"] as? Int
        if lastModifiedTimestamp != nil {
            lastModifiedTimestamp = lastModifiedTimestamp! / 1000
        }
        
        var raidSpawnTimestamp = json["raidSpawnMs"] as? Int
        if raidSpawnTimestamp != nil {
            raidSpawnTimestamp = raidSpawnTimestamp! / 1000
        }
        var raidBattleTimestamp = json["raidBattleMs"] as? Int
        if raidBattleTimestamp != nil {
            raidBattleTimestamp = raidBattleTimestamp! / 1000
        }
        var raidEndTimestamp = json["raidEndMs"] as? Int
        if raidEndTimestamp != nil {
            raidEndTimestamp = raidEndTimestamp! / 1000
        }
        let url = json["imageURL"] as? String
        
        self.id = id
        self.lat = lat
        self.lon = lon
        self.enabled = enabled
        self.lastModifiedTimestamp = lastModifiedTimestamp?.toUInt32()
        self.raidSpawnTimestamp = raidSpawnTimestamp?.toUInt32()
        self.raidEndTimestamp = raidEndTimestamp?.toUInt32()
        self.raidBattleTimestamp = raidBattleTimestamp?.toUInt32()
        self.raidLevel = raidLevel?.toUInt8()
        self.raidPokemonId = raidPokemonId?.toUInt16()
        self.guardPokemonId = guardPokemonId?.toUInt16()
        self.availbleSlots = availbleSlots?.toUInt16()
        self.teamId = teamId?.toUInt8()
        self.exRaidEligible = exRaidEligible
        self.inBattle = inBattle
        self.raidPokemonForm = raidPokemonForm?.toUInt8()
        self.raidPokemonMove1 = raidPokemonMove1?.toUInt16()
        self.raidPokemonMove2 = raidPokemonMove2?.toUInt16()
        self.raidPokemonCp = raidPokemonCp?.toUInt16()

        if url != "" {
            self.url = url
        }
        self.updated = UInt32(Date().timeIntervalSince1970)
        
    }
    
    init(fortData: POGOProtos_Map_Fort_FortData) {
        
        self.id = fortData.id
        self.lat = fortData.latitude
        self.lon = fortData.longitude
        self.enabled = fortData.enabled
        self.guardPokemonId = fortData.guardPokemonID.rawValue.toUInt16()
        self.teamId = fortData.ownedByTeam.rawValue.toUInt8()
        self.availbleSlots = UInt16(fortData.gymDisplay.slotsAvailable)
        self.lastModifiedTimestamp = UInt32(fortData.lastModifiedTimestampMs / 1000)
        self.exRaidEligible = fortData.isExRaidEligible
        self.inBattle = fortData.isInBattle
        if fortData.imageURL != "" {
            self.url = fortData.imageURL
        }
        
        if fortData.hasRaidInfo {
            self.raidEndTimestamp = UInt32(fortData.raidInfo.raidEndMs / 1000)
            self.raidSpawnTimestamp = UInt32(fortData.raidInfo.raidSpawnMs / 1000)
            self.raidBattleTimestamp = UInt32(fortData.raidInfo.raidBattleMs / 1000)
            self.raidLevel = UInt8(fortData.raidInfo.raidLevel.rawValue)
            self.raidPokemonId = UInt16(fortData.raidInfo.raidPokemon.pokemonID.rawValue)
            self.raidPokemonMove1 = UInt16(fortData.raidInfo.raidPokemon.move1.rawValue)
            self.raidPokemonMove2 = UInt16(fortData.raidInfo.raidPokemon.move2.rawValue)
            self.raidPokemonForm = UInt8(fortData.raidInfo.raidPokemon.pokemonDisplay.form.rawValue)
            self.raidPokemonCp = UInt16(fortData.raidInfo.raidPokemon.cp)
        }
        
        self.updated = UInt32(Date().timeIntervalSince1970)
        
    }
    
    public func save() throws {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[GYM] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let oldGym: Gym?
        do {
            oldGym = try Gym.getWithId(id: id)
        } catch {
            oldGym = nil
        }
        let mysqlStmt = MySQLStmt(mysql)
        
        if oldGym == nil {
            WebHookController.global.addGymEvent(gym: self)
            WebHookController.global.addGymInfoEvent(gym: self)
            let raidBattleTime = Date(timeIntervalSince1970: Double(raidBattleTimestamp ?? 0))
            let raidEndTime = Date(timeIntervalSince1970: Double(raidEndTimestamp ?? 0))
            let now = Date()
            
            
            if raidBattleTime > now && self.raidLevel ?? 0 != 0 {
                WebHookController.global.addEggEvent(gym: self)
            } else if raidBattleTime < now && raidEndTime > now && self.raidPokemonId ?? 0 != 0 {
                WebHookController.global.addRaidEvent(gym: self)
            }

            
            let sql = """
                INSERT INTO gym (id, lat, lon, name, url, guarding_pokemon_id, last_modified_timestamp, team_id, raid_end_timestamp, raid_spawn_timestamp, raid_battle_timestamp, raid_pokemon_id, enabled, availble_slots, updated, raid_level, ex_raid_eligible, in_battle, raid_pokemon_move_1, raid_pokemon_move_2, raid_pokemon_form, raid_pokemon_cp)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            _ = mysqlStmt.prepare(statement: sql)
            mysqlStmt.bindParam(id)
        } else {
            if oldGym!.name != nil && self.name == nil {
                self.name = oldGym!.name
            }
            if oldGym!.url != nil && self.url == nil {
                self.url = oldGym!.url
            }
            if oldGym!.exRaidEligible != nil && self.exRaidEligible == nil {
                self.exRaidEligible = oldGym!.exRaidEligible
            }
            if oldGym!.inBattle != nil && self.inBattle == nil {
                self.inBattle = oldGym!.inBattle
            }
            if oldGym!.raidPokemonForm != nil && self.raidPokemonForm == nil {
                self.raidPokemonForm = oldGym!.raidPokemonForm
            }
            if oldGym!.raidPokemonMove1 != nil && self.raidPokemonMove1 == nil {
                self.raidPokemonMove1 = oldGym!.raidPokemonMove1
                self.raidPokemonMove2 = oldGym!.raidPokemonMove2
            }
            if oldGym!.raidPokemonCp != nil && self.raidPokemonCp == nil {
                self.raidPokemonCp = oldGym!.raidPokemonCp
            }
            
            if oldGym!.availbleSlots != self.availbleSlots || oldGym!.teamId != self.teamId {
                WebHookController.global.addGymInfoEvent(gym: self)
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
                } else if raidBattleTime < now && raidEndTime > now && self.raidPokemonId ?? 0 != 0 {
                    WebHookController.global.addRaidEvent(gym: self)
                }
                
            }
            
            let sql = """
                UPDATE gym
                SET lat = ?, lon = ? , name = ? , url = ? , guarding_pokemon_id = ? , last_modified_timestamp = ? , team_id = ? , raid_end_timestamp = ? , raid_spawn_timestamp = ? , raid_battle_timestamp = ? , raid_pokemon_id = ? , enabled = ? , availble_slots = ? , updated = ? , raid_level = ?, ex_raid_eligible = ?, in_battle = ?, raid_pokemon_move_1 = ?, raid_pokemon_move_2 = ?, raid_pokemon_form = ?, raid_pokemon_cp = ?
                WHERE id = ?
            """
            _ = mysqlStmt.prepare(statement: sql)
        }
        
        mysqlStmt.bindParam(lat)
        mysqlStmt.bindParam(lon)
        mysqlStmt.bindParam(name)
        mysqlStmt.bindParam(url)
        mysqlStmt.bindParam(guardPokemonId)
        mysqlStmt.bindParam(lastModifiedTimestamp)
        mysqlStmt.bindParam(teamId)
        mysqlStmt.bindParam(raidEndTimestamp)
        mysqlStmt.bindParam(raidSpawnTimestamp)
        mysqlStmt.bindParam(raidBattleTimestamp)
        mysqlStmt.bindParam(raidPokemonId)
        mysqlStmt.bindParam(enabled)
        mysqlStmt.bindParam(availbleSlots)
        mysqlStmt.bindParam(updated)
        mysqlStmt.bindParam(raidLevel)
        mysqlStmt.bindParam(exRaidEligible)
        mysqlStmt.bindParam(inBattle)
        mysqlStmt.bindParam(raidPokemonMove1)
        mysqlStmt.bindParam(raidPokemonMove2)
        mysqlStmt.bindParam(raidPokemonForm)
        mysqlStmt.bindParam(raidPokemonCp)

        if oldGym != nil {
            mysqlStmt.bindParam(id)
        }
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[GYM] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
    
    public static func getAll(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double, updated: UInt32, raidsOnly: Bool, showRaids: Bool) throws -> [Gym] {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[GYM] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        var sql = """
            SELECT id, lat, lon, name, url, guarding_pokemon_id, last_modified_timestamp, team_id, raid_end_timestamp, raid_spawn_timestamp, raid_battle_timestamp, raid_pokemon_id, enabled, availble_slots, updated, raid_level, ex_raid_eligible, in_battle, raid_pokemon_move_1, raid_pokemon_move_2, raid_pokemon_form, raid_pokemon_cp
            FROM gym
            WHERE lat >= ? AND lat <= ? AND lon >= ? AND lon <= ? AND updated > ?
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
            let availbleSlots = result[13] as? UInt16
            let updated = result[14] as! UInt32
            let raidLevel = result[15] as? UInt8
            let exRaidEligible = (result[16] as? UInt8)?.toBool()
            let inBattle = (result[17] as? UInt8)?.toBool()
            let raidPokemonMove1 = result[18] as? UInt16
            let raidPokemonMove2 = result[19] as? UInt16
            let raidPokemonForm = result[20] as? UInt8
            let raidPokemonCp = result[21] as? UInt16

            gyms.append(Gym(id: id, lat: lat, lon: lon, name: name, url: url, guardPokemonId: guardPokemonId, enabled: enabled, lastModifiedTimestamp: lastModifiedTimestamp, teamId: teamId, raidEndTimestamp: raidEndTimestamp, raidSpawnTimestamp: raidSpawnTimestamp, raidBattleTimestamp: raidBattleTimestamp, raidPokemonId: raidPokemonId, raidLevel: raidLevel, availbleSlots: availbleSlots, updated: updated, exRaidEligible: exRaidEligible, inBattle: inBattle, raidPokemonMove1: raidPokemonMove1, raidPokemonMove2: raidPokemonMove2, raidPokemonForm: raidPokemonForm, raidPokemonCp: raidPokemonCp))
        }
        return gyms
        
    }

    public static func getWithId(id: String) throws -> Gym? {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[GYM] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT id, lat, lon, name, url, guarding_pokemon_id, last_modified_timestamp, team_id, raid_end_timestamp, raid_spawn_timestamp, raid_battle_timestamp, raid_pokemon_id, enabled, availble_slots, updated, raid_level, ex_raid_eligible, in_battle, raid_pokemon_move_1, raid_pokemon_move_2, raid_pokemon_form, raid_pokemon_cp
            FROM gym
            WHERE id = ?
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
        let availbleSlots = result[13] as? UInt16
        let updated = result[14] as! UInt32
        let raidLevel = result[15] as? UInt8
        let exRaidEligible = (result[16] as? UInt8)?.toBool()
        let inBattle = (result[17] as? UInt8)?.toBool()
        let raidPokemonMove1 = result[18] as? UInt16
        let raidPokemonMove2 = result[19] as? UInt16
        let raidPokemonForm = result[20] as? UInt8
        let raidPokemonCp = result[21] as? UInt16
        
        return Gym(id: id, lat: lat, lon: lon, name: name, url: url, guardPokemonId: guardPokemonId, enabled: enabled, lastModifiedTimestamp: lastModifiedTimestamp, teamId: teamId, raidEndTimestamp: raidEndTimestamp, raidSpawnTimestamp: raidSpawnTimestamp, raidBattleTimestamp: raidBattleTimestamp, raidPokemonId: raidPokemonId, raidLevel: raidLevel, availbleSlots: availbleSlots, updated: updated, exRaidEligible: exRaidEligible, inBattle: inBattle, raidPokemonMove1: raidPokemonMove1, raidPokemonMove2: raidPokemonMove2, raidPokemonForm: raidPokemonForm, raidPokemonCp: raidPokemonCp)
    }
}
