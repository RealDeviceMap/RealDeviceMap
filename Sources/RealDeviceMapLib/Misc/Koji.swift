import Foundation
import PerfectLib

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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
    
    public func getDataFromKoji(kojiUrl: String, kojiSecret: String, dataPoints: [Coord], statsOnly: Bool = false, radius: Int = 70,
                                minPoints: Int = 1, benchmarkMode: Bool = false, sortBy: String = sorting.ClusterCount.asText(),
                                returnType: String = returnType.SingleArray.asText(), fast: Bool = true, onlyUnique: Bool = true) -> Koji.returnData?
    {
        let inputData: jsonInput = jsonInput(radius: radius, min_points: minPoints, benchmark_mode: benchmarkMode, sort_by: sortBy, return_type: returnType, fast: fast, only_unique: onlyUnique, data_points: dataPoints)
        let jsonData = try? JSONSerialization.data(withJSONObject: inputData)
        
        var returnedData: Koji.returnData?
        
        let url = URL(string: kojiUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = URLSession.shared.dataTask(with: request, completionHandler: {data, response, error in
            if let error = error
            {
                Log.error(message: "Unable to retrieve data from Koji" + error.localizedDescription)
            }
            else if let response = response as? HTTPURLResponse, 300..<400 ~= response.statusCode
            {
                Log.error(message: "Unable to retrieve data from Koji" + response.debugDescription)
            }
            else if let data = data
            {
                if let kojiDataObject = try? JSONDecoder().decode(returnData.self, from: data)
                {
                    returnedData = kojiDataObject
                }
                else
                {
                    Log.error(message: "Unable to decode JSON data obtained from Koji")
                }
            }
            
            semaphore.signal()
        })
        
        task.resume()
        _ = semaphore.wait(wallTimeout: .now() + 120)
        
        return returnedData
    }
} 
