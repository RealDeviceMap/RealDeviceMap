//
//  AssignmentController.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 02.11.18.
//

import Foundation
import PerfectLib
import PerfectThread
import PerfectMySQL

public class AssignmentController: InstanceControllerDelegate {

    public static var global = AssignmentController()

    private var assignmentsLock = Threading.Lock()
    private var assignments = [Assignment]()
    private var isSetup = false
    private var queue: ThreadQueue!
    private var timeZone: TimeZone!

    private init() {}

    // swiftlint:disable:next superfluous_disable_command function_body_length cyclomatic_complexity
    public func setup() throws {

        assignmentsLock.lock()
        assignments = try Assignment.getAll()
        assignmentsLock.unlock()

        timeZone = Localizer.global.timeZone

        if !isSetup {
            isSetup = true

            queue = Threading.getQueue(name: "AssignmentController-updater", type: .serial)
            queue.dispatch {

                var mysql: MySQL?

                var lastUpdate: Int32 = -2
                let lastUpdatedFile = File("\(Dir.projectroot)/backups/last-updated.txt")
                if lastUpdatedFile.exists {
                    do {
                        try lastUpdatedFile.open(.read)
                        if let contents = try lastUpdatedFile.readString().toInt32() {
                            lastUpdate = contents
                        }
                        lastUpdatedFile.close()
                    } catch {
                        Log.error(message: "Failed to read last updated from file: \(error.localizedDescription)")
                    }
                }

                while true {

                    let now = self.todaySeconds()
                    if lastUpdate == -2 {
                        Threading.sleep(seconds: 5)
                        lastUpdate = Int32(now)
                        continue
                    } else if lastUpdate > now {
                        lastUpdate = -1
                    }

                    self.assignmentsLock.lock()
                    let assignments = self.assignments
                    self.assignmentsLock.unlock()

                    for assignment in assignments {
                        if assignment.time != 0 &&
                           now >= assignment.time &&
                           lastUpdate < assignment.time {
                            if mysql == nil {
                                mysql = DBController.global.mysql
                            }
                            do {
                                try self.triggerAssignment(mysql: mysql, assignment: assignment)
                            } catch {
                                Log.error(message: "Failed to trigger assignment: \(error.localizedDescription)")
                            }
                        }

                    }
                    mysql = nil

                    Threading.sleep(seconds: 5)
                    lastUpdate = Int32(now)
                    do {
                        try lastUpdatedFile.open(.write)
                        try lastUpdatedFile.write(string: lastUpdate.toString())
                        lastUpdatedFile.close()
                    } catch {
                        Log.error(message: "Failed to store last updated to file: \(error.localizedDescription)")
                    }
                }

            }
        }

    }

    public func addAssignment(assignment: Assignment) {
        assignmentsLock.lock()
        assignments.append(assignment)
        assignmentsLock.unlock()
    }

    public func editAssignment(oldAssignment: Assignment, newAssignment: Assignment) {
        assignmentsLock.lock()
        if let index = assignments.firstIndex(of: oldAssignment) {
            assignments.remove(at: index)
        }
        assignments.append(newAssignment)
        assignmentsLock.unlock()
    }

    public func deleteAssignment(id: UInt32) {
        assignmentsLock.lock()
        assignments = assignments.filter({ $0.id != id })
        assignmentsLock.unlock()
    }

    public func triggerAssignment(mysql: MySQL?=nil, assignment: Assignment,
                                  instance: String?=nil, force: Bool=false) throws {
        guard force || (
            assignment.enabled && (assignment.date == nil || assignment.date!.toString() == Date().toString())
        ) else {
            return
        }
        var devices = [Device]()
        if let deviceUUID = assignment.deviceUUID, let device = try Device.getById(mysql: mysql, id: deviceUUID) {
            devices.append(device)
        }
        if let deviceGroupName = assignment.deviceGroupName {
            devices += try Device.getAllInGroup(mysql: mysql, deviceGroupName: deviceGroupName)
        }
        for device in devices where (
            force || (
                (instance == nil || device.instanceName == instance) &&
                device.instanceName != assignment.instanceName &&
                (assignment.sourceInstanceName == nil || assignment.sourceInstanceName == device.instanceName)
            )
        ) {
            Log.info(
                message: "[AssignmentController] Assigning \(device.uuid) to \(assignment.instanceName)"
            )
            InstanceController.global.removeDevice(device: device)
            device.instanceName = assignment.instanceName
            try device.save(mysql: mysql, oldUUID: device.uuid)
            InstanceController.global.addDevice(device: device)
        }
    }

    func resolveAssignmentChain(assignment: Assignment) -> [String] {
        let assignments = assignments.filter({ $0.enabled == true})
        var result = [Assignment]()
        var toVisit = [assignment]
        while !toVisit.isEmpty {
            var found = false
            for source in toVisit {
                for target in assignments.filter({ $0.sourceInstanceName == source.instanceName}) {
                    if !toVisit.contains(target) {
                        toVisit.append(target)
                    }
                }
                if !result.contains(source) {
                    found = true
                    result.append(source)
                }
                toVisit.remove(at: toVisit.firstIndex(of: source)!)
            }
            if !found {
                // no new source found for result - finished
                break
            }
        }
        return result.map({ $0.instanceName}) // instances names
    }

    internal func startAssignmentGroup(assignmentGroup: AssignmentGroup) throws {
        let assignmentsInGroup = assignments.filter({ assignmentGroup.assignmentIDs.contains($0.id!) })
        for assignment in assignmentsInGroup {
            try AssignmentController.global.triggerAssignment(assignment: assignment, force: true)
        }
    }

    // swiftlint:disable:next superfluous_disable_command
    // swiftlint:disable cyclomatic_complexity
    internal func reQuestAssignmentGroup(assignmentGroup: AssignmentGroup) throws {
        let assignmentsInGroup = assignments.filter({ assignmentGroup.assignmentIDs.contains($0.id!) })
        let instances = try Instance.getAll().filter({ $0.type == .autoQuest})
        var clearQuests = [Instance]()
        for assignment in assignmentsInGroup {
            let affectedInstanceNames = self.resolveAssignmentChain(assignment: assignment)
            let affectedInstances = instances.filter({ affectedInstanceNames.contains($0.name) })

            for instance in affectedInstances where !clearQuests.contains(instance) {
                clearQuests.append(instance)
            }
        }
        Log.info(message: "[AssignmentController] ReQuest will clear quests on \(clearQuests.count) instances")
        var minLat: Double = 90.0
        var maxLat: Double = -90.0
        var minLon: Double = 180.0
        var maxLon: Double = -180.0
        do {
            for instance in clearQuests {
                let areaType1 = instance.data["area"] as? [[String: Double]]
                let areaType2 = instance.data["area"] as? [[[String: Double]]]
                if areaType1 != nil {
                    for coordLine in areaType1! {
                        minLat = coordLine["lat"]! < minLat ? coordLine["lat"]! : minLat
                        maxLat = coordLine["lat"]! > maxLat ? coordLine["lat"]! : maxLat
                        minLon = coordLine["lon"]! < minLon ? coordLine["lon"]! : minLon
                        maxLon = coordLine["lon"]! > maxLon ? coordLine["lon"]! : maxLon
                    }
                } else if areaType2 != nil {
                    for geofence in areaType2! {
                        for coordLine in geofence {
                            minLat = coordLine["lat"]! < minLat ? coordLine["lat"]! : minLat
                            maxLat = coordLine["lat"]! > maxLat ? coordLine["lat"]! : maxLat
                            minLon = coordLine["lon"]! < minLon ? coordLine["lon"]! : minLon
                            maxLon = coordLine["lon"]! > maxLon ? coordLine["lon"]! : maxLon
                        }
                    }
                }
            }
            let bbox: [Coord] = [Coord(lat: minLat, lon: minLon), Coord(lat: minLat, lon: maxLon),
                                 Coord(lat: maxLat, lon: maxLon), Coord(lat: maxLat, lon: minLon),
                                 Coord(lat: minLat, lon: minLon)]
            try Pokestop.clearQuests(area: bbox)
        } catch {
            Log.error(message: "[AssignmentController] Failed to clear quests of \(clearQuests.count) instances")
        }
        for instance in clearQuests {
            InstanceController.global.getInstanceController(instanceName: instance.name)?.reload()
        }
        for assignment in assignmentsInGroup {
            try AssignmentController.global.triggerAssignment(assignment: assignment, force: true)
        }
    }

    private func todaySeconds() -> UInt32 {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = timeZone
        let formattedDate = formatter.string(from: date)

        let split = formattedDate.components(separatedBy: ":")
        if split.count >= 3 {
            let hour = UInt32(split[0]) ?? 0
            let minute = UInt32(split[1]) ?? 0
            let second = UInt32(split[2]) ?? 0
            return hour * 3600 + minute * 60 + second
        } else {
            return 0
        }
    }

    deinit {
        Threading.destroyQueue(queue)
    }

    // MARK: - InstanceControllerDelegate

    public func instanceControllerDone(mysql: MySQL?, name: String) {
        for assignment in assignments where assignment.time == 0 {
            do {
                try triggerAssignment(mysql: mysql, assignment: assignment, instance: name)
            } catch {
                Log.error(message: "Failed to trigger assignment: \(error.localizedDescription)")
            }
        }
    }
}
