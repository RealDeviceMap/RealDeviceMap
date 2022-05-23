//
//  JSON.swift
//  Config
//
//  https://github.com/mustafakarakus/Config
//
//  Created by Mustafa Karakus on 03/10/2019.
//  Copyright © 2019 Mustafa Karakus. All rights reserved.
//

import Foundation

@dynamicMemberLookup
public enum JSON {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSON])
    case array([JSON])
    case error(String)
}

extension JSON: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = try ((try? container.decode(String.self)).map(JSON.string))
                .or((try? container.decode(Int.self)).map(JSON.int))
                .or((try? container.decode(Double.self)).map(JSON.double))
                .or((try? container.decode(Bool.self)).map(JSON.bool))
                .or((try? container.decode([String: JSON].self)).map(JSON.object))
                .or((try? container.decode([JSON].self)).map(JSON.array))
                .resolve(with: DecodingError.typeMismatch(JSON.self, DecodingError.Context(codingPath:
                    container.codingPath, debugDescription: "Not valid JSON")))
    }

    public func value<T>() -> T? {
        return getValue(json: self) as? T
    }

    public subscript(key: String) -> JSON {
        if case .object(let dict) = self {
            return dict[key] ?? JSON.error("Key does not exists - '\(key)'")
        }
        return JSON.error("Not valid JSON")
    }

    public subscript(dynamicMember member: String) -> JSON {
        if case .object(let dict) = self {
            return dict[member] ?? JSON.error("Key does not exists - '\(member)'")
        }
        return JSON.error("Can not reach - '\(member)'")
    }

    func getValue(json: JSON) -> Any {
        switch json {
        case .int(let intValue):
            return intValue
        case .string(let stringValue):
            return stringValue
        case .bool(let boolValue):
            return boolValue
        case .double(let doubleValue):
            return doubleValue
        case .object(let dictionaryValue):
            return dictionaryValue.mapValues {  getValue(json: $0 )}
        case .array(let arrayValue):
            return arrayValue.map { getValue(json: $0 )}
        default:
            return JSON.error
        }
    }
}

extension JSON {
    public var intValue: Int? {
        return getValue(json: self) as? Int
    }
    public var stringValue: String? {
        return getValue(json: self) as? String
    }
    public var boolValue: Bool? {
        return getValue(json: self) as? Bool
    }
    public var doubleValue: Double? {
        return getValue(json: self) as? Double
    }
}

extension Optional {
    func or(_ other: Optional) -> Optional {
        switch self {
        case .none: return other
        case .some: return self
        }
    }

    func resolve(with error: @autoclosure () -> Error) throws -> Wrapped {
        switch self {
        case .none: throw error()
        case .some(let wrapped): return wrapped
        }
    }
}
