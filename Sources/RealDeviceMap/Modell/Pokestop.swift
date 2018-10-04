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

class Pokestop: JSONConvertibleObject, WebHookEvent {
    
    class ParsingError: Error {}
    
    override func getJSONValues() -> [String : Any] {
        return [
            "id":id,
            "lat":lat,
            "lon":lon,
            "name":name as Any,
            "url":url as Any,
            "lure_expire_timestamp":lureExpireTimestamp as Any,
            "last_modified_timestamp":lastModifiedTimestamp as Any,
            "enabled":enabled as Any,
            "updated": updated
        ]
    }
    
    func getWebhookValues() -> [String : Any] {
        return [
            "pokestop_id":id,
            "latitude":lat,
            "longitude":lon,
            "name":name as Any,
            "url":url as Any,
            "lure_expiration":lureExpireTimestamp as Any,
            "last_modified":lastModifiedTimestamp as Any,
            "enabled":enabled as Any,
            "updated": updated
        ]
    }
    
    var id: String
    var lat: Double
    var lon: Double
    
    var enabled: Bool?
    var lureExpireTimestamp: UInt32?
    var lastModifiedTimestamp: UInt32?
    var name: String?
    var url: String?
    var updated: UInt32
    
    init(id: String, lat: Double, lon: Double, name: String?, url: String?, enabled: Bool?, lureExpireTimestamp: UInt32?, lastModifiedTimestamp: UInt32?, updated: UInt32) {
        self.id = id
        self.lat = lat
        self.lon = lon
        self.name = name
        self.url = url
        self.enabled = enabled
        self.lureExpireTimestamp = lureExpireTimestamp
        self.lastModifiedTimestamp = lastModifiedTimestamp
        self.updated = updated
    }
    
    init(json: [String: Any]) throws {
        
        guard
            let id = json["pokestop_id"] as? String,
            let lat = json["latitude"] as? Double,
            let lon = json["longitude"] as? Double
        else {
            throw ParsingError()
        }
        let enabled = json["enabled"] as? Bool
        var lastModifiedTimestamp = json["last_modified"] as? Int
        var lureExpireTimestamp = json["lure_expiration"] as? Int
        let url = json["imageURL"] as? String
        
        if lastModifiedTimestamp != nil {
            lastModifiedTimestamp = lastModifiedTimestamp! / 1000
        }
        if lureExpireTimestamp != nil {
            lureExpireTimestamp = lureExpireTimestamp! / 1000
        }
        
        self.id = id
        self.lat = lat
        self.lon = lon
        self.enabled = enabled
        self.lastModifiedTimestamp = lastModifiedTimestamp?.toUInt32()
        self.lureExpireTimestamp = lureExpireTimestamp?.toUInt32()
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
        self.lureExpireTimestamp = UInt32(fortData.lureInfo.lureExpiresTimestampMs / 1000)
        self.lastModifiedTimestamp = UInt32(fortData.lastModifiedTimestampMs / 1000)
        if fortData.imageURL != "" {
            self.url = fortData.imageURL
        }
        
        self.updated = UInt32(Date().timeIntervalSince1970)
        
    }
    
    public func save() throws {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[POKESTOP] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let oldPokestop: Pokestop?
        do {
            oldPokestop = try Pokestop.getWithId(id: id)
        } catch {
            oldPokestop = nil
        }
        let mysqlStmt = MySQLStmt(mysql)
        
        if oldPokestop == nil {
            WebHookController.global.addPokestopEvent(pokestop: self)
            let sql = """
                INSERT INTO pokestop (id, lat, lon, name, url, enabled, lure_expire_timestamp, last_modified_timestamp, updated)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            _ = mysqlStmt.prepare(statement: sql)
            mysqlStmt.bindParam(id)
        } else {
            if oldPokestop!.name != nil && self.name == nil {
                self.name = oldPokestop!.name
            }
            if oldPokestop!.url != nil && self.url == nil {
                self.url = oldPokestop!.url
            }
            
            if oldPokestop!.lureExpireTimestamp ?? 0 < self.lureExpireTimestamp ?? 0 {
                WebHookController.global.addLureEvent(pokestop: self)
            }
            
            let sql = """
                UPDATE pokestop
                SET lat = ? , lon = ? , name = ? , url = ? , enabled = ? , lure_expire_timestamp = ? , last_modified_timestamp = ? , updated = ?
                WHERE id = ?
            """
            _ = mysqlStmt.prepare(statement: sql)
        }
        
        mysqlStmt.bindParam(lat)
        mysqlStmt.bindParam(lon)
        mysqlStmt.bindParam(name)
        mysqlStmt.bindParam(url)
        mysqlStmt.bindParam(enabled)
        mysqlStmt.bindParam(lureExpireTimestamp)
        mysqlStmt.bindParam(lastModifiedTimestamp)
        mysqlStmt.bindParam(updated)
        
        if oldPokestop != nil {
            mysqlStmt.bindParam(id)
        }
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }

    public static func getAll(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double, updated: UInt32) throws -> [Pokestop] {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[POKESTOP] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT id, lat, lon, name, url, enabled, lure_expire_timestamp, last_modified_timestamp, updated
            FROM pokestop
            WHERE lat >= ? AND lat <= ? AND lon >= ? AND lon <= ? AND updated > ?
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(minLat)
        mysqlStmt.bindParam(maxLat)
        mysqlStmt.bindParam(minLon)
        mysqlStmt.bindParam(maxLon)
        mysqlStmt.bindParam(updated)
        
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

            pokestops.append(Pokestop(id: id, lat: lat, lon: lon, name: name, url: url, enabled: enabled, lureExpireTimestamp: lureExpireTimestamp, lastModifiedTimestamp: lastModifiedTimestamp, updated: updated))
        }
        return pokestops
        
    }

    public static func getWithId(id: String) throws -> Pokestop? {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[POKESTOP] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT id, lat, lon, name, url, enabled, lure_expire_timestamp, last_modified_timestamp, updated
            FROM pokestop
            WHERE id = ?
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
        
        return Pokestop(id: id, lat: lat, lon: lon, name: name, url: url, enabled: enabled, lureExpireTimestamp: lureExpireTimestamp, lastModifiedTimestamp: lastModifiedTimestamp, updated: updated)
    
    }

}
