//
//  SubmissionPlacementCell.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.11.19.
//

import Foundation
import PerfectLib
import PerfectMySQL
import S2Geometry
import Turf

class SubmissionPlacementCell: JSONConvertibleObject {

    class Ring: JSONConvertibleObject {
        
        var id: String
        var lat: Double
        var lon: Double
        var radius: UInt16
        
        override func getJSONValues() -> [String : Any] {
            return [
                "id": id,
                "lat": lat,
                "lon": lon,
                "radius": radius
            ]
        }
        
        init(lat: Double, lon: Double, radius: UInt16) {
            self.id = "\(lat)-\(lon)-\(radius)"
            self.lat = lat
            self.lon = lon
            self.radius = radius
        }
    }
    
    var id: UInt64
    let level: UInt8 = 17
    var blocked: Bool
    
    override func getJSONValues() -> [String : Any] {
        
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
            "blocked": blocked,
            "polygon": polygon
        ]
    }
    
    init(id: UInt64, blocked: Bool) {
        self.id = id
        self.blocked = blocked
    }

    public static func getAll(mysql: MySQL?=nil, minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) throws -> (cells: [SubmissionPlacementCell], rings: [Ring]) {
        
        let minLatReal = minLat - 0.001
        let maxLatReal = maxLat + 0.001
        let minLonReal = minLon - 0.001
        let maxLonReal = maxLon + 0.001
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[CELL] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let allStops = try Pokestop.getAll(
            mysql: mysql,
            minLat: minLatReal - 0.002,
            maxLat: maxLatReal + 0.002,
            minLon: minLonReal - 0.002,
            maxLon: maxLonReal + 0.002,
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
            minLat: minLatReal - 0.002,
            maxLat: maxLatReal + 0.002,
            minLon: minLonReal - 0.002,
            maxLon: maxLonReal + 0.002,
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
        let allCoords = allStopCoods + allGymCoods
        
        let regionCoverer = S2RegionCoverer()
        regionCoverer.maxCells = 1000
        regionCoverer.minLevel = 17
        regionCoverer.maxLevel = 17
        let region = S2LatLngRect(
            lo: S2LatLng(coord: CLLocationCoordinate2D(latitude: minLatReal, longitude: minLonReal)),
            hi: S2LatLng(coord: CLLocationCoordinate2D(latitude: maxLatReal, longitude: maxLonReal))
        )
        
        var indexedCells = [UInt64: SubmissionPlacementCell]()
        for cell in regionCoverer.getCovering(region: region) {
            indexedCells[cell.uid] = SubmissionPlacementCell(id: cell.uid, blocked: false)
        }
        
        for coord in allCoords {
            let level1Cell = S2CellId(latlng: S2LatLng(coord: coord))
            let level17Cell = level1Cell.parent(level: 17)
            if let cell = indexedCells[level17Cell.uid] {
                cell.blocked = true
            }
        }

        let rings = (allGymCoods + allStopCoods).map { (coord) -> Ring in
            return Ring(lat: coord.latitude, lon: coord.longitude, radius: 20)
        }
        
        return (Array(indexedCells.values), rings)
        
    }

}
