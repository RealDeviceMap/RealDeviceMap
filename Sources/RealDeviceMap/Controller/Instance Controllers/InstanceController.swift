//
//  InstanceController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 30.09.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity

import Foundation
import PerfectLib
import PerfectThread
import Turf

protocol InstanceControllerDelegate: class {
    func instanceControllerDone(name: String)
}

protocol InstanceControllerProto {
    var name: String { get }
    var minLevel: UInt8 { get }
    var maxLevel: UInt8 { get }
    var delegate: InstanceControllerDelegate? { get set }
    func getTask(uuid: String, username: String?) -> [String: Any]
    func getStatus(formatted: Bool) -> JSONConvertible?
    func reload()
    func stop()
}

extension InstanceControllerProto {
    static func == (lhs: InstanceControllerProto, rhs: InstanceControllerProto) -> Bool {
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
        case .circleSmartRaid, .circlePokemon, .circleRaid:
            var coordsArray = [Coord]()
            if instance.data["area"] as? [Coord] != nil {
                coordsArray = instance.data["area"] as? [Coord] ?? [Coord]()
            } else {
                let coords = instance.data["area"] as? [[String: Double]] ?? [[String: Double]]()
                for coord in coords {
                    coordsArray.append(Coord(lat: coord["lat"]!, lon: coord["lon"]!))
                }
            }
            let minLevel = instance.data["min_level"] as? UInt8 ?? (instance.data["min_level"] as? Int)?.toUInt8() ?? 0
            let maxLevel = instance.data["max_level"] as? UInt8 ?? (instance.data["max_level"] as? Int)?.toUInt8() ?? 29

            if instance.type == .circlePokemon {
                instanceController = CircleInstanceController(name: instance.name, coords: coordsArray,
                                                              type: .pokemon, minLevel: minLevel, maxLevel: maxLevel)
            } else if instance.type == .circleRaid {
                instanceController = CircleInstanceController(name: instance.name, coords: coordsArray,
                                                              type: .raid, minLevel: minLevel, maxLevel: maxLevel)
            } else {
                instanceController = CircleSmartRaidInstanceController(name: instance.name, coords: coordsArray,
                                                                       minLevel: minLevel, maxLevel: maxLevel)
            }
        case .pokemonIV, .autoQuest:
            var areaArray = [[Coord]]()
            if instance.data["area"] as? [[Coord]] != nil {
                areaArray = instance.data["area"] as? [[Coord]] ?? [[Coord]]()
            } else {
                let areas = instance.data["area"] as? [[[String: Double]]] ?? [[[String: Double]]]()
                var i = 0
                for coords in areas {
                    for coord in coords {
                        while areaArray.count != i + 1 {
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

            let minLevel = instance.data["min_level"] as? UInt8 ?? (instance.data["min_level"] as? Int)?.toUInt8() ?? 0
            let maxLevel = instance.data["max_level"] as? UInt8 ?? (instance.data["max_level"] as? Int)?.toUInt8() ?? 29

            if instance.type == .pokemonIV {
                let pokemonList = instance.data["pokemon_ids"] as? [UInt16] ??
                                  (instance.data["pokemon_ids"] as? [Int])?.map({ (int) -> UInt16 in
                    return UInt16(int)
                }) ?? [UInt16]()
                let ivQueueLimit = instance.data["iv_queue_limit"] as? Int ?? 100
                let scatterList = instance.data["scatter_pokemon_ids"] as? [UInt16] ??
                                  (instance.data["scatter_pokemon_ids"] as? [Int])?.map({ (int) -> UInt16 in
                    return UInt16(int)
                }) ?? [UInt16]()
                instanceController = IVInstanceController(
                    name: instance.name, multiPolygon: MultiPolygon(areaArrayEmptyInner), pokemonList: pokemonList,
                    minLevel: minLevel, maxLevel: maxLevel, ivQueueLimit: ivQueueLimit, scatterPokemon: scatterList
                )
            } else {
                let spinLimit = instance.data["spin_limit"] as? Int ?? 500
                instanceController = AutoInstanceController(
                    name: instance.name, multiPolygon: MultiPolygon(areaArrayEmptyInner), type: .quest,
                    timezoneOffset: timezoneOffset, minLevel: minLevel, maxLevel: maxLevel, spinLimit: spinLimit
                )
            }
        }
        instanceController.delegate = AssignmentController.global
        instancesByInstanceName[instance.name] = instanceController
    }

    public func reloadAllInstances() {
        for instance in instancesByInstanceName {
            instance.value.reload()
        }
        try? AssignmentController.global.setup()
    }

    public func reloadInstance(newInstance: Instance, oldInstanceName: String) {
        let oldInstance = instancesByInstanceName[oldInstanceName]
        if oldInstance != nil {
            for row in devicesByDeviceUUID where row.value.instanceName == oldInstance!.name {
                let device = row.value
                device.instanceName = newInstance.name
                devicesByDeviceUUID[row.key] = device
            }
            instancesByInstanceName[oldInstanceName]?.stop()
            instancesByInstanceName[oldInstanceName] = nil
        }
        addInstance(instance: newInstance)
    }

    public func removeInstance(instance: Instance) {
        instancesByInstanceName[instance.name]?.stop()
        instancesByInstanceName[instance.name] = nil
        for device in devicesByDeviceUUID where device.value.instanceName == instance.name {
            devicesByDeviceUUID[device.key] = nil
        }
        try? AssignmentController.global.setup()
    }

    public func removeInstance(instanceName: String) {
        instancesByInstanceName[instanceName]?.stop()
        instancesByInstanceName[instanceName] = nil
        for device in devicesByDeviceUUID where device.value.instanceName == instanceName {
            devicesByDeviceUUID[device.key] = nil
        }
        try? AssignmentController.global.setup()
    }

    public func addDevice(device: Device) {
        if device.instanceName != nil && instancesByInstanceName[device.instanceName!] != nil {
            devicesByDeviceUUID[device.uuid] = device
        }
        try? AssignmentController.global.setup()
    }

    public func reloadDevice(newDevice: Device, oldDeviceUUID: String) {
        removeDevice(deviceUUID: oldDeviceUUID)
        addDevice(device: newDevice)
    }

    public func removeDevice(device: Device) {
        devicesByDeviceUUID[device.uuid] = nil
        try? AssignmentController.global.setup()
    }

    public func removeDevice(deviceUUID: String) {
        devicesByDeviceUUID[deviceUUID] = nil
        try? AssignmentController.global.setup()
    }

    public func getDeviceUUIDsInInstance(instanceName: String) -> [String] {
        var deviceUUIDS = [String]()
        for device in devicesByDeviceUUID where device.value.instanceName == instanceName {
            deviceUUIDS.append(device.key)
        }
        return deviceUUIDS
    }

    public func getInstanceStatus(instance: Instance, formatted: Bool) -> JSONConvertible? {
        if let instanceProto = instancesByInstanceName[instance.name] {
            return instanceProto.getStatus(formatted: formatted)
        } else {
            if formatted {
                return "?"
            } else {
                return nil
            }
        }
    }

    public func gotPokemon(pokemon: Pokemon) {
        for instance in instancesByInstanceName {
            if let instance = instance.value as? IVInstanceController {
                instance.addPokemon(pokemon: pokemon)
            }
        }
    }

    public func gotIV(pokemon: Pokemon) {
        for instance in instancesByInstanceName {
            if let instance = instance.value as? IVInstanceController {
                instance.gotIV(pokemon: pokemon)
            }
        }
    }

    public func getIVQueue(name: String) -> [Pokemon] {
        if let instance = instancesByInstanceName[name] as? IVInstanceController {
            return instance.getQueue()
        }
        return [Pokemon]()
    }

}
