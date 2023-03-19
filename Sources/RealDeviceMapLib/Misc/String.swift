//
//  String.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 24.09.18.
//

import Foundation
import PerfectLib
import COpenSSL
import Regex

public extension String {

    func toDouble() -> Double? {
        return Double(self)
    }

    func toBool() -> Bool? {
        return Bool(self)
    }

    func toInt() -> Int? {
        return Int(self)
    }

    func toInt32() -> Int32? {
        return Int32(self)
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

    func toDate() -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = Localizer.global.timeZone
        return formatter.date(from: self)
    }

    var length: Int {
        return self.count
    }

    subscript (index: Int) -> String {
        return self[index ..< index + 1]
    }

    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }

    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }

    subscript (range: Range<Int>) -> String {
        let rangeBounds = Range(uncheckedBounds: (lower: max(0, min(length, range.lowerBound)),
                                            upper: min(length, max(0, range.upperBound))))
        let start = index(startIndex, offsetBy: rangeBounds.lowerBound)
        let end = index(start, offsetBy: rangeBounds.upperBound - rangeBounds.lowerBound)
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
        let step1 = self.replacingOccurrences(of: "/", with: "&slash")
        let step2 = step1.replacingOccurrences(of: "+", with: "&plus")
        return step2.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
    }

    func decodeUrl() -> String? {
        if let step1 = self.removingPercentEncoding {
            let step2 = step1.replacingOccurrences(of: "&slash", with: "/")
            return step2.replacingOccurrences(of: "&plus", with: "+")
        }
        return nil
    }

    func escaped() -> String {
        return self.replacingOccurrences(of: "\\", with: "\\\\")
    }

    func unescaped() -> String {
        return self.replacingOccurrences(of: "\\\\", with: "\\")
    }

    func emptyToNil() -> String? {
        if self.trimmingCharacters(in: .whitespacesAndNewlines) == "" {
            return nil
        } else {
            return self
        }
    }

    var isValidURL: Bool
    {
        // wtf, this doesn't work in linux but does in mac
        /*
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        if let match = detector.firstMatch(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count)) {
            // it is a link, if the match covers the whole string
            return match.range.length == self.utf16.count
        } else {
            return false
        }
        */

        // quick and dirty url check
        let regex = "(https?)://[-A-Z0-9+&@#/%?=~_|$!:,.;]*[A-Z0-9+&@#/%=~_|$]"
        return self =~ regex
    }
}

extension String.UTF8View {

    // Source: https://github.com/PerfectlySoft/Perfect-HTTP/blob/master/Sources/PerfectHTTP/StaticFileHandler.swift
    var sha1: [UInt8] {
        let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(SHA_DIGEST_LENGTH))
        defer { bytes.deallocate() }

        SHA1([UInt8](self), (self.count), bytes)

        var returnBytes = [UInt8]()
        for idx in 0..<Int(SHA_DIGEST_LENGTH) {
            returnBytes.append(bytes[idx])
        }
        return returnBytes
    }

}
