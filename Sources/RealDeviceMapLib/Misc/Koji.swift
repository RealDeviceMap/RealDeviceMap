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

public class Koji
{
    // koji related variables from config file
    private let kojiSecret: String = ConfigLoader.global.getConfig(type: .kojiSecret)
    private let kojiUrl: String = ConfigLoader.global.getConfig(type: .kojiUrl)
    
    // endpoints for koji that can be used
    public enum kojiEndPoint: String, CaseIterable 
    {
        case clusterGym = "/api/v1/calc/cluster/gym"

        public func asText() -> String
        {
            return String(self.rawValue)
        }
    }
    
    // rudimentary check that the url provided in configs is ok
    public func hasValidUrl() -> Bool
    {
        return kojiUrl.isValidURL
    }
    public func getUrl() -> String
    {
        return kojiUrl
    }
    public func getSecret() -> String
    {
        return kojiSecret
    }
    
    // json data that is fed to koji
    public struct jsonInput: Codable
    {
        var radius: Int
        var min_points: Int
        var benchmark_mode: Bool
        var sort_by: String
        var return_type: String
        var fast: Bool
        var only_unique: Bool
        var data_points: [Coord]
    }

    // sorting options on how Koji can return data
    public enum sorting: String, Codable
    {
        case Random, GeoHash, ClusterCount
        
        public func asText() -> String
        {
            return String(self.rawValue)
        }
    }

    // types of data that Koji can return
    public enum returnType: String, Codable
    {
        case SingleArray, MultiArray, Struct, Text, AltText
        
        public func asText() -> String
        {
            return String(self.rawValue)
        }
    }

    // json for main body of json data returned after Koji has done its thing
    public struct returnData: Codable
    {
        var message: String
        var status: String
        var status_code: Int
        var data: [[Double]]?
        var stats: returnedStats
    }
    
    // returned stats from Koji
    public struct returnedStats: Codable
    {
        var best_clusters: [[Double]]
        var best_cluster_point_count : Int
        var cluster_time: Double
        var total_points: Int
        var points_covered: Int
        var total_clusters: Int
        var total_distance: Double
        var longest_distance: Double
    }
    
    func emptyReturnData() -> returnData
    {
        return returnData(message: "", status: "error", status_code: -1, data: [], stats: emptyReturnStats())
    }
    func emptyReturnStats() -> returnedStats
    {
        return returnedStats(best_clusters: [], best_cluster_point_count: 0, cluster_time: 0.0, total_points: 0, points_covered: 0, total_clusters: 0, total_distance: 0.0, longest_distance: 0.0)
    }
  
    // function to get data from koji server
    //
    // 1. with the use of semaphores, the function is synchronous
    // 2. function returns nil if there is a problem with getting data from koji
    // 3. error handling is to be managed from calling functions, but function does utilize Log.error
    //
    public func getDataFromKojiSync(dataPoints: [Coord], statsOnly: Bool = false, radius: Int = 70,
                                minPoints: Int = 1, benchmarkMode: Bool = false, fast: Bool = true, sortBy: String = sorting.ClusterCount.asText(),
                                returnType: String = returnType.SingleArray.asText(), onlyUnique: Bool = true,
                                timeout: Int = 60) -> Koji.returnData?
    {
        Log.debug(message: "[Koji] getDataFromKojiSync() - Started process to get data from Koji, using url=\(kojiUrl + kojiEndPoint.clusterGym.asText())")
        
        var toReturn: Koji.returnData? = nil
        
        let inputData: jsonInput = jsonInput(radius: radius, min_points: minPoints, benchmark_mode: benchmarkMode, sort_by: sortBy, return_type: returnType, fast: fast, only_unique: onlyUnique, data_points: dataPoints)
        let jsonEncoder = JSONEncoder()
        let jsonData = try? jsonEncoder.encode(inputData)
        
        // let body = String(data: jsonData!, encoding: String.Encoding.utf8)
        // Log.debug(message: "[Koji - getDataFromKoji] - body=\(body)")
        
        let url = URL(string: kojiUrl + kojiEndPoint.clusterGym.asText())
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
                Log.error(message: "[Koji] getDataFromKojiSync() - Error getting data from koji = " + String(error.debugDescription))
                return
            }
            
            guard (200 ... 299) ~= response.statusCode else
            {   // check for http errors
                Log.error(message: "[Koji] getDataFromKojiSync() - Bad response from koji, statusCode should be 2xx, but is \(response.statusCode)")
                Log.error(message: "[Koji] getDataFromKojiSync() - Bad response from koji, response = \(response)")
                return
            }
            
            // do whatever you want with the data returned from koji
            do
            {
                toReturn = try JSONDecoder().decode(returnData.self, from: data)
            }
            catch
            {   // parsing error
                Log.error(message: "[Koji] getDataFromKojiSync() - Error parsing data from Koji, error = \(error)")
                print(error) 
                
                if let responseString = String(data: data, encoding: .utf8)
                {
                    Log.error(message: "[Koji] getDataFromKojiSync() - Error parsing data from Koji, responseString = \(responseString)")
                }
                else
                {
                    Log.error(message: "[Koji] getDataFromKojiSync() - Error parsing data from Koji, unable to parse response as string")
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
