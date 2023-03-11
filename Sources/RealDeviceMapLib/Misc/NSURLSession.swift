import Foundation

/// NSURLSession synchronous behavior
/// Particularly for playground sessions that need to run sequentially
public extension URLSession
{    
    /// Return data from synchronous URL request
    static func requestSynchronousData(request: NSURLRequest) -> NSData? {
        var data: NSData? = nil
        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: {
            taskData, _, error -> () in
            data = taskData as NSData?
            if data == nil, let error = error {print(error)}
            semaphore.signal();
        })
        task.resume()
        //semaphore.wait(timeout: dispatch_time_t(DispatchTime.distantFuture))
        semaphore.wait(timeout: DispatchTime.init(uptimeNanoseconds: UInt64(6e+10)))
        return data
    }
    
    /// Return data synchronous from specified endpoint
    static func requestSynchronousDataWithURLString(requestString: String) -> NSData? {
        guard let url = NSURL(string:requestString) else {return nil}
        let request = NSURLRequest(url: url as URL)
        return URLSession.requestSynchronousData(request: request)
    }
    
    /// Return JSON synchronous from URL request
    static func requestSynchronousJSON(request: NSURLRequest) -> AnyObject?
    {
        guard let data = URLSession.requestSynchronousData(request: request) else {return nil}
        return data
        //return try? NSJSONSerialization.JSONObjectWithData(data as Data, options: [])
    }
    
    /// Return JSON synchronous from specified endpoint
    static func requestSynchronousJSONWithURLString(requestString: String) -> AnyObject? {
        guard let url = NSURL(string: requestString) else {return nil}
        let request = NSMutableURLRequest(url:url as URL)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return URLSession.requestSynchronousJSON(request: request)
    }
}
