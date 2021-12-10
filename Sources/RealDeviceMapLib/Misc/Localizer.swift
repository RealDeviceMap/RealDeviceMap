//
//  Localizer.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 07.10.18.
//

import Foundation
import PerfectLib
import PerfectCURL
import PerfectThread

public class Localizer {

    public static let global = Localizer()
    public static var locale = "en" {
        didSet {
            global.load()
            global.loadTranslationsFromRepo(language: Localizer.locale)
        }
    }

    public var timeZone = NSTimeZone.default

    public private(set) var lastModified: Int = 0
    public private(set) var wwwLastModified: Int = 0

    private var cachedData = [String: String]()
    private var cachedDataEn = [String: String]()

    private let updaterThread: ThreadQueue
    private var eTag: String?

    private init() {
        updaterThread = Threading.getQueue(name: "TranslationFileUpdater", type: .serial)
        updaterThread.dispatch {
            while true {
                Threading.sleep(seconds: 900)
                self.loadTranslationFileIfNeeded()
            }
        }
    }

    private func load() {
        let file = File("\(Dir.projectroot)/resources/webroot/static/data/\(Localizer.locale).json")
        lastModified = file.modificationTime
        do {
            try file.open()
            let contents = try file.readString()
            file.close()
            guard
                let json = try contents.jsonDecode() as? [String: Any],
                let values = json["values"] as? [String: String]
                else {
                    Log.error(message: "[Localizer] Failed to read file for locale: \(Localizer.locale)")
                    return
            }
            cachedData.merge(values) { (_, new) in new }
        } catch {
            Log.error(message: "[Localizer] Failed to read file for locale: \(Localizer.locale)")
        }

        if Localizer.locale != "en" {
            do {
                let fileEn = File("\(Dir.projectroot)/resources/webroot/static/data/en.json")
                try fileEn.open()
                let contentsEn = try fileEn.readString()
                fileEn.close()
                let jsonEn = try contentsEn.jsonDecode() as? [String: Any]
                let valuesEn = jsonEn?["values"] as? [String: String]
                if valuesEn != nil {
                    cachedDataEn = valuesEn!
                }
            } catch {}
        }
    }

    private func loadTranslationFileIfNeeded() {
        let request = CURLRequest(
            "https://raw.githubusercontent.com/WatWowMap/pogo-translations/" +
                "master/static/locales/\(Localizer.locale).json",
            .httpMethod(.head)
        )
        guard let result = try? request.perform() else {
            Log.error(message: "[pogo-translations] Failed to load translation file")
            return
        }
        let newETag = result.get(.eTag)
        if newETag != eTag {
            Log.info(message: "[pogo-translations] Translation file changed")
            loadTranslationsFromRepo(language: Localizer.locale)
        }
    }

    private func loadTranslationsFromRepo(language: String) {
        let request = CURLRequest(
            "https://raw.githubusercontent.com/WatWowMap/pogo-translations/master/static/locales/\(language).json"
        )
        guard let result = try? request.perform() else {
            Log.error(message: "[Localizer] Failed to load pogo-translations file")
            return
        }
        eTag = result.get(.eTag)
        // save translation file for JS frontend
        let file = File("\(Dir.projectroot)/resources/webroot/static/data/www_\(language).json")
        do {
            try file.open(.readWrite)
            try file.write(bytes: result.bodyBytes)
            wwwLastModified = file.modificationTime
            file.close()
        } catch {
            Log.error(message: "[Localizer] Failed to save pogo-translations file: \(error)")
        }
        // save translation into cache
        let bodyJSON = try? JSONSerialization.jsonObject(with: Data(result.bodyBytes))
        guard let values = bodyJSON as? [String: String] else {
            Log.error(message: "[Localizer] Failed to read pogo-translations file for locale: \(Localizer.locale)")
            return
        }
        cachedData.merge(values) { (_, new) in new }
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
