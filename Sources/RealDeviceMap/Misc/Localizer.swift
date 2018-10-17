//
//  Localizer.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 07.10.18.
//

import Foundation
import PerfectLib

class Localizer {
    
    public static var locale = "en"
    public static let global = Localizer()
    
    private var cachedData = [String: String]()
    
    private init() {
        let file = File("resources/webroot/static/data/\(Localizer.locale).json")
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
 
    func get(value: String) -> String? {
        return cachedData[value]
    }
    
}
