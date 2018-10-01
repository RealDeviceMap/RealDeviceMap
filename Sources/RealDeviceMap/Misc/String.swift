//
//  String.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 24.09.18.
//

import Foundation

extension String {
    
    func toDouble() -> Double? {
        return Double(self)
    }
    
    func toBool() -> Bool? {
        return Bool(self)
    }
    
    func toInt() -> Int? {
        return Int(self)
    }
    
    func toUInt32() -> UInt32? {
        return UInt32(self)
    }
    
    func toUInt64() -> UInt64? {
        return UInt64(self)
    }
    
    var length: Int {
        return self.count
    }
    
    subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }
    
    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }
    
    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }
    
    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
    
}
