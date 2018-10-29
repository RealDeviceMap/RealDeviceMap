//
//  AutoInstanceController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 23.10.18.
//

import Foundation
import PerfectLib
import PerfectThread
import Turf

class AutoInstanceController: InstanceControllerProto {
    
    enum AutoType {
        case quest
    }
    
    public private(set) var name: String

    private var multiPolygon: MultiPolygon
    private var type: AutoType
    private var stopsLock = NSLock()
    private var allStops: [Pokestop]?
    private var todayStops: [Pokestop]?
    private var questClearerQueue: ThreadQueue?
    private var timezoneOffset: Int
    
    private static let cooldownDataArray = [1: 0, 2: 2, 4: 3, 5: 4, 8: 5, 10: 7, 15: 9, 20: 12, 25: 15, 30: 17, 35: 18, 45: 20, 50: 20, 60: 21, 70: 23, 80: 24, 90: 25, 100: 26, 125: 29, 150: 32, 175: 34, 201: 37, 250: 41, 300: 46, 328: 48, 350: 50, 400: 54, 450: 58, 500: 62, 550: 66, 600: 70, 650: 74, 700: 77, 751: 82, 802: 84, 839: 88, 897: 90, 900: 91, 948: 95, 1007: 98, 1020: 102, 1100: 104, 1180: 109, 1200: 111, 1221: 113, 1300: 117, 1344: 119, Int.max: 120].sorted { (lhs, rhs) -> Bool in
        lhs.key < rhs.key
    }
    
    init(name: String, multiPolygon: MultiPolygon, type: AutoType, timezoneOffset: Int) {
        self.name = name
        self.type = type
        self.multiPolygon = multiPolygon
        self.timezoneOffset = timezoneOffset
        update()
        
        if type == .quest {
            questClearerQueue = Threading.getQueue(name: "\(name)-quest-clearer", type: .serial)
            questClearerQueue!.dispatch {
                
                while true {
                    var calendar = Calendar.current
                    calendar.timeZone = TimeZone(secondsFromGMT: timezoneOffset) ?? TimeZone.current
                    let tomorrowMidnight = calendar.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTimePreservingSmallerComponents)!
                    let timeLeft = tomorrowMidnight.timeIntervalSince(Date())
                    
                    if timeLeft > 0 {
                        sleep(UInt32(timeLeft))
                        
                        let ids = self.allStops!.map({ (stop) -> String in
                            return stop.id
                        })
                        var done = false
                        while !done {
                            do {
                                try Pokestop.clearQuests(ids: ids)
                                done = true
                            } catch {
                                sleep(5)
                            }
                        }
                        self.stopsLock.lock()
                        self.todayStops = self.allStops
                        self.stopsLock.unlock()
                    }
                }
                
            }
        }
        
    }
    
    deinit {
        if questClearerQueue != nil {
            Threading.destroyQueue(questClearerQueue!)
        }
    }
    
    private func update() {
        switch type {
        case .quest:
            stopsLock.lock()
            self.allStops = [Pokestop]()
            for polygon in multiPolygon.polygons {
                
                if let bounds = BoundingBox(from: polygon.outerRing.coordinates),
                    let stops = try? Pokestop.getAll(minLat: bounds.southEast.latitude, maxLat: bounds.northWest.latitude, minLon: bounds.northWest.longitude, maxLon: bounds.southEast.longitude, updated: 0, questsOnly: false, showQuests: true) {
                    
                    for stop in stops {
                        let coord = CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon)
                        if polygon.contains(coord, ignoreBoundary: false) {
                            self.allStops!.append(stop)
                        }
                    }
                }
                
            }
            self.todayStops = [Pokestop]()
            for stop in self.allStops! {
                if stop.questType == nil {
                    self.todayStops!.append(stop)
                }
            }
            stopsLock.unlock()
        }
    }
    
    private func encounterCooldown(distM: Double) -> UInt32 {
        
        let dist = distM / 1000
        
        for data in AutoInstanceController.cooldownDataArray {
            if Double(data.key) >= dist {
                return UInt32(data.value * 60)
            }
        }
        return 0
    
    }
    
    
    func getTask(uuid: String, username: String?) -> [String : Any] {
        
        switch type {
        case .quest:
            
            stopsLock.lock()
            if todayStops == nil || todayStops!.isEmpty {
                stopsLock.unlock()
                return [String : Any]()
            }
            stopsLock.unlock()
        
            var lastLat: Double?
            var lastLon: Double?
            var lastTime: UInt32?
            var account: Account?
            
            do {
                if username != nil, let accountT = try Account.getWithUsername(username: username!) {
                    account = accountT
                    lastLat = accountT.lastEncounterLat
                    lastLon = accountT.lastEncounterLon
                    lastTime = accountT.lastEncounterTime
                } else {
                    lastLat = Double(try DBController.global.getValueForKey(key: "AIC_\(uuid)_last_lat") ?? "")
                    lastLon = Double(try DBController.global.getValueForKey(key: "AIC_\(uuid)_last_lon") ?? "")
                    lastTime = UInt32(try DBController.global.getValueForKey(key: "AIC_\(uuid)_last_time") ?? "")
                }
            } catch { }
            
            let newLon: Double
            let newLat: Double
            let encounterTime: UInt32
            
            if lastLat != nil && lastLon != nil {
                
                let current = CLLocationCoordinate2D(latitude: lastLat!, longitude: lastLon!)
                
                var closest: Pokestop!
                var closestDistance: Double = 6378137
                
                stopsLock.lock()
                let todayStopsC = todayStops
                stopsLock.unlock()
                
                for stop in todayStopsC! {
                    let coord = CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon)
                    let dist = current.distance(to: coord)
                    if dist < closestDistance {
                        closest = stop
                        closestDistance = dist
                    }
                }
                
                newLon = closest.lon
                newLat = closest.lat
                if lastTime == nil {
                    encounterTime = UInt32(Date().timeIntervalSince1970)
                } else {
                    let encounterTimeT = lastTime! + encounterCooldown(distM: closestDistance)
                    let new = UInt32(Date().timeIntervalSince1970)
                    if encounterTimeT < new {
                        encounterTime = new
                    } else {
                        encounterTime = encounterTimeT
                    }
                }
                stopsLock.lock()
                todayStops?.removeAll(where: { (stop) -> Bool in
                    stop.id == closest.id
                })
                stopsLock.unlock()
            } else {
                stopsLock.lock()
                let stop = todayStops!.first!
                newLon = stop.lon
                newLat = stop.lat
                encounterTime = UInt32(Date().timeIntervalSince1970)
                _ = todayStops!.removeFirst()
                stopsLock.unlock()
            }
            
            if username != nil && account != nil {
                account!.lastEncounterLon = newLon
                account!.lastEncounterLat = newLat
                account!.lastEncounterTime = encounterTime
                try? account!.save(update: true)
            } else {
                try? DBController.global.setValueForKey(key: "AIC_\(uuid)_last_lat", value: newLat.description)
                try? DBController.global.setValueForKey(key: "AIC_\(uuid)_last_lon", value: newLon.description)
                try? DBController.global.setValueForKey(key: "AIC_\(uuid)_last_time", value: encounterTime.description)
            }
            
            let delayT = Int(Date(timeIntervalSince1970: Double(encounterTime)).timeIntervalSinceNow)
            let delay: Int
            if delayT < 0 {
                delay = 0
            } else {
                delay = delayT + 1
            }
            
            if todayStops!.isEmpty {
                let ids = self.allStops!.map({ (stop) -> String in
                    return stop.id
                })
                var newStops: [Pokestop]!
                var done = false
                while !done {
                    do {
                        newStops = try Pokestop.getIn(ids: ids)
                        done = true
                    } catch {
                        sleep(5)
                    }
                }
                
                stopsLock.lock()
                for stop in newStops {
                    if stop.questType == nil {
                        todayStops!.append(stop)
                    }
                }
                if todayStops!.isEmpty {
                    Log.info(message: "[AutoInstanceController] Instance \(name) done")
                }
                
                stopsLock.unlock()
                
            }
            
            return ["action": "scan_quest", "lat": newLat, "lon": newLon, "delay": delay]
        }

    }
    
        
}
