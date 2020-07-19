//
//  Date.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.07.20.
//

import Foundation

public extension Date {

    func toString(_ format: String = "yyyy-MM-dd") -> String? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: self)
    }

}
