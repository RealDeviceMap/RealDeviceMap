//
//  HTTPResponse.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//

import Foundation
import PerfectLib
import PerfectThread

class MemoryCache<T> {

    private let lock = Threading.RWLock()
    private var store = [String: T]()
    private var hits = [String: Date]()

    init(interval: UInt32, keepTime: Double) {
        let clearingQueue = Threading.getQueue(name: "MemoryCache-\(UUID().uuidString)-clearer", type: .serial)
        clearingQueue.dispatch {
            while true {
                let now = Date()
                self.lock.writeLock()
                self.store = self.store.filter { element in
                    let hit = self.hits[element.key]
                    return hit != nil && now.timeIntervalSince(hit!) < keepTime
                }
                self.lock.unlock()
                sleep(interval)
            }
        }
    }

    func get(id: String) -> T? {
        lock.readLock()
        let value = store[id]
        lock.unlock()
        if value != nil {
            hits[id] = Date()
        }
        return value
    }

    func set(id: String, value: T) {
        lock.writeLock()
        store[id] = value
        lock.unlock()
        hits[id] = Date()
    }

    func clear() {
        lock.writeLock()
        store = [:]
        lock.unlock()
    }

}
