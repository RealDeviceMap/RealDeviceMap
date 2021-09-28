//
//  Shell.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 29.10.18.
//

import Foundation

public class Shell {

    private var args: [String]

    public init (_ args: String...) {
        self.args = args
    }

    @discardableResult
    public func run(errorPipe: Any?=nil, inputPipe: Any?=nil, environment: [String: String]?=nil) -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/env"
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
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: String.Encoding.utf8)
    }

    @discardableResult
    public func runError(standartPipe: Any?=nil, inputPipe: Any?=nil, environment: [String: String]?=nil) -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        if environment != nil {
            task.environment = environment
        }
        task.arguments = args
        let pipe = Pipe()
        if standartPipe != nil {
            task.standardOutput = standartPipe
        }
        if inputPipe != nil {
            task.standardInput = inputPipe
        }
        task.standardError = pipe
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: String.Encoding.utf8)
    }

}
