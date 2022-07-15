//
//  GymDefender.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 18.09.18 & SkOODaT.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast
import Foundation
import PerfectLib
import PerfectMySQL
import POGOProtos

public class GymDefender: JSONConvertibleObject {

    class ParsingError: Error {}

    public override func getJSONValues() -> [String: Any] {
        return [
            "id": id,
            "fortID": fortID,
            "pokemonID": pokemonID,
            "cp": cp as Any,
            "atk_iv": atkIv as Any,
            "def_iv": defIv as Any,
            "sta_iv": staIv as Any,
            "updated": updated ?? 1
        ]
    }

    var id: UInt64
    var fortID: String
    var pokemonID: UInt16
    var cp: UInt16?
    var atkIv: UInt8?
    var defIv: UInt8?
    var staIv: UInt8?
    var updated: UInt32?

    var hasChanges = false

    init(id: UInt64, fortID: String, pokemonID: UInt16, cp: UInt16?,
         atkIv: UInt8?, defIv: UInt8?, staIv: UInt8?, updated: UInt32?) {
        self.id = id
        self.fortID = fortID
        self.pokemonID = pokemonID
        self.cp = cp
        self.atkIv = atkIv
        self.defIv = defIv
        self.staIv = staIv
        self.updated = updated
    }

    init(fortID: String, gymDefInfo: GymDefenderProto) {
        self.id = gymDefInfo.motivatedPokemon.pokemon.id
        self.fortID = fortID
        self.pokemonID = gymDefInfo.motivatedPokemon.pokemon.pokemonID.rawValue.toUInt16()
        self.cp = gymDefInfo.motivatedPokemon.pokemon.cp.toUInt16()
        self.atkIv = gymDefInfo.motivatedPokemon.pokemon.individualAttack.toUInt8()
        self.defIv = gymDefInfo.motivatedPokemon.pokemon.individualDefense.toUInt8()
        self.staIv = gymDefInfo.motivatedPokemon.pokemon.individualStamina.toUInt8()

        //move1
        //move2
        //battles_defended
        //Log.info(message: "[GYMDEFENDER] gymDefInfo. (\(gymDefInfo))")
    }

    public func save(mysql: MySQL?=nil) throws {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[GYMDEFENDER] Failed to connect to database.")
            throw DBController.DBError()
        }

        let oldGymDefender: GymDefender?
        do {
            oldGymDefender = try GymDefender.getWithId(mysql: mysql, id: id)
        } catch {
            oldGymDefender = nil
        }
        let mysqlStmt = MySQLStmt(mysql)

        updated = UInt32(Date().timeIntervalSince1970)

        let now = UInt32(Date().timeIntervalSince1970)
        if oldGymDefender == nil {
            let sql = """
                INSERT INTO gymdefender (
                    id, fortID, pokemonID, cp, atk_iv, def_iv, sta_iv, updated)
                VALUES (
                    ?, ?, ?, ?, ?, ?, ?, UNIX_TIMESTAMP()
                )
            """
            self.updated = now
            _ = mysqlStmt.prepare(statement: sql)
            mysqlStmt.bindParam(id)
        } else {

            guard GymDefender.shouldUpdate(old: oldGymDefender!, new: self) else {
                return
            }
            let sqlDel = """
                DELETE FROM gymdefender
                WHERE fortID = ?
            """
            let sql = """
                UPDATE gymdefender
                SET fortID = ?, pokemonID = ?, cp = ?, atk_iv = ?, def_iv = ?, sta_iv = ?,
                updated = UNIX_TIMESTAMP()
                WHERE id = ?
            """
            self.updated = now
            _ = mysqlStmt.prepare(statement: sqlDel)
            _ = mysqlStmt.prepare(statement: sql)
        }

        mysqlStmt.bindParam(fortID)
        mysqlStmt.bindParam(pokemonID)
        mysqlStmt.bindParam(cp)
        mysqlStmt.bindParam(atkIv)
        mysqlStmt.bindParam(defIv)
        mysqlStmt.bindParam(staIv)

        if oldGymDefender != nil {
            mysqlStmt.bindParam(id)
        }

        guard mysqlStmt.execute() else {
            if mysqlStmt.errorCode() == 1062 {
                Log.debug(message: "[GYMDEFENDER] Duplicated key. Skipping...")
            } else {
                Log.error(message: "[GYMDEFENDER] Failed to execute query 'save'. (\(mysqlStmt.errorMessage()))")
            }
            throw DBController.DBError()
        }
    }

    public static func getWithId(mysql: MySQL?=nil, id: UInt64) throws -> GymDefender? {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[GYMDEFENDER] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
            SELECT id, fortID, pokemonID, cp, atk_iv, def_iv, sta_iv, updated
            FROM gymdefender
            WHERE id = ?
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(id)

        guard mysqlStmt.execute() else {
            Log.error(message: "[GYMDEFENDER] Failed to execute query 'getWithId'. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }

        let result = results.next()!
        let id = result[0] as! UInt64
        let fortID = result[1] as! String
        let pokemonID = result[2] as! UInt16
        let cp = result[3] as! UInt16?
        let atkIv = result[4] as! UInt8?
        let defIv = result[5] as! UInt8?
        let staIv = result[6] as! UInt8?
        let updated = result[7] as! UInt32

        let gymdefender = GymDefender(
            id: id, fortID: fortID, pokemonID: pokemonID, cp: cp,
            atkIv: atkIv, defIv: defIv, staIv: staIv, updated: updated)
        return gymdefender
    }

    public static func shouldUpdate(old: GymDefender, new: GymDefender) -> Bool {
        if old.hasChanges {
            old.hasChanges = false
            return true
        }
        return
            new.fortID != old.fortID ||
            new.pokemonID != old.pokemonID ||
            //new.cp != old.cp ||
            new.atkIv != old.atkIv ||
            new.defIv != old.defIv ||
            new.staIv != old.staIv
    }

}
