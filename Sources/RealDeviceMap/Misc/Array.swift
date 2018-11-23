//
//  Sequence.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 23.11.18.
//

import Foundation

extension Array {
    
    func randomShuffled() -> [Element] {
        var results = [Element]()
        var indexes = (0 ..< count).map { $0 }
        while indexes.count > 0 {
            let indexOfIndexes = Int.getRandomNum(0, indexes.count - 1)
            let index = indexes[indexOfIndexes]
            results.append(self[index])
            indexes.remove(at: indexOfIndexes)
        }
        return results
    }
    
}
