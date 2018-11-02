//
//  UInt32.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 02.11.18.
//

import Foundation

extension UInt32 {
    
    func secondsToHoursMinutesSeconds() -> (hours: UInt8, minutes: UInt8, seconds: UInt8) {
        return (UInt8(self / 3600), UInt8((self % 3600) / 60), UInt8((self % 3600) % 60))
    }
    
}
