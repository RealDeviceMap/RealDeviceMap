//
//  UInt64.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 05.10.18.
//

import Foundation

extension UInt64 {
    
    func toHexString() -> String? {
        return String(format:"%02X", self)
    }
    
}
