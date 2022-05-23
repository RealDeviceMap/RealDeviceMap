//
//  Config.swift
//  Config
//
//  Created by Fabio S. on 20.05.2022.
//
import Foundation
import PerfectLib

@dynamicMemberLookup
public class Config {
    private var url: URL?
    private var properties: JSON?

    public init(with fileName: String) {
        let file = File("\(Dir.projectroot)/\(fileName).json")
        guard file.exists else {
            Log.error(message: "Config file not found \(fileName)")
            return
        }
        self.url = URL(fileURLWithPath: file.path)
        self.readConfig()
    }

    public subscript(dynamicMember member: String) -> JSON {
        if let properties = self.properties {
            let val = properties[member]
            return val
        }
        return JSON.error("Please check your config source, not exists or not valid JSON.")
    }

    public subscript<T>(key: String) -> T? {
        let splitChar = "."
        var subscripts: [String] = []
        if key.contains(splitChar) {
            subscripts = key.components(separatedBy: splitChar)
        } else {
            subscripts.append(key)
        }
        var data: JSON = self[dynamicMember: subscripts[0]]
        for i in 1..<subscripts.count {
            data = data[dynamicMember: subscripts[i]]
        }
        return data.value()
    }

    private func readConfig() {
        guard let url = self.url else {
            Log.error(message: "[RDMConfig] Please check your config source, not exists or not valid JSON.")
            return
        }
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard let response = try? JSONDecoder().decode(JSON.self, from: data)
            else {
                Log.error(message: "Not valid JSON.")
                return
            }
            properties = response
        } catch {
            Log.error(message: "Not valid JSON.")
        }
    }

    public func isEmpty() -> Bool {
        return properties == nil
    }

    public func reset() {
        properties = nil
        url = nil
    }
}
