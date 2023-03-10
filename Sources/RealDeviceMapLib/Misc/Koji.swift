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

    public enum sorting
    {
        Random = "Random"
        GeoHash = "GeoHash"
        ClusterCount = "ClusterCount"
    }

    public enum returnType
    {
        SingleArray = "Array"
        MultiArray = "MultiArray"
        Struct = "Struct"
        Text = "Text"
        AltText = "Text"
    }

    public struct returnData : Decodable
    {
        message: String
        status: String
        status_code: Int
        data: [Coord]
        stats: kojiReturnStats
    }
    
    public struct returnStats: Decodable
    {
        best_clusters: [Coord]
        best_cluster_point_count : Int
        cluster_time: Double
        total_points: Int
        points_covered: Int
        total_clusters: Int
        total_distance: Double
        longest_distance: Double
    }
}