//
//  Log.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 21.09.21.
//

import PerfectLib

public extension Log {
    static var threshold = LogPriority.debug
    static func info(message: @autoclosure () -> String) {
        if threshold <= .info {
            Log.logger.info(message: message(), even)
        }
    }
    static func debug(message: @autoclosure () -> String) {
        if threshold <= .debug {
            Log.logger.debug(message: message(), even)
        }
    }
    static func warning(message: @autoclosure() -> String) {
        if threshold <= .warning {
            Log.logger.warning(message: message(), even)
        }
    }
    static func setThreshold(value: String) {
        if value == "debug" {
            Log.threshold = .debug
        } else if value == "warning" {
            Log.threshold = .warning
        } else {
            Log.threshold = .info
        }
    }
}

public enum LogPriority: Int {
    case debug
    case info
    case warning
    // case error
    // case critical
    // case terminal
}

extension LogPriority: Comparable {
    public static func == (lhs: LogPriority, rhs: LogPriority) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }

    public static func < (lhs: LogPriority, rhs: LogPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    public static func > (lhs: LogPriority, rhs: LogPriority) -> Bool {
        return lhs.rawValue > rhs.rawValue
    }

    public static func <= (lhs: LogPriority, rhs: LogPriority) -> Bool {
        return lhs.rawValue <= rhs.rawValue
    }

}
