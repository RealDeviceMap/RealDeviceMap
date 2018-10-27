//
//  AutoInstanceController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 23.10.18.
//

import Foundation
import Turf

class AutoInstanceController: InstanceControllerProto {
    
    enum AutoType {
        case quest
    }
    
    var name: String
    var multiPolygon: MultiPolygon
    
    private var type: AutoType
    
    init(name: String, multiPolygon: MultiPolygon, type: AutoType) {
        self.name = name
        self.type = type
        self.multiPolygon = multiPolygon
    }
    
    func getTask() -> [String : Any] {
        return ["action": "scan_quest", "lat": 47.477196, "lon": 11.9723570]
    }
        
}
