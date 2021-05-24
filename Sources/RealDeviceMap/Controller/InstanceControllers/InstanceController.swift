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
import PerfectMySQL
import Turf
import POGOProtos

protocol InstanceControllerDelegate: class {
    func instanceControllerDone(mysql: MySQL?, name: String)
}

protocol InstanceControllerProto {
    var name: String { get }
    var minLevel: UInt8 { get }
    var maxLevel: UInt8 { get }
    var accountGroup: String? { get }
    var isEvent: Bool { get }
    var delegate: InstanceControllerDelegate? { get set }
    func getTask(mysql: MySQL, uuid: String, username: String?, account: Account?) -> [String: Any]
    func getStatus(mysql: MySQL, formatted: Bool) -> JSONConvertible?
    func getAccount(mysql: MySQL, uuid: String) throws -> Account?
    func accountValid(account: Account) -> Bool
    func reload()
    func stop()
    func shouldStoreData() -> Bool
    func gotPokemon(pokemon: Pokemon)
    func gotIV(pokemon: Pokemon)
    func gotFortData(fortData: PokemonFortProto, username: String?)
    func gotPlayerInfo(username: String, level: Int, xp: Int)
}

extension InstanceControllerProto {
    func shouldStoreData() -> Bool { return true }
    func gotPokemon(pokemon: Pokemon) { }
    func gotIV(pokemon: Pokemon) { }
    func gotFortData(fortData: PokemonFortProto, username: String?) { }
    func gotPlayerInfo(username: String, level: Int, xp: Int) { }
    func getAccount(mysql: MySQL, uuid: String) throws -> Account? {
        return try Account.getNewAccount(mysql: mysql, minLevel: minLevel, maxLevel: maxLevel,
                                         device: uuid, group: accountGroup)
    }
    func accountValid(account: Account) -> Bool {
        return account.level >= minLevel && account.level <= maxLevel && account.isValid(group: accountGroup)
    }
}

extension InstanceControllerProto {
    static func == (lhs: InstanceControllerProto, rhs: InstanceControllerProto) -> Bool {
        return lhs.name == rhs.name
    }
}

class InstanceController {

    public private(set) static var global = InstanceController()
    public static var noRequireAccount = false

    public static func setup() throws {

        let instances = try Instance.getAll()
        let devices = try Device.getAll()

        let thread = Threading.getQueue(name: "InstanceController-global-setup", type: .serial)
        thread.dispatch {
            Log.info(message: "[InstanceController] Starting instances...")
            let dispatchGroup = DispatchGroup()
            for instance in instances {
                dispatchGroup.enter()
                let instanceThread = Threading.getQueue(
                    name: "InstanceController-instance-\(instance.name)-setup",
                    type: .serial
                )
                instanceThread.dispatch {
                    Log.debug(message: "[InstanceController] Starting \(instance.name)...")
                    global.addInstance(instance: instance)
                    Log.debug(message: "[InstanceController] Started \(instance.name)")
                    for device in devices where device.instanceName == instance.name {
                        global.addDevice(device: device)
                    }
                    dispatchGroup.leave()
                }
            }
            dispatchGroup.wait()
            Log.info(message: "[InstanceController] Done starting instances")
        }

    }

    private init() { }

    private let instancesLock = Threading.Lock()
    private var instancesByInstanceName = [String: InstanceControllerProto]()
    private var devicesByDeviceUUID = [String: Device]()

    public func getInstanceController(instanceName: String) -> InstanceControllerProto? {
        instancesLock.lock()
        let instances = instancesByInstanceName[instanceName]
        instancesLock.unlock()
        return instances
    }

    public func getInstanceController(deviceUUID: String) -> InstanceControllerProto? {
        instancesLock.lock()
        guard let device = devicesByDeviceUUID[deviceUUID], let instanceName = device.instanceName else {
            instancesLock.unlock()
            return nil
        }
        let instances = instancesByInstanceName[instanceName]
        instancesLock.unlock()
        return instances
    }

    public func addInstance(instance: Instance) {
        var instanceController: InstanceControllerProto
        switch instance.type {
        case .circleSmartRaid, .circleSmartPokemon, .circlePokemon, .circleRaid:
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
            let accountGroup = (instance.data["account_group"] as? String)?.emptyToNil()
            let isEvent = instance.data["is_event"] as? Bool ?? false

            if instance.type == .circlePokemon {
                instanceController = CircleInstanceController(name: instance.name, coords: coordsArray,
                                                              type: .pokemon, minLevel: minLevel, maxLevel: maxLevel,
                                                              accountGroup: accountGroup, isEvent: isEvent)
            } else if instance.type == .circleSmartPokemon {
                instanceController = CircleInstanceController(name: instance.name, coords: coordsArray,
                                                              type: .smartPokemon, minLevel: minLevel,
                                                              maxLevel: maxLevel, accountGroup: accountGroup,
                                                              isEvent: isEvent)
            } else if instance.type == .circleRaid {
                instanceController = CircleInstanceController(name: instance.name, coords: coordsArray,
                                                              type: .raid, minLevel: minLevel, maxLevel: maxLevel,
                                                              accountGroup: accountGroup, isEvent: isEvent)
            } else {
                instanceController = CircleSmartRaidInstanceController(name: instance.name, coords: coordsArray,
                                                                       minLevel: minLevel, maxLevel: maxLevel,
                                                                       accountGroup: accountGroup, isEvent: isEvent)
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
            let accountGroup = (instance.data["account_group"] as? String)?.emptyToNil()
            let isEvent = instance.data["is_event"] as? Bool ?? false

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
                    minLevel: minLevel, maxLevel: maxLevel, ivQueueLimit: ivQueueLimit, scatterPokemon: scatterList,
                    accountGroup: accountGroup, isEvent: isEvent
                )
            } else {
                let spinLimit = instance.data["spin_limit"] as? Int ?? 1000
                let delayLogout = instance.data["delay_logout"] as? Int ?? 900
                instanceController = AutoInstanceController(
                    name: instance.name, multiPolygon: MultiPolygon(areaArrayEmptyInner), type: .quest,
                    timezoneOffset: timezoneOffset, minLevel: minLevel, maxLevel: maxLevel,
                    spinLimit: spinLimit, delayLogout: delayLogout,
                    accountGroup: accountGroup, isEvent: isEvent
                )
            }
        case .leveling:
            let coord: Coord
            if let coordX = instance.data["area"] as? Coord {
                coord = coordX
            } else {
                let coordDict = instance.data["area"] as? [String: Double] ?? [:]
                if let lat = coordDict["lat"], let lon = coordDict["lon"] {
                    coord = Coord(lat: lat, lon: lon)
                } else {
                    coord = Coord(lat: 0, lon: 0)
                }
            }
            let minLevel = instance.data["min_level"] as? UInt8 ?? (instance.data["min_level"] as? Int)?.toUInt8() ?? 0
            let maxLevel = instance.data["max_level"] as? UInt8 ?? (instance.data["max_level"] as? Int)?.toUInt8() ?? 29
            let accountGroup = (instance.data["account_group"] as? String)?.emptyToNil()
            let isEvent = instance.data["is_event"] as? Bool ?? false
            let radius = instance.data["radius"] as? UInt64 ?? (instance.data["radius"] as? Int)?.toUInt64() ?? 100000
            let storeData = instance.data["store_data"] as? Bool ?? false
            instanceController = LevelingInstanceController(
                name: instance.name,
                start: coord,
                minLevel: minLevel,
                maxLevel: maxLevel,
                storeData: storeData,
                radius: radius,
                accountGroup: accountGroup,
                isEvent: isEvent
            )
        }
        instanceController.delegate = AssignmentController.global
        instancesLock.lock()
        instancesByInstanceName[instance.name] = instanceController
        instancesLock.unlock()
    }

    public func reloadAllInstances() {
        instancesLock.lock()
        for instance in instancesByInstanceName {
            instance.value.reload()
        }
        instancesLock.unlock()
        try? AssignmentController.global.setup()
    }

    public func reloadInstance(newInstance: Instance, oldInstanceName: String) {
        instancesLock.lock()
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
        instancesLock.unlock()
        addInstance(instance: newInstance)
    }

    public func removeInstance(instance: Instance) {
        instancesLock.lock()
        instancesByInstanceName[instance.name]?.stop()
        instancesByInstanceName[instance.name] = nil
        for device in devicesByDeviceUUID where device.value.instanceName == instance.name {
            devicesByDeviceUUID[device.key] = nil
        }
        instancesLock.unlock()
        try? AssignmentController.global.setup()
    }

    public func removeInstance(instanceName: String) {
        instancesLock.lock()
        instancesByInstanceName[instanceName]?.stop()
        instancesByInstanceName[instanceName] = nil
        for device in devicesByDeviceUUID where device.value.instanceName == instanceName {
            devicesByDeviceUUID[device.key] = nil
        }
        instancesLock.unlock()
        try? AssignmentController.global.setup()
    }

    public func addDevice(device: Device) {
        instancesLock.lock()
        if device.instanceName != nil && instancesByInstanceName[device.instanceName!] != nil {
            devicesByDeviceUUID[device.uuid] = device
        }
        instancesLock.unlock()
        try? AssignmentController.global.setup()
    }

    public func reloadDevice(newDevice: Device, oldDeviceUUID: String) {
        removeDevice(deviceUUID: oldDeviceUUID)
        addDevice(device: newDevice)
    }

    public func removeDevice(device: Device) {
        instancesLock.lock()
        devicesByDeviceUUID[device.uuid] = nil
        instancesLock.unlock()
        try? AssignmentController.global.setup()
    }

    public func removeDevice(deviceUUID: String) {
        instancesLock.lock()
        devicesByDeviceUUID[deviceUUID] = nil
        instancesLock.unlock()
        try? AssignmentController.global.setup()
    }

    public func shouldStoreData(deviceUUID: String) -> Bool {
        if let instanceController = getInstanceController(deviceUUID: deviceUUID) {
            return instanceController.shouldStoreData()
        }
        return true
    }

    public func getAccount(mysql: MySQL, deviceUUID: String) throws -> Account? {
        if let instanceController = getInstanceController(deviceUUID: deviceUUID) {
            return try instanceController.getAccount(mysql: mysql, uuid: deviceUUID)
        }
        return try Account.getNewAccount(minLevel: 0, maxLevel: 29, device: deviceUUID)
    }

    public func accountValid(deviceUUID: String, account: Account) -> Bool {
        if let instanceController = getInstanceController(deviceUUID: deviceUUID) {
            return instanceController.accountValid(account: account)
        }
        return account.isValid()
    }

    public func getDeviceUUIDsInInstance(instanceName: String) -> [String] {
        var deviceUUIDS = [String]()
        instancesLock.lock()
        for device in devicesByDeviceUUID where device.value.instanceName == instanceName {
            deviceUUIDS.append(device.key)
        }
        instancesLock.unlock()
        return deviceUUIDS
    }

    public func getInstanceStatus(mysql: MySQL, instance: Instance, formatted: Bool) -> JSONConvertible? {
        instancesLock.lock()
        if let instanceProto = instancesByInstanceName[instance.name] {
            instancesLock.unlock()
            return instanceProto.getStatus(mysql: mysql, formatted: formatted)
        } else {
            instancesLock.unlock()
            if formatted {
                return "Starting..."
            } else {
                return nil
            }
        }
    }

    public func gotPokemon(pokemon: Pokemon) {
        instancesLock.lock()
        for instance in instancesByInstanceName {
            instance.value.gotPokemon(pokemon: pokemon)
        }
        instancesLock.unlock()
    }

    public func gotIV(pokemon: Pokemon) {
        instancesLock.lock()
        for instance in instancesByInstanceName {
            instance.value.gotIV(pokemon: pokemon)
        }
        instancesLock.unlock()
    }

    public func gotFortData(fortData: PokemonFortProto, username: String?) {
        instancesLock.lock()
        for instance in instancesByInstanceName {
            instance.value.gotFortData(fortData: fortData, username: username)
        }
        instancesLock.unlock()
    }

    public func gotPlayerInfo(username: String, level: Int, xp: Int) {
        instancesLock.lock()
        for instance in instancesByInstanceName {
            instance.value.gotPlayerInfo(username: username, level: level, xp: xp)
        }
        instancesLock.unlock()
    }

    public func getIVQueue(name: String) -> [Pokemon] {
        instancesLock.lock()
        if let instance = instancesByInstanceName[name] as? IVInstanceController {
            instancesLock.unlock()
            return instance.getQueue()
        }
        instancesLock.unlock()
        return [Pokemon]()
    }

}
