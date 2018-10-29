//
//  Shell.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 29.10.18.
//

import Foundation

class Shell {
    
    private var args: [String]
    
    init (_ args: String...) {
        self.args = args
    }
    
    func run() -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: String.Encoding.utf8)
    }
    
}
