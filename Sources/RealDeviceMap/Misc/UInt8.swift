//
//  UInt8.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 19.09.18.
//

import Foundation

extension UInt8 {
    func toBool() -> Bool {
        if self == 0 {
            return false
        } else {
            return true
        }
    }
}
