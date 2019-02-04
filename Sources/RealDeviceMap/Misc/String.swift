//
//  String.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 24.09.18.
//

import Foundation
import PerfectLib

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
    
    func toUInt8() -> UInt8? {
        return UInt8(self)
    }
    
    func toUInt16() -> UInt16? {
        return UInt16(self)
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
    
    func jsonDecodeForceTry() -> JSONConvertible? {
        
        do {
            return try self.jsonDecode()
        } catch {
            return nil
        }
        
    }
    
    func encodeUrl() -> String? {
        let a = self.replacingOccurrences(of: "/", with: "&slash")
        let b = a.replacingOccurrences(of: "+", with: "&plus")
        return b.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
    }
    
    func decodeUrl() -> String? {
        if let a = self.removingPercentEncoding {
            let b = a.replacingOccurrences(of: "&slash", with: "/")
            return b.replacingOccurrences(of: "&plus", with: "+")
        }
        return nil
    }
    
    func escaped() -> String {
        return self.replacingOccurrences(of: "\\", with: "\\\\")
    }
    
    func unscaped() -> String {
        return self.replacingOccurrences(of: "\\\\", with: "\\")
    }
    
    func emptyToNil() -> String? {
        if self.trimmingCharacters(in: .whitespacesAndNewlines) == "" {
            return nil
        } else {
            return self
        }
    }
    
}
