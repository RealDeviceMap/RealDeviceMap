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
    private let hitsLock = Threading.Lock()
    private var hits = [String: Date]()

    init(interval: Double, keepTime: Double) {
        let clearingQueue = Threading.getQueue(name: "MemoryCache-\(UUID().uuidString)-clearer", type: .serial)
        clearingQueue.dispatch {
            while true {
                let now = Date()
                self.lock.writeLock()
                self.hitsLock.lock()
                self.store = self.store.filter { element in
                    let hit = self.hits[element.key]
                    return hit != nil && now.timeIntervalSince(hit!) < keepTime
                }
                self.lock.unlock()
                self.hitsLock.unlock()
                Threading.sleep(seconds: Double(interval))
            }
        }
    }

    func get(id: String) -> T? {
        lock.readLock()
        let value = store[id]
        lock.unlock()
        if value != nil {
            hitsLock.lock()
            hits[id] = Date()
            hitsLock.unlock()
        }
        return value
    }

    func set(id: String, value: T) {
        lock.writeLock()
        store[id] = value
        lock.unlock()
        hitsLock.lock()
        hits[id] = Date()
        hitsLock.unlock()
    }

    func clear() {
        lock.writeLock()
        store = [:]
        lock.unlock()
        hitsLock.lock()
        hits = [:]
        hitsLock.unlock()
    }

}
