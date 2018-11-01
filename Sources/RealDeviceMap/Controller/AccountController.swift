//
//  AccountController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 01.11.18.
//

import Foundation
import PerfectLib
import PerfectThread

class AccountController {
    
    public static var global = AccountController()
    private var clearSpinsQueue: ThreadQueue!
    private var isSetup = false
    
    private init() {}
    
    public func setup() {
        if isSetup {
            return
        }
        isSetup = true
        
        clearSpinsQueue = Threading.getQueue(name: "AccountController-spin-clearer", type: .serial)
        clearSpinsQueue.dispatch {
            while true {
                
                let date = Date()
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                formatter.timeZone = Localizer.global.timeZone
                let formattedDate = formatter.string(from: date)
                
                let split = formattedDate.components(separatedBy: ":")
                let hour = Int(split[0])!
                let minute = Int(split[1])!
                let second = Int(split[2])!
                
                let timeLeft = (23 - hour) * 3600 + (59 - minute) * 60 + (60 - second)
                
                if timeLeft > 0 {
                    Threading.sleep(seconds: Double(timeLeft))
                    
                    Log.debug(message: "[AccountController] Clearing Spins...")
                    var done = false
                    while !done {
                        do {
                            try Account.clearSpins()
                            done = true
                        } catch {
                            Threading.sleep(seconds: 5.0)
                        }
                    }
                    
                }
                
            }
        }
    }
    
    deinit {
        Threading.destroyQueue(clearSpinsQueue)
    }
    
}
