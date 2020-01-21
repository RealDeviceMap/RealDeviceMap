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

class Coord: JSONConvertibleObject, Hashable {

    var lat: Double
    var lon: Double

    public var hashValue: Int {
        return "\(lat.rounded(toStringWithDecimals: 10));\(lon.rounded(toStringWithDecimals: 10))".hashValue
    }

    init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
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
