//
//  InstanceController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 30.09.18.
//

import Foundation
import Turf

protocol InstanceControllerDelegate {
    func instanceControllerDone(name: String)
}

protocol InstanceControllerProto {
    var name: String { get }
    var delegate: InstanceControllerDelegate? { get set }
    func getTask(uuid: String, username: String?) -> [String: Any]
    func getStatus() -> String
    func reload()
}

extension InstanceControllerProto {
    static func == (lhs: InstanceControllerProto, rhs:InstanceControllerProto) -> Bool {
        return lhs.name == rhs.name
    }
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
    private var devicesByDeviceUUID = [String: Device]()

    public func getInstanceController(instanceName: String) -> InstanceControllerProto? {
        return instancesByInstanceName[instanceName]
    }
    
    public func getInstanceController(deviceUUID: String) -> InstanceControllerProto? {
        guard let device = devicesByDeviceUUID[deviceUUID], let instanceName = device.instanceName else {
            return nil
        }
        return instancesByInstanceName[instanceName]
    }
    
    public func addInstance(instance: Instance) {
        var instanceController: InstanceControllerProto
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
        case .autoQuest:
            var areaArray = [[Coord]]()
            if instance.data["area"] as? [[Coord]] != nil {
                areaArray = instance.data["area"] as! [[Coord]]
            } else {
                let areas = instance.data["area"] as! [[[String: Double]]]
                var i = 0
                for coords in areas {
                    for coord in coords {
                        while areaArray.count != i + 1{
                            areaArray.append([Coord]())
                        }
                        areaArray[i].append(Coord(lat: coord["lat"]!, lon: coord["lon"]!))
                    }
                    i += 1
                }
            }
            let timezoneOffset = instance.data["timezone_offset"] as? Int ?? 0
            
            var areaArrayEmptyInner = [[[CLLocationCoordinate2D]]]()
            for coords in areaArray {
                var polyCoords = [CLLocationCoordinate2D]()
                for coord in coords {
                    polyCoords.append(CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lon))
                }
                areaArrayEmptyInner.append([polyCoords])
            }
            
            instanceController = AutoInstanceController(name: instance.name, multiPolygon: MultiPolygon(areaArrayEmptyInner), type: .quest, timezoneOffset: timezoneOffset)
        }
        instanceController.delegate = AssignmentController.global
        instancesByInstanceName[instance.name] = instanceController
    }
    
    public func reloadAllInstances() {
        for instance in instancesByInstanceName {
            instance.value.reload()
        }
    }
    
    public func reloadInstance(newInstance: Instance, oldInstanceName: String) {
        let oldInstance = instancesByInstanceName[oldInstanceName]
        if oldInstance != nil {
            for row in devicesByDeviceUUID {
                if row.value.instanceName == oldInstance!.name {
                    let device = row.value
                    device.instanceName = newInstance.name
                    devicesByDeviceUUID[row.key] = device
                }
            }
            instancesByInstanceName[oldInstanceName] = nil
        }
        addInstance(instance: newInstance)
    }
    
    public func removeInstance(instance: Instance) {
        instancesByInstanceName[instance.name] = nil
        for device in devicesByDeviceUUID {
            if device.value.instanceName == instance.name {
                devicesByDeviceUUID[device.key] = nil
            }
        }
    }
    
    public func removeInstance(instanceName: String) {
        instancesByInstanceName[instanceName] = nil
        for device in devicesByDeviceUUID {
            if device.value.instanceName == instanceName {
                devicesByDeviceUUID[device.key] = nil
            }
        }
    }
    
    public func addDevice(device: Device) {
        if device.instanceName != nil && instancesByInstanceName[device.instanceName!] != nil {
            devicesByDeviceUUID[device.uuid] = device
        }
    }
    
    public func reloadDevice(newDevice: Device, oldDeviceUUID: String) {
        removeDevice(deviceUUID: oldDeviceUUID)
        addDevice(device: newDevice)
    }
    
    public func removeDevice(device: Device) {
        devicesByDeviceUUID[device.uuid] = nil
    }
    
    public func removeDevice(deviceUUID: String) {
        devicesByDeviceUUID[deviceUUID] = nil
    }
    
    public func getDeviceUUIDsInInstance(instanceName: String) -> [String] {
        var deviceUUIDS = [String]()
        for device in devicesByDeviceUUID {
            if device.value.instanceName == instanceName {
                deviceUUIDS.append(device.key)
            }
        }
        return deviceUUIDS
    }
    
    public func getInstanceStatus(instance: Instance) -> String {
        if let instanceProto = instancesByInstanceName[instance.name] {
            return instanceProto.getStatus()
        } else {
            return "?"
        }
    }
        
}
