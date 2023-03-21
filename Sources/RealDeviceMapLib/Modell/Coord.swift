//
//  Coord.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 29.09.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast

import Foundation
import PerfectLib
import Turf

public class Coord: JSONConvertibleObject, Hashable, Codable {

    var lat: Double
    var lon: Double

    var locationCoordinate2D: LocationCoordinate2D {
        return LocationCoordinate2D(latitude: lat, longitude: lon)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine("\(lat.rounded(toStringWithDecimals: 10));\(lon.rounded(toStringWithDecimals: 10))".hashValue)
    }

    init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }

    // swiftlint:disable:next identifier_name
    func distance(to: Coord) -> Double {
        return self.locationCoordinate2D.distance(to: to.locationCoordinate2D)
    }

    public override func getJSONValues() -> [String: Any] {
        return [
            "lat": lat,
            "lon": lon
        ]
    }

    public static func == (lhs: Coord, rhs: Coord) -> Bool {
        return lhs.lat == rhs.lat && lhs.lon == rhs.lon
    }

    // this is required for proper reading of data from some koji fields, not all have lat/lon labeled
    public required init(from decoder: Decoder) throws
    {
        var values = try decoder.unkeyedContainer()
        self.lat = try values.decode(Double.self)
        self.lon = try values.decode(Double.self)
    }
}
