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
        let branch: String?
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
                branch = nil
            } else if ref.starts(with: "refs/heads/") {
                branch = ref.replacingOccurrences(of: "refs/heads/", with: "")
                pullRequest = nil
            } else {
                pullRequest = nil
                branch = nil
            }
        } catch {
            pullRequest = nil
            branch = nil
            Log.error(message: "[VersionManager] Failed to read .gitref")
        }

        if pullRequest == nil {
            let tagsRequest = CURLRequest("https://api.github.com/repos/RealDeviceMap/RealDeviceMap/tags")
            tagsRequest.addHeader(.userAgent, value: "RealDeviceMap")
            if let tags = try? tagsRequest.perform().bodyJSON([TagsResponse].self),
               let first = tags.first(where: { $0.commit.sha == sha }) {
                version = "Version \(first.name)"
            } else {
                if branch != nil {
                    version = branch!
                } else {
                    version = "?"
                }
            }
        } else {
            version = "Pull Request #\(pullRequest!)"
        }

        if pullRequest != nil {
            self.url = "https://github.com/RealDeviceMap/RealDeviceMap/pull/\(pullRequest!)"
        } else if branch != nil && !version.contains("Version ") {
            self.url = "https://github.com/RealDeviceMap/RealDeviceMap/tree/\(branch!)"
        } else {
            self.url = "https://github.com/RealDeviceMap/RealDeviceMap/releases"
        }
        self.version = version
        self.commit = sha

        Log.info(message: "[VersionManager] \(version) (\(sha))")
    }

}
