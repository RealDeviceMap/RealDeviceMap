//
//  File 2.swift
//  
//
//  Created by Chris Ewing on 3/18/23.
//

import Foundation

public func clamp<T>(_ value: T, minValue: T, maxValue: T) -> T where T : Comparable {
    return min(max(value, minValue), maxValue)
}
