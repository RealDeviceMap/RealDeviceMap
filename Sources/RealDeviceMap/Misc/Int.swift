//
//  Int.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//

import Foundation

extension Int {
    
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
        return String(self)
    }
    func toUInt8Checked() -> UInt8? {
        if self >= UInt8.min && self <= UInt8.max {
            return UInt8(self)
        }
        return nil
    }
    static func getRandomNum(_ min: Int, _ max: Int) -> Int {
        #if os(Linux)
        return Int(Glibc.random() % max) + min
        #else
        return Int(arc4random_uniform(UInt32(max)) + UInt32(min))
        #endif
    }
    
}
