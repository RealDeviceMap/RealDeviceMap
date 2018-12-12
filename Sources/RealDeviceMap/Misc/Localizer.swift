//
//  Localizer.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 07.10.18.
//

import Foundation
import PerfectLib

class Localizer {
    
    public static let global = Localizer()
    public static var locale = "en" {
        didSet {
            global.load()
        }
    }
    
    public var timeZone = NSTimeZone.default
    public private(set) var lastModified: Int = 0

    private var cachedData = [String: String]()
    

    
    private init() {}
    
    private func load() {
        let file = File("\(projectroot)/resources/webroot/static/data/\(Localizer.locale).json")
        lastModified = file.modificationTime
        do {
            try file.open()
            let contents = try file.readString()
            guard
                let json = try contents.jsonDecode() as? [String: Any],
                let values = json["values"] as? [String: String]
                else {
                    Log.error(message: "[Localizer] Failed to read file for locale: \(Localizer.locale)")
                    return
            }
            cachedData = values
        } catch {
            Log.error(message: "[Localizer] Failed to read file for locale: \(Localizer.locale)")
        }
    }
 
    func get(value: String) -> String {
        return cachedData[value] ?? value
    }
    
    func get(value: String, replace: [String: String]) -> String {
        var value = cachedData[value] ?? value
        for repl in replace {
            value = value.replacingOccurrences(of: "%{\(repl.key)}", with: repl.value)
        }
        return value
    }
    
}
