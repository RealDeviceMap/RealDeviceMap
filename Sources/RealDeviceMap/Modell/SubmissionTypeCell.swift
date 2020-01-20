//
//  SubmissionTypeCell.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 19.11.19.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast

import Foundation
import PerfectLib
import PerfectMySQL
import S2Geometry
import Turf

class SubmissionTypeCell: JSONConvertibleObject {

    var id: UInt64
    let level: UInt8 = 14
    var count: UInt8
    var countPokestops: UInt8
    var countGyms: UInt8

    override func getJSONValues() -> [String: Any] {

        let s2cell = S2Cell(cellId: S2CellId(uid: id))
        var polygon =  [[Double]]()
        for i in 0...3 {
            let coord = S2LatLng(point: s2cell.getVertex(i)).coord
            polygon.append([
                coord.latitude,
                coord.longitude
            ])
        }

        return [
            "id": id.description,
            "level": level,
            "count": count,
            "count_pokestops": countPokestops,
            "count_gyms": countGyms,
            "polygon": polygon
        ]
    }

    init(id: UInt64, countPokestops: UInt8, countGyms: UInt8) {
        self.id = id
        self.countPokestops = countPokestops
        self.countGyms = countGyms
        self.count = countPokestops + countGyms
    }

    public static func getAll(mysql: MySQL?=nil, minLat: Double, maxLat: Double,
                              minLon: Double, maxLon: Double) throws -> [SubmissionTypeCell] {

        let minLatReal = minLat - 0.01
        let maxLatReal = maxLat + 0.01
        let minLonReal = minLon - 0.01
        let maxLonReal = maxLon + 0.01

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[CELL] Failed to connect to database.")
            throw DBController.DBError()
        }

        let allStops = try Pokestop.getAll(
            mysql: mysql,
            minLat: minLatReal - 0.02,
            maxLat: maxLatReal + 0.02,
            minLon: minLonReal - 0.02,
            maxLon: maxLonReal + 0.02,
            updated: 0,
            questsOnly: false,
            showQuests: false,
            showLures: false,
            showInvasions: false,
            questFilterExclude: nil,
            pokestopFilterExclude: nil
        ).filter({ (pokestop) -> Bool in
            return pokestop.sponsorId == nil || pokestop.sponsorId == 0
        })
        let allGyms = try Gym.getAll(
            mysql: mysql,
            minLat: minLatReal - 0.02,
            maxLat: maxLatReal + 0.02,
            minLon: minLonReal - 0.02,
            maxLon: maxLonReal + 0.02,
            updated: 0,
            raidsOnly: false,
            showRaids: false,
            raidFilterExclude: nil,
            gymFilterExclude: nil
        ).filter({ (gym) -> Bool in
            return gym.sponsorId == nil || gym.sponsorId == 0
        })
        let allStopCoods = allStops.map { (pokestop) -> CLLocationCoordinate2D in
            return CLLocationCoordinate2D(latitude: pokestop.lat, longitude: pokestop.lon)
        }
        let allGymCoods = allGyms.map { (gym) -> CLLocationCoordinate2D in
            return CLLocationCoordinate2D(latitude: gym.lat, longitude: gym.lon)
        }

        let regionCoverer = S2RegionCoverer()
        regionCoverer.maxCells = 1000
        regionCoverer.minLevel = 14
        regionCoverer.maxLevel = 14
        let region = S2LatLngRect(
            lo: S2LatLng(coord: CLLocationCoordinate2D(latitude: minLatReal, longitude: minLonReal)),
            hi: S2LatLng(coord: CLLocationCoordinate2D(latitude: maxLatReal, longitude: maxLonReal))
        )

        var indexedCells = [UInt64: SubmissionTypeCell]()
        for cell in regionCoverer.getCovering(region: region) {
            indexedCells[cell.uid] = SubmissionTypeCell(id: cell.uid, countPokestops: 0, countGyms: 0)
        }

        for coord in allGymCoods {
            let level1Cell = S2CellId(latlng: S2LatLng(coord: coord))
            let level14Cell = level1Cell.parent(level: 14)
            if let cell = indexedCells[level14Cell.uid] {
                cell.countGyms += 1
                cell.count += 1
            }
        }

        for coord in allStopCoods {
            let level1Cell = S2CellId(latlng: S2LatLng(coord: coord))
            let level14Cell = level1Cell.parent(level: 14)
            if let cell = indexedCells[level14Cell.uid] {
                cell.countPokestops += 1
                cell.count += 1
            }
        }

        return Array(indexedCells.values)

    }

}
