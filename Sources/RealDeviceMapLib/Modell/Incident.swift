//
// Created by Fabio on 23.03.22.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable function_body_length cyclomatic_complexity force_cast

import Foundation
import PerfectLib
import PerfectMySQL
import POGOProtos

public class Incident: JSONConvertibleObject, WebHookEvent, Hashable {

    var id: String
    var pokestopId: String
    var start: UInt32
    var expiration: UInt32
    var displayType: UInt16
    var style: UInt16
    var character: UInt16
    var updated: UInt32

    public static var cache: MemoryCache<Incident>?

    init(now: UInt32, pokestopId: String, pokestopDisplay: PokestopIncidentDisplayProto) {
        self.pokestopId = pokestopId
        self.id = pokestopDisplay.incidentID
        self.start = UInt32(pokestopDisplay.incidentStartMs / 1000)
        self.expiration = UInt32(pokestopDisplay.incidentExpirationMs / 1000)
        self.displayType = UInt16(pokestopDisplay.incidentDisplayType.rawValue)
        self.style = UInt16(pokestopDisplay.characterDisplay.style.rawValue)
        self.character = UInt16(pokestopDisplay.characterDisplay.character.rawValue)
        self.updated = now
    }

    init(id: String, pokestopId: String, start: UInt32, expiration: UInt32, displayType: UInt16, style: UInt16,
         character: UInt16, updated: UInt32) {
        self.id = id
        self.pokestopId = pokestopId
        self.start = start
        self.expiration = expiration
        self.displayType = displayType
        self.style = style
        self.character = character
        self.updated = updated
    }

    public override func getJSONValues() -> [String: Any] {
        [
            "id": id,
            "pokestop_id": pokestopId as Any,
            "start": start,
            "incident_expire_timestamp": expiration, // deprecated, remove old key in the future
            "expiration": expiration,
            "display_type": displayType as Any,
            "style": style as Any,
            "grunt_type": character as Any, // deprecated, remove old key in the future
            "character": character as Any,
            "updated": updated
        ]
    }

    func getWebhookValues(type: String) -> [String: Any] {
        fatalError("getWebhookValues(type:) has not been implemented, use getWebhookValues(pokestop:) instead")
    }

    func getWebhookValues(type: String, pokestop: Pokestop) -> [String: Any] {
        let message: [String: Any] = [
            "id": id,
            "pokestop_id": pokestopId as Any,
            "latitude": pokestop.lat,
            "longitude": pokestop.lon,
            "pokestop_name": pokestop.name ?? "Unknown",
            "url": pokestop.url ?? "",
            "enabled": pokestop.enabled ?? true,
            "start": start,
            "incident_expire_timestamp": expiration, // deprecated, remove old key in the future
            "expiration": expiration,
            "display_type": displayType as Any,
            "style": style as Any,
            "grunt_type": character as Any, // deprecated, remove old key in the future
            "character": character as Any,
            "updated": updated
        ]
        return [
            "type": "invasion",
            "message": message
        ]

    }

    func save(mysql: MySQL?=nil) throws {
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[INCIDENT] Failed to connect to database.")
            throw DBController.DBError()
        }
        let oldIncident: Incident?
        do {
            oldIncident = try Incident.getWithId(mysql: mysql, id: id)
        } catch {
            oldIncident = nil
        }
        let mysqlStmt = MySQLStmt(mysql)

        let now = UInt32(Date().timeIntervalSince1970)

        if oldIncident == nil {
            let sql = """
                      INSERT INTO incident (
                      id, pokestop_id, start, expiration, display_type, style, `character`, updated
                      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                      """
            self.updated = now
            _ = mysqlStmt.prepare(statement: sql)
            mysqlStmt.bindParam(id)
            mysqlStmt.bindParam(pokestopId)
        } else {
            guard Incident.shouldUpdate(old: oldIncident!, new: self) else {
                return
            }
            let sql = """
                      UPDATE incident
                      SET start = ?, expiration = ?, display_type =?, style = ?, `character` = ?, updated = ?
                      WHERE id = ?
                      """
            self.updated = now
            _ = mysqlStmt.prepare(statement: sql)
        }
        mysqlStmt.bindParam(start)
        mysqlStmt.bindParam(expiration)
        mysqlStmt.bindParam(displayType)
        mysqlStmt.bindParam(style)
        mysqlStmt.bindParam(character)
        mysqlStmt.bindParam(updated)
        if oldIncident != nil {
            mysqlStmt.bindParam(id)
        }

        guard mysqlStmt.execute() else {
            if mysqlStmt.errorCode() == 1062 {
                Log.debug(message: "[INCIDENT] Duplicated key. Skipping...")
            } else {
                Log.error(message: "[INCIDENT] Failed to execute query 'save'. (\(mysqlStmt.errorMessage()))")
            }
            throw DBController.DBError()
        }

        Incident.cache?.set(id: self.id, value: self)

        if oldIncident == nil {
            let pokestop = try? Pokestop.getWithId(id: self.pokestopId)
            if pokestop != nil {
                WebHookController.global.addInvasionEvent(pokestop: pokestop!, incident: self)
            }
        } else {
            print("[TMP] incident is updated")
            if oldIncident!.expiration < self.expiration || oldIncident!.character != self.character {
                let pokestop = try? Pokestop.getWithId(id: self.pokestopId)
                if pokestop != nil {
                    WebHookController.global.addInvasionEvent(pokestop: pokestop!, incident: self)
                }
            }
        }
    }

    public static func getWithId(mysql: MySQL?=nil, id: String, withExpired: Bool = false) throws -> Incident? {
        if let cached = cache?.get(id: id) {
            return cached
        }

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[INCIDENT] Failed to connect to database.")
            throw DBController.DBError()
        }

        let expiredSQL = withExpired ? "" : "AND expiration >= UNIX_TIMESTAMP()"

        let sql = """
                  SELECT id, pokestop_id, start, expiration, display_type, style, `character`, updated
                  FROM incident
                  WHERE id = ? \(expiredSQL)
                  """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(id)

        guard mysqlStmt.execute() else {
            Log.error(message: "[INCIDENT] Failed to execute query 'getWithId'. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }

        let result = results.next()!

        let incidentId = result[0] as! String
        let pokestopId = result[1] as! String
        let start = result[2] as! UInt32
        let expiration = result[3] as! UInt32
        let displayType = result[4] as! UInt16
        let style = result[5] as! UInt16
        let character = result[6] as! UInt16
        let incidentUpdated = result[7] as! UInt32
        let incident = Incident(id: incidentId, pokestopId: pokestopId, start: start, expiration: expiration,
            displayType: displayType, style: style, character: character, updated: incidentUpdated)
        cache?.set(id: incident.id, value: incident)
        return incident
    }

    public static func shouldUpdate(old: Incident, new: Incident) -> Bool {
        old.character != new.character || old.expiration != new.expiration
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Incident, rhs: Incident) -> Bool {
        lhs.id == rhs.id
    }
}
