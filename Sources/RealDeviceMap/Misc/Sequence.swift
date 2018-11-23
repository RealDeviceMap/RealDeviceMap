//
//  Sequence.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 23.11.18.
//

import Foundation

extension Sequence {
    
    func randomShuffled() -> [Element] {
        var result = Array(self)
        result.shuffle()
        return result
    }
    
}
