//
//  VersionManager.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 10.05.20.
//

import Foundation
import PerfectLib
import PerfectCURL

public class VersionManager {

    fileprivate struct TagsResponse: Codable {
        fileprivate struct Commit: Codable {
            fileprivate var sha: String
        }
        fileprivate var name: String
        fileprivate var commit: Commit
    }

    public static let global = VersionManager()
    internal let version: String
    internal let commit: String
    internal let url: String

    // swiftlint:disable:next function_body_length
    private init() {
        let sha: String
        let pullRequest: String?
        let version: String
        let shaFile = File("\(Dir.projectroot)/.gitsha")
        do {
            try shaFile.open()
            sha = try shaFile.readString().components(separatedBy: .newlines)[0]
                             .trimmingCharacters(in: .whitespaces)
        } catch {
            sha = "?"
            Log.error(message: "[VersionManager] Failed to read .gitsha")
        }
        let refFile = File("\(Dir.projectroot)/.gitref")
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
            let tagsRequest = CURLRequest("https://api.github.com/repos/RealDeviceMapLib/RealDeviceMapLib/tags")
            tagsRequest.addHeader(.userAgent, value: "RealDeviceMapLib")
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
            self.url = "https://github.com/RealDeviceMapLib/RealDeviceMapLib/releases"
        } else {
            self.url = "https://github.com/RealDeviceMapLib/RealDeviceMapLib/pull/\(pullRequest!)"
        }
        self.version = version
        self.commit = sha

        Log.info(message: "[VersionManager] \(version) (\(sha))")
    }

}
