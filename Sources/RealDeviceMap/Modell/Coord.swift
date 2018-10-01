//
//  Coord.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 29.09.18.
//

import Foundation
import PerfectLib

class Coord: JSONConvertibleObject {
        
    var lat: Double
    var lon: Double
    
    init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }
    
    override func getJSONValues() -> [String : Any] {
        return [
            "lat": lat,
            "lon": lon
        ]
    }

}
