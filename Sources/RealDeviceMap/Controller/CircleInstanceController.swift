//
//  CircleInstanceController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 30.09.18.
//

import Foundation

class CircleInstanceController: InstanceControllerProto {
   
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
    
    func getTask(uuid: String, username: String?) -> [String : Any] {
        
        lock.lock()
        let currentIndex = self.lastIndex
        if lastIndex + 1 == coords.count {
            lastIndex = 0
        } else {
            lastIndex = lastIndex + 1
        }
        lock.unlock()
        
        let currentCoord = coords[currentIndex]
        
        if type == .pokemon {
            return ["action": "scan_pokemon", "lat": currentCoord.lat, "lon": currentCoord.lon]
        } else {
            return ["action": "scan_raid", "lat": currentCoord.lat, "lon": currentCoord.lon]
        }
        
    }
    
}
