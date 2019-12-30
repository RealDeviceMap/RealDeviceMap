//
//  Int64.swift
//  RealDeviceMap
//
//  Created by versx on 12/29/19.
//

import Foundation

extension Int64 {
    
    func withCommas() -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        return numberFormatter.string(from: NSNumber(value: self))!
    }
    
}
