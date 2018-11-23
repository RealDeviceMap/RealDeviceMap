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
    
}
