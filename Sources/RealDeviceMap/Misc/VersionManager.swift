//
//  VersionManager.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 10.05.20.
//

import Foundation
import PerfectLib
import PerfectCURL

internal class VersionManager {

    fileprivate struct TagsResponse: Codable {
        fileprivate struct Commit: Codable {
            fileprivate var sha: String
        }
        fileprivate var name: String
        fileprivate var commit: Commit
    }

    internal static let global = VersionManager()
    internal let version: String
    internal let commit: String
    internal let url: String

    // swiftlint:disable:next function_body_length
    private init() {
        let sha: String
        let pullRequest: String?
        let version: String
        let shaFile = File("\(projectroot)/.gitsha")
        do {
            try shaFile.open()
            sha = try shaFile.readString().components(separatedBy: .newlines)[0]
                             .trimmingCharacters(in: .whitespaces)
        } catch {
            sha = "?"
            Log.error(message: "[VersionManager] Failed to read .gitsha")
        }
        let refFile = File("\(projectroot)/.gitref")
        do {
            try refFile.open()
            let ref = try refFile.readString().components(separatedBy: .newlines)[0]
                                 .trimmingCharacters(in: .whitespaces)
            if ref.starts(with: "refs/pull/") && ref.contains(string: "/merge") {
                pullRequest = ref.replacingOccurrences(of: "refs/pull/", with: "")
                                 .replacingOccurrences(of: "/merge", with: "")
            } else {
                pullRequest = nil
            }
        } catch {
            pullRequest = nil
            Log.error(message: "[VersionManager] Failed to read .gitref")
        }

        if pullRequest == nil {
            let tagsRequest = CURLRequest("https://api.github.com/repos/RealDeviceMap/RealDeviceMap/tags")
            tagsRequest.addHeader(.userAgent, value: "RealDeviceMap")
            if let tags = try? tagsRequest.perform().bodyJSON([TagsResponse].self),
               let first = tags.first(where: { $0.commit.sha == sha }) {
                version = "Version \(first.name)"
            } else {
                version = "?"
            }
        } else {
            version = "Pull Request #\(pullRequest!)"
        }

        if pullRequest == nil {
            self.url = "https://github.com/RealDeviceMap/RealDeviceMap/releases"
        } else {
            self.url = "https://github.com/RealDeviceMap/RealDeviceMap/pull/\(pullRequest!)"
        }
        self.version = version
        self.commit = sha

        Log.info(message: "[VersionManager] \(version) (\(sha)")
    }

}
