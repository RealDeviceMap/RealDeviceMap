import Foundation

public class Koji
{
    public struct jsonInput: Codable
    {
        var radius: Int
        var min_points: Int
        var benchmark_mode: Bool
        var sort_by: kojiSorting
        var return_type: String
        var fast: Bool
        var only_unique: Bool
        var data_points: [Coord]
    }

    public enum sorting: String, Printable
    {
        Random = "Random"
        GeoHash = "GeoHash"
        ClusterCount = "ClusterCount"
    }

    public enum returnType: String, Printable
    {
        SingleArray = "Array"
        MultiArray = "MultiArray"
        Struct = "Struct"
        Text = "Text"
        AltText = "Text"
    }

    public struct returnData: Decodable
    {
        var message: String
        var status: String
        var status_code: Int
        var data: [Coord]
        var stats: returnedStats
    }
    
    public struct returnedStats: Decodable
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

    public func getDataFromKoji(kojiUrl:string, dataPoints: [Coord], statsOnly: Bool = false, radius: Int = 70,
        minPoints: Int = 1, benchmarkMode: Bool = false, sortBy: String = kojiSorting.ClusterCount,
        returnType: String = kojiReturnType.SingleArray, fast: Bool = true, onlyUnique: Bool = true) -> Koji.returnData
    {
        var inputData = Koji.jsonInput(radius: radius, min_points: minPoints, benchmark_mode: benchmarkMode, 
                        sort_by = sortBy, return_type = returnType, fast = fast, only_unique = onlyUnique,
                        data_points = dataPoints)

        let jsonData = try? JSONSerialization.data(withJSONObject: inputData)

        let url = URL(string: kojiUrl)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30.0
        sessionConfig.timeoutIntervalForResource = 60.0

        let task = URLSession(configuration: sessionConfig).shared.dataTask(with: request)
        { data, response, error in
            guard let data = data, error == nil else
            {
                Log.error(message: "[AutoInstanceController.getClustersFromKoji] Unable to get cluster data from Koji.")
                return nil
            }
    
            if let returnedFromKoji: Koji.returnData = try? JSONDecoder().decode(returnedFromKoji.self, from: jsonData)
            {
                return returnedFromKoji
            }
        }
        task.resume()
    }
} 