//
//  Int32.swift
//  RealDeviceMap
//
//  Created by versx on 12/22/19.
//

import Foundation

extension Int32 {
    func withCommas() -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        return numberFormatter.string(from: NSNumber(value: self))!
    }
}
