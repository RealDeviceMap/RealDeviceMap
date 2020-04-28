//
//  S2LatLng.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 23.11.18.
//

import S2Geometry
import Turf

extension S2LatLng {

    init(coord: CLLocationCoordinate2D) {
        self.init(lat: S1Angle(degrees: coord.latitude), lng: S1Angle(degrees: coord.longitude))
    }

    var coord: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: lat.degrees, longitude: lng.degrees)
    }

    func getLoadedS2CellIds() -> [S2CellId] {
        let radius: CLLocationDistance
        if lat.degrees <= 39 {
            radius = 715
        } else if lat.degrees >= 69 {
            radius = 330
        } else {
            radius = -13 * lat.degrees + 1225
        }
        let radians = radius / 6378137
        let centerNormalizedPoint = self.normalized.point
        let circle = S2Cap(axis: centerNormalizedPoint, height: (radians*radians)/2)
        let coverer = S2RegionCoverer()
        coverer.maxCells = 100
        coverer.maxLevel = 15
        coverer.minLevel = 15
        return coverer.getCovering(region: circle)
    }
}
