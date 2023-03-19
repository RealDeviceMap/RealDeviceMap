//
//  Kojis.swift
//  RealDeviceMapLib
//
//  Created by Beavis on Mar 18, 2023.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast large_tuple

import Foundation

public func clamp<T>(_ value: T, minValue: T, maxValue: T) -> T where T : Comparable {
    return min(max(value, minValue), maxValue)
}
