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
    private var cachedDataEn = [String: String]()

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
        if Localizer.locale != "en" {
            do {
                let fileEn = File("\(projectroot)/resources/webroot/static/data/en.json")
                try fileEn.open()
                let contentsEn = try fileEn.readString()
                let jsonEn = try contentsEn.jsonDecode() as? [String: Any]
                let valuesEn = jsonEn?["values"] as? [String: String]
                if valuesEn != nil {
                    cachedDataEn = valuesEn!
                }
            } catch {}
        }
    }

    func get(value: String) -> String {
        return cachedData[value] ?? cachedDataEn[value] ?? value
    }

    func get(value: String, replace: [String: String]) -> String {
        var value = cachedData[value] ?? cachedDataEn[value] ?? value
        for repl in replace {
            value = value.replacingOccurrences(of: "%{\(repl.key)}", with: repl.value)
        }
        return value
    }

}
