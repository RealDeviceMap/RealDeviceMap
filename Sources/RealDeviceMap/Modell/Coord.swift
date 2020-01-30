//
//  Coord.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 29.09.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast

import Foundation
import PerfectLib
import Turf

class Coord: JSONConvertibleObject, Hashable {

    var lat: Double
    var lon: Double

    var cLLocationCoordinate2D: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    public var hashValue: Int {
        return "\(lat.rounded(toStringWithDecimals: 10));\(lon.rounded(toStringWithDecimals: 10))".hashValue
    }

    init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }

    // swiftlint:disable:next identifier_name
    func distance(to: Coord) -> Double {
        return self.cLLocationCoordinate2D.distance(to: to.cLLocationCoordinate2D)
    }

    override func getJSONValues() -> [String: Any] {
        return [
            "lat": lat,
            "lon": lon
        ]
    }

    static func == (lhs: Coord, rhs: Coord) -> Bool {
        return lhs.lat == rhs.lat && lhs.lon == rhs.lon
    }

}
