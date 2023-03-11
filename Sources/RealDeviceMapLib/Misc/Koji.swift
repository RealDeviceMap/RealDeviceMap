import Foundation
import PerfectLib

public class Koji
{
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
        
        /*
        init(radius: Int, min_points: Int, becnchmark_mode: sorting, return_type: String, fast: Bool, only_unique: Bool, data_points: [Coord])
        {
            self.radius = radius
        }
         */
    }

    public enum sorting: String, Codable
    {
        case Random, GeoHash, ClusterCount
        
        public func asText() -> String
        {
            return String(self.rawValue)
        }
    }

    public enum returnType: String, Codable
    {
        case SingleArray, MultiArray, Struct, Text, AltText
        
        public func asText() -> String
        {
            return String(self.rawValue)
        }
    }

    public struct returnData: Codable
    {
        var message: String
        var status: String
        var status_code: Int
        var data: [Coord]
        var stats: returnedStats
    }
    
    public struct returnedStats: Codable
    {
        var best_clusters: [Coord]
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

    /*
    public func getDataFromKoji(kojiUrl: String, kojiSecret: String, dataPoints: [Coord], statsOnly: Bool = false, radius: Int = 70,
                                minPoints: Int = 1, benchmarkMode: Bool = false, sortBy: String = sorting.ClusterCount.asText(),
                                returnType: String = returnType.SingleArray.asText(), fast: Bool = true, onlyUnique: Bool = true) -> Koji.returnData
    {
        let inputData: jsonInput = jsonInput(radius: radius, min_points: minPoints, benchmark_mode: benchmarkMode, sort_by: sortBy, return_type: returnType, fast: fast, only_unique: onlyUnique, data_points: dataPoints)

        let jsonData = try? JSONSerialization.data(withJSONObject: inputData)

        let url = URL(string: kojiUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30.0
        sessionConfig.timeoutIntervalForResource = 60.0

        let task = URLSession.shared.dataTask(with: request)
        { data, response, error in
            guard let data = data, error == nil else {return}
                do
                {
                    if let returnedFromKoji = try? JSONDecoder().decode(returnData.self, from: data)
                    {
                        completion(returnedFromKoji, nil)
                    }
                }
                catch let jsonError
                {
                    Log.error(message: "[AutoInstanceController.getClustersFromKoji] Unable to get cluster data from Koji.")
                    completion(nil, jsonError)
                }
    
            
        }
        task.resume()
    }
    */
    
    public func getDataFromKoji(kojiUrl: String, kojiSecret: String, dataPoints: [Coord], statsOnly: Bool = false, radius: Int = 70,
                                   minPoints: Int = 1, benchmarkMode: Bool = false, sortBy: String = sorting.ClusterCount.asText(),
                                   returnType: String = returnType.SingleArray.asText(), fast: Bool = true, onlyUnique: Bool = true) -> Koji.returnData
    {
        let inputData: jsonInput = jsonInput(radius: radius, min_points: minPoints, benchmark_mode: benchmarkMode, sort_by: sortBy, return_type: returnType, fast: fast, only_unique: onlyUnique, data_points: dataPoints)

        let jsonData = try? JSONSerialization.data(withJSONObject: inputData)
        
        guard let url = NSURL(string: kojiUrl) else { return emptyReturnData() }
        let request = NSMutableURLRequest(url:url as URL)
        
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Authorization", forHTTPHeaderField: "Bearer " + kojiSecret)
        
        let retData = URLSession.requestSynchronousJSON(request: request)
        let jsonData = retData?.data!
        
        let returnedFromKoji = try? JSONDecoder().decode(returnData.self, from: jsonData)
    }
} 
