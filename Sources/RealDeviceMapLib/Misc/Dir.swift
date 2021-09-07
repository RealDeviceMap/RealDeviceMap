//
//  Dir.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 07.09.21.
//
import Foundation
import PerfectLib

public extension Dir {
    #if DEBUG
    public static let projectroot = ProcessInfo.processInfo.environment["PROJECT_DIR"] ?? Dir.workingDir.path
    #else
    public static let projectroot = Dir.workingDir.path
    #endif
}