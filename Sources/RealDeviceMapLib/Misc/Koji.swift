import Foundation
import PerfectLib
import PerfectCURL
import cURL

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
    
    /*
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
    */
    
    /*
    public func getDataFromKoji(kojiUrl: String, kojiSecret: String, dataPoints: [Coord], statsOnly: Bool = false, radius: Int = 70,
                                minPoints: Int = 1, benchmarkMode: Bool = false, sortBy: String = sorting.ClusterCount.asText(),
                                returnType: String = returnType.SingleArray.asText(), fast: Bool = true, onlyUnique: Bool = true,
                                timeout: Int = 120) -> Koji.returnData?
    {
        Log.debug(message: "[Koji - getDataFromKoji] Started process to get data from Koji")
        
        var toReturn: Koji.returnData? = nil
        
        let inputData: jsonInput = jsonInput(radius: radius, min_points: minPoints, benchmark_mode: benchmarkMode, sort_by: sortBy, return_type: returnType, fast: fast, only_unique: onlyUnique, data_points: dataPoints)
        Log.debug(message: "[Koji - getDataFromKoji] - \(inputData)")
        let jsonEncoder = JSONEncoder()
        let jsonData = try? jsonEncoder.encode(inputData)
        
        let body = String(data: jsonData!, encoding: String.Encoding.utf8)
        let byteArray:[UInt8] = Array(body!.utf8)
                
        Log.debug(message: "[Koji - getDataFromKoji] Encoded data to send to Koji as \(body)")

        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: byteArray.count)
        pointer.initialize(from: byteArray, count: byteArray.count)

        let header =    """
                        Authorization: Bearer \(kojiSecret)
                        Content-Type: application/json
                        Accept: application/json
                        """
        
        let curlObject = CURL(url: kojiSecret)
        curlObject.setOption(CURLOPT_POST, int: 1)
        curlObject.setOption(CURLOPT_HTTPHEADER, s: header)
        curlObject.setOption(CURLOPT_SSL_VERIFYPEER, int: 0)
        curlObject.setOption(CURLOPT_POSTFIELDS, v: pointer)
        curlObject.setOption(CURLOPT_POSTFIELDSIZE, int: byteArray.count)
        curlObject.setOption(CURLOPT_TIMEOUT, int: timeout)
        
        Log.debug(message: "[Koji - getDataFromKoji] Ready to call perform, curlObject=\(curlObject)")
        
        curlObject.perform
        {   (code, header, body) in
            
            Log.debug(message: "[Koji - getDataFromKoji] Called perform, got body length of = \(body)")
            
            let json = curlObject.url.data(using: String.Encoding.utf8)
            Log.debug(message: "[Koji - getDataFromKoji] Called perform, got data = \(String(describing: json))")

            if let kojiDataObject = try? JSONDecoder().decode(returnData.self, from: json!)
            {
                toReturn = kojiDataObject
            }
            else
            {
                Log.error(message: "[Koji - getDataFromKoji] Unable to decode JSON data obtained from Koji")
            }
            
            curlObject.close()
        }
        
        return toReturn
    }
     */
    
    public func getDataFromKoji(kojiUrl: String, kojiSecret: String, dataPoints: [Coord], statsOnly: Bool = false, radius: Int = 70,
                                minPoints: Int = 1, benchmarkMode: Bool = false, sortBy: String = sorting.ClusterCount.asText(),
                                returnType: String = returnType.SingleArray.asText(), fast: Bool = true, onlyUnique: Bool = true,
                                timeout: Int = 120) -> Koji.returnData?
    {
        Log.debug(message: "[Koji - getDataFromKoji] Started process to get data from Koji")
        
        var toReturn: Koji.returnData? = nil
        
        let inputData: jsonInput = jsonInput(radius: radius, min_points: minPoints, benchmark_mode: benchmarkMode, sort_by: sortBy, return_type: returnType, fast: fast, only_unique: onlyUnique, data_points: dataPoints)
        Log.debug(message: "[Koji - getDataFromKoji] - \(inputData)")
        let jsonEncoder = JSONEncoder()
        let jsonData = try? jsonEncoder.encode(inputData)
        
        let body = String(data: jsonData!, encoding: String.Encoding.utf8)
        
        let url = URL(string: kojiUrl)
        var request = URLRequest(url: url!)
        request.setValue("Authorization", forHTTPHeaderField: "Bearer \(kojiSecret)")
        request.setValue("Content-Type", forHTTPHeaderField: "application/json")
        request.setValue("Accept", forHTTPHeaderField: "application/json")
        request.httpMethod = "POST"
        request.httpBody = body?.data(using: String.Encoding.utf8)
        
        let semaphore = DispatchSemaphore.init(value: 0)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard
                let data = data,
                let response = response as? HTTPURLResponse,
                error == nil
            else {                                                               // check for fundamental networking error
                print("error", error ?? URLError(.badServerResponse))
                return
            }
            
            guard (200 ... 299) ~= response.statusCode else {                    // check for http errors
                print("statusCode should be 2xx, but is \(response.statusCode)")
                print("response = \(response)")
                return
            }
            
            // do whatever you want with the `data`, e.g.:
            
            do {
                let responseObject = try JSONDecoder().decode(returnData.self, from: data)
                print(responseObject)
            } catch {
                print(error) // parsing error
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("responseString = \(responseString)")
                } else {
                    print("unable to parse response as string")
                }
            }
            
            semaphore.signal()
        }

        task.resume()
        
        semaphore.wait(wallTimeout: .now() + 60)
        
        return toReturn
    }
} 
