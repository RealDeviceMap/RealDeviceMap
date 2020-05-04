//
//  PersistentHashable.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 04.03.20.
//
import Foundation
import PerfectCrypto

public protocol PersistentHashable {
    var persistentHash: String? { get }
}

extension PersistentHashable where Self: Codable {
    public var persistentHash: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let json = try? encoder.encode(self),
              let md5Data = [UInt8](json).digest(.md5)else {
            return nil
        }
        return Data(md5Data).base64EncodedString()
    }
}
