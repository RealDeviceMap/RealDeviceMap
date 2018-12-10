//
//  LoginLimiter.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 10.12.18.
//

import Foundation
import PerfectThread

class LoginLimiter {
    
    static let global = LoginLimiter()
    
    let failedLock = Threading.Lock()
    var failed = [String: [Date]]()
    
    private init() {}
    
    func allowed(host: String) -> Bool {
        failedLock.lock()
        if failed[host] == nil {
            failedLock.unlock()
            return true
        }
        let now = Date()
        var realTimes = [Date]()
        for time in failed[host]! {
            if now.timeIntervalSince(time) <= 900 {
                realTimes.append(time)
            }
        }
        failed[host] = realTimes
        failedLock.unlock()
        return realTimes.count < 5
    }
    
    func failed(host: String) {
        failedLock.lock()
        if failed[host] == nil {
            failed[host] = [Date()]
        } else {
            failed[host]!.append(Date())
        }
        failedLock.unlock()
    }
    
}
