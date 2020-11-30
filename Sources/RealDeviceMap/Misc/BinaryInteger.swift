//
//  BinaryInteger.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 14.01.20.
//

import Foundation

public extension BinaryInteger {

    func toUInt64() -> UInt64 {
        return UInt64(self)
    }
    func toUInt32() -> UInt32 {
        return UInt32(self)
    }
    func toUInt16() -> UInt16 {
        return UInt16(self)
    }
    func toUInt8() -> UInt8 {
        return UInt8(self)
    }
    func toInt32() -> Int32 {
        return Int32(self)
    }
    func toInt16() -> Int16 {
        return Int16(self)
    }
    func toInt8() -> Int8 {
        return Int8(self)
    }
    func toString() -> String {
        return self.description
    }
    func toUInt8Checked() -> UInt8? {
        if self >= UInt8.min && self <= UInt8.max {
            return UInt8(self)
        }
        return nil
    }
    func toBool() -> Bool {
        if self == 0 {
            return false
        } else {
            return true
        }
    }
    func zeroToNull() -> Self? {
        if self == 0 {
            return nil
        } else {
            return self
        }
    }

    // swiftlint:disable:next large_tuple
    func secondsToHoursMinutesSeconds() -> (hours: UInt8, minutes: UInt8, seconds: UInt8) {
        return (UInt8(self / 3600), UInt8((self % 3600) / 60), UInt8((self % 3600) % 60))
    }

    // swiftlint:disable:next large_tuple
    func secondsToDaysHoursMinutesSeconds() -> (days: UInt16, hours: UInt8, minutes: UInt8, seconds: UInt8) {
        return (UInt16(self / 86400), UInt8((self / 3600) % 24), UInt8((self % 3600) / 60), UInt8((self % 3600) % 60))
    }

    func withCommas() -> String {
        let charArray = Array(self.toString()).reversed()
        var charWithCommasArray = [Character]()
        var index = 1
        for char in charArray {
            charWithCommasArray.append(char)
            if index % 3 == 0 && index != charArray.count {
                charWithCommasArray.append(",")
            }
            index += 1
        }
        return String(charWithCommasArray.reversed())
    }
}

extension BinaryInteger where Self: CVarArg {
    func toHexString() -> String? {
        return String(format: "%02X", self)
    }
}
