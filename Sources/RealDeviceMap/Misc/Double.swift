//
//  Double.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 06.10.18.
//

import Foundation

extension Double {

    func rounded(decimals: Int) -> Double {
        let divisor = pow(10.0, Double(decimals))
        return (self * divisor).rounded() / divisor
    }
    func rounded(toStringWithDecimals decimals: Int) -> String {
        return String(format: "%.\(decimals)f", self.rounded(decimals: decimals))
    }

}
