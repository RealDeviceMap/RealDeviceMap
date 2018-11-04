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
    public var delegate: InstanceControllerDelegate?
    
    private let type: CircleType
    private let coords: [Coord]
    private var lastIndex: Int = 0
    private var lock = NSLock()
    private var lastLastCompletedTime: Date?
    private var lastCompletedTime: Date?

    
    init(name: String, coords: [Coord], type: CircleType) {
        self.name = name
        self.coords = coords
        self.type = type
    }
    
    func getTask(uuid: String, username: String?) -> [String : Any] {
        
        lock.lock()
        let currentIndex = self.lastIndex
        if lastIndex + 1 == coords.count {
            lastLastCompletedTime = lastCompletedTime
            lastCompletedTime = Date()
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
    
    func getStatus() -> String {
        
        if let lastLast = lastLastCompletedTime, let last = lastCompletedTime {
            let time = Int(last.timeIntervalSince(lastLast))
            return "Round Time: \(time)s"
        } else {
            return "-"
        }
        
    }
    
    func reload() {
        lock.lock()
        lastIndex = 0
        lock.unlock()
    }
    
}
