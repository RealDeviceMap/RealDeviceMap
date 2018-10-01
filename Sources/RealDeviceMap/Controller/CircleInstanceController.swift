//
//  CircleInstanceController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 30.09.18.
//

import Foundation

class CircleInstanceController: InstanceControllerProto {
   
    static func == (lhs: CircleInstanceController, rhs: CircleInstanceController) -> Bool {
        return lhs.name == rhs.name
    }
    
    
    enum CircleType {
        case pokemon
        case raid
    }
    
    public private(set) var name: String
    
    private let type: CircleType
    private let coords: [Coord]
    private var lastIndex: Int = 0
    private var lock = NSLock()

    
    init(name: String, coords: [Coord], type: CircleType) {
        self.name = name
        self.coords = coords
        self.type = type
    }
    
    func getTask() -> [String : Any] {
        
        let count = coords.count
        
        lock.lock()
        let currentIndex = self.lastIndex
        
        let nextIndex: Int
        if lastIndex + 1 == count {
            nextIndex = 0
        } else {
            nextIndex = lastIndex + 1
        }
        lastIndex = nextIndex
        lock.unlock()
        
        let currentCoord = coords[currentIndex]
        
        if type == .pokemon {
            return ["action": "scan_pokemon", "lat": currentCoord.lat, "lon": currentCoord.lon]
        } else {
            return ["action": "scan_raid", "lat": currentCoord.lat, "lon": currentCoord.lon]
        }
        
    }
        
}
