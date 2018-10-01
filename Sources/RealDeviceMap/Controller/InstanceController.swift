//
//  InstanceController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 30.09.18.
//

import Foundation

protocol InstanceControllerProto {
    var name: String { get }
    func getTask() -> [String: Any]
}

class InstanceController {
    
    public private(set) static var global = InstanceController()
    
    public static func setup() throws {
        
        let instances = try Instance.getAll()
        let devices = try Device.getAll()
        
        for instance in instances {
            global.addInstance(instance: instance)
        }
        for device in devices {
            global.addDevice(device: device)
        }
        
    }
    
    private init() { }
    
    private var instancesByInstanceName = [String: InstanceControllerProto]()
    private var instancesByDeviceUUID = [String: InstanceControllerProto]()

    public func getInstanceController(instanceName: String) -> InstanceControllerProto? {
        return instancesByInstanceName[instanceName]
    }
    
    public func getInstanceController(deviceUUID: String) -> InstanceControllerProto? {
        return instancesByDeviceUUID[deviceUUID]
    }
    
    public func addInstance(instance: Instance) {
        let instanceController: InstanceControllerProto
        switch instance.type {
        case .circlePokemon:
            fallthrough
        case .circleRaid:
            var coordsArray = [Coord]()
            if instance.data["area"] as? [Coord] != nil {
                coordsArray = instance.data["area"] as! [Coord]
            } else {
                let coords = instance.data["area"] as! [[String: Double]]
                for coord in coords {
                    coordsArray.append(Coord(lat: coord["lat"]!, lon: coord["lon"]!))
                }
            }
            if instance.type == .circlePokemon {
                instanceController = CircleInstanceController(name: instance.name, coords: coordsArray, type: .pokemon)
            } else {
                instanceController = CircleInstanceController(name: instance.name, coords: coordsArray, type: .raid)
            }
        }
        instancesByInstanceName[instance.name] = instanceController
    }
    
    public func reloadInstance(newInstance: Instance, oldInstanceName: String) {
        let oldInstance = instancesByInstanceName[oldInstanceName]
        var removedDeviceUUIDs = [String]()
        if oldInstance != nil {
            for row in instancesByDeviceUUID {
                if row.value.name == oldInstance!.name {
                    removedDeviceUUIDs.append(row.key)
                }
            }
            instancesByInstanceName[oldInstanceName] = nil
        }
        addInstance(instance: newInstance)
        for removedDeviceUUID in removedDeviceUUIDs {
            instancesByDeviceUUID[removedDeviceUUID] = instancesByInstanceName[newInstance.name]
        }
    }
    
    public func removeInstance(instance: Instance) {
        instancesByInstanceName[instance.name] = nil
        for deviceInstance in instancesByDeviceUUID {
            if deviceInstance.value.name == instance.name {
                instancesByDeviceUUID[deviceInstance.key] = nil
            }
        }
    }
    
    public func removeInstance(instanceName: String) {
        instancesByInstanceName[instanceName] = nil
        for deviceInstance in instancesByDeviceUUID {
            if deviceInstance.value.name == instanceName {
                instancesByDeviceUUID[deviceInstance.key] = nil
            }
        }
    }
    
    public func addDevice(device: Device) {
        if device.instanceName != nil && instancesByInstanceName[device.instanceName!] != nil {
            instancesByDeviceUUID[device.uuid] = instancesByInstanceName[device.instanceName!]
        }
    }
    
    public func reloadDevice(newDevice: Device, oldDeviceUUID: String) {
        instancesByDeviceUUID[oldDeviceUUID] = nil
        addDevice(device: newDevice)
    }
    
    public func removeDevice(device: Device) {
        instancesByDeviceUUID[device.uuid] = nil
    }
    
    public func removeDevice(deviceUUID: String) {
        instancesByDeviceUUID[deviceUUID] = nil
    }
        
}
