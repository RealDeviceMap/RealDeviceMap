//
//  Log.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 21.09.21.
//

import PerfectLib

public extension Log {
    static var logDebug = true
    static func debug(message: @autoclosure () -> String) {
        if logDebug {
            Log.logger.debug(message: message(), even)
        }
    }
}
