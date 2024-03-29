//
//  Date.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 18.07.20.
//

import Foundation

public extension Date {

    func toString(_ format: String = "yyyy-MM-dd") -> String? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        formatter.timeZone = Localizer.global.timeZone
        return formatter.string(from: self)
    }

    var timestampMs: UInt64 {
        UInt64(self.timeIntervalSince1970 * 1000)
    }

}
