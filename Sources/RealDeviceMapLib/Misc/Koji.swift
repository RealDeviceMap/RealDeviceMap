//
//  Koji.swift
//  RealDeviceMapLib
//
//  Created by Beavis on Mar 15, 2023.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast large_tuple

import Foundation
import PerfectLib

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public class Koji {
    // koji related variables from config file
    private let kojiSecret: String = ConfigLoader.global.getConfig(type: .kojiSecret)
    private let kojiUrl: String = ConfigLoader.global.getConfig(type: .kojiUrl)

    // endpoints for koji that can be used
    public enum KojiEndPoint: String, CaseIterable {
        case clusterGym = "/api/v1/calc/cluster/gym"

        public func asText() -> String {
            return String(self.rawValue)
        }
    }

    // rudimentary check that the url provided in configs is ok
    public func hasValidUrl() -> Bool {
        return kojiUrl.isValidURL
    }
    public func getUrl() -> String {
        return kojiUrl
    }
    public func getSecret() -> String {
        return kojiSecret
    }

    // json data that is fed to koji
    public struct JsonInput: Codable {
        var radius: Int
        var minPoints: Int
        var benchmarkMode: Bool
        var sortBy: String
        var returnType: String
        var fast: Bool
        var onlyUnique: Bool
        var dataPoints: [Coord]

        enum CodingKeys: String, CodingKey {
            case radius
            case minPoints = "min_points"
            case benchmarkMode = "benchmark_mode"
            case sortBy = "sort_by"
            case returnType = "return_type"
            case fast
            case onlyUnique = "only_unique"
            case dataPoints = "data_points"
        }
    }

    // sorting options on how Koji can return data
    public enum Sorting: String, Codable {
        case random, geoHash, clusterCount

        public func asText() -> String {
            return String(self.rawValue.capitalized)
        }
    }

    // types of data that Koji can return
    public enum ReturnType: String, Codable {
        case singleArray, multiArray, `struct`, text, altText

        public func asText() -> String {
            return String(self.rawValue.capitalized)
        }
    }

    // json for main body of json data returned after Koji has done its thing
    public struct ReturnedDataOfSingleArray: Codable {
        var message: String
        var status: String
        var statusCode: Int
        var data: [Coord]?
        var stats: ReturnedStats

        enum CodingKeys: String, CodingKey {
            case message
            case status
            case statusCode = "status_code"
            case data
            case stats
        }
    }

    // returned stats from Koji
    public struct ReturnedStats: Codable {
        var bestClusters: [Coord]
        var bestClusterPointCount: Int
        var clusterTime: Double
        var totalPoints: Int
        var pointsCovered: Int
        var totalClusters: Int
        var totalDistance: Double
        var longestDistance: Double

        enum CodingKeys: String, CodingKey {
            case bestClusters = "best_clusters"
            case bestClusterPointCount = "best_cluster_point_count"
            case clusterTime = "cluster_time"
            case totalPoints = "total_points"
            case pointsCovered = "points_covered"
            case totalClusters = "total_clusters"
            case totalDistance = "total_distance"
            case longestDistance = "longest_distance"
        }
    }

    // function to get data from koji server
    //
    // 1. with the use of semaphores, the function is synchronous
    // 2. function returns nil if there is a problem with getting data from koji
    // 3. error handling is to be managed from calling functions, but function does utilize Log.error
    //
    public func getClusterTthFromKoji(dataPoints: [Coord], statsOnly: Bool = false, radius: Int = 70,
                                      minPoints: Int = 1, benchmarkMode: Bool = false, fast: Bool = true,
                                      sortBy: String = Sorting.clusterCount.asText(),
                                      returnType: String = ReturnType.singleArray.asText(), onlyUnique: Bool = true,
                                      timeout: Int = 60) -> Koji.ReturnedDataOfSingleArray? {
        Log.debug(message: "[Koji] getDataFromKojiSync() - " +
                  "Started process to get data from Koji, " +
                  "using url=\(kojiUrl + KojiEndPoint.clusterGym.asText())")

        var toReturn: Koji.ReturnedDataOfSingleArray?

        let inputData: JsonInput = JsonInput(radius: radius, minPoints: minPoints,
                                             benchmarkMode: benchmarkMode, sortBy: sortBy,
                                             returnType: returnType, fast: fast,
                                             onlyUnique: onlyUnique, dataPoints: dataPoints)
        let jsonEncoder = JSONEncoder()
        let jsonData = try? jsonEncoder.encode(inputData)

        // let body = String(data: jsonData!, encoding: String.Encoding.utf8)
        // Log.debug(message: "[Koji - getDataFromKoji] - body=\(body)")

        let url = URL(string: kojiUrl + KojiEndPoint.clusterGym.asText())
        var request = URLRequest(url: url!)
        request.setValue("Bearer \(kojiSecret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.httpMethod = "POST"
        request.httpBody = jsonData

        let semaphore = DispatchSemaphore.init(value: 0)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard
                let data = data,
                let response = response as? HTTPURLResponse,
                error == nil
            else
            {   // check for fundamental networking error
                Log.error(message: "[Koji] getDataFromKojiSync() - " +
                          "Error getting data from koji = " + String(error.debugDescription))
                return
            }

            guard (200 ... 299) ~= response.statusCode else {   // check for http errors
                Log.error(message: "[Koji] getDataFromKojiSync() - " +
                          "Bad response from koji, statusCode should be 2xx, but is \(response.statusCode)")
                Log.error(message: "[Koji] getDataFromKojiSync() - " +
                          "Bad response from koji, response = \(response)")
                return
            }

            // do whatever you want with the data returned from koji
            do {
                toReturn = try JSONDecoder().decode(ReturnedDataOfSingleArray.self, from: data)
            } catch {   // parsing error
                Log.error(message: "[Koji] getDataFromKojiSync() - Error parsing data from Koji, error = \(error)")

                if let responseString = String(data: data, encoding: .utf8) {
                    Log.error(message: "[Koji] getDataFromKojiSync() - " +
                              "Error parsing data from Koji, responseString = \(responseString)")
                } else {
                    Log.error(message: "[Koji] getDataFromKojiSync() - " +
                              "Error parsing data from Koji, unable to parse response as string")
                }
            }

            semaphore.signal()
        }

        task.resume()

        // wait for timeout seconds for things to finish before continuing
        _ = semaphore.wait(wallTimeout: .now() + DispatchTimeInterval.seconds(timeout))

        return toReturn
    }
}
