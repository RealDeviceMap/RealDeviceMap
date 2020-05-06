//
//  AssignmentController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 02.11.18.
//

import Foundation
import PerfectLib
import PerfectThread

class AssignmentController: InstanceControllerDelegate {

    public static var global = AssignmentController()

    private var assignmentsLock = Threading.Lock()
    private var assignments = [Assignment]()
    private var isSetup = false
    private var queue: ThreadQueue!
    private var timeZone: TimeZone!

    private init() {}

    public func setup() throws {

        assignmentsLock.lock()
        assignments = try Assignment.getAll()
        assignmentsLock.unlock()

        timeZone = Localizer.global.timeZone

        if !isSetup {
            isSetup = true

            queue = Threading.getQueue(name: "AssignmentController-updater", type: .serial)
            queue.dispatch {

                var lastUpdate: Int32 = -2

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

                        if assignment.enabled &&
                           assignment.time != 0 &&
                           now >= assignment.time &&
                           lastUpdate < assignment.time {
                            self.triggerAssignment(assignment: assignment)
                        }

                    }

                    Threading.sleep(seconds: 5)
                    lastUpdate = Int32(now)

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
        if let index = assignments.index(of: oldAssignment) {
            assignments.remove(at: index)
        }
        assignments.append(newAssignment)
        assignmentsLock.unlock()
    }

    public func deleteAssignment(assignment: Assignment) {
        assignmentsLock.lock()
        if let index = assignments.index(of: assignment) {
            assignments.remove(at: index)
        }
        assignmentsLock.unlock()
    }

    private func triggerAssignment(assignment: Assignment) {
        var device: Device?
        var done = false
        while !done {
            do {
                device = try Device.getById(id: assignment.deviceUUID)
                done = true
            } catch {
                Threading.sleep(seconds: 1.0)
            }
        }
        if let device = device, device.instanceName != assignment.instanceName {
            Log.info(
                message: "[AssignmentController] Assigning \(assignment.deviceUUID) to \(assignment.instanceName)"
            )
            InstanceController.global.removeDevice(device: device)
            device.instanceName = assignment.instanceName
            done = false
            while !done {
                do {
                    try device.save(oldUUID: device.uuid)
                    done = true
                } catch {
                    Threading.sleep(seconds: 1.0)
                }
            }
            InstanceController.global.addDevice(device: device)
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

    public func instanceControllerDone(name: String) {

        for assignment in assignments {

            let deviceUUIDs = InstanceController.global.getDeviceUUIDsInInstance(instanceName: name)

            if assignment.enabled && assignment.time == 0 && deviceUUIDs.contains(assignment.deviceUUID) {
                triggerAssignment(assignment: assignment)
                return
            }

        }

    }
}
