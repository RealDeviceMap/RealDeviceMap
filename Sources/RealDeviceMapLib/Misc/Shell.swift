//
//  Shell.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 29.10.18.
//

import Foundation
import PerfectLib

public class Shell {

    private var args: [String]

    public init(_ args: String...) {
        self.args = args
    }

    public func run(errorPipe: Any? = nil, inputPipe: Any? = nil, environment: [String: String]? = nil) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        if environment != nil {
            task.environment = environment
        }
        task.arguments = args
        let pipe = Pipe()
        if errorPipe != nil {
            task.standardError = errorPipe
        }
        if inputPipe != nil {
            task.standardInput = inputPipe
        }
        task.standardOutput = pipe
        do {
            try task.run()
        } catch {
            Log.error(message: "Failed to run command: \(error.localizedDescription)")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: String.Encoding.utf8)
    }

    public func runError(standardPipe: Any? = nil,
                         inputPipe: Any? = nil,
                         environment: [String: String]? = nil) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        if environment != nil {
            task.environment = environment
        }
        task.arguments = args
        let pipe = Pipe()
        if standardPipe != nil {
            task.standardOutput = standardPipe
        }
        if inputPipe != nil {
            task.standardInput = inputPipe
        }
        task.standardError = pipe
        do {
            try task.run()
        } catch {
            Log.error(message: "Failed to run command: \(error.localizedDescription)")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: String.Encoding.utf8)
    }

}
